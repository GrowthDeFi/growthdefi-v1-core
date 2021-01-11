// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

library GTimeWeightedAveragePrice_V2
{
	using SafeMath for uint256;
	using GTimeWeightedAveragePrice_V2 for GTimeWeightedAveragePrice_V2.Self;

	struct Self {
		uint256 lastCumulativePrice;
		uint256 lastPrice;
		uint256 lastTime;

		uint256 lastAverageCumulativePrice;
		uint256 lastAveragePrice;
		uint256 lastAverageTime;
		uint256 minimumPeriod;
	}

	function init(Self storage _self) public
	{
		_self.lastCumulativePrice = 0;
		_self.lastPrice = 1;
		_self.lastTime = now;

		_self.lastAverageCumulativePrice = 0;
		_self.lastAveragePrice = 1;
		_self.lastAverageTime = now;
		_self.minimumPeriod = 24 hours;
	}

	function _calcCumulativePrice(Self storage _self, uint256 _currentTime) internal view returns (uint256 _cumulativePrice)
	{
		uint256 _timeEllapsed = _currentTime.sub(_self.lastTime);
		_cumulativePrice += _timeEllapsed.mul(_self.lastPrice);
		return _cumulativePrice;
	}

	function _calcAveragePrice(Self storage _self, uint256 _currentTime) internal view returns (uint256 _averagePrice)
	{
		uint256 _timeEllapsed = _currentTime.sub(_self.lastTime);
		if (_timeEllapsed >= _self.minimumPeriod) {
			return _self.lastPrice;
		} else {
			uint256 _cumulativePrice = _self._calcCumulativePrice(_currentTime);
			_timeEllapsed = _currentTime.sub(_self.lastAverageTime);
			if (_timeEllapsed >= _self.minimumPeriod) {
				uint256 _fixedTime = _timeEllapsed.sub(_self.minimumPeriod);
				return (_cumulativePrice - _self.lastAverageCumulativePrice - _fixedTime.mul(_self.lastAveragePrice)).div(_self.minimumPeriod);
			} else {
				uint256 _fixedTime = _self.minimumPeriod.sub(_timeEllapsed);
				return (_cumulativePrice - _self.lastAverageCumulativePrice + _fixedTime.mul(_self.lastAveragePrice)).div(_self.minimumPeriod);
			}
		}
	}

	function _recordPrice(Self storage _self, uint256 _currentTime, uint256 _currentPrice) internal
	{
		uint256 _cumulativePrice = _self._calcCumulativePrice(_currentTime);
		_self.lastCumulativePrice = _cumulativePrice;
		_self.lastPrice = _currentPrice;
		_self.lastTime = _currentTime;

		uint256 _timeEllapsed = _currentTime.sub(_self.lastAverageTime);
		if (_timeEllapsed >= _self.minimumPeriod) {
			_self.lastAveragePrice = (_cumulativePrice - _self.lastAverageCumulativePrice).div(_timeEllapsed);
			_self.lastAverageCumulativePrice = _cumulativePrice;
			_self.lastAverageTime = _currentTime;
		}
	}
}
