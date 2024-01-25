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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract collateralLending {
    error messageCallDoesNotMatchAnyContractFunctions();
    error amountCannotBeZero();

    using SafeERC20 for IERC20;

    address private _owner;
    IERC20 private immutable i_token;

    mapping(address user => uint256 collateralBalance) private _collateralBalance;
    mapping(address user => uint256 debtBalance) private _debtBalance;

    event ethSentToContract(address indexed sender);
    event collateralDeposited(
        address indexed depositor, uint256 indexed amountDeposited, uint256 indexed currentUserBalance
    );

    modifier cannotBeZero(uint256 amount) {
        if (amount == 0) {
            revert amountCannotBeZero();
        }
        _;
    }

    constructor(address owner, address tokenAddress) {
        _owner = owner;
        i_token = IERC20(tokenAddress);
    }

    receive() external payable {
        emit ethSentToContract(msg.sender);
    }

    fallback() external {
        revert messageCallDoesNotMatchAnyContractFunctions();
    }

    function depositCollateral(uint256 amount) external cannotBeZero(amount) {
        i_token.approve(address(this), amount);
        i_token.safeTransferFrom(msg.sender, address(this), amount);
        _collateralBalance[msg.sender] += amount;
        emit collateralDeposited(msg.sender, amount, _collateralBalance[msg.sender]);
    }

    function withdrawCollateral() external {}

    function borrowAsset(uint256 amount) external cannotBeZero(amount) {}

    function repayLoan(uint256 amount) external cannotBeZero(amount) {}

    function liquidateCollateral(address borrower) external {}
}
