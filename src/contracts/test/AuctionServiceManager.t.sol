// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.27;

// import {Test} from "forge-std/Test.sol";
// import {ERC1967Proxy} from
//     "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import {IECDSAStakeRegistryTypes} from
//     "eigenlayer-middleware/src/interfaces/IECDSAStakeRegistry.sol";
// import {ECDSAStakeRegistryEqualWeight} from
//     "eigenlayer-middleware/src/unaudited/examples/ECDSAStakeRegistryEqualWeight.sol";
// import {IDelegationManager} from
//     "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
// import {IAVSDirectory} from
//     "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
// import {ISignatureUtilsMixinTypes} from
//     "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";
// import {PoolId} from "v4-core/types/PoolId.sol";

// import {AuctionServiceManager} from "../src/AuctionServiceManager.sol";
// import {IAuctionServiceManager, AuctionResult} from "../src/interfaces/IAuctionServiceManager.sol";
// import {ErrorsLib} from "../src/libraries/ErrorsLib.sol";
// import {EventsLib} from "../src/libraries/EventsLib.sol";

// /// @notice Fork test suite for AuctionServiceManager.
// /// Requires env var HOLESKY_RPC_URL pointing to a Holesky RPC endpoint.
// /// Run with: forge test --match-contract AuctionServiceManagerTest --fork-url $HOLESKY_RPC_URL
// contract AuctionServiceManagerTest is Test {
//     // ─── Holesky EigenLayer addresses ────────────────────────────────────────
//     address constant DELEGATION_MANAGER = 0xA44151489861Fe9e3055d95adC98FbD462B948e7;
//     address constant AVS_DIRECTORY       = 0x055733000064333CaDDbC92763c58BF0192fFeBf;
//     address constant REWARDS_COORDINATOR = 0xAcc1fb458a1317E886dB376Fc8141540537E68fE;

//     // ─── Test state ───────────────────────────────────────────────────────────
//     AuctionServiceManager asm;
//     ECDSAStakeRegistryEqualWeight registry;
//     PoolId poolId;
//     address winner;

//     uint256 constant BID = 1 ether;

//     // Operator signing keys and their derived addresses.
//     uint256 op1Key = 0xA11CE;
//     uint256 op2Key = 0xB0B;
//     uint256 op3Key = 0xCAFE;
//     address op1;
//     address op2;
//     address op3;

//     // ─── Setup ────────────────────────────────────────────────────────────────

//     function setUp() public {
//         // This test suite requires a Holesky fork.
//         if (vm.envOr("HOLESKY_RPC_URL", bytes("")).length == 0) {
//             vm.skip(true);
//         }

//         poolId  = PoolId.wrap(bytes32(uint256(1)));
//         winner  = makeAddr("winner");

//         op1 = vm.addr(op1Key);
//         op2 = vm.addr(op2Key);
//         op3 = vm.addr(op3Key);

//         _deployContracts();
//         _registerOperators();

//         // Advance one block so referenceBlock < block.number is satisfiable.
//         vm.roll(block.number + 1);
//     }

//     /* TEST HELPERS */

//     /// @dev Deploys the ECDSAStakeRegistryEqualWeight + AuctionServiceManager proxy pair.
//     ///      Addresses form a circular dependency so we predict the registry proxy address
//     ///      before deploying the ASM implementation.
//     function _deployContracts() internal {
//         // 1. Deploy registry implementation.
//         ECDSAStakeRegistryEqualWeight registryImpl =
//             new ECDSAStakeRegistryEqualWeight(IDelegationManager(DELEGATION_MANAGER));

//         // 2. Deploy ASM implementation (registry proxy address computed below).
//         //    nonce+1 == registryProxy (deployed two steps later).
//         address predictedRegistryProxy =
//             vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 2);

//         AuctionServiceManager asmImpl = new AuctionServiceManager(
//             AVS_DIRECTORY,
//             predictedRegistryProxy,
//             REWARDS_COORDINATOR,
//             DELEGATION_MANAGER,
//             address(0), // AllocationManager not on Holesky pre-slashing
//             address(0)  // PermissionController not on Holesky pre-slashing
//         );

