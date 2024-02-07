// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {
    IEntryPoint,
    IEntryPointSimulations,
    IStakeManager,
    ENTRYPOINT_ADDR,
    UserOperationDetails
} from "./lib/ERC4337.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { getLabel, getMappingKeyAndParentOf } from "./lib/Vm.sol";

/**
 * @title ERC4337SpecsParser
 * @author kopy-kat
 * @dev Parses and validates the ERC-4337 rules
 * @custom:credits Credits to Dror (drortirosh) for the approach and an intial prototype
 */
library ERC4337SpecsParser {
    // Minimum stake delay
    uint256 constant MIN_UNSTAKE_DELAY = 1 days;
    // Minimum stake value
    uint256 constant MIN_STAKE_VALUE = 0.5 ether;

    // Emmitted if an invalid storage location is accessed
    error InvalidStorageLocation(
        address contractAddress,
        string contractLabel,
        bytes32 slot,
        bytes32 previousValue,
        bytes32 newValue,
        bool isWrite
    );

    // Emmitted if a banned opcode is used
    error InvalidOpcode(address contractAddress, string opcode);

    /**
     * @dev Entity struct
     * @dev Entities can be factory, paymaster, aggregator and account, if included in the
     * UserOperation
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
     * @dev Parses and validates the ERC-4337 rules
     * @param accesses The state diffs to validate
     * @param userOpDetails The UserOperationDetails to validate
     */
    function parseValidation(
        VmSafe.AccountAccess[] memory accesses,
        UserOperationDetails memory userOpDetails
    )
        internal
    {
        // Get entities for the userOp
        Entities memory entities = getEntities(userOpDetails);

        // Validate banned opcodes
        validateBannedOpcodes();

        // Loop over the state diffs
        for (uint256 i; i < accesses.length; i++) {
            VmSafe.AccountAccess memory currentAccess = accesses[i];

            // Ignore test files
            if (currentAccess.account != address(this) && currentAccess.accessor != address(this)) {
                // Validate storage accesses
                validateBannedStorageLocations(currentAccess, entities);

                // Validate disallowed *CALLs
                validateDisallowedCalls(currentAccess, entities);

                // Validate disallowed EXT* opcodes
                validateDisallowedExtOpCodes(currentAccess, entities);

                // Validate disallowed CREATEs
                validateDisallowedCreate(currentAccess, entities);
            }
        }
    }

    /**
     * @dev Validates that no banned opcodes are used
     * @notice This function is not implemented yet, it depends on
     * https://github.com/foundry-rs/foundry/issues/6704
     */
    function validateBannedOpcodes() internal pure {
        // todo
        // forbidden opcodes are GASPRICE, GASLIMIT, DIFFICULTY, TIMESTAMP, BASEFEE, BLOCKHASH,
        // NUMBER, SELFBALANCE, BALANCE, ORIGIN, GAS, CREATE, COINBASE, SELFDESTRUCT
        // Exception: GAS is allowed if followed immediately by one of { CALL, DELEGATECALL,
        // CALLCODE, STATICCALL }]
        // revert InvalidOpcode(currentAccess.account, opcode);
    }

    // todo: [OP-020] Revert on "out of gas" is forbidden as it can "leak" the gas limit or the
    // current call stack depth.

    /**
     * @dev Validates that no banned storage locations are accessed
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
     * @dev Validates that no disallowed *CALLs are made
     * @param currentAccess The current state diff to validate
     * @param entities The entities of the userOp
     */
    function validateDisallowedCalls(
        VmSafe.AccountAccess memory currentAccess,
        Entities memory entities
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
                currentAccess.account.code.length == 0
                    && uint256(uint160(currentAccess.account)) > 0x09
                    && currentAccess.account != entities.account
            ) {
                revert("[OP-041] Cannot *CALL addresses without code");
            }

            bool callerIsAccount = currentAccess.accessor == entities.account;
            bool callerIsFactory = currentAccess.accessor == entities.factory;
            bool calleeIsEntryPoint = currentAccess.account == ENTRYPOINT_ADDR;

            // Check that value is only used from account or factory to EntryPoint
            // Revert otherwise
            if (currentAccess.value > 0) {
                if (!((callerIsAccount || callerIsFactory) && calleeIsEntryPoint)) {
                    revert("[OP-061] Cannot use value except from account or factory to EntryPoint");
                }
            }

            // Allow self calls from EntryPoint
            if (calleeIsEntryPoint && currentAccess.accessor != ENTRYPOINT_ADDR) {
                // Allow only depositTo from factory/account or fallback from account
                // Revert otherwise
                if (
                    (
                        !(
                            (
                                (callerIsAccount || callerIsFactory)
                                    && currentAccess.data.length > 4
                                    && bytes4(currentAccess.data) != bytes4(0xb760faf9)
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
     * @dev Validates that no disallowed EXT* opcodes are used
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
                currentAccess.account.code.length == 0
                    && uint256(uint160(currentAccess.account)) > 0x09
                    && currentAccess.account != entities.account
            ) {
                revert("[OP-041] EXT* opcodes cannot access addresses without code");
            }
        }
    }

    /**
     * @dev Validates that no disallowed CREATE2 opcodes are used
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
            // Note: If the initCode is emptpy, the factory address is address(0)
            // Revert otherwise
            if (entities.factory == address(0) || currentAccess.account != entities.account) {
                revert(
                    "[OP-031] CREATE2 is allowed exactly once in the deployment phase and must deploy code for the sender address"
                );
            }
        }
    }

    /**
     * @dev Returns whether the current storage slot is associated with an entity
     * @param currentSlot The current storage slot
     * @param currentAccessAccount The contract address of the current access
     * @param entities The entities of the UserOperation
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
     * @dev Returns whether the current storage slot matches an entity
     * @param slot The current storage slot
     * @param entities The entities of the UserOperation
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
     * @dev Returns the parent of the current storage slot
     * @param currentAccessAccount The contract address of the current access
     * @param currentSlot The current storage slot
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
            for (uint256 k = 1; k <= 128; k++) {
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
     * @dev Returns the entities of the UserOperation
     * @param userOpDetails The UserOperationDetails to get the entities of
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
            isFactoryStaked: isStaked(factory),
            paymaster: paymaster,
            isPaymasterStaked: isStaked(paymaster),
            aggregator: aggregator,
            isAggregatorStaked: isStaked(aggregator)
        });
    }

    /**
     * @dev Returns whether something is an entity and is staked
     * @param entities The entities of the UserOperation
     * @param toCheck The address to check
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
     * @dev Returns whether the entity is staked
     * @param entity The entity to check
     * @return isEntityStaked Whether the entity is staked
     */
    function isStaked(address entity) internal view returns (bool isEntityStaked) {
        // Get the deposit info for the entity
        IStakeManager.DepositInfo memory deposit =
            IStakeManager(ENTRYPOINT_ADDR).getDepositInfo(entity);

        // Return whether the entity is staked
        isEntityStaked =
            deposit.stake >= MIN_STAKE_VALUE && deposit.unstakeDelaySec >= MIN_UNSTAKE_DELAY;
    }
}
