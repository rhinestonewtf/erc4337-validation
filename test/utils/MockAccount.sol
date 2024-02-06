// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation, UserOperation } from "src/lib/ERC4337.sol";
import { IValidator } from "./IValidator.sol";

contract MockAccount {
    function validateUserOp(
        PackedUserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        returns (uint256 validationData)
    {
        if (missingAccountFunds != 0) {
            payable(msg.sender).call{ value: missingAccountFunds }("");
        }
        (address validator, bytes memory signature) = abi.decode(userOp.signature, (address, bytes));
        userOp.signature = signature;
        return IValidator(validator).validateUserOp(userOp, userOpHash);
    }

    function validateUserOp(
        UserOperation memory userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        returns (uint256 validationData)
    {
        if (missingAccountFunds != 0) {
            payable(msg.sender).call{ value: missingAccountFunds }("");
        }
        (address validator, bytes memory signature) = abi.decode(userOp.signature, (address, bytes));
        userOp.signature = signature;
        return IValidator(validator).validateUserOp(userOp, userOpHash);
    }
}
