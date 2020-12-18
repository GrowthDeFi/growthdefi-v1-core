// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

interface GElastic
{
	// view functions
	function scalingFactor() external view returns (uint256 _scalingFactor);
	function maxScalingFactor() external view returns (uint256 _scalingFactor);
	function treasury() external view returns (address _treasury);
	function rebaseMaximumDeviation() external view returns (address _rebaseMaximumDeviation);
	function rebaseDampeningFactor() external view returns (address _rebaseDampeningFactor);
	function rebaseTreasuryMintPercent() external view returns (address _rebaseTreasuryMintPercent);
	function rebaseTimingParameters() external view returns (address _rebaseMinimumInterval, address _rebaseWindowOffset, address _rebaseWindowLength);
	function rebaseActive() external view returns (bool _rebaseActive);
	function rebaseAvailable() external view returns (bool _available);
	function lastRebaseTime() external view returns (uint256 _lastRebaseTime);
	function epoch() external view returns (uint256 _epoch);

	// open functions
	function activateRebase() external;
	function rebase() external;

	// priviledged functions
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
