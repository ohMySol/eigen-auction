// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";

import {PoolRewards} from "../types/PoolRewards.sol";
import {RewardGrowthLib} from "./RewardGrowthLib.sol";
import {TickCrossingLib} from "./TickCrossingLib.sol";

/// @title PoolRewardsLib
/// @author ohMySol
/// @notice Stateful reward-accounting operations over a `PoolRewards` accumulator. 
/// The hook delegates all reward bookkeeping here instead of holding storage mappings. Rewards are always in currency0.
library PoolRewardsLib {
    using StateLibrary for IPoolManager;

    /// @notice Reward growth (X128) accumulated inside `[tickLower, tickUpper]` at `currentTick`.
    function getGrowthInside(
        PoolRewards storage self,
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256) {
        return RewardGrowthLib.growthInside(
            currentTick,
            tickLower,
            tickUpper,
            self.growthGlobalX128,
            self.tickGrowthOutside[tickLower],
            self.tickGrowthOutside[tickUpper]
        );
    }

    /// @notice Initializes a tick's outside accumulator the first time it becomes a position
    /// boundary, following Uniswap's convention: if the current price is at or above the tick, all
    /// historical growth is considered to lie "below" it, so its outside value seeds to the global
    /// accumulator. Ticks already initialized in V4 (gross liquidity > 0) are left untouched.
    /// @dev Call this for both boundaries *before* adding the liquidity that initializes them.
    function initializeBoundary(
        PoolRewards storage self,
        IPoolManager poolManager,
        PoolId poolId,
        int24 tick,
        int24 currentTick
    ) internal {
        (uint128 grossLiquidity,) = poolManager.getTickLiquidity(poolId, tick);
        if (grossLiquidity != 0) return; // already an active boundary; outside value already seeded
        if (currentTick >= tick) {
            self.tickGrowthOutside[tick] = self.growthGlobalX128;
        }
    }

    /// @notice Snapshots the pool tick before a swap so `crossTicks` can flip the boundaries the
    /// swap crosses.
    function snapshotTick(PoolRewards storage self, int24 tick) internal {
        self.priorTick = tick;
    }

    /// @notice Flips the outside accumulator for every initialized tick the last swap crossed,
    /// walking from the snapshotted `priorTick` to `newTick`.
    /// @dev MUST run before any reward for that swap is folded, so flips are taken relative to the
    /// pre-reward global accumulator (V3 convention). Safe to call on swaps that add no reward — the
    /// flip of an unchanged global keeps the inside/outside bookkeeping consistent as price moves.
    function crossTicks(
        PoolRewards storage self,
        IPoolManager poolManager,
        PoolId poolId,
        int24 tickSpacing,
        int24 newTick
    ) internal {
        TickCrossingLib.crossTicks(
            self,
            poolManager, 
            poolId, 
            tickSpacing, 
            self.priorTick, 
            newTick
        );
    }

    /// @notice Folds `amount` of currency0 reward into the global accumulator, spread across the
    /// currently active liquidity. No-op when there is nothing to distribute or no active liquidity.
    /// @dev Call after `crossTicks` so the reward accrues only to positions in range at the current
    /// (post-swap) tick.
    /// @param amount Reward in currency0.
    /// @param poolLiquidity Active liquidity to spread the reward across.
    function fold(PoolRewards storage self, uint256 amount, uint128 poolLiquidity) internal {
        if (amount == 0 || poolLiquidity == 0) return;
        unchecked {
            self.growthGlobalX128 += FullMath.mulDiv(amount, FixedPoint128.Q128, poolLiquidity);
        }
    }
}
