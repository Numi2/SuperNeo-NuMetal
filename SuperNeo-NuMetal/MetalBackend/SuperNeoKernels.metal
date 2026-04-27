#include <metal_stdlib>
using namespace metal;

constant ulong GOLDILOCKS_MODULUS = 0xffffffff00000001UL;
constant ulong GOLDILOCKS_EPSILON = 0xffffffffUL;
constant ulong GOLDILOCKS_LIMB_MASK = 0xffffffffUL;
constant uint SHAKE256_RATE_BYTES = 136;

constant uint SHA256_INITIAL_STATE[8] = {
    0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU,
    0x510e527fU, 0x9b05688cU, 0x1f83d9abU, 0x5be0cd19U
};

constant uint SHA256_ROUND_CONSTANTS[64] = {
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U,
    0x3956c25bU, 0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U,
    0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U,
    0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU,
    0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
    0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U,
    0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
    0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U,
    0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U,
    0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
    0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U
};

constant ulong KECCAK_ROUND_CONSTANTS[24] = {
    0x0000000000000001UL, 0x0000000000008082UL,
    0x800000000000808aUL, 0x8000000080008000UL,
    0x000000000000808bUL, 0x0000000080000001UL,
    0x8000000080008081UL, 0x8000000000008009UL,
    0x000000000000008aUL, 0x0000000000000088UL,
    0x0000000080008009UL, 0x000000008000000aUL,
    0x000000008000808bUL, 0x800000000000008bUL,
    0x8000000000008089UL, 0x8000000000008003UL,
    0x8000000000008002UL, 0x8000000000000080UL,
    0x000000000000800aUL, 0x800000008000000aUL,
    0x8000000080008081UL, 0x8000000000008080UL,
    0x0000000080000001UL, 0x8000000080008008UL
};

constant uint KECCAK_ROTATION_OFFSETS[25] = {
    0, 1, 62, 28, 27,
    36, 44, 6, 55, 20,
    3, 10, 43, 25, 39,
    41, 45, 15, 21, 8,
    18, 2, 61, 56, 14
};

inline ulong rotate_left_u64(ulong value, uint amount) {
    return amount == 0 ? value : ((value << amount) | (value >> (64 - amount)));
}

inline void keccak_f1600(thread ulong *lanes) {
    ulong c[5];
    ulong d[5];
    ulong b[25];

    for (uint round = 0; round < 24; round++) {
        for (uint x = 0; x < 5; x++) {
            c[x] = lanes[x] ^ lanes[x + 5] ^ lanes[x + 10] ^ lanes[x + 15] ^ lanes[x + 20];
        }
        for (uint x = 0; x < 5; x++) {
            d[x] = c[(x + 4) % 5] ^ rotate_left_u64(c[(x + 1) % 5], 1);
        }
        for (uint x = 0; x < 5; x++) {
            for (uint y = 0; y < 5; y++) {
                lanes[x + 5 * y] ^= d[x];
            }
        }

        for (uint x = 0; x < 5; x++) {
            for (uint y = 0; y < 5; y++) {
                const uint source = x + 5 * y;
                const uint destination = y + 5 * ((2 * x + 3 * y) % 5);
                b[destination] = rotate_left_u64(lanes[source], KECCAK_ROTATION_OFFSETS[source]);
            }
        }

        for (uint x = 0; x < 5; x++) {
            for (uint y = 0; y < 5; y++) {
                lanes[x + 5 * y] = b[x + 5 * y]
                    ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y]);
            }
        }
        lanes[0] ^= KECCAK_ROUND_CONSTANTS[round];
    }
}

inline void shake256_absorb_byte(thread ulong *state, thread uint &blockOffset, uchar byte) {
    const uint laneIndex = blockOffset >> 3;
    const uint laneShift = (blockOffset & 7) * 8;
    state[laneIndex] ^= (ulong(byte) << laneShift);
    blockOffset += 1;
    if (blockOffset == SHAKE256_RATE_BYTES) {
        keccak_f1600(state);
        blockOffset = 0;
    }
}

inline void shake256_absorb_device_bytes(
    thread ulong *state,
    thread uint &blockOffset,
    device const uchar *bytes,
    uint start,
    uint length
) {
    for (uint index = 0; index < length; index++) {
        shake256_absorb_byte(state, blockOffset, bytes[start + index]);
    }
}

inline void shake256_absorb_thread_bytes(
    thread ulong *state,
    thread uint &blockOffset,
    thread const uchar *bytes,
    uint length
) {
    for (uint index = 0; index < length; index++) {
        shake256_absorb_byte(state, blockOffset, bytes[index]);
    }
}

inline void shake256_absorb_u64_le(thread ulong *state, thread uint &blockOffset, ulong value) {
    for (uint byteIndex = 0; byteIndex < 8; byteIndex++) {
        shake256_absorb_byte(state, blockOffset, uchar((value >> (byteIndex * 8)) & 0xffUL));
    }
}

inline void shake256_absorb_device_frame(
    thread ulong *state,
    thread uint &blockOffset,
    device const uchar *bytes,
    uint start,
    uint length
) {
    shake256_absorb_u64_le(state, blockOffset, ulong(length));
    shake256_absorb_device_bytes(state, blockOffset, bytes, start, length);
}

inline void shake256_absorb_thread_frame(
    thread ulong *state,
    thread uint &blockOffset,
    thread const uchar *bytes,
    uint length
) {
    shake256_absorb_u64_le(state, blockOffset, ulong(length));
    shake256_absorb_thread_bytes(state, blockOffset, bytes, length);
}

inline void shake256_absorb_single_byte_frame(thread ulong *state, thread uint &blockOffset, uchar byte) {
    shake256_absorb_u64_le(state, blockOffset, 1UL);
    shake256_absorb_byte(state, blockOffset, byte);
}

inline void shake256_absorb_u64_le_frame(thread ulong *state, thread uint &blockOffset, ulong value) {
    shake256_absorb_u64_le(state, blockOffset, 8UL);
    shake256_absorb_u64_le(state, blockOffset, value);
}

inline void shake256_squeeze_digest256(thread ulong *state, uint blockOffset, thread uchar *outBytes) {
    const uint suffixLane = blockOffset >> 3;
    const uint suffixShift = (blockOffset & 7) * 8;
    state[suffixLane] ^= (ulong(0x1f) << suffixShift);
    state[(SHAKE256_RATE_BYTES - 1) >> 3] ^= (ulong(0x80) << (((SHAKE256_RATE_BYTES - 1) & 7) * 8));
    keccak_f1600(state);
    for (uint lane = 0; lane < 4; lane++) {
        const ulong value = state[lane];
        for (uint byteIndex = 0; byteIndex < 8; byteIndex++) {
            outBytes[lane * 8 + byteIndex] = uchar((value >> (byteIndex * 8)) & 0xffUL);
        }
    }
}

