// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestBaseUtil } from "test/utils/TestBaseUtil.sol";
import { ERC4337SpecsParser } from "src/SpecsParser.sol";
import { OpcodeValidator } from "test/specs-parser/mocks/OpcodeValidator.sol";

contract OpcodeParserTest is TestBaseUtil {
    OpcodeValidator internal validator;

    function setUp() public override {
        super.setUp();
        validator = new OpcodeValidator();
        vm.label(address(validator), "OpcodeValidator");
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function testValidOpcodes() public {
        _runOpcodeTest(0x00, false); // Valid opcodes (using 0x00 as a placeholder for valid
            // opcodes)
    }

    function testValidGAS__WhenFollowedByCALL() public {
        _runOpcodeTest(0xF1, false); // CALL
    }

    function testValidGAS__WhenFollowedByDELEGATECALL() public {
        _runOpcodeTest(0xF4, false); // DELEGATECALL
    }

    function testValidGAS__WhenFollowedByCALLCODE() public {
        _runOpcodeTest(0xF2, false); // CALLCODE
    }

    function testValidGAS__WhenFollowedBySTATICCALL() public {
        _runOpcodeTest(0xFA, false); // STATICCALL
    }

    function testBannedOpcode__RevertWhen__UsingGASPRICE() public {
        _runOpcodeTest(0x3A, true); // GASPRICE
    }

    function testBannedOpcode__RevertWhen__UsingGASLIMIT() public {
        _runOpcodeTest(0x45, true); // GASLIMIT
    }

    function testBannedOpcode__RevertWhen__UsingDIFFICULTY() public {
        _runOpcodeTest(0x44, true); // DIFFICULTY
    }

    function testBannedOpcode__RevertWhen__UsingTIMESTAMP() public {
        _runOpcodeTest(0x42, true); // TIMESTAMP
    }

    function testBannedOpcode__RevertWhen__UsingBASEFEE() public {
        _runOpcodeTest(0x48, true); // BASEFEE
    }

    function testBannedOpcode__RevertWhen__UsingBLOCKHASH() public {
        _runOpcodeTest(0x40, true); // BLOCKHASH
    }

    function testBannedOpcode__RevertWhen__UsingNUMBER() public {
        _runOpcodeTest(0x43, true); // NUMBER
    }

    function testBannedOpcode__RevertWhen__UsingSELFBALANCE() public {
        _runOpcodeTest(0x47, true); // SELFBALANCE
    }

    function testBannedOpcode__RevertWhen__UsingBALANCE() public {
        _runOpcodeTest(0x31, true); // BALANCE
    }

    function testBannedOpcode__RevertWhen__UsingORIGIN() public {
        _runOpcodeTest(0x32, true); // ORIGIN
    }

    function testBannedOpcode__RevertWhen__UsingGAS() public {
        _runOpcodeTest(0x5A, true); // GAS
    }

    function testBannedOpcode__RevertWhen__UsingCREATE() public {
        _runOpcodeTest(0xF0, true); // CREATE
    }

    function testBannedOpcode__RevertWhen__UsingCOINBASE() public {
        _runOpcodeTest(0x41, true); // COINBASE
    }

    function testOutOfGas__RevertWhen__RunningOutOfGas() public {
        _runOpcodeTest(0xFF, true); // SELFDESTRUCT (used for out of gas scenario)
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _runOpcodeTest(uint256 opcode, bool shouldRevert) internal {
        if (shouldRevert) {
            (bool success,) =
                address(this).call(abi.encodeWithSelector(this.runSimulation.selector, opcode));
            assertFalse(success);
        } else {
            (bool success,) =
                address(this).call(abi.encodeWithSelector(this.runSimulation.selector, opcode));
            assertTrue(success);
        }
    }

    function runSimulation(uint256 opcode) public {
        simulateUserOp(address(validator), abi.encode(opcode));
    }
}
