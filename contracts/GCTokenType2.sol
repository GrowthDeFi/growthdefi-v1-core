// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GCToken } from "./GCToken.sol";
import { GCFormulae } from "./GCFormulae.sol";
import { GCTokenBase } from "./GCTokenBase.sol";
import { GCDelegatedReserveManager } from "./GCDelegatedReserveManager.sol";
import { G } from "./G.sol";
import { GC } from "./GC.sol";

contract GCTokenType2 is GCTokenBase
{
	using GCDelegatedReserveManager for GCDelegatedReserveManager.Self;

	GCDelegatedReserveManager.Self drm;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakesToken, address _reserveToken, address _miningToken, address _growthToken)
		GCTokenBase(_name, _symbol, _decimals, _stakesToken, _reserveToken, _miningToken, _growthToken) public
	{
		address _underlyingToken = GC.getUnderlyingToken(_reserveToken);
		drm.init(_reserveToken, _underlyingToken, _miningToken, _growthToken);
	}

	function borrowingReserveUnderlying() public view override returns (uint256 _borrowingReserveUnderlying)
	{
		uint256 _lendAmount = GC.getLendAmount(reserveToken);
		uint256 _availableAmount = _lendAmount.mul(GC.getCollateralRatio(reserveToken)).div(1e18);
		address _growthReserveToken = GCToken(growthToken).reserveToken();
		uint256 _borrowAmount = GC.getBorrowAmount(_growthReserveToken);
		uint256 _freeAmount = GC.getLiquidityAmount(_growthReserveToken);
		uint256 _totalAmount = _borrowAmount.add(_freeAmount);
		return _totalAmount > 0 ? _availableAmount.mul(_borrowAmount).div(_totalAmount) : 0;
	}

	function exchange() public view override returns (address _exchange)
	{
		return drm.exchange;
	}

	function miningGulpRange() public view override returns (uint256 _miningMinGulpAmount, uint256 _miningMaxGulpAmount)
	{
		return (drm.miningMinGulpAmount, drm.miningMaxGulpAmount);
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

	function setMiningGulpRange(uint256 _miningMinGulpAmount, uint256 _miningMaxGulpAmount) public override onlyOwner nonReentrant
	{
		drm.setMiningGulpRange(_miningMinGulpAmount, _miningMaxGulpAmount);
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
		return drm.adjustReserve(GCFormulae._calcUnderlyingCostFromCost(_cost, GC.fetchExchangeRate(reserveToken)));
	}
}
