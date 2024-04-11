// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { IXERC20 } from './interfaces/IXERC20.sol';
import { IXERC20Lockbox } from './interfaces/IXERC20Lockbox.sol';

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

contract CatLockbox is IXERC20Lockbox {

  error BadTokenAddress();
  error NotNative();
  error IsNative();
  error WithdrawFailed();

  /**
   * @notice The XERC20 token of this contract
   */
  IXERC20 public immutable XERC20;

  /**
   * @notice The ERC20 token of this contract
   */
  address public immutable ERC20;

  /**
   * @notice Whether the ERC20 token is the native gas token of this chain
   */
  bool public immutable IS_NATIVE;

  /**
   * @notice Constructor
   *
   * @param xerc20 The address of the CatERC20 contract
   * @param baseToken The address of the ERC20 contract
   * @param isNative Whether the ERC20 token is the native gas token of this chain or not
   */
  constructor(address xerc20, address baseToken, bool isNative) {
    if ((baseToken == address(0) && !isNative) || (isNative && baseToken != address(0))) {
      revert BadTokenAddress();
    }
    XERC20 = IXERC20(xerc20);
    ERC20 = baseToken;
    IS_NATIVE = isNative;
  }

  /**
   * @notice Deposit native tokens into the lockbox
   */

  function depositNative() public payable {
    if (!IS_NATIVE) revert NotNative();

    _deposit(msg.sender, msg.value);
  }

  /**
   * @notice Deposit ERC20 tokens into the lockbox
   *
   * @param amount The amount of tokens to deposit
   */
  function deposit(uint256 amount) external {
    if (IS_NATIVE) revert IsNative();

    _deposit(msg.sender, amount);
  }

  /**
   * @notice Deposit ERC20 tokens into the lockbox, and send the CatERC20 to a user
   *
   * @param to The user to send the CatERC20 to
   * @param amount The amount of tokens to deposit
   */

  function depositTo(address to, uint256 amount) external {
    if (IS_NATIVE) revert IsNative();

    _deposit(to, amount);
  }

  /**
   * @notice Deposit the native asset into the lockbox, and send the CatERC20 to a user
   *
   * @param to The user to send the CatERC20 to
   */
  function depositNativeTo(address to) public payable {
    if (!IS_NATIVE) revert NotNative();

    _deposit(to, msg.value);
  }

  /**
   * @notice Withdraw ERC20 tokens from the lockbox
   *
   * @param amount The amount of tokens to withdraw
   */

  function withdraw(uint256 amount) external {
    _withdraw(msg.sender, amount);
  }

  /**
   * @notice Withdraw tokens from the lockbox
   *
   * @param to The user to withdraw to
   * @param amount The amount of tokens to withdraw
   */

  function withdrawTo(address to, uint256 amount) external {
    _withdraw(to, amount);
  }

  /**
   * @notice Withdraw tokens from the lockbox
   *
   * @param to The user to withdraw to
   * @param amount The amount of tokens to withdraw
   */
  function _withdraw(address to, uint256 amount) internal {
    XERC20.burn(msg.sender, amount);

    if (IS_NATIVE) {
      SafeTransferLib.safeTransferETH(to, amount);
    } else {
      SafeTransferLib.safeTransfer(ERC20, to, amount);
    }
    emit Withdraw(to, amount);
  }

  /**
   * @notice Deposit tokens into the lockbox
   *
   * @param to The address to send the xerc20 to
   * @param amount The amount of tokens to deposit
   */
  function _deposit(address to, uint256 amount) internal {
    if (!IS_NATIVE) {
      SafeTransferLib.safeTransferFrom(ERC20, msg.sender, address(this), amount);
    }

    XERC20.mint(to, amount);
    emit Deposit(to, amount);
  }

  /**
   * @notice Fallback function to deposit native tokens
   */
  receive() external payable {
    depositNative();
  }
}