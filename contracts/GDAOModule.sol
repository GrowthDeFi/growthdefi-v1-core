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
	string public constant VERSION = "0.0.2";

	uint256 constant VOTING_ROUND_INTERVAL = 1 days;

	uint256 constant SIGNING_OWNERS = 7;
	uint256 constant SIGNING_THRESHOLD = 4;

	address public immutable safe;
	address public immutable votingToken;

	uint256 private votingRound;
	EnumerableSet.AddressSet private candidates;

	bool public pendingChanges;

	/**
	 * @dev Restricts execution to Externally Owned Accounts (EOA).
	 */
	modifier onlyEOA()
	{
		require(tx.origin == msg.sender, "not an externally owned account");
		_;
	}

	/**
	 * @dev Constructor for the Gnosis Safe extension module.
	 * @param _safe The Gnosis Safe multisig contract address.
	 * @param _votingToken The ERC-20 token used for voting (stkGRO).
	 */
	constructor (address _safe, address _votingToken) public
	{
		safe = _safe;
		votingToken = _votingToken;

		votingRound = _currentVotingRound();

		address[] memory _owners = G.getOwners(_safe);
		uint256 _ownersCount = _owners.length;
		for (uint256 _index = 0; _index < _ownersCount; _index++) {
			address _owner = _owners[_index];
			bool _success = candidates.add(_owner);
			assert(_success);
		}

		pendingChanges = false;
	}

	/**
	 * @notice Returns the current voting round. This value gets incremented
	 *         every 24 hours.
	 * @return _votingRound The current voting round.
	 */
	function currentVotingRound() public view returns (uint256 _votingRound)
	{
		return _currentVotingRound();
	}

	/**
	 * @notice Returns the approximate number of seconds remaining until a
	 *         a new voting round starts.
	 * @return _timeToNextVotingRound The number of seconds to the next
	 *                                voting round.
	 */
	function timeToNextVotingRound() public view returns (uint256 _timeToNextVotingRound)
	{
		return now.div(VOTING_ROUND_INTERVAL).add(1).mul(VOTING_ROUND_INTERVAL).sub(now);
	}

	/**
	 * @notice Returns a boolean indicating whether or not turnOver()
	 *         can be called to apply pending changes.
	 * @return _available Returns true if a new round has started and there
	 *                    are pending changes.
	 */
	function turnOverAvailable() public view returns (bool _available)
	{
		return _turnOverAvailable();
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
	function appointCandidate() public onlyEOA nonReentrant
	{
		address _candidate = msg.sender;
		if (_turnOverAvailable()) _turnOver();
		require(!candidates.contains(_candidate), "already eligible");
		require(_appointCandidate(_candidate), "not eligible");
	}

	/**
	 * @notice Updates the multisig signers with the appointed candidade
	 *         list from the previous round. Anyone can call this method
	 *         as soon as a new voting round starts. See hasPendingTurnOver()
	 *         to figure out whether or not there are pending changes to
	 *         be applied to the multisig.
	 */
	function turnOver() public onlyEOA nonReentrant
	{
		require(_turnOverAvailable(), "not available");
		_turnOver();
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
			uint256 _votes = _countVotes(_candidate);
			if (_votes < _leastVotes) {
				_leastVoted = _candidate;
				_leastVotes = _votes;
			}
		}
		return (_leastVoted, _leastVotes);
	}

	/**
	 * @dev Implements the logic for appointing a new candidate. It looks
	 *      for the appointed candidate with the least votes and if the
	 *      prospect given canditate has strictly more votes, it replaces
	 *      it on the list. Note that, if the list has less than 7 appointed
	 *      candidates, the operation always succeeds.
	 * @param _newCandidate The given prospect candidate, assumed not to be
	 *                      on the list.
	 * @return _success A boolean indicating if indeed the prospect appointed
	 *                  candidate has enough votes to beat someone on the
	 *                  list and the operation succeded.
	 */
	function _appointCandidate(address _newCandidate) internal returns(bool _success)
	{
		address _oldCandidate = address(0);
		uint256 _candidateCount = candidates.length();
		if (_candidateCount == SIGNING_OWNERS) {
			uint256 _oldVotes;
			(_oldCandidate, _oldVotes) = _findLeastVoted();
			uint256 _newVotes = _countVotes(_newCandidate);
			if (_newVotes <= _oldVotes) return false;

			_success = candidates.remove(_oldCandidate);
			assert(_success);
		}
		_success = candidates.add(_newCandidate);
		assert(_success);

		pendingChanges = true;

		emit CandidateChange(votingRound, _oldCandidate, _newCandidate);

		return true;
	}

	/**
	 * @dev Calculates the current voting round.
	 * @return _votingRound The current voting round as calculated.
	 */
	function _currentVotingRound() internal view returns (uint256 _votingRound)
	{
		return now.div(VOTING_ROUND_INTERVAL);
	}

	/**
	 * @dev Returns a boolean indicating whether or not the multisig
	 *      can be updated with new signers.
	 * @return _available Returns true if a new round has started and there
	 *                    are pending changes.
	 */
	function _turnOverAvailable() internal view returns (bool _available)
	{
		uint256 _votingRound = _currentVotingRound();
		return _votingRound > votingRound && pendingChanges;
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
		votingRound = _currentVotingRound();

		// adds new candidates
		uint256 _candidateCount = candidates.length();
		for (uint256 _index = 0; _index < _candidateCount; _index++) {
			address _candidate = candidates.at(_index);
			if (G.isOwner(safe, _candidate)) continue;
			bool _success = G.addOwnerWithThreshold(safe, _candidate, 1);
			assert(_success);
		}

		// removes old candidates
		address[] memory _owners = G.getOwners(safe);
		uint256 _ownersCount = _owners.length;
		address _prevOwner = address(0x1); // sentinel from Gnosis
		for (uint256 _index = 0; _index < _ownersCount; _index++) {
			address _owner = _owners[_index];
			if (candidates.contains(_owner)) {
				_prevOwner = _owner;
				continue;
			}
			bool _success = G.removeOwner(safe, _prevOwner, _owner, 1);
			assert(_success);
		}

		// updates minimum number of signers
		uint256 _threshold = G.min(_candidateCount, SIGNING_THRESHOLD);
		bool _success = G.changeThreshold(safe, _threshold);
		assert(_success);

		pendingChanges = false;

		emit TurnOver(votingRound);
	}

	/**
	 * @dev Returns the vote count for a given candidate.
	 * @param _candidate The given candidate.
	 * @return _votes The number of votes delegated to the given candidate.
	 */
	function _countVotes(address _candidate) internal view virtual returns (uint256 _votes)
	{
		return GVoting(votingToken).votes(_candidate);
	}

	event TurnOver(uint256 indexed _votingRound);
	event CandidateChange(uint256 indexed _votingRound, address indexed _oldCandidate, address indexed _newCandidate);
}
