// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ElasticERC20 } from "./ElasticERC20.sol";
import { G } from "./G.sol";

contract GElasticToken is ElasticERC20, Ownable, ReentrancyGuard
{
	using SafeMath for uint256;

	constructor (string memory _name, string memory _symbol, uint8 _decimals)
		ElasticERC20(_name, _symbol) public
	{
		_setupDecimals(_decimals);
	}

	function mint(address _to, uint256 _amount) public onlyOwner
	{
		_mint(_to, _amount);
	}

	function rebase(uint256 _epoch, uint256 _delta, bool _positive) public onlyOwner
	{
		uint256 _oldScalingFactor = scalingFactor;
		uint256 _newScalingFactor;
		if (_delta == 0) {
			_newScalingFactor = _oldScalingFactor;
		} else {
			if (_positive) {
				_newScalingFactor = _oldScalingFactor.mul(uint256(1e18).add(_delta)).div(1e18);
			} else {
				_newScalingFactor = _oldScalingFactor.mul(uint256(1e18).sub(_delta)).div(1e18);
			}
		}
		if (_newScalingFactor > _oldScalingFactor) {
			uint256 _maxScalingFactor = _calcMaxScalingFactor(unscaledTotalSupply);
			_newScalingFactor = G.min(_newScalingFactor, _maxScalingFactor);
		}
		_setScalingFactor(_newScalingFactor);
		emit Rebase(_epoch, _oldScalingFactor, _newScalingFactor);
	}

	event Rebase(uint256 _epoch, uint256 _oldScalingFactor, uint256 _newScalingFactor);
}
