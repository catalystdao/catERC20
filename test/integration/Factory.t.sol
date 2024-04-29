//SPDX-License-Identifier:Mit


pragma solidity ^0.8.18;
import {Test} from 'forge-std/Test.sol';
import {CatERC20Factory} from '../../src/catERC20Factory.sol';
import {CatERC20} from '../../src/catERC20.sol';
import {CatLockbox} from '../../catLockbox.sol';
contract Factory is Test{

    CatERC20Factory catERC20Factory;
    string constant private TOKEN_NAME = "Test";
    string constant private TOKEN_SYMBOL = "Ts";
    function setUp() external {
        vm.startBroadcast();
        catERC20Factory = new CatERC20Factory();
        vm.startBroadcast();
    }

    function test_deploy_simple_token() external{

        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);

        CatERC20 catERC20Contract = CatERC20(catERC20Factory.deployXERC20(TOKEN_NAME,TOKEN_SYMBOL,minterLimits,burnerLimits,bridges));
        

        assertEq(TOKEN_NAME,catERC20Contract.name());
        assertEq(TOKEN_SYMBOL,catERC20Contract.symbol());
        assertEq(catERC20Contract.owner(),address(this));
        assertEq(catERC20Contract.totalSupply(),0);
    }

    function test_deploy_simple_token_twice() external{

        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);

        catERC20Factory.deployXERC20(TOKEN_NAME,TOKEN_SYMBOL,minterLimits,burnerLimits,bridges);

        vm.expectRevert();
        catERC20Factory.deployXERC20(TOKEN_NAME,TOKEN_SYMBOL,minterLimits,burnerLimits,bridges);

        vm.prank(address(200));
        catERC20Factory.deployXERC20(TOKEN_NAME,TOKEN_SYMBOL,minterLimits,burnerLimits,bridges);
    }

    function test_deploy_lockbox(address caterc20, address basetoken) external {

        bool isNative = false;
        basetoken = address(0);
        CatLockbox lockbox = catLockbox(catERC20Factory.deployLockbox(caterc20,basetoken,isNative));
        assertEq(address(lockbox.XERC20()),caterc20);
        assertEq((address(lockbox.ERC20())),baseToken);

    }

    function testr_deploy_lockbox_twice() external{
        bool isNative = false;
        basetoken = address(0);
        CatLockbox lockbox = catLockbox(catERC20Factory.deployLockbox(caterc20,basetoken,isNative));

        vm.expectRevert();
        CatLockbox lockbox = catLockbox(catERC20Factory.deployLockbox(caterc20,basetoken,isNative));

        vm.prank(address(102));
        CatLockbox lockbox = catLockbox(catERC20Factory.deployLockbox(caterc20,basetoken,isNative));
    }
}