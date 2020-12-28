// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

library Executor
{
	struct Target {
		address to;
		bytes data;
	}

	function addTarget(Target[] storage _targets, address _to, bytes memory _data) internal
	{
		_targets.push(Target({ to: _to, data: _data }));
	}

	function removeTarget(Target[] storage _targets, uint256 _index) internal
	{
		require(_index < _targets.length, "invalid index");
		_targets[_index] = _targets[_targets.length - 1];
		_targets.pop();
	}

	function executeAll(Target[] storage _targets) internal
	{
		for (uint256 _i = 0; _i < _targets.length; _i++) {
			Target storage _target = _targets[_i];
			bool _success = _externalCall(_target.to, _target.data);
			require(_success, "call failed");
		}
	}

	function _externalCall(address _to, bytes memory _data) internal returns (bool _success)
	{
		assembly {
			_success := call(gas(), _to, 0, add(_data, 0x20), mload(_data), 0, 0)
		}
	}
}
