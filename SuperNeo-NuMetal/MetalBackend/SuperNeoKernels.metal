#include <metal_stdlib>
using namespace metal;

constant ulong GOLDILOCKS_MODULUS = 0xffffffff00000001UL;
constant ulong GOLDILOCKS_EPSILON = 0xffffffffUL;
constant ulong GOLDILOCKS_LIMB_MASK = 0xffffffffUL;

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
