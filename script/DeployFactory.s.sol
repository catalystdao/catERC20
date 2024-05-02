// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import {StdAssertions} from "forge-std/StdAssertions.sol";
import {Script, console2} from "forge-std/Script.sol";

import { CatERC20Factory } from "src/CatERC20Factory.sol";

contract DeployFactoryScript is Script, StdAssertions {
    function setUp() public {}

    function deployFactory() public returns(CatERC20Factory fact) {
        vm.broadcast();

        fact = new CatERC20Factory{salt: bytes32(0x121b3296e0ac6ed96b0e1c2ce9a6213991b7d8549fa9f83b794fb501b8603cc3)}();

        assertEq(address(fact), 0x0000000065a80d469A41ef286008afA7BF9E252b);
        console2.logAddress(address(fact));
    }

    function test(string memory name, string memory symbol, address owner, bytes12 salt) public {
        CatERC20Factory fact = deployFactory();
        vm.broadcast();

        address tkn = fact.deployXERC20(name, symbol, owner, salt);

        console2.logAddress(tkn);
    }
}
