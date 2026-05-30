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
/// @notice Interface that defines the functions for the `AuctionServiceManager` contract
interface IAuctionServiceManager {
    /// @notice Returns the committed auction result for a given pool and block.
    /// @param poolId ID of the pool
    /// @param blockNumber Chain block number
    /// @return AuctionResult structure with auction information
    function getWinner(PoolId poolId, uint256 blockNumber) external view returns (AuctionResult memory);
    
    
    /// @notice Commits the auction winner for a given pool and block. 
    /// Callers supply a bundle of operator signatures over the winner hash.
    /// @param poolId ID of the pool
    /// @param targetBlock Block for which the winner should be set
    /// @param winner Address of the auction winner
    /// @param bidAmount Auction winner bid amount
    /// @param signatures Array of AVS operators signatures
    function commitWinner(
        PoolId poolId, 
        uint256 targetBlock, 
        address winner, 
        uint256 bidAmount, 
        bytes[] calldata signatures
    ) external;
}