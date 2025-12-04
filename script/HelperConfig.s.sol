// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        address payable entryAddress = payable(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
        EntryPoint entryPoint = EntryPoint(entryAddress);
        bytes memory domain = abi.encodePacked("ETHEREUM MAINNET");
        Falcon falcon = Falcon(address(0x1bFD01d5D9013e1f9351CDf4bCc6E789367E1ffd));
        NetworkConfig memory sepoliaConfig = NetworkConfig({entryPoint: entryPoint, domain: domain, falcon: falcon});
        // Quantum account deployed Oct 3 with address 0x21e9b414891741a9778c00f5323157fb753dc28F
        return sepoliaConfig;
    }

    /*
    *  Need to update entrypoint value once an entry point has been deployed to Sepolia.
    */
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        address payable entryAddress = payable(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
        EntryPoint entryPoint = EntryPoint(entryAddress);
        bytes memory domain = abi.encodePacked("ETHEREUM SEPOLIA");
        Falcon falcon = Falcon(address(0xCb68F85Fc7F3Ee95769065C9DccCE9340c6dd082));
        NetworkConfig memory sepoliaConfig = NetworkConfig({entryPoint: entryPoint, domain: domain, falcon: falcon});
        // deployed Oct 3 with address 0xC1C72BEA860b1F85F08CbAaFFfcd59F13A8Ea72a
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
