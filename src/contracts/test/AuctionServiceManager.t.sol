// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {AuctionServiceManager} from "../src/AuctionServiceManager.sol";
import {IAuctionServiceManager, AuctionResult} from "../src/interfaces/IAuctionServiceManager.sol";
import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
import {EventsLib} from "../src/libraries/EventsLib.sol";

contract AuctionServiceManagerTest is Test {
    using MessageHashUtils for bytes32;

    AuctionServiceManager asm;
    PoolId poolId;
    address winner;
    uint256 constant BID = 1 ether;
    uint256 constant THRESHOLD = 2;

    uint256 op1Key = 0xA11CE;
    uint256 op2Key = 0xB0B;
    uint256 op3Key = 0xCAFE;
    address op1;
    address op2;
    address op3;

    address owner = address(this);

    function setUp() public {
        poolId = PoolId.wrap(bytes32(uint256(1)));
        winner = makeAddr("winner");

        op1 = vm.addr(op1Key);
        op2 = vm.addr(op2Key);
        op3 = vm.addr(op3Key);

        asm = new AuctionServiceManager(THRESHOLD);
        asm.registerOperator(op1);
        asm.registerOperator(op2);
        asm.registerOperator(op3);
    }

    /* TEST HELPERS */

    function _sign(uint256 privKey, uint256 targetBlock) internal view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked(poolId, targetBlock, winner, BID)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /* CONSTRUCTOR TESTS */

    function test_Constructor_Sets_Owner_And_Threshold() public view {
        assertEq(asm.owner(), address(this));
        assertEq(asm.threshold(), THRESHOLD);
    }

    function test_Constructor_Reverts_When_Threshold_Is_Zero() public {
        vm.expectRevert(ErrorsLib.AuctionServiceManager_InvalidThreshold.selector);
        new AuctionServiceManager(0);
    }

    /* REGISTER OPERATOR TESTS */

    function test_registerOperator_Adds_Operator_To_Set() public {
        address op4 = makeAddr("op4");
        asm.registerOperator(op4);
        assertTrue(asm.isOperator(op4));
        assertEq(asm.operatorCount(), 4);
    }

    function test_registerOperator_Emits_OperatorRegistered() public {
        address op4 = makeAddr("op4");
        vm.expectEmit(address(asm));
        emit EventsLib.OperatorRegistered(op4);
        asm.registerOperator(op4);
    }

    function test_registerOperator_Reverts_When_Not_Owner() public {
        address stranger = makeAddr("stranger");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        asm.registerOperator(makeAddr("op4"));
    }

    function test_registerOperator_Reverts_When_Already_Registered() public {
        vm.expectRevert(ErrorsLib.AuctionServiceManager_OperatorAlreadyRegistered.selector);
        asm.registerOperator(op1);
    }

    function test_registerOperator_Reverts_When_Zero_Address() public {
        vm.expectRevert(ErrorsLib.AuctionServiceManager_ZeroOperator.selector);
        asm.registerOperator(address(0));
    }

    /* COMMIT WINNER TESTS */

    function test_commitWinner_TwoOfThree_Sigs_Succeeds() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op2Key, target);

        asm.commitWinner(poolId, target, winner, BID, sigs);

        AuctionResult memory r = asm.getWinner(poolId, target);
        assertTrue(r.committed);
        assertEq(r.winner, winner);
        assertEq(r.bidAmount, BID);
    }

    function test_commitWinner_Emits_WinnerCommitted() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op2Key, target);

        vm.expectEmit(address(asm));
        emit EventsLib.WinnerCommitted(poolId, target, winner, BID);
        asm.commitWinner(poolId, target, winner, BID, sigs);
    }

    function test_commitWinner_ExtraSigs_Above_Threshold_Succeeds() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](3);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op2Key, target);
        sigs[2] = _sign(op3Key, target);

        asm.commitWinner(poolId, target, winner, BID, sigs);
        assertTrue(asm.getWinner(poolId, target).committed);
    }

    function test_commitWinner_Reverts_When_Insufficient_Sigs() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _sign(op1Key, target);

        vm.expectRevert(ErrorsLib.AuctionServiceManager_QuorumNotMet.selector);
        asm.commitWinner(poolId, target, winner, BID, sigs);
    }

    function test_commitWinner_Reverts_When_Duplicate_Sig() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op1Key, target); // same operator twice

        vm.expectRevert(ErrorsLib.AuctionServiceManager_QuorumNotMet.selector);
        asm.commitWinner(poolId, target, winner, BID, sigs);
    }

    function test_commitWinner_Reverts_When_NonOperator_Sig() public {
        uint256 target = block.number;
        uint256 randKey = 0x1234;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(randKey, target); // not a registered operator

        vm.expectRevert(ErrorsLib.AuctionServiceManager_QuorumNotMet.selector);
        asm.commitWinner(poolId, target, winner, BID, sigs);
    }

    function test_commitWinner_Reverts_When_Stale_Block() public {
        vm.roll(block.number + 5);
        uint256 staleBlock = block.number - 3;

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, staleBlock);
        sigs[1] = _sign(op2Key, staleBlock);

        vm.expectRevert(ErrorsLib.AuctionServiceManager_StaleBlock.selector);
        asm.commitWinner(poolId, staleBlock, winner, BID, sigs);
    }

    function test_commitWinner_Reverts_When_Already_Committed() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op2Key, target);

        asm.commitWinner(poolId, target, winner, BID, sigs);

        vm.expectRevert(ErrorsLib.AuctionServiceManager_AlreadyCommitted.selector);
        asm.commitWinner(poolId, target, winner, BID, sigs);
    }

    function test_commitWinner_Reverts_When_Zero_Winner() public {
        uint256 target = block.number;
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op2Key, target);

        vm.expectRevert(ErrorsLib.AuctionServiceManager_ZeroWinner.selector);
        asm.commitWinner(poolId, target, address(0), BID, sigs);
    }

    function test_commitWinner_Reverts_When_Sigs_For_Wrong_Bid() public {
        uint256 target = block.number;
        // Operators signed for BID, but commit attempts a different amount → recovered hash differs.
        bytes[] memory sigs = new bytes[](2);
        sigs[0] = _sign(op1Key, target);
        sigs[1] = _sign(op2Key, target);

        vm.expectRevert(ErrorsLib.AuctionServiceManager_QuorumNotMet.selector);
        asm.commitWinner(poolId, target, winner, BID + 1, sigs);
    }

    /* GET WINNER TESTS */

    function test_getWinner_Returns_Empty_When_Not_Committed() public view {
        AuctionResult memory r = asm.getWinner(poolId, block.number);
        assertFalse(r.committed);
        assertEq(r.winner, address(0));
        assertEq(r.bidAmount, 0);
    }
}
