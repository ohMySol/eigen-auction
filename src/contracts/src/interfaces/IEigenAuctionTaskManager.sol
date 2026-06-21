// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";
import {IBLSSignatureCheckerTypes} from "eigenlayer-middleware/src/interfaces/IBLSSignatureChecker.sol";

/// @notice A quorum-attested auction result for a single (pool, block).
/// @dev The mapping key (target block) doubles as the commit block, so it isn't stored again.
/// @param resultHash `keccak256(arbOrderHash, clearingPriceX128, intentsRoot)` — the exact batch the
/// executor must reproduce at settle time.
/// @param signatoryRecordHash Identifies the operators that signed; consumed by the fraud-proof slash.
/// @param executor The off-chain selected operator allowed to call `settle` for this commitment.
/// @param exists Whether a commitment was recorded (zero-struct guard).
struct Commitment {
    bytes32 resultHash;
    bytes32 signatoryRecordHash;
    address executor;
    bool exists;
}

/// @title IEigenAuctionTaskManager
/// @author ohMySol
/// @notice Interface for EigenAuctionTaskManager.
interface IEigenAuctionTaskManager {
    /// @notice Quorums whose aggregate signature must clear the threshold, one byte per quorum id.
    /// EigenLayer organizes restaked operators into numbered quorums (groups) which typically segmented 
    /// by strategy/token type. Each byte in this bytes value is one quorum ID
    function quorumNumbers() external view returns (bytes memory);

    // @notice Minimum signed-to-total stake ratio required per quorum, in basis points.
    // It's the minimum fraction of total registered stake in a quorum that must be represented in the aggregate BLS signature.
    function thresholdBps() external view returns (uint256);

    /// @notice Updates the quorum set the verifier checks against (e.g. as the operator set evolves).
    /// @dev Only AVS admin can call this function.
    /// @param newQuorumNumbers New quorum number of operators
    function setQuorumNumbers(bytes calldata newQuorumNumbers) external;

    /// @notice Updates the per-quorum stake threshold in basis points.
    /// @dev Only AVS admin can call this function.
    /// @param newThresholdBps New threshold value in 
    function setThreshold(uint256 newThresholdBps) external;

    /// @notice Records the quorum-attested winner for the current block.
    /// @dev Permissionless: the BLS signature is the authorization, so anyone may relay it. A griefer
    /// can't forge a quorum signature, and re-relaying the same result just hits `AlreadyCommitted`.
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

    /// @notice The commitment for `(poolId, targetBlock)`, or a zero struct if none exists.
    function getCommitment(PoolId poolId, uint256 targetBlock) external view returns (Commitment memory);
}
