// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BLSSignatureChecker} from "eigenlayer-middleware/src/BLSSignatureChecker.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {IEigenAuctionTaskManager} from "./interfaces/IEigenAuctionTaskManager.sol";
import {ICommitmentReader} from "./interfaces/ICommitmentReader.sol";
import {Commitment} from "./types/Commitment.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";

/// @title EigenAuctionTaskManager
/// @author ohMySol
/// @notice On-chain task logic for the EigenAuction AVS. A stake-weighted BLS quorum of the operator
/// set attests each block's auction result off-chain; the aggregator relays the aggregate signature
/// here via `commitWinner`. Once a commitment exists, the bound `executor` settles it (enforced in
/// the Settler). The committed terms are later challengeable with a strictly-better order.
///
/// @dev Inherits EigenLayer's `BLSSignatureChecker`. The  winning `executor` is part of the signed message, 
/// so the quorum (not any single operator) decides who may settle while the random selection itself stays off-chain.
contract EigenAuctionTaskManager is BLSSignatureChecker, IEigenAuctionTaskManager {
    /* STATE VARIABLES */
    
    /// @inheritdoc IEigenAuctionTaskManager
    bytes public quorumNumbers;

    /// @inheritdoc IEigenAuctionTaskManager
    uint256 public thresholdBps;

    /// @dev poolId => target block => attested result.
    mapping(PoolId => mapping(uint256 => Commitment)) private _commitments;
    
    /* CONSTRUCTOR */

    /// @param _registryCoordinator The AVS registry coordinator; supplies the stake/APK registries the
    /// inherited verifier reads, and whose owner administers the config below.
    /// @param _quorumNumbers Initial quorum ids (one byte each).
    /// @param _thresholdBps Initial stake threshold in bps (e.g. 6000 for 60%).
    constructor(ISlashingRegistryCoordinator _registryCoordinator, bytes memory _quorumNumbers, uint256 _thresholdBps)
        BLSSignatureChecker(_registryCoordinator)
    {
        _setQuorumNumbers(_quorumNumbers);
        _setThreshold(_thresholdBps);
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
            signatoryRecordHash: signatoryRecordHash,
            executor: executor,
            exists: true
        });

        emit EventsLib.WinnerCommitted(poolId, targetBlock, executor, resultHash);
    }

    /* VIEWS */

    /// @inheritdoc ICommitmentReader
    function getCommitment(PoolId poolId, uint256 targetBlock) external view override returns (Commitment memory) {
        return _commitments[poolId][targetBlock];
    }

    /* INTERNAL */

    /// @dev Wrapper over the inherited `checkSignatures`. Production verifies the real
    /// aggregate signature; tests override this to return canned stake totals without standing up the
    /// registry stack. `checkSignatures` itself is `public` and not `virtual`, hence the wrapper.
    function _verifyQuorum(
        bytes32 msgHash,
        uint32 referenceBlockNumber,
        bytes calldata quorums,
        NonSignerStakesAndSignature calldata params
    ) internal view virtual returns (QuorumStakeTotals memory, bytes32 signatoryRecordHash) {
        return checkSignatures(msgHash, quorums, referenceBlockNumber, params);
    }

    /// @dev Reverts unless every quorum's signed stake meets the threshold. Bounded by the number of
    /// quorums (one in the default config). Rearranged to a cross-multiplication so there is no
    /// division or rounding; `uint96 * BPS` cannot overflow `uint256`.
    function _requireThreshold(QuorumStakeTotals memory totals) private view {
        uint256 quorums = totals.signedStakeForQuorum.length;
        for (uint256 i; i < quorums; ++i) {
            if (uint256(totals.signedStakeForQuorum[i]) * ConstantsLib.BPS < uint256(totals.totalStakeForQuorum[i]) * thresholdBps) {
                revert ErrorsLib.EigenAuctionTaskManager_QuorumNotMet();
            }
        }
    }

    /// @dev Verify and set new quorum numbers
    function _setQuorumNumbers(bytes memory newQuorumNumbers) private {
        if (newQuorumNumbers.length == 0) revert ErrorsLib.EigenAuctionTaskManager_EmptyQuorumNumbers();
        quorumNumbers = newQuorumNumbers;
    }

    /// @dev Verify and set new threshold bps
    function _setThreshold(uint256 newThresholdBps) private {
        if (newThresholdBps == 0 || newThresholdBps > ConstantsLib.BPS) revert ErrorsLib.EigenAuctionTaskManager_InvalidThreshold();
        thresholdBps = newThresholdBps;
    }
}
