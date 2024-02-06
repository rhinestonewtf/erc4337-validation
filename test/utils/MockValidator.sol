// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation } from "src/lib/ERC4337.sol";
import { IValidator } from "test/utils/IValidator.sol";

contract MockValidator {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256)
    {
        return 0;
    }
}
