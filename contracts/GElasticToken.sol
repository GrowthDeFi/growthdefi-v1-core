// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { G } from "./G.sol";

contract GElasticToken is ERC20, Ownable, ReentrancyGuard
{
	using SafeMath for uint256;

	uint256 public scalingFactor = 1e18;

	constructor (string memory _name, string memory _symbol, uint8 _decimals)
		ERC20(_name, _symbol) public
	{
		_setupDecimals(_decimals);
	}

	function scaledTotalSupply() public view returns (uint256 _scaledTotalSupply)
	{
		return _scale(totalSupply(), scalingFactor);
	}

	function balanceOfScaled(address _address) public view returns (uint256 _scaledBalance)
	{
		return _scale(balanceOf(_address), scalingFactor);
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
			uint256 _maxScalingFactor = _calcMaxScalingFactor(totalSupply());
			_newScalingFactor = G.min(_newScalingFactor, _maxScalingFactor);
		}
		scalingFactor = _newScalingFactor;
		emit Rebase(_epoch, _oldScalingFactor, _newScalingFactor);
	}

	function _calcMaxScalingFactor(uint256 _totalSupply) internal pure returns (uint256 _maxScalingFactor)
	{
		return uint256(-1) / _totalSupply;
	}

	function _scale(uint256 _amount, uint256 _scalingFactor) internal pure returns (uint256 _scaledAmount)
	{
		return _amount.mul(_scalingFactor).div(1e24);
	}

	function _unscale(uint256 _scaledAmount, uint256 _scalingFactor) internal pure returns (uint256 _amount)
	{
		return _scaledAmount.mul(1e24).div(_scalingFactor);
	}

	function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override
	{
		_to; // silences warnings
		if (_from == address(0)) {
			uint256 _newTotalSupply = totalSupply().add(_amount);
			uint256 _maxScalingFactor = _calcMaxScalingFactor(_newTotalSupply);
			require(scalingFactor <= _maxScalingFactor, "max scaling factor too low");
		}
	}

	event NewRebaser(address _oldRebaser, address _newRebaser);
	event Rebase(uint256 _epoch, uint256 _oldScalingFactor, uint256 _newScalingFactor);
}
