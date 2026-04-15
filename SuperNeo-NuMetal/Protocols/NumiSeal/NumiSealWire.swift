import Foundation

enum NumiSealWireLimits {
    static let maximumObligationCount = 1 << 20
    static let maximumLaneCount = 1 << 16
    static let maximumAggregateCount = 1 << 20
    static let maximumPublicInputCount = 1 << 20
    static let maximumEvaluationPointCount = 64
    static let maximumMatrixEvaluationCount = 1024
}

extension ByteReader {
    mutating func readNumiSealLaneID() throws -> NumiSealLaneID {
        let byteCount = try readCount(
            maximum: NumiSealLaneID.maximumByteCount,
            name: "NumiSeal lane ID byte"
        )
        return try NumiSealLaneID(readData(count: byteCount))
    }

    mutating func readNumiSealLaneKey() throws -> NumiSealLaneKey {
        try NumiSealLaneKey(
            profileID: readUInt16(),
            shapeDigest: Digest256(readData(count: Digest256.byteCount)),
            verifierKeyDigest: Digest256(readData(count: Digest256.byteCount)),
            evalPointDigest: Digest256(readData(count: Digest256.byteCount)),
            laneID: readNumiSealLaneID()
        )
    }

    mutating func readNumiSealLaneSummary() throws -> NumiSealLaneSummary {
        let laneKey = try readNumiSealLaneKey()
        let obligationCount = try readCount(
            maximum: NumiSealWireLimits.maximumObligationCount,
            name: "NumiSeal lane obligation"
        )
        guard obligationCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal lane summary cannot be empty")
        }
        return NumiSealLaneSummary(
            laneKey: laneKey,
            obligationCount: obligationCount,
            laneObligationRoot: try Digest256(readData(count: Digest256.byteCount)),
            laneSummaryDigest: try Digest256(readData(count: Digest256.byteCount))
        )
    }

    mutating func readNumiSealRing() throws -> CyclotomicRing54 {
        try CyclotomicRing54(littleEndianBytes: readData(count: CyclotomicRing54.degree * 8))
    }

    mutating func readNumiSealExt2() throws -> GoldilocksExt2 {
        try GoldilocksExt2(littleEndianBytes: readData(count: 16)[...])
    }

    mutating func readNumiSealExt2Ring() throws -> CyclotomicExt2Ring54 {
        try CyclotomicExt2Ring54(littleEndianBytes: readData(count: CyclotomicRing54.degree * 16))
    }

    mutating func readNumiSealCommitment(parameters: SuperNeoParameters) throws -> AjtaiCommitment {
        var elements: [CyclotomicRing54] = []
        elements.reserveCapacity(parameters.kappa)
        for _ in 0..<parameters.kappa {
            elements.append(try readNumiSealRing())
        }
        return AjtaiCommitment(elements)
    }

    mutating func readNumiSealPublicInputEncoding() throws -> PublicInputEncoding {
        let fieldCount = try readCount(
            maximum: NumiSealWireLimits.maximumPublicInputCount,
            name: "NumiSeal public input",
            elementByteWidth: 8
        )
        let field = try (0..<fieldCount).map { _ in
            try GoldilocksField(littleEndianBytes: readData(count: 8)[...])
        }
        let packedCount = try readCount(
            maximum: SuperNeoEmbedding.paddedLength(forFieldElementCount: fieldCount) / CyclotomicRing54.degree,
            name: "NumiSeal packed public input",
            elementByteWidth: CyclotomicRing54.degree * 8
        )
        let packed = try (0..<packedCount).map { _ in try readNumiSealRing() }
        return try PublicInputEncoding(field: field, packed: packed)
    }

    mutating func readNumiSealEvaluationPoint() throws -> [GoldilocksExt2] {
        let count = try readCount(
            maximum: NumiSealWireLimits.maximumEvaluationPointCount,
            name: "NumiSeal evaluation point",
            elementByteWidth: 16
        )
        return try (0..<count).map { _ in try readNumiSealExt2() }
    }

    mutating func readNumiSealMatrixEvaluations() throws -> [CyclotomicExt2Ring54] {
        let count = try readCount(
            maximum: NumiSealWireLimits.maximumMatrixEvaluationCount,
            name: "NumiSeal matrix evaluation",
            elementByteWidth: CyclotomicRing54.degree * 16
        )
        guard count > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal aggregate must contain matrix evaluations")
        }
        return try (0..<count).map { _ in try readNumiSealExt2Ring() }
    }
}
