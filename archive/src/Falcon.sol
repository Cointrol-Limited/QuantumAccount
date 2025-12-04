// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FalconVerify} from "./FalconVerify.sol";
import {FalconHashToPointKeccakUtils} from "./FalconHashToPointKeccak.sol";
import {FalconPkPackedUtils} from "./FalconPkPacked.sol";
import {FalconSigCompressedUtils} from "./FalconSigCompressed.sol";

contract Falcon {
    FalconPkPackedUtils pkUtils;
    FalconSigCompressedUtils sigUtils;
    FalconHashToPointKeccakUtils hashToPointUtils;
    FalconVerify falconVerify;

    constructor() {
        pkUtils = new FalconPkPackedUtils();
        sigUtils = new FalconSigCompressedUtils();
        hashToPointUtils = new FalconHashToPointKeccakUtils();
        falconVerify = new FalconVerify();
    }

    function loadPublicKey(bytes memory publicKey) external view returns (uint16[1024] memory) {
        uint16[1024] memory decodedKey = pkUtils.decodePkPacked(publicKey);
        return falconVerify.toMoNTTy(decodedKey);
    }

    function getPublicKey(uint16[1024] memory publicKey) external view returns (uint16[1024] memory) {
        return falconVerify.fromMoNTTy(publicKey);
    }

    function getNonceAndSZero(bytes memory _signature) external view returns (bytes memory, int16[1024] memory) {
        return sigUtils.decode(_signature);
    }

    function getMessageArray(bytes memory domain, bytes memory nonce, bytes32 message)
        external
        view
        returns (uint16[1024] memory)
    {
        return hashToPointUtils.hashToPointCT(domain, nonce, message);
    }

    function verify(int16[1024] memory signature, uint16[1024] memory hashedMessage, uint16[1024] memory publicKey)
        external
        view
        returns (bool)
    {
        return falconVerify._is_short(signature, falconVerify.fetch_signature(hashedMessage, signature, publicKey));
    }
}
