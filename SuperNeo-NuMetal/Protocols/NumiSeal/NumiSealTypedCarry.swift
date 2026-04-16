import Foundation

public enum NumiSealCarryKind: UInt8, Equatable, Sendable {
    case residualOpening = 1
    case maskedResidualOpening = 2
}

public struct NumiSealCarryStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.typed-carry.v1")
    public static let version: UInt16 = 1

    public let version: UInt16
    public let carryKind: NumiSealCarryKind
    public let recursionLevel: Int
    public let producerProofEnvelopeDigest: Digest256
    public let producerProofTranscriptDigest: Digest256
    public let parentStatementDigest: Digest256
    public let parentPublicStatementDigest: Digest256
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let residualOpeningDigest: Digest256
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitmentDigest: Digest256
    public let finalPointDigest: Digest256
    public let claimedDigitEvaluation: GoldilocksExt2
    public let consumerContextDigest: Digest256
    public let carryDigest: Digest256

    public init(
        carryKind: NumiSealCarryKind,
        recursionLevel: Int,
        producerProofEnvelopeDigest: Digest256,
        producerProofTranscriptDigest: Digest256,
        parentStatementDigest: Digest256,
        parentPublicStatementDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualOpeningDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        finalPointDigest: Digest256,
        claimedDigitEvaluation: GoldilocksExt2,
        consumerContextDigest: Digest256
    ) throws {
        try Self.validate(recursionLevel: recursionLevel, aggregateIndex: aggregateIndex)
        self.version = Self.version
        self.carryKind = carryKind
        self.recursionLevel = recursionLevel
        self.producerProofEnvelopeDigest = producerProofEnvelopeDigest
        self.producerProofTranscriptDigest = producerProofTranscriptDigest
        self.parentStatementDigest = parentStatementDigest
        self.parentPublicStatementDigest = parentPublicStatementDigest
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.residualOpeningDigest = residualOpeningDigest
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.finalPointDigest = finalPointDigest
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.consumerContextDigest = consumerContextDigest
        self.carryDigest = Self.computeCarryDigest(
            carryKind: carryKind,
            recursionLevel: recursionLevel,
            producerProofEnvelopeDigest: producerProofEnvelopeDigest,
            producerProofTranscriptDigest: producerProofTranscriptDigest,
            parentStatementDigest: parentStatementDigest,
            parentPublicStatementDigest: parentPublicStatementDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualOpeningDigest: residualOpeningDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            finalPointDigest: finalPointDigest,
            claimedDigitEvaluation: claimedDigitEvaluation,
            consumerContextDigest: consumerContextDigest
        )
    }

    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("NumiSeal carry statement domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal carry statement version")
        }
        let rawKind = try reader.readUInt8()
        guard let carryKind = NumiSealCarryKind(rawValue: rawKind) else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal carry kind")
        }
        let recursionLevel = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal carry recursion level"
        )
        let producerProofEnvelopeDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let producerProofTranscriptDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let parentStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let parentPublicStatementDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal carry aggregate index"
        )
        let residualOpeningDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitmentDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let finalPointDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let claimedDigitEvaluation = try reader.readNumiSealExt2()
        let consumerContextDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let carryDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()
        try Self.validate(recursionLevel: recursionLevel, aggregateIndex: aggregateIndex)
        let expectedDigest = Self.computeCarryDigest(
            carryKind: carryKind,
            recursionLevel: recursionLevel,
            producerProofEnvelopeDigest: producerProofEnvelopeDigest,
            producerProofTranscriptDigest: producerProofTranscriptDigest,
            parentStatementDigest: parentStatementDigest,
            parentPublicStatementDigest: parentPublicStatementDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            residualOpeningDigest: residualOpeningDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitmentDigest: decompositionCommitmentDigest,
            finalPointDigest: finalPointDigest,
            claimedDigitEvaluation: claimedDigitEvaluation,
            consumerContextDigest: consumerContextDigest
        )
        guard carryDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal carry digest mismatch")
        }
        self.version = version
        self.carryKind = carryKind
        self.recursionLevel = recursionLevel
        self.producerProofEnvelopeDigest = producerProofEnvelopeDigest
        self.producerProofTranscriptDigest = producerProofTranscriptDigest
        self.parentStatementDigest = parentStatementDigest
        self.parentPublicStatementDigest = parentPublicStatementDigest
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.residualOpeningDigest = residualOpeningDigest
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitmentDigest = decompositionCommitmentDigest
        self.finalPointDigest = finalPointDigest
        self.claimedDigitEvaluation = claimedDigitEvaluation
        self.consumerContextDigest = consumerContextDigest
        self.carryDigest = carryDigest
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + numiSealEncodeUInt16(version)
            + [carryKind.rawValue]
            + Self.bodyBytes(
                recursionLevel: recursionLevel,
                producerProofEnvelopeDigest: producerProofEnvelopeDigest,
                producerProofTranscriptDigest: producerProofTranscriptDigest,
                parentStatementDigest: parentStatementDigest,
                parentPublicStatementDigest: parentPublicStatementDigest,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                residualOpeningDigest: residualOpeningDigest,
                decompositionKeyDigest: decompositionKeyDigest,
                decompositionCommitmentDigest: decompositionCommitmentDigest,
                finalPointDigest: finalPointDigest,
                claimedDigitEvaluation: claimedDigitEvaluation,
                consumerContextDigest: consumerContextDigest
            )
            + carryDigest.superNeoBytes
    }

    public static func finalPointDigest(_ point: [GoldilocksExt2]) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.carry.final-point.v1",
            bytes: numiSealEncodeCount(point.count) + point.flatMap(\.superNeoBytes)
        )
    }

    private static func validate(recursionLevel: Int, aggregateIndex: Int) throws {
        guard recursionLevel >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal carry recursion level must be non-negative")
        }
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal carry aggregate index must be non-negative")
        }
    }

    private static func computeCarryDigest(
        carryKind: NumiSealCarryKind,
        recursionLevel: Int,
        producerProofEnvelopeDigest: Digest256,
        producerProofTranscriptDigest: Digest256,
        parentStatementDigest: Digest256,
        parentPublicStatementDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualOpeningDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        finalPointDigest: Digest256,
        claimedDigitEvaluation: GoldilocksExt2,
        consumerContextDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.typed-carry.digest.v1",
            bytes: [carryKind.rawValue]
                + bodyBytes(
                    recursionLevel: recursionLevel,
                    producerProofEnvelopeDigest: producerProofEnvelopeDigest,
                    producerProofTranscriptDigest: producerProofTranscriptDigest,
                    parentStatementDigest: parentStatementDigest,
                    parentPublicStatementDigest: parentPublicStatementDigest,
                    laneKey: laneKey,
                    aggregateIndex: aggregateIndex,
                    residualOpeningDigest: residualOpeningDigest,
                    decompositionKeyDigest: decompositionKeyDigest,
                    decompositionCommitmentDigest: decompositionCommitmentDigest,
                    finalPointDigest: finalPointDigest,
                    claimedDigitEvaluation: claimedDigitEvaluation,
                    consumerContextDigest: consumerContextDigest
                )
        )
    }

    private static func bodyBytes(
        recursionLevel: Int,
        producerProofEnvelopeDigest: Digest256,
        producerProofTranscriptDigest: Digest256,
        parentStatementDigest: Digest256,
        parentPublicStatementDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        residualOpeningDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitmentDigest: Digest256,
        finalPointDigest: Digest256,
        claimedDigitEvaluation: GoldilocksExt2,
        consumerContextDigest: Digest256
    ) -> [UInt8] {
        numiSealEncodeCount(recursionLevel)
            + producerProofEnvelopeDigest.superNeoBytes
            + producerProofTranscriptDigest.superNeoBytes
            + parentStatementDigest.superNeoBytes
            + parentPublicStatementDigest.superNeoBytes
            + laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + residualOpeningDigest.superNeoBytes
            + decompositionKeyDigest.superNeoBytes
            + decompositionCommitmentDigest.superNeoBytes
            + finalPointDigest.superNeoBytes
            + claimedDigitEvaluation.superNeoBytes
            + consumerContextDigest.superNeoBytes
    }
}

