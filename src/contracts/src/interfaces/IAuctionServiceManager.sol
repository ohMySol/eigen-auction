// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";

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

/// @title IAuctionServiceManager
/// @author ohMySol
/// @notice On-chain anchor for the off-chain LVR-auction AVS. A quorum of registered operator
/// signers validate each per-block winner tuple via ECDSA; `commitWinner` verifies the quorum
/// and stores the result so `EigenAuctionHook` can enforce arb exclusivity. Committed results can
/// be challenged within a window — a valid higher-bid proof triggers operator slashing.
interface IAuctionServiceManager {
    /// @notice Minimum number of unique registered-operator signatures required to commit a winner.
    function threshold() external view returns (uint256);

    /// @notice Initialises the proxy: sets the owner and rewards initiator.
    /// @param initialOwner Address of the intial owner of the contract.
    /// @param rewardsInitiator Address of the rewards initiator.
    function initialize(address initialOwner, address rewardsInitiator) external;

    /// @notice Creates this AVS's operator set in EigenLayer with the given slashable strategies.
    /// @dev Call once post-deployment. Operators then able to join by calling:
    /// `AllocationManager.registerForOperatorSets(operator, {avs: this, operatorSetIds: [1], data: ""})`.
    /// They must also allocate stake to `OPERATOR_SET_ID` for slashing to have economic effect.
    /// ! Only owner can call this function. 
    ///
    /// @param strategies List of strategies (staked assets) that will be slashable in case of a successful challenge.
    function createOperatorSet(IStrategy[] calldata strategies) external;

    /// @notice Sets the strategies and slash percentages applied to each signer when a challenge succeeds.
    /// @dev `strategies` must match those in the operator set. Proportions are in wads:
    /// 1e17 = 10 %, 5e17 = 50 %, 1e18 = 100 %.
    /// ! Only owner can call this function.
    ///
    /// @param strategies List of strategies (staked assets) that will be slashable in case of a successful challenge.
    /// @param wads List of slash percentages in wads (1e18 = 100 %). Must be the same length as `strategies`.
    function configureSlashing(IStrategy[] calldata strategies, uint256[] calldata wads) external;

    /// @notice Commits the auction winner for a given pool and block.
    /// @dev Validates that at least `threshold` unique registered operators signed
    /// `ethSignedMessageHash(keccak256(abi.encodePacked(poolId, targetBlock, winner, bidAmount)))`.
    /// Reverts if the block is stale, the result is already committed, or quorum is not met.
    function commitWinner(
        PoolId poolId,
        uint256 targetBlock,
        address winner,
        uint256 bidAmount,
        bytes[] calldata signatures
    ) external;

    /// @notice Challenges a committed result by proving a higher bid was ignored by operators.
    /// @dev The fraud proof is a signed bid: `higherBidder` must have signed
    /// `ethSignedMessageHash(keccak256(abi.encodePacked(poolId, targetBlock, higherBidAmount)))`.
    /// If valid, the result is marked as challenged and the signing operators are slashed
    /// via EigenLayer's AllocationManager (when configured). Callable by anyone.
    ///
    /// @param poolId Pool the disputed result belongs to.
    /// @param targetBlock Block number of the disputed result.
    /// @param higherBidder Address whose signed bid proves the committed winner was wrong.
    /// @param higherBidAmount Bid amount from `higherBidder` (must exceed the committed bid).
    /// @param bidderSignature EIP-191 signature by `higherBidder` over the bid hash.
    function challengeWinner(
        PoolId poolId,
        uint256 targetBlock,
        address higherBidder,
        uint256 higherBidAmount,
        bytes calldata bidderSignature
    ) external;

    /// @notice Returns the committed auction result for a given pool and block.
    /// @dev Returns a zero-initialised struct (committed == false) when no winner was committed.
    /// @param poolId Pool ID.
    /// @param blockNumber Block number.
    function getWinner(PoolId poolId, uint256 blockNumber) external view returns (AuctionResult memory);
}
