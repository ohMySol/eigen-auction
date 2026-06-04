// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author @ohMySol
/// @notice A library that defines the errors for EigenAuction Hook smart contract system
library ErrorsLib {
    /* EigenAuctionHook Errors */

    /// @notice Thrown during construction when a required address argument is the zero address
    error EigenAuctionHook_ZeroAddress();

    /// @notice Thrown when an arb-flagged swap targets a block that has no committed auction winner
    error EigenAuctionHook_AuctionNotCommitted();

    /// @notice Thrown when an arb-flagged swap is executed by an address other than the committed winner
    error EigenAuctionHook_NotWinner();

    /// @notice Thrown when an arb-flagged swap targets a result that was invalidated by a challenge
    error EigenAuctionHook_WinnerChallenged();

    /// @notice Thrown when an LP has no rewards to claim for a position
    error EigenAuctionHook_NothingToClaim();

    /* AuctionServiceManager / MockAuctionServiceManager Errors */

    /// @notice Thrown by MockAuctionServiceManager when the caller is not the mock owner
    error AuctionServiceManager_NotOwner();

    /// @notice Thrown when constructing with a threshold of zero
    error AuctionServiceManager_InvalidThreshold();

    /// @notice Thrown when committing a winner for a block that already has a committed result
    error AuctionServiceManager_AlreadyCommitted();

    /// @notice Thrown when committing a winner for a block that is too old (outside the commit window)
    error AuctionServiceManager_StaleBlock();

    /// @notice Thrown when the number of valid unique operator signatures is below the threshold
    error AuctionServiceManager_QuorumNotMet();

    /// @notice Thrown when committing a winner with the zero address as winner
    error AuctionServiceManager_ZeroWinner();

    /// @notice Thrown when challenging a result that has no committed winner
    error AuctionServiceManager_NotCommitted();

    /// @notice Thrown when challenging a result that was already successfully challenged
    error AuctionServiceManager_AlreadyChallenged();

    /// @notice Thrown when the challenge window (CHALLENGE_WINDOW blocks) has closed
    error AuctionServiceManager_ChallengeWindowClosed();

    /// @notice Thrown when the challenger's bid is not strictly greater than the committed bid
    error AuctionServiceManager_NotHigherBid();

    /// @notice Thrown when the bidder signature in a challenge cannot be recovered or does not match higherBidder
    error AuctionServiceManager_InvalidBidSignature();

    /// @notice Thrown when `configureSlashing` is called with arrays of mismatched length
    error AuctionServiceManager_SlashConfigLengthMismatch();
}