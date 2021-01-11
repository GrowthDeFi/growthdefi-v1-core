// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Minimal interface for gTokens, implemented by the GTokenBase contract.
 *      See GTokenBase.sol for further documentation.
 */
interface GToken_V2 is IERC20
{
	// view functions
	function calcDepositSharesFromCost(uint256 _cost) external view returns (uint256 _shares);
	function calcDepositCostFromShares(uint256 _shares) external view returns (uint256 _cost);
	function calcWithdrawalSharesFromCost(uint256 _cost) external view returns (uint256 _shares);
	function calcWithdrawalCostFromShares(uint256 _shares) external view returns (uint256 _cost);
	function reserveToken() external view returns (address _reserveToken);
	function totalReserve() external view returns (uint256 _totalReserve);
	// function depositFee() external view returns (uint256 _depositFee);
	// function withdrawalFee() external view returns (uint256 _withdrawalFee);

	// open functions
	function deposit(uint256 _cost) external;
	function withdraw(uint256 _shares) external;
}
