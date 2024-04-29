// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { IXERC20Factory } from './interfaces/IXERC20Factory.sol';

import { CatERC20 } from './CatERC20.sol';
import { CatLockbox } from './CatLockbox.sol';

contract CatERC20Factory is IXERC20Factory {

  /**
   * @notice Deploys an CatERC20 contract using CREATE2
   * @dev limits and minters must be the same length
   * @param name The name of the token
   * @param symbol The symbol of the token
   * @param minterLimits The array of limits that you are adding (optional, can be an empty array)
   * @param bridges The array of bridges that you are adding (optional, can be an empty array)
   * @return caterc20 The address of the xerc20
   */
  function deployXERC20(
    string calldata name,
    string calldata symbol,
    uint256[] calldata minterLimits,
    uint256[] calldata /* _burnerLimits */,
    address[] calldata bridges
  ) external returns (address caterc20) {
    caterc20 = _deployXERC20(name, symbol, minterLimits, bridges);
    CatERC20(caterc20).transferOwnership(msg.sender);

    emit XERC20Deployed(caterc20);
  }

  /**
   * @notice Deploys an XERC20Lockbox contract using CREATE3
   *
   * @dev When deploying a lockbox for the gas token of the chain, then, the base token needs to be address(0)
   * @param caterc20 The address of the caterc20 that you want to deploy a lockbox for
   * @param baseToken The address of the base token that you want to lock
   * @param isNative Whether or not the base token is the native (gas) token of the chain. Eg: MATIC for polygon chain
   * @return lockbox The address of the lockbox
   */
  function deployLockbox(
    address caterc20,
    address baseToken,
    bool isNative
  ) external returns (address payable lockbox) {
    if ((baseToken == address(0) && !isNative) || (isNative && baseToken != address(0))) {
      revert IXERC20Factory_BadTokenAddress();
    }

    lockbox = _deployLockbox(caterc20, baseToken, isNative);

    emit LockboxDeployed(lockbox);
  }

  function deployXERC20WithLockbox(
    string calldata name,
    string calldata symbol,
    uint256[] calldata minterLimits,
    address[] calldata bridges,
    address baseToken,
    bool isNative
  ) external returns (address caterc20, address payable lockbox) {
    if ((baseToken == address(0) && !isNative) || (isNative && baseToken != address(0))) {
      revert IXERC20Factory_BadTokenAddress();
    }
    caterc20 = _deployXERC20(name, symbol, minterLimits, bridges);

    emit XERC20Deployed(caterc20);

    lockbox = _deployLockbox(caterc20, baseToken, isNative);

    CatERC20(caterc20).setLockbox(lockbox);

    emit LockboxDeployed(lockbox);

    CatERC20(caterc20).transferOwnership(msg.sender);
  }

  /**
   * @notice Deploys an XERC20 contract using CREATE3
   * @dev _limits and _minters must be the same length
   * @param name The name of the token
   * @param symbol The symbol of the token
   * @param minterLimits The array of limits that you are adding (optional, can be an empty array)
   * @param bridges The array of burners that you are adding (optional, can be an empty array)
   * @return caterc20 The address of the xerc20
   */
  function _deployXERC20(
    string calldata name,
    string calldata symbol,
    uint256[] calldata minterLimits,
    address[] calldata bridges
  ) internal returns (address caterc20) {
    uint256 _bridgesLength = bridges.length;
    if (minterLimits.length != _bridgesLength) {
      revert IXERC20Factory_InvalidLength();
    }
    bytes32 salt = keccak256(abi.encodePacked(name, symbol, msg.sender));

    caterc20 = address(new CatERC20{salt: salt}(name, symbol));

    for (uint256 i; i < _bridgesLength; ++i) {
      CatERC20(caterc20).setLimits(bridges[i], minterLimits[i], 0);
    }
  }

  /**
   * @notice Deploys an XERC20Lockbox contract using CREATE3
   *
   * @dev When deploying a lockbox for the gas token of the chain, then, the base token needs to be address(0)
   * Does not set the lockbox on the CatERC20 token, only deploying the 
   * lockbox itself.
   * msg.sender is not included in the lockbox salt. This is not needed
   * since a lockbox is a non-ownable contract and is pure logic.
   * @param caterc20 The address of the caterc20 that you want to deploy a lockbox for
   * @param baseToken The address of the base token that you want to lock
   * @param isNative Whether or not the base token is the native (gas) token of the chain. Eg: MATIC for polygon chain
   * @return lockbox The address of the lockbox
   */
  function _deployLockbox(
    address caterc20,
    address baseToken,
    bool isNative
  ) internal returns (address payable lockbox) {
    bytes32 salt = keccak256(abi.encodePacked(caterc20, baseToken, isNative)); // We technically don't have to include isNative in the salt since the baseToken does that. But for simplicity we do it anyway.

    lockbox = payable(new CatLockbox{salt: salt}(caterc20, baseToken, isNative));

    return lockbox;
  }
}