// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import { Cat } from "../src/Cat.sol";

contract CatTest is Test {
    Cat public catToken;

    function setUp() public {
        catToken = new Cat();
    }
}