inline void shake256_digest_sumcheck_absorb_state(
    uchar proofKind,
    thread const uchar *stateDigest,
    device const uchar *payloadBytes,
    uint payloadOffset,
    uint payloadLength,
    device const uchar *domainBytes,
    uint domainLength,
    thread uchar *outDigest
) {
    ulong state[25];
    for (uint lane = 0; lane < 25; lane++) {
        state[lane] = 0;
    }
    uint blockOffset = 0;
    shake256_absorb_device_frame(state, blockOffset, domainBytes, 0, domainLength);
    shake256_absorb_single_byte_frame(state, blockOffset, proofKind);
    shake256_absorb_thread_frame(state, blockOffset, stateDigest, 32);
    shake256_absorb_u64_le_frame(state, blockOffset, ulong(payloadLength));
    shake256_absorb_device_frame(state, blockOffset, payloadBytes, payloadOffset, payloadLength);
    shake256_squeeze_digest256(state, blockOffset, outDigest);
}

inline void shake256_digest_sumcheck_challenge_seed(
    uchar proofKind,
    device const uchar *challengeTapeSeed,
    thread const uchar *stateDigest,
    ulong challengeCounter,
    device const uchar *domainBytes,
    uint domainLength,
    thread uchar *outDigest
) {
    ulong state[25];
    for (uint lane = 0; lane < 25; lane++) {
        state[lane] = 0;
    }
    uint blockOffset = 0;
    shake256_absorb_device_frame(state, blockOffset, domainBytes, 0, domainLength);
    shake256_absorb_single_byte_frame(state, blockOffset, proofKind);
    shake256_absorb_device_frame(state, blockOffset, challengeTapeSeed, 0, 32);
    shake256_absorb_thread_frame(state, blockOffset, stateDigest, 32);
    shake256_absorb_u64_le_frame(state, blockOffset, challengeCounter);
    shake256_squeeze_digest256(state, blockOffset, outDigest);
}

inline uint rotate_right_u32(uint value, uint amount) {
    return (value >> amount) | (value << (32 - amount));
}

inline uint sha256_ch(uint x, uint y, uint z) {
    return (x & y) ^ ((~x) & z);
}

inline uint sha256_maj(uint x, uint y, uint z) {
    return (x & y) ^ (x & z) ^ (y & z);
}

inline uint sha256_big_sigma0(uint x) {
    return rotate_right_u32(x, 2) ^ rotate_right_u32(x, 13) ^ rotate_right_u32(x, 22);
}

inline uint sha256_big_sigma1(uint x) {
    return rotate_right_u32(x, 6) ^ rotate_right_u32(x, 11) ^ rotate_right_u32(x, 25);
}

inline uint sha256_small_sigma0(uint x) {
    return rotate_right_u32(x, 7) ^ rotate_right_u32(x, 18) ^ (x >> 3);
}

inline uint sha256_small_sigma1(uint x) {
    return rotate_right_u32(x, 17) ^ rotate_right_u32(x, 19) ^ (x >> 10);
}

inline uchar sha256_padded_byte(
    device const uchar *inputBytes,
    uint start,
    uint length,
    uint paddedLength,
    uint index
) {
    if (index < length) {
        return inputBytes[start + index];
    }
    if (index == length) {
        return 0x80;
    }
    const uint lengthStart = paddedLength - 8;
    if (index >= lengthStart) {
        const ulong bitLength = ulong(length) * 8UL;
        const uint shift = (7 - (index - lengthStart)) * 8;
        return uchar((bitLength >> shift) & 0xffUL);
    }
    return 0;
}

// constant-time-source-scope: metal-goldilocks-common-arithmetic begin
inline ulong ct_mask(bool condition) {
    return select(0UL, ~0UL, condition);
}

inline ulong ct_select_ulong(ulong falseValue, ulong trueValue, bool condition) {
    ulong mask = ct_mask(condition);
    return (falseValue & ~mask) | (trueValue & mask);
}

inline ulong goldilocks_subtract_modulus_if_needed(ulong value) {
    ulong candidate = value - GOLDILOCKS_MODULUS;
    return ct_select_ulong(value, candidate, value >= GOLDILOCKS_MODULUS);
}

inline ulong goldilocks_add_folded_carry(ulong value, ulong foldedCarry) {
    ulong first = value + foldedCarry;
    bool firstOverflow = first < value;
    ulong secondCarry = GOLDILOCKS_EPSILON & ct_mask(firstOverflow);
    ulong second = first + secondCarry;
    bool secondOverflow = second < first;
    return second + (GOLDILOCKS_EPSILON & ct_mask(secondOverflow));
}

inline ulong goldilocks_add(ulong a, ulong b) {
    ulong r = a + b;
    r = goldilocks_add_folded_carry(r, GOLDILOCKS_EPSILON & ct_mask(r < a));
    return goldilocks_subtract_modulus_if_needed(r);
}

inline ulong goldilocks_sub(ulong a, ulong b) {
    ulong difference = a - b;
    return difference + (GOLDILOCKS_MODULUS & ct_mask(a < b));
}

inline void mul_wide_u64(ulong a, ulong b, thread ulong &high, thread ulong &low) {
    ulong a0 = a & GOLDILOCKS_LIMB_MASK;
    ulong a1 = a >> 32;
    ulong b0 = b & GOLDILOCKS_LIMB_MASK;
    ulong b1 = b >> 32;

    ulong p0 = a0 * b0;
    ulong p1 = a0 * b1;
    ulong p2 = a1 * b0;
    ulong p3 = a1 * b1;

    ulong middle = (p0 >> 32) + (p1 & GOLDILOCKS_LIMB_MASK) + (p2 & GOLDILOCKS_LIMB_MASK);
    low = (p0 & GOLDILOCKS_LIMB_MASK) | ((middle & GOLDILOCKS_LIMB_MASK) << 32);
    high = p3 + (p1 >> 32) + (p2 >> 32) + (middle >> 32);
}

