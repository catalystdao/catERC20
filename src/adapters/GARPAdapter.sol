// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

// GARP
import { ICrossChainReceiver } from "GeneralisedIncentives/src/interfaces/ICrossChainReceiver.sol";
import { IIncentivizedMessageEscrow } from "GeneralisedIncentives/src/interfaces/IIncentivizedMessageEscrow.sol";
import { IMessageEscrowStructs } from "GeneralisedIncentives/src/interfaces/IMessageEscrowStructs.sol";

// xERC20
import { IXERC20 } from "../interfaces/IXERC20.sol";

// Solady
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// TODO: be an ERC20 token such that we can fallback to minting our own dummy that can be converted at a later date.
contract GARPAdapter is ICrossChainReceiver, IMessageEscrowStructs {
  error EscrowAlreadyExists();
  error NoEscrowExists();

  IIncentivizedMessageEscrow immutable public GARP;

  mapping(bytes32 tokenEscrowHash => bool) _tokenEscrow;

  constructor(address garp) {
    // Set the escrow.
    GARP = IIncentivizedMessageEscrow(garp);
  }

  /** @notice Called if the sender isn't the set GARP */
  error NotApprovedGARP();

  /** @dev Only lets the configured GARP call the function */
  modifier onlyGARP() {
    if (msg.sender != address(GARP)) revert NotApprovedGARP();
    _;
  }

  //--- Generalised Incentives (GARP) ---//

  function receiveAck(bytes32 destinationIdentifier, bytes32 messageIdentifier, bytes calldata acknowledgement) onlyGARP external {
    // Check if escrow was specified.
    // TODO: implement
  }

  // Remember to add your onlyEscrow modifier.
  function receiveMessage(bytes32 sourceIdentifierbytes, bytes32 messageIdentifier, bytes calldata fromApplication, bytes calldata message) onlyGARP() external returns(bytes memory acknowledgement) {
    // Success flow:
    // 1. Try to mint tokens.
    // Failure:
    // - Any bool: Revert back to source chain.
    // 2. Execude specified additional logic.
    // Failure:
    // - 0x01: Don't revert back to source, mint tokens to destination.
    // - 0x02: revert back to source

    // On failure:
    // 0x01 is set:  
    // 1. Try to mint tokens.
    // 2. If mint fails, check if they escrowed.

    // decode packet.
    address token;
    address to;
    uint256 amount;
    bytes1 escrowFlags;

    // Try to mint tokens.
    bool mintSuccess = _mint( token, to, amount);
    if (!mintSuccess && uint8(escrowFlags) != 0) {
      // TODO: revert back.
      return bytes.concat(hex"");
    }

    // Execute the remote logic.
    // We assume that the caller trusts


    // Do some processing and then return back your ack.
    // Notice that we are sending back 00 before our message.
    // That is because if the message fails for some reason,
    // an error code is prepended to the message.
    // By always sending back hex"00", we ensure that the first byte is unused.
    // Alternativly, use this byte as our own failure code.
    return bytes.concat(
      hex"00",
      keccak256(message)
    );
  }

  function _mint(address token, address to, uint256 amount) internal returns(bool success) {
    try IXERC20(token).mint(to, amount) {
      return true;
    } catch (bytes memory /* err */) {
      return false;
    }
  }

  /**
   * @notice Send tokens to a destination chain
   * @param escrowFlags Flags for how to handle the escrow:
   * - If 00000001 is set (& 0x01), then release escrow on source IF couldn't mint on destination
   * - If 00000010 is set (& 0x02), then release escrow on source IF logic couldn't execute on destiantion
   * TODO: params and args.
   */
  function burn(
    address token,
    uint256 amount,
    bytes1 escrowFlags,
    address refundTo,
    bytes calldata calldata_,
    bytes32 destinationIdentifier,
    bytes calldata destinationAddress, // TODO: set based on auth and destinationIdentifier
    IncentiveDescription calldata incentive,
    uint64 deadline
  ) external payable returns(uint256 gasRefund, bytes32 messageIdentifier) {
    // Check if the user specified to escrow or to burn (and then mint on destination).
    // We will always collect all tokens from the user, even if they specified no escrow.
    SafeTransferLib.safeTransferFrom(token, msg.sender, address(this), amount);
    // That is because we can't gurantee that the tx on the dest. side will execute.
    // As a result, we will have to escrow it regardless.
    // TODO: set escrow.
    _writeEscrow(token, amount, refundTo);

    // Create the message. // TODO: message format
    bytes memory message = bytes.concat(
      bytes20(uint160(token)), // TODO: better encode
      bytes32(amount),
      escrowFlags,
      calldata_
    );

    (gasRefund, messageIdentifier) = GARP.submitMessage(
      destinationIdentifier,
      destinationAddress,
      message,
      incentive,
      deadline
    );
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

  function _escrowHash(address token, uint256 amount, address refundTo, uint40 blockNumber) internal pure returns(bytes32) {
    return keccak256(bytes.concat(
      bytes20(uint160(token)),
      bytes32(amount), 
      bytes20(uint160(refundTo)),
      bytes5(uint40(blockNumber))
    ));
  }

  function _writeEscrow(address token, uint256 amount, address refundTo) internal returns(bytes32 ourContext) {
    uint40 blockNumber = uint40(block.number);
    bytes32 escrowHash = _escrowHash(token, amount, refundTo, blockNumber);
    // Check that there is no existing escrow here.
    if (_tokenEscrow[escrowHash]) revert EscrowAlreadyExists();
    _tokenEscrow[escrowHash] = true;

    // Our context is 32 bytes where the first 20 is the address and the last 5 is the block number.
    return _encodeOurContext(refundTo, blockNumber);
  }

  function _deleteEscrow(address token, uint256 amount, bytes32 ourContext) internal {
    (address refundTo, uint40 blockNumber) = _decodeOurContext(ourContext);
    bytes32 escrowHash = _escrowHash(token, amount, refundTo, blockNumber);
    if (!_tokenEscrow[escrowHash]) revert NoEscrowExists();
    _tokenEscrow[escrowHash] = false;
  }

  function _releaseEscrow(address token, uint256 amount, bytes32 ourContext) internal {
    (address refundTo, uint40 blockNumber) = _decodeOurContext(ourContext);
    bytes32 escrowHash = _escrowHash(token, amount, refundTo, blockNumber);
    if (!_tokenEscrow[escrowHash]) revert NoEscrowExists();
    _tokenEscrow[escrowHash] = false;

    // Refund the user.
    SafeTransferLib.safeTransfer(token, refundTo, amount);
  }
}