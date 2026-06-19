// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IPermissionController} from "eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {AuctionServiceManager} from "../../src/AuctionServiceManager.sol";
import {Settler} from "../../src/Settler.sol";
import {AuctionResult} from "../../src/types/AuctionResult.sol";
import {ToBOrder, TOB_ORDER_TYPEHASH} from "../../src/types/ToBOrder.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {EventsLib} from "../../src/libraries/EventsLib.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";
import {MockAllocationManager} from "../mocks/MockAllocationManager.sol";

/// @notice Unit suite for `AuctionServiceManager` under the operator-batch model: operator membership,
/// settlement recording, and the dominant-order fraud proof. Slashing/membership use
/// `MockAllocationManager`; the other EigenLayer deps are unused and passed as zero.
contract AuctionServiceManagerTest is Test {
    uint32 public constant OPERATOR_SET_ID = 1;

    AuctionServiceManager public asm;
    MockAllocationManager public allocationManager;
    Settler public settler;

    PoolId public poolId;

    uint256 public opKey = 0xA11CE;
    address public operator;
    uint256 public arberKey = 0xCAFE;
    address public arber;
    address public stranger = makeAddr("stranger");

    IStrategy public dummyStrategy = IStrategy(address(0x5712A7E69));

    function setUp() public {
        poolId = PoolId.wrap(bytes32(uint256(1)));
        operator = vm.addr(opKey);
        arber = vm.addr(arberKey);

        allocationManager = new MockAllocationManager();

        AuctionServiceManager impl = new AuctionServiceManager(
            IAVSDirectory(address(0)),
            IRewardsCoordinator(address(0)),
            ISlashingRegistryCoordinator(address(0)),
            IStakeRegistry(address(0)),
            IPermissionController(address(0)),
            IAllocationManager(address(allocationManager))
        );
        bytes memory init = abi.encodeCall(AuctionServiceManager.initialize, (address(this), address(this)));
        asm = AuctionServiceManager(address(new ERC1967Proxy(address(impl), init)));

        // Settler provides the EIP-712 domain the AVS uses for fraud-proof signature recovery.
        settler = new Settler(makeAddr("poolManager"), address(asm));
        asm.setSettler(address(settler));

        allocationManager.setMember(operator, address(asm), OPERATOR_SET_ID, true);
        vm.roll(block.number + 2);
    }

    /* HELPERS */

    function _configureSlashing() internal {
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = dummyStrategy;
        uint256[] memory wads = new uint256[](1);
        wads[0] = 1e17; // 10%
        asm.createOperatorSet(strategies);
        asm.configureSlashing(strategies, wads);
    }

    function _record(uint256 targetBlock, bool zeroForOne, uint128 qtyIn, uint128 qtyOut) internal {
        vm.prank(address(settler));
        asm.recordSettlement(poolId, targetBlock, operator, zeroForOne, qtyIn, qtyOut);
    }

    function _signToB(bool zeroForOne, uint128 qtyIn, uint128 qtyOut, uint64 validForBlock)
        internal
        view
        returns (ToBOrder memory a)
    {
        a = ToBOrder({
            arber: arber,
            poolId: PoolId.unwrap(poolId),
            zeroForOne: zeroForOne,
            useInternal: false,
            quantityIn: qtyIn,
            quantityOut: qtyOut,
            validForBlock: validForBlock,
            signature: ""
        });
        bytes32 structHash = keccak256(
            abi.encode(
                TOB_ORDER_TYPEHASH, a.arber, a.poolId, a.zeroForOne, a.useInternal, a.quantityIn, a.quantityOut, a.validForBlock
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", settler.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(arberKey, digest);
        a.signature = abi.encodePacked(r, s, v);
    }

    /* CONFIG */

    function test_Initialize_Sets_Owner() public view {
        assertEq(asm.owner(), address(this));
    }

    function test_SetSettler_Set() public view {
        assertEq(asm.settler(), address(settler));
    }

    function test_SetSettler_Reverts_When_Already_Set() public {
        vm.expectRevert(ErrorsLib.AuctionServiceManager_InvalidSettler.selector);
        asm.setSettler(makeAddr("other"));
    }

    function test_isOperator_Reflects_Membership() public view {
        assertTrue(asm.isOperator(operator));
        assertFalse(asm.isOperator(stranger));
    }

    function test_ConfigureSlashing_Reverts_On_Length_Mismatch() public {
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = dummyStrategy;
        uint256[] memory wads = new uint256[](2);
        vm.expectRevert(ErrorsLib.AuctionServiceManager_SlashConfigLengthMismatch.selector);
        asm.configureSlashing(strategies, wads);
    }

    /* RECORD SETTLEMENT */

    function test_recordSettlement_Stores() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 0.9e18);

        AuctionResult memory r = asm.getSettlement(poolId, target);
        assertTrue(r.settled);
        assertEq(r.operator, operator);
        assertTrue(r.zeroForOne);
        assertEq(r.quantityIn, 1e18);
        assertEq(r.quantityOut, 0.9e18);
        assertFalse(r.challenged);
    }

    function test_recordSettlement_Reverts_When_Not_Settler() public {
        vm.expectRevert(ErrorsLib.AuctionServiceManager_NotSettler.selector);
        asm.recordSettlement(poolId, block.number, operator, true, 1e18, 1e18);
    }

    function test_recordSettlement_Reverts_When_Already_Settled() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);
        vm.prank(address(settler));
        vm.expectRevert(ErrorsLib.AuctionServiceManager_AlreadySettled.selector);
        asm.recordSettlement(poolId, target, operator, true, 1e18, 1e18);
    }

    /* CHALLENGE */

    function test_challenge_Succeeds_Marks_And_Slashes() public {
        _configureSlashing();
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);

        // A dominant order: same input, strictly less output wanted ⇒ strictly larger bid.
        ToBOrder memory better = _signToB(true, 1e18, 0.9e18, uint64(target));
        asm.challengeSettlement(poolId, target, better);

        assertTrue(asm.getSettlement(poolId, target).challenged);
        assertEq(allocationManager.slashCount(), 1);
        assertEq(allocationManager.slashedOperators(0), operator);
    }

    function test_challenge_Succeeds_Without_Slashing_Config() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);

        ToBOrder memory better = _signToB(true, 1.1e18, 1e18, uint64(target)); // pays more
        asm.challengeSettlement(poolId, target, better);

        assertTrue(asm.getSettlement(poolId, target).challenged);
        assertEq(allocationManager.slashCount(), 0);
    }

    function test_challenge_Reverts_When_Not_Settled() public {
        ToBOrder memory better = _signToB(true, 1e18, 0.9e18, uint64(block.number));
        vm.expectRevert(ErrorsLib.AuctionServiceManager_NotSettled.selector);
        asm.challengeSettlement(poolId, block.number, better);
    }

    function test_challenge_Reverts_When_Not_Better() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);
        // Identical terms ⇒ not strictly dominant.
        ToBOrder memory same = _signToB(true, 1e18, 1e18, uint64(target));
        vm.expectRevert(ErrorsLib.AuctionServiceManager_NotBetterOrder.selector);
        asm.challengeSettlement(poolId, target, same);
    }

    function test_challenge_Reverts_On_Direction_Mismatch() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);
        ToBOrder memory wrongDir = _signToB(false, 1e18, 0.9e18, uint64(target));
        vm.expectRevert(ErrorsLib.AuctionServiceManager_OrderMismatch.selector);
        asm.challengeSettlement(poolId, target, wrongDir);
    }

    function test_challenge_Reverts_On_Bad_Signature() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);
        ToBOrder memory better = _signToB(true, 1e18, 0.9e18, uint64(target));
        better.arber = makeAddr("notSigner"); // recovery will not match
        vm.expectRevert(ErrorsLib.AuctionServiceManager_InvalidOrderSignature.selector);
        asm.challengeSettlement(poolId, target, better);
    }

    function test_challenge_Reverts_When_Already_Challenged() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);
        ToBOrder memory better = _signToB(true, 1e18, 0.9e18, uint64(target));
        asm.challengeSettlement(poolId, target, better);

        vm.expectRevert(ErrorsLib.AuctionServiceManager_AlreadyChallenged.selector);
        asm.challengeSettlement(poolId, target, better);
    }

    function test_challenge_Reverts_When_Window_Closed() public {
        uint256 target = block.number;
        _record(target, true, 1e18, 1e18);
        ToBOrder memory better = _signToB(true, 1e18, 0.9e18, uint64(target));

        vm.roll(block.number + ConstantsLib.CHALLENGE_WINDOW + 1);
        vm.expectRevert(ErrorsLib.AuctionServiceManager_ChallengeWindowClosed.selector);
        asm.challengeSettlement(poolId, target, better);
    }

    function test_getSettlement_Empty_When_None() public view {
        AuctionResult memory r = asm.getSettlement(poolId, block.number);
        assertFalse(r.settled);
        assertEq(r.operator, address(0));
    }
}
