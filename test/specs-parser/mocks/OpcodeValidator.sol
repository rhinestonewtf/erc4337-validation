// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation, UserOperation } from "src/lib/ERC4337.sol";
import { IValidator } from "test/utils/IValidator.sol";

contract OpcodeValidator is IValidator {
    // To make the optimizer actually use our opcodes
    event Log(uint256 value);

    function mockFunction() public pure returns (uint256) {
        return 0;
    }

    function _validateUserOp(bytes calldata signature) internal {
        uint256 opcode = abi.decode(signature, (uint256));
        if (opcode == 0x00) {
            // Valid opcodes, do nothing
            assembly {
                pop(0)
            }
        } else if (opcode == 0x3A) {
            // Gasprice
            assembly {
                let _gasPrice := gasprice()
                log0(0, _gasPrice)
            }
        } else if (opcode == 0x45) {
            // Gaslimit
            uint256 limit;
            assembly {
                limit := gaslimit()
            }
            emit Log(limit);
        } else if (opcode == 0x44) {
            // Difficulty
            assembly {
                let _difficulty := prevrandao()
                log0(0, _difficulty)
            }
        } else if (opcode == 0x42) {
            // Timestamp
            assembly {
                let _timestamp := timestamp()
                log0(0, _timestamp)
            }
        } else if (opcode == 0x48) {
            // Basefee
            assembly {
                let _basefee := basefee()
                log0(0, _basefee)
            }
        } else if (opcode == 0x40) {
            uint256 _blockhash;
            // Blockhash
            assembly {
                _blockhash := blockhash(0)
            }
            emit Log(_blockhash);
        } else if (opcode == 0x43) {
            // Number
            assembly {
                let _number := number()
                log0(0, _number)
            }
        } else if (opcode == 0x47) {
            // Selfbalance
            assembly {
                let _balance := selfbalance()
                log0(0, _balance)
            }
        } else if (opcode == 0x31) {
            // Balance
            assembly {
                let _balance := balance(0xdead)
                log0(0, _balance)
            }
        } else if (opcode == 0x32) {
            // Origin
            address origin = tx.origin;
            emit Log(uint256(uint160(origin)));
        } else if (opcode == 0x5A) {
            // Gas
            uint256 _gasleft;
            assembly {
                _gasleft := gas()
            }
            emit Log(_gasleft);
        } else if (opcode == 0xF0) {
            // Create
            assembly {
                pop(create(0, 0, 0))
            }
        } else if (opcode == 0x41) {
            // Coinbase
            assembly {
                let _coinbase := coinbase()
                log0(0, _coinbase)
            }
        } else if (opcode == 0xF1) {
            // CALL
            assembly {
                let g := gas()
                pop(call(g, 0x0000000000000000000000000000000000000000, 0, 0, 0, 0, 0))
            }
        } else if (opcode == 0xF4) {
            // DELEGATECALL
            assembly {
                let g := gas()
                pop(delegatecall(g, 0x0000000000000000000000000000000000000000, 0, 0, 0, 0))
            }
        } else if (opcode == 0xF2) {
            // CALLCODE
            assembly {
                let g := gas()
                pop(callcode(g, 0x0000000000000000000000000000000000000000, 0, 0, 0, 0, 0))
            }
        } else if (opcode == 0xFA) {
            // STATICCALL
            assembly {
                let g := gas()
                pop(staticcall(gas(), 0x0000000000000000000000000000000000000000, 0, 0, 0, 0))
            }
        } else if (opcode == 0xFF) {
            // Out of gas
            uint256 gasLimit = 10;
            address(this).call{ gas: gasLimit }(abi.encodeWithSignature("mockFunction()"));
        }
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
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
        override
        returns (uint256)
    {
        _validateUserOp(userOp.signature);
        return 0;
    }
}
