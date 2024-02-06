// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { MockAccount } from "./MockAccount.sol";
import { MockFactory } from "./MockFactory.sol";
import {
    UserOperation,
    ENTRYPOINT_ADDR,
    IEntryPointV060,
    etchEntrypointV060
} from "src/lib/ERC4337.sol";
import { Simulator } from "src/Simulator.sol";

contract TestBaseUtil is Test {
    // singletons
    MockAccount implementation;
    MockFactory factory;
    IEntryPointV060 entrypoint = IEntryPointV060(ENTRYPOINT_ADDR);

    function setUp() public virtual {
        // Set up EntryPoint
        etchEntrypointV060();

        // Set up Account and Factory
        implementation = new MockAccount();
        factory = new MockFactory(address(implementation));
    }

    function getAccountAndInitCode(bytes32 salt)
        internal
        returns (address account, bytes memory initCode)
    {
        // Get address of new account
        account = factory.getAddress(salt);

        // Pack the initcode to include in the userOp
        initCode = abi.encodePacked(
            address(factory), abi.encodeWithSelector(factory.createAccount.selector, salt)
        );

        // Deal 1 ether to the account
        vm.deal(account, 1 ether);
    }

    function getDefaultUserOp() internal returns (UserOperation memory userOp) {
        userOp = UserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            callGasLimit: 2e6,
            verificationGasLimit: 2e6,
            preVerificationGas: 2e6,
            maxFeePerGas: 1,
            maxPriorityFeePerGas: 1,
            paymasterAndData: bytes(""),
            signature: ""
        });
    }

    function getFormattedUserOp(
        address validator,
        bytes memory signature
    )
        internal
        returns (UserOperation memory userOp)
    {
        userOp = getDefaultUserOp();
        (address account, bytes memory initCode) = getAccountAndInitCode(keccak256("account1"));
        userOp.sender = account;
        userOp.initCode = initCode;
        userOp.nonce = 0;
        userOp.signature = abi.encode(validator, signature);
    }

    function simulateUserOp(UserOperation memory userOp) internal {
        // Simulate userOperation
        Simulator.simulateUserOp(userOp, ENTRYPOINT_ADDR);
    }

    function simulateUserOp(address validator, bytes memory signature) internal {
        UserOperation memory userOp = getFormattedUserOp(validator, signature);
        // Simulate userOperation
        Simulator.simulateUserOp(userOp, ENTRYPOINT_ADDR);
    }
}
