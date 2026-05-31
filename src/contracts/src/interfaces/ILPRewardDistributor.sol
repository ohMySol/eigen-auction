// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

/// @title ILPRewardsDistributor
/// @author ohMySol
/// @notice Interface that defines the functions for the `LPRewardsDistributor` hook contract
interface ILPRewardDistributor {
    /// @notice The hook contract that is authorised to call state-mutating functions on this distributor.
    /// Set once at construction.
    function hook() external view returns (address);

    /// @notice Mapping: poolId => accumulated reward per unit of liquidity, scaled by 1e18.
    /// @dev Increases each time a bid is received. Used together with `rewardDebt` to compute an LP's unclaimed earnings.
    /// 
    /// @param poolId ID of the pool
    /// @return Reward-per-share accumulator for the pool
    function rewardPerShareStored(PoolId poolId) external view returns (uint256);

    /// @notice Mapping: poolId => sum of all LP liquidity currently tracked in this distributor.
    /// @dev Updated on every `updateShares` call. Used as the denominator when distributing a bid.
    /// 
    /// @param poolId ID of the pool
    /// @return Total liquidity across all LPs for the pool
    function totalLiquidity(PoolId poolId) external view returns (uint256);

    /// @notice Mapping: poolId => lp => liquidity amount last recorded for this LP.
    /// @dev Kept in sync by the hook via `updateShares` on every add/remove liquidity event.
    ///
    /// @param poolId ID of the pool
    /// @param lp Address of the liquidity provider
    /// @return LP's current liquidity share tracked by this distributor
    function lpLiquidity(PoolId poolId, address lp) external view returns (uint128);

    /// @notice Mapping: poolId => lp => snapshot of `rewardPerShareStored` at the LP's last settlement.
    /// Without this last settlement traction, every time `rewardPerShareStored` grows, all LPs would earn 
    /// from the beginning — including rewards that existed before they joined. Only earnings after the last settlement are paid out.
    /// @dev Earnings are computed as: lpLiquidity * (rewardPerShareStored - rewardDebt) / 1e18.
    /// 
    /// @param poolId ID of the pool
    /// @param lp Address of the liquidity provider
    /// @return rewardPerShare value at the time the LP was last settled
    function rewardDebt(PoolId poolId, address lp) external view returns (uint256);

    /// @notice Mapping: poolId => lp => settled rewards waiting to be claimed.
    /// @dev Accumulates each time `updateShares` or `claimRewards` triggers a settlement.
    /// Transferred to the LP on `claimRewards`.
    /// 
    /// @param poolId ID of the pool
    /// @param lp Address of the liquidity provider
    /// @return ETH amount (in wei) the LP can claim right now
    function pendingRewards(PoolId poolId, address lp) external view returns (uint256);

    /// @notice Receives the winning arbitrage bid and distributes it proportionally across all LPs.
    /// @dev Increments `rewardPerShareStored` by `msg.value / totalLiquidity`.
    /// No-ops silently when `totalLiquidity` is zero to avoid revert on empty pools.
    /// Restricted to `hook`. Reverts with `OnlyHook` if called by any other address.
    /// 
    /// @param poolId ID of the pool whose LPs receive the bid
    function receiveArbitrageFee(PoolId poolId) external payable;

    /// @notice Settles pending rewards for `lp` and updates their tracked liquidity share.
    /// @dev Must be called by the hook on every `afterAddLiquidity` and `afterRemoveLiquidity` event.
    /// Restricted to `hook`. Reverts with `OnlyHook` if called by any other address.
    /// 
    /// @param poolId ID of the pool
    /// @param lp Address of the liquidity provider whose share is changing
    /// @param oldLiquidity LP's liquidity amount before the change
    /// @param newLiquidity LP's liquidity amount after the change
    function updateShares(
        PoolId poolId,
        address lp,
        uint128 oldLiquidity,
        uint128 newLiquidity
    ) external;

    /// @notice Settles and transfers all accrued ETH rewards to `msg.sender`.
    /// Reverts when there is nothing to claim.
    /// @param poolId ID of the pool to claim rewards from
    function claimRewards(PoolId poolId) external;
}