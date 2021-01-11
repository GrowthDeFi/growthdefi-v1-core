// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GToken_V2 } from "./GToken_V2.sol";

/**
 * @dev Minimal interface for gcTokens, implemented by the GCTokenBase contract.
 *      See GCTokenBase.sol for further documentation.
 */
interface GCToken_V2 is GToken_V2
{
	// pure functions
	function calcCostFromUnderlyingCost(uint256 _underlyingCost, uint256 _exchangeRate) external pure returns (uint256 _cost);
	function calcUnderlyingCostFromCost(uint256 _cost, uint256 _exchangeRate) external pure returns (uint256 _underlyingCost);

	// view functions
	function calcDepositSharesFromUnderlyingCost(uint256 _underlyingCost) external view returns (uint256 _shares);
	function calcDepositUnderlyingCostFromShares(uint256 _shares) external view returns (uint256 _underlyingCost);
	function calcWithdrawalSharesFromUnderlyingCost(uint256 _underlyingCost) external view returns (uint256 _shares);
	function calcWithdrawalUnderlyingCostFromShares(uint256 _shares) external view returns (uint256 _underlyingCost);
	function underlyingToken() external view returns (address _underlyingToken);
	function exchangeRate() external view returns (uint256 _exchangeRate);
	function totalReserveUnderlying() external view returns (uint256 _totalReserveUnderlying);
	function lendingReserveUnderlying() external view returns (uint256 _lendingReserveUnderlying);
	function borrowingReserveUnderlying() external view returns (uint256 _borrowingReserveUnderlying);
	function collateralizationRatio() external view returns (uint256 _collateralizationRatio, uint256 _collateralizationMargin);

	// open functions
	function depositUnderlying(uint256 _cost) external;
	function withdrawUnderlying(uint256 _shares) external;

	// priviledged functions
	function setCollateralizationRatio(uint256 _collateralizationRatio, uint256 _collateralizationMargin) external;
}
