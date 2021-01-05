// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Math } from "./Math.sol";
import { Transfers } from "./Transfers.sol";

import { Pair, Router02 } from "../interop/UniswapV2.sol";

import { $ } from "../network/$.sol";

library UniswapV2LiquidityPoolAbstraction
{
	using SafeMath for uint256;

	function _joinPool(address _pair, address _token, uint256 _amount, uint256 _minShares) internal returns (uint256 _shares)
	{
		if (_amount == 0) return 0;
		address _router = $.UniswapV2_ROUTER02;
		address _token0 = Pair(_pair).token0();
		address _token1 = Pair(_pair).token1();
		address _otherToken = _token == _token0 ? _token1 : _token0;
		(uint256 _reserve0, uint256 _reserve1,) = Pair(_pair).getReserves();
		uint256 _swapAmount = _calcSwapOutputFromInput(_token == _token0 ? _reserve0 : _reserve1, _amount);
		if (_swapAmount == 0) _swapAmount = _amount.div(2);
		uint256 _leftAmount = _amount.sub(_swapAmount);
		Transfers._approveFunds(_token, _router, _swapAmount);
		address[] memory _path = new address[](2);
		_path[0] = _token;
		_path[1] = _otherToken;
		uint256 _otherAmount = Router02(_router).swapExactTokensForTokens(_swapAmount, 1, _path, address(this), uint256(-1))[_path.length - 1];
		Transfers._approveFunds(_token, _router, _leftAmount);
		Transfers._approveFunds(_otherToken, _router, _otherAmount);
		(,,_shares) = Router02(_router).addLiquidity(_token, _otherToken, _leftAmount, _otherAmount, 1, 1, address(this), uint256(-1));
		require(_shares >= _minShares, "high slippage");
		return _shares;
	}

	function _calcSwapOutputFromInput(uint256 _reserveAmount, uint256 _inputAmount) internal pure returns (uint256)
	{
		return Math._sqrt(_reserveAmount.mul(_inputAmount.mul(3988000).add(_reserveAmount.mul(3988009)))).sub(_reserveAmount.mul(1997)) / 1994;
	}
}
