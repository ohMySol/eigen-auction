// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// EIP-712 typehash for arbitrageur top-of-block order signature verification.
bytes32 constant TOB_ORDER_TYPEHASH = keccak256(
    "ToBOrder(address arber,bytes32 poolId,bool zeroForOne,bool useInternal,"
    "uint128 quantityIn,uint128 quantityOut,uint64 validForBlock)"
);

/// @notice A top-of-block arbitrage order signed off-chain by an arbitrageur and included in the
/// operator's batch. The operator selects the order whose terms leave the largest surplus for LPs.
///
/// Unlike a `SwapIntent`, the arb's reward (bid) is NOT stated in the order — it is derived on-chain
/// from the difference between the AMM's deterministic quote and the order's specified amounts, and
/// is always expressed in currency0:
///   - zeroForOne (arb pays token0, wants token1): bid = quantityIn - ammIn (exact-output swap)
///   - oneForZero (arb pays token1, wants token0): bid = ammOut - quantityOut (exact-input swap)
/// The operator therefore cannot inflate or fake the reward — it is a deterministic function of the
/// pool state and the signed order.
///
/// @param searcher Signer (arbitrageur); token source and recipient of the arb fill.
/// @param poolId `PoolId.unwrap(key.toId())` — binds the order to a specific pool.
/// @param zeroForOne Swap direction: currency0 → currency1 when `true`.
/// @param useInternal Settle from the searchers internal Settler balance instead of ERC20 transfers.
/// @param quantityIn Amount of the input currency the searcher commits to pay.
/// @param quantityOut Amount of the output currency the searcher accepts to receive.
/// @param validForBlock Block number this order is valid for; bounds replay to a single block.
/// @param signature 65-byte ECDSA (r, s, v) over the EIP-712 struct hash.
struct ToBOrder {
    address searcher;
    bytes32 poolId;
    bool zeroForOne;
    bool useInternal;
    uint128 quantityIn;
    uint128 quantityOut;
    uint64 validForBlock;
    bytes signature;
}
