// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

library GElasticTokenManager
{
	using SafeMath for uint256;
	using GElasticTokenManager for GElasticTokenManager.Self;

	uint256 constant MAXIMUM_REBASE_TREASURY_MINT_PERCENT = 25e16; // 25%

	uint256 constant DEFAULT_REBASE_MINIMUM_INTERVAL = 24 hours;
	uint256 constant DEFAULT_REBASE_WINDOW_OFFSET = 17 hours; // 5PM UTC
	uint256 constant DEFAULT_REBASE_WINDOW_LENGTH = 1 hours;
	uint256 constant DEFAULT_REBASE_MAXIMUM_DEVIATION = 5e16; // 5%
	uint256 constant DEFAULT_REBASE_DAMPENING_FACTOR = 10; // 10x to reach 100%
	uint256 constant DEFAULT_REBASE_TREASURY_MINT_PERCENT = 10e16; // 10%

	struct Self {
		address treasury;

		uint256 rebaseMaximumDeviation;
		uint256 rebaseDampeningFactor;
		uint256 rebaseTreasuryMintPercent;

		uint256 rebaseMinimumInterval;
		uint256 rebaseWindowOffset;
		uint256 rebaseWindowLength;

		bool rebaseActive;
		uint256 lastRebaseTime;
		uint256 epoch;
	}

	function init(Self storage _self, address _treasury) public
	{
		_self.treasury = _treasury;

		_self.rebaseMaximumDeviation = DEFAULT_REBASE_MAXIMUM_DEVIATION;
		_self.rebaseDampeningFactor = DEFAULT_REBASE_DAMPENING_FACTOR;
		_self.rebaseTreasuryMintPercent = DEFAULT_REBASE_TREASURY_MINT_PERCENT;

		_self.rebaseMinimumInterval = DEFAULT_REBASE_MINIMUM_INTERVAL;
		_self.rebaseWindowOffset = DEFAULT_REBASE_WINDOW_OFFSET;
		_self.rebaseWindowLength = DEFAULT_REBASE_WINDOW_LENGTH;

		_self.rebaseActive = false;
		_self.lastRebaseTime = 0;
		_self.epoch = 0;
	}

	function activateRebase(Self storage _self) public
	{
		require(!_self.rebaseActive, "already active");
		_self.rebaseActive = true;
		_self.lastRebaseTime = now.sub(now.mod(_self.rebaseMinimumInterval)).add(_self.rebaseWindowOffset);
	}

	function setTreasury(Self storage _self, address _treasury) public
	{
		require(_treasury == address(0), "invalid treasury");
		_self.treasury = _treasury;
	}

	function setRebaseMaximumDeviation(Self storage _self, uint256 _rebaseMaximumDeviation) public
	{
		require(_rebaseMaximumDeviation > 0, "invalid maximum deviation");
		_self.rebaseMaximumDeviation = _rebaseMaximumDeviation;
	}

	function setRebaseDampeningFactor(Self storage _self, uint256 _rebaseDampeningFactor) public
	{
		require(_rebaseDampeningFactor > 0, "invalid dampening factor");
		_self.rebaseDampeningFactor = _rebaseDampeningFactor;
	}

	function setRebaseTreasuryMintPercent(Self storage _self, uint256 _rebaseTreasuryMintPercent) public
	{
		require(_rebaseTreasuryMintPercent < MAXIMUM_REBASE_TREASURY_MINT_PERCENT, "invalid percent");
		_self.rebaseTreasuryMintPercent = _rebaseTreasuryMintPercent;
	}

	function setRebaseTimingParameters(Self storage _self, uint256 _rebaseMinimumInterval, uint256 _rebaseWindowOffset, uint256 _rebaseWindowLength) public
	{
		require(_rebaseMinimumInterval > 0, "invalid interval");
		require(_rebaseWindowOffset.add(_rebaseWindowLength) <= _rebaseMinimumInterval, "invalid window");
		_self.rebaseMinimumInterval = _rebaseMinimumInterval;
		_self.rebaseWindowOffset = _rebaseWindowOffset;
		_self.rebaseWindowLength = _rebaseWindowLength;
	}

	function rebaseAvailable(Self storage _self) public view returns (bool _available)
	{
		return _self._rebaseAvailable();
	}

	function rebase(Self storage _self, uint256 _exchangeRate, uint256 _totalSupply) public returns (uint256 _delta, bool _positive, uint256 _mintAmount)
	{
		require(_self._rebaseAvailable(), "not available");

		_self.lastRebaseTime = now.sub(now.mod(_self.rebaseMinimumInterval)).add(_self.rebaseWindowOffset);
		_self.epoch = _self.epoch.add(1);

		_positive = _exchangeRate > 1e18;

		uint256 _deviation = _positive ? _exchangeRate.sub(1e18) : uint256(1e18).sub(_exchangeRate);
		if (_deviation < _self.rebaseMaximumDeviation) {
			_deviation = 0;
			_positive = false;
		}

		_delta = _deviation.div(_self.rebaseDampeningFactor);

		_mintAmount = 0;
		if (_positive) {
			uint256 _mintPercent = _delta.mul(_self.rebaseTreasuryMintPercent).div(1e18);
			_delta = _delta.sub(_mintPercent);
			_mintAmount = _totalSupply.mul(_mintPercent).div(1e18);
		}

		return (_delta, _positive, _mintAmount);
	}

	function _rebaseAvailable(Self storage _self) internal view returns (bool _available)
	{
		if (!_self.rebaseActive) return false;
		if (now < _self.lastRebaseTime.add(_self.rebaseMinimumInterval)) return false;
		uint256 _offset = now.mod(_self.rebaseMinimumInterval);
		return _self.rebaseWindowOffset <= _offset && _offset < _self.rebaseWindowOffset.add(_self.rebaseWindowLength);
	}
}
