// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {EmptyContract} from "eigenlayer-contracts/src/test/mocks/EmptyContract.sol";
import {PauserRegistry} from "eigenlayer-contracts/src/contracts/permissions/PauserRegistry.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IAVSRegistrar} from "eigenlayer-contracts/src/contracts/interfaces/IAVSRegistrar.sol";

import {StakeRegistry} from "eigenlayer-middleware/src/StakeRegistry.sol";
import {BLSApkRegistry} from "eigenlayer-middleware/src/BLSApkRegistry.sol";
import {IndexRegistry} from "eigenlayer-middleware/src/IndexRegistry.sol";
import {SocketRegistry} from "eigenlayer-middleware/src/SocketRegistry.sol";
import {OperatorStateRetriever} from "eigenlayer-middleware/src/OperatorStateRetriever.sol";
import {SlashingRegistryCoordinator} from "eigenlayer-middleware/src/SlashingRegistryCoordinator.sol";
import {VetoableSlasher} from "eigenlayer-middleware/src/slashers/VetoableSlasher.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {ISlashingRegistryCoordinatorTypes} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistryTypes} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";

import {EigenAuctionTaskManager} from "../../src/EigenAuctionTaskManager.sol";
import {EigenAuctionServiceManager} from "../../src/EigenAuctionServiceManager.sol";
import {ConstantsLib} from "../../src/libraries/ConstantsLib.sol";
import {NetworkConfig} from "../libs/ConfigLib.sol";

