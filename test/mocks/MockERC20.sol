// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC20 } from "solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {

  string NAME;
  string SYMBOL;
  
  constructor(string memory name_, string memory symbol_, uint256 totalSupply) {
      NAME = name_;
      SYMBOL = symbol_;
      
      _mint(msg.sender, totalSupply);

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
}
