// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {FalconConstants} from "./FalconConstants.sol";
import {FalconHelperFunctions} from "./FalconHelperFunctions.sol";

contract Falcon is FalconConstants, FalconHelperFunctions {
    uint256 internal constant NONCE_LEN = 40;
    uint256 internal constant SIG_BYTES = 1280;
    uint256 internal constant SBYTES = SIG_BYTES - 1 - NONCE_LEN;
    uint256 internal constant REJ = 61445; // reject threshold (5*q)
    //uint internal constant OVER_CT = 287; // oversampling for "constant-time" path
    uint256 internal constant CT_BYTES = 2622; //(uint256(N) + OVER_CT) * 2; // 2622 bytes
    uint256 internal constant n = 1024;

    // === Little helpers ===

    /// @dev Read a 16-bit big-endian word at offset `off` from `src`.
    function _readU16BE(bytes memory src, uint256 off) private pure returns (uint256 v) {
        v = (uint256(uint8(src[off])) << 8) | uint256(uint8(src[off + 1]));
    }

    // === Keccak-256 "XOF": expand to `outLen` bytes with counter-mode ===

    /**
     * @dev Expand into `outLen` bytes using: keccak256( domain || nonce || message || uint32(counter) )
     * @param domain  Domain separation tag (e.g., "ETHEREUM MAINNET", "POLYGON AMOY", etc.)
     * @param nonce   40 bytes is common in Falcon signatures, but any size is accepted here
     * @param message Arbitrary message bytes
     */
    function _keccakExpand(bytes memory domain, bytes memory nonce, bytes32 message)
        private
        pure
        returns (bytes memory out)
    {
        out = new bytes(CT_BYTES);

        // Precompute the common prefix to avoid repeated concatenation costs
        // prefix = domain || nonce || message
        bytes memory prefix = abi.encodePacked(domain, nonce, message);

        uint256 fullBlocks = 81; //CT_BYTES / 32
        uint256 tail = 30; //CT_BYTES % 32;

        // Write 32-byte blocks
        for (uint256 ctr = 0; ctr < fullBlocks; ctr++) {
            bytes32 h = keccak256(abi.encodePacked(prefix, uint32(ctr)));
            // store directly
            assembly {
                // data pointer of `out` is at out + 0x20
                let ptr := add(add(out, 0x20), mul(ctr, 32))
                mstore(ptr, h)
            }
        }

        // Tail (partial) block
        if (tail != 0) {
            bytes32 hLast = keccak256(abi.encodePacked(prefix, uint32(fullBlocks)));
            // Copy `tail` bytes of hLast into out
            // (Write byte-by-byte to avoid overruns.)
            for (uint256 i = 0; i < tail; i++) {
                out[fullBlocks * 32 + i] = hLast[i];
            }
        }
    }

    function verifySignature(bytes calldata signature, bytes32 messageHash, bytes memory domain, uint16[1024] memory h)
        external
        view
        returns (bool)
    {
        uint256 isShort = 0;
        bytes memory nonce = new bytes(NONCE_LEN);
        uint256[1024] memory s;
        // 1. Get nonce and s0 from signature and start to calculate isShort
        //    Also do monty multiplication of s0 and public key (h)
        {
            unchecked {
                for (uint256 i = 0; i < n; i++) {
                    s[i] = uint8(signature[40 + (2 * i)]) * 256 + uint8(signature[41 + (2 * i)]);
                    if (i < 40) {
                        nonce[i] = signature[i];
                    }
                    if (s[i] > (FalconConstants.Q / 2)) {
                        isShort += (FalconConstants.Q - s[i]) ** 2;
                    } else {
                        isShort += s[i] ** 2;
                    }
                    s[i] = monty_mul(s[i], FalconConstants.R2); // convert to monty
                }
            }
        }

        // convert s to NTT domain
        {
            unchecked {
                uint256 t = n;
                for (uint256 m = 0; m < FalconConstants.LOGN; m++) {
                    uint256 corr_m = 1 << m;
                    uint256 ht = t >> 1;
                    uint256 j1 = 0;
                    for (uint256 i = 0; i < corr_m; i++) {
                        uint256 snum = FalconConstants.GMb[corr_m + i];
                        uint256 j2 = j1 + ht;
                        for (uint256 j = j1; j < j2; j++) {
                            uint256 u = s[j];
                            uint256 v = monty_mul(s[j + ht], snum);
                            s[j] = add_q(u, v);
                            s[j + ht] = sub_q(u, v);
                        }
                        j1 += t;
                    }
                    t = ht;
                }
            }
        }

        // monty multiplication of s and h
        unchecked {
            for (uint256 i = 0; i < n; i++) {
                s[i] = monty_mul(s[i], h[i]);
            }
        }

        // 2. Convert s0h product to polynomial in normal domain

        {
            unchecked {
                uint256 m2 = n;
                uint256 t2 = 1;
                while (m2 > 1) {
                    uint256 hm = m2 >> 1;
                    uint256 dt = t2 << 1;
                    uint256 j1 = 0;
                    for (uint256 i = 0; i < hm; i++) {
                        uint256 s3 = FalconConstants.iGMb[hm + i];
                        uint256 j2 = j1 + t2;
                        for (uint256 j = j1; j < j2; j++) {
                            uint256 u = s[j];
                            uint256 v = s[j + t2];
                            s[j] = add_q(u, v);
                            uint256 w = sub_q(u, v);
                            s[j + t2] = monty_mul(w, s3);
                        }
                        j1 += dt;
                    }
                    t2 = dt;
                    m2 = hm;
                }
            }
        }

        // 3. Get message array from domain, nonce, and messageHash and subtract from previous result
        //    calculate the other half of isShort

        // Expand exactly the needed bytes for (N + OVER_CT) 16-bit words
        bool isShortEnough;
        {
            bytes memory stream = _keccakExpand(domain, nonce, messageHash);

            uint256 outIdx = 0;
            // Scan all words; keep the first N valid ones
            unchecked {
                for (uint256 off = 0; off < CT_BYTES; off += 2) {
                    uint256 w = _readU16BE(stream, off);
                    if (w < REJ && outIdx < n) {
                        w %= FalconConstants.Q;
                        uint256 checkx = sub_q(w, monty_mul(monty_mul(uint32(s[outIdx]), 64), 1)); // monty multiply by 64 (last step of iNTT) then return to normal domain)
                        if (checkx > Q / 2) {
                            isShort += (FalconConstants.Q - checkx) * (FalconConstants.Q - checkx);
                        } else {
                            isShort += checkx * checkx;
                        }
                        outIdx++;
                        //if (outIdx == N) {
                        // We *still* run through the full loop for constant work,
                        // but ignore additional valid words (no writes).
                        // (Leaving the `if` here has no effect on total loop count.)
                        //}
                    }
                }
            }
            require(outIdx >= N, "H2P: not enough valid samples");

            // 4. Check if isShort is less than l2bound from constants
            isShortEnough = (isShort < FalconConstants.l2bound);
        }
        return isShortEnough;
    }

    function loadPublicKey(bytes memory publicKey) external view returns (uint16[1024] memory h) {
        uint256 t = n;
        // 1. Convert bytes to an array of 1024 uint16 values in [0..Q-1]
        // If your blob includes the 1-byte Falcon header, skip it.
        {
            uint256 PACKED_LEN = 1792;
            uint256 start = (publicKey.length == 1793) ? 1 : 0;
            require(publicKey.length == PACKED_LEN + start, "bad pk length");

            uint256 idx = start;
            uint256 acc = 0;
            uint256 accBits = 0;
            uint256 i = 0;

            unchecked {
                while (i < t) {
                    while (accBits < 14) {
                        require(idx < publicKey.length + start, "pk too short");
                        acc |= uint256(uint8(publicKey[idx])) << accBits; // LSB-first fill
                        idx++;
                        accBits += 8;
                    }
                    h[i] = uint16(monty_mul(uint256(acc & 0x3FFF), FalconConstants.R2)); // take low 14 bits then convert to monty
                    acc >>= 14;
                    accBits -= 14;
                    i++;
                }
            }
        }

        // 2. Convert to NTT domain

        {
            unchecked {
                for (uint256 m = 0; m < FalconConstants.LOGN; m++) {
                    uint256 corr_m = uint256(1 << m);
                    uint256 ht = t >> 1;
                    uint256 j1 = 0;
                    for (uint256 i1 = 0; i1 < corr_m; i1++) {
                        uint256 s = FalconConstants.GMb[corr_m + i1];
                        uint256 j2 = j1 + ht;
                        for (uint256 j = j1; j < j2; j++) {
                            uint256 u = h[j];
                            uint256 v = monty_mul(h[j + ht], s);
                            h[j] = uint16(add_q(u, v));
                            h[j + ht] = uint16(sub_q(u, v));
                        }
                        j1 += t;
                    }
                    t = ht;
                }
            }
        }

        return h;
    }
}
