// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Struct that defines auction round data
/// @param targetBlock Block number where arbitrage happen
/// @param bid Arbitrageur bid amount (to be on the 1st place)
/// @param winner Address of the arbitrageur who won auction
/// @param settled - ?
struct AuctionRound {
    uint256 targetBlock;
    uint256 bid;
    address winner;
    bool settled;
}

/// @title IEigenAuctionHook
/// @author ohMySol
/// @notice Interface that defines the functions for the `EigenAuctionHook` hook contract
interface IEigenAuctionHook {

}
