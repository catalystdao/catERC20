// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import { CatERC20 } from "../../../src/CatERC20.sol";

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
}

contract CatERC20UnitTest is Test {

    uint256 DURATION = 1 days;

    CatERC20getCurrentLimit GCL;

    function setUp() external {
        GCL = new CatERC20getCurrentLimit("", "");
    }

    function test_limit_simple_add(uint104 maxLimit, uint104 percentageOfMaxLimit, uint40 lastTouched) view external {
        vm.assume(maxLimit != type(uint104).max);
        uint256 currentLimit = 0;
        uint256 currentTime = lastTouched;
        int256 deltaLimit = int256(uint256(
            uint256(maxLimit) * uint256(percentageOfMaxLimit) / type(uint104).max
        ));

        uint256 newLimit = GCL.getCurrentLimit(
            uint256(maxLimit),
            currentLimit,
            uint256(lastTouched),
            currentTime,
            deltaLimit
        );

        assertEq(newLimit, uint256(deltaLimit), "Addition");
    }

    function test_unlimited_limit(uint256 currentLimit, uint256 lastTouched, uint256 currentTime, int256 deltaLimit) view external {
        uint256 maxLimit = uint256(type(uint104).max);

        uint256 newLimit = GCL.getCurrentLimit(
            maxLimit,
            currentLimit,
            lastTouched,
            currentTime,
            deltaLimit
        );

        assertEq(newLimit, 0, "Addition");
    }

    function test_revert_more_than_limit(uint104 maxLimit, uint256 lastTouched) external {
        vm.assume(maxLimit < type(uint104).max - 1);

        vm.expectRevert(abi.encodeWithSignature("IXERC20_NotHighEnoughLimits()"));
        GCL.getCurrentLimit(
            uint256(maxLimit),
            0,
            lastTouched,
            lastTouched,
            int256(uint256(maxLimit) + 1)
        );
    }

    function test_delta_gt_duration(int104 deltaLimit, uint40 lastTouched, uint8 extraDiff, uint256 currentLimit) view external {
        uint256 maxLimit = uint256(type(uint104).max - 1);

        uint256 newLimit = GCL.getCurrentLimit(
            maxLimit,
            currentLimit,
            uint256(lastTouched),
            uint256(lastTouched) + uint256(DURATION) + uint256(extraDiff),
            int256(deltaLimit)
        );

        assertEq(
            newLimit, 
            deltaLimit > 0 ? uint256(int256(deltaLimit)) : 0,
            "Delta beyond expiry not correctly set."
        );
    }

    function test_limit_decay_delta0(uint104 maxLimit, uint104 currentLimit, uint40 lastTouched, uint40 extraTime) view external {
        vm.assume(maxLimit != type(uint104).max);
        int256 deltaLimit = 0;

        uint256 newLimit = GCL.getCurrentLimit(
            maxLimit,
            currentLimit,
            uint256(lastTouched),
            uint256(lastTouched) + uint256(extraTime),
            deltaLimit
        );

        uint256 decay = uint256(maxLimit) * uint256(extraTime) / DURATION;

        assertEq(
            newLimit, 
            extraTime >= DURATION ? 0 : (currentLimit > decay ? currentLimit - decay : 0),
            "decay not decaying."
        );
    }

    function test_limit_decay_delta_small(uint104 maxLimit, int96 deltaPercentage, uint96 currentLimitPercentage, uint40 lastTouched, uint40 extraTime) view external {
        vm.assume(maxLimit != type(uint104).max);
        int256 deltaLimit = int256(uint256(maxLimit))*int256(deltaPercentage) / int256(type(int104).max);
        uint256 currentLimit = uint256(maxLimit) * uint256(currentLimitPercentage)/ uint256(type(uint104).max);

        uint256 newLimit = GCL.getCurrentLimit(
            maxLimit,
            currentLimit,
            uint256(lastTouched),
            uint256(lastTouched) + uint256(extraTime),
            deltaLimit
        );

        uint256 decay = uint256(maxLimit) * uint256(extraTime) / DURATION;

        int256 newExpectedLimit = int256((extraTime > DURATION ? 0 : (currentLimit > decay ? currentLimit - decay : 0))) + deltaLimit;

        assertEq(
            int256(newLimit), 
            newExpectedLimit > 0 ? int256(newExpectedLimit) : int256(0),
            "delta limit not working with decay"
        );
    }
}
