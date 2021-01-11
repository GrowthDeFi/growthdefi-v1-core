// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import { GCToken_V2 } from "./GCToken_V2.sol";
import { G } from "./G.sol";

library GPortfolioReserveManager_V2
{
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;
	using GPortfolioReserveManager_V2 for GPortfolioReserveManager_V2.Self;

	uint256 constant DEFAULT_LIQUID_REBALANCE_MARGIN = 95e15; // 9.5%
	uint256 constant DEFAULT_PORTFOLIO_REBALANCE_MARGIN = 1e16; // 1%
	uint256 constant MAXIMUM_TOKEN_COUNT = 5;
	uint256 constant PORTFOLIO_CHANGE_WAIT_INTERVAL = 1 days;
	uint256 constant PORTFOLIO_CHANGE_OPEN_INTERVAL = 1 days;

	struct Self {
		address reserveToken;
		EnumerableSet.AddressSet tokens;
		mapping (address => uint256) percents;
		mapping (uint256 => uint256) announcements;
		uint256 liquidRebalanceMargin;
		uint256 portfolioRebalanceMargin;
	}

	function init(Self storage _self, address _reserveToken) public
	{
		_self.reserveToken = _reserveToken;
		_self.percents[_reserveToken] = 1e18;
		_self.liquidRebalanceMargin = DEFAULT_LIQUID_REBALANCE_MARGIN;
		_self.portfolioRebalanceMargin = DEFAULT_PORTFOLIO_REBALANCE_MARGIN;
	}

	function tokenCount(Self storage _self) public view returns (uint256 _count)
	{
		return _self.tokens.length();
	}

	function tokenAt(Self storage _self, uint256 _index) public view returns (address _token)
	{
		require(_index < _self.tokens.length(), "invalid index");
		return _self.tokens.at(_index);
	}

	function tokenPercent(Self storage _self, address _token) public view returns (uint256 _percent)
	{
		return _self.percents[_token];
	}

	function insertToken(Self storage _self, address _token) public
	{
		require(_self.tokens.length() < MAXIMUM_TOKEN_COUNT, "limit reached");
		address _underlyingToken = GCToken_V2(_token).underlyingToken();
		require(_underlyingToken == _self.reserveToken, "mismatched token");
		require(_self.tokens.add(_token), "duplicate token");
		assert(_self.percents[_token] == 0);
	}

	function removeToken(Self storage _self, address _token) public
	{
		require(_self.tokens.remove(_token), "unknown token");
		uint256 _percent = _self.percents[_token];
		_self.percents[_token] = 0;
		_self.percents[_self.reserveToken] += _percent;
		bool _success = _self._withdrawUnderlying(_token, _self._getUnderlyingReserve(_token));
		// note that withdrawal failure does not prevent token removal
		// in that case funds would still be help by this contract
		// the token could be reinserted for a second try
		_success; // silences warnings
	}

	function announceTokenPercentTransfer(Self storage _self, address _sourceToken, address _targetToken, uint256 _percent) public
	{
		uint256 _hash = uint256(keccak256(abi.encode(uint256(_sourceToken), uint256(_targetToken), _percent)));
		uint256 _announcementTime = now;
		_self.announcements[_hash] = _announcementTime;
	}

	function transferTokenPercent(Self storage _self, address _sourceToken, address _targetToken, uint256 _percent) public
	{
		require(_percent <= _self.percents[_sourceToken], "invalid percent");
		require(_sourceToken != _targetToken, "invalid transfer");
		require(_targetToken == _self.reserveToken || _self.tokens.contains(_targetToken), "unknown token");
		uint256 _hash = uint256(keccak256(abi.encode(uint256(_sourceToken), uint256(_targetToken), _percent)));
		uint256 _announcementTime = _self.announcements[_hash];
		uint256 _effectiveTime = _announcementTime + PORTFOLIO_CHANGE_WAIT_INTERVAL;
		uint256 _cutoffTime = _effectiveTime + PORTFOLIO_CHANGE_OPEN_INTERVAL;
		require(_targetToken == _self.reserveToken || _effectiveTime <= now && now < _cutoffTime, "unannounced transfer");
		_self.announcements[_hash] = 0;
		_self.percents[_sourceToken] -= _percent;
		_self.percents[_targetToken] += _percent;
	}

	function setRebalanceMargins(Self storage _self, uint256 _liquidRebalanceMargin, uint256 _portfolioRebalanceMargin) public
	{
		require(0 <= _liquidRebalanceMargin && _liquidRebalanceMargin <= 1e18, "invalid margin");
		require(0 <= _portfolioRebalanceMargin && _portfolioRebalanceMargin <= 1e18, "invalid margin");
		_self.liquidRebalanceMargin = _liquidRebalanceMargin;
		_self.portfolioRebalanceMargin = _portfolioRebalanceMargin;
	}

	function totalReserve(Self storage _self) public view returns (uint256 _totalReserve)
	{
		return _self._calcTotalReserve();
	}

	function adjustReserve(Self storage _self, uint256 _roomAmount) public returns (bool _success)
	{
		// the reserve amount must deduct the room requested
		uint256 _reserveAmount = _self._calcTotalReserve();
		_roomAmount = G.min(_roomAmount, _reserveAmount);
		_reserveAmount = _reserveAmount.sub(_roomAmount);

		// the liquid amount must deduct the room requested
		uint256 _liquidAmount = G.getBalance(_self.reserveToken);
		uint256 _blockedAmount = G.min(_roomAmount, _liquidAmount);
		_liquidAmount = _liquidAmount.sub(_blockedAmount);

		// calculates whether or not the liquid amount exceeds the
		// configured range and requires either a deposit or a withdrawal
		// to be performed
		(uint256 _depositAmount, uint256 _withdrawalAmount) = _self._calcLiquidAdjustment(_reserveAmount, _liquidAmount);

		// if the liquid amount is not enough to process a withdrawal
		// we will need to withdraw the missing amount from one of the
		// underlying gTokens (actually we will choose the one for which
		// the withdrawal will produce the least impact in terms of
		// percentual share deviation from its configured target)
		uint256 _requiredAmount = _roomAmount.sub(_blockedAmount);
		if (_requiredAmount > 0) {
			_withdrawalAmount = _withdrawalAmount.add(_requiredAmount);
			(address _adjustToken, uint256 _adjustAmount) = _self._findRequiredWithdrawal(_reserveAmount, _requiredAmount, _withdrawalAmount);
			if (_adjustToken == address(0)) return false;
			return _self._withdrawUnderlying(_adjustToken, _adjustAmount);
		}

		// finds the gToken that will have benefited more of this deposit
		// in terms of its target percentual share deviation and performs
		// the deposit on it
		if (_depositAmount > 0) {
			(address _adjustToken, uint256 _adjustAmount) = _self._findDeposit(_reserveAmount);
			if (_adjustToken == address(0)) return true;
			return _self._depositUnderlying(_adjustToken, G.min(_adjustAmount, _depositAmount));
		}

		// finds the gToken that will have benefited more of this withdrawal
		// in terms of its target percentual share deviation and performs
		// the withdrawal on it
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
			uint256 _tokenReserve = _self._getUnderlyingReserve(_token);
			_totalReserve = _totalReserve.add(_tokenReserve);
		}
		return _totalReserve;
	}

	function _calcLiquidAdjustment(Self storage _self, uint256 _reserveAmount, uint256 _liquidAmount) internal view returns (uint256 _depositAmount, uint256 _withdrawalAmount)
	{
		uint256 _tokenPercent = _self.percents[_self.reserveToken];
		uint256 _tokenReserve = _reserveAmount.mul(_tokenPercent).div(1e18);
		if (_liquidAmount > _tokenReserve) {
			uint256 _upperPercent = G.min(1e18, _tokenPercent.add(_self.liquidRebalanceMargin));
			uint256 _upperReserve = _reserveAmount.mul(_upperPercent).div(1e18);
			if (_liquidAmount > _upperReserve) return (_liquidAmount.sub(_tokenReserve), 0);
		}
		else
		if (_liquidAmount < _tokenReserve) {
			uint256 _lowerPercent = _tokenPercent.sub(G.min(_tokenPercent, _self.liquidRebalanceMargin));
			uint256 _lowerReserve = _reserveAmount.mul(_lowerPercent).div(1e18);
			if (_liquidAmount < _lowerReserve) return (0, _tokenReserve.sub(_liquidAmount));
		}
		return (0, 0);
	}

	function _findRequiredWithdrawal(Self storage _self, uint256 _reserveAmount, uint256 _minimumAmount, uint256 _targetAmount) internal view returns (address _adjustToken, uint256 _adjustAmount)
	{
		uint256 _minPercent = 1e18;
		_adjustToken = address(0);
		_adjustAmount = 0;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);
			uint256 _tokenReserve = _self._getUnderlyingReserve(_token);
			if (_tokenReserve < _minimumAmount) continue;
			uint256 _maximumAmount = G.min(_tokenReserve, _targetAmount);

			uint256 _oldTokenReserve = _tokenReserve.sub(_maximumAmount);
			uint256 _oldTokenPercent = _oldTokenReserve.mul(1e18).div(_reserveAmount);
			uint256 _newTokenPercent = _self.percents[_token];

			uint256 _percent = 0;
			if (_newTokenPercent > _oldTokenPercent) _percent = _newTokenPercent.sub(_oldTokenPercent);
			else
			if (_newTokenPercent < _oldTokenPercent) _percent = _oldTokenPercent.sub(_newTokenPercent);

			if (_maximumAmount > _adjustAmount || _maximumAmount == _adjustAmount && _percent < _minPercent) {
				_minPercent = _percent;
				_adjustToken = _token;
				_adjustAmount = _maximumAmount;
			}
		}

		return (_adjustToken, _adjustAmount);
	}

	function _findDeposit(Self storage _self, uint256 _reserveAmount) internal view returns (address _adjustToken, uint256 _adjustAmount)
	{
		uint256 _maxPercent = _self.portfolioRebalanceMargin;
		_adjustToken = address(0);
		_adjustAmount = 0;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);

			uint256 _oldTokenReserve = _self._getUnderlyingReserve(_token);
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
		uint256 _maxPercent = _self.portfolioRebalanceMargin;
		_adjustToken = address(0);
		_adjustAmount = 0;

		uint256 _tokenCount = _self.tokens.length();
		for (uint256 _index = 0; _index < _tokenCount; _index++) {
			address _token = _self.tokens.at(_index);

			uint256 _oldTokenReserve = _self._getUnderlyingReserve(_token);
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
		try GCToken_V2(_token).depositUnderlying(_amount) {
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
		try GCToken_V2(_token).withdrawUnderlying(_grossShares) {
			return true;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}

	function _getUnderlyingReserve(Self storage _self, address _token) internal view returns (uint256 _underlyingCost)
	{
		uint256 _shares = G.getBalance(_token);
		return _self._calcWithdrawalUnderlyingCostFromShares(_token, _shares);
	}

	function _calcWithdrawalUnderlyingCostFromShares(Self storage /* _self */, address _token, uint256 _shares) internal view returns (uint256 _underlyingCost)
	{
		return GCToken_V2(_token).calcWithdrawalUnderlyingCostFromShares(_shares);
	}

	function _calcWithdrawalSharesFromUnderlyingCost(Self storage /* _self */, address _token, uint256 _underlyingCost) internal view returns (uint256 _shares)
	{
		return GCToken_V2(_token).calcWithdrawalSharesFromUnderlyingCost(_underlyingCost);
	}
}
