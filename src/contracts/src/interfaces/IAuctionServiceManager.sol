// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

import {AuctionResult} from "../types/AuctionResult.sol";
import {ToBOrder} from "../types/ToBOrder.sol";

/// @title IAuctionServiceManager
/// @author ohMySol
/// @notice On-chain gate for the off-chain operator-batch arbitrage auction. Operators are the
/// members of this AVS's EigenLayer operator set; the selected operator settles a (pool, block) once
/// through the Settler. The Settler records the included arb order here so it can be challenged with a
/// strictly-better signed order during the challenge window, slashing the operator.
interface IAuctionServiceManager {
    /// @notice The Settler authorized to record settlements. Set once by the owner.
    function settler() external view returns (address);

    /// @notice Initialises the proxy: sets the owner and rewards initiator.
    /// @param initialOwner Address of the initial owner of the contract.
    /// @param rewardsInitiator Address of the rewards initiator.
    function initialize(address initialOwner, address rewardsInitiator) external;

    /// @notice Registers the Settler permitted to call `recordSettlement`. Owner-only, called once.
    /// @param settler Address of the deployed `Settler`.
    function setSettler(address settler) external;

    /// @notice Returns whether `operator` is a member of this AVS's operator set (and thus authorized
    /// to settle batches).
    /// @param operator Address to check.
    function isOperator(address operator) external view returns (bool);

    /// @notice Records the arb order an operator included when settling a (pool, block). Settler-only.
    /// @dev Reverts if a settlement already exists for the pair. Stores the order terms (not the bid)
    /// so dominance can be proven AMM-independently in `challengeSettlement`.
    /// @param poolId Pool that was settled.
    /// @param blockNumber Block the settlement targeted.
    /// @param operator Operator that executed the settlement (slashed on a successful challenge).
    /// @param zeroForOne Direction of the included arb order.
    /// @param quantityIn Input quantity of the included arb order.
    /// @param quantityOut Output quantity of the included arb order.
    function recordSettlement(
        PoolId poolId,
        uint256 blockNumber,
        address operator,
        bool zeroForOne,
        uint128 quantityIn,
        uint128 quantityOut
    ) external;

    /// @notice Challenges a settlement by proving a strictly-better signed arb order was available.
    /// @dev `betterOrder` must be bound to the same (pool, block, direction), carry a valid searcher
    /// signature, and dominate the included order (`quantityIn >=`, `quantityOut <=`, strict in one).
    /// On success the settlement is marked challenged and the operator is slashed. Callable by anyone.
    /// @param poolId Pool the disputed settlement belongs to.
    /// @param blockNumber Block number of the disputed settlement.
    /// @param betterOrder A signed top-of-block order that strictly dominates the included one.
    function challengeSettlement(PoolId poolId, uint256 blockNumber, ToBOrder calldata betterOrder) external;

    /// @notice Returns the recorded settlement for a (pool, block).
    /// @dev Returns a zero-initialised struct (`settled == false`) when none exists.
    function getSettlement(PoolId poolId, uint256 blockNumber) external view returns (AuctionResult memory);
}
