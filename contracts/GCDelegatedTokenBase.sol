// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { GToken } from "./GToken.sol";
import { GFormulae } from "./GFormulae.sol";
import { GTokenBase } from "./GTokenBase.sol";
import { GCToken } from "./GCToken.sol";
import { GCFormulae } from "./GCFormulae.sol";
import { GCDelegatedReserveManager } from "./GCDelegatedReserveManager.sol";
import { G } from "./G.sol";

contract GCDelegatedTokenBase is GTokenBase, GCToken
{
	using GCDelegatedReserveManager for GCDelegatedReserveManager.Self;

	address public immutable override underlyingToken;
	address public immutable growthToken;

	GCDelegatedReserveManager.Self drm;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakeToken, address _reserveToken, address _miningToken, address _growthToken)
		GTokenBase(_name, _symbol, _decimals, _stakeToken, _reserveToken) public
	{
		address _underlyingToken = G.getUnderlyingToken(_reserveToken);
		underlyingToken = _underlyingToken;
		growthToken = _growthToken;
		drm.init(_reserveToken, _underlyingToken, _miningToken, _growthToken);
	}

	function calcCostFromUnderlyingCost(uint256 _underlyingCost, uint256 _exchangeRate) public pure override returns (uint256 _cost)
	{
		return GCFormulae._calcCostFromUnderlyingCost(_underlyingCost, _exchangeRate);
	}

	function calcUnderlyingCostFromCost(uint256 _cost, uint256 _exchangeRate) public pure override returns (uint256 _underlyingCost)
	{
		return GCFormulae._calcUnderlyingCostFromCost(_cost, _exchangeRate);
	}

	function exchangeRate() public view override returns (uint256 _exchangeRate)
	{
		return G.getExchangeRate(reserveToken);
	}

	function totalReserve() public view override(GToken, GTokenBase) returns (uint256 _totalReserve)
	{
		return GCFormulae._calcCostFromUnderlyingCost(totalReserveUnderlying(), exchangeRate());
	}

	function totalReserveUnderlying() public view override returns (uint256 _totalReserveUnderlying)
	{
		return lendingReserveUnderlying();
	}

	function lendingReserveUnderlying() public view override returns (uint256 _lendingReserveUnderlying)
	{
		return G.getLendAmount(reserveToken);
	}

	function borrowingReserveUnderlying() public view override returns (uint256 _borrowingReserveUnderlying)
	{
		uint256 _lendAmount = G.getLendAmount(reserveToken);
		uint256 _availableAmount = _lendAmount.mul(G.getCollateralRatio(reserveToken)).div(1e18);
		address _growthReserveToken = GCToken(growthToken).reserveToken();
		uint256 _borrowAmount = G.getBorrowAmount(_growthReserveToken);
		uint256 _freeAmount = G.getLiquidityAmount(_growthReserveToken);
		uint256 _totalAmount = _borrowAmount.add(_freeAmount);
		return _availableAmount.mul(_borrowAmount).div(_totalAmount);
	}

	function depositUnderlying(uint256 _underlyingCost) public override nonReentrant
	{
		address _from = msg.sender;
		require(_underlyingCost > 0, "underlying cost must be greater than 0");
		uint256 _cost = GCFormulae._calcCostFromUnderlyingCost(_underlyingCost, exchangeRate());
		(uint256 _netShares, uint256 _feeShares) = GFormulae._calcDepositSharesFromCost(_cost, totalReserve(), totalSupply(), depositFee());
		require(_netShares > 0, "shares must be greater than 0");
		G.pullFunds(underlyingToken, _from, _underlyingCost);
		G.safeLend(reserveToken, _underlyingCost);
		require(_prepareDeposit(_cost), "not available at the moment");
		_mint(_from, _netShares);
		_mint(address(this), _feeShares.div(2));
		lpm.gulpPoolAssets();
	}

	function withdrawUnderlying(uint256 _grossShares) public override nonReentrant
	{
		address _from = msg.sender;
		require(_grossShares > 0, "shares must be greater than 0");
		(uint256 _cost, uint256 _feeShares) = GFormulae._calcWithdrawalCostFromShares(_grossShares, totalReserve(), totalSupply(), withdrawalFee());
		uint256 _underlyingCost = GCFormulae._calcUnderlyingCostFromCost(_cost, exchangeRate());
		require(_underlyingCost > 0, "underlying cost must be greater than 0");
		require(_prepareWithdrawal(_cost), "not available at the moment");
		_underlyingCost = G.min(_underlyingCost, G.getLendAmount(reserveToken));
		G.safeRedeem(reserveToken, _underlyingCost);
		G.pushFunds(underlyingToken, _from, _underlyingCost);
		_burn(_from, _grossShares);
		_mint(address(this), _feeShares.div(2));
		lpm.gulpPoolAssets();
	}

	function miningExchange() public view override returns (address _miningExchange)
	{
		return drm.miningExchange;
	}

	function miningGulpRange() public view override returns (uint256 _miningMinGulpAmount, uint256 _miningMaxGulpAmount)
	{
		return (drm.miningMinGulpAmount, drm.miningMaxGulpAmount);
	}

	function growthGulpRange() public view /*override*/ returns (uint256 _growthMinGulpAmount, uint256 _growthMaxGulpAmount)
	{
		return (drm.growthMinGulpAmount, drm.growthMaxGulpAmount);
	}

	function collateralizationRatio() public view override returns (uint256 _collateralizationRatio)
	{
		return drm.collateralizationRatio;
	}

	function collateralizationMargin() public view /*override*/ returns (uint256 _collateralizationMargin)
	{
		return drm.collateralizationMargin;
	}

	function setMiningExchange(address _miningExchange) public override onlyOwner nonReentrant
	{
		drm.setMiningExchange(_miningExchange);
	}

	function setMiningGulpRange(uint256 _miningMinGulpAmount, uint256 _miningMaxGulpAmount) public override onlyOwner nonReentrant
	{
		drm.setMiningGulpRange(_miningMinGulpAmount, _miningMaxGulpAmount);
	}

	function setGrowthGulpRange(uint256 _growthMinGulpAmount, uint256 _growthMaxGulpAmount) public /*override*/ onlyOwner nonReentrant
	{
		drm.setGrowthGulpRange(_growthMinGulpAmount, _growthMaxGulpAmount);
	}

	function setCollateralizationRatio(uint256 _collateralizationRatio) public override onlyOwner nonReentrant
	{
		drm.setCollateralizationRatio(_collateralizationRatio);
	}

	function setCollateralizationMargin(uint256 _collateralizationMargin) public /*override*/ onlyOwner nonReentrant
	{
		drm.setCollateralizationMargin(_collateralizationMargin);
	}

	function _prepareWithdrawal(uint256 _cost) internal override returns (bool _success)
	{
		return drm.adjustReserve(GCFormulae._calcUnderlyingCostFromCost(_cost, G.fetchExchangeRate(reserveToken)));
	}

	function _prepareDeposit(uint256 _cost) internal override returns (bool _success)
	{
		_cost; // silences warnings
		return drm.adjustReserve(0);
	}
}