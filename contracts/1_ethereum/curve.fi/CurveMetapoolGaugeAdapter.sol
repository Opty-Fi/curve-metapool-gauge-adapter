// solhint-disable no-unused-vars
// solhint-disable no-empty-blocks
// SPDX-License-Identifier: agpl-3.0

pragma solidity =0.8.11;

//  libraries
import { Address } from "@openzeppelin/contracts-0.8.x/utils/Address.sol";

// helpers
import { AdapterModifiersBase } from "../../utils/AdapterModifiersBase.sol";

//  interfaces
import { ICurveLiquidityGaugeV3 } from "@optyfi/defi-legos/ethereum/curve/contracts/ICurveLiquidityGaugeV3.sol";
import { ICurveRegistry } from "@optyfi/defi-legos/ethereum/curve/contracts/interfacesV0/ICurveRegistry.sol";
import "@optyfi/defi-legos/ethereum/curve/contracts/interfacesV0/ICurveAddressProvider.sol";
import { IERC20 } from "@openzeppelin/contracts-0.8.x/token/ERC20/IERC20.sol";
import { IAdapter, IAdapterV2 } from "../../utils/interfaces/IAdapterV2.sol";
import { IAdapterHarvestReward, IAdapterHarvestRewardV2 } from "../../utils/interfaces/IAdapterHarvestRewardV2.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title Adapter for Curve's metapool gauges
 * @author Opty.fi
 * @dev Abstraction layer to Curve's metapool gauges
 */

