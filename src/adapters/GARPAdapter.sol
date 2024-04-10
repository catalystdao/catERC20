// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;


contract GARPAdapter {
  error EscrowAlreadyExists();
  error NoEscrowExists();

  mapping(bytes32 escrowHash => bool) _escrow;

  /**
   * @notice Burns tokens for a user
   * @dev Can only be called by a minter
   * @param user The address of the user who needs tokens burned
   * @param amount The amount of tokens being burned
   */
  function _mint(address user, uint256 amount) public {
  }

  /**
   * @notice Burns tokens for a user
   * @dev Can only be called by a minter
   * @param user The address of the user who needs tokens burned
   * @param amount The amount of tokens being burned
   */
  function _burn(address user, uint256 amount) public {
  }

  //--- Escrow Helpers ---//

  function _encodeOurContext(address refundTo, uint40 blockNumber) internal pure returns(bytes32) {
    return bytes32(
      uint256(
        bytes32(bytes20(refundTo)) // Place the address in the leftmost 20 bytes.
      ) +
      uint256(
        blockNumber // This places the blockNumber (uint40 => 5 bytes) in the rightmost 5 bytes.
      )
    );
  }

  function _decodeOurContext(bytes32 ourContext) internal pure returns(address refundTo, uint40 blockNumber) {
    refundTo = address(bytes20(ourContext)); // select the address from the leftmost 20 bytes.
    blockNumber = uint40(uint256(blockNumber)); // select the blockNumber from the rightmost 5 bytes. 
  }

  function _escrowHash(address bridge, uint256 amount, address refundTo, uint40 blockNumber) internal pure returns(bytes32) {
    return keccak256(bytes.concat(
      bytes20(uint160(bridge)),
      bytes32(amount), 
      bytes20(uint160(refundTo)),
      bytes5(uint40(blockNumber))
    ));
  }

  function _writeEscrow(address bridge, uint256 amount, address refundTo) internal returns(bytes32 ourContext) {
    uint40 blockNumber = uint40(block.number);
    bytes32 escrowHash = _escrowHash(bridge, amount, refundTo, blockNumber);
    // Check that there is no existing escrow here.
    if (_escrow[escrowHash]) revert EscrowAlreadyExists();
    _escrow[escrowHash] = true;

    // Our context is 32 bytes where the first 20 is the address and the last 5 is the block number.
    return _encodeOurContext(refundTo, blockNumber);
  }

  function _deleteEscrow(address bridge, uint256 amount, bytes32 ourContext) internal {
    (address refundTo, uint40 blockNumber) = _decodeOurContext(ourContext);
    bytes32 escrowHash = _escrowHash(bridge, amount, refundTo, blockNumber);
    if (!_escrow[escrowHash]) revert NoEscrowExists();
    _escrow[escrowHash] = false;
  }

  function _releaseEscrow(address bridge, uint256 amount, bytes32 ourContext) internal {
    (address refundTo, uint40 blockNumber) = _decodeOurContext(ourContext);
    bytes32 escrowHash = _escrowHash(bridge, amount, refundTo, blockNumber);
    if (!_escrow[escrowHash]) revert NoEscrowExists();
    _escrow[escrowHash] = false;

    // Refund to the user.
    _mint(refundTo, amount);
  }
}