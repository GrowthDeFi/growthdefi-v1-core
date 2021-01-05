// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { Math } from "./modules/Math.sol";
import { Transfers } from "./modules/Transfers.sol";
import { UniswapV2LiquidityPoolAbstraction } from "./modules/UniswapV2LiquidityPoolAbstraction.sol";

contract GLPMiningToken is ERC20, Ownable, ReentrancyGuard//, GToken, GStaking
{
	uint256 constant BLOCKS_PER_WEEK = 7 days / 15 seconds;
	uint256 constant DEFAULT_PERFORMANCE_FEE = 1e15; // 0.1%
	uint256 constant MAXIMUM_PERFORMANCE_FEE = 10e16; // 10%

	address public immutable /*override*/ reserveToken;
	address public immutable /*override*/ rewardsToken;

	address public treasury;
	uint256 public performanceFee = DEFAULT_PERFORMANCE_FEE;

	uint256 lastContractBlock;
	uint256 lastUnlockedRewards;
	uint256 rewardRatePerBlock;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken, address _rewardsToken, address _treasury)
		ERC20(_name, _symbol) public
	{
		address _from = msg.sender;
		_setupDecimals(_decimals);
		reserveToken = _reserveToken;
		rewardsToken = _rewardsToken;
		treasury = _treasury;
		assert(_reserveToken != _rewardsToken);
		Transfers._pullFunds(_reserveToken, _from, 1);
		_mint(address(this), 1);
	}

	function calcSharesFromCost(uint256 _cost) public view /*override*/ returns (uint256 _shares)
	{
		return _cost.mul(totalSupply()).div(totalReserve());
	}

	function calcCostFromShares(uint256 _shares) public view /*override*/ returns (uint256 _cost)
	{
		return _shares.mul(totalReserve()).div(totalSupply());
	}

	function totalReserve() public view /*virtual override*/ returns (uint256 _totalReserve)
	{
		return Transfers._getBalance(reserveToken);
	}

	function totalRewards() public view /*override*/ returns (uint256 _totalLockedReward, uint256 _totalUnlockedReward)
	{
		uint256 _oldUnlocked = lastUnlockedRewards;
		uint256 _oldLocked = Transfers._getBalance(rewardsToken).sub(_oldUnlocked);
		uint256 _blocks = block.number.sub(lastContractBlock);
		if (_blocks == 0) return (_oldLocked, _oldUnlocked);



		uint256 _factor = Math._powi(uint256(1e18).sub(rewardRatePerBlock), _blocks);
		uint256 _newLocked = _oldLocked.mul(_factor).div(1e18);
		uint256 _newUnlocked = _oldUnlocked.add(_oldLocked.sub(_newLocked));
		return (_newLocked, _newUnlocked);
	}

	function deposit(uint256 _cost, uint256 _minShares) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _shares = calcSharesFromCost(_cost);
		require(_shares >= _minShares, "minimum not met");
		Transfers._pullFunds(reserveToken, _from, _cost);
		_mint(_from, _shares);
	}

	function withdraw(uint256 _shares, uint256 _minCost) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		require(_cost >= _minCost, "minimum not met");
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
	}

	function adjustReserve() external /*override*/ nonReentrant
	{
		_updateRewards();
		uint256 _profitCost = UniswapV2LiquidityPoolAbstraction._joinPool(reserveToken, rewardsToken, lastUnlockedRewards, 1);
		lastUnlockedRewards = 0;
		uint256 _feeCost = _profitCost.mul(performanceFee).div(1e18);
		uint256 _feeShares = calcSharesFromCost(_feeCost);
		_mint(treasury, _feeShares);
	}

	function setTreasury(address _treasury) external /*override*/ onlyOwner nonReentrant
	{
		require(_treasury != address(0), "invalid address");
		treasury = _treasury;
	}

	function setPerformanceFee(uint256 _performanceFee) external /*override*/ onlyOwner nonReentrant
	{
		require(_performanceFee <= MAXIMUM_PERFORMANCE_FEE, "invalid rate");
		performanceFee = _performanceFee;
	}

	function _updateRewards() internal
	{
		if (block.number > lastContractBlock) {
			(,lastUnlockedRewards) = totalRewards();
			lastContractBlock = block.number;
		}
	}
}
