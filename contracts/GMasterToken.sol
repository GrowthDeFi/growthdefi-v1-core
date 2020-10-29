// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import { GTokenBase } from "./GTokenBase.sol";
import { GCToken } from "./GCToken.sol";
import { G } from "./G.sol";

// missing 0.1% fee / month collected at each operation
// streaming fee accumulated and then claimed to an external contract
// which by default is the locked LP
// replacing the external contract applies immediately but requires
// liquidity migration policy of 7-days

contract GMasterToken is GTokenBase
{
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;

	EnumerableSet.AddressSet private tokens;
	mapping (address => uint256) private weights;
	uint256 totalWeight;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakesToken, address _reserveToken)
		GTokenBase(_name, _symbol, _decimals, _stakesToken, _reserveToken) public
	{
		weights[_reserveToken] = 1e18;
		totalWeight = 1e18;
	}

	function tokenCount() public view returns (uint256 _tokenCount)
	{
		return tokens.length();
	}

	function tokenAt(uint256 _index) public view returns (address _token)
	{
		return tokens.at(_index);
	}

	function tokenPercent(address _token) public view returns (uint256 _percent)
	{
		return weights[_token].mul(1e18).div(totalWeight);
	}

	function setTokenPercent(address _token, uint256 _percent) public onlyOwner nonReentrant
	{
		require(_percent < 1e18, "Invalid percent");
		if (_token != reserveToken) require(tokens.contains(_token), "Unknown token");
		uint256 _weight = weights[_token];
		totalWeight = totalWeight.sub(_weight);
		uint256 _factor = _percent.mul(1e18).div(uint256(1e18).sub(_percent));
		_weight = totalWeight.mul(_factor).div(1e18);
		weights[_token] = _weight;
		totalWeight = totalWeight.add(_weight);
	}

	function insertToken(address _token) public onlyOwner nonReentrant
	{
		address _underlyingToken = GCToken(_token).underlyingToken();
		require(_underlyingToken == reserveToken, "Mismatched token");
		require(tokens.add(_token), "Duplicate token");
	}

	function removeToken(address _token) public onlyOwner nonReentrant
	{
		require(weights[_token] == 0, "Positive percent");
		require(tokens.remove(_token), "Unknown token");
	}

	function totalReserve() public view virtual override returns (uint256 _totalReserve)
	{
		_totalReserve = G.getBalance(reserveToken);
		uint256 _tokenCount = tokenCount();
		for (uint256 _i = 0; _i < _tokenCount; _i++) {
			address _token = tokenAt(_i);
			uint256 _tokenReserve = GCToken(_token).totalReserveUnderlying();
			_totalReserve = _totalReserve.add(_tokenReserve);
		}
		return _totalReserve;
	}

	function _prepareDeposit(uint256 _cost) internal override returns (bool _success) {
		return _adjustReserve(_cost);
	}

	function _prepareWithdrawal(uint256 _cost) internal override returns (bool _success) {
		return _adjustReserve(_cost);
	}

	function _adjustReserve(uint256 _roomAmount) internal returns (bool _success) {
		uint256 _reserveAmount = totalReserve();
		_roomAmount = G.min(_roomAmount, _reserveAmount);
		_reserveAmount = _reserveAmount.sub(_roomAmount);
		uint256 _tokenCount = tokenCount();
		for (uint256 _i = 0; _i < _tokenCount; _i++) {
			address _token = tokenAt(_i);
			uint256 _tokenPercent = tokenPercent(_token);
			uint256 _newTokenReserve = _reserveAmount.mul(_tokenPercent).div(1e18);
			uint256 _oldTokenReserve = GCToken(_token).totalReserveUnderlying();
			if (_newTokenReserve < _oldTokenReserve) {
				uint256 _amount = _oldTokenReserve.sub(_newTokenReserve);
				uint256 _grossShares = _calcSharesFromUnderlyingCost(_token, _amount);
				if (_grossShares > 0) {
					try GCToken(_token).withdrawUnderlying(_grossShares) {
					} catch (bytes memory /* _data */) {
						return false;
					}
				}
			}
		}
		for (uint256 _i = 0; _i < _tokenCount; _i++) {
			address _token = tokenAt(_i);
			uint256 _tokenPercent = tokenPercent(_token);
			uint256 _newTokenReserve = _reserveAmount.mul(_tokenPercent).div(1e18);
			uint256 _oldTokenReserve = GCToken(_token).totalReserveUnderlying();
			if (_newTokenReserve > _oldTokenReserve) {
				uint256 _amount = _newTokenReserve.sub(_oldTokenReserve);
				try GCToken(_token).depositUnderlying(_amount) {
				} catch (bytes memory /* _data */) {
					return false;
				}
			}
		}
		return true;
	}

	function _calcSharesFromUnderlyingCost(address _token, uint256 _underlyingCost) internal view returns (uint256 _grossShares) {
		uint256 _totalReserve = GCToken(_token).totalReserve();
		uint256 _totalSupply = GCToken(_token).totalSupply();
		uint256 _withdrawalFee = GCToken(_token).withdrawalFee();
		uint256 _exchangeRate = GCToken(_token).exchangeRate();
		(_grossShares,) = GCToken(_token).calcWithdrawalSharesFromUnderlyingCost(_underlyingCost, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _grossShares;
	}

	// streamming fee

	uint256 constant STREAMING_FEE_PER_SECOND = 385609697; // ((1 + 0.001) ** (1 / (30 * 24 * 60 * 60))) - 1

	function _calcStreamingFee(uint256 _totalSupply, uint256 _lastTime, uint256 _thisTime) internal pure returns (uint256 _shares)
	{
		uint256 _ellapsed = _thisTime.sub(_lastTime);
		uint256 _factor = _powpi(STREAMING_FEE_PER_SECOND.add(1e18), _ellapsed).sub(1e18);
		_shares = _totalSupply.mul(_factor).div(1e18);
		return _shares;
	}

	function _powpi(uint256 _base, uint256 _exp) internal pure returns (uint256 _power)
	{
		_power = 1e18;
		while (_exp > 0) {
			if (_exp & 1 != 0) _power = _power.mul(_base).div(1e18);
			_base = _base.mul(_base).div(1e18);
			_exp >>= 1;
		}
		return _power;
	}
}
