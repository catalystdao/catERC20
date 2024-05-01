// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import { CatERC20, Bridge } from "../../../src/catERC20.sol";

contract CatERC20getCurrentLimit is CatERC20 {
    function test() external {}

    constructor(string memory name, string memory symbol) CatERC20(name, symbol) {}

    function getCurrentLimit(
        uint256 maxLimit,
        uint256 currentLimit,
        uint256 lastTouched,
        uint256 currentTime,
        int256 deltaLimit
    ) external pure returns(uint256 newLimit) {
        return _getCurrentLimit(maxLimit, currentLimit, lastTouched, currentTime, deltaLimit);
    }

    function setBridge(address bridge, Bridge calldata bridgeContext) external {
        bridges[bridge] = bridgeContext;
    }
}

contract CatERC20CurrentLimitOfTest is Test {

    uint256 DURATION = 1 days;

    CatERC20getCurrentLimit GCL;

    function setUp() external {
        GCL = new CatERC20getCurrentLimit("", "");
    }

    function test_compare_mintingCurrentLimitOf(address bridge, Bridge calldata bridgeContext) external {
        GCL.setBridge(bridge, bridgeContext);
        uint256 expectedLimit = GCL.getCurrentLimit(
            bridgeContext.maxLimit,
            bridgeContext.currentLimit,
            bridgeContext.lastTouched, 
            block.timestamp,
            0
        );
        uint256 viewedRead = GCL.mintingCurrentLimitOf(bridge);

        assertEq(expectedLimit, viewedRead, "Not expected comparision for mintingCurrentLimit");
    }

    function test_verify_burningCurrentLimitOf(address bridge) view external {
        uint256 viewedRead = GCL.burningCurrentLimitOf(bridge);

        assertEq(type(uint256).max, viewedRead, "Not expected comparision for burningCurrentLimitOf");
    }
}
