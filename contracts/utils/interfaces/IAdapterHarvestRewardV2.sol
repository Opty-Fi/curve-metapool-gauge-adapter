// SPDX-License-Identifier: MIT

pragma solidity >0.6.0 <=0.9.0;
pragma experimental ABIEncoderV2;

import { IAdapterHarvestReward } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterHarvestReward.sol";

/**
 * @title Interface V2 for Reward tokens and Swapping tokens for the DeFi adapters
 * @author Opty.fi
 * @notice Interface of the DeFi protocol code adapter for reward tokens and swapping tokens functionality
 * @dev Abstraction layer to different DeFi protocols like Compound, Cream etc.
 * It is used as a layer for adding any new function related to reward token feature to be used in DeFi-adapters.
 * It is also used as a middleware for adding functionality of swapping/harvesting of tokens used in DeFi-adapters.
 */
interface IAdapterHarvestRewardV2 is IAdapterHarvestReward {
    /**
     * @notice Returns the amount of accrued reward tokens
     * @param _vault Vault contract address
     * @param _liquidityPool Liquidity pool's contract address from where to claim reward tokens
     * @param _underlyingToken Underlying token's contract address for which to claim reward tokens
     * @param _rewardToken address of the reward token
     * @return _amount returns pending unclaimed reward token amount
     */
    function getUnclaimedRewardTokenAmount(
        address payable _vault,
        address _liquidityPool,
        address _underlyingToken,
        address _rewardToken
    ) external view returns (uint256 _amount);

    /**
     * @dev Get batch of function calls for swapping specified amount of rewards in vault to underlying tokens
     * via DEX like Uniswap
     * @param _vault Vault contract address
     * @param _underlyingToken Underlying token address for the given liquidity pool
     * @param _liquidityPool Liquidity pool's contract address where the vault's deposit is generating rewards
     * @param _rewardToken address of the reward token
     * @param _rewardTokenAmount Amount of reward token to be harvested to underlyingTokens via DEX
     * @return _codes Returns an array of bytes in sequence that can be executed by vault
     */
    function getHarvestSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        address _rewardToken,
        uint256 _rewardTokenAmount
    ) external view returns (bytes[] memory _codes);

    /**
     * @dev Get batch of function calls for swapping full balance of rewards in vault to underlying tokens
     * via DEX like Uniswap
     * @param _vault Vault contract address
     * @param _underlyingToken List of underlying token addresses for the given liquidity pool
     * @param _liquidityPool Liquidity pool's contract address where the vault's deposit is generating rewards
     * @param _rewardToken address of the reward token
     * @return _codes Returns an array of bytes in sequence that can be executed by vault
     */
    function getHarvestAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        address _rewardToken
    ) external view returns (bytes[] memory _codes);
}
