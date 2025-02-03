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
    
    function _mintAccruedInterest(address _user) internal {
        // (1) find their current balance of the rebase tokens that have been minted to the user -> principle balance
        // (2) calculate their current balance including any interest --> balanceOf
        // calculate the number of tokens that need to be minted to the user -> (2) -(1)
        // calculate _mint to mint the tokens to the user
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
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