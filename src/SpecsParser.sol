// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager,
    UserOperationDetails
} from "./lib/ERC4337.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { getLabel, getMappingKeyAndParentOf } from "./lib/Vm.sol";

/**
 * @title ERC4337SpecsParser
 * @author kopy-kat
 * @dev Parses and validates the ERC-4337 rules
 * @custom:credits Credits to Dror (drortirosh) for the approach and an initial prototype
 */
library ERC4337SpecsParser {
    // Minimum stake delay
    uint256 constant MIN_UNSTAKE_DELAY = 1 days;
    // Minimum stake value
    uint256 constant MIN_STAKE_VALUE = 0.5 ether;

    // Emitted if an invalid storage location is accessed
    error InvalidStorageLocation(
        address contractAddress,
        string contractLabel,
        bytes32 slot,
        bytes32 previousValue,
        bytes32 newValue,
        bool isWrite
    );

    // Emitted if a banned opcode is used
    error InvalidOpcode(address contractAddress, uint8 opcode);

    /**
     * Entity struct
     * UserOperation
     * @dev Entities can be factory, paymaster, aggregator and account, if included in the
     */
    struct Entities {
        // Account
        address account;
        // Factory
        address factory;
        bool isFactoryStaked;
        // Paymaster
        address paymaster;
        bool isPaymasterStaked;
        // Aggregator
        address aggregator;
        bool isAggregatorStaked;
    }

    /**
     * Parses and validates the ERC-4337 rules
     *
     * @param accesses The state diffs to validate
     * @param userOpDetails The UserOperationDetails to validate
     * @param debugTrace A trace of used opcodes, stack and memory to validate
     */
    function parseValidation(
        VmSafe.AccountAccess[] memory accesses,
        UserOperationDetails memory userOpDetails,
        VmSafe.DebugStep[] memory debugTrace
    )
        internal
    {
        // Get entities for the userOp
        Entities memory entities = getEntities(userOpDetails);

        // Filter debug trace to get the debug steps for the userOp and paymasterUserOp
        (
            VmSafe.DebugStep[] memory filteredUserOpSteps,
            VmSafe.DebugStep[] memory filteredPaymasterUserOpSteps
        ) = filterDebugTrace(debugTrace, entities, userOpDetails.entryPoint);

        // Validate banned opcodes for the userOp and paymasterUserOp
        validateBannedOpcodes(filteredUserOpSteps);
        validateBannedOpcodes(filteredPaymasterUserOpSteps);

        // Validate there are not out of gas errors for the userOp and paymasterUserOp
        validateOutOfGas(filteredUserOpSteps);
        validateOutOfGas(filteredPaymasterUserOpSteps);

        // Loop over the state diffs
        for (uint256 i; i < accesses.length; i++) {
            VmSafe.AccountAccess memory currentAccess = accesses[i];

            // Ignore test files
            if (currentAccess.account != address(this) && currentAccess.accessor != address(this)) {
                // Validate storage accesses
                validateBannedStorageLocations(currentAccess, entities);

                // Validate disallowed *CALLs
                validateDisallowedCalls(currentAccess, entities, userOpDetails.entryPoint);

                // Validate disallowed EXT* opcodes
                validateDisallowedExtOpCodes(currentAccess, entities);

                // Validate disallowed CREATEs
                validateDisallowedCreate(currentAccess, entities);
            }
        }
    }

    /**
     * Validates that no banned opcodes are used
     * @param debugTrace The debug trace to validate
     */
    function validateBannedOpcodes(VmSafe.DebugStep[] memory debugTrace) internal pure {
        // forbidden opcodes are GASPRICE, GASLIMIT, DIFFICULTY, TIMESTAMP, BASEFEE, BLOCKHASH,
        // NUMBER, SELFBALANCE, BALANCE, ORIGIN, GAS, CREATE, COINBASE, SELFDESTRUCT
        // Exception: GAS is allowed if followed immediately by one of { CALL, DELEGATECALL,
        // CALLCODE, STATICCALL }]

        // Loop over the debug steps to validate the opcodes
        for (uint256 i; i < debugTrace.length; i++) {
            // Check if the current opcode is a forbidden opcode
            if (isForbiddenOpcode(debugTrace[i].opcode)) {
                // Check if the current opcode is GAS, if so, check if it is followed by a CALL,
                // DELEGATECALL, CALLCODE or STATICCALL
                if (
                    debugTrace[i].opcode == 0x5A // GAS
                ) {
                    if (
                        i + 1 >= debugTrace.length
                            || debugTrace[i + 1].opcode != 0xF1 // CALL
                                && debugTrace[i + 1].opcode != 0xF4 // DELEGATECALL
                                && debugTrace[i + 1].opcode != 0xF2 // CALLCODE
                                && debugTrace[i + 1].opcode != 0xFA // STATICCALL
                    ) {
                        revert InvalidOpcode(debugTrace[i].contractAddr, 0x5A);
                    }
                } else {
                    revert InvalidOpcode(debugTrace[i].contractAddr, debugTrace[i].opcode);
                }
            }
        }
    }

    /**
     * Filter debug trace, we are interested in the following debug traces:
     * - Entrypoint -> validateUserOp
     * - Entrypoint - validatePaymasterUserOp
     * @param debugTrace The debug trace to filter
     * @param entities The entities of the userOp
     * @param entryPoint The entryPoint address
     * @return filteredUserOpSteps The filtered debug steps
     * @return filteredPaymasterUserOpSteps The filtered debug steps
     */
    function filterDebugTrace(
        VmSafe.DebugStep[] memory debugTrace,
        Entities memory entities,
        address entryPoint
    )
        private
        pure
        returns (VmSafe.DebugStep[] memory, VmSafe.DebugStep[] memory)
    {
        // Init filtered debug steps
        VmSafe.DebugStep[] memory filteredUserOpSteps = new VmSafe.DebugStep[](debugTrace.length);
        VmSafe.DebugStep[] memory filteredPaymasterUserOpSteps =
            new VmSafe.DebugStep[](debugTrace.length);

        // Init filtered debug steps lengths
        uint256 filteredUserOpStepsLength;
        uint256 filteredPaymasterUserOpStepsLength;

        // Init start depth (first time we enter the entryPoint)
        uint256 startDepth = 0;

        // Loop over the debug steps to find the start depth
        for (uint256 i; i < debugTrace.length; i++) {
            // Check if the current debug step contract address is the entryPoint
            if (debugTrace[i].contractAddr == entryPoint) {
                // Set the start depth
                startDepth = debugTrace[i].depth;
                break;
            }
        }

        // Init currentContractAddr
        address currentContractAddr;

        // Loop over the debug steps to filter the debug steps
        for (uint256 i = 0; i < debugTrace.length; i++) {
            // Ignore calls on base depth where the contract address is the entryPoint
            if (debugTrace[i].depth == startDepth && debugTrace[i].contractAddr == entryPoint) {
                // If the current opcode is call or static call, update the currentContractAddr with
                // the value from the stack
                if (
                    debugTrace[i].opcode == 0xF1 // CALL
                        || debugTrace[i].opcode == 0xFA // STATICCALL
                ) {
                    currentContractAddr = address(uint160(uint256(debugTrace[i].stack[1])));
                }
                continue;
            }

            // If the depth is grander than the start depth, we are interested in the debug steps,
            // add to the filteredUserOpSteps
            // or filteredPaymasterUserOpSteps based on the currentContractAddr
            if (debugTrace[i].depth > startDepth) {
                if (currentContractAddr == entities.account) {
                    filteredUserOpSteps[filteredUserOpStepsLength++] = debugTrace[i];
                } else if (currentContractAddr == entities.paymaster) {
                    filteredPaymasterUserOpSteps[filteredPaymasterUserOpStepsLength++] =
                        debugTrace[i];
                }
            }
        }

        // Update the filtered debug steps lengths
        assembly {
            mstore(filteredUserOpSteps, filteredUserOpStepsLength)
            mstore(filteredPaymasterUserOpSteps, filteredPaymasterUserOpStepsLength)
        }

        // Return the filtered debug steps
        return (filteredUserOpSteps, filteredPaymasterUserOpSteps);
    }

    /**
     * Validate that the simulation does not revert with Out of Gas
     * @param debugTrace The debug trace to validate
     */
    function validateOutOfGas(VmSafe.DebugStep[] memory debugTrace) internal pure {
        // Loop over the debug steps to validate out of gas errors
        for (uint256 i; i < debugTrace.length; i++) {
            if (debugTrace[i].isOutOfGas) {
                revert("[OP-020] Simulation reverts with Out of Gas");
            }
        }
    }

    /**
     * Validates that no banned storage locations are accessed
     *
     * @param currentAccess The current state diff to validate
     * @param entities The entities of the userOp
     */
    function validateBannedStorageLocations(
        VmSafe.AccountAccess memory currentAccess,
        Entities memory entities
    )
        internal
    {
        // Loop over the storage accesses
        for (uint256 j; j < currentAccess.storageAccesses.length; j++) {
            // Get current storage access and account
            VmSafe.StorageAccess memory currentStorageAccess = currentAccess.storageAccesses[j];
            address currentAccessAccount = currentStorageAccess.account;

            // Allow storage accesses from the sender or allowed entities
            if (!isEntityAndStaked(entities, currentAccessAccount)) {
                bytes32 currentSlot = currentStorageAccess.slot;
                bool isAssociated = isAssociatedStorage(currentSlot, currentAccessAccount, entities);
                if (!isAssociated) {
                    revert InvalidStorageLocation(
                        currentAccessAccount,
                        getLabel(currentAccessAccount),
                        currentSlot,
                        currentStorageAccess.previousValue,
                        currentStorageAccess.newValue,
                        currentStorageAccess.isWrite
                    );
                }
            }
        }
    }

    /**
     * Validates that no disallowed *CALLs are made
     *
     * @param currentAccess The current state diff to validate
     * @param entities The entities of the userOp
     */
    function validateDisallowedCalls(
        VmSafe.AccountAccess memory currentAccess,
        Entities memory entities,
        address entryPoint
    )
        internal
        view
    {
        if (
            currentAccess.kind == VmSafe.AccountAccessKind.Call
                || currentAccess.kind == VmSafe.AccountAccessKind.DelegateCall
                || currentAccess.kind == VmSafe.AccountAccessKind.CallCode
                || currentAccess.kind == VmSafe.AccountAccessKind.StaticCall
        ) {
            // Check that the account has code, is a standard precompile or is the sender (before
            // deployment)
            // Revert otherwise
            if (
                currentAccess.account.code.length == 0 && !isPrecompile(currentAccess.account)
                    && currentAccess.account != entities.account
            ) {
                revert("[OP-041] Cannot *CALL addresses without code");
            }

            bool callerIsAccount = currentAccess.accessor == entities.account;
            bool callerIsFactory = currentAccess.accessor == entities.factory;
            bool calleeIsEntryPoint = currentAccess.account == entryPoint;

            // Check that value is only used from account or factory to EntryPoint
            // Revert otherwise
            if (currentAccess.value > 0) {
                if (!((callerIsAccount || callerIsFactory) && calleeIsEntryPoint)) {
                    revert("[OP-061] Cannot use value except from account or factory to EntryPoint");
                }
            }

            // Allow self calls from EntryPoint
            if (calleeIsEntryPoint && currentAccess.accessor != entryPoint) {
                // Allow only depositTo from factory/account or fallback from account
                // Revert otherwise
                if (
                    (
                        !(
                            (
                                (callerIsAccount || callerIsFactory)
                                    && currentAccess.data.length >= 4
                                    && bytes4(currentAccess.data) == bytes4(0xb760faf9)
                            ) || (callerIsAccount && currentAccess.data.length == 0)
                        )
                    )
                ) {
                    revert(
                        "[OP-052] Cannot call EntryPoint except depositTo from factory or account"
                    );
                }
            }
        }
    }

    /**
     * Validates that no disallowed EXT* opcodes are used
     *
     * @param currentAccess The current state diff to validate
     * @param entities The entities of the userOp
     */
    function validateDisallowedExtOpCodes(
        VmSafe.AccountAccess memory currentAccess,
        Entities memory entities
    )
        internal
        view
    {
        if (
            currentAccess.kind == VmSafe.AccountAccessKind.Extcodesize
                || currentAccess.kind == VmSafe.AccountAccessKind.Extcodehash
                || currentAccess.kind == VmSafe.AccountAccessKind.Extcodecopy
        ) {
            // Check that the account has code, is a standard precompile or is the sender (before
            // deployment)
            // Revert otherwise
            if (
                currentAccess.account.code.length == 0 && !isPrecompile(currentAccess.account)
                    && currentAccess.account != entities.account
            ) {
                revert("[OP-041] EXT* opcodes cannot access addresses without code");
            }
        }
    }

    /**
     * Validates that no disallowed CREATE2 opcodes are used
     *
     * @param currentAccess The current state diff to validate
     * @param entities The entities of the userOp
     */
    function validateDisallowedCreate(
        VmSafe.AccountAccess memory currentAccess,
        Entities memory entities
    )
        internal
        pure
    {
        if (currentAccess.kind == VmSafe.AccountAccessKind.Create) {
            // Check that the initCode is not empty and that only the sender is created
            // Note: If the initCode is empty, the factory address is address(0)
            // Revert otherwise
            if (entities.factory == address(0) || currentAccess.account != entities.account) {
                revert(
                    "[OP-031] CREATE2 is allowed exactly once in the deployment phase and must deploy code for the sender address"
                );
            }
        }
    }

    /**
     * Returns whether the current storage slot is associated with an entity
     *
     * @param currentSlot The current storage slot
     * @param currentAccessAccount The contract address of the current access
     * @param entities The entities of the UserOperation
     *
     * @return isAssociated Whether the current storage slot is associated with an entity
     */
    function isAssociatedStorage(
        bytes32 currentSlot,
        address currentAccessAccount,
        Entities memory entities
    )
        internal
        returns (bool isAssociated)
    {
        // Check if the current slot is associated with an entity
        if (slotMatchesEntity(currentSlot, entities)) {
            isAssociated = true;
        } else {
            // Get the parent of the current slot if it is a mapping
            (bool found, bytes32 key) = getMappingParent(currentAccessAccount, currentSlot);

            // If the parent was found, check if it is associated with an entity
            if (found) {
                if (slotMatchesEntity(key, entities)) {
                    isAssociated = true;
                }
            }
        }
        // todo: [STO-033] Read-only access to any storage in non-entity contract.
    }

    /**
     * Returns whether the current storage slot matches an entity
     *
     * @param slot The current storage slot
     * @param entities The entities of the UserOperation
     *
     * @return _ Whether the current storage slot matches an entity
     */
    function slotMatchesEntity(
        bytes32 slot,
        Entities memory entities
    )
        internal
        pure
        returns (bool)
    {
        // Make sure that the slot is not empty and thus matches with an unset entity
        if (slot == bytes32(0)) {
            return false;
        }

        // Check if the slot matches an entity and the entity is staked (if applicable)
        return slot == bytes32(uint256(uint160(entities.account)))
            || (slot == bytes32(uint256(uint160(entities.factory))) && entities.isFactoryStaked)
            || (slot == bytes32(uint256(uint160(entities.paymaster))) && entities.isPaymasterStaked);
    }

    /**
     * Returns the parent of the current storage slot
     *
     * @param currentAccessAccount The contract address of the current access
     * @param currentSlot The current storage slot
     *
     * @return found Whether the parent was found
     * @return key The parent slot
     */
    function getMappingParent(
        address currentAccessAccount,
        bytes32 currentSlot
    )
        internal
        returns (bool found, bytes32 key)
    {
        // Get the parent of the current slot
        (bool _found, bytes32 _key,) = getMappingKeyAndParentOf(currentAccessAccount, currentSlot);

        // If the parent was found, return it
        if (_found) {
            found = _found;
            key = _key;
        } else {
            // If the parent was not found, loop over the previous 128 slots to find it
            // This covers mappings using structs up to an offset of 128
            for (uint256 k = 1; k <= 128 && k <= uint256(currentSlot); k++) {
                (_found, _key,) = getMappingKeyAndParentOf(
                    currentAccessAccount, bytes32(uint256(currentSlot) - k)
                );
                if (_found) {
                    found = _found;
                    key = _key;
                    break;
                }
            }
        }
    }

    /**
     * Returns the entities of the UserOperation
     *
     * @param userOpDetails The UserOperationDetails to get the entities of
     *
     * @return entities The entities of the UserOperation
     */
    function getEntities(UserOperationDetails memory userOpDetails)
        internal
        view
        returns (Entities memory entities)
    {
        // Get UserOperation factory
        address factory;
        if (userOpDetails.initCode.length > 20) {
            bytes memory initCode = userOpDetails.initCode;
            assembly {
                factory := mload(add(initCode, 20))
            }
        }

        // Get UserOperation paymaster
        address paymaster;
        if (userOpDetails.paymasterAndData.length > 20) {
            bytes memory paymasterAndData = userOpDetails.paymasterAndData;
            assembly {
                paymaster := mload(add(paymasterAndData, 20))
            }
        }

        // Get UserOperation aggregator
        // Notice: Not supported yet
        address aggregator;

        entities = Entities({
            account: userOpDetails.sender,
            factory: factory,
            isFactoryStaked: isStaked(factory, userOpDetails.entryPoint),
            paymaster: paymaster,
            isPaymasterStaked: isStaked(paymaster, userOpDetails.entryPoint),
            aggregator: aggregator,
            isAggregatorStaked: isStaked(aggregator, userOpDetails.entryPoint)
        });
    }

    /**
     * Returns whether something is an entity and is staked
     *
     * @param entities The entities of the UserOperation
     * @param toCheck The address to check
     *
     * @return addressIsEntityAndStaked Whether the address is an entity and is staked
     */
    function isEntityAndStaked(
        Entities memory entities,
        address toCheck
    )
        internal
        pure
        returns (bool addressIsEntityAndStaked)
    {
        if (toCheck == entities.account) {
            addressIsEntityAndStaked = true;
        } else if (toCheck == entities.factory) {
            addressIsEntityAndStaked = entities.isFactoryStaked;
        } else if (toCheck == entities.paymaster) {
            addressIsEntityAndStaked = entities.isPaymasterStaked;
        } else if (toCheck == entities.aggregator) {
            addressIsEntityAndStaked = entities.isAggregatorStaked;
        }
    }

    /**
     * Returns whether the entity is staked
     *
     * @param entity The entity to check
     *
     * @return isEntityStaked Whether the entity is staked
     */
    function isStaked(
        address entity,
        address entryPoint
    )
        internal
        view
        returns (bool isEntityStaked)
    {
        // Get the deposit info for the entity
        IStakeManager.DepositInfo memory deposit = IStakeManager(entryPoint).getDepositInfo(entity);

        // Return whether the entity is staked
        isEntityStaked =
            deposit.stake >= MIN_STAKE_VALUE && deposit.unstakeDelaySec >= MIN_UNSTAKE_DELAY;
    }

    /**
     * Returns whether the address is a precompile
     *
     * @param target The address to check
     *
     * @return isPrecompile Whether the address is a precompile
     */
    function isPrecompile(address target) internal pure returns (bool) {
        return uint256(uint160(target)) <= 0x09 || uint256(uint160(target)) == 0x100;
    }

    /**
     * Checks if the opcode is a forbidden opcode
     *
     * @param opcode The opcode to check
     *
     * @return isForbidden Whether the opcode is forbidden
     */
    function isForbiddenOpcode(uint8 opcode) private pure returns (bool isForbidden) {
        return opcode == 0x3A // GASPRICE
            || opcode == 0x45 // GASLIMIT
            || opcode == 0x44 // DIFFICULTY (PREVRANDAO)
            || opcode == 0x42 // TIMESTAMP
            || opcode == 0x48 // BASEFEE
            || opcode == 0x40 // BLOCKHASH
            || opcode == 0x43 // NUMBER
            || opcode == 0x47 // SELFBALANCE
            || opcode == 0x31 // BALANCE
            || opcode == 0x32 // ORIGIN
            || opcode == 0x5A // GAS
            || opcode == 0xF0 // CREATE
            || opcode == 0x41 // COINBASE
            || opcode == 0xFE // INVALID
            || opcode == 0xFF; // SELFDESTRUCT
    }
}
