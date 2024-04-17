//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICatalystReceiver {
    /** 
     * @notice The call on a mint & burn if desired.
     * @dev Named "onCatalystCall" to improve compatibility with Catalyst & its usage of Generalised Incentives.
     */
    function onCatalystCall(uint256 purchasedTokens, bytes calldata data, bool underwritten) external;
}
