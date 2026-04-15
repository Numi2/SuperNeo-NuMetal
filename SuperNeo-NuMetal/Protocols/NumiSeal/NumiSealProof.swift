import Foundation

extension NumiSealWireLimits {
    static let maximumProofComponentByteCount = 1 << 24
    static let maximumProofLaneByteCount = 1 << 24
    static let maximumPublicStatementByteCount = 1 << 24
}

public enum NumiSealComponentDigestKind: UInt16, CaseIterable, Sendable {
    case publicStatement = 1
    case laneAggregate = 2
    case decomposition = 3
    case scalarization = 4
    case sumcheck = 5
    case residualOpening = 6
    case carry = 7

    public var label: String {
        switch self {
        case .publicStatement:
            return "numiseal.public-statement.v1"
        case .laneAggregate:
            return "numiseal.lane-aggregate.v1"
        case .decomposition:
            return "numiseal.decomposition.v1"
        case .scalarization:
            return "numiseal.scalarization.v1"
        case .sumcheck:
            return "numiseal.sumcheck.v1"
        case .residualOpening:
            return "numiseal.residual-opening.v1"
        case .carry:
            return "numiseal.carry.v1"
        }
    }
}

public struct NumiSealComponentDigest: Equatable, Sendable, SuperNeoByteEncodable {
    public let kind: NumiSealComponentDigestKind
    public let isAbsent: Bool
    public let laneKey: NumiSealLaneKey?
    public let aggregateIndex: Int?
    public let payloadDigest: Digest256

    public init(
        kind: NumiSealComponentDigestKind,
        isAbsent: Bool,
        laneKey: NumiSealLaneKey?,
        aggregateIndex: Int?,
        payloadDigest: Digest256
    ) throws {
        if kind == .publicStatement {
            guard laneKey == nil, aggregateIndex == nil else {
                throw SuperNeoError.invalidParameter("NumiSeal public statement component must be unscoped")
            }
        } else {
            guard laneKey != nil, aggregateIndex != nil else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate component must be scoped")
            }
        }
        if let aggregateIndex {
            guard aggregateIndex >= 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal component aggregate index must be non-negative")
            }
        }

        self.kind = kind
        self.isAbsent = isAbsent
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.payloadDigest = payloadDigest
    }

    public static func present(
        kind: NumiSealComponentDigestKind,
        laneKey: NumiSealLaneKey? = nil,
        aggregateIndex: Int? = nil,
        payloadBytes: [UInt8]
    ) -> Self {
        Self(
            uncheckedKind: kind,
            isAbsent: false,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            payloadDigest: NumiSealEncoding.digest(label: kind.label, bytes: payloadBytes)
        )
    }

    public static func absent(
        kind: NumiSealComponentDigestKind,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int
    ) -> Self {
        let scope = scopedBytes(laneKey: laneKey, aggregateIndex: aggregateIndex)
        return Self(
            uncheckedKind: kind,
            isAbsent: true,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            payloadDigest: NumiSealEncoding.digest(
                label: "numiseal.absent-component.v1",
                bytes: numiSealEncodeString(kind.label) + scope
            )
        )
    }

    public var leafDigest: Digest256 {
        NumiSealEncoding.digest(label: "numiseal.component-digest.v1", bytes: digestMaterial)
    }

    public var superNeoBytes: [UInt8] {
        digestMaterial + leafDigest.superNeoBytes
    }

    private var digestMaterial: [UInt8] {
        numiSealEncodeUInt16(kind.rawValue)
            + [isAbsent ? 0 : 1]
            + Self.scopeBytes(laneKey: laneKey, aggregateIndex: aggregateIndex)
            + payloadDigest.superNeoBytes
    }

    private init(
        uncheckedKind kind: NumiSealComponentDigestKind,
        isAbsent: Bool,
        laneKey: NumiSealLaneKey?,
        aggregateIndex: Int?,
        payloadDigest: Digest256
    ) {
        self.kind = kind
        self.isAbsent = isAbsent
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.payloadDigest = payloadDigest
    }

    private static func scopeBytes(laneKey: NumiSealLaneKey?, aggregateIndex: Int?) -> [UInt8] {
        guard let laneKey, let aggregateIndex else {
            return [0]
        }
        return scopedBytes(laneKey: laneKey, aggregateIndex: aggregateIndex)
    }

    private static func scopedBytes(laneKey: NumiSealLaneKey, aggregateIndex: Int) -> [UInt8] {
        [1] + laneKey.superNeoBytes + numiSealEncodeCount(aggregateIndex)
    }
}

