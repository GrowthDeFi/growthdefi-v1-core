// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface GToken is IERC20
{
	function calcDepositSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) external pure returns (uint256 _netShares, uint256 _feeShares);
	function calcDepositCostFromShares(uint256 _netShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) external pure returns (uint256 _cost, uint256 _feeShares);
	function calcWithdrawalSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) external pure returns (uint256 _grossShares, uint256 _feeShares);
	function calcWithdrawalCostFromShares(uint256 _grossShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) external pure returns (uint256 _cost, uint256 _feeShares);

	function stakesToken() external view returns (address _stakesToken);
	function reserveToken() external view returns (address _reserveToken);
	function totalReserve() external view returns (uint256 _totalReserve);
	function depositFee() external view returns (uint256 _depositFee);
	function withdrawalFee() external view returns (uint256 _withdrawalFee);
	function liquidityPool() external view returns (address _liquidityPool);
	function liquidityPoolBurningRate() external view returns (uint256 _burningRate);
	function liquidityPoolLastBurningTime() external view returns (uint256 _lastBurningTime);
	function liquidityPoolMigrationRecipient() external view returns (address _migrationRecipient);
	function liquidityPoolMigrationUnlockTime() external view returns (uint256 _migrationUnlockTime);

	function deposit(uint256 _cost) external;
	function withdraw(uint256 _grossShares) external;

	function setFees(uint256 _depositFee, uint256 _withdrawalFee) external;
	function allocateLiquidityPool(uint256 _stakesAmount, uint256 _sharesAmount) external;
	function setLiquidityPoolBurningRate(uint256 _burningRate) external;
	function burnLiquidityPoolPortion() external;
	function initiateLiquidityPoolMigration(address _migrationRecipient) external;
	function cancelLiquidityPoolMigration() external;
	function completeLiquidityPoolMigration() external;

	event UpdateFees(uint256 _depositFee, uint256 _withdrawalFee);
	event BurnLiquidityPoolPortion(uint256 _stakesAmount, uint256 _sharesAmount);
	event InitiateLiquidityPoolMigration(address indexed _migrationRecipient);
	event CancelLiquidityPoolMigration(address indexed _migrationRecipient);
	event CompleteLiquidityPoolMigration(address indexed _migrationRecipient, uint256 _stakesAmount, uint256 _sharesAmount);
}
