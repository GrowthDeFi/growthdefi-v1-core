// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev This library implements auxiliary math definitions.
 */
library Math
{
	function _min(uint256 _amount1, uint256 _amount2) internal pure returns (uint256 _minAmount)
	{
		return _amount1 < _amount2 ? _amount1 : _amount2;
	}

	function _max(uint256 _amount1, uint256 _amount2) internal pure returns (uint256 _maxAmount)
	{
		return _amount1 > _amount2 ? _amount1 : _amount2;
	}

	function _sqrt(uint256 y) internal pure returns (uint256 _z)
	{
		if (y > 3) {
			_z = y;
			uint256 x = y / 2 + 1;
			while (x < _z) {
				_z = x;
				x = (y / x + x) / 2;
			}
		} else if (y != 0) {
			_z = 1;
		} else {
			_z = 0;
		}
	}

	function _powi(uint256 _base, uint256 _n) internal pure returns (uint256)
	{
		require(_base <= 1e18, "invalid base");
		uint256 _res = 1e18;
		while (_n > 0) {
			if ((_n & 1) == 1) _res = (_res * _base) / 1e18;
			_base = (_base * _base) / 1e18;
			_n >>= 1;
		}
		return _res;
	}
}
