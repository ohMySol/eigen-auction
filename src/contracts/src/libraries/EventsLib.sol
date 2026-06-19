// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

/// @title EventsLib
/// @author @ohMySol
/// @notice A library that defines the events for EigenAuction Hook smart contract system
library EventsLib {
    /* AuctionServiceManager Events  */

    /// @notice Emitted when an operator records the arb order it included for a (pool, block)
    /// @param poolId ID of the pool
    /// @param blockNumber Block the settlement targeted
    /// @param operator Operator that executed the settlement
    /// @param quantityIn Input quantity of the included arb order
    /// @param quantityOut Output quantity of the included arb order
    event SettlementRecorded(
        PoolId indexed poolId,
        uint256 indexed blockNumber,
        address indexed operator,
        uint128 quantityIn,
        uint128 quantityOut
    );

    /// @notice Emitted when a settlement is successfully challenged with a strictly-better arb order
    /// @param poolId Pool the disputed settlement belongs to
    /// @param blockNumber Block number of the disputed settlement
    /// @param challenger Address that submitted the fraud proof
    /// @param operator Operator that was slashed
    event SettlementChallenged(
        PoolId indexed poolId,
        uint256 indexed blockNumber,
        address indexed challenger,
        address operator
    );

    /// @notice Emitted for each operator slashed after a successful challenge
    /// @param operator Address of the slashed operator
    /// @param slashId  Slash ID returned by AllocationManager
    event OperatorSlashed(address indexed operator, uint256 slashId);

    /// @notice Emitted when AllocationManager admits an operator into this AVS's operator set
    /// @param operator Address of the registered operator
    /// @param operatorSetId The operator set the operator joined
    event OperatorRegistered(address indexed operator, uint32 operatorSetId);

    /// @notice Emitted when AllocationManager removes an operator from this AVS's operator set
    /// @param operator Address of the deregistered operator
    /// @param operatorSetId The operator set the operator left
    event OperatorDeregistered(address indexed operator, uint32 operatorSetId);

    /* EigenAuctionHook Events  */

    /// @notice Emitted when a winning arb swap settles and the operator's reward is folded into LP rewards
    /// @param poolId ID of the pool
    /// @param winner Address of the auction winner who paid the reward
    /// @param rewardAmount Amount of currency0 distributed to the pool's in-range liquidity providers
    event ArbitrageSettled(
        PoolId indexed poolId,
        address indexed winner,
        uint256 rewardAmount
    );

    /// @notice Emitted when an LP claims rewards for a position
    /// @param poolId ID of the pool
    /// @param lp Liquidity provider (position owner) address
    /// @param amount Reward paid in currency0
    event RewardsClaimed(
        PoolId indexed poolId,
        address indexed lp,
        uint256 amount
    );

    /// @notice Emitted when an LP adds liquidity through the hook's own entry point
    /// @param poolId ID of the pool
    /// @param lp Liquidity provider that supplied the position
    /// @param tickLower Lower tick of the position's range
    /// @param tickUpper Upper tick of the position's range
    /// @param liquidity Liquidity units added
    event LiquidityAdded(
        PoolId indexed poolId,
        address indexed lp,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );

    /// @notice Emitted when an LP removes liquidity through the hook's own entry point
    /// @param poolId ID of the pool
    /// @param lp Liquidity provider that withdrew the position
    /// @param tickLower Lower tick of the position's range
    /// @param tickUpper Upper tick of the position's range
    /// @param liquidity Liquidity units removed
    event LiquidityRemoved(
        PoolId indexed poolId,
        address indexed lp,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    );

    /* Settler Events */

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

    /* EigenAuctionHook Events — venue lock */

    /// @notice Emitted when the settler address is registered on the hook
    /// @param settler The settler contract address
    event SettlerSet(address indexed settler);
}