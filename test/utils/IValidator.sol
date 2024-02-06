// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation, UserOperation } from "src/lib/ERC4337.sol";

interface IValidator {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256);

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256);
}
