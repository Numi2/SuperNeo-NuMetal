import Foundation
import SuperNeo_NuMetal

private enum VectorToolError: Error, CustomStringConvertible {
    case usage

    var description: String {
        switch self {
        case .usage:
            "usage: superneo-formal-vectors ext2|ce|embedding"
        }
    }
}

private func littleEndianBytes(_ value: UInt64) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func encodeCount(_ value: Int) -> [UInt8] {
    littleEndianBytes(UInt64(value))
}

private func decimalByteList(_ bytes: [UInt8]) -> String {
    bytes.map(String.init).joined(separator: ",")
}

private func fieldElement(_ value: Int) -> GoldilocksField {
    if value >= 0 {
        return GoldilocksField(UInt64(value))
    } else {
        return -GoldilocksField(UInt64(-value))
    }
}

private func fieldList(_ values: [GoldilocksField]) -> String {
    values.map { String($0.rawValue) }.joined(separator: ",")
}

private func ringCoefficients(_ value: CyclotomicRing54) -> String {
    fieldList(value.coefficients)
}

private func decodeStatus(_ bytes: [UInt8]) -> String {
    do {
        let decoded = try GoldilocksExt2(littleEndianBytes: bytes[...])
        return "some:\(decoded.c0.rawValue),\(decoded.c1.rawValue)"
    } catch {
        return "none"
    }
}

private func emitEmbeddingVectors() throws {
    let signedPattern = [0, 1, -1, 2, -2, 3, -3, 5, -5, 8, -8]
    let fieldVector = (0..<60).map { index in
        fieldElement(signedPattern[index % signedPattern.count])
    }
    let packed = try SuperNeoEmbedding.packPadded(fieldVector)
    let unpacked = SuperNeoEmbedding.unpack(packed)
    let exactBlock = Array(fieldVector.prefix(CyclotomicRing54.degree))

    var rowCoefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
    rowCoefficients[0] = fieldElement(3)
    rowCoefficients[7] = fieldElement(-5)
    rowCoefficients[17] = fieldElement(11)
    rowCoefficients[53] = fieldElement(13)
    let transformedRow = CyclotomicRing54(try CyclotomicRing54.innerProductTransform(rowCoefficients))
    let ringProduct = transformedRow * CyclotomicRing54(exactBlock)
    let expectedInnerProduct = zip(rowCoefficients, exactBlock).reduce(GoldilocksField.zero) { partial, pair in
        partial + pair.0 * pair.1
    }

    let matrix = try SparseFieldMatrix(
        rows: 2,
        columns: fieldVector.count,
        entries: [
            SparseFieldMatrix.Entry(row: 0, column: 0, value: fieldElement(3)),
            SparseFieldMatrix.Entry(row: 0, column: 7, value: fieldElement(-5)),
            SparseFieldMatrix.Entry(row: 0, column: 17, value: fieldElement(11)),
            SparseFieldMatrix.Entry(row: 0, column: 53, value: fieldElement(13)),
            SparseFieldMatrix.Entry(row: 1, column: 1, value: fieldElement(19)),
            SparseFieldMatrix.Entry(row: 1, column: 54, value: fieldElement(23)),
            SparseFieldMatrix.Entry(row: 1, column: 59, value: fieldElement(-29)),
        ]
    )
    let fieldProduct = try matrix.multiplied(by: fieldVector)
    let transformedDenseConstants = try matrix
        .transformedForSuperNeo()
        .multiplied(by: packed)
        .map(\.constantTerm)
    let transformedSparseConstants = try matrix
        .transformedSparseForSuperNeo()
        .multiplied(by: packed)
        .map(\.constantTerm)

    let lines: [(String, String)] = [
        ("embedding_input_length", String(fieldVector.count)),
        ("embedding_padded_length", String(SuperNeoEmbedding.paddedLength(forFieldElementCount: fieldVector.count))),
        ("embedding_packed_column_count", String(packed.count)),
        ("embedding_input_raw_values", fieldList(fieldVector)),
        ("embedding_first_column_coefficients", ringCoefficients(packed[0])),
        ("embedding_second_column_coefficients", ringCoefficients(packed[1])),
        ("embedding_unpacked_prefix", fieldList(Array(unpacked.prefix(fieldVector.count)))),
        ("embedding_padding_suffix_zero", String(unpacked.dropFirst(fieldVector.count).allSatisfy { $0 == .zero })),
        ("embedding_preserves_norm_exact_block", String(try SuperNeoEmbedding.preservesNorm(exactBlock))),
        ("embedding_inner_product_row_coefficients", fieldList(rowCoefficients)),
        ("embedding_inner_product_transform_coefficients", ringCoefficients(transformedRow)),
        ("embedding_inner_product_constant_term", String(ringProduct.constantTerm.rawValue)),
        ("embedding_inner_product_expected", String(expectedInnerProduct.rawValue)),
        ("embedding_sparse_matrix_field_product", fieldList(fieldProduct)),
        ("embedding_transformed_dense_constants", fieldList(transformedDenseConstants)),
        ("embedding_transformed_sparse_constants", fieldList(transformedSparseConstants)),
    ]

    for (label, value) in lines {
        print("\(label)=\(value)")
    }
}

