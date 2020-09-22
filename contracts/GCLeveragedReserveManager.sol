// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { G } from "./G.sol";

import { $ } from "./network/$.sol";

library GCLeveragedReserveManager
{
	using SafeMath for uint256;
	using GCLeveragedReserveManager for GCLeveragedReserveManager.Self;

	uint256 constant DELEVERAGING_UNROLL_LIMIT = 10;
	uint256 constant MINIMUM_RATIO_GRANULARITY = 4e16; // 4%
	uint256 constant DEFAULT_IDEAL_COLLATERALIZATION_RATIO = 88e16; // 88% of 75% = 66%
	uint256 constant DEFAULT_LIMIT_COLLATERALIZATION_RATIO = 92e16; // 92% of 75% = 69%
	uint256 constant DEFAULT_COLLATERALIZATION_DEVIATION_RATIO = 1e16; // 1%

	struct Self {
		address miningToken;
		address reserveToken;
		address leverageToken;
		address underlyingToken;
		address borrowToken;

		bool leverageEnabled;
		uint256 leverageAdjustmentAmount;
		uint256 idealCollateralizationRatio;
		uint256 limitCollateralizationRatio;
		uint256 collateralizationDeviationRatio;
	}

	function init(Self storage _self, address _miningToken, address _reserveToken, address _leverageToken, uint256 _leverageAdjustmentAmount) public
	{
		_self.miningToken = _miningToken;
		_self.reserveToken = _reserveToken;
		_self.leverageToken = _leverageToken;
		_self.underlyingToken = G.getUnderlyingToken(_reserveToken);
		_self.borrowToken = G.getUnderlyingToken(_leverageToken);

		_self.leverageEnabled = false;
		_self.leverageAdjustmentAmount = _leverageAdjustmentAmount;
		_self.idealCollateralizationRatio = DEFAULT_IDEAL_COLLATERALIZATION_RATIO;
		_self.limitCollateralizationRatio = DEFAULT_LIMIT_COLLATERALIZATION_RATIO;
		_self.collateralizationDeviationRatio = DEFAULT_COLLATERALIZATION_DEVIATION_RATIO;

		G.safeEnter(_reserveToken);
	}

	function setLeverageEnabled(Self storage _self, bool _leverageEnabled) public
	{
		_self.leverageEnabled = _leverageEnabled;
	}

	function setLeverageAdjustmentAmount(Self storage _self, uint256 _leverageAdjustmentAmount) public
	{
		require(_leverageAdjustmentAmount > 0, "invalid amount");
		_self.leverageAdjustmentAmount = _leverageAdjustmentAmount;
	}

	function setIdealCollateralizationRatio(Self storage _self, uint256 _idealCollateralizationRatio) public
	{
		require(_idealCollateralizationRatio >= MINIMUM_RATIO_GRANULARITY, "invalid ratio");
		require(_idealCollateralizationRatio + MINIMUM_RATIO_GRANULARITY <= _self.limitCollateralizationRatio, "invalid ratio gap");
		_self.idealCollateralizationRatio = _idealCollateralizationRatio;
	}

	function setLimitCollateralizationRatio(Self storage _self, uint256 _limitCollateralizationRatio) public
	{
		require(_limitCollateralizationRatio + MINIMUM_RATIO_GRANULARITY <= 1e18, "invalid ratio");
		require(_self.idealCollateralizationRatio + MINIMUM_RATIO_GRANULARITY <= _limitCollateralizationRatio, "invalid ratio gap");
		_self.limitCollateralizationRatio = _limitCollateralizationRatio;
	}

	function setCollateralizationDeviationRatio(Self storage _self, uint256 _collateralizationDeviationRatio) public
	{
		require(_collateralizationDeviationRatio <= MINIMUM_RATIO_GRANULARITY, "invalid ratio");
		_self.collateralizationDeviationRatio = _collateralizationDeviationRatio;
	}

	function estimateBorrowInUnderlying(Self storage _self, uint256 _borrowAmount) public view returns (uint256 _underlyingAmount)
	{
		return _self._calcConversionUnderlyingToBorrowGivenBorrow(_borrowAmount);
	}

	function ensureLiquidity(Self storage _self, uint256 _requiredAmount) public returns (bool _success)
	{
		uint256 _availableAmount = _self._getAvailableUnderlying();
		for (uint256 _i; _i < DELEVERAGING_UNROLL_LIMIT; _i++) {
			$.debug("ensureLiquidity::_i", _i);
			$.debug("ensureLiquidity::_availableAmount", _availableAmount);
			if (_requiredAmount <= _availableAmount) return true;
			_success = _self._decreaseLeverage(_requiredAmount.sub(_availableAmount));
			if (!_success) return false;
			uint256 _newAvailableAmount = _self._getAvailableUnderlying();
			if (_newAvailableAmount <= _availableAmount) return false;
			_availableAmount = _newAvailableAmount;
		}
		return false;
	}

	function gulpMiningAssets(Self storage _self) public returns (bool _success)
	{
		uint256 _availableAmount = G.getBalance(_self.miningToken);
		uint256 _estimateAmount = _self._calcConversionUnderlyingToMiningGivenMining(_availableAmount);
		uint256 _limitAmount = G.min(_estimateAmount, _self.leverageAdjustmentAmount);
		uint256 _conversionAmount = _estimateAmount > 0 ? _availableAmount.mul(_limitAmount).div(_estimateAmount) : 0;
		_self._convertMiningToUnderlying(_conversionAmount);
		return G.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
	}

	function adjustLeverage(Self storage _self) public returns (bool _success)
	{
		uint256 _borrowAmount = _self._calcConversionUnderlyingToBorrowGivenBorrow(G.fetchBorrowAmount(_self.leverageToken));
		$.debug("adjustLeverage::_borrowAmount", _borrowAmount);
		if (!_self.leverageEnabled) return _self._decreaseLeverageLimited(_borrowAmount);
		uint256 _lendAmount = G.fetchLendAmount(_self.reserveToken);
		$.debug("adjustLeverage::_lendAmount", _lendAmount);
		uint256 _idealAmount = _self._calcIdealAmount(_lendAmount);
		$.debug("adjustLeverage::_idealAmount", _idealAmount);
		uint256 _deviationAmount = _self._calcDeviationAmount(_lendAmount);
		$.debug("adjustLeverage::_deviationAmount", _deviationAmount);
		if (_borrowAmount < _idealAmount.sub(_deviationAmount)) return _self._increaseLeverageLimited(_idealAmount.sub(_borrowAmount));
		if (_borrowAmount > _idealAmount.add(_deviationAmount)) return _self._decreaseLeverageLimited(_borrowAmount.sub(_idealAmount));
		return true;
	}

	function _getAvailableUnderlying(Self storage _self) internal view returns (uint256 _availableUnderlying)
	{
		uint256 _lendAmount = G.getLendAmount(_self.reserveToken);
		uint256 _deathAmount = _self._calcDeathAmount(_lendAmount);
		uint256 _limitAmount = _self._calcLimitAmount(_lendAmount);
		uint256 _marginAmount = _deathAmount.sub(_limitAmount);
		return G.getAvailableAmount(_self.reserveToken, _marginAmount);
	}

	function _getAvailableBorrow(Self storage _self) internal view returns (uint256 _availableBorrow)
	{
		uint256 _lendAmount = G.getLendAmount(_self.reserveToken);
		uint256 _deathAmount = _self._calcDeathAmount(_lendAmount);
		uint256 _idealAmount = _self._calcIdealAmount(_lendAmount);
		uint256 _marginAmount = _deathAmount.sub(_idealAmount);
		return _self._calcConversionUnderlyingToBorrowGivenUnderlying(G.getAvailableAmount(_self.reserveToken, _marginAmount));
	}

	function _calcIdealAmount(Self storage _self, uint256 _amount) internal view returns (uint256 _idealAmount)
	{
		return _amount.mul(G.getCollateralRatio(_self.reserveToken)).mul(_self.idealCollateralizationRatio).div(1e36);
	}

	function _calcLimitAmount(Self storage _self, uint256 _amount) internal view returns (uint256 _limitAmount)
	{
		return _amount.mul(G.getCollateralRatio(_self.reserveToken)).mul(_self.limitCollateralizationRatio).div(1e36);
	}

	function _calcDeathAmount(Self storage _self, uint256 _amount) internal view returns (uint256 _limitAmount)
	{
		return _amount.mul(G.getCollateralRatio(_self.reserveToken)).div(1e18);
	}

	function _calcDeviationAmount(Self storage _self, uint256 _amount) internal view returns (uint256 _deviationAmount)
	{
		return _amount.mul(G.getCollateralRatio(_self.reserveToken)).mul(_self.collateralizationDeviationRatio).div(1e36);
	}

	function _increaseLeverageLimited(Self storage _self, uint256 _amount) internal returns (bool _success)
	{
		return _self._increaseLeverage(G.min(_amount, _self.leverageAdjustmentAmount));
	}

	function _decreaseLeverageLimited(Self storage _self, uint256 _amount) internal returns (bool _success)
	{
		return _self._decreaseLeverage(G.min(_amount, _self.leverageAdjustmentAmount));
	}

	function _increaseLeverage(Self storage _self, uint256 _amount) internal returns (bool _success)
	{
		$.debug("_increaseLeverage::_amount", _amount);
		uint256 _convertedAmount = _self._calcConversionUnderlyingToBorrowGivenUnderlying(_amount);
		$.debug("_increaseLeverage::_convertedAmount", _convertedAmount);
		uint256 _availableAmount = _self._getAvailableBorrow();
		$.debug("_increaseLeverage::_availableAmount", _availableAmount);
		bool _success1 = G.borrow(_self.leverageToken, G.min(_convertedAmount, _availableAmount));
		$.debug("_increaseLeverage::_success1", _success1 ? 1 : 0);
		_self._convertBorrowToUnderlying(G.getBalance(_self.borrowToken));
		bool _success2 = G.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
		$.debug("_increaseLeverage::_success2", _success2 ? 1 : 0);
		_self._convertUnderlyingToBorrow(G.getBalance(_self.underlyingToken));
		G.repay(_self.leverageToken, G.min(G.getBalance(_self.borrowToken), G.getBorrowAmount(_self.leverageToken)));
		return _success1 && _success2;
	}

	function _decreaseLeverage(Self storage _self, uint256 _amount) internal returns (bool _success)
	{
		$.debug("_decreaseLeverage::_amount", _amount);
		uint256 _convertedAmount = _self._calcConversionUnderlyingToBorrowGivenBorrow(_self._calcConversionBorrowToUnderlyingGivenUnderlying(_amount));
		$.debug("_decreaseLeverage::_convertedAmount", _convertedAmount);
		uint256 _availableAmount = _self._getAvailableUnderlying();
		$.debug("_decreaseLeverage::_availableAmount", _availableAmount);
		bool _success1 = G.redeem(_self.reserveToken, G.min(_convertedAmount, _availableAmount));
		$.debug("_decreaseLeverage::_success1", _success1 ? 1 : 0);
		_self._convertUnderlyingToBorrow(G.getBalance(_self.underlyingToken));
		bool _success2 = G.repay(_self.leverageToken, G.min(G.getBalance(_self.borrowToken), G.getBorrowAmount(_self.leverageToken)));
		$.debug("_decreaseLeverage::_success2", _success2 ? 1 : 0);
		_self._convertBorrowToUnderlying(G.getBalance(_self.borrowToken));
		G.lend(_self.reserveToken, G.getBalance(_self.underlyingToken));
		return _success1 && _success2;
	}

	function _calcConversionUnderlyingToMiningGivenMining(Self storage _self, uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		if (_self.miningToken == _self.underlyingToken) return _outputAmount;
		return G.calcConversionInputFromOutput(_self.underlyingToken, _self.miningToken, _outputAmount);
	}

	function _calcConversionUnderlyingToBorrowGivenUnderlying(Self storage _self, uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		if (_self.borrowToken == _self.underlyingToken) return _inputAmount;
		return G.calcConversionOutputFromInput(_self.underlyingToken, _self.borrowToken, _inputAmount);
	}

	function _calcConversionUnderlyingToBorrowGivenBorrow(Self storage _self, uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		if (_self.borrowToken == _self.underlyingToken) return _outputAmount;
		return G.calcConversionInputFromOutput(_self.underlyingToken, _self.borrowToken, _outputAmount);
	}

	function _calcConversionBorrowToUnderlyingGivenUnderlying(Self storage _self, uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		if (_self.borrowToken == _self.underlyingToken) return _outputAmount;
		return G.calcConversionInputFromOutput(_self.borrowToken, _self.underlyingToken, _outputAmount);
	}

	function _convertMiningToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		if (_self.miningToken == _self.underlyingToken) return;
		G.convertFunds(_self.miningToken, _self.underlyingToken, _inputAmount, 0);
	}

	function _convertBorrowToUnderlying(Self storage _self, uint256 _inputAmount) internal
	{
		if (_self.borrowToken == _self.underlyingToken) return;
		G.convertFunds(_self.borrowToken, _self.underlyingToken, _inputAmount, 0);
	}

	function _convertUnderlyingToBorrow(Self storage _self, uint256 _inputAmount) internal
	{
		if (_self.borrowToken == _self.underlyingToken) return;
		G.convertFunds(_self.underlyingToken, _self.borrowToken, _inputAmount, 0);
	}
}
