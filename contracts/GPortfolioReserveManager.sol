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
		require(0 < _rebalanceMargin && _rebalanceMargin < 1e18, "Invalid margin");
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

		{
			uint256 _liquidAmount = G.getBalance(_self.reserveToken);
			uint256 _requiredAmount = _roomAmount.sub(G.min(_liquidAmount, _roomAmount));
			if (_requiredAmount == 0) {
				uint256 _tokenPercent = _self.percents[_self.reserveToken];
				uint256 _newTokenReserve = _liquidAmount.sub(_roomAmount);
				uint256 _newTokenPercent = _newTokenReserve.mul(1e18).div(_reserveAmount);
				if (_newTokenPercent > _tokenPercent) {
					uint256 _percent = _newTokenPercent.sub(_tokenPercent);
					if (_percent < _self.rebalanceMargin) return true;
				}
				else
				if (_newTokenPercent < _tokenPercent) {
					uint256 _percent = _tokenPercent.sub(_newTokenPercent);
					if (_percent < _self.rebalanceMargin) return true;
				}
			}
		}

		(uint256 _which, address _token, uint256 _underlyingCostOrGrossShares) = _self._findAdjustReserveOperation(_reserveAmount);
		return _self._executeOperation(_which, _token, _underlyingCostOrGrossShares);
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

	function _executeOperation(Self storage _self, uint256 _which, address _token, uint256 _underlyingCostOrGrossShares) internal returns (bool _success)
	{
		if (_which == 0) {
			return true;
		}
		if (_which == 1) {
			uint256 _underlyingCost = _underlyingCostOrGrossShares;
			G.approveFunds(_self.reserveToken, _token, _underlyingCost);
			try GCToken(_token).depositUnderlying(_underlyingCost) {
				return true;
			} catch (bytes memory /* _data */) {
				G.approveFunds(_self.reserveToken, _token, 0);
				return false;
			}
		}
		if (_which == 2) {
			uint256 _grossShares = _underlyingCostOrGrossShares;
			try GCToken(_token).withdrawUnderlying(_grossShares) {
				return true;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
		assert(false);
	}

	function _findAdjustReserveOperation(Self storage _self, uint256 _reserveAmount) internal view returns (uint256 _which, address _adjustToken, uint256 _underlyingCostOrGrossShares)
	{
		_which = 0;
		uint256 _maxPercent = _self.rebalanceMargin;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);

			uint256 _oldTokenReserve = GCToken(_token).totalReserveUnderlying();
			uint256 _oldTokenPercent = _oldTokenReserve.mul(1e18).div(_reserveAmount);

			uint256 _idealTokenReserve;
			{
				uint256 _tokenPercent = _self.percents[_token];
				_idealTokenReserve = _reserveAmount.mul(_tokenPercent).div(1e18);
			}

			if (_idealTokenReserve > _oldTokenReserve) {
				uint256 _underlyingCost = _idealTokenReserve.sub(_oldTokenReserve);
				_underlyingCost = G.min(_underlyingCost, G.getBalance(_self.reserveToken));

				uint256 _percent;
				{
					uint256 _newTokenReserve = _oldTokenReserve.add(_underlyingCost);
					uint256 _newTokenPercent = _newTokenReserve.mul(1e18).div(_reserveAmount);
					_percent = _newTokenPercent.sub(_oldTokenPercent);
				}

				if (_percent > _maxPercent) {
					_maxPercent = _percent;
					_which = 1;
					_adjustToken = _token;
					_underlyingCostOrGrossShares = _underlyingCost;
				}
				continue;
			}/*
			if (_idealTokenReserve < _oldTokenReserve) {
				uint256 _underlyingCost = _oldTokenReserve.sub(_idealTokenReserve);
				uint256 _grossShares = _self._calcWithdrawalSharesFromUnderlyingCost(_token, _underlyingCost);
				_grossShares = G.min(_grossShares, G.getBalance(_token));
				_underlyingCost = _self._calcWithdrawalUnderlyingCostFromShares(_token, _grossShares);

				uint256 _percent;
				{
					uint256 _newTokenReserve = _oldTokenReserve.sub(_underlyingCost);
					uint256 _newTokenPercent = _newTokenReserve.mul(1e18).div(_reserveAmount);
					_percent = _newTokenPercent.sub(_oldTokenPercent);
				}

				if (_percent > _maxPercent) {
					_maxPercent = _percent;
					_which = 2;
					_adjustToken = _token;
					_underlyingCostOrGrossShares = _grossShares;
				}
				continue;
			}*/
		}

		return (_which, _adjustToken, _underlyingCostOrGrossShares);
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

	function _calcWithdrawalUnderlyingCostFromShares(Self storage /* _self */, address _token, uint256 _grossShares) internal view returns (uint256 _underlyingCost)
	{
		uint256 _totalReserve = GCToken(_token).totalReserve();
		uint256 _totalSupply = GCToken(_token).totalSupply();
		uint256 _withdrawalFee = GCToken(_token).withdrawalFee();
		uint256 _exchangeRate = GCToken(_token).exchangeRate();
		(_underlyingCost,) = GCToken(_token).calcWithdrawalUnderlyingCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _underlyingCost;
	}
}
