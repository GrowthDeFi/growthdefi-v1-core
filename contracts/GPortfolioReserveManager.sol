// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import { GCToken } from "./GCToken.sol";
import { G } from "./G.sol";

library GPortfolioReserveManager
{
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;
	using GPortfolioReserveManager for GPortfolioReserveManager.Self;

	uint256 constant DEFAULT_REBALANCE_MARGIN = 1e16; // 1%
	uint256 constant MAXIMUM_TOKEN_COUNT = 5;

	struct Self {
		address reserveToken;
		EnumerableSet.AddressSet tokens;
		mapping (address => uint256) percents;
		uint256 rebalanceMargin;
	}

	function init(Self storage _self, address _reserveToken) public
	{
		_self.reserveToken = _reserveToken;
		_self.percents[_reserveToken] = 1e18;
		_self.rebalanceMargin = DEFAULT_REBALANCE_MARGIN;
	}

	function tokenCount(Self storage _self) public view returns (uint256 _count)
	{
		return _self.tokens.length();
	}

	function tokenAt(Self storage _self, uint256 _index) public view returns (address _token)
	{
		require(_index < _self.tokens.length(), "Invalid index");
		return _self.tokens.at(_index);
	}

	function tokenPercent(Self storage _self, address _token) public view returns (uint256 _percent)
	{
		return _self.percents[_token];
	}

	function insertToken(Self storage _self, address _token) public
	{
		require(_self.tokens.length() < MAXIMUM_TOKEN_COUNT, "Limit reached");
		address _underlyingToken = GCToken(_token).underlyingToken();
		require(_underlyingToken == _self.reserveToken, "Mismatched token");
		require(_self.tokens.add(_token), "Duplicate token");
	}

	function removeToken(Self storage _self, address _token) public
	{
		require(_self.percents[_token] == 0, "Positive percent");
		require(G.getBalance(_token) == 0, "Unbalanced reserve");
		require(_self.tokens.remove(_token), "Unknown token");
	}

	function transferTokenPercent(Self storage _self, address _sourceToken, address _targetToken, uint256 _percent) public
	{
		require(_percent <= _self.percents[_sourceToken], "Invalid percent");
		require(_sourceToken != _targetToken, "Invalid transfer");
		require(_targetToken == _self.reserveToken || _self.tokens.contains(_targetToken), "Unknown token");
		_self.percents[_sourceToken] -= _percent;
		_self.percents[_targetToken] += _percent;
	}

	function setRebalanceMargin(Self storage _self, uint256 _rebalanceMargin) public
	{
		require(0 <= _rebalanceMargin && _rebalanceMargin <= 1e18, "Invalid margin");
		_self.rebalanceMargin = _rebalanceMargin;
	}

	function totalReserve(Self storage _self) public view returns (uint256 _totalReserve)
	{
		return _self._calcTotalReserve();
	}

	function adjustReserve(Self storage _self, uint256 _roomAmount) public returns (bool _success)
	{
		uint256 _reserveAmount = _self._calcTotalReserve();
		_roomAmount = G.min(_roomAmount, _reserveAmount);
		_reserveAmount = _reserveAmount.sub(_roomAmount);

		uint256 _liquidAmount = G.getBalance(_self.reserveToken);
		uint256 _blockedAmount = G.min(_roomAmount, _liquidAmount);
		_liquidAmount = _liquidAmount.sub(_blockedAmount);

		uint256 _requiredAmount = _roomAmount.sub(_blockedAmount);
		if (_requiredAmount > 0) {
			(address _adjustToken, uint256 _adjustAmount) = _self._findRequiredWithdrawal(_reserveAmount, _requiredAmount);
			if (_adjustToken == address(0)) return false;
			return _self._withdrawUnderlying(_adjustToken, _adjustAmount);
		}

		(uint256 _depositAmount, uint256 _withdrawalAmount) = _self._calcLiquidAdjustment(_reserveAmount, _liquidAmount);

		if (_depositAmount > 0) {
			(address _adjustToken, uint256 _adjustAmount) = _self._findDeposit(_reserveAmount);
			if (_adjustToken == address(0)) return true;
			return _self._depositUnderlying(_adjustToken, G.min(_adjustAmount, _depositAmount));
		}

		if (_withdrawalAmount > 0) {
			(address _adjustToken, uint256 _adjustAmount) = _self._findWithdrawal(_reserveAmount);
			if (_adjustToken == address(0)) return true;
			return _self._withdrawUnderlying(_adjustToken, G.min(_adjustAmount, _withdrawalAmount));
		}

		return true;
	}

	function _calcTotalReserve(Self storage _self) internal view returns (uint256 _totalReserve)
	{
		_totalReserve = G.getBalance(_self.reserveToken);
		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);
			uint256 _tokenReserve = GCToken(_token).totalReserveUnderlying();
			_totalReserve = _totalReserve.add(_tokenReserve);
		}
		return _totalReserve;
	}

	function _calcLiquidAdjustment(Self storage _self, uint256 _reserveAmount, uint256 _liquidAmount) internal view returns (uint256 _depositAmount, uint256 _withdrawalAmount)
	{
		uint256 _tokenPercent = _self.percents[_self.reserveToken];
		uint256 _tokenReserve = _reserveAmount.mul(_tokenPercent).div(1e18);
		if (_liquidAmount > _tokenReserve) {
			uint256 _upperPercent = G.min(1e18, _tokenPercent.add(_self.rebalanceMargin));
			uint256 _upperReserve = _reserveAmount.mul(_upperPercent).div(1e18);
			if (_liquidAmount > _upperReserve) return (_liquidAmount.sub(_tokenReserve), 0);
		}
		else
		if (_liquidAmount < _tokenReserve) {
			uint256 _lowerPercent = _tokenPercent.sub(G.min(_tokenPercent, _self.rebalanceMargin));
			uint256 _lowerReserve = _reserveAmount.mul(_lowerPercent).div(1e18);
			if (_liquidAmount < _lowerReserve) return (0, _tokenReserve.sub(_liquidAmount));
		}
		return (0, 0);
	}

	function _findRequiredWithdrawal(Self storage _self, uint256 _reserveAmount, uint256 _requiredAmount) internal view returns (address _adjustToken, uint256 _adjustAmount)
	{
		uint256 _minPercent = 1e18;
		_adjustToken = address(0);
		_adjustAmount = 0;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);
			uint256 _tokenReserve = GCToken(_token).totalReserveUnderlying();
			if (_tokenReserve < _requiredAmount) continue;

			uint256 _oldTokenReserve = _tokenReserve.sub(_requiredAmount);
			uint256 _oldTokenPercent = _oldTokenReserve.mul(1e18).div(_reserveAmount);
			uint256 _newTokenPercent = _self.percents[_token];

			uint256 _percent = 0;
			if (_newTokenPercent > _oldTokenPercent) _percent = _newTokenPercent.sub(_oldTokenPercent);
			else
			if (_newTokenPercent < _oldTokenPercent) _percent = _oldTokenPercent.sub(_newTokenPercent);

			if (_percent < _minPercent) {
				_minPercent = _percent;
				_adjustToken = _token;
				_adjustAmount = _requiredAmount;
			}
		}

		return (_adjustToken, _adjustAmount);
	}

	function _findDeposit(Self storage _self, uint256 _reserveAmount) internal view returns (address _adjustToken, uint256 _adjustAmount)
	{
		uint256 _maxPercent = _self.rebalanceMargin;
		_adjustToken = address(0);
		_adjustAmount = 0;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);

			uint256 _oldTokenReserve = GCToken(_token).totalReserveUnderlying();
			uint256 _oldTokenPercent = _oldTokenReserve.mul(1e18).div(_reserveAmount);
			uint256 _newTokenPercent = _self.percents[_token];

			if (_newTokenPercent > _oldTokenPercent) {
				uint256 _percent = _newTokenPercent.sub(_oldTokenPercent);
				if (_percent > _maxPercent) {
					uint256 _newTokenReserve = _reserveAmount.mul(_newTokenPercent).div(1e18);
					uint256 _amount = _newTokenReserve.sub(_oldTokenReserve);

					_maxPercent = _percent;
					_adjustToken = _token;
					_adjustAmount = _amount;
				}
			}
		}

		return (_adjustToken, _adjustAmount);
	}

	function _findWithdrawal(Self storage _self, uint256 _reserveAmount) internal view returns (address _adjustToken, uint256 _adjustAmount)
	{
		uint256 _maxPercent = _self.rebalanceMargin;
		_adjustToken = address(0);
		_adjustAmount = 0;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);

			uint256 _oldTokenReserve = GCToken(_token).totalReserveUnderlying();
			uint256 _oldTokenPercent = _oldTokenReserve.mul(1e18).div(_reserveAmount);
			uint256 _newTokenPercent = _self.percents[_token];

			if (_newTokenPercent < _oldTokenPercent) {
				uint256 _percent = _oldTokenPercent.sub(_newTokenPercent);
				if (_percent > _maxPercent) {
					uint256 _newTokenReserve = _reserveAmount.mul(_newTokenPercent).div(1e18);
					uint256 _amount = _oldTokenReserve.sub(_newTokenReserve);

					_maxPercent = _percent;
					_adjustToken = _token;
					_adjustAmount = _amount;
				}
			}
		}

		return (_adjustToken, _adjustAmount);
	}

	function _depositUnderlying(Self storage _self, address _token, uint256 _amount) internal returns (bool _success)
	{
		_amount = G.min(_amount, G.getBalance(_self.reserveToken));
		if (_amount == 0) return true;
		G.approveFunds(_self.reserveToken, _token, _amount);
		try GCToken(_token).depositUnderlying(_amount) {
			return true;
		} catch (bytes memory /* _data */) {
			G.approveFunds(_self.reserveToken, _token, 0);
			return false;
		}
	}

	function _withdrawUnderlying(Self storage _self, address _token, uint256 _amount) internal returns (bool _success)
	{
		uint256 _grossShares = _self._calcWithdrawalSharesFromUnderlyingCost(_token, _amount);
		_grossShares = G.min(_grossShares, G.getBalance(_token));
		if (_grossShares == 0) return true;
		try GCToken(_token).withdrawUnderlying(_grossShares) {
			return true;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _calcWithdrawalSharesFromUnderlyingCost(Self storage /* _self */, address _token, uint256 _underlyingCost) internal view returns (uint256 _grossShares)
	{
		uint256 _totalReserve = GCToken(_token).totalReserve();
		uint256 _totalSupply = GCToken(_token).totalSupply();
		uint256 _withdrawalFee = GCToken(_token).withdrawalFee();
		uint256 _exchangeRate = GCToken(_token).exchangeRate();
		(_grossShares,) = GCToken(_token).calcWithdrawalSharesFromUnderlyingCost(_underlyingCost, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _grossShares;
	}
}