//         // 3. Deploy ASM proxy and initialise.
//         bytes memory asmInit =
//             abi.encodeCall(AuctionServiceManager.initialize, (address(this), address(this)));
//         ERC1967Proxy asmProxy = new ERC1967Proxy(address(asmImpl), asmInit);
//         asm = AuctionServiceManager(address(asmProxy));

//         // 4. Deploy registry proxy with ASM address; this lands at predictedRegistryProxy.
//         IECDSAStakeRegistryTypes.Quorum memory quorum; // empty — equal-weight ignores strategies
//         bytes memory regInit = abi.encodeCall(
//             registryImpl.initialize, (address(asm), 6667, quorum) // 66.67 % = 2-of-3
//         );
//         ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryImpl), regInit);
//         registry = ECDSAStakeRegistryEqualWeight(address(registryProxy));

//         require(address(registry) == predictedRegistryProxy, "registry proxy address mismatch");
//     }

//     /// @dev Registers three operators in EigenLayer DelegationManager and then in our registry.
//     function _registerOperators() internal {
//         IDelegationManager dm = IDelegationManager(DELEGATION_MANAGER);
//         IAVSDirectory avsd     = IAVSDirectory(AVS_DIRECTORY);

//         address[3] memory ops = [op1, op2, op3];
//         uint256[3] memory keys = [op1Key, op2Key, op3Key];

//         for (uint256 i = 0; i < 3; i++) {
//             address op = ops[i];
//             uint256 key = keys[i];

//             // Register as EigenLayer operator (no stake required).
//             vm.prank(op);
//             dm.registerAsOperator(address(0), 0, "");

//             // Build the EIP-712 registration signature for the AVSDirectory.
//             bytes32 digestHash = avsd.calculateOperatorAVSRegistrationDigestHash(
//                 op, address(asm), bytes32(uint256(i + 1)), type(uint256).max
//             );
//             (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digestHash);
//             ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry memory operatorSig =
//                 ISignatureUtilsMixinTypes.SignatureWithSaltAndExpiry({
//                     signature: abi.encodePacked(r, s, v),
//                     salt: bytes32(uint256(i + 1)),
//                     expiry: type(uint256).max
//                 });

//             // Register with the stake registry (signing key == operator address).
//             vm.prank(op);
//             registry.registerOperatorWithSignature(operatorSig, op);
//         }
//     }

//     /// @dev Produces a sorted (ascending) pair of operator addresses with their commitWinner
//     ///      signatures. Sorting is required by the registry's _validateSortedSigners check.
//     function _buildQuorum(uint256 targetBlock)
//         internal
//         view
//         returns (address[] memory signers, bytes[] memory sigs, uint32 referenceBlock)
//     {
//         // Use block.number - 1 as referenceBlock (must be strictly less than current block).
//         referenceBlock = uint32(block.number - 1);

//         bytes32 digest = keccak256(abi.encodePacked(poolId, targetBlock, winner, BID));

//         // Sign with op1 and op2 (2-of-3 satisfies the 66.67 % threshold).
//         (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(op1Key, digest);
//         (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(op2Key, digest);

//         // Sort signers by address so the registry's ascending check passes.
//         if (op1 < op2) {
//             signers = new address[](2);
//             sigs    = new bytes[](2);
//             signers[0] = op1; sigs[0] = abi.encodePacked(r1, s1, v1);
//             signers[1] = op2; sigs[1] = abi.encodePacked(r2, s2, v2);
//         } else {
//             signers = new address[](2);
//             sigs    = new bytes[](2);
//             signers[0] = op2; sigs[0] = abi.encodePacked(r2, s2, v2);
//             signers[1] = op1; sigs[1] = abi.encodePacked(r1, s1, v1);
//         }
//     }

//     /* CONSTRUCTOR / INITIALIZER TESTS */

//     function test_Initialize_Sets_Owner() public view {
//         assertEq(asm.owner(), address(this));
//     }

//     function test_Initialize_Sets_StakeRegistry() public view {
//         assertEq(asm.stakeRegistry(), address(registry));
//     }

