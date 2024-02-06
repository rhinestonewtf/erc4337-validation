// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "account-abstraction/core/UserOperationLib.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { IEntryPointSimulations } from "account-abstraction/interfaces/IEntryPointSimulations.sol";
import { ValidationData, _packValidationData } from "account-abstraction/core/Helpers.sol";
import { IStakeManager } from "account-abstraction/interfaces/IStakeManager.sol";
import { EntryPointSimulations } from "account-abstraction/core/EntryPointSimulations.sol";
import { SenderCreator } from "account-abstraction/core/EntryPoint.sol";
import { etch } from "./Vm.sol";

address constant ENTRYPOINT_ADDR = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

/**
 * @title EntryPointSimulationsPatch
 * @dev EntryPointSimulations that is patched to be etched to a specific address
 */
contract EntryPointSimulationsPatch is EntryPointSimulations {
    address _entrypointAddr = address(this);

    SenderCreator _newSenderCreator;

    function init(address entrypointAddr) public {
        _entrypointAddr = entrypointAddr;
        initSenderCreator();
    }

    function initSenderCreator() internal override {
        // this is the address of the first contract created with CREATE by this address.
        address createdObj = address(
            uint160(uint256(keccak256(abi.encodePacked(hex"d694", _entrypointAddr, hex"01"))))
        );
        _newSenderCreator = SenderCreator(createdObj);
    }

    function senderCreator() internal view virtual override returns (SenderCreator) {
        return _newSenderCreator;
    }
}

/**
 * Creates a new entry point and etches it to the ENTRYPOINT_ADDR
 */
function etchEntrypoint() returns (IEntryPoint) {
    address payable entryPoint = payable(address(new EntryPointSimulationsPatch()));
    etch(ENTRYPOINT_ADDR, entryPoint.code);
    EntryPointSimulationsPatch(payable(ENTRYPOINT_ADDR)).init(entryPoint);

    return IEntryPoint(ENTRYPOINT_ADDR);
}
