// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20 } from "solady/tokens/ERC20.sol";
import { Ownable } from "solady/auth/Ownable.sol";

/** 
 * @notice Very simple token which supports ownable minting and burning
 */
contract MiniToken is ERC20, Ownable {
  string NAME;
  string SYMBOL;

  constructor(string memory name_, string memory symbol_) {
      NAME = name_;
      SYMBOL = symbol_;
      _initializeOwner(msg.sender);

      CONSTANT_NAME_HASH = keccak256(bytes(name_));
  }

  bytes32 immutable CONSTANT_NAME_HASH;

  /// @dev For more performance, override to return the constant value
  /// of `keccak256(bytes(name()))` if `name()` will never change.
  function _constantNameHash() internal view override returns (bytes32 result) {
    return result = CONSTANT_NAME_HASH;
  }

  /// @dev Returns the name of the token.
  function name() public view override returns (string memory) {
      return NAME;
  }

  /// @dev Returns the symbol of the token.
  function symbol() public view override returns (string memory) {
      return SYMBOL;
  }

  /**
   * @notice Mints tokens for a user
   * @param user The address of the user who needs tokens minted
   * @param amount The amount of tokens being minted
   */
  function mint(address user, uint256 amount) external onlyOwner {
    _mint(user, amount);
  }

  /**
   * @notice Burns tokens for a user
   * @param user The address of the user who needs tokens burned
   * @param amount The amount of tokens being burned
   */
  function burn(address user, uint256 amount) external onlyOwner {
    _burn(user, amount);
  }
}