//     /* COMMIT WINNER TESTS */

//     function test_commitWinner_TwoOfThree_Succeeds() public {
//         uint256 target = block.number;
//         (address[] memory signers, bytes[] memory sigs, uint32 refBlock) =
//             _buildQuorum(target);

//         asm.commitWinner(poolId, target, winner, BID, signers, sigs, refBlock);

//         AuctionResult memory r = asm.getWinner(poolId, target);
//         assertTrue(r.committed);
//         assertEq(r.winner, winner);
//         assertEq(r.bidAmount, BID);
//     }

//     function test_commitWinner_Emits_WinnerCommitted() public {
//         uint256 target = block.number;
//         (address[] memory signers, bytes[] memory sigs, uint32 refBlock) =
//             _buildQuorum(target);

//         vm.expectEmit(address(asm));
//         emit EventsLib.WinnerCommitted(poolId, target, winner, BID);
//         asm.commitWinner(poolId, target, winner, BID, signers, sigs, refBlock);
//     }

//     function test_commitWinner_Reverts_When_QuorumNotMet_OneSig() public {
//         uint256 target = block.number;
//         uint32 refBlock = uint32(block.number - 1);
//         bytes32 digest  = keccak256(abi.encodePacked(poolId, target, winner, BID));
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(op1Key, digest);

//         address[] memory signers = new address[](1);
//         bytes[] memory sigs      = new bytes[](1);
//         signers[0] = op1;
//         sigs[0]    = abi.encodePacked(r, s, v);

//         vm.expectRevert(ErrorsLib.AuctionServiceManager_QuorumNotMet.selector);
//         asm.commitWinner(poolId, target, winner, BID, signers, sigs, refBlock);
//     }

//     function test_commitWinner_Reverts_When_Stale_Block() public {
//         vm.roll(block.number + 5);
//         uint256 staleBlock = block.number - 4;

//         (address[] memory signers, bytes[] memory sigs, uint32 refBlock) =
//             _buildQuorum(staleBlock);

//         vm.expectRevert(ErrorsLib.AuctionServiceManager_StaleBlock.selector);
//         asm.commitWinner(poolId, staleBlock, winner, BID, signers, sigs, refBlock);
//     }

//     function test_commitWinner_Reverts_When_Already_Committed() public {
//         uint256 target = block.number;
//         (address[] memory signers, bytes[] memory sigs, uint32 refBlock) =
//             _buildQuorum(target);

//         asm.commitWinner(poolId, target, winner, BID, signers, sigs, refBlock);

//         vm.expectRevert(ErrorsLib.AuctionServiceManager_AlreadyCommitted.selector);
//         asm.commitWinner(poolId, target, winner, BID, signers, sigs, refBlock);
//     }

//     function test_commitWinner_Reverts_When_Zero_Winner() public {
//         uint256 target = block.number;
//         (address[] memory signers, bytes[] memory sigs, uint32 refBlock) =
//             _buildQuorum(target);

//         vm.expectRevert(ErrorsLib.AuctionServiceManager_ZeroWinner.selector);
//         asm.commitWinner(poolId, target, address(0), BID, signers, sigs, refBlock);
//     }

//     function test_commitWinner_Reverts_When_Sigs_For_Wrong_Bid() public {
//         uint256 target = block.number;
//         // Operators signed for BID; caller submits BID + 1 → digest mismatch → quorum fails.
//         (address[] memory signers, bytes[] memory sigs, uint32 refBlock) =
//             _buildQuorum(target);

//         vm.expectRevert(ErrorsLib.AuctionServiceManager_QuorumNotMet.selector);
//         asm.commitWinner(poolId, target, winner, BID + 1, signers, sigs, refBlock);
//     }

//     /* GET WINNER TESTS */

//     function test_getWinner_Returns_Empty_When_Not_Committed() public view {
//         AuctionResult memory r = asm.getWinner(poolId, block.number);
//         assertFalse(r.committed);
//         assertEq(r.winner, address(0));
//         assertEq(r.bidAmount, 0);
//     }
// }
