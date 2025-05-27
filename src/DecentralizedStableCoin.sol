// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Okhamena Azeez
 * @notice This is the ERC20 implementation of our stablecoin system
 * @dev This contract is governed by the DSCEngine contract
 * @custom:collateral Exogenous (ETH and BTC)
 * @custom:minting Algorithmic
 * @custom:stability Pegged to USD
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    // Errors
    error DecentralizedStableCoin__AmountMustBeGreaterThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();


    /**
     * @notice Constructor initializes the token with name and symbol
     * @dev Sets the owner to the deployer of the contract
     * @dev Inherits from ERC20 and Ownable contracts
     * @dev Token name: "DecentralizedStableCoin"
     * @dev Token symbol: "DSC"
     */
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    /**
     * @notice Mints new tokens to a specified address
     * @dev Only callable by the owner
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     * @return bool Returns true if minting is successful
     * @custom:throws DecentralizedStableCoin__NotZeroAddress if recipient address is zero
     * @custom:throws DecentralizedStableCoin__AmountMustBeGreaterThanZero if amount is zero or negative
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeGreaterThanZero();
        }
        _mint(_to, _amount);
        return true;
    }

    /**
     * @notice Burns a specific amount of tokens from the caller's balance
     * @dev Only callable by the owner
     * @param _amount The amount of tokens to burn
     * @custom:throws DecentralizedStableCoin__AmountMustBeGreaterThanZero if amount is zero or negative
     * @custom:throws DecentralizedStableCoin__BurnAmountExceedsBalance if burn amount exceeds balance
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeGreaterThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
}