/// @title DeployMiddleware
/// @author ohMySol
/// @notice Deploys and wires the per-AVS BLS middleware stack the EigenAuction protocol owns:
/// the `SlashingRegistryCoordinator` (+ its stake/BLS/index/socket registries), the
/// `EigenAuctionTaskManager`, and the `VetoableSlasher` + `EigenAuctionSlasher` pair.
///
/// @dev The coordinator and its registries are a circular constructor dependency (each takes the other),
/// resolved with the standard EigenLayer pattern: deploy the coordinator behind a transparent proxy
/// pointed at an empty placeholder, deploy the registries against that proxy address, deploy the
/// coordinator implementation against the registries, then upgrade + initialize the proxy. The AVS
/// address is only known after the registries exist, so coordinator initialization is deferred until
/// the consumer (`DeployCore`) has deployed the `EigenAuctionServiceManager`. All admin calls assume the
/// broadcasting deployer is the AVS owner, the coordinator owner, and the veto committee key holder.
abstract contract DeployMiddleware is Script {
    /* DEPLOY PARAMETERS */

    /// @dev Coordinator semantic version tag (informational, surfaced by SemVerMixin).
    string internal constant MIDDLEWARE_VERSION = "v1.0.0";

    /// @dev Blocks the veto committee has to cancel a queued slashing request.
    uint32 internal constant VETO_WINDOW_BLOCKS = 50;

    /// @dev Maximum operators admitted to the single quorum.
    uint32 internal constant MAX_OPERATOR_COUNT = 50;

    /// @dev Stake multiplier applied to the slashable strategy in the quorum (1e18 = 1x weight).
    uint96 internal constant STRATEGY_MULTIPLIER = 1e18;

    /// @dev Minimum stake (in the quorum's weighted units) required to join the operator set.
    uint96 internal constant MIN_OPERATOR_STAKE = 0;

    /// @dev Slashable-stake lookahead, in blocks. Zero matches the same-block commit+settle model.
    uint32 internal constant QUORUM_LOOK_AHEAD = 0;

    /// @dev Per-strategy slash fraction queued on a proven fault (1e18 = 100%).
    uint256 internal constant SLASH_WAD = 5e17;

    /// @notice The deployed BLS middleware contracts.
    struct RegistryStack {
        ProxyAdmin proxyAdmin;
        PauserRegistry pauserRegistry;
        SlashingRegistryCoordinator coordinator; // transparent proxy
        SlashingRegistryCoordinator coordinatorImpl;
        StakeRegistry stakeRegistry;
        BLSApkRegistry blsApkRegistry;
        IndexRegistry indexRegistry;
        SocketRegistry socketRegistry;
        OperatorStateRetriever operatorStateRetriever;
    }

    /* REGISTRY STACK */

    /// @dev Deploys the registry coordinator (uninitialized, behind a proxy) and its registries. The
    /// coordinator must be initialized later via `_initRegistryCoordinator`, once the AVS exists.
    function _deployRegistryStack(NetworkConfig memory config, address owner)
        internal
        returns (RegistryStack memory rs)
    {
        rs.proxyAdmin = new ProxyAdmin();

        address[] memory pausers = new address[](1);
        pausers[0] = owner;
        rs.pauserRegistry = new PauserRegistry(pausers, owner);

        // Placeholder implementation so the proxy has code while the registries are deployed against
        // its (already-final) address; upgraded to the real implementation in `_initRegistryCoordinator`.
        EmptyContract empty = new EmptyContract();
        rs.coordinator = SlashingRegistryCoordinator(
            address(new TransparentUpgradeableProxy(address(empty), address(rs.proxyAdmin), ""))
        );

        ISlashingRegistryCoordinator rc = ISlashingRegistryCoordinator(address(rs.coordinator));
        rs.stakeRegistry = new StakeRegistry(
            rc,
            IDelegationManager(config.delegationManager),
            IAVSDirectory(config.avsDirectory),
            IAllocationManager(config.allocationManager)
        );
        rs.blsApkRegistry = new BLSApkRegistry(rc);
        rs.indexRegistry = new IndexRegistry(rc);
        rs.socketRegistry = new SocketRegistry(rc);
        rs.operatorStateRetriever = new OperatorStateRetriever();

        rs.coordinatorImpl = new SlashingRegistryCoordinator(
            rs.stakeRegistry,
            rs.blsApkRegistry,
            rs.indexRegistry,
            rs.socketRegistry,
            IAllocationManager(config.allocationManager),
            rs.pauserRegistry,
            MIDDLEWARE_VERSION
        );
    }

    /// @dev Upgrades the coordinator proxy to its implementation and initializes it, binding it to the
    /// AVS. `owner` becomes the coordinator owner, churn approver, and ejector.
    function _initRegistryCoordinator(RegistryStack memory rs, address owner, address avs) internal {
        rs.proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(rs.coordinator)),
            address(rs.coordinatorImpl),
            abi.encodeCall(SlashingRegistryCoordinator.initialize, (owner, owner, owner, 0, avs))
        );
    }

    /* TASK MANAGER + SLASHER */

    /// @dev Deploys the task manager bound to the coordinator, with the single configured quorum,
    /// stake threshold, and slashing operator-set params.
    /// @param rs Registry stack (coordinator + registries).
    /// @param thresholdBps Minimum signed-to-total stake ratio in basis points.
    /// @param _quorumNumber Quorum id whose signers are slashed on a fault.
    /// @param _operatorSetId Operator set id slashed on a fault.
    function _deployTaskManager(
        RegistryStack memory rs,
        uint256 thresholdBps,
        uint8 _quorumNumber,
        uint32 _operatorSetId
    ) internal returns (EigenAuctionTaskManager taskManager) {
        taskManager = new EigenAuctionTaskManager(
            ISlashingRegistryCoordinator(address(rs.coordinator)),
            hex"00",
            thresholdBps,
            _quorumNumber,
            _operatorSetId
        );
    }

    /* AVS REGISTRAR + QUORUM */

    /// @dev Points the AVS registrar at the coordinator and creates the single slashable-stake quorum.
    /// Grants the UAM appointees the coordinator and slasher need to act on behalf of the AVS, then
    /// (as a now-appointed deployer) sets the registrar and creates the quorum. AVS metadata MUST
    /// already be registered, and `owner` MUST be the broadcasting deployer.
    function _configureOperatorSet(
        NetworkConfig memory config,
        RegistryStack memory rs,
        EigenAuctionServiceManager avs,
        VetoableSlasher veto,
        address owner
    ) internal {
        IAllocationManager allocationManager = IAllocationManager(config.allocationManager);
        address am = address(allocationManager);

        // UAM grants: deployer may set the registrar, the coordinator may create operator sets, and the
        // VetoableSlasher may slash — all on behalf of the AVS account.
        avs.setAppointee(owner, am, IAllocationManager.setAVSRegistrar.selector);
        avs.setAppointee(address(rs.coordinator), am, IAllocationManager.createOperatorSets.selector);
        avs.setAppointee(address(veto), am, IAllocationManager.slashOperator.selector);

        // Route operator registration through the coordinator so BLS pubkeys land in the APK registry.
        allocationManager.setAVSRegistrar(address(avs), IAVSRegistrar(address(rs.coordinator)));

        // Create quorum 0 as a slashable-stake quorum over the configured stake strategy.
        ISlashingRegistryCoordinatorTypes.OperatorSetParam memory operatorSetParams =
        ISlashingRegistryCoordinatorTypes.OperatorSetParam({
            maxOperatorCount: MAX_OPERATOR_COUNT,
            kickBIPsOfOperatorStake: 0,
            kickBIPsOfTotalStake: 0
        });

        IStakeRegistryTypes.StrategyParams[] memory strategyParams = new IStakeRegistryTypes.StrategyParams[](1);
        strategyParams[0] = IStakeRegistryTypes.StrategyParams({
            strategy: IStrategy(config.stakeStrategy),
            multiplier: STRATEGY_MULTIPLIER
        });

        rs.coordinator.createSlashableStakeQuorum(
            operatorSetParams, MIN_OPERATOR_STAKE, strategyParams, QUORUM_LOOK_AHEAD
        );
    }
}
