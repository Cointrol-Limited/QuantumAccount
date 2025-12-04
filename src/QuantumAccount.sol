// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseAccount} from "../lib/account-abstraction/contracts/core/BaseAccount.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../lib/account-abstraction/contracts/core/Helpers.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Falcon} from "./Falcon.sol";

contract QuantumAccount is BaseAccount {
    error QuantumAccount__CallFailed();
    error QuantumAccount__InvalidSignature();

    //enum {}
    /* Type Declarations */

    /* State Variables */

    address private immutable i_owner;
    IEntryPoint private immutable i_entryPoint;
    Falcon private immutable i_falcon;
    bytes private domain;
    uint16[1024] private publicKey; // in montgomery and NTT form
    bytes private publicKeyBytes;

    constructor(
        address entryPointAddress,
        address owner,
        address falcon,
        bytes memory _domain,
        bytes memory _publicKeyBytes
    ) {
        i_entryPoint = IEntryPoint(entryPointAddress);
        i_owner = owner;
        domain = _domain;
        i_falcon = Falcon(falcon);
        publicKeyBytes = _publicKeyBytes;
        publicKey = i_falcon.loadPublicKey(publicKeyBytes);
    }

    function updatePublicKey(bytes memory _publicKeyBytes) external {
        _requireFromEntryPoint(); //Restrict access to valid entry points
        publicKeyBytes = _publicKeyBytes;
        publicKey = i_falcon.loadPublicKey(_publicKeyBytes);
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        override
        returns (uint256)
    {

        bool isVerified = i_falcon.verifySignature(userOp.signature, userOpHash, domain, publicKey);
        if (isVerified) {
            return SIG_VALIDATION_SUCCESS;
        } else { 
            return SIG_VALIDATION_FAILED;
        }
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return i_entryPoint;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getFalcon() public view returns (address) {
        return address(i_falcon);
    }

    function getDomain() public view returns (bytes memory) {
        return domain;
    }

    function getPublicKeyBytes() public view returns (bytes memory) {
        return publicKeyBytes;
    }
}
