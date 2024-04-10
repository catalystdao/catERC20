// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, stdError} from "forge-std/Test.sol";
import { CatERC20, Bridge } from "../../src/CatERC20.sol";

contract CatERC20Test is Test {

    string constant NAME = "hello";
    string constant SYMBOL = "hello";

    CatERC20 CATERC20;

    function setUp() public {
        CATERC20 = new CatERC20(NAME, SYMBOL);
    }

    //--- Lockbox Interactions ---//

    function test_set_lockbox(address lockbox) external {
        vm.assume(lockbox != address(0));

        CATERC20.setLockbox(lockbox);

        // Checks:
        // 1. Check that the lockbox was set publicly:
        assertEq(CATERC20.lockbox(), lockbox, "Lockbox not set");

        // 2. Check that the limit has been set.
        (, uint104 maxLimit,) = CATERC20.bridges(lockbox);
        assertEq(maxLimit, type(uint104).max, "Lockbox limit not set");

        // 3. The deployer is the default owner
        assertEq(CATERC20.owner(), address(this), "Owner not correctly set");

    }

    function test_set_lockbox_events(address lockbox) external {
        vm.assume(lockbox != address(0));

        CATERC20.setLockbox(lockbox);
        // TODO: Events
    }

    function test_revert_set_lockbox_only_owner(address caller, address lockbox) external {
        vm.assume(lockbox != address(0));
        vm.assume(caller != address(this));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        CATERC20.setLockbox(lockbox);
    }

    function test_revert_set_lockbox_no_address_0() external {
        vm.expectRevert(abi.encodeWithSignature("Lockbox0()"));
        CATERC20.setLockbox(address(0));
    }

    function test_revert_set_lockbox_only_once(address lockbox) external {
        vm.assume(lockbox != address(0));

        CATERC20.setLockbox(lockbox);
        vm.expectRevert(abi.encodeWithSignature("LockboxAlreadySet()"));
        CATERC20.setLockbox(lockbox);
    }

    function test_lockbox_can_mint_unlimited(address lockbox, address to, uint248 amount) external {
        vm.assume(lockbox != address(0));
        vm.assume(to != address(0));

        CATERC20.setLockbox(lockbox);

        vm.prank(lockbox);
        CATERC20.mint(to, amount);

        assertEq(CATERC20.balanceOf(to), amount, "Incorrect amount minted");
    }

    function test_revert_lockbox_mint_limit(address lockbox, address to) external {
        vm.assume(lockbox != address(0));
        vm.assume(to != address(0));

        uint256 amount = uint256(type(int256).max) + 1;

        CATERC20.setLockbox(lockbox);

        vm.prank(lockbox);
        vm.expectRevert(abi.encodeWithSignature("AmountTooHigh()"));
        CATERC20.mint(to, amount);
    }

    //--- Bridge Limits ---//

    function test_set_limit(address bridge, uint104 mintingLimit, uint32 time) external {
        vm.warp(time);

        CATERC20.setLimits(bridge, mintingLimit, 0);
        
        (uint48 lastTouched, uint104 maxLimit, uint104 currentLimit) = CATERC20.bridges(bridge);

        // Check:
        // 1. Check lastTouched
        assertEq(lastTouched, time, "Time not correctly set");
        // 1. Check maxLimit
        assertEq(maxLimit, mintingLimit, "Time not correctly set");
        // 1. Check currentLimit
        assertEq(currentLimit, 0, "Time not correctly set");
    }

    function test_set_limit_event(address bridge, uint104 mintingLimit) external {
        CATERC20.setLimits(bridge, mintingLimit, 0);
        // todo: check event.
    }

    function test_revert_set_limit_high(address bridge) external {
        uint256 mintingLimit = uint256(type(uint104).max) + 1; 
        vm.expectRevert(abi.encodeWithSignature("IXERC20_LimitsTooHigh()"));
        CATERC20.setLimits(bridge, mintingLimit, 0);
    }

    function test_revert_set_limit_only_owner(address bridge, uint256 mintingLimit, address caller) external {
        vm.assume(caller != address(this));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        CATERC20.setLimits(bridge, mintingLimit, 0);
    }
}
