// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IPermissionController} from "eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";

import {EigenAuctionServiceManager} from "../../src/EigenAuctionServiceManager.sol";
import {MockAllocationManager} from "../mocks/MockAllocationManager.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

/// @notice Unit suite for `EigenAuctionServiceManager` in the BLS model: proxy init + operator-set
/// membership. Result commitment and fraud proofs live on `EigenAuctionTaskManager`. Membership uses
/// `MockAllocationManager`; the other EigenLayer deps are unused and passed as zero.
contract EigenAuctionServiceManagerTest is Test {
    uint32 public constant OPERATOR_SET_ID = 0;

    EigenAuctionServiceManager public asm;
    MockAllocationManager public allocationManager;

    address public operator = makeAddr("operator");
    address public stranger = makeAddr("stranger");

    function setUp() public {
        allocationManager = new MockAllocationManager();

        EigenAuctionServiceManager impl = new EigenAuctionServiceManager(
            IAVSDirectory(address(0)),
            IRewardsCoordinator(address(0)),
            ISlashingRegistryCoordinator(address(0)),
            IStakeRegistry(address(0)),
            IPermissionController(address(0)),
            IAllocationManager(address(allocationManager))
        );
        bytes memory init = abi.encodeCall(EigenAuctionServiceManager.initialize, (address(this), address(this)));
        asm = EigenAuctionServiceManager(address(new ERC1967Proxy(address(impl), init)));

        allocationManager.setMember(operator, address(asm), OPERATOR_SET_ID, true);
    }

    function test_Initialize_Sets_Owner() public view {
        assertEq(asm.owner(), address(this));
    }

    function test_isOperator_Reflects_Membership() public view {
        assertTrue(asm.isOperator(operator));
        assertFalse(asm.isOperator(stranger));
    }

    /* SETTLER WIRING */

    function test_SetSettler_UpdatesAndIsReadable() public {
        address s = makeAddr("settler");
        asm.setSettler(s);
        assertEq(asm.settler(), s);
    }

    function test_SetSettler_NotOwner_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert();
        asm.setSettler(makeAddr("settler"));
    }

    function test_SetSettler_ZeroAddress_Reverts() public {
        vm.expectRevert(ErrorsLib.EigenAuctionServiceManager_ZeroAddress.selector);
        asm.setSettler(address(0));
    }

    /* OPERATOR FEE RECEIPT */

    function test_ReceiveOperatorFee_NotSettler_Reverts() public {
        vm.prank(stranger);
        vm.expectRevert(ErrorsLib.EigenAuctionServiceManager_NotSettler.selector);
        asm.receiveOperatorFee(makeAddr("token"), 100);
    }

    function test_ReceiveOperatorFee_BySettler_Succeeds() public {
        address s = makeAddr("settler");
        asm.setSettler(s);
        // Tokens are already held by the SM in production (forwarded via ERC20 transfer before
        // this call). Here we just verify the call itself doesn't revert.
        vm.prank(s);
        asm.receiveOperatorFee(makeAddr("token"), 100);
    }
}
