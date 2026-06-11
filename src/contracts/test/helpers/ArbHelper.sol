// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

interface IERC20Min {
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @dev Test helper that executes an arb swap following the same pre-funding pattern as Settler:
/// deposits `rewardAmount` of currency0 into the pool manager before the swap, passes the current
/// pool liquidity as `expectedLiquidity` in hookData (or an override for JIT tests), and settles
/// all swap deltas against `caller`.
contract ArbHelper is IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    IPoolManager immutable pm;

    constructor(IPoolManager _pm) { pm = _pm; }

    /// @param key Pool to swap against.
    /// @param params Swap parameters.
    /// @param rewardAmount Currency0 reward to pre-fund. Pulled from `caller` via transferFrom.
    /// @param caller Address that pays the reward and the arb input, and receives the arb output.
    function execute(
        PoolKey calldata key,
        SwapParams calldata params,
        uint256 rewardAmount,
        address caller
    ) external {
        pm.unlock(abi.encode(caller, key, params, rewardAmount, uint256(0)));
    }

    /// @dev Same as `execute` but uses `overrideExpectedLiq` instead of reading pool liquidity.
    /// Pass a stale value to simulate a JIT liquidity change for testing the hook's JIT guard.
    function executeWithLiqOverride(
        PoolKey calldata key,
        SwapParams calldata params,
        uint256 rewardAmount,
        address caller,
        uint256 overrideExpectedLiq
    ) external {
        pm.unlock(abi.encode(caller, key, params, rewardAmount, overrideExpectedLiq));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        (address caller, PoolKey memory key, SwapParams memory params, uint256 rewardAmount, uint256 liqOverride) =
            abi.decode(data, (address, PoolKey, SwapParams, uint256, uint256));

        // Transfer reward directly to the hook (outside V4 flash accounting) so the hook can
        // update its accumulator in afterSwap without leaving unsettled PM deltas.
        if (rewardAmount > 0) {
            IERC20Min(Currency.unwrap(key.currency0)).transferFrom(caller, address(key.hooks), rewardAmount);
        }

        uint256 expectedLiq = liqOverride > 0 ? liqOverride : pm.getLiquidity(key.toId());

        BalanceDelta delta = pm.swap(key, params, abi.encode(true, rewardAmount, expectedLiq));

        // Settle arb swap deltas against caller.
        int128 d0 = delta.amount0();
        int128 d1 = delta.amount1();
        if (d0 < 0) {
            pm.sync(key.currency0);
            IERC20Min(Currency.unwrap(key.currency0)).transferFrom(caller, address(pm), uint256(-int256(d0)));
            pm.settle();
        } else if (d0 > 0) {
            pm.take(key.currency0, caller, uint256(int256(d0)));
        }
        if (d1 < 0) {
            pm.sync(key.currency1);
            IERC20Min(Currency.unwrap(key.currency1)).transferFrom(caller, address(pm), uint256(-int256(d1)));
            pm.settle();
        } else if (d1 > 0) {
            pm.take(key.currency1, caller, uint256(int256(d1)));
        }

        return "";
    }
}
