// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {token} from "../src/token.sol";
import {CollateralLending} from "../src/CollateralLending.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract tokenDeployer is Script {
    HelperConfig helperConfig = new HelperConfig();
    address tokenOwner = helperConfig.getOwnerAddress();

    function run() public returns (token) {
        vm.startBroadcast();
        token myToken = new token(tokenOwner);
        vm.stopBroadcast();
        return myToken;
    }
}

contract testCollateralLendingDeployer is Script, tokenDeployer {
    function testRun() public returns (CollateralLending) {
        HelperConfig helperConfig = new HelperConfig();
        address contractOwner = helperConfig.getOwnerAddress();
        token testToken = tokenDeployer.run();
        vm.startBroadcast();
        CollateralLending collateralLending = new CollateralLending(address(testToken), contractOwner);
        vm.stopBroadcast();
        return collateralLending;
    }
}

contract CollateralLendingDeployer is Script {
    function run() public returns (CollateralLending) {
        HelperConfig helperConfig = new HelperConfig();
        address contractOwner = helperConfig.getOwnerAddress();
        address tokenAddress = 0xc4fcaCC1D17FF9057Aa2BCDE3a3dc26F455a4A54;
        vm.startBroadcast();
        CollateralLending collateralLending = new CollateralLending(tokenAddress, contractOwner);
        vm.stopBroadcast();
        return collateralLending;
    }
}
