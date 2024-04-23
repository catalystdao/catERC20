//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from 'forge-std/Script.sol';
import {CatERC20Factory} from '../src/catERC20Factory.sol';
import {BaseMultiChainDeployer} from '../lib/GeneralisedIncentives/script/BaseMultiChainDeployer.s.sol';


contract DeployFactory is BaseMultiChainDeployer{

    CatERC20Factory catERC20Factory;
    function _deploy() public returns(CatERC20Factory){
            catERC20Factory = new CatERC20Factory();
        return catERC20Factory;
    }

    function deployToAllChains()  iter_chains(chain_list) broadcast external {
        _deploy();
    }

    
    function deployToAllChains( string[] memory chains) iter_chains_string(chains) broadcast external {
        _deploy();
    }
}