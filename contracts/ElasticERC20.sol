// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

//import "../../utils/Address.sol";

import { Context } from "@openzeppelin/contracts/GSN/Context.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ElasticERC20 is Context, IERC20
{
	using SafeMath for uint256;

	mapping (address => mapping (address => uint256)) private allowances;

	mapping (address => uint256) unscaledBalanceOf;
	uint256 unscaledTotalSupply;

	uint256 public scalingFactor = 1e18;

	string public name;
	string public symbol;
	uint8 public decimals;

	constructor (string memory _name, string memory _symbol) public
	{
		name = _name;
		symbol = _symbol;
		decimals = 18;
	}

	function totalSupply() public view override returns (uint256)
	{
		return _scale(unscaledTotalSupply, scalingFactor);
	}

	function balanceOf(address _account) public view override returns (uint256 _balance)
	{
		return _scale(unscaledBalanceOf[_account], scalingFactor);
	}

	function allowance(address _owner, address _spender) public view virtual override returns (uint256 _allowance)
	{
		return allowances[_owner][_spender];
	}

	function approve(address _spender, uint256 _amount) public virtual override returns (bool _success)
	{
		_approve(_msgSender(), _spender, _amount);
		return true;
	}

	function increaseAllowance(address _spender, uint256 _addedValue) public virtual returns (bool _success)
	{
		_approve(_msgSender(), _spender, allowances[_msgSender()][_spender].add(_addedValue));
		return true;
	}

	function decreaseAllowance(address _spender, uint256 _subtractedValue) public virtual returns (bool _success)
	{
		_approve(_msgSender(), _spender, allowances[_msgSender()][_spender].sub(_subtractedValue, "ERC20: decreased allowance below zero"));
		return true;
	}

	function transfer(address _recipient, uint256 _amount) public virtual override returns (bool _success)
	{
		_transfer(_msgSender(), _recipient, _amount);
		return true;
	}

	function transferFrom(address _sender, address _recipient, uint256 _amount) public virtual override returns (bool _success)
	{
		_transfer(_sender, _recipient, _amount);
		_approve(_sender, _msgSender(), allowances[_sender][_msgSender()].sub(_amount, "ERC20: transfer amount exceeds allowance"));
		return true;
	}

	function _approve(address _owner, address _spender, uint256 _amount) internal virtual
	{
		require(_owner != address(0), "ERC20: approve from the zero address");
		require(_spender != address(0), "ERC20: approve to the zero address");
		allowances[_owner][_spender] = _amount;
		emit Approval(_owner, _spender, _amount);
	}

	function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual
	{
		uint256 _unscaledAmount = _unscale(_amount, scalingFactor);
		require(_sender != address(0), "ERC20: transfer from the zero address");
		require(_recipient != address(0), "ERC20: transfer to the zero address");
		_beforeTokenTransfer(_sender, _recipient, _amount);
		unscaledBalanceOf[_sender] = unscaledBalanceOf[_sender].sub(_unscaledAmount, "ERC20: transfer amount exceeds balance");
		unscaledBalanceOf[_recipient] = unscaledBalanceOf[_recipient].add(_unscaledAmount);
		emit Transfer(_sender, _recipient, _amount);
	}

	function _mint(address _account, uint256 _amount) internal virtual
	{
		uint256 _unscaledAmount = _unscale(_amount, scalingFactor);
		require(_account != address(0), "ERC20: mint to the zero address");
		_beforeTokenTransfer(address(0), _account, _amount);
		unscaledTotalSupply = unscaledTotalSupply.add(_unscaledAmount);
		uint256 _maxScalingFactor = _calcMaxScalingFactor(unscaledTotalSupply);
		require(scalingFactor <= _maxScalingFactor, "unsupported scaling factor");
		unscaledBalanceOf[_account] = unscaledBalanceOf[_account].add(_unscaledAmount);
		emit Transfer(address(0), _account, _amount);
	}

	function _burn(address _account, uint256 _amount) internal virtual
	{
		uint256 _unscaledAmount = _unscale(_amount, scalingFactor);
		require(_account != address(0), "ERC20: burn from the zero address");
		_beforeTokenTransfer(_account, address(0), _amount);
		unscaledBalanceOf[_account] = unscaledBalanceOf[_account].sub(_unscaledAmount, "ERC20: burn amount exceeds balance");
		unscaledTotalSupply = unscaledTotalSupply.sub(_unscaledAmount);
		emit Transfer(_account, address(0), _amount);
	}

	function _setupDecimals(uint8 _decimals) internal
	{
		decimals = _decimals;
	}

	function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual { }

	function _calcMaxScalingFactor(uint256 _unscaledTotalSupply) internal pure returns (uint256 _maxScalingFactor)
	{
		return uint256(-1) / _unscaledTotalSupply;
	}

	function _scale(uint256 _unscaledAmount, uint256 _scalingFactor) internal pure returns (uint256 _amount)
	{
		return _unscaledAmount.mul(_scalingFactor).div(1e24);
	}

	function _unscale(uint256 _amount, uint256 _scalingFactor) internal pure returns (uint256 _unscaledAmount)
	{
		return _amount.mul(1e24).div(_scalingFactor);
	}

	function _setScalingFactor(uint256 _scalingFactor) internal
	{
		uint256 _maxScalingFactor = _calcMaxScalingFactor(unscaledTotalSupply);
		require(0 < _scalingFactor && _scalingFactor <= _maxScalingFactor, "unsupported scaling factor");
		scalingFactor = _scalingFactor;
	}
}
