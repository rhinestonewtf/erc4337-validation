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

library Simulator {
    function simulateUserOp(PackedUserOperation memory userOp, address onEntryPoint) internal {
        uint256 snapShotId = snapshot();
        IEntryPointSimulations simulationEntryPoint = IEntryPointSimulations(onEntryPoint);
        startMappingRecording();
        startStateDiffRecording();
        IEntryPointSimulations.ValidationResult memory result =
            simulationEntryPoint.simulateValidation(userOp);
        require(result.returnInfo.sigFailed == false, "Simulation error: signature failed");
        VmSafe.AccountAccess[] memory accesses = stopAndReturnStateDiff();
        ERC4337SpecsParser.parseValidation(accesses, userOp);
        stopMappingRecording();
        revertTo(snapShotId);
    }
}
