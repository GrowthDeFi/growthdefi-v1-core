// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GAFormulae } from "./GAFormulae.sol";
import { GATokenBase } from "./GATokenBase.sol";
import { GADelegatedReserveManager } from "./GADelegatedReserveManager.sol";
import { G } from "./G.sol";
import { GA } from "./GA.sol";

contract GATokenType2 is GATokenBase
{
	using GADelegatedReserveManager for GADelegatedReserveManager.Self;

	GADelegatedReserveManager.Self drm;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakesToken, address _reserveToken, address _borrowToken, address _growthToken)
		GATokenBase(_name, _symbol, _decimals, _stakesToken, _reserveToken, _growthToken) public
	{
		drm.init(_reserveToken, _borrowToken, _growthToken);
	}

	function borrowingReserveUnderlying() public view override returns (uint256 _borrowingReserveUnderlying)
	{
		uint256 _lendAmount = GA.getLendAmount(reserveToken);
		uint256 _availableAmount = _lendAmount.mul(GA.getCollateralRatio(reserveToken)).div(1e18);
		uint256 _borrowAmount = GA.getBorrowAmount(drm.borrowToken);
		uint256 _freeAmount = GA.getLiquidityAmount(drm.borrowToken);
		uint256 _totalAmount = _borrowAmount.add(_freeAmount);
		return _totalAmount > 0 ? _availableAmount.mul(_borrowAmount).div(_totalAmount) : 0;
	}

	function exchange() public view override returns (address _exchange)
	{
		return drm.exchange;
	}

	function growthGulpRange() public view override returns (uint256 _growthMinGulpAmount, uint256 _growthMaxGulpAmount)
	{
		return (drm.growthMinGulpAmount, drm.growthMaxGulpAmount);
	}

	function collateralizationRatio() public view override returns (uint256 _collateralizationRatio, uint256 _collateralizationMargin)
	{
		return (drm.collateralizationRatio, drm.collateralizationMargin);
	}

	function setExchange(address _exchange) public override onlyOwner nonReentrant
	{
		drm.setExchange(_exchange);
	}

	function setGrowthGulpRange(uint256 _growthMinGulpAmount, uint256 _growthMaxGulpAmount) public override onlyOwner nonReentrant
	{
		drm.setGrowthGulpRange(_growthMinGulpAmount, _growthMaxGulpAmount);
	}

	function setCollateralizationRatio(uint256 _collateralizationRatio, uint256 _collateralizationMargin) public override onlyOwner nonReentrant
	{
		drm.setCollateralizationRatio(_collateralizationRatio, _collateralizationMargin);
	}

	function _prepareDeposit(uint256 /* _cost */) internal override returns (bool _success)
	{
		return drm.adjustReserve(0);
	}

	function _prepareWithdrawal(uint256 _cost) internal override returns (bool _success)
	{
		return drm.adjustReserve(GAFormulae._calcUnderlyingCostFromCost(_cost, GA.fetchExchangeRate(reserveToken)));
	}
}
