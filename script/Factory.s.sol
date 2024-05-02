// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import { CatERC20Factory } from "src/CatERC20Factory.sol";

contract DeployFactoryScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new CatERC20Factory{salt: bytes32(0)}();
    }
}
