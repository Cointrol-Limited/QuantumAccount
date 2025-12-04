// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {QuantumAccount} from "../src/QuantumAccount.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {Falcon} from "../src/Falcon.sol";

contract DeployQuantumAccount is Script {
    function run(EntryPoint entryPoint, Falcon falcon, bytes memory domain, bytes memory _publicKey)
        external
        returns (QuantumAccount)
    {
        vm.startBroadcast();
        QuantumAccount quantumAccount =
            new QuantumAccount(address(entryPoint), msg.sender, address(falcon), domain, _publicKey);
        vm.stopBroadcast();
        return (quantumAccount);
    }
}
