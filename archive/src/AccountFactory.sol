// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SimpleAccount} from "./SimpleAccount.sol";

contract AccountFactory {
    function createAccount(address entryPointAddress, address owner) external returns (SimpleAccount) {
        return new SimpleAccount(entryPointAddress, owner);
    }
}
