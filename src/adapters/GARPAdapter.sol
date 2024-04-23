// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// GARP
import { ICrossChainReceiver } from "GeneralisedIncentives/src/interfaces/ICrossChainReceiver.sol";
import { IIncentivizedMessageEscrow } from "GeneralisedIncentives/src/interfaces/IIncentivizedMessageEscrow.sol";
import { IMessageEscrowStructs } from "GeneralisedIncentives/src/interfaces/IMessageEscrowStructs.sol";
import { Bytes65 } from "GeneralisedIncentives/src/utils/Bytes65.sol";
import { ICatalystReceiver } from "../interfaces/IOnCatalyst.sol";

// xERC20
import { IXERC20 } from "../interfaces/IXERC20.sol";
import { MiniToken } from "./MiniToken.sol";

// Solady
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// Payload Description
import "./GARPAdapterPayload.sol";

// TODO: Figure out if want to always use escrows because the fallback token significantly complicates this.
/**
 * @notice XERC20 Adapter targeting Generalised Incentives.
 * This allows any XERC20 to use Generalised Incentives as a wrapper around any Bridge that Generalised Incentives support.
 * There are a few important differentiators between Generalised Incentives and other bridge adapters.
 *
 * 1. When bridging, it can be configured if the bridge should be escrowed. // TODO: Enable XERC20s to set if escrows should be enabled.
 * The XERC20 tokens are not burned until after the ack is called on the source chain. As a result, the totalSupply
 * may be higher across all XERC20 while the burn is pending.
 * If escrows are disabled, the user will receive a placeholder token if the mint limit is exceeded.
 // TODO: We may consider disabling the below logic.
 * 2. The first time a mint on the destination chain fails and it isn't escrowed, may deploy a ERC20 contract. The first time and every time afterwards
 * tokens will be minted if the mint fails on the destination chain.
 * The token can be retried afterwards or sent back.
 * be redeemed. If that fails (say out of gas), then it will fail back to the source chain where another attemot at dep
 */
