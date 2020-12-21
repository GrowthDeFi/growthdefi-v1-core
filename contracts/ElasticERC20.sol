// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Context } from "@openzeppelin/contracts/GSN/Context.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ElasticERC20 is Context, IERC20
{
	using SafeMath for uint256;

	uint8 public constant UNSCALED_DECIMALS = 24;
	uint256 public constant UNSCALED_FACTOR = 10 ** uint256(UNSCALED_DECIMALS);

	mapping (address => mapping (address => uint256)) private allowances_;

	mapping (address => uint256) private unscaledBalances_;
	uint256 private unscaledTotalSupply_;

	string private name_;
	string private symbol_;
	uint8 private decimals_;

	uint256 private scalingFactor_;

	constructor (string memory _name, string memory _symbol) public
	{
		name_ = _name;
		symbol_ = _symbol;
		_setupDecimals(18);
	}

	function name() public view returns (string memory _name)
	{
		return name_;
	}

	function symbol() public view returns (string memory _symbol)
	{
		return symbol_;
	}

	function decimals() public view returns (uint8 _decimals)
	{
		return decimals_;
	}

	function totalSupply() public view override returns (uint256 _supply)
	{
		return _scale(unscaledTotalSupply_, scalingFactor_);
	}

	function balanceOf(address _account) public view override returns (uint256 _balance)
	{
		return _scale(unscaledBalances_[_account], scalingFactor_);
	}

	function allowance(address _owner, address _spender) public view virtual override returns (uint256 _allowance)
	{
		return allowances_[_owner][_spender];
	}

	function approve(address _spender, uint256 _amount) public virtual override returns (bool _success)
	{
		_approve(_msgSender(), _spender, _amount);
		return true;
	}

	function increaseAllowance(address _spender, uint256 _addedValue) public virtual returns (bool _success)
	{
		_approve(_msgSender(), _spender, allowances_[_msgSender()][_spender].add(_addedValue));
		return true;
	}

	function decreaseAllowance(address _spender, uint256 _subtractedValue) public virtual returns (bool _success)
	{
		_approve(_msgSender(), _spender, allowances_[_msgSender()][_spender].sub(_subtractedValue, "ERC20: decreased allowance below zero"));
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
		_approve(_sender, _msgSender(), allowances_[_sender][_msgSender()].sub(_amount, "ERC20: transfer amount exceeds allowance"));
		return true;
	}

	function _approve(address _owner, address _spender, uint256 _amount) internal virtual
	{
		require(_owner != address(0), "ERC20: approve from the zero address");
		require(_spender != address(0), "ERC20: approve to the zero address");
		allowances_[_owner][_spender] = _amount;
		emit Approval(_owner, _spender, _amount);
	}

	function _transfer(address _sender, address _recipient, uint256 _amount) internal virtual
	{
		uint256 _unscaledAmount = _unscale(_amount, scalingFactor_);
		require(_sender != address(0), "ERC20: transfer from the zero address");
		require(_recipient != address(0), "ERC20: transfer to the zero address");
		_beforeTokenTransfer(_sender, _recipient, _amount);
		unscaledBalances_[_sender] = unscaledBalances_[_sender].sub(_unscaledAmount, "ERC20: transfer amount exceeds balance");
		unscaledBalances_[_recipient] = unscaledBalances_[_recipient].add(_unscaledAmount);
		emit Transfer(_sender, _recipient, _amount);
	}

	function _mint(address _account, uint256 _amount) internal virtual
	{
		uint256 _unscaledAmount = _unscale(_amount, scalingFactor_);
		require(_account != address(0), "ERC20: mint to the zero address");
		_beforeTokenTransfer(address(0), _account, _amount);
		unscaledTotalSupply_ = unscaledTotalSupply_.add(_unscaledAmount);
		uint256 _maxScalingFactor = _calcMaxScalingFactor(unscaledTotalSupply_);
		require(scalingFactor_ <= _maxScalingFactor, "unsupported scaling factor");
		unscaledBalances_[_account] = unscaledBalances_[_account].add(_unscaledAmount);
		emit Transfer(address(0), _account, _amount);
	}

	function _burn(address _account, uint256 _amount) internal virtual
	{
		uint256 _unscaledAmount = _unscale(_amount, scalingFactor_);
		require(_account != address(0), "ERC20: burn from the zero address");
		_beforeTokenTransfer(_account, address(0), _amount);
		unscaledBalances_[_account] = unscaledBalances_[_account].sub(_unscaledAmount, "ERC20: burn amount exceeds balance");
		unscaledTotalSupply_ = unscaledTotalSupply_.sub(_unscaledAmount);
		emit Transfer(_account, address(0), _amount);
	}

	function _setupDecimals(uint8 _decimals) internal
	{
		decimals_ = _decimals;
		scalingFactor_ = 10 ** uint256(_decimals);
	}

	function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal virtual { }

	function unscaledTotalSupply() public view returns (uint256 _supply)
	{
		return unscaledTotalSupply_;
	}

	function unscaledBalanceOf(address _account) public view returns (uint256 _balance)
	{
		return unscaledBalances_[_account];
	}

	function scalingFactor() public view returns (uint256 _scalingFactor)
	{
		return scalingFactor_;
	}

	function maxScalingFactor() public view returns (uint256 _maxScalingFactor)
	{
		return _calcMaxScalingFactor(unscaledTotalSupply_);
	}

	function _calcMaxScalingFactor(uint256 _unscaledTotalSupply) internal pure returns (uint256 _maxScalingFactor)
	{
		return uint256(-1).div(_unscaledTotalSupply);
	}

	function _scale(uint256 _unscaledAmount, uint256 _scalingFactor) internal pure returns (uint256 _amount)
	{
		return _unscaledAmount.mul(_scalingFactor).div(UNSCALED_FACTOR);
	}

	function _unscale(uint256 _amount, uint256 _scalingFactor) internal pure returns (uint256 _unscaledAmount)
	{
		return _amount.mul(UNSCALED_FACTOR).div(_scalingFactor);
	}

	function _setScalingFactor(uint256 _scalingFactor) internal
	{
		uint256 _maxScalingFactor = _calcMaxScalingFactor(unscaledTotalSupply_);
		require(0 < _scalingFactor && _scalingFactor <= _maxScalingFactor, "unsupported scaling factor");
		scalingFactor_ = _scalingFactor;
	}
}
