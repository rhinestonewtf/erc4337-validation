// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { LibClone } from "solady/src/utils/LibClone.sol";

contract MockFactory {
    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createAccount(bytes32 salt) public payable virtual returns (address) {
        (, address account) = LibClone.createDeterministicERC1967(msg.value, implementation, salt);
        return account;
    }

    function getAddress(bytes32 salt) public view virtual returns (address) {
        return LibClone.predictDeterministicAddressERC1967(implementation, salt, address(this));
    }
}
