// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {IAuctionServiceManager} from "./IAuctionServiceManager.sol";

/// @title IEigenAuctionHook
/// @author ohMySol
/// @notice Interface for `EigenAuctionHook` — a Uniswap V4 hook that locks each pool to a single
/// Settler and returns arb-auction proceeds to in-range LPs.
///
/// Pool locking
/// -------------
/// Once a settler is registered via `setSettler`, swaps must originate from that Settler, at most
/// once per pool per block. Any other caller is rejected unless `FALLBACK_PERIOD` consecutive blocks
/// elapse without a recorded settlement, in which case the pool re-opens to public routing.
///
/// LP rewards
/// ----------
/// Rewards (always currency0) are tracked with a V3-style growth accumulator. The Settler transfers
/// the derived arb bid (and any clearing-price residual) to the hook and calls `distributeReward`,
/// which folds it into the accumulator for in-range LPs. LPs collect via `claimRewards`, or
/// automatically when they remove liquidity. Liquidity must be managed through `addLiquidity` /
/// `removeLiquidity`; positions opened via external V4 routers are not tracked.
interface IEigenAuctionHook {
    /// @notice The service manager that authorizes operators and records settlements.
    function avs() external view returns (IAuctionServiceManager);

    /// @notice Address permitted to call `setSettler` once.
    function owner() external view returns (address);

    /// @notice The sole contract permitted to initiate swaps while the venue is locked.
    /// `address(0)` means no settler is registered yet (open mode).
    function settler() external view returns (address);

    /// @notice The last block in which `recordSettlement` succeeded for `poolId`.
    function lastSettledBlock(PoolId poolId) external view returns (uint256);

    /// @notice Pool-wide cumulative reward growth per unit of liquidity, X128 (currency0).
    function rewardGrowthGlobal(PoolId poolId) external view returns (uint256);

    /// @notice Register the settler. Callable exactly once by the owner.
    /// @param _settler Address of the deployed `Settler` contract.
    function setSettler(address _settler) external;

    /// @notice Called by the settler once per block per pool to reset the fallback liveness timer.
    /// Reverts if the caller is not the settler or the pool was already settled this block.
    /// @param poolId The pool being settled.
    function recordSettlement(PoolId poolId) external;

    /// @notice Folds a settler-supplied reward (currency0) into the pool's reward accumulator for
    /// whoever is in range now. The settler must transfer `amount` of currency0 to the hook first.
    /// @param key The pool to distribute the reward in.
    /// @param amount Reward amount in currency0.
    function distributeReward(PoolKey calldata key, uint256 amount) external;

    /* LP ACTIONS */

    /// @notice Supplies liquidity to the pool through the hook itself.
    function addLiquidity(PoolKey calldata key, int24 tickLower, int24 tickUpper, uint128 liquidity) external;

    /// @notice Withdraws liquidity previously supplied through `addLiquidity`. Accrued rewards are
    /// paid out automatically.
    function removeLiquidity(PoolKey calldata key, int24 tickLower, int24 tickUpper, uint128 liquidity) external;

    /// @notice Collects accrued rewards for a position without changing its liquidity.
    /// @param key The pool the position belongs to.
    /// @param tickLower Lower tick of the position's range.
    /// @param tickUpper Upper tick of the position's range.
    function claimRewards(PoolKey calldata key, int24 tickLower, int24 tickUpper) external;

    /// @notice Returns the currency0 rewards a position has accrued (settled plus not-yet-settled).
    function earned(
        PoolKey calldata key,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) external view returns (uint256 amount);

    /// @notice Returns the liquidity the hook attributes to a position.
    function positionLiquidity(
        PoolKey calldata key,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) external view returns (uint128);
}
