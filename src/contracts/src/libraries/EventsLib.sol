// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

/// @title EventsLib
/// @author ohMySol
/// @notice A library that defines the events for EigenAuction Hook smart contract system
library EventsLib {
    /* ───────────────────────── EigenAuctionServiceManager Events ───────────────────────── */

    /// @notice Emitted when the ServiceManager receives an operator fee forwarded by the Settler
    /// @param asset The token received (currency0 of the settled pool)
    /// @param amount Fee amount received
    event OperatorFeeReceived(address indexed asset, uint256 amount);

    /* ───────────────────────── EigenAuctionHook Events  ───────────────────────── */

    /// @notice Emitted when the settler address is registered on the hook
    /// @param settler The settler contract address
    event SettlerSet(address indexed settler);

    /// @notice Emitted when a winning arb swap settles and the operator's reward is folded into LP rewards
    /// @param poolId ID of the pool
    /// @param winner Address of the auction winner who paid the reward
    /// @param rewardAmount Amount of currency0 distributed to the pool's in-range liquidity providers
    event ArbitrageSettled(
        PoolId indexed poolId,
        address indexed winner,
        uint256 rewardAmount
    );

    /// @notice Emitted when a position's accrued rewards are paid out on removal (currency0)
    /// @param poolId ID of the pool
    /// @param owner Position owner as V4 attributes it — the router / PositionManager address
    /// @param amount Reward paid in currency0
    event RewardsClaimed(
        PoolId indexed poolId,
        address indexed owner,
        uint256 amount
    );

    /* ───────────────────────── Settler Events ───────────────────────── */

    /// @notice Emitted when a user swap intent is successfully filled
    /// @param poolId Pool the intent was filled against
    /// @param user Intent signer and token recipient
    /// @param zeroForOne Swap direction
    /// @param amountIn Input amount pulled from the user
    /// @param amountOut Output amount delivered to the user
    event IntentFilled(
        PoolId indexed poolId,
        address indexed user,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOut
    );

    /// @notice Emitted when a user invalidates a nonce to cancel a pending intent
    /// @param user  Owner of the nonce
    /// @param nonce The invalidated nonce
    event NonceInvalidated(address indexed user, uint64 nonce);

    /// @notice Emitted when a user deposits tokens into their internal Settler balance
    /// @param asset Token deposited
    /// @param user Account credited
    /// @param amount Amount deposited
    event Deposited(address indexed asset, address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws tokens from their internal Settler balance
    /// @param asset Token withdrawn
    /// @param user Account debited
    /// @param amount Amount withdrawn
    event Withdrawn(address indexed asset, address indexed user, uint256 amount);

    /// @notice Emitted when a top-of-block arb order is filled inside a settlement
    /// @param poolId Pool the arb executed against
    /// @param arber Arbitrageur whose signed order was included
    /// @param bid Reward (currency0) the arb left for LPs, derived from the AMM quote
    event ArbFilled(PoolId indexed poolId, address indexed arber, uint256 bid);

    /// @notice Emitted when a full settlement round (arb + user intents) completes
    /// @param poolId Pool that was settled
    /// @param blockNumber Block the settlement targeted
    /// @param operator AVS winner that executed the settlement
    event BlockSettled(PoolId indexed poolId, uint256 indexed blockNumber, address indexed operator);

    /// @notice Emitted when governance changes the operator fee rate on the Settler
    /// @param newOperatorFeeBps New fee in basis points
    event OperatorFeeBpsSet(uint256 newOperatorFeeBps);

    /* ───────────────────────── EigenAuctionTaskManager Events ───────────────────────── */

    /// @notice Emitted once a quorum-attested searcher winner is recorded for a (pool, block).
    /// @param poolId Pool ID the winner is committed for
    /// @param targetBlock Block for which the winner is committed
    /// @param executor Address of the operator who was selected to send a batch tx
    /// @param resultHash `keccak256(arbOrderHash, clearingPriceX128, intentsRoot)` the executor must
    /// reproduce at settle time
    event WinnerCommitted(
        PoolId indexed poolId,
        uint256 indexed targetBlock,
        address indexed executor,
        bytes32 resultHash
    );

    /// @notice Emitted when a commitment is proven fraudulent by a strictly-better arbitrage order.
    /// @param poolId Pool the disputed commitment belongs to
    /// @param targetBlock Block the disputed commitment targeted
    /// @param challenger Address that submitted the fraud proof
    event CommitmentChallenged(
        PoolId indexed poolId,
        uint256 indexed targetBlock,
        address indexed challenger
    );

    /// @notice Emitted once per fraudulent commitment after its signing operators are queued for slashing.
    /// @param poolId Pool the fraudulent commitment belongs to
    /// @param targetBlock Block the fraudulent commitment targeted
    /// @param signerCount Number of signing operators queued for slashing (executor excluded)
    event SignatorySlashingQueued(
        PoolId indexed poolId,
        uint256 indexed targetBlock,
        uint256 signerCount
    );

    /// @notice Emitted for each signing operator queued in the VetoableSlasher.
    /// @param operator The operator whose slashing was queued
    event OperatorSlashQueued(address indexed operator);

    /// @notice Emitted when the slashing config (strategies + per-strategy wad) is updated.
    /// @param strategyCount Number of strategies that will be slashed on a fault
    /// @param wadToSlash Fraction of each strategy's allocation slashed, in wad (1e18 = 100%)
    event SlashingConfigSet(uint256 strategyCount, uint256 wadToSlash);
}