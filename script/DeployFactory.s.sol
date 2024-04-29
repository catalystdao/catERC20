// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script, console } from 'forge-std/Script.sol';
import { BaseMultiChainDeployer } from 'GeneralisedIncentives/script/BaseMultiChainDeployer.s.sol';
import { CatERC20Factory } from '../src/catERC20Factory.sol';
 
contract DeployFactory is BaseMultiChainDeployer {
 
    CatERC20Factory public catERC20Factory;
    bytes32 constant salt = 0x1234567890abcdef1234567890abcdef1239967890abcdef1234567890abcdef;
   
    function _deployFactory() internal {
        catERC20Factory = new CatERC20Factory{salt: salt}();
        console.log("CatERC20Factory deployed at:", address(catERC20Factory));
    }

    function _deployXERC20() internal {
        catERC20Factory = new CatERC20Factory{salt: salt}();
        console.log("CatERC20Factory deployed at:", address(catERC20Factory));

        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        
        address deployedToken = catERC20Factory.deployXERC20("Test", "TS", minterLimits, burnerLimits, bridges);
        console.log("ERC20 Token deployed at:", deployedToken);
    }

    // Function to deploy to all chains, with salt fixed
    function deployFactoryToAllChains() iter_chains(chain_list) broadcast external {
        _deployFactory();
    }

    // Function to deploy to specific chains, with salt fixed
    function deployFactoryToAllChains(string[] memory chains) iter_chains_string(chains) broadcast public {
        _deployFactory();
    }

    // Function to deploy to all chains, with salt fixed
    function deployXERC20ToAllChains() iter_chains(chain_list) broadcast external {
        _deployXERC20();
    }

    // Function to deploy to specific chains, with salt fixed
    function deployXERC20ToAllChains(string[] memory chains) iter_chains_string(chains) broadcast public {
        _deployXERC20();
    }


}