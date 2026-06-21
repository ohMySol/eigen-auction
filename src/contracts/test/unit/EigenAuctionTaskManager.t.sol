// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";

import {EigenAuctionTaskManager} from "../../src/EigenAuctionTaskManager.sol";
import {Commitment} from "../../src/interfaces/IEigenAuctionTaskManager.sol";

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

/// @dev Minimal stand-ins for the registry stack. The inherited `BLSSignatureChecker` constructor
/// walks `coordinator.stakeRegistry().delegation()` + `coordinator.blsApkRegistry()`, and the admin
/// modifier reads `coordinator.owner()`. Real signature verification is never reached because the
/// harness overrides `_verifyQuorum`, so these only need matching selectors.
contract MockStakeRegistry {
    function delegation() external view returns (address) {
        return address(this);
    }
}

contract MockRegistryCoordinator {
    address public immutable owner;
    address public immutable stakeRegistry;

    constructor(address _owner, address _stakeRegistry) {
        owner = _owner;
        stakeRegistry = _stakeRegistry;
    }

    function blsApkRegistry() external view returns (address) {
        return address(this);
    }
}

/// @dev Test seam: replaces the real aggregate-signature verification with canned stake totals so the
/// task manager's own threshold/replay/staleness/access logic can be tested in isolation.
contract TaskManagerHarness is EigenAuctionTaskManager {
    uint96[] private _signed;
    uint96[] private _total;
    bytes32 public recordHash = keccak256("signatory-record");
    bool public reverts;

    constructor(ISlashingRegistryCoordinator rc, bytes memory q, uint256 t) EigenAuctionTaskManager(rc, q, t) {}

    function setStakes(uint96[] calldata signed, uint96[] calldata total) external {
        _signed = signed;
        _total = total;
    }

    function setRevert(bool value) external {
        reverts = value;
    }

    function _verifyQuorum(bytes32, uint32, bytes calldata, NonSignerStakesAndSignature calldata)
        internal
        view
        override
        returns (QuorumStakeTotals memory totals, bytes32)
    {
        require(!reverts, "bad signature");
        totals.signedStakeForQuorum = _signed;
        totals.totalStakeForQuorum = _total;
        return (totals, recordHash);
    }
}

/// @notice Unit tests for `EigenAuctionTaskManager.commitWinner`. Aggregate-signature verification is
/// EigenLayer's audited code (exercised in a fork/integration test); here we cover our threshold,
/// staleness, replay, and access-control logic via the harness seam.
contract EigenAuctionTaskManagerTest is Test {
    TaskManagerHarness taskManager;

    PoolId poolId = PoolId.wrap(bytes32(uint256(1)));
    address executor = makeAddr("executor");
    address admin = makeAddr("admin");

    bytes32 constant RESULT_HASH = keccak256("result");
    uint256 constant THRESHOLD_BPS = 6600; // 66%
    bytes constant QUORUMS = hex"00";

    function setUp() public {
        MockStakeRegistry stakeReg = new MockStakeRegistry();
        MockRegistryCoordinator coordinator = new MockRegistryCoordinator(admin, address(stakeReg));
        taskManager =
            new TaskManagerHarness(ISlashingRegistryCoordinator(address(coordinator)), hex"00", THRESHOLD_BPS);

        vm.roll(100); // move off genesis so a past reference block exists
        _setStakes(66, 100); // exactly meets 66%
    }

    function _setStakes(uint96 signed, uint96 total) internal {
        uint96[] memory s = new uint96[](1);
        uint96[] memory t = new uint96[](1);
        s[0] = signed;
        t[0] = total;
        taskManager.setStakes(s, t);
    }

    function _emptySig() internal pure returns (EigenAuctionTaskManager.NonSignerStakesAndSignature memory p) {}

    function _commit() internal {
        taskManager.commitWinner(poolId, block.number, RESULT_HASH, executor, uint32(block.number - 1), QUORUMS, _emptySig());
    }

    /* COMMIT */

    function test_Commit_StoresCommitment() public {
        _commit();
        Commitment memory c = taskManager.getCommitment(poolId, block.number);
        assertTrue(c.exists);
        assertEq(c.resultHash, RESULT_HASH);
        assertEq(c.executor, executor);
        assertEq(c.signatoryRecordHash, taskManager.recordHash());
    }

    function test_Commit_AtExactThreshold_Succeeds() public {
        _setStakes(66, 100);
        _commit();
        assertTrue(taskManager.getCommitment(poolId, block.number).exists);
    }

    function test_Commit_BelowThreshold_Reverts() public {
        _setStakes(65, 100); // 65% < 66%
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_QuorumNotMet.selector);
        _commit();
    }

    function test_Commit_ZeroExecutor_Reverts() public {
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_ZeroExecutor.selector);
        taskManager.commitWinner(poolId, block.number, RESULT_HASH, address(0), uint32(block.number - 1), QUORUMS, _emptySig());
    }

    function test_Commit_WrongTargetBlock_Reverts() public {
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_WrongTargetBlock.selector);
        taskManager.commitWinner(poolId, block.number + 1, RESULT_HASH, executor, uint32(block.number - 1), QUORUMS, _emptySig());
    }

    function test_Commit_FutureReferenceBlock_Reverts() public {
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_FutureReferenceBlock.selector);
        taskManager.commitWinner(poolId, block.number, RESULT_HASH, executor, uint32(block.number), QUORUMS, _emptySig());
    }

    function test_Commit_QuorumNumbersMismatch_Reverts() public {
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_QuorumNumbersMismatch.selector);
        taskManager.commitWinner(poolId, block.number, RESULT_HASH, executor, uint32(block.number - 1), hex"0001", _emptySig());
    }

    function test_Commit_Twice_Reverts() public {
        _commit();
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_AlreadyCommitted.selector);
        _commit();
    }

    function test_Commit_VerifierRejects_Reverts() public {
        taskManager.setRevert(true);
        vm.expectRevert(bytes("bad signature"));
        _commit();
    }

    /* ADMIN */

    function test_SetThreshold_OnlyCoordinatorOwner() public {
        vm.prank(admin);
        taskManager.setThreshold(5000);
        assertEq(taskManager.thresholdBps(), 5000);
    }

    function test_SetThreshold_NotOwner_Reverts() public {
        vm.expectRevert();
        taskManager.setThreshold(5000);
    }

    function test_SetThreshold_OutOfRange_Reverts() public {
        vm.startPrank(admin);
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_InvalidThreshold.selector);
        taskManager.setThreshold(0);
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_InvalidThreshold.selector);
        taskManager.setThreshold(10_001);
        vm.stopPrank();
    }

    function test_SetQuorumNumbers_Empty_Reverts() public {
        vm.prank(admin);
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_EmptyQuorumNumbers.selector);
        taskManager.setQuorumNumbers("");
    }
}
