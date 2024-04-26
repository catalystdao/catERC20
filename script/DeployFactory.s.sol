// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script, console } from 'forge-std/Script.sol';
import { BaseMultiChainDeployer } from 'GeneralisedIncentives/script/BaseMultiChainDeployer.s.sol';
import { CatERC20Factory } from '../src/catERC20Factory.sol';
import { Create2 } from './Create2.sol';
import {DeployERC20} from './DeployERC20.s.sol';
 
contract DeployFactory is BaseMultiChainDeployer,DeployERC20 {
 
    CatERC20Factory public catERC20Factory;
    Create2 create2;
   
    
    function _deploy() public  {
        create2 = new Create2();
        bytes32 salt = bytes32(uint256(12345)); 
        bytes memory creationCode = type(CatERC20Factory).creationCode;
        catERC20Factory = CatERC20Factory(create2.deploy(salt, creationCode));
        address deployedToken = getFactoryContractAddress(catERC20Factory);
    }


    function deployToAllChains() iter_chains(chain_list) broadcast external {
        _deploy();
    }

    function deployToAllChains(string[] memory chains) iter_chains_string(chains) broadcast public {
        _deploy();
    }
}