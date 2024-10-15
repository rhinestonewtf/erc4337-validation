// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import { MockAccount } from "./MockAccount.sol";
import { MockFactory } from "./MockFactory.sol";
import {
    PackedUserOperation, ENTRYPOINT_ADDR, IEntryPoint, etchEntrypoint
} from "src/lib/ERC4337.sol";
import { Simulator } from "src/Simulator.sol";

contract TestBaseUtil is Test {
    // singletons
    MockAccount implementation;
    MockFactory factory;
    IEntryPoint entrypoint = IEntryPoint(ENTRYPOINT_ADDR);

    function setUp() public virtual {
        // Set up EntryPoint
        etchEntrypoint();

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

    function getDefaultUserOp() internal returns (PackedUserOperation memory userOp) {
        userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: bytes(""),
            signature: ""
        });
    }

    function getFormattedUserOp(
        address validator,
        bytes memory signature
    )
        internal
        returns (PackedUserOperation memory userOp)
    {
        userOp = getDefaultUserOp();
        (address account, bytes memory initCode) = getAccountAndInitCode(keccak256("account1"));
        userOp.sender = account;
        userOp.initCode = initCode;
        userOp.nonce = 0;
        userOp.signature = abi.encode(validator, signature);
    }

    function simulateUserOp(PackedUserOperation memory userOp) internal {
        // Simulate userOperation
        Simulator.simulateUserOp(userOp, ENTRYPOINT_ADDR);
    }

    function simulateUserOp(address validator, bytes memory signature) internal {
        PackedUserOperation memory userOp = getFormattedUserOp(validator, signature);
        // Simulate userOperation
        Simulator.simulateUserOp(userOp, ENTRYPOINT_ADDR);
    }
}
