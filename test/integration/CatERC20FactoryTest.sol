// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";

import { CatERC20 } from "../../src/CatERC20.sol";
import { CatLockbox } from "../../src/CatLockbox.sol";
import { CatERC20Factory } from "../../src/CatERC20Factory.sol";

contract CatERC20FactoryTest is Test {
    CatERC20Factory CATERC20FACTORY;

    function setUp() public {
        CATERC20FACTORY = new CatERC20Factory();
    }

    //--- Deploy XERC20 Token ---/

     function test_deploy_simple_token_with_owner(string calldata name, string calldata symbol, address owner, bytes12 salt) external {
        vm.assume(owner != address(0));
        address deployedToken = CATERC20FACTORY.deployXERC20(name, symbol, owner, salt);

        // Checks:
        // 1. Owner is set to address we provided.
        assertEq(CatERC20(deployedToken).owner(), owner, "Owner not correctly set");

        // 2. Name and symbol
        assertEq(CatERC20(deployedToken).name(), name, "Name not set correctly");
        assertEq(CatERC20(deployedToken).symbol(), symbol, "Symbol not set correctly");

        // 3. Check that it has 0 totalSupply.
        assertEq(CatERC20(deployedToken).totalSupply(), 0, "Not valid initial token");
    }

    /** @notice Checks that we can't deploy the same salt twice (with same owner). */
    function test_salt_determines_address(string calldata name, string calldata symbol, address owner, bytes12 salt) external {
        vm.assume(owner != address(0));
        vm.assume(owner != address(type(uint160).max));
        CATERC20FACTORY.deployXERC20(name, symbol, owner, salt);

        vm.expectRevert();
        CATERC20FACTORY.deployXERC20(name, symbol, owner, salt);

        unchecked {
            CATERC20FACTORY.deployXERC20(name, symbol, owner, bytes12(uint96(salt) + 1));
            CATERC20FACTORY.deployXERC20(name, symbol, address(uint160(owner) + 1), salt);
        }

    }

    function test_deploy_simple_token(string calldata name, string calldata symbol) external {
        uint256[] memory minterLimits = new uint256[](0);
        address[] memory bridges = new address[](0);
        address deployedToken = CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);

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
        address[] memory bridges = new address[](0);
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);

        vm.expectRevert();
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);

        // If we use another sender, then we get another address.
        vm.prank(address(200));
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);
    }

    /** Also contains a revert test.  */
    function test_set_minting_limits_on_create(string calldata name, string calldata symbol, uint104[] calldata minterLimits_, address[] calldata bridges_) external {
        address[] memory bridges = bridges_;

        for (uint256 i = 0; i < bridges.length; ++i) {
            // bridges cannot have address 0 since that is the default lockbox.
            if (bridges[i] == address(0)) bridges[i] = address(1);
        }

        uint256[] memory minterLimits = new uint256[](minterLimits_.length);
        for (uint256 i = 0; i < minterLimits_.length; ++i) {
            minterLimits[i] = minterLimits_[i];
        }

        if (minterLimits.length != bridges.length) {
            vm.expectRevert(abi.encodeWithSignature("IXERC20Factory_InvalidLength()"));
            CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);
            return;
        }
        uint256 snapshotId = vm.snapshot();
        address deploymentAddress = CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);

        vm.revertTo(snapshotId);

        for (uint256 i = 0; i < minterLimits_.length; ++i) {
            vm.expectCall(deploymentAddress, abi.encodeWithSignature("setLimits(address,uint256,uint256)", bridges[i], minterLimits[i], 0));
        }
        CATERC20FACTORY.deployXERC20(name, symbol, minterLimits, bridges);
    }

    //TODO: Check events.

    //--- Deploy Lockbox ---//

    function test_deploy_lockbox(address caterc20, bytes32 tokenSalt) external {
        MockERC20 ERC20 = new MockERC20{salt: tokenSalt}("hello", "hello", 0);
        address baseToken = address(ERC20);

        bool isNative = baseToken == address(0);
        address payable lockbox = CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);

        // Checks:
        // 1. Check that the caterc20 is set.
        assertEq(address(CatLockbox(lockbox).XERC20()), caterc20, "caterc20 not correctly set");

        // 2. Check that the basetoken is set.
        assertEq(address(CatLockbox(lockbox).ERC20()), baseToken, "erc20 not correctly set");
    }

    // TODO: Check events.
    /** @dev Tokens are deployed with create2, with salt as caterc20 and baseToken. As a result, you can't do deployments of same parameters twice. */
    function test_revert_deploy_twice_same_parameters(address caterc20, bytes32 tokenSalt) external {
        MockERC20 ERC20 = new MockERC20{salt: tokenSalt}("hello", "hello", 0);
        address baseToken = address(ERC20);

        bool isNative = baseToken == address(0);
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);

        vm.expectRevert();
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);

        // If we use another sender, then we still get the same address and it reverts.
        vm.prank(address(200));
        vm.expectRevert();
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);
    }

    function test_revert_compare_base_token_and_is_native(address caterc20, bytes32 tokenSalt, bool isNative) external {
        address baseToken;
        if (tokenSalt != bytes32(0)) {
            MockERC20 ERC20 = new MockERC20{salt: tokenSalt}("hello", "hello", 0);
            baseToken = address(ERC20);
        }

        if (isNative && baseToken == address(0)) {
            // Works
        } else if (!isNative && baseToken != address(0)) {
            // Works
        } else {
            vm.expectRevert(abi.encodeWithSignature("IXERC20Factory_BadTokenAddress()"));
        }
        CATERC20FACTORY.deployLockbox(caterc20, baseToken, isNative);
    }

    //--- Deploy CatERC20 & Lockbox ---//

    function test_deploy_token_and_lockbox(string calldata name, string calldata symbol, bytes32 tokenSalt) external {
        MockERC20 ERC20 = new MockERC20{salt: tokenSalt}("hello", "hello", 0);
        address baseToken = address(ERC20);

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

    function test_revert_compare_base_token_and_is_native(string calldata name, string calldata symbol, bytes32 tokenSalt, bool isNative) external {
        MockERC20 ERC20 = new MockERC20{salt: tokenSalt}("hello", "hello", 0);
        address baseToken = address(ERC20);

        uint256[] memory minterLimits = new uint256[](0);
        address[] memory bridges = new address[](0);

        if (isNative && baseToken == address(0)) {
            // Works
        } else if (!isNative && baseToken != address(0)) {
            // Works
        } else {
            vm.expectRevert(abi.encodeWithSignature("IXERC20Factory_BadTokenAddress()"));
        }
        CATERC20FACTORY.deployXERC20WithLockbox(name, symbol, minterLimits, bridges, baseToken, isNative);
    }
}
