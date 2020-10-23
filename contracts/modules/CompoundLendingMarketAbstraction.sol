// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Math } from "./Math.sol";
import { Wrapping } from "./Wrapping.sol";
import { Transfers } from "./Transfers.sol";

import { Comptroller, PriceOracle, CToken } from "../interop/Compound.sol";

import { $ } from "../network/$.sol";

library CompoundLendingMarketAbstraction
{
	using SafeMath for uint256;

	function _getUnderlyingToken(address _ctoken) internal view returns (address _token)
	{
		if (_ctoken == $.cETH) return $.WETH;
		return CToken(_ctoken).underlying();
	}

	function _getCollateralRatio(address _ctoken) internal view returns (uint256 _collateralFactor)
	{
		address _comptroller = $.Compound_COMPTROLLER;
		(, _collateralFactor) = Comptroller(_comptroller).markets(_ctoken);
		return _collateralFactor;
	}

	function _getMarketAmount(address _ctoken) internal view returns (uint256 _marketAmount)
	{
		return CToken(_ctoken).getCash();
	}

	function _getLiquidityAmount(address _ctoken) internal view returns (uint256 _liquidityAmount)
	{
		address _comptroller = $.Compound_COMPTROLLER;
		(uint256 _result, uint256 _liquidity, uint256 _shortfall) = Comptroller(_comptroller).getAccountLiquidity(address(this));
		if (_result != 0) return 0;
		if (_shortfall > 0) return 0;
		address _priceOracle = Comptroller(_comptroller).oracle();
		uint256 _price = PriceOracle(_priceOracle).getUnderlyingPrice(_ctoken);
		return _liquidity.mul(1e18).div(_price);
	}

	function _getAvailableAmount(address _ctoken, uint256 _marginAmount) internal view returns (uint256 _availableAmount)
	{
		uint256 _liquidityAmount = _getLiquidityAmount(_ctoken);
		if (_liquidityAmount <= _marginAmount) return 0;
		return Math._min(_liquidityAmount.sub(_marginAmount), _getMarketAmount(_ctoken));
	}

	function _exchangeRateStored(address _ctoken) internal view returns (uint256 _exchangeRate)
	{
		return CToken(_ctoken).exchangeRateStored();
	}

	function _exchangeRateCurrent(address _ctoken) internal returns (uint256 _exchangeRate)
	{
		return CToken(_ctoken).exchangeRateCurrent();
	}

	function _calcLendAmount(address _ctoken) internal view returns (uint256 _amount)
	{
		return CToken(_ctoken).balanceOf(address(this)).mul(_exchangeRateStored(_ctoken)).div(1e18);
	}

	function _fetchLendAmount(address _ctoken) internal returns (uint256 _amount)
	{
		return CToken(_ctoken).balanceOfUnderlying(address(this));
	}

	function _borrowBalanceStored(address _ctoken) internal view returns (uint256 _amount)
	{
		return CToken(_ctoken).borrowBalanceStored(address(this));
	}

	function _borrowBalanceCurrent(address _ctoken) internal returns (uint256 _amount)
	{
		return CToken(_ctoken).borrowBalanceCurrent(address(this));
	}

	function _enter(address _ctoken) internal returns (bool _success)
	{
		address _comptroller = $.Compound_COMPTROLLER;
		address[] memory _ctokens = new address[](1);
		_ctokens[0] = _ctoken;
		try Comptroller(_comptroller).enterMarkets(_ctokens) returns (uint256[] memory _errorCodes) {
			return _errorCodes[0] == 0;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _lend(address _ctoken, uint256 _amount) internal returns (bool _success)
	{
		if (_ctoken == $.cETH) {
			if (!Wrapping._unwrap(_amount)) return false;
			try CToken(_ctoken).mint{value: _amount}() {
				return true;
			} catch (bytes memory /* _data */) {
				assert(Wrapping._wrap(_amount));
				return false;
			}
		} else {
			address _token = _getUnderlyingToken(_ctoken);
			Transfers._approveFunds(_token, _ctoken, _amount);
			try CToken(_ctoken).mint(_amount) returns (uint256 _errorCode) {
				return _errorCode == 0;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
	}

	function _redeem(address _ctoken, uint256 _amount) internal returns (bool _success)
	{
		if (_ctoken == $.cETH) {
			try CToken(_ctoken).redeemUnderlying(_amount) returns (uint256 _errorCode) {
				if (_errorCode == 0) {
					assert(Wrapping._wrap(_amount));
					return true;
				} else {
					return false;
				}
			} catch (bytes memory /* _data */) {
				return false;
			}
		} else {
			try CToken(_ctoken).redeemUnderlying(_amount) returns (uint256 _errorCode) {
				return _errorCode == 0;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
	}

	function _borrow(address _ctoken, uint256 _amount) internal returns (bool _success)
	{
		if (_ctoken == $.cETH) {
			try CToken(_ctoken).borrow(_amount) returns (uint256 _errorCode) {
				if (_errorCode == 0) {
					assert(Wrapping._wrap(_amount));
					return true;
				} else {
					return false;
				}
			} catch (bytes memory /* _data */) {
				return false;
			}
		} else {
			try CToken(_ctoken).borrow(_amount) returns (uint256 _errorCode) {
				return _errorCode == 0;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
	}

	function _repay(address _ctoken, uint256 _amount) internal returns (bool _success)
	{
		if (_ctoken == $.cETH) {
			if (!Wrapping._unwrap(_amount)) return false;
			try CToken(_ctoken).repayBorrow{value: _amount}() {
				return true;
			} catch (bytes memory /* _data */) {
				assert(Wrapping._wrap(_amount));
				return false;
			}
		} else {
			address _token = _getUnderlyingToken(_ctoken);
			Transfers._approveFunds(_token, _ctoken, _amount);
			try CToken(_ctoken).repayBorrow(_amount) returns (uint256 _errorCode) {
				return _errorCode == 0;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
	}

	function _safeEnter(address _ctoken) internal
	{
		require(_enter(_ctoken), "enter failed");
	}

	function _safeLend(address _ctoken, uint256 _amount) internal
	{
		require(_lend(_ctoken, _amount), "lend failure");
	}

	function _safeRedeem(address _ctoken, uint256 _amount) internal
	{
		require(_redeem(_ctoken, _amount), "redeem failure");
	}

	function _safeBorrow(address _ctoken, uint256 _amount) internal
	{
		require(_borrow(_ctoken, _amount), "borrow failure");
	}

	function _safeRepay(address _ctoken, uint256 _amount) internal
	{
		require(_repay(_ctoken, _amount), "repay failure");
	}
}
