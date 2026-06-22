// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ConstantsLib
/// @author ohMySol
/// @notice Library of constants used across the EigenAuction contracts.
library ConstantsLib {
    /// @notice Blocks after `commitWinner` during which the result can be challenged.
    uint256 public constant CHALLENGE_WINDOW = 50;

    /// @notice EigenLayer operator-set ID this AVS uses for membership checks and slashing. Matches the
    /// single quorum (quorum 0) created on the `SlashingRegistryCoordinator`; operator set id == quorum
    /// number in the operator-set middleware.
    uint32 public constant OPERATOR_SET_ID = 0;

    /// @notice Number of blocks without a settlement after which public swaps are re-allowed.
    uint256 public constant FALLBACK_PERIOD = 5;

    /// @notice Denominator for the stake threshold expressed in basis points.
    uint256 public constant BPS = 10_000;

    /// @notice Default operator-fee skimmed from each currency0 reward at deploy time (5%).
    uint256 public constant DEFAULT_OPERATOR_FEE_BPS = 500;

    /// @notice Hard ceiling governance can raise the operator fee to (20%). Keeps the LP share
    /// dominant no matter how the fee is tuned.
    uint256 public constant MAX_OPERATOR_FEE_BPS = 2_000;
}