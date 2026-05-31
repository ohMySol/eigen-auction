// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author @ohMySol
/// @notice A library that defines the errors for EigenAuction Hook smart contract system
library ErrorsLib {
    /* LPRewardDistributor Errors */
    
    /// @notice Thrown when function caller is not hook contract
    error LPRewardDistributor_OnlyHook();

    /// @notice Thrown during contract construction when hook parameter is zero address
    error LPRewardDistributor_HookAddressZero();

    /// @notice Thrown when LP reward transfer failed during the claim
    error LPRewardDistributor_TransferFailed();

    /// @notice Thrown when LP has 0 rewards balance for claim
    error LPRewardDistributor_NothingToClaim();
}