// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";

import {IVetoableSlasher} from "eigenlayer-middleware/src/interfaces/IVetoableSlasher.sol";
import {IAllocationManagerTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

import {EigenAuctionTaskManager} from "../../src/EigenAuctionTaskManager.sol";
import {Commitment} from "../../src/types/Commitment.sol";
import {ToBOrder, toBStructHash} from "../../src/types/ToBOrder.sol";

import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";
import {EventsLib} from "../../src/libraries/EventsLib.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";

/// @dev Returns a fixed EIP-712 domain so challenge tests can sign ToBOrders the TaskManager accepts.
contract MockSettlerDomain {
    bytes32 public immutable DOMAIN_SEPARATOR;

    constructor(bytes32 d) {
        DOMAIN_SEPARATOR = d;
    }
}

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
    address public immutable indexRegistry;
    address public immutable blsApkRegistry;

    constructor(address _owner, address _stakeRegistry, address _indexRegistry, address _blsApkRegistry) {
        owner = _owner;
        stakeRegistry = _stakeRegistry;
        indexRegistry = _indexRegistry;
        blsApkRegistry = _blsApkRegistry;
    }
}

/// @dev Returns a fixed operator list for any (quorum, block). Only the selector the TaskManager calls
/// is implemented.
contract MockIndexRegistry {
    bytes32[] private _list;

    function setList(bytes32[] calldata list) external { _list = list; }

    function getOperatorListAtBlockNumber(uint8, uint32) external view returns (bytes32[] memory) {
        return _list;
    }
}

/// @dev Two-way map between operator ids (pubkey hashes) and addresses.
contract MockBlsApkRegistry {
    mapping(bytes32 => address) public idToOperator;
    mapping(address => bytes32) public operatorToId;

    function set(bytes32 id, address operator) external {
        idToOperator[id] = operator;
        operatorToId[operator] = id;
    }

    function getOperatorId(address operator) external view returns (bytes32) { return operatorToId[operator]; }
    function getOperatorFromPubkeyHash(bytes32 id) external view returns (address) { return idToOperator[id]; }
}

/// @dev Records every queued slashing request so tests can assert who was slashed.
contract MockVetoableSlasher {
    address[] public queuedOperators;
    uint256[] public lastWads;

    function queueSlashingRequest(IAllocationManagerTypes.SlashingParams calldata params) external {
        queuedOperators.push(params.operator);
        if (params.wadsToSlash.length != 0) lastWads.push(params.wadsToSlash[0]);
    }

    function count() external view returns (uint256) { return queuedOperators.length; }
}

