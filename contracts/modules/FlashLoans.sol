// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Math } from "./Math.sol";
import { AaveFlashLoanAbstraction } from "./AaveFlashLoanAbstraction.sol";
import { DydxFlashLoanAbstraction } from "./DydxFlashLoanAbstraction.sol";

import { $ } from "../network/$.sol";

library FlashLoans
{
	enum Provider { Aave, Dydx }

	function _estimateFlashLoanFee(Provider _provider, address _token, uint256 _netAmount) internal pure returns (uint256 _feeAmount)
	{
		if (_provider == Provider.Aave) return AaveFlashLoanAbstraction._estimateFlashLoanFee(_token, _netAmount);
		if (_provider == Provider.Dydx) return DydxFlashLoanAbstraction._estimateFlashLoanFee(_token, _netAmount);
	}

	function _getFlashLoanLiquidity(address _token) internal view returns (uint256 _liquidityAmount)
	{
		uint256 _liquidityAmountDydx = 0;
		if ($.NETWORK == $.Network.Mainnet || $.NETWORK == $.Network.Kovan) {
			_liquidityAmountDydx = DydxFlashLoanAbstraction._getFlashLoanLiquidity(_token);
		}
		uint256 _liquidityAmountAave = 0;
		if ($.NETWORK == $.Network.Mainnet || $.NETWORK == $.Network.Ropsten || $.NETWORK == $.Network.Kovan) {
			_liquidityAmountAave = AaveFlashLoanAbstraction._getFlashLoanLiquidity(_token);
		}
		return Math._max(_liquidityAmountDydx, _liquidityAmountAave);
	}

	function _requestFlashLoan(address _token, uint256 _netAmount, bytes memory _context) internal returns (bool _success)
	{
		if ($.NETWORK == $.Network.Mainnet || $.NETWORK == $.Network.Kovan) {
			_success = DydxFlashLoanAbstraction._requestFlashLoan(_token, _netAmount, _context);
			if (_success) return true;
		}
		if ($.NETWORK == $.Network.Mainnet || $.NETWORK == $.Network.Ropsten || $.NETWORK == $.Network.Kovan) {
			_success = AaveFlashLoanAbstraction._requestFlashLoan(_token, _netAmount, _context);
			if (_success) return true;
		}
		return false;
	}

	function _paybackFlashLoan(Provider _provider, address _token, uint256 _grossAmount) internal
	{
		if (_provider == Provider.Aave) return AaveFlashLoanAbstraction._paybackFlashLoan(_token, _grossAmount);
		if (_provider == Provider.Dydx) return DydxFlashLoanAbstraction._paybackFlashLoan(_token, _grossAmount);
	}
}