private func emitExt2Vectors() {
    let c0Raw: UInt64 = 0x0102_0304_0506_0708
    let c1Raw: UInt64 = 0x1110_0F0E_0D0C_0B0A
    let c0 = GoldilocksField(c0Raw)
    let c1 = GoldilocksField(c1Raw)
    let element = GoldilocksExt2(c0, c1)
    let swapped = GoldilocksExt2(c1, c0)

    let expected = element.superNeoBytes
    let swappedBytes = swapped.superNeoBytes
    let ring = CyclotomicExt2Ring54([element, swapped])
    let sumcheck = SumcheckProof(
        claimedSum: element,
        rounds: [SumcheckRound(coeffs: [swapped, element])],
        finalPoint: [element],
        finalValue: swapped
    )

    let prefixBytes: [UInt8] = [160, 161, 162, 163, 164]
    let surfaceBytes = prefixBytes
        + encodeCount(1)
        + swapped.superNeoBytes
        + encodeCount(1)
        + ring.superNeoBytes

    var nonCanonicalC0 = expected
    nonCanonicalC0.replaceSubrange(0..<8, with: littleEndianBytes(GoldilocksField.modulus))
    var nonCanonicalC1 = expected
    nonCanonicalC1.replaceSubrange(8..<16, with: littleEndianBytes(GoldilocksField.modulus))
    let wrongLength = Array(expected.dropLast())

    let lines: [(String, String)] = [
        ("goldilocks_c0_encode", decimalByteList(c0.superNeoBytes)),
        ("goldilocks_c1_encode", decimalByteList(c1.superNeoBytes)),
        ("goldilocks_ext2_encode", decimalByteList(expected)),
        ("goldilocks_ext2_swapped_encode", decimalByteList(swappedBytes)),
        ("goldilocks_ext2_decode_valid", decodeStatus(expected)),
        ("goldilocks_ext2_decode_noncanonical_c0", decodeStatus(nonCanonicalC0)),
        ("goldilocks_ext2_decode_noncanonical_c1", decodeStatus(nonCanonicalC1)),
        ("goldilocks_ext2_decode_wrong_length", decodeStatus(wrongLength)),
        ("cyclotomic_ext2_ring54_encode", decimalByteList(ring.superNeoBytes)),
        ("sumcheck_ext2_surface_encode", decimalByteList(sumcheck.superNeoBytes)),
        ("point_evaluation_ext2_surface_encode", decimalByteList(surfaceBytes)),
    ]

    for (label, value) in lines {
        print("\(label)=\(value)")
    }
}

private func digest(_ seed: UInt8) throws -> Digest256 {
    try Digest256((0..<Digest256.byteCount).map { UInt8(truncatingIfNeeded: Int(seed) + $0) })
}

private func ceBranchName(_ response: CEOpeningProofResponse) -> String {
    switch response {
    case .mask:
        return "mask"
    case .maskedWitness:
        return "maskedWitness"
    case .permutedWitness:
        return "permutedWitness"
    }
}

private func ceProofDecodeStatus(_ bytes: [UInt8]) -> String {
    do {
        let proof = try CEOpeningProof(bytes: bytes)
        let branches = proof.rounds.prefix(3).map { ceBranchName($0.response) }.joined(separator: ",")
        return "some:rounds=\(proof.rounds.count),branches=\(branches)"
    } catch {
        return "none"
    }
}

