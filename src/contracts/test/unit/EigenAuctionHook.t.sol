// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
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

/// @notice Unit tests for `EigenAuctionHook` access control, JIT guard, and reward distribution.
/// LP reward splitting and removal are covered in EigenAuctionHookLP.t.sol.
contract EigenAuctionHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    EigenAuctionHook public hook;
    MockAuctionServiceManager public mockAvs;
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

        mockAvs = new MockAuctionServiceManager();

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        address hookAddress = address(flags);
        deployCodeTo("EigenAuctionHook.sol", abi.encode(address(manager), address(mockAvs), address(this)), hookAddress);
        hook = EigenAuctionHook(payable(hookAddress));

        (poolKey, poolId) = initPool(currency0, currency1, hook, 3000, 60, SQRT_PRICE_1_1);

        arbHelper = new ArbHelper(manager);
        hook.setSettler(address(arbHelper));

        // Reward + arb input come from the test contract.
        MockERC20(Currency.unwrap(currency0)).approve(address(arbHelper), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(arbHelper), type(uint256).max);

        // Seed an in-range LP through the hook so it is reward-tracked.
        MockERC20(Currency.unwrap(currency0)).mint(lp, 1_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(lp, 1_000e18);
        vm.startPrank(lp);
        MockERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        vm.stopPrank();
    }

    function _bal(Currency c, address a) internal view returns (uint256) {
        return MockERC20(Currency.unwrap(c)).balanceOf(a);
    }

    function _addLp(uint128 liq) internal {
        vm.prank(lp);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, liq);
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
        assertApproxEqAbs(hook.earned(poolKey, lp, TICK_LOWER, TICK_UPPER, bytes32(0)), REWARD, 2);
    }

    function test_ClaimRewards_Pays_Without_Removing() public {
        _addLp(1e18);
        vm.roll(block.number + 1);
        _arbSwap();

        uint256 before = _bal(currency0, lp);
        vm.prank(lp);
        hook.claimRewards(poolKey, TICK_LOWER, TICK_UPPER);
        assertApproxEqAbs(_bal(currency0, lp) - before, REWARD, 2);
        assertEq(hook.earned(poolKey, lp, TICK_LOWER, TICK_UPPER, bytes32(0)), 0);
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
        assertEq(hook.earned(poolKey, lp, TICK_LOWER, TICK_UPPER, bytes32(0)), 0);
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
