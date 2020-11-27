// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev An interface with the extended functionality of portfolio management
 *      gTokens. See GTokenType0.sol for further documentation.
 */
interface GPortfolio
{
	// view functions
	function tokenCount() external view returns (uint256 _count);
	function tokenAt(uint256 _index) external view returns (address _token);
	function tokenPercent(address _token) external view returns (uint256 _percent);
	function getRebalanceMargins() external view returns (uint256 _liquidRebalanceMargin, uint256 _portfolioRebalanceMargin);

	// priviledged functions
	function insertToken(address _token) external;
	function removeToken(address _token) external;
	function anounceTokenPercentTransfer(address _sourceToken, address _targetToken, uint256 _percent) external;
	function transferTokenPercent(address _sourceToken, address _targetToken, uint256 _percent) external;
	function setRebalanceMargins(uint256 _liquidRebalanceMargin, uint256 _portfolioRebalanceMargin) external;

	// emitted events
	event InsertToken(address indexed _token);
	event RemoveToken(address indexed _token);
	event AnnounceTokenPercentTransfer(address indexed _sourceToken, address indexed _targetToken, uint256 _percent);
	event TransferTokenPercent(address indexed _sourceToken, address indexed _targetToken, uint256 _percent);
	event ChangeTokenPercent(address indexed _token, uint256 _oldPercent, uint256 _newPercent);
}
