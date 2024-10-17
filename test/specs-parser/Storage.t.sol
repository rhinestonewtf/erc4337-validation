// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestBaseUtil } from "test/utils/TestBaseUtil.sol";
import { StorageValidator } from "test/specs-parser/mocks/StorageValidator.sol";
import { ERC4337SpecsParser } from "src/SpecsParser.sol";

contract StorageParserTest is TestBaseUtil {
    StorageValidator internal validator;

    function setUp() public override {
        // Set up base test util
        super.setUp();

        // Setup mock validator
        validator = new StorageValidator();
        vm.label(address(validator), "StorageValidator");
    }

    function testSingleMapping() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(1))));
    }

    function testNestedMapping() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(2))));
    }

    function testNestedMappingStruct() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(3))));
    }

    function singleMapping__RevertWhen__InvalidKey() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(4))));
    }

    function testSingleMapping__RevertWhen__InvalidKey() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.singleMapping__RevertWhen__InvalidKey.selector)
        );
        assertFalse(success);
    }

    function nestedMapping__RevertWhen__InvalidKey() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(5))));
    }

    function testNestedMapping__RevertWhen__InvalidKey() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.nestedMapping__RevertWhen__InvalidKey.selector)
        );
        assertFalse(success);
    }

    function simpleStorage__RevertWhen__InvalidSlot() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(6))));
    }

    function testSimpleStorage__RevertWhen__InvalidSlot() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.simpleStorage__RevertWhen__InvalidSlot.selector)
        );
        assertFalse(success);
    }

    function nestedMapping__RevertWhen__InvalidArgOrder() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(7))));
    }

    function testNestedMapping__RevertWhen__InvalidArgOrder() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.nestedMapping__RevertWhen__InvalidArgOrder.selector)
        );
        assertFalse(success);
    }

    function testStructMapping__With__Offset() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(8))));
    }

    function structMapping__RevertWhen__OutOfBounds() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(9))));
    }

    function testStructMapping__RevertWhen__OutOfBounds() public {
        // vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.structMapping__RevertWhen__OutOfBounds.selector)
        );
        assertFalse(success);
    }

    function testSetDataIntoAccountSlot() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(10))));
    }

    function testReadData() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(11))));
    }

    function testTransientSetDataIntoSlot() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(12))));
    }

    function transientStorage__RevertWhen__InvalidSlot() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(13))));
    }

    function testTransientStorage__RevertWhen__InvalidSlot() public {
        vm.expectRevert(ERC4337SpecsParser.InvalidStorageLocation.selector);
        (bool success,) = address(this).call(
            abi.encodeWithSelector(this.transientStorage__RevertWhen__InvalidSlot.selector)
        );
        assertFalse(success);
    }

    function testTransientReadDataFromSlot() public {
        simulateUserOp(address(validator), abi.encodePacked(bytes32(uint256(14))));
    }
}
