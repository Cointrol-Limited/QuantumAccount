// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";

contract DeployEntryPoint is Script {
    function run() external returns (EntryPoint) {
        //HelperConfig helperConfig = new HelperConfig();
        //address entryPoint = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();
        return (entryPoint);
    }
}
