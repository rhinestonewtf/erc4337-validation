// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { TestBaseUtil, UserOperation } from "test/utils/TestBaseUtilV060.sol";
import { MockValidator } from "test/utils/MockValidator.sol";

contract SimulatorTest is TestBaseUtil {
    MockValidator internal validator;

    function setUp() public override {
        // Set up base test util
        super.setUp();

        // Set up validator
        validator = new MockValidator();
    }

    function testSimulate() public {
        // Set up userOp
        UserOperation memory userOp = getDefaultUserOp();
        (address account, bytes memory initCode) = getAccountAndInitCode(0);
        userOp.initCode = initCode;
        userOp.sender = account;
        userOp.signature = abi.encode(address(validator), bytes(""));

        // Simulate
        simulateUserOp(userOp);
    }
}