public enum NumiSealComponentDigestTree {
    public static func root(_ components: [NumiSealComponentDigest]) -> Digest256 {
        NumiSealEncoding.root(
            label: "numiseal.component-digest-root.v1",
            leaves: components.map(\.leafDigest)
        )
    }
}

public struct NumiSealResidualOpening: Equatable, Sendable, SuperNeoByteEncodable {
    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) throws {
        guard !bytes.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening cannot be empty")
        }
        guard bytes.count <= NumiSealWireLimits.maximumProofComponentByteCount else {
            throw SuperNeoError.invalidParameter("NumiSeal residual opening is too large")
        }
        self.bytes = bytes
    }

    public var superNeoBytes: [UInt8] { bytes }
}

public struct NumiSealCarryClaim: Equatable, Sendable, SuperNeoByteEncodable {
    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) throws {
        guard !bytes.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal carry claim cannot be empty")
        }
        guard bytes.count <= NumiSealWireLimits.maximumProofComponentByteCount else {
            throw SuperNeoError.invalidParameter("NumiSeal carry claim is too large")
        }
        self.bytes = bytes
    }

    public var superNeoBytes: [UInt8] { bytes }
}

public struct NumiSealLaneProof: Equatable, Sendable, SuperNeoByteEncodable {
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let aggregateDigest: Digest256
    public let decompositionKeyDigest: Digest256
    public let decompositionCommitment: AjtaiCommitment
    public let scalarizationDigest: Digest256
    public let sumcheckProof: SumcheckProof
    public let residualOpening: NumiSealResidualOpening
    public let optionalCarryClaim: NumiSealCarryClaim?

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        aggregateDigest: Digest256,
        decompositionKeyDigest: Digest256,
        decompositionCommitment: AjtaiCommitment,
        scalarizationDigest: Digest256,
        sumcheckProof: SumcheckProof,
        residualOpening: NumiSealResidualOpening,
        optionalCarryClaim: NumiSealCarryClaim? = nil
    ) throws {
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal lane proof aggregate index must be non-negative")
        }
        guard decompositionCommitment.elements.count == SuperNeoParameters.goldilocks.kappa else {
            throw SuperNeoError.invalidParameter("NumiSeal decomposition commitment has wrong length")
        }
        guard sumcheckProof.finalPoint.count == sumcheckProof.rounds.count else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check final point count must match round count")
        }
        guard sumcheckProof.rounds.allSatisfy({ !$0.coeffs.isEmpty }) else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check rounds cannot be empty")
        }

        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.aggregateDigest = aggregateDigest
        self.decompositionKeyDigest = decompositionKeyDigest
        self.decompositionCommitment = decompositionCommitment
        self.scalarizationDigest = scalarizationDigest
        self.sumcheckProof = sumcheckProof
        self.residualOpening = residualOpening
        self.optionalCarryClaim = optionalCarryClaim
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal lane proof aggregate index"
        )
        let aggregateDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionKeyDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let decompositionCommitment = try reader.readNumiSealCommitment(parameters: parameters)
        let scalarizationDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let sumcheckBytes = try reader.readNumiSealProofComponentBytes(name: "NumiSeal sum-check proof")
        let sumcheckProof = try NumiSealProofReaders.readSumcheckProof(from: sumcheckBytes)
        let residualOpening = try NumiSealResidualOpening(
            reader.readNumiSealProofComponentBytes(name: "NumiSeal residual opening")
        )
        let carryTag = try reader.readUInt8()
        let optionalCarryClaim: NumiSealCarryClaim?
        switch carryTag {
        case 0:
            optionalCarryClaim = nil
        case 1:
            optionalCarryClaim = try NumiSealCarryClaim(
                reader.readNumiSealProofComponentBytes(name: "NumiSeal carry claim")
            )
        default:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal carry claim tag")
        }
        try reader.finish()

        try self.init(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            aggregateDigest: aggregateDigest,
            decompositionKeyDigest: decompositionKeyDigest,
            decompositionCommitment: decompositionCommitment,
            scalarizationDigest: scalarizationDigest,
            sumcheckProof: sumcheckProof,
            residualOpening: residualOpening,
            optionalCarryClaim: optionalCarryClaim
        )
    }

    public var componentDigests: [NumiSealComponentDigest] {
        [
            .present(
                kind: .laneAggregate,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: aggregateDigest.superNeoBytes
            ),
            .present(
                kind: .decomposition,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: decompositionKeyDigest.superNeoBytes + decompositionCommitment.superNeoBytes
            ),
            .present(
                kind: .scalarization,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: scalarizationDigest.superNeoBytes
            ),
            .present(
                kind: .sumcheck,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: sumcheckProof.superNeoBytes
            ),
            .present(
                kind: .residualOpening,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: residualOpening.superNeoBytes
            ),
            carryComponentDigest
        ]
    }

    public var proofDigest: Digest256 {
        NumiSealEncoding.digest(label: "numiseal.lane-proof.v1", bytes: superNeoBytes)
    }

    public var superNeoBytes: [UInt8] {
        laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + aggregateDigest.superNeoBytes
            + decompositionKeyDigest.superNeoBytes
            + decompositionCommitment.superNeoBytes
            + scalarizationDigest.superNeoBytes
            + numiSealFrame(sumcheckProof.superNeoBytes)
            + numiSealFrame(residualOpening.superNeoBytes)
            + (optionalCarryClaim.map { [UInt8(1)] + numiSealFrame($0.superNeoBytes) } ?? [UInt8(0)])
    }

    private var carryComponentDigest: NumiSealComponentDigest {
        if let optionalCarryClaim {
            return .present(
                kind: .carry,
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                payloadBytes: optionalCarryClaim.superNeoBytes
            )
        }
        return .absent(kind: .carry, laneKey: laneKey, aggregateIndex: aggregateIndex)
    }
}

