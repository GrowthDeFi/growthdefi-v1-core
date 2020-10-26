// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

interface LendingPoolAddressesProvider
{
	function getLendingPool() external view returns (address _pool);
	function getLendingPoolCore() external view returns (address payable _lendingPoolCore);
}

interface LendingPool
{
	function getReserveData(address _reserve) external view returns (uint256 _totalLiquidity, uint256 _availableLiquidity, uint256 _totalBorrowsStable, uint256 _totalBorrowsVariable, uint256 _liquidityRate, uint256 _variableBorrowRate, uint256 _stableBorrowRate, uint256 _averageStableBorrowRate, uint256 _utilizationRate, uint256 _liquidityIndex, uint256 _variableBorrowIndex, address _aTokenAddress, uint40 _lastUpdateTimestamp);
	function flashLoan(address _receiver, address _reserve, uint256 _amount, bytes calldata _params) external;
}

interface FlashLoanReceiver
{
	function executeOperation(address _reserve, uint256 _amount, uint256 _fee, bytes calldata _params) external;
}
