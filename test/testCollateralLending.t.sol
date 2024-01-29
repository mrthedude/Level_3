// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {testCollateralLendingDeployer} from "../script/DeploymentScripts.s.sol";
import {CollateralLending} from "../src/CollateralLending.sol";
import {token} from "../src/token.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract testCollateralLending is Test, testCollateralLendingDeployer {
    CollateralLending collateralLending;
    address tokenAddress;
    token myToken;
    address owner;
    uint256 public constant STARTING_USER_BALANCE = 100e18;
    address public constant USER = address(1);

    function setUp() public {
        testCollateralLendingDeployer contractDeployer = new testCollateralLendingDeployer();
        collateralLending = contractDeployer.testRun();
        tokenAddress = collateralLending.getTokenAddress();
        myToken = token(tokenAddress);
        owner = collateralLending.getOwnerAddress();
        vm.deal(USER, STARTING_USER_BALANCE);
        vm.deal(owner, STARTING_USER_BALANCE);
    }

    //////////////////////////// testing testCollateralLendingDeployer ////////////////////////////
    function testContractAndTokenDeployment() public {
        assertEq(owner, collateralLending.getOwnerAddress());
        assertEq(tokenAddress, collateralLending.getTokenAddress());
    }

    //////////////////////////// testing CollateralLending ////////////////////////////
    ////////////// testing depositToken //////////////
    function testRevert_whenAmountIsZero() public {
        vm.startPrank(owner);
        vm.expectRevert(CollateralLending.amountCannotBeZero.selector);
        collateralLending.depositToken(0);
        vm.stopPrank();
    }

    function testFuzz_tokensAreSentToContract(uint256 tokenAmount) public {
        vm.assume(tokenAmount < 100000e18 && tokenAmount != 0);
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), tokenAmount);
        collateralLending.depositToken(tokenAmount);
        assertEq(myToken.balanceOf(address(collateralLending)), tokenAmount);
        vm.stopPrank();
    }

    function testFuzz_userDepositBalanceUpdates(uint256 tokenAmount) public {
        vm.assume(tokenAmount < 100000e18 && tokenAmount != 0);
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), tokenAmount);
        collateralLending.depositToken(tokenAmount);
        vm.stopPrank();
        assertEq(collateralLending.getTokenBalance(owner), tokenAmount);
    }

    ////////////// testing withdrawToken //////////////
    function testRevert_whenWithdrawAmountIsZero() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 1e18);
        collateralLending.depositToken(1e18);
        vm.expectRevert(CollateralLending.amountCannotBeZero.selector);
        collateralLending.withdrawToken(0);
        vm.stopPrank();
    }

    function testRevert_whenWithdrawAmountIsGreaterThanContractBalance() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 1e18);
        collateralLending.depositToken(1e18);
        vm.expectRevert(CollateralLending.notEnoughTokensInContractToBorrow.selector);
        collateralLending.withdrawToken(1.1e18);
        vm.stopPrank();
    }

    function testRevert_whenWithdrawAmountIsGreatedThanUserDepositBalance() public {
        vm.prank(owner);
        myToken.transfer(USER, 10e18);
        vm.startPrank(USER);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        vm.stopPrank();
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 1e18);
        collateralLending.depositToken(1e18);
        vm.expectRevert(CollateralLending.withdrawlAmountIsGreaterThanUserTokenBalance.selector);
        collateralLending.withdrawToken(1.1e18);
        vm.stopPrank();
    }

    function testFuzz_withdrawAmountIsSentToCallerAddress(uint256 tokenAmount) public {
        vm.assume(tokenAmount <= 100000e18 && tokenAmount != 0);
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), tokenAmount);
        collateralLending.depositToken(tokenAmount);
        collateralLending.withdrawToken(tokenAmount);
        vm.stopPrank();
        assertEq(myToken.balanceOf(owner), 100000e18);
    }

    function testFuzz_tokenBalanceOfUserTracksWithdrawls(uint256 tokenAmount) public {
        vm.assume(tokenAmount <= 100000e18 && tokenAmount != 0);
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), tokenAmount);
        collateralLending.depositToken(tokenAmount);
        collateralLending.withdrawToken(tokenAmount);
        vm.stopPrank();
        assertEq(collateralLending.getTokenBalance(owner), 0);
    }

    ////////////// testing borrowTokenWithCollateral //////////////
    function testRevert_whenborrowAmountIsZero() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        vm.expectRevert(CollateralLending.amountCannotBeZero.selector);
        collateralLending.borrowTokenWithCollateral{value: 2e18}(0);
        vm.stopPrank();
    }

    function testRevert_whenborrowAmountIsGreaterThanContractBalance() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        vm.expectRevert(CollateralLending.notEnoughTokensInContractToBorrow.selector);
        collateralLending.borrowTokenWithCollateral{value: 50e18}(11e18);
        vm.stopPrank();
    }

    function testFuzz_RevertBorrowWhenHealthFactorFallsBelowCollateralFactor(uint256 ethCollateral) public {
        vm.assume(ethCollateral < 15e18 && ethCollateral != 0);
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        vm.expectRevert(CollateralLending.actionWillCauseCollateralHealthFactorToFallBelowRequiredThreshold.selector);
        collateralLending.borrowTokenWithCollateral{value: ethCollateral}(10e18);
        vm.stopPrank();
    }

    function test_successfulBorrowAddsTokensToCallerAddress() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 15e18}(10e18);
        assertEq(myToken.balanceOf(owner), 100000e18);
    }

    function test_collateralBalanceIncreasesWithDeposits() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 20e18);
        collateralLending.depositToken(20e18);
        collateralLending.borrowTokenWithCollateral{value: 30e18}(5e18);
        assertEq(collateralLending.getDepositedCollateralBalance(owner), 30e18);
        vm.stopPrank();
    }

    function test_borrowedAmountsIncreasesWithBorrowing() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 15e18}(10e18);
        assertEq(collateralLending.getBorrowedTokenBalance(owner), 10e18);
    }

    function test_contractEtherBalanceIncreasesWithFunctionCall() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 15e18}(10e18);
        assertEq(address(collateralLending).balance, 15e18);
    }

    ////////////// testing repayToken //////////////
    function testRevert_whenRepayAmountIsZero() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 50e18}(10e18);
        vm.expectRevert(CollateralLending.amountCannotBeZero.selector);
        collateralLending.repayToken(0);
        vm.stopPrank();
    }

    function testRevert_whenRepaymentAmountIsGreaterThanDebt() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 50e18}(10e18);
        vm.expectRevert(CollateralLending.repaymentAmountIsGreaterThanOutstandingDebt.selector);
        collateralLending.repayToken(11e18);
        vm.stopPrank();
    }

    function test_repaidTokensAreSentToContract() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 20e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 50e18}(10e18);
        collateralLending.repayToken(10e18);
        assertEq(myToken.balanceOf(address(collateralLending)), 10e18);
        vm.stopPrank();
    }

    function test_borrowedAmountsReducesByRepaymentAmount() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 20e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 50e18}(10e18);
        collateralLending.repayToken(10e18);
        assertEq(collateralLending.getBorrowedTokenBalance(owner), 0);
        vm.stopPrank();
    }

    ////////////// testing withdrawEthCollateral //////////////
    function testRevert_whenWithdrawIsZero() public {
        vm.startPrank(owner);
        (bool success,) = address(collateralLending).call{value: 10e18}("");
        require(success, "Transfer Failed");
        vm.expectRevert(CollateralLending.amountCannotBeZero.selector);
        collateralLending.withdrawEthCollateral(0);
        vm.stopPrank();
    }

    function testFuzz_revertWhenWithdrawAmountIsGreaterThanEthDeposit(uint256 ethAmount) public {
        vm.assume(ethAmount > 1e18);
        vm.startPrank(owner);
        (bool success,) = address(collateralLending).call{value: 1e18}("");
        require(success, "Failed");
        vm.expectRevert(CollateralLending.withdrawlAmountGreaterThanCollateralDeposited.selector);
        collateralLending.withdrawEthCollateral(ethAmount);
        vm.stopPrank();
    }

    function testRevert_whenCollateralWithdrawCausesHealthFactorToFallBelowCollateralFactor() public {
        vm.startPrank(owner);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 15e18}(10e18);
        vm.expectRevert(CollateralLending.actionWillCauseCollateralHealthFactorToFallBelowRequiredThreshold.selector);
        collateralLending.withdrawEthCollateral(0.1e18);
        vm.stopPrank();
    }

    function test_collateralBalanceUpdatesWithWithdrawl() public {
        vm.startPrank(owner);
        (bool success,) = address(collateralLending).call{value: 10e18}("");
        require(success, "failed");
        collateralLending.withdrawEthCollateral(4e18);
        assertEq(collateralLending.getDepositedCollateralBalance(owner), 6e18);
        vm.stopPrank();
    }

    ////////////// testing liquidate //////////////
    ////////////// tests only work if src function checks are commented out //////////////

    function testRevert_whenBorrowerIsNotEligibleToBeLiquidated() public {
        vm.startPrank(owner);
        myToken.transfer(USER, 50e18);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 15e18}(10e18);
        vm.stopPrank();
        vm.startPrank(USER);
        myToken.approve(address(collateralLending), 10e18);
        vm.expectRevert(CollateralLending.borrowerIsNotEligibleToBeLiquidated.selector);
        collateralLending.liquidate(owner, 10e18);
        vm.stopPrank();
    }

    function testRevert_whenLiquidatorRepaysTheWrongTokenAmount() public {
        vm.startPrank(owner);
        myToken.transfer(USER, 50e18);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 14e18}(10e18);
        vm.stopPrank();
        vm.startPrank(USER);
        myToken.approve(address(collateralLending), 9e18);
        vm.expectRevert(CollateralLending.borrowerDebtMustBePaidToLiquidateCollateral.selector);
        collateralLending.liquidate(owner, 9e18);
        vm.stopPrank();
    }

    function test_liquidatedFundsAreSentToCallerAndTokensAreSubtracted() public {
        vm.startPrank(owner);
        myToken.transfer(USER, 10e18);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.depositToken(10e18);
        collateralLending.borrowTokenWithCollateral{value: 14e18}(10e18);
        vm.stopPrank();
        vm.startPrank(USER);
        myToken.approve(address(collateralLending), 10e18);
        collateralLending.liquidate(owner, 10e18);
        assertEq(myToken.balanceOf(USER), 0);
        assertEq(USER.balance, 114e18);
    }

    ////////////// testing ownerNeedsANewCar //////////////
    function testRevert_whencallerIsNotOwner() public {
        vm.prank(owner);
        (bool success,) = address(collateralLending).call{value: 10e18}("");
        require(success, "failed");
        vm.prank(USER);
        vm.expectRevert(CollateralLending.onlyTheOwnerCanCallThisFunction.selector);
        collateralLending.ownerNeedsANewCar(10);
    }

    function testFuzz_unitConversionFunctionality(uint256 ethAmount) public {
        vm.assume(ethAmount < 100);
        vm.startPrank(owner);
        (bool success,) = address(collateralLending).call{value: ethAmount * 10 ** 18}("");
        require(success, "failed");
        collateralLending.ownerNeedsANewCar(ethAmount);
        assertEq(address(collateralLending).balance, 0);
    }
}
