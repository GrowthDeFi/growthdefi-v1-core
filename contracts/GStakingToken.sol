// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GToken } from "./GToken.sol";
import { GFormulae } from "./GFormulae.sol";
import { G } from "./G.sol";

import { Math } from "./modules/Math.sol";

interface GStaking
{
	// view functions
	function rewardsToken() external view returns (address _rewardsToken);
	function totalStake() external view returns (uint256 _totalStake);
	function stakeOf(address _account) external view returns (uint256 _stake);
	function percentStakeOf(address _account) external view returns (uint256 _stakePercent);
	function averageStakePeriod() external view returns (uint256 _averageStakePeriod);
	function averageStakePeriodOf(address _account) external view returns (uint256 _averageStakePeriod);
	function totalRewards() external view returns (uint256 _totalLockedReward, uint256 _totalUnlockedReward);
	function maximumRewardOf(address _account) external view returns (uint256 _maximumReward);
	function currentRewardOf(address _account) external view returns (uint256 _currentReward);

	// open functions
	function depositReward(uint256 _amount, uint256 _rewardRatePerPeriod) external;
}

contract GStakingToken is ERC20, ReentrancyGuard, GToken, GStaking
{
	address public immutable override reserveToken;
	address public immutable override rewardsToken;

	mapping (address => uint256) lastAccountBlock;
	mapping (address => uint256) lastAccountStake;

	uint256 lastContractBlock;
	uint256 lastContractStake;
	uint256 lastUnlockedRewards;

	uint256 rewardRatePerPeriod;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken, address _rewardsToken)
		ERC20(_name, _symbol) public
	{
		assert(_reserveToken != _rewardsToken);
		_setupDecimals(_decimals);
		reserveToken = _reserveToken;
		rewardsToken = _rewardsToken;
	}

	function calcDepositSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) public pure override returns (uint256 _netShares, uint256 _feeShares)
	{
		return GFormulae._calcDepositSharesFromCost(_cost, _totalReserve, _totalSupply, _depositFee);
	}

	function calcDepositCostFromShares(uint256 _netShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _depositFee) public pure override returns (uint256 _cost, uint256 _feeShares)
	{
		return GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
	}

	function calcWithdrawalSharesFromCost(uint256 _cost, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) public pure override returns (uint256 _grossShares, uint256 _feeShares)
	{
		return GFormulae._calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
	}

	function calcWithdrawalCostFromShares(uint256 _grossShares, uint256 _totalReserve, uint256 _totalSupply, uint256 _withdrawalFee) public pure override returns (uint256 _cost, uint256 _feeShares)
	{
		return GFormulae._calcWithdrawalCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee);
	}

	function totalReserve() public view virtual override returns (uint256 _totalReserve)
	{
		return G.getBalance(reserveToken);
	}

	function depositFee() public view override returns (uint256 _depositFee) {
		return 0;
	}

	function withdrawalFee() public view override returns (uint256 _withdrawalFee) {
		return 0;
	}

	function totalStake() public view override returns (uint256 _totalStake)
	{
		uint256 _periods = block.number.sub(lastContractBlock);
		if (_periods == 0) return lastContractStake;
		return lastContractStake.add(totalSupply().mul(_periods));
	}

	function stakeOf(address _account) public view override returns (uint256 _stake)
	{
		uint256 _periods = block.number.sub(lastAccountBlock[_account]);
		if (_periods == 0) return lastAccountStake[_account];
		return lastAccountStake[_account].add(balanceOf(_account).mul(_periods));
	}

	function percentStakeOf(address _account) public view override returns (uint256 _stakePercent)
	{
		uint256 _totalStake = totalStake();
		if (_totalStake == 0) return 0;
		return stakeOf(_account).mul(1e18).div(_totalStake);
	}

	function averageStakePeriod() public view override returns (uint256 _averageStakePeriod)
	{
		uint256 _totalSupply = totalSupply();
		if (_totalSupply == 0) return 0;
		return totalStake().div(_totalSupply);
	}

	function averageStakePeriodOf(address _account) public view override returns (uint256 _averageStakePeriod)
	{
		uint256 _balance = balanceOf(_account);
		if (_balance == 0) return 0;
		return stakeOf(_account).div(_balance);
	}

	function totalRewards() public view override returns (uint256 _totalLockedReward, uint256 _totalUnlockedReward)
	{
		uint256 _periods = block.number.sub(lastContractBlock);
		uint256 _oldUnlocked = lastUnlockedRewards;
		uint256 _oldLocked = G.getBalance(rewardsToken).sub(_oldUnlocked);
		if (_periods == 0) return (_oldLocked, _oldUnlocked);
		uint256 _factor = Math._powi(uint256(1e18).sub(rewardRatePerPeriod), _periods);
		uint256 _newLocked = _oldLocked.mul(_factor).div(1e18);
		uint256 _newUnlocked = _oldUnlocked.add(_oldLocked.sub(_newLocked));
		return (_newLocked, _newUnlocked);
	}

	function maximumRewardOf(address _account) public view override returns (uint256 _maximumReward)
	{
		uint256 _totalStake = totalStake();
		if (_totalStake == 0) return 0;
		(,uint256 _totalUnlockedReward) = totalRewards();
		return _totalUnlockedReward.mul(stakeOf(_account)).div(_totalStake);
	}

	function currentRewardOf(address _account) public view override returns (uint256 _currentReward)
	{
		uint256 _factor = _calcRewardsFactor(averageStakePeriodOf(_account), averageStakePeriod());
		return maximumRewardOf(_account).mul(_factor).div(1e18);
	}

	function deposit(uint256 _amount) public override nonReentrant
	{
		address _from = msg.sender;
		require(_amount > 0, "amount must be greater than 0");
		_updateContract();
		_updateAccount(_from);
		G.pullFunds(reserveToken, _from, _amount);
		_mint(_from, _amount);
	}

	function withdraw(uint256 _amount) public override nonReentrant
	{
		address _from = msg.sender;
		require(_amount > 0, "amount must be greater than 0");
		uint256 _balance = balanceOf(_from);
		require(_amount <= _balance, "insuffcient balance");
		_updateContract();
		_updateAccount(_from);
		uint256 _removedStake = lastAccountStake[_from].mul(_amount).div(_balance);
		uint256 _maximumReward = lastUnlockedRewards.mul(_removedStake).div(lastContractStake);
		uint256 _factor = _calcRewardsFactor(averageStakePeriodOf(_from), averageStakePeriod());
		uint256 _reward = _maximumReward.mul(_factor).div(1e18);
		lastAccountStake[_from] = lastAccountStake[_from].sub(_removedStake);
		lastContractStake = lastContractStake.sub(_removedStake);
		lastUnlockedRewards = lastUnlockedRewards.sub(_reward);
		_burn(_from, _amount);
		G.pushFunds(reserveToken, _from, _amount);
		G.pushFunds(rewardsToken, _from, _reward);
	}

	function depositReward(uint256 _amount, uint256 _rewardRatePerPeriod) public override nonReentrant
	{
		address _from = msg.sender;
		require(_amount > 0, "amount must be greater than 0");
		require(1e12 <= _rewardRatePerPeriod && _rewardRatePerPeriod <= 1e18, "invalid rate");
		_updateContract();
		uint256 _reward = _amount.mul(_rewardRatePerPeriod).div(1e18);
		uint256 _oldLocked = G.getBalance(rewardsToken).sub(lastUnlockedRewards);
		uint256 _oldReward = _oldLocked.mul(rewardRatePerPeriod).div(1e18);
		uint256 _newLocked = _oldLocked.add(_amount);
		uint256 _newReward = _oldReward.add(_reward);
		rewardRatePerPeriod = _newReward.mul(1e18).div(_newLocked);
		G.pullFunds(rewardsToken, _from, _amount);
	}

	function _updateContract() internal
	{
		if (block.number > lastContractBlock) {
			(,lastUnlockedRewards) = totalRewards();
			lastContractStake = totalStake();
			lastContractBlock = block.number;
		}
	}

	function _updateAccount(address _account) internal
	{
		if (block.number > lastAccountBlock[_account]) {
			lastAccountStake[_account] = stakeOf(_account);
			lastAccountBlock[_account] = block.number;
		}
	}

	function _calcRewardsFactor(uint256 _periods, uint256 _maxPeriods) internal pure returns (uint256 _factor)
	{
		uint256 _boostedMaxPeriods = _maxPeriods.mul(11e17).div(1e18);
		if (_periods >= _boostedMaxPeriods) return 1e18;
		uint256 _percent = _periods.mul(1e18).div(_boostedMaxPeriods);
		return uint256(1e18).div(uint256(5e18).sub(uint256(4e18).mul(_percent)));
	}
}