public struct NumiSealProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let bodyVersion: UInt16 = 10

    public let bodyVersion: UInt16
    public let publicStatement: NumiSealPublicStatement
    public let aggregateCount: Int
    public let laneProofs: [NumiSealLaneProof]
    public let componentDigestRoot: Digest256
    public let transcriptDigest: Digest256

    public init(
        publicStatement: NumiSealPublicStatement,
        laneProofs: [NumiSealLaneProof]
    ) throws {
        guard !laneProofs.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal proof requires lane proofs")
        }
        try Self.validateLaneProofOrdering(laneProofs)
        let componentDigestRoot = Self.computeComponentDigestRoot(
            publicStatement: publicStatement,
            laneProofs: laneProofs
        )
        self.bodyVersion = Self.bodyVersion
        self.publicStatement = publicStatement
        self.aggregateCount = laneProofs.count
        self.laneProofs = laneProofs
        self.componentDigestRoot = componentDigestRoot
        self.transcriptDigest = Self.computeTranscriptDigest(
            bodyVersion: Self.bodyVersion,
            publicStatement: publicStatement,
            aggregateCount: laneProofs.count,
            laneProofs: laneProofs,
            componentDigestRoot: componentDigestRoot
        )
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let bodyVersion = try reader.readUInt16()
        guard bodyVersion == Self.bodyVersion else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal proof body version")
        }
        let publicStatementBytes = try reader.readNumiSealProofComponentBytes(
            maximum: NumiSealWireLimits.maximumPublicStatementByteCount,
            name: "NumiSeal public statement"
        )
        let publicStatement = try NumiSealPublicStatement(bytes: publicStatementBytes)
        let aggregateCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal aggregate"
        )
        let laneProofCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal lane proof",
            elementByteWidth: 8
        )
        guard aggregateCount == laneProofCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal aggregate count must match lane proof count")
        }
        guard laneProofCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal proof requires lane proofs")
        }
        let laneProofs = try (0..<laneProofCount).map { _ in
            try NumiSealLaneProof(
                bytes: reader.readNumiSealProofComponentBytes(
                    maximum: NumiSealWireLimits.maximumProofLaneByteCount,
                    name: "NumiSeal lane proof"
                ),
                parameters: parameters
            )
        }
        let componentDigestRoot = try Digest256(reader.readData(count: Digest256.byteCount))
        let transcriptDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()
        try Self.validateLaneProofOrdering(laneProofs)

        let expectedComponentDigestRoot = Self.computeComponentDigestRoot(
            publicStatement: publicStatement,
            laneProofs: laneProofs
        )
        guard componentDigestRoot == expectedComponentDigestRoot else {
            throw SuperNeoError.invalidEncoding("NumiSeal component digest root mismatch")
        }
        let expectedTranscriptDigest = Self.computeTranscriptDigest(
            bodyVersion: bodyVersion,
            publicStatement: publicStatement,
            aggregateCount: aggregateCount,
            laneProofs: laneProofs,
            componentDigestRoot: componentDigestRoot
        )
        guard transcriptDigest == expectedTranscriptDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal transcript digest mismatch")
        }

        self.bodyVersion = bodyVersion
        self.publicStatement = publicStatement
        self.aggregateCount = aggregateCount
        self.laneProofs = laneProofs
        self.componentDigestRoot = componentDigestRoot
        self.transcriptDigest = transcriptDigest
    }

    public var componentDigests: [NumiSealComponentDigest] {
        [
            .present(kind: .publicStatement, payloadBytes: publicStatement.superNeoBytes)
        ] + laneProofs.flatMap(\.componentDigests)
    }

    public var superNeoBytes: [UInt8] {
        numiSealEncodeUInt16(bodyVersion)
            + numiSealFrame(publicStatement.superNeoBytes)
            + numiSealEncodeCount(aggregateCount)
            + numiSealEncodeCount(laneProofs.count)
            + laneProofs.flatMap { numiSealFrame($0.superNeoBytes) }
            + componentDigestRoot.superNeoBytes
            + transcriptDigest.superNeoBytes
    }

    private static func computeComponentDigestRoot(
        publicStatement: NumiSealPublicStatement,
        laneProofs: [NumiSealLaneProof]
    ) -> Digest256 {
        NumiSealComponentDigestTree.root(
            [.present(kind: .publicStatement, payloadBytes: publicStatement.superNeoBytes)]
                + laneProofs.flatMap(\.componentDigests)
        )
    }

    private static func computeTranscriptDigest(
        bodyVersion: UInt16,
        publicStatement: NumiSealPublicStatement,
        aggregateCount: Int,
        laneProofs: [NumiSealLaneProof],
        componentDigestRoot: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.proof-transcript.v1",
            bytes: numiSealEncodeUInt16(bodyVersion)
                + publicStatement.digest.superNeoBytes
                + numiSealEncodeCount(aggregateCount)
                + numiSealEncodeCount(laneProofs.count)
                + laneProofs.flatMap { $0.proofDigest.superNeoBytes }
                + componentDigestRoot.superNeoBytes
        )
    }

    private static func validateLaneProofOrdering(_ laneProofs: [NumiSealLaneProof]) throws {
        var previousLaneKeyBytes: [UInt8]?
        var previousAggregateIndex: Int?
        for laneProof in laneProofs {
            let laneKeyBytes = laneProof.laneKey.superNeoBytes
            if let previousLaneKeyBytes, let previousAggregateIndex {
                if laneKeyBytes == previousLaneKeyBytes {
                    guard previousAggregateIndex < laneProof.aggregateIndex else {
                        throw SuperNeoError.invalidEncoding("NumiSeal lane proofs must be lane-major and aggregate-index sorted")
                    }
                } else {
                    guard previousLaneKeyBytes.lexicographicallyPrecedes(laneKeyBytes) else {
                        throw SuperNeoError.invalidEncoding("NumiSeal lane proofs must be lane-major and aggregate-index sorted")
                    }
                }
            }
            previousLaneKeyBytes = laneKeyBytes
            previousAggregateIndex = laneProof.aggregateIndex
        }
    }
}

