// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { GCToken } from "./GCToken.sol";
import { G, GC } from "./G.sol";

library GCDelegatedReserveManager
{
	using SafeMath for uint256;
	using GCDelegatedReserveManager for GCDelegatedReserveManager.Self;

	uint256 constant DEFAULT_COLLATERALIZATION_RATIO = 80e16; // 80% of 50% = 40%
	uint256 constant DEFAULT_COLLATERALIZATION_MARGIN = 8e16; // 8% of 50% = 4%

	struct Self {
		address reserveToken;
		address underlyingToken;

		address exchange;

		address miningToken;
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

		_self.exchange = address(0);

		_self.miningToken = _miningToken;
		_self.miningMinGulpAmount = 0;
		_self.miningMaxGulpAmount = 0;

		_self.growthToken = _growthToken;
		_self.growthReserveToken = GCToken(_growthToken).reserveToken();
		_self.growthUnderlyingToken = GCToken(_growthToken).underlyingToken();
		_self.growthMinGulpAmount = 0;
		_self.growthMaxGulpAmount = 0;

		_self.collateralizationRatio = DEFAULT_COLLATERALIZATION_RATIO;
		_self.collateralizationMargin = DEFAULT_COLLATERALIZATION_MARGIN;

		GC.safeEnter(_reserveToken);
	}

	function setExchange(Self storage _self, address _exchange) public
	{
		_self.exchange = _exchange;
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

	function setCollateralizationRatio(Self storage _self, uint256 _collateralizationRatio, uint256 _collateralizationMargin) public
	{
		require(_collateralizationMargin <= _collateralizationRatio && _collateralizationRatio.add(_collateralizationMargin) <= 1e18, "invalid ratio");
		_self.collateralizationRatio = _collateralizationRatio;
		_self.collateralizationMargin = _collateralizationMargin;
	}

	function adjustReserve(Self storage _self, uint256 _roomAmount) public returns (bool _success)
	{
		bool _success1 = _self._gulpMiningAssets();
		bool _success2 = _self._gulpGrowthAssets();
		bool _success3 = _self._adjustReserve(_roomAmount);
		return _success1 && _success2 && _success3;
	}

	function _calcCollateralizationRatio(Self storage _self) internal view returns (uint256 _collateralizationRatio)
	{
		return GC.getCollateralRatio(_self.reserveToken).mul(_self.collateralizationRatio).div(1e18);
	}

	function _gulpMiningAssets(Self storage _self) internal returns (bool _success)
	{
		if (_self.exchange == address(0)) return true;
		uint256 _miningAmount = G.getBalance(_self.miningToken);
		if (_miningAmount == 0) return true;
		if (_miningAmount < _self.miningMinGulpAmount) return true;
		_self._convertMiningToUnderlying(G.min(_miningAmount, _self.miningMaxGulpAmount));
		return GC.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
	}

	function _gulpGrowthAssets(Self storage _self) internal returns (bool _success)
	{
		if (_self.exchange == address(0)) return true;
		uint256 _borrowAmount = GC.fetchBorrowAmount(_self.growthReserveToken);
		uint256 _redeemableAmount = _self._calcUnderlyingCostFromShares(G.getBalance(_self.growthToken));
		if (_redeemableAmount <= _borrowAmount) return true;
		uint256 _growthAmount = _redeemableAmount.sub(_borrowAmount);
		if (_growthAmount < _self.growthMinGulpAmount) return true;
		uint256 _grossShares = _self._calcSharesFromUnderlyingCost(G.min(_growthAmount, _self.growthMaxGulpAmount));
		if (_grossShares == 0) return true;
		try GCToken(_self.growthToken).withdrawUnderlying(_grossShares) {
			_self._convertGrowthUnderlyingToUnderlying(G.getBalance(_self.growthUnderlyingToken));
			return GC.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _adjustReserve(Self storage _self, uint256 _roomAmount) internal returns (bool _success)
	{
		uint256 _scallingRatio;
		{
			uint256 _reserveAmount = GC.fetchLendAmount(_self.reserveToken);
			_roomAmount = G.min(_roomAmount, _reserveAmount);
			uint256 _newReserveAmount = _reserveAmount.sub(_roomAmount);
			// TODO review if this is necessary (r1 * c) / (r2 * c) => r1 / r2 (if c > 0)
			uint256 _collateralRatio = _self._calcCollateralizationRatio();
			uint256 _availableAmount = _reserveAmount.mul(_collateralRatio).div(1e18);
			uint256 _newAvailableAmount = _newReserveAmount.mul(_collateralRatio).div(1e18);
			_scallingRatio = _availableAmount > 0 ? uint256(1e18).mul(_newAvailableAmount).div(_availableAmount) : 1e18;
		}
		uint256 _borrowAmount = GC.fetchBorrowAmount(_self.growthReserveToken);
		uint256 _newBorrowAmount;
		uint256 _minBorrowAmount;
		uint256 _maxBorrowAmount;
		{
			uint256 _freeAmount = GC.getLiquidityAmount(_self.growthReserveToken);
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
			_success = GC.borrow(_self.growthReserveToken, _amount);
			if (!_success) return false;
			G.approveFunds(_self.growthUnderlyingToken, _self.growthToken, _amount);
			try GCToken(_self.growthToken).depositUnderlying(_amount) {
				return true;
			} catch (bytes memory /* _data */) {
				GC.repay(_self.growthReserveToken, _amount);
				return false;
			}
		}
		if (_borrowAmount > _maxBorrowAmount) {
			uint256 _amount = _borrowAmount.sub(_newBorrowAmount);
			uint256 _grossShares = _self._calcSharesFromUnderlyingCost(_amount);
			_grossShares = G.min(_grossShares, G.getBalance(_self.growthToken));
			if (_grossShares == 0) return true;
			try GCToken(_self.growthToken).withdrawUnderlying(_grossShares) {
				uint256 _repayAmount = G.min(_borrowAmount, G.getBalance(_self.growthUnderlyingToken));
				return GC.repay(_self.growthReserveToken, _repayAmount);
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
		(_underlyingCost,) = GCToken(_self.growthToken).calcWithdrawalUnderlyingCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _underlyingCost;
	}

	function _calcSharesFromUnderlyingCost(Self storage _self, uint256 _underlyingCost) internal view returns (uint256 _grossShares) {
		uint256 _totalReserve = GCToken(_self.growthToken).totalReserve();
		uint256 _totalSupply = GCToken(_self.growthToken).totalSupply();
		uint256 _withdrawalFee = GCToken(_self.growthToken).withdrawalFee();
		uint256 _exchangeRate = GCToken(_self.growthToken).exchangeRate();
		(_grossShares,) = GCToken(_self.growthToken).calcWithdrawalSharesFromUnderlyingCost(_underlyingCost, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _grossShares;
	}

	function _convertMiningToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		G.dynamicConvertFunds(_self.exchange, _self.miningToken, _self.underlyingToken, _inputAmount, 0);
	}

	function _convertGrowthUnderlyingToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		G.dynamicConvertFunds(_self.exchange, _self.growthUnderlyingToken, _self.underlyingToken, _inputAmount, 0);
	}
}
