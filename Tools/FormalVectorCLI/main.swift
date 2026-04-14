import Foundation
import SuperNeo_NuMetal

private enum VectorToolError: Error, CustomStringConvertible {
    case usage

    var description: String {
        switch self {
        case .usage:
            "usage: superneo-formal-vectors ext2|ce"
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

private func decodeStatus(_ bytes: [UInt8]) -> String {
    do {
        let decoded = try GoldilocksExt2(littleEndianBytes: bytes[...])
        return "some:\(decoded.c0.rawValue),\(decoded.c1.rawValue)"
    } catch {
        return "none"
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
    default:
        throw VectorToolError.usage
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(64)
}
