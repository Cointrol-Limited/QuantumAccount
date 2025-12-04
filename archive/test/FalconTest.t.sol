// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Falcon} from "../src/Falcon.sol";
import {MockFalconData} from "./mocks/MockFalconData.sol";

contract FalconTest is Test {
    Falcon falcon;
    MockFalconData mockData;

    function setUp() public {
        falcon = new Falcon();
        mockData = new MockFalconData();
    }

    // test decoding of packed public key
    function test_falcon_getPublicKey() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            (bytes memory _publicKey, uint16[1024] memory publicKey) = mockData.getKeyData(i);
            //act
            uint256 initialGas = gasleft();
            (uint16[1024] memory decodedPk) = falcon.loadPublicKey(_publicKey);
            uint256 midGas = gasleft();
            decodedPk = falcon.getPublicKey(decodedPk);
            uint256 endGas = gasleft();
            uint256 gasLoad = initialGas - midGas;
            uint256 gasGet = midGas - endGas;
            console.log("Gas used for load was %s", gasLoad);
            console.log("Gas used for getting public key was %s", gasGet);
            //assert
            bool isEqual = true;
            for (uint256 j = 0; j < 1024; j++) {
                if (publicKey[j] != decodedPk[j]) {
                    isEqual = false;
                    break;
                }
            }
            assertTrue(isEqual, "Decoded public key should match original");
        }
    }

    //test decoding of compressed signature
    function test_falcon_getNonceAndSignature() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            (bytes memory _signature, bytes memory nonce, int16[1024] memory signature) = mockData.getNonceData(i);
            //act
            uint256 initialGas = gasleft();
            (bytes memory _nonce, int16[1024] memory decodedSig) = falcon.getNonceAndSZero(_signature);
            uint256 gasUsed = initialGas - gasleft();
            console.log("Gas used for getting nonce and signature was %s", gasUsed);
            //assert
            bool isEqual = true;
            for (uint256 j = 0; j < 1024; j++) {
                if (signature[j] != decodedSig[j]) {
                    console.log("Mismatch at index %s", j);
                    console.log("Expected: %s", signature[j]);
                    console.log("Got: %s", decodedSig[j]);
                    isEqual = false;
                    break;
                }
            }
            assertTrue(isEqual, "Decoded signature should match original");
            assertEq(_nonce, nonce, "Decoded nonce should match original");
        }
    }

    function test_falcon_verify() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            (uint16[1024] memory hashedMessage, int16[1024] memory signature,,) = mockData.getAllArrays(i);
            (bytes memory _publicKey,) = mockData.getKeyData(i);
            //act
            uint16[1024] memory moNTTyPublicKey = falcon.loadPublicKey(_publicKey);
            uint256 initialGas = gasleft();
            bool isValid = falcon.verify(signature, hashedMessage, moNTTyPublicKey);
            uint256 gasUsed = initialGas - gasleft();
            console.log("Gas used for verification was %s", gasUsed);
            //assert
            assertTrue(isValid, "Signature should be valid");
        }
    }

    function test_falcon_verify_with_sig() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            (bytes memory _signature, bytes memory _publicKey) = mockData.getSignatureAndPublicKey(i);
            uint16[1024] memory moNTTyPublicKey = falcon.loadPublicKey(_publicKey);
            (bytes memory nonce, int16[1024] memory signature) = falcon.getNonceAndSZero(_signature);
            bytes memory domain = abi.encodePacked("ETHEREUM");
            uint16[1024] memory hm = falcon.getMessageArray(domain, nonce, mockData.getUserOpHash(i));
            //Act
            bool isValid = falcon.verify(signature, hm, moNTTyPublicKey);
            //Assert
            assertTrue(isValid, "Signature should be valid");
            
        }
    }

    function test_falcon_getMessageArray() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 i = 0; i < numberOfDataSets; i++) {
            bytes memory domain = mockData.getDomain();
            (,bytes memory nonce,) = mockData.getNonceData(i);
            bytes32 userOpHash = mockData.getUserOpHash(i);
            (uint16[1024] memory expectedMessageArray,,,) = mockData.getAllArrays(i);
            //act
            uint256 initialGas = gasleft();
            uint16[1024] memory messageArray = falcon.getMessageArray(domain, nonce, userOpHash);
            uint256 gasUsed = initialGas - gasleft();
            console.log("Gas used for getting message array was %s", gasUsed);
            //assert
            bool isEqual = true;
            for (uint256 j = 0; j < 1024; j++) {
                if (expectedMessageArray[j] != messageArray[j]) {
                    isEqual = false;
                    break;
                }
            }
            assertTrue(isEqual, "Message array should match expected");
        }
    }
}
