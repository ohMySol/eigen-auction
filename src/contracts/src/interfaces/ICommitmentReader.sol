// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

import {Commitment} from "../types/Commitment.sol";

/// @title ICommitmentReader
/// @author ohMySol
/// @notice Settler-facing read surface over `EigenAuctionTaskManager`'s commitments.
/// @dev Kept EigenLayer-free so the Settler (pragma ^0.8.0) can import it without pulling in the
/// ^0.8.27 BLS middleware that `IEigenAuctionTaskManager` requires. Do not co-locate with that
/// interface. `EigenAuctionTaskManager` satisfies this surface via inheritance.
interface ICommitmentReader {
    /// @notice Returns the commitment for `(poolId, targetBlock)`, or a zeroed struct if none was recorded.
    /// @param poolId The pool to look up.
    /// @param targetBlock The block number the commitment is for.
    /// @return The stored commitment; check `exists` before using other fields.
    function getCommitment(PoolId poolId, uint256 targetBlock) external view returns (Commitment memory);
}
