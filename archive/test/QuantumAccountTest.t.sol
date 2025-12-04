// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2 as console} from "forge-std/Test.sol";
import {QuantumAccount} from "src/QuantumAccount.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "../lib/account-abstraction/contracts/core/Helpers.sol";
import {DeployEntryPoint} from "../script/DeployEntryPoint.s.sol";
import {Falcon} from "../src/Falcon.sol";
import {MockFalconData} from "./mocks/MockFalconData.sol";

contract QuantumAccountHarness is QuantumAccount {
    constructor(address entryPoint, address owner, address falcon, bytes memory domain, bytes memory publicKeyBytes)
        QuantumAccount(entryPoint, owner, falcon, domain, publicKeyBytes)
    {}

    // exposes `_validateSignature` for testing
    function validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        view
        returns (uint256)
    {
        return _validateSignature(userOp, userOpHash);
    }
}

contract RevertsOnEthTransfer {
    fallback() external {
        revert("");
    }
}

contract QuantumAccountTest is Test {
    QuantumAccountHarness private quantumAccountHarness;
    EntryPoint private entryPoint;
    Falcon private falcon;
    bytes private domain;
    MockFalconData mockData;

    Account owner;
    Account randomUser;
    bytes publicKey;
    bytes signature;

    function setUp() external {
        //HelperConfig helperConfig = new HelperConfig();
        //entryPoint=  helperConfig.activeNetworkConfig();
        domain = abi.encodePacked("ETHEREUM");
        owner = makeAccount("owner");
        randomUser = makeAccount("randomUser");
        DeployEntryPoint deployEntryPoint = new DeployEntryPoint();
        entryPoint = deployEntryPoint.run();
        falcon = new Falcon();
        mockData = new MockFalconData();
        (signature, publicKey) = mockData.getSignatureAndPublicKey(0);
        quantumAccountHarness =
            new QuantumAccountHarness(address(entryPoint), owner.addr, address(falcon), domain, publicKey);
        vm.deal(address(quantumAccountHarness), 10 ether);
    }

    function testStateVariables() public view {
        // Arrange

        // Act
        address contractOwner = quantumAccountHarness.getOwner();
        address contractEntryPoint = address(quantumAccountHarness.entryPoint());
        address contractFalcon = address(quantumAccountHarness.getFalcon());
        bytes memory contractDomain = quantumAccountHarness.getDomain();

        // Assert
        vm.assertEq(owner.addr, contractOwner);
        vm.assertEq(address(entryPoint), contractEntryPoint);
        vm.assertEq(address(falcon), contractFalcon);
        vm.assertEq(contractDomain, domain);
    }

    function testExecuteFunction() public {
        // Arrange
        uint256 initalBalanceOfRandomUser = randomUser.addr.balance;
        uint256 initalBalanceOfAccountContract = address(quantumAccountHarness).balance;

        uint256 valueToSend = 1 ether;

        // Act
        vm.prank(address(entryPoint));
        quantumAccountHarness.execute(randomUser.addr, valueToSend, "");

        // Assert
        vm.assertEq(randomUser.addr.balance, initalBalanceOfRandomUser + valueToSend);
        vm.assertEq(address(quantumAccountHarness).balance, initalBalanceOfAccountContract - valueToSend);
    }

    function testExecuteRevertsWithCorrectError() public {
        // Arrange
        uint256 valueToSend = 1 ether;

        // Act + Assert
        vm.prank(randomUser.addr);
        vm.expectRevert(bytes("account: not from EntryPoint"));
        quantumAccountHarness.execute(randomUser.addr, valueToSend, "");
    }

    function testCallFromExecuteFails() public {
        // Arrange
        RevertsOnEthTransfer revertsOnEthTransfer = new RevertsOnEthTransfer();

        uint256 valueToSend = 1 ether;

        // Act + Assert
        vm.prank(address(entryPoint)); // execute function needs to be executes from EntryPoint
        vm.expectRevert(QuantumAccount.QuantumAccount__CallFailed.selector);
        quantumAccountHarness.execute(address(revertsOnEthTransfer), valueToSend, "");
    }

    function testValidateSignature() public view {
        // Arrange
        PackedUserOperation memory userOp = mockData.getUserOp(0);
        //bytes32 message = "Hello, world!";
        // Act
        bytes32 userOpHash = mockData.getUserOpHash(0);
        uint256 result = quantumAccountHarness.validateSignature(userOp, userOpHash);
        // Assert
        vm.assertEq(result, SIG_VALIDATION_SUCCESS);
    }

    function testValidateSignatureWithWrongSignature() public view {
        // Arrange
        PackedUserOperation memory userOp = mockData.getUserOp(0);
        bytes32 message = "Hello, world! This should fail";
        // Act
        uint256 result = quantumAccountHarness.validateSignature(userOp, message);
        // Assert
        vm.assertEq(result, SIG_VALIDATION_FAILED);
    }
}
