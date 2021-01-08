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
	uint256 constant DEFAULT_PERFORMANCE_FEE = 10e16; // 10%
	uint256 constant DEFAULT_REWARD_RATE_PER_WEEK = 1e16; // 1%

	address public immutable /*override*/ reserveToken;
	address public immutable /*override*/ rewardsToken;

	address public treasury;

	uint256 public performanceFee = DEFAULT_PERFORMANCE_FEE;
	uint256 public rewardRatePerWeek = DEFAULT_REWARD_RATE_PER_WEEK;

	uint256 lastContractBlock = block.number;
	uint256 lastRewardPerBlock = 0;
	uint256 lastUnlockedReward = 0;
	uint256 lastLockedReward = 0;

	uint256 lastTotalSupply = 1;
	uint256 lastTotalReserve = 1;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken, address _rewardsToken, address _treasury)
		ERC20(_name, _symbol) public
	{
		_setupDecimals(_decimals);
		assert(_reserveToken != _rewardsToken);
		reserveToken = _reserveToken;
		rewardsToken = _rewardsToken;
		treasury = _treasury;
		// just after creation it must transfer 1 wei from reserveToken
		// into this contract
		// this must be performed manually because we cannot approve
		// the spending by this contract before it exists
		// Transfers._pullFunds(_reserveToken, _from, 1);
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

	function rewardInfo() public view /*override*/ returns (uint256 _lockedReward, uint256 _unlockedReward, uint256 _rewardPerBlock)
	{
		(, _rewardPerBlock, _unlockedReward, _lockedReward) = _calcCurrentRewards();
		return (_lockedReward, _unlockedReward, _rewardPerBlock);
	}

	function deposit(uint256 _cost) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _shares = calcSharesFromCost(_cost);
		Transfers._pullFunds(reserveToken, _from, _cost);
		_mint(_from, _shares);
	}

	function withdraw(uint256 _shares) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
	}

	function gulpRewards() external /*override*/ nonReentrant
	{
		_updateRewards();
		UniswapV2LiquidityPoolAbstraction._joinPool(reserveToken, rewardsToken, lastUnlockedReward, 1);
		lastUnlockedReward = 0;
	}

	function gulpFees() external /*override*/ nonReentrant
	{
		uint256 _oldTotalSupply = lastTotalSupply;
		uint256 _oldTotalReserve = lastTotalReserve;

		uint256 _newTotalSupply = totalSupply();
		uint256 _newTotalReserve = totalReserve();

		// calculates the profit using the following formula
		// ((P1 - P0) * S1 * f) / P1
		// where P1 = R1 / S1 and P0 = R0 / S0
		uint256 _positive = _oldTotalSupply.mul(_newTotalReserve);
		uint256 _negative = _newTotalSupply.mul(_oldTotalReserve);
		if (_positive > _negative) {
			uint256 _profitCost = _positive.sub(_negative).div(_oldTotalSupply);
			uint256 _feeCost = _profitCost.mul(performanceFee).div(1e18);
			uint256 _feeShares = calcSharesFromCost(_feeCost);
			_mint(treasury, _feeShares);
		}

		lastTotalSupply = _newTotalSupply;
		lastTotalReserve = _newTotalReserve;
	}

	function setTreasury(address _treasury) external /*override*/ onlyOwner nonReentrant
	{
		require(_treasury != address(0), "invalid address");
		treasury = _treasury;
	}

	function setPerformanceFee(uint256 _performanceFee) external /*override*/ onlyOwner nonReentrant
	{
		require(_performanceFee <= 1e18, "invalid rate");
		performanceFee = _performanceFee;
	}

	function setRewardRatePerWeek(uint256 _rewardRatePerWeek) external /*override*/ onlyOwner nonReentrant
	{
		require(_rewardRatePerWeek <= 1e18, "invalid rate");
		rewardRatePerWeek = _rewardRatePerWeek;
	}

	function _updateRewards() internal
	{
		(lastContractBlock, lastRewardPerBlock, lastUnlockedReward, lastLockedReward) = _calcCurrentRewards();
		uint256 _balanceReward = Transfers._getBalance(rewardsToken);
		uint256 _totalReward = lastLockedReward.add(lastUnlockedReward);
		if (_balanceReward > _totalReward) {
			uint256 _newLockedReward = _balanceReward.sub(_totalReward);
			uint256 _newRewardPerBlock = _calcRewardPerBlock(_newLockedReward);
			lastRewardPerBlock = lastRewardPerBlock.add(_newRewardPerBlock);
			lastLockedReward = lastLockedReward.add(_newLockedReward);
		}
		else
		if (_balanceReward < _totalReward) {
			uint256 _removedLockedReward = _totalReward.sub(_balanceReward);
			uint256 _removedRewardPerBlock = _calcRewardPerBlock(_removedLockedReward);
			if (_removedLockedReward >= lastLockedReward) {
				_removedRewardPerBlock = lastLockedReward;
				_removedLockedReward = lastRewardPerBlock;
			}
			lastRewardPerBlock = lastRewardPerBlock.sub(_removedRewardPerBlock);
			lastLockedReward = lastLockedReward.sub(_removedLockedReward);
			lastUnlockedReward = _balanceReward.sub(lastLockedReward);
		}
	}

	function _calcCurrentRewards() internal view returns (uint256 _currentContractBlock, uint256 _currentRewardPerBlock, uint256 _currentUnlockedReward, uint256 _currentLockedReward)
	{
		uint256 _contractBlock = lastContractBlock;
		uint256 _rewardPerBlock = lastRewardPerBlock;
		uint256 _unlockedReward = lastUnlockedReward;
		uint256 _lockedReward = lastLockedReward;
		if (_contractBlock < block.number) {
			uint256 _week = _contractBlock.div(BLOCKS_PER_WEEK);
			uint256 _offset = _contractBlock.mod(BLOCKS_PER_WEEK);

			_contractBlock = block.number;
			uint256 _currentWeek = _contractBlock.div(BLOCKS_PER_WEEK);
			uint256 _currentOffset = _contractBlock.mod(BLOCKS_PER_WEEK);

			while (_week < _currentWeek) {
				uint256 _blocks = BLOCKS_PER_WEEK.sub(_offset);
				uint256 _reward = _blocks.mul(_rewardPerBlock);
				_unlockedReward = _unlockedReward.add(_reward);
				_lockedReward = _lockedReward.sub(_reward);
				_rewardPerBlock = _calcRewardPerBlock(_lockedReward);
				_week++;
				_offset = 0;
			}

			uint256 _blocks = _currentOffset.sub(_offset);
			uint256 _reward = _blocks.mul(_rewardPerBlock);
			_unlockedReward = _unlockedReward.add(_reward);
			_lockedReward = _lockedReward.sub(_reward);
		}
		return (_contractBlock, _rewardPerBlock, _unlockedReward, _lockedReward);
	}

	function _calcRewardPerBlock(uint256 _lockedReward) internal view returns (uint256 _rewardPerBlock)
	{
		return _lockedReward.mul(rewardRatePerWeek).div(1e18).div(BLOCKS_PER_WEEK);
	}
}
