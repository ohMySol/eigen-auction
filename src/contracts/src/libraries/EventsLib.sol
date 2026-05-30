// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

/// @title EventsLib
/// @author @ohMySol
/// @notice A library that defines the events for EigenAuction Hook smart contract system
library EventsLib {
    /* AuctionServiceManager Events  */
    
    /// @notice Emitted when `AuctionServiceManager` received an auction winner
    /// @param poolId ID of the pool
    /// @param targetBlock Block where the winner was commited
    /// @param winner Address of the auction winner
    /// @param bidAmount Amount of the winner bid
    event WinnerCommitted(
        PoolId indexed poolId,
        uint256 indexed targetBlock,
        address indexed winner,
        uint256 bidAmount
    );

    /* LPRewardDistributor Events  */

    /// @notice Emitted when the winning arbitrage bid is distributed
    /// @param poolId ID of the pool
    /// @param amount Amount of reward
    event RewardsReceived(PoolId indexed poolId, uint256 amount);

    /// @notice Emitted when LPs claim their rewards
    /// @param poolId ID of the pool
    /// @param lp Liquidity provider address
    /// @param amount Rewards amount
    event RewardsClaimed(PoolId indexed poolId, address indexed lp, uint256 amount);

}