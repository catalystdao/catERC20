// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC20 } from "solady/tokens/ERC20.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract Cat is ERC20, Ownable {
    /// @dev Returns the name of the token.
    function name() public pure override returns (string memory) {
        return "Catalyst";
    }

    /// @dev Returns the symbol of the token.
    function symbol() public pure override returns (string memory) {
        return "CAT";
    }

    /** @notice Mint new tokens  */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /** @notice Burns your tokens. :)  */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
