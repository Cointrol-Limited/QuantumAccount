// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {FalconHashToPointKeccakUtils} from "../src/FalconHashToPointKeccak.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MockFalconData} from "./mocks/MockFalconData.sol";

contract FalconH2PTest is Test {
    //stage data
    FalconHashToPointKeccakUtils falconH2PKU;
    MockFalconData mockData;

    function setUp() public {
        falconH2PKU = new FalconHashToPointKeccakUtils();
        mockData = new MockFalconData();
    }

    function testH2POutputMatchesPython() public view {
        uint256 numberOfDataSets = mockData.mockDataSetsLength();
        for (uint256 j = 0; j < numberOfDataSets; j++) {
            (, bytes memory nonce,) = mockData.getNonceData(j);
            bytes32 message = mockData.getUserOpHash(j);
            uint16[1024] memory point = falconH2PKU.hashToPointCT(mockData.getDomain(), nonce, message);
            (uint16[1024] memory expectedPoint,,,) = mockData.getAllArrays(j);
            bool isEqual = true;
            for (uint256 i = 0; i < 1024; i++) {
                if (point[i] != expectedPoint[i]) {
                    console.log("Mismatch at index %s", i);
                    console.log("Expected: %s", expectedPoint[i]);
                    console.log("Got: %s", point[i]);
                    isEqual = false;
                    break;
                }
            }
            assertTrue(isEqual, "H2P output does not match expected point from python reference");
        }
    }
}
