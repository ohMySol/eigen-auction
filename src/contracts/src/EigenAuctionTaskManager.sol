// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BLSSignatureChecker} from "eigenlayer-middleware/src/BLSSignatureChecker.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IIndexRegistry} from "eigenlayer-middleware/src/interfaces/IIndexRegistry.sol";
import {IVetoableSlasher} from "eigenlayer-middleware/src/interfaces/IVetoableSlasher.sol";
import {IAllocationManagerTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {IEigenAuctionTaskManager} from "./interfaces/IEigenAuctionTaskManager.sol";
import {ICommitmentReader} from "./interfaces/ICommitmentReader.sol";
import {Commitment} from "./types/Commitment.sol";
import {ToBOrder} from "./types/ToBOrder.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";

/// @dev Minimal Settler surface to recover the EIP-712 domain a `ToBOrder` was signed under. A
/// runtime call, not an import, so the ^0.8.0 Settler graph stays out of this ^0.8.27 contract.
interface ISettlerDomain {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/// @title EigenAuctionTaskManager
/// @author ohMySol
/// @notice On-chain task logic for the EigenAuction AVS. A stake-weighted BLS quorum of the operator
/// set attests each block's auction result off-chain; the aggregator relays the aggregate signature
/// here via `commitWinner`. Once a commitment exists, the bound `executor` settles it (enforced in
/// the Settler). The committed terms are later challengeable with a strictly-better order.
///
/// @dev Inherits EigenLayer's `BLSSignatureChecker`. The winning `executor` is part of the signed
/// message, so the quorum (not any single operator) decides who may settle while the random selection
/// itself stays off-chain.
contract EigenAuctionTaskManager is BLSSignatureChecker, IEigenAuctionTaskManager {
    /* CONSTANTS */

    string private constant _SLASH_DESCRIPTION = "EigenAuction: fraudulent commitment";

    /* IMMUTABLES */

    /// @notice Index registry supplying the operator list snapshot at a reference block.
    IIndexRegistry public immutable indexRegistry;

    /// @notice Quorum whose signers are slashed on a fault.
    uint8 public immutable quorumNumber;

    /// @notice Operator set id slashed on a fault.
    uint32 public immutable operatorSetId;

    /* STATE VARIABLES */

    /// @inheritdoc IEigenAuctionTaskManager
    bytes public quorumNumbers;

    /// @inheritdoc IEigenAuctionTaskManager
    uint256 public thresholdBps;

    /// @dev poolId => target block => attested result.
    mapping(PoolId => mapping(uint256 => Commitment)) private _commitments;

    /// @notice Veto-gated slasher requests are queued into. address(0) disables slashing.
    IVetoableSlasher public vetoableSlasher;

    /// @dev Strategies slashed on a fault.
    IStrategy[] private _strategies;

    /// @notice Fraction of each strategy's slashable allocation to slash, in wad (1e18 = 100%).
    uint256 public wadToSlash;

    /// @notice Settler whose EIP-712 domain is used to verify challenged `ToBOrder` signatures.
    address public settler;

    /* CONSTRUCTOR */

    /// @param _registryCoordinator The AVS registry coordinator; supplies the stake/APK registries the
    /// inherited verifier reads, and whose owner administers the config below.
    /// @param _quorumNumbers Initial quorum ids (one byte each).
    /// @param _thresholdBps Initial stake threshold in bps (e.g. 6000 for 60%).
    /// @param _quorumNumber Quorum id whose signers are slashed on a fault.
    /// @param _operatorSetId Operator set id slashed on a fault.
    constructor(
        ISlashingRegistryCoordinator _registryCoordinator,
        bytes memory _quorumNumbers,
        uint256 _thresholdBps,
        uint8 _quorumNumber,
        uint32 _operatorSetId
    ) BLSSignatureChecker(_registryCoordinator) {
        _setQuorumNumbers(_quorumNumbers);
        _setThreshold(_thresholdBps);
        quorumNumber = _quorumNumber;
        operatorSetId = _operatorSetId;
        indexRegistry = _registryCoordinator.indexRegistry();
    }

    /* ADMIN — gated by the registry coordinator owner (the AVS admin) */

    /// @inheritdoc IEigenAuctionTaskManager
    function setQuorumNumbers(bytes calldata newQuorumNumbers) external onlyCoordinatorOwner {
        _setQuorumNumbers(newQuorumNumbers);
    }

    /// @inheritdoc IEigenAuctionTaskManager
    function setThreshold(uint256 newThresholdBps) external onlyCoordinatorOwner {
        _setThreshold(newThresholdBps);
    }

    /// @notice Sets the VetoableSlasher requests are queued into. address(0) disables slashing
    /// (challenge still records the fraud).
    /// @param newVetoableSlasher New VetoableSlasher address, or zero to disable slashing.
    function setVetoableSlasher(IVetoableSlasher newVetoableSlasher) external onlyCoordinatorOwner {
        vetoableSlasher = newVetoableSlasher;
    }

    /// @notice Updates the strategies and per-strategy wad slashed on a fault.
    /// @param newStrategies New strategy set (non-empty).
    /// @param newWadToSlash New per-strategy slash fraction in wad (non-zero, 1e18 = 100%).
    function setSlashingConfig(IStrategy[] calldata newStrategies, uint256 newWadToSlash) external onlyCoordinatorOwner {
        _setSlashingConfig(newStrategies, newWadToSlash);
    }

    /// @notice Sets the Settler whose EIP-712 domain verifies challenged order signatures.
    /// @param newSettler Address of the deployed `Settler` contract.
    function setSettler(address newSettler) external onlyCoordinatorOwner {
        settler = newSettler;
    }

    /* COMMIT */

    /// @inheritdoc IEigenAuctionTaskManager
    function commitWinner(
        PoolId poolId,
        uint256 targetBlock,
        bytes32 resultHash,
        address executor,
        uint32 referenceBlockNumber,
        bytes calldata quorums,
        NonSignerStakesAndSignature calldata nonSignerStakesAndSignature
    ) external {
        if (executor == address(0)) revert ErrorsLib.EigenAuctionTaskManager_ZeroExecutor();
        // A winner is only ever committed for the block it will settle in.
        if (targetBlock != block.number) revert ErrorsLib.EigenAuctionTaskManager_WrongTargetBlock();
        // Stake must be read from a confirmed past block; the verifier additionally enforces recency.
        if (referenceBlockNumber >= block.number) revert ErrorsLib.EigenAuctionTaskManager_FutureReferenceBlock();
        if (keccak256(quorums) != keccak256(quorumNumbers)) revert ErrorsLib.EigenAuctionTaskManager_QuorumNumbersMismatch();
        // Fail before the (expensive) pairing check.
        if (_commitments[poolId][targetBlock].exists) revert ErrorsLib.EigenAuctionTaskManager_AlreadyCommitted();

        // Binding `executor` into the signed hash is what makes the random selection trustless: the
        // quorum signs who settles, so no lone operator can nominate itself.
        bytes32 msgHash = keccak256(abi.encode(poolId, targetBlock, resultHash, executor));

        (QuorumStakeTotals memory totals, bytes32 signatoryRecordHash) =
            _verifyQuorum(msgHash, referenceBlockNumber, quorums, nonSignerStakesAndSignature);

        _requireThreshold(totals);

        _commitments[poolId][targetBlock] = Commitment({
            resultHash: resultHash,
            hashOfNonSigners: signatoryRecordHash,
            executor: executor,
            exists: true,
            challenged: false
        });

        emit EventsLib.WinnerCommitted(poolId, targetBlock, executor, resultHash);
    }

    /* CHALLENGE */

    /// @inheritdoc IEigenAuctionTaskManager
    function challenge(
        PoolId poolId,
        uint256 targetBlock,
        ToBOrder calldata committedArb,
        uint256 clearingPriceX128,
        bytes32 intentsRoot,
        ToBOrder calldata dominantOrder,
        uint32 referenceBlockNumber,
        bytes32[] calldata nonSignerPubkeyHashes
    ) external {
        Commitment storage commitment = _commitments[poolId][targetBlock];

        if (!commitment.exists) revert ErrorsLib.EigenAuctionTaskManager_NoCommitment();
        if (commitment.challenged) revert ErrorsLib.EigenAuctionTaskManager_AlreadyChallenged();
        if (block.number > targetBlock + ConstantsLib.CHALLENGE_WINDOW) {
            revert ErrorsLib.EigenAuctionTaskManager_ChallengeWindowClosed();
        }

        _proveFraud(
            poolId, 
            targetBlock, 
            committedArb, 
            clearingPriceX128, 
            intentsRoot, 
            dominantOrder, 
            commitment.resultHash
        );

        commitment.challenged = true;
        emit EventsLib.CommitmentChallenged(poolId, targetBlock, msg.sender);

        if (address(vetoableSlasher) != address(0) && _strategies.length != 0) {
            _queueSlashing(poolId, targetBlock, referenceBlockNumber, nonSignerPubkeyHashes, commitment);
        }
    }

    /* VIEWS */

    /// @inheritdoc ICommitmentReader
    function getCommitment(PoolId poolId, uint256 targetBlock) external view override returns (Commitment memory) {
        return _commitments[poolId][targetBlock];
    }

    /// @notice Strategies slashed on a fault.
    function strategies() external view returns (IStrategy[] memory) {
        return _strategies;
    }

    /* INTERNAL */

    /// @dev Wrapper over the inherited `checkSignatures`. Production verifies the real
    /// aggregate signature; tests override this to return canned stake totals without standing up the
    /// registry stack. `checkSignatures` itself is `public` and not `virtual`, hence the wrapper.
    /// @param msgHash Hash of the message the quorum must have signed.
    /// @param referenceBlockNumber Block whose operator stake snapshot is used for verification.
    /// @param quorums Quorum ids the signature covers.
    /// @param params Non-signer stakes and aggregate BLS signature data for the verifier.
    function _verifyQuorum(
        bytes32 msgHash,
        uint32 referenceBlockNumber,
        bytes calldata quorums,
        NonSignerStakesAndSignature calldata params
    ) internal view virtual returns (QuorumStakeTotals memory, bytes32 signatoryRecordHash) {
        return checkSignatures(msgHash, quorums, referenceBlockNumber, params);
    }

    /* PRIVATE */

    /// @dev Proves the committed order is fraudulent: `committedArb` reproduces the commitment's
    /// `resultHash`, and `dominantOrder` is a genuine searcher-signed order for the same pool/block/
    /// direction that strictly dominates it. Reverts otherwise. Split out of `challenge` to keep its
    /// stack shallow under the non-viaIR optimizer.
    /// @param poolId Pool the disputed commitment belongs to.
    /// @param targetBlock Block the disputed commitment targeted.
    /// @param committedArb The arb order carried in the committed result.
    /// @param clearingPriceX128 The committed clearing price, used to rebuild the result hash.
    /// @param intentsRoot The committed intents root, used to rebuild the result hash.
    /// @param dominantOrder The challenger's order that must strictly dominate `committedArb`.
    /// @param committedResultHash The result hash stored in the commitment, used to verify `committedArb`.
    function _proveFraud(
        PoolId poolId,
        uint256 targetBlock,
        ToBOrder calldata committedArb,
        uint256 clearingPriceX128,
        bytes32 intentsRoot,
        ToBOrder calldata dominantOrder,
        bytes32 committedResultHash
    ) private view {
        // Prove committedArb is the order the quorum actually attested.
        bytes32 resultHash = keccak256(abi.encode(committedArb.toBStructHash(), clearingPriceX128, intentsRoot));
        if (resultHash != committedResultHash) revert ErrorsLib.EigenAuctionTaskManager_ResultMismatch();

        // The dominant order must dispute the same pool/block/direction.
        if (
            dominantOrder.poolId != PoolId.unwrap(poolId) ||
            dominantOrder.validForBlock != targetBlock ||
            dominantOrder.zeroForOne != committedArb.zeroForOne
        ) revert ErrorsLib.EigenAuctionTaskManager_OrderMismatch();

        // Dominance: pays >= and wants <= (strict in at least one) -> strictly larger token0 bid for any
        // AMM state, so no historical pool data is needed.
        bool dominates = dominantOrder.quantityIn >= committedArb.quantityIn && dominantOrder.quantityOut <= committedArb.quantityOut
            && (dominantOrder.quantityIn > committedArb.quantityIn || dominantOrder.quantityOut < committedArb.quantityOut);
        if (!dominates) revert ErrorsLib.EigenAuctionTaskManager_NotDominant();

        // The order must be a genuine searcher commitment under the Settler's EIP-712 domain.
        bytes32 digest = keccak256(
            abi.encodePacked(hex"1901", ISettlerDomain(settler).DOMAIN_SEPARATOR(), dominantOrder.toBStructHash())
        );
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, dominantOrder.signature);

        if (err != ECDSA.RecoverError.NoError || recovered != dominantOrder.searcher) {
            revert ErrorsLib.EigenAuctionTaskManager_InvalidOrderSignature();
        }
    }

    /// @dev Reverts unless every quorum's signed stake meets the threshold. Bounded by the number of
    /// quorums (one in the default config). Rearranged to a cross-multiplication so there is no
    /// division or rounding; `uint96 * BPS` cannot overflow `uint256`.
    /// @param totals Signed and total stake per quorum returned by the BLS signature verifier.
    function _requireThreshold(QuorumStakeTotals memory totals) private view {
        uint256 quorums = totals.signedStakeForQuorum.length;
        for (uint256 i; i < quorums; ++i) {
            if (uint256(totals.signedStakeForQuorum[i]) * ConstantsLib.BPS < uint256(totals.totalStakeForQuorum[i]) * thresholdBps) {
                revert ErrorsLib.EigenAuctionTaskManager_QuorumNotMet();
            }
        }
    }

    /// @dev Validates the non-signer set against the stored `hashOfNonSigners`, then reconstructs
    /// the signer set (full quorum minus non-signers minus executor) and queues one slash per signer.
    /// @param poolId Pool the fraudulent commitment belongs to (used only for the emitted event).
    /// @param targetBlock Block the fraudulent commitment targeted (used only for the emitted event).
    /// @param referenceBlockNumber Block used to snapshot the operator set that signed the commitment.
    /// @param nonSignerPubkeyHashes Sorted BLS pubkey hashes of operators that did not sign.
    /// @param commitment The fraudulent commitment whose `hashOfNonSigners` is verified against.
    function _queueSlashing(
        PoolId poolId,
        uint256 targetBlock,
        uint32 referenceBlockNumber,
        bytes32[] calldata nonSignerPubkeyHashes,
        Commitment memory commitment
    ) private {
        bytes32 computed = keccak256(abi.encodePacked(referenceBlockNumber, nonSignerPubkeyHashes));
        if (computed != commitment.hashOfNonSigners) {
            revert ErrorsLib.EigenAuctionTaskManager_SignatoryRecordMismatch();
        }
        
        bytes32[] memory fullSet = indexRegistry.getOperatorListAtBlockNumber(quorumNumber, referenceBlockNumber);
        bytes32 executorId = blsApkRegistry.getOperatorId(commitment.executor);
        uint256 signerCount = _queueSigners(fullSet, executorId, nonSignerPubkeyHashes);
        
        emit EventsLib.SignatorySlashingQueued(poolId, targetBlock, signerCount);
    }

    /// @dev Queues one slashing request per signer (full set minus executor and non-signers).
    /// Split out of `_queueSlashing` to keep the stack shallow under the non-viaIR optimizer.
    /// @param fullSet BLS pubkey hashes of all operators registered at the reference block.
    /// @param executorId BLS pubkey hash of the committed executor, skipped during slashing.
    /// @param nonSignerPubkeyHashes Sorted hashes of operators that did not sign, also skipped.
    function _queueSigners(
        bytes32[] memory fullSet,
        bytes32 executorId,
        bytes32[] calldata nonSignerPubkeyHashes
    ) private returns (uint256 signerCount) {
        IStrategy[] memory strategies_ = _strategies;
        uint256[] memory wads = new uint256[](strategies_.length);
        
        for (uint256 i; i < wads.length; ++i) {
            wads[i] = wadToSlash;
        }
        
        for (uint256 i; i < fullSet.length; ++i) {
            bytes32 id = fullSet[i];
            if (id == executorId || _isNonSigner(id, nonSignerPubkeyHashes)) continue;
            
            address operator = blsApkRegistry.getOperatorFromPubkeyHash(id);
            
            vetoableSlasher.queueSlashingRequest(
                IAllocationManagerTypes.SlashingParams({
                    operator: operator,
                    operatorSetId: operatorSetId,
                    strategies: strategies_,
                    wadsToSlash: wads,
                    description: _SLASH_DESCRIPTION
                })
            );
            ++signerCount;
            
            emit EventsLib.OperatorSlashQueued(operator);
        }
    }

    /// @dev Linear scan to check whether a pubkey hash belongs to the non-signer set.
    /// @param id BLS pubkey hash to search for.
    /// @param nonSignerPubkeyHashes The non-signer list to search through.
    function _isNonSigner(bytes32 id, bytes32[] calldata nonSignerPubkeyHashes) private pure returns (bool) {
        for (uint256 i; i < nonSignerPubkeyHashes.length; ++i) {
            if (nonSignerPubkeyHashes[i] == id) return true;
        }
        return false;
    }

    /// @dev Validates and stores the slashing config.
    /// @param strategies_ New strategy set to slash on a fault (must be non-empty).
    /// @param newWadToSlash New per-strategy slash fraction in wad (must be non-zero; 1e18 = 100%).
    function _setSlashingConfig(IStrategy[] memory strategies_, uint256 newWadToSlash) private {
        if (strategies_.length == 0 || newWadToSlash == 0) {
            revert ErrorsLib.EigenAuctionTaskManager_InvalidSlashingConfig();
        }
        _strategies = strategies_;
        wadToSlash = newWadToSlash;
        emit EventsLib.SlashingConfigSet(strategies_.length, newWadToSlash);
    }

    /// @dev Validates and stores the quorum numbers.
    /// @param newQuorumNumbers New quorum ids to require (one byte per quorum, must be non-empty).
    function _setQuorumNumbers(bytes memory newQuorumNumbers) private {
        if (newQuorumNumbers.length == 0) revert ErrorsLib.EigenAuctionTaskManager_EmptyQuorumNumbers();
        quorumNumbers = newQuorumNumbers;
    }

    /// @dev Validates and stores the stake threshold.
    /// @param newThresholdBps New threshold in basis points (must be > 0 and ≤ BPS = 10_000).
    function _setThreshold(uint256 newThresholdBps) private {
        if (newThresholdBps == 0 || newThresholdBps > ConstantsLib.BPS) revert ErrorsLib.EigenAuctionTaskManager_InvalidThreshold();
        thresholdBps = newThresholdBps;
    }
}
