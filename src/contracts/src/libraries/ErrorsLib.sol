// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author @ohMySol
/// @notice A library that defines the errors for EigenAuction Hook smart contract system
library ErrorsLib {
    /* ───────────────────────── EigenAuctionHook Errors ───────────────────────── */

    /// @notice Thrown during construction when a required address argument is the zero address
    error EigenAuctionHook_ZeroAddress();

    /// @notice Thrown when `addLiquidity`/`removeLiquidity` is called with a zero liquidity amount
    error EigenAuctionHook_ZeroLiquidity();

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

    /* ───────────────────────── AuctionServiceManager / MockAuctionServiceManager Errors ───────────────────────── */

    /// @notice Thrown when `recordSettlement` is called by an address other than the registered settler
    error AuctionServiceManager_NotSettler();

    /// @notice Thrown when setting the settler to the zero address or after it is already set
    error AuctionServiceManager_InvalidSettler();

    /// @notice Thrown when recording a settlement for a (pool, block) that already has one
    error AuctionServiceManager_AlreadySettled();

    /// @notice Thrown when challenging a (pool, block) that has no recorded settlement
    error AuctionServiceManager_NotSettled();

    /// @notice Thrown when challenging a settlement that was already successfully challenged
    error AuctionServiceManager_AlreadyChallenged();

    /// @notice Thrown when the challenge window (CHALLENGE_WINDOW blocks) has closed
    error AuctionServiceManager_ChallengeWindowClosed();

    /// @notice Thrown when the challenge order does not strictly dominate the included arb order
    error AuctionServiceManager_NotBetterOrder();

    /// @notice Thrown when the challenge order's signature is invalid or does not match its arber
    error AuctionServiceManager_InvalidOrderSignature();

    /// @notice Thrown when the challenge order is not bound to the disputed (pool, block) or direction
    error AuctionServiceManager_OrderMismatch();

    /// @notice Thrown when `configureSlashing` is called with arrays of mismatched length
    error AuctionServiceManager_SlashConfigLengthMismatch();

    /// @notice Thrown when an `IAVSRegistrar` hook is called by an address other than the AllocationManager
    error AuctionServiceManager_NotAllocationManager();

    /// @notice Thrown when an operator-set registration targets an AVS other than this contract
    error AuctionServiceManager_InvalidAvs();

    /// @notice Thrown when registering for an operator set id this AVS does not run
    error AuctionServiceManager_InvalidOperatorSet();

    /* ───────────────────────── Settler Errors ───────────────────────── */

    /// @notice Thrown when `unlockCallback` is called by an address other than the pool manager
    error Settler_NotPoolManager();

    /// @notice Thrown when `settle` is called by an address that is not a registered AVS operator
    error Settler_NotOperator();

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

    /// @notice Thrown when an ERC20 `transferFrom` returns false during settlement
    error Settler_TransferFailed();

    /// @notice Thrown when any address passed to `Settler` constructor is zero address
    error Settler_ConstructorZeroAddress();

    /* ───────────────────────── EigenAuctionTaskManager Errors ───────────────────────── */

    error EigenAuctionTaskManager_ZeroExecutor();

    error EigenAuctionTaskManager_WrongTargetBlock();

    error EigenAuctionTaskManager_FutureReferenceBlock();

    error EigenAuctionTaskManager_AlreadyCommitted();

    error EigenAuctionTaskManager_QuorumNotMet();

    error EigenAuctionTaskManager_QuorumNumbersMismatch();

    error EigenAuctionTaskManager_EmptyQuorumNumbers();

    error EigenAuctionTaskManager_InvalidThreshold();
}