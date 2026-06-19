// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {EigenAuctionHook} from "../../src/EigenAuctionHook.sol";
import {Settler} from "../../src/Settler.sol";
import {SwapIntent, INTENT_TYPEHASH} from "../../src/types/SwapIntent.sol";
import {ToBOrder, TOB_ORDER_TYPEHASH} from "../../src/types/ToBOrder.sol";
import {MockAuctionServiceManager} from "../mocks/MockAuctionServiceManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

/// @notice Tests for the operator-batch Settler against a real V4 pool: operator-gated settlement,
/// signed ToBOrder arb with on-chain bid derivation, and uniform-clearing-price user batches.
contract SettlerTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    EigenAuctionHook hook;
    MockAuctionServiceManager mockAvs;
    Settler settler;
    PoolKey poolKey;
    PoolId poolId;

    uint256 constant Q128 = 1 << 128;

    uint256 constant USER_PK = 0xA11CE;
    uint256 constant USER2_PK = 0xB0B;
    uint256 constant ARBER_PK = 0xCAFE;
    address user;
    address user2;
    address arber;

    address constant OPERATOR = address(0xAAAA);
    address constant LP = address(0xB10C);

    function setUp() public {
        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();

        mockAvs = new MockAuctionServiceManager();
        mockAvs.setOperator(OPERATOR, true);

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        address hookAddress = address(flags);
        deployCodeTo("EigenAuctionHook.sol", abi.encode(address(manager), address(mockAvs), address(this)), hookAddress);
        hook = EigenAuctionHook(payable(hookAddress));

        (poolKey, poolId) = initPool(currency0, currency1, hook, 3000, 60, SQRT_PRICE_1_1);

        settler = new Settler(address(manager), address(mockAvs));
        hook.setSettler(address(settler));
        mockAvs.setSettler(address(settler));

        // Seed liquidity through the hook so the LP is reward-tracked.
        _fundAndApprove(LP, 1_000e18);
        vm.prank(LP);
        hook.addLiquidity(poolKey, -600, 600, 100e18);

        user = vm.addr(USER_PK);
        user2 = vm.addr(USER2_PK);
        arber = vm.addr(ARBER_PK);

        _fundAndApprove(user, 100e18);
        _fundAndApprove(user2, 100e18);
        _fundAndApprove(arber, 100e18);
    }

    function _fundAndApprove(address who, uint256 amount) internal {
        MockERC20(Currency.unwrap(currency0)).mint(who, amount);
        MockERC20(Currency.unwrap(currency1)).mint(who, amount);
        vm.startPrank(who);
        MockERC20(Currency.unwrap(currency0)).approve(address(settler), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(settler), type(uint256).max);
        MockERC20(Currency.unwrap(currency0)).approve(address(hook), type(uint256).max);
        MockERC20(Currency.unwrap(currency1)).approve(address(hook), type(uint256).max);
        vm.stopPrank();
    }

    function _emptyArb() internal pure returns (ToBOrder memory a) {
        a.signature = "";
    }

    function _noIntents() internal pure returns (SwapIntent[] memory) {
        return new SwapIntent[](0);
    }

    function _signIntent(uint256 pk, bool zeroForOne, uint128 amountIn, uint128 minOut, uint64 nonce)
        internal
        view
        returns (SwapIntent memory intent)
    {
        intent = SwapIntent({
            user: vm.addr(pk),
            poolId: PoolId.unwrap(poolId),
            zeroForOne: zeroForOne,
            useInternal: false,
            amountIn: amountIn,
            minAmountOut: minOut,
            nonce: nonce,
            deadline: type(uint64).max,
            signature: ""
        });
        bytes32 structHash = keccak256(
            abi.encode(
                INTENT_TYPEHASH, intent.user, intent.poolId, intent.zeroForOne, intent.useInternal,
                intent.amountIn, intent.minAmountOut, intent.nonce, intent.deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", settler.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        intent.signature = abi.encodePacked(r, s, v);
    }

    function _signArb(uint256 pk, bool zeroForOne, uint128 qtyIn, uint128 qtyOut)
        internal
        view
        returns (ToBOrder memory a)
    {
        a = ToBOrder({
            searcher: vm.addr(pk),
            poolId: PoolId.unwrap(poolId),
            zeroForOne: zeroForOne,
            useInternal: false,
            quantityIn: qtyIn,
            quantityOut: qtyOut,
            validForBlock: uint64(block.number),
            signature: ""
        });
        bytes32 structHash = keccak256(
            abi.encode(
                TOB_ORDER_TYPEHASH, a.searcher, a.poolId, a.zeroForOne, a.useInternal, a.quantityIn, a.quantityOut, a.validForBlock
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", settler.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        a.signature = abi.encodePacked(r, s, v);
    }

    /* ACCESS CONTROL */

    function test_Settle_NonOperator_Reverts() public {
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 0.5e18, 0, 1);
        vm.expectRevert(ErrorsLib.Settler_NotOperator.selector);
        settler.settle(poolKey, _emptyArb(), intents, Q128);
    }

    function test_Settle_OncePerBlock_Reverts() public {
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 0.5e18, 0, 1);

        vm.startPrank(OPERATOR);
        settler.settle(poolKey, _emptyArb(), intents, (Q128 * 99) / 100);

        SwapIntent[] memory intents2 = new SwapIntent[](1);
        intents2[0] = _signIntent(USER_PK, true, 0.5e18, 0, 2);
        vm.expectRevert(ErrorsLib.EigenAuctionHook_AlreadySettledThisBlock.selector);
        settler.settle(poolKey, _emptyArb(), intents2, (Q128 * 99) / 100);
        vm.stopPrank();
    }

    /* USER BATCH */

    // A single one-directional intent clears at the supplied price; user receives exactly the
    // clearing-price output. A one-sided batch pays AMM fee + slippage, so the operator must price
    // below spot for the batch to stay solvent.
    function test_Settle_SingleIntent_ClearsAtPrice() public {
        uint128 amountIn = 0.1e18;
        uint256 price = (Q128 * 97) / 100; // 3% below spot covers the 0.3% fee + slippage
        uint128 expectedOut = uint128((uint256(amountIn) * price) / Q128);

        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, amountIn, expectedOut, 1);

        uint256 before1 = MockERC20(Currency.unwrap(currency1)).balanceOf(user);
        vm.prank(OPERATOR);
        settler.settle(poolKey, _emptyArb(), intents, price);

        assertEq(MockERC20(Currency.unwrap(currency1)).balanceOf(user) - before1, expectedOut);
        assertTrue(settler.isNonceUsed(user, 1));
    }

    // Opposite-direction intents net against each other at one uniform price (CoW).
    function test_Settle_TwoSidedBatch_UniformPrice() public {
        uint128 inA = 1e18; // user sells token0
        uint128 inB = 1e18; // user2 sells token1
        uint256 price = Q128; // perfectly matched 1:1, net ~0

        SwapIntent[] memory intents = new SwapIntent[](2);
        intents[0] = _signIntent(USER_PK, true, inA, 0, 1);
        intents[1] = _signIntent(USER2_PK, false, inB, 0, 1);

        uint256 u1Before = MockERC20(Currency.unwrap(currency1)).balanceOf(user);
        uint256 u2Before = MockERC20(Currency.unwrap(currency0)).balanceOf(user2);

        vm.prank(OPERATOR);
        settler.settle(poolKey, _emptyArb(), intents, price);

        // user (z4o) gets token1 at price; user2 (o4z) gets token0 at price.
        assertEq(MockERC20(Currency.unwrap(currency1)).balanceOf(user) - u1Before, 1e18);
        assertEq(MockERC20(Currency.unwrap(currency0)).balanceOf(user2) - u2Before, 1e18);
    }

    function test_Settle_SlippageExceeded_Reverts() public {
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 1e18, type(uint128).max, 7);
        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_SlippageExceeded.selector);
        settler.settle(poolKey, _emptyArb(), intents, (Q128 * 99) / 100);
    }

    /* ARB */

    // A zeroForOne arb leaves a derived currency0 bid that the in-range LP earns.
    function test_Settle_Arb_PaysDerivedBidToLP() public {
        vm.roll(block.number + 1);

        // Arb commits to pay more token0 than the AMM needs for quantityOut token1 → positive bid.
        uint128 quantityOut = 1e18;
        uint128 quantityIn = 1.05e18; // generous input; surplus over ammIn is the bid
        ToBOrder memory arb = _signArb(ARBER_PK, true, quantityIn, quantityOut);

        vm.prank(OPERATOR);
        settler.settle(poolKey, arb, _noIntents(), 0);

        uint256 earned = hook.earned(poolKey, LP, -600, 600, bytes32(0));
        assertGt(earned, 0);
        // Bid cannot exceed the generous input.
        assertLt(earned, quantityIn);
    }

    // A negative-bid arb (input below the AMM quote) reverts.
    function test_Settle_Arb_NegativeBid_Reverts() public {
        vm.roll(block.number + 1);
        uint128 quantityOut = 1e18;
        uint128 quantityIn = 0.5e18; // far below what the AMM needs
        ToBOrder memory arb = _signArb(ARBER_PK, true, quantityIn, quantityOut);

        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_NegativeBid.selector);
        settler.settle(poolKey, arb, _noIntents(), 0);
    }

    // An arb signed for a different block is rejected.
    function test_Settle_Arb_WrongBlock_Reverts() public {
        ToBOrder memory arb = _signArb(ARBER_PK, true, 1.05e18, 1e18);
        vm.roll(block.number + 1);
        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_WrongBlock.selector);
        settler.settle(poolKey, arb, _noIntents(), 0);
    }
}
