//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Layout of contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// private
// view & pure functions


import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title RebaseToken
* @author Adrian Casal
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards
* @notice The interest rate in the smart contract can only decrease
* @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
*/
contract RebaseToken is ERC20 {
    error RebaseToken_InteresRateCanOnlyDecrease(uint256 oldInteresRate, uint256 newInterestRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userinterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    constructor() ERC20("RebaseToken", "RBT") {}

    event InterestRateSet(uint256 newInterestRate);

    /*
    * @notice Set the interest rate in the contract
    * @param _newInterestRate The new interest rate to set
    * @dev The interest rate can only decrease
    */
    function setInteresRate(uint256 _newInterestRate) external {
        // Set the interest rate
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken_InteresRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /*
    * @notice Get the principle balance of a user. This is the number of tokens that have currently been minted to the user, 
    not including any interest that has accrued since the last time the user interacted with the protocol.
    * @param _user The user to get the principle balance for
    * @return The principle balance of the user
    */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /*
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user to mint the tokens to
    * @param _amount The amount of the tokens to mint
    */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userinterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /*
    * @notice Burn the user tokens when they widthdraw from the vault
    * @param _from The user to burn the tokens from
    * @param _amount The amount of tokens to burn
    */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /*
    * calculate the balance for the user including the interest that has accumulated since the last update
    * (principle balance) + some interest that has accrued
    * @param _user The user to calculate the balance for
    * @return The balance of the user including the interest that has accumulated since the last update
    */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of tokens that have actually been minted to the user)
        // multiply the principle balance by the interest that has accumulated in the time since the balance was upated
        return super.balanceOf(_user) * _calculateUserAcccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR;
    }

    /*
    * @notice Transfer tokens from one user to another
    * @param _recipient The user to transfer the tokens to
    * @param _amount The amount of tokens to transfer
    * @return True if the transfer was successful
    */
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userinterestRate[_recipient] = s_userinterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /*
    * @notice Transfer tokens from one user to another
    * @param _sender The user to transfer the tokens from
    * @param _recipient The user to transfer the tokens to
    * @param _amount The amount of tokens to transfer
    * @return True if the transfer was successful
    */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userinterestRate[_recipient] = s_userinterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);        
    }
 
    /*
    * @notice Calculate the interest that has accumulated since the last update
    * @param _user The user to calculate the interest accumulate for
    * @return The interest that has accumulated since the las update
    */
    function _calculateUserAcccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        // we need to calculate the interest that has accumulated since the last updated
        // this is going to be linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linea growth
        // principle amount(1 + (user interest rate * time elapsed))
        // deposit: 10 tokens
        // interest rate 0.5 tokens per second
        // time elapsed is 2 seconds
        // 10 + (10 * 0.5 * 2)
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userinterestRate[_user] * timeElapsed);
    }
    
    /*
    * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
    * @param _user The user to mint the accrued interest to
    */
    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of the rebase tokens that have been minted to the user -> principle balance
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest --> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> (2) -(1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        // calculate _mint to mint the tokens to the user
        _mint(_user, balanceIncrease);
    }

    /*
    * @notice Get the interest rate that is currently set for the contract. Any future depositors will receive this interest rate
    * @return The interest rate for the contract
    */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /*
    * @notice Get the interest rate for the user
    * @param _user The user to get the interest rate for
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userinterestRate[_user];
    }
}