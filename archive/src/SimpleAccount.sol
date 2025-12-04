// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseAccount} from "../lib/account-abstraction/contracts/core/BaseAccount.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../lib/account-abstraction/contracts/core/Helpers.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract SimpleAccount is BaseAccount {
    error SimpleAccount__CallFailed();
    error SimpleAccount__InvalidSignature();

    //enum {}
    /* Type Declarations */

    /* State Variables */

    address private immutable i_owner;
    IEntryPoint private immutable i_entryPoint;

    constructor(address entryPointAddress, address owner) {
        i_entryPoint = IEntryPoint(entryPointAddress);
        i_owner = owner;
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256)
    {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address messageSigner = ECDSA.recover(digest, userOp.signature);
        if (messageSigner == i_owner) {
            return SIG_VALIDATION_SUCCESS;
        } else {
            return SIG_VALIDATION_FAILED;
        }
    }

    function execute(address dest, uint256 value, bytes calldata funcCallData) external {
        _requireFromEntryPoint(); //Restrict access to valid entry points
        (bool success,) = dest.call{value: value}(funcCallData);
        if (!success) {
            revert SimpleAccount__CallFailed();
        }
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return i_entryPoint;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}
