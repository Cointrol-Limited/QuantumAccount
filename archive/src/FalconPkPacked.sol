// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library FalconPkPacked {
    uint16 internal constant N = 1024;
    uint256 internal constant PACKED_LEN = 1792; // 1024*14/8

    // --- Decode 1792 bytes (14-bit packing) into h[] in [0..Q-1] ---
    function decodePublicKeyModQPacked(bytes memory packed) internal pure returns (uint16[1024] memory h) {
        // If your blob includes the 1-byte Falcon header, skip it.
        uint256 start = (packed.length == 1793) ? 1 : 0;
        require(packed.length == PACKED_LEN + start, "bad pk length");

        uint256 idx = start;
        uint256 acc = 0;
        uint256 accBits = 0;
        uint256 i = 0;

        unchecked {
            while (i < N) {
                while (accBits < 14) {
                    require(idx < packed.length + start, "pk too short");
                    acc |= uint256(uint8(packed[idx])) << accBits; // LSB-first fill
                    idx++;
                    accBits += 8;
                }
                h[i] = uint16(acc & 0x3FFF); // take low 14 bits
                acc >>= 14;
                accBits -= 14;
                i++;
            }
        }
    }
}

// Optional thin wrapper for tests/tooling
contract FalconPkPackedUtils {
    using FalconPkPacked for uint16[1024];

    function decodePkPacked(bytes memory pk) external pure returns (uint16[1024] memory h) {
        return FalconPkPacked.decodePublicKeyModQPacked(pk);
    }
}
