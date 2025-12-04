// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FalconConstants} from "./FalconConstants.sol";

contract FalconHelperFunctions is FalconConstants {
    // Contract includes math functions and conversion functions

    /* 
    * Addition modulo q. Operands must be in the range [0, q-1].
    */
    function add_q(uint32 a, uint32 b) internal pure returns (uint32) {
        require(a < FalconConstants.Q && b < FalconConstants.Q, "Operands must be in the range [0, q-1] - add_q");
        uint32 d;
        unchecked {
            d = a + b - FalconConstants.Q;
            d += FalconConstants.Q & (0 - (d >> 31));
        }
        return d;
    }

    /*
    * Subtraction modulo q. Operands must be in the range [0, q-1].
    */
    function sub_q(uint32 a, uint32 b) internal pure returns (uint32) {
        require(a < FalconConstants.Q && b < FalconConstants.Q, "Operands must be in the range [0, q-1] - Sub_q");
        uint32 d;
        unchecked {
            d = a - b;
            d += FalconConstants.Q & (0 - (d >> 31));
        }
        return d;
    }

    /*
    * Division by 2 modulo q. Operand must be in the range [0, q-1].
    */
    function div2_q(uint32 a) internal pure returns (uint32) {
        require(a < FalconConstants.Q, "Operand must be in the range [0, q-1], div2_q");
        uint32 d = a;
        unchecked {
            d += FalconConstants.Q & (0 - (a & 1));
            d >>= 1;
        }
        return d;
    }

    /*
    * Montgomery multiplication modulo q. If we set R=2^16 mod q, then this function computes: a * b / R mod q.
    * Operands must be in the range [0, q-1].
    */
    function monty_mul(uint32 a, uint32 b) internal pure returns (uint32) {
        require(a < FalconConstants.Q && b < FalconConstants.Q, "Operands must be in the range [0, q-1] - monty_mul");
        uint32 temp = (a * b);
        unchecked {
            uint32 w = ((temp * uint32(FalconConstants.Q01)) & 0xFFFF) * uint32(FalconConstants.Q);
            temp = (temp + w) >> 16;
            if (temp >= FalconConstants.Q) {
                temp -= FalconConstants.Q;
            }
        }
        return temp;
    }

    /* 
    * Tell whether a given vector (2N coordintaes, in two halves) is acceptable as a signature.
    * This compares the appropirate norm of the vector with the acceptance bound.
    * Returned value is 1 on success (vector is short enough to be acceptable), 0 otherwise.
    */
    function is_short(int16[1024] memory s1, int16[1024] memory s2) internal view returns (bool) {
        /* 
        * Uses the l2-norm.  Code below uses only 32-bit operations to compute the square
        * of the norm with saturation to 2^32-1 if the value exceed 2^31-1.
        */
        uint32 n = uint32(1) << uint32(FalconConstants.LOGN);
        uint32 ng = 0;
        unchecked {
            for (uint32 i = 0; i < n; i++) {
                ng += uint32(int32(s1[i]) * int32(s1[i]));
                ng += uint32(int32(s2[i]) * int32(s2[i]));
            }
        }
        return (ng <= FalconConstants.l2bound[FalconConstants.LOGN]);
    }
}