inline ulong goldilocks_reduce128(ulong high, ulong low) {
    ulong highLow = high & GOLDILOCKS_LIMB_MASK;
    ulong highHigh = high >> 32;

    ulong reduced = low - highHigh;
    reduced -= GOLDILOCKS_EPSILON & ct_mask(low < highHigh);

    ulong foldedHighLow = highLow * GOLDILOCKS_EPSILON;
    ulong sum = reduced + foldedHighLow;
    sum = goldilocks_add_folded_carry(sum, GOLDILOCKS_EPSILON & ct_mask(sum < reduced));

    return goldilocks_subtract_modulus_if_needed(sum);
}

inline ulong goldilocks_mul(ulong a, ulong b) {
    ulong high = 0;
    ulong low = 0;
    mul_wide_u64(a, b, high, low);
    return goldilocks_reduce128(high, low);
}
// constant-time-source-scope: metal-goldilocks-common-arithmetic end

inline ulong goldilocks_mul_small_or_full(ulong a, ulong b) {
    if (a == 0 || b == 0) { return 0; }
    if (b == 1) { return a; }
    if (b == 2) { return goldilocks_add(a, a); }
    if (b == GOLDILOCKS_MODULUS - 1) { return goldilocks_sub(0, a); }
    if (b == GOLDILOCKS_MODULUS - 2) { return goldilocks_sub(0, goldilocks_add(a, a)); }
    return goldilocks_mul(a, b);
}

kernel void goldilocks_add_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    out[id] = goldilocks_add(lhs[id], rhs[id]);
}

kernel void goldilocks_sub_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    out[id] = goldilocks_sub(lhs[id], rhs[id]);
}

kernel void goldilocks_mul_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    out[id] = goldilocks_mul(lhs[id], rhs[id]);
}

kernel void sha256_digest256_preframed_kernel(
    device const uchar *inputBytes [[buffer(0)]],
    device const uint *inputOffsets [[buffer(1)]],
    device const uint *inputLengths [[buffer(2)]],
    device uchar *outputBytes [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }

    uint h[8];
    for (uint word = 0; word < 8; word++) {
        h[word] = SHA256_INITIAL_STATE[word];
    }

    const uint start = inputOffsets[id];
    const uint length = inputLengths[id];
    const uint blockCount = (length + 9 + 63) / 64;
    const uint paddedLength = blockCount * 64;
    uint w[64];

    for (uint blockIndex = 0; blockIndex < blockCount; blockIndex++) {
        const uint blockOffset = blockIndex * 64;
        for (uint word = 0; word < 16; word++) {
            const uint byteIndex = blockOffset + word * 4;
            w[word] =
                (uint(sha256_padded_byte(inputBytes, start, length, paddedLength, byteIndex)) << 24)
                | (uint(sha256_padded_byte(inputBytes, start, length, paddedLength, byteIndex + 1)) << 16)
                | (uint(sha256_padded_byte(inputBytes, start, length, paddedLength, byteIndex + 2)) << 8)
                | uint(sha256_padded_byte(inputBytes, start, length, paddedLength, byteIndex + 3));
        }
        for (uint word = 16; word < 64; word++) {
            w[word] = sha256_small_sigma1(w[word - 2]) + w[word - 7]
                + sha256_small_sigma0(w[word - 15]) + w[word - 16];
        }

        uint a = h[0];
        uint b = h[1];
        uint c = h[2];
        uint d = h[3];
        uint e = h[4];
        uint f = h[5];
        uint g = h[6];
        uint hh = h[7];
        for (uint round = 0; round < 64; round++) {
            const uint t1 = hh + sha256_big_sigma1(e) + sha256_ch(e, f, g)
                + SHA256_ROUND_CONSTANTS[round] + w[round];
            const uint t2 = sha256_big_sigma0(a) + sha256_maj(a, b, c);
            hh = g;
            g = f;
            f = e;
            e = d + t1;
            d = c;
            c = b;
            b = a;
            a = t1 + t2;
        }

        h[0] += a;
        h[1] += b;
        h[2] += c;
        h[3] += d;
        h[4] += e;
        h[5] += f;
        h[6] += g;
        h[7] += hh;
    }

    const uint outputBase = id * 32;
    for (uint word = 0; word < 8; word++) {
        outputBytes[outputBase + word * 4] = uchar((h[word] >> 24) & 0xff);
        outputBytes[outputBase + word * 4 + 1] = uchar((h[word] >> 16) & 0xff);
        outputBytes[outputBase + word * 4 + 2] = uchar((h[word] >> 8) & 0xff);
        outputBytes[outputBase + word * 4 + 3] = uchar(h[word] & 0xff);
    }
}

kernel void shake256_digest384_preframed_kernel(
    device const uchar *inputBytes [[buffer(0)]],
    device const uint *inputOffsets [[buffer(1)]],
    device const uint *inputLengths [[buffer(2)]],
    device ulong *outputLanes [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }

    ulong state[25];
    for (uint lane = 0; lane < 25; lane++) {
        state[lane] = 0;
    }

    uint blockOffset = 0;
    const uint start = inputOffsets[id];
    const uint length = inputLengths[id];
    for (uint offset = 0; offset < length; offset++) {
        shake256_absorb_byte(state, blockOffset, inputBytes[start + offset]);
    }

    const uint suffixLane = blockOffset >> 3;
    const uint suffixShift = (blockOffset & 7) * 8;
    state[suffixLane] ^= (ulong(0x1f) << suffixShift);
    state[(SHAKE256_RATE_BYTES - 1) >> 3] ^= (ulong(0x80) << (((SHAKE256_RATE_BYTES - 1) & 7) * 8));
    keccak_f1600(state);

    const uint outputBase = id * 6;
    for (uint lane = 0; lane < 6; lane++) {
        outputLanes[outputBase + lane] = state[lane];
    }
}

