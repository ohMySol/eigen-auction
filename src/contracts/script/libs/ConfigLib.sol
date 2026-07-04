// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Vm} from "forge-std/Vm.sol";
import {stdJson} from "forge-std/StdJson.sol";

/// @notice Canonical, externally-deployed addresses for a network — the curated input read from
/// `config/networks/<chainId>.json`. These are never written by tooling.
struct NetworkConfig {
    // Uniswap V4
    address poolManager;
    address stateView;
    address permit2;
    // EigenLayer core
    address allocationManager;
    address delegationManager;
    address avsDirectory;
    address rewardsCoordinator;
    address permissionController;
    address strategyManager;
    address stakeStrategy;
    address stakeToken;
    // Pool
    address currency0;
    address currency1;
    uint8 currency0Decimals;
    uint8 currency1Decimals;
    uint24 fee;
    int24 tickSpacing;
    // AVS
    uint256 threshold;
}

/// @notice Deployment artifact produced by a deployment — the generated output written to
/// `deployments/<chainId>.json` and consumed by the backend/frontend as the single source of truth.
struct Deployment {
    uint256 chainId;
    address poolManager;
    address stateView;
    address serviceManager;
    address taskManager;
    address registryCoordinator;
    address stakeRegistry;
    address blsApkRegistry; 
    address operatorStateRetriever;
    address delegationManager; 
    address allocationManager;
    address avsDirectory; 
    address stakeStrategy;
    uint256 quorumNumbers;
    address hook;
    address settler;
    address currency0;
    address currency1;
    uint8 currency0Decimals;
    uint8 currency1Decimals;
    uint24 fee;
    int24 tickSpacing;
    bytes32 poolId;
    uint256 deployedBlock;
}

