// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2 as console} from "../lib/forge-std/src/Test.sol";
import {Falcon} from "../src/Falcon.sol";
import {MockFalconData} from "./mocks/MockFalconData.sol";
import {FalconConstants} from "../src/FalconConstants.sol";
import {FalconHelperFunctions} from "../src/FalconHelperFunctions.sol";

contract FalconTest is Test, FalconConstants, FalconHelperFunctions {
    Falcon falcon;
    MockFalconData mockData;
    bytes __signature;
    bool genSig = false;

    function setUp() public {
        falcon = new Falcon();
        mockData = new MockFalconData();
    }

    // test decoding of packed public key
    function testLoadPublicKey() public view {
        // get packed public key from mock data
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            (bytes memory packedKey, uint16[1024] memory expectedUnpackedKey) = mockData.getKeyData(i);
            uint256 initialGas = gasleft();
            uint16[1024] memory unpackedKey = falcon.loadPublicKey(packedKey);
            uint256 usedGas = initialGas - gasleft();
            console.log("Gas used to load public key: ", usedGas);
            expectedUnpackedKey = mockData.poly_to_monty(expectedUnpackedKey);
            expectedUnpackedKey = mockData.NTT(expectedUnpackedKey);
            bool test = mockData.compareArrays(unpackedKey, expectedUnpackedKey);
            assertTrue(test);
        }
    }

    // test signature verification
    // verifySignature(bytes memory signature, bytes32 messageHash, bytes memory domain, uint16[1024] memory h)
    function testVerifySignature() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            // first fetch signature, userOpHash, domain, and public key (bytes format)
            (bytes memory signature, bytes memory publicKey) = mockData.getSignatureAndPublicKey(i);
            bytes memory domain = mockData.getDomain();
            bytes32 userOpHash = mockData.getUserOpHash(i);
            // convert public key
            uint16[1024] memory h = falcon.loadPublicKey(publicKey);
            // get expected result
            uint256 initialGas = gasleft();
            bool result = falcon.verifySignature(signature, userOpHash, domain, h);
            uint256 usedGas = initialGas - gasleft();
            console.log("Gas used to verify: ", usedGas);
            assertTrue(result);
        }
    }

    /* function testSignatureAndNonce() public pure {
                bytes memory nonce = new bytes(40);
        uint[1024] memory s;
        // 1. Get nonce and s0 from signature and start to calculate isShort
        //    Also do monty multiplication of s0 and public key (h)
        // uses 7 million gas
        bool checkSig = true;
        
            for (uint i = 0; i < N; i++){
                assert(_signature.length == 40 + 2*N);
                s[i] = uint8(_signature[40+(2*i)])* 256 + uint8(_signature[41+(2*i)]);
                if ( i < 40){
                    nonce[i] = _signature[i];
                }
                if (s[i]>(FalconConstants.Q/2)){
                    if (expectedSig[i] != int16(int(s[i]) - int(FalconConstants.Q))){
                        checkSig = false;
                        console.log("i: ", i);
                        console.log("got: ", int16(int(FalconConstants.Q) -int(s[i])));
                        console.log("expected: ", expectedSig[i]);
                        console.logBytes1(_signature[40+i]);
                        break;
                    }
                } else {
                    if (expectedSig[i] != int16(int(s[i]))){
                        checkSig = false;
                        console.log("i: ", i);
                        console.log("got: ", int16(int(FalconConstants.Q) -int(s[i])));
                        console.log("expected: ", expectedSig[i]);
                        console.logBytes1(_signature[40+i]);
                        break;
                    }
                }
            }
            bool checkNonce = (keccak256(nonce) == keccak256(_nonce));
            if (!checkNonce){
                console.log("Expented nonce: ", vm.toString(_nonce));
                console.log("Got nonce: ", vm.toString(nonce));
            }
            assertTrue(checkNonce && checkSig);
    } */

    function testGenerateSignature() public {
        if (!genSig) {
            assertTrue(true);
            return;
        }
        // get private key and public key from mock data
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            (, bytes memory _nonce, int16[1024] memory _s1) = mockData.getNonceData(i);
            __signature = _nonce;
            for (uint256 j = 0; j < 1024; j++) {
                int256 check = _s1[j];
                if (check < 0) {
                    check += int256(FalconConstants.Q);
                }
                uint256 firstByte = uint256(check / 256);
                uint256 secondByte = uint256(check % 256);
                __signature.push(bytes1(uint8(firstByte)));
                __signature.push(bytes1(uint8(secondByte)));
            }
            console.log("Signature at index: ", i);
            console.logBytes(__signature);
        }
    }
}
