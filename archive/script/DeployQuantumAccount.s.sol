// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {QuantumAccount} from "../src/QuantumAccount.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Falcon} from "../src/Falcon.sol";

contract DeployQuantumAccount is Script {
    function run(EntryPoint entryPoint, Falcon falcon, bytes memory domain, bytes memory _publicKey)
        external
        returns (QuantumAccount)
    {
        //if (_owner == address(0)) {
        //    _owner = msg.sender;
        //}
        vm.startBroadcast();
        QuantumAccount quantumAccount =
            new QuantumAccount(address(entryPoint), msg.sender, address(falcon), domain, _publicKey);
        vm.stopBroadcast();
        return (quantumAccount);
    }
}
