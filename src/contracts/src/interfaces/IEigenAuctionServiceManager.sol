// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IEigenAuctionServiceManager
/// @author ohMySol
/// @notice On-chain identity for the EigenAuction AVS: operator-set membership, fee custody, and
/// EigenLayer rewards submission. Settlement gating and fraud proofs live on the Settler/TaskManager.
interface IEigenAuctionServiceManager {
    /// @notice Initialises the proxy: sets the owner and rewards initiator.
    function initialize(address initialOwner, address rewardsInitiator) external;

    /// @notice The Settler contract authorised to forward operator fees to this contract.
    function settler() external view returns (address);

    /// @notice Sets the authorised Settler address. Owner-only.
    function setSettler(address newSettler) external;

    /// @notice Called by the Settler after transferring the operator fee cut for a settlement.
    /// Emits an accounting event; tokens are already held by this contract.
    /// @param asset The currency0 token the fee was captured in.
    /// @param amount The fee amount received.
    function receiveOperatorFee(address asset, uint256 amount) external;

    /// @notice Returns whether `operator` is a member of this AVS's operator set.
    function isOperator(address operator) external view returns (bool);
}
