// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IPermissionController} from "eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {OperatorSet} from "eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {ServiceManagerBase} from "eigenlayer-middleware/src/ServiceManagerBase.sol";

import {IEigenAuctionServiceManager} from "./interfaces/IEigenAuctionServiceManager.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";

/// @title EigenAuctionServiceManager
/// @author ohMySol
/// @notice EigenLayer AVS service manager for the operator-batch arbitrage auction. Inherits
/// `ServiceManagerBase` so EigenLayer integration (rewards, metadata, admin) is handled by the base.
///
/// Operator membership is resolved entirely via EigenLayer's `AllocationManager`: an address is an
/// authorized operator if it is a member of `OPERATOR_SET_ID` for this AVS. In the BLS model the
/// auction result is committed and challenged on the `EigenAuctionTaskManager`, operators register
/// through the `SlashingRegistryCoordinator` (the AVS registrar), and this contract is the AVS
/// identity: metadata, rewards submission, and an operator-set membership view.
///
/// @dev Deploy as a proxy. Call `initialize` once.
contract EigenAuctionServiceManager is ServiceManagerBase, IEigenAuctionServiceManager {
    /* STATE VARIABLES */

    /// @inheritdoc IEigenAuctionServiceManager
    address public settler;

    /* CONSTRUCTOR */

    /// @param _avsDirectory EigenLayer `AVSDirectory` proxy.
    /// @param _rewardsCoordinator EigenLayer `RewardsCoordinator` proxy.
    /// @param _registryCoordinator `SlashingRegistryCoordinator` for this AVS (may be `address(0)`).
    /// @param _stakeRegistry `StakeRegistry` for this AVS (may be `address(0)`).
    /// @param _permissionController EigenLayer `PermissionController` proxy.
    /// @param _allocationManager EigenLayer `AllocationManager` proxy.
    constructor(
        IAVSDirectory _avsDirectory,
        IRewardsCoordinator _rewardsCoordinator,
        ISlashingRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry,
        IPermissionController _permissionController,
        IAllocationManager _allocationManager
    )
        ServiceManagerBase(
            _avsDirectory,
            _rewardsCoordinator,
            _registryCoordinator,
            _stakeRegistry,
            _permissionController,
            _allocationManager
        )
    {}

    /* INITIALIZER */

    /// @inheritdoc IEigenAuctionServiceManager
    function initialize(address initialOwner, address rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);
    }

    /* SETTLER WIRING */

    /// @inheritdoc IEigenAuctionServiceManager
    function setSettler(address newSettler) external onlyOwner {
        if (newSettler == address(0)) revert ErrorsLib.EigenAuctionServiceManager_ZeroAddress();
        settler = newSettler;
        emit EventsLib.SettlerSet(newSettler);
    }

    /// @inheritdoc IEigenAuctionServiceManager
    /// @dev Tokens arrive via the preceding ERC20 transfer from the Settler; this function just
    /// emits the accounting event. Only the registered Settler may call it so the event is trustworthy.
    function receiveOperatorFee(address asset, uint256 amount) external {
        if (msg.sender != settler) revert ErrorsLib.EigenAuctionServiceManager_NotSettler();
        emit EventsLib.OperatorFeeReceived(asset, amount);
    }

    /* REWARDS */

    /// @notice Submits operator-directed rewards from fees already held by this contract.
    /// @dev Overrides the base to skip the `transferFrom` pull — tokens are already here after being
    /// forwarded by the Settler. Only the `rewardsInitiator` may call this; the base modifier applies.
    function createOperatorDirectedAVSRewardsSubmission(
        IRewardsCoordinator.OperatorDirectedRewardsSubmission[] calldata submissions
    ) public override onlyRewardsInitiator {
        _approveSubmissions(submissions);
        _rewardsCoordinator.createOperatorDirectedAVSRewardsSubmission(address(this), submissions);
    }

    /// @notice Operator-set variant of the rewards submission, recommended by the RewardsCoordinator
    /// v2.1 for AVSs that use EigenLayer Operator Sets (this AVS does). Targets this AVS's operator set
    /// automatically; per-operator amounts are computed off-chain by the rewards keeper.
    /// @dev Same pattern as the AVS variant: tokens are already held here (forwarded by the Settler),
    /// so we approve the coordinator and submit rather than pulling from the initiator. The coordinator
    /// requires operators within each submission to be in ascending address order.
    /// @param submissions Operator-directed reward submissions, one per token.
    function createOperatorDirectedOperatorSetRewardsSubmission(
        IRewardsCoordinator.OperatorDirectedRewardsSubmission[] calldata submissions
    ) external onlyRewardsInitiator {
        _approveSubmissions(submissions);
        _rewardsCoordinator.createOperatorDirectedOperatorSetRewardsSubmission(
            OperatorSet({avs: address(this), id: ConstantsLib.OPERATOR_SET_ID}),
            submissions
        );
    }

    /* EIGENLAYER OPERATOR SET SETUP */

    /// @notice Registers this AVS's metadata with EigenLayer's AllocationManager.
    /// @dev Owner-only. MUST be called once before the operator set / quorum is created — the
    /// AllocationManager reverts with `NonexistentAVSMetadata` otherwise.
    /// @param metadataURI URI describing the AVS (any non-empty string for local/testnet).
    function registerAvsMetadata(string calldata metadataURI) external onlyOwner {
        _allocationManager.updateAVSMetadataURI(address(this), metadataURI);
    }

    /* AVS LOGIC */

    /// @inheritdoc IEigenAuctionServiceManager
    function isOperator(address operator) public view returns (bool) {
        OperatorSet memory opSet = OperatorSet({
            avs: address(this),
            id: ConstantsLib.OPERATOR_SET_ID
        });
        return _allocationManager.isMemberOfOperatorSet(operator, opSet);
    }

    /* EIGENLAYER SERVICE MANAGER BASE VIEW OVERRIDES */

    // Note: ServiceManagerBase reads strategies from `_registryCoordinator` and `_stakeRegistry` - the old middleware path I am not using. 
    // That's why I am passing address(0) for both `ISlashingRegistryCoordinator` and `IStakeRegistry` in my `DeployCore` script.
    // It also means the dead functions below from ServiceManagerBase that call _registryCoordinator and _stakeRegistry would revert if
    // ever triggered (for example when EigenLayer's indexers queries them).
    // I considered implementing them to return empty arrays, because the strategies are registered through `AllocationManager`.
    // 
    // Later I am planning to create a custom AuctionServiceManagerBase wihtout dead functions and keep it clean.

    /// @dev Return `new address[](0)` because we handle strategy configuration through `AllocationManager` 
    /// directly (via `createOperatorSet` and `configureSlashing`), not through the legacy StakeRegistry path.
    function getRestakeableStrategies() external pure override returns (address[] memory) {
        return new address[](0);
    }

    /// @dev Return `new address[](0)` because we handle strategy configuration through `AllocationManager` 
    /// directly (via `createOperatorSet` and `configureSlashing`), not through the legacy StakeRegistry path.
    function getOperatorRestakedStrategies(address) external pure override returns (address[] memory) {
        return new address[](0);
    }

    /* PRIVATE */

    /// @dev Approves the RewardsCoordinator to pull each submission's total from fees already held by
    /// this contract (forwarded by the Settler). Resets each allowance to 0 before setting it, so
    /// non-standard ERC20s that require a zero allowance before a new approval are handled.
    /// @param submissions Operator-directed reward submissions, one per token.
    function _approveSubmissions(
        IRewardsCoordinator.OperatorDirectedRewardsSubmission[] calldata submissions
    ) private {
        for (uint256 i = 0; i < submissions.length; ++i) {
            uint256 total = 0;
            for (uint256 j = 0; j < submissions[i].operatorRewards.length; ++j) {
                total += submissions[i].operatorRewards[j].amount;
            }
            submissions[i].token.approve(address(_rewardsCoordinator), 0);
            submissions[i].token.approve(address(_rewardsCoordinator), total);
        }
    }
}
