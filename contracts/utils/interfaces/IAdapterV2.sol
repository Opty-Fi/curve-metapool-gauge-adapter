// SPDX-License-Identifier: MIT

pragma solidity >0.6.0 <=0.9.0;
pragma experimental ABIEncoderV2;

import { IAdapter } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapter.sol";

/**
 * @title Interface V2 for all the DeFi adapters
 * @author Opty.fi
 * @notice Interface with minimal functions to be inhertied in all DeFi adapters
 * @dev Abstraction layer to different DeFi protocols like AaveV1, Compound etc.
 * It is used as a layer for adding any new function which will be used in all DeFi adapters
 * Conventions used:
 *  - lpToken: liquidity pool token
 */

interface IAdapterV2 is IAdapter {
    /**
     * @notice returns list of reward tokens emitted by liquidity pool
     * @param _liquidityPool address of the liquidity pool contract
     * @return _rewardTokens array of reward token addresses
     */
    function getRewardTokens(address _liquidityPool) external view returns (address[] memory _rewardTokens);
}
