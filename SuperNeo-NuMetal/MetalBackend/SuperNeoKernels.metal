#include <metal_stdlib>
using namespace metal;

constant ulong GOLDILOCKS_MODULUS = 0xffffffff00000001UL;

inline ulong goldilocks_add(ulong a, ulong b) {
    ulong r = a + b;
    if (r < a) {
        r += 0xffffffffUL;
    }
    if (r >= GOLDILOCKS_MODULUS) {
        r -= GOLDILOCKS_MODULUS;
    }
    return r;
}

inline ulong goldilocks_sub(ulong a, ulong b) {
    return a >= b ? a - b : GOLDILOCKS_MODULUS - (b - a);
}

inline ulong goldilocks_mul_fallback(ulong a, ulong b) {
    // Portable bit-serial multiplication modulo p for GPUs without native 128-bit lanes.
    ulong result = 0;
    ulong base = a;
    ulong scalar = b;
    for (uint i = 0; i < 64; i++) {
        if ((scalar & 1UL) != 0) {
            result = goldilocks_add(result, base);
        }
        scalar >>= 1;
        if (i != 63) {
            base = goldilocks_add(base, base);
        }
    }
    return result;
}

inline ulong goldilocks_mul_small_or_full(ulong a, ulong b) {
    if (a == 0 || b == 0) {
        return 0;
    }
    if (b == 1) {
        return a;
    }
    if (b == 2) {
        return goldilocks_add(a, a);
    }
    if (b == GOLDILOCKS_MODULUS - 1) {
        return goldilocks_sub(0, a);
    }
    if (b == GOLDILOCKS_MODULUS - 2) {
        return goldilocks_sub(0, goldilocks_add(a, a));
    }
    return goldilocks_mul_fallback(a, b);
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
    out[id] = goldilocks_mul_fallback(lhs[id], rhs[id]);
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
    out[id] = goldilocks_mul_fallback(rings[id], scalars[ringIndex]);
}

kernel void ring_mul_kernel(
    device const ulong *lhs [[buffer(0)]],
    device const ulong *rhs [[buffer(1)]],
    device ulong *out [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= count) { return; }

    ulong product[107];
    for (uint i = 0; i < 107; i++) {
        product[i] = 0;
    }

    uint base = id * 54;
    for (uint i = 0; i < 54; i++) {
        ulong a = lhs[base + i];
        if (a == 0) { continue; }
        for (uint j = 0; j < 54; j++) {
            ulong b = rhs[base + j];
            if (b == 0) { continue; }
            product[i + j] = goldilocks_add(product[i + j], goldilocks_mul_fallback(a, b));
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
        out[base + i] = product[i];
    }
}

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
            product[i + j] = goldilocks_add(product[i + j], goldilocks_mul_fallback(a, b));
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
            ulong term = goldilocks_mul_small_or_full(matrixRing[coeff], scalar);
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
        ulong product[54];
        ring_mul_local(matrix + matrixOffset, vector + vectorOffset, product);
        for (uint coeff = 0; coeff < 54; coeff++) {
            acc[coeff] = goldilocks_add(acc[coeff], product[coeff]);
        }
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
        acc0 = goldilocks_add(acc0, goldilocks_mul_fallback(rowCoeff, r0));
        acc1 = goldilocks_add(acc1, goldilocks_mul_fallback(rowCoeff, r1));
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
