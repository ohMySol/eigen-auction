// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {FixedPoint128} from "v4-core/libraries/FixedPoint128.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

import {ISettler} from "./interfaces/ISettler.sol";
import {IEigenAuctionServiceManager} from "./interfaces/IEigenAuctionServiceManager.sol";
import {ICommitmentReader} from "./interfaces/ICommitmentReader.sol";
import {Commitment} from "./types/Commitment.sol";
import {SwapIntent} from "./types/SwapIntent.sol";
import {ToBOrder} from "./types/ToBOrder.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";

/// @dev Minimal hook surface used during settlement.
interface IHook {
    function recordSettlement(PoolId poolId) external;
    function distributeReward(PoolKey calldata key, uint256 amount) external;
}

/// @title Settler
/// @author ohMySol
/// @notice Atomic batch-settlement contract for all EigenAuction pools. Deploy once per
/// chain; register on each pool's hook via `hook.setSettler(address(this))` and on the AVS via
/// `avs.setSettler(address(this))`.
///
/// A randomly selected AVS operator aggregates the block's signed arbitrage order and user intents
/// off-chain and calls `settle(key, arbitrage, intents, clearingPriceX128)` once per pool per block. The
/// whole batch executes inside a single Uniswap V4 unlock, so its ordering cannot be tampered with by
/// proposers or builders.
///
/// Step 1 — Top-of-block arbitrage.
/// The signed `ToBOrder` is executed as one AMM swap. The LP reward (bid) is derived on-chain, always
/// in currency0, as the gap between the AMM's deterministic quote and the order's amounts:
///   - zeroForOne: bid = quantityIn - ammIn (exact-output swap for quantityOut)
///   - oneForZero: bid = ammOut - quantityOut (exact-input swap of quantityIn)
/// The bid is sent to the hook and folded into LP rewards at the post-arbitrage price.
///
/// Step 2 — Uniform-clearing-price user batch.
/// Every intent clears at the single operator-supplied `clearingPriceX128` (currency1 per currency0,Q128), 
/// so there is no intra-batch ordering MEV. Opposite-direction intents net against each other;
/// only the leftover imbalance hits the AMM as one swap. Any currency0 residual goes to LPs. Each
/// fill must satisfy the signer's `minAmountOut`, and the batch must be solvent or the call reverts.
contract Settler is ISettler, IUnlockCallback, Ownable {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;

    /* CONSTANTS */

    bytes32 private constant _DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /* IMMUTABLES */

    /// @inheritdoc ISettler
    IPoolManager public immutable poolManager;

    /// @inheritdoc ISettler
    IEigenAuctionServiceManager public immutable avs;

    /// @inheritdoc ISettler
    ICommitmentReader public immutable taskManager;

    /// @inheritdoc ISettler
    bytes32 public immutable DOMAIN_SEPARATOR;

    /* STORAGE */

    /// @dev user => (nonce >> 8) => 256-bit bitmap.
    mapping(address => mapping(uint248 => uint256)) private _nonces;

    /// @inheritdoc ISettler
    mapping(address => mapping(address => uint256)) public balanceOf;

    /// @inheritdoc ISettler
    uint256 public operatorFeeBps;

    /// @dev Decoded settlement payload passed through the V4 unlock.
    struct SettleData {
        PoolKey key;
        ToBOrder arb;
        SwapIntent[] intents;
        uint256 clearingPriceX128;
    }

    /* MODIFIERS */

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert ErrorsLib.Settler_NotPoolManager();
        _;
    }

    /* CONSTRUCTOR */

    /// @param _poolManager Uniswap V4 pool manager.
    /// @param _avs AVS service manager; receives the operator fee cut from each settlement and owns
    /// the EigenLayer rewards submission surface.
    /// @param _taskManager EigenAuctionTaskManager whose commitments gate settlement. May be the
    /// zero address in a partial deploy — `settle` reverts on the first commitment read until it is set.
    /// @param _owner Governance address that tunes the operator fee rate.
    /// @param _operatorFeeBps Initial operator fee, in basis points. Must not exceed `MAX_OPERATOR_FEE_BPS`.
    constructor(
        address _poolManager, 
        address _avs, 
        address _taskManager, 
        address _owner,
        uint256 _operatorFeeBps
    ) Ownable(_owner) {
        if (_poolManager == address(0) || _avs == address(0)) {
            revert ErrorsLib.Settler_ConstructorZeroAddress();
        }
        if (_operatorFeeBps > ConstantsLib.MAX_OPERATOR_FEE_BPS) revert ErrorsLib.Settler_FeeTooHigh();

        poolManager = IPoolManager(_poolManager);
        avs = IEigenAuctionServiceManager(_avs);
        taskManager = ICommitmentReader(_taskManager);

        operatorFeeBps = _operatorFeeBps;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH, 
                keccak256("EigenAuction Settler"), 
                keccak256("1"), 
                block.chainid, 
                address(this)
            )
        );
    }

    /* GOVERNANCE */

    /// @inheritdoc ISettler
    function setOperatorFeeBps(uint256 newOperatorFeeBps) external onlyOwner {
        if (newOperatorFeeBps > ConstantsLib.MAX_OPERATOR_FEE_BPS) revert ErrorsLib.Settler_FeeTooHigh();
        operatorFeeBps = newOperatorFeeBps;
        emit EventsLib.OperatorFeeBpsSet(newOperatorFeeBps);
    }

    /* INTERNAL BALANCES */

    /// @inheritdoc ISettler
    function deposit(address asset, uint256 amount) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        balanceOf[asset][msg.sender] += amount;
        emit EventsLib.Deposited(asset, msg.sender, amount);
    }

    /// @inheritdoc ISettler
    function withdraw(address asset, uint256 amount) external {
        uint256 bal = balanceOf[asset][msg.sender];

        if (bal < amount) revert ErrorsLib.Settler_InsufficientBalance();

        balanceOf[asset][msg.sender] = bal - amount;

        IERC20(asset).safeTransfer(msg.sender, amount);
        emit EventsLib.Withdrawn(asset, msg.sender, amount);
    }

    /* SETTLEMENT */

    /// @inheritdoc ISettler
    function settle(
        PoolKey calldata key,
        ToBOrder calldata arb,
        SwapIntent[] calldata intents,
        uint256 clearingPriceX128
    ) external {
        bool hasArb = arb.quantityIn != 0 || arb.quantityOut != 0;
        if (!hasArb && intents.length == 0) revert ErrorsLib.Settler_NothingToSettle();
        if (intents.length != 0 && clearingPriceX128 == 0) revert ErrorsLib.Settler_ZeroClearingPrice();

        PoolId poolId = key.toId();

        // The quorum attested this exact batch for this block and bound the operator allowed to relay
        // it. Re-derive the result and match it against the commitment before any state changes, so an
        // executor can only push the batch the operator set actually signed off on.
        Commitment memory commitment = taskManager.getCommitment(poolId, block.number);
        if (!commitment.exists) revert ErrorsLib.Settler_NoCommitment();
        if (computeResultHash(arb, clearingPriceX128, intents) != commitment.resultHash) {
            revert ErrorsLib.Settler_ResultMismatch();
        }
        if (msg.sender != commitment.executor) revert ErrorsLib.Settler_NotExecutor();

        // Settles at most once per block per pool (enforced by the hook).
        IHook(address(key.hooks)).recordSettlement(poolId);

        poolManager.unlock(
            abi.encode(
                SettleData({
                    key: key,
                    arb: arb,
                    intents: intents,
                    clearingPriceX128: clearingPriceX128
                })
            )
        );

        emit EventsLib.BlockSettled(poolId, block.number, msg.sender);
    }

    /* V4 UNLOCK CALLBACK */

    function unlockCallback(bytes calldata data) external override onlyPoolManager returns (bytes memory) {
        SettleData memory stlData = abi.decode(data, (SettleData));

        if (stlData.arb.quantityIn != 0 || stlData.arb.quantityOut != 0) {
            _executeArb(stlData.key, stlData.arb);
        }

        if (stlData.intents.length != 0) {
            _executeBatch(stlData.key, stlData.intents, stlData.clearingPriceX128);
        }

        return "";
    }

    /* ARB */

    /// @dev Executes the signed arb order as one AMM swap, derives the currency0 bid, and folds it
    /// into LP rewards via the hook.
    function _executeArb(PoolKey memory key, ToBOrder memory arb) private {
        _verifyArb(key, arb);

        PoolId poolId = key.toId();
        bytes memory hookData = abi.encode(poolManager.getLiquidity(poolId)); // JIT guard snapshot

        uint256 bid;
        if (arb.zeroForOne) {
            // Exact-output: receive exactly quantityOut token1, pay ammIn token0.
            BalanceDelta delta = poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: true,
                    amountSpecified: int256(uint256(arb.quantityOut)),
                    sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
                }),
                hookData
            );

            uint256 ammIn = uint256(uint128(-delta.amount0()));
            if (arb.quantityIn < ammIn) revert ErrorsLib.Settler_NegativeBid();

            _pullIn(arb.searcher, key.currency0, arb.quantityIn, arb.useInternal);
            _settleToPool(key.currency0, ammIn);

            poolManager.take(key.currency1, address(this), uint256(uint128(delta.amount1())));

            _payOut(arb.searcher, key.currency1, uint256(uint128(delta.amount1())), arb.useInternal);

            bid = arb.quantityIn - ammIn;
        } else {
            // Exact-input: pay exactly quantityIn token1, receive ammOut token0.
            BalanceDelta delta = poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: false,
                    amountSpecified: -int256(uint256(arb.quantityIn)),
                    sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
                }),
                hookData
            );
            
            uint256 ammOut = uint256(uint128(delta.amount0()));
            if (ammOut < arb.quantityOut) revert ErrorsLib.Settler_NegativeBid();

            _pullIn(arb.searcher, key.currency1, arb.quantityIn, arb.useInternal);
            _settleToPool(key.currency1, arb.quantityIn);
            
            poolManager.take(key.currency0, address(this), ammOut);
            
            _payOut(arb.searcher, key.currency0, arb.quantityOut, arb.useInternal);

            bid = ammOut - arb.quantityOut;
        }

        if (bid != 0) _rewardHook(key, bid);
        emit EventsLib.ArbFilled(key.toId(), arb.searcher, bid);
    }

    /* USER BATCH */

    /// @dev Clears all intents at one uniform price, nets opposite directions, swaps only the leftover
    /// imbalance against the AMM, and routes any currency0 residual to LPs.
    function _executeBatch(PoolKey memory key, SwapIntent[] memory intents, uint256 priceX128) private {
        bytes32 poolId = PoolId.unwrap(key.toId());

        // Phase 1: validate every intent and collect inputs; accumulate per-token totals.
        uint256 t0in;
        uint256 t1in;
        uint256 t0out;
        uint256 t1out;
        uint256 n = intents.length;
        for (uint256 i; i < n; ++i) {
            SwapIntent memory intent = intents[i];
            if (intent.poolId != poolId) revert ErrorsLib.Settler_WrongPool();
            if (block.timestamp > intent.deadline) revert ErrorsLib.Settler_IntentExpired();
            _useNonce(intent.user, intent.nonce);
            _verifyIntent(intent);

            if (intent.zeroForOne) {
                uint256 out1 = FullMath.mulDiv(intent.amountIn, priceX128, FixedPoint128.Q128);
                if (out1 < intent.minAmountOut) revert ErrorsLib.Settler_SlippageExceeded();
                _pullIn(intent.user, key.currency0, intent.amountIn, intent.useInternal);
                t0in += intent.amountIn;
                t1out += out1;
            } else {
                uint256 out0 = FullMath.mulDiv(intent.amountIn, FixedPoint128.Q128, priceX128);
                if (out0 < intent.minAmountOut) revert ErrorsLib.Settler_SlippageExceeded();
                _pullIn(intent.user, key.currency1, intent.amountIn, intent.useInternal);
                t1in += intent.amountIn;
                t0out += out0;
            }
        }

        // Phase 2: trade only the net imbalance against the AMM. token1 ends exactly at t1out; any
        // surplus is left in token0 so it can reward LPs.
        uint256 token0Available = t0in;
        if (t1out > t1in) {
            // Net buy token1: zeroForOne exact-output for the shortfall.
            BalanceDelta delta = poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: true,
                    amountSpecified: int256(t1out - t1in),
                    sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
                }),
                ""
            );
            
            uint256 ammIn0 = uint256(uint128(-delta.amount0()));
            if (ammIn0 > token0Available) revert ErrorsLib.Settler_BatchInsolvent();
            
            _settleToPool(key.currency0, ammIn0);
            
            poolManager.take(key.currency1, address(this), t1out - t1in);
            token0Available -= ammIn0;
        } else if (t1in > t1out) {
            // Net sell token1: oneForZero exact-input of the surplus.
            BalanceDelta delta = poolManager.swap(
                key,
                SwapParams({
                    zeroForOne: false,
                    amountSpecified: -int256(t1in - t1out),
                    sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
                }),
                ""
            );
            
            _settleToPool(key.currency1, t1in - t1out);
            uint256 ammOut0 = uint256(uint128(delta.amount0()));
            
            poolManager.take(key.currency0, address(this), ammOut0);
            token0Available += ammOut0;
        }

        if (token0Available < t0out) revert ErrorsLib.Settler_BatchInsolvent();

        // Phase 3: pay every intent its clearing-price output.
        for (uint256 i; i < n; ++i) {
            SwapIntent memory intent = intents[i];
            
            if (intent.zeroForOne) {
                uint256 out1 = FullMath.mulDiv(intent.amountIn, priceX128, FixedPoint128.Q128);
                _payOut(intent.user, key.currency1, out1, intent.useInternal);
                emit EventsLib.IntentFilled(key.toId(), intent.user, true, intent.amountIn, out1);
            } else {
                uint256 out0 = FullMath.mulDiv(intent.amountIn, FixedPoint128.Q128, priceX128);
                _payOut(intent.user, key.currency0, out0, intent.useInternal);
                emit EventsLib.IntentFilled(key.toId(), intent.user, false, intent.amountIn, out0);
            }
        }

        // Phase 4: any leftover currency0 is surplus the batch produced — give it to LPs.
        uint256 residual0 = token0Available - t0out;
        if (residual0 != 0) _rewardHook(key, residual0);
    }

    /* NONCE MANAGEMENT */

    /// @inheritdoc ISettler
    function invalidateNonce(uint64 nonce) external {
        _useNonce(msg.sender, nonce);
        emit EventsLib.NonceInvalidated(msg.sender, nonce);
    }

    /// @inheritdoc ISettler
    function isNonceUsed(address user, uint64 nonce) external view returns (bool) {
        return _nonces[user][uint248(nonce >> 8)] & (1 << (nonce & 0xff)) != 0;
    }

    /* RESULT HASH */

    /// @inheritdoc ISettler
    function computeResultHash(
        ToBOrder calldata arb, 
        uint256 clearingPriceX128, 
        SwapIntent[] calldata intents
    ) public pure returns (bytes32) {
        bool hasArb = arb.quantityIn != 0 || arb.quantityOut != 0;
        bytes32 arbOrderHash = hasArb ? arb.toBStructHash() : bytes32(0);

        uint256 n = intents.length;
        bytes32[] memory hashes = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            hashes[i] = intents[i].intentStructHash();
        }
        bytes32 intentsRoot = keccak256(abi.encode(hashes));

        return keccak256(abi.encode(arbOrderHash, clearingPriceX128, intentsRoot));
    }
    
    /* INTERNAL — TOKEN MOVEMENT */

    /// @dev Pulls `amount` of `currency` from `from`: debits internal balance when `useInternal`, else
    /// transfers in via ERC20.
    function _pullIn(address from, Currency currency, uint256 amount, bool useInternal) private {
        if (amount == 0) return;
        address asset = Currency.unwrap(currency);

        if (useInternal) {
            uint256 bal = balanceOf[asset][from];
            if (bal < amount) revert ErrorsLib.Settler_InsufficientBalance();
            balanceOf[asset][from] = bal - amount;
        } else {
            IERC20(asset).safeTransferFrom(from, address(this), amount);
        }
    }

    /// @dev Pays `amount` of `currency` to `to`: credits internal balance when `useInternal`, else transfers
    /// out via ERC20.
    function _payOut(address to, Currency currency, uint256 amount, bool useInternal) private {
        if (amount == 0) return;
        address asset = Currency.unwrap(currency);

        if (useInternal) {
            balanceOf[asset][to] += amount;
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }

    /// @dev Settles `amount` of `currency` from this contract's balance to the pool manager.
    function _settleToPool(Currency currency, uint256 amount) private {
        poolManager.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransfer(address(poolManager), amount);
        poolManager.settle();
    }

    /// @dev Single point where captured currency0 value (arbitrage bid or batch residual) is routed out.
    /// Takes the operator fee and pushes it to the ServiceManager so it can fund EigenLayer reward
    /// submissions; forwards the remainder to the hook for LP distribution.
    function _rewardHook(PoolKey memory key, uint256 amount) private {
        address asset = Currency.unwrap(key.currency0);

        uint256 fee = (amount * operatorFeeBps) / ConstantsLib.BPS;
        if (fee != 0) {
            IERC20(asset).safeTransfer(address(avs), fee);
            avs.receiveOperatorFee(asset, fee);
        }

        uint256 lpAmount = amount - fee;
        if (lpAmount != 0) {
            IERC20(asset).safeTransfer(address(key.hooks), lpAmount);
            IHook(address(key.hooks)).distributeReward(key, lpAmount);
        }
    }

    /* INTERNAL — NONCES & SIGNATURES */

    function _useNonce(address user, uint64 nonce) private {
        uint248 word = uint248(nonce >> 8);
        uint256 bit = 1 << (nonce & 0xff);
        uint256 prev = _nonces[user][word];
        if (prev & bit != 0) revert ErrorsLib.Settler_NonceUsed();
        _nonces[user][word] = prev | bit;
    }

    function _verifyIntent(SwapIntent memory intent) private view {
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", DOMAIN_SEPARATOR, intent.intentStructHash()));
        (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, intent.signature);

        if (err != ECDSA.RecoverError.NoError || signer != intent.user) revert ErrorsLib.Settler_InvalidSignature();
    }

    function _verifyArb(PoolKey memory key, ToBOrder memory arb) private view {
        if (arb.poolId != PoolId.unwrap(key.toId())) revert ErrorsLib.Settler_WrongPool();
        if (arb.validForBlock != block.number) revert ErrorsLib.Settler_WrongBlock();

        bytes32 digest = keccak256(abi.encodePacked(hex"1901", DOMAIN_SEPARATOR, arb.toBStructHash()));
        (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, arb.signature);

        if (err != ECDSA.RecoverError.NoError || signer != arb.searcher) revert ErrorsLib.Settler_InvalidArbSignature();
    }
}
