// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {Falcon} from "../src/Falcon.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        Falcon falcon;
        EntryPoint entryPoint;
        bytes domain;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    /*
    *  Need to update entrypoint value once an entry point has been deployed to Sepolia.
    */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        address payable entryAddress = payable(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
        EntryPoint entryPoint = EntryPoint(entryAddress);
        bytes memory domain = abi.encodePacked("ETHEREUM SEPOLIA");
        Falcon falcon = Falcon(address(0x7F7E3DbAc052a86A1A354A2d2F8d11e537Cb14e8));
        NetworkConfig memory sepoliaConfig = NetworkConfig({entryPoint: entryPoint, domain: domain, falcon: falcon});
        return sepoliaConfig;
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        /*         if (address(activeNetworkConfig.entryPoint) != address(0)){
            return activeNetworkConfig;
        } */

        vm.startBroadcast();
        EntryPoint entryPoint = new EntryPoint();
        Falcon falcon = new Falcon();
        vm.stopBroadcast();
        bytes memory domain = abi.encodePacked("ETHEREUM");

        NetworkConfig memory anvilConfig = NetworkConfig({entryPoint: entryPoint, domain: domain, falcon: falcon});
        return anvilConfig;
    }
}
