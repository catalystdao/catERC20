// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IXERC20 } from "./interfaces/IXERC20.sol";

import { ERC20 } from "solady/tokens/ERC20.sol";
import { Ownable } from "solady/auth/Ownable.sol";

/** @notice Optimised for storage, fits into a single slot: 6 + 13 + 13 = 32 */
struct Bridge {
    uint48 lastTouched;
    uint104 maxLimit;
    uint104 currentLimit;
}

/** 
 * @notice xERC20 token remix which improves security by using a combined mint & burn buffer.
 * This allows administrators to set a lower overall limit.
 * Inspired by https://github.com/defi-wonderland/xERC20
 * type(uint104).max is a magic number in this contract and implies unlimited mints.
 * @dev For optimisations purposes, the bridge limits can't be larger than uint104.
 */
contract CatERC20 is ERC20, Ownable, IXERC20 {

  /** @notice Allow unlimited mints. @dev This is the max size of the Bridge struct */
  uint256 constant UNLIMITED_MINTS = type(uint104).max;

  error AmountTooHigh();
  error LockboxAlreadySet();
  error Lockbox0();

  string NAME;
  string SYMBOL;

  /**
   * @notice The duration it takes for the limits to fully replenish
   */
  uint256 private constant DURATION = 1 days;

  /**
   * @notice The address of the lockbox contract
   */
  address public lockbox;

  /**
   * @notice Maps bridge address to bridge configurations
   */
  mapping(address bridgeAddress => Bridge bridgeContext) public bridges;

  constructor(string memory name_, string memory symbol_, address owner) {
      NAME = name_;
      SYMBOL = symbol_;
      _initializeOwner(owner);

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

  //--- Admin Set Functions ---//

  /**
   * @notice Sets the lockbox address
   * @dev Sets unlimited limits for the lockbox.
   * @param lockbox_ The address of the lockbox
   */
  function setLockbox(address lockbox_) public onlyOwner {
    if (lockbox_ == address(0)) revert Lockbox0();
    if (lockbox != address(0)) revert LockboxAlreadySet();
    lockbox = lockbox_;
    _changeLimit(lockbox_, UNLIMITED_MINTS);
    emit LockboxSet(lockbox_);
  }

  /**
   * @notice Updates the limits of any bridge
   * @dev Can only be called by the owner
   * type(uint104).max is a magic number, it is unlimited.
   * @param bridge The address of the bridge we are setting the limits too
   * @param mintingLimit The updated minting limit we are setting to the bridge
   */
  function setLimits(address bridge, uint256 mintingLimit, uint256 /* burningLimit */) public onlyOwner {
    if (bridge == lockbox) revert Lockbox0();
    // UNLIMITED_MINTS == type(uint104).max.
    if (mintingLimit > UNLIMITED_MINTS) revert IXERC20_LimitsTooHigh();
    _changeLimit(bridge, mintingLimit);
    emit BridgeLimitsSet(mintingLimit, type(uint256).max, bridge);
  }

  //--- Bridge functions ---//

  /**
   * @notice Mints tokens for a user
   * @dev Can only be called by a minter: Bridge, Lockbox, or owner.
   * @param user The address of the user who needs tokens minted
   * @param amount The amount of tokens being minted
   */
  function mint(address user, uint256 amount) public {
    if (amount > uint256(type(int256).max)) revert AmountTooHigh();

    _useBridgeLimits(msg.sender, int256(amount));
    _mint(user, amount);
  }

  /**
   * @notice Lets the owner mint tokens.
   * This function exists to make it easier for owners to mint tokens.
   * The XERC20 standard is a "mintable token", since the owner
   * can register themselves as a bridge and mint tokens that way.
   * @dev Can only be called by owner
   * @param user The address of the user who needs tokens minted
   * @param amount The amount of tokens being minted
   */
  function ownableMint(address user, uint256 amount) external onlyOwner {
    _mint(user, amount);
  }

  /**
   * @notice Burns tokens for a user
   * @dev Can only be called by a minter
   * @param user The address of the user who needs tokens burned
   * @param amount The amount of tokens being burned
   */
  function burn(address user, uint256 amount) public {
    // if amount > -type(int256).min then it would overflow. int256 contains 1 more negative integer:
    // -type(int256).min == type(int256).max - 1. The comparision amount > type(int256).max - 1 is
    //  equiv.: amount >= type(int256).max because amount is discrete.
    if (amount >= uint256(type(int256).max)) revert AmountTooHigh();
    if (user != msg.sender) _spendAllowance(user, msg.sender, amount);

    _useBridgeLimits(msg.sender, -int256(amount));
    _burn(user, amount);
  }

  //--- View Bridge Limits ---//

  /**
   * @notice Returns the max limit of a bridge
   *
   * @param bridge the bridge we are viewing the limits of
   * @return limit The limit the bridge has
   */
  function mintingMaxLimitOf(address bridge) public view returns (uint256 limit) {
    return limit = bridges[bridge].maxLimit;
  }

  /**
   * @notice Returns the max limit of a bridge
   *
   * @return limit The limit the bridge has
   */
  function burningMaxLimitOf(address /* bridge */) public pure returns (uint256 limit) {
    return limit = type(uint256).max;
  }

  /**
   * @notice Returns the current limit of a bridge
   *
   * @param bridge the bridge we are viewing the limits of
   * @return limit The limit the bridge has
   */
  function mintingCurrentLimitOf(address bridge) public view returns (uint256 limit) {
    Bridge storage bridgeContext = bridges[bridge];
    return limit = _calcNewCurrentLimit(
      bridgeContext.maxLimit,
      bridgeContext.currentLimit,
      bridgeContext.lastTouched,
      block.timestamp,
      0
    );
  }

  /**
   * @notice Returns the current limit of a bridge
   *
   * @return limit The limit the bridge has
   */
  function burningCurrentLimitOf(address /* bridge */) public pure returns (uint256 limit) {
    return limit = type(uint256).max;
  }

  //--- Change Bridge Limits ---//

  /**
   * @notice Uses the limit of any bridge
   * @param bridge The address of the bridge who is being changed
   * @param deltaLimit The change in the limit
   */
  function _useBridgeLimits(address bridge, int256 deltaLimit) internal {
    Bridge storage bridgeContext = bridges[bridge];

    uint256 currentTime = block.timestamp;

    uint256 newCurrentLimit = _calcNewCurrentLimit(
      bridgeContext.maxLimit,
      bridgeContext.currentLimit,
      bridgeContext.lastTouched,
      currentTime,
      deltaLimit
    );
    
    bridgeContext.lastTouched = uint40(currentTime);
    bridgeContext.currentLimit = uint104(newCurrentLimit);
  }

  /**
   * @notice Updates the limit of any bridge
   * @param bridge The address of the bridge we are setting the limit too
   * @param newMaxLimit The updated limit we are setting to the bridge
   */
  function _changeLimit(address bridge, uint256 newMaxLimit) internal {
    Bridge storage bridgeContext = bridges[bridge];

    uint256 currentTime = block.timestamp;

    uint256 newCurrentLimit = _calcNewCurrentLimit(
      bridgeContext.maxLimit, // Use the old limit to compute the delta correctly.
      bridgeContext.currentLimit,
      bridgeContext.lastTouched,
      currentTime,
      0
    );

    bridgeContext.lastTouched = uint40(currentTime);
    bridgeContext.maxLimit = uint104(newMaxLimit);
    bridgeContext.currentLimit = uint104(newCurrentLimit);
  }

  /**
   * @notice Calculates the new limit based on decay in time.
   * @dev Reverts if extraDifference cannot fit into the limit.
   * 
   * Function constraints:
   * maxLimit <= type(uint104).max.
   * currentLimit <= type(uint104).max but may be larger than currentLimit.
   * lastTouched <= reasonable timestamp <= type(uint48).max.
   * currentTime <= reasonable timestamp <= type(uint48).max.
   *  type(int256).min <= deltaLimit <= type(int256).max.
   * 
   * @param maxLimit The maximum for the bridge
   * @param currentLimit The current used of the limit
   * @param lastTouched When the last change to the limit was made
   * @param currentTime The current time. Please provide block.timestamp.
   * @param deltaLimit The delta that has to be applied to the limit.
   * @return newCurrentLimit The new current limit
   */
  function _calcNewCurrentLimit(
    uint256 maxLimit,
    uint256 currentLimit,
    uint256 lastTouched,
    uint256 currentTime,
    int256 deltaLimit
  ) internal pure returns (uint256 newCurrentLimit) {
    // Check if maxLimit is a magic number.
    if (maxLimit == UNLIMITED_MINTS) return 0;
    // Check that extraDifference < maxLimit.
    // int256(maxLimit) cannot overflow in casting since maxLimit < type(uint104).max < type(int256).max
    if (int256(maxLimit) < deltaLimit) revert IXERC20_NotHighEnoughLimits();

    uint256 deltaTime;
    unchecked {
      // Current time is always greater than the last time it was touched.
      deltaTime = currentTime - lastTouched;
    }

    // if deltaTime > DURATION: Then the new limit is deltaLimit since we know deltaLimit < maxLimit.
    if (deltaTime >= DURATION) return deltaLimit > 0 ? uint256(deltaLimit) : 0;
    
    // Lets compute the decay.
    uint256 decay = maxLimit * deltaTime / DURATION;
    
    newCurrentLimit = currentLimit > decay ? currentLimit - decay : 0;

    // If deltaLimit < 0, then we don't have to check if it matches the limit.
    // Likewise when deltaLimit = 0. 
    // The deltaLimit = 0 check is important when newCurrentLimit > maxLimit.
    unchecked {
      // Unchecked is important for uint256(-deltaLimit).
      // If deltaLimit = type(int256).min then -deltaLimit overflows since signed integers
      // are larger negative than positive by exactly 1.
      // type(int256).min == [100000...00000]. We change the sign by taking the compliment and adding 1: -type(int256).min === [0111111...11111] + 1 = type(int256).max + 1 = uint256(-type(int256).min)
      if (deltaLimit <= 0)
        return newCurrentLimit > uint256(-deltaLimit) ? newCurrentLimit - uint256(-deltaLimit) : 0;
    }

    unchecked {
      // deltaLimit is bounded by maxLimit. newCurrentLimit is bounded by type(uint104).max. Each of which is bounded by type(uint256).max / 2.
      if (maxLimit < uint256(deltaLimit) + newCurrentLimit) revert IXERC20_NotHighEnoughLimits();
      // Same bounded argument: newCurrentLimit + deltaLimit < type(104).max + maxLimit < type(104).max * 2.
      // We also know that deltaLimit > 0 so it can be casted to uint256.
      return newCurrentLimit + uint256(deltaLimit);
    }
  }
}
