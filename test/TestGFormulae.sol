// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Assert } from "truffle/Assert.sol";

import { Env } from "./Env.sol";

import { GFormulae } from "../contracts/GFormulae.sol";

contract TestGFormulae is Env
{
	/* deposit(cost):
	 *   price = reserve / supply = 1
	 *   gross = cost / price     = 100e18
	 *   net = gross * 0.99       =  99e18
	 *   fee = gross - net        =   1e18
	 *   return net, fee
	 */
	function test01() public
	{
		uint256 _cost1 = 100e18;
		uint256 _totalReserve = 1000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _depositFee = 1e16;
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 99e18, "net shares must be 99e18");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	/* deposit(cost):
	 *   price = reserve / supply = 1
	 *   gross = cost / price     = 10e18
	 *   net = gross * 0.99       = 99e17
	 *   fee = gross - net        =  1e17
	 *   return net, fee
	 */
	function test011() public
	{
		uint256 _cost1 = 10e18;
		uint256 _totalReserve = 100e18;
		uint256 _totalSupply = 100e18;
		uint256 _depositFee = 1e16;
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 99e17, "net shares must be 99e17");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	/* deposit(cost):
	 *   price = reserve / supply = 1
	 *   gross = cost / price     = 100e18
	 *   net = gross * 0.99       =  99e18
	 *   fee = gross - net        =   1e18
	 *   return net, fee
	 */
	function test012() public
	{
		uint256 _cost1 = 100e18;
		uint256 _totalReserve = 1000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _depositFee = 1e15;
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 99e18, "net shares must be 99e18");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	/* deposit(cost):
	 *   price = reserve / supply = 1
	 *   gross = cost / price     = 10e18
	 *   net = gross * 0.99       = 99e17
	 *   fee = gross - net        =  1e17
	 *   return net, fee
	 */
	function test013() public
	{
		uint256 _cost1 = 10e18;
		uint256 _totalReserve = 100e18;
		uint256 _totalSupply = 100e18;
		uint256 _depositFee = 1e16; //back to _depositFee == _cost1 / 1000 , this test passes
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 99e17, "net shares must be 99e17");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test02() public
	{
		uint256 _grossShares1 = 100e18;
		uint256 _totalReserve = 1000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _withdrawalFee = 1e16;
		(uint256 _cost, uint256 _feeShares1) = GFormulae._calcWithdrawalCostFromShares(_grossShares1, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_cost, 99e18, "cost must be 99e18");
		(uint256 _grossShares2, uint256 _feeShares2) = GFormulae._calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_grossShares1, _grossShares2, "gross shares must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test03() public
	{
		uint256 _cost1 = 100e18;
		uint256 _totalReserve = 1000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _depositFee = 0e16;
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 100e18, "net shares must be 100e18");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test04() public
	{
		uint256 _grossShares1 = 100e18;
		uint256 _totalReserve = 1000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _withdrawalFee = 0e16;
		(uint256 _cost, uint256 _feeShares1) = GFormulae._calcWithdrawalCostFromShares(_grossShares1, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_cost, 100e18, "cost must be 100e18");
		(uint256 _grossShares2, uint256 _feeShares2) = GFormulae._calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_grossShares1, _grossShares2, "gross shares must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test05() public
	{
		uint256 _cost1 = 1000e18;
		uint256 _totalReserve = 2000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _depositFee = 1e16;
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 495e18, "net shares must be 495e18");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test06() public
	{
		uint256 _grossShares1 = 100e18;
		uint256 _totalReserve = 2000e18;
		uint256 _totalSupply = 1000e18;
		uint256 _withdrawalFee = 1e16;
		(uint256 _cost, uint256 _feeShares1) = GFormulae._calcWithdrawalCostFromShares(_grossShares1, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_cost, 198e18, "cost must be 198e18");
		(uint256 _grossShares2, uint256 _feeShares2) = GFormulae._calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_grossShares1, _grossShares2, "gross shares must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test07() public
	{
		uint256 _cost1 = 100e18;
		uint256 _totalReserve = 0e18;
		uint256 _totalSupply = 0e18;
		uint256 _depositFee = 0e16;
		(uint256 _netShares, uint256 _feeShares1) = GFormulae._calcDepositSharesFromCost(_cost1, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_netShares, 100e18, "net shares must be 100e18");
		(uint256 _cost2, uint256 _feeShares2) = GFormulae._calcDepositCostFromShares(_netShares, _totalReserve, _totalSupply, _depositFee);
		Assert.equal(_cost1, _cost2, "costs must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}

	function test08() public
	{
		uint256 _grossShares1 = 100e18;
		uint256 _totalReserve = 2000e18;
		uint256 _totalSupply = 100e18;
		uint256 _withdrawalFee = 0e16;
		(uint256 _cost, uint256 _feeShares1) = GFormulae._calcWithdrawalCostFromShares(_grossShares1, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_cost, 2000e18, "cost must be 2000e18");
		(uint256 _grossShares2, uint256 _feeShares2) = GFormulae._calcWithdrawalSharesFromCost(_cost, _totalReserve, _totalSupply, _withdrawalFee);
		Assert.equal(_grossShares1, _grossShares2, "gross shares must be equal");
		Assert.equal(_feeShares1, _feeShares2, "fee shares must be equal");
	}
}
