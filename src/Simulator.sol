// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    PackedUserOperation,
    IEntryPointSimulations,
    IEntryPointSimulationsV060,
    UserOperation,
    UserOperationDetails,
    IStakeManager
} from "./lib/ERC4337.sol";
import { VmSafe } from "forge-std/Vm.sol";
import {
    snapshot,
    startMappingRecording,
    startStateDiffRecording,
    stopAndReturnStateDiff,
    stopMappingRecording,
    revertTo,
    expectRevert
} from "./lib/Vm.sol";
import { ERC4337SpecsParser } from "./SpecsParser.sol";

/**
 * @title Simulator
 * @author kopy-kat
 * @dev Simulates a UserOperation and validates the ERC-4337 rules
 */
library Simulator {
    /**
     * Simulates a UserOperation and validates the ERC-4337 rules
     * @dev This function will revert if the UserOperation is invalid
     * @dev If the simulation fails, the rules might not be checked correctly so simulationSuccess
     * should be handled accordingly
     * @dev This function is used for v0.7 ERC-4337
     *
     * @param userOp The PackedUserOperation to simulate
     * @param onEntryPoint The address of the entry point to simulate the UserOperation on
     *
     * @return simulationSuccess True if the simulation was successful, false otherwise
     */
    function simulateUserOp(
        PackedUserOperation memory userOp,
        address onEntryPoint
    )
        internal
        returns (bool simulationSuccess)
    {
        // Pre-simulation setup
        _preSimulation();

        // Encode the call data
        bytes memory epCallData =
            abi.encodeCall(IEntryPointSimulations.simulateValidation, (userOp));

        // Simulate the UserOperation and exit on revert
        bytes memory returnData;
        (simulationSuccess, returnData) = address(onEntryPoint).call(epCallData);
        if (!simulationSuccess) {
            return simulationSuccess;
        }

        // Decode the return data
        IEntryPointSimulations.ValidationResult memory result =
            abi.decode(returnData, (IEntryPointSimulations.ValidationResult));

        // Ensure that the signature was valid
        if (result.returnInfo.accountValidationData != 0) {
            bool sigFailed = (result.returnInfo.accountValidationData & 1) == 1;
            if (sigFailed) {
                simulationSuccess = false;
            }
        }

        // Create a UserOperationDetails struct
        // This is to make it easier to maintain compatibility of the differnt UserOperation
        // versions
        UserOperationDetails memory userOpDetails = UserOperationDetails({
            entryPoint: onEntryPoint,
            sender: userOp.sender,
            initCode: userOp.initCode,
            paymasterAndData: userOp.paymasterAndData
        });

        // Post-simulation validation
        _postSimulation(userOpDetails);
    }

    /**
     * Simulates a UserOperation and validates the ERC-4337 rules
     * @dev this function will revert if the UserOperation is invalid
     * @dev If the simulation fails, the rules might not be checked correctly so simulationSuccess
     * should be handled accordingly
     * @dev This function is used for v0.6 ERC-4337
     *
     * @param userOp The UserOperation to simulate
     * @param onEntryPoint The address of the entry point to simulate the UserOperation on
     *
     * @return simulationSuccess True if the simulation was successful, false otherwise
     */
    function simulateUserOp(
        UserOperation memory userOp,
        address onEntryPoint
    )
        internal
        returns (bool simulationSuccess)
    {
        // Pre-simulation setup
        _preSimulation();

        // Simulate the UserOperation and handle revert
        try IEntryPointSimulationsV060(onEntryPoint).simulateValidation(userOp) {
            simulationSuccess = true;
        } catch (bytes memory reason) {
            simulationSuccess = false;

            uint256 sigFailed;
            // selector (4 bytes) + length(32 bytes) + preOpGas(32 bytes)
            // + prefund (32 bytes) + sigFailed (32 bytes)
            uint256 pos = 4 + 32 + 32 + 32;
            assembly {
                sigFailed := mload(add(reason, pos))
            }
        }

        // Create a UserOperationDetails struct
        // This is to make it easier to maintain compatibility of the differnt UserOperation
        // versions
        UserOperationDetails memory userOpDetails = UserOperationDetails({
            entryPoint: onEntryPoint,
            sender: userOp.sender,
            initCode: userOp.initCode,
            paymasterAndData: userOp.paymasterAndData
        });

        // Post-simulation validation
        _postSimulation(userOpDetails);
    }

    /**
     * Pre-simulation setup
     */
    function _preSimulation() internal {
        // Create snapshot to revert to after simulation
        uint256 snapShotId = snapshot();

        // Store the snapshot id so that it can be reverted to after simulation
        bytes32 snapShotSlot = keccak256(abi.encodePacked("Simulator.SnapshotId"));
        assembly {
            sstore(snapShotSlot, snapShotId)
        }

        // Start recording mapping accesses and state diffs
        startMappingRecording();
        startStateDiffRecording();
    }

    /**
     * Post-simulation validation
     *
     * @param userOpDetails The UserOperationDetails to validate
     */
    function _postSimulation(UserOperationDetails memory userOpDetails) internal {
        // Get the state diffs
        VmSafe.AccountAccess[] memory accesses = stopAndReturnStateDiff();

        // Validate the ERC-4337 rules
        ERC4337SpecsParser.parseValidation(accesses, userOpDetails);

        // Stop (and remove) recording mapping accesses
        stopMappingRecording();

        // Get the snapshot id
        uint256 snapShotId;
        bytes32 snapShotSlot = keccak256(abi.encodePacked("Simulator.SnapshotId"));
        assembly {
            snapShotId := sload(snapShotSlot)
        }

        // Revert to snapshot
        revertTo(snapShotId);
    }
}
