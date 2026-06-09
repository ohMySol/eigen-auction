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
import {Settler} from "../../src/Settler.sol";
import {SwapIntent} from "../../src/interfaces/ISettler.sol";
import {MockAuctionServiceManager} from "../mocks/MockAuctionServiceManager.sol";

/// @notice Regression tests for Settler.settle against a real V4 pool. Specifically guards the
/// flash-accounting sign convention in `_settleDeltas`/`_fill`: an inverted sign there leaves a
/// non-zero delta and the unlock reverts with `CurrencyNotSettled`.
contract SettlerSettleTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    EigenAuctionHook hook;
    MockAuctionServiceManager mockAvs;
    Settler settler;
    PoolKey poolKey;
    PoolId poolId;

    uint256 constant USER_PK = 0xA11CE;
    address user;
    address constant WINNER = address(0xBEEF);

    bytes32 constant INTENT_TYPEHASH = keccak256(
        "SwapIntent(address user,bytes32 poolId,bool zeroForOne,uint128 amountIn,uint128 minAmountOut,uint64 nonce,uint64 deadline)"
    );

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        mockAvs = new MockAuctionServiceManager();

        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
                | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );
        address hookAddress = address(flags);
        deployCodeTo("EigenAuctionHook.sol", abi.encode(address(manager), address(mockAvs), address(this)), hookAddress);
        hook = EigenAuctionHook(payable(hookAddress));

        (poolKey, poolId) = initPool(currency0, currency1, hook, 3000, 60, SQRT_PRICE_1_1);

        settler = new Settler(address(manager), address(mockAvs));
        hook.setSettler(address(settler));

        // Seed in-range liquidity (the LP is the modifyLiquidityRouter).
        modifyLiquidityRouter.modifyLiquidity(
            poolKey,
            ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: 100e18, salt: bytes32(0)}),
            new bytes(0)
        );

        user = vm.addr(USER_PK);
        MockERC20(Currency.unwrap(currency0)).mint(user, 10e18);
        vm.prank(user);
        MockERC20(Currency.unwrap(currency0)).approve(address(settler), type(uint256).max);

        // Fund the winner so it can pay the arb's input.
        MockERC20(Currency.unwrap(currency0)).mint(WINNER, 10e18);
        vm.prank(WINNER);
        MockERC20(Currency.unwrap(currency0)).approve(address(settler), type(uint256).max);
    }

    function _signedIntent(uint128 amountIn, uint64 nonce) internal view returns (SwapIntent memory intent) {
        intent = SwapIntent({
            user: user,
            poolId: PoolId.unwrap(poolId),
            zeroForOne: true,
            amountIn: amountIn,
            minAmountOut: 0,
            nonce: nonce,
            deadline: type(uint64).max,
            signature: ""
        });
        bytes32 structHash = keccak256(abi.encode(
            INTENT_TYPEHASH, intent.user, intent.poolId, intent.zeroForOne,
            intent.amountIn, intent.minAmountOut, intent.nonce, intent.deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", settler.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(USER_PK, digest);
        intent.signature = abi.encodePacked(r, s, v);
    }

    function _noArb() internal pure returns (SwapParams memory) {
        return SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0});
    }

    // The core regression: an intent-only settle must fill (and not revert with CurrencyNotSettled).
    function test_Settle_FillsIntent_WithoutCurrencyNotSettled() public {
        mockAvs.commitWinner(poolId, block.number, WINNER, 0, new bytes[](0));

        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signedIntent(0.5e18, 1);

        uint256 userOut0 = MockERC20(Currency.unwrap(currency1)).balanceOf(user);
        vm.prank(WINNER);
        settler.settle(poolKey, _noArb(), intents);

        assertTrue(settler.isNonceUsed(user, 1), "nonce should be consumed");
        assertGt(MockERC20(Currency.unwrap(currency1)).balanceOf(user), userOut0, "user should receive output");
    }

    // The arb path skims LVR; an in-range, matured LP should then have a claimable reward.
    function test_Settle_Arb_SkimsLvrToLPs() public {
        // Mature the seeded LP (added at the setUp block) so it is reward-eligible.
        vm.roll(block.number + 1);
        mockAvs.commitWinner(poolId, block.number, WINNER, 0, new bytes[](0));

        SwapParams memory arb = SwapParams({zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: MIN_PRICE_LIMIT});
        SwapIntent[] memory none = new SwapIntent[](0);

        vm.prank(WINNER);
        settler.settle(poolKey, arb, none);

        (uint256 r0, uint256 r1) = hook.earned(poolKey, address(modifyLiquidityRouter), -600, 600, bytes32(0));
        assertGt(r0 + r1, 0, "LP should have earned LVR rewards");
    }
}
