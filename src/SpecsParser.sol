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
import { getLabel, getMappingKeyAndParentOf } from "./lib/Vm.sol";

// Credit to Dror (@drortirosh) for the implementation approach and an initial prototype
library ERC4337SpecsParser {
    error InvalidStorageLocation(
        address contractAddress,
        string contractLabel,
        bytes32 slot,
        bytes32 previousValue,
        bytes32 newValue,
        bool isWrite
    );
    error InvalidOpcode(address contractAddress, string opcode);

    function parseValidation(
        VmSafe.AccountAccess[] memory accesses,
        PackedUserOperation memory userOp
    )
        internal
    {
        validateBannedOpcodes();
        for (uint256 i; i < accesses.length; i++) {
            VmSafe.AccountAccess memory currentAccess = accesses[i];
            if (currentAccess.account != address(this) && currentAccess.accessor != address(this)) {
                validateBannedStorageLocations(currentAccess, userOp);
                validateDisallowedCalls(currentAccess, userOp);
                validateDisallowedExtOpCodes(currentAccess);
                validateDisallowedCreate(currentAccess, userOp);
            }
        }
    }

    function validateBannedOpcodes() internal pure {
        // todo
        // forbidden opcodes are GASPRICE, GASLIMIT, DIFFICULTY, TIMESTAMP, BASEFEE, BLOCKHASH,
        // NUMBER, SELFBALANCE, BALANCE, ORIGIN, GAS, CREATE, COINBASE, SELFDESTRUCT
        // Exception: GAS is allowed if followed immediately by one of { CALL, DELEGATECALL,
        // CALLCODE, STATICCALL }]
        // revert InvalidOpcode(currentAccess.account, opcode);
    }

    function validateBannedStorageLocations(
        VmSafe.AccountAccess memory currentAccess,
        PackedUserOperation memory userOp
    )
        internal
    {
        for (uint256 j; j < currentAccess.storageAccesses.length; j++) {
            VmSafe.StorageAccess memory currentStorageAccess = currentAccess.storageAccesses[j];
            address currentAccessAccount = currentStorageAccess.account;
            if (currentAccessAccount != userOp.sender && !isStaked(currentAccessAccount)) {
                bytes32 currentSlot = currentStorageAccess.slot;
                if (currentSlot != bytes32(uint256(uint160(address(userOp.sender))))) {
                    (bool found, bytes32 key) = getMappingParent(currentAccessAccount, currentSlot);
                    if (found) {
                        address parentSlotAddress = address(uint160(uint256(key)));
                        if (parentSlotAddress != userOp.sender) {
                            revert InvalidStorageLocation(
                                currentAccessAccount,
                                getLabel(currentAccessAccount),
                                currentSlot,
                                currentStorageAccess.previousValue,
                                currentStorageAccess.newValue,
                                currentStorageAccess.isWrite
                            );
                        }
                    } else {
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
    }

    function validateDisallowedCalls(
        VmSafe.AccountAccess memory currentAccess,
        PackedUserOperation memory userOp
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
            if (
                currentAccess.account.code.length == 0
                    && uint256(uint160(currentAccess.account)) > 0x09
            ) {
                revert("Cannot call addresses without code");
            }

            bool callerIsAccount = currentAccess.accessor == userOp.sender;
            bool calleeIsEntryPoint = currentAccess.account == ENTRYPOINT_ADDR;

            if (currentAccess.value > 0) {
                if (!callerIsAccount || !calleeIsEntryPoint) {
                    revert("Cannot use value except from account to EntryPoint");
                }
            }

            if (calleeIsEntryPoint) {
                if (
                    currentAccess.data.length > 4
                        && bytes4(currentAccess.data) != bytes4(0xb760faf9) // depositTo
                ) {
                    if (currentAccess.accessor != ENTRYPOINT_ADDR) {
                        revert("Cannot call EntryPoint except depositTo");
                    }
                }
            }
        }
    }

    function validateDisallowedExtOpCodes(VmSafe.AccountAccess memory currentAccess)
        internal
        view
    {
        if (
            currentAccess.kind == VmSafe.AccountAccessKind.Extcodesize
                || currentAccess.kind == VmSafe.AccountAccessKind.Extcodehash
                || currentAccess.kind == VmSafe.AccountAccessKind.Extcodecopy
        ) {
            if (
                currentAccess.account.code.length == 0
                    && uint256(uint160(currentAccess.account)) > 0x09
            ) {
                revert("EXT* opcodes cannot access addresses without code");
            }
        }
    }

    function validateDisallowedCreate(
        VmSafe.AccountAccess memory currentAccess,
        PackedUserOperation memory userOp
    )
        internal
        pure
    {
        if (currentAccess.kind == VmSafe.AccountAccessKind.Create) {
            if (userOp.initCode.length == 0 || currentAccess.account != userOp.sender) {
                revert(
                    "Only one CREATE2 opcode is allowed in a user operation, to deploy the account"
                );
            }
        }
    }

    function getMappingParent(
        address currentAccessAccount,
        bytes32 currentSlot
    )
        internal
        returns (bool found, bytes32 key)
    {
        (bool _found, bytes32 _key,) = getMappingKeyAndParentOf(currentAccessAccount, currentSlot);
        if (_found) {
            found = _found;
            key = _key;
        } else {
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

    function isStaked(address entity) internal view returns (bool) {
        IStakeManager.DepositInfo memory deposit =
            IStakeManager(ENTRYPOINT_ADDR).getDepositInfo(entity);
        return deposit.stake > 0;
    }
}
