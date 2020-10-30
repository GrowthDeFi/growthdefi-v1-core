// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Transfers } from "./Transfers.sol";

import { LendingPool, LendingPoolCore } from "../interop/Aave.sol";

import { $ } from "../network/$.sol";

library AaveFlashLoanAbstraction
{
	using SafeMath for uint256;

	uint256 constant FLASH_LOAN_FEE_RATIO = 9e14; // 0.09%

	function _estimateFlashLoanFee(address /* _token */, uint256 _netAmount) internal pure returns (uint256 _feeAmount)
	{
		return _netAmount.mul(FLASH_LOAN_FEE_RATIO).div(1e18);
	}

	function _getFlashLoanLiquidity(address _token) internal view returns (uint256 _liquidityAmount)
	{
		address _core = $.Aave_AAVE_LENDING_POOL_CORE;
		return LendingPoolCore(_core).getReserveAvailableLiquidity(_token);
	}

	function _requestFlashLoan(address _token, uint256 _netAmount, bytes memory _context) internal returns (bool _success)
	{
		address _pool = $.Aave_AAVE_LENDING_POOL;
		try LendingPool(_pool).flashLoan(address(this), _token, _netAmount, _context) {
			return true;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _paybackFlashLoan(address _token, uint256 _grossAmount) internal
	{
		address _poolCore = $.Aave_AAVE_LENDING_POOL_CORE;
		Transfers._pushFunds(_token, _poolCore, _grossAmount);
	}
}
