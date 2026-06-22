// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {IEigenAuctionHook} from "./interfaces/IEigenAuctionHook.sol";
import {IEigenAuctionServiceManager} from "./interfaces/IEigenAuctionServiceManager.sol";
import {Position, LiquidityCallback} from "./types/Position.sol";
import {PoolRewards} from "./types/PoolRewards.sol";
import {PoolRewardsLib} from "./libraries/PoolRewardsLib.sol";
import {RewardGrowthLib} from "./libraries/RewardGrowthLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";

/// @title EigenAuctionHook
/// @author ohMySol
/// @notice Uniswap V4 hook that locks each pool to a single Settler and distributes arb-auction
/// proceeds to in-range LPs.
///
/// @dev 
/// Pool lock
/// ----------
/// Once `setSettler` is called only the Settler may initiate swaps, and at most once per pool per
/// block (`recordSettlement`). Any other caller is rejected unless `FALLBACK_PERIOD` blocks elapse
/// with no settlement, at which point the pool re-opens to prevent a permanent liveness failure.
///
/// Reward distribution
/// -------------------
/// Reward growth is tracked per pool in a V3-style `PoolRewards` accumulator (always currency0).
/// On every swap that reaches the hook, `_beforeSwap` snapshots the tick and `_afterSwap` flips the
/// outside accumulators for the ticks crossed (see `PoolRewardsLib`/`TickCrossingLib`). The Settler
/// transfers the derived bid (and any clearing-price residual) to this hook and calls
/// `distributeReward`, which folds it into the accumulator for whoever is in range at that moment.
/// A pre-swap `expectedLiquidity` in hookData lets the hook revert on a JIT add (JIT guard).
///
/// LP positions are managed exclusively through this hook's `addLiquidity`/`removeLiquidity`; the
/// hook does not track liquidity supplied through external V4 routers.
contract EigenAuctionHook is BaseHook, IEigenAuctionHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using CurrencyLibrary for Currency;
    using PoolRewardsLib for PoolRewards;

    /* IMMUTABLES */

    /// @inheritdoc IEigenAuctionHook
    IEigenAuctionServiceManager public immutable avs;

    /// @inheritdoc IEigenAuctionHook
    address public immutable owner;

    /* POOL LOCK STATE */

    /// @inheritdoc IEigenAuctionHook
    address public settler;

    /// @inheritdoc IEigenAuctionHook
    mapping(PoolId => uint256) public lastSettledBlock;

    /* REWARD ACCOUNTING STORAGE */

    /// @dev Per-pool V3-style reward accumulator (currency0).
    mapping(PoolId => PoolRewards) private _poolRewards;

    /// @dev positionKey => position. Keyed by `keccak256(poolId, owner, lower, upper, salt)`.
    mapping(bytes32 => Position) private _positions;

    /* CONSTRUCTOR */

    /// @param _poolManager Address of the Uniswap V4 pool manager.
    /// @param _avs Address of the auction service manager.
    /// @param _owner Address permitted to call `setSettler` once.
    constructor(address _poolManager, address _avs, address _owner) BaseHook(IPoolManager(_poolManager)) {
        if (_avs == address(0) || _owner == address(0)) revert ErrorsLib.EigenAuctionHook_ZeroAddress();
        avs = IEigenAuctionServiceManager(_avs);
        owner = _owner;
    }

    /// @inheritdoc BaseHook
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /* POOL LOCK */

    /// @inheritdoc IEigenAuctionHook
    function setSettler(address _settler) external {
        if (msg.sender != owner) revert ErrorsLib.EigenAuctionHook_Unauthorized();
        if (_settler == address(0)) revert ErrorsLib.EigenAuctionHook_ZeroAddress();
        if (settler != address(0)) revert ErrorsLib.EigenAuctionHook_SettlerAlreadySet();
        settler = _settler;
        emit EventsLib.SettlerSet(_settler);
    }

    /// @inheritdoc IEigenAuctionHook
    function recordSettlement(PoolId poolId) external {
        if (msg.sender != settler) revert ErrorsLib.EigenAuctionHook_OnlySettler();
        if (lastSettledBlock[poolId] == block.number) revert ErrorsLib.EigenAuctionHook_AlreadySettledThisBlock();
        lastSettledBlock[poolId] = block.number;
    }

    /// @inheritdoc IEigenAuctionHook
    function distributeReward(PoolKey calldata key, uint256 amount) external {
        if (msg.sender != settler) revert ErrorsLib.EigenAuctionHook_OnlySettler();
        if (amount == 0) return;
        
        PoolId poolId = key.toId();
        uint128 liquidity = poolManager.getLiquidity(poolId);
        
        // If no active liquidity, the reward cannot accrue to anyone; the Settler keeps it.
        if (liquidity == 0) return;
        
        _poolRewards[poolId].fold(amount, liquidity);
        
        emit EventsLib.ArbitrageSettled(poolId, msg.sender, amount);
    }

    /* LP LIQUIDITY */

    /// @inheritdoc IEigenAuctionHook
    function addLiquidity(PoolKey calldata key, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        if (liquidity == 0) revert ErrorsLib.EigenAuctionHook_ZeroLiquidity();
        poolManager.unlock(
            abi.encode(
                LiquidityCallback({
                    key: key,
                    lp: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int256(uint256(liquidity))
                })
            )
        );
        emit EventsLib.LiquidityAdded(key.toId(), msg.sender, tickLower, tickUpper, liquidity);
    }

    /// @inheritdoc IEigenAuctionHook
    function removeLiquidity(PoolKey calldata key, int24 tickLower, int24 tickUpper, uint128 liquidity) external {
        if (liquidity == 0) revert ErrorsLib.EigenAuctionHook_ZeroLiquidity();
        poolManager.unlock(
            abi.encode(
                LiquidityCallback({
                    key: key,
                    lp: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int256(uint256(liquidity))
                })
            )
        );
        emit EventsLib.LiquidityRemoved(key.toId(), msg.sender, tickLower, tickUpper, liquidity);
    }

    /// @notice Pool-manager unlock callback for the hook's own LP add/remove flow.
    /// @dev V4 skips a hook's own liquidity callbacks on self-calls, so the reward ledger is updated
    /// inline here, keyed to the real LP rather than the router.
    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        LiquidityCallback memory cbData = abi.decode(data, (LiquidityCallback));
        PoolId poolId = cbData.key.toId();
        bytes32 positionKey = _positionKey(
            poolId, 
            cbData.lp, 
            cbData.tickLower, 
            cbData.tickUpper, 
            bytes32(0)
        );

        (, int24 currentTick,,) = poolManager.getSlot0(poolId);

        // Seed reward-outside for boundaries this add will initialize (V3 convention), before adding.
        if (cbData.liquidityDelta > 0) {
            _poolRewards[poolId].initializeBoundary(poolManager, poolId, cbData.tickLower, currentTick);
            _poolRewards[poolId].initializeBoundary(poolManager, poolId, cbData.tickUpper, currentTick);
        }

        // Accrue rewards earned so far and re-checkpoint before the liquidity change.
        _settlePosition(poolId, positionKey, currentTick, cbData.tickLower, cbData.tickUpper);

        (BalanceDelta delta,) = poolManager.modifyLiquidity(
            cbData.key,
            ModifyLiquidityParams({
                tickLower: cbData.tickLower,
                tickUpper: cbData.tickUpper,
                liquidityDelta: cbData.liquidityDelta,
                salt: bytes32(uint256(uint160(cbData.lp)))
            }),
            ""
        );

        _applyLiquidity(positionKey, cbData.liquidityDelta);

        // Auto-pay accrued rewards on removal so the LP never needs a separate claim step.
        if (cbData.liquidityDelta < 0) {
            _payRewards(poolId, positionKey, cbData.key.currency0, cbData.lp);
        }

        _settlePrincipal(cbData.key.currency0, delta.amount0(), cbData.lp);
        _settlePrincipal(cbData.key.currency1, delta.amount1(), cbData.lp);
        return "";
    }

    /// @inheritdoc IEigenAuctionHook
    function claimRewards(PoolKey calldata key, int24 tickLower, int24 tickUpper) external {
        PoolId poolId = key.toId();
        (, int24 currentTick,,) = poolManager.getSlot0(poolId);
        bytes32 positionKey = _positionKey(poolId, msg.sender, tickLower, tickUpper, bytes32(0));
        
        _settlePosition(poolId, positionKey, currentTick, tickLower, tickUpper);
        _payRewards(poolId, positionKey, key.currency0, msg.sender);
    }

    /* VIEWS */

    /// @inheritdoc IEigenAuctionHook
    function rewardGrowthGlobal(PoolId poolId) external view returns (uint256) {
        return _poolRewards[poolId].growthGlobalX128;
    }

    /// @inheritdoc IEigenAuctionHook
    function earned(
        PoolKey calldata key,
        address owner_,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) external view returns (uint256 amount) {
        PoolId poolId = key.toId();
        Position storage pos = _positions[_positionKey(poolId, owner_, tickLower, tickUpper, salt)];
        (, int24 currentTick,,) = poolManager.getSlot0(poolId);
        
        uint256 insideX128 = _poolRewards[poolId].getGrowthInside(currentTick, tickLower, tickUpper);
        
        amount = pos.owed + RewardGrowthLib.rewardsOf(insideX128, pos.lastGrowthInsideX128, pos.liquidity);
    }

    /// @inheritdoc IEigenAuctionHook
    function positionLiquidity(
        PoolKey calldata key,
        address owner_,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) external view override returns (uint128) {
        return _positions[_positionKey(key.toId(), owner_, tickLower, tickUpper, salt)].liquidity;
    }

    /* SWAP HOOKS */

    /// @dev Enforces the venue lock, snapshots the tick for reward crossing, and runs the JIT guard.
    /// Allows Settler swaps always; allows public swaps only before a settler is set or after the
    /// fallback period elapses. For Settler swaps, `hookData` may carry a 32-byte `expectedLiquidity`
    /// snapshotted by the operator; if it differs from the live value a JIT add slipped in → revert.
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        bool isSettler = sender == settler;

        if (!isSettler) {
            bool open = settler == address(0) || block.number > lastSettledBlock[poolId] + ConstantsLib.FALLBACK_PERIOD;
            if (!open) revert ErrorsLib.EigenAuctionHook_NotSettler();
        }

        (, int24 tick,,) = poolManager.getSlot0(poolId);
        _poolRewards[poolId].snapshotTick(tick);

        if (isSettler && hookData.length == 32) {
            uint256 expectedLiquidity = abi.decode(hookData, (uint256));
            if (expectedLiquidity > 0 && poolManager.getLiquidity(poolId) != uint128(expectedLiquidity)) {
                revert ErrorsLib.EigenAuctionHook_LiquidityMismatch();
            }
        }

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @dev Flips outside accumulators for the ticks this swap crossed. Reward folding happens
    /// separately via `distributeReward` once the Settler knows the bid/residual amount.
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        (, int24 newTick,,) = poolManager.getSlot0(poolId);
        _poolRewards[poolId].crossTicks(poolManager, poolId, key.tickSpacing, newTick);
        return (this.afterSwap.selector, 0);
    }

    /* INTERNAL HELPERS */

    /// @dev Settles a position's principal token deltas against the pool manager during an LP action.
    function _settlePrincipal(Currency currency, int128 amount, address lp) private {
        if (amount < 0) {
            poolManager.sync(currency);
            IERC20Minimal(Currency.unwrap(currency)).transferFrom(lp, address(poolManager), uint256(uint128(-amount)));
            poolManager.settle();
        } else if (amount > 0) {
            poolManager.take(currency, lp, uint256(uint128(amount)));
        }
    }

    /// @dev Transfers any settled-but-unpaid rewards for `positionKey` directly to `lp`. No-op when nothing owed.
    function _payRewards(PoolId poolId, bytes32 positionKey, Currency currency0, address lp) private {
        uint256 owed = _positions[positionKey].owed;
        if (owed == 0) return;
        _positions[positionKey].owed = 0;
        currency0.transfer(lp, owed);
        emit EventsLib.RewardsClaimed(poolId, lp, owed);
    }

    /// @dev Accrues rewards for `positionKey` into `owed` and advances the growth checkpoint.
    function _settlePosition(
        PoolId poolId,
        bytes32 positionKey,
        int24 currentTick,
        int24 tickLower,
        int24 tickUpper
    ) private {
        Position storage pos = _positions[positionKey];
        uint256 insideX128 = _poolRewards[poolId].getGrowthInside(currentTick, tickLower, tickUpper);
        unchecked {
            pos.owed += RewardGrowthLib.rewardsOf(insideX128, pos.lastGrowthInsideX128, pos.liquidity);
        }
        pos.lastGrowthInsideX128 = insideX128;
    }

    /// @dev Applies a signed liquidity delta to a position, clamping at zero on removal.
    function _applyLiquidity(bytes32 positionKey, int256 liquidityDelta) private {
        Position storage pos = _positions[positionKey];
        if (liquidityDelta > 0) {
            pos.liquidity += uint128(uint256(liquidityDelta));
        } else if (liquidityDelta < 0) {
            uint128 dec = uint128(uint256(-liquidityDelta));
            pos.liquidity = pos.liquidity >= dec ? pos.liquidity - dec : 0;
        }
    }

    /// @dev Derives the storage key for a position.
    function _positionKey(
        PoolId poolId,
        address owner_,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            PoolId.unwrap(poolId), 
            owner_, 
            tickLower, 
            tickUpper, 
            salt
        ));
    }
}
