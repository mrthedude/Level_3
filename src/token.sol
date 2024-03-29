// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract token is ERC20, Ownable {
    constructor(address owner) ERC20("Level3", "LVL3") Ownable(owner) {
        _mint(owner, 100000 * 10 ** decimals());
    }
}
