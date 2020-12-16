// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Enum, Safe } from "../interop/Gnosis.sol";

/**
 * @dev This library abstracts the Gnosis Safe multisig operations.
 */
library Multisig
{
	/**
	 * @dev Lists the current owners/signers of a Gnosis Safe multisig.
	 * @param _safe The Gnosis Safe contract address.
	 * @return _owners The list of current owners/signers of the multisig.
	 */
	function _getOwners(address _safe) internal view returns (address[] memory _owners)
	{
		return Safe(_safe).getOwners();
	}

	/**
	 * @dev Checks if an address is a signer of the Gnosis Safe multisig.
	 * @param _safe The Gnosis Safe contract address.
	 * @param _owner The address to check if it is a owner/signer of the multisig.
	 * @return _isOnwer A boolean indicating if the provided address is
	 *                  indeed a signer.
	 */
	function _isOwner(address _safe, address _owner) internal view returns (bool _isOnwer)
	{
		return Safe(_safe).isOwner(_owner);
	}

	/**
	 * @dev Adds a signer to the multisig by calling the Gnosis Safe function
	 *      addOwnerWithThreshold() via the execTransactionFromModule()
	 *      primitive.
	 * @param _safe The Gnosis Safe contract address.
	 * @param _owner The owner/signer to be added to the multisig.
	 * @param _threshold The new threshold (minimum number of signers) to be set.
	 * @return _success A boolean indicating if the operation succeded.
	 */
	function _addOwnerWithThreshold(address _safe, address _owner, uint256 _threshold) internal returns (bool _success)
	{
		bytes memory _data = abi.encodeWithSignature("addOwnerWithThreshold(address,uint256)", _owner, _threshold);
		return _execTransactionFromModule(_safe, _data);
	}

	/**
	 * @dev Removes a signer to the multisig by calling the Gnosis Safe function
	 *      removeOwner() via the execTransactionFromModule()
	 *      primitive.
	 * @param _safe The Gnosis Safe contract address.
	 * @param _prevOwner The previous owner/signer in the multisig linked list.
	 * @param _owner The owner/signer to be added to the multisig.
	 * @param _threshold The new threshold (minimum number of signers) to be set.
	 * @return _success A boolean indicating if the operation succeded.
	 */
	function _removeOwner(address _safe, address _prevOwner, address _owner, uint256 _threshold) internal returns (bool _success)
	{
		bytes memory _data = abi.encodeWithSignature("removeOwner(address,address,uint256)", _prevOwner, _owner, _threshold);
		return _execTransactionFromModule(_safe, _data);
	}

	/**
	 * @dev Changes minimum number of signers of the multisig by calling the
	 *      Gnosis Safe function changeThreshold() via the
	 *      execTransactionFromModule() primitive.
	 * @param _safe The Gnosis Safe contract address.
	 * @param _threshold The new threshold (minimum number of signers) to be set.
	 * @return _success A boolean indicating if the operation succeded.
	 */
	function _changeThreshold(address _safe, uint256 _threshold) internal returns (bool _success)
	{
		bytes memory _data = abi.encodeWithSignature("changeThreshold(uint256)", _threshold);
		return _execTransactionFromModule(_safe, _data);
	}

	/**
	 * @dev Calls the execTransactionFrom() module primitive handling
	 *      possible errors.
	 * @param _safe The Gnosis Safe contract address.
	 * @param _data The encoded data describing the function signature and
	 *              argument values.
	 * @return _success A boolean indicating if the operation succeded.
	 */
	function _execTransactionFromModule(address _safe, bytes memory _data) internal returns (bool _success)
	{
		try Safe(_safe).execTransactionFromModule(_safe, 0, _data, Enum.Operation.Call) returns (bool _result) {
			return _result;
		} catch (bytes memory /* _data */) {
			return false;
		}
	}
}
