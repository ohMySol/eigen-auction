// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

using SwapIntentLib for SwapIntent global;

// Intent typehash for users signature verification
bytes32 constant INTENT_TYPEHASH = keccak256(
    "SwapIntent(address user,bytes32 poolId,bool zeroForOne,bool useInternal,"
    "uint128 amountIn,uint128 minAmountOut,uint64 nonce,uint64 deadline)"
);

/// @notice An off-chain swap intent signed by the user.
///
/// Users sign this struct (EIP-712) and deliver it to the operator's private RPC rather than
/// broadcasting a transaction. The winning operator batches received intents into `settle`.
///
/// @param user Signer and token source / recipient.
/// @param poolId `PoolId.unwrap(key.toId())` — binds the intent to a specific pool,
/// preventing cross-pool replay when the same settler serves multiple pools.
/// @param zeroForOne Swap direction: currency0 --> currency1 when `true`.
/// @param useInternal When `true`, settle from the user's internal Settler balance instead of
/// pulling/pushing tokens via ERC20 transfers. Lets active traders pre-fund once and fill many
/// intents without per-intent approvals.
/// @param amountIn Exact input amount the settler is authorised to pull from `user`.
/// @param minAmountOut Minimum output the user accepts; the fill reverts if not met.
/// @param nonce Single-use value for replay protection (bitmap scheme, not sequential).
/// Users choose any unused 64-bit value; call `isNonceUsed` to check.
/// @param deadline Latest `block.timestamp` at which this intent may be filled.
/// @param signature 65-byte ECDSA (r, s, v) over the EIP-712 struct hash.
struct SwapIntent {
    address user;
    bytes32 poolId;
    bool zeroForOne;
    bool useInternal;
    uint128 amountIn;
    uint128 minAmountOut;
    uint64 nonce;
    uint64 deadline;
    bytes signature;
}

/// @title SwapIntentLib
/// @notice This library allows to derive the hash of the `SwapInten` struct
library SwapIntentLib {
    /// @dev Reruturns EIP-712 struct hash of an intent's terms. Signature excluded, because 
    /// EIP-712 defines the struct hash as a hash of the typed data. The signature is the proof, 
    /// not part of the message being proved. It lives alongside the struct in calldata but is never hashed into it.
    /// @param intent User swap intent
    function intentStructHash(SwapIntent memory intent) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                INTENT_TYPEHASH,
                intent.user,
                intent.poolId,
                intent.zeroForOne,
                intent.useInternal,
                intent.amountIn,
                intent.minAmountOut,
                intent.nonce,
                intent.deadline
            )
        );
    }
}