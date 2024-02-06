// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager,
    ENTRYPOINT_ADDR
} from "./lib/ERC4337.sol";
import { VmSafe } from "forge-std/Vm.sol";
import {
    snapshot,
    startMappingRecording,
    startStateDiffRecording,
    stopAndReturnStateDiff,
    stopMappingRecording,
    revertTo
} from "./lib/Vm.sol";
import { ERC4337SpecsParser } from "./SpecsParser.sol";

/**
 * @title Simulator
 * @author kopy-kat
 * @dev Simulates a UserOperation and validates the ERC-4337 rules
 */
library Simulator {
    /**
     * @dev Simulates a UserOperation and validates the ERC-4337 rules
     * @dev will revert if the UserOperation is invalid
     * @param userOp The PackedUserOperation to simulate
     * @param onEntryPoint The address of the entry point to simulate the UserOperation on
     */
    function simulateUserOp(PackedUserOperation memory userOp, address onEntryPoint) internal {
        // Create snapshot to revert to after simulation
        uint256 snapShotId = snapshot();

        // Start recording mapping accesses and state diffs
        startMappingRecording();
        startStateDiffRecording();

        // Simulate the UserOperation
        IEntryPointSimulations.ValidationResult memory result =
            IEntryPointSimulations(onEntryPoint).simulateValidation(userOp);

        // Ensure that the signature was valid
        require(result.returnInfo.sigFailed == false, "Simulation error: signature failed");

        // Get the state diffs
        VmSafe.AccountAccess[] memory accesses = stopAndReturnStateDiff();

        // Validate the ERC-4337 rules
        ERC4337SpecsParser.parseValidation(accesses, userOp);

        // Stop (and remove) recording mapping accesses
        stopMappingRecording();

        // Revert to snapshot
        revertTo(snapShotId);
    }
}
