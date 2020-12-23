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

	uint256 constant DEFAULT_PERIOD = 24 hours;

	struct Self {
		address pair;
		bool use0;

		uint256 period;

		uint256 priceCumulativeLast;
		uint32 blockTimestampLast;
		FixedPoint.uq112x112 priceAverage;
	}

	function init(Self storage _self) public
	{
		_self.pair = address(0);

		_self.period = DEFAULT_PERIOD;
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

	function changePeriod(Self storage _self, uint256 _period) public
	{
		require(_period > 0, "invalid period");
		_self.period = _period;
	}

	function update(Self storage _self) public
	{
		require(_self._active(), "not active");

		(uint256 _price0Cumulative, uint256 _price1Cumulative, uint32 _blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(_self.pair);
		uint256 _priceCumulative = _self.use0 ? _price0Cumulative : _price1Cumulative;

		uint32 _timeElapsed = _blockTimestamp - _self.blockTimestampLast; // overflow is desired

		// ensure that at least one full period has passed since the last update
		require(_timeElapsed >= _self.period, "period not elapsed");

		// overflow is desired, casting never truncates
		// cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
		_self.priceAverage = FixedPoint.uq112x112(uint224((_priceCumulative - _self.priceCumulativeLast) / _timeElapsed));

		_self.priceCumulativeLast = _priceCumulative;
		_self.blockTimestampLast = _blockTimestamp;
	}

	function consult(Self storage _self, uint256 _amountIn) public view returns (uint256 _amountOut)
	{
		return _self.priceAverage.mul(_amountIn).decode144();
	}

	function _active(Self storage _self) internal view returns (bool _isActive)
	{
		return _self.pair != address(0);
	}
}
