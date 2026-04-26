import CryptoKit
import Foundation

public struct Digest256: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public static let byteCount = 32
    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) throws {
        guard bytes.count == Self.byteCount else {
            throw SuperNeoError.invalidEncoding("Digest256 must be 32 bytes")
        }
        self.bytes = bytes
    }

    private init(unchecked bytes: [UInt8]) {
        precondition(bytes.count == Self.byteCount, "SHA-256 digest must be 32 bytes")
        self.bytes = bytes
    }

    public static func hash(_ bytes: [UInt8]) -> Self {
        let digest = SHA256.hash(data: Data(bytes))
        return Self(unchecked: Array(digest))
    }

    public static func hash(_ string: String) -> Self {
        hash(Array(string.utf8))
    }

    public var superNeoBytes: [UInt8] { bytes }

    public init(hexDigest raw: String, name: String = "digest") throws {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw SuperNeoError.invalidEncoding("\(name) must be a 64-character lowercase or uppercase hex digest")
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Self.byteCount)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<next], radix: 16) else {
                throw SuperNeoError.invalidEncoding("\(name) must be a valid hex digest")
            }
            bytes.append(byte)
            index = next
        }
        try self.init(bytes)
    }

    public var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

public enum ProofEnvelopeKind: UInt8, Equatable, Sendable {
    case foldReduction = 1
    case terminalLocal = 2
    case compressedPublic = 3
    case numiSealTerminal = 4
    case numiSealZK = 5
}

public struct ProofEnvelopeHeader: Equatable, Sendable, SuperNeoByteEncodable {
    public static let magic: UInt32 = 0x4E_55_4D_51
    public static let version: UInt16 = 5
    public static let byteCount = 141

    public let magic: UInt32
    public let version: UInt16
    public let profileID: UInt16
    public let kind: ProofEnvelopeKind
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let bodyLength: UInt32

    public init(
        profileID: UInt16,
        kind: ProofEnvelopeKind = .foldReduction,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1"),
        bodyLength: UInt32
    ) {
        self.magic = Self.magic
        self.version = Self.version
        self.profileID = profileID
        self.kind = kind
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.bodyLength = bodyLength
    }

    fileprivate init(
        magic: UInt32,
        version: UInt16,
        profileID: UInt16,
        kind: ProofEnvelopeKind,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        bodyLength: UInt32
    ) {
        self.magic = magic
        self.version = version
        self.profileID = profileID
        self.kind = kind
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.bodyLength = bodyLength
    }

    public var superNeoBytes: [UInt8] {
        encodeUInt32(magic)
            + encodeUInt16(version)
            + encodeUInt16(profileID)
            + encodeUInt8(kind.rawValue)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
            + encodeUInt32(bodyLength)
    }

    public var transcriptBindingBytes: [UInt8] {
        encodeUInt32(magic)
            + encodeUInt16(version)
            + encodeUInt16(profileID)
            + encodeUInt8(kind.rawValue)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
    }
}

public struct ProofEnvelopeContext: Equatable, Sendable {
    public let profileID: UInt16
    public let kind: ProofEnvelopeKind
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256

    public init(
        profileID: UInt16,
        kind: ProofEnvelopeKind = .foldReduction,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1")
    ) {
        self.profileID = profileID
        self.kind = kind
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
    }
}

/// Trusted context for accepting complete terminal proofs.
///
/// The policy gates accepted terminal proof kinds and compares the public
/// proof-envelope context through the 384-bit CTCO/H_bind context binder.
/// Applications still own artifact provenance, replay policy, key
/// distribution, and statement semantics.
public struct SuperNeoTerminalProofAcceptancePolicy: Equatable, Sendable {
    public enum ProofKindPolicy: Equatable, Sendable {
        case terminalOrCompressed
        case terminalOnly
        case compressedOnly

        public func accepts(_ kind: ProofEnvelopeKind) -> Bool {
            switch (self, kind) {
            case (.terminalOrCompressed, .terminalLocal),
                 (.terminalOrCompressed, .compressedPublic),
                 (.terminalOnly, .terminalLocal),
                 (.compressedOnly, .compressedPublic):
                return true
            case (.terminalOrCompressed, .foldReduction),
                 (.terminalOrCompressed, .numiSealTerminal),
                 (.terminalOrCompressed, .numiSealZK),
                 (.terminalOnly, .foldReduction),
                 (.terminalOnly, .numiSealTerminal),
                 (.terminalOnly, .numiSealZK),
                 (.terminalOnly, .compressedPublic),
                 (.compressedOnly, .foldReduction),
                 (.compressedOnly, .numiSealTerminal),
                 (.compressedOnly, .numiSealZK),
                 (.compressedOnly, .terminalLocal):
                return false
            }
        }
    }

    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let proofKindPolicy: ProofKindPolicy
    public let maximumProofByteCount: Int?

