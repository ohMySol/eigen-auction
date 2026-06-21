// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolId} from "v4-core/types/PoolId.sol";

import {ICommitmentReader} from "../../src/interfaces/ICommitmentReader.sol";
import {Commitment} from "../../src/types/Commitment.sol";

/// @title MockTaskManager
/// @author ohMySol
/// @notice Test double for the Settler-facing commitment surface. Commitments are written directly
/// via `setCommitment`, bypassing BLS verification, so Settler tests can exercise the commitment gate
/// without standing up the registry/BLS stack. Implements only `ICommitmentReader`, keeping it (and
/// any V4 test importing it) free of EigenLayer's `^0.8.27` pragma. Never deploy to production.
contract MockTaskManager is ICommitmentReader {
    /// @dev poolId => targetBlock => commitment.
    mapping(PoolId => mapping(uint256 => Commitment)) private _commitments;

    /// @notice Records a commitment for `(poolId, targetBlock)` so the Settler's gate can read it.
    function setCommitment(PoolId poolId, uint256 targetBlock, bytes32 resultHash, address executor) external {
        _commitments[poolId][targetBlock] =
            Commitment({resultHash: resultHash, signatoryRecordHash: bytes32(0), executor: executor, exists: true});
    }

    /// @inheritdoc ICommitmentReader
    function getCommitment(PoolId poolId, uint256 targetBlock) external view returns (Commitment memory) {
        return _commitments[poolId][targetBlock];
    }
}
