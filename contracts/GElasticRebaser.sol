// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import { UniswapV2OracleLibrary } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";

import { GElasticToken } from "./GElasticToken.sol";

interface UniswapPair
{
	function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
	function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
	function sync() external;
}

interface BPool
{
	function gulp(address token) external;
}

contract TransactionsExt is Ownable
{
	struct Transaction {
		bool enabled;
		address destination;
		bytes data;
	}

	// Stable ordering is not guaranteed.
	Transaction[] public transactions;

	/**
	 * @notice Adds a transaction that gets called for a downstream receiver of rebases
	 * @param destination Address of contract destination
	 * @param data Transaction data payload
	 */
	function addTransaction(address destination, bytes calldata data) external onlyOwner
	{
		transactions.push(Transaction({
			enabled: true,
			destination: destination,
			data: data
		}));
	}

	/**
	 * @param index Index of transaction to remove.
	 *              Transaction ordering may have changed since adding.
	 */
	function removeTransaction(uint index) external onlyOwner
	{
		require(index < transactions.length, "index out of bounds");
		if (index < transactions.length - 1) {
			transactions[index] = transactions[transactions.length - 1];
		}
		transactions.pop();
	}

	/**
	 * @param index Index of transaction. Transaction ordering may have changed since adding.
	 * @param enabled True for enabled, false for disabled.
	 */
	function setTransactionEnabled(uint index, bool enabled) external onlyOwner
	{
		require(index < transactions.length, "index must be in range of stored tx list");
		transactions[index].enabled = enabled;
	}

	function executeTransactions() internal
	{
		for (uint i = 0; i < transactions.length; i++) {
			Transaction storage t = transactions[i];
			if (t.enabled) {
				bool result = externalCall(t.destination, t.data);
				if (!result) {
					emit TransactionFailed(t.destination, i, t.data);
					revert("Transaction Failed");
				}
			}
		}
	}

	/**
	 * @dev wrapper to call the encoded transactions on downstream consumers.
	 * @param destination Address of destination contract.
	 * @param data The encoded data payload.
	 * @return True on success
	 */
	function externalCall(address destination, bytes memory data) internal returns (bool)
	{
		bool result;
		assembly {  // solhint-disable-line no-inline-assembly
			// "Allocate" memory for output
			// (0x40 is where "free memory" pointer is stored by convention)
			let outputAddress := mload(0x40)

			// First 32 bytes are the padded length of data, so exclude that
			let dataAddress := add(data, 32)

			result := call(
				// 34710 is the value that solidity is currently emitting
				// It includes callGas (700) + callVeryLow (3, to pay for SUB)
				// + callValueTransferGas (9000) + callNewAccountGas
				// (25000, in case the destination address does not exist and needs creating)
				sub(gas(), 34710),
				destination,
				0, // transfer value in wei
				dataAddress,
				mload(data),  // Size of the input, in bytes. Stored in position 0 of the array.
				outputAddress,
				0  // Output is ignored, therefore the output size is zero
			)
		}
		return result;
	}

	event TransactionFailed(address indexed destination, uint index, bytes data);
}

contract UniswapPoolsExt is Ownable
{
	/// @notice list of uniswap pairs to sync
	address[] public uniSyncPairs;

	/**
	 * @notice Uniswap synced pairs
	 */
	function getUniSyncPairs() public view returns (address[] memory)
	{
		address[] memory pairs = uniSyncPairs;
		return pairs;
	}

	/**
	 * @notice Adds pairs to sync
	 */
	function addSyncPairs(address[] memory uniSyncPairs_) public onlyOwner
	{
		for (uint256 i = 0; i < uniSyncPairs_.length; i++) {
			uniSyncPairs.push(uniSyncPairs_[i]);
		}
	}

	function removeUniPair(uint256 index) public onlyOwner
	{
		if (index >= uniSyncPairs.length) return;
		for (uint i = index; i < uniSyncPairs.length-1; i++) {
			uniSyncPairs[i] = uniSyncPairs[i+1];
		}
		uniSyncPairs.pop();
	}

	function updateUniPairs() internal
	{
		for (uint256 i = 0; i < uniSyncPairs.length; i++) {
			UniswapPair(uniSyncPairs[i]).sync();
		}
	}
}

