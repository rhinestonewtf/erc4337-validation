// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation, UserOperation } from "src/lib/ERC4337.sol";
import { IValidator } from "test/utils/IValidator.sol";

contract StorageValidator {
    struct DataStruct {
        uint256 data1;
        uint256 data2;
    }

    uint256 data;
    mapping(address => uint256) singleData;
    mapping(uint256 => mapping(address => uint256)) nestedData;
    mapping(address => mapping(uint256 => uint256)) nestedDataReverse;
    mapping(uint256 => mapping(address => DataStruct)) nestedDataStruct;

    function setData(uint256 value) public {
        data = value;
    }

    function setDataIntoSlot(address addr, uint256 value) public {
        assembly {
            sstore(addr, value)
        }
    }

    function setData(address addr, uint256 value) public {
        singleData[addr] = value;
    }

    function setNestedData(address addr, uint256 value) public {
        nestedData[value][addr] = value;
    }

    function setNestedDataReverse(address addr, uint256 value) public {
        nestedDataReverse[addr][value] = value;
    }

    function setNestedDataStruct(address addr, uint256 value) public {
        nestedDataStruct[value][addr] = DataStruct({ data1: value, data2: value });
    }

    function setNestedDataWithOffset(address addr, uint256 value, uint256 offset) public {
        bytes32 slot;
        assembly {
            slot := singleData.slot
        }
        bytes32 _slot = keccak256(abi.encode(addr, slot));
        bytes32 offsetSlot = bytes32(uint256(_slot) + offset);
        assembly {
            sstore(offsetSlot, value)
        }
    }

    function _validateUserOp(bytes calldata signature) internal {
        uint256 mode = uint256(bytes32(signature[0:32]));
        if (mode == 1) {
            setData(msg.sender, 1);
        } else if (mode == 2) {
            setNestedData(msg.sender, 2);
        } else if (mode == 3) {
            setNestedDataStruct(msg.sender, 3);
        } else if (mode == 4) {
            setData(address(1), 4);
        } else if (mode == 5) {
            setNestedData(address(1), 5);
        } else if (mode == 6) {
            setData(6);
        } else if (mode == 7) {
            setNestedDataReverse(address(1), 7);
        } else if (mode == 8) {
            setNestedDataWithOffset(msg.sender, 8, 128);
        } else if (mode == 9) {
            setNestedDataWithOffset(msg.sender, 9, 129);
        } else if (mode == 10) {
            setDataIntoSlot(msg.sender, 10);
        }
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