/// @title ConfigLib
/// @notice Reads the curated per-network config and writes the generated deployment artifact, so the
/// deploy script stays declarative and the backend/frontend read one JSON keyed by chainId.
library ConfigLib {
    using stdJson for string;

    /// @dev config/ and deployments/ live at the repo root (shared by contracts + backend + frontend),
    /// which is two levels above the Foundry root (src/contracts).
    function repoRoot(Vm vm) internal view returns (string memory rootDir) {
        rootDir = string.concat(vm.projectRoot(), "/../..");
    }

    /// @dev Constructs the absolute path to a config or deployment JSON for a chain.
    /// @param vm The forge VM handle (libraries are stateless, so it must be passed in).
    /// @param suffix The path prefix under the repo root, e.g. "/config/networks/" or "/deployments/".
    /// @param chainId The chain ID the file is keyed by.
    function getPath(Vm vm, string memory suffix, uint256 chainId) internal view returns (string memory) {
        return string.concat(repoRoot(vm), suffix, vm.toString(chainId), ".json");
    }

    /// @dev Reads `config/networks/<chainId>.json` and decodes it into a NetworkConfig.
    function readNetwork(Vm vm, uint256 chainId) internal view returns (NetworkConfig memory config) {
        string memory path = getPath(vm, "/config/networks/", chainId);
        string memory json = vm.readFile(path);

        config.poolManager = json.readAddress(".uniswap.poolManager");
        config.stateView = json.readAddress(".uniswap.stateView");
        config.permit2 = json.readAddress(".uniswap.permit2");

        config.allocationManager = json.readAddress(".eigenlayer.allocationManager");
        config.delegationManager = json.readAddress(".eigenlayer.delegationManager");
        config.avsDirectory = json.readAddress(".eigenlayer.avsDirectory");
        config.rewardsCoordinator = json.readAddress(".eigenlayer.rewardsCoordinator");
        config.permissionController = json.readAddress(".eigenlayer.permissionController");
        config.strategyManager = json.readAddress(".eigenlayer.strategyManager");
        config.stakeStrategy = json.readAddress(".eigenlayer.stakeStrategy");
        config.stakeToken = json.readAddress(".eigenlayer.stakeToken");

        config.currency0 = json.readAddress(".pool.currency0");
        config.currency1 = json.readAddress(".pool.currency1");
        config.currency0Decimals = uint8(json.readUint(".pool.currency0Decimals"));
        config.currency1Decimals = uint8(json.readUint(".pool.currency1Decimals"));
        config.fee = uint24(json.readUint(".pool.fee"));
        config.tickSpacing = int24(json.readInt(".pool.tickSpacing"));

        config.threshold = json.readUint(".avs.threshold");
    }

    /// @dev Reads back a previously written `deployments/<chainId>.json` (e.g. for SeedLiquidity).
    function readDeployment(Vm vm, uint256 chainId) internal view returns (Deployment memory deployment) {
        string memory path = getPath(vm, "/deployments/", chainId);
        string memory json = vm.readFile(path);

        deployment.chainId = chainId;
        deployment.poolManager = json.readAddress(".poolManager");
        deployment.stateView = json.readAddress(".stateView");
        deployment.serviceManager = json.readAddress(".serviceManager");
        deployment.hook = json.readAddress(".hook");
        deployment.settler = json.readAddress(".settler");
        deployment.taskManager = json.readAddress(".taskManager");
        deployment.registryCoordinator = json.readAddress(".registryCoordinator");
        deployment.stakeRegistry = json.readAddress(".stakeRegistry");
        deployment.blsApkRegistry = json.readAddress(".blsApkRegistry");
        deployment.operatorStateRetriever = json.readAddress(".operatorStateRetriever");
        deployment.delegationManager = json.readAddress(".delegationManager");
        deployment.allocationManager = json.readAddress(".allocationManager");
        deployment.avsDirectory = json.readAddress(".avsDirectory");
        deployment.stakeStrategy = json.readAddress(".stakeStrategy");
        deployment.quorumNumbers = json.readUint(".quorumNumbers");
        deployment.currency0 = json.readAddress(".pool.currency0");
        deployment.currency1 = json.readAddress(".pool.currency1");
        deployment.currency0Decimals = uint8(json.readUint(".pool.currency0Decimals"));
        deployment.currency1Decimals = uint8(json.readUint(".pool.currency1Decimals"));
        deployment.fee = uint24(json.readUint(".pool.fee"));
        deployment.tickSpacing = int24(json.readInt(".pool.tickSpacing"));
        deployment.poolId = json.readBytes32(".pool.poolId");
    }

    /// @dev Writes `deployments/<chainId>.json` in the exact shape the backend config loader expects.
    function writeDeployment(Vm vm, Deployment memory deployment) internal {
        string memory obj = "deployment";
        vm.serializeUint(obj, "chainId", deployment.chainId);
        vm.serializeAddress(obj, "poolManager", deployment.poolManager);
        vm.serializeAddress(obj, "stateView", deployment.stateView);
        vm.serializeAddress(obj, "serviceManager", deployment.serviceManager);
        vm.serializeAddress(obj, "hook", deployment.hook);
        vm.serializeAddress(obj, "settler", deployment.settler);

        // AVS/middleware + EL-core addresses the off-chain aggregator and operator client bind to.
        vm.serializeAddress(obj, "taskManager", deployment.taskManager);
        vm.serializeAddress(obj, "registryCoordinator", deployment.registryCoordinator);
        vm.serializeAddress(obj, "stakeRegistry", deployment.stakeRegistry);
        vm.serializeAddress(obj, "blsApkRegistry", deployment.blsApkRegistry);
        vm.serializeAddress(obj, "operatorStateRetriever", deployment.operatorStateRetriever);
        vm.serializeAddress(obj, "delegationManager", deployment.delegationManager);
        vm.serializeAddress(obj, "allocationManager", deployment.allocationManager);
        vm.serializeAddress(obj, "avsDirectory", deployment.avsDirectory);
        vm.serializeAddress(obj, "stakeStrategy", deployment.stakeStrategy);
        vm.serializeUint(obj, "quorumNumbers", deployment.quorumNumbers);

        // Nested "pool" object, mirroring config/networks and the artifact schema.
        string memory poolObj = "pool";
        vm.serializeAddress(poolObj, "currency0", deployment.currency0);
        vm.serializeAddress(poolObj, "currency1", deployment.currency1);
        vm.serializeUint(poolObj, "currency0Decimals", deployment.currency0Decimals);
        vm.serializeUint(poolObj, "currency1Decimals", deployment.currency1Decimals);
        vm.serializeUint(poolObj, "fee", deployment.fee);
        vm.serializeInt(poolObj, "tickSpacing", deployment.tickSpacing);
        string memory poolJson = vm.serializeBytes32(poolObj, "poolId", deployment.poolId);

        vm.serializeString(obj, "pool", poolJson);
        string memory finalJson = vm.serializeUint(obj, "deployedBlock", deployment.deployedBlock);

        string memory outPath = getPath(vm, "/deployments/", deployment.chainId);
        vm.writeJson(finalJson, outPath);
    }
}