public enum NumiSealResidualMode: UInt8, Equatable, Sendable {
    case immediate = 1
}

public enum NumiSealCarryMode: UInt8, Equatable, Sendable {
    case none = 0
    case optional = 1
    case required = 2
}

public struct NumiSealTerminalProofAcceptancePolicy: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let acceptedLaneIDs: Set<NumiSealLaneID>
    public let maximumProofByteCount: Int?
    public let maximumLaneCount: Int?
    public let maximumAggregatesPerLane: Int?
    public let acceptedResidualMode: NumiSealResidualMode
    public let acceptedCarryMode: NumiSealCarryMode

    public init(
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = Digest256.hash("SuperNeo-NuMetal.numiseal.v1"),
        acceptedLaneIDs: Set<NumiSealLaneID>,
        maximumProofByteCount: Int? = nil,
        maximumLaneCount: Int? = nil,
        maximumAggregatesPerLane: Int? = nil,
        acceptedResidualMode: NumiSealResidualMode = .immediate,
        acceptedCarryMode: NumiSealCarryMode = .none
    ) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.acceptedLaneIDs = acceptedLaneIDs
        self.maximumProofByteCount = maximumProofByteCount
        self.maximumLaneCount = maximumLaneCount
        self.maximumAggregatesPerLane = maximumAggregatesPerLane
        self.acceptedResidualMode = acceptedResidualMode
        self.acceptedCarryMode = acceptedCarryMode
    }

    public func preflight(
        proofBytes: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> NumiSealProofEnvelope {
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        _ = try context(for: header, totalByteCount: proofBytes.count)
        let envelope = try NumiSealProofEnvelope(bytes: proofBytes, parameters: parameters)
        try validate(proof: envelope.proof)
        return envelope
    }

    public func context(for header: ProofEnvelopeHeader, totalByteCount: Int) throws -> ProofEnvelopeContext {
        try validateLimits(totalByteCount: totalByteCount)
        try header.validateEnvelopeLength(totalByteCount: totalByteCount)
        guard header.kind == .numiSealTerminal else {
            throw SuperNeoError.verificationFailed("NumiSeal terminal proof required")
        }
        guard header.profileID == profileID else {
            throw SuperNeoError.verificationFailed("NumiSeal profile mismatch")
        }
        guard header.shapeDigest == shapeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal shape digest mismatch")
        }
        guard header.statementDigest == statementDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal statement digest mismatch")
        }
        guard header.verifierKeyDigest == verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal verifier key digest mismatch")
        }
        guard header.transcriptDomain == transcriptDomain else {
            throw SuperNeoError.verificationFailed("NumiSeal transcript domain mismatch")
        }
        return ProofEnvelopeContext(
            profileID: profileID,
            kind: .numiSealTerminal,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }

    public func validate(proof: NumiSealProof) throws {
        try validateLimits(totalByteCount: nil)
        guard !acceptedLaneIDs.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal policy must accept at least one lane ID")
        }
        try proof.publicStatement.validate(
            against: NumiSealAcceptancePolicy(
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                acceptedLaneIDs: acceptedLaneIDs,
                maximumProofByteCount: maximumProofByteCount
            )
        )
        if let maximumLaneCount {
            guard proof.publicStatement.laneSummaries.count <= maximumLaneCount else {
                throw SuperNeoError.verificationFailed("NumiSeal lane count exceeds policy maximum")
            }
        }
        let publicStatementLaneKeys = Set(proof.publicStatement.laneSummaries.map(\.laneKey))
        var aggregatesByLane: [NumiSealLaneKey: Int] = [:]
        for laneProof in proof.laneProofs {
            guard acceptedLaneIDs.contains(laneProof.laneKey.laneID) else {
                throw SuperNeoError.verificationFailed("NumiSeal lane proof lane is not accepted by policy")
            }
            guard publicStatementLaneKeys.contains(laneProof.laneKey) else {
                throw SuperNeoError.verificationFailed("NumiSeal lane proof is not covered by public statement")
            }
            aggregatesByLane[laneProof.laneKey, default: 0] += 1
            switch acceptedCarryMode {
            case .none:
                guard laneProof.optionalCarryClaim == nil else {
                    throw SuperNeoError.verificationFailed("NumiSeal carry claims are not accepted by policy")
                }
            case .optional:
                break
            case .required:
                guard laneProof.optionalCarryClaim != nil else {
                    throw SuperNeoError.verificationFailed("NumiSeal carry claim required by policy")
                }
            }
        }
        if let maximumAggregatesPerLane {
            for count in aggregatesByLane.values {
                guard count <= maximumAggregatesPerLane else {
                    throw SuperNeoError.verificationFailed("NumiSeal aggregate count exceeds policy maximum")
                }
            }
        }
    }

    private func validateLimits(totalByteCount: Int?) throws {
        if let maximumProofByteCount {
            guard maximumProofByteCount > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum proof byte count must be positive")
            }
            if let totalByteCount {
                guard totalByteCount <= maximumProofByteCount else {
                    throw SuperNeoError.verificationFailed("NumiSeal proof byte count exceeds policy maximum")
                }
            }
        }
        if let maximumLaneCount {
            guard maximumLaneCount > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum lane count must be positive")
            }
        }
        if let maximumAggregatesPerLane {
            guard maximumAggregatesPerLane > 0 else {
                throw SuperNeoError.invalidParameter("NumiSeal maximum aggregates per lane must be positive")
            }
        }
        switch acceptedResidualMode {
        case .immediate:
            break
        }
    }
}