    public init(
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1"),
        proofKindPolicy: ProofKindPolicy = .terminalOrCompressed,
        maximumProofByteCount: Int? = nil
    ) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.proofKindPolicy = proofKindPolicy
        self.maximumProofByteCount = maximumProofByteCount
    }

    public init(
        statement: CCSStatement,
        verifierKeyDigest: Digest256,
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1"),
        proofKindPolicy: ProofKindPolicy = .terminalOrCompressed,
        maximumProofByteCount: Int? = nil
    ) {
        self.init(
            profileID: profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            proofKindPolicy: proofKindPolicy,
            maximumProofByteCount: maximumProofByteCount
        )
    }

    public init(
        publicInput: SuperNeoPublicFoldInput,
        verifierKeyDigest: Digest256,
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi81.profileID,
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1"),
        proofKindPolicy: ProofKindPolicy = .terminalOrCompressed,
        maximumProofByteCount: Int? = nil
    ) {
        self.init(
            statement: CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map { CEInstance($0) },
                recursiveRelationDigest: publicInput.recursiveRelationDigest
            ),
            verifierKeyDigest: verifierKeyDigest,
            profileID: profileID,
            transcriptDomain: transcriptDomain,
            proofKindPolicy: proofKindPolicy,
            maximumProofByteCount: maximumProofByteCount
        )
    }

    public func context(for header: ProofEnvelopeHeader, totalByteCount: Int) throws -> ProofEnvelopeContext {
        if let maximumProofByteCount {
            guard maximumProofByteCount > 0 else {
                throw SuperNeoError.invalidParameter("maximum proof byte count must be positive")
            }
            guard totalByteCount <= maximumProofByteCount else {
                throw SuperNeoError.verificationFailed("proof byte count exceeds policy maximum")
            }
        }
        try header.validateEnvelopeLength(totalByteCount: totalByteCount)
        guard header.kind != .foldReduction else {
            throw SuperNeoError.verificationFailed("terminal proof required")
        }
        guard proofKindPolicy.accepts(header.kind) else {
            throw SuperNeoError.verificationFailed("proof kind not accepted by policy")
        }
        let expectedContext = ProofEnvelopeContext(
            profileID: profileID,
            kind: header.kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
        guard header.ctcoContextBinder == expectedContext.ctcoContextBinder else {
            throw SuperNeoError.verificationFailed("proof envelope CTCO context binder mismatch")
        }
        return expectedContext
    }
}

public struct FoldProofEnvelope: Equatable, Sendable, SuperNeoByteEncodable {
    public typealias Kind = ProofEnvelopeKind

    public let header: ProofEnvelopeHeader
    public let proof: FoldProof
    private let bodyBytes: [UInt8]

    public init(context: ProofEnvelopeContext, proof: FoldProof) throws {
        guard context.kind == .foldReduction else {
            throw SuperNeoError.invalidParameter("FoldProofEnvelope only supports foldReduction kind")
        }
        let bodyBytes = proof.superNeoBytes
        guard bodyBytes.count <= Int(UInt32.max) else {
            throw SuperNeoError.invalidEncoding("proof body too large")
        }
        self.header = ProofEnvelopeHeader(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: context.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain,
            bodyLength: UInt32(bodyBytes.count)
        )
        self.proof = proof
        self.bodyBytes = bodyBytes
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let header = try reader.readProofEnvelopeHeader()
        try header.validate()
        guard header.kind == .foldReduction else {
            throw SuperNeoError.invalidEncoding("fold proof envelope kind mismatch")
        }
        let body = try reader.readData(count: Int(header.bodyLength))
        try reader.finish()

        var bodyReader = ByteReader(body)
        self.proof = try bodyReader.readFoldProof(parameters: parameters)
        try bodyReader.finish()
        self.header = header
        self.bodyBytes = body
    }

    public var superNeoBytes: [UInt8] {
        let headerBytes = header.superNeoBytes
        var bytes: [UInt8] = []
        bytes.reserveCapacity(headerBytes.count + bodyBytes.count)
        bytes.append(contentsOf: headerBytes)
        bytes.append(contentsOf: bodyBytes)
        return bytes
    }
}

public struct TerminalFoldProofEnvelope: Equatable, Sendable, SuperNeoByteEncodable {
    public typealias Kind = ProofEnvelopeKind

    public let header: ProofEnvelopeHeader
    public let proof: TerminalFoldProof
    private let bodyBytes: [UInt8]

    public init(context: ProofEnvelopeContext, proof: TerminalFoldProof) throws {
        guard context.kind == .terminalLocal else {
            throw SuperNeoError.invalidParameter("TerminalFoldProofEnvelope only supports terminalLocal kind")
        }
        guard proof.outputClaims == proof.foldProof.outputClaims else {
            throw SuperNeoError.invalidParameter("terminal CE statement must match fold proof output claims")
        }
        let bodyBytes = proof.superNeoBytes
        guard bodyBytes.count <= Int(UInt32.max) else {
            throw SuperNeoError.invalidEncoding("terminal proof body too large")
        }
        self.header = ProofEnvelopeHeader(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: context.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain,
            bodyLength: UInt32(bodyBytes.count)
        )
        self.proof = proof
        self.bodyBytes = bodyBytes
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let header = try reader.readProofEnvelopeHeader()
        try header.validate()
        guard header.kind == .terminalLocal else {
            throw SuperNeoError.invalidEncoding("terminal fold proof envelope kind mismatch")
        }
        let body = try reader.readData(count: Int(header.bodyLength))
        try reader.finish()

        var bodyReader = ByteReader(body)
        self.proof = try bodyReader.readTerminalFoldProof(parameters: parameters)
        try bodyReader.finish()
        self.header = header
        self.bodyBytes = body
    }

    public var superNeoBytes: [UInt8] {
        let headerBytes = header.superNeoBytes
        var bytes: [UInt8] = []
        bytes.reserveCapacity(headerBytes.count + bodyBytes.count)
        bytes.append(contentsOf: headerBytes)
        bytes.append(contentsOf: bodyBytes)
        return bytes
    }
}

