# Quantum Account and Falcon

**This is an ERC4337 implementation that includes a smart contract which will verify a falcon 1024 signature (FIPS 206)**

Falcon consists of:

- **Falcon**: The main implementation of the logic that includes two external functions: verifySignature and loadPublicKey
- **FalconConstants**: Values used for the NTT transformations, iNTT transformations, and the acceptance boundary.
- **FalconHelperFunctions**: Functions that provide outputs modolo Q (12289) includes add, subtract, Montgomery multiplication and division by 2.  These are the only functions required for signature verification.

QuantumAccount is an extension of BaseAccount with the following modifications:

- **Constructor**:  In addition to the EntryPoint address, the constructor takes an owner address (but does nothing with it at the moment), a falcon address, a domain value in bytes, and a public key in bytes format (using the falcon encode function where the header is optional so it expects either 1792 bytes or 1793 bytes).  The domain is used in the message hashing portion of the code.  The constructor will call the loadPublicKey function.
- **_validateSignature**:  In addition to using the userOp and userOpHash values, the domain value and public keys are passed to the Falcon contract for a verifySignature execution.
- **updatePublicKeys**:  This function allows the user to rotate the public keys associated with the QuantumAccount.

This was originally tested against EntryPointv0.7.0 but I have updated some of the tests so that they will still pass with v0.8.0

## Message Hashing

The FIPS 206 algorithm uses SHAKE256 to generate the hashed message.  I have instead used a Keccak-variant to reduce gas consumption.

## Documentation

There is a discord channel that includes the ABIs for QuantumAccount and Falcon and instructions on how to verify the transaction done on Mainnet on October 3rd.  https://discord.gg/Qc2FcNJD

## Archive Folder

I have included an archive folder with the original implementation I had written.  This implementation uses 40 million gas so it will not work except locally.  It has a cleaner, aesthetic style where functions have been organised into various folders and included a lot of validation on values to ensure they were always modolo Q.

##  Future Development

In case it was not obvious, the bundlers would still be vulnerable to Shor's algorithm once a quantum computer with sufficient qubits is built.  In such a case the worst an attacker could do is drain all the bundlers balances and inhibit transaction flow.  Estimates as when that could happen vary between 5 and 15 years.  Ethereum will switch from ECDSA before then and falcon is likely a good contender because its public keys and signatures are small when compared with other PQCs.
This is still a work in progress.  
The verify signature function uses about 10 million gas while the update public key is around 6 million so anyone updating their key in a falcon-signed transaction may have issues with the ~16 million transaction limit introduced with Fukasa.  To reduce gas consumption on verification, the public keys are transformed ready for Montgomery multiplication when loaded so they do not need to be transformed with each verification.  
I am considering changing the update key function to assume that Montgomery multiplication has occurred off-chain.  
I may also simplify the key decoding function to simple bytes like the signature instead of the big-endian/little-endian conversion.
I may revise the message hashing.

##  Python Code

The below code is a modification I made to a copy of code from this repository: https://github.com/tprest/falcon.py 
The modification replaces the SHAKE256 portion with the Keccak variant used in my solidity contracts.

```
from typing import Generator

Q = 12289
N = 1024

# ---- Keccak-256 wrapper -----------------------------------------------------

def _keccak256(data: bytes) -> bytes:
    """
    Returns Keccak-256 digest of data (32 bytes).
    Tries pycryptodome first, then pysha3.
    """
    try:
        # pycryptodome
        from Crypto.Hash import keccak  # type: ignore
        k = keccak.new(digest_bits=256)
        k.update(data)
        return k.digest()
    except Exception:
        try:
            # pysha3 (pip install pysha3) exposes keccak_256 in 'sha3' module
            import sha3  # type: ignore
            k = sha3.keccak_256()
            k.update(data)
            return k.digest()
        except Exception as e:
            raise RuntimeError(
                "No Keccak-256 implementation found. Install either:\n"
                "  pip install pycryptodome   (preferred)\n"
                "or\n"
                "  pip install pysha3"
            ) from e

def keccak_prf_stream(salt: bytes, message: bytes, domain: bytes = b"ETHEREUM") -> Generator[bytes, None, None]:
    """
    Counter-mode PRF stream using Keccak-256:
       block_i = Keccak256(domain || salt || message )
    Yields 32-byte blocks.
    """
    ctr = 0
    ctr_bytes = ctr.to_bytes(4, 'big')
    first = _keccak256(domain + salt + message + ctr_bytes)
    print("first:", first.hex())
    while True:
        ctr_bytes = ctr.to_bytes(4, 'big')
        yield _keccak256(domain + salt + message + ctr_bytes)
        ctr += 1

# ---- HashToPoint (Algorithm 7) with Keccak stream --------------------------

def hash_to_point_keccak(domain: bytes, message: bytes, salt: bytes, n: int = N, q: int = Q) -> list[int]:
    """
    Falcon HashToPoint using Keccak-256 stream.
    - 16-bit BIG-ENDIAN chunks
    - rejection if t >= k*q, then ci = t % q
    Outputs:
    - coeffs (list of 1024 uint16) mod q
    """
    if n <= 0:
        raise ValueError("n must be positive")
    if not (1 <= q <= 2**16):
        raise ValueError("q must be in [1, 2^16]")

    k = (1 << 16) // q          # floor(2^16 / q)
    kq = k * q                   # acceptance threshold
    coeffs = [0] * n
    i = 0

    stream = keccak_prf_stream(salt, message, domain)
    buf = b""
    # Consume 2-byte BE chunks until we fill n coefficients.
    while i < n:
        if len(buf) < 2:
            buf += next(stream)  # pull another 32-byte block
            continue
        t = int.from_bytes(buf[:2], 'big')
        buf = buf[2:]
        if t < kq:
            coeffs[i] = t % q
            i += 1

    return coeffs
```