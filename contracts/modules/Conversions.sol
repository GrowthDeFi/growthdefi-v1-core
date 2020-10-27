// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Transfers } from "./Transfers.sol";
import { CurveExchangeAbstraction } from "./CurveExchangeAbstraction.sol";
import { UniswapV2ExchangeAbstraction } from "./UniswapV2ExchangeAbstraction.sol";

import { GExchange } from "../GExchange.sol";

import { $ } from "../network/$.sol";

library Conversions
{
	function _calcConversionOutputFromInput(address _from, address _to, uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		if (_inputAmount == 0) return 0;
		if ($.NETWORK == $.Network.Mainnet) {
			if (_from == $.DAI && _to == $.USDC) return CurveExchangeAbstraction._calcConversionDAIToUSDCGivenDAI(_inputAmount);
			if (_from == $.USDC && _to == $.DAI) return CurveExchangeAbstraction._calcConversionUSDCToDAIGivenUSDC(_inputAmount);
		}
		return UniswapV2ExchangeAbstraction._calcConversionOutputFromInput(_from, _to, _inputAmount);
	}

	function _calcConversionInputFromOutput(address _from, address _to, uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		if (_outputAmount == 0) return 0;
		if ($.NETWORK == $.Network.Mainnet) {
			if (_from == $.DAI && _to == $.USDC) return CurveExchangeAbstraction._calcConversionDAIToUSDCGivenUSDC(_outputAmount);
			if (_from == $.USDC && _to == $.DAI) return CurveExchangeAbstraction._calcConversionUSDCToDAIGivenDAI(_outputAmount);
		}
		return UniswapV2ExchangeAbstraction._calcConversionInputFromOutput(_from, _to, _outputAmount);
	}

	function _convertFunds(address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) internal returns (uint256 _outputAmount)
	{
		if (_inputAmount == 0) {
			require(_minOutputAmount == 0, "insufficient output amount");
			return 0;
		}
		if ($.NETWORK == $.Network.Mainnet) {
			if (_from == $.DAI && _to == $.USDC) return CurveExchangeAbstraction._convertFundsDAIToUSDC(_inputAmount, _minOutputAmount);
			if (_from == $.USDC && _to == $.DAI) return CurveExchangeAbstraction._convertFundsUSDCToDAI(_inputAmount, _minOutputAmount);
		}
		return UniswapV2ExchangeAbstraction._convertFunds(_from, _to, _inputAmount, _minOutputAmount);
	}

	function _dynamicConvertFunds(address _exchange, address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) internal returns (uint256 _outputAmount)
	{
		Transfers._approveFunds(_from, _exchange, _inputAmount);
		try GExchange(_exchange).convertFunds(_from, _to, _inputAmount, _minOutputAmount) returns (uint256 _outAmount) {
			return _outAmount;
		} catch (bytes memory /* _data */) {
			Transfers._approveFunds(_from, _exchange, 0);
			return 0;
		}
	}
}
