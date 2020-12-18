// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import { UniswapV2OracleLibrary } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";

import { GElasticToken } from "./GElasticToken.sol";

contract TWAPExt
{
	using SafeMath for uint256;

	bool public isToken0;
	address public trade_pair;
	address public eth_usdc_pair;

	uint256 public timeOfTWAPInit;
	uint256 public priceCumulativeLastYAMETH;
	uint256 public priceCumulativeLastETHUSDC;
	uint32 public blockTimestampLast;

	constructor(address _elasticToken, address _factory, address _reserveToken)
		public
	{
		// used for interacting with uniswap
		// uniswap YAM<>Reserve pair
		(address _token0, address _token1) = sortTokens(_elasticToken, _reserveToken);
		isToken0 = _token0 == _elasticToken;
		trade_pair = pairFor(_factory, _token0, _token1);

		// get eth_usdc pair
		// USDC < WETH address, so USDC is token0
		address USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
		eth_usdc_pair = pairFor(_factory, USDC, _reserveToken);
	}

	/**
	 * @notice Initializes TWAP start point, starts countdown to first rebase
	 */
	function initTWAP() public
	{
		require(timeOfTWAPInit == 0, "already activated");
		(uint256 _price0Cumulative, uint256 _price1Cumulative, uint32 _blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(trade_pair);
		uint256 _priceCumulative = isToken0 ? _price0Cumulative : _price1Cumulative;
		(,uint256 _priceCumulativeUSDC,) = UniswapV2OracleLibrary.currentCumulativePrices(eth_usdc_pair);

		require(_blockTimestamp > 0, "no trades");
		timeOfTWAPInit = _blockTimestamp;
		priceCumulativeLastYAMETH = _priceCumulative;
		priceCumulativeLastETHUSDC = _priceCumulativeUSDC;
		blockTimestampLast = _blockTimestamp;
	}

	/**
	 * @notice Calculates current TWAP from uniswap
	 */
	function getCurrentTWAP() public view returns (uint256 _currentTWAP)
	{
		(_currentTWAP,,,) = _getTWAP();
		return _currentTWAP;
	}

	/**
	* @notice Calculates TWAP from uniswap
	*
	* @dev When liquidity is low, this can be manipulated by an end of block -> next block
	*      attack. We delay the activation of rebases 12 hours after liquidity incentives
	*      to reduce this attack vector. Additional there is very little supply
	*      to be able to manipulate this during that time period of highest vuln.
	*/
	function _getTWAP() internal view returns (uint256 _TWAP, uint256 _priceCumulativeLastYAMETH, uint256 _priceCumulativeLastETHUSDC, uint32 _blockTimestampLast)
	{
		(uint256 _price0Cumulative, uint256 _price1Cumulative, uint32 _blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(trade_pair);
		uint256 _priceCumulative = isToken0 ? _price0Cumulative : _price1Cumulative;
		(,uint256 _priceCumulativeETH,) = UniswapV2OracleLibrary.currentCumulativePrices(eth_usdc_pair);

		uint32 _timeElapsed = _blockTimestamp - blockTimestampLast; // overflow is desired

		// overflow is desired
		uint256 _priceAverageYAMETH = uint256(uint224((_priceCumulative - priceCumulativeLastYAMETH) / _timeElapsed));
		uint256 _priceAverageETHUSDC = uint256(uint224((_priceCumulativeETH - priceCumulativeLastETHUSDC) / _timeElapsed));

		// to be returned
		_priceCumulativeLastYAMETH = _priceCumulative;
		_priceCumulativeLastETHUSDC = _priceCumulativeETH;
		_blockTimestampLast = _blockTimestamp;

		// BASE is on order of 1e18, which takes 2^60 bits
		// multiplication will revert if priceAverage > 2^196
		// (which it can because it overflows intentially)
		uint256 _YAMETHprice;
		if (_priceAverageYAMETH > uint192(-1)) {
			_YAMETHprice = (_priceAverageYAMETH >> 112) * 1e18;
		} else {
			_YAMETHprice = (_priceAverageYAMETH * 1e18) >> 112;
		}

		uint256 _ETHprice;
		if (_priceAverageETHUSDC > uint192(-1)) {
			_ETHprice = (_priceAverageETHUSDC >> 112) * 1e18;
		} else {
			_ETHprice = (_priceAverageETHUSDC * 1e18) >> 112;
		}

		_TWAP = _YAMETHprice.mul(_ETHprice).div(1e6);

		return (_TWAP, _priceCumulativeLastYAMETH, _priceCumulativeLastETHUSDC, _blockTimestampLast);
	}

	function _updateTWAP() internal returns (uint256 _TWAP)
	{
		(_TWAP, priceCumulativeLastYAMETH, priceCumulativeLastETHUSDC, blockTimestampLast) = _getTWAP();
		return _TWAP;
	}

	// move code below elsewhere

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

	function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1)
	{
		require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
		(token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
		require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
	}
}

contract GElasticRebaser is Ownable, TWAPExt
{
	using SafeMath for uint256;

	uint256 constant REBASE_ACTIVATION_DELAY = 24 hours;
	uint256 constant MAXIMUM_REBASE_MINT_TREASURY_PERCENT = 25e16; // 25%

	uint256 constant DEFAULT_REBASE_MINIMUM_INTERVAL = 24 hours;
	uint256 constant DEFAULT_REBASE_WINDOW_OFFSET = 17 hours; // 5PM UTC
	uint256 constant DEFAULT_REBASE_WINDOW_LENGTH = 1 hours;
	uint256 constant DEFAULT_REBASE_MAXIMUM_DEVIATION = 5e16; // 5%
	uint256 constant DEFAULT_REBASE_DAMPENING_FACTOR = 10; // 10x to reach 100%
	uint256 constant DEFAULT_REBASE_MINT_TREASURY_PERCENT = 10e16; // 10%

	address public elasticToken;
	address public treasury;

	uint256 public rebaseMinimumInterval = DEFAULT_REBASE_MINIMUM_INTERVAL;
	uint256 public rebaseWindowOffset = DEFAULT_REBASE_WINDOW_OFFSET;
	uint256 public rebaseWindowLength = DEFAULT_REBASE_WINDOW_LENGTH;
	uint256 public rebaseMaximumDeviation = DEFAULT_REBASE_MAXIMUM_DEVIATION;
	uint256 public rebaseDampeningFactor = DEFAULT_REBASE_DAMPENING_FACTOR;
	uint256 public rebaseMintTreasuryPercent = DEFAULT_REBASE_MINT_TREASURY_PERCENT;

	bool public rebaseActive;
	uint256 public lastRebaseTime;
	uint256 public epoch;

	constructor(address _elasticToken, address _treasury, address _factory, address _reserveToken)
		TWAPExt(_elasticToken, _factory, _reserveToken) public
	{
		elasticToken = _elasticToken;
		treasury = _treasury;
	}

	/**
	 * @notice Activates rebasing
	 * @dev One way function, cannot be undone, callable by anyone
	 */
	function activateRebasing() public
	{
		require(timeOfTWAPInit > 0, "twap wasnt intitiated, call initTWAP()");
		require(now >= timeOfTWAPInit + REBASE_ACTIVATION_DELAY, "!end_delay");
		rebaseActive = true;
	}

	/**
	 * @return _available If the latest block timestamp is within the rebase time window it, returns true.
	 *                    Otherwise, returns false.
	 */
	function rebaseAvailable() public view returns (bool _available)
	{
		return _rebaseAvailable();
	}

	/**
	 * @notice Updates reserve contract
	 * @param _newTreasury the new reserve contract
	 */
	function setTreasury(address _newTreasury) public onlyOwner
	{
		address _oldTreasury = treasury;
		treasury = _newTreasury;
		emit ChangeTreasury(_oldTreasury, _newTreasury);
	}

	/**
	 * @notice Sets the deviation threshold fraction. If the exchange rate given by the market
	 *         oracle is within this fractional distance from the targetRate, then no supply
	 *         modifications are made.
	 * @param _newRebaseMaximumDeviation The new exchange rate threshold fraction.
	 */
	function setRebaseMaximumDeviation(uint256 _newRebaseMaximumDeviation) external onlyOwner
	{
		require(_newRebaseMaximumDeviation > 0);
		uint256 _oldRebaseMaximumDeviation = rebaseMaximumDeviation;
		rebaseMaximumDeviation = _newRebaseMaximumDeviation;
		emit ChangeRebaseMaximumDeviation(_oldRebaseMaximumDeviation, _newRebaseMaximumDeviation);
	}

	/**
	 * @notice Sets the rebase lag parameter.
	 *         It is used to dampen the applied supply adjustment by 1 / rebaseDampeningFactor
	 *         If the rebase lag R, equals 1, the smallest value for R, then the full supply
	 *         correction is applied on each rebase cycle.
	 *         If it is greater than 1, then a correction of 1/R of is applied on each rebase.
	 * @param _newRebaseDampeningFactor The new rebase lag parameter.
	 */
	function setRebaseDampeningFactor(uint256 _newRebaseDampeningFactor) external onlyOwner
	{
		require(_newRebaseDampeningFactor > 0);
		uint256 _oldRebaseDampeningFactor = rebaseDampeningFactor;
		rebaseDampeningFactor = _newRebaseDampeningFactor;
		emit ChangeRebaseDampeningFactor(_oldRebaseDampeningFactor, _newRebaseDampeningFactor);
	}

	/**
	 * @notice Updates rebase mint percentage
	 * @param _newRebaseMintTreasuryPercent the new rebase mint percentage
	 */
	function setRebaseMintTreasuryPercent(uint256 _newRebaseMintTreasuryPercent) public onlyOwner
	{
		require(_newRebaseMintTreasuryPercent < MAXIMUM_REBASE_MINT_TREASURY_PERCENT, "invalid percent");
		uint256 _oldRebaseMintTreasuryPercent = rebaseMintTreasuryPercent;
		rebaseMintTreasuryPercent = _newRebaseMintTreasuryPercent;
		emit ChangeRebaseMintTreasuryPercent(_oldRebaseMintTreasuryPercent, _newRebaseMintTreasuryPercent);
	}

	/**
	 * @notice Sets the parameters which control the timing and frequency of
	 *         rebase operations.
	 *         a) the minimum time period that must elapse between rebase cycles.
	 *         b) the rebase window offset parameter.
	 *         c) the rebase window length parameter.
	 * @param _rebaseMinimumInterval More than this much time must pass between rebase
	 *                               operations, in seconds.
	 * @param _rebaseWindowOffset The number of seconds from the beginning of
	 *                            the rebase interval, where the rebase window begins.
	 * @param _rebaseWindowLength The length of the rebase window in seconds.
	 */
	function setRebaseTimingParameters(uint256 _rebaseMinimumInterval, uint256 _rebaseWindowOffset, uint256 _rebaseWindowLength) external onlyOwner
	{
		require(_rebaseMinimumInterval > 0);
		require(_rebaseWindowOffset < _rebaseMinimumInterval);
		require(_rebaseWindowOffset + _rebaseWindowLength < _rebaseMinimumInterval);
		rebaseMinimumInterval = _rebaseMinimumInterval;
		rebaseWindowOffset = _rebaseWindowOffset;
		rebaseWindowLength = _rebaseWindowLength;
	}

	/**
	 * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
	 *
	 * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseDampeningFactor
	 *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
	 *      and targetRate is 1e18
	 */
	function rebase() public
	{
		// EOA only or gov
		require(msg.sender == tx.origin, "!EOA");

		require(rebaseActive, "not active");
		require(_rebaseAvailable(), "not available");

		// This comparison also ensures there is no reentrancy.
		require(lastRebaseTime.add(rebaseMinimumInterval) < now);
		lastRebaseTime = now.sub(now.mod(rebaseMinimumInterval)).add(rebaseWindowOffset);
		epoch = epoch.add(1);

		// get twap from uniswap v2;
		uint256 _rate = _updateTWAP();

		// calculates % change to supply
		bool _positive = _rate > 1e18;
		uint256 _deviation = _positive ? _rate.sub(1e18) : uint256(1e18).sub(_rate);
		if (_deviation < rebaseMaximumDeviation) {
			_deviation = 0;
			_positive = false;
		}

		// apply the dampening factor
		uint256 _delta = _deviation;
		_delta = _delta.div(rebaseDampeningFactor);

		// calculates mint amount for positive rebases
		uint256 _mintAmount = 0;
		if (_positive) {
			uint256 _mintPercent = _delta.mul(rebaseMintTreasuryPercent).div(1e18);
			_delta = _delta.sub(_mintPercent);
			uint256 _totalSupply = GElasticToken(elasticToken).totalSupply();
			_mintAmount = _totalSupply.mul(_mintPercent).div(1e18);
		}

		GElasticToken(elasticToken).rebase(epoch, _delta, _positive);
		if (_mintAmount > 0) {
			GElasticToken(elasticToken).mint(treasury, _mintAmount);
		}
	}

	function _rebaseAvailable() internal view returns (bool _available)
	{
		uint256 _offsetSec = now.mod(rebaseMinimumInterval);
		return rebaseWindowOffset <= _offsetSec && _offsetSec < rebaseWindowOffset.add(rebaseWindowLength);
	}

	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangeRebaseMaximumDeviation(uint256 _oldRebaseMaximumDeviation, uint256 _newRebaseMaximumDeviation);
	event ChangeRebaseDampeningFactor(uint256 _oldRebaseDampeningFactor, uint256 _newRebaseDampeningFactor);
	event ChangeRebaseMintTreasuryPercent(uint256 _oldRebaseMintTreasuryPercent, uint256 _newRebaseMintTreasuryPercent);
}
