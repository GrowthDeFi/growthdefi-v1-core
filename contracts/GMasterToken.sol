// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import { GTokenBase } from "./GTokenBase.sol";
import { GCToken } from "./GCToken.sol";
import { G } from "./G.sol";

contract GMasterToken is GTokenBase
{
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;

	EnumerableSet.AddressSet private tokens;
	mapping (address => uint256) private percents;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _stakesToken, address _reserveToken)
		GTokenBase(_name, _symbol, _decimals, _stakesToken, _reserveToken) public
	{
		percents[_reserveToken] = 1e18;
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
		return percents[_token];
	}

	function transferTokenPercent(address _sourceToken, address _targetToken, uint256 _percent) public onlyOwner nonReentrant
	{
		require(_percent <= percents[_sourceToken], "Invalid percent");
		require(_sourceToken != _targetToken, "Invalid transfer");
		require(_targetToken == reserveToken || tokens.contains(_targetToken), "Unknown token");
		percents[_sourceToken] -= _percent;
		percents[_targetToken] += _percent;
	}

	function insertToken(address _token) public onlyOwner nonReentrant
	{
		address _underlyingToken = GCToken(_token).underlyingToken();
		require(_underlyingToken == reserveToken, "Mismatched token");
		require(tokens.add(_token), "Duplicate token");
	}

	function removeToken(address _token) public onlyOwner nonReentrant
	{
		require(percents[_token] == 0, "Positive percent");
		require(G.getBalance(_token) == 0, "Unbalanced reserve");
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

	function _prepareDeposit(uint256 _cost) internal override returns (bool _success)
	{
		return _adjustReserve(_cost);
	}

	function _prepareWithdrawal(uint256 _cost) internal override returns (bool _success)
	{
		return _adjustReserve(_cost);
	}

	function _adjustReserve(uint256 _roomAmount) internal returns (bool _success)
	{
		(uint256 _which, address _token, uint256 _underlyingCostOrGrossShares) = _findAdjustReserveOperation(_roomAmount);
		if (_which == 1) {
			uint256 _underlyingCost = _underlyingCostOrGrossShares;
			G.approveFunds(reserveToken, _token, _underlyingCost);
			try GCToken(_token).depositUnderlying(_underlyingCost) {
				return true;
			} catch (bytes memory /* _data */) {
				G.approveFunds(reserveToken, _token, 0);
				return false;
			}
		}
		if (_which == 2) {
			uint256 _grossShares = _underlyingCostOrGrossShares;
			try GCToken(_token).withdrawUnderlying(_grossShares) {
				return true;
			} catch (bytes memory /* _data */) {
				return false;
			}
		}
		return true;
	}

	function _findAdjustReserveOperation(uint256 _roomAmount) internal view returns (uint256 _which, address _adjustToken, uint256 _underlyingCostOrGrossShares)
	{
		_which = 0;
		uint256 _maxPercent = 0; // add minimum

		uint256 _reserveAmount = totalReserve();
		_roomAmount = G.min(_roomAmount, _reserveAmount);
		_reserveAmount = _reserveAmount.sub(_roomAmount);

		uint256 _tokenCount = tokenCount();
		for (uint256 _i = 0; _i < _tokenCount; _i++) {
			address _token = tokenAt(_i);

			uint256 _oldTokenReserve = GCToken(_token).totalReserveUnderlying();
			uint256 _oldTokenPercent = _oldTokenReserve.mul(1e18).div(_reserveAmount);

			uint256 _idealTokenReserve;
			{
				uint256 _tokenPercent = percents[_token];
				_idealTokenReserve = _reserveAmount.mul(_tokenPercent).div(1e18);
			}

			if (_idealTokenReserve > _oldTokenReserve) {
				uint256 _underlyingCost = _idealTokenReserve.sub(_oldTokenReserve);
				_underlyingCost = G.min(_underlyingCost, G.getBalance(reserveToken));

				uint256 _newTokenReserve = _oldTokenReserve.add(_underlyingCost);
				uint256 _newTokenPercent = _newTokenReserve.mul(1e18).div(_reserveAmount);

				uint256 _percent = _newTokenPercent.sub(_oldTokenPercent);
				if (_percent > _maxPercent) {
					_maxPercent = _percent;
					_which = 1;
					_adjustToken = _token;
					_underlyingCostOrGrossShares = _underlyingCost;
				}
				continue;
			}
			if (_idealTokenReserve < _oldTokenReserve) {
				uint256 _underlyingCost = _oldTokenReserve.sub(_idealTokenReserve);
				uint256 _grossShares = _calcWithdrawalSharesFromUnderlyingCost(_token, _underlyingCost);
				_grossShares = G.min(_grossShares, G.getBalance(_token));
				_underlyingCost = _calcWithdrawalUnderlyingCostFromShares(_token, _grossShares);

				uint256 _newTokenReserve = _oldTokenReserve.sub(_underlyingCost);
				uint256 _newTokenPercent = _newTokenReserve.mul(1e18).div(_reserveAmount);

				uint256 _percent = _newTokenPercent.sub(_oldTokenPercent);
				if (_percent > _maxPercent) {
					_maxPercent = _percent;
					_which = 2;
					_adjustToken = _token;
					_underlyingCostOrGrossShares = _grossShares;
				}
				continue;
			}
		}
		return (_which, _adjustToken, _underlyingCostOrGrossShares);
	}

	function _calcWithdrawalSharesFromUnderlyingCost(address _token, uint256 _underlyingCost) internal view returns (uint256 _grossShares)
	{
		uint256 _totalReserve = GCToken(_token).totalReserve();
		uint256 _totalSupply = GCToken(_token).totalSupply();
		uint256 _withdrawalFee = GCToken(_token).withdrawalFee();
		uint256 _exchangeRate = GCToken(_token).exchangeRate();
		(_grossShares,) = GCToken(_token).calcWithdrawalSharesFromUnderlyingCost(_underlyingCost, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _grossShares;
	}

	function _calcWithdrawalUnderlyingCostFromShares(address _token, uint256 _grossShares) internal view returns (uint256 _underlyingCost)
	{
		uint256 _totalReserve = GCToken(_token).totalReserve();
		uint256 _totalSupply = GCToken(_token).totalSupply();
		uint256 _withdrawalFee = GCToken(_token).withdrawalFee();
		uint256 _exchangeRate = GCToken(_token).exchangeRate();
		(_underlyingCost,) = GCToken(_token).calcWithdrawalUnderlyingCostFromShares(_grossShares, _totalReserve, _totalSupply, _withdrawalFee, _exchangeRate);
		return _underlyingCost;
	}
}