private func emitCEVectors() throws {
    let firstCommitment = CEOpeningProofCommitments(
        maskLinearDigest: try digest(10),
        permutedMaskDigest: try digest(11),
        permutedMaskedWitnessDigest: try digest(12)
    )
    let secondCommitment = CEOpeningProofCommitments(
        maskLinearDigest: try digest(13),
        permutedMaskDigest: try digest(14),
        permutedMaskedWitnessDigest: try digest(15)
    )
    let commitments = [firstCommitment, secondCommitment]
    let maskOpenings = [
        CEOpeningLinearResponse(permutation: [0, 1], vector: [GoldilocksField(7), GoldilocksField(11)]),
        CEOpeningLinearResponse(permutation: [1, 0], vector: [GoldilocksField(13), GoldilocksField(17)])
    ]
    let maskedWitnessOpenings = [
        CEOpeningLinearResponse(permutation: [1, 1], vector: [GoldilocksField(19), GoldilocksField(23)]),
        CEOpeningLinearResponse(permutation: [0, 0], vector: [GoldilocksField(29), GoldilocksField(31)])
    ]
    let permutedWitnessOpenings = [
        CEOpeningNormResponse(
            permutedMask: [GoldilocksField(37), GoldilocksField(41)],
            permutedWitness: [GoldilocksField(43), GoldilocksField(47)]
        ),
        CEOpeningNormResponse(
            permutedMask: [GoldilocksField(53), GoldilocksField(59)],
            permutedWitness: [GoldilocksField(61), GoldilocksField(67)]
        )
    ]

    let maskResponse = CEOpeningProofResponse.mask(maskOpenings)
    let maskedWitnessResponse = CEOpeningProofResponse.maskedWitness(maskedWitnessOpenings)
    let permutedWitnessResponse = CEOpeningProofResponse.permutedWitness(permutedWitnessOpenings)
    let maskRound = CEOpeningProofRound(commitments: commitments, response: maskResponse)
    let maskedWitnessRound = CEOpeningProofRound(commitments: commitments, response: maskedWitnessResponse)
    let permutedWitnessRound = CEOpeningProofRound(commitments: commitments, response: permutedWitnessResponse)
    let roundCycle = [maskRound, maskedWitnessRound, permutedWitnessRound]
    let rounds = (0..<CEOpeningProof.roundCount).map { roundCycle[$0 % roundCycle.count] }
    let proof = try CEOpeningProof(rounds: rounds)
    let proofBytes = proof.superNeoBytes

    let roundWidth = maskRound.superNeoBytes.count
    let responseTagOffsetInRound = 8 + commitments.count * 3 * Digest256.byteCount
    let firstResponseTagOffset = 8 + responseTagOffsetInRound

    var wrongRoundCount = proofBytes
    wrongRoundCount[0] = UInt8(CEOpeningProof.roundCount - 1)
    var invalidTag = proofBytes
    invalidTag[firstResponseTagOffset] = 9
    var wrongResponseCount = proofBytes
    wrongResponseCount[firstResponseTagOffset + 1] = 1

    let lines: [(String, String)] = [
        ("ce_response_mask_encode", decimalByteList(maskResponse.superNeoBytes)),
        ("ce_response_masked_witness_encode", decimalByteList(maskedWitnessResponse.superNeoBytes)),
        ("ce_response_permuted_witness_encode", decimalByteList(permutedWitnessResponse.superNeoBytes)),
        ("ce_round_mask_encode", decimalByteList(maskRound.superNeoBytes)),
        ("ce_round_masked_witness_encode", decimalByteList(maskedWitnessRound.superNeoBytes)),
        ("ce_round_permuted_witness_encode", decimalByteList(permutedWitnessRound.superNeoBytes)),
        ("ce_round_width", String(roundWidth)),
        ("ce_first_response_tag_offset", String(firstResponseTagOffset)),
        ("ce_proof_encode", decimalByteList(proofBytes)),
        ("ce_proof_decode_valid", ceProofDecodeStatus(proofBytes)),
        ("ce_proof_decode_wrong_round_count", ceProofDecodeStatus(wrongRoundCount)),
        ("ce_proof_decode_invalid_tag", ceProofDecodeStatus(invalidTag)),
        ("ce_proof_decode_wrong_response_count", ceProofDecodeStatus(wrongResponseCount)),
    ]

    for (label, value) in lines {
        print("\(label)=\(value)")
    }
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch arguments {
    case ["ext2"]:
        emitExt2Vectors()
    case ["ce"]:
        try emitCEVectors()
    case ["embedding"]:
        try emitEmbeddingVectors()
    default:
        throw VectorToolError.usage
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(64)
}
