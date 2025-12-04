// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {SimpleAccount} from "../src/SimpleAccount.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySimpleAccount is Script {
    function run(EntryPoint entryPoint, address _owner) external returns (SimpleAccount) {
        //HelperConfig helperConfig = new HelperConfig();
        //address entryPoint = helperConfig.activeNetworkConfig();
        if (_owner == address(0)) {
            _owner = msg.sender;
        }
        vm.startBroadcast();
        SimpleAccount simpleAccount = new SimpleAccount(address(entryPoint), _owner);
        console.log(address(simpleAccount));
        vm.stopBroadcast();
        return (simpleAccount);
    }
}
