// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {DeployEntryPoint} from "../../script/DeployEntryPoint.s.sol";
import {EntryPoint} from "../../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "../../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {QuantumAccount} from "../../src/QuantumAccount.sol";

contract GenerateuserOp is Test {
    
    EntryPoint private entryPoint;
    address quantumAccount = 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496;

    function setUp() external {
        // set EntryPoint
        DeployEntryPoint deployEntryPoint = new DeployEntryPoint();
        entryPoint = deployEntryPoint.run();
    }

    function testGenerateUserOp() public view {

        bytes memory callData = abi.encodeWithSelector(QuantumAccount.execute.selector, "0x78dfd9b2170b8a1b4c7b103be8a5498858b39914", 0.1 ether, "");
        console.logBytes(callData);

uint256 gasLimit = type(uint24).max;
        uint256 verificationGasLimit = 0x000000000000000000000000ffffffff;

        uint256 preVerificationGas = 0x000000000000000000000000ffffffff;

        uint256 maxFeePerGas = type(uint8).max;
        uint256 maxPriorityFeePerGas = type(uint8).max;

        bytes32 accountGasLimits = bytes32(verificationGasLimit << 128 | gasLimit);

        bytes32 gasFees = bytes32(maxPriorityFeePerGas << 128 | maxFeePerGas);
        console.log("gasLimit", gasLimit);
        console.log("verificationGasLimit", verificationGasLimit);
        console.log("preVerificationGas", preVerificationGas);
        console.log("maxFeePerGas", maxFeePerGas);
        console.log("maxPriorityFeePerGas", maxPriorityFeePerGas);
        console.log("accountGasLimits");
        console.logBytes32(accountGasLimits);
        console.log("gasFees");
        console.logBytes32(gasFees);

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(quantumAccount),
            nonce: 0,
            initCode: hex"",
            callData: callData,
            accountGasLimits: accountGasLimits,
            preVerificationGas: preVerificationGas,
            gasFees: gasFees,
            paymasterAndData: hex"",
            signature: hex""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        console.logBytes32(userOpHash);
    }
}