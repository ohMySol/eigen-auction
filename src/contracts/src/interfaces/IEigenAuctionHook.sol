// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {IEigenAuctionServiceManager} from "./IEigenAuctionServiceManager.sol";

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
/// which folds it into the accumulator for in-range LPs. Liquidity is supplied through any standard
/// V4 router or PositionManager; the hook mirrors each position in its before-liquidity callbacks and
/// pays accrued rewards out in `afterRemoveLiquidity` as a currency0 delta that rides back to the LP
/// with the withdrawn principal. A zero-liquidity removal can be used to collect rewards in place.
interface IEigenAuctionHook {
    /// @notice The service manager that authorizes operators and records settlements.
    function avs() external view returns (IEigenAuctionServiceManager);

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

    /* LP VIEWS */

    /// @notice Returns the total currency0 rewards a position has accrued — both already settled
    /// into `owed` and not-yet-checkpointed growth since the last action.
    /// @param key The pool the position belongs to.
    /// @param owner Position owner as V4 attributes it — the router / PositionManager address.
    /// @param tickLower Lower tick of the position's range.
    /// @param tickUpper Upper tick of the position's range.
    /// @param salt Position salt under `owner` (the PositionManager's per-NFT salt).
    /// @return amount Total currency0 claimable right now.
    function earned(
        PoolKey calldata key,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) external view returns (uint256 amount);

    /// @notice Returns the liquidity units the hook tracks for a position.
    /// @param key The pool the position belongs to.
    /// @param owner Position owner as V4 attributes it — the router / PositionManager address.
    /// @param tickLower Lower tick of the position's range.
    /// @param tickUpper Upper tick of the position's range.
    /// @param salt Position salt under `owner` (the PositionManager's per-NFT salt).
    /// @return Liquidity units attributed to this position.
    function positionLiquidity(
        PoolKey calldata key,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) external view returns (uint128);
}
