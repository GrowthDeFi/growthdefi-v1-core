// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GTokenBase } from "./GTokenBase.sol";
import { GPortfolioReserveManager } from "./GPortfolioReserveManager.sol";

contract GTokenType0 is GTokenBase
{
	using GPortfolioReserveManager for GPortfolioReserveManager.Self;

	GPortfolioReserveManager.Self prm;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakesToken, address _reserveToken)
		GTokenBase(_name, _symbol, _decimals, _stakesToken, _reserveToken) public
	{
		prm.init(_reserveToken);
	}

	function totalReserve() public view virtual override returns (uint256 _totalReserve)
	{
		return prm.totalReserve();
	}

	function tokenCount() public view returns (uint256 _count)
	{
		return prm.tokenCount();
	}

	function tokenAt(uint256 _index) public view returns (address _token)
	{
		return prm.tokenAt(_index);
	}

	function tokenPercent(address _token) public view returns (uint256 _percent)
	{
		return prm.tokenPercent(_token);
	}

	function getRebalanceMargin() public view returns (uint256 _rebalanceMargin)
	{
		return prm.rebalanceMargin;
	}

	function insertToken(address _token) public onlyOwner nonReentrant
	{
		prm.insertToken(_token);
	}

	function removeToken(address _token) public onlyOwner nonReentrant
	{
		prm.removeToken(_token);
	}

	function transferTokenPercent(address _sourceToken, address _targetToken, uint256 _percent) public onlyOwner nonReentrant
	{
		prm.transferTokenPercent(_sourceToken, _targetToken, _percent);
	}

	function setRebalanceMargin(uint256 _rebalanceMargin) public onlyOwner nonReentrant
	{
		prm.setRebalanceMargin(_rebalanceMargin);
	}

	function _prepareDeposit(uint256 /* _cost */) internal override returns (bool _success)
	{
		return prm.adjustReserve(0);
	}

	function _prepareWithdrawal(uint256 _cost) internal override returns (bool _success)
	{
		return prm.adjustReserve(_cost);
	}
}
