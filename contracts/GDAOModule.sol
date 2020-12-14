// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GVoting } from "./GVoting.sol";
import { G } from "./G.sol";

import { Enum, Safe } from "./interop/Gnosis.sol";

contract GDAOModule is ReentrancyGuard
{
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;

	string public constant NAME = "GrowthDeFi DAO Module";
	string public constant VERSION = "0.0.1";

	uint256 constant VOTING_ROUND_INTERVAL = 1 days;

	uint256 constant SIGNING_OWNERS = 7;
	uint256 constant SIGNING_THRESHOLD = 4;

	address public immutable votingToken;

	EnumerableSet.AddressSet private safes;

	bool private synced = false;
	uint256 private votingRound = 0;
	EnumerableSet.AddressSet private candidates;

	constructor (address _safe, address _votingToken) public
	{
		{
			bool _success = safes.add(_safe);
			assert(_success);
		}
		votingToken = _votingToken;
		address[] memory _owners = Safe(_safe).getOwners();
		uint256 _ownersCount = _owners.length;
		for (uint256 _index = 0; _index < _ownersCount; _index++) {
			address _owner = _owners[_index];
			bool _success = candidates.add(_owner);
			assert(_success);
		}
	}

	modifier onlySafe() {
		address _from = msg.sender;
		require(safes.contains(_from), "unauthorized caller");
		_;
	}

	function currentVotingRound() public view returns (uint256 _votingRound)
	{
		return block.timestamp.div(VOTING_ROUND_INTERVAL);
	}

	function timeToNextVotingRound() public view returns (uint256 _timeToNextVotingRound)
	{
		return block.timestamp.div(VOTING_ROUND_INTERVAL).add(1).mul(VOTING_ROUND_INTERVAL);
	}

	function hasPendingTurnOver() internal view returns (bool _hasPendingTurnOver)
	{
		uint256 _votingRound = block.timestamp.div(VOTING_ROUND_INTERVAL);
		return _votingRound > votingRound && !synced;
	}

	function candidateCount() public view returns (uint256 _count)
	{
		return candidates.length();
	}

	function candidateAt(uint256 _index) public view returns (address _candidate)
	{
		return candidates.at(_index);
	}

	function safeCount() public view returns (uint256 _count)
	{
		return safes.length();
	}

	function safeAt(uint256 _index) public view returns (address _safe)
	{
		return safes.at(_index);
	}

	function insertSafe(address _safe) public onlySafe nonReentrant
	{
		require(safes.add(_safe), "duplicate safe");
	}

	function removeSafe(address _safe) public onlySafe nonReentrant
	{
		address _from = msg.sender;
		require(_from != _safe, "cannot remove itself");
		require(safes.remove(_safe), "unknown safe");
	}

	function appointCandidate() public nonReentrant
	{
		address _candidate = msg.sender;
		_closeRound();
		require(!candidates.contains(_candidate), "candidate already eligible");
		require(_appointCandidate(_candidate), "candidate not eligible");
	}

	function turnOver() public nonReentrant
	{
		require(_closeRound(), "must wait next interval");
	}

	function _findLeastVoted() internal view returns (address _leastVoted, uint256 _leastVotes)
	{
		_leastVoted = address(0);
		_leastVotes = uint256(-1);
		uint256 _candidateCount = candidates.length();
		for (uint256 _index = 0; _index < _candidateCount; _index++) {
			address _candidate = candidates.at(_index);
			uint256 _votes = GVoting(votingToken).votes(_candidate);
			if (_votes < _leastVotes) {
				_leastVoted = _candidate;
				_leastVotes = _votes;
			}
		}
		return (_leastVoted, _leastVotes);
	}

	function _closeRound() internal returns (bool _success)
	{
		uint256 _votingRound = block.timestamp.div(VOTING_ROUND_INTERVAL);
		if (_votingRound > votingRound) {
			votingRound = _votingRound;
			if (synced) return true;
			uint256 _safeCount = safes.length();
			for (uint256 _index = 0; _index < _safeCount; _index++) {
				address _safe = safes.at(_index);
				require(_turnOver(_safe), "unable to update safe");
			}
			synced = true;
			return true;
		}
		return false;
	}

	function _appointCandidate(address _candidate) internal returns(bool _success)
	{
		uint256 _candidateCount = candidates.length();
		if (_candidateCount == SIGNING_OWNERS) {
			uint256 _votes = GVoting(votingToken).votes(_candidate);
			(address _leastVoted, uint256 _leastVotes) = _findLeastVoted();
			if (_leastVotes >= _votes) return false;
			candidates.remove(_leastVoted);
		}
		candidates.add(_candidate);
		synced = false;
		return true;
	}

	function _turnOver(address _safe) internal returns (bool _success)
	{
		uint256 _candidateCount = candidates.length();
		for (uint256 _index = 0; _index < _candidateCount; _index++) {
			address _candidate = candidates.at(_index);
			if (Safe(_safe).isOwner(_candidate)) continue;
			_success = _addOwnerWithThreshold(_safe, _candidate, 1);
			if (!_success) return false;
		}
		address[] memory _owners = Safe(_safe).getOwners();
		uint256 _ownersCount = _owners.length;
		for (uint256 _index = 0; _index < _ownersCount; _index++) {
			address _owner = _owners[_index];
			if (candidates.contains(_owner)) continue;
			address _prevOwner = _index == 0 ? address(0x1) : _owners[_index - 1];
			_success = _removeOwner(_safe, _prevOwner, _owner, 1);
			if (!_success) return false;
		}
		uint256 _threshold = G.min(_candidateCount, SIGNING_THRESHOLD);
		_success = _changeThreshold(_safe, _threshold);
		if (!_success) return false;
		return true;
	}

	function _addOwnerWithThreshold(address _safe, address _owner, uint256 _threshold) internal returns (bool _success)
	{
		bytes memory _data = abi.encodeWithSignature("addOwnerWithThreshold(address,uint256)", _owner, _threshold);
		return _execTransactionFromModule(_safe, _data);
	}

	function _removeOwner(address _safe, address _prevOwner, address _owner, uint256 _threshold) internal returns (bool _success)
	{
		bytes memory _data = abi.encodeWithSignature("removeOwner(address,address,uint256)", _prevOwner, _owner, _threshold);
		return _execTransactionFromModule(_safe, _data);
	}

	function _changeThreshold(address _safe, uint256 _threshold) internal returns (bool _success)
	{
		bytes memory _data = abi.encodeWithSignature("changeThreshold(uint256)", _threshold);
		return _execTransactionFromModule(_safe, _data);
	}

	function _execTransactionFromModule(address _safe, bytes memory _data) internal returns (bool _success)
	{
		try Safe(_safe).execTransactionFromModule(_safe, 0, _data, Enum.Operation.Call) returns (bool _result) {
			return _result;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}
}
