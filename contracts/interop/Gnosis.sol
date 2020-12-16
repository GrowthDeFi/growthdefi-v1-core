// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

interface Enum
{
	enum Operation { Call, DelegateCall }
}

interface OwnerManager
{
	function getOwners() external view returns (address[] memory _owners);
	function isOwner(address _owner) external view returns (bool _isOwner);
}

interface ModuleManager
{
	function execTransactionFromModule(address _to, uint256 _value, bytes calldata _data, Enum.Operation _operation) external returns (bool _success);
}

interface Safe is OwnerManager, ModuleManager
{
}
