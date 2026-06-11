// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title FaucetToken
/// @author ohMySol
/// @notice A permissionless, mintable ERC20 for testnet demos. Anyone can call `faucet()` to receive
/// a fixed drip, so a visitor to the frontend can get tokens to provide liquidity or swap without an
/// external faucet. Decimals are configurable at deploy time so a realistic pair can be modelled.
/// @dev Testnet only — minting is open by design. Never deploy this on mainnet.
contract FaucetToken is ERC20 {
    /// @notice Decimals reported by this token (set once at construction).
    uint8 private immutable _decimals;

    /// @notice Amount minted to the caller on each `faucet()` call, in the token's smallest unit.
    uint256 public immutable faucetAmount;

    /// @param name_ ERC20 name.
    /// @param symbol_ ERC20 symbol.
    /// @param decimals_ Number of decimals this token uses.
    /// @param faucetWholeTokens Whole-token amount dispensed per `faucet()` call (scaled by decimals).
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 faucetWholeTokens)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
        faucetAmount = faucetWholeTokens * (10 ** decimals_);
    }

    /// @inheritdoc ERC20
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Mints the fixed `faucetAmount` to the caller. Permissionless (testnet only).
    function faucet() external {
        _mint(msg.sender, faucetAmount);
    }

    /// @notice Mints an arbitrary amount to `to`. Used by deploy scripts to seed demo participants.
    /// @dev Open by design for testnet convenience.
    /// @param to Recipient of the freshly minted tokens.
    /// @param amount Amount to mint, in the token's smallest unit.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
