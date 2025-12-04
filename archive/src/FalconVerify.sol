// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FalconConstants} from "./FalconConstants.sol";
import {FalconHelperFunctions} from "./FalconHelperFunctions.sol";
import {Test, console2 as console} from "forge-std/Test.sol";

contract FalconVerify is FalconConstants, FalconHelperFunctions {
    /*
    * Compute NTT on a ring element
    */
    function NTT(uint16[1024] memory a) private view returns (uint16[1024] memory) {
        uint16 n = uint16(1 << FalconConstants.LOGN);
        uint16 t = n;
        for (uint16 m = 0; m < FalconConstants.LOGN; m++) {
            uint16 corr_m = uint16(1 << m);
            uint16 ht = t >> 1;
            uint16 j1 = 0;
            for (uint16 i = 0; i < corr_m; i++) {
                uint32 s = FalconConstants.GMb[corr_m + i];
                uint16 j2 = j1 + ht;
                for (uint16 j = j1; j < j2; j++) {
                    uint32 u = a[j];
                    uint32 v = monty_mul(uint32(a[j + ht]), s);
                    a[j] = uint16(add_q(u, v));
                    a[j + ht] = uint16(sub_q(u, v));
                }
                j1 += t;
            }
            t = ht;
        }
        return a;
    }

    function toMoNTTy(uint16[1024] memory a) external view returns (uint16[1024] memory) {
        uint16[1024] memory b = poly_to_monty(a);
        return NTT(b);
    }

    /*
    * Compute inverse NTT on a ring element, binary case
    */
    function iNTT(uint16[1024] memory a) private view returns (uint16[1024] memory) {
        uint16 n = uint16(1 << FalconConstants.LOGN);
        uint16 m = n;
        uint16 t = 1;
        while (m > 1) {
            uint16 hm = m >> 1;
            uint16 dt = t << 1;
            uint16 j1 = 0;
            for (uint16 i = 0; i < hm; i++) {
                uint32 s = FalconConstants.iGMb[hm + i];
                uint16 j2 = j1 + t;
                for (uint16 j = j1; j < j2; j++) {
                    uint32 u = a[j];
                    uint32 v = a[j + t];
                    a[j] = uint16(add_q(u, v));
                    uint32 w = sub_q(u, v);
                    a[j + t] = uint16(monty_mul(w, s));
                }
                j1 += dt;
            }
            t = dt;
            m = hm;
        }

        /*
    	 * To complete the inverse NTT, we must now divide all values by
      * n (the vector size). We thus need the inverse of n, i.e. we
    	 * need to divide 1 by 2 logn times. But we also want it in
      * Montgomery representation, i.e. we also want to multiply it
    	 * by R = 2^16. In the common case, this should be a simple right
      * shift. The loop below is generic and works also in corner cases;
    	 * its computation time is negligible.
      */

        uint32 ni = uint32(FalconConstants.R);
        for (uint16 mi = n; mi > 1; mi >>= 1) {
            ni = uint16(div2_q(ni));
        }
        for (uint16 i = 0; i < n; i++) {
            a[i] = uint16(monty_mul(uint32(a[i]), ni)); // 12277 is 1/n in montgomery form for n=1024
        }
        // Return the transformed array

        return a;
    }

    function fromMoNTTy(uint16[1024] memory a) external view returns (uint16[1024] memory) {
        uint16[1024] memory b = iNTT(a);
        for (uint16 i = 0; i < FalconConstants.N; i++) {
            b[i] = uint16(monty_mul(uint32(b[i]), 1));
        }
        return b;
    }

    /*
    * Convert a polynomial (mod q) to Montgomery representation.
    */
    function poly_to_monty(uint16[1024] memory a) private pure returns (uint16[1024] memory) {
        uint16 n = uint16(1) << uint16(FalconConstants.LOGN);
        for (uint16 i = 0; i < n; i++) {
            a[i] = uint16(monty_mul(uint32(a[i]), uint32(FalconConstants.R2)));
        }
        return a;
    }

    /*
    * Multiply two polynomials together (NTT representation, and using a Montgomery multiplication).
    * Result a*b is written over a
    */
    function poly_montymul_ntt(uint16[1024] memory a, uint16[1024] memory b)
        private
        pure
        returns (uint16[1024] memory)
    {
        uint16 n = uint16(1) << uint16(FalconConstants.LOGN);
        for (uint16 i = 0; i < n; i++) {
            a[i] = uint16(monty_mul(uint32(a[i]), uint32(b[i])));
        }
        return a;
    }

    /*
    * Subtrace polynomial b from polynomial a
    */
    function poly_sub(uint16[1024] memory a, uint16[1024] memory b) private pure returns (uint16[1024] memory) {
        uint16 n = uint16(1) << uint16(FalconConstants.LOGN);
        for (uint16 i = 0; i < n; i++) {
            a[i] = uint16(sub_q(uint32(a[i]), uint32(b[i])));
        }
        return a;
    }

    /*
    *  Convert int16 (-q/2...+q/2) to uint16 (0..q-1)
    */
    function int16_to_uint16(int16[1024] memory a) private pure returns (uint16[1024] memory) {
        uint16 n = uint16(FalconConstants.N);
        uint16[1024] memory r;
        for (uint16 i = 0; i < n; i++) {
            if (a[i] < 0) {
                a[i] += int16(FalconConstants.Q);
            }
            r[i] = uint16(a[i]);
        }
        return r;
    }
    /*
    *  Convert uint16 (0..q-1) to int16 (-q/2...+q/2) 
    */

    function uint16_to_int16(uint16[1024] memory a) private pure returns (int16[1024] memory) {
        uint16 n = uint16(FalconConstants.N);
        int16[1024] memory r;
        for (uint16 i = 0; i < n; i++) {
            if (a[i] > (uint16(FalconConstants.Q) / 2)) {
                r[i] = int16(a[i]) - int16(FalconConstants.Q);
            } else {
                r[i] = int16(a[i]);
            }
        }
        return r;
    }


    /*
     * Internal signature verification code:
     *   c0[]      contains the hashed nonce+message
     *   s2[]      is the decoded signature
     *   h[]       contains the public key, in NTT + Montgomery format
     * Returned value is 1 on success, 0 on error.
     *
     * tmp[] must have 16-bit alignment.
     */
    function fetch_signature_raw(uint16[1024] memory c0, int16[1024] memory s2, uint16[1024] memory h)
        internal
        view
        returns (int16[1024] memory)
    {
        /*
        * Reduce s2 elements modulo q.
        */
        uint16[1024] memory tmp = int16_to_uint16(s2);
        /*
        * Compute -s1 = s2*h - c0 mod phi mod q (in tmp[])
        */
        tmp = poly_to_monty(tmp);
        tmp = NTT(tmp);
        tmp = poly_montymul_ntt(tmp, h);
        tmp = iNTT(tmp);
        // Convert out of montgomery form
        for (uint16 i = 0; i < FalconConstants.N; i++) {
            tmp[i] = uint16(monty_mul(uint32(tmp[i]), 1));
        }
        tmp = poly_sub(c0, tmp);
        /*
        * Normalize -s1 elements into the [-q/2 .. q/2] range.
        */
        int16[1024] memory itmp = uint16_to_int16(tmp);
        return itmp;
    }

    function fetch_signature(uint16[1024] memory c0, int16[1024] memory s2, uint16[1024] memory h)
        external
        view
        returns (int16[1024] memory)
    {
        return fetch_signature_raw(c0, s2, h);
    }

    function _is_short(int16[1024] memory s1, int16[1024] memory s2) external view returns (bool) {
        /* 
        * Uses the l2-norm.  Code below uses only 32-bit operations to compute the square
        * of the norm with saturation to 2^32-1 if the value exceed 2^31-1.
        */
        return (is_short(s1, s2));
    }
}
