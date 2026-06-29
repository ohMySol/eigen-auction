// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

import {DeployCore} from "./base/DeployCore.sol";
import {ConfigLib, NetworkConfig} from "./libs/ConfigLib.sol";
import {FaucetToken} from "./helpers/FaucetToken.sol";

/// @title DeployTestnet
/// @author ohMySol
/// @notice Public-testnet deployment (e.g. Sepolia). Same protocol deployment as `Deploy`
/// (via the shared `DeployCore`), but additionally deploys two FaucetTokens for the pool, mints demo
/// balances, and starts the pool at 1:1.
///
/// Liquidity is seeded off-chain through a standard V4 router / PositionManager (the hook tracks any
/// position opened that way), not from this script — see the backend tooling. Demo balances come from
/// the mintable FaucetTokens, and any wallet can top up later via `FaucetToken.faucet()`; no node cheats.
///
/// Required env:
///   DEPLOYER_PK  — deploys contracts + tokens; AVS owner and pool initialiser
///   OPERATOR_PK  — the AVS operator that registers into the operator set
///
/// Run: `forge script script/DeployTestnet.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast`
contract DeployTestnet is DeployCore {
    /// @dev sqrt(1) * 2**96 — the pool starts at 1:1 and the off-chain FIXED_PRICE supplies the arb
    /// gap, so the price math is independent of which FaucetToken sorts as currency0.
    uint160 constant START_SQRT_PRICE_X96 = 79228162514264337593543950336;

    // Demo balance minted to the deployer and operator for each FaucetToken.
    uint256 constant MINT_AMOUNT = 1_000_000e18;

    function run() external {
        NetworkConfig memory config = ConfigLib.readNetwork(vm, block.chainid);
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        uint256 operatorPk = vm.envUint("OPERATOR_PK");
        address deployer = vm.addr(deployerPk);
        address operator = vm.addr(operatorPk);

        // Step 1 — tokens + protocol + pool (deployer == AVS/hook owner and pool initialiser).
        vm.startBroadcast(deployerPk);
        (
            Currency currency0,
            Currency currency1,
            uint8 decimals0,
            uint8 decimals1
        ) = _resolveTokens(config, deployer, operator);

        ProtocolContracts memory protocol = _deployProtocol(config, deployer);
        PoolKey memory key = _poolKey(config, address(protocol.hook), currency0, currency1);
        IPoolManager(config.poolManager).initialize(key, START_SQRT_PRICE_X96);
        // Liquidity is seeded off-chain via a standard V4 router / PositionManager (see backend tooling).
        vm.stopBroadcast();

        // Step 2 — ensure the demo operator is a registered EigenLayer operator. BLS operator-set
        // membership is submitted off-chain by the operator client (see M6).
        vm.startBroadcast(operatorPk);
        _registerOperator(config, operator);
        vm.stopBroadcast();

        // Step 3 — persist the artifact the backend/frontend read.
        _writeDeployment(config, key, protocol, decimals0, decimals1);
    }

    /// @dev Returns the pool's currency pair. When the config leaves the pair unset (zero), deploys two
    /// FaucetTokens, mints demo balances to the deployer + operator, and returns them address-sorted
    /// (V4 requires currency0 < currency1). When the config names real tokens, uses them verbatim.
    function _resolveTokens(NetworkConfig memory config, address deployer, address operator)
        internal
        returns (Currency currency0, Currency currency1, uint8 decimals0, uint8 decimals1)
    {
        if (config.currency0 != address(0) && config.currency1 != address(0)) {
            return (
                Currency.wrap(config.currency0),
                Currency.wrap(config.currency1),
                config.currency0Decimals,
                config.currency1Decimals
            );
        }

        FaucetToken a = new FaucetToken("Mock USDC", "mUSDC", 18, 10_000);
        FaucetToken b = new FaucetToken("Mock Ether", "mETH", 18, 10);
        (FaucetToken lowerToken, FaucetToken higherToken) = address(a) < address(b) ? (a, b) : (b, a);

        lowerToken.mint(deployer, MINT_AMOUNT);
        lowerToken.mint(operator, MINT_AMOUNT);
        higherToken.mint(deployer, MINT_AMOUNT);
        higherToken.mint(operator, MINT_AMOUNT);

        return (Currency.wrap(address(lowerToken)), Currency.wrap(address(higherToken)), 18, 18);
    }
}