kernel void ce_challenge_seed_chain_kernel(
    device const uchar *commitmentBytes [[buffer(0)]],
    device const uint *commitmentOffsets [[buffer(1)]],
    device const uint *commitmentLengths [[buffer(2)]],
    device const uchar *responseBytes [[buffer(3)]],
    device const uint *responseOffsets [[buffer(4)]],
    device const uint *responseLengths [[buffer(5)]],
    device const uchar *challengeTapeSeed [[buffer(6)]],
    device const uchar *initialStateDigest [[buffer(7)]],
    device const uchar *roundCountPayload [[buffer(8)]],
    device uchar *outputSeedBytes [[buffer(9)]],
    device const uchar *absorbDomainBytes [[buffer(10)]],
    device const uchar *fieldChallengeDomainBytes [[buffer(11)]],
    constant uint *params [[buffer(12)]],
    uint id [[thread_position_in_grid]]
) {
    if (id != 0) { return; }
    const uint roundCount = params[0];
    const uchar proofKind = uchar(params[1]);
    const uint absorbDomainLength = params[2];
    const uint fieldChallengeDomainLength = params[3];

    uchar stateDigest[32];
    uchar nextDigest[32];
    for (uint byteIndex = 0; byteIndex < 32; byteIndex++) {
        stateDigest[byteIndex] = initialStateDigest[byteIndex];
    }

    shake256_digest_sumcheck_absorb_state(
        proofKind,
        stateDigest,
        roundCountPayload,
        0,
        8,
        absorbDomainBytes,
        absorbDomainLength,
        nextDigest
    );
    for (uint byteIndex = 0; byteIndex < 32; byteIndex++) {
        stateDigest[byteIndex] = nextDigest[byteIndex];
    }

    for (uint roundIndex = 0; roundIndex < roundCount; roundIndex++) {
        shake256_digest_sumcheck_absorb_state(
            proofKind,
            stateDigest,
            commitmentBytes,
            commitmentOffsets[roundIndex],
            commitmentLengths[roundIndex],
            absorbDomainBytes,
            absorbDomainLength,
            nextDigest
        );
        for (uint byteIndex = 0; byteIndex < 32; byteIndex++) {
            stateDigest[byteIndex] = nextDigest[byteIndex];
        }

        shake256_digest_sumcheck_challenge_seed(
            proofKind,
            challengeTapeSeed,
            stateDigest,
            ulong(roundIndex),
            fieldChallengeDomainBytes,
            fieldChallengeDomainLength,
            nextDigest
        );
        const uint outputBase = roundIndex * 32;
        for (uint byteIndex = 0; byteIndex < 32; byteIndex++) {
            outputSeedBytes[outputBase + byteIndex] = nextDigest[byteIndex];
        }

        shake256_digest_sumcheck_absorb_state(
            proofKind,
            stateDigest,
            responseBytes,
            responseOffsets[roundIndex],
            responseLengths[roundIndex],
            absorbDomainBytes,
            absorbDomainLength,
            nextDigest
        );
        for (uint byteIndex = 0; byteIndex < 32; byteIndex++) {
            stateDigest[byteIndex] = nextDigest[byteIndex];
        }
    }
}

kernel void ring_add_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    out[id] = goldilocks_add(lhs[id], rhs[id]);
}

kernel void ring_scalar_mul_kernel(
    device const ulong *rings [[buffer(0)]],
    device const ulong *scalars [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint ringIndex = id / 54;
    out[id] = goldilocks_mul_small_or_full(rings[id], scalars[ringIndex]);
}

inline ulong ring_raw_product_coefficient(
    device const ulong *lhs,
    device const ulong *rhs,
    uint base,
    uint target
) {
    ulong acc = 0;
    uint start = target > 53 ? target - 53 : 0;
    uint end = target < 53 ? target : 53;
    for (uint i = start; i <= end; i++) {
        ulong a = lhs[base + i];
        ulong b = rhs[base + target - i];
        if (a == 0 || b == 0) { continue; }
        acc = goldilocks_add(acc, goldilocks_mul_small_or_full(a, b));
    }
    return acc;
}

kernel void ring_mul_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }

    uint base = (id / 54) * 54;
    uint coeff = id % 54;

    ulong acc = ring_raw_product_coefficient(lhs, rhs, base, coeff);
    if (coeff <= 26) {
        acc = goldilocks_sub(acc, ring_raw_product_coefficient(lhs, rhs, base, coeff + 54));
    } else {
        acc = goldilocks_sub(acc, ring_raw_product_coefficient(lhs, rhs, base, coeff + 27));
    }
    if (coeff <= 25) {
        acc = goldilocks_add(acc, ring_raw_product_coefficient(lhs, rhs, base, coeff + 81));
    }

    out[base + coeff] = acc;
}

// constant-time-source-scope: metal-numiseal-zk-secret-bearing-kernels begin
kernel void numiseal_apply_mask_kernel(
    device const ulong *digitTensor [[buffer(0)]],
    device const ulong *mask [[buffer(1)]],
    device ulong *maskedTensor [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    maskedTensor[id] = goldilocks_add(digitTensor[id], mask[id]);
}

kernel void numiseal_dense_fold_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    ulong challenge = (ulong(params[1]) << 32) | ulong(params[0]);
    out[id] = goldilocks_add(lhs[id], goldilocks_mul(rhs[id], challenge));
}

