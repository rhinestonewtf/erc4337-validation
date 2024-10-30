// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { PackedUserOperation, UserOperation } from "src/lib/ERC4337.sol";

contract TargetValidator {
    function _validateUserOp(bytes calldata signature) internal {
        (address target, bytes memory data) = abi.decode(signature, (address, bytes));
        target.call(data);
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256)
    {
        _validateUserOp(userOp.signature);
        return 0;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        returns (uint256)
    {
        _validateUserOp(userOp.signature);
        return 0;
    }
}
