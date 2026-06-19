// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolRewardsLib} from "../libraries/PoolRewardsLib.sol";

using PoolRewardsLib for PoolRewards global;

/// @notice Per-pool reward accumulator, modelled on Uniswap V3's fee-growth bookkeeping. Rewards are
/// always denominated in currency0. A position's earned reward is the growth that accrued "inside" its
/// range since it last checkpointed, multiplied by its liquidity.
/// @param growthGlobalX128 Pool-wide cumulative reward growth per unit of liquidity, X128 fixed point.
/// @param tickGrowthOutside Per-tick reward growth recorded "outside" the tick (X128). Seeded when a
/// tick first becomes a position boundary and flipped each time an arb swap crosses it.
/// @param priorTick Pool tick snapshotted in `_beforeSwap`, used by `crossTicks` to know which ticks
/// the most recent swap traversed.
struct PoolRewards {
    uint256 growthGlobalX128;
    mapping(int24 => uint256) tickGrowthOutside;
    int24 priorTick;
}