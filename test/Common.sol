// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import { CatERC20 } from "../src/CatERC20.sol";

contract CatTest is Test {

    string constant NAME = "hello";
    string constant SYMBOL = "hello";


    CatERC20 CATERC20;

    function setUp() public {
        CATERC20 = new CatERC20(NAME, SYMBOL);
    }
}
