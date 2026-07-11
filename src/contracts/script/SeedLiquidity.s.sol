// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IStateView} from "v4-periphery/src/interfaces/IStateView.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ConfigLib, Deployment} from "./libs/ConfigLib.sol";

/// @title SeedLiquidity
/// @author ohMySol
/// @notice Seeds the deployed pool with a full-range LP position so the arb + batch swaps in
/// `Settler.settle` have liquidity to trade against. Deploys a v4 test liquidity router, approves it,
/// and adds liquidity from the deployer (funded by `make fund`). Fork/dev tooling only — a production LP
/// uses a real V4 PositionManager; this exists because both Deploy scripts defer LP seeding off-chain.
///
/// Env:
///   DEPLOYER_PK — holds currency0/currency1 (make fund gives 1M USDC + 5000 WETH)
///   SEED_AMOUNT0 / SEED_AMOUNT1 (optional) — raw token amounts to seed; defaults are balanced at the
///   ~2000 currency0/currency1 start price.
///
/// Run: `forge script script/SeedLiquidity.s.sol --root src/contracts --rpc-url $RPC_URL --broadcast`
contract SeedLiquidity is Script {
    // Full range for tickSpacing 60 (nearest usable ticks to MIN/MAX).
    int24 constant TICK_LOWER = -887220;
    int24 constant TICK_UPPER = 887220;

    function run() external {
        Deployment memory d = ConfigLib.readDeployment(vm, block.chainid);
        uint256 pk = vm.envUint("DEPLOYER_PK");

        uint256 amount0 = vm.envOr("SEED_AMOUNT0", uint256(400_000) * (10 ** d.currency0Decimals));
        uint256 amount1 = vm.envOr("SEED_AMOUNT1", uint256(200) * (10 ** d.currency1Decimals));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(d.currency0),
            currency1: Currency.wrap(d.currency1),
            fee: d.fee,
            tickSpacing: d.tickSpacing,
            hooks: IHooks(d.hook)
        });

        (uint160 sqrtPriceX96,,,) = IStateView(d.stateView).getSlot0(PoolId.wrap(d.poolId));
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(TICK_LOWER),
            TickMath.getSqrtPriceAtTick(TICK_UPPER),
            amount0,
            amount1
        );
        require(liquidity > 0, "SeedLiquidity: zero liquidity (check amounts/price)");

        vm.startBroadcast(pk);
        PoolModifyLiquidityTest router = new PoolModifyLiquidityTest(IPoolManager(d.poolManager));
        IERC20(d.currency0).approve(address(router), type(uint256).max);
        IERC20(d.currency1).approve(address(router), type(uint256).max);
        router.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: TICK_LOWER,
                tickUpper: TICK_UPPER,
                liquidityDelta: int256(uint256(liquidity)),
                salt: bytes32(0)
            }),
            ""
        );
        vm.stopBroadcast();

        console2.log("seeded pool with liquidity:", uint256(liquidity));
        console2.log("liquidity router:", address(router));
    }
}
