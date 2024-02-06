import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";
import { UserOperationLib } from "account-abstraction/core/UserOperationLib.sol";
import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";
import { IEntryPointSimulations } from "account-abstraction/interfaces/IEntryPointSimulations.sol";
import { ValidationData, _packValidationData } from "account-abstraction/core/Helpers.sol";
import { IStakeManager } from "account-abstraction/interfaces/IStakeManager.sol";

address constant ENTRYPOINT_ADDR = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
