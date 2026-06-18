// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Committed result of an LVR auction round.
/// @param bidAmount ETH amount the winner committed to pay the LP reward distributor.
/// @param winner Address that won the auction and must execute the arb swap.
/// @param committed Whether a result has been committed for this (poolId, blockNumber) pair.
/// @param challenged Whether a fraud-proof challenge succeeded and the result was invalidated.
/// @param committedBlock Block number at which `commitWinner` was called (challenge window anchor).
/// @param signers Ordered list of operators whose signatures satisfied the quorum (used for slashing).
struct AuctionResult {
    uint256 bidAmount;
    address winner;
    bool committed;
    bool challenged;
    uint256 committedBlock;
    address[] signers;
}