public struct NumiSealProofEnvelope: Equatable, Sendable, SuperNeoByteEncodable {
    public let header: ProofEnvelopeHeader
    public let proof: NumiSealProof

    public init(context: ProofEnvelopeContext, proof: NumiSealProof) throws {
        guard context.kind == .numiSealTerminal else {
            throw SuperNeoError.invalidParameter("NumiSealProofEnvelope only supports numiSealTerminal kind")
        }
        let body = proof.superNeoBytes
        guard body.count <= Int(UInt32.max) else {
            throw SuperNeoError.invalidEncoding("NumiSeal proof body too large")
        }
        self.header = ProofEnvelopeHeader(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: context.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain,
            bodyLength: UInt32(body.count)
        )
        self.proof = proof
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let header = try ProofEnvelopeHeader.parsePrefix(from: bytes)
        try header.validateEnvelopeLength(totalByteCount: bytes.count)
        guard header.kind == .numiSealTerminal else {
            throw SuperNeoError.invalidEncoding("NumiSeal proof envelope kind mismatch")
        }
        _ = try reader.readData(count: ProofEnvelopeHeader.byteCount)
        let body = try reader.readData(count: Int(header.bodyLength))
        try reader.finish()
        self.header = header
        self.proof = try NumiSealProof(bytes: body, parameters: parameters)
    }

