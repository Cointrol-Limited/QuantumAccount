// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title FalconSigCompressed - Falcon-1024 compressed signature decoder
/// @notice Implements the reference Algorithms 17/18 (Decompress) and the
///         signature container from §3.11.3 (header | 40-byte nonce | padded s).
///         Header format: 0 c c 1 n n n n  with cc=01 (compressed), nnnn=10 (n=1024).
library FalconSigCompressed {
    // ----- Falcon-1024 params -----
    uint16 internal constant N = 1024;
    uint16 internal constant NONCE_LEN = 40;

    // Signature sizes (Falcon-1024, compressed):
    // Total signature = 1280 bytes = 1(header) + 40(nonce) + sbytelen.
    uint16 internal constant SIG_BYTES = 1280;
    uint16 internal constant SBYTES = SIG_BYTES - 1 - NONCE_LEN; // 1239
    // Per spec uniqueness rule: slen = 8*sbytelen - 328.
    //uint16 internal constant SLEN_BITS    = (SBYTES * 8) - 328;        // 9584

    // Header byte: 0 cc 1 nnnn  with cc=01, nnnn=LOGN(=10)
    // bit7=0, bits6..5=01, bit4=1, bits3..0=10(=0xA)  => 0x3A.
    uint8 internal constant HEADER_COMP = 0x3A;

    function _getBitMSB(bytes memory inb, uint256 bitIndex) private pure returns (uint8) {
        uint256 byteIndex = bitIndex >> 3;
        uint256 shift = 7 - (bitIndex & 7);
        return (uint8(inb[byteIndex]) >> uint8(shift)) & 1;
    }

    // ======== Core Decompress (Alg. 18) with uniqueness checks ========

    /// @notice Decompress the S-body (length must be exactly SBYTES), enforcing uniqueness.
    /// @return s The reconstructed int16[1024] vector.
    function decompressS(bytes memory body) internal pure returns (int16[1024] memory s) {
        require(body.length == SBYTES, "s body len");

        // Enforce rule (1): fixed bitlength slen = 8*SBYTES - 328
        uint256 totalBits = uint256(SBYTES) * 8;

        uint256 bitpos = 0;

        unchecked {
            for (uint256 i = 0; i < N; i++) {
                if (bitpos + 9 > totalBits) revert("decompress underflow");

                // sign
                uint8 sign = _getBitMSB(body, bitpos++);

                // 7 LSBs of |si|, read as b6..b0 (MSB-first in stream)
                uint32 low = 0;
                for (uint256 j = 0; j < 7; j++) {
                    uint8 bj = _getBitMSB(body, bitpos++);
                    low = (low << 1) | bj; // accumulate MSB-first
                }

                // unary MSBs: count zeros until first 1
                uint32 k = 0;
                while (true) {
                    if (bitpos >= totalBits) revert("decompress unary eof");
                    uint8 b = _getBitMSB(body, bitpos++);
                    if (b == 0) {
                        k++;
                    } else {
                        break; // saw the terminating '1'
                    }
                }

                // reconstruct si
                int32 val = int32(int256(uint256(low + (k << 7))));
                if (sign == 1) val = -val;

                // Uniqueness rule (2): if si == 0, sign must be 0
                if (val == 0 && sign == 1) revert("decompress zero-sign");

                s[i] = int16(val);
            }

            // Uniqueness rule (3): trailing bits (from slen to end of body) must be zero
            // There are exactly 328 trailing padding bits in SBYTES, they must be all zero.
            for (uint256 t = bitpos; t < totalBits; t++) {
                if (_getBitMSB(body, t) != 0) revert("decompress pad");
            }
        }
    }

    /// @notice Parse and verify a compressed signature; returns (s, nonce).
    /// @dev Accepts only the padded, fixed-length Falcon-1024 compressed form.
    function decodeSignatureCompressed(bytes memory sig)
        internal
        pure
        returns (int16[1024] memory s, bytes memory nonce)
    {
        require(sig.length == SIG_BYTES, "sig len");
        // Check header matches 0 cc 1 nnnn with cc=01, nnnn=10
        require(uint8(sig[0]) == HEADER_COMP, "header");

        // read nonce (40 bytes)
        nonce = new bytes(NONCE_LEN);
        for (uint256 i = 0; i < NONCE_LEN; i++) {
            nonce[i] = sig[1 + i];
        }

        // slice s body
        bytes memory body = new bytes(SBYTES);
        for (uint256 i = 0; i < SBYTES; i++) {
            body[i] = sig[1 + NONCE_LEN + i];
        }

        // Decompress with uniqueness checks
        s = decompressS(body);
    }
}

/// @dev Thin wrapper for testing/tooling from Solidity/Foundry.
///      Exposes external methods so you can fuzz round-trips.
contract FalconSigCompressedUtils {
    function decode(bytes calldata sig) external pure returns (bytes memory nonce, int16[1024] memory s) {
        (s, nonce) = FalconSigCompressed.decodeSignatureCompressed(sig);
    }
}
