// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {PoolId} from "v4-core/types/PoolId.sol";
import {IBLSSignatureCheckerTypes} from "eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IVetoableSlasher} from "eigenlayer-middleware/src/interfaces/IVetoableSlasher.sol";

import {ICommitmentReader} from "./ICommitmentReader.sol";
import {Commitment} from "../types/Commitment.sol";
import {ToBOrder} from "../types/ToBOrder.sol";

/// @title IEigenAuctionTaskManager
/// @author ohMySol
/// @notice Interface for EigenAuctionTaskManager.
/// @dev Extends the `ICommitmentReader` (the Settler-facing `getCommitment` surface)
/// with the BLS-dependent write/admin surface. The `Commitment` struct lives in `types/` so the
/// reader stays free of the `^0.8.27` middleware graph imported below.
interface IEigenAuctionTaskManager is ICommitmentReader {
    /// @notice Quorums whose aggregate signature must clear the threshold, one byte per quorum id.
    /// EigenLayer organizes restaked operators into numbered quorums (groups), which are segmented
    /// by strategy/token type. Each byte in this bytes value is one quorum id.
    function quorumNumbers() external view returns (bytes memory);

    /// @notice Minimum signed-to-total stake ratio required per quorum, in basis points. The minimum
    /// fraction of total registered stake in a quorum that must be represented in the aggregate BLS
    /// signature.
    function thresholdBps() external view returns (uint256);

    /// @notice Updates the quorum set the verifier checks against (e.g. as the operator set evolves).
    /// @dev Only AVS admin can call this function.
    /// @param newQuorumNumbers New quorum ids (one byte each).
    function setQuorumNumbers(bytes calldata newQuorumNumbers) external;

    /// @notice Updates the per-quorum stake threshold in basis points.
    /// @dev Only AVS admin can call this function.
    /// @param newThresholdBps New threshold in basis points (e.g. 6000 for 60%).
    function setThreshold(uint256 newThresholdBps) external;

    /* SLASHING VIEWS */

    /// @notice Veto-gated slasher this contract queues slashing requests into.
    /// Returns `address(0)` when slashing is disabled.
    function vetoableSlasher() external view returns (IVetoableSlasher);

    /// @notice Fraction of each strategy's slashable allocation slashed on a fault.
    /// Expressed in wad (1e18 = 100%).
    function wadToSlash() external view returns (uint256);

    /// @notice Strategies whose allocations are slashed on a fault.
    function strategies() external view returns (IStrategy[] memory);

    /// @notice BLS quorum id whose signers are accountable on a fault.
    function quorumNumber() external view returns (uint8);

    /// @notice EigenLayer operator set id slashed on a fault.
    function operatorSetId() external view returns (uint32);

    /* SLASHING ADMIN */

    /// @notice Sets the VetoableSlasher this contract queues slashing into.
    /// Pass `address(0)` to disable slashing without removing the strategies config.
    /// @dev Only the coordinator owner may call this.
    /// @param newVetoableSlasher New VetoableSlasher address (or zero to disable).
    function setVetoableSlasher(IVetoableSlasher newVetoableSlasher) external;

    /// @notice Updates the strategies and per-strategy wad slashed on a fault.
    /// @dev Only the coordinator owner may call this. Both arrays must be non-empty / non-zero.
    /// @param newStrategies New strategy set (non-empty).
    /// @param newWadToSlash New per-strategy slash fraction in wad (non-zero).
    function setSlashingConfig(IStrategy[] calldata newStrategies, uint256 newWadToSlash) external;

    /* COMMIT */

    /// @notice Records the quorum-attested winner for the current block.
    ///
    /// @dev Permissionless: the BLS signature is the authorization, so anyone may relay it. A griefer
    /// can't forge a quorum signature, and re-relaying the same result just hits `AlreadyCommitted`.
    ///
    /// @param poolId Pool the result is for.
    /// @param targetBlock Block the result settles in; must be the current block.
    /// @param resultHash `keccak256(arbOrderHash, clearingPriceX128, intentsRoot)`.
    /// @param executor Off-chain-selected operator permitted to settle this commitment.
    /// @param referenceBlockNumber Past block whose stake snapshot the signature is verified against.
    /// @param quorums Quorum ids the signature covers; must equal the configured `quorumNumbers`.
    /// @param nonSignerStakesAndSignature Aggregate signature plus non-signer data for the verifier.
    /// @dev `quorums` is taken from calldata (the verifier requires it) but pinned to the configured
    /// set, so a relayer can't substitute a weaker quorum where it happens to hold majority stake.
    function commitWinner(
        PoolId poolId,
        uint256 targetBlock,
        bytes32 resultHash,
        address executor,
        uint32 referenceBlockNumber,
        bytes calldata quorums,
        IBLSSignatureCheckerTypes.NonSignerStakesAndSignature calldata nonSignerStakesAndSignature
    ) external;

    /* CHALLENGE */

    /// @notice Proves a commitment fraudulent by providing a strictly-better signed arbitrage order
    /// than the one committed, marks it challenged, and queues slashing of its signers.
    ///
    /// @dev Permissionless. `committedArb` + `clearingPriceX128` + `intentsRoot` must reproduce the
    /// commitment's `resultHash`, proving `committedArb` is the order the quorum attested. The empty-arb
    /// case (a profitable arb existed but none was committed) is out of scope. Slashing is skipped when
    /// no slasher / strategies are configured (the fraud is still recorded).
    ///
    /// @param poolId Pool the disputed commitment belongs to.
    /// @param targetBlock Block the disputed commitment targeted.
    /// @param committedArb The arbitrage order carried in the committed result.
    /// @param clearingPriceX128 The committed uniform clearing price (to rebuild the result hash).
    /// @param intentsRoot The committed intents root (to rebuild the result hash).
    /// @param dominantOrder A searcher-signed order that strictly dominates `committedArb`.
    /// @param referenceBlockNumber Stake-snapshot block the fraudulent signature was verified against,
    /// used to reconstruct the signer set. Ignored when no slasher is set.
    /// @param nonSignerPubkeyHashes Sorted pubkey hashes of the operators that did not sign the
    /// fraudulent commitment. Ignored when no slasher is set.
    function challenge(
        PoolId poolId,
        uint256 targetBlock,
        ToBOrder calldata committedArb,
        uint256 clearingPriceX128,
        bytes32 intentsRoot,
        ToBOrder calldata dominantOrder,
        uint32 referenceBlockNumber,
        bytes32[] calldata nonSignerPubkeyHashes
    ) external;
}
