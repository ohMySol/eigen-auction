// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";

import {IEigenAuctionHook, Position} from "./interfaces/IEigenAuctionHook.sol";
import {IAuctionServiceManager, AuctionResult} from "./interfaces/IAuctionServiceManager.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {RewardGrowthLib} from "./libraries/RewardGrowthLib.sol";

/// @title EigenAuctionHook
/// @author ohMySol
/// @notice Uniswap V4 hook that enforces an EigenLayer AVS secured arbitrage auction. A swap may flag
/// itself as an arbitrage by encoding `true` in `hookData`. When it does, the hook requires the
/// caller to be the AVS-committed winner for the current block. On settlement the committed bid is
/// skimmed from the swap's output currency via `afterSwapReturnDelta` and folded into a per-tick
/// reward-growth accumulator, so it flows back to the in-range liquidity providers — proportional to
/// their liquidity, V3 fee-growth style. Non-arbitrage swaps pass through untouched.
/// @dev The bid is taken in whichever pool currency is the swap's unspecified (output) side, so
/// rewards are tracked per currency (index 0 = `currency0`, 1 = `currency1`). Payment is atomic with
/// the swap — no escrow. Rewards are tracked per position (`owner, tickLower, tickUpper, salt`) and an
/// LP claims a position's currency0 and currency1 rewards together.
contract EigenAuctionHook is BaseHook, IEigenAuctionHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using CurrencyLibrary for Currency;
    using SafeCast for uint256;

    /* IMMUTABLE VARIABLES */

    /// @inheritdoc IEigenAuctionHook
    IAuctionServiceManager public immutable avs;

    /* REWARD ACCOUNTING STORAGE */

    /// @inheritdoc IEigenAuctionHook
    mapping(PoolId => uint256[2]) public rewardGrowthGlobalX128;

    /// @dev positionKey => position. Keyed by `keccak256(poolId, owner, lower, upper, salt)`.
    mapping(bytes32 => Position) private _positions;

    /* CONSTRUCTOR */

    /// @param _poolManager Address of the Uniswap V4 pool manager.
    /// @param _avs Address of the auction service manager that commits winners.
    constructor(address _poolManager, address _avs) BaseHook(IPoolManager(_poolManager)) {
        if (_avs == address(0)) revert ErrorsLib.EigenAuctionHook_ZeroAddress();
        avs = IAuctionServiceManager(_avs);
    }

    /// @inheritdoc BaseHook
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /* REWARD CLAIMING */

    /// @inheritdoc IEigenAuctionHook
    function claimRewards(
        PoolKey calldata key, 
        int24 tickLower, 
        int24 tickUpper, 
        bytes32 salt
    ) external {
        PoolId poolId = key.toId();
        bytes32 pk = _positionKey(poolId, msg.sender, tickLower, tickUpper, salt);

        _settle(poolId, pk, tickLower, tickUpper);

        Position storage pos = _positions[pk];
        uint256 owed0 = pos.owed[0];
        uint256 owed1 = pos.owed[1];
        if (owed0 == 0 && owed1 == 0) revert ErrorsLib.EigenAuctionHook_NothingToClaim();

        pos.owed[0] = 0;
        pos.owed[1] = 0;

        if (owed0 > 0) key.currency0.transfer(msg.sender, owed0);
        if (owed1 > 0) key.currency1.transfer(msg.sender, owed1);

        emit EventsLib.RewardsClaimed(poolId, msg.sender, owed0, owed1);
    }

    /// @inheritdoc IEigenAuctionHook
    function earned(
        PoolKey calldata key, 
        address owner, 
        int24 tickLower, 
        int24 tickUpper, 
        bytes32 salt
    ) external view returns (uint256 amount0, uint256 amount1) {
        PoolId poolId = key.toId();
        Position storage pos = _positions[_positionKey(
            poolId, 
            owner, 
            tickLower, 
            tickUpper, 
            salt
        )];
        
        amount0 = pos.owed[0] + RewardGrowthLib.rewardsOf(
            _growthInside(poolId, tickLower, tickUpper, 0), 
            pos.lastGrowthInsideX128[0], 
            pos.liquidity
        );
        
        amount1 = pos.owed[1] + RewardGrowthLib.rewardsOf(
            _growthInside(poolId, tickLower, tickUpper, 1), 
            pos.lastGrowthInsideX128[1], 
            pos.liquidity
        );
    }

    /// @inheritdoc IEigenAuctionHook
    function positionLiquidity(
        PoolKey calldata key, 
        address owner, 
        int24 tickLower, 
        int24 tickUpper, 
        bytes32 salt
    ) external view override returns (uint128) {
        PoolId poolId = key.toId();
        return _positions[_positionKey(poolId, owner, tickLower, tickUpper, salt)].liquidity;
    }

    /* SWAP HOOKS */

    /// @dev Only the auction winner is allowed to execute a swap that self-identifies as arbitrage. 
    /// Any other address calling with that flag gets reverted. Swaps without the flag pass through 
    /// untouched — regular users are completely unaffected.
    /// Reverts if no winner is committed for the block or the caller is not the committed winner.
    function _beforeSwap(
        address sender, 
        PoolKey calldata key, 
        SwapParams calldata, 
        bytes calldata hookData
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        if (!_isArb(hookData)) {
            return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        AuctionResult memory result = avs.getWinner(key.toId(), block.number);
        if (!result.committed) revert ErrorsLib.EigenAuctionHook_AuctionNotCommitted();
        if (sender != result.winner) revert ErrorsLib.EigenAuctionHook_NotWinner();

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @dev Settles a winning arb swap: skims the committed bid from the swap's unspecified (output)
    /// currency via the returned hook delta, takes it into the hook, and folds it into that currency's
    /// reward-growth accumulator. Non arbitrage swaps short-circuit.
    function _afterSwap(
        address sender, 
        PoolKey calldata key, 
        SwapParams calldata params, 
        BalanceDelta, 
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        if (!_isArb(hookData)) {
            return (IHooks.afterSwap.selector, 0);
        }

        PoolId poolId = key.toId();
        uint256 bid = avs.getWinner(poolId, block.number).bidAmount;
        if (bid == 0) {
            return (IHooks.afterSwap.selector, 0);
        }

        // The hook delta applies to the swap's unspecified currency: the output for an exact-input
        // swap, the input for an exact-output swap. Determine which pool currency that is.
        bool unspecifiedIsCurrency1 = params.zeroForOne == (params.amountSpecified < 0);
        uint8 i = unspecifiedIsCurrency1 ? 1 : 0;
        Currency feeCurrency = unspecifiedIsCurrency1 ? key.currency1 : key.currency0;

        // Pull the bid into the hook (a debit) and return it as a positive delta on the unspecified
        // currency (a credit) — the two net to zero for the hook while charging the swapper the bid.
        poolManager.take(feeCurrency, address(this), bid);
        _distribute(poolId, i, bid);

        emit EventsLib.ArbitrageSettled(poolId, sender, i, bid);
        return (IHooks.afterSwap.selector, bid.toInt128());
    }

    /* LIQUIDITY HOOKS */

    /// @dev Mirrors the LP's increased liquidity into the position's reward accounting.
    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _updatePosition(
            key, 
            sender, 
            params.tickLower, 
            params.tickUpper, 
            params.salt, 
            params.liquidityDelta
        );
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /// @dev Mirrors the LP's decreased liquidity into the position's reward accounting.
    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        _updatePosition(
            key, 
            sender, 
            params.tickLower, 
            params.tickUpper, 
            params.salt, 
            params.liquidityDelta
        );
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    /* INTERNAL HELPERS */

    /// @dev Folds `amount` of currency `i` into that currency's global reward-growth accumulator,
    /// spread across the liquidity currently in range. No in-range liquidity --> nobody to credit.
    function _distribute(PoolId poolId, uint8 i, uint256 amount) private {
        uint128 active = poolManager.getLiquidity(poolId);
        if (active == 0) return;
        rewardGrowthGlobalX128[poolId][i] += FullMath.mulDiv(amount, FixedPoint128.Q128, active);
    }

    /// @dev Settles a position's accrued rewards (both currencies), then applies the liquidity delta.
    /// Settling first is essential: rewards must accrue on the old liquidity before the share changes.
    function _updatePosition(
        PoolKey calldata key,
        address owner,
        int24 tickLower,
        int24 tickUpper,
        bytes32 salt,
        int256 liquidityDelta
    ) private {
        PoolId poolId = key.toId();
        bytes32 pk = _positionKey(poolId, owner, tickLower, tickUpper, salt);

        _settle(poolId, pk, tickLower, tickUpper);

        Position storage pos = _positions[pk];
        if (liquidityDelta >= 0) {
            pos.liquidity += uint128(uint256(liquidityDelta));
        } else {
            uint128 dec = uint128(uint256(-liquidityDelta));
            pos.liquidity = pos.liquidity >= dec ? pos.liquidity - dec : 0;
        }
    }

    /// @dev Accrues both currencies' rewards earned since the last checkpoint into `owed`, then
    /// advances the checkpoints to the current inside-growth values.
    function _settle(PoolId poolId, bytes32 pk, int24 tickLower, int24 tickUpper) private {
        Position storage pos = _positions[pk];
        for (uint8 i = 0; i < 2; i++) {
            uint256 insideX128 = _growthInside(poolId, tickLower, tickUpper, i);
            pos.owed[i] += RewardGrowthLib.rewardsOf(insideX128, pos.lastGrowthInsideX128[i], pos.liquidity);
            pos.lastGrowthInsideX128[i] = insideX128;
        }
    }

    /// @dev Reward growth inside `[tickLower, tickUpper]` for currency `i`. Per-tick outside growth is
    /// not yet maintained, so distribution is exact at the current tick (in-range liquidity only).
    function _growthInside(PoolId poolId, int24 tickLower, int24 tickUpper, uint8 i)
        private
        view
        returns (uint256)
    {
        (, int24 currentTick,,) = poolManager.getSlot0(poolId);
        return RewardGrowthLib.growthInside(
            currentTick, tickLower, tickUpper, rewardGrowthGlobalX128[poolId][i], 0, 0
        );
    }

    /// @dev Derives the storage key for a position.
    function _positionKey(
        PoolId poolId, 
        address owner, 
        int24 tickLower, 
        int24 tickUpper, 
        bytes32 salt
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            PoolId.unwrap(poolId), 
            owner, 
            tickLower, 
            tickUpper, 
            salt
        ));
    }

    /// @dev Decodes the arb flag from `hookData`. A swap is an arbitrage only when `hookData` is
    /// exactly an ABI-encoded `true`. Empty or malformed data means a normal swap.
    function _isArb(bytes calldata hookData) private pure returns (bool) {
        if (hookData.length != 32) return false;
        return abi.decode(hookData, (bool));
    }
}
