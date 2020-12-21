// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { UniswapV2OracleLibrary } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";

library GPriceOracle
{
	using GPriceOracle for GPriceOracle.Self;

	struct Self {
		address pair;
		bool use0;

		uint256 lastCumulativePrice;
		uint32 lastBlockTimestamp;
	}

	function init(Self storage _self) public
	{
		_self.pair = address(0);
		_self.use0 = false;

		_self.lastCumulativePrice = 0;
		_self.lastBlockTimestamp = 0;
	}

	function active(Self storage _self) public view returns (bool _isActive)
	{
		return _self._active();
	}

	function activate(Self storage _self, address _pair, bool _use0) public
	{
		require(!_self._active(), "already active");
		require(_pair != address(0), "invalid pair");
		_self.pair = _pair;
		_self.use0 = _use0;
		(_self.lastCumulativePrice, _self.lastBlockTimestamp) = _self._getCumulativePrice();
	}

	function getPrice(Self storage _self) public view returns (uint256 _price)
	{
		(,,_price) = _self._getPrice();
		return _price;
	}

	function updatePrice(Self storage _self) public returns (uint256 _price)
	{
		(_self.lastCumulativePrice, _self.lastBlockTimestamp, _price) = _self._getPrice();
		return _price;
	}

	function _getPrice(Self storage _self) internal view returns (uint256 _cumulativePrice, uint32 _blockTimestamp, uint256 _price)
	{
		(uint256 _oldCumulativePrice, uint32 _oldBlockTimestamp) = (_self.lastCumulativePrice, _self.lastBlockTimestamp);

		(uint256 _newCumulativePrice, uint32 _newBlockTimestamp) = _self._getCumulativePrice();

		uint256 _priceAverage = uint256(uint224((_newCumulativePrice - _oldCumulativePrice) / (_newBlockTimestamp - _oldBlockTimestamp)));

		_price = _priceAverage > uint192(-1) ? (_priceAverage >> 112) * 1e18 : (_priceAverage * 1e18) >> 112;

		return (_cumulativePrice, _blockTimestamp, _price);
	}

	function _getCumulativePrice(Self storage _self) internal view returns (uint256 _cumulativePrice, uint32 _blockTimestamp)
	{
		require(_self._active(), "not active");
		(uint256 _price0, uint256 _price1, uint32 _time) = UniswapV2OracleLibrary.currentCumulativePrices(_self.pair);
		assert(_time > 0);
		_cumulativePrice = _self.use0 ? _price0 : _price1;
		_blockTimestamp = _time;
		return (_cumulativePrice, _blockTimestamp);
	}

	function _active(Self storage _self) internal view returns (bool _isActive)
	{
		return _self.pair != address(0);
	}
}
