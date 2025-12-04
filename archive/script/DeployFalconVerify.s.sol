// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {FalconVerify} from "../src/FalconVerify.sol";

contract DeployFalconVerify is Script {
    function run() external returns (FalconVerify) {
        vm.startBroadcast();
        FalconVerify falconVerify = new FalconVerify();
        vm.stopBroadcast();
        return (falconVerify);
    }
}
