//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { CatERC20Factory } from '../src/catERC20Factory.sol';
import { Script, console } from "forge-std/Script.sol";

contract DeployERC20 is Script {
    uint256 pk1;

    function getFactoryContractAddress(CatERC20Factory catERC20Factory) internal returns(address){
        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        address deployedToken = catERC20Factory.deployXERC20("Test", "ts", minterLimits, burnerLimits, bridges);
        return deployedToken;
    }
}