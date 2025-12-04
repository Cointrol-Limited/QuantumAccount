// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FalconConstants} from "./FalconConstants.sol";

contract FalconHelperFunctions is FalconConstants {
    // Contract includes math functions and conversion functions

    /* 
    * Addition modulo q. Operands must be in the range [0, q-1].
    */
    function add_q(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            r = a + b;
            if (r >= FalconConstants.Q) r -= FalconConstants.Q;
        }
    }

    /*
    * Subtraction modulo q. Operands must be in the range [0, q-1].
    */
    function sub_q(uint256 a, uint256 b) internal pure returns (uint256 r) {
        unchecked {
            // precond: a < Q, b < Q
            r = (a >= b) ? (a - b) : (a + FalconConstants.Q - b);
        }
    }

    /*
    * Division by 2 modulo q. Operand must be in the range [0, q-1].
    */
    function div2_q(uint256 a) internal pure returns (uint256 r) {
        //       require(a < FalconConstants.Q, "Operand must be in the range [0, q-1], div2_q");

        unchecked {
            r = a;
            r += FalconConstants.Q & (0 - (a & 1));
            r >>= 1;
        }
    }

    /*
    * Montgomery multiplication modulo q. If we set R=2^16 mod q, then this function computes: a * b / R mod q.
    * Operands must be in the range [0, q-1].
    */
    function monty_mul(uint256 a, uint256 b) internal pure returns (uint256 r) {
        //       require(a < FalconConstants.Q && b < FalconConstants.Q, "Operands must be in the range [0, q-1] - monty_mul");

        unchecked {
            r = a * b;
            uint256 w = ((r * FalconConstants.Q01) & 0xFFFF) * FalconConstants.Q;
            r = (r + w) >> 16;
            if (r >= FalconConstants.Q) {
                r -= FalconConstants.Q;
            }
        }
    }
}
