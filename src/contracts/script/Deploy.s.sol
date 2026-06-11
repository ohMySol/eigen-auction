// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

import {DeployCore} from "./base/DeployCore.sol";
import {ConfigLib, NetworkConfig} from "./libs/ConfigLib.sol";

/// @title Deploy
/// @author ohMySol
/// @notice Canonical deployment for any network whose token pair already exists on-chain — real
/// mainnet, the mainnet fork (chainId 1), or a testnet configured with real tokens. Reuses the live
/// Uniswap V4 + EigenLayer core from config/networks/<chainId>.json and deploys this project's three
/// contracts (AuctionServiceManager proxy, EigenAuctionHook, Settler), creates the AVS operator set,
/// registers the operator, initialises the pool, and writes deployments/<chainId>.json.
///
/// For a testnet with no token pair, use DeployTestnet (deploys FaucetTokens + seeds LP).
///
/// Funding and LP seeding are out of scope here (node-level / separate ops): for the fork they run from
/// the Makefile (`make fund seed`) before/after this script.
///
/// Required env:
///   DEPLOYER_PK  — deploys contracts; AVS owner + pool initialiser
///   OPERATOR_PK  — the AVS operator that registers into the operator set
/// Optional:
///   DEPLOY_SQRT_PRICE_X96 — pool start price (defaults to ~the live market for the configured pair)
///
/// Run: `forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast`
contract Deploy is DeployCore {
    function run() external {
        NetworkConfig memory config = ConfigLib.readNetwork(vm, block.chainid);
        require(
            config.currency0 != address(0) && config.currency1 != address(0),
            "Deploy: token pair not configured for this chain; use DeployTestnet to deploy mock tokens"
        );

        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        uint256 operatorPk = vm.envUint("OPERATOR_PK");
        address operator = vm.addr(operatorPk);
        uint160 startSqrtPriceX96 = uint160(vm.envOr("DEPLOY_SQRT_PRICE_X96", _defaultSqrtPrice()));

        // Step 1 — deploy + wire the protocol, then initialise the pool (deployer == AVS/hook owner).
        vm.startBroadcast(deployerPk);
        ProtocolContracts memory protocol = _deployProtocol(config, vm.addr(deployerPk));
        PoolKey memory key = _poolKey(
            config, 
            address(protocol.hook), 
            Currency.wrap(config.currency0), 
            Currency.wrap(config.currency1)
        );
        IPoolManager(config.poolManager).initialize(key, startSqrtPriceX96);
        vm.stopBroadcast();

        // Step 2 — register the operator into the AVS operator set.
        vm.startBroadcast(operatorPk);
        _registerOperator(config, address(protocol.avs), operator);
        vm.stopBroadcast();

        // Step 3 — persist the artifact the backend/frontend read.
        _writeDeployment(config, key, protocol, config.currency0Decimals, config.currency1Decimals);
    }

    /// @dev Default pool start price for USDC(6)/WETH(18), already decimal-adjusted (~2000 USDC/WETH).
    /// Override with DEPLOY_SQRT_PRICE_X96 for a different pair/price. Keep it distinct from the
    /// off-chain FIXED_PRICE target so there is an arb gap for the demo to close.
    function _defaultSqrtPrice() internal pure returns (uint256) {
        return 1771595571142957166518320255467520;
    }
}
