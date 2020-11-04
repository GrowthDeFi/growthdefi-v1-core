// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Math } from "./Math.sol";
import { Wrapping } from "./Wrapping.sol";
import { Transfers } from "./Transfers.sol";

import { LendingPoolAddressesProvider, LendingPool, LendingPoolCore, AToken, APriceOracle } from "../interop/Aave.sol";

import { $ } from "../network/$.sol";

library AaveLendingMarketAbstraction
{
	using SafeMath for uint256;

	uint16 constant AAVE_REFERRAL_CODE = 0; // TODO update this referral code

	function _getUnderlyingToken(address _atoken) internal view returns (address _token)
	{
		if (_atoken == $.aETH) return $.WETH;
		return AToken(_atoken).underlyingAssetAddress();
	}

	function _getCollateralRatio(address _atoken) internal view returns (uint256 _collateralFactor)
	{
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		(_collateralFactor,,,,,,,) = LendingPool(_pool).getReserveConfigurationData(_token);
		return _collateralFactor.mul(1e18);
	}

	function _getMarketAmount(address _atoken) internal view returns (uint256 _marketAmount)
	{
		address _core = $.Aave_AAVE_LENDING_POOL_CORE;
		address _token = AToken(_atoken).underlyingAssetAddress();
		return LendingPoolCore(_core).getReserveAvailableLiquidity(_token);
	}

	function _getLiquidityAmount(address _atoken) internal view returns (uint256 _liquidityAmount)
	{
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		(,,,,_liquidityAmount,,,) = LendingPool(_pool).getUserAccountData(address(this));
		if (_atoken == $.aETH) {
			return _liquidityAmount;
		} else {
			address _provider = $.Aave_AAVE_LENDING_POOL_ADDRESSES_PROVIDER;
			address _priceOracle = LendingPoolAddressesProvider(_provider).getPriceOracle();
			uint256 _price = APriceOracle(_priceOracle).getAssetPrice(_token);
			address _core = $.Aave_AAVE_LENDING_POOL_CORE;
			uint256 _decimals = LendingPoolCore(_core).getReserveDecimals(_token);
			if (_decimals > 18) {
				uint256 _factor = 10 ** (_decimals - 18);
				return _liquidityAmount.mul(uint256(1e18).mul(_factor)).div(_price);
			}
			if (_decimals < 18) {
				uint256 _factor = 10 ** (18 - _decimals);
				return _liquidityAmount.mul(1e18).div(_price.mul(_factor));
			}
			return _liquidityAmount.mul(1e18).div(_price);
		}
	}

	function _getAvailableAmount(address _atoken, uint256 _marginAmount) internal view returns (uint256 _availableAmount)
	{
		uint256 _liquidityAmount = _getLiquidityAmount(_atoken);
		if (_liquidityAmount <= _marginAmount) return 0;
		return Math._min(_liquidityAmount.sub(_marginAmount), _getMarketAmount(_atoken));
	}

	function _getExchangeRate(address _atoken) internal pure returns (uint256 _exchangeRate)
	{
		return _fetchExchangeRate(_atoken);
	}

	function _fetchExchangeRate(address /* _atoken */) internal pure returns (uint256 _exchangeRate)
	{
		return 1e18;
	}

	function _getLendAmount(address _atoken) internal view returns (uint256 _amount)
	{
		return _fetchLendAmount(_atoken);
	}

	function _fetchLendAmount(address _atoken) internal view returns (uint256 _amount)
	{
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		(_amount,,,,,,,,,) = LendingPool(_pool).getUserReserveData(_token, address(this));
		return _amount;
	}

	function _getBorrowAmount(address _atoken) internal view returns (uint256 _amount)
	{
		return _fetchBorrowAmount(_atoken);
	}

	function _fetchBorrowAmount(address _atoken) internal view returns (uint256 _amount)
	{
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		(,uint256 _netAmount,,,,,uint256 _feeAmount,,,) = LendingPool(_pool).getUserReserveData(_token, address(this));
		return _netAmount.add(_feeAmount);
	}

	function _enter(address /* _atoken */) internal pure returns (bool _success)
	{
		return true;
	}

	function _lend(address _atoken, uint256 _amount) internal returns (bool _success)
	{
		if (_amount == 0) return true;
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		if (_atoken == $.aETH) {
			if (!Wrapping._unwrap(_amount)) return false;
			try LendingPool(_pool).deposit{value: _amount}(_token, _amount, AAVE_REFERRAL_CODE) {
				return true;
			} catch (bytes memory /* _data */) {
				assert(Wrapping._wrap(_amount));
				return false;
			}
		} else {
			address _core = $.Aave_AAVE_LENDING_POOL_CORE;
			Transfers._approveFunds(_token, _core, _amount);
			try LendingPool(_pool).deposit(_token, _amount, AAVE_REFERRAL_CODE) {
				return true;
			} catch (bytes memory /* _data */) {
				Transfers._approveFunds(_token, _core, 0);
				return false;
			}
		}
	}

	function _redeem(address _atoken, uint256 _amount) internal returns (bool _success)
	{
		if (_amount == 0) return true;
		if (_atoken == $.aETH) {
			try AToken(_atoken).redeem(_amount) {
				assert(Wrapping._wrap(_amount));
				return true;
			} catch (bytes memory /* _data */) {
				return false;
			}
		} else {
			try AToken(_atoken).redeem(_amount) {
				return true;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
	}

	function _borrow(address _atoken, uint256 _amount) internal returns (bool _success)
	{
		if (_amount == 0) return true;
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		if (_atoken == $.aETH) {
			try LendingPool(_pool).borrow(_token, _amount, 2, AAVE_REFERRAL_CODE) {
				assert(Wrapping._wrap(_amount));
				return true;
			} catch (bytes memory /* _data */) {
				return false;
			}
		} else {
			try LendingPool(_pool).borrow(_token, _amount, 2, AAVE_REFERRAL_CODE) {
				return true;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
	}

	function _repay(address _atoken, uint256 _amount) internal returns (bool _success)
	{
		if (_amount == 0) return true;
		address _pool = $.Aave_AAVE_LENDING_POOL;
		address _token = AToken(_atoken).underlyingAssetAddress();
		address payable _self = payable(address(this));
		if (_atoken == $.aETH) {
			if (!Wrapping._unwrap(_amount)) return false;
			try LendingPool(_pool).repay{value: _amount}(_token, _amount, _self) {
				return true;
			} catch (bytes memory /* _data */) {
				assert(Wrapping._wrap(_amount));
				return false;
			}
		} else {
			address _core = $.Aave_AAVE_LENDING_POOL_CORE;
			Transfers._approveFunds(_token, _core, _amount);
			try LendingPool(_pool).repay(_token, _amount, _self) {
				return true;
			} catch (bytes memory /* _data */) {
				Transfers._approveFunds(_token, _core, 0);
				return false;
			}
		}
	}

	function _safeEnter(address _atoken) internal pure
	{
		require(_enter(_atoken), "enter failed");
	}

	function _safeLend(address _atoken, uint256 _amount) internal
	{
		require(_lend(_atoken, _amount), "lend failure");
	}

	function _safeRedeem(address _atoken, uint256 _amount) internal
	{
		require(_redeem(_atoken, _amount), "redeem failure");
	}

	function _safeBorrow(address _atoken, uint256 _amount) internal
	{
		require(_borrow(_atoken, _amount), "borrow failure");
	}

	function _safeRepay(address _atoken, uint256 _amount) internal
	{
		require(_repay(_atoken, _amount), "repay failure");
	}
}
