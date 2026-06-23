// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice A quorum-attested auction result for a single (pool, block).
/// @dev EigenLayer-free on purpose: lives in `types/` so the `^0.8.0` Settler can read commitments
/// without importing the `^0.8.27` eigenlayer-middleware graph the TaskManager itself depends on.
/// The mapping key (target block) doubles as the commit block, so it isn't stored again.
/// @param resultHash `keccak256(arbOrderHash, clearingPriceX128, intentsRoot)` — the exact batch the
/// executor must reproduce at settle time (see `ISettler.computeResultHash`).
/// @param hashOfNonSigners Identifies the hash of operators pub keys that didn't sign; consumed by the fraud-proof slash.
/// @param executor The off-chain selected operator allowed to call `settle` for this commitment.
/// @param exists Whether a commitment was recorded.
/// @param challenged Whether a fraud proof has succeeded against this commitment.
struct Commitment {
    bytes32 resultHash;
    bytes32 hashOfNonSigners;
    address executor;
    bool exists;
    bool challenged;
}
