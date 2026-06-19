// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IRewardsCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IRewardsCoordinator.sol";
import {IAllocationManager, IAllocationManagerTypes} from "eigenlayer-contracts/src/contracts/interfaces/IAllocationManager.sol";
import {IPermissionController} from "eigenlayer-contracts/src/contracts/interfaces/IPermissionController.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {OperatorSet} from "eigenlayer-contracts/src/contracts/libraries/OperatorSetLib.sol";
import {ISlashingRegistryCoordinator} from "eigenlayer-middleware/src/interfaces/ISlashingRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/src/interfaces/IStakeRegistry.sol";
import {ServiceManagerBase} from "eigenlayer-middleware/src/ServiceManagerBase.sol";
import {IAVSRegistrar} from "eigenlayer-contracts/src/contracts/interfaces/IAVSRegistrar.sol";

import {PoolId} from "v4-core/types/PoolId.sol";

import {IAuctionServiceManager} from "./interfaces/IAuctionServiceManager.sol";
import {AuctionResult} from "./types/AuctionResult.sol";
import {ToBOrder, TOB_ORDER_TYPEHASH} from "./types/ToBOrder.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";

/// @dev Minimal Settler surface needed to recover the EIP-712 domain for fraud-proof verification.
interface ISettlerDomain {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/// @title AuctionServiceManager
/// @author ohMySol
/// @notice EigenLayer AVS service manager for the operator-batch arbitrage auction. Inherits
/// `ServiceManagerBase` so EigenLayer integration (rewards, metadata, admin) is handled by the base.
///
/// Operator membership is resolved entirely via EigenLayer's `AllocationManager`: an address is an
/// authorized operator if it is a member of `OPERATOR_SET_ID` for this AVS. The selected operator 
/// picks the winning arb off-chain and submits the batch through the Settler, which records the included 
/// arb order here via `recordSettlement`.
///
/// Fraud proof
/// -----------
/// Each settlement sits in a `CHALLENGE_WINDOW` - block window. Anyone can submit a signed `ToBOrder`
/// for the same (pool, block, direction) that strictly dominates the included order — pays at least
/// as much and wants at most as much, strict in one. Dominance guarantees a strictly larger token0
/// bid regardless of AMM state, so the proof needs no historical pool data. A valid challenge slashes
/// the operator that settled.
///
/// @dev Deploy as a proxy. Call `initialize` once, then `setSettler` once.
contract AuctionServiceManager is ServiceManagerBase, IAuctionServiceManager, IAVSRegistrar {
    /* STORAGE */

    /// @inheritdoc IAuctionServiceManager
    address public settler;

    /// @notice Strategies slashed per operator on a successful challenge.
    IStrategy[] private _slashableStrategies;

    /// @notice Slash proportion per strategy in wads (1e18 = 100%).
    uint256[] private _slashWads;

    /// @notice poolId => blockNumber => recorded settlement.
    mapping(PoolId => mapping(uint256 => AuctionResult)) private _results;

    /// @dev Restricts the IAVSRegistrar functions to be called only by EigenLayer's AllocationManager.
    modifier onlyAllocationManager() {
        if (msg.sender != address(_allocationManager)) {
            revert ErrorsLib.AuctionServiceManager_NotAllocationManager();
        }
        _;
    }

    /* CONSTRUCTOR */

    /// @param _avsDirectory         EigenLayer `AVSDirectory` proxy.
    /// @param _rewardsCoordinator   EigenLayer `RewardsCoordinator` proxy.
    /// @param _registryCoordinator  `SlashingRegistryCoordinator` for this AVS (may be `address(0)`).
    /// @param _stakeRegistry        `StakeRegistry` for this AVS (may be `address(0)`).
    /// @param _permissionController EigenLayer `PermissionController` proxy.
    /// @param _allocationManager    EigenLayer `AllocationManager` proxy.
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

    /// @inheritdoc IAuctionServiceManager
    function initialize(address initialOwner, address rewardsInitiator) external initializer {
        __ServiceManagerBase_init(initialOwner, rewardsInitiator);
    }

    /// @inheritdoc IAuctionServiceManager
    function setSettler(address _settler) external onlyOwner {
        if (_settler == address(0) || settler != address(0)) {
            revert ErrorsLib.AuctionServiceManager_InvalidSettler();
        }
        settler = _settler;
    }

    /* EIGENLAYER OPERATOR SET SETUP */

    /// @notice Registers this AVS's metadata with EigenLayer's AllocationManager.
    /// @dev Owner-only. MUST be called once before `createOperatorSet` — AllocationManager reverts
    /// with `NonexistentAVSMetadata` otherwise.
    /// @param metadataURI URI describing the AVS (any non-empty string for local/testnet).
    function registerAvsMetadata(string calldata metadataURI) external onlyOwner {
        _allocationManager.updateAVSMetadataURI(address(this), metadataURI);
    }

    /// @notice Creates this AVS's operator set in EigenLayer with the given slashable strategies.
    /// @dev Owner-only. Not part of the IAuctionServiceManager interface because it references
    /// `IStrategy`, whose `^0.8.27` pragma would conflict with the V4 `=0.8.26` consumers contracts like `EigenAuctionHook`.
    /// @param strategies Strategies (staked assets) slashable on a successful challenge.
    function createOperatorSet(IStrategy[] calldata strategies) external onlyOwner {
        IAllocationManagerTypes.CreateSetParams[] memory params = new IAllocationManagerTypes.CreateSetParams[](1);

        params[0] = IAllocationManagerTypes.CreateSetParams({
            operatorSetId: ConstantsLib.OPERATOR_SET_ID,
            strategies: strategies
        });

        _allocationManager.createOperatorSets(address(this), params);
    }

    /// @notice Sets the strategies and slash proportions applied to a fraudulent operator.
    /// Owner-only. Proportions are in wads (1e17 = 10%, 1e18 = 100%). Kept off the interface for the
    /// same `IStrategy` pragma reason as `createOperatorSet`.
    /// @param strategies Strategies to slash.
    /// @param wads Slash proportion per strategy, in wads. Same length as `strategies`.
    function configureSlashing(IStrategy[] calldata strategies, uint256[] calldata wads) external onlyOwner {
        if (strategies.length != wads.length) {
            revert ErrorsLib.AuctionServiceManager_SlashConfigLengthMismatch();
        }
        delete _slashableStrategies;
        delete _slashWads;
        for (uint256 i = 0; i < strategies.length; i++) {
            _slashableStrategies.push(strategies[i]);
            _slashWads.push(wads[i]);
        }
    }

    /* IAVSRegistrar — operator-set callbacks */

    // Note: EigenLayer's AllocationManager defaults the AVS registrar to the AVS address itself when none is
    // set, so this contract IS its own registrar. Without these callback functions below `registerForOperatorSets` 
    // would revert and no operator could ever join the set, making `commitWinner` permanently unsatisfiable.
    // I didn't implement a separate registrar contract because the logic is trivial.

    /// @inheritdoc IAVSRegistrar
    /// @dev Called by AllocationManager when an operator joins. Admission is permissionless — the
    /// economic gate is the operator's EigenLayer stake/slashing; we only assert the registration
    /// targets this AVS and the single operator set it runs.
    function registerOperator(
        address operator,
        address avs,
        uint32[] calldata operatorSetIds,
        bytes calldata /* data */
    ) external onlyAllocationManager {
        if (avs != address(this)) revert ErrorsLib.AuctionServiceManager_InvalidAvs();
        for (uint256 i = 0; i < operatorSetIds.length; i++) {
            if (operatorSetIds[i] != ConstantsLib.OPERATOR_SET_ID) {
                revert ErrorsLib.AuctionServiceManager_InvalidOperatorSet();
            }
        }
        emit EventsLib.OperatorRegistered(operator, ConstantsLib.OPERATOR_SET_ID);
    }

    /// @inheritdoc IAVSRegistrar
    /// @dev Called by AllocationManager when an operator leaves. Membership state lives in
    /// AllocationManager; we just acknowledge the deregistration.
    function deregisterOperator(address operator, address avs, uint32[] calldata /* operatorSetIds */)
        external
        onlyAllocationManager
    {
        if (avs != address(this)) revert ErrorsLib.AuctionServiceManager_InvalidAvs();
        emit EventsLib.OperatorDeregistered(operator, ConstantsLib.OPERATOR_SET_ID);
    }

    /// @inheritdoc IAVSRegistrar
    function supportsAVS(address avs) external view returns (bool) {
        return avs == address(this);
    }

    /* AVS LOGIC */

    /// @inheritdoc IAuctionServiceManager
    function isOperator(address operator) public view returns (bool) {
        OperatorSet memory opSet = OperatorSet({
            avs: address(this), 
            id: ConstantsLib.OPERATOR_SET_ID
        });
        return _allocationManager.isMemberOfOperatorSet(operator, opSet);
    }

    /// @inheritdoc IAuctionServiceManager
    function recordSettlement(
        PoolId poolId,
        uint256 blockNumber,
        address operator,
        bool zeroForOne,
        uint128 quantityIn,
        uint128 quantityOut
    ) external {
        if (msg.sender != settler) revert ErrorsLib.AuctionServiceManager_NotSettler();

        AuctionResult storage result = _results[poolId][blockNumber];
        if (result.settled) revert ErrorsLib.AuctionServiceManager_AlreadySettled();

        result.operator = operator;
        result.settledBlock = uint64(block.number);
        result.zeroForOne = zeroForOne;
        result.settled = true;
        result.quantityIn = quantityIn;
        result.quantityOut = quantityOut;

        emit EventsLib.SettlementRecorded(poolId, blockNumber, operator, quantityIn, quantityOut);
    }

    /// @inheritdoc IAuctionServiceManager
    function challengeSettlement(PoolId poolId, uint256 blockNumber, ToBOrder calldata betterOrder) external {
        AuctionResult storage result = _results[poolId][blockNumber];

        if (!result.settled) revert ErrorsLib.AuctionServiceManager_NotSettled();
        if (result.challenged) revert ErrorsLib.AuctionServiceManager_AlreadyChallenged();
        if (block.number > result.settledBlock + ConstantsLib.CHALLENGE_WINDOW) {
            revert ErrorsLib.AuctionServiceManager_ChallengeWindowClosed();
        }

        // The challenge order must be bound to the same pool, block, and direction as the settlement.
        if (
            betterOrder.poolId != PoolId.unwrap(poolId) || 
            betterOrder.validForBlock != blockNumber || 
            betterOrder.zeroForOne != result.zeroForOne
        ) revert ErrorsLib.AuctionServiceManager_OrderMismatch();

        // Dominance: pays >= and wants <= (strict in at least one) --> strictly larger token0 bid for
        // ANY AMM state, so no historical pool data is required to prove the operator chose worse.
        bool dominates = betterOrder.quantityIn >= result.quantityIn &&  betterOrder.quantityOut <= result.quantityOut && 
        (betterOrder.quantityIn > result.quantityIn || betterOrder.quantityOut < result.quantityOut);
        
        if (!dominates) revert ErrorsLib.AuctionServiceManager_NotBetterOrder();

        // The order must be a genuine, searcher-signed commitment under the Settler's EIP-712 domain.
        bytes32 digest = _toBDigest(betterOrder);
        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(digest, betterOrder.signature);
        if (err != ECDSA.RecoverError.NoError || recovered != betterOrder.searcher) {
            revert ErrorsLib.AuctionServiceManager_InvalidOrderSignature();
        }

        result.challenged = true;
        _slashOperator(result.operator);

        emit EventsLib.SettlementChallenged(poolId, blockNumber, msg.sender, result.operator);
    }

    /* VIEW FUNCTIONS */

    /// @inheritdoc IAuctionServiceManager
    function getSettlement(PoolId poolId, uint256 blockNumber) external view returns (AuctionResult memory) {
        return _results[poolId][blockNumber];
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

    /* INTERNAL HELPERS */

    /// @dev Recomputes the EIP-712 digest a `ToBOrder` was signed over, using the Settler's domain so
    /// the same signature the Settler accepted is verifiable here.
    function _toBDigest(ToBOrder calldata order) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                TOB_ORDER_TYPEHASH, 
                order.searcher, 
                order.poolId, 
                order.zeroForOne, 
                order.useInternal, 
                order.quantityIn, 
                order.quantityOut,
                order.validForBlock
            )
        );

        bytes32 domainSeparator = ISettlerDomain(settler).DOMAIN_SEPARATOR();
        return keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
    }

    /// @dev Calls `AllocationManager.slashOperator` for `operator`. No-ops when no slashing
    /// strategies are configured yet (the settlement is still marked challenged).
    function _slashOperator(address operator) internal {
        if (_slashableStrategies.length == 0) return;

        IAllocationManagerTypes.SlashingParams memory params = IAllocationManagerTypes.SlashingParams({
            operator: operator,
            operatorSetId: ConstantsLib.OPERATOR_SET_ID,
            strategies: _slashableStrategies,
            wadsToSlash: _slashWads,
            description: "AuctionServiceManager: included a strictly worse arb order"
        });

        (uint256 slashId,) = _allocationManager.slashOperator(address(this), params);
        emit EventsLib.OperatorSlashed(operator, slashId);
    }
}
