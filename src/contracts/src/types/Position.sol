// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";
import {RewardGrowthLib} from "../libraries/RewardGrowthLib.sol";

using PositionLib for Position global;

/// @notice Per-position reward bookkeeping. Rewards are always denominated in currency0.
/// @dev Every time rewards are distributed to a pool, the global growth accumulator (growthGlobalX128) ticks up.
/// Each position only records a checkpoint `lastGrowthInsideX128` — the value of that accumulator the last time someone looked at that position.
/// To know what a position earned, we subtract the old checkpoint from the current accumulator and multiply by the position's liquidity.
/// @param liquidity Mature, reward-eligible liquidity.
/// @param lastGrowthInsideX128 Inside-growth checkpoint for `liquidity` (currency0 only).
/// @param owed Settled-but-unclaimed reward balance in currency0.
struct Position {
    uint128 liquidity;
    uint256 lastGrowthInsideX128;
    uint256 owed;
}

/// @title PositionLib
/// @author ohMySol
/// @dev Bookkeeping helpers attached to `Position`.
library PositionLib {
    /// @dev Returns the storage key used to look up a position. The key uniquely identifies a
    /// position by combining all the coordinates that distinguish it.
    /// @param poolId The pool this position belongs to.
    /// @param owner The address that owns this position.
    /// @param tickLower Lower tick of the position's price range.
    /// @param tickUpper Upper tick of the position's price range.
    /// @param salt Extra differentiator so the same address can hold multiple positions in the same range.
    /// @return keccak256 hash used as the mapping key in `_positions`.
    function positionKey(
        PoolId poolId,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            PoolId.unwrap(poolId), 
            owner, 
            tickLower, 
            tickUpper, 
            salt
        ));
    }

    /// @dev Adds the rewards earned since the last checkpoint to `owed` and advances the checkpoint
    /// to the current inside growth value. Must be called before any liquidity change.
    /// @param self The position to update.
    /// @param insideX128 Current reward growth inside the position's tick range (X128 fixed point).
    function settlePosition(Position storage self, uint256 insideX128) internal {
        unchecked {
            self.owed += RewardGrowthLib.rewardsOf(insideX128, self.lastGrowthInsideX128, self.liquidity);
        }
        self.lastGrowthInsideX128 = insideX128;
    }

    /// @dev Applies a signed liquidity change to the position. Positive values add liquidity,
    /// negative values remove it. Liquidity is clamped at zero on removal to avoid underflow.
    /// @param self The position to update.
    /// @param liquidityDelta Positive to add liquidity units, negative to remove them.
    function applyLiquidity(Position storage self, int256 liquidityDelta) internal {
        if (liquidityDelta > 0) {
            self.liquidity += uint128(uint256(liquidityDelta));
        } else if (liquidityDelta < 0) {
            uint128 dec = uint128(uint256(-liquidityDelta));
            self.liquidity = self.liquidity >= dec ? self.liquidity - dec : 0;
        }
    }
}