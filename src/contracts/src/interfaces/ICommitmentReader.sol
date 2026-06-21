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
    /// @notice The commitment for `(poolId, targetBlock)`, or a zero struct if none exists.
    function getCommitment(PoolId poolId, uint256 targetBlock) external view returns (Commitment memory);
}
