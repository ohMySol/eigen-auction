// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {EigenAuctionHook} from "../../src/EigenAuctionHook.sol";
import {MockEigenAuctionServiceManager} from "../mocks/MockEigenAuctionServiceManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {ArbHelper} from "../helpers/ArbHelper.sol";

/// @notice Tests for LP reward accounting when liquidity is supplied through a standard V4 router.
/// The hook attributes each position to the router (the owner V4 sees) plus the position salt, so
/// reward queries use `address(modifyLiquidityRouter)` and a per-LP salt distinguishes positions.
contract EigenAuctionHookLPTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

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

        _fundAndApprove(lp);

        arbHelper = new ArbHelper(manager);
        // The arb helper acts as the hook's settler so its swaps and distributeReward succeed.
        hook.setSettler(address(arbHelper));
        // address(this) (the test) pays rewards and arb inputs.
        MockERC20(Currency.unwrap(currency0)).approve(address(arbHelper), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(arbHelper), type(uint256).max);
    }

    /* HELPERS */

    /// @dev Position owner as the hook sees it — the router that opened the position.
    function _lpOwner() internal view returns (address) {
        return address(modifyLiquidityRouter);
    }

    function _bal(Currency c, address a) internal view returns (uint256) {
        return MockERC20(Currency.unwrap(c)).balanceOf(a);
    }

    function _fundAndApprove(address who) internal {
        MockERC20(Currency.unwrap(currency0)).mint(who, 1_000e18);
        MockERC20(Currency.unwrap(currency1)).mint(who, 1_000e18);
        vm.startPrank(who);
        MockERC20(Currency.unwrap(currency0)).approve(address(modifyLiquidityRouter), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(modifyLiquidityRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _add(address who, uint128 liq, bytes32 salt) internal {
        vm.prank(who);
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: int256(uint256(liq)), salt: salt}),
            ""
        );
    }

    function _remove(address who, uint128 liq, bytes32 salt) internal {
        vm.prank(who);
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: -int256(uint256(liq)), salt: salt}),
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

    /* TESTS */

    /// @notice End-to-end LP path: supply via the router, mature, get arbed, then remove to collect rewards.
    function test_LP_Add_Earn_Remove() public {
        _add(lp, 1e18, bytes32(0));

        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = _bal(currency0, address(hook));
        assertEq(reward, REWARD);

        uint256 earned = hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0));
        assertApproxEqAbs(earned, reward, 2);

        // Removing pays rewards automatically: the hook's reward balance drains and earned() is zeroed.
        _remove(lp, 1e18, bytes32(0));
        assertApproxEqAbs(_bal(currency0, address(hook)), 0, 1, "hook reward balance drained on remove");
        assertEq(hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0)), 0, "nothing left after remove");
    }

    /// @notice On remove, the accrued reward rides out as the hook's currency0 delta to the LP — so the
    /// LP's currency0 gain covers principal plus at least the reward, and the hook is fully drained.
    function test_LP_Remove_Pays_Reward_To_LP_Via_Delta() public {
        _add(lp, 1e18, bytes32(0));
        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0));
        assertApproxEqAbs(reward, REWARD, 2);

        uint256 lpC0Before = _bal(currency0, lp);
        _remove(lp, 1e18, bytes32(0));

        // LP receives principal0 + reward in currency0; the increase is at least the reward.
        assertGe(_bal(currency0, lp) - lpC0Before, reward, "LP did not receive the reward on remove");
        assertApproxEqAbs(_bal(currency0, address(hook)), 0, 1, "reward left the hook");
    }

    /// @notice Two LPs in the same range (distinct salts) split the reward by liquidity share.
    function test_LP_TwoLPs_SplitByShare() public {
        address lp2 = makeAddr("lp2");
        _fundAndApprove(lp2);

        _add(lp, 0.25e18, bytes32(uint256(1)));
        _add(lp2, 0.75e18, bytes32(uint256(2)));

        vm.roll(block.number + 1);
        _arbSwap();

        uint256 reward = _bal(currency0, address(hook));
        assertGt(reward, 1000);

        uint256 a1 = hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(uint256(1)));
        uint256 a2 = hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(uint256(2)));

        assertApproxEqAbs(a1, reward / 4, 2);
        assertApproxEqAbs(a2, (reward * 3) / 4, 2);
    }

    /// @notice Removing returns principal to the LP in both currencies.
    function test_LP_Remove_Returns_Principal() public {
        _add(lp, 1e18, bytes32(0));

        uint256 c0Before = _bal(currency0, lp);
        uint256 c1Before = _bal(currency1, lp);

        _remove(lp, 1e18, bytes32(0));

        assertGt(_bal(currency0, lp), c0Before);
        assertGt(_bal(currency1, lp), c1Before);
    }

    /// @notice `setSettler` can only be called once (already set to the arb helper in setUp).
    function test_SetSettler_Reverts_When_Already_Set() public {
        vm.expectRevert(ErrorsLib.EigenAuctionHook_SettlerAlreadySet.selector);
        hook.setSettler(makeAddr("settler2"));
    }

    /// @notice LP earns only from arbs that occur while price is inside its range.
    function test_LP_TickCrossing_EarnsOnlyInRangeRewards() public {
        _add(lp, 1e18, bytes32(0));
        vm.roll(block.number + 1);

        // Arb 1: small, stays inside [-600, 600]. LP earns REWARD in currency0.
        _arbSwap();
        uint256 reward1 = _bal(currency0, address(hook));
        assertEq(reward1, REWARD);

        // Arb 2: large enough to push the tick below TICK_LOWER (-600), so the LP is out of range and
        // does not earn the second reward.
        arbHelper.execute(
            poolKey,
            SwapParams({zeroForOne: true, amountSpecified: -200 ether, sqrtPriceLimitX96: MIN_PRICE_LIMIT}),
            REWARD,
            address(this)
        );

        uint256 lpEarned = hook.earned(poolKey, _lpOwner(), TICK_LOWER, TICK_UPPER, bytes32(0));
        assertApproxEqAbs(lpEarned, reward1, 2);
    }
}
