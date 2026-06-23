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

    /// @notice Returns the reward growth (X128) that accrued inside the tick range
    /// `[tickLower, tickUpper]` relative to the current pool tick.
    /// @param self The pool's reward accumulator.
    /// @param currentTick The pool's current tick.
    /// @param tickLower Lower tick of the position's range.
    /// @param tickUpper Upper tick of the position's range.
    /// @return Reward growth inside the range (X128 fixed point).
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

    /// @notice Seeds the outside accumulator for a tick the first time it becomes a position
    /// boundary. Follows Uniswap's convention: if the current price is at or above the tick, all
    /// historical growth is treated as lying "below" it, so the outside value is seeded to the
    /// global accumulator. Ticks already initialized in V4 (gross liquidity > 0) are left untouched.
    /// @dev Call this for both boundaries *before* adding the liquidity that initializes them.
    /// @param self The pool's reward accumulator.
    /// @param poolManager V4 pool manager, used to check whether the tick already has gross liquidity.
    /// @param poolId Pool whose tick state is checked.
    /// @param tick The tick boundary being initialized.
    /// @param currentTick The pool's current tick at the time of the LP add.
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

    /// @notice Records the pool tick just before a swap so `crossTicks` can later identify which
    /// boundaries the swap crossed.
    /// @param self The pool's reward accumulator.
    /// @param tick The current pool tick, read in `_beforeSwap`.
    function snapshotTick(PoolRewards storage self, int24 tick) internal {
        self.priorTick = tick;
    }

    /// @notice Flips the outside accumulator for every initialized tick the last swap crossed,
    /// walking from the snapshotted `priorTick` to `newTick`.
    /// @dev MUST run before any reward for that swap is folded, so flips are taken relative to the
    /// pre-reward global accumulator (V3 convention). Safe to call on swaps that add no reward — the
    /// flip of an unchanged global keeps the inside/outside bookkeeping consistent as price moves.
    /// @param self The pool's reward accumulator whose outside values are updated.
    /// @param poolManager V4 pool manager, used to read tick bitmap words.
    /// @param poolId Pool whose ticks are being processed.
    /// @param tickSpacing The pool's tick spacing.
    /// @param newTick The tick the pool landed on after the swap.
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

    /// @notice Adds `amount` of currency0 reward to the pool-wide growth accumulator, spread evenly
    /// across the currently active liquidity. No-op when `amount` is zero or no liquidity is active.
    /// @dev Call after `crossTicks` so the reward accrues only to positions in range at the current
    /// (post-swap) tick.
    /// @param self The pool's reward accumulator.
    /// @param amount Reward in currency0 to distribute.
    /// @param poolLiquidity Currently active liquidity units to spread the reward across.
    function fold(PoolRewards storage self, uint256 amount, uint128 poolLiquidity) internal {
        if (amount == 0 || poolLiquidity == 0) return;
        unchecked {
            self.growthGlobalX128 += FullMath.mulDiv(amount, FixedPoint128.Q128, poolLiquidity);
        }
    }
}
