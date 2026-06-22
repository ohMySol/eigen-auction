// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {EigenAuctionHook} from "../../src/EigenAuctionHook.sol";
import {Settler} from "../../src/Settler.sol";
import {SwapIntent, INTENT_TYPEHASH} from "../../src/types/SwapIntent.sol";
import {ToBOrder, TOB_ORDER_TYPEHASH} from "../../src/types/ToBOrder.sol";
import {MockEigenAuctionServiceManager} from "../mocks/MockEigenAuctionServiceManager.sol";
import {MockTaskManager} from "../mocks/MockTaskManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";

/// @notice Tests for the commitment-gated Settler against a real V4 pool: commitment + executor gate,
/// signed ToBOrder arb with on-chain bid derivation, and uniform-clearing-price user batches.
contract SettlerTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    EigenAuctionHook hook;
    MockEigenAuctionServiceManager mockAvs;
    MockTaskManager taskManager;
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

        mockAvs = new MockEigenAuctionServiceManager();
        mockAvs.setOperator(OPERATOR, true);

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        address hookAddress = address(flags);
        deployCodeTo("EigenAuctionHook.sol", abi.encode(address(manager), address(mockAvs), address(this)), hookAddress);
        hook = EigenAuctionHook(payable(hookAddress));

        (poolKey, poolId) = initPool(currency0, currency1, hook, 3000, 60, SQRT_PRICE_1_1);

        taskManager = new MockTaskManager();
        // Deploy fee-free so the existing reward assertions hold; fee behaviour gets its own tests
        // that raise the fee through governance (this test contract is the owner).
        settler = new Settler(address(manager), address(mockAvs), address(taskManager), address(this), 0);
        hook.setSettler(address(settler));

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

    /// @dev Records the quorum commitment the Settler gate reads: binds the exact batch (via its
    /// `resultHash`) and the operator allowed to relay it for the current block.
    function _seedCommitment(ToBOrder memory arb, uint256 price, SwapIntent[] memory intents, address executor)
        internal
    {
        bytes32 resultHash = settler.computeResultHash(arb, price, intents);
        taskManager.setCommitment(poolId, block.number, resultHash, executor);
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

    /* COMMITMENT GATE */

    // With no quorum commitment for the block, settlement is rejected outright.
    function test_Settle_NoCommitment_Reverts() public {
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 0.5e18, 0, 1);
        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_NoCommitment.selector);
        settler.settle(poolKey, _emptyArb(), intents, Q128);
    }

    // A batch that doesn't reproduce the committed resultHash (here: a different price) is rejected.
    function test_Settle_ResultMismatch_Reverts() public {
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 0.5e18, 0, 1);

        // Commit to one price, then try to settle the same intents at another.
        _seedCommitment(_emptyArb(), Q128, intents, OPERATOR);

        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_ResultMismatch.selector);
        settler.settle(poolKey, _emptyArb(), intents, (Q128 * 99) / 100);
    }

    // The committed batch can only be relayed by the committed executor, not any other operator.
    function test_Settle_NotExecutor_Reverts() public {
        uint256 price = (Q128 * 99) / 100;
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 0.5e18, 0, 1);

        _seedCommitment(_emptyArb(), price, intents, OPERATOR);

        // Correct batch, wrong sender.
        vm.prank(address(0xBEEF));
        vm.expectRevert(ErrorsLib.Settler_NotExecutor.selector);
        settler.settle(poolKey, _emptyArb(), intents, price);
    }

    function test_Settle_OncePerBlock_Reverts() public {
        uint256 price = (Q128 * 99) / 100;
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 0.5e18, 0, 1);

        _seedCommitment(_emptyArb(), price, intents, OPERATOR);

        vm.startPrank(OPERATOR);
        settler.settle(poolKey, _emptyArb(), intents, price);

        // Replaying the same committed batch in the same block is stopped by the hook's once-per-block
        // guard (reached before the consumed nonce would trip).
        vm.expectRevert(ErrorsLib.EigenAuctionHook_AlreadySettledThisBlock.selector);
        settler.settle(poolKey, _emptyArb(), intents, price);
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

        _seedCommitment(_emptyArb(), price, intents, OPERATOR);

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

        _seedCommitment(_emptyArb(), price, intents, OPERATOR);

        uint256 u1Before = MockERC20(Currency.unwrap(currency1)).balanceOf(user);
        uint256 u2Before = MockERC20(Currency.unwrap(currency0)).balanceOf(user2);

        vm.prank(OPERATOR);
        settler.settle(poolKey, _emptyArb(), intents, price);

        // user (z4o) gets token1 at price; user2 (o4z) gets token0 at price.
        assertEq(MockERC20(Currency.unwrap(currency1)).balanceOf(user) - u1Before, 1e18);
        assertEq(MockERC20(Currency.unwrap(currency0)).balanceOf(user2) - u2Before, 1e18);
    }

    function test_Settle_SlippageExceeded_Reverts() public {
        uint256 price = (Q128 * 99) / 100;
        SwapIntent[] memory intents = new SwapIntent[](1);
        intents[0] = _signIntent(USER_PK, true, 1e18, type(uint128).max, 7);

        _seedCommitment(_emptyArb(), price, intents, OPERATOR);

        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_SlippageExceeded.selector);
        settler.settle(poolKey, _emptyArb(), intents, price);
    }

    /* ARB */

    // A zeroForOne arb leaves a derived currency0 bid that the in-range LP earns.
    function test_Settle_Arb_PaysDerivedBidToLP() public {
        vm.roll(block.number + 1);

        // Arb commits to pay more token0 than the AMM needs for quantityOut token1 → positive bid.
        uint128 quantityOut = 1e18;
        uint128 quantityIn = 1.05e18; // generous input; surplus over ammIn is the bid
        ToBOrder memory arb = _signArb(ARBER_PK, true, quantityIn, quantityOut);

        _seedCommitment(arb, 0, _noIntents(), OPERATOR);

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

        _seedCommitment(arb, 0, _noIntents(), OPERATOR);

        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_NegativeBid.selector);
        settler.settle(poolKey, arb, _noIntents(), 0);
    }

    // An arb signed for a different block is rejected.
    function test_Settle_Arb_WrongBlock_Reverts() public {
        ToBOrder memory arb = _signArb(ARBER_PK, true, 1.05e18, 1e18);
        vm.roll(block.number + 1);

        // Commitment exists for the settle block; the arb itself is stale (validForBlock is last block).
        _seedCommitment(arb, 0, _noIntents(), OPERATOR);

        vm.prank(OPERATOR);
        vm.expectRevert(ErrorsLib.Settler_WrongBlock.selector);
        settler.settle(poolKey, arb, _noIntents(), 0);
    }

    /* OPERATOR FEE — GOVERNANCE */

    function test_Constructor_SetsOwnerAndFeeDefaults() public view {
        assertEq(settler.owner(), address(this));
        assertEq(settler.operatorFeeBps(), 0);
    }

    function test_Constructor_FeeAboveCap_Reverts() public {
        vm.expectRevert(ErrorsLib.Settler_FeeTooHigh.selector);
        new Settler(
            address(manager),
            address(mockAvs),
            address(taskManager),
            address(this),
            ConstantsLib.MAX_OPERATOR_FEE_BPS + 1
        );
    }

    function test_Constructor_ZeroOwner_Reverts() public {
        // Ownership is enforced by OpenZeppelin's `Ownable`, which rejects the zero owner first.
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Settler(address(manager), address(mockAvs), address(taskManager), address(0), 0);
    }

    function test_SetOperatorFeeBps_Updates() public {
        settler.setOperatorFeeBps(750);
        assertEq(settler.operatorFeeBps(), 750);
    }

    function test_SetOperatorFeeBps_AboveCap_Reverts() public {
        vm.expectRevert(ErrorsLib.Settler_FeeTooHigh.selector);
        settler.setOperatorFeeBps(ConstantsLib.MAX_OPERATOR_FEE_BPS + 1);
    }

    function test_SetOperatorFeeBps_NotOwner_Reverts() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0xBEEF)));
        settler.setOperatorFeeBps(750);
    }

    function test_TransferOwnership_Updates() public {
        address newOwner = makeAddr("newOwner");
        settler.transferOwnership(newOwner);
        assertEq(settler.owner(), newOwner);

        // Old owner (this test contract) can no longer govern.
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        settler.setOperatorFeeBps(100);
    }

    /* OPERATOR FEE — CARVE-OUT + FORWARDING */

    // The fee is skimmed from the arb bid and pushed to the ServiceManager before LPs receive the
    // remainder. fee + lpAmount must reproduce the gross bid at the configured bps.
    function test_Settle_Arb_ForwardsOperatorFeeToAvs() public {
        settler.setOperatorFeeBps(2000); // 20%
        vm.roll(block.number + 1);

        ToBOrder memory arb = _signArb(ARBER_PK, true, 1.05e18, 1e18);
        _seedCommitment(arb, 0, _noIntents(), OPERATOR);

        address asset = Currency.unwrap(currency0);
        uint256 avsBefore  = MockERC20(asset).balanceOf(address(mockAvs));
        uint256 hookBefore = MockERC20(asset).balanceOf(address(hook));

        vm.prank(OPERATOR);
        settler.settle(poolKey, arb, _noIntents(), 0);

        uint256 fee      = MockERC20(asset).balanceOf(address(mockAvs)) - avsBefore;
        uint256 lpAmount = MockERC20(asset).balanceOf(address(hook)) - hookBefore;

        assertGt(fee, 0);
        assertGt(lpAmount, 0);
        // fee == floor(gross * 2000 / 10000)
        assertEq(fee, ((fee + lpAmount) * 2000) / ConstantsLib.BPS);
    }

    // With a zero fee rate, nothing is forwarded to the ServiceManager.
    function test_Settle_Arb_ZeroFee_NothingForwarded() public {
        vm.roll(block.number + 1);
        ToBOrder memory arb = _signArb(ARBER_PK, true, 1.05e18, 1e18);
        _seedCommitment(arb, 0, _noIntents(), OPERATOR);

        address asset = Currency.unwrap(currency0);
        uint256 avsBefore = MockERC20(asset).balanceOf(address(mockAvs));

        vm.prank(OPERATOR);
        settler.settle(poolKey, arb, _noIntents(), 0);

        assertEq(MockERC20(asset).balanceOf(address(mockAvs)), avsBefore);
    }
}
