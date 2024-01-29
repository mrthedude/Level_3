// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error notATestingEnvironment();

    address public owner;

    function getOwnerAddress() public view returns (address _owner) {
        if (block.chainid == 534351) {
            // Scroll Sepolia
            return 0x6a571992ECaaDe9df63334BACEdD46C7C78e3Ef9;
        }

        if (block.chainid == 31337) {
            // Anvil
            return 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        }
        revert notATestingEnvironment();
    }
}
