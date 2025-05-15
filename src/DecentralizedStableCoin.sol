// SPDX-License-Identifier: SEE LICENSE IN LICENSE

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.29;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Harshana Abeyaratne
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * @notice Governed by DSCEngine.sol. ERC20 implementation of stableCoin.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__BalanceNotEnoughToBurn();
    error DecentralizedStableCoin__BurnAmountMustBeMoreThanZero();
    error DecentralizedStableCoin__CannotMintToZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _value) public override onlyOwner {
        if (_value == 0) {
            revert DecentralizedStableCoin__BurnAmountMustBeMoreThanZero();
        }
        if (balanceOf(msg.sender) < _value) {
            revert DecentralizedStableCoin__BalanceNotEnoughToBurn();
        }

        super.burn(_value);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__CannotMintToZeroAddress();
        }

        if (_amount == 0) {
            revert DecentralizedStableCoin__BurnAmountMustBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
