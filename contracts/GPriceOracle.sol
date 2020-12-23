// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { FixedPoint } from "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import { UniswapV2OracleLibrary } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";

import { Pair } from "./interop/UniswapV2.sol";

// based on https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleOracleSimple.sol
library GPriceOracle
{
	using FixedPoint for FixedPoint.uq112x112;
	using FixedPoint for FixedPoint.uq144x112;
	using GPriceOracle for GPriceOracle.Self;

	uint256 constant DEFAULT_MINIMUM_INTERVAL = 23 hours;

	struct Self {
		address pair;
		bool use0;

		uint256 minimumInterval;

		uint256 priceCumulativeLast;
		uint32 blockTimestampLast;
		FixedPoint.uq112x112 priceAverage;
	}

	function init(Self storage _self) public
	{
		_self.pair = address(0);

		_self.minimumInterval = DEFAULT_MINIMUM_INTERVAL;
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

		_self.priceCumulativeLast = _use0 ? Pair(_pair).price0CumulativeLast() : Pair(_pair).price1CumulativeLast();

		uint112 reserve0;
		uint112 reserve1;
		(reserve0, reserve1, _self.blockTimestampLast) = Pair(_pair).getReserves();
		require(reserve0 > 0 && reserve1 > 0, "no reserves"); // ensure that there's liquidity in the pair
	}

	function changeMinimumInterval(Self storage _self, uint256 _minimumInterval) public
	{
		require(_minimumInterval > 0, "invalid interval");
		_self.minimumInterval = _minimumInterval;
	}

	function consultLastPrice(Self storage _self, uint256 _amountIn) public view returns (uint256 _amountOut)
	{
		require(_self._active(), "not active");

		return _self.priceAverage.mul(_amountIn).decode144();
	}

	function consultCurrentPrice(Self storage _self, uint256 _amountIn) public view returns (uint256 _amountOut)
	{
		require(_self._active(), "not active");

		(,, FixedPoint.uq112x112 memory _priceAverage) = _self._estimatePrice(false);
		return _priceAverage.mul(_amountIn).decode144();
	}

	function updatePrice(Self storage _self) public
	{
		require(_self._active(), "not active");

		(_self.priceCumulativeLast, _self.blockTimestampLast, _self.priceAverage) = _self._estimatePrice(true);
	}

	function _active(Self storage _self) internal view returns (bool _isActive)
	{
		return _self.pair != address(0);
	}

	function _estimatePrice(Self storage _self, bool _enforceTimeElapsed) internal view returns (uint256 _priceCumulative, uint32 _blockTimestamp, FixedPoint.uq112x112 memory _priceAverage)
	{
		uint256 _price0Cumulative;
		uint256 _price1Cumulative;
		(_price0Cumulative, _price1Cumulative, _blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(_self.pair);
		_priceCumulative = _self.use0 ? _price0Cumulative : _price1Cumulative;

		uint32 _timeElapsed = _blockTimestamp - _self.blockTimestampLast; // overflow is desired

		// ensure that at least one full interval has passed since the last update
		if (_enforceTimeElapsed) {
			require(_timeElapsed >= _self.minimumInterval, "minimum interval not elapsed");
		}

		// overflow is desired, casting never truncates
		// cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
		_priceAverage = FixedPoint.uq112x112(uint224((_priceCumulative - _self.priceCumulativeLast) / _timeElapsed));
	}
}
