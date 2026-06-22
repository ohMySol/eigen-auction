// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEigenAuctionServiceManager} from "../../src/interfaces/IEigenAuctionServiceManager.sol";

/// @title MockEigenAuctionServiceManager
/// @author ohMySol
/// @notice Test double exposing operator membership without EigenLayer. Membership is set directly via
/// `setOperator`. Never deploy to production.
/// @dev Implements the reduced `IEigenAuctionServiceManager` surface only, keeping any V4 test that imports
/// it free of EigenLayer's `^0.8.27` pragma.
contract MockEigenAuctionServiceManager is IEigenAuctionServiceManager {
    /// @notice Operator allowlist used by `isOperator`.
    mapping(address => bool) public operators;

    address public settler;

    /// @notice Flags `operator` as (un)authorized for `isOperator`.
    function setOperator(address operator, bool allowed) external {
        operators[operator] = allowed;
    }

    /// @inheritdoc IEigenAuctionServiceManager
    function initialize(address, address) external override {}

    /// @inheritdoc IEigenAuctionServiceManager
    function setSettler(address newSettler) external override {
        settler = newSettler;
    }

    /// @inheritdoc IEigenAuctionServiceManager
    function receiveOperatorFee(address, uint256) external override {}

    /// @inheritdoc IEigenAuctionServiceManager
    function isOperator(address operator) external view override returns (bool) {
        return operators[operator];
    }
}
