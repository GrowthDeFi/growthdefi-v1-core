// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GToken } from "./GToken.sol";
import { GFormulae } from "./GFormulae.sol";
import { GLiquidityPoolManager } from "./GLiquidityPoolManager.sol";
import { G } from "./G.sol";

abstract contract GTokenBase is ERC20, Ownable, ReentrancyGuard, GToken
{
	using GLiquidityPoolManager for GLiquidityPoolManager.Self;

	uint256 constant DEFAULT_DEPOSIT_FEE = 1e16; // 1%
	uint256 constant DEFAULT_WITHDRAWAL_FEE = 1e16; // 1%
	uint256 constant MAXIMUM_DEPOSIT_FEE = 2e16; // 2%
	uint256 constant MAXIMUM_WITHDRAWAL_FEE = 2e16; // 2%

	address public immutable override stakesToken;
	address public immutable override reserveToken;

	uint256 private operatingDepositFee = DEFAULT_DEPOSIT_FEE;
	uint256 private operatingWithdrawalFee = DEFAULT_WITHDRAWAL_FEE;

	GLiquidityPoolManager.Self lpm;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakesToken, address _reserveToken)
		ERC20(_name, _symbol) public
	{
		_setupDecimals(_decimals);
		stakesToken = _stakesToken;
		reserveToken = _reserveToken;
		lpm.init(_stakesToken, address(this));
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
		return lpm.hasPool() ? operatingDepositFee : 0;
	}

	function withdrawalFee() public view override returns (uint256 _withdrawalFee) {
		return lpm.hasPool() ? operatingWithdrawalFee : 0;
	}

	function liquidityPool() public view override returns (address _liquidityPool)
	{
		return lpm.liquidityPool;
	}

	function liquidityPoolBurningRate() public view override returns (uint256 _burningRate)
	{
		return lpm.burningRate;
	}

	function liquidityPoolLastBurningTime() public view override returns (uint256 _lastBurningTime)
	{
		return lpm.lastBurningTime;
	}

	function liquidityPoolMigrationRecipient() public view override returns (address _migrationRecipient)
	{
		return lpm.migrationRecipient;
	}

	function liquidityPoolMigrationUnlockTime() public view override returns (uint256 _migrationUnlockTime)
	{
		return lpm.migrationUnlockTime;
	}

	function deposit(uint256 _cost) public override nonReentrant
	{
		address _from = msg.sender;
		require(_cost > 0, "cost must be greater than 0");
		(uint256 _netShares, uint256 _feeShares) = GFormulae._calcDepositSharesFromCost(_cost, totalReserve(), totalSupply(), depositFee());
		require(_netShares > 0, "shares must be greater than 0");
		G.pullFunds(reserveToken, _from, _cost);
		require(_prepareDeposit(_cost), "not available at the moment");
		_mint(_from, _netShares);
		_mint(address(this), _feeShares.div(2));
		lpm.gulpPoolAssets();
	}

	function withdraw(uint256 _grossShares) public override nonReentrant
	{
		address _from = msg.sender;
		require(_grossShares > 0, "shares must be greater than 0");
		(uint256 _cost, uint256 _feeShares) = GFormulae._calcWithdrawalCostFromShares(_grossShares, totalReserve(), totalSupply(), withdrawalFee());
		require(_cost > 0, "cost must be greater than 0");
		require(_prepareWithdrawal(_cost), "not available at the moment");
		_cost = G.min(_cost, G.getBalance(reserveToken));
		G.pushFunds(reserveToken, _from, _cost);
		_burn(_from, _grossShares);
		_mint(address(this), _feeShares.div(2));
		lpm.gulpPoolAssets();
	}

	function setFees(uint256 _depositFee, uint256 _withdrawalFee) public override onlyOwner nonReentrant
	{
		require(lpm.hasPool(), "pool must be available");
		require(_depositFee <= MAXIMUM_DEPOSIT_FEE, "deposit fee exceeds the limit");
		require(_withdrawalFee <= MAXIMUM_WITHDRAWAL_FEE, "withdrawal fee exceeds the limit");
		operatingDepositFee = _depositFee;
		operatingWithdrawalFee = _withdrawalFee;
		emit UpdateFees(_depositFee, _withdrawalFee);
	}

	function allocateLiquidityPool(uint256 _stakesAmount, uint256 _sharesAmount) public override onlyOwner nonReentrant
	{
		address _from = msg.sender;
		G.pullFunds(stakesToken, _from, _stakesAmount);
		_transfer(_from, address(this), _sharesAmount);
		lpm.allocatePool(_stakesAmount, _sharesAmount);
	}

	function setLiquidityPoolBurningRate(uint256 _burningRate) public override onlyOwner nonReentrant
	{
		lpm.setBurningRate(_burningRate);
	}

	function burnLiquidityPoolPortion() public override onlyOwner nonReentrant
	{
		(uint256 _stakesAmount, uint256 _sharesAmount) = lpm.burnPoolPortion();
		_burnStakes(_stakesAmount);
		_burn(address(this), _sharesAmount);
		emit BurnLiquidityPoolPortion(_stakesAmount, _sharesAmount);
	}

	function initiateLiquidityPoolMigration(address _migrationRecipient) public override onlyOwner nonReentrant
	{
		lpm.initiatePoolMigration(_migrationRecipient);
		emit InitiateLiquidityPoolMigration(_migrationRecipient);
	}

	function cancelLiquidityPoolMigration() public override onlyOwner nonReentrant
	{
		address _migrationRecipient = lpm.cancelPoolMigration();
		emit CancelLiquidityPoolMigration(_migrationRecipient);
	}

	function completeLiquidityPoolMigration() public override onlyOwner nonReentrant
	{
		(address _migrationRecipient, uint256 _stakesAmount, uint256 _sharesAmount) = lpm.completePoolMigration();
		G.pushFunds(stakesToken, _migrationRecipient, _stakesAmount);
		_transfer(address(this), _migrationRecipient, _sharesAmount);
		emit CompleteLiquidityPoolMigration(_migrationRecipient, _stakesAmount, _sharesAmount);
	}

	function _prepareDeposit(uint256 _cost) internal virtual returns (bool _success);
	function _prepareWithdrawal(uint256 _cost) internal virtual returns (bool _success);

	function _burnStakes(uint256 _stakesAmount) internal virtual
	{
		G.pushFunds(stakesToken, address(0), _stakesAmount);
	}
}
