// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {EigenAuctionHook} from "../../src/EigenAuctionHook.sol";
import {MockAuctionServiceManager} from "../mocks/MockAuctionServiceManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";
import {ArbHelper} from "../helpers/ArbHelper.sol";

/// @notice Unit tests for the `EigenAuctionHook`.
contract EigenAuctionHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    EigenAuctionHook public hook;
    MockAuctionServiceManager public mockAvs;
    ArbHelper public arbHelper;
    PoolKey public poolKey;
    PoolId public poolId;

    // Fixed reward paid by arb helper per arb in currency0.
    uint256 constant REWARD = 0.001 ether;

    address public lpRouter;

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        mockAvs = new MockAuctionServiceManager();

        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );
        address hookAddress = address(flags);
        deployCodeTo("EigenAuctionHook.sol", abi.encode(address(manager), address(mockAvs), address(this)), hookAddress);
        hook = EigenAuctionHook(payable(hookAddress));

        (poolKey, poolId) = initPool(currency0, currency1, hook, 3000, 60, SQRT_PRICE_1_1);

        lpRouter = address(modifyLiquidityRouter);

        arbHelper = new ArbHelper(manager);
        // Allow arbHelper to pull currency0 (reward + arb input) from address(this).
        MockERC20(Currency.unwrap(currency0)).approve(address(arbHelper), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(arbHelper), type(uint256).max);
    }

    /* HELPERS */

    function _bal(Currency c, address a) internal view returns (uint256) {
        return MockERC20(Currency.unwrap(c)).balanceOf(a);
    }

    function _addLiquidity(int256 delta, bytes32 salt) internal {
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: delta, salt: salt}),
            new bytes(0)
        );
    }

    // Arb swap that pays REWARD of currency0 to LPs and moves price zeroForOne.
    function _arbSwap() internal {
        arbHelper.execute(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this)
        );
    }

    // Hook's currency0 balance — the cumulative reward collected from operators.
    function _skimmed() internal view returns (uint256) {
        return _bal(currency0, address(hook));
    }

    /* TESTS */

    function test_SoleLP_Earns_Whole_Reward_In_Currency0() public {
        _addLiquidity(1e18, bytes32(0));
        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = _skimmed();
        assertEq(reward, REWARD);

        uint256 amount = hook.earned(poolKey, lpRouter, -600, 600, bytes32(0));
        assertApproxEqAbs(amount, reward, 2);
    }

    function test_Reward_Splits_Proportionally_Between_Two_LPs() public {
        _addLiquidity(1e18, bytes32(0));
        _addLiquidity(3e18, bytes32(uint256(1)));

        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = _skimmed();
        uint256 a  = hook.earned(poolKey, lpRouter, -600, 600, bytes32(0));
        uint256 aB = hook.earned(poolKey, lpRouter, -600, 600, bytes32(uint256(1)));

        assertApproxEqAbs(a,  reward / 4,      2);
        assertApproxEqAbs(aB, (reward * 3) / 4, 2);
    }

    function test_OutOfRange_LP_Earns_Nothing() public {
        _addLiquidity(1e18, bytes32(0));

        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: 1200, tickUpper: 1800, liquidityDelta: 5e18, salt: bytes32(uint256(2))}),
            new bytes(0)
        );

        vm.roll(block.number + 1);
        _arbSwap();

        uint256 out = hook.earned(poolKey, lpRouter, 1200, 1800, bytes32(uint256(2)));
        assertEq(out, 0);

        uint256 inRange = hook.earned(poolKey, lpRouter, -600, 600, bytes32(0));
        assertApproxEqAbs(inRange, _skimmed(), 2);
    }

    function test_RemoveLiquidity_Pays_Rewards_To_LP() public {
        _addLiquidity(1e18, bytes32(0));
        vm.roll(block.number + 1);
        _arbSwap();
        uint256 reward = _skimmed();

        uint256 before = _bal(currency0, lpRouter);
        // Removing triggers automatic reward payment — no separate claim step needed.
        _addLiquidity(-1e18, bytes32(0));
        assertApproxEqAbs(_bal(currency0, lpRouter) - before, reward, 2);

        // Nothing left after remove.
        assertEq(hook.earned(poolKey, lpRouter, -600, 600, bytes32(0)), 0);
    }

    /// @notice JIT detection: arb with a stale expectedLiquidity (before a JIT add) reverts.
    function test_JIT_Detection_Reverts_When_Liquidity_Changed() public {
        _addLiquidity(1e18, bytes32(0));
        vm.roll(block.number + 1);

        // Snapshot pre-JIT liquidity.
        uint256 preLiq = manager.getLiquidity(poolId);

        // JIT add changes pool liquidity after the snapshot.
        _addLiquidity(5e18, bytes32(uint256(7)));

        // Arb with the stale expectedLiquidity should revert. V4 wraps the hook's inner revert
        // in a FailedHookCall, so we check for a generic revert rather than the specific selector.
        vm.expectRevert();
        arbHelper.executeWithLiqOverride(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this),
            preLiq
        );
    }

    /// @notice An arb with rewardAmount=0 and old-format hookData still works (no reward, no JIT check).
    function test_ZeroReward_Arb_Passes_Without_Reward() public {
        _addLiquidity(1e18, bytes32(0));
        vm.roll(block.number + 1);

        // Old-format hookData: abi.encode(true) = 32 bytes, rewardAmount and expectedLiquidity default to 0.
        swapRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            abi.encode(true)
        );

        // No reward distributed.
        assertEq(_skimmed(), 0);
        assertEq(hook.earned(poolKey, lpRouter, -600, 600, bytes32(0)), 0);
    }

    function test_NonSettlerSwap_Reverts_When_Settler_Set() public {
        hook.setSettler(address(0xBEEF));

        vm.expectRevert();
        swapRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            new bytes(0)
        );
    }

    function test_Swap_Passes_After_Fallback_Period_Elapses() public {
        hook.setSettler(address(0xBEEF));
        vm.roll(block.number + ConstantsLib.FALLBACK_PERIOD + 1);

        _addLiquidity(1e18, bytes32(0));
        swapRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            new bytes(0)
        );
    }

    function test_NormalSwap_Passes_Through() public {
        _addLiquidity(1e18, bytes32(0));
        swapRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            new bytes(0)
        );
        assertEq(_skimmed(), 0);
    }
}
