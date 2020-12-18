// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import { UniswapV2OracleLibrary } from "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";

import { GElasticToken } from "./GElasticToken.sol";

contract TWAP
{
	using SafeMath for uint256;

	bool private immutable use0;
	address public immutable pair;

	uint256 public timeOfTWAPInit;
	uint256 public lastCumulativePrice;
	uint32 public lastBlockTimestamp;

	constructor(address _factory, address _baseToken, address _quoteToken)
		public
	{
		(address _token0, address _token1) = sortTokens(_baseToken, _quoteToken);
		use0 = _token0 == _baseToken;
		pair = pairFor(_factory, _token0, _token1);
	}

	/**
	 * @notice Initializes TWAP start point, starts countdown to first rebase
	 */
	function activateTWAP() public
	{
		require(timeOfTWAPInit == 0, "already activate");
		(lastCumulativePrice, lastBlockTimestamp) = _currentCumulativePrice();
		require(lastBlockTimestamp > 0, "no trades");
		timeOfTWAPInit = lastBlockTimestamp;
	}

	/**
	 * @notice Calculates current TWAP from uniswap
	 */
	function getCurrentTWAP() public view returns (uint256 _price)
	{
		(_price,,) = _getTWAP();
		return _price;
	}

	function _currentCumulativePrice() internal view returns (uint256 _cumulativePrice, uint32 _blockTime)
	{
		(uint256 _cumulativePrice0, uint256 _cumulativePrice1, uint32 _blockTimestamp) = UniswapV2OracleLibrary.currentCumulativePrices(pair);
		_cumulativePrice = use0 ? _cumulativePrice0 : _cumulativePrice1;
		return (_cumulativePrice, _blockTimestamp);
	}

	/**
	* @notice Calculates TWAP from uniswap
	*
	* @dev When liquidity is low, this can be manipulated by an end of block -> next block
	*      attack. We delay the activation of rebases 12 hours after liquidity incentives
	*      to reduce this attack vector. Additional there is very little supply
	*      to be able to manipulate this during that time period of highest vuln.
	*/
	function _getTWAP() internal view returns (uint256 _price, uint256 _cumulativePrice, uint32 _blockTimestamp)
	{
		(_cumulativePrice, _blockTimestamp) = _currentCumulativePrice();

		// overflow is desired
		uint256 _priceAverage = uint256(uint224((_cumulativePrice - lastCumulativePrice) / (_blockTimestamp - lastBlockTimestamp)));

		// BASE is on order of 1e18, which takes 2^60 bits
		// multiplication will revert if priceAverage > 2^196
		// (which it can because it overflows intentionally)
		_price = _priceAverage > uint192(-1) ? (_priceAverage >> 112) * 1e18 : (_priceAverage * 1e18) >> 112;

		return (_price, _cumulativePrice, _blockTimestamp);
	}

	function _updateTWAP() internal returns (uint256 _price)
	{
		(_price, lastCumulativePrice, lastBlockTimestamp) = _getTWAP();
		return _price;
	}

	// TODO move code below elsewhere

	function pairFor(address _factory, address _token0, address _token1) internal pure returns (address _pair)
	{
		_pair = address(uint(keccak256(abi.encodePacked(
			hex"ff",
			_factory,
			keccak256(abi.encodePacked(_token0, _token1)),
			hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f"
		))));
	}

	function sortTokens(address _tokenA, address _tokenB) internal pure returns (address _token0, address _token1)
	{
		require(_tokenA != _tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
		(_token0, _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
		require(_token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
	}
}

contract GElasticRebaser is Ownable, TWAP
{
	using SafeMath for uint256;

	uint256 constant REBASE_ACTIVATION_DELAY = 24 hours;
	uint256 constant REBASE_MAXIMUM_TREASURY_MINT_PERCENT = 25e16; // 25%

	uint256 constant DEFAULT_REBASE_MINIMUM_INTERVAL = 24 hours;
	uint256 constant DEFAULT_REBASE_WINDOW_OFFSET = 17 hours; // 5PM UTC
	uint256 constant DEFAULT_REBASE_WINDOW_LENGTH = 1 hours;
	uint256 constant DEFAULT_REBASE_MAXIMUM_DEVIATION = 5e16; // 5%
	uint256 constant DEFAULT_REBASE_DAMPENING_FACTOR = 10; // 10x to reach 100%
	uint256 constant DEFAULT_REBASE_TREASURY_MINT_PERCENT = 10e16; // 10%

	address public elasticToken;
	address public treasury;

	uint256 public rebaseMaximumDeviation = DEFAULT_REBASE_MAXIMUM_DEVIATION;
	uint256 public rebaseDampeningFactor = DEFAULT_REBASE_DAMPENING_FACTOR;
	uint256 public rebaseTreasuryMintPercent = DEFAULT_REBASE_TREASURY_MINT_PERCENT;

	uint256 rebaseMinimumInterval = DEFAULT_REBASE_MINIMUM_INTERVAL;
	uint256 rebaseWindowOffset = DEFAULT_REBASE_WINDOW_OFFSET;
	uint256 rebaseWindowLength = DEFAULT_REBASE_WINDOW_LENGTH;

	bool public rebaseActive;
	uint256 public lastRebaseTime;
	uint256 public epoch;

	constructor(address _factory, address _elasticToken, address _pegToken, address _treasury)
		TWAP(_factory, _elasticToken, _pegToken) public
	{
		elasticToken = _elasticToken;
		treasury = _treasury;
	}

	/**
	 * @notice Activates rebasing
	 * @dev One way function, cannot be undone, callable by anyone
	 */
	function activateRebase() public
	{
		require(timeOfTWAPInit > 0 && now >= timeOfTWAPInit + REBASE_ACTIVATION_DELAY, "not available");
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

	function rebaseTimingParameters() external view returns (address _rebaseMinimumInterval, address _rebaseWindowOffset, address _rebaseWindowLength)
	{
		return (_rebaseMinimumInterval, _rebaseWindowOffset, _rebaseWindowLength);
	}

	/**
	 * @notice Updates reserve contract
	 * @param _newTreasury the new reserve contract
	 */
	function setTreasury(address _newTreasury) public onlyOwner
	{
		require(_newTreasury != address(0), "invalid treasury");
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
		require(_newRebaseMaximumDeviation > 0, "invalid maximum deviation");
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
		require(_newRebaseDampeningFactor > 0, "invalid dampening factor");
		uint256 _oldRebaseDampeningFactor = rebaseDampeningFactor;
		rebaseDampeningFactor = _newRebaseDampeningFactor;
		emit ChangeRebaseDampeningFactor(_oldRebaseDampeningFactor, _newRebaseDampeningFactor);
	}

	/**
	 * @notice Updates rebase mint percentage
	 * @param _newRebaseTreasuryMintPercent the new rebase mint percentage
	 */
	function setRebaseTreasuryMintPercent(uint256 _newRebaseTreasuryMintPercent) public onlyOwner
	{
		require(_newRebaseTreasuryMintPercent < REBASE_MAXIMUM_TREASURY_MINT_PERCENT, "invalid percent");
		uint256 _oldRebaseTreasuryMintPercent = rebaseTreasuryMintPercent;
		rebaseTreasuryMintPercent = _newRebaseTreasuryMintPercent;
		emit ChangeRebaseTreasuryMintPercent(_oldRebaseTreasuryMintPercent, _newRebaseTreasuryMintPercent);
	}

	/**
	 * @notice Sets the parameters which control the timing and frequency of
	 *         rebase operations.
	 *         a) the minimum time period that must elapse between rebase cycles.
	 *         b) the rebase window offset parameter.
	 *         c) the rebase window length parameter.
	 * @param _newRebaseMinimumInterval More than this much time must pass between rebase
	 *                                  operations, in seconds.
	 * @param _newRebaseWindowOffset The number of seconds from the beginning of
	 *                               the rebase interval, where the rebase window begins.
	 * @param _newRebaseWindowLength The length of the rebase window in seconds.
	 */
	function setRebaseTimingParameters(uint256 _newRebaseMinimumInterval, uint256 _newRebaseWindowOffset, uint256 _newRebaseWindowLength) external onlyOwner
	{
		require(_newRebaseMinimumInterval > 0, "invalid interval");
		require(_newRebaseWindowOffset.add(_newRebaseWindowLength) <= _newRebaseMinimumInterval, "invalid window");
		uint256 _oldRebaseMinimumInterval = rebaseMinimumInterval;
		uint256 _oldRebaseWindowOffset = rebaseWindowOffset;
		uint256 _oldRebaseWindowLength = rebaseWindowLength;
		rebaseMinimumInterval = _newRebaseMinimumInterval;
		rebaseWindowOffset = _newRebaseWindowOffset;
		rebaseWindowLength = _newRebaseWindowLength;
		emit ChangeRebaseTimingParameters(_oldRebaseMinimumInterval, _oldRebaseWindowOffset, _oldRebaseWindowLength, _newRebaseMinimumInterval, _newRebaseWindowOffset, _newRebaseWindowLength);
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
		require(msg.sender == tx.origin, "restricted to externally owned accounts");

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
			uint256 _mintPercent = _delta.mul(rebaseTreasuryMintPercent).div(1e18);
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
		uint256 _offset = now.mod(rebaseMinimumInterval);
		return rebaseWindowOffset <= _offset && _offset < rebaseWindowOffset.add(rebaseWindowLength);
	}

	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangeRebaseMaximumDeviation(uint256 _oldRebaseMaximumDeviation, uint256 _newRebaseMaximumDeviation);
	event ChangeRebaseDampeningFactor(uint256 _oldRebaseDampeningFactor, uint256 _newRebaseDampeningFactor);
	event ChangeRebaseTreasuryMintPercent(uint256 _oldRebaseTreasuryMintPercent, uint256 _newRebaseTreasuryMintPercent);
	event ChangeRebaseTimingParameters(uint256 _oldRebaseMinimumInterval, uint256 _oldRebaseWindowOffset, uint256 _oldRebaseWindowLength, uint256 _newRebaseMinimumInterval, uint256 _newRebaseWindowOffset, uint256 _newRebaseWindowLength);
}
