// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {IEigenAuctionServiceManager} from "./IEigenAuctionServiceManager.sol";
import {ICommitmentReader} from "./ICommitmentReader.sol";
import {SwapIntent} from "../types/SwapIntent.sol";
import {ToBOrder} from "../types/ToBOrder.sol";

/// @title ISettler
/// @author ohMySol
/// @notice Batch-settlement entry point for all EigenAuction pools.
///
/// One Settler is deployed per chain. Each `EigenAuctionHook` registers it via `setSettler`, and the
/// AVS registers it via `setSettler`. A randomly selected AVS operator aggregates the block's signed
/// arb order and user intents off-chain and calls `settle` once per pool per block. Everything runs
/// inside a single Uniswap V4 unlock, so the batch's contents cannot be reordered by proposers/builders.
///
/// Step 1 — Top-of-block arb. The signed `ToBOrder` executes as one AMM swap; the LP reward (bid) is
/// derived on-chain in currency0 from the AMM quote vs the order amounts.
///
/// Step 2 — User batch. Every `SwapIntent` clears at one uniform `clearingPriceX128`; opposite
/// directions net against each other and only the leftover hits the AMM. Each fill must satisfy the
/// signer's `minAmountOut`.
interface ISettler {
    /* INTERNAL BALANCES */

    /// @notice Internal balance of `asset` credited to `user`, usable in intents/orders with
    /// `useInternal = true`.
    /// @param asset Token address to query.
    /// @param user Account whose balance is returned.
    /// @return Balance held for `user`.
    function balanceOf(address asset, address user) external view returns (uint256);

    /// @notice Deposits `amount` of `asset` into the caller's internal balance.
    /// @param asset Token to deposit.
    /// @param amount Amount to deposit; pulled from the caller via `transferFrom`.
    function deposit(address asset, uint256 amount) external;

    /// @notice Withdraws `amount` of `asset` from the caller's internal balance.
    /// @param asset Token to withdraw.
    /// @param amount Amount to withdraw; sent to the caller.
    function withdraw(address asset, uint256 amount) external;

    /* SETTLEMENT */

    /// @notice Settle a block for `key`: execute the arb order, then clear user intents at one price.
    /// @dev Gated by the TaskManager commitment for `(poolId, block.number)`: a commitment must exist,
    /// the submitted batch must reproduce its `resultHash` (see `computeResultHash`), and the caller
    /// must be the committed `executor`. Also reverts if both the arb order is empty
    /// (`quantityIn == quantityOut == 0`) and `intents` is empty, if a pool was already settled this
    /// block, or if the batch is insolvent at the supplied clearing price.
    ///
    /// @param key The pool to settle.
    /// @param arb Signed top-of-block arb order. Pass an all-zero order to skip the arb.
    /// @param intents User intents to clear at `clearingPriceX128`.
    /// @param clearingPriceX128 Uniform clearing price (currency1 per currency0, Q128). Required when
    /// `intents` is non-empty.
    function settle(
        PoolKey calldata key,
        ToBOrder calldata arb,
        SwapIntent[] calldata intents,
        uint256 clearingPriceX128
    ) external;

    /* OPERATOR FEE / GOVERNANCE */

    /// @notice Operator fee, in basis points, taken from each currency0 reward and forwarded to
    /// the ServiceManager before LP distribution.
    function operatorFeeBps() external view returns (uint256);

    /// @notice Sets the operator fee rate. Owner-only; reverts above `MAX_OPERATOR_FEE_BPS`.
    /// @param newOperatorFeeBps New fee in basis points.
    function setOperatorFeeBps(uint256 newOperatorFeeBps) external;

    /* NONCE MANAGEMENT */

    /// @notice Cancel a nonce so the corresponding pending intent can never be filled.
    /// @param nonce The nonce to invalidate.
    function invalidateNonce(uint64 nonce) external;

    /// @notice Returns `true` if `nonce` has been used or explicitly invalidated for `user`.
    /// @param user Account whose nonce bitmap is checked.
    /// @param nonce The nonce value to look up.
    function isNonceUsed(address user, uint64 nonce) external view returns (bool);

    /* VIEW */

    /// @notice The Uniswap V4 pool manager this settler submits swaps to.
    function poolManager() external view returns (IPoolManager);

    /// @notice The AVS service manager; retained for operator-set membership and the rewards pipeline.
    function avs() external view returns (IEigenAuctionServiceManager);

    /// @notice The TaskManager whose quorum-attested commitments gate settlement.
    function taskManager() external view returns (ICommitmentReader);

    /// @notice EIP-712 domain separator used when verifying intent and arb-order signatures.
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice Re-derives the committed `resultHash` for a batch: the value the executor must match
    ///
    /// @dev On-chain definition of the committed `resultHash`. The off-chain aggregator MUST
    /// build the operator-signed digest the same way: resultHash = keccak256(arbOrderHash, clearingPriceX128, intentsRoot)
    /// where `arbOrderHash` is the searcher's EIP-712 struct hash (or `bytes32(0)` for an empty arb) and
    /// `intentsRoot = keccak256(abi.encode([intent struct hashes...]))` over the intents in order.
    /// Hashing terms (not signatures) keeps the commitment independent of signature malleability.
    /// against `getCommitment(poolId, block.number).resultHash` at settle time. Off-chain operators
    /// sign this same digest. Hashes order/intent terms (not signatures).
    /// 
    /// @param arb The top-of-block arb order (all-zero amounts for an arb-less batch).
    /// @param clearingPriceX128 Uniform clearing price for the user intents.
    /// @param intents The user intents in the order they are committed.
    function computeResultHash(ToBOrder calldata arb, uint256 clearingPriceX128, SwapIntent[] calldata intents)
        external
        pure
        returns (bytes32);
}
