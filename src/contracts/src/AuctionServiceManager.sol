// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {MessageHashUtils} from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {IAuctionServiceManager, AuctionResult} from "./interfaces/IAuctionServiceManager.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title AuctionServiceManager
/// @author ohMySol
/// @notice MVP EigenLayer-style service manager: an owner-managed operator set commits the
/// per-block LVR-auction winner once a quorum of operators has signed the winner tuple.
/// @dev This is a simplified stand-in for a production `ECDSAServiceManagerBase`. It keeps a
/// flat operator allow-list and an `m-of-n` ECDSA threshold instead of a full EigenLayer stake
/// registry, which is sufficient for the hook to enforce auction exclusivity on-chain.
contract AuctionServiceManager is IAuctionServiceManager, Ownable2Step {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /* IMMUTABLE VARIABLES */

    /// @inheritdoc IAuctionServiceManager
    uint256 public immutable threshold;

    /* STORAGE */

    /// @inheritdoc IAuctionServiceManager
    address[] public operators;

    /// @inheritdoc IAuctionServiceManager
    mapping(address => bool) public isOperator;

    /// @notice Mapping: poolId => targetBlock => committed auction result.
    mapping(PoolId => mapping(uint256 => AuctionResult)) private _results;

    /* CONSTRUCTOR */

    /// @dev Initializes the owner to the deployer and locks in the signing threshold.
    /// @param _threshold Minimum number of unique operator signatures required to commit a winner
    constructor(uint256 _threshold) Ownable(msg.sender) {
        if (_threshold == 0) revert ErrorsLib.AuctionServiceManager_InvalidThreshold();
        threshold = _threshold;
    }

    /* OPERATOR MANAGEMENT */

    /// @inheritdoc IAuctionServiceManager
    function registerOperator(address operator) external onlyOwner {
        if (operator == address(0)) revert ErrorsLib.AuctionServiceManager_ZeroOperator();
        if (isOperator[operator]) revert ErrorsLib.AuctionServiceManager_OperatorAlreadyRegistered();
        
        isOperator[operator] = true;
        operators.push(operator);
        
        emit EventsLib.OperatorRegistered(operator);
    }

    /* WINNER COMMITMENT */

    /// @inheritdoc IAuctionServiceManager
    function commitWinner(
        PoolId poolId,
        uint256 targetBlock,
        address winner,
        uint256 bidAmount,
        bytes[] calldata signatures
    ) external override {
        if (winner == address(0)) revert ErrorsLib.AuctionServiceManager_ZeroWinner();
        // A winner may only be committed for the current block or one block in the future.
        if (block.number > targetBlock + 1) revert ErrorsLib.AuctionServiceManager_StaleBlock();
        if (_results[poolId][targetBlock].committed) {
            revert ErrorsLib.AuctionServiceManager_AlreadyCommitted();
        }

        bytes32 ethHash =
            keccak256(abi.encodePacked(poolId, targetBlock, winner, bidAmount)).toEthSignedMessageHash();

        uint256 validSigs = _countUniqueOperatorSigs(ethHash, signatures);
        if (validSigs < threshold) revert ErrorsLib.AuctionServiceManager_QuorumNotMet();

        _results[poolId][targetBlock] = AuctionResult({
            bidAmount: bidAmount, 
            winner: winner, 
            committed: true
        });

        emit EventsLib.WinnerCommitted(poolId, targetBlock, winner, bidAmount);
    }

    /* INTERNAL HELPERS */

    /// @dev Recovers each signature and counts how many distinct registered operators signed
    /// `ethHash`. Signatures from unknown signers and duplicate operator signatures are ignored,
    /// so a caller cannot pad the bundle with repeats or junk to reach the threshold.
    /// @param ethHash EIP-191 prefixed digest the operators are expected to have signed
    /// @param signatures Bundle of candidate operator signatures
    /// @return validSigs Number of unique registered operators that signed `ethHash`
    function _countUniqueOperatorSigs(bytes32 ethHash, bytes[] calldata signatures)
        internal
        view
        returns (uint256 validSigs)
    {
        address[] memory seen = new address[](signatures.length);

        for (uint256 i = 0; i < signatures.length; i++) {
            (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(ethHash, signatures[i]);
            if (err != ECDSA.RecoverError.NoError) continue;
            if (!isOperator[signer]) continue;

            bool duplicate = false;
            for (uint256 j = 0; j < validSigs; j++) {
                if (seen[j] == signer) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) continue;

            seen[validSigs] = signer;
            validSigs++;
        }
    }

    /* VIEW FUNCTIONS */

    /// @notice Returns the total number of registered operators.
    function operatorCount() external view returns (uint256) {
        return operators.length;
    }

    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    /// @inheritdoc IAuctionServiceManager
    function getWinner(PoolId poolId, uint256 blockNumber)
        external
        view
        override
        returns (AuctionResult memory)
    {
        return _results[poolId][blockNumber];
    }
}
