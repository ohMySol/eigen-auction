// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

/// @notice Struct that defines auction result data
/// @param bidAmount Auction winner bid amount
/// @param winner Address of the auction winner
/// @param committed Whether this event was committed to `AuctionServiceManager` contract
struct AuctionResult {
    uint256 bidAmount;
    address winner;
    bool committed;
}

/// @title IAuctionServiceManager
/// @author ohMySol
/// @notice Interface that defines the functions for the `AuctionServiceManager` contract.
/// The service manager is the on-chain anchor for the off-chain AVS auction: a quorum of
/// registered operators signs the per-block winner, and the winner is committed here so the
/// `EigenAuctionHook` can enforce exclusivity for arb swaps.
interface IAuctionServiceManager {
    /// @notice Minimum number of unique operator signatures required to commit a winner.
    function threshold() external view returns (uint256);

    /// @notice Mapping: operator address => whether it belongs to the signing set.
    /// @param operator Address to check
    /// @return True if the address is a registered operator
    function isOperator(address operator) external view returns (bool);

    /// @notice Returns the operator by index
    function operators(uint256 index) external view returns (address);
    
    /// @notice Adds an operator to the signing set.
    /// @dev Restricted to the owner. Reverts on the zero address or a duplicate registration.
    /// @param operator Address of the operator to register
    function registerOperator(address operator) external;
    
    /// @notice Returns the committed auction result for a given pool and block.
    /// @dev Returns a zero-initialised struct (committed == false) when no winner was committed.
    ///
    /// @param poolId ID of the pool
    /// @param blockNumber Chain block number to look up the result for
    /// @return AuctionResult structure with auction information for the (poolId, blockNumber) pair
    function getWinner(PoolId poolId, uint256 blockNumber) external view returns (AuctionResult memory);

    /// @notice Commits the auction winner for a given pool and block.
    /// Callers supply a bundle of operator signatures over the winner hash. The commitment
    /// succeeds only when at least `threshold` unique registered operators signed the exact
    /// `(poolId, targetBlock, winner, bidAmount)` tuple.
    /// @dev Reverts if the block is stale, the winner is already committed, or the quorum is not met.
    ///
    /// @param poolId ID of the pool
    /// @param targetBlock Block for which the winner should be set
    /// @param winner Address of the auction winner
    /// @param bidAmount Auction winner bid amount
    /// @param signatures Array of AVS operator signatures over the winner hash
    function commitWinner(
        PoolId poolId,
        uint256 targetBlock,
        address winner,
        uint256 bidAmount,
        bytes[] calldata signatures
    ) external;
}