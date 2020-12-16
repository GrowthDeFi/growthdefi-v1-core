// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GVoting } from "./GVoting.sol";
import { G } from "./G.sol";

/**
 * @notice This contract implements a Gnosis Safe extension module to allow
 *         replacing the multisig signers using the 1-level delegation voting
 *         provided by stkGRO. Every 24 hours, around 0 UTC, a new voting round
 *         starts and the candidates appointed in the previous round can become
 *         the signers of the multisig. This module allows up to 7 signers with
 *         a minimum of 4 signatures to take any action. There are 3 consecutive
 *         phases in the process, each occuring at a 24 hour voting round. In
 *         the first round, stkGRO holders can delegate their votes (stkGRO
 *         balance) to candidates; vote balance is frozen by the end of that
 *         round. In the second round, most voted candidates can appoint
 *         themselves to become signers, replacing a previous candidate from the
 *         current list. In the third and final round, the list of appointed
 *         candidates is set as the list of signers to the multisig. The 3
 *         phases overlap so that, when one list of signers is being set, the
 *         list for the next day is being build, and yet the votes for
 *         subsequent day are being counted. See GVoting and GTokenType3 for
 *         further documentation.
 */
contract GDAOModule is ReentrancyGuard
{
	using SafeMath for uint256;
	using EnumerableSet for EnumerableSet.AddressSet;

	string public constant NAME = "GrowthDeFi DAO Module";
	string public constant VERSION = "0.0.1";

	uint256 constant VOTING_ROUND_INTERVAL = 1 days;

	uint256 constant SIGNING_OWNERS = 7;
	uint256 constant SIGNING_THRESHOLD = 4;

	address public immutable safe;
	address public immutable votingToken;

	bool private synced = false;
	uint256 private votingRound = 0;
	EnumerableSet.AddressSet private candidates;

	/**
	 * @dev Constructor for the Gnosis Safe extension module.
	 * @param _safe The Gnosis Safe multisig contract address.
	 * @param _votingToken The ERC-20 token used for voting (stkGRO).
	 */
	constructor (address _safe, address _votingToken) public
	{
		safe = _safe;
		votingToken = _votingToken;

		address[] memory _owners = G.getOwners(_safe);
		uint256 _ownersCount = _owners.length;
		for (uint256 _index = 0; _index < _ownersCount; _index++) {
			address _owner = _owners[_index];
			bool _success = candidates.add(_owner);
			assert(_success);
		}
	}

	/**
	 * @notice Returns the current voting round. This value gets incremented
	 *         every 24 hours.
	 * @return _votingRound The current voting round.
	 */
	function currentVotingRound() public view returns (uint256 _votingRound)
	{
		return block.timestamp.div(VOTING_ROUND_INTERVAL);
	}

	/**
	 * @notice Returns the approximate number of seconds remaining until a
	 *         a new voting round starts.
	 * @return _timeToNextVotingRound The number of seconds to the next
	 *                                voting round.
	 */
	function timeToNextVotingRound() public view returns (uint256 _timeToNextVotingRound)
	{
		uint256 _time = block.timestamp;
		return _time.div(VOTING_ROUND_INTERVAL).add(1).mul(VOTING_ROUND_INTERVAL).sub(_time);
	}

	/**
	 * @notice Returns a boolean indicating whether or not there are pending
	 *         changes to be applied by calling turnOver().
	 * @return _hasPendingTurnOver True if there are pending changes.
	 */
	function hasPendingTurnOver() internal view returns (bool _hasPendingTurnOver)
	{
		uint256 _votingRound = block.timestamp.div(VOTING_ROUND_INTERVAL);
		return _votingRound > votingRound && !synced;
	}

	/**
	 * @notice Returns the current number of appointed candidates in the list.
	 * @return _count The size of the appointed candidate list.
	 */
	function candidateCount() public view returns (uint256 _count)
	{
		return candidates.length();
	}

	/**
	 * @notice Returns the i-th appointed candidates on the list.
	 * @return _candidate The address of an stkGRO holder appointed to the
	 *                    candidate list.
	 */
	function candidateAt(uint256 _index) public view returns (address _candidate)
	{
		return candidates.at(_index);
	}

	/**
	 * @notice Appoints as candidate to be a signer for the multisig,
	 *         starting on the next voting round. Only the actual candidate
	 *         can appoint himself and he must have a vote count large
	 *         enough to kick someone else from the appointed candidate list.
	 *         No that the first candidate appointment on a round may update
	 *         the multisig signers with the list from the previous round, if
	 *         there are changes.
	 */
	function appointCandidate() public nonReentrant
	{
		address _candidate = msg.sender;
		_closeRound();
		require(!candidates.contains(_candidate), "candidate already eligible");
		require(_appointCandidate(_candidate), "candidate not eligible");
	}

	/**
	 * @notice Updates the multisig signers with the appointed candidade
	 *         list from the previous round. Anyone can call this method
	 *         as soon as a new voting round starts. See hasPendingTurnOver()
	 *         to figure out whether or not there are pending changes to
	 *         be applied to the multisig.
	 */
	function turnOver() public nonReentrant
	{
		require(_closeRound(), "must wait next interval");
	}

	/**
	 * @dev Finds the appointed candidates with the least amount of votes
	 *      for the current list. This is used to find the candidate to be
	 *      removed when a new candidate with more votes is appointed.
	 * @return _leastVoted The address of the least voted appointed candidate.
	 * @return _leastVotes The actual number of votes for the least voted
	 *                     appointed candidate.
	 */
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

	/**
	 * @dev Checks whether or not we have entered a new voting round before
	 *      turning over.
	 * @return _success A boolean indicating if indeed we have entered a
	 *                  new voting round.
	 */
	function _closeRound() internal returns (bool _success)
	{
		uint256 _votingRound = block.timestamp.div(VOTING_ROUND_INTERVAL);
		if (_votingRound > votingRound) {
			votingRound = _votingRound;
			_turnOver();
			return true;
		}
		return false;
	}

	/**
	 * @dev Implements the logic for appointing a new candidate. It looks
	 *      for the appointed candidate with the least votes and if the
	 *      prospect given canditate has strictly more votes, it replaces
	 *      it on the list. Note that, if the list has less than 7 appointed
	 *      candidates, the operation always succeeds.
	 * @param _candidate The given prospect candidate, assumed not to be on
	 *                   the list.
	 * @return _success A boolean indicating if indeed the prospect appointed
	 *                  candidate has enough votes to beat someone on the
	 *                  list and the operation succeded.
	 */
	function _appointCandidate(address _candidate) internal returns(bool _success)
	{
		uint256 _candidateCount = candidates.length();
		if (_candidateCount == SIGNING_OWNERS) {
			uint256 _votes = GVoting(votingToken).votes(_candidate);
			(address _leastVoted, uint256 _leastVotes) = _findLeastVoted();
			if (_leastVotes >= _votes) return false;
			_success = candidates.remove(_leastVoted);
			assert(_success);
		}
		_success = candidates.add(_candidate);
		assert(_success);
		synced = false;
		return true;
	}

	/**
	 * @dev Implements the turn over by first adding all the missing
	 *      candidates from the appointed list to the multisig signers
	 *      list, and later removing the multisig signers not present
	 *      in the current appointed list. At last, it sets the minimum
	 *      number of signers to 4 (or the size of the list if smaller than
	 *      4). This function is optimized to skip the process if it is
	 *      in sync, i.e no candidates were appointed since the last update.
	 */
	function _turnOver() internal
	{
		if (synced) return;
		uint256 _candidateCount = candidates.length();
		for (uint256 _index = 0; _index < _candidateCount; _index++) {
			address _candidate = candidates.at(_index);
			if (G.isOwner(safe, _candidate)) continue;
			bool _success = G.addOwnerWithThreshold(safe, _candidate, 1);
			assert(_success);
		}
		address[] memory _owners = G.getOwners(safe);
		uint256 _ownersCount = _owners.length;
		for (uint256 _index = 0; _index < _ownersCount; _index++) {
			address _owner = _owners[_index];
			if (candidates.contains(_owner)) continue;
			address _prevOwner = _index == 0 ? address(0x1) : _owners[_index - 1];
			bool _success = G.removeOwner(safe, _prevOwner, _owner, 1);
			assert(_success);
		}
		uint256 _threshold = G.min(_candidateCount, SIGNING_THRESHOLD);
		bool _success = G.changeThreshold(safe, _threshold);
		assert(_success);
		synced = true;
	}
}