public struct CompressedTerminalStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.compressed-public.statement.v1")

    public let context: ProofEnvelopeContext
    public let publicInputDigest: Digest256
    public let terminalStatementDigest: Digest256
    public let verifierKeyDigest: Digest256

    public init(
        context: ProofEnvelopeContext,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        verifierKeyDigest: Digest256
    ) {
        self.context = context
        self.publicInputDigest = publicInputDigest
        self.terminalStatementDigest = terminalStatementDigest
        self.verifierKeyDigest = verifierKeyDigest
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + encodeUInt16(context.profileID)
            + encodeUInt8(context.kind.rawValue)
            + context.shapeDigest.superNeoBytes
            + context.statementDigest.superNeoBytes
            + context.verifierKeyDigest.superNeoBytes
            + context.transcriptDomain.superNeoBytes
            + publicInputDigest.superNeoBytes
            + terminalStatementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
    }

    public var statementDigest: Digest256 {
        Digest256.hash(superNeoBytes)
    }
}

public struct CompressedTerminalProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let transcriptDomain = Digest256.hash("SuperNeo-NuMetal.compressed-public.proof.v2")

    public let statement: CompressedTerminalStatement
    public let foldProof: FoldProof
    public let ceOpeningProof: CEOpeningProof
    public let foldProofDigest: Digest256
    public let ceOpeningProofDigest: Digest256
    public let compressionDigest: Digest256

    public init(statement: CompressedTerminalStatement, foldProof: FoldProof, ceOpeningProof: CEOpeningProof) {
        let foldProofDigest = Digest256.hash(foldProof.superNeoBytes)
        let ceOpeningProofDigest = Digest256.hash(ceOpeningProof.superNeoBytes)
        self.statement = statement
        self.foldProof = foldProof
        self.ceOpeningProof = ceOpeningProof
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.compressionDigest = Self.makeCompressionDigest(
            statement: statement,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest
        )
    }

    fileprivate init(
        statement: CompressedTerminalStatement,
        foldProof: FoldProof,
        ceOpeningProof: CEOpeningProof,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        compressionDigest: Digest256
    ) throws {
        guard foldProofDigest == Digest256.hash(foldProof.superNeoBytes) else {
            throw SuperNeoError.invalidEncoding("compressed fold proof digest mismatch")
        }
        guard ceOpeningProofDigest == Digest256.hash(ceOpeningProof.superNeoBytes) else {
            throw SuperNeoError.invalidEncoding("compressed CE opening proof digest mismatch")
        }
        guard compressionDigest == Self.makeCompressionDigest(
            statement: statement,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest
        ) else {
            throw SuperNeoError.invalidEncoding("compressed terminal proof transcript mismatch")
        }
        self.statement = statement
        self.foldProof = foldProof
        self.ceOpeningProof = ceOpeningProof
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.compressionDigest = compressionDigest
    }

    public var superNeoBytes: [UInt8] {
        statement.superNeoBytes
            + foldProofDigest.superNeoBytes
            + ceOpeningProofDigest.superNeoBytes
            + compressionDigest.superNeoBytes
            + foldProof.superNeoBytes
            + ceOpeningProof.superNeoBytes
    }

    private static func makeCompressionDigest(
        statement: CompressedTerminalStatement,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256
    ) -> Digest256 {
        Digest256.hash(
            transcriptDomain.superNeoBytes
                + statement.statementDigest.superNeoBytes
                + foldProofDigest.superNeoBytes
                + ceOpeningProofDigest.superNeoBytes
        )
    }
}

public struct CompressedTerminalProofEnvelope: Equatable, Sendable, SuperNeoByteEncodable {
    public typealias Kind = ProofEnvelopeKind

    public let header: ProofEnvelopeHeader
    public let proof: CompressedTerminalProof
    private let bodyBytes: [UInt8]

    public init(context: ProofEnvelopeContext, proof: CompressedTerminalProof) throws {
        guard context.kind == .compressedPublic else {
            throw SuperNeoError.invalidParameter("CompressedTerminalProofEnvelope only supports compressedPublic kind")
        }
        guard proof.statement.context == context else {
            throw SuperNeoError.invalidParameter("compressed statement context mismatch")
        }
        let bodyBytes = proof.superNeoBytes
        guard bodyBytes.count <= Int(UInt32.max) else {
            throw SuperNeoError.invalidEncoding("compressed proof body too large")
        }
        self.header = ProofEnvelopeHeader(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: context.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain,
            bodyLength: UInt32(bodyBytes.count)
        )
        self.proof = proof
        self.bodyBytes = bodyBytes
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let header = try reader.readProofEnvelopeHeader()
        try header.validate()
        guard header.kind == .compressedPublic else {
            throw SuperNeoError.invalidEncoding("compressed terminal proof envelope kind mismatch")
        }
        let body = try reader.readData(count: Int(header.bodyLength))
        try reader.finish()

        var bodyReader = ByteReader(body)
        self.proof = try bodyReader.readCompressedTerminalProof(parameters: parameters)
        try bodyReader.finish()
        self.header = header
        self.bodyBytes = body
    }

    public var superNeoBytes: [UInt8] {
        let headerBytes = header.superNeoBytes
        var bytes: [UInt8] = []
        bytes.reserveCapacity(headerBytes.count + bodyBytes.count)
        bytes.append(contentsOf: headerBytes)
        bytes.append(contentsOf: bodyBytes)
        return bytes
    }
}

public protocol SuperNeoByteEncodable {
    var superNeoBytes: [UInt8] { get }
}

extension GoldilocksField: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] { littleEndianBytes }
}

extension GoldilocksExt2: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] { littleEndianBytes }
}

extension CyclotomicRing54: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] { littleEndianBytes }
}

extension CyclotomicExt2Ring54: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] { littleEndianBytes }
}

extension AjtaiCommitment: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] { littleEndianBytes }
}

extension DecompositionProof: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(commitments.count)
        for commitment in commitments {
            bytes.append(contentsOf: commitment.superNeoBytes)
        }
        bytes.append(contentsOf: encodeCount(evaluations.count))
        for evaluationBatch in evaluations {
            bytes.append(contentsOf: encodeCount(evaluationBatch.count))
            for evaluation in evaluationBatch {
                bytes.append(contentsOf: evaluation.superNeoBytes)
            }
        }
        return bytes
    }
}

extension PiCCSSection: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = sumCheck.superNeoBytes
        bytes.append(contentsOf: encodeCount(finalClaims.count))
        for claim in finalClaims {
            bytes.append(contentsOf: claim.superNeoBytes)
        }
        return bytes
    }
}

extension PiRLCSection: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(challenges.count)
        for challenge in challenges {
            bytes.append(contentsOf: challenge.superNeoBytes)
        }
        bytes.append(contentsOf: foldedClaim.superNeoBytes)
        return bytes
    }
}

extension PiDECSection: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = decomposition.superNeoBytes
        bytes.append(contentsOf: encodeCount(outputClaims.count))
        for claim in outputClaims {
            bytes.append(contentsOf: claim.superNeoBytes)
        }
        return bytes
    }
}

extension PiRLCBranch: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        piRLC.superNeoBytes + piDEC.superNeoBytes
    }
}

extension CCSEvaluationClaim: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = commitment.superNeoBytes
        bytes.append(contentsOf: encodeCount(publicInput.count))
        for value in publicInput {
            bytes.append(contentsOf: value.superNeoBytes)
        }
        bytes.append(contentsOf: encodeCount(point.count))
        for coordinate in point {
            bytes.append(contentsOf: coordinate.superNeoBytes)
        }
        bytes.append(contentsOf: encodeCount(evaluations.count))
        for evaluation in evaluations {
            bytes.append(contentsOf: evaluation.superNeoBytes)
        }
        return bytes
    }
}

extension CEOpeningStatement: SuperNeoByteEncodable {
    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        self = try reader.readCEOpeningStatement(parameters: parameters)
        try reader.finish()
    }

    public var superNeoBytes: [UInt8] {
        var bytes = encodeUInt16(profileID)
        bytes.append(contentsOf: shapeDigest.superNeoBytes)
        bytes.append(contentsOf: verifierKeyDigest.superNeoBytes)
        bytes.append(contentsOf: instance.superNeoBytes)
        return bytes
    }

    public var statementDigest: Digest256 {
        Digest256.hash(superNeoBytes)
    }
}

extension TerminalCEStatement: SuperNeoByteEncodable {
    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        self = try reader.readTerminalCEStatement(parameters: parameters)
        try reader.finish()
    }

    public var superNeoBytes: [UInt8] {
        var bytes = encodeUInt16(profileID)
        bytes.append(contentsOf: shapeDigest.superNeoBytes)
        bytes.append(contentsOf: verifierKeyDigest.superNeoBytes)
        bytes.append(contentsOf: encodeCount(openings.count))
        for opening in openings {
            bytes.append(contentsOf: opening.superNeoBytes)
        }
        return bytes
    }

    public var statementDigest: Digest256 {
        Digest256.hash(superNeoBytes)
    }
}

extension CEOpeningProofCommitments: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = maskLinearDigest.superNeoBytes
        bytes.append(contentsOf: permutedMaskDigest.superNeoBytes)
        bytes.append(contentsOf: permutedMaskedWitnessDigest.superNeoBytes)
        return bytes
    }
}

extension CEOpeningLinearResponse: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(permutation.count)
        for index in permutation {
            bytes.append(contentsOf: encodeSignedInt(index))
        }
        bytes.append(contentsOf: encodeCount(vector.count))
        for value in vector {
            bytes.append(contentsOf: value.superNeoBytes)
        }
        return bytes
    }
}

extension CEOpeningNormResponse: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(permutedMask.count)
        for value in permutedMask {
            bytes.append(contentsOf: value.superNeoBytes)
        }
        bytes.append(contentsOf: encodeCount(permutedWitness.count))
        for value in permutedWitness {
            bytes.append(contentsOf: value.superNeoBytes)
        }
        return bytes
    }
}

extension CEOpeningProofResponse: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        switch self {
        case .mask(let openings):
            return encodeCEOpeningResponse(tag: 0, openings: openings)
        case .maskedWitness(let openings):
            return encodeCEOpeningResponse(tag: 1, openings: openings)
        case .permutedWitness(let openings):
            return encodeCEOpeningResponse(tag: 2, openings: openings)
        }
    }
}

extension CEOpeningProofRound: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(commitments.count)
        for commitment in commitments {
            bytes.append(contentsOf: commitment.superNeoBytes)
        }
        bytes.append(contentsOf: response.superNeoBytes)
        return bytes
    }
}

extension CEOpeningProof: SuperNeoByteEncodable {
    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        self = try reader.readCEOpeningProof(parameters: parameters)
        try reader.finish()
    }

    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(rounds.count)
        for round in rounds {
            bytes.append(contentsOf: round.superNeoBytes)
        }
        return bytes
    }
}

extension TerminalFoldProof: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = foldProof.superNeoBytes
        bytes.append(contentsOf: terminalStatement.superNeoBytes)
        bytes.append(contentsOf: ceOpeningProof.superNeoBytes)
        return bytes
    }
}

extension FoldProof: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        var bytes = encodeCount(piCCSTapes.count)
        for tape in piCCSTapes {
            bytes.append(contentsOf: tape.superNeoBytes)
        }
        bytes.append(contentsOf: encodeCount(piRLCBranches.count))
        for branch in piRLCBranches {
            bytes.append(contentsOf: branch.superNeoBytes)
        }
        return bytes
    }
}

private func encodeCEOpeningResponse<T: SuperNeoByteEncodable>(tag: UInt8, openings: [T]) -> [UInt8] {
    var bytes = encodeUInt8(tag)
    bytes.append(contentsOf: encodeCount(openings.count))
    for opening in openings {
        bytes.append(contentsOf: opening.superNeoBytes)
    }
    return bytes
}

private func encodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func encodeSignedInt(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(bitPattern: Int64(value)).littleEndian, Array.init)
}

private func encodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func encodeUInt8(_ value: UInt8) -> [UInt8] {
    [value]
}

private func encodeUInt32(_ value: UInt32) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

public struct ByteReader {
    private let data: [UInt8]
    private var offset: Int

    public init(_ data: [UInt8]) {
        self.data = data
        self.offset = 0
    }

    public init(_ data: Data) {
        self.init(Array(data))
    }

    public mutating func readData(count: Int) throws -> [UInt8] {
        guard count >= 0, count <= data.count - offset else {
            throw SuperNeoError.invalidEncoding("unexpected end of proof bytes")
        }
        defer { offset += count }
        return Array(data[offset..<offset + count])
    }

    public mutating func readUInt16() throws -> UInt16 {
        let bytes = try readData(count: 2)
        return bytes.enumerated().reduce(UInt16(0)) { acc, pair in
            acc | (UInt16(pair.element) << UInt16(pair.offset * 8))
        }
    }

    public mutating func readUInt8() throws -> UInt8 {
        try readData(count: 1)[0]
    }

    public mutating func readUInt32() throws -> UInt32 {
        let bytes = try readData(count: 4)
        return bytes.enumerated().reduce(UInt32(0)) { acc, pair in
            acc | (UInt32(pair.element) << UInt32(pair.offset * 8))
        }
    }

    public mutating func readUInt64() throws -> UInt64 {
        let bytes = try readData(count: 8)
        return bytes.enumerated().reduce(UInt64(0)) { acc, pair in
            acc | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
    }

    public mutating func readCount(maximum: Int, name: String) throws -> Int {
        let raw = try readUInt64()
        guard raw <= UInt64(Int.max), Int(raw) <= maximum else {
            throw SuperNeoError.invalidEncoding("\(name) count exceeds canonical bound")
        }
        return Int(raw)
    }

    public mutating func readCount(maximum: Int, name: String, elementByteWidth: Int) throws -> Int {
        guard elementByteWidth > 0 else {
            throw SuperNeoError.invalidParameter("element byte width must be positive")
        }
        let count = try readCount(maximum: maximum, name: name)
        guard count <= remainingByteCount / elementByteWidth else {
            throw SuperNeoError.invalidEncoding("\(name) count exceeds remaining byte capacity")
        }
        return count
    }

    public var remainingByteCount: Int {
        data.count - offset
    }

    public mutating func finish() throws {
        guard offset == data.count else {
            throw SuperNeoError.invalidEncoding("trailing proof bytes")
        }
    }
}

extension ProofEnvelopeHeader {
    public static func parsePrefix(from bytes: [UInt8]) throws -> Self {
        guard bytes.count >= byteCount else {
            throw SuperNeoError.invalidEncoding("proof envelope is shorter than its header")
        }
        var reader = ByteReader(Array(bytes.prefix(byteCount)))
        let header = try reader.readProofEnvelopeHeader()
        try reader.finish()
        try header.validate()
        return header
    }

    public func validateEnvelopeLength(totalByteCount: Int) throws {
        guard totalByteCount >= Self.byteCount else {
            throw SuperNeoError.invalidEncoding("proof envelope is shorter than its header")
        }
        let expectedLength = Self.byteCount + Int(bodyLength)
        guard totalByteCount == expectedLength else {
            throw SuperNeoError.invalidEncoding("proof envelope body length mismatch")
        }
    }

    fileprivate func validate() throws {
        guard magic == Self.magic else { throw SuperNeoError.invalidEncoding("wrong proof magic") }
        guard version == Self.version else { throw SuperNeoError.invalidEncoding("unsupported proof version") }
    }
}

extension ByteReader {
    fileprivate mutating func readProofEnvelopeHeader() throws -> ProofEnvelopeHeader {
        let magic = try readUInt32()
        let version = try readUInt16()
        let profileID = try readUInt16()
        let kindRaw = try readUInt8()
        guard let kind = ProofEnvelopeKind(rawValue: kindRaw) else {
            throw SuperNeoError.invalidEncoding("unsupported proof kind")
        }
        let shapeDigest = try Digest256(readData(count: Digest256.byteCount))
        let statementDigest = try Digest256(readData(count: Digest256.byteCount))
        let verifierKeyDigest = try Digest256(readData(count: Digest256.byteCount))
        let transcriptDomain = try Digest256(readData(count: Digest256.byteCount))
        let bodyLength = try readUInt32()
        return ProofEnvelopeHeader(
            magic: magic,
            version: version,
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            bodyLength: bodyLength
        )
    }

    fileprivate mutating func readGoldilocksField() throws -> GoldilocksField {
        try GoldilocksField(littleEndianBytes: readData(count: 8)[...])
    }

    fileprivate mutating func readGoldilocksExt2() throws -> GoldilocksExt2 {
        try GoldilocksExt2(littleEndianBytes: readData(count: 16)[...])
    }

    fileprivate mutating func readRing() throws -> CyclotomicRing54 {
        try CyclotomicRing54(littleEndianBytes: readData(count: CyclotomicRing54.degree * 8))
    }

    fileprivate mutating func readExt2Ring() throws -> CyclotomicExt2Ring54 {
        try CyclotomicExt2Ring54(littleEndianBytes: readData(count: CyclotomicRing54.degree * 16))
    }

    fileprivate mutating func readCommitment(parameters: SuperNeoParameters) throws -> AjtaiCommitment {
        var elements: [CyclotomicRing54] = []
        elements.reserveCapacity(parameters.kappa)
        for _ in 0..<parameters.kappa {
            elements.append(try readRing())
        }
        return AjtaiCommitment(elements)
    }

    fileprivate mutating func readSumCheckProof() throws -> SumcheckProof {
        let claimedSum = try readGoldilocksExt2()
        let roundCount = try readCount(maximum: 64, name: "sum-check round", elementByteWidth: 8)
        let rounds = try (0..<roundCount).map { _ -> SumcheckRound in
            let coeffCount = try readCount(maximum: 4096, name: "sum-check coefficient", elementByteWidth: 16)
            guard coeffCount > 0 else {
                throw SuperNeoError.invalidEncoding("sum-check round polynomial cannot be empty")
            }
            return SumcheckRound(coeffs: try (0..<coeffCount).map { _ in try readGoldilocksExt2() })
        }
        let finalPointCount = try readCount(maximum: 64, name: "sum-check final point", elementByteWidth: 16)
        guard finalPointCount == roundCount else {
            throw SuperNeoError.invalidEncoding("sum-check final point count must match round count")
        }
        let finalPoint = try (0..<finalPointCount).map { _ in try readGoldilocksExt2() }
        let finalValue = try readGoldilocksExt2()
        return SumcheckProof(claimedSum: claimedSum, rounds: rounds, finalPoint: finalPoint, finalValue: finalValue)
    }

    fileprivate mutating func readDecompositionProof(parameters: SuperNeoParameters) throws -> DecompositionProof {
        let commitmentCount = try readCount(
            maximum: parameters.decompositionLength,
            name: "decomposition commitment",
            elementByteWidth: parameters.kappa * CyclotomicRing54.degree * 8
        )
        guard commitmentCount > 0 else {
            throw SuperNeoError.invalidEncoding("decomposition commitment count cannot be zero")
        }
        let commitments = try (0..<commitmentCount).map { _ in try readCommitment(parameters: parameters) }
        let evaluationRows = try readCount(maximum: parameters.decompositionLength, name: "decomposition evaluation", elementByteWidth: 8)
        guard evaluationRows == commitmentCount else {
            throw SuperNeoError.invalidEncoding("decomposition evaluation row count must match commitment count")
        }
        let evaluations = try (0..<evaluationRows).map { _ -> [CyclotomicExt2Ring54] in
            let count = try readCount(
                maximum: 1024,
                name: "decomposition evaluation column",
                elementByteWidth: CyclotomicRing54.degree * 16
            )
            guard count > 0 else {
                throw SuperNeoError.invalidEncoding("decomposition evaluation row cannot be empty")
            }
            return try (0..<count).map { _ in try readExt2Ring() }
        }
        return DecompositionProof(commitments: commitments, evaluations: evaluations)
    }

    fileprivate mutating func readEvaluationClaim(parameters: SuperNeoParameters) throws -> CCSEvaluationClaim {
        let commitment = try readCommitment(parameters: parameters)
        let publicInputCount = try readCount(maximum: 1 << 20, name: "public input", elementByteWidth: 8)
        let publicInput = try (0..<publicInputCount).map { _ in try readGoldilocksField() }
        let pointCount = try readCount(maximum: 64, name: "evaluation point", elementByteWidth: 16)
        let point = try (0..<pointCount).map { _ in try readGoldilocksExt2() }
        let evaluationCount = try readCount(
            maximum: 1024,
            name: "matrix evaluation",
            elementByteWidth: CyclotomicRing54.degree * 16
        )
        guard evaluationCount > 0 else {
            throw SuperNeoError.invalidEncoding("evaluation claim must contain matrix evaluations")
        }
        let evaluations = try (0..<evaluationCount).map { _ in try readExt2Ring() }
        return CCSEvaluationClaim(
            commitment: commitment,
            publicInput: publicInput,
            point: point,
            evaluations: evaluations,
            witness: nil
        )
    }

    fileprivate mutating func readCEOpeningStatement(parameters: SuperNeoParameters) throws -> CEOpeningStatement {
        let profileID = try readUInt16()
        let shapeDigest = try Digest256(readData(count: Digest256.byteCount))
        let verifierKeyDigest = try Digest256(readData(count: Digest256.byteCount))
        let instance = try readCEInstance(parameters: parameters)
        return CEOpeningStatement(
            profileID: profileID,
            shapeDigest: shapeDigest,
            verifierKeyDigest: verifierKeyDigest,
            instance: instance
        )
    }

    fileprivate mutating func readTerminalCEStatement(parameters: SuperNeoParameters) throws -> TerminalCEStatement {
        let profileID = try readUInt16()
        let shapeDigest = try Digest256(readData(count: Digest256.byteCount))
        let verifierKeyDigest = try Digest256(readData(count: Digest256.byteCount))
        let openingCount = try readCount(
            maximum: parameters.decompositionLength,
            name: "terminal CE opening",
            elementByteWidth: 2 + (2 * Digest256.byteCount)
        )
        guard openingCount > 0 else {
            throw SuperNeoError.invalidEncoding("terminal CE statement cannot be empty")
        }
        let openings = try (0..<openingCount).map { _ in
            try readCEOpeningStatement(parameters: parameters)
        }
        return try TerminalCEStatement(
            profileID: profileID,
            shapeDigest: shapeDigest,
            verifierKeyDigest: verifierKeyDigest,
            openings: openings
        )
    }

    fileprivate mutating func readPiCCSSection(parameters: SuperNeoParameters) throws -> PiCCSSection {
        let sumCheck = try readSumCheckProof()
        let piCCSCount = try readCount(
            maximum: parameters.maxFreshBatchCount + parameters.maxPriorClaimCount,
            name: "PiCCS final claim",
            elementByteWidth: parameters.kappa * CyclotomicRing54.degree * 8
        )
        let piCCSClaims = try (0..<piCCSCount).map { _ in try readEvaluationClaim(parameters: parameters) }
        return PiCCSSection(sumCheck: sumCheck, finalClaims: piCCSClaims)
    }

    fileprivate mutating func readPiRLCSection(
        expectedChallengeCount: Int,
        parameters: SuperNeoParameters
    ) throws -> PiRLCSection {
        let rlcCount = try readCount(
            maximum: parameters.maxFreshBatchCount + parameters.maxPriorClaimCount,
            name: "random-linear-combination challenge",
            elementByteWidth: CyclotomicRing54.degree * 8
        )
        guard expectedChallengeCount == rlcCount else {
            throw SuperNeoError.invalidEncoding("PiCCS final claim count must match RLC challenge count")
        }
        let randomLinearCombinationChallenges = try (0..<rlcCount).map { _ in try readRing() }
        let foldedClaim = try readEvaluationClaim(parameters: parameters)
        return PiRLCSection(challenges: randomLinearCombinationChallenges, foldedClaim: foldedClaim)
    }

    fileprivate mutating func readPiDECSection(parameters: SuperNeoParameters) throws -> PiDECSection {
        let decomposition = try readDecompositionProof(parameters: parameters)
        let outputCount = try readCount(
            maximum: parameters.decompositionLength,
            name: "output claim",
            elementByteWidth: parameters.kappa * CyclotomicRing54.degree * 8
        )
        guard outputCount > 0 else {
            throw SuperNeoError.invalidEncoding("output claim count cannot be zero")
        }
        guard outputCount == decomposition.commitments.count,
              outputCount == decomposition.evaluations.count else {
            throw SuperNeoError.invalidEncoding("output claim count must match decomposition proof count")
        }
        let outputClaims = try (0..<outputCount).map { _ in try readEvaluationClaim(parameters: parameters) }
        guard decomposition.commitments == outputClaims.map(\.commitment) else {
            throw SuperNeoError.invalidEncoding("decomposition commitments must match output claims")
        }
        guard decomposition.evaluations == outputClaims.map(\.evaluations) else {
            throw SuperNeoError.invalidEncoding("decomposition evaluations must match output claims")
        }
        return PiDECSection(decomposition: decomposition, outputClaims: outputClaims)
    }

    fileprivate mutating func readCEOpeningProof(parameters: SuperNeoParameters) throws -> CEOpeningProof {
        let roundCount = try readCount(
            maximum: CEOpeningProof.roundCount,
            name: "CE opening proof round",
            elementByteWidth: Digest256.byteCount * 3
        )
        guard roundCount == CEOpeningProof.roundCount else {
            throw SuperNeoError.invalidEncoding("wrong CE opening proof round count")
        }
        let rounds = try (0..<roundCount).map { _ in
            try readCEOpeningProofRound(parameters: parameters)
        }
        return try CEOpeningProof(rounds: rounds)
    }

    private mutating func readCEOpeningProofRound(parameters: SuperNeoParameters) throws -> CEOpeningProofRound {
        let commitmentCount = try readCount(
            maximum: parameters.decompositionLength,
            name: "CE opening commitment",
            elementByteWidth: Digest256.byteCount * 3
        )
        guard commitmentCount > 0 else {
            throw SuperNeoError.invalidEncoding("CE opening proof round cannot be empty")
        }
        let commitments = try (0..<commitmentCount).map { _ in
            CEOpeningProofCommitments(
                maskLinearDigest: try Digest256(readData(count: Digest256.byteCount)),
                permutedMaskDigest: try Digest256(readData(count: Digest256.byteCount)),
                permutedMaskedWitnessDigest: try Digest256(readData(count: Digest256.byteCount))
            )
        }
        let response = try readCEOpeningProofResponse(expectedCount: commitmentCount)
        return CEOpeningProofRound(commitments: commitments, response: response)
    }

    private mutating func readCEOpeningProofResponse(expectedCount: Int) throws -> CEOpeningProofResponse {
        let tag = try readUInt8()
        let count = try readCount(maximum: expectedCount, name: "CE opening response", elementByteWidth: 8)
        guard count == expectedCount else {
            throw SuperNeoError.invalidEncoding("CE opening response count mismatch")
        }
        switch tag {
        case 0:
            return .mask(try (0..<count).map { _ in try readCEOpeningLinearResponse() })
        case 1:
            return .maskedWitness(try (0..<count).map { _ in try readCEOpeningLinearResponse() })
        case 2:
            return .permutedWitness(try (0..<count).map { _ in try readCEOpeningNormResponse() })
        default:
            throw SuperNeoError.invalidEncoding("unsupported CE opening response challenge")
        }
    }

    private mutating func readCEOpeningLinearResponse() throws -> CEOpeningLinearResponse {
        let permutationCount = try readCount(maximum: 1 << 20, name: "CE opening permutation", elementByteWidth: 8)
        let permutation = try (0..<permutationCount).map { _ -> Int in
            let raw = try readUInt64()
            guard raw <= UInt64(Int.max) else {
                throw SuperNeoError.invalidEncoding("CE opening permutation index exceeds Int")
            }
            return Int(raw)
        }
        let vectorCount = try readCount(maximum: permutationCount, name: "CE opening linear response", elementByteWidth: 8)
        guard vectorCount == permutationCount else {
            throw SuperNeoError.invalidEncoding("CE opening linear response length mismatch")
        }
        let vector = try (0..<vectorCount).map { _ in try readGoldilocksField() }
        return CEOpeningLinearResponse(permutation: permutation, vector: vector)
    }

    private mutating func readCEOpeningNormResponse() throws -> CEOpeningNormResponse {
        let maskCount = try readCount(maximum: 1 << 20, name: "CE opening permuted mask", elementByteWidth: 8)
        let permutedMask = try (0..<maskCount).map { _ in try readGoldilocksField() }
        let witnessCount = try readCount(maximum: maskCount, name: "CE opening permuted witness", elementByteWidth: 8)
        guard witnessCount == maskCount else {
            throw SuperNeoError.invalidEncoding("CE opening norm response length mismatch")
        }
        let permutedWitness = try (0..<witnessCount).map { _ in try readGoldilocksField() }
        return CEOpeningNormResponse(permutedMask: permutedMask, permutedWitness: permutedWitness)
    }

    fileprivate mutating func readFoldProof(parameters: SuperNeoParameters) throws -> FoldProof {
        let piCCSTapeCount = try readCount(
            maximum: FoldProof.selectedPiCCSTapeCount,
            name: "PiCCS repeated tape",
            elementByteWidth: 16
        )
        guard piCCSTapeCount == FoldProof.selectedPiCCSTapeCount else {
            throw SuperNeoError.invalidEncoding("wrong PiCCS repeated tape count")
        }
        let piCCSTapes = try (0..<piCCSTapeCount).map { _ in
            try readPiCCSSection(parameters: parameters)
        }
        guard let canonicalPiCCS = piCCSTapes.first else {
            throw SuperNeoError.invalidEncoding("missing canonical PiCCS tape")
        }
        let piRLCBranchCount = try readCount(
            maximum: FoldProof.selectedPiRLCBranchCount,
            name: "PiRLC repeated branch",
            elementByteWidth: CyclotomicRing54.degree * 8
        )
        guard piRLCBranchCount == FoldProof.selectedPiRLCBranchCount else {
            throw SuperNeoError.invalidEncoding("wrong PiRLC repeated branch count")
        }
        let piRLCBranches = try (0..<piRLCBranchCount).map { _ -> PiRLCBranch in
            let piRLC = try readPiRLCSection(
                expectedChallengeCount: canonicalPiCCS.finalClaims.count,
                parameters: parameters
            )
            let piDEC = try readPiDECSection(parameters: parameters)
            return PiRLCBranch(piRLC: piRLC, piDEC: piDEC)
        }
        guard let canonicalBranch = piRLCBranches.first else {
            throw SuperNeoError.invalidEncoding("missing canonical PiRLC branch")
        }
        return FoldProof(
            piCCS: canonicalPiCCS,
            piRLC: canonicalBranch.piRLC,
            piDEC: canonicalBranch.piDEC,
            auxiliaryPiCCSTapes: Array(piCCSTapes.dropFirst()),
            auxiliaryPiRLCBranches: Array(piRLCBranches.dropFirst())
        )
    }

    fileprivate mutating func readTerminalFoldProof(parameters: SuperNeoParameters) throws -> TerminalFoldProof {
        let foldProof = try readFoldProof(parameters: parameters)
        let terminalStatement = try readTerminalCEStatement(parameters: parameters)
        guard terminalStatement.openings.count == foldProof.outputClaims.count else {
            throw SuperNeoError.invalidEncoding("terminal CE statement output count must match fold proof output count")
        }
        guard terminalStatement.outputClaims == foldProof.outputClaims else {
            throw SuperNeoError.invalidEncoding("terminal CE statement must match fold proof output claims")
        }
        let ceOpeningProof = try readCEOpeningProof(parameters: parameters)
        return TerminalFoldProof(
            foldProof: foldProof,
            terminalStatement: terminalStatement,
            ceOpeningProof: ceOpeningProof
        )
    }

    fileprivate mutating func readCompressedTerminalStatement() throws -> CompressedTerminalStatement {
        let domain = try Digest256(readData(count: Digest256.byteCount))
        guard domain == CompressedTerminalStatement.domain else {
            throw SuperNeoError.invalidEncoding("compressed terminal statement domain mismatch")
        }
        let profileID = try readUInt16()
        let kindRaw = try readUInt8()
        guard let kind = ProofEnvelopeKind(rawValue: kindRaw) else {
            throw SuperNeoError.invalidEncoding("unsupported compressed statement proof kind")
        }
        let context = try ProofEnvelopeContext(
            profileID: profileID,
            kind: kind,
            shapeDigest: Digest256(readData(count: Digest256.byteCount)),
            statementDigest: Digest256(readData(count: Digest256.byteCount)),
            verifierKeyDigest: Digest256(readData(count: Digest256.byteCount)),
            transcriptDomain: Digest256(readData(count: Digest256.byteCount))
        )
        return try CompressedTerminalStatement(
            context: context,
            publicInputDigest: Digest256(readData(count: Digest256.byteCount)),
            terminalStatementDigest: Digest256(readData(count: Digest256.byteCount)),
            verifierKeyDigest: Digest256(readData(count: Digest256.byteCount))
        )
    }

    fileprivate mutating func readCompressedTerminalProof(parameters: SuperNeoParameters) throws -> CompressedTerminalProof {
        let statement = try readCompressedTerminalStatement()
        let foldProofDigest = try Digest256(readData(count: Digest256.byteCount))
        let ceOpeningProofDigest = try Digest256(readData(count: Digest256.byteCount))
        let compressionDigest = try Digest256(readData(count: Digest256.byteCount))
        let foldProof = try readFoldProof(parameters: parameters)
        let ceOpeningProof = try readCEOpeningProof(parameters: parameters)
        return try CompressedTerminalProof(
            statement: statement,
            foldProof: foldProof,
            ceOpeningProof: ceOpeningProof,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            compressionDigest: compressionDigest
        )
    }
}
