// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { GTokenType0 } from "./GTokenType0.sol";
import { GCTokenType1 } from "./GCTokenType1.sol";
import { GCTokenType2 } from "./GCTokenType2.sol";
import { GTokenType3 } from "./GTokenType3.sol";
import { GElasticToken } from "./GElasticToken.sol";

import { $ } from "./network/$.sol";

/**
 * @notice Definition of gDAI. As a gToken Type 0, it uses DAI as reserve and
 * distributes to other gToken types.
 */
contract gDAI is GTokenType0
{
	constructor ()
		GTokenType0("growth DAI", "gDAI", 18, $.GRO, $.DAI) public
	{
	}
}

/**
 * @notice Definition of gUSDC. As a gToken Type 0, it uses USDC as reserve and
 * distributes to other gToken types.
 */
contract gUSDC is GTokenType0
{
	constructor ()
		GTokenType0("growth USDC", "gUSDC", 6, $.GRO, $.USDC) public
	{
	}
}

/**
 * @notice Definition of gETH. As a gToken Type 0, it uses WETH as reserve and
 * distributes to other gToken types.
 */
contract gETH is GTokenType0
{
	constructor ()
		GTokenType0("growth ETH", "gETH", 18, $.GRO, $.WETH) public
	{
	}
}

/**
 * @notice Definition of gWBTC. As a gToken Type 0, it uses WBTC as reserve and
 * distributes to other gToken types.
 */
contract gWBTC is GTokenType0
{
	constructor ()
		GTokenType0("growth WBTC", "gWBTC", 8, $.GRO, $.WBTC) public
	{
	}
}

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
 * @notice Definition of gcETH. As a gcToken Type 2, it uses cETH as reserve
 * which serves as collateral for minting gDAI.
 */
contract gcETH is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cETH", "gcETH", 8, $.GRO, $.cETH, $.COMP, $.cDAI, _growthToken) public
	{
	}

	receive() external payable {} // not to be used directly
}

/**
 * @notice Definition of gcWBTC. As a gcToken Type 2, it uses cWBTC as reserve
 * which serves as collateral for minting gDAI.
 */
contract gcWBTC is GCTokenType2
{
	constructor (address _growthToken)
		GCTokenType2("growth cWBTC", "gcWBTC", 8, $.GRO, $.cWBTC, $.COMP, $.cDAI, _growthToken) public
	{
	}
}

/**
 * @notice Definition of stkGRO. As a gToken Type 3, it uses GRO as reserve and
 * burns both reserve and supply with each operation.
 */
contract stkGRO is GTokenType3
{
	constructor ()
		GTokenType3("staked GRO", "stkGRO", 18, $.GRO) public
	{
	}
}

/**
 * @notice Definition of rAAVE. As a gToken Type 4, it is an elastic supply
 * token that uses AAVE as reference token.
 */
contract rAAVE is GElasticToken
{
	constructor (uint256 _initialSupply)
		GElasticToken("rebase AAVE", "rAAVE", 18, $.AAVE, _initialSupply) public
	{
	}
}
