// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script, console } from 'forge-std/Script.sol';
import { BaseMultiChainDeployer } from 'GeneralisedIncentives/script/BaseMultiChainDeployer.s.sol';
import { CatERC20Factory } from '../src/catERC20Factory.sol';
import { Create2 } from './Create2.sol';
 
contract DeployFactory is BaseMultiChainDeployer {
 
    CatERC20Factory catERC20Factory;
    Create2 create2;
    
    function _deploy() public returns (CatERC20Factory) {
        create2 = new Create2();
        bytes32 salt = bytes32(uint256(12345)); 
        bytes memory creationCode = type(CatERC20Factory).creationCode;
        CatERC20Factory deployedAddress = CatERC20Factory(create2.deploy(salt, creationCode));
        return deployedAddress;
    }

    function deployToAllChains() iter_chains(chain_list) broadcast external {
        _deploy();
    }

    function deployToAllChains(string[] memory chains) iter_chains_string(chains) broadcast external {
        _deploy();
    }
}