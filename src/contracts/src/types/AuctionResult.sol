// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Record of the arb order an operator included when settling a (pool, block).
///
/// In the operator-batch model the winner is selected off-chain by the operator; there is no
/// on-chain commit. This record is written by the Settler at settlement time and exists purely so a
/// fraud proof can later show the operator included a strictly worse arb order than one that was
/// available — see `IAuctionServiceManager.challengeSettlement`.
///
/// The winning order's terms are stored (not the derived bid) because dominance between two orders
/// is AMM-independent: an order with `quantityIn' >= quantityIn` and `quantityOut' <= quantityOut`
/// (strict in at least one) always yields a strictly larger token0 bid, for any AMM state.
///
/// Layout packs into two storage slots.
/// @param operator Operator that executed the settlement (slashed on a successful challenge).
/// @param settledBlock Block at which settlement occurred (challenge-window anchor).
/// @param zeroForOne Direction of the included arb order.
/// @param settled Whether a settlement was recorded for this (pool, block).
/// @param challenged Whether a fraud proof succeeded and the operator was slashed.
/// @param quantityIn Input quantity of the included arb order.
/// @param quantityOut Output quantity of the included arb order.
struct AuctionResult {
    address operator;
    uint64 settledBlock;
    bool zeroForOne;
    bool settled;
    bool challenged;
    uint128 quantityIn;
    uint128 quantityOut;
}
