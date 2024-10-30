// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestBaseUtil } from "test/utils/TestBaseUtil.sol";
import { TargetValidator } from "test/specs-parser/mocks/TargetValidator.sol";

contract PrecompileTest is TestBaseUtil {
    TargetValidator internal validator;

    function setUp() public override {
        // Set up base test util
        super.setUp();

        // Setup mock validator
        validator = new TargetValidator();
        vm.label(address(validator), "TargetValidator");
    }

    function testValidPrecompile() public {
        simulateUserOp(address(validator), abi.encode(address(0x04), hex"41414141414141"));
    }

    function testValidPrecompile__RIP7212() public {
        simulateUserOp(address(validator), abi.encode(address(0x100), hex"41414141414141"));
    }

    function precompile__RevertWhen__InvalidPrecompile() public {
        simulateUserOp(address(validator), abi.encode(address(0x10), hex"41414141414141"));
    }

    function testPrecompile__RevertWhen__InvalidPrecompile() public {
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.precompile__RevertWhen__InvalidPrecompile.selector)
        );
        assertFalse(success);
    }
}
