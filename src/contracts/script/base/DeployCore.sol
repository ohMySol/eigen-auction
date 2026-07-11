// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IPermissionController} from "eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {VetoableSlasher} from "eigenlayer-middleware/src/slashers/VetoableSlasher.sol";
import {IVetoableSlasher} from "eigenlayer-middleware/src/interfaces/IVetoableSlasher.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {EigenAuctionServiceManager} from "../../src/EigenAuctionServiceManager.sol";
import {EigenAuctionHook} from "../../src/EigenAuctionHook.sol";
import {Settler} from "../../src/Settler.sol";
import {EigenAuctionTaskManager} from "../../src/EigenAuctionTaskManager.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";
import {ConfigLib, NetworkConfig, Deployment} from "../libs/ConfigLib.sol";
import {DeployMiddleware} from "./DeployMiddleware.sol";

/// @title DeployCore
/// @author ohMySol
/// @notice Shared, config-driven deployment logic for the AVS-secured LVR auction.
/// Concrete scripts (`Deploy`, `DeployTestnet`) inherit this and differ only in how the token pair is sourced 
/// and whether demo liquidity is seeded — every address comes from `config/networks/<chainId>.json`, so there are no chain-specific branches here.
///
/// Broadcast scoping is the caller's responsibility: wrap `_deployProtocol`/pool-init in the deployer's
/// `vm.startBroadcast(deployerPk)` and `_registerOperator` in the operator's broadcast.
abstract contract DeployCore is DeployMiddleware {
    using PoolIdLibrary for PoolKey;

    /// @notice The protocol + middleware contracts produced by a deployment.
    struct ProtocolContracts {
        EigenAuctionServiceManager avs;
        EigenAuctionHook hook;
        Settler settler;
        EigenAuctionTaskManager taskManager;
        VetoableSlasher vetoableSlasher;
        ISlashingRegistryCoordinator registryCoordinator;
        // Registry sub-addresses the off-chain aggregator binds to (BLS pubkeys, stake, sig indices).
        address stakeRegistry;
        address blsApkRegistry;
        address operatorStateRetriever;
    }

    /// @dev Hook permission flags this hook encodes in its address. Must exactly equal
    /// EigenAuctionHook.getHookPermissions(), or the hook constructor's validateHookPermissions reverts
    /// inside the CREATE2 deploy (the mined address bits would satisfy the wrong permission set).
    uint160 constant HOOK_FLAGS = uint160(
        Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
        Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
        Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
        Hooks.BEFORE_SWAP_FLAG |
        Hooks.AFTER_SWAP_FLAG |
        Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
    );

    /// @dev Deploys the full stack — BLS middleware (coordinator + registries), AVS proxy, mined-address
    /// hook, Settler, TaskManager, and the VetoableSlasher/EigenAuctionSlasher pair — and wires them:
    /// the coordinator becomes the AVS registrar, the single slashable quorum is created, and the hook,
    /// AVS, and TaskManager are all pointed at the Settler. Must run inside the deployer's broadcast; the
    /// deployer becomes the AVS/hook/coordinator owner and the slasher's veto committee.
    function _deployProtocol(NetworkConfig memory config, address owner) internal returns (ProtocolContracts memory protocol) {
        // 1. BLS middleware stack (coordinator proxy live but not yet initialized).
        RegistryStack memory rs = _deployRegistryStack(config, owner);
        protocol.registryCoordinator = ISlashingRegistryCoordinator(address(rs.coordinator));
        protocol.stakeRegistry = address(rs.stakeRegistry);
        protocol.blsApkRegistry = address(rs.blsApkRegistry);
        protocol.operatorStateRetriever = address(rs.operatorStateRetriever);

        // 2. AVS wired to the coordinator + stake registry; coordinator init needs the AVS address.
        protocol.avs = _deployAvs(config, owner, address(rs.coordinator), address(rs.stakeRegistry));
        _initRegistryCoordinator(rs, owner, address(protocol.avs));

        // 3. Hook (mined CREATE2 address), TaskManager, and the Settler the three contracts gate on.
        protocol.hook = _deployHook(config.poolManager, address(protocol.avs), owner);
        protocol.taskManager = _deployTaskManager(
            rs,
            config.threshold,
            uint8(ConstantsLib.OPERATOR_SET_ID),
            ConstantsLib.OPERATOR_SET_ID
        );
        protocol.settler = new Settler(
            config.poolManager,
            address(protocol.avs),
            address(protocol.taskManager),
            owner,
            ConstantsLib.DEFAULT_OPERATOR_FEE_BPS
        );
        protocol.hook.setSettler(address(protocol.settler));
        protocol.avs.setSettler(address(protocol.settler));
        protocol.taskManager.setSettler(address(protocol.settler));

        // 4. Slashing config on TaskManager + VetoableSlasher whose authorizedSlasher is TaskManager.
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(config.stakeStrategy);
        protocol.taskManager.setSlashingConfig(strategies, SLASH_WAD);

        protocol.vetoableSlasher = new VetoableSlasher(
            IAllocationManager(config.allocationManager),
            IStrategyManager(config.strategyManager),
            ISlashingRegistryCoordinator(address(rs.coordinator)),
            address(protocol.taskManager),
            owner,
            VETO_WINDOW_BLOCKS
        );
        protocol.taskManager.setVetoableSlasher(IVetoableSlasher(address(protocol.vetoableSlasher)));

        // 5. AVS identity + operator set: metadata, coordinator-as-registrar, slashable quorum 0.
        protocol.avs.registerAvsMetadata("https://eigen-auction.local/avs.json");
        _configureOperatorSet(config, rs, protocol.avs, protocol.vetoableSlasher, owner);
    }

    /// @dev Assembles the PoolKey from config + a resolved token pair and the deployed hook.
    function _poolKey(
        NetworkConfig memory config, 
        address hook, 
        Currency currency0, 
        Currency currency1
    ) internal pure returns (PoolKey memory) {
        return PoolKey({
            currency0: currency0, 
            currency1: currency1, 
            fee: config.fee, 
            tickSpacing: config.tickSpacing, 
            hooks: IHooks(hook)
        });
    }

    /// @dev Ensures `operator` is a registered EigenLayer operator (the prerequisite for joining the
    /// AVS). Must run inside the operator's broadcast. On a mainnet fork the operator may already be
    /// registered (mainnet state is preserved); the guard skips re-registration so the script doesn't
    /// revert with `ActivelyDelegated`.
    ///
    /// Operator-set membership in the BLS model is a `SlashingRegistryCoordinator` registration carrying
    /// the operator's BLS pubkey-registration params and signature, which are generated and submitted
    /// off-chain by the operator client (see the M6 off-chain components). It is intentionally not done
    /// here, where those params are unavailable.
    function _registerOperator(NetworkConfig memory config, address operator) internal {
        if (!IDelegationManager(config.delegationManager).isOperator(operator)) {
            IDelegationManager(config.delegationManager).registerAsOperator(address(0), 0, "");
        }
    }

    /// @dev Writes deployments/<chainId>.json — the single artifact the backend/frontend read — and logs
    /// the deployed addresses.
    function _writeDeployment(
        NetworkConfig memory config, 
        PoolKey memory key, 
        ProtocolContracts memory protocol, 
        uint8 decimals0, 
        uint8 decimals1
    ) internal {
        Deployment memory deployment = Deployment({
            chainId: block.chainid,
            poolManager: config.poolManager,
            stateView: config.stateView,
            serviceManager: address(protocol.avs),
            taskManager: address(protocol.taskManager),
            registryCoordinator: address(protocol.registryCoordinator),
            stakeRegistry: protocol.stakeRegistry,
            blsApkRegistry: protocol.blsApkRegistry,
            operatorStateRetriever: protocol.operatorStateRetriever,
            // EL core is referenced by address (not deployed by us) but the aggregator needs it for
            // operator-set registration, so it is echoed into the artifact from the network config.
            delegationManager: config.delegationManager,
            allocationManager: config.allocationManager,
            avsDirectory: config.avsDirectory,
            stakeStrategy: config.stakeStrategy,
            quorumNumbers: ConstantsLib.OPERATOR_SET_ID,
            hook: address(protocol.hook),
            settler: address(protocol.settler),
            currency0: Currency.unwrap(key.currency0),
            currency1: Currency.unwrap(key.currency1),
            currency0Decimals: decimals0,
            currency1Decimals: decimals1,
            fee: config.fee,
            tickSpacing: config.tickSpacing,
            poolId: PoolId.unwrap(key.toId()),
            deployedBlock: block.number
        });
        ConfigLib.writeDeployment(vm, deployment);

        console2.log("currency0: ", Currency.unwrap(key.currency0));
        console2.log("currency1: ", Currency.unwrap(key.currency1));
        console2.log("EigenAuctionServiceManager: ", address(protocol.avs));
        console2.log("EigenAuctionHook: ", address(protocol.hook));
        console2.log("Settler: ", address(protocol.settler));
        console2.log("EigenAuctionTaskManager: ", address(protocol.taskManager));
        console2.log("SlashingRegistryCoordinator: ", address(protocol.registryCoordinator));
        console2.log("VetoableSlasher: ", address(protocol.vetoableSlasher));
    }

    /* INTERNAL BUILDING BLOCKS */

    /// @dev Deploy the AVS implementation wired to the live EL core and this AVS's BLS registry stack,
    /// behind an initialised proxy.
    function _deployAvs(NetworkConfig memory config, address owner, address registryCoordinator, address stakeRegistry)
        internal
        returns (EigenAuctionServiceManager avs)
    {
        EigenAuctionServiceManager impl = new EigenAuctionServiceManager(
            IAVSDirectory(config.avsDirectory),
            IRewardsCoordinator(config.rewardsCoordinator),
            ISlashingRegistryCoordinator(registryCoordinator),
            IStakeRegistry(stakeRegistry),
            IPermissionController(config.permissionController),
            IAllocationManager(config.allocationManager)
        );
        bytes memory initData = abi.encodeCall(EigenAuctionServiceManager.initialize, (owner, owner));
        avs = EigenAuctionServiceManager(address(new ERC1967Proxy(address(impl), initData)));
    }

    /// @dev Mine a hook address carrying the required permission flags, then deploy via CREATE2.
    function _deployHook(address poolManager, address avs, address owner) internal returns (EigenAuctionHook hook) {
        bytes memory args = abi.encode(poolManager, avs, owner);
        (address hookAddr, bytes32 salt) = HookMiner.find(
            CREATE2_FACTORY, 
            HOOK_FLAGS, 
            type(EigenAuctionHook).creationCode, 
            args
        );

        hook = new EigenAuctionHook{salt: salt}(poolManager, avs, owner);

        require(address(hook) == hookAddr, "DeployCore: hook address mismatch");
    }
}
