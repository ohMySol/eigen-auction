// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {EigenAuctionHook} from "../../src/EigenAuctionHook.sol";
import {MockAuctionServiceManager} from "../mocks/MockAuctionServiceManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {ArbHelper} from "../helpers/ArbHelper.sol";

/// @notice Tests for the hook's own LP entry point — Angstrom-style in-hook liquidity.
contract EigenAuctionHookLPTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

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

        MockERC20(Currency.unwrap(currency0)).mint(lp, 1_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(lp, 1_000e18);
        vm.startPrank(lp);
        MockERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        vm.stopPrank();

        arbHelper = new ArbHelper(manager);
        // The arb helper acts as the hook's settler so its swaps and distributeReward succeed.
        hook.setSettler(address(arbHelper));
        // address(this) (the test) pays rewards and arb inputs.
        MockERC20(Currency.unwrap(currency0)).approve(address(arbHelper), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(arbHelper), type(uint256).max);
    }

    /* HELPERS */

    function _bal(Currency c, address a) internal view returns (uint256) {
        return MockERC20(Currency.unwrap(c)).balanceOf(a);
    }

    function _arbSwap() internal {
        arbHelper.execute(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -0.01 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this)
        );
    }

    /* TESTS */

    /// @notice End-to-end LP path: supply via hook, mature, get arbed, then remove to collect rewards.
    function test_InHookLP_Add_Earn_Remove() public {
        vm.prank(lp);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 1e18);

        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = _bal(currency0, address(hook));
        assertEq(reward, REWARD);

        uint256 earned = hook.earned(poolKey, lp, TICK_LOWER, TICK_UPPER, bytes32(0));
        assertApproxEqAbs(earned, reward, 2);

        // Removing pays rewards automatically. Verify the hook's reward balance is drained and
        // earned() returns 0 (principal repayment also flows to the LP, so we don't assert the
        // exact LP balance delta — that would conflate reward with principal).
        vm.prank(lp);
        hook.removeLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 1e18);
        assertApproxEqAbs(_bal(currency0, address(hook)), 0, 1, "hook reward balance drained on remove");
        assertEq(hook.earned(poolKey, lp, TICK_LOWER, TICK_UPPER, bytes32(0)), 0, "nothing left after remove");
    }

    /// @notice Two in-hook LPs split the reward by liquidity share.
    function test_InHookLP_TwoLPs_SplitByShare() public {
        address lp2 = makeAddr("lp2");
        MockERC20(Currency.unwrap(currency0)).mint(lp2, 1_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(lp2, 1_000e18);
        vm.startPrank(lp2);
        MockERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        vm.stopPrank();

        vm.prank(lp);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 0.25e18);
        vm.prank(lp2);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 0.75e18);

        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = _bal(currency0, address(hook));
        assertGt(reward, 1000);

        uint256 a1  = hook.earned(poolKey, lp,  TICK_LOWER, TICK_UPPER, bytes32(0));
        uint256 a1b = hook.earned(poolKey, lp2, TICK_LOWER, TICK_UPPER, bytes32(0));

        assertApproxEqAbs(a1,  reward / 4,      2);
        assertApproxEqAbs(a1b, (reward * 3) / 4, 2);
    }

    /// @notice Removing returns principal; rewards remain claimable.
    function test_InHookLP_Remove_Returns_Principal() public {
        vm.prank(lp);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 1e18);

        uint256 c0Before = _bal(currency0, lp);
        uint256 c1Before = _bal(currency1, lp);

        vm.prank(lp);
        hook.removeLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 1e18);

        assertGt(_bal(currency0, lp), c0Before);
        assertGt(_bal(currency1, lp), c1Before);
    }

    /// @notice Zero-amount add is rejected.
    function test_InHookLP_ZeroLiquidity_Reverts() public {
        vm.prank(lp);
        vm.expectRevert(ErrorsLib.EigenAuctionHook_ZeroLiquidity.selector);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 0);
    }

    /// @notice `unlockCallback` is only callable from the pool manager.
    function test_InHookLP_UnlockCallback_OnlyPoolManager() public {
        vm.expectRevert();
        hook.unlockCallback("");
    }

    /// @notice `setSettler` can only be called once (already set to the arb helper in setUp).
    function test_SetSettler_Reverts_When_Already_Set() public {
        vm.expectRevert(ErrorsLib.EigenAuctionHook_SettlerAlreadySet.selector);
        hook.setSettler(makeAddr("settler2"));
    }

    /// @notice LP earns only from arbs that occur while price is inside its range.
    function test_InHookLP_TickCrossing_EarnsOnlyInRangeRewards() public {
        vm.prank(lp);
        hook.addLiquidity(poolKey, TICK_LOWER, TICK_UPPER, 1e18);
        vm.roll(block.number + 1);

        // Arb 1: small, stays inside [-600, 600]. LP earns REWARD in currency0.
        _arbSwap();
        uint256 reward1 = _bal(currency0, address(hook));
        assertEq(reward1, REWARD);

        // Arb 2: large enough to push the tick below TICK_LOWER (-600). LP is out of range.
        arbHelper.execute(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -200 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this)
        );

        // Total hook balance is now 2 * REWARD, but the second reward went to whoever is in-range
        // at the post-arb tick — which is nobody (LP's range was exited), so it still distributes
        // to in-range liquidity at that tick. The LP's earned amount should equal only reward1
        // since its range was already crossed before the second reward was added.
        uint256 lpEarned = hook.earned(poolKey, lp, TICK_LOWER, TICK_UPPER, bytes32(0));
        assertApproxEqAbs(lpEarned, reward1, 2);
    }
}
