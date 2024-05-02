// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

import {LibString} from "./LibString.sol";

import { CatERC20 } from "src/CatERC20.sol";
import { CatERC20Factory } from "src/CatERC20Factory.sol";

contract MineSalt is Script {
    using LibString for bytes;

    function setUp() public {}

    function mineSalt(bytes32 initCodeHash, string memory startsWith)
        public
        returns (bytes32 salt, address expectedAddress)
    {
        string[] memory args = new string[](6);
        args[0] = "cast";
        args[1] = "create2";
        args[2] = "--starts-with";
        args[3] = startsWith;
        args[4] = "--init-code-hash";
        args[5] = LibString.toHexStringNoPrefix(uint256(initCodeHash), 32);
        string memory result = string(vm.ffi(args));

        uint256 addressIndex = LibString.indexOf(result, "Address: ");
        string memory addressStr = LibString.slice(result, addressIndex + 9, addressIndex + 9 + 42);
        expectedAddress = vm.parseAddress(addressStr);

        uint256 saltIndex = LibString.indexOf(result, "Salt: ");
        string memory saltStr = LibString.slice(result, saltIndex + 6, saltIndex + 6 + 64 + 2);
        salt = bytes32(vm.parseBytes32(saltStr));
    }

    function mineSalt(bytes32 initCodeHash, string memory startsWith, address factoryAddress, address owner)
        public
        returns (bytes32 salt, address expectedAddress)
    {
        string[] memory args = new string[](10);
        args[0] = "cast";
        args[1] = "create2";
        args[2] = "--starts-with";
        args[3] = startsWith;
        args[4] = "--init-code-hash";
        args[5] = LibString.toHexStringNoPrefix(uint256(initCodeHash), 32);
        args[6] = "--caller";
        args[7] = LibString.toHexStringChecksummed(owner);
        args[8] = "--deployer";
        args[9] = LibString.toHexStringChecksummed(factoryAddress);
        string memory result = string(vm.ffi(args));

        uint256 addressIndex = LibString.indexOf(result, "Address: ");
        string memory addressStr = LibString.slice(result, addressIndex + 9, addressIndex + 9 + 42);
        expectedAddress = vm.parseAddress(addressStr);

        uint256 saltIndex = LibString.indexOf(result, "Salt: ");
        string memory saltStr = LibString.slice(result, saltIndex + 6, saltIndex + 6 + 64 + 2);
        salt = bytes32(vm.parseBytes32(saltStr));
    }

    function factory(string memory prefix) public {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(CatERC20Factory).creationCode));
        console2.logBytes32(initCodeHash);
        (bytes32 salt, ) = mineSalt(initCodeHash, prefix);

        // DEPLOY
        vm.startBroadcast();
        address actualAddress = address(new CatERC20Factory{salt: bytes32(salt)}());
        vm.stopBroadcast();

        // assertEq(actualAddress, expectedAddress);
        console2.log(actualAddress);
        console.logBytes32(salt);
    }

    function tokenAddress(string memory prefix, address factoryAddress, string memory name, string memory symbol, address owner) public {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(CatERC20).creationCode, abi.encode(name, symbol, factoryAddress)));
        console2.logBytes32(initCodeHash);
        (bytes32 salt, address expectedAddress) = mineSalt(initCodeHash, prefix, factoryAddress, owner);

        console2.log(expectedAddress);
        console.logBytes32(salt);
    }
}