// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { Math } from "./modules/Math.sol";
import { Wrapping } from "./modules/Wrapping.sol";
import { Transfers } from "./modules/Transfers.sol";
import { Conversions } from "./modules/Conversions.sol";
import { FlashLoans } from "./modules/FlashLoans.sol";
import { BalancerLiquidityPoolAbstraction } from "./modules/BalancerLiquidityPoolAbstraction.sol";
import { CompoundLendingMarketAbstraction } from "./modules/CompoundLendingMarketAbstraction.sol";

/**
 * @dev This public library provides a single entrypoint to all the relevant
 *      internal libraries available in the modules folder. It exists to
 *      circunvent the contract size limitation imposed by the EVM. All function
 *      calls are directly delegated to the target library function preserving
 *      argument and return values exactly as they are. Thit library is shared
 *      by all contracts and even other public libraries from this repository,
 *      therefore it needs to be published alongside them.
 */
library G
{
	function min(uint256 _amount1, uint256 _amount2) public pure returns (uint256 _minAmount) { return Math._min(_amount1, _amount2); }
//	function max(uint256 _amount1, uint256 _amount2) public pure returns (uint256 _maxAmount) { return Math._max(_amount1, _amount2); }

//	function wrap(uint256 _amount) public returns (bool _success) { return Wrapping._wrap(_amount); }
//	function unwrap(uint256 _amount) public returns (bool _success) { return Wrapping._unwrap(_amount); }
	function safeWrap(uint256 _amount) public { Wrapping._safeWrap(_amount); }
	function safeUnwrap(uint256 _amount) public { Wrapping._safeUnwrap(_amount); }

	function getBalance(address _token) public view returns (uint256 _balance) { return Transfers._getBalance(_token); }
	function pullFunds(address _token, address _from, uint256 _amount) public { Transfers._pullFunds(_token, _from, _amount); }
	function pushFunds(address _token, address _to, uint256 _amount) public { Transfers._pushFunds(_token, _to, _amount); }
	function approveFunds(address _token, address _to, uint256 _amount) public { Transfers._approveFunds(_token, _to, _amount); }

//	function calcConversionOutputFromInput(address _from, address _to, uint256 _inputAmount) public view returns (uint256 _outputAmount) { return Conversions._calcConversionOutputFromInput(_from, _to, _inputAmount); }
//	function calcConversionInputFromOutput(address _from, address _to, uint256 _outputAmount) public view returns (uint256 _inputAmount) { return Conversions._calcConversionInputFromOutput(_from, _to, _outputAmount); }
//	function convertFunds(address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) public returns (uint256 _outputAmount) { return Conversions._convertFunds(_from, _to, _inputAmount, _minOutputAmount); }
	function dynamicConvertFunds(address _exchange, address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) public returns (uint256 _outputAmount) { return Conversions._dynamicConvertFunds(_exchange, _from, _to, _inputAmount, _minOutputAmount); }

//	function estimateFlashLoanFee(FlashLoans.Provider _provider, address _token, uint256 _netAmount) public pure returns (uint256 _feeAmount) { return FlashLoans._estimateFlashLoanFee(_provider, _token, _netAmount); }
	function getFlashLoanLiquidity(address _token) public view returns (uint256 _liquidityAmount) { return FlashLoans._getFlashLoanLiquidity(_token); }
	function requestFlashLoan(address _token, uint256 _amount, bytes memory _context) public returns (bool _success) { return FlashLoans._requestFlashLoan(_token, _amount, _context); }
	function paybackFlashLoan(FlashLoans.Provider _provider, address _token, uint256 _grossAmount) public { FlashLoans._paybackFlashLoan(_provider, _token, _grossAmount); }

	function createPool(address _token0, uint256 _amount0, address _token1, uint256 _amount1) public returns (address _pool) { return BalancerLiquidityPoolAbstraction._createPool(_token0, _amount0, _token1, _amount1); }
	function joinPool(address _pool, address _token, uint256 _maxAmount) public returns (uint256 _amount) { return BalancerLiquidityPoolAbstraction._joinPool(_pool, _token, _maxAmount); }
	function exitPool(address _pool, uint256 _percent) public returns (uint256 _amount0, uint256 _amount1) { return BalancerLiquidityPoolAbstraction._exitPool(_pool, _percent); }

	function getUnderlyingToken(address _ctoken) public view returns (address _token) { return CompoundLendingMarketAbstraction._getUnderlyingToken(_ctoken); }
	function getCollateralRatio(address _ctoken) public view returns (uint256 _collateralFactor) { return CompoundLendingMarketAbstraction._getCollateralRatio(_ctoken); }
//	function getMarketAmount(address _ctoken) public view returns (uint256 _marketAmount) { return CompoundLendingMarketAbstraction._getMarketAmount(_ctoken); }
	function getLiquidityAmount(address _ctoken) public view returns (uint256 _liquidityAmount) { return CompoundLendingMarketAbstraction._getLiquidityAmount(_ctoken); }
//	function getAvailableAmount(address _ctoken, uint256 _marginAmount) public view returns (uint256 _availableAmount) { return CompoundLendingMarketAbstraction._getAvailableAmount(_ctoken, _marginAmount); }
	function getExchangeRate(address _ctoken) public view returns (uint256 _exchangeRate) { return CompoundLendingMarketAbstraction._getExchangeRate(_ctoken); }
	function fetchExchangeRate(address _ctoken) public returns (uint256 _exchangeRate) { return CompoundLendingMarketAbstraction._fetchExchangeRate(_ctoken); }
	function getLendAmount(address _ctoken) public view returns (uint256 _amount) { return CompoundLendingMarketAbstraction._getLendAmount(_ctoken); }
	function fetchLendAmount(address _ctoken) public returns (uint256 _amount) { return CompoundLendingMarketAbstraction._fetchLendAmount(_ctoken); }
	function getBorrowAmount(address _ctoken) public view returns (uint256 _amount) { return CompoundLendingMarketAbstraction._getBorrowAmount(_ctoken); }
	function fetchBorrowAmount(address _ctoken) public returns (uint256 _amount) { return CompoundLendingMarketAbstraction._fetchBorrowAmount(_ctoken); }
//	function enter(address _ctoken) public returns (bool _success) { return CompoundLendingMarketAbstraction._enter(_ctoken); }
	function lend(address _ctoken, uint256 _amount) public returns (bool _success) { return CompoundLendingMarketAbstraction._lend(_ctoken, _amount); }
	function redeem(address _ctoken, uint256 _amount) public returns (bool _success) { return CompoundLendingMarketAbstraction._redeem(_ctoken, _amount); }
	function borrow(address _ctoken, uint256 _amount) public returns (bool _success) { return CompoundLendingMarketAbstraction._borrow(_ctoken, _amount); }
	function repay(address _ctoken, uint256 _amount) public returns (bool _success) { return CompoundLendingMarketAbstraction._repay(_ctoken, _amount); }
//	function safeEnter(address _ctoken) public { CompoundLendingMarketAbstraction._safeEnter(_ctoken); }
	function safeLend(address _ctoken, uint256 _amount) public { CompoundLendingMarketAbstraction._safeLend(_ctoken, _amount); }
	function safeRedeem(address _ctoken, uint256 _amount) public { CompoundLendingMarketAbstraction._safeRedeem(_ctoken, _amount); }
//	function safeBorrow(address _ctoken, uint256 _amount) public { CompoundLendingMarketAbstraction._safeBorrow(_ctoken, _amount); }
//	function safeRepay(address _ctoken, uint256 _amount) public { CompoundLendingMarketAbstraction._safeRepay(_ctoken, _amount); }
}
