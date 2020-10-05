// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { GCToken } from "./GCToken.sol";
import { G } from "./G.sol";

library GCDelegatedReserveManager
{
	using SafeMath for uint256;
	using GCDelegatedReserveManager for GCDelegatedReserveManager.Self;

	uint256 constant DEFAULT_COLLATERALIZATION_RATIO = 80e16; // 80% of 50% = 40%
	uint256 constant DEFAULT_COLLATERALIZATION_MARGIN = 8e16; // 8% of 50% = 4%

	struct Self {
		address reserveToken;
		address underlyingToken;

		address miningToken;
		address miningExchange;
		uint256 miningMinGulpAmount;
		uint256 miningMaxGulpAmount;

		address growthToken;
		address growthReserveToken;
		address growthUnderlyingToken;
		uint256 growthMinGulpAmount;
		uint256 growthMaxGulpAmount;

		uint256 collateralizationRatio;
		uint256 collateralizationMargin;
	}

	function init(Self storage _self, address _reserveToken, address _underlyingToken, address _miningToken, address _growthToken) public
	{
		_self.reserveToken = _reserveToken;
		_self.underlyingToken = _underlyingToken;

		_self.miningToken = _miningToken;
		_self.miningExchange = address(0);
		_self.miningMinGulpAmount = 0;
		_self.miningMaxGulpAmount = 0;

		_self.growthToken = _growthToken;
		_self.growthReserveToken = GCToken(_growthToken).reserveToken();
		_self.growthUnderlyingToken = GCToken(_growthToken).underlyingToken();
		_self.growthMinGulpAmount = 0;
		_self.growthMaxGulpAmount = 0;

		_self.collateralizationRatio = DEFAULT_COLLATERALIZATION_RATIO;
		_self.collateralizationMargin = DEFAULT_COLLATERALIZATION_MARGIN;

		G.safeEnter(_reserveToken);
	}

	function setMiningExchange(Self storage _self, address _miningExchange) public
	{
		_self.miningExchange = _miningExchange;
	}

	function setMiningGulpRange(Self storage _self, uint256 _miningMinGulpAmount, uint256 _miningMaxGulpAmount) public
	{
		require(_miningMinGulpAmount <= _miningMaxGulpAmount, "invalid range");
		_self.miningMinGulpAmount = _miningMinGulpAmount;
		_self.miningMaxGulpAmount = _miningMaxGulpAmount;
	}

	function setGrowthGulpRange(Self storage _self, uint256 _growthMinGulpAmount, uint256 _growthMaxGulpAmount) public
	{
		require(_growthMinGulpAmount <= _growthMaxGulpAmount, "invalid range");
		_self.growthMinGulpAmount = _growthMinGulpAmount;
		_self.growthMaxGulpAmount = _growthMaxGulpAmount;
	}

	function setCollateralizationRatio(Self storage _self, uint256 _collateralizationRatio) public
	{
		require(_self.collateralizationMargin <= _collateralizationRatio && _collateralizationRatio.add(_self.collateralizationMargin) <= 1e18, "invalid ratio");
		_self.collateralizationRatio = _collateralizationRatio;
	}

	function setCollateralizationMargin(Self storage _self, uint256 _collateralizationMargin) public
	{
		require(_collateralizationMargin <= _self.collateralizationRatio && _self.collateralizationRatio.add(_collateralizationMargin) <= 1e18, "invalid ratio");
		_self.collateralizationMargin = _collateralizationMargin;
	}

	function adjustReserve(Self storage _self, uint256 _roomAmount) public returns (bool _success)
	{
		bool success1 = _self._gulpMiningAssets();
		bool success2 = _self._gulpGrowthAssets();
		bool success3 = _self._adjustReserve(_roomAmount);
		return success1 && success2 && success3;
	}

	function _calcCollateralizationRatio(Self storage _self) internal view returns (uint256 _collateralizationRatio)
	{
		return G.getCollateralRatio(_self.reserveToken).mul(_self.collateralizationRatio).div(1e18);
	}

	function _gulpMiningAssets(Self storage _self) internal returns (bool _success)
	{
		uint256 _miningAmount = G.getBalance(_self.miningToken);
		if (_miningAmount == 0) return true;
		if (_miningAmount < _self.miningMinGulpAmount) return true;
		if (_self.miningExchange == address(0)) return true;
		_self._convertMiningToUnderlying(G.min(_miningAmount, _self.miningMaxGulpAmount));
		return G.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
	}

	function _gulpGrowthAssets(Self storage _self) internal returns (bool _success)
	{
		uint256 _borrowAmount = G.fetchBorrowAmount(_self.growthReserveToken);
		uint256 _redeemableAmount = _self._calcUnderlyingCostFromShares(G.getBalance(_self.growthToken));
		if (_redeemableAmount <= _borrowAmount) return true;
		uint256 _growthAmount = _redeemableAmount.sub(_borrowAmount);
		if (_growthAmount < _self.growthMinGulpAmount) return true;
		if (_self.miningExchange == address(0)) return true;
		uint256 _grossShares = _self._calcSharesFromUnderlyingCost(G.min(_growthAmount, _self.growthMaxGulpAmount));
		if (_grossShares == 0) return true;
		try GCToken(_self.growthToken).withdrawUnderlying(_grossShares) {
			_self._convertGrowthUnderlyingToUnderlying(G.getBalance(_self.growthUnderlyingToken));
			return G.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _adjustReserve(Self storage _self, uint256 _roomAmount) internal returns (bool _success)
	{
		uint256 _scallingRatio;
		{
			uint256 _reserveAmount = G.fetchLendAmount(_self.reserveToken);
			_roomAmount = G.min(_roomAmount, _reserveAmount);
			uint256 _newReserveAmount = _reserveAmount.sub(_roomAmount);
			uint256 _collateralRatio = _self._calcCollateralizationRatio();
			uint256 _availableAmount = _reserveAmount.mul(_collateralRatio).div(1e18);
			uint256 _newAvailableAmount = _newReserveAmount.mul(_collateralRatio).div(1e18);
			_scallingRatio = _newAvailableAmount.mul(1e18).div(_availableAmount);
		}
		uint256 _borrowAmount = G.fetchBorrowAmount(_self.growthReserveToken);
		uint256 _newBorrowAmount;
		uint256 _minBorrowAmount;
		uint256 _maxBorrowAmount;
		{
			uint256 _freeAmount = G.getLiquidityAmount(_self.growthReserveToken);
			uint256 _totalAmount = _borrowAmount.add(_freeAmount);
			uint256 _idealAmount = _totalAmount.mul(_self.collateralizationRatio).div(1e18);
			uint256 _marginAmount = _totalAmount.mul(_self.collateralizationMargin).div(1e18);
			_newBorrowAmount = _idealAmount.mul(_scallingRatio).div(1e18);
			uint256 _newMarginAmount = _marginAmount.mul(_scallingRatio).div(1e18);
			_newMarginAmount = G.min(_newMarginAmount, _newBorrowAmount);
			_minBorrowAmount = _newBorrowAmount.sub(_newMarginAmount);
			_maxBorrowAmount = _newBorrowAmount.add(_newMarginAmount);
		}
		if (_borrowAmount < _minBorrowAmount) {
			uint256 _amount = _newBorrowAmount.sub(_borrowAmount);
			_success = G.borrow(_self.growthReserveToken, _amount);
			if (!_success) return false;
			try GCToken(_self.growthToken).depositUnderlying(_amount) {
				return true;
			} catch (bytes memory /* _data */) {
				G.repay(_self.growthReserveToken, _amount);
				return false;
			}
		}
		if (_borrowAmount > _maxBorrowAmount) {
			uint256 _amount = _borrowAmount.sub(_newBorrowAmount);
			uint256 _grossShares = _self._calcSharesFromUnderlyingCost(_amount);
			try GCToken(_self.growthToken).withdrawUnderlying(_grossShares) {
				return G.repay(_self.growthReserveToken, G.getBalance(_self.growthUnderlyingToken));
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
		return true;
	}

	function _calcUnderlyingCostFromShares(Self storage _self, uint256 _grossShares) internal view returns (uint256 _underlyingCost) {
		uint256 _totalReserve = GCToken(_self.growthToken).totalReserve();
		uint256 _totalSupply = GCToken(_self.growthToken).totalSupply();
		uint256 _withdrawalFee = GCToken(_self.growthToken).withdrawalFee();
		uint256 _exchangeRate = GCToken(_self.growthToken).exchangeRate();
		(uint256 _cost,) = GCToken(_self.growthToken).calcWithdrawalCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee);
		return GCToken(_self.growthToken).calcUnderlyingCostFromCost(_cost, _exchangeRate);
	}

	function _calcSharesFromUnderlyingCost(Self storage _self, uint256 _underlyingCost) internal view returns (uint256 _grossShares) {
		uint256 _totalReserve = GCToken(_self.growthToken).totalReserve();
		uint256 _totalSupply = GCToken(_self.growthToken).totalSupply();
		uint256 _withdrawalFee = GCToken(_self.growthToken).withdrawalFee();
		uint256 _exchangeRate = GCToken(_self.growthToken).exchangeRate();
		uint256 _cost = GCToken(_self.growthToken).calcCostFromUnderlyingCost(_underlyingCost, _exchangeRate);
		(_grossShares,) = GCToken(_self.growthToken).calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
		return _grossShares;
	}

	function _convertMiningToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		G.dynamicConvertFunds(_self.miningExchange, _self.miningToken, _self.underlyingToken, _inputAmount, 0);
	}

	function _convertGrowthUnderlyingToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		GCToken gct = GCToken(_self.growthToken);
		G.dynamicConvertFunds(_self.miningExchange, gct.underlyingToken(), _self.underlyingToken, _inputAmount, 0);
	}
}