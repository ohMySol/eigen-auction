// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

import {IAuctionServiceManager} from "../../src/interfaces/IAuctionServiceManager.sol";
import {AuctionResult} from "../../src/types/AuctionResult.sol";
import {ToBOrder} from "../../src/types/ToBOrder.sol";
import {EventsLib} from "../../src/libraries/EventsLib.sol";

/// @title MockAuctionServiceManager
/// @author ohMySol
/// @notice Test double for the operator-batch model. Operator membership is set directly via
/// `setOperator`, bypassing EigenLayer. The settler-only guard on `recordSettlement` is enforced so
/// Settler tests exercise the real wiring. Never deploy to production.
/// @dev Implements the hook/settler-facing `IAuctionServiceManager` surface only. It deliberately
/// does NOT pull in `IStrategy`, keeping this mock — and any V4 test that imports it — free of
/// EigenLayer's `^0.8.27` pragma.
contract MockAuctionServiceManager is IAuctionServiceManager {
    /// @inheritdoc IAuctionServiceManager
    address public settler;

    /// @notice Operator allowlist used by `isOperator`.
    mapping(address => bool) public operators;

    /// @notice poolId => blockNumber => recorded settlement.
    mapping(PoolId => mapping(uint256 => AuctionResult)) private _results;

    /* TEST HELPERS */

    /// @notice Flags `operator` as (un)authorized for `isOperator`.
    function setOperator(address operator, bool allowed) external {
        operators[operator] = allowed;
    }

    /// @notice Flags an already-recorded settlement as challenged.
    function markChallenged(PoolId poolId, uint256 blockNumber) external {
        _results[poolId][blockNumber].challenged = true;
    }

    /* INERT STUBS */

    /// @inheritdoc IAuctionServiceManager
    function initialize(address, address) external override {}

    /// @inheritdoc IAuctionServiceManager
    function challengeSettlement(PoolId poolId, uint256 blockNumber, ToBOrder calldata) external override {
        _results[poolId][blockNumber].challenged = true;
    }

    /* CORE SURFACE */

    /// @inheritdoc IAuctionServiceManager
    function setSettler(address _settler) external override {
        settler = _settler;
    }

    /// @inheritdoc IAuctionServiceManager
    function isOperator(address operator) external view override returns (bool) {
        return operators[operator];
    }

    /// @inheritdoc IAuctionServiceManager
    function recordSettlement(
        PoolId poolId,
        uint256 blockNumber,
        address operator,
        bool zeroForOne,
        uint128 quantityIn,
        uint128 quantityOut
    ) external override {
        AuctionResult storage result = _results[poolId][blockNumber];
        result.operator = operator;
        result.settledBlock = uint64(block.number);
        result.zeroForOne = zeroForOne;
        result.settled = true;
        result.quantityIn = quantityIn;
        result.quantityOut = quantityOut;
        emit EventsLib.SettlementRecorded(poolId, blockNumber, operator, quantityIn, quantityOut);
    }

    /// @inheritdoc IAuctionServiceManager
    function getSettlement(PoolId poolId, uint256 blockNumber) external view override returns (AuctionResult memory) {
        return _results[poolId][blockNumber];
    }
}
