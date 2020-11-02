// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Math } from "./Math.sol";
import { AaveLendingMarketAbstraction } from "./AaveLendingMarketAbstraction.sol";
import { CompoundLendingMarketAbstraction } from "./CompoundLendingMarketAbstraction.sol";

library LendingMarkets
{
	using SafeMath for uint256;

	enum Provider { Aave, Compound }

	function _getUnderlyingToken(Provider _provider, address _xtoken) internal view returns (address _token)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getUnderlyingToken(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getUnderlyingToken(_xtoken);
	}

	function _getCollateralRatio(Provider _provider, address _xtoken) internal view returns (uint256 _collateralFactor)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getCollateralRatio(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getCollateralRatio(_xtoken);
	}

	function _getMarketAmount(Provider _provider, address _xtoken) internal view returns (uint256 _marketAmount)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getMarketAmount(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getMarketAmount(_xtoken);
	}

	function _getLiquidityAmount(Provider _provider, address _xtoken) internal view returns (uint256 _liquidityAmount)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getLiquidityAmount(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getLiquidityAmount(_xtoken);
	}

	function _getAvailableAmount(Provider _provider, address _xtoken, uint256 _marginAmount) internal view returns (uint256 _availableAmount)
	{
		uint256 _liquidityAmount = _getLiquidityAmount(_provider, _xtoken);
		if (_liquidityAmount <= _marginAmount) return 0;
		return Math._min(_liquidityAmount.sub(_marginAmount), _getMarketAmount(_provider, _xtoken));
	}

	function _getExchangeRate(Provider _provider, address _xtoken) internal view returns (uint256 _exchangeRate)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getExchangeRate(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getExchangeRate(_xtoken);
	}

	function _fetchExchangeRate(Provider _provider, address _xtoken) internal returns (uint256 _exchangeRate)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._fetchExchangeRate(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._fetchExchangeRate(_xtoken);
	}

	function _getLendAmount(Provider _provider, address _xtoken) internal view returns (uint256 _amount)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getLendAmount(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getLendAmount(_xtoken);
	}

	function _fetchLendAmount(Provider _provider, address _xtoken) internal returns (uint256 _amount)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._fetchLendAmount(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._fetchLendAmount(_xtoken);
	}

	function _getBorrowAmount(Provider _provider, address _xtoken) internal view returns (uint256 _amount)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._getBorrowAmount(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._getBorrowAmount(_xtoken);
	}

	function _fetchBorrowAmount(Provider _provider, address _xtoken) internal returns (uint256 _amount)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._fetchBorrowAmount(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._fetchBorrowAmount(_xtoken);
	}

	function _enter(Provider _provider, address _xtoken) internal returns (bool _success)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._enter(_xtoken);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._enter(_xtoken);
	}

	function _lend(Provider _provider, address _xtoken, uint256 _amount) internal returns (bool _success)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._lend(_xtoken, _amount);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._lend(_xtoken, _amount);
	}

	function _redeem(Provider _provider, address _xtoken, uint256 _amount) internal returns (bool _success)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._redeem(_xtoken, _amount);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._redeem(_xtoken, _amount);
	}

	function _borrow(Provider _provider, address _xtoken, uint256 _amount) internal returns (bool _success)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._borrow(_xtoken, _amount);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._borrow(_xtoken, _amount);
	}

	function _repay(Provider _provider, address _xtoken, uint256 _amount) internal returns (bool _success)
	{
		if (_provider == Provider.Aave) return AaveLendingMarketAbstraction._repay(_xtoken, _amount);
		if (_provider == Provider.Compound) return CompoundLendingMarketAbstraction._repay(_xtoken, _amount);
	}

	function _safeEnter(Provider _provider, address _xtoken) internal
	{
		require(_enter(_provider, _xtoken), "enter failed");
	}

	function _safeLend(Provider _provider, address _xtoken, uint256 _amount) internal
	{
		require(_lend(_provider, _xtoken, _amount), "lend failure");
	}

	function _safeRedeem(Provider _provider, address _xtoken, uint256 _amount) internal
	{
		require(_redeem(_provider, _xtoken, _amount), "redeem failure");
	}

	function _safeBorrow(Provider _provider, address _xtoken, uint256 _amount) internal
	{
		require(_borrow(_provider, _xtoken, _amount), "borrow failure");
	}

	function _safeRepay(Provider _provider, address _xtoken, uint256 _amount) internal
	{
		require(_repay(_provider, _xtoken, _amount), "repay failure");
	}
}