kernel void numiseal_eq_weight_kernel(
    device const ulong *point [[buffer(0)]],
    device ulong *out [[buffer(1)]],
    device const uint *params [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint variableCount = params[0];
    ulong acc = 1;
    for (uint variable = 0; variable < variableCount; variable++) {
        ulong coordinate = point[variable];
        bool bit = ((id >> variable) & 1u) != 0;
        ulong oneMinusCoordinate = goldilocks_sub(1, coordinate);
        ulong term = ct_select_ulong(oneMinusCoordinate, coordinate, bit);
        acc = goldilocks_mul(acc, term);
    }
    out[id] = acc;
}

kernel void numiseal_sumcheck_accumulate_kernel(
    device const ulong *terms [[buffer(0)]],
    device const ulong *weights [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint termCount = params[0];
    ulong acc = 0;
    for (uint termIndex = 0; termIndex < termCount; termIndex++) {
        ulong term = terms[termIndex * count + id];
        ulong weight = weights[termIndex];
        acc = goldilocks_add(acc, goldilocks_mul(term, weight));
    }
    out[id] = acc;
}

kernel void numiseal_mask_accumulate_kernel(
    device const ulong *digitTensor [[buffer(0)]],
    device const ulong *mask [[buffer(1)]],
    device ulong *maskedTensor [[buffer(2)]],
    device ulong *accumulation [[buffer(3)]],
    device const ulong *weights [[buffer(4)]],
    constant uint &count [[buffer(5)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    ulong digit = digitTensor[id];
    ulong maskValue = mask[id];
    ulong masked = goldilocks_add(digit, maskValue);
    maskedTensor[id] = masked;
    ulong acc = goldilocks_mul(digit, weights[0]);
    acc = goldilocks_add(acc, goldilocks_mul(maskValue, weights[1]));
    acc = goldilocks_add(acc, goldilocks_mul(masked, weights[2]));
    accumulation[id] = acc;
}
// constant-time-source-scope: metal-numiseal-zk-secret-bearing-kernels end

inline void ring_mul_local(
    device const ulong *lhs,
    device const ulong *rhs,
    thread ulong *out
) {
    ulong product[107];
    for (uint i = 0; i < 107; i++) {
        product[i] = 0;
    }

    for (uint i = 0; i < 54; i++) {
        ulong a = lhs[i];
        if (a == 0) { continue; }
        for (uint j = 0; j < 54; j++) {
            ulong b = rhs[j];
            if (b == 0) { continue; }
            product[i + j] = goldilocks_add(product[i + j], goldilocks_mul_small_or_full(a, b));
        }
    }

    for (int exponent = 106; exponent >= 54; exponent--) {
        ulong value = product[exponent];
        if (value == 0) { continue; }
        product[exponent] = 0;
        int shifted = exponent - 54;
        product[shifted] = goldilocks_sub(product[shifted], value);
        product[shifted + 27] = goldilocks_sub(product[shifted + 27], value);
    }

    for (uint i = 0; i < 54; i++) {
        out[i] = product[i];
    }
}

inline bool ring_is_zero(device const ulong *ring) {
    for (uint coeff = 0; coeff < 54; coeff++) {
        if (ring[coeff] != 0) { return false; }
    }
    return true;
}

inline void ring_mul_accumulate_coeff_major_message(
    device const ulong *matrixRing,
    device const ulong *messages,
    uint messageBatchBase,
    uint columnCount,
    uint column,
    thread ulong *acc
) {
    for (uint shift = 0; shift < 54; shift++) {
        ulong scalar = messages[messageBatchBase + shift * columnCount + column];
        if (scalar == 0) { continue; }
        for (uint coeff = 0; coeff < 54; coeff++) {
            ulong matrixCoeff = matrixRing[coeff];
            if (matrixCoeff == 0) { continue; }
            ulong term = goldilocks_mul_small_or_full(matrixCoeff, scalar);
            if (term == 0) { continue; }
            uint exponent = coeff + shift;
            if (exponent < 54) {
                acc[exponent] = goldilocks_add(acc[exponent], term);
            } else if (exponent < 81) {
                acc[exponent - 54] = goldilocks_sub(acc[exponent - 54], term);
                acc[exponent - 27] = goldilocks_sub(acc[exponent - 27], term);
            } else {
                acc[exponent - 81] = goldilocks_add(acc[exponent - 81], term);
            }
        }
    }
}

inline void ring_mul_accumulate_rhs_coefficients(
    device const ulong *lhs,
    device const ulong *rhs,
    thread ulong *acc
) {
    for (uint shift = 0; shift < 54; shift++) {
        ulong scalar = rhs[shift];
        if (scalar == 0) { continue; }
        for (uint coeff = 0; coeff < 54; coeff++) {
            ulong lhsCoeff = lhs[coeff];
            if (lhsCoeff == 0) { continue; }
            ulong term = goldilocks_mul_small_or_full(lhsCoeff, scalar);
            if (term == 0) { continue; }
            uint exponent = coeff + shift;
            if (exponent < 54) {
                acc[exponent] = goldilocks_add(acc[exponent], term);
            } else if (exponent < 81) {
                acc[exponent - 54] = goldilocks_sub(acc[exponent - 54], term);
                acc[exponent - 27] = goldilocks_sub(acc[exponent - 27], term);
            } else {
                acc[exponent - 81] = goldilocks_add(acc[exponent - 81], term);
            }
        }
    }
}

kernel void transformed_matvec_kernel(
    device const ulong *matrix [[buffer(0)]],
    device const ulong *vector [[buffer(1)]],
    device ulong *outRows [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint row [[thread_position_in_grid]]
) {
    if (row >= count) { return; }
    uint rowCount = params[0];
    uint columnCount = params[1];
    if (row >= rowCount) { return; }

    ulong acc[54];
    for (uint coeff = 0; coeff < 54; coeff++) {
        acc[coeff] = 0;
    }

    for (uint column = 0; column < columnCount; column++) {
        uint matrixOffset = ((row * columnCount) + column) * 54;
        uint vectorOffset = column * 54;
        ring_mul_accumulate_rhs_coefficients(matrix + matrixOffset, vector + vectorOffset, acc);
    }

    uint outOffset = row * 54;
    for (uint coeff = 0; coeff < 54; coeff++) {
        outRows[outOffset + coeff] = acc[coeff];
    }
}

kernel void transformed_matvec_sparse_aware_kernel(
    device const ulong *matrix [[buffer(0)]],
    device const ulong *vector [[buffer(1)]],
    device ulong *outRows [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint row [[thread_position_in_grid]]
) {
    if (row >= count) { return; }
    uint rowCount = params[0];
    uint columnCount = params[1];
    if (row >= rowCount) { return; }

    ulong acc[54];
    for (uint coeff = 0; coeff < 54; coeff++) {
        acc[coeff] = 0;
    }

    for (uint column = 0; column < columnCount; column++) {
        uint matrixOffset = ((row * columnCount) + column) * 54;
        if (ring_is_zero(matrix + matrixOffset)) { continue; }
        uint vectorOffset = column * 54;
        ring_mul_accumulate_rhs_coefficients(matrix + matrixOffset, vector + vectorOffset, acc);
    }

    uint outOffset = row * 54;
    for (uint coeff = 0; coeff < 54; coeff++) {
        outRows[outOffset + coeff] = acc[coeff];
    }
}

kernel void sparse_transformed_matvec_kernel(
    device const uint *rowOffsets [[buffer(0)]],
    device const uint *columnIndices [[buffer(1)]],
    device const ulong *values [[buffer(2)]],
    device const ulong *vector [[buffer(3)]],
    device ulong *outRows [[buffer(4)]],
    device const uint *params [[buffer(5)]],
    constant uint &count [[buffer(6)]],
    uint row [[thread_position_in_grid]]
) {
    if (row >= count) { return; }
    uint rowCount = params[0];
    if (row >= rowCount) { return; }

    ulong acc[54];
    for (uint coeff = 0; coeff < 54; coeff++) {
        acc[coeff] = 0;
    }

    uint start = rowOffsets[row];
    uint end = rowOffsets[row + 1];
    for (uint entry = start; entry < end; entry++) {
        uint vectorOffset = columnIndices[entry] * 54;
        uint valueOffset = entry * 54;
        ring_mul_accumulate_rhs_coefficients(values + valueOffset, vector + vectorOffset, acc);
    }

    uint outOffset = row * 54;
    for (uint coeff = 0; coeff < 54; coeff++) {
        outRows[outOffset + coeff] = acc[coeff];
    }
}

kernel void transformed_eval_dot_kernel(
    device const ulong *rows [[buffer(0)]],
    device const ulong *rHat [[buffer(1)]],
    device ulong *outExtCoeffs [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint coeff [[thread_position_in_grid]]
) {
    if (coeff >= count || coeff >= 54) { return; }
    uint rowCount = params[0];

    ulong acc0 = 0;
    ulong acc1 = 0;
    for (uint row = 0; row < rowCount; row++) {
        ulong rowCoeff = rows[row * 54 + coeff];
        ulong r0 = rHat[row * 2];
        ulong r1 = rHat[row * 2 + 1];
        acc0 = goldilocks_add(acc0, goldilocks_mul(rowCoeff, r0));
        acc1 = goldilocks_add(acc1, goldilocks_mul(rowCoeff, r1));
    }

    outExtCoeffs[coeff * 2] = acc0;
    outExtCoeffs[coeff * 2 + 1] = acc1;
}

kernel void ajtai_matvec_tile_kernel(
    device const ulong *matrix [[buffer(0)]],
    device const ulong *messages [[buffer(1)]],
    device ulong *partialRows [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint rowCount = params[0];
    uint columnCount = params[1];
    uint columnTileSize = params[2];
    uint tileCount = params[3];
    uint batchCount = params[4];

    uint row = id % rowCount;
    uint tile = (id / rowCount) % tileCount;
    uint batch = id / (rowCount * tileCount);
    if (batch >= batchCount) { return; }

    uint columnStart = tile * columnTileSize;
    uint columnEnd = min(columnStart + columnTileSize, columnCount);

    ulong acc[54];
    for (uint coeff = 0; coeff < 54; coeff++) {
        acc[coeff] = 0;
    }

    uint messageBatchBase = batch * columnCount * 54;
    for (uint column = columnStart; column < columnEnd; column++) {
        uint matrixOffset = ((row * columnCount) + column) * 54;
        ring_mul_accumulate_coeff_major_message(
            matrix + matrixOffset,
            messages,
            messageBatchBase,
            columnCount,
            column,
            acc
        );
    }

    uint outOffset = (((batch * tileCount) + tile) * rowCount + row) * 54;
    for (uint coeff = 0; coeff < 54; coeff++) {
        partialRows[outOffset + coeff] = acc[coeff];
    }
}

inline void ajtai_accumulate_target_coefficient(
    device const ulong *matrixRing,
    ulong scalar,
    int matrixCoeff,
    thread ulong &acc,
    bool subtractTerm
) {
    if (scalar == 0) { return; }
    if (matrixCoeff < 0 || matrixCoeff >= 54) { return; }
    ulong matrixValue = matrixRing[matrixCoeff];
    if (matrixValue == 0) { return; }
    ulong term = goldilocks_mul_small_or_full(matrixValue, scalar);
    if (term == 0) { return; }
    acc = subtractTerm ? goldilocks_sub(acc, term) : goldilocks_add(acc, term);
}

inline void ajtai_accumulate_target_coefficient_small_message(
    device const ulong *matrixRing,
    ulong scalar,
    int matrixCoeff,
    thread ulong &acc,
    bool subtractTerm
) {
    if (scalar == 0) { return; }
    if (matrixCoeff < 0 || matrixCoeff >= 54) { return; }
    ulong matrixValue = matrixRing[matrixCoeff];
    if (matrixValue == 0) { return; }

    ulong term = matrixValue;
    bool negateTerm = false;
    if (scalar == 2) {
        term = goldilocks_add(matrixValue, matrixValue);
    } else if (scalar == GOLDILOCKS_MODULUS - 1) {
        negateTerm = true;
    } else if (scalar == GOLDILOCKS_MODULUS - 2) {
        term = goldilocks_add(matrixValue, matrixValue);
        negateTerm = true;
    } else if (scalar != 1) {
        term = goldilocks_mul(matrixValue, scalar);
    }

    bool shouldSubtract = subtractTerm != negateTerm;
    acc = shouldSubtract ? goldilocks_sub(acc, term) : goldilocks_add(acc, term);
}

inline void sparse_transformed_eval_accumulate_rows(
    device const uint *rowOffsets,
    device const uint *columnIndices,
    device const ulong *values,
    device const ulong *vectors,
    device const ulong *rHat,
    uint rowOffsetBase,
    uint vectorBase,
    uint rowStart,
    uint rowEnd,
    int target,
    thread ulong &acc0,
    thread ulong &acc1
) {
    for (uint row = rowStart; row < rowEnd; row++) {
        ulong rowCoeff = 0;
        uint start = rowOffsets[rowOffsetBase + row];
        uint end = rowOffsets[rowOffsetBase + row + 1];
        for (uint entry = start; entry < end; entry++) {
            uint valueOffset = entry * 54;
            uint vectorOffset = vectorBase + columnIndices[entry] * 54;
            for (uint shift = 0; shift < 54; shift++) {
                ulong scalar = vectors[vectorOffset + shift];
                if (scalar == 0) { continue; }
                int shifted = int(shift);
                ajtai_accumulate_target_coefficient(values + valueOffset, scalar, target - shifted, rowCoeff, false);
                if (target <= 26) {
                    ajtai_accumulate_target_coefficient(values + valueOffset, scalar, target + 54 - shifted, rowCoeff, true);
                }
                if (target >= 27) {
                    ajtai_accumulate_target_coefficient(values + valueOffset, scalar, target + 27 - shifted, rowCoeff, true);
                }
                if (target <= 25) {
                    ajtai_accumulate_target_coefficient(values + valueOffset, scalar, target + 81 - shifted, rowCoeff, false);
                }
            }
        }
        if (rowCoeff == 0) { continue; }
        ulong r0 = rHat[row * 2];
        ulong r1 = rHat[row * 2 + 1];
        acc0 = goldilocks_add(acc0, goldilocks_mul(rowCoeff, r0));
        acc1 = goldilocks_add(acc1, goldilocks_mul(rowCoeff, r1));
    }
}

kernel void sparse_transformed_eval_fused_kernel(
    device const uint *rowOffsets [[buffer(0)]],
    device const uint *columnIndices [[buffer(1)]],
    device const ulong *values [[buffer(2)]],
    device const ulong *vectors [[buffer(3)]],
    device const ulong *rHat [[buffer(4)]],
    device ulong *outExtCoeffs [[buffer(5)]],
    device const uint *params [[buffer(6)]],
    constant uint &count [[buffer(7)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint matrixCount = params[0];
    uint rowCount = params[1];
    uint columnCount = params[2];
    uint vectorCount = params[3];

    uint coeff = id % 54;
    uint matrix = (id / 54) % matrixCount;
    uint vector = id / (matrixCount * 54);
    if (vector >= vectorCount) { return; }

    int target = int(coeff);
    ulong acc0 = 0;
    ulong acc1 = 0;
    uint rowOffsetBase = matrix * (rowCount + 1);
    uint vectorBase = vector * columnCount * 54;

    sparse_transformed_eval_accumulate_rows(
        rowOffsets,
        columnIndices,
        values,
        vectors,
        rHat,
        rowOffsetBase,
        vectorBase,
        0,
        rowCount,
        target,
        acc0,
        acc1
    );

    uint outOffset = ((vector * matrixCount + matrix) * 54 + coeff) * 2;
    outExtCoeffs[outOffset] = acc0;
    outExtCoeffs[outOffset + 1] = acc1;
}

kernel void sparse_transformed_eval_block_partial_kernel(
    device const uint *rowOffsets [[buffer(0)]],
    device const uint *columnIndices [[buffer(1)]],
    device const ulong *values [[buffer(2)]],
    device const ulong *vectors [[buffer(3)]],
    device const ulong *rHat [[buffer(4)]],
    device ulong *partialExtCoeffs [[buffer(5)]],
    device const uint *params [[buffer(6)]],
    constant uint &count [[buffer(7)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint matrixCount = params[0];
    uint rowCount = params[1];
    uint columnCount = params[2];
    uint vectorCount = params[3];
    uint rowBlockSize = params[4];
    uint rowBlockCount = params[5];

    uint coeff = id % 54;
    uint rowBlock = (id / 54) % rowBlockCount;
    uint matrix = (id / (54 * rowBlockCount)) % matrixCount;
    uint vector = id / (matrixCount * rowBlockCount * 54);
    if (vector >= vectorCount) { return; }

    uint rowStart = rowBlock * rowBlockSize;
    uint rowEnd = min(rowStart + rowBlockSize, rowCount);
    int target = int(coeff);
    ulong acc0 = 0;
    ulong acc1 = 0;
    uint rowOffsetBase = matrix * (rowCount + 1);
    uint vectorBase = vector * columnCount * 54;

    sparse_transformed_eval_accumulate_rows(
        rowOffsets,
        columnIndices,
        values,
        vectors,
        rHat,
        rowOffsetBase,
        vectorBase,
        rowStart,
        rowEnd,
        target,
        acc0,
        acc1
    );

    uint outOffset = (((vector * matrixCount + matrix) * rowBlockCount + rowBlock) * 54 + coeff) * 2;
    partialExtCoeffs[outOffset] = acc0;
    partialExtCoeffs[outOffset + 1] = acc1;
}

kernel void sparse_transformed_eval_block_reduce_kernel(
    device const ulong *partialExtCoeffs [[buffer(0)]],
    device ulong *outExtCoeffs [[buffer(1)]],
    device const uint *params [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint matrixCount = params[0];
    uint vectorCount = params[3];
    uint rowBlockCount = params[5];

    uint coeff = id % 54;
    uint matrix = (id / 54) % matrixCount;
    uint vector = id / (matrixCount * 54);
    if (vector >= vectorCount) { return; }

    ulong acc0 = 0;
    ulong acc1 = 0;
    for (uint rowBlock = 0; rowBlock < rowBlockCount; rowBlock++) {
        uint partialOffset = (((vector * matrixCount + matrix) * rowBlockCount + rowBlock) * 54 + coeff) * 2;
        acc0 = goldilocks_add(acc0, partialExtCoeffs[partialOffset]);
        acc1 = goldilocks_add(acc1, partialExtCoeffs[partialOffset + 1]);
    }

    uint outOffset = ((vector * matrixCount + matrix) * 54 + coeff) * 2;
    outExtCoeffs[outOffset] = acc0;
    outExtCoeffs[outOffset + 1] = acc1;
}

kernel void sparse_transformed_eval_row_partial_kernel(
    device const uint *rowOffsets [[buffer(0)]],
    device const uint *columnIndices [[buffer(1)]],
    device const ulong *values [[buffer(2)]],
    device const ulong *vectors [[buffer(3)]],
    device const ulong *rHat [[buffer(4)]],
    device ulong *partialExtCoeffs [[buffer(5)]],
    device const uint *params [[buffer(6)]],
    constant uint &count [[buffer(7)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint matrixCount = params[0];
    uint rowCount = params[1];
    uint columnCount = params[2];
    uint vectorCount = params[3];

    uint row = id % rowCount;
    uint matrix = (id / rowCount) % matrixCount;
    uint vector = id / (matrixCount * rowCount);
    if (vector >= vectorCount) { return; }

    ulong rowCoeff[54];
    for (uint coeff = 0; coeff < 54; coeff++) {
        rowCoeff[coeff] = 0;
    }

    uint rowOffsetBase = matrix * (rowCount + 1);
    uint vectorBase = vector * columnCount * 54;
    uint start = rowOffsets[rowOffsetBase + row];
    uint end = rowOffsets[rowOffsetBase + row + 1];
    for (uint entry = start; entry < end; entry++) {
        uint valueOffset = entry * 54;
        uint vectorOffset = vectorBase + columnIndices[entry] * 54;
        ring_mul_accumulate_rhs_coefficients(values + valueOffset, vectors + vectorOffset, rowCoeff);
    }

    ulong r0 = rHat[row * 2];
    ulong r1 = rHat[row * 2 + 1];
    uint outOffset = (((vector * matrixCount + matrix) * rowCount + row) * 54) * 2;
    for (uint coeff = 0; coeff < 54; coeff++) {
        ulong value = rowCoeff[coeff];
        partialExtCoeffs[outOffset + coeff * 2] = goldilocks_mul(value, r0);
        partialExtCoeffs[outOffset + coeff * 2 + 1] = goldilocks_mul(value, r1);
    }
}

kernel void sparse_transformed_eval_row_reduce_kernel(
    device const ulong *partialExtCoeffs [[buffer(0)]],
    device ulong *outExtCoeffs [[buffer(1)]],
    device const uint *params [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint matrixCount = params[0];
    uint rowCount = params[1];
    uint vectorCount = params[3];

    uint coeff = id % 54;
    uint matrix = (id / 54) % matrixCount;
    uint vector = id / (matrixCount * 54);
    if (vector >= vectorCount) { return; }

    ulong acc0 = 0;
    ulong acc1 = 0;
    uint partialBase = ((vector * matrixCount + matrix) * rowCount * 54 + coeff) * 2;
    for (uint row = 0; row < rowCount; row++) {
        uint partialOffset = partialBase + row * 54 * 2;
        acc0 = goldilocks_add(acc0, partialExtCoeffs[partialOffset]);
        acc1 = goldilocks_add(acc1, partialExtCoeffs[partialOffset + 1]);
    }

    uint outOffset = ((vector * matrixCount + matrix) * 54 + coeff) * 2;
    outExtCoeffs[outOffset] = acc0;
    outExtCoeffs[outOffset + 1] = acc1;
}

kernel void ajtai_matvec_ring_batch_coeff_kernel(
    device const ulong *matrix [[buffer(0)]],
    device const ulong *messages [[buffer(1)]],
    device ulong *outRows [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint rowCount = params[0];
    uint columnCount = params[1];
    uint batchCount = params[2];

    uint coeff = id % 54;
    uint row = (id / 54) % rowCount;
    uint batch = id / (rowCount * 54);
    if (batch >= batchCount) { return; }

    int target = int(coeff);
    ulong acc = 0;
    uint messageBatchBase = batch * columnCount * 54;
    for (uint column = 0; column < columnCount; column++) {
        uint matrixOffset = ((row * columnCount) + column) * 54;
        uint messageOffset = messageBatchBase + column * 54;
        for (uint shift = 0; shift < 54; shift++) {
            ulong scalar = messages[messageOffset + shift];
            if (scalar == 0) { continue; }
            int shifted = int(shift);
            ajtai_accumulate_target_coefficient(matrix + matrixOffset, scalar, target - shifted, acc, false);
            if (target <= 26) {
                ajtai_accumulate_target_coefficient(matrix + matrixOffset, scalar, target + 54 - shifted, acc, true);
            }
            if (target >= 27) {
                ajtai_accumulate_target_coefficient(matrix + matrixOffset, scalar, target + 27 - shifted, acc, true);
            }
            if (target <= 25) {
                ajtai_accumulate_target_coefficient(matrix + matrixOffset, scalar, target + 81 - shifted, acc, false);
            }
        }
    }

    outRows[(batch * rowCount + row) * 54 + coeff] = acc;
}

kernel void ajtai_matvec_ring_batch_coeff_small_message_kernel(
    device const ulong *matrix [[buffer(0)]],
    device const ulong *messages [[buffer(1)]],
    device ulong *outRows [[buffer(2)]],
    device const uint *params [[buffer(3)]],
    constant uint &count [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint rowCount = params[0];
    uint columnCount = params[1];
    uint batchCount = params[2];

    uint coeff = id % 54;
    uint row = (id / 54) % rowCount;
    uint batch = id / (rowCount * 54);
    if (batch >= batchCount) { return; }

    int target = int(coeff);
    ulong acc = 0;
    uint messageBatchBase = batch * columnCount * 54;
    for (uint column = 0; column < columnCount; column++) {
        uint matrixOffset = ((row * columnCount) + column) * 54;
        uint messageOffset = messageBatchBase + column * 54;
        for (uint shift = 0; shift < 54; shift++) {
            ulong scalar = messages[messageOffset + shift];
            if (scalar == 0) { continue; }
            int shifted = int(shift);
            ajtai_accumulate_target_coefficient_small_message(matrix + matrixOffset, scalar, target - shifted, acc, false);
            if (target <= 26) {
                ajtai_accumulate_target_coefficient_small_message(matrix + matrixOffset, scalar, target + 54 - shifted, acc, true);
            }
            if (target >= 27) {
                ajtai_accumulate_target_coefficient_small_message(matrix + matrixOffset, scalar, target + 27 - shifted, acc, true);
            }
            if (target <= 25) {
                ajtai_accumulate_target_coefficient_small_message(matrix + matrixOffset, scalar, target + 81 - shifted, acc, false);
            }
        }
    }

    outRows[(batch * rowCount + row) * 54 + coeff] = acc;
}

kernel void ajtai_matvec_reduce_kernel(
    device const ulong *partialRows [[buffer(0)]],
    device ulong *outRows [[buffer(1)]],
    device const uint *params [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }
    uint rowCount = params[0];
    uint tileCount = params[3];
    uint batchCount = params[4];

    uint row = id % rowCount;
    uint batch = id / rowCount;
    if (batch >= batchCount) { return; }

    ulong acc[54];
    for (uint coeff = 0; coeff < 54; coeff++) {
        acc[coeff] = 0;
    }

    for (uint tile = 0; tile < tileCount; tile++) {
        uint partialOffset = (((batch * tileCount) + tile) * rowCount + row) * 54;
        for (uint coeff = 0; coeff < 54; coeff++) {
            acc[coeff] = goldilocks_add(acc[coeff], partialRows[partialOffset + coeff]);
        }
    }

    uint outOffset = (batch * rowCount + row) * 54;
    for (uint coeff = 0; coeff < 54; coeff++) {
        outRows[outOffset + coeff] = acc[coeff];
    }
}

inline uint reverse_low_bits(uint value, uint bitCount) {
    uint reversed = 0;
    for (uint bit = 0; bit < bitCount; bit++) {
        reversed = (reversed << 1) | (value & 1);
        value >>= 1;
    }
    return reversed;
}

kernel void fri_bit_reverse_permute_kernel(
    device const ulong *input [[buffer(0)]],
    device ulong *output [[buffer(1)]],
    constant uint *params [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    const uint count = params[0];
    const uint bitCount = params[1];
    if (id >= count) {
        return;
    }
    const uint reversed = reverse_low_bits(id, bitCount);
    output[reversed] = input[id];
}

kernel void fri_ntt_stage_kernel(
    device ulong *values [[buffer(0)]],
    device const ulong *twiddles [[buffer(1)]],
    constant uint *params [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    const uint count = params[0];
    const uint length = params[1];
    const uint halfCount = params[2];
    const uint pairCount = count >> 1;
    if (id >= pairCount) {
        return;
    }
    const uint group = id / halfCount;
    const uint offset = id - group * halfCount;
    const uint first = group * length + offset;
    const uint second = first + halfCount;
    const ulong even = values[first];
    const ulong odd = goldilocks_mul(values[second], twiddles[offset]);
    values[first] = goldilocks_add(even, odd);
    values[second] = goldilocks_sub(even, odd);
}
