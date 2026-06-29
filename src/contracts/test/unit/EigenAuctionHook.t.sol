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
import {MockEigenAuctionServiceManager} from "../mocks/MockEigenAuctionServiceManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";
import {ArbHelper} from "../helpers/ArbHelper.sol";

/// @notice Unit tests for `EigenAuctionHook` access control, JIT guard, and reward distribution.
/// LP reward splitting and removal are covered in EigenAuctionHookLP.t.sol.
contract EigenAuctionHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    EigenAuctionHook public hook;
    MockEigenAuctionServiceManager public mockAvs;
    ArbHelper public arbHelper;
    PoolKey public poolKey;
    PoolId public poolId;

    uint256 constant REWARD = 0.001 ether;
    int24 constant TICK_LOWER = -600;
    int24 constant TICK_UPPER = 600;

    address lp = makeAddr("lp");

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        mockAvs = new MockEigenAuctionServiceManager();

        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
                | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        address hookAddress = address(flags);
        deployCodeTo("EigenAuctionHook.sol", abi.encode(address(manager), address(mockAvs), address(this)), hookAddress);
        hook = EigenAuctionHook(payable(hookAddress));

        (poolKey, poolId) = initPool(currency0, currency1, hook, 3000, 60, SQRT_PRICE_1_1);

        arbHelper = new ArbHelper(manager);
        hook.setSettler(address(arbHelper));

        // Reward + arb input come from the test contract.
        MockERC20(Currency.unwrap(currency0)).approve(address(arbHelper), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(arbHelper), type(uint256).max);

        // The LP supplies through the standard V4 router; the hook attributes the position to the
        // router (the owner V4 sees), so reward queries use `address(modifyLiquidityRouter)`.
        MockERC20(Currency.unwrap(currency0)).mint(lp, 1_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(lp, 1_000e18);
        vm.startPrank(lp);
        MockERC20(Currency.unwrap(currency0)).approve(address(modifyLiquidityRouter), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(modifyLiquidityRouter), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev Position owner as the hook sees it — the router that opened the position.
    function _lpOwner() internal view returns (address) {
        return address(modifyLiquidityRouter);
    }

    function _bal(Currency c, address a) internal view returns (uint256) {
        return MockERC20(Currency.unwrap(c)).balanceOf(a);
    }

    function _addLp(uint128 liq) internal {
        vm.prank(lp);
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                liquidityDelta: int256(uint256(liq)),
                salt: bytes32(0)
            }),
            ""
        );
    }

    function _arbSwap() internal {
        arbHelper.execute(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this)
        );
    }

    /* REWARD */

    function test_SoleLP_Earns_Whole_Reward_In_Currency0() public {
        _addLp(1e18);
        vm.roll(block.number + 1);
        _arbSwap();

        assertEq(_bal(currency0, address(hook)), REWARD);
        assertApproxEqAbs(hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0)), REWARD, 2);
    }

    /// @notice A zero-liquidity removal collects accrued rewards without exiting the position. The LVR
    /// reward rides out as the hook's currency0 delta; V4 also settles the position's accrued swap fees
    /// in the same poke, so the LP's currency0 gain is at least the reward.
    function test_ZeroLiquidityRemove_Collects_Rewards_In_Place() public {
        _addLp(1e18);
        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0));
        assertApproxEqAbs(reward, REWARD, 2);

        uint256 before = _bal(currency0, lp);
        vm.prank(lp);
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: 0, salt: bytes32(0)}),
            ""
        );
        // Reward (plus any accrued swap fees) is paid out; the LVR reward leaves the hook.
        assertGe(_bal(currency0, lp) - before, reward, "LP did not receive the reward");
        assertApproxEqAbs(_bal(currency0, address(hook)), 0, 1, "reward left the hook");
        assertEq(hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0)), 0);
        // Position is intact — liquidity unchanged.
        assertEq(hook.positionLiquidity(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0)), 1e18);
    }

    /* JIT GUARD */

    function test_JIT_Detection_Reverts_When_Liquidity_Changed() public {
        _addLp(1e18);
        vm.roll(block.number + 1);

        uint256 preLiq = manager.getLiquidity(poolId);
        _addLp(5e18); // JIT add changes liquidity after the operator's snapshot

        vm.expectRevert();
        arbHelper.executeWithLiqOverride(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this),
            preLiq
        );
    }

    function test_ZeroReward_Arb_CrossesWithoutReward() public {
        _addLp(1e18);
        vm.roll(block.number + 1);

        arbHelper.execute(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            0,
            address(this)
        );

        assertEq(_bal(currency0, address(hook)), 0);
        assertEq(hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0)), 0);
    }

    /* ACCESS CONTROL */

    function test_NonSettlerSwap_Reverts_When_Settler_Set() public {
        _addLp(1e18);
        vm.expectRevert();
        swapRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            new bytes(0)
        );
    }

    function test_Swap_Passes_After_Fallback_Period_Elapses() public {
        _addLp(1e18);
        vm.roll(block.number + ConstantsLib.FALLBACK_PERIOD + 1);
        swapRouter.swap(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            new bytes(0)
        );
    }
}
