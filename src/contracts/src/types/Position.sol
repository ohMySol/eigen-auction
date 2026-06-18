// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice Per-position reward bookkeeping. Rewards are always denominated in currency0.
/// @param liquidity Mature, reward-eligible liquidity.
/// @param lastGrowthInsideX128 Inside-growth checkpoint for `liquidity` (currency0 only).
/// @param owed Settled-but-unclaimed reward balance in currency0.
struct Position {
    uint128 liquidity;
    uint256 lastGrowthInsideX128;
    uint256 owed;
}

/// @notice Payload passed through `poolManager.unlock` for an LP add/remove routed through the hook.
/// @param key The pool being modified.
/// @param lp The liquidity provider that owns the position.
/// @param tickLower Lower tick of the position's range.
/// @param tickUpper Upper tick of the position's range.
/// @param liquidityDelta Signed liquidity change applied to the position.
struct LiquidityCallback {
    PoolKey key;
    address lp;
    int24 tickLower;
    int24 tickUpper;
    int256 liquidityDelta;
}