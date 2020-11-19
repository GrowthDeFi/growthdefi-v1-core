// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { GToken } from "./GToken.sol";
import { G } from "./G.sol";
import { GC } from "./GC.sol";

library GCDelegatedReserveManager
{
	using SafeMath for uint256;
	using GCDelegatedReserveManager for GCDelegatedReserveManager.Self;

	uint256 constant MAXIMUM_COLLATERALIZATION_RATIO = 96e16; // 96% of 50% = 48%
	uint256 constant DEFAULT_COLLATERALIZATION_RATIO = 66e16; // 66% of 50% = 33%
	uint256 constant DEFAULT_COLLATERALIZATION_MARGIN = 8e16; // 8% of 50% = 4%

	struct Self {
		address reserveToken;
		address underlyingToken;

		address exchange;

		address miningToken;
		uint256 miningMinGulpAmount;
		uint256 miningMaxGulpAmount;

		address borrowToken;

		address growthToken;
		address growthReserveToken;
		uint256 growthMinGulpAmount;
		uint256 growthMaxGulpAmount;

		uint256 collateralizationRatio;
		uint256 collateralizationMargin;
	}

	function init(Self storage _self, address _reserveToken, address _miningToken, address _borrowToken, address _growthToken) public
	{
		address _underlyingToken = GC.getUnderlyingToken(_reserveToken);
		address _borrowUnderlyingToken = GC.getUnderlyingToken(_borrowToken);
		address _growthReserveToken = GToken(_growthToken).reserveToken();
		assert(_borrowUnderlyingToken == _growthReserveToken);

		_self.reserveToken = _reserveToken;
		_self.underlyingToken = _underlyingToken;

		_self.exchange = address(0);

		_self.miningToken = _miningToken;
		_self.miningMinGulpAmount = 0;
		_self.miningMaxGulpAmount = 0;

		_self.borrowToken = _borrowToken;

		_self.growthToken = _growthToken;
		_self.growthReserveToken = _growthReserveToken;
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
		require(_collateralizationMargin <= _collateralizationRatio && _collateralizationRatio.add(_collateralizationMargin) <= MAXIMUM_COLLATERALIZATION_RATIO, "invalid ratio");
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
		if (_self.miningMaxGulpAmount == 0) return true;
		uint256 _miningAmount = G.getBalance(_self.miningToken);
		if (_miningAmount == 0) return true;
		if (_miningAmount < _self.miningMinGulpAmount) return true;
		_self._convertMiningToUnderlying(G.min(_miningAmount, _self.miningMaxGulpAmount));
		return GC.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
	}

	function _gulpGrowthAssets(Self storage _self) internal returns (bool _success)
	{
		if (_self.exchange == address(0)) return true;
		if (_self.growthMaxGulpAmount == 0) return true;
		uint256 _borrowAmount = GC.fetchBorrowAmount(_self.borrowToken);
		uint256 _totalShares = G.getBalance(_self.growthToken);
		uint256 _redeemableAmount = _self._calcWithdrawalCostFromShares(_totalShares);
		if (_redeemableAmount <= _borrowAmount) return true;
		uint256 _growthAmount = _redeemableAmount.sub(_borrowAmount);
		if (_growthAmount < _self.growthMinGulpAmount) return true;
		uint256 _grossShares = _self._calcWithdrawalSharesFromCost(G.min(_growthAmount, _self.growthMaxGulpAmount));
		_grossShares = G.min(_grossShares, _totalShares);
		if (_grossShares == 0) return true;
		_success = _self._withdraw(_grossShares);
		if (!_success) return false;
		_self._convertGrowthReserveToUnderlying(G.getBalance(_self.growthReserveToken));
		return GC.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
	}

	function _adjustReserve(Self storage _self, uint256 _roomAmount) internal returns (bool _success)
	{
		uint256 _scallingRatio;
		{
			uint256 _reserveAmount = GC.fetchLendAmount(_self.reserveToken);
			_roomAmount = G.min(_roomAmount, _reserveAmount);
			uint256 _newReserveAmount = _reserveAmount.sub(_roomAmount);
			_scallingRatio = _reserveAmount > 0 ? uint256(1e18).mul(_newReserveAmount).div(_reserveAmount) : 0;
		}
		uint256 _borrowAmount = GC.fetchBorrowAmount(_self.borrowToken);
		uint256 _newBorrowAmount;
		uint256 _minBorrowAmount;
		uint256 _maxBorrowAmount;
		{
			uint256 _freeAmount = GC.getLiquidityAmount(_self.borrowToken);
			uint256 _totalAmount = _borrowAmount.add(_freeAmount);
			uint256 _newTotalAmount = _totalAmount.mul(_scallingRatio).div(1e18);
			_newBorrowAmount = _newTotalAmount.mul(_self.collateralizationRatio).div(1e18);
			uint256 _newMarginAmount = _newTotalAmount.mul(_self.collateralizationMargin).div(1e18);
			_minBorrowAmount = _newBorrowAmount.sub(G.min(_newMarginAmount, _newBorrowAmount));
			_maxBorrowAmount = G.min(_newBorrowAmount.add(_newMarginAmount), _newTotalAmount);
		}
		if (_borrowAmount < _minBorrowAmount) {
			uint256 _amount = _newBorrowAmount.sub(_borrowAmount);
			_amount = G.min(_amount, GC.getMarketAmount(_self.borrowToken));
			_success = GC.borrow(_self.borrowToken, _amount);
			if (!_success) return false;
			_success = _self._deposit(_amount);
			if (_success) return true;
			GC.repay(_self.borrowToken, _amount);
			return false;
		}
		if (_borrowAmount > _maxBorrowAmount) {
			uint256 _amount = _borrowAmount.sub(_newBorrowAmount);
			uint256 _grossShares = _self._calcWithdrawalSharesFromCost(_amount);
			_grossShares = G.min(_grossShares, G.getBalance(_self.growthToken));
			if (_grossShares == 0) return true;
			_success = _self._withdraw(_grossShares);
			if (!_success) return false;
			uint256 _repayAmount = G.min(_borrowAmount, G.getBalance(_self.growthReserveToken));
			return GC.repay(_self.borrowToken, _repayAmount);
		}
		return true;
	}

	function _calcWithdrawalCostFromShares(Self storage _self, uint256 _grossShares) internal view returns (uint256 _cost) {
		uint256 _totalReserve = GToken(_self.growthToken).totalReserve();
		uint256 _totalSupply = GToken(_self.growthToken).totalSupply();
		uint256 _withdrawalFee = GToken(_self.growthToken).withdrawalFee();
		(_cost,) = GToken(_self.growthToken).calcWithdrawalCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee);
		return _cost;
	}

	function _calcWithdrawalSharesFromCost(Self storage _self, uint256 _cost) internal view returns (uint256 _grossShares) {
		uint256 _totalReserve = GToken(_self.growthToken).totalReserve();
		uint256 _totalSupply = GToken(_self.growthToken).totalSupply();
		uint256 _withdrawalFee = GToken(_self.growthToken).withdrawalFee();
		(_grossShares,) = GToken(_self.growthToken).calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
		return _grossShares;
	}

	function _deposit(Self storage _self, uint256 _cost) internal returns (bool _success)
	{
		G.approveFunds(_self.growthReserveToken, _self.growthToken, _cost);
		try GToken(_self.growthToken).deposit(_cost) {
			return true;
		} catch (bytes memory /* _data */) {
			G.approveFunds(_self.growthReserveToken, _self.growthToken, 0);
			return false;
		}
	}

	function _withdraw(Self storage _self, uint256 _grossShares) internal returns (bool _success)
	{
		try GToken(_self.growthToken).withdraw(_grossShares) {
			return true;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _convertMiningToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		G.dynamicConvertFunds(_self.exchange, _self.miningToken, _self.underlyingToken, _inputAmount, 0);
	}

	function _convertGrowthReserveToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		G.dynamicConvertFunds(_self.exchange, _self.growthReserveToken, _self.underlyingToken, _inputAmount, 0);
	}
}
