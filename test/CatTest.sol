// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import { catERC20 } from "../src/catERC20.sol";

contract CatTest is Test {
    catERC20 public catToken;

    string constant NAME = "hello";
    string constant SYMBOL = "hello";

    function setUp() public {
        catToken = new catERC20("hello", "hello");
    }
}
