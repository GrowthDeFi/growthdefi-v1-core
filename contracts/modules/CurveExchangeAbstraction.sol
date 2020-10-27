// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Transfers } from "./Transfers.sol";

import { Swap } from "../interop/Curve.sol";

import { $ } from "../network/$.sol";

library CurveExchangeAbstraction
{
	using SafeMath for uint256;

	function _calcConversionDAIToUSDCGivenDAI(uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		address _swap = $.Curve_COMPOUND;
		return Swap(_swap).get_dy_underlying(0, 1, _inputAmount);
	}

	function _calcConversionDAIToUSDCGivenUSDC(uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		address _swap = $.Curve_COMPOUND;
		return Swap(_swap).get_dx_underlying(0, 1, _outputAmount);
	}

	function _calcConversionUSDCToDAIGivenUSDC(uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		address _swap = $.Curve_COMPOUND;
		return Swap(_swap).get_dy_underlying(1, 0, _inputAmount);
	}

	function _calcConversionUSDCToDAIGivenDAI(uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		address _swap = $.Curve_COMPOUND;
		return Swap(_swap).get_dx_underlying(1, 0, _outputAmount);
	}

	function _convertFundsUSDCToDAI(uint256 _inputAmount, uint256 _minOutputAmount) internal returns (uint256 _outputAmount)
	{
		address _swap = $.Curve_COMPOUND;
		address _from = Swap(_swap).underlying_coins(1);
		address _to = Swap(_swap).underlying_coins(0);
		uint256 _oldBalance = Transfers._getBalance(_to);
		Transfers._approveFunds(_from, _swap, _inputAmount);
		Swap(_swap).exchange_underlying(1, 0, _inputAmount, _minOutputAmount);
		uint256 _newBalance = Transfers._getBalance(_to);
		return _newBalance.sub(_oldBalance);
	}

	function _convertFundsDAIToUSDC(uint256 _inputAmount, uint256 _minOutputAmount) internal returns (uint256 _outputAmount)
	{
		address _swap = $.Curve_COMPOUND;
		address _from = Swap(_swap).underlying_coins(0);
		address _to = Swap(_swap).underlying_coins(1);
		uint256 _oldBalance = Transfers._getBalance(_to);
		Transfers._approveFunds(_from, _swap, _inputAmount);
		Swap(_swap).exchange_underlying(0, 1, _inputAmount, _minOutputAmount);
		uint256 _newBalance = Transfers._getBalance(_to);
		return _newBalance.sub(_oldBalance);
	}
}