contract BalancerPoolsExt is Ownable
{
	/// @notice list of balancer pairs to gulp
	address[] public balGulpPairs;

	/**
	 * @notice Uniswap synced pairs
	 */
	function getBalGulpPairs() public view returns (address[] memory)
	{
		address[] memory pairs = balGulpPairs;
		return pairs;
	}

	/**
	 * @notice Adds pairs to sync
	 */
	function addBalPairs(address[] memory balGulpPairs_) public onlyOwner
	{
		for (uint256 i = 0; i < balGulpPairs_.length; i++) {
			balGulpPairs.push(balGulpPairs_[i]);
		}
	}

	function removeBalPair(uint256 index) public onlyOwner
	{
		if (index >= balGulpPairs.length) return;
		for (uint i = index; i < balGulpPairs.length-1; i++) {
			balGulpPairs[i] = balGulpPairs[i+1];
		}
		balGulpPairs.pop();
	}

	function updateBalPairs(address yamAddress) internal
	{
		for (uint256 i = 0; i < balGulpPairs.length; i++) {
			BPool(balGulpPairs[i]).gulp(yamAddress);
		}
	}
}

contract GElasticRebaser is Ownable //, UniswapPoolsExt, BalancerPoolsExt, TransactionsExt
{
	using SafeMath for uint256;

	struct UniVars {
		uint256 yamsToUni;
		uint256 amountFromReserves;
		uint256 mintToReserves;
	}

/*
	event NewMaxSlippageFactor(uint256 oldSlippageFactor, uint256 newSlippageFactor);
	event NewDeviationThreshold(uint256 oldDeviationThreshold, uint256 newDeviationThreshold);
*/
	event MintAmount(uint256 mintAmount);
/*
	event NewRebaseMintPercent(uint256 oldRebaseMintPerc, uint256 newRebaseMintPerc);
	event NewReserveContract(address oldReserveContract, address newReserveContract);
*/
	event TreasuryIncreased(uint256 reservesAdded, uint256 yamsSold, uint256 yamsFromReserves, uint256 yamsToReserves);

	/// @notice Spreads out getting to the target price
	uint256 public rebaseLag;

	/// @notice Peg target
	uint256 public targetRate;

	/// @notice Percent of rebase that goes to minting for treasury building
	uint256 public rebaseMintPerc;

	// If the current exchange rate is within this fractional distance from the target, no supply
	// update is performed. Fixed point number--same format as the rate.
	// (ie) abs(rate - targetRate) / targetRate < deviationThreshold, then no supply change.
	uint256 public deviationThreshold;

	/// @notice More than this much time must pass between rebase operations.
	uint256 public minRebaseTimeIntervalSec;

	/// @notice Block timestamp of last rebase operation
	uint256 public lastRebaseTimestampSec;

	/// @notice The rebase window begins this many seconds into the minRebaseTimeInterval period.
	// For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
	uint256 public rebaseWindowOffsetSec;

	/// @notice The length of the time window where a rebase operation is allowed to execute, in seconds.
	uint256 public rebaseWindowLengthSec;

	/// @notice The number of rebase cycles since inception
	uint256 public epoch;

	// rebasing is not active initially. It can be activated at T+12 hours from
	// deployment time
	///@notice boolean showing rebase activation status
	bool public rebasingActive;

	/// @notice delays rebasing activation to facilitate liquidity
	uint256 public constant rebaseDelay = 12 hours;

	/// @notice Time of TWAP initialization
	uint256 public timeOfTWAPInit;

	/// @notice YAM token address
	address public yamAddress;

	address public reserveToken;

	/// @notice Reserves vault contract
	address public reservesContract;

	/// @notice pair for reserveToken <> YAM
	address public trade_pair;

	/// @notice pair for reserveToken <> YAM
	address public eth_usdc_pair;

	/// @notice last TWAP update time
	uint32 public blockTimestampLast;

	/// @notice last TWAP cumulative price;
	uint256 public priceCumulativeLastYAMETH;

	/// @notice last TWAP cumulative price;
	uint256 public priceCumulativeLastETHUSDC;

	/// @notice address to send part of treasury to
	address public public_goods;

	/// @notice percentage of treasury to send to public goods address
	uint256 public public_goods_perc;

	// Max slippage factor when buying reserve token. Magic number based on
	// the fact that uniswap is a constant product. Therefore,
	// targeting a % max slippage can be achieved by using a single precomputed
	// number. i.e. 2.5% slippage is always equal to some f(maxSlippageFactor, reserves)
	/// @notice the maximum slippage factor when buying reserve token
	uint256 public maxSlippageFactor;

	/// @notice Whether or not this token is first in uniswap YAM<>Reserve pair
	bool public isToken0;

	uint256 public constant BASE = 10**18;

/*
	uint256 public constant MAX_SLIPPAGE_PARAM = 1180339 * 10**11; // max ~20% market impact

	uint256 public constant MAX_MINT_PERC_PARAM = 25 * 10**16; // max 25% of rebase can go to treasury
*/

	constructor(address yamAddress_, address reserveToken_, address factory, address reservesContract_, address public_goods_, uint256 public_goods_perc_)
		public
	{
		minRebaseTimeIntervalSec = 12 hours;
		rebaseWindowOffsetSec = 28800; // 8am/8pm UTC rebases

		(address token0, address token1) = sortTokens(yamAddress_, reserveToken_);

		// used for interacting with uniswap
		if (token0 == yamAddress_) {
			isToken0 = true;
		} else {
			isToken0 = false;
		}
		// uniswap YAM<>Reserve pair
		trade_pair = pairForSushi(factory, token0, token1);

		// get eth_usdc piar
		address USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

		// USDC < WETH address, so USDC is token0
		eth_usdc_pair = pairForSushi(factory, USDC, reserveToken_);

		// Reserves contract is mutable
		reservesContract = reservesContract_;

		// Reserve token is not mutable. Must deploy a new rebaser to update it
		reserveToken = reserveToken_;

		yamAddress = yamAddress_;

		public_goods = public_goods_;
		public_goods_perc = public_goods_perc_;

		// target 5% slippage
		// ~2.6%
		maxSlippageFactor = 2597836 * 10**10; //5409258 * 10**10;

		// $1
		targetRate = BASE;

		// twice daily rebase, with targeting reaching peg in 10 days
		rebaseLag = 20;

		// 10%
		rebaseMintPerc = 10**17;

		// 5%
		deviationThreshold = 5 * 10**16;

		// 60 minutes
		rebaseWindowLengthSec = 60 * 60;
	}

/*
	/**
	 * @notice Updates slippage factor
	 * @param maxSlippageFactor_ the new slippage factor
	 *
	 * /
	function setMaxSlippageFactor(uint256 maxSlippageFactor_) public onlyGov
	{
		require(maxSlippageFactor_ < MAX_SLIPPAGE_PARAM);
		uint256 oldSlippageFactor = maxSlippageFactor;
		maxSlippageFactor = maxSlippageFactor_;
		emit NewMaxSlippageFactor(oldSlippageFactor, maxSlippageFactor_);
	}

	/**
	 * @notice Updates rebase mint percentage
	 * @param rebaseMintPerc_ the new rebase mint percentage
	 *
	 * /
	function setRebaseMintPerc(uint256 rebaseMintPerc_) public onlyGov
	{
		require(rebaseMintPerc_ < MAX_MINT_PERC_PARAM);
		uint256 oldPerc = rebaseMintPerc;
		rebaseMintPerc = rebaseMintPerc_;
		emit NewRebaseMintPercent(oldPerc, rebaseMintPerc_);
	}

	/**
	 * @notice Updates reserve contract
	 * @param reservesContract_ the new reserve contract
	 *
	 * /
	function setReserveContract(address reservesContract_) public onlyGov
	{
		address oldReservesContract = reservesContract;
		reservesContract = reservesContract_;
		emit NewReserveContract(oldReservesContract, reservesContract_);
	}
*/

	/**
	 * @notice Initializes TWAP start point, starts countdown to first rebase
	 *
	 */
	function init_twap() public
	{
		require(timeOfTWAPInit == 0, "already activated");
		(uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(trade_pair);
		uint priceCumulative = isToken0 ? price0Cumulative : price1Cumulative;
		(,uint priceCumulativeUSDC,) = UniswapV2OracleLibrary.currentCumulativePrices(eth_usdc_pair);

		require(blockTimestamp > 0, "no trades");
		blockTimestampLast = blockTimestamp;
		priceCumulativeLastYAMETH = priceCumulative;
		priceCumulativeLastETHUSDC = priceCumulativeUSDC;
		timeOfTWAPInit = blockTimestamp;
	}

	/**
	 * @notice Activates rebasing
	 * @dev One way function, cannot be undone, callable by anyone
	 */
	function activate_rebasing() public
	{
		require(timeOfTWAPInit > 0, "twap wasnt intitiated, call init_twap()");
		// cannot enable prior to end of rebaseDelay
		require(now >= timeOfTWAPInit + rebaseDelay, "!end_delay");

		rebasingActive = true;
	}

	/**
	 * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
	 *
	 * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
	 *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
	 *      and targetRate is 1e18
	 */
	function rebase() public
	{
		// EOA only or gov
		require(msg.sender == tx.origin, "!EOA");
		// ensure rebasing at correct time
		_inRebaseWindow();

		// This comparison also ensures there is no reentrancy.
		require(lastRebaseTimestampSec.add(minRebaseTimeIntervalSec) < now);

		// Snap the rebase time to the start of this window.
		lastRebaseTimestampSec = now.sub(now.mod(minRebaseTimeIntervalSec)).add(rebaseWindowOffsetSec);

		epoch = epoch.add(1);

		// get twap from uniswap v2;
		uint256 exchangeRate = getTWAP();

		// calculates % change to supply
		(uint256 offPegPerc, bool positive) = computeOffPegPerc(exchangeRate);

		uint256 indexDelta = offPegPerc;

		// Apply the Dampening factor.
		indexDelta = indexDelta.div(rebaseLag);

		GElasticToken yam = GElasticToken(yamAddress);

		if (positive) {
			require(yam.scalingFactor().mul(BASE.add(indexDelta)).div(BASE) < yam.maxScalingFactor(), "new scaling factor will be too big");
		}

		uint256 currSupply = yam.totalSupply();
		uint256 mintAmount;

		// reduce indexDelta to account for minting
		if (positive) {
			uint256 mintPerc = indexDelta.mul(rebaseMintPerc).div(BASE);
			indexDelta = indexDelta.sub(mintPerc);
			mintAmount = currSupply.mul(mintPerc).div(BASE);
		}

		// rebase
		// ignore returned var
		yam.rebase(epoch, indexDelta, positive);

		// perform actions after rebase
		emit MintAmount(mintAmount);
		afterRebase(mintAmount, offPegPerc);
	}

	function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes memory data) public
	{
		// enforce that it is coming from uniswap
		require(msg.sender == trade_pair, "bad msg.sender");
		// enforce that this contract called uniswap
		require(sender == address(this), "bad origin");
		(UniVars memory uniVars) = abi.decode(data, (UniVars));

		GElasticToken yam = GElasticToken(yamAddress);

		if (uniVars.amountFromReserves > 0) {
			// transfer from reserves and mint to uniswap
			yam.transferFrom(reservesContract, trade_pair, uniVars.amountFromReserves);
			if (uniVars.amountFromReserves < uniVars.yamsToUni) {
				// if the amount from reserves > yamsToUni, we have fully paid for the yCRV tokens
				// thus this number would be 0 so no need to mint
				yam.mint(trade_pair, uniVars.yamsToUni.sub(uniVars.amountFromReserves));
			}
		} else {
			// mint to uniswap
			yam.mint(trade_pair, uniVars.yamsToUni);
		}

		// mint unsold to mintAmount
		if (uniVars.mintToReserves > 0) {
			yam.mint(reservesContract, uniVars.mintToReserves);
		}

		// transfer reserve token to reserves
		if (isToken0) {
			if (public_goods != address(0) && public_goods_perc > 0) {
				uint256 amount_to_public_goods = amount1.mul(public_goods_perc).div(BASE);
				SafeERC20.safeTransfer(IERC20(reserveToken), reservesContract, amount1.sub(amount_to_public_goods));
				SafeERC20.safeTransfer(IERC20(reserveToken), public_goods, amount_to_public_goods);
				emit TreasuryIncreased(amount1.sub(amount_to_public_goods), uniVars.yamsToUni, uniVars.amountFromReserves, uniVars.mintToReserves);
			} else {
				SafeERC20.safeTransfer(IERC20(reserveToken), reservesContract, amount1);
				emit TreasuryIncreased(amount1, uniVars.yamsToUni, uniVars.amountFromReserves, uniVars.mintToReserves);
			}
		} else {
			if (public_goods != address(0) && public_goods_perc > 0) {
				uint256 amount_to_public_goods = amount0.mul(public_goods_perc).div(BASE);
				SafeERC20.safeTransfer(IERC20(reserveToken), reservesContract, amount0.sub(amount_to_public_goods));
				SafeERC20.safeTransfer(IERC20(reserveToken), public_goods, amount_to_public_goods);
				emit TreasuryIncreased(amount0.sub(amount_to_public_goods), uniVars.yamsToUni, uniVars.amountFromReserves, uniVars.mintToReserves);
			} else {
				SafeERC20.safeTransfer(IERC20(reserveToken), reservesContract, amount0);
				emit TreasuryIncreased(amount0, uniVars.yamsToUni, uniVars.amountFromReserves, uniVars.mintToReserves);
			}
		}
	}

	function buyReserveAndTransfer(uint256 mintAmount, uint256 offPegPerc) internal
	{
		UniswapPair pair = UniswapPair(trade_pair);

		GElasticToken yam = GElasticToken(yamAddress);

		// get reserves
		(uint256 token0Reserves, uint256 token1Reserves,) = pair.getReserves();

		// check if protocol has excess yam in the reserve
		uint256 excess = yam.balanceOf(reservesContract);

		uint256 tokens_to_max_slippage = uniswapMaxSlippage(token0Reserves, token1Reserves, offPegPerc);

		UniVars memory uniVars = UniVars({
			yamsToUni: tokens_to_max_slippage, // how many yams uniswap needs
			amountFromReserves: excess, // how much of yamsToUni comes from reserves
			mintToReserves: 0 // how much yams protocol mints to reserves
		});

		// tries to sell all mint + excess
		// falls back to selling some of mint and all of excess
		// if all else fails, sells portion of excess
		// upon pair.swap, `uniswapV2Call` is called by the uniswap pair contract
		if (isToken0) {
			if (tokens_to_max_slippage > mintAmount.add(excess)) {
				// we already have performed a safemath check on mintAmount+excess
				// so we dont need to continue using it in this code path

				// can handle selling all of reserves and mint
				uint256 buyTokens = getAmountOut(mintAmount + excess, token0Reserves, token1Reserves);
				uniVars.yamsToUni = mintAmount + excess;
				uniVars.amountFromReserves = excess;
				// call swap using entire mint amount and excess; mint 0 to reserves
				pair.swap(0, buyTokens, address(this), abi.encode(uniVars));
			} else {
				if (tokens_to_max_slippage > excess) {
					// uniswap can handle entire reserves
					uint256 buyTokens = getAmountOut(tokens_to_max_slippage, token0Reserves, token1Reserves);

					// swap up to slippage limit, taking entire yam reserves, and minting part of total
					uniVars.mintToReserves = mintAmount.sub((tokens_to_max_slippage - excess));
					pair.swap(0, buyTokens, address(this), abi.encode(uniVars));
				} else {
					// uniswap cant handle all of excess
					uint256 buyTokens = getAmountOut(tokens_to_max_slippage, token0Reserves, token1Reserves);
					uniVars.amountFromReserves = tokens_to_max_slippage;
					uniVars.mintToReserves = mintAmount;
					// swap up to slippage limit, taking excess - remainingExcess from reserves, and minting full amount
					// to reserves
					pair.swap(0, buyTokens, address(this), abi.encode(uniVars));
				}
			}
		} else {
			if (tokens_to_max_slippage > mintAmount.add(excess)) {
				// can handle all of reserves and mint
				uint256 buyTokens = getAmountOut(mintAmount + excess, token1Reserves, token0Reserves);
				uniVars.yamsToUni = mintAmount + excess;
				uniVars.amountFromReserves = excess;
				// call swap using entire mint amount and excess; mint 0 to reserves
				pair.swap(buyTokens, 0, address(this), abi.encode(uniVars));
			} else {
				if (tokens_to_max_slippage > excess) {
					// uniswap can handle entire reserves
					uint256 buyTokens = getAmountOut(tokens_to_max_slippage, token1Reserves, token0Reserves);

					// swap up to slippage limit, taking entire yam reserves, and minting part of total
					uniVars.mintToReserves = mintAmount.sub( (tokens_to_max_slippage - excess) );
					pair.swap(buyTokens, 0, address(this), abi.encode(uniVars));
				} else {
					// uniswap cant handle all of excess
					uint256 buyTokens = getAmountOut(tokens_to_max_slippage, token1Reserves, token0Reserves);
					uniVars.amountFromReserves = tokens_to_max_slippage;
					uniVars.mintToReserves = mintAmount;
					// swap up to slippage limit, taking excess - remainingExcess from reserves, and minting full amount
					// to reserves
					pair.swap(buyTokens, 0, address(this), abi.encode(uniVars));
				}
			}
		}
	}

	function uniswapMaxSlippage(uint256 token0, uint256 token1, uint256 offPegPerc) internal view returns (uint256)
	{
		if (isToken0) {
			if (offPegPerc >= 10**17) {
				// cap slippage
				return token0.mul(maxSlippageFactor).div(BASE);
			} else {
				// in the 5-10% off peg range, slippage is essentially 2*x (where x is percentage of pool to buy).
				// all we care about is not pushing below the peg, so underestimate
				// the amount we can sell by dividing by 3. resulting price impact
				// should be ~= offPegPerc * 2 / 3, which will keep us above the peg
				//
				// this is a conservative heuristic
				return token0.mul(offPegPerc).div(3 * BASE);
			}
		} else {
			if (offPegPerc >= 10**17) {
				return token1.mul(maxSlippageFactor).div(BASE);
			} else {
				return token1.mul(offPegPerc).div(3 * BASE);
			}
		}
	}

	/**
	 * @notice given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
	 *
	 * @param amountIn input amount of the asset
	 * @param reserveIn reserves of the asset being sold
	 * @param reserveOut reserves if the asset being purchased
	 */
	function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut)
	{
		require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
		require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
		uint amountInWithFee = amountIn.mul(997);
		uint numerator = amountInWithFee.mul(reserveOut);
		uint denominator = reserveIn.mul(1000).add(amountInWithFee);
		amountOut = numerator / denominator;
	}

	function afterRebase(uint256 mintAmount, uint256 offPegPerc) internal
	{
		// update uniswap pairs
		// updateUniPairs();

		// update balancer pairs
		// updateBalPairs(yamAddress);

		if (mintAmount > 0) {
			buyReserveAndTransfer(mintAmount, offPegPerc);
		}

		// call any extra functions
		// executeTransactions();
	}

	/**
	* @notice Calculates TWAP from uniswap
	*
	* @dev When liquidity is low, this can be manipulated by an end of block -> next block
	*      attack. We delay the activation of rebases 12 hours after liquidity incentives
	*      to reduce this attack vector. Additional there is very little supply
	*      to be able to manipulate this during that time period of highest vuln.
	*/
	function getTWAP() internal returns (uint256)
	{
		(uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(trade_pair);
		uint priceCumulative = isToken0 ? price0Cumulative : price1Cumulative;
		(,uint priceCumulativeETH,) = UniswapV2OracleLibrary.currentCumulativePrices(eth_usdc_pair);
		uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

		// no period check as is done in isRebaseWindow

		// overflow is desired
		uint256 priceAverageYAMETH = uint256(uint224((priceCumulative - priceCumulativeLastYAMETH) / timeElapsed));
		uint256 priceAverageETHUSDC = uint256(uint224((priceCumulativeETH - priceCumulativeLastETHUSDC) / timeElapsed));

		priceCumulativeLastYAMETH = priceCumulative;
		priceCumulativeLastETHUSDC = priceCumulativeETH;
		blockTimestampLast = blockTimestamp;

		// BASE is on order of 1e18, which takes 2^60 bits
		// multiplication will revert if priceAverage > 2^196
		// (which it can because it overflows intentially)
		uint256 YAMETHprice;
		uint256 ETHprice;
		if (priceAverageYAMETH > uint192(-1)) {
			// eat loss of precision
			// effectively: (x / 2**112) * 1e18
			YAMETHprice = (priceAverageYAMETH >> 112) * BASE;
		} else {
			// cant overflow
			// effectively: (x * 1e18 / 2**112)
			YAMETHprice = (priceAverageYAMETH * BASE) >> 112;
		}

		if (priceAverageETHUSDC > uint192(-1)) {
			ETHprice = (priceAverageETHUSDC >> 112) * BASE;
		} else {
			ETHprice = (priceAverageETHUSDC * BASE) >> 112;
		}

		return YAMETHprice.mul(ETHprice).div(10**6);
	}

/*
	/**
	 * @notice Calculates current TWAP from uniswap
	 *
	 * /
	function getCurrentTWAP() public view returns (uint256)
	{
		(uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(trade_pair);
		uint priceCumulative = isToken0 ? price0Cumulative : price1Cumulative;
		(,uint priceCumulativeETH,) = UniswapV2OracleLibrary.currentCumulativePrices(eth_usdc_pair);

		uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

		// no period check as is done in isRebaseWindow

		uint256 priceAverageYAMETH = uint256(uint224((priceCumulative - priceCumulativeLastYAMETH) / timeElapsed));
		uint256 priceAverageETHUSDC = uint256(uint224((priceCumulativeETH - priceCumulativeLastETHUSDC) / timeElapsed));

		// BASE is on order of 1e18, which takes 2^60 bits
		// multiplication will revert if priceAverage > 2^196
		// (which it can because it overflows intentially)
		uint256 YAMETHprice;
		uint256 ETHprice;
		if (priceAverageYAMETH > uint192(-1)) {
			// eat loss of precision
			// effectively: (x / 2**112) * 1e18
			YAMETHprice = (priceAverageYAMETH >> 112) * BASE;
		} else {
			// cant overflow
			// effectively: (x * 1e18 / 2**112)
			YAMETHprice = (priceAverageYAMETH * BASE) >> 112;
		}

		if (priceAverageETHUSDC > uint192(-1)) {
			ETHprice = (priceAverageETHUSDC >> 112) * BASE;
		} else {
			ETHprice = (priceAverageETHUSDC * BASE) >> 112;
		}

		return YAMETHprice.mul(ETHprice).div(10**6);
	}

	/**
	 * @notice Sets the deviation threshold fraction. If the exchange rate given by the market
	 *         oracle is within this fractional distance from the targetRate, then no supply
	 *         modifications are made.
	 * @param deviationThreshold_ The new exchange rate threshold fraction.
	 * /
	function setDeviationThreshold(uint256 deviationThreshold_) external onlyGov
	{
		require(deviationThreshold > 0);
		uint256 oldDeviationThreshold = deviationThreshold;
		deviationThreshold = deviationThreshold_;
		emit NewDeviationThreshold(oldDeviationThreshold, deviationThreshold_);
	}

	/**
	 * @notice Sets the rebase lag parameter.
	 * It is used to dampen the applied supply adjustment by 1 / rebaseLag
	 * If the rebase lag R, equals 1, the smallest value for R, then the full supply
	 * correction is applied on each rebase cycle.
	 * If it is greater than 1, then a correction of 1/R of is applied on each rebase.
	 * @param rebaseLag_ The new rebase lag parameter.
	 * /
	function setRebaseLag(uint256 rebaseLag_) external onlyGov
	{
		require(rebaseLag_ > 0);
		rebaseLag = rebaseLag_;
	}

	/**
	 * @notice Sets the targetRate parameter.
	 * @param targetRate_ The new target rate parameter.
	 * /
	function setTargetRate(uint256 targetRate_) external onlyGov
	{
		require(targetRate_ > 0);
		targetRate = targetRate_;
	}

	/**
	* @notice Sets the parameters which control the timing and frequency of
	*         rebase operations.
	*         a) the minimum time period that must elapse between rebase cycles.
	*         b) the rebase window offset parameter.
	*         c) the rebase window length parameter.
	* @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
	*        operations, in seconds.
	* @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
	the rebase interval, where the rebase window begins.
	* @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
	* /
	function setRebaseTimingParameters(uint256 minRebaseTimeIntervalSec_, uint256 rebaseWindowOffsetSec_, uint256 rebaseWindowLengthSec_) external onlyGov
	{
		require(minRebaseTimeIntervalSec_ > 0);
		require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_);
		require(rebaseWindowOffsetSec_ + rebaseWindowLengthSec_ < minRebaseTimeIntervalSec_);
		minRebaseTimeIntervalSec = minRebaseTimeIntervalSec_;
		rebaseWindowOffsetSec = rebaseWindowOffsetSec_;
		rebaseWindowLengthSec = rebaseWindowLengthSec_;
	}

	/**
	 * @return If the latest block timestamp is within the rebase time window it, returns true.
	 *         Otherwise, returns false.
	 * /
	function inRebaseWindow() public view returns (bool)
	{
		// rebasing is delayed until there is a liquid market
		_inRebaseWindow();
		return true;
	}
*/

	function _inRebaseWindow() internal view
	{
		// rebasing is delayed until there is a liquid market
		require(rebasingActive, "rebasing not active");

		require(now.mod(minRebaseTimeIntervalSec) >= rebaseWindowOffsetSec, "too early");
		require(now.mod(minRebaseTimeIntervalSec) < (rebaseWindowOffsetSec.add(rebaseWindowLengthSec)), "too late");
	}

	/**
	 * @return Computes in % how far off market is from peg
	 */
	function computeOffPegPerc(uint256 rate) private view returns (uint256, bool)
	{
		if (withinDeviationThreshold(rate)) {
			return (0, false);
		}

		// indexDelta =  (rate - targetRate) / targetRate
		if (rate > targetRate) {
			return (rate.sub(targetRate).mul(BASE).div(targetRate), true);
		} else {
			return (targetRate.sub(rate).mul(BASE).div(targetRate), false);
		}
	}

	/**
	 * @param rate The current exchange rate, an 18 decimal fixed point number.
	 * @return If the rate is within the deviation threshold from the target rate, returns true.
	 *         Otherwise, returns false.
	 */
	function withinDeviationThreshold(uint256 rate) private view returns (bool)
	{
		uint256 absoluteDeviationThreshold = targetRate.mul(deviationThreshold).div(10 ** 18);
		return
			(rate >= targetRate && rate.sub(targetRate) < absoluteDeviationThreshold) ||
			(rate < targetRate && targetRate.sub(rate) < absoluteDeviationThreshold);
	}

/*
	// calculates the CREATE2 address for a pair without making any external calls
	function pairFor(address factory, address token0, address token1) internal pure returns (address pair)
	{
		pair = address(uint(keccak256(abi.encodePacked(
			hex'ff',
			factory,
			keccak256(abi.encodePacked(token0, token1)),
			hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
		))));
	}
*/

	function pairForSushi(address factory, address tokenA, address tokenB) internal pure returns (address pair)
	{
		(address token0, address token1) = sortTokens(tokenA, tokenB);
		pair = address(uint(keccak256(abi.encodePacked(
			hex'ff',
			factory,
			keccak256(abi.encodePacked(token0, token1)),
			hex'e18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303' // init code hash
		))));
	}

	// returns sorted token addresses, used to handle return values from pairs sorted in this order
	function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1)
	{
		require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
		(token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
		require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
	}
}
