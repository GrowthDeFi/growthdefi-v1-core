// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Transfers } from "./Transfers.sol";

import { LendingPool } from "../interop/Aave.sol";

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
		address _pool = $.Aave_AAVE_LENDING_POOL;
		// this is the code in solidity, but does not compile
		//	try LendingPool(_pool).getReserveData(_token) returns (uint256 _totalLiquidity, uint256 _availableLiquidity, uint256 _totalBorrowsStable, uint256 _totalBorrowsVariable, uint256 _liquidityRate, uint256 _variableBorrowRate, uint256 _stableBorrowRate, uint256 _averageStableBorrowRate, uint256 _utilizationRate, uint256 _liquidityIndex, uint256 _variableBorrowIndex, address _aTokenAddress, uint40 _lastUpdateTimestamp) {
		//		return _availableLiquidity;
		//	} catch (bytes memory /* _data */) {
		//		return 0;
		//	}
		// we use EVM assembly instead
		bytes memory _data = abi.encodeWithSignature("getReserveData(address)", _token);
		uint256[2] memory _result;
		assembly {
			let _success := staticcall(gas(), _pool, add(_data, 32), mload(_data), _result, 64)
			if iszero(_success) {
				mstore(add(_result, 32), 0)
			}
		}
		return _result[1];
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
