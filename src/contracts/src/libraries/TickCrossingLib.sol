// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickBitmap} from "v4-core/libraries/TickBitmap.sol";
import {BitMath} from "v4-core/libraries/BitMath.sol";

import {PoolRewards} from "../types/PoolRewards.sol";

/// @title TickCrossingLib
/// @author ohMySol
/// @notice Flips per-tick reward-growth-outside accumulators for every initialized tick an arb swap
/// crossed, by walking Uniswap V4's own tick bitmap.
/// @dev This replaces an earlier design that iterated a hook-maintained append-only list of every
/// tick ever used as a position boundary — that list was unbounded and would eventually make
/// settlement exceed the block gas limit. Here we read V4's stored bitmap (`getTickBitmap`) and
/// visit only the *initialized* ticks inside the crossed range, so cost is O(ticks crossed), not
/// O(all ticks ever registered). Mirrors the logic Uniswap performs internally during a swap.
library TickCrossingLib {
    using StateLibrary for IPoolManager;

    /// @dev Crossing context bundled into one memory slot to stay within the stack limit.
    /// @param tickSpacing The pool tick spacing
    /// @param lower exclusive bound of the crossed span
    /// @param higher inclusive bound of the crossed span
    /// @param growthGlobalX128 pre-reward global accumulator the flip is taken against
    struct Ctx {
        int24 tickSpacing;
        int24 lower;
        int24 higher;
        uint256 growthGlobalX128;
    }

    /// @notice Flips `tickGrowthOutside[t] = growthGlobalX128 - tickGrowthOutside[t]` for every
    /// initialized tick `t` the swap crossed (the half-open span `(lower, higher]` between
    /// `priorTick` and `newTick`).
    /// @dev MUST be called before the swap's reward is folded into `growthGlobalX128`, so flips are
    /// taken relative to the pre-reward accumulator (V3 fee-growth-outside convention).
    ///
    /// V4 keeps initialized ticks in a bitmap: `mapping(int16 wordPos => uint256)`, where each "word"
    /// is 256 bits covering 256 consecutive compressed-tick slots and a set bit marks an initialized
    /// tick. `TickBitmap.position(compressedTick)` returns `(wordPos, bitPos)` — which word, and which
    /// bit inside it. We therefore scan from the word holding `lower` to the word holding `higher`.
    /// @param self The pool's reward accumulator whose outside values are flipped.
    /// @param poolManager The V4 pool manager, read for the pool's tick bitmap words.
    /// @param poolId The pool whose bitmap is walked.
    /// @param tickSpacing The pool's tick spacing.
    /// @param priorTick Pool tick snapshotted before the swap.
    /// @param newTick Pool tick after the swap.
    function crossTicks(
        PoolRewards storage self,
        IPoolManager poolManager,
        PoolId poolId,
        int24 tickSpacing,
        int24 priorTick,
        int24 newTick
    ) internal {
        if (priorTick == newTick) return;

        Ctx memory ctx;
        ctx.tickSpacing = tickSpacing;
        ctx.growthGlobalX128 = self.growthGlobalX128;
        // Half-open span (lower, higher]: exclusive of the lower bound, inclusive of the upper.
        (ctx.lower, ctx.higher) = newTick < priorTick
            ? (newTick, priorTick)
            : (priorTick, newTick);

        // Bitmap word index containing each end of the crossed span.
        (int16 lowerWordPos,) = TickBitmap.position(TickBitmap.compress(ctx.lower, tickSpacing));
        (int16 upperWordPos,) = TickBitmap.position(TickBitmap.compress(ctx.higher, tickSpacing));

        for (int16 wordPos = lowerWordPos; wordPos <= upperWordPos; ++wordPos) {
            _flipWord(self, ctx, wordPos, poolManager.getTickBitmap(poolId, wordPos));
        }
    }

    /// @dev Flips every set bit of one bitmap word whose tick lies in the crossed half-open span.
    /// @param self The pool's reward accumulator whose outside values are flipped.
    /// @param ctx The crossing context (tick spacing, span bounds, pre-reward global accumulator).
    /// @param wordPos Bitmap word index being scanned.
    /// @param bitmap The 256-bit bitmap word at `wordPos`; each set bit is an initialized tick.
    function _flipWord(PoolRewards storage self, Ctx memory ctx, int16 wordPos, uint256 bitmap) private {
        while (bitmap != 0) {
            uint8 bitPos = BitMath.leastSignificantBit(bitmap);
            bitmap &= bitmap - 1; // clear the consumed bit so the loop terminates

            // Reconstruct the real (uncompressed) tick this (wordPos, bitPos) pair represents.
            int24 tick = (int24(wordPos) * 256 + int24(uint24(bitPos))) * ctx.tickSpacing;
            if (tick > ctx.lower && tick <= ctx.higher) {
                unchecked {
                    self.tickGrowthOutside[tick] = ctx.growthGlobalX128 - self.tickGrowthOutside[tick];
                }
            }
        }
    }
}