    public var superNeoBytes: [UInt8] {
        header.superNeoBytes + proof.superNeoBytes
    }
}

private enum NumiSealProofReaders {
    static func readSumcheckProof(from bytes: [UInt8]) throws -> SumcheckProof {
        var reader = ByteReader(bytes)
        let proof = try reader.readNumiSealSumcheckProof()
        try reader.finish()
        guard proof.superNeoBytes == bytes else {
            throw SuperNeoError.invalidEncoding("NumiSeal sum-check proof is not canonical")
        }
        return proof
    }
}

private extension ByteReader {
    mutating func readNumiSealProofComponentBytes(
        maximum: Int = NumiSealWireLimits.maximumProofComponentByteCount,
        name: String
    ) throws -> [UInt8] {
        let byteCount = try readCount(
            maximum: maximum,
            name: "\(name) byte",
            elementByteWidth: 1
        )
        guard byteCount > 0 else {
            throw SuperNeoError.invalidEncoding("\(name) cannot be empty")
        }
        return try readData(count: byteCount)
    }

    mutating func readNumiSealSumcheckProof() throws -> SumcheckProof {
        let claimedSum = try readNumiSealExt2()
        let roundCount = try readCount(maximum: 64, name: "NumiSeal sum-check round", elementByteWidth: 8)
        let rounds = try (0..<roundCount).map { _ -> SumcheckRound in
            let coeffCount = try readCount(
                maximum: 4096,
                name: "NumiSeal sum-check coefficient",
                elementByteWidth: 16
            )
            guard coeffCount > 0 else {
                throw SuperNeoError.invalidEncoding("NumiSeal sum-check round polynomial cannot be empty")
            }
            return SumcheckRound(coeffs: try (0..<coeffCount).map { _ in try readNumiSealExt2() })
        }
        let finalPointCount = try readCount(
            maximum: 64,
            name: "NumiSeal sum-check final point",
            elementByteWidth: 16
        )
        guard finalPointCount == roundCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal sum-check final point count must match round count")
        }
        let finalPoint = try (0..<finalPointCount).map { _ in try readNumiSealExt2() }
        let finalValue = try readNumiSealExt2()
        return SumcheckProof(
            claimedSum: claimedSum,
            rounds: rounds,
            finalPoint: finalPoint,
            finalValue: finalValue
        )
    }
}

private func numiSealFrame(_ bytes: [UInt8]) -> [UInt8] {
    numiSealEncodeCount(bytes.count) + bytes
}