public extension NumiSealCarryClaim {
    var typedStatement: NumiSealCarryStatement? {
        try? NumiSealCarryStatement(bytes: bytes)
    }
}

public struct NumiSealAcceptedCarry: Equatable, Sendable {
    public let statement: NumiSealCarryStatement
    public let replayIdentity: Digest256

    public init(statement: NumiSealCarryStatement, replayIdentity: Digest256) {
        self.statement = statement
        self.replayIdentity = replayIdentity
    }
}

public struct NumiSealCarryConsumer: Sendable {
    private var seenReplayIdentities: Set<Digest256>

    public init(seenReplayIdentities: Set<Digest256> = []) {
        self.seenReplayIdentities = seenReplayIdentities
    }

    public mutating func consume(
        _ statement: NumiSealCarryStatement,
        parentProofAccepted: Bool,
        expectedProducerProofEnvelopeDigest: Digest256,
        expectedProducerProofTranscriptDigest: Digest256,
        expectedParentStatementDigest: Digest256,
        expectedParentPublicStatementDigest: Digest256,
        expectedConsumerContextDigest: Digest256,
        minimumNextRecursionLevel: Int
    ) throws -> NumiSealAcceptedCarry {
        guard parentProofAccepted else {
            throw SuperNeoError.verificationFailed("NumiSeal carry parent proof is not accepted")
        }
        guard statement.producerProofEnvelopeDigest == expectedProducerProofEnvelopeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal carry producer proof envelope digest mismatch")
        }
        guard statement.producerProofTranscriptDigest == expectedProducerProofTranscriptDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal carry producer transcript digest mismatch")
        }
        guard statement.parentStatementDigest == expectedParentStatementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal carry parent statement digest mismatch")
        }
        guard statement.parentPublicStatementDigest == expectedParentPublicStatementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal carry parent public statement digest mismatch")
        }
        guard statement.consumerContextDigest == expectedConsumerContextDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal carry consumer context digest mismatch")
        }
        guard statement.recursionLevel >= minimumNextRecursionLevel else {
            throw SuperNeoError.verificationFailed("NumiSeal carry recursion level rollback")
        }
        let replayIdentity = NumiSealEncoding.digest(
            label: "numiseal.carry.replay-identity.v1",
            bytes: statement.carryDigest.superNeoBytes
                + statement.producerProofEnvelopeDigest.superNeoBytes
                + statement.consumerContextDigest.superNeoBytes
        )
        guard !seenReplayIdentities.contains(replayIdentity) else {
            throw SuperNeoError.verificationFailed("NumiSeal carry replay detected")
        }
        seenReplayIdentities.insert(replayIdentity)
        return NumiSealAcceptedCarry(statement: statement, replayIdentity: replayIdentity)
    }
}
