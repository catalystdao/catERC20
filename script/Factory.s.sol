// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import {StdAssertions} from "forge-std/StdAssertions.sol";
import {Script, console2} from "forge-std/Script.sol";

import { CatERC20Factory } from "src/CatERC20Factory.sol";

contract DeployFactoryScript is Script, StdAssertions {
    function setUp() public {}

    function deployFactory() public returns(CatERC20Factory fact) {
        vm.broadcast();

        fact = new CatERC20Factory{salt: bytes32(0x674bffae0d0816cab9be2a8df93557866622de5e01b16c801d7cc4fe66d7163c)}(); // 0x000000000d53e6b5968b70Fdd3cb68B5e216cE93

        assertEq(address(fact), 0x000000000d53e6b5968b70Fdd3cb68B5e216cE93);
        console2.logAddress(address(fact));
    }

    function test(address owner, bytes12 salt) public {
        CatERC20Factory fact = deployFactory();
        vm.broadcast();

        address tkn = fact.deployXERC20("Name", "Symbol", owner, salt);

        console2.logAddress(tkn);
    }
}
