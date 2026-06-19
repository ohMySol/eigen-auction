// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {IAuctionServiceManager} from "./IAuctionServiceManager.sol";
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
    function balanceOf(address asset, address user) external view returns (uint256);

    /// @notice Deposits `amount` of `asset` into the caller's internal balance.
    function deposit(address asset, uint256 amount) external;

    /// @notice Withdraws `amount` of `asset` from the caller's internal balance.
    function withdraw(address asset, uint256 amount) external;

    /* SETTLEMENT */

    /// @notice Settle a block for `key`: execute the arb order, then clear user intents at one price.
    /// @dev Caller must be an AVS-registered operator. Reverts if both the arb order is empty
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

    /* NONCE MANAGEMENT */

    /// @notice Cancel a nonce so the corresponding pending intent can never be filled.
    /// @param nonce The nonce to invalidate.
    function invalidateNonce(uint64 nonce) external;

    /// @notice Returns `true` if `nonce` has been used or explicitly invalidated for `user`.
    function isNonceUsed(address user, uint64 nonce) external view returns (bool);

    /* VIEW */

    /// @notice The Uniswap V4 pool manager this settler submits swaps to.
    function poolManager() external view returns (IPoolManager);

    /// @notice The AVS service manager that authorizes operators and records settlements.
    function avs() external view returns (IAuctionServiceManager);

    /// @notice EIP-712 domain separator used when verifying intent and arb-order signatures.
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
