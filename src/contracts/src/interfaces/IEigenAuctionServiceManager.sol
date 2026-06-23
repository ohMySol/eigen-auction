// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IEigenAuctionServiceManager
/// @author ohMySol
/// @notice On-chain identity for the EigenAuction AVS: operator-set membership, fee custody, and
/// EigenLayer rewards submission. Settlement gating and fraud proofs live on the Settler/TaskManager.
interface IEigenAuctionServiceManager {
    /// @notice Initialises the proxy: sets the owner and rewards initiator.
    /// @param initialOwner Address that will own this proxy and can call owner-gated functions.
    /// @param rewardsInitiator Address permitted to submit EigenLayer reward proposals.
    function initialize(address initialOwner, address rewardsInitiator) external;

    /// @notice The Settler contract authorised to forward operator fees to this contract.
    function settler() external view returns (address);

    /// @notice Sets the authorised Settler address. Owner-only.
    /// @param newSettler The Settler contract address to authorise.
    function setSettler(address newSettler) external;

    /// @notice Called by the Settler after transferring the operator fee cut for a settlement.
    /// Emits an accounting event; tokens are already held by this contract.
    /// @param asset The currency0 token the fee was captured in.
    /// @param amount The fee amount received.
    function receiveOperatorFee(address asset, uint256 amount) external;

    /// @notice Returns whether `operator` is a member of this AVS's operator set.
    /// @param operator Address to check.
    /// @return True if the address is a registered operator for this AVS.
    function isOperator(address operator) external view returns (bool);
}
