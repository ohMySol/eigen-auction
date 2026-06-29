// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author ohMySol
/// @notice A library that defines the errors for EigenAuction Hook smart contract system
library ErrorsLib {
    /* ───────────────────────── EigenAuctionHook Errors ───────────────────────── */

    /// @notice Thrown during construction when a required address argument is the zero address
    error EigenAuctionHook_ZeroAddress();

    /// @notice Thrown when a swap reaches the hook from an address other than the registered settler
    /// while the fallback period has not yet elapsed
    error EigenAuctionHook_NotSettler();

    /// @notice Thrown when a reward-distribution or settlement-record call comes from a non-settler
    error EigenAuctionHook_OnlySettler();

    /// @notice Thrown when a second settlement is attempted for a pool in the same block
    error EigenAuctionHook_AlreadySettledThisBlock();

    /// @notice Thrown when `setSettler` is called by a non-owner or after the settler is already set
    error EigenAuctionHook_Unauthorized();
    
    /// @notice Thrown when `setSettler` is called and the settler is already set
    error EigenAuctionHook_SettlerAlreadySet();

    /// @notice Thrown when the arb swap's actual pool liquidity differs from the operator's expected
    /// value, indicating a JIT add landed between the operator's snapshot and the swap
    error EigenAuctionHook_LiquidityMismatch();

    /* ───────────────────────── EigenAuctionServiceManager Errors ───────────────────────── */

    /// @notice Thrown when `receiveOperatorFee` is called by an address other than the registered Settler
    error EigenAuctionServiceManager_NotSettler();

    /// @notice Thrown when `setSettler` is given the zero address
    error EigenAuctionServiceManager_ZeroAddress();

    /* ───────────────────────── Settler Errors ───────────────────────── */

    /// @notice Thrown when `unlockCallback` is called by an address other than the pool manager
    error Settler_NotPoolManager();

    /// @notice Thrown when a top-of-block arb order carries an invalid EIP-712 signature
    error Settler_InvalidArbSignature();

    /// @notice Thrown when an order's bound block does not match the current block
    error Settler_WrongBlock();

    /// @notice Thrown when the arb order amounts are below the AMM's deterministic quote
    /// (a negative bid), meaning the order would pay LPs nothing
    error Settler_NegativeBid();

    /// @notice Thrown when the operator's clearing price leaves the batch insolvent
    error Settler_BatchInsolvent();

    /// @notice Thrown when a clearing price of zero is supplied
    error Settler_ZeroClearingPrice();

    /// @notice Thrown when withdrawing more than the caller's internal balance
    error Settler_InsufficientBalance();

    /// @notice Thrown when filling a user intent whose `deadline` has passed
    error Settler_IntentExpired();

    /// @notice Thrown when a user intent's actual output is below `minAmountOut`
    error Settler_SlippageExceeded();

    /// @notice Thrown when filling a user intent whose nonce was already used or invalidated
    error Settler_NonceUsed();

    /// @notice Thrown when a user intent carries an invalid EIP-712 signature
    error Settler_InvalidSignature();

    /// @notice Thrown when `settle` is called with no arb swap and no user intents
    error Settler_NothingToSettle();

    /// @notice Thrown when a user intent's `poolId` does not match the pool being settled
    error Settler_WrongPool();

    /// @notice Thrown when any address passed to `Settler` constructor is zero address
    error Settler_ConstructorZeroAddress();

    /// @notice Thrown when settling a (pool, block) that has no quorum-attested commitment
    error Settler_NoCommitment();

    /// @notice Thrown when the batch the caller submitted does not reproduce the committed `resultHash`
    error Settler_ResultMismatch();

    /// @notice Thrown when the caller is not the executor bound in the commitment
    error Settler_NotExecutor();

    /// @notice Thrown when setting an operator fee above `MAX_OPERATOR_FEE_BPS`
    error Settler_FeeTooHigh();

    /* ───────────────────────── EigenAuctionTaskManager Errors ───────────────────────── */

    /// @notice Thrown when `commitWinner` is given the zero address as executor
    error EigenAuctionTaskManager_ZeroExecutor();

    /// @notice Thrown when the committed `targetBlock` is not the current block
    error EigenAuctionTaskManager_WrongTargetBlock();

    /// @notice Thrown when the stake-snapshot reference block is not strictly in the past
    error EigenAuctionTaskManager_FutureReferenceBlock();

    /// @notice Thrown when a commitment already exists for the (pool, block)
    error EigenAuctionTaskManager_AlreadyCommitted();

    /// @notice Thrown when a quorum's signed stake is below the configured threshold
    error EigenAuctionTaskManager_QuorumNotMet();

    /// @notice Thrown when the supplied quorums do not match the configured `quorumNumbers`
    error EigenAuctionTaskManager_QuorumNumbersMismatch();

    /// @notice Thrown when setting an empty quorum-numbers set
    error EigenAuctionTaskManager_EmptyQuorumNumbers();

    /// @notice Thrown when setting a threshold of zero or above `BPS`
    error EigenAuctionTaskManager_InvalidThreshold();

    /// @notice Thrown when challenging a (pool, block) that has no commitment
    error EigenAuctionTaskManager_NoCommitment();

    /// @notice Thrown when challenging a commitment that was already successfully challenged
    error EigenAuctionTaskManager_AlreadyChallenged();

    /// @notice Thrown when the challenge arrives after the CHALLENGE_WINDOW has closed
    error EigenAuctionTaskManager_ChallengeWindowClosed();

    /// @notice Thrown when the supplied committed arb + price + intentsRoot do not reproduce the
    /// commitment's resultHash (so the order is not provably the one that was committed)
    error EigenAuctionTaskManager_ResultMismatch();

    /// @notice Thrown when the dominant order is not bound to the disputed pool/block/direction
    error EigenAuctionTaskManager_OrderMismatch();

    /// @notice Thrown when the challenge order does not strictly dominate the committed arb order
    error EigenAuctionTaskManager_NotDominant();

    /// @notice Thrown when the dominant order's signature is invalid or not from its searcher
    error EigenAuctionTaskManager_InvalidOrderSignature();

    /// @notice Thrown when the supplied reference block + non-signer hashes do not reproduce the
    /// commitment's `hashOfNonSigners`, so the signer set cannot be trusted
    error EigenAuctionTaskManager_SignatoryRecordMismatch();

    /// @notice Thrown when the slashing config is set with no strategies or a zero wad
    error EigenAuctionTaskManager_InvalidSlashingConfig();
}