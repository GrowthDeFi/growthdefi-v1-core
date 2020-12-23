// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

interface GElastic
{
	// view functions
	function referenceToken() external view returns (address _referenceToken);
	function treasury() external view returns (address _treasury);
	function rebaseMaximumDeviation() external view returns (uint256 _rebaseMaximumDeviation);
	function rebaseDampeningFactor() external view returns (uint256 _rebaseDampeningFactor);
	function rebaseTreasuryMintPercent() external view returns (uint256 _rebaseTreasuryMintPercent);
	function rebaseTimingParameters() external view returns (uint256 _rebaseMinimumInterval, uint256 _rebaseWindowOffset, uint256 _rebaseWindowLength);
	function rebaseActive() external view returns (bool _rebaseActive);
	function rebaseAvailable() external view returns (bool _available);
	function lastRebaseTime() external view returns (uint256 _lastRebaseTime);
	function epoch() external view returns (uint256 _epoch);
	function lastExchangeRate() external view returns (uint256 _exchangeRate);
	function currentExchangeRate() external view returns (uint256 _exchangeRate);

	// open functions
	function rebase() external;

	// priviledged functions
	function activateOracle(address _pair) external;
	function activateRebase() external;
	function setTreasury(address _newTreasury) external;
	function setRebaseMaximumDeviation(uint256 _newRebaseMaximumDeviation) external;
	function setRebaseDampeningFactor(uint256 _newRebaseDampeningFactor) external;
	function setRebaseTreasuryMintPercent(uint256 _newRebaseTreasuryMintPercent) external;
	function setRebaseTimingParameters(uint256 _newRebaseMinimumInterval, uint256 _newRebaseWindowOffset, uint256 _newRebaseWindowLength) external;

	// emitted events
	event Rebase(uint256 _epoch, uint256 _oldScalingFactor, uint256 _newScalingFactor);
	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangeRebaseMaximumDeviation(uint256 _oldRebaseMaximumDeviation, uint256 _newRebaseMaximumDeviation);
	event ChangeRebaseDampeningFactor(uint256 _oldRebaseDampeningFactor, uint256 _newRebaseDampeningFactor);
	event ChangeRebaseTreasuryMintPercent(uint256 _oldRebaseTreasuryMintPercent, uint256 _newRebaseTreasuryMintPercent);
	event ChangeRebaseTimingParameters(uint256 _oldRebaseMinimumInterval, uint256 _oldRebaseWindowOffset, uint256 _oldRebaseWindowLength, uint256 _newRebaseMinimumInterval, uint256 _newRebaseWindowOffset, uint256 _newRebaseWindowLength);
}
