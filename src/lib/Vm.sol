// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Vm, VmSafe } from "forge-std/Vm.sol";

address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

function etch(address target, bytes memory runtimeBytecode) {
    Vm(VM_ADDR).etch(target, runtimeBytecode);
}

function getLabel(address addr) view returns (string memory) {
    return Vm(VM_ADDR).getLabel(addr);
}

function snapshotState() returns (uint256) {
    return Vm(VM_ADDR).snapshotState();
}

function revertToState(uint256 id) returns (bool) {
    return Vm(VM_ADDR).revertToState(id);
}

function startMappingRecording() {
    Vm(VM_ADDR).startMappingRecording();
}

function stopMappingRecording() {
    Vm(VM_ADDR).stopMappingRecording();
}

function getMappingKeyAndParentOf(address target, bytes32 slot) returns (bool, bytes32, bytes32) {
    return Vm(VM_ADDR).getMappingKeyAndParentOf(target, slot);
}

function expectRevert() {
    Vm(VM_ADDR).expectRevert();
}

function startDebugTraceRecording() {
    Vm(VM_ADDR).startDebugTraceRecording();
}

function stopAndReturnDebugTraceRecording() returns (VmSafe.DebugStep[] memory steps) {
    return Vm(VM_ADDR).stopAndReturnDebugTraceRecording();
}

function pauseGasMetering() {
    Vm(VM_ADDR).pauseGasMetering();
}

function resumeGasMetering() {
    Vm(VM_ADDR).resumeGasMetering();
}
