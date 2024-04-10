// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { CatERC20 } from "../../src/CatERC20.sol";
import { CatLockbox } from "../../src/CatLockbox.sol";
import { CatERC20Factory } from "../../src/CatERC20Factory.sol";

contract CatERC20FactoryTest is Test {
    CatERC20Factory CATERC20FACTORY;

    function setUp() public {
        CATERC20FACTORY = new CatERC20Factory();
    }

    //--- Deploy XERC20 Token ---/

    function test_deploy_simple_token(string calldata name, string calldata symbol) external {
        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        address deployedToken = CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, burnerLimits, bridges);

        // Checks:
        // 1. Owner is set to us. (address(this)).
        assertEq(CatERC20(deployedToken).owner(), address(this), "Owner not correctly set");

        // 2. Name and symbol
        assertEq(CatERC20(deployedToken).name(), name, "Name not set correctly");
        assertEq(CatERC20(deployedToken).symbol(), symbol, "Symbol not set correctly");

        // 3. Check that it has 0 totalSupply.
        assertEq(CatERC20(deployedToken).totalSupply(), 0, "Not valid initial token");
    }

    /** @dev Tokens are deployed with create2, with salt as sender, name and symbol. As a result, you can't do deployments of same parameters twice. */
    function test_revert_deploy_twice_same_parameters(string calldata name, string calldata symbol) external {
        uint256[] memory minterLimits = new uint256[](0);
        uint256[] memory burnerLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, burnerLimits, bridges);

        vm.expectRevert();
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, burnerLimits, bridges);

        // If we use another sender, then we get another address.
        vm.prank(address(200));
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, burnerLimits, bridges);
    }

    //TODO: Check events.

    //--- Deploy Lockbox ---//

    function test_deploy_lockbox(address caterc20, address baseToken) external {
        bool isNative = baseToken == address(0);
        address payable lockbox = CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);

        // Checks:
        // 1. Check that the caterc20 is set.
        assertEq(address(CatLockbox(lockbox).XERC20()), caterc20, "caterc20 not correctly set");

        // 2. Check that the basetoken is set.
        assertEq(address(CatLockbox(lockbox).ERC20()), baseToken, "erc20 not correctly set");
    }

    // TODO: Check events.
    // TODO: isnative
    /** @dev Tokens are deployed with create2, with salt as caterc20 and baseToken. As a result, you can't do deployments of same parameters twice. */
    function test_revert_deploy_twice_same_parameters(address caterc20, address baseToken) external {
        bool isNative = baseToken == address(0);
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);

        vm.expectRevert();
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);

        // If we use another sender, then we still get the same address and it reverts.
        vm.prank(address(200));
        vm.expectRevert();
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);
    }

    //--- Deploy CatERC20 & Lockbox ---//

    function test_deploy_token_and_lockbox(string calldata name, string calldata symbol, address baseToken) external {
        uint256[] memory minterLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        bool isNative = baseToken == address(0);
        (address deployedToken, address payable lockbox) = CATERC20FACTORY.deployXERC20WithLockbox(name, symbol, minterLimits, bridges, baseToken, isNative);

        // Checks:
        // 1. Owner is set to us. (address(this)).
        assertEq(CatERC20(deployedToken).owner(), address(this), "Owner not correctly set");

        // 2. Name and symbol
        assertEq(CatERC20(deployedToken).name(), name, "Name not set correctly");
        assertEq(CatERC20(deployedToken).symbol(), symbol, "Symbol not set correctly");

        // 3. Check that it has 0 totalSupply.
        assertEq(CatERC20(deployedToken).totalSupply(), 0, "Not valid initial token");

        // Checks:
        // 1. Check that the caterc20 is set.
        assertEq(address(CatLockbox(lockbox).XERC20()), deployedToken, "caterc20 not correctly set");

        // 2. Check that the basetoken is set.
        assertEq(address(CatLockbox(lockbox).ERC20()), baseToken, "erc20 not correctly set");
    }
}
