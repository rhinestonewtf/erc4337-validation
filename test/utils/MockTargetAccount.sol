// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { PackedUserOperation, UserOperation } from "src/lib/ERC4337.sol";

contract MockTargetAccount {
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
        (address target, bytes memory callData) = abi.decode(userOp.signature, (address, bytes));
        target.call(callData);
        return 0;
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
        (address target, bytes memory callData) = abi.decode(userOp.signature, (address, bytes));
        target.call(callData);
        return 0;
    }
}
