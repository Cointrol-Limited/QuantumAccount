// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2 as console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {QuantumAccount} from "../src/QuantumAccount.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {DeployQuantumAccount} from "../script/DeployQuantumAccount.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MockFalconData} from "./mocks/MockFalconData.sol";
import {Falcon} from "../src/Falcon.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract QuantumAccountAccountIntegrationTest is Test {
    QuantumAccount quantumAccount;
    EntryPoint private entryPoint;
    HelperConfig private helperConfig;
    Falcon private falcon;
    bytes domain;
    MockFalconData mockData;
    uint256 whichTest = 8;

    Account private bundler;

    function setUp() external {
        bundler = makeAccount("bundler");
        helperConfig = new HelperConfig();
        mockData = new MockFalconData();
        entryPoint = helperConfig.getNetworkConfig().entryPoint;
        falcon = helperConfig.getNetworkConfig().falcon;
        domain = helperConfig.getNetworkConfig().domain;
        DeployQuantumAccount deployAccount = new DeployQuantumAccount();
        // quantum account address when deployed locally to anvil using this script is 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
        (, bytes memory publicKey) = mockData.getSignatureAndPublicKey(whichTest);
        quantumAccount = deployAccount.run(entryPoint, falcon, domain, publicKey);
    }

    function testQuantumAccountGetUserOpHashViaEntry() public view {
        // Arrange
        PackedUserOperation memory userOp = mockData.getUserOp(whichTest);
        bytes32 userOpHash = mockData.getUserOpHash(whichTest);
        bytes32 getUserOpHash = entryPoint.getUserOpHash(userOp);
        console.log(address(entryPoint));
        console.log(block.chainid);
        assertEq(userOpHash, getUserOpHash);
    }

    function testQuantumAccountViaEntryPoint() public {
        // ARRANGE

        // 1. Add ether to the account contract
        uint256 initialBalance = 100 ether;
        vm.deal(address(quantumAccount), initialBalance);
        uint256 initialGas = gasleft();
        console.log("Initial gas: ", initialGas);

        // 2. Get user operation from mock data (will replace with op generator)
        PackedUserOperation memory userOp = mockData.getUserOp(whichTest);
        bytes32 userOpHash = mockData.getUserOpHash(whichTest);
        console.logBytes32(userOpHash);

        // 3. Generate the user operations array to pass to the handleOps function
        PackedUserOperation[] memory userOperationArray = new PackedUserOperation[](1);
        userOperationArray[0] = userOp;

        // ACT

        // 4. Send operations to entry point & check if the event is emitted
        vm.prank(bundler.addr,bundler.addr);
        vm.expectEmit(true, true, true, false, address(entryPoint));
        emit IEntryPoint.UserOperationEvent(userOpHash, address(quantumAccount), address(0), 0, true, 0, 0);
        vm.recordLogs();

        // 5. Send it to entry point
        entryPoint.handleOps(userOperationArray, payable(bundler.addr));

        // ASSERT

        // 6. Check if the user operation was successful.
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // 7. Decode the data to retrieve the non-indexed values
        (uint256 decodedNonce, bool decodedSuccess) = abi.decode(logs[2].data, (uint256, bool));

        // 8. Assert that the success value matches what was emitted
        assertEq(decodedNonce, 0); // Ensure the nonce matches
        assertEq(decodedSuccess, true); // Ensure the success value matches
    }
}
