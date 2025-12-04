// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title FalconHashToPointKeccak
 * @notice Falcon-1024 hash-to-point driven by Keccak-256 (counter-mode XOF).
 *
 * How it works (Falcon-compatible sampler, Keccak-driven stream):
 *  - Build a byte stream by hashing:  keccak256( domain || nonce || message )
 *  - Read 16-bit **big-endian** words from that stream.
 *  - If w >= 61445 (i.e., >= 5*q), reject. Else reduce modulo q=12289 by repeated subtraction.
 *  - Collect 1024 coefficients in [0..12288].
 *
 * Exposed variants:
 *  - `hashToPointKeccakCT(nonce, message)`: constant-work (expands exactly (N+287)*2 bytes).
 *  - `expandKeccakXOF(...)`: internal helper to make a deterministic XOF from Keccak-256.
 *
 * Notes:
 *  - This mirrors Falcon’s sampler logic but swaps SHAKE256 for Keccak-256.
 *  - Big-endian word parsing matches the reference’s convention.
 */
library FalconHashToPointKeccak {
    // Falcon-1024 parameters
    uint16 internal constant Q = 12289;
    uint16 internal constant N = 1024;
    uint16 internal constant REJ = 61445; // reject threshold (5*q)
    uint16 internal constant OVER_CT = 287; // oversampling for "constant-time" path
    uint256 internal constant CT_BYTES = (uint256(N) + OVER_CT) * 2; // 2622 bytes

    // === Little helpers ===

    /// @dev Read a 16-bit big-endian word at offset `off` from `src`.
    function _readU16BE(bytes memory src, uint256 off) private pure returns (uint16 v) {
        v = (uint16(uint8(src[off])) << 8) | uint16(uint8(src[off + 1]));
    }

    /// @dev Reduce v (0..61444) modulo q = 12289 via a small fixed chain of subtractions.
    function _reduceModQ(uint16 v) private pure returns (uint16) {
        uint32 w = v;
        if (w >= Q) w -= Q;
        if (w >= Q) w -= Q;
        if (w >= Q) w -= Q;
        if (w >= Q) w -= Q;
        return uint16(w);
    }

    // === Keccak-256 "XOF": expand to `outLen` bytes with counter-mode ===

    /**
     * @dev Expand into `outLen` bytes using: keccak256( domain || nonce || message || uint32(counter) )
     * @param domain  Domain separation tag (e.g., "ETHEREUM MAINNET", "POLYGON AMOY", etc.)
     * @param nonce   40 bytes is common in Falcon signatures, but any size is accepted here
     * @param message Arbitrary message bytes
     * @param outLen  Exact number of output bytes to produce
     */
    function _keccakExpand(bytes memory domain, bytes memory nonce, bytes32 message, uint256 outLen)
        private
        pure
        returns (bytes memory out)
    {
        out = new bytes(outLen);

        // Precompute the common prefix to avoid repeated concatenation costs
        // prefix = domain || nonce || message
        bytes memory prefix = abi.encodePacked(domain, nonce, message);

        uint256 fullBlocks = outLen / 32;
        uint256 tail = outLen % 32;

        // Write 32-byte blocks
        for (uint32 ctr = 0; ctr < fullBlocks; ctr++) {
            bytes32 h = keccak256(abi.encodePacked(prefix, ctr));
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

    // === Public/External API ===

    /**
     * @notice Constant-work hash-to-point: uses exactly 2622 bytes from Keccak-256 XOF.
     * @dev This mirrors the "constant-time" oversampling approach: we decode (N+287) words,
     *      discard invalid ones (>= REJ) by *scanning* (no early exit), and take the first N valid.
     *      With OVER_CT=287 the probability of ending with <N valid words is negligible; we still
     *      add a sanity `require`.
     *
     * @param domain  Domain separation tag (e.g., "ETHEREUM", "POLYGON", etc.)
     * @param nonce   Arbitrary nonce (e.g., 40 bytes if mirroring Falcon’s signature layout)
     * @param message Message bytes
     * @return x 1024 coefficients in [0..Q-1]
     */
    function hashToPointKeccakCT(bytes memory domain, bytes memory nonce, bytes32 message)
        internal
        pure
        returns (uint16[1024] memory x)
    {
        // Expand exactly the needed bytes for (N + OVER_CT) 16-bit words
        bytes memory stream = _keccakExpand(domain, nonce, message, CT_BYTES);

        uint256 outIdx = 0;
        // Scan all words; keep the first N valid ones
        unchecked {
            for (uint256 off = 0; off < CT_BYTES; off += 2) {
                uint16 w = _readU16BE(stream, off);
                if (w < REJ && outIdx < N) {
                    x[outIdx] = _reduceModQ(w);
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
    }
}

/**
 * @dev Thin wrapper exposing the library as external functions for testing or Foundry.
 */
contract FalconHashToPointKeccakUtils {
    function hashToPointCT(bytes memory domain, bytes memory nonce, bytes32 message)
        external
        pure
        returns (uint16[1024] memory c)
    {
        bytes memory check = hex"00";
        bool check2 = keccak256(abi.encodePacked(message)) == keccak256(abi.encodePacked(check));
        require(!check2, "message cannot be empty");
        c = FalconHashToPointKeccak.hashToPointKeccakCT(domain, nonce, message);
    }
}
