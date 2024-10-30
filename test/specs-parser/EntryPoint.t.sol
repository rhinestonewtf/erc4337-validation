// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TestBaseUtil } from "test/utils/TestBaseUtil.sol";
import { TargetValidator } from "test/specs-parser/mocks/TargetValidator.sol";
import { MockTargetAccount } from "test/utils/MockTargetAccount.sol";
import { MockAccount } from "test/utils/MockAccount.sol";
import { MockFactory } from "test/utils/MockFactory.sol";

contract EntryPointTest is TestBaseUtil {
    TargetValidator internal validator;

    function setUp() public override {
        // Set up base test util
        super.setUp();

        // Setup mock validator
        validator = new TargetValidator();
        vm.label(address(validator), "TargetValidator");

        implementation = MockAccount(address(new MockTargetAccount()));
        vm.label(address(implementation), "MockTargetAccount");

        factory = new MockFactory(address(implementation));
    }

    function testEntryPointDepositTo() public {
        simulateUserOp(address(entrypoint), hex"b760faf9");
    }

    function testEntryPointFallback() public {
        simulateUserOp(address(entrypoint), "");
    }

    function entryPoint__RevertWhen__DisallowedFunction() public {
        simulateUserOp(address(entrypoint), hex"22cdde4c");
    }

    function testEntryPoint__RevertWhen__DisallowedFunction() public {
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.entryPoint__RevertWhen__DisallowedFunction.selector)
        );
        assertFalse(success);
    }
}