contract GARPAdapter is ICrossChainReceiver, IMessageEscrowStructs, Bytes65 {
  error EscrowAlreadyExists();
  error NoEscrowExists();

  IIncentivizedMessageEscrow immutable public GARP;

  mapping(bytes32 tokenEscrowHash => bool) _tokenEscrow;
  
  mapping(address => address) _tempTokenForXERC20;

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

  /** @notice Called the route that is tried has no allowance. */
  error NotAllowedRemote();

  /**
   * @notice Determines if a remote XERC20 is allowed to mint a local XERC20
   * @dev By default only allowed if they are equal, but can be overridden with permissions
   * It should revert on invald route
   */
  function _allowedRemote(bytes32 /* remoteChainIdentifier */, bytes32 remoteXERC20, bytes32 localXERC20) internal virtual {
    if (remoteXERC20 != localXERC20) revert NotAllowedRemote();
  }

  //--- Set Connections 

  //--- Generalised Incentives (GARP) ---//

  function receiveAck(bytes32 /* destinationIdentifier */, bytes32 /* messageIdentifier */, bytes calldata acknowledgement) onlyGARP external {
    // Check if escrow was specified.
    bytes1 status = acknowledgement[0];

    // decode packet.
    bytes1 escrowFlag = bytes1(acknowledgement[ESCROW_FLAGS]);
    address token = address(uint160(uint256(bytes32(acknowledgement[SOURCE_TOKEN_IDENTIFIER_START + 1 : SOURCE_TOKEN_IDENTIFIER_END + 1]))));
    uint256 amount = uint256(bytes32(acknowledgement[AMOUNT_START + 1 : AMOUNT_END + 1]));
    bytes32 escrowContext = bytes32(acknowledgement[ESCROW_SCRATCHPAD_START + 1 : ESCROW_SCRATCHPAD_END + 1]);
    
    // Check if an escrow was set
    if (uint8(escrowFlag) > 0) {
      // Check if the call was successful
      if (status == 0x00) {
        _deleteEscrow(token, amount, escrowContext);
      } else {
        // status > 0x00, swap failed.
        _releaseEscrow(token, amount, escrowContext);
      }
    } else {
      // Check if call failed.
      if (status != 0x00) {
        // We need to try to re-mint token or mint temp token. Get or create our temp token.
        address tempToken = _getOrCreateTempToken(token);

        (address refundTo, ) = _decodeEscrowContext(escrowContext);
        // Mint tokens:
        MiniToken(tempToken).mint(refundTo, amount);
      }
    }

    // TODO: Emit event.
  }

  /**
   * @notice Called when we receive messages from GARP 
   * 
   * Success flow:
   * 1. Try to mint tokens.
   * Failure:
   * - Any bool: Revert back to source chain.
   * 2. Execude specified additional logic.
   * Failure:
   * - 0x01: Don't revert back to source, mint tokens to destination.
   * - 0x02: revert back to source
   * 
   * On failure:
   * 0x01 is set:  
   * 1. Try to mint tokens.
   * 2. If mint fails, check if they escrowed.
   *
   * @dev Only callable by GARP.
   * If you are not familiar with GARP, when we revert GARP sends our
   * message back along with a failure code. As a result, it is safe to revert.
   * @param sourceChainIdentifier The source chain. Identifier is specific to the AMB used.
   * @param fromApplication The source application that sent us this message. The encoding is specific to the AMB used.
   * @param message The message sent to us by fromApplication.
   * 
   */
  function receiveMessage(
    bytes32 sourceChainIdentifier, 
    bytes32 /* messageIdentifier */, 
    bytes calldata fromApplication,
    bytes calldata message
  ) external onlyGARP returns(bytes memory acknowledgement) {
    // TODO: verify adapter through fromApplication

    // Decode tokens and check if the source token is allowed to mint the destination token.
    bytes32 sourceToken = bytes32(message[SOURCE_TOKEN_IDENTIFIER_START : SOURCE_TOKEN_IDENTIFIER_END]);
    bytes32 destinationToken = bytes32(message[DESTINATION_TOKEN_IDENTIFIER_START : DESTINATION_TOKEN_IDENTIFIER_END]);
    _allowedRemote(sourceChainIdentifier, sourceToken, destinationToken);

    bytes1 escrowFlags = message[ESCROW_FLAGS];
    uint256 amount = uint256(bytes32(message[AMOUNT_START : AMOUNT_END]));
    address toAccount = address(bytes20(message[TO_ACCOUNT_START_EVM : TO_ACCOUNT_END]));
    address toToken = address(uint160(uint256(destinationToken)));

    // Try to mint tokens.
    bool mintSuccess;
    try IXERC20(toToken).mint(toAccount, amount) {
      mintSuccess = true;
    } catch (bytes memory /* err */) {
      mintSuccess = false;
    }

    if (!mintSuccess) {
      if (uint8(escrowFlags) != 0) {
        // TODO: hardrevert back
        require(false, "TODO: Set revert statement");
      } else {
        // Get or create our temp token.
        address tempToken = _getOrCreateTempToken(toToken);
        // Mint tokens:
        MiniToken(tempToken).mint(toAccount, amount);
      }
    }

    uint16 calldata_length = uint16(bytes2(message[DATA_LENGTH_START : DATA_LENGTH_END]));
    // Execute the remote logic.
    if (calldata_length != 0) {
      // bytes calldata additionalLogicData = message[DATA_START:];
      address dataTarget = address(bytes20(message[DATA_START + 0: DATA_START + 20]));
      bytes calldata dataArguments = message[DATA_START + 20: ];
      // We assume that the caller trusts the application they are calling. As a result, we 
      // don't protect this outwards call. If this function isn't properly implemented or
      // then the logic will fallback to Generalised Incentives failure => error code + full message ack.
      try ICatalystReceiver(dataTarget).onCatalystCall(amount, dataArguments, false) {

      } catch (bytes memory /* err */) {
        // Check if the revert logic flag has been set.
        if (uint8(escrowFlags & 0x02) != 0) {
          // TODO: hardrevert back
          require(false, "TODO: Set revert statement");
        }
      }
    }

    // Set the acknowledgement for return.
    acknowledgement = bytes.concat(
      bytes1(0x00),
      message
    );

    // TODO: emit event.
  }
  
  /**
   * @notice Send tokens to a destination chain
   * @param escrowFlags Flags for how to handle the escrow:
   * - If 00000001 is set (& 0x01), then release escrow on source IF couldn't mint on destination
   * - If 00000010 is set (& 0x02), then release escrow on source IF logic couldn't execute on destiantion
   * TODO: params and args.
   */
  function burn(
    address sourceToken,
    bytes32 destinationToken,
    uint256 amount,
    bytes1 escrowFlags,
    address refundTo,
    bytes calldata toAccount,
    bytes calldata calldata_,
    bytes32 destinationIdentifier,
    bytes calldata destinationAddress, // TODO: set based on auth and destinationIdentifier
    IncentiveDescription calldata incentive,
    uint64 deadline
  ) external payable checkBytes65Address(toAccount) returns(uint256 gasRefund, bytes32 messageIdentifier) {
    // TODO: Disallow escrows
    // Collect tokens from user and write escrow.
    // Token collection is done together with the escrow, to ensure escrow actions are complete.
    bytes32 escrowContext = _writeEscrow(sourceToken, amount, refundTo);
    // _writeEscrow makes an external call. There should be no storage modifications beyond this call.

    // Create the message.
    bytes memory message = bytes.concat(
      escrowFlags,
      bytes32(amount),
      bytes32(uint256(uint160(sourceToken))),
      destinationToken,
      toAccount,
      escrowContext,
      bytes32(0),
      bytes2(uint16(calldata_.length)),
      calldata_
    );

    (gasRefund, messageIdentifier) = GARP.submitMessage(
      destinationIdentifier,
      destinationAddress,
      message,
      incentive,
      deadline
    );

    // TODO: emit event.
  }

  //--- Temp Token Helpers ---//

  function tempTokenForXERC20(address xerc20) external view returns(address tkn) {
    return _tempTokenForXERC20[xerc20];
  }

  function _getOrCreateTempToken(address xerc20) internal returns(address tempToken) {
    tempToken = _tempTokenForXERC20[xerc20];
    if (tempToken == address(0)) {
      // TODO: get temp token name and symbol
      string memory tempTokenName = "";
      string memory tempTokenSymbol = "";
      tempToken = address(new MiniToken{salt: bytes32(bytes20(xerc20))}(tempTokenName, tempTokenSymbol));
    }
  }

  //--- Escrow Helpers ---//

  function _encodeEscrowContext(address refundTo, uint40 blockNumber) internal pure returns(bytes32) {
    return bytes32(
      uint256(
        bytes32(bytes20(refundTo)) // Place the address in the leftmost 20 bytes.
      ) +
      uint256(
        blockNumber // This places the blockNumber (uint40 => 5 bytes) in the rightmost 5 bytes.
      )
    );
  }

  function _decodeEscrowContext(bytes32 escrowContext) internal pure returns(address refundTo, uint40 blockNumber) {
    refundTo = address(bytes20(escrowContext)); // select the address from the leftmost 20 bytes.
    blockNumber = uint40(uint256(blockNumber)); // select the blockNumber from the rightmost 5 bytes. 
  }

  /**
   * @notice Computes an escrow hash. Importantly, this hash ensures that fradulent AMBs can only
   * touch escrows with correct context: Escrows with wrong amounts and/or refundTo cannot be released.
   * 
   */
  function _escrowHash(address token, uint256 amount, address refundTo, uint40 blockNumber) internal pure returns(bytes32) {
    return keccak256(bytes.concat(
      bytes20(uint160(token)),
      bytes32(amount), 
      bytes20(uint160(refundTo)),
      bytes5(uint40(blockNumber))
    ));
  }

  /**
   * @notice Write escrow and collect tokens for the escrow.
   * @dev This function is complete: It writes an escrow for the exact amount that is collected. 
   */
  function _writeEscrow(address token, uint256 amount, address refundTo) internal returns(bytes32 escrowContext) {
    uint40 blockNumber = uint40(block.number);
    bytes32 escrowHash = _escrowHash(token, amount, refundTo, blockNumber);
    // Check that there is no existing escrow here.
    if (_tokenEscrow[escrowHash]) revert EscrowAlreadyExists();
    _tokenEscrow[escrowHash] = true;

    // Collect tokens for escrow.
    SafeTransferLib.safeTransferFrom(token, msg.sender, address(this), amount);

    // Our context is 32 bytes where the first 20 is the address and the last 5 is the block number.
    return _encodeEscrowContext(refundTo, blockNumber);
  }

  /**
   * @notice Delete an escrow and burn the relevant tokens for the escrow.
   * @dev For any random xERC20 token, this call may fail because of the burn limit
   * However, this is not an issue since GARP allow replaying acks.
   */
  function _deleteEscrow(address token, uint256 amount, bytes32 escrowContext) internal {
    (address refundTo, uint40 blockNumber) = _decodeEscrowContext(escrowContext);
    bytes32 escrowHash = _escrowHash(token, amount, refundTo, blockNumber);
    if (!_tokenEscrow[escrowHash]) revert NoEscrowExists();
    _tokenEscrow[escrowHash] = false;

    // Burn the escrowedTokens
    IXERC20(token).burn(address(this), amount);
  }

  /**
   * @notice Delete an escrow and refunds the relevant tokens for the escrow.
   * @dev If an ERC20 is a block-list ERC20, the refund may fail if refundTo
   * got blacklisted. As a result the call may fail.
   * However, GARP allows replaying acks so if the user's address is ever un-blocked
   * they can replay the ack to release their tokens.
   */
  function _releaseEscrow(address token, uint256 amount, bytes32 escrowContext) internal {
    (address refundTo, uint40 blockNumber) = _decodeEscrowContext(escrowContext);
    bytes32 escrowHash = _escrowHash(token, amount, refundTo, blockNumber);
    if (!_tokenEscrow[escrowHash]) revert NoEscrowExists();
    _tokenEscrow[escrowHash] = false;

    // Refund the user.
    SafeTransferLib.safeTransfer(token, refundTo, amount);
  }
}