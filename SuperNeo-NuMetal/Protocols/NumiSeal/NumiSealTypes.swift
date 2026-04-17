import Foundation

public struct NumiSealLaneID: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public static let maximumByteCount = 128

    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) throws {
        guard !bytes.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal lane ID cannot be empty")
        }
        guard bytes.count <= Self.maximumByteCount else {
            throw SuperNeoError.invalidParameter("NumiSeal lane ID is too long")
        }
        self.bytes = bytes
    }

    public init(_ label: String) throws {
        try self.init(Array(label.utf8))
    }

    public var superNeoBytes: [UInt8] {
        numiSealEncodeCount(bytes.count) + bytes
    }
}

public struct NumiSealLaneKey: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let evalPointDigest: Digest256
    public let laneID: NumiSealLaneID

    public init(
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        evalPointDigest: Digest256,
        laneID: NumiSealLaneID
    ) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.evalPointDigest = evalPointDigest
        self.laneID = laneID
    }

    public var superNeoBytes: [UInt8] {
        numiSealEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + evalPointDigest.superNeoBytes
            + laneID.superNeoBytes
    }
}

public struct NumiSealAggregateKey: Equatable, Hashable, Sendable {
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int

    public init(laneKey: NumiSealLaneKey, aggregateIndex: Int) throws {
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate key index must be non-negative")
        }
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
    }
}

public struct NumiSealAcceptancePolicy: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let acceptedLaneIDs: Set<NumiSealLaneID>
    public let maximumProofByteCount: Int?

    public init(
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = Digest256.hash("SuperNeo-NuMetal.numiseal.v1"),
        acceptedLaneIDs: Set<NumiSealLaneID>,
        maximumProofByteCount: Int? = nil
    ) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.acceptedLaneIDs = acceptedLaneIDs
        self.maximumProofByteCount = maximumProofByteCount
    }

    public init(
        statement: CCSStatement,
        verifierKeyDigest: Digest256,
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        transcriptDomain: Digest256 = Digest256.hash("SuperNeo-NuMetal.numiseal.v1"),
        acceptedLaneIDs: Set<NumiSealLaneID>,
        maximumProofByteCount: Int? = nil
    ) {
        self.init(
            profileID: profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            acceptedLaneIDs: acceptedLaneIDs,
            maximumProofByteCount: maximumProofByteCount
        )
    }
}

public struct NumiSealObligation: Equatable, Sendable, SuperNeoByteEncodable {
    public let laneID: NumiSealLaneID
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let commitment: AjtaiCommitment
    public let publicInputEncoding: PublicInputEncoding
    public let evalPoint: [GoldilocksExt2]
    public let matrixEvaluations: [CyclotomicExt2Ring54]
    public let sourceFoldDigest: Digest256

    public var publicInput: [GoldilocksField] { publicInputEncoding.field }

    public init(
        laneID: NumiSealLaneID,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        commitment: AjtaiCommitment,
        publicInputEncoding: PublicInputEncoding,
        evalPoint: [GoldilocksExt2],
        matrixEvaluations: [CyclotomicExt2Ring54],
        sourceFoldDigest: Digest256
    ) {
        self.laneID = laneID
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.commitment = commitment
        self.publicInputEncoding = publicInputEncoding
        self.evalPoint = evalPoint
        self.matrixEvaluations = matrixEvaluations
        self.sourceFoldDigest = sourceFoldDigest
    }

    public init(
        laneID: NumiSealLaneID,
        profileID: UInt16,
        statement: CCSStatement,
        verifierKeyDigest: Digest256,
        instance: CEInstance,
        sourceFoldDigest: Digest256
    ) {
        self.init(
            laneID: laneID,
            profileID: profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            commitment: instance.commitment,
            publicInputEncoding: instance.publicInputEncoding,
            evalPoint: instance.evalPoint,
            matrixEvaluations: instance.matrixEvals,
            sourceFoldDigest: sourceFoldDigest
        )
    }

    public var superNeoBytes: [UInt8] {
        laneID.superNeoBytes
            + numiSealEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + commitment.superNeoBytes
            + publicInputEncoding.superNeoBytes
            + numiSealEncodeCount(evalPoint.count)
            + evalPoint.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(matrixEvaluations.count)
            + matrixEvaluations.flatMap(\.superNeoBytes)
            + sourceFoldDigest.superNeoBytes
    }
}

public struct NumiSealCanonicalObligation: Equatable, Sendable {
    public let obligation: NumiSealObligation
    public let laneKey: NumiSealLaneKey
    public let obligationDigest: Digest256

    public init(
        obligation: NumiSealObligation,
        laneKey: NumiSealLaneKey,
        obligationDigest: Digest256
    ) {
        self.obligation = obligation
        self.laneKey = laneKey
        self.obligationDigest = obligationDigest
    }
}

public struct NumiSealLaneSummary: Equatable, Sendable, SuperNeoByteEncodable {
    public let laneKey: NumiSealLaneKey
    public let obligationCount: Int
    public let laneObligationRoot: Digest256
    public let laneSummaryDigest: Digest256

    public init(
        laneKey: NumiSealLaneKey,
        obligationCount: Int,
        laneObligationRoot: Digest256,
        laneSummaryDigest: Digest256
    ) {
        self.laneKey = laneKey
        self.obligationCount = obligationCount
        self.laneObligationRoot = laneObligationRoot
        self.laneSummaryDigest = laneSummaryDigest
    }

    public var superNeoBytes: [UInt8] {
        laneKey.superNeoBytes
            + numiSealEncodeCount(obligationCount)
            + laneObligationRoot.superNeoBytes
            + laneSummaryDigest.superNeoBytes
    }
}

public struct NumiSealCanonicalizationResult: Equatable, Sendable {
    public let obligations: [NumiSealCanonicalObligation]
    public let laneSummaries: [NumiSealLaneSummary]
    public let obligationRoot: Digest256
    public let laneSummaryRoot: Digest256

    public init(
        obligations: [NumiSealCanonicalObligation],
        laneSummaries: [NumiSealLaneSummary],
        obligationRoot: Digest256,
        laneSummaryRoot: Digest256
    ) {
        self.obligations = obligations
        self.laneSummaries = laneSummaries
        self.obligationRoot = obligationRoot
        self.laneSummaryRoot = laneSummaryRoot
    }
}

enum NumiSealEncoding {
    static func digest(label: String, bytes: [UInt8]) -> Digest256 {
        Digest256.hash(numiSealEncodeString(label) + bytes)
    }

    static func root(label: String, leaves: [Digest256]) -> Digest256 {
        digest(
            label: label,
            bytes: numiSealEncodeCount(leaves.count) + leaves.flatMap(\.superNeoBytes)
        )
    }
}

func numiSealEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

func numiSealEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

func numiSealEncodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return numiSealEncodeCount(bytes.count) + bytes
}
