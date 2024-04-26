// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script, console } from 'forge-std/Script.sol';
import { BaseMultiChainDeployer } from 'GeneralisedIncentives/script/BaseMultiChainDeployer.s.sol';
import { CatERC20Factory } from '../src/catERC20Factory.sol';
 
contract DeployFactory is BaseMultiChainDeployer {
 
    CatERC20Factory public catERC20Factory;
    bytes32 constant salt = 0x1234567890abcdef1234567890abcdef1239967890abcdef1234567890abcdef;
   
    function _deploy() internal {
        catERC20Factory = new CatERC20Factory{salt: salt}();
        console.log("CatERC20Factory deployed at:", address(catERC20Factory));

        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        
        address deployedToken = catERC20Factory.deployXERC20("Test", "TS", minterLimits, burnerLimits, bridges);
        console.log("ERC20 Token deployed at:", deployedToken);
    }

    // Function to deploy to all chains, with salt fixed
    function deployToAllChains() iter_chains(chain_list) broadcast external {
        _deploy();
    }

    // Function to deploy to specific chains, with salt fixed
    function deployToAllChains(string[] memory chains) iter_chains_string(chains) broadcast public {
        _deploy();
    }
}