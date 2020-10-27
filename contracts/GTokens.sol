// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { GCTokenType1 } from "./GCTokenType1.sol";
import { GCTokenType2 } from "./GCTokenType2.sol";

import { $ } from "./network/$.sol";

/**
 * @notice Definition of gcDAI. As a gcToken Type 1, it uses cDAI as reserve
 * and employs leverage to maximize returns.
 */
contract gcDAI is GCTokenType1
{
	constructor ()
		GCTokenType1("growth cDAI", "gcDAI", 8, $.GRO, $.cDAI, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcUSDC. As a gcToken Type 1, it uses cUSDC as reserve
 * and employs leverage to maximize returns.
 */
contract gcUSDC is GCTokenType1
{
	constructor ()
		GCTokenType1("growth cUSDC", "gcUSDC", 8, $.GRO, $.cUSDC, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcUSDT. As a gcToken Type 1, it uses cUSDT as reserve
 * and employs leverage to maximize returns.
 */
contract gcUSDT is GCTokenType1
{
	constructor ()
		GCTokenType1("growth cUSDT", "gcUSDT", 8, $.GRO, $.cUSDT, $.COMP) public
	{
	}
}

/**
 * @notice Definition of gcETH. As a gcToken Type 2, it uses cETH as reserve
 * which serves as collateral for minting gcDAI.
 */
contract gcETH is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cETH", "gcETH", 8, $.GRO, $.cETH, $.COMP, _growthToken) public
	{
	}

	receive() external payable {} // not to be used directly
}

/**
 * @notice Definition of gcWBTC. As a gcToken Type 2, it uses cWBTC as reserve
 * which serves as collateral for minting gcDAI.
 */
contract gcWBTC is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cWBTC", "gcWBTC", 8, $.GRO, $.cWBTC, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcBAT. As a gcToken Type 2, it uses cBAT as reserve
 * which serves as collateral for minting gcDAI.
 */
contract gcBAT is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cBAT", "gcBAT", 8, $.GRO, $.cBAT, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcZRX. As a gcToken Type 2, it uses cZRX as reserve
 * which serves as collateral for minting gcDAI.
 */
contract gcZRX is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cZRX", "gcZRX", 8, $.GRO, $.cZRX, $.COMP, _growthToken) public
	{
	}
}

/**
 * @notice Definition of gcUNI. As a gcToken Type 2, it uses cUNI as reserve
 * which serves as collateral for minting gcDAI.
 */
contract gcUNI is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cUNI", "gcUNI", 8, $.GRO, $.cUNI, $.COMP, _growthToken) public
	{
	}
}
