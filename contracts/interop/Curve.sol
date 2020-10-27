// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

interface Swap
{
	function underlying_coins(int128 _i) external view returns (address _underlying_coin);
	function get_dx_underlying(int128 _i, int128 _j, uint256 _dy) external view returns (uint256 _dx);
	function get_dy_underlying(int128 _i, int128 _j, uint256 _dx) external view returns (uint256 _dy);
	function exchange_underlying(int128 _i, int128 _j, uint256 _dx, uint256 _min_dy) external;
}
