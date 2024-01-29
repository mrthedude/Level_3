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

/**
 * @title Collateral Lending Contract
 * @notice This contract allows users to deposit ERC20 tokens, borrow against them as collateral, and repay their loans.
 * @dev This contract does not handle interest rates or loan durations.
 */
contract CollateralLending {
    error messageCallDoesNotMatchAnyContractFunctions();
    error amountCannotBeZero();
    error repaymentAmountIsGreaterThanOutstandingDebt();
    error withdrawlAmountIsGreaterThanUserTokenBalance();
    error onlyTheOwnerCanCallThisFunction();
    error transferFailed();
    error notEnoughTokensInContractToBorrow();
    error actionWillCauseCollateralHealthFactorToFallBelowRequiredThreshold();
    error withdrawlAmountGreaterThanCollateralDeposited();
    error borrowerIsNotEligibleToBeLiquidated();
    error borrowerDebtMustBePaidToLiquidateCollateral();

    using SafeERC20 for IERC20;

    /// @notice Stores the token balances of each user.
    mapping(address user => uint256 depositedTokenBalance) private _tokenBalance;

    /// @notice Stores the borrowed token amounts of each user.
    mapping(address user => uint256 debtBalance) private _borrowedAmounts;

    mapping(address user => uint256 ethDeposited) private _collateralBalance;

    /// @notice Stores the owner of the contract for restricted access functions
    address private immutable i_owner;

    /// @notice The ERC20 token used for lending and borrowing.
    IERC20 private immutable i_token;

    /// @notice The collateral factor, representing the percentage of tokens required as collateral.
    uint256 public constant COLLATERAL_FACTOR = 150; // 150% -> The collateral deposited must be at least 1.5x the value of the tokens borrowed

    event ethSentToContract(
        address indexed sender, uint256 indexed amountOfEthSent, uint256 indexed totalUserEthBalance
    );
    event userDepositedTokens(
        address indexed user, uint256 indexed amountDeposited, uint256 indexed totalDepositedBalance
    );
    event tokensWithdrawn(address indexed user, uint256 indexed withdrawlAmount, uint256 indexed totalDepositedBalance);
    event debtReduced(address indexed user, uint256 indexed amountRepaid, uint256 indexed totalOutstandingDebt);
    event userBorrowedTokens(address indexed user, uint256 totalDebt, uint256 indexed currentCollateralHealthFactor);
    event collateralWithdrawn(
        address indexed user, uint256 indexed amountWithdrawn, uint256 indexed remainingCollateralDeposited
    );
    event userLiquidated(address indexed liquidatedUser);
    event safu(string indexed ggBoys);

    /// @notice Modifier to restict inputs on certain functions to be above 0
    modifier cannotBeZero(uint256 amount) {
        if (amount == 0) {
            revert amountCannotBeZero();
        }
        _;
    }

    /// @notice Modifier to restrict access to calling functions to only the owner
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert onlyTheOwnerCanCallThisFunction();
        }
        _;
    }

    /// @notice Checks to see if there are enough tokens in the contract to borrow or withdraw against
    modifier tokenBalanceCheck(uint256 tokenAmount) {
        if (i_token.balanceOf(address(this)) < tokenAmount) {
            revert notEnoughTokensInContractToBorrow();
        }
        _;
    }

    /**
     * @notice Sets the token to be used for lending/borrowing and the owner of the contract
     * @param tokenAddress The address of the ERC20 token used for lending and borrowing.
     * @param owner The address of the owner of the contract
     */
    constructor(address tokenAddress, address owner) {
        i_token = IERC20(tokenAddress);
        i_owner = owner;
    }

    /// @notice Catch-all function to receive ETH sent to the contract when no calldata is sent
    /// @notice Updates a user's collateral balance that they are eligible to borrow against
    receive() external payable {
        _collateralBalance[msg.sender] += msg.value;
        emit ethSentToContract(msg.sender, msg.value, _collateralBalance[msg.sender]);
    }

    /// @notice Catch-all function to revert calls to the contract that do not match any function signatures
    fallback() external {
        revert messageCallDoesNotMatchAnyContractFunctions();
    }

    /**
     * @notice Allows users to deposit tokens into the contract.
     * @param amount The amount of tokens to deposit
     * @dev The input cannot be zero
     */
    function depositToken(uint256 amount) external cannotBeZero(amount) {
        i_token.safeTransferFrom(msg.sender, address(this), amount);
        _tokenBalance[msg.sender] += amount;
        emit userDepositedTokens(msg.sender, amount, _tokenBalance[msg.sender]);
    }

    /**
     * @notice Allows users to withdraw their tokens from the contract.
     * @param amount The amount of tokens to withdraw.
     * @dev Requires that the user has enough balance to withdraw.
     */
    function withdrawToken(uint256 amount) external tokenBalanceCheck(amount) cannotBeZero(amount) {
        if (_tokenBalance[msg.sender] < amount) {
            revert withdrawlAmountIsGreaterThanUserTokenBalance();
        }
        i_token.safeTransfer(msg.sender, amount);
        _tokenBalance[msg.sender] -= amount;
        emit tokensWithdrawn(msg.sender, amount, _tokenBalance[msg.sender]);
    }

    /**
     * @notice Allows users to borrow tokens by providing ETH as collateral.
     * @notice Updates the user's collateral balance
     * @notice Updates the user's borrowed tokens balance
     * @param tokenAmount The amount of tokens to borrow.
     * @dev Requires that the user provides enough ETH as collateral and that the contract has enough tokens to lend.
     */
    function borrowTokenWithCollateral(uint256 tokenAmount)
        external
        payable
        cannotBeZero(tokenAmount)
        tokenBalanceCheck(tokenAmount)
    {
        uint256 requiredCollateralAmount = tokenAmount * COLLATERAL_FACTOR / 100;
        if (msg.value + _collateralBalance[msg.sender] < requiredCollateralAmount) {
            revert actionWillCauseCollateralHealthFactorToFallBelowRequiredThreshold();
        }
        i_token.safeTransfer(msg.sender, tokenAmount);
        _collateralBalance[msg.sender] += msg.value;
        _borrowedAmounts[msg.sender] += tokenAmount;
        emit userBorrowedTokens(
            msg.sender,
            _borrowedAmounts[msg.sender],
            ((_collateralBalance[msg.sender] * 1e18 / _borrowedAmounts[msg.sender]) * 100) / 1e18
        );
    }

    /**
     * @notice Allows users to repay their borrowed tokens.
     * @param tokenAmount The amount of tokens to repay.
     * @dev Requires that the user has borrowed at least the amount they are trying to repay.
     */
    function repayToken(uint256 tokenAmount) external cannotBeZero(tokenAmount) {
        if (_borrowedAmounts[msg.sender] < tokenAmount) {
            revert repaymentAmountIsGreaterThanOutstandingDebt();
        }

        i_token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        _borrowedAmounts[msg.sender] -= tokenAmount;
        emit debtReduced(msg.sender, tokenAmount, _borrowedAmounts[msg.sender]);
    }

    /**
     * @notice Allows users to withdraw deposited ETH
     * @param ethAmount The amount of ETH the user specifies to withdraw from the contract
     * @dev Requires that ethAmount does not exceed the user's deposited ETH amount
     * @dev Requires COLLATERAL_FACTOR of user to be above threshold after withdrawl
     */
    function withdrawEthCollateral(uint256 ethAmount) public cannotBeZero(ethAmount) {
        if (_collateralBalance[msg.sender] < ethAmount) {
            revert withdrawlAmountGreaterThanCollateralDeposited();
        }
        if (
            _borrowedAmounts[msg.sender] != 0
                && (((_collateralBalance[msg.sender] - ethAmount) * 1e18 / _borrowedAmounts[msg.sender]) * 100) / 1e18
                    < COLLATERAL_FACTOR
        ) {
            revert actionWillCauseCollateralHealthFactorToFallBelowRequiredThreshold();
        }
        (bool success,) = msg.sender.call{value: ethAmount}("");
        if (!success) {
            revert transferFailed();
        }
        _collateralBalance[msg.sender] -= ethAmount;
        emit collateralWithdrawn(msg.sender, ethAmount, _collateralBalance[msg.sender]);
    }

    /**
     * @notice Allows for the liquidation of a borrower's collateral if they fail to maintain the required collateral factor.
     * @param borrower The address of the borrower.
     * @param tokenAmount The amount of tokens to be liquidated.
     * @dev Requires that the borrower is below the required COLLATERAL_FACTOR threshold and that they have borrowed the specified token amount.
     */
    function liquidate(address borrower, uint256 tokenAmount) external payable {
        if (
            _borrowedAmounts[borrower] == 0
                || (
                    (((_collateralBalance[borrower] * 1e18) / _borrowedAmounts[borrower]) * 100) / 1e18 >= COLLATERAL_FACTOR
                )
        ) {
            revert borrowerIsNotEligibleToBeLiquidated();
        }
        if (tokenAmount != _borrowedAmounts[borrower]) {
            revert borrowerDebtMustBePaidToLiquidateCollateral();
        }

        i_token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        (bool success,) = msg.sender.call{value: _collateralBalance[borrower]}("");
        if (!success) {
            revert transferFailed();
        }
        emit userLiquidated(borrower);
    }

    /**
     * @notice Allows the contract owner to withdraw ETH
     * @param ethAmount The amount of ETH in the contract that the owner specifies to withdraw
     */
    function ownerNeedsANewCar(uint256 ethAmount) external onlyOwner {
        (bool success,) = i_owner.call{value: ethAmount * 10 ** 18}("");
        if (!success) {
            revert transferFailed();
        }
        emit safu("Funds are being put to a good use");
    }

    /**
     * @notice Getter functions to retrieve contract data
     */
    function getTokenAddress() public view returns (address tokenAddress) {
        tokenAddress = address(i_token);
    }

    function getOwnerAddress() public view returns (address contractOwner) {
        contractOwner = i_owner;
    }

    function getTokenBalance(address user) public view returns (uint256 tokenBalance) {
        tokenBalance = _tokenBalance[user];
    }

    function getDepositedCollateralBalance(address user) public view returns (uint256 ethCollateral) {
        ethCollateral = _collateralBalance[user];
    }

    function getBorrowedTokenBalance(address user) public view returns (uint256 borrowedAmount) {
        borrowedAmount = _borrowedAmounts[user];
    }
}
