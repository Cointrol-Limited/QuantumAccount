// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Falcon} from "../src/Falcon.sol";

contract DeployFalcon is Script {
    function run() external returns (Falcon) {
        vm.startBroadcast();
        Falcon falcon = new Falcon();
        vm.stopBroadcast();
        return (falcon);
    }
}