/// @dev Test seam: replaces the real aggregate-signature verification with canned stake totals so the
/// task manager's own threshold/replay/staleness/access logic can be tested in isolation.
contract TaskManagerHarness is EigenAuctionTaskManager {
    uint96[] private _signed;
    uint96[] private _total;
    bytes32 public recordHash = keccak256("signatory-record");
    bool public reverts;

    function setRecordHash(bytes32 h) external { recordHash = h; }

    constructor(ISlashingRegistryCoordinator rc, bytes memory q, uint256 t) EigenAuctionTaskManager(rc, q, t, 0, 1) {}

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

    MockVetoableSlasher mockVeto;
    MockIndexRegistry mockIndex;
    MockBlsApkRegistry mockApk;
    MockSettlerDomain settlerDomain;
    uint256 constant SEARCHER_PK = 0x5EA6C6;
    bytes32 constant DOMAIN = keccak256("EigenAuction Settler test domain");
    bytes32 constant INTENTS_ROOT = keccak256("intents");
    uint256 constant PRICE = 1 << 128;
    uint32 constant REF_BLOCK = 99;

    /// @dev Sample non-signer pubkey hashes forwarded through `challenge` to the slasher seam.
    function _nonSigners() internal pure returns (bytes32[] memory hashes) {
        hashes = new bytes32[](2);
        hashes[0] = bytes32(uint256(0xA));
        hashes[1] = bytes32(uint256(0xB));
    }

    function setUp() public {
        mockIndex = new MockIndexRegistry();
        mockApk = new MockBlsApkRegistry();
        MockStakeRegistry stakeReg = new MockStakeRegistry();
        MockRegistryCoordinator coordinator = new MockRegistryCoordinator(
            admin, address(stakeReg), address(mockIndex), address(mockApk)
        );
        taskManager =
            new TaskManagerHarness(ISlashingRegistryCoordinator(address(coordinator)), hex"00", THRESHOLD_BPS);

        vm.roll(100); // move off genesis so a past reference block exists
        _setStakes(66, 100); // exactly meets 66%

        mockVeto = new MockVetoableSlasher();
        settlerDomain = new MockSettlerDomain(DOMAIN);

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(makeAddr("strategy"));

        vm.startPrank(admin);
        taskManager.setVetoableSlasher(IVetoableSlasher(address(mockVeto)));
        taskManager.setSlashingConfig(strategies, 5e17);
        taskManager.setSettler(address(settlerDomain));
        vm.stopPrank();
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

    // An unsigned committed arb (only its struct hash matters for the commitment).
    function _committedArb(bool zeroForOne, uint128 qtyIn, uint128 qtyOut)
        internal
        view
        returns (ToBOrder memory o)
    {
        o = ToBOrder({
            searcher: vm.addr(SEARCHER_PK),
            poolId: PoolId.unwrap(poolId),
            zeroForOne: zeroForOne,
            useInternal: false,
            quantityIn: qtyIn,
            quantityOut: qtyOut,
            validForBlock: uint64(block.number),
            signature: ""
        });
    }

    // A searcher-signed dominant order under the mock Settler domain.
    function _signedOrder(bool zeroForOne, uint128 qtyIn, uint128 qtyOut, uint64 validForBlock)
        internal
        view
        returns (ToBOrder memory o)
    {
        o = ToBOrder({
            searcher: vm.addr(SEARCHER_PK),
            poolId: PoolId.unwrap(poolId),
            zeroForOne: zeroForOne,
            useInternal: false,
            quantityIn: qtyIn,
            quantityOut: qtyOut,
            validForBlock: validForBlock,
            signature: ""
        });
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", DOMAIN, toBStructHash(o)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SEARCHER_PK, digest);
        o.signature = abi.encodePacked(r, s, v);
    }

    function _resultHash(ToBOrder memory arb) internal pure returns (bytes32) {
        return keccak256(abi.encode(toBStructHash(arb), PRICE, INTENTS_ROOT));
    }

    // Commit a result over `committedArb` so it can be challenged.
    function _commitArb(ToBOrder memory committedArb) internal {
        taskManager.commitWinner(
            poolId, block.number, _resultHash(committedArb), executor, uint32(block.number - 1), QUORUMS, _emptySig()
        );
    }

    /* COMMIT */

    function test_Commit_StoresCommitment() public {
        _commit();
        Commitment memory c = taskManager.getCommitment(poolId, block.number);
        assertTrue(c.exists);
        assertEq(c.resultHash, RESULT_HASH);
        assertEq(c.executor, executor);
        assertEq(c.hashOfNonSigners, taskManager.recordHash());
    }

    function test_Commit_StartsUnchallenged() public {
        _commit();
        assertFalse(taskManager.getCommitment(poolId, block.number).challenged);
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

    function test_SetVetoableSlasher_OnlyCoordinatorOwner() public {
        address newVeto = makeAddr("veto2");
        vm.prank(admin);
        taskManager.setVetoableSlasher(IVetoableSlasher(newVeto));
        assertEq(address(taskManager.vetoableSlasher()), newVeto);
    }

    function test_SetVetoableSlasher_NotOwner_Reverts() public {
        vm.expectRevert();
        taskManager.setVetoableSlasher(IVetoableSlasher(makeAddr("veto2")));
    }

    function test_SetSlashingConfig_OnlyCoordinatorOwner() public {
        IStrategy[] memory s = new IStrategy[](1);
        s[0] = IStrategy(makeAddr("s2"));
        vm.prank(admin);
        taskManager.setSlashingConfig(s, 1e18);
        assertEq(taskManager.wadToSlash(), 1e18);
        assertEq(taskManager.strategies().length, 1);
    }

    function test_SetSlashingConfig_NotOwner_Reverts() public {
        IStrategy[] memory s = new IStrategy[](1);
        s[0] = IStrategy(makeAddr("s2"));
        vm.expectRevert();
        taskManager.setSlashingConfig(s, 1e18);
    }

    function test_SetSlashingConfig_InvalidConfig_Reverts() public {
        vm.startPrank(admin);
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_InvalidSlashingConfig.selector);
        taskManager.setSlashingConfig(new IStrategy[](0), 5e17);
        IStrategy[] memory s = new IStrategy[](1);
        s[0] = IStrategy(makeAddr("s"));
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_InvalidSlashingConfig.selector);
        taskManager.setSlashingConfig(s, 0);
        vm.stopPrank();
    }

    function test_SetSettler_OnlyCoordinatorOwner() public {
        address newSettler = makeAddr("settler2");
        vm.prank(admin);
        taskManager.setSettler(newSettler);
        assertEq(taskManager.settler(), newSettler);
    }

    /* CHALLENGE */

    function test_Challenge_Succeeds_MarksAndQueuesSlash() public {
        // Set recordHash BEFORE commit so commitment stores a hash we can reproduce at challenge time.
        bytes32[] memory nonSigners = _nonSigners();
        taskManager.setRecordHash(keccak256(abi.encodePacked(REF_BLOCK, nonSigners)));

        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);

        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));

        vm.expectEmit(true, true, true, false);
        emit EventsLib.CommitmentChallenged(poolId, block.number, address(this));
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, nonSigners);

        assertTrue(taskManager.getCommitment(poolId, block.number).challenged);
        // mockIndex returns empty list by default → signerCount == 0 but the path was taken.
        assertEq(mockVeto.count(), 0);
    }

    function test_Challenge_NoCommitment_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_NoCommitment.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, _nonSigners());
    }

    function test_Challenge_ResultMismatch_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        // Wrong intentsRoot -> reconstructed result hash won't match.
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_ResultMismatch.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, keccak256("other"), dominant, REF_BLOCK, _nonSigners());
    }

    function test_Challenge_OrderMismatch_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        // Opposite direction.
        ToBOrder memory dominant = _signedOrder(false, 1.2e18, 1e18, uint64(block.number));
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_OrderMismatch.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, _nonSigners());
    }

    function test_Challenge_NotDominant_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        // Equal terms -> not strictly dominant.
        ToBOrder memory dominant = _signedOrder(true, 1e18, 1e18, uint64(block.number));
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_NotDominant.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, _nonSigners());
    }

    function test_Challenge_BadSignature_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        dominant.signature = abi.encodePacked(uint256(1), uint256(2), uint8(27)); // garbage 65 bytes
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_InvalidOrderSignature.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, _nonSigners());
    }

    function test_Challenge_WindowClosed_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        uint256 committedBlock = block.number;
        vm.roll(committedBlock + ConstantsLib.CHALLENGE_WINDOW + 1);
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_ChallengeWindowClosed.selector);
        taskManager.challenge(poolId, committedBlock, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, _nonSigners());
    }

    function test_Challenge_Twice_Reverts() public {
        bytes32[] memory nonSigners = _nonSigners();
        // Set recordHash BEFORE commit so the first challenge can pass the hash check.
        taskManager.setRecordHash(keccak256(abi.encodePacked(REF_BLOCK, nonSigners)));
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, nonSigners);
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_AlreadyChallenged.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, nonSigners);
    }

    function test_Challenge_NoSlasher_StillMarks() public {
        vm.prank(admin);
        taskManager.setVetoableSlasher(IVetoableSlasher(address(0)));
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        // Slasher is disabled so _queueSlashing is skipped; no hash matching needed.
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, _nonSigners());
        assertTrue(taskManager.getCommitment(poolId, block.number).challenged);
    }

    function test_Challenge_SignatoryRecordMismatch_Reverts() public {
        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        // Supply nonSigners that don't reproduce the stored hashOfNonSigners.
        bytes32[] memory wrong = new bytes32[](1);
        wrong[0] = bytes32(uint256(0xDEAD));
        vm.expectRevert(ErrorsLib.EigenAuctionTaskManager_SignatoryRecordMismatch.selector);
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, wrong);
    }

    function test_Challenge_QueuesSlashForSigners() public {
        // Operator universe: ID1, ID2 are signers; ID3 is non-signer; ID_EXEC is the executor.
        bytes32 ID1 = bytes32(uint256(0x11));
        bytes32 ID2 = bytes32(uint256(0x22));
        bytes32 ID3 = bytes32(uint256(0x33));
        bytes32 ID_EXEC = bytes32(uint256(0xEE));
        address op1 = makeAddr("op1");
        address op2 = makeAddr("op2");
        address op3 = makeAddr("op3");

        bytes32[] memory fullSet = new bytes32[](4);
        fullSet[0] = ID1; fullSet[1] = ID2; fullSet[2] = ID3; fullSet[3] = ID_EXEC;
        mockIndex.setList(fullSet);
        mockApk.set(ID1, op1);
        mockApk.set(ID2, op2);
        mockApk.set(ID3, op3);
        mockApk.set(ID_EXEC, executor);

        bytes32[] memory nonSigners = new bytes32[](1);
        nonSigners[0] = ID3;

        // Set recordHash BEFORE commit so the commitment stores a hash we can reproduce at challenge.
        taskManager.setRecordHash(keccak256(abi.encodePacked(REF_BLOCK, nonSigners)));

        ToBOrder memory committed = _committedArb(true, 1e18, 1e18);
        _commitArb(committed);
        ToBOrder memory dominant = _signedOrder(true, 1.2e18, 1e18, uint64(block.number));
        taskManager.challenge(poolId, block.number, committed, PRICE, INTENTS_ROOT, dominant, REF_BLOCK, nonSigners);

        // ID3 is non-signer, ID_EXEC is executor → only op1 and op2 queued.
        assertEq(mockVeto.count(), 2);
        assertEq(mockVeto.queuedOperators(0), op1);
        assertEq(mockVeto.queuedOperators(1), op2);
        assertEq(mockVeto.lastWads(0), 5e17);
    }
}
