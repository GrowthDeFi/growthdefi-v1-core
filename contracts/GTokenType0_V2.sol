// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GToken_V2 } from "./GToken_V2.sol";
import { GPortfolio } from "./GPortfolio.sol";
import { GTimeWeightedAveragePrice_V2 } from "./GTimeWeightedAveragePrice_V2.sol";
import { GPortfolioReserveManager_V2 } from "./GPortfolioReserveManager_V2.sol";

import { Math } from "./modules/Math.sol";
import { Transfers } from "./modules/Transfers.sol";

contract GTokenType0_V2 is ERC20, Ownable, ReentrancyGuard, GPortfolio, GToken_V2
{
	using GPortfolioReserveManager_V2 for GPortfolioReserveManager_V2.Self;
	using GTimeWeightedAveragePrice_V2 for GTimeWeightedAveragePrice_V2.Self;

	address public immutable override reserveToken;

	GPortfolioReserveManager_V2.Self prm;
	GTimeWeightedAveragePrice_V2.Self twap;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken)
		ERC20(_name, _symbol) public
	{
		_setupDecimals(_decimals);
		reserveToken = _reserveToken;
		prm.init(_reserveToken);
	}

	function calcDepositSharesFromCost(uint256 _cost) public view override returns (uint256 _shares)
	{
		uint256 _buyPrice = twap._calcAveragePrice(now);
		_buyPrice = Math._max(_buyPrice, twap.lastPrice);
		return _cost.mul(1e18).div(_buyPrice);
	}

	function calcDepositCostFromShares(uint256 _shares) public view override returns (uint256 _cost)
	{
		uint256 _buyPrice = twap._calcAveragePrice(now);
		_buyPrice = Math._max(_buyPrice, twap.lastPrice);
		return _shares.mul(_buyPrice).div(1e18);
	}

	function calcWithdrawalSharesFromCost(uint256 _cost) public view override returns (uint256 _shares)
	{
		uint256 _sellPrice = twap._calcAveragePrice(now);
		_sellPrice = Math._min(_sellPrice, twap.lastPrice);
		return _cost.mul(1e18).div(_sellPrice);
	}

	function calcWithdrawalCostFromShares(uint256 _shares) public view override returns (uint256 _cost)
	{
		uint256 _sellPrice = twap._calcAveragePrice(now);
		_sellPrice = Math._min(_sellPrice, twap.lastPrice);
		return _shares.mul(_sellPrice).div(1e18);
	}

	function totalReserve() public view override returns (uint256 _totalReserve)
	{
		return prm.totalReserve();
	}

	function tokenCount() external view override returns (uint256 _count)
	{
		return prm.tokenCount();
	}

	function tokenAt(uint256 _index) external view override returns (address _token)
	{
		return prm.tokenAt(_index);
	}

	function tokenPercent(address _token) external view override returns (uint256 _percent)
	{
		return prm.tokenPercent(_token);
	}

	function getRebalanceMargins() external view override returns (uint256 _liquidRebalanceMargin, uint256 _portfolioRebalanceMargin)
	{
		return (prm.liquidRebalanceMargin, prm.portfolioRebalanceMargin);
	}

	function deposit(uint256 _cost) external override nonReentrant
	{
		address _from = msg.sender;
		// require(_cost > 0, "cost must be greater than 0");
		uint256 _shares = calcDepositSharesFromCost(_cost);
		// require(_shares > 0, "shares must be greater than 0");
		Transfers._pullFunds(reserveToken, _from, _cost);
		// require(_prepareDeposit(_cost), "not available at the moment");
		_mint(_from, _shares);
	}

	function withdraw(uint256 _shares) external override nonReentrant
	{
		address _from = msg.sender;
		// require(_shares > 0, "shares must be greater than 0");
		uint256 _cost = calcWithdrawalCostFromShares(_shares);
		// require(_cost > 0, "cost must be greater than 0");
		// require(_prepareWithdrawal(_cost), "not available at the moment");
		// _cost = G.min(_cost, G.getBalance(reserveToken));
		if (_cost > Transfers._getBalance(reserveToken)) {
			prm.adjustReserve(_cost);
		}
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
	}

	function adjustReserve() external /*override*/ nonReentrant
	{
		require(prm.adjustReserve(0), "rebalance failure");
	}

	function updatePrice() external /*override*/ nonReentrant
	{
		uint256 _price = uint256(1e18).mul(totalReserve()).div(totalSupply());
		twap._recordPrice(now, _price);
	}

	function insertToken(address _token) external override onlyOwner nonReentrant
	{
		prm.insertToken(_token);
		emit InsertToken(_token);
	}

	function removeToken(address _token) external override onlyOwner nonReentrant
	{
		prm.removeToken(_token);
		emit RemoveToken(_token);
	}

	function anounceTokenPercentTransfer(address _sourceToken, address _targetToken, uint256 _percent) external override onlyOwner nonReentrant
	{
		prm.announceTokenPercentTransfer(_sourceToken, _targetToken, _percent);
		emit AnnounceTokenPercentTransfer(_sourceToken, _targetToken, _percent);
	}

	function transferTokenPercent(address _sourceToken, address _targetToken, uint256 _percent) external override onlyOwner nonReentrant
	{
		uint256 _oldSourceTokenPercent = prm.tokenPercent(_sourceToken);
		uint256 _oldTargetTokenPercent = prm.tokenPercent(_targetToken);
		prm.transferTokenPercent(_sourceToken, _targetToken, _percent);
		uint256 _newSourceTokenPercent = prm.tokenPercent(_sourceToken);
		uint256 _newTargetTokenPercent = prm.tokenPercent(_targetToken);
		emit TransferTokenPercent(_sourceToken, _targetToken, _percent);
		emit ChangeTokenPercent(_sourceToken, _oldSourceTokenPercent, _newSourceTokenPercent);
		emit ChangeTokenPercent(_targetToken, _oldTargetTokenPercent, _newTargetTokenPercent);
	}

	function setRebalanceMargins(uint256 _liquidRebalanceMargin, uint256 _portfolioRebalanceMargin) external override onlyOwner nonReentrant
	{
		prm.setRebalanceMargins(_liquidRebalanceMargin, _portfolioRebalanceMargin);
	}
}
