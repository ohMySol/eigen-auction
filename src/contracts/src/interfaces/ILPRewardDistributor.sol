// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

/// @title ILPRewardsDistributor
/// @author ohMySol
/// @notice Interface that defines the functions for the `LPRewardsDistributor` hook contract
interface ILPRewardsDistributor {
    /// @notice Called by the hook after a winning arbitrage swap to distribute the bid
    /// @param poolId ID of the pool
    function receiveProceeds(PoolId poolId) external payable;

    /// @notice Called by the hook when an LP's liquidity changes
    /// @param poolId ID of the pool
    /// @param lp Liquidity provider address
    /// @param oldLiquidity Previous liquidity amount
    /// @param newLiquidity New liquidity amount
    function updateShares(
        PoolId poolId,
        address lp,
        uint128 oldLiquidity,
        uint128 newLiquidity
    ) external;

    /// @notice Function for LP to pull the accrued rewards
    /// @param poolId ID of the pool
    function claimRewards(PoolId poolId) external;
}