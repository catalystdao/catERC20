// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";

import { CatERC20 } from "../../src/catERC20.sol";
import { CatLockbox } from "../../src/catLockbox.sol";

contract CatLockboxTest is Test {

    string constant NAME = "hello";
    string constant SYMBOL = "hello";

    MockERC20 ERC20;
    CatERC20 CATERC20;

    function setUp() external {
        ERC20 = new MockERC20(NAME, SYMBOL, 0);
        CATERC20 = new CatERC20(NAME, SYMBOL, address(this));
    }

    function _getERC20Lockbox(address xerc20, address erc20) internal returns(CatLockbox catbox) {
        catbox = new CatLockbox(xerc20, erc20, false);
        CATERC20.setLockbox(address(catbox));
    }

    function _getNativeLockbox(address xerc20) internal returns(CatLockbox catbox) {
        catbox = new CatLockbox(xerc20, address(0), true);
        CATERC20.setLockbox(address(catbox));
    }

    //--- ERC20 Lockbox Deposit ---//

    function test_deposit(uint248 amount, address caller) external {
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        ERC20.mint(caller, amount);
        vm.prank(caller);
        ERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("mint(address,uint256)", caller, amount));
        lockbox.deposit(amount);

        assertEq(ERC20.balanceOf(address(lockbox)), amount, "Lockbox didn't collect tokens");
    }

    function test_deposit_to(uint248 amount, address caller, address to) external {
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        ERC20.mint(caller, amount);
        vm.prank(caller);
        ERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("mint(address,uint256)", to, amount));
        lockbox.depositTo(to, amount);

        assertEq(ERC20.balanceOf(address(lockbox)), amount, "Lockbox didn't collect tokens");
    }

    function test_revert_deposit_no_approval(uint248 amount, address caller) external {
        vm.assume(caller != address(0));
        vm.assume(amount != 0);
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        ERC20.mint(caller, amount);
        
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));
        lockbox.deposit(amount);
    }

    function test_deposit_revert_no_balance(uint248 amount, address caller) external {
        vm.assume(caller != address(0));
        vm.assume(amount != 0);
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        vm.prank(caller);
        ERC20.approve(address(lockbox), amount);

        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));
        lockbox.deposit(amount);
    }

    function test_revert_deposit_native_in_erc20(uint248 amount, address caller) external {
        vm.assume(amount != 0);
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        vm.deal(caller, amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("NotNative()"));
        lockbox.depositNative{value: amount}();
    }

     function test_revert_deposit_to_native_in_erc20(uint248 amount, address caller, address to) external {
        vm.assume(amount != 0);
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        vm.deal(caller, amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("NotNative()"));
        lockbox.depositNativeTo{value: amount}(to);
    }

    //--- ERC20 Lockbox Withdraw ---//

    function test_withdraw(uint248 amount, address caller) external {
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        CATERC20.ownableMint(caller, amount);
        ERC20.mint(address(lockbox), amount);


        vm.prank(caller);
        CATERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("burn(address,uint256)", caller, amount));
        lockbox.withdraw(amount);

        assertEq(ERC20.balanceOf(address(caller)), amount, "Lockbox didn't send tokens");
        assertEq(CATERC20.balanceOf(address(caller)), 0, "Lockbox didn't burn tokens");
    }

    function test_withdraw_to(uint248 amount, address caller, address to) external {
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getERC20Lockbox(address(CATERC20), address(ERC20));

        CATERC20.ownableMint(caller, amount);
        ERC20.mint(address(lockbox), amount);

        vm.prank(caller);
        CATERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("burn(address,uint256)", caller, amount));
        lockbox.withdrawTo(to, amount);

        assertEq(ERC20.balanceOf(address(to)), amount, "Lockbox didn't send tokens");
        assertEq(CATERC20.balanceOf(address(caller)), 0, "Lockbox didn't burn tokens");
    }
    
    //--- Native Lockbox Deposit ---//

    function test_deposit_native(uint248 amount, address caller) external {
        vm.assume(amount != 0);
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));

        vm.deal(caller, amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("mint(address,uint256)", caller, amount));
        lockbox.depositNative{value: amount}();
    }

    function test_deposit_native_fallback(uint248 amount, address caller) external {
        vm.assume(amount != 0);
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));

        vm.deal(caller, amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("mint(address,uint256)", caller, amount));
        payable(lockbox).call{value: amount}("");
    }

    function test_deposit_native_to(uint248 amount, address caller, address to) external {
        vm.assume(amount != 0);
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));

        vm.deal(caller, amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("mint(address,uint256)", to, amount));
        lockbox.depositNativeTo{value: amount}(to);
    }

    function test_revert_deposit_erc20_in_native(uint248 amount, address caller) external {
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));

        ERC20.mint(caller, amount);
        vm.prank(caller);
        ERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("IsNative()"));
        lockbox.deposit(amount);
    }

    function test_revert_deposit_to_erc20_in_native(uint248 amount, address caller, address to) external {
        vm.assume(caller != address(0));
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));

        ERC20.mint(caller, amount);
        vm.prank(caller);
        ERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("IsNative()"));
        lockbox.depositTo(to, amount);
    }

    //--- Native Lockbox Withdraw ---//

    function test_withdraw_native(uint248 amount) external {
        vm.assume(amount != 0);
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));
        address caller = address(200);

        vm.deal(address(lockbox), amount);

        CATERC20.ownableMint(caller, amount);

        vm.prank(caller);
        CATERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("burn(address,uint256)", caller, amount));
        lockbox.withdraw(amount);
    }

    function test_withdraw_to_native(uint248 amount, address caller) external {
        vm.assume(amount != 0);
        vm.assume(caller != address(0));
        address to = address(200);
        CatLockbox lockbox = _getNativeLockbox(address(CATERC20));

        vm.deal(address(lockbox), amount);

        CATERC20.ownableMint(caller, amount);

        vm.prank(caller);
        CATERC20.approve(address(lockbox), amount);

        vm.prank(caller);
        vm.expectCall(address(CATERC20), abi.encodeWithSignature("burn(address,uint256)", caller, amount));
        lockbox.withdrawTo(to, amount);
    }
}
