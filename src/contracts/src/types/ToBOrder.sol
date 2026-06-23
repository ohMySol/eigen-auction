// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

using ToBOrderLib for ToBOrder global;

// EIP-712 typehash for arbitrageur top-of-block order signature verification.
bytes32 constant TOB_ORDER_TYPEHASH = keccak256(
    "ToBOrder(address searcher,bytes32 poolId,bool zeroForOne,bool useInternal,"
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

/// @title ToBOrderLib
/// @author ohMySol
/// @dev Encoding helpers for `ToBOrder`. Used by both the Settler (signature / result-hash checks) and the
/// TaskManager (challenge fraud proof), so there is a single canonical encoding across the system.
library ToBOrderLib {
    /// @notice Returns the EIP-712 struct hash of the order's terms. The signature field is
    /// excluded because it is the proof over those terms, not part of the message being proved.
    /// @param order The arb order to hash.
    /// @return The EIP-712 struct hash, safe to use in an EIP-191 digest.
    function toBStructHash(ToBOrder memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                TOB_ORDER_TYPEHASH,
                order.searcher,
                order.poolId,
                order.zeroForOne,
                order.useInternal,
                order.quantityIn,
                order.quantityOut,
                order.validForBlock
            )
        );
    }
}