contract CurveMetapoolGaugeAdapter is IAdapterV2, IAdapterHarvestRewardV2, AdapterModifiersBase {
    using Address for address;

    /**
     * @notice Uniswap V2 router contract address
     */
    address public constant uniswapV2Router02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    /**
     * @notice CRV token contract address
     */
    address public constant CRV_TOKEN = address(0xD533a949740bb3306d119CC777fa900bA034cd52);

    /**
     * @notice Curve's minter contract address
     */
    address public constant MINTER = address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);

    constructor(address _registry) AdapterModifiersBase(_registry) {}

    /**
     * @inheritdoc IAdapter
     */
    function getDepositAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _gauge
    ) public view override returns (bytes[] memory _codes) {
        uint256 _amount = IERC20(_underlyingToken).balanceOf(_vault);
        return getDepositSomeCodes(_vault, _underlyingToken, _gauge, _amount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _gauge
    ) public view override returns (bytes[] memory _codes) {
        uint256 _redeemAmount = getLiquidityPoolTokenBalance(_vault, _underlyingToken, _gauge);
        return getWithdrawSomeCodes(_vault, _underlyingToken, _gauge, _redeemAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getUnderlyingTokens(address _gauge, address)
        public
        view
        override
        returns (address[] memory _underlyingTokens)
    {
        _underlyingTokens = new address[](1);
        _underlyingTokens[0] = ICurveLiquidityGaugeV3(_gauge).lp_token();
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateAmountInLPToken(
        address,
        address,
        uint256 _underlyingTokenAmount
    ) public pure override returns (uint256) {
        return _underlyingTokenAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateRedeemableLPTokenAmount(
        address payable _vault,
        address _underlyingToken,
        address _gauge,
        uint256 _redeemAmount
    ) public view override returns (uint256 _amount) {
        uint256 _liquidityPoolTokenBalance = getLiquidityPoolTokenBalance(_vault, _underlyingToken, _gauge);
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _gauge);
        // can have unintentional rounding errors
        _amount = ((_liquidityPoolTokenBalance * _redeemAmount) / _balanceInToken) + 1;
    }

    /**
     * @inheritdoc IAdapter
     */
    function isRedeemableAmountSufficient(
        address payable _vault,
        address _underlyingToken,
        address _gauge,
        uint256 _redeemAmount
    ) public view override returns (bool) {
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _gauge);
        return _balanceInToken >= _redeemAmount;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getClaimRewardTokenCode(address payable, address _gauge)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        uint256 _codeLength = uint256(1);
        address[] memory _rewardTokens = getRewardTokens(_gauge);
        if (_rewardTokens[1] != address(0)) {
            _codeLength++;
        }
        _codes = new bytes[](_codeLength);
        _codes[0] = abi.encode(_getMinter(), abi.encodeWithSignature("mint(address)", _gauge));
        if (_rewardTokens[1] != address(0)) {
            _codes[1] = abi.encode(_gauge, abi.encodeWithSignature("claim_rewards()"));
        }
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _gauge
    ) public view override returns (bytes[] memory _codes) {
        uint256 _rewardTokenAmount = IERC20(getRewardToken(_gauge)).balanceOf(_vault);
        return getHarvestSomeCodes(_vault, _underlyingToken, _gauge, _rewardTokenAmount);
    }

    /**
     * @inheritdoc IAdapterHarvestRewardV2
     */
    function getHarvestAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        address _rewardToken
    ) external view override returns (bytes[] memory _codes) {
        return getHarvestSomeCodes(_vault, _underlyingToken, _liquidityPool, IERC20(_rewardToken).balanceOf(_vault));
    }

    /**
     * @inheritdoc IAdapter
     */
    function canStake(address) public pure override returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositSomeCodes(
        address payable,
        address,
        address _gauge,
        uint256 _amount
    ) public pure override returns (bytes[] memory _codes) {
        if (_amount > 0) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(_gauge, abi.encodeWithSignature("deposit(uint256)", _amount));
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawSomeCodes(
        address payable,
        address,
        address _gauge,
        uint256 _amount
    ) public pure override returns (bytes[] memory _codes) {
        if (_amount > 0) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(_gauge, abi.encodeWithSignature("withdraw(uint256)", _amount));
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getPoolValue(address _gauge, address) public view override returns (uint256) {
        return ICurveLiquidityGaugeV3(_gauge).totalSupply();
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolToken(address, address _gauge) public pure override returns (address) {
        return _gauge;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getAllAmountInToken(
        address payable _vault,
        address,
        address _gauge
    ) public view override returns (uint256 _amount) {
        _amount = ICurveLiquidityGaugeV3(_gauge).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolTokenBalance(
        address payable _vault,
        address,
        address _gauge
    ) public view override returns (uint256) {
        return ICurveLiquidityGaugeV3(_gauge).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getSomeAmountInToken(
        address,
        address,
        uint256 _liquidityPoolTokenAmount
    ) public pure override returns (uint256) {
        return _liquidityPoolTokenAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getRewardToken(address) public pure override returns (address) {
        return CRV_TOKEN;
    }

    /**
     * @inheritdoc IAdapterV2
     */
    function getRewardTokens(address _gauge) public view override returns (address[] memory _rewardTokens) {
        _rewardTokens = new address[](9);
        _rewardTokens[0] = getRewardToken(_gauge);
        for (uint256 _i = 0; _i < 8; _i++) {
            _rewardTokens[_i + 1] = ICurveLiquidityGaugeV3(_gauge).reward_tokens(_i);
        }
    }

    /*solhint-disable no-empty-blocks*/

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getUnclaimedRewardTokenAmount(
        address payable,
        address,
        address
    ) public view override returns (uint256) {}

    /**
     * @inheritdoc IAdapterHarvestRewardV2
     */
    function getUnclaimedRewardTokenAmount(
        address payable,
        address,
        address,
        address
    ) public view override returns (uint256) {}

    /*solhint-enable no-empty-blocks*/

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address _gauge,
        uint256 _rewardTokenAmount
    ) public view override returns (bytes[] memory _codes) {
        return _getHarvestCodes(_vault, getRewardToken(_gauge), _underlyingToken, _rewardTokenAmount);
    }

    /**
     * @inheritdoc IAdapterHarvestRewardV2
     */
    function getHarvestSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address,
        address _rewardToken,
        uint256 _rewardTokenAmount
    ) public view override returns (bytes[] memory _codes) {
        return _getHarvestCodes(_vault, _rewardToken, _underlyingToken, _rewardTokenAmount);
    }

    /* solhint-disable no-empty-blocks */

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getAddLiquidityCodes(address payable, address) public view override returns (bytes[] memory) {}

    /* solhint-enable no-empty-blocks */

    /**
     * @notice Get the Curve Minter's address
     * @return address the address of the minter
     */
    function _getMinter() internal pure returns (address) {
        return MINTER;
    }

    /**
     * @dev Get the codes for harvesting the tokens using uniswap router
     * @param _vault Vault contract address
     * @param _rewardToken Reward token address
     * @param _underlyingToken Token address acting as underlying Asset for the vault contract
     * @param _rewardTokenAmount reward token amount to harvest
     * @return _codes List of harvest codes for harvesting reward tokens
     */
    function _getHarvestCodes(
        address payable _vault,
        address _rewardToken,
        address _underlyingToken,
        uint256 _rewardTokenAmount
    ) internal view returns (bytes[] memory _codes) {
        if (_rewardTokenAmount > 0) {
            uint256[] memory _amounts = IUniswapV2Router02(uniswapV2Router02).getAmountsOut(
                _rewardTokenAmount,
                _getPath(_rewardToken, _underlyingToken)
            );
            if (_amounts[_amounts.length - 1] > 0) {
                _codes = new bytes[](3);
                _codes[0] = abi.encode(
                    _rewardToken,
                    abi.encodeCall(IERC20(_rewardToken).approve, (uniswapV2Router02, uint256(0)))
                );
                _codes[1] = abi.encode(
                    _rewardToken,
                    abi.encodeCall(IERC20(_rewardToken).approve, (uniswapV2Router02, _rewardTokenAmount))
                );
                _codes[2] = abi.encode(
                    uniswapV2Router02,
                    abi.encodeCall(
                        IUniswapV2Router01(uniswapV2Router02).swapExactTokensForTokens,
                        (
                            _rewardTokenAmount,
                            uint256(0),
                            _getPath(_rewardToken, _underlyingToken),
                            _vault,
                            type(uint256).max
                        )
                    )
                );
            }
        }
    }

    /**
     * @dev Constructs the path for token swap on Uniswap
     * @param _initialToken The token to be swapped with
     * @param _finalToken The token to be swapped for
     * @return _path The array of tokens in the sequence to be swapped for
     */
    function _getPath(address _initialToken, address _finalToken) internal pure returns (address[] memory _path) {
        address _weth = IUniswapV2Router02(uniswapV2Router02).WETH();
        if (_finalToken == _weth) {
            _path = new address[](2);
            _path[0] = _initialToken;
            _path[1] = _weth;
        } else if (_initialToken == _weth) {
            _path = new address[](2);
            _path[0] = _weth;
            _path[1] = _finalToken;
        } else {
            _path = new address[](3);
            _path[0] = _initialToken;
            _path[1] = _weth;
            _path[2] = _finalToken;
        }
    }

    /**
     * @dev Get the underlying token amount equivalent to reward token amount
     * @param _rewardToken Reward token address
     * @param _underlyingToken Token address acting as underlying Asset for the vault contract
     * @param _amount reward token balance amount
     * @return equivalent reward token balance in Underlying token value
     */
    function _getRewardBalanceInUnderlyingTokens(
        address _rewardToken,
        address _underlyingToken,
        uint256 _amount
    ) internal view returns (uint256) {
        try
            IUniswapV2Router02(uniswapV2Router02).getAmountsOut(_amount, _getPath(_rewardToken, _underlyingToken))
        returns (uint256[] memory _amountsA) {
            return _amountsA[_amountsA.length - 1];
        } catch {
            return 0;
        }
    }
}
