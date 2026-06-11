// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";

import {IEigenAuctionHook} from "../src/interfaces/IEigenAuctionHook.sol";
import {ConfigLib, Deployment} from "./libs/ConfigLib.sol";

/// @dev Minimal ERC-20 approve surface.
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title SeedLiquidity
/// @notice Adds an in-range LP position to the deployed pool so the demo has an LP to reward — seeded
/// straight through the hook (`addLiquidity`), so the position is attributed to the broadcaster and its
/// rewards are claimable by them. Used by the fork flow after `Deploy` + `make fund` (so the deployer
/// holds both currencies). DeployTestnet seeds its own LP inline, so this is only needed for the fork.
///
/// Note: liquidity added in a block is the JIT cohort and matures the next block, so let one block pass
/// before the arb settlement so this position is reward-eligible.
///
/// Run: `forge script script/SeedLiquidity.s.sol --rpc-url $RPC_URL --broadcast`
contract SeedLiquidity is Script {
    // Full usable range for tickSpacing 60: floor(887272 / 60) * 60 = 887220.
    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;
    uint128 constant LIQUIDITY = 1e15;

    function run() external {
        Deployment memory deployment = ConfigLib.readDeployment(vm, block.chainid);
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(deployment.currency0),
            currency1: Currency.wrap(deployment.currency1),
            fee: deployment.fee,
            tickSpacing: deployment.tickSpacing,
            hooks: IHooks(deployment.hook)
        });

        vm.startBroadcast(deployerPk);

        // The hook pulls both currencies from the broadcaster during settlement, so approve it.
        IERC20(deployment.currency0).approve(deployment.hook, type(uint256).max);
        IERC20(deployment.currency1).approve(deployment.hook, type(uint256).max);

        IEigenAuctionHook(deployment.hook).addLiquidity(key, TICK_LOWER, TICK_UPPER, LIQUIDITY);

        vm.stopBroadcast();

        console2.log("Seeded liquidity through the hook for:", vm.addr(deployerPk));
    }
}
