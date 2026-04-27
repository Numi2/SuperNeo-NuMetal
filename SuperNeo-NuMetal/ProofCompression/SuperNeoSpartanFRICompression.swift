import Foundation

public struct SuperNeoSpartanFRICompressionStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.spartan-fri-compression.statement.v1")

    public let sourceProofKind: ProofEnvelopeKind
    public let sourceProofByteCount: Int
    public let sourceProofDigest: Digest256
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let publicInputDigest: Digest256
    public let terminalStatementDigest: Digest256
    public let foldProofDigest: Digest256
    public let ceOpeningProofDigest: Digest256
    public let statementCompressionDigest: Digest256

    public init(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256
    ) throws {
        guard sourceProofKind == .terminalLocal || sourceProofKind == .compressedPublic else {
            throw SuperNeoError.invalidParameter("Spartan/FRI compression only accepts terminal proof sources")
        }
        guard sourceProofByteCount > 0 else {
            throw SuperNeoError.invalidParameter("Spartan/FRI compression source byte count must be positive")
        }
        self.sourceProofKind = sourceProofKind
        self.sourceProofByteCount = sourceProofByteCount
        self.sourceProofDigest = sourceProofDigest
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.publicInputDigest = publicInputDigest
        self.terminalStatementDigest = terminalStatementDigest
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.statementCompressionDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    sourceProofKind: sourceProofKind,
                    sourceProofByteCount: sourceProofByteCount,
                    sourceProofDigest: sourceProofDigest,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain,
                    publicInputDigest: publicInputDigest,
                    terminalStatementDigest: terminalStatementDigest,
                    foldProofDigest: foldProofDigest,
                    ceOpeningProofDigest: ceOpeningProofDigest
                )
        )
    }

    fileprivate init(
        uncheckedSourceProofKind sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256
    ) {
        self.sourceProofKind = sourceProofKind
        self.sourceProofByteCount = sourceProofByteCount
        self.sourceProofDigest = sourceProofDigest
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.publicInputDigest = publicInputDigest
        self.terminalStatementDigest = terminalStatementDigest
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.statementCompressionDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    sourceProofKind: sourceProofKind,
                    sourceProofByteCount: sourceProofByteCount,
                    sourceProofDigest: sourceProofDigest,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain,
                    publicInputDigest: publicInputDigest,
                    terminalStatementDigest: terminalStatementDigest,
                    foldProofDigest: foldProofDigest,
                    ceOpeningProofDigest: ceOpeningProofDigest
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                sourceProofKind: sourceProofKind,
                sourceProofByteCount: sourceProofByteCount,
                sourceProofDigest: sourceProofDigest,
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                publicInputDigest: publicInputDigest,
                terminalStatementDigest: terminalStatementDigest,
                foldProofDigest: foldProofDigest,
                ceOpeningProofDigest: ceOpeningProofDigest
            )
            + statementCompressionDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        statementCompressionDigest == Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    sourceProofKind: sourceProofKind,
                    sourceProofByteCount: sourceProofByteCount,
                    sourceProofDigest: sourceProofDigest,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain,
                    publicInputDigest: publicInputDigest,
                    terminalStatementDigest: terminalStatementDigest,
                    foldProofDigest: foldProofDigest,
                    ceOpeningProofDigest: ceOpeningProofDigest
                )
        )
    }

    private static func bodyBytes(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256
    ) -> [UInt8] {
        [sourceProofKind.rawValue]
            + spartanFRIEncodeCount(sourceProofByteCount)
            + sourceProofDigest.superNeoBytes
            + spartanFRIEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
            + publicInputDigest.superNeoBytes
            + terminalStatementDigest.superNeoBytes
            + foldProofDigest.superNeoBytes
            + ceOpeningProofDigest.superNeoBytes
    }
}

public struct SuperNeoFRICommitment: Equatable, Sendable, SuperNeoByteEncodable {
    public let domainSize: Int
    public let root: Digest384

    public init(domainSize: Int, root: Digest384) {
        self.domainSize = domainSize
        self.root = root
    }

    public var superNeoBytes: [UInt8] {
        spartanFRIEncodeCount(domainSize) + root.superNeoBytes
    }
}

public struct SuperNeoFRIMerkleSibling: Equatable, Sendable, SuperNeoByteEncodable {
    public enum Position: UInt8, Equatable, Sendable {
        case left = 0
        case right = 1
    }

    public let position: Position
    public let digest: Digest384

    public init(position: Position, digest: Digest384) {
        self.position = position
        self.digest = digest
    }

    public var superNeoBytes: [UInt8] {
        [position.rawValue] + digest.superNeoBytes
    }
}

public struct SuperNeoFRIMerkleOpening: Equatable, Sendable, SuperNeoByteEncodable {
    public let index: Int
    public let leafCount: Int
    public let point: GoldilocksField
    public let value: GoldilocksField
    public let siblings: [SuperNeoFRIMerkleSibling]

    public init(
        index: Int,
        leafCount: Int,
        point: GoldilocksField = .zero,
        value: GoldilocksField,
        siblings: [SuperNeoFRIMerkleSibling]
    ) {
        self.index = index
        self.leafCount = leafCount
        self.point = point
        self.value = value
        self.siblings = siblings
    }

    public var superNeoBytes: [UInt8] {
        spartanFRIEncodeCount(index)
            + spartanFRIEncodeCount(leafCount)
            + point.superNeoBytes
            + value.superNeoBytes
            + spartanFRIEncodeCount(siblings.count)
            + siblings.flatMap(\.superNeoBytes)
    }

    public func verifies(root: Digest384, domain: String) -> Bool {
        guard index >= 0, index < leafCount else { return false }
        let leafDomain = "\(domain)/leaf"
        let nodeDomain = "\(domain)/node"
        var digest = spartanFRILeafDigest(
            leafDomain: leafDomain,
            index: index,
            leafCount: leafCount,
            point: point,
            value: value
        )
        for sibling in siblings {
            switch sibling.position {
            case .left:
                digest = SuperNeoSplitQRO.hBind(domain: nodeDomain, frames: [sibling.digest.superNeoBytes, digest.superNeoBytes])
            case .right:
                digest = SuperNeoSplitQRO.hBind(domain: nodeDomain, frames: [digest.superNeoBytes, sibling.digest.superNeoBytes])
            }
        }
        return digest == root
    }
}

public struct SuperNeoFRIQueryProof: Equatable, Sendable, SuperNeoByteEncodable {
    public let initialIndex: Int
    public let layerOpenings: [[SuperNeoFRIMerkleOpening]]

    public init(initialIndex: Int, layerOpenings: [[SuperNeoFRIMerkleOpening]]) {
        self.initialIndex = initialIndex
        self.layerOpenings = layerOpenings
    }

    public var superNeoBytes: [UInt8] {
        spartanFRIEncodeCount(initialIndex)
            + spartanFRIEncodeCount(layerOpenings.count)
            + layerOpenings.flatMap { openings in
                spartanFRIEncodeCount(openings.count) + openings.flatMap(\.superNeoBytes)
            }
    }
}

public struct SuperNeoFRIProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.fri-style-pcs.v1")

    public let vectorLength: Int
    public let paddedDomainSize: Int
    public let queryCount: Int
    public let blowupFactor: Int
    public let claimedDegreeBound: Int
    public let domainRoot: GoldilocksField
    public let cosetGenerator: GoldilocksField
    public let baseCommitment: SuperNeoFRICommitment
    public let foldedCommitments: [SuperNeoFRICommitment]
    public let foldingChallenges: [GoldilocksField]
    public let queryProofs: [SuperNeoFRIQueryProof]
    public let finalPolynomial: [GoldilocksField]
    public let proofDigest: Digest384

    public init(
        vectorLength: Int,
        paddedDomainSize: Int,
        queryCount: Int,
        blowupFactor: Int = 1,
        claimedDegreeBound: Int = 0,
        domainRoot: GoldilocksField = .one,
        cosetGenerator: GoldilocksField = .one,
        baseCommitment: SuperNeoFRICommitment,
        foldedCommitments: [SuperNeoFRICommitment],
        foldingChallenges: [GoldilocksField],
        queryProofs: [SuperNeoFRIQueryProof],
        finalPolynomial: [GoldilocksField] = []
    ) throws {
        guard vectorLength > 0 else {
            throw SuperNeoError.invalidParameter("FRI vector length must be positive")
        }
        guard paddedDomainSize > 0, paddedDomainSize.nonzeroBitCount == 1 else {
            throw SuperNeoError.invalidParameter("FRI domain size must be a power of two")
        }
        guard vectorLength <= paddedDomainSize else {
            throw SuperNeoError.invalidParameter("FRI vector length exceeds padded domain")
        }
        guard blowupFactor > 0 else {
            throw SuperNeoError.invalidParameter("FRI blowup factor must be positive")
        }
        let resolvedDegreeBound = claimedDegreeBound == 0 ? vectorLength : claimedDegreeBound
        guard resolvedDegreeBound > 0, resolvedDegreeBound <= vectorLength else {
            throw SuperNeoError.invalidParameter("FRI claimed degree bound is invalid")
        }
        guard paddedDomainSize / blowupFactor >= resolvedDegreeBound else {
            throw SuperNeoError.invalidParameter("FRI domain is smaller than claimed degree times blowup")
        }
        guard cosetGenerator != .zero else {
            throw SuperNeoError.invalidParameter("FRI coset generator must be nonzero")
        }
        guard domainRoot.pow(UInt64(paddedDomainSize)) == .one,
              paddedDomainSize == 1 || domainRoot.pow(UInt64(paddedDomainSize / 2)) != .one else {
            throw SuperNeoError.invalidParameter("FRI domain root does not have exact padded order")
        }
        let resolvedFinalPolynomial = finalPolynomial.isEmpty ? [.zero] : finalPolynomial
        guard resolvedFinalPolynomial.count == 1 else {
            throw SuperNeoError.invalidParameter("FRI final polynomial must be constant")
        }
        guard queryCount > 0 else {
            throw SuperNeoError.invalidParameter("FRI query count must be positive")
        }
        guard queryCount <= paddedDomainSize else {
            throw SuperNeoError.invalidParameter("FRI query count exceeds padded domain")
        }
        let queryDomainSize = max(1, paddedDomainSize / 2)
        guard queryCount <= queryDomainSize else {
            throw SuperNeoError.invalidParameter("FRI query count exceeds folded pair domain")
        }
        guard queryProofs.count == queryCount else {
            throw SuperNeoError.invalidParameter("FRI query proof count mismatch")
        }
        guard foldingChallenges.count == foldedCommitments.count else {
            throw SuperNeoError.invalidParameter("FRI challenge count mismatch")
        }
        guard foldedCommitments.count == spartanFRIFoldingRoundCount(forDegreeBound: resolvedDegreeBound) else {
            throw SuperNeoError.invalidParameter("FRI folding round count does not match claimed degree bound")
        }
        let commitments = [baseCommitment] + foldedCommitments
        guard commitments.first?.domainSize == paddedDomainSize else {
            throw SuperNeoError.invalidParameter("FRI commitment domain chain mismatch")
        }
        for round in 0..<(commitments.count - 1) {
            guard commitments[round].domainSize == commitments[round + 1].domainSize * 2 else {
                throw SuperNeoError.invalidParameter("FRI commitment domain chain mismatch")
            }
        }
        var terminalDegreeBound = resolvedDegreeBound
        for _ in foldedCommitments.indices {
            terminalDegreeBound = max(1, (terminalDegreeBound + 1) / 2)
        }
        guard terminalDegreeBound == 1 else {
            throw SuperNeoError.invalidParameter("FRI final layer does not reach a constant degree bound")
        }
        guard queryProofs.allSatisfy({ $0.initialIndex >= 0 && $0.initialIndex < queryDomainSize }) else {
            throw SuperNeoError.invalidParameter("FRI query index out of range")
        }
        self.vectorLength = vectorLength
        self.paddedDomainSize = paddedDomainSize
        self.queryCount = queryCount
        self.blowupFactor = blowupFactor
        self.claimedDegreeBound = resolvedDegreeBound
        self.domainRoot = domainRoot
        self.cosetGenerator = cosetGenerator
        self.baseCommitment = baseCommitment
        self.foldedCommitments = foldedCommitments
        self.foldingChallenges = foldingChallenges
        self.queryProofs = queryProofs
        self.finalPolynomial = resolvedFinalPolynomial
        self.proofDigest = Digest384.shake256(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    vectorLength: vectorLength,
                    paddedDomainSize: paddedDomainSize,
                    queryCount: queryCount,
                    blowupFactor: blowupFactor,
                    claimedDegreeBound: resolvedDegreeBound,
                    domainRoot: domainRoot,
                    cosetGenerator: cosetGenerator,
                    baseCommitment: baseCommitment,
                    foldedCommitments: foldedCommitments,
                    foldingChallenges: foldingChallenges,
                    queryProofs: queryProofs,
                    finalPolynomial: resolvedFinalPolynomial
                )
        )
    }

    public var commitments: [SuperNeoFRICommitment] {
        [baseCommitment] + foldedCommitments
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                vectorLength: vectorLength,
                paddedDomainSize: paddedDomainSize,
                queryCount: queryCount,
                blowupFactor: blowupFactor,
                claimedDegreeBound: claimedDegreeBound,
                domainRoot: domainRoot,
                cosetGenerator: cosetGenerator,
                baseCommitment: baseCommitment,
                foldedCommitments: foldedCommitments,
                foldingChallenges: foldingChallenges,
                queryProofs: queryProofs,
                finalPolynomial: finalPolynomial
            )
            + proofDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        proofDigest == Digest384.shake256(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    vectorLength: vectorLength,
                    paddedDomainSize: paddedDomainSize,
                    queryCount: queryCount,
                    blowupFactor: blowupFactor,
                    claimedDegreeBound: claimedDegreeBound,
                    domainRoot: domainRoot,
                    cosetGenerator: cosetGenerator,
                    baseCommitment: baseCommitment,
                    foldedCommitments: foldedCommitments,
                    foldingChallenges: foldingChallenges,
                    queryProofs: queryProofs,
                    finalPolynomial: finalPolynomial
                )
        )
    }

    private static func bodyBytes(
        vectorLength: Int,
        paddedDomainSize: Int,
        queryCount: Int,
        blowupFactor: Int,
        claimedDegreeBound: Int,
        domainRoot: GoldilocksField,
        cosetGenerator: GoldilocksField,
        baseCommitment: SuperNeoFRICommitment,
        foldedCommitments: [SuperNeoFRICommitment],
        foldingChallenges: [GoldilocksField],
        queryProofs: [SuperNeoFRIQueryProof],
        finalPolynomial: [GoldilocksField]
    ) -> [UInt8] {
        spartanFRIEncodeCount(vectorLength)
            + spartanFRIEncodeCount(paddedDomainSize)
            + spartanFRIEncodeCount(queryCount)
            + spartanFRIEncodeCount(blowupFactor)
            + spartanFRIEncodeCount(claimedDegreeBound)
            + domainRoot.superNeoBytes
            + cosetGenerator.superNeoBytes
            + baseCommitment.superNeoBytes
            + spartanFRIEncodeCount(foldedCommitments.count)
            + foldedCommitments.flatMap(\.superNeoBytes)
            + spartanFRIEncodeCount(foldingChallenges.count)
            + foldingChallenges.flatMap(\.superNeoBytes)
            + spartanFRIEncodeCount(queryProofs.count)
            + queryProofs.flatMap(\.superNeoBytes)
            + spartanFRIEncodeCount(finalPolynomial.count)
            + finalPolynomial.flatMap(\.superNeoBytes)
    }
}

public struct SuperNeoTerminalVerifierPCSProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let version: UInt16 = 1
    public static let domain = Digest256.hash("SuperNeo-NuMetal.terminal-verifier-pcs.v1")
    public static let relationTag = "terminal-verifier-typed-air/canonical-public-piccs-pirlc-pidec-ce-inner/v1"

    public let version: UInt16
    public let sourceProofKind: ProofEnvelopeKind
    public let sourceProofByteCount: Int
    public let sourceProofDigest: Digest256
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let publicInputDigest: Digest256
    public let recursiveRelationDigest: Digest256?
    public let compressionPolicyDigest: Digest256
    public let terminalStatementDigest: Digest256
    public let foldProofDigest: Digest256
    public let ceOpeningProofDigest: Digest256
    public let relationDigest: Digest256
    public let traceVectorLength: Int
    public let paddedDomainSize: Int
    public let tracePCS: SuperNeoFRIProof
    public let residualPCS: SuperNeoFRIProof
    public let proofDigest: Digest384

    public init(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        traceVectorLength: Int,
        paddedDomainSize: Int,
        tracePCS: SuperNeoFRIProof,
        residualPCS: SuperNeoFRIProof
    ) throws {
        guard sourceProofKind == .terminalLocal || sourceProofKind == .compressedPublic else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS source must be terminal or compressed-public")
        }
        guard sourceProofByteCount > ProofEnvelopeHeader.byteCount else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS source byte count must include a proof body")
        }
        guard traceVectorLength > 0, paddedDomainSize >= traceVectorLength else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS trace dimensions are invalid")
        }
        guard tracePCS.vectorLength == traceVectorLength,
              residualPCS.vectorLength == traceVectorLength,
              tracePCS.paddedDomainSize == paddedDomainSize,
              residualPCS.paddedDomainSize == paddedDomainSize,
              tracePCS.queryCount == residualPCS.queryCount,
              tracePCS.claimedDegreeBound == traceVectorLength,
              residualPCS.claimedDegreeBound == traceVectorLength,
              tracePCS.blowupFactor == residualPCS.blowupFactor,
              tracePCS.domainRoot == residualPCS.domainRoot,
              tracePCS.cosetGenerator == residualPCS.cosetGenerator else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS proof dimensions do not match")
        }
        let relationDigest = Self.computeRelationDigest(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            traceVectorLength: traceVectorLength,
            paddedDomainSize: paddedDomainSize
        )
        let expectedQueries = terminalVerifierAIRQueryIndices(
            tracePCS: tracePCS,
            residualPCS: residualPCS,
            relationDigest: relationDigest
        )
        guard tracePCS.queryProofs.map(\.initialIndex) == expectedQueries,
              residualPCS.queryProofs.map(\.initialIndex) == expectedQueries else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS trace/residual proofs must use the joint AIR query schedule")
        }
        self.version = Self.version
        self.sourceProofKind = sourceProofKind
        self.sourceProofByteCount = sourceProofByteCount
        self.sourceProofDigest = sourceProofDigest
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.publicInputDigest = publicInputDigest
        self.recursiveRelationDigest = recursiveRelationDigest
        self.compressionPolicyDigest = compressionPolicyDigest
        self.terminalStatementDigest = terminalStatementDigest
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.relationDigest = relationDigest
        self.traceVectorLength = traceVectorLength
        self.paddedDomainSize = paddedDomainSize
        self.tracePCS = tracePCS
        self.residualPCS = residualPCS
        self.proofDigest = Self.computeProofDigest(
            version: Self.version,
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            relationDigest: relationDigest,
            traceVectorLength: traceVectorLength,
            paddedDomainSize: paddedDomainSize,
            tracePCS: tracePCS,
            residualPCS: residualPCS
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                version: version,
                sourceProofKind: sourceProofKind,
                sourceProofByteCount: sourceProofByteCount,
                sourceProofDigest: sourceProofDigest,
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                publicInputDigest: publicInputDigest,
                recursiveRelationDigest: recursiveRelationDigest,
                compressionPolicyDigest: compressionPolicyDigest,
                terminalStatementDigest: terminalStatementDigest,
                foldProofDigest: foldProofDigest,
                ceOpeningProofDigest: ceOpeningProofDigest,
                relationDigest: relationDigest,
                traceVectorLength: traceVectorLength,
                paddedDomainSize: paddedDomainSize,
                tracePCS: tracePCS,
                residualPCS: residualPCS
            )
            + proofDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        relationDigest == Self.computeRelationDigest(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            traceVectorLength: traceVectorLength,
            paddedDomainSize: paddedDomainSize
        )
        && proofDigest == Self.computeProofDigest(
            version: version,
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            relationDigest: relationDigest,
            traceVectorLength: traceVectorLength,
            paddedDomainSize: paddedDomainSize,
            tracePCS: tracePCS,
            residualPCS: residualPCS
        )
    }

    static func computeRelationDigest(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        traceVectorLength: Int,
        paddedDomainSize: Int
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + spartanFRIEncodeString(Self.relationTag)
                + [sourceProofKind.rawValue]
                + spartanFRIEncodeCount(sourceProofByteCount)
                + sourceProofDigest.superNeoBytes
                + spartanFRIEncodeUInt16(profileID)
                + shapeDigest.superNeoBytes
                + statementDigest.superNeoBytes
                + verifierKeyDigest.superNeoBytes
                + transcriptDomain.superNeoBytes
                + publicInputDigest.superNeoBytes
                + (recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
                + compressionPolicyDigest.superNeoBytes
                + terminalStatementDigest.superNeoBytes
                + foldProofDigest.superNeoBytes
                + ceOpeningProofDigest.superNeoBytes
                + spartanFRIEncodeCount(traceVectorLength)
                + spartanFRIEncodeCount(paddedDomainSize)
        )
    }

    private static func computeProofDigest(
        version: UInt16,
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        relationDigest: Digest256,
        traceVectorLength: Int,
        paddedDomainSize: Int,
        tracePCS: SuperNeoFRIProof,
        residualPCS: SuperNeoFRIProof
    ) -> Digest384 {
        Digest384.shake256(
            Self.domain.superNeoBytes
                + bodyBytes(
                    version: version,
                    sourceProofKind: sourceProofKind,
                    sourceProofByteCount: sourceProofByteCount,
                    sourceProofDigest: sourceProofDigest,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    statementDigest: statementDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    transcriptDomain: transcriptDomain,
                    publicInputDigest: publicInputDigest,
                    recursiveRelationDigest: recursiveRelationDigest,
                    compressionPolicyDigest: compressionPolicyDigest,
                    terminalStatementDigest: terminalStatementDigest,
                    foldProofDigest: foldProofDigest,
                    ceOpeningProofDigest: ceOpeningProofDigest,
                    relationDigest: relationDigest,
                    traceVectorLength: traceVectorLength,
                    paddedDomainSize: paddedDomainSize,
                    tracePCS: tracePCS,
                    residualPCS: residualPCS
                )
        )
    }

    private static func bodyBytes(
        version: UInt16,
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        relationDigest: Digest256,
        traceVectorLength: Int,
        paddedDomainSize: Int,
        tracePCS: SuperNeoFRIProof,
        residualPCS: SuperNeoFRIProof
    ) -> [UInt8] {
        spartanFRIEncodeUInt16(version)
            + [sourceProofKind.rawValue]
            + spartanFRIEncodeCount(sourceProofByteCount)
            + sourceProofDigest.superNeoBytes
            + spartanFRIEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + statementDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + transcriptDomain.superNeoBytes
            + publicInputDigest.superNeoBytes
            + (recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
            + compressionPolicyDigest.superNeoBytes
            + terminalStatementDigest.superNeoBytes
            + foldProofDigest.superNeoBytes
            + ceOpeningProofDigest.superNeoBytes
            + relationDigest.superNeoBytes
            + spartanFRIEncodeCount(traceVectorLength)
            + spartanFRIEncodeCount(paddedDomainSize)
            + tracePCS.superNeoBytes
            + residualPCS.superNeoBytes
    }
}

public struct SuperNeoSpartanFRICompressionProof: Equatable, Sendable, SuperNeoByteEncodable {
    public static let schemeID = "superneo-spartan-fri-compression-v1"
    public static let domain = Digest256.hash("SuperNeo-NuMetal.spartan-fri-compression.proof.v1")
    public static let version: UInt16 = 1
    public static let defaultQueryCount = 12
    public static let defaultBlowupFactor = 4

    public let version: UInt16
    public let schemeID: String
    public let statement: SuperNeoSpartanFRICompressionStatement
    public let arithmetizationDigest: Digest256
    public let traceVectorLength: Int
    public let paddedDomainSize: Int
    public let terminalVerifierPCSProof: SuperNeoTerminalVerifierPCSProof
    public let witnessPCS: SuperNeoFRIProof
    public let residualPCS: SuperNeoFRIProof
    public let proofDigest: Digest384

    public init(
        statement: SuperNeoSpartanFRICompressionStatement,
        arithmetizationDigest: Digest256,
        traceVectorLength: Int,
        paddedDomainSize: Int,
        terminalVerifierPCSProof: SuperNeoTerminalVerifierPCSProof,
        witnessPCS: SuperNeoFRIProof,
        residualPCS: SuperNeoFRIProof
    ) throws {
        guard traceVectorLength > 0 else {
            throw SuperNeoError.invalidParameter("Spartan/FRI trace length must be positive")
        }
        guard paddedDomainSize >= traceVectorLength else {
            throw SuperNeoError.invalidParameter("Spartan/FRI padded domain is too small")
        }
        guard witnessPCS.paddedDomainSize == paddedDomainSize,
              residualPCS.paddedDomainSize == paddedDomainSize,
              witnessPCS.vectorLength == traceVectorLength,
              residualPCS.vectorLength == traceVectorLength else {
            throw SuperNeoError.invalidParameter("Spartan/FRI PCS dimensions do not match trace")
        }
        guard terminalVerifierPCSProof.sourceProofKind == statement.sourceProofKind,
              terminalVerifierPCSProof.sourceProofByteCount == statement.sourceProofByteCount,
              terminalVerifierPCSProof.sourceProofDigest == statement.sourceProofDigest,
              terminalVerifierPCSProof.profileID == statement.profileID,
              terminalVerifierPCSProof.shapeDigest == statement.shapeDigest,
              terminalVerifierPCSProof.statementDigest == statement.statementDigest,
              terminalVerifierPCSProof.verifierKeyDigest == statement.verifierKeyDigest,
              terminalVerifierPCSProof.transcriptDomain == statement.transcriptDomain,
              terminalVerifierPCSProof.publicInputDigest == statement.publicInputDigest,
              terminalVerifierPCSProof.terminalStatementDigest == statement.terminalStatementDigest,
              terminalVerifierPCSProof.foldProofDigest == statement.foldProofDigest,
              terminalVerifierPCSProof.ceOpeningProofDigest == statement.ceOpeningProofDigest else {
            throw SuperNeoError.invalidParameter("Spartan/FRI terminal verifier PCS relation mismatch")
        }
        guard witnessPCS.claimedDegreeBound == traceVectorLength,
              residualPCS.claimedDegreeBound == traceVectorLength,
              witnessPCS.blowupFactor == residualPCS.blowupFactor,
              witnessPCS.domainRoot == residualPCS.domainRoot,
              witnessPCS.cosetGenerator == residualPCS.cosetGenerator else {
            throw SuperNeoError.invalidParameter("Spartan/FRI PCS domain metadata does not match trace")
        }
        self.version = Self.version
        self.schemeID = Self.schemeID
        self.statement = statement
        self.arithmetizationDigest = arithmetizationDigest
        self.traceVectorLength = traceVectorLength
        self.paddedDomainSize = paddedDomainSize
        self.terminalVerifierPCSProof = terminalVerifierPCSProof
        self.witnessPCS = witnessPCS
        self.residualPCS = residualPCS
        self.proofDigest = Digest384.shake256(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    version: Self.version,
                    schemeID: Self.schemeID,
                    statement: statement,
                    arithmetizationDigest: arithmetizationDigest,
                    traceVectorLength: traceVectorLength,
                    paddedDomainSize: paddedDomainSize,
                    terminalVerifierPCSProof: terminalVerifierPCSProof,
                    witnessPCS: witnessPCS,
                    residualPCS: residualPCS
                )
        )
    }

    public var compressionRatioAgainstSource: Double {
        Double(statement.sourceProofByteCount) / Double(max(1, superNeoBytes.count))
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                version: version,
                schemeID: schemeID,
                statement: statement,
                arithmetizationDigest: arithmetizationDigest,
                traceVectorLength: traceVectorLength,
                paddedDomainSize: paddedDomainSize,
                terminalVerifierPCSProof: terminalVerifierPCSProof,
                witnessPCS: witnessPCS,
                residualPCS: residualPCS
            )
            + proofDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        terminalVerifierPCSProof.hasValidDigest()
        && proofDigest == Digest384.shake256(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    version: version,
                    schemeID: schemeID,
                    statement: statement,
                    arithmetizationDigest: arithmetizationDigest,
                    traceVectorLength: traceVectorLength,
                    paddedDomainSize: paddedDomainSize,
                    terminalVerifierPCSProof: terminalVerifierPCSProof,
                    witnessPCS: witnessPCS,
                    residualPCS: residualPCS
                )
        )
    }

    static func arithmetizationDigest(
        statement: SuperNeoSpartanFRICompressionStatement,
        terminalVerifierPCSProof: SuperNeoTerminalVerifierPCSProof,
        traceLength: Int,
        paddedDomainSize: Int,
        blowupFactor: Int,
        claimedDegreeBound: Int
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + spartanFRIEncodeString("spartan-residual-relation: witness(X)-public-trace(X)=residual(X)")
                + statement.statementCompressionDigest.superNeoBytes
                + terminalVerifierPCSProof.relationDigest.superNeoBytes
                + terminalVerifierPCSProof.proofDigest.superNeoBytes
                + spartanFRIEncodeCount(traceLength)
                + spartanFRIEncodeCount(paddedDomainSize)
                + spartanFRIEncodeCount(blowupFactor)
                + spartanFRIEncodeCount(claimedDegreeBound)
        )
    }

    private static func bodyBytes(
        version: UInt16,
        schemeID: String,
        statement: SuperNeoSpartanFRICompressionStatement,
        arithmetizationDigest: Digest256,
        traceVectorLength: Int,
        paddedDomainSize: Int,
        terminalVerifierPCSProof: SuperNeoTerminalVerifierPCSProof,
        witnessPCS: SuperNeoFRIProof,
        residualPCS: SuperNeoFRIProof
    ) -> [UInt8] {
        spartanFRIEncodeUInt16(version)
            + spartanFRIEncodeString(schemeID)
            + statement.superNeoBytes
            + arithmetizationDigest.superNeoBytes
            + spartanFRIEncodeCount(traceVectorLength)
            + spartanFRIEncodeCount(paddedDomainSize)
            + terminalVerifierPCSProof.superNeoBytes
            + witnessPCS.superNeoBytes
            + residualPCS.superNeoBytes
    }
}

public extension SuperNeoSpartanFRICompressionStatement {
    init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        self = try reader.readSpartanFRICompressionStatement()
        try reader.finish()
    }
}

public extension SuperNeoTerminalVerifierPCSProof {
    init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        self = try reader.readTerminalVerifierPCSProof()
        try reader.finish()
    }
}

public extension SuperNeoFRIProof {
    init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        self = try reader.readSpartanFRIProof()
        try reader.finish()
    }
}

public extension SuperNeoSpartanFRICompressionProof {
    init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        let domain = try Digest256(reader.readData(count: Digest256.byteCount))
        guard domain == Self.domain else {
            throw SuperNeoError.invalidEncoding("Spartan/FRI compression proof domain mismatch")
        }
        let version = try reader.readUInt16()
        guard version == Self.version else {
            throw SuperNeoError.invalidEncoding("unsupported Spartan/FRI compression proof version")
        }
        let schemeID = try reader.readSpartanFRIString(maximumByteCount: 4096, name: "Spartan/FRI scheme")
        guard schemeID == Self.schemeID else {
            throw SuperNeoError.invalidEncoding("unsupported Spartan/FRI compression scheme")
        }
        let statement = try reader.readSpartanFRICompressionStatement()
        let arithmetizationDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        let traceVectorLength = try reader.readCount(maximum: 1 << 24, name: "Spartan/FRI trace length")
        let paddedDomainSize = try reader.readCount(maximum: 1 << 26, name: "Spartan/FRI padded domain")
        let terminalVerifierPCSProof = try reader.readTerminalVerifierPCSProof()
        let witnessPCS = try reader.readSpartanFRIProof()
        let residualPCS = try reader.readSpartanFRIProof()
        let parsedDigest = try Digest384(reader.readData(count: Digest384.byteCount))
        try reader.finish()
        let decoded = try Self(
            statement: statement,
            arithmetizationDigest: arithmetizationDigest,
            traceVectorLength: traceVectorLength,
            paddedDomainSize: paddedDomainSize,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            witnessPCS: witnessPCS,
            residualPCS: residualPCS
        )
        guard decoded.proofDigest == parsedDigest else {
            throw SuperNeoError.invalidEncoding("Spartan/FRI compression proof digest mismatch")
        }
        self = decoded
    }
}

private extension ByteReader {
    mutating func readSpartanFRIString(maximumByteCount: Int, name: String) throws -> String {
        let byteCount = try readCount(maximum: maximumByteCount, name: name, elementByteWidth: 1)
        let bytes = try readData(count: byteCount)
        guard let value = String(bytes: bytes, encoding: .utf8) else {
            throw SuperNeoError.invalidEncoding("\(name) must be valid UTF-8")
        }
        return value
    }

    mutating func readSpartanDigest256() throws -> Digest256 {
        try Digest256(readData(count: Digest256.byteCount))
    }

    mutating func readSpartanDigest384() throws -> Digest384 {
        try Digest384(readData(count: Digest384.byteCount))
    }

    mutating func readSpartanGoldilocksField() throws -> GoldilocksField {
        try GoldilocksField(littleEndianBytes: readData(count: 8)[...])
    }

    mutating func readSpartanProofEnvelopeKind() throws -> ProofEnvelopeKind {
        let raw = try readUInt8()
        guard let kind = ProofEnvelopeKind(rawValue: raw) else {
            throw SuperNeoError.invalidEncoding("unsupported Spartan/FRI source proof kind")
        }
        return kind
    }

    mutating func readSpartanOptionalDigest256(name: String) throws -> Digest256? {
        let tag = try readUInt8()
        switch tag {
        case 0:
            return nil
        case 1:
            return try readSpartanDigest256()
        default:
            throw SuperNeoError.invalidEncoding("\(name) optional digest tag must be 0 or 1")
        }
    }

    mutating func readSpartanFRICommitment() throws -> SuperNeoFRICommitment {
        let domainSize = try readCount(maximum: 1 << 26, name: "FRI commitment domain")
        let root = try readSpartanDigest384()
        return SuperNeoFRICommitment(domainSize: domainSize, root: root)
    }

    mutating func readSpartanFRIMerkleSibling() throws -> SuperNeoFRIMerkleSibling {
        let rawPosition = try readUInt8()
        guard let position = SuperNeoFRIMerkleSibling.Position(rawValue: rawPosition) else {
            throw SuperNeoError.invalidEncoding("FRI Merkle sibling position must be left or right")
        }
        return SuperNeoFRIMerkleSibling(position: position, digest: try readSpartanDigest384())
    }

    mutating func readSpartanFRIMerkleOpening() throws -> SuperNeoFRIMerkleOpening {
        let index = try readCount(maximum: 1 << 26, name: "FRI Merkle opening index")
        let leafCount = try readCount(maximum: 1 << 26, name: "FRI Merkle opening leaf count")
        let point = try readSpartanGoldilocksField()
        let value = try readSpartanGoldilocksField()
        let siblingCount = try readCount(
            maximum: 64,
            name: "FRI Merkle sibling",
            elementByteWidth: 1 + Digest384.byteCount
        )
        let siblings = try (0..<siblingCount).map { _ in try readSpartanFRIMerkleSibling() }
        return SuperNeoFRIMerkleOpening(
            index: index,
            leafCount: leafCount,
            point: point,
            value: value,
            siblings: siblings
        )
    }

    mutating func readSpartanFRIQueryProof() throws -> SuperNeoFRIQueryProof {
        let initialIndex = try readCount(maximum: 1 << 26, name: "FRI query initial index")
        let layerCount = try readCount(maximum: 64, name: "FRI query layer")
        let layerOpenings = try (0..<layerCount).map { _ -> [SuperNeoFRIMerkleOpening] in
            let openingCount = try readCount(maximum: 3, name: "FRI query opening")
            return try (0..<openingCount).map { _ in try readSpartanFRIMerkleOpening() }
        }
        return SuperNeoFRIQueryProof(initialIndex: initialIndex, layerOpenings: layerOpenings)
    }

    mutating func readSpartanFRIProof() throws -> SuperNeoFRIProof {
        let domain = try readSpartanDigest256()
        guard domain == SuperNeoFRIProof.domain else {
            throw SuperNeoError.invalidEncoding("FRI proof domain mismatch")
        }
        let vectorLength = try readCount(maximum: 1 << 24, name: "FRI vector length")
        let paddedDomainSize = try readCount(maximum: 1 << 26, name: "FRI padded domain")
        let queryCount = try readCount(maximum: 4096, name: "FRI query count")
        let blowupFactor = try readCount(maximum: 1 << 16, name: "FRI blowup factor")
        let claimedDegreeBound = try readCount(maximum: 1 << 24, name: "FRI claimed degree bound")
        let domainRoot = try readSpartanGoldilocksField()
        let cosetGenerator = try readSpartanGoldilocksField()
        let baseCommitment = try readSpartanFRICommitment()
        let foldedCommitmentCount = try readCount(
            maximum: 64,
            name: "FRI folded commitment",
            elementByteWidth: 8 + Digest384.byteCount
        )
        let foldedCommitments = try (0..<foldedCommitmentCount).map { _ in try readSpartanFRICommitment() }
        let challengeCount = try readCount(maximum: 64, name: "FRI folding challenge", elementByteWidth: 8)
        let foldingChallenges = try (0..<challengeCount).map { _ in try readSpartanGoldilocksField() }
        let queryProofCount = try readCount(maximum: 4096, name: "FRI query proof")
        let queryProofs = try (0..<queryProofCount).map { _ in try readSpartanFRIQueryProof() }
        let finalPolynomialCount = try readCount(maximum: 1024, name: "FRI final polynomial", elementByteWidth: 8)
        let finalPolynomial = try (0..<finalPolynomialCount).map { _ in try readSpartanGoldilocksField() }
        let parsedDigest = try readSpartanDigest384()
        let decoded = try SuperNeoFRIProof(
            vectorLength: vectorLength,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            domainRoot: domainRoot,
            cosetGenerator: cosetGenerator,
            baseCommitment: baseCommitment,
            foldedCommitments: foldedCommitments,
            foldingChallenges: foldingChallenges,
            queryProofs: queryProofs,
            finalPolynomial: finalPolynomial
        )
        guard decoded.proofDigest == parsedDigest else {
            throw SuperNeoError.invalidEncoding("FRI proof digest mismatch")
        }
        return decoded
    }

    mutating func readSpartanFRICompressionStatement() throws -> SuperNeoSpartanFRICompressionStatement {
        let domain = try readSpartanDigest256()
        guard domain == SuperNeoSpartanFRICompressionStatement.domain else {
            throw SuperNeoError.invalidEncoding("Spartan/FRI compression statement domain mismatch")
        }
        let sourceProofKind = try readSpartanProofEnvelopeKind()
        let sourceProofByteCount = try readCount(maximum: 1 << 32, name: "Spartan/FRI source proof byte")
        let sourceProofDigest = try readSpartanDigest256()
        let profileID = try readUInt16()
        let shapeDigest = try readSpartanDigest256()
        let statementDigest = try readSpartanDigest256()
        let verifierKeyDigest = try readSpartanDigest256()
        let transcriptDomain = try readSpartanDigest256()
        let publicInputDigest = try readSpartanDigest256()
        let terminalStatementDigest = try readSpartanDigest256()
        let foldProofDigest = try readSpartanDigest256()
        let ceOpeningProofDigest = try readSpartanDigest256()
        let parsedDigest = try readSpartanDigest256()
        let decoded = try SuperNeoSpartanFRICompressionStatement(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest
        )
        guard decoded.statementCompressionDigest == parsedDigest else {
            throw SuperNeoError.invalidEncoding("Spartan/FRI compression statement digest mismatch")
        }
        return decoded
    }

    mutating func readTerminalVerifierPCSProof() throws -> SuperNeoTerminalVerifierPCSProof {
        let domain = try readSpartanDigest256()
        guard domain == SuperNeoTerminalVerifierPCSProof.domain else {
            throw SuperNeoError.invalidEncoding("terminal verifier PCS proof domain mismatch")
        }
        let version = try readUInt16()
        guard version == SuperNeoTerminalVerifierPCSProof.version else {
            throw SuperNeoError.invalidEncoding("unsupported terminal verifier PCS proof version")
        }
        let sourceProofKind = try readSpartanProofEnvelopeKind()
        let sourceProofByteCount = try readCount(maximum: 1 << 32, name: "terminal verifier PCS source proof byte")
        let sourceProofDigest = try readSpartanDigest256()
        let profileID = try readUInt16()
        let shapeDigest = try readSpartanDigest256()
        let statementDigest = try readSpartanDigest256()
        let verifierKeyDigest = try readSpartanDigest256()
        let transcriptDomain = try readSpartanDigest256()
        let publicInputDigest = try readSpartanDigest256()
        let recursiveRelationDigest = try readSpartanOptionalDigest256(name: "terminal verifier recursive relation")
        let compressionPolicyDigest = try readSpartanDigest256()
        let terminalStatementDigest = try readSpartanDigest256()
        let foldProofDigest = try readSpartanDigest256()
        let ceOpeningProofDigest = try readSpartanDigest256()
        let relationDigest = try readSpartanDigest256()
        let traceVectorLength = try readCount(maximum: 1 << 24, name: "terminal verifier trace vector")
        let paddedDomainSize = try readCount(maximum: 1 << 26, name: "terminal verifier padded domain")
        let tracePCS = try readSpartanFRIProof()
        let residualPCS = try readSpartanFRIProof()
        let parsedDigest = try readSpartanDigest384()
        let decoded = try SuperNeoTerminalVerifierPCSProof(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            traceVectorLength: traceVectorLength,
            paddedDomainSize: paddedDomainSize,
            tracePCS: tracePCS,
            residualPCS: residualPCS
        )
        guard decoded.relationDigest == relationDigest else {
            throw SuperNeoError.invalidEncoding("terminal verifier PCS relation digest mismatch")
        }
        guard decoded.proofDigest == parsedDigest else {
            throw SuperNeoError.invalidEncoding("terminal verifier PCS proof digest mismatch")
        }
        return decoded
    }
}

public enum SuperNeoTerminalVerifierAIRConstraintKind: UInt8, Equatable, Sendable {
    case canonicalSourceRepresentation = 1
    case publicBinding = 2
    case piCCSVerifier = 3
    case piRLCVerifier = 4
    case piDECVerifier = 5
    case terminalCEOpening = 6
    case innerCompressedProofVerifier = 7
    case acceptAggregation = 8
}

public enum SuperNeoTerminalVerifierAIRRowProvenance: UInt8, Equatable, Sendable {
    case primitiveArithmetic = 1
    case canonicalDecoding = 2
    case publicInputBinding = 3
    case hashSubrelation = 4
    case publicCoinBinding = 5
    case friPCSVerifier = 6
}

public struct SuperNeoTerminalVerifierAIRConstraintRow: Equatable, Sendable {
    public let kind: SuperNeoTerminalVerifierAIRConstraintKind
    public let provenance: SuperNeoTerminalVerifierAIRRowProvenance
    public let labelDigest: Digest256
    public let observed: GoldilocksField
    public let expected: GoldilocksField

    public var residual: GoldilocksField { observed - expected }

    public init(
        kind: SuperNeoTerminalVerifierAIRConstraintKind,
        provenance: SuperNeoTerminalVerifierAIRRowProvenance,
        label: String,
        observed: GoldilocksField,
        expected: GoldilocksField
    ) {
        self.kind = kind
        self.provenance = provenance
        self.labelDigest = Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.constraint-row.v1".utf8)
                + [kind.rawValue]
                + [provenance.rawValue]
                + spartanFRIEncodeString(label)
        )
        self.observed = observed
        self.expected = expected
    }

    public static func required(
        _ condition: Bool,
        kind: SuperNeoTerminalVerifierAIRConstraintKind,
        provenance: SuperNeoTerminalVerifierAIRRowProvenance = .primitiveArithmetic,
        label: String
    ) -> SuperNeoTerminalVerifierAIRConstraintRow {
        SuperNeoTerminalVerifierAIRConstraintRow(
            kind: kind,
            provenance: provenance,
            label: label,
            observed: condition ? .one : .zero,
            expected: .one
        )
    }
}

struct SuperNeoTerminalVerifierAIRPrimitiveBatchSummary: Equatable, Sendable {
    let rowCount: Int
    let observedTranscriptDigest: Digest256
    let expectedTranscriptDigest: Digest256
    let challengeDigest: Digest256
    let aggregateResidual: GoldilocksField
    let indexAccumulator: GoldilocksField
    let coefficients: [GoldilocksField]
}

enum SuperNeoTerminalVerifierAIRPrimitiveBatch {
    static func validateCanonicalRowIndices(_ indices: [Int]) throws {
        guard indices == Array(indices.indices) else {
            throw SuperNeoError.invalidParameter("terminal verifier AIR primitive batch row indices must be contiguous and ordered")
        }
    }

    static func validateRowsForBatching(
        _ rows: [SuperNeoTerminalVerifierAIRConstraintRow]
    ) throws {
        guard rows.allSatisfy({ $0.kind != .acceptAggregation }) else {
            throw SuperNeoError.invalidParameter("terminal verifier AIR primitive batch must not contain accept-bit aggregation rows")
        }
        guard rows.allSatisfy({ $0.provenance != .friPCSVerifier }) else {
            throw SuperNeoError.invalidParameter("terminal verifier AIR primitive batch must not contain PCS verifier shortcut rows")
        }
    }

    static func summarize(
        _ primitiveRows: [SuperNeoTerminalVerifierAIRConstraintRow],
        label: String
    ) -> SuperNeoTerminalVerifierAIRPrimitiveBatchSummary {
        let observedRowBytes = primitiveRows.enumerated().flatMap { index, row in
            rowEncoding(
                rowCount: primitiveRows.count,
                index: index,
                row: row,
                label: label,
                observed: row.observed
            )
        }
        let expectedRowBytes = primitiveRows.enumerated().flatMap { index, row in
            rowEncoding(
                rowCount: primitiveRows.count,
                index: index,
                row: row,
                label: label,
                observed: row.expected
            )
        }
        let observedTranscriptDigest = transcriptDigest(
            rowCount: primitiveRows.count,
            label: label,
            rowBytes: observedRowBytes
        )
        let expectedTranscriptDigest = transcriptDigest(
            rowCount: primitiveRows.count,
            label: label,
            rowBytes: expectedRowBytes
        )
        let challengeDigest = Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.primitive-batch-challenge-after-row-transcript.v1".utf8)
                + spartanFRIEncodeString(label)
                + spartanFRIEncodeCount(primitiveRows.count)
                + observedTranscriptDigest.superNeoBytes
                + expectedTranscriptDigest.superNeoBytes
        )
        var aggregateResidual = GoldilocksField.zero
        var indexAccumulator = GoldilocksField.zero
        var coefficients: [GoldilocksField] = []
        coefficients.reserveCapacity(primitiveRows.count)
        for (index, row) in primitiveRows.enumerated() {
            let coefficient = coefficient(
                row: row,
                label: label,
                index: index,
                challengeDigest: challengeDigest
            )
            coefficients.append(coefficient)
            aggregateResidual = aggregateResidual + row.residual * coefficient
            indexAccumulator = indexAccumulator + coefficient * GoldilocksField(UInt64(index + 1))
        }
        return SuperNeoTerminalVerifierAIRPrimitiveBatchSummary(
            rowCount: primitiveRows.count,
            observedTranscriptDigest: observedTranscriptDigest,
            expectedTranscriptDigest: expectedTranscriptDigest,
            challengeDigest: challengeDigest,
            aggregateResidual: aggregateResidual,
            indexAccumulator: indexAccumulator,
            coefficients: coefficients
        )
    }

    static func contextRoot(
        rows: [SuperNeoTerminalVerifierAIRConstraintRow],
        label: String,
        terminalVerifierRelationDigest: Digest256,
        recursiveRelationDigest: Digest256,
        sourceDigest: Digest256,
        sourceByteCount: Int,
        publicInputDigest: Digest256,
        compressionPolicyDigest: Digest256
    ) -> Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.primitive-batch-context-root.v1".utf8)
                + spartanFRIEncodeString(label)
                + terminalVerifierRelationDigest.superNeoBytes
                + recursiveRelationDigest.superNeoBytes
                + sourceDigest.superNeoBytes
                + spartanFRIEncodeCount(sourceByteCount)
                + publicInputDigest.superNeoBytes
                + compressionPolicyDigest.superNeoBytes
                + spartanFRIEncodeCount(rows.count)
                + rows.enumerated().flatMap { index, row in
                    contextRowDigest(
                        domain: label,
                        subrelationKindRawValue: row.kind.rawValue,
                        rowIndex: index,
                        row: row,
                        terminalVerifierRelationDigest: terminalVerifierRelationDigest,
                        recursiveRelationDigest: recursiveRelationDigest,
                        sourceDigest: sourceDigest,
                        sourceByteCount: sourceByteCount,
                        publicInputDigest: publicInputDigest,
                        compressionPolicyDigest: compressionPolicyDigest,
                        terminalStatementDigest: .hash("SuperNeo-NuMetal.terminal-verifier-air.context-root.no-terminal-statement"),
                        foldProofDigest: .hash("SuperNeo-NuMetal.terminal-verifier-air.context-root.no-fold-proof"),
                        ceOpeningProofDigest: .hash("SuperNeo-NuMetal.terminal-verifier-air.context-root.no-ce-opening")
                    ).superNeoBytes
                }
        )
    }

    static func contextRowDigest(
        domain: String,
        subrelationKindRawValue: UInt8,
        rowIndex: Int,
        row: SuperNeoTerminalVerifierAIRConstraintRow,
        terminalVerifierRelationDigest: Digest256,
        recursiveRelationDigest: Digest256,
        sourceDigest: Digest256,
        sourceByteCount: Int,
        publicInputDigest: Digest256,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256
    ) -> Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.primitive-row-context-binding.v1".utf8)
                + spartanFRIEncodeString(domain)
                + [subrelationKindRawValue]
                + spartanFRIEncodeCount(rowIndex)
                + [row.kind.rawValue, row.provenance.rawValue]
                + row.labelDigest.superNeoBytes
                + row.observed.superNeoBytes
                + row.expected.superNeoBytes
                + row.residual.superNeoBytes
                + terminalVerifierRelationDigest.superNeoBytes
                + recursiveRelationDigest.superNeoBytes
                + sourceDigest.superNeoBytes
                + spartanFRIEncodeCount(sourceByteCount)
                + publicInputDigest.superNeoBytes
                + compressionPolicyDigest.superNeoBytes
                + terminalStatementDigest.superNeoBytes
                + foldProofDigest.superNeoBytes
                + ceOpeningProofDigest.superNeoBytes
        )
    }

    private static func rowEncoding(
        rowCount: Int,
        index: Int,
        row: SuperNeoTerminalVerifierAIRConstraintRow,
        label: String,
        observed: GoldilocksField
    ) -> [UInt8] {
        Array("SuperNeo-NuMetal.terminal-verifier-air.primitive-row.v2".utf8)
            + spartanFRIEncodeString(label)
            + spartanFRIEncodeCount(rowCount)
            + spartanFRIEncodeCount(index)
            + [row.kind.rawValue, row.provenance.rawValue]
            + row.labelDigest.superNeoBytes
            + observed.superNeoBytes
            + row.expected.superNeoBytes
            + (observed - row.expected).superNeoBytes
    }

    private static func transcriptDigest(
        rowCount: Int,
        label: String,
        rowBytes: [UInt8]
    ) -> Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.full-primitive-row-transcript.v1".utf8)
                + spartanFRIEncodeString(label)
                + spartanFRIEncodeCount(rowCount)
                + rowBytes
        )
    }

    private static func coefficient(
        row: SuperNeoTerminalVerifierAIRConstraintRow,
        label: String,
        index: Int,
        challengeDigest: Digest256
    ) -> GoldilocksField {
        let coinDigest = Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.primitive-batch-coin.v2".utf8)
                + spartanFRIEncodeString(label)
                + challengeDigest.superNeoBytes
                + spartanFRIEncodeCount(index)
                + [row.kind.rawValue, row.provenance.rawValue]
                + row.labelDigest.superNeoBytes
        )
        let fields = spartanFRIDigestFields(coinDigest)
        return fields[0] + GoldilocksField(UInt64(index + 1))
    }
}

public struct SuperNeoTerminalVerifierAIRSpec: Equatable, Sendable {
    public let sourceProofKind: ProofEnvelopeKind
    public let sourceProofByteCount: Int
    public let sourceProofDigest: Digest256
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let publicInputDigest: Digest256
    public let recursiveRelationDigest: Digest256?
    public let compressionPolicyDigest: Digest256
    public let terminalStatementDigest: Digest256
    public let foldProofDigest: Digest256
    public let ceOpeningProofDigest: Digest256
    public let canonicalSourceEncodingDigest: Digest256
    public let publicCoinBindingDigest: Digest256
    public let innerCompressedProofDigest: Digest256?
    public let specDigest: Digest256
    public let normalVerifierResult: VerificationResult
    public let constraintRows: [SuperNeoTerminalVerifierAIRConstraintRow]

    public var accepts: Bool {
        constraintRows.allSatisfy { $0.residual == .zero }
    }

    public var acceptBit: GoldilocksField {
        accepts ? .one : .zero
    }

    public init(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        canonicalSourceEncodingDigest: Digest256,
        publicCoinBindingDigest: Digest256,
        innerCompressedProofDigest: Digest256?,
        normalVerifierResult: VerificationResult,
        constraintRows: [SuperNeoTerminalVerifierAIRConstraintRow]
    ) {
        self.sourceProofKind = sourceProofKind
        self.sourceProofByteCount = sourceProofByteCount
        self.sourceProofDigest = sourceProofDigest
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.transcriptDomain = transcriptDomain
        self.publicInputDigest = publicInputDigest
        self.recursiveRelationDigest = recursiveRelationDigest
        self.compressionPolicyDigest = compressionPolicyDigest
        self.terminalStatementDigest = terminalStatementDigest
        self.foldProofDigest = foldProofDigest
        self.ceOpeningProofDigest = ceOpeningProofDigest
        self.canonicalSourceEncodingDigest = canonicalSourceEncodingDigest
        self.publicCoinBindingDigest = publicCoinBindingDigest
        self.innerCompressedProofDigest = innerCompressedProofDigest
        self.normalVerifierResult = normalVerifierResult
        self.constraintRows = constraintRows
        self.specDigest = Self.computeSpecDigest(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: profileID,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            publicInputDigest: publicInputDigest,
            recursiveRelationDigest: recursiveRelationDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest,
            canonicalSourceEncodingDigest: canonicalSourceEncodingDigest,
            publicCoinBindingDigest: publicCoinBindingDigest,
            innerCompressedProofDigest: innerCompressedProofDigest,
            constraintRows: constraintRows
        )
    }

    public var compressionStatement: SuperNeoSpartanFRICompressionStatement {
        get throws {
            try SuperNeoSpartanFRICompressionStatement(
                sourceProofKind: sourceProofKind,
                sourceProofByteCount: sourceProofByteCount,
                sourceProofDigest: sourceProofDigest,
                profileID: profileID,
                shapeDigest: shapeDigest,
                statementDigest: statementDigest,
                verifierKeyDigest: verifierKeyDigest,
                transcriptDomain: transcriptDomain,
                publicInputDigest: publicInputDigest,
                terminalStatementDigest: terminalStatementDigest,
                foldProofDigest: foldProofDigest,
                ceOpeningProofDigest: ceOpeningProofDigest
            )
        }
    }

    public func constraints(
        for kind: SuperNeoTerminalVerifierAIRConstraintKind
    ) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
        constraintRows.filter { $0.kind == kind }
    }

    public static func boundPublicSpec(
        statement: SuperNeoSpartanFRICompressionStatement,
        publicInput: SuperNeoPublicFoldInput,
        verifierKeyDigest: Digest256,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) throws -> SuperNeoTerminalVerifierAIRSpec {
        let ccsStatement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        guard statement.profileID == policy.profileID,
              statement.shapeDigest == policy.shapeDigest,
              statement.statementDigest == policy.statementDigest,
              statement.verifierKeyDigest == policy.verifierKeyDigest,
              statement.transcriptDomain == policy.transcriptDomain else {
            throw SuperNeoError.verificationFailed("terminal verifier AIR spec policy mismatch")
        }
        guard statement.verifierKeyDigest == verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("terminal verifier AIR spec verifier key mismatch")
        }
        guard ccsStatement.shapeDigest == statement.shapeDigest,
              ccsStatement.statementDigest == statement.statementDigest else {
            throw SuperNeoError.verificationFailed("terminal verifier AIR spec public statement mismatch")
        }
        guard statement.publicInputDigest == spartanFRIPublicInputDigest(publicInput) else {
            throw SuperNeoError.verificationFailed("terminal verifier AIR spec public input digest mismatch")
        }
        guard policy.proofKindPolicy.accepts(statement.sourceProofKind) else {
            throw SuperNeoError.verificationFailed("terminal verifier AIR spec proof kind not accepted")
        }
        let policyDigest = terminalVerifierCompressionPolicyDigest(policy)
        let publicCoinBindingDigest = terminalVerifierAIRPublicCoinBindingDigest(
            transcriptDomain: statement.transcriptDomain,
            statementDigest: statement.statementDigest,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        let innerCompressedProofDigest = statement.sourceProofKind == .compressedPublic
            ? terminalVerifierAIRInnerCompressedDigest(statement: statement, policyDigest: policyDigest)
            : nil
        let constraintRows = terminalVerifierAIRConstraintRows(
            sourceProofKind: statement.sourceProofKind,
            sourceProofByteCount: statement.sourceProofByteCount,
            sourceProofDigest: statement.sourceProofDigest,
            canonicalSourceEncodingDigest: statement.sourceProofDigest,
            profileID: statement.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: statement.verifierKeyDigest,
            transcriptDomain: statement.transcriptDomain,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest,
            compressionPolicyDigest: policyDigest,
            terminalStatementDigest: statement.terminalStatementDigest,
            foldProofDigest: statement.foldProofDigest,
            ceOpeningProofDigest: statement.ceOpeningProofDigest,
            publicCoinBindingDigest: publicCoinBindingDigest,
            innerCompressedProofDigest: innerCompressedProofDigest,
            contextBound: true,
            sourceDigestComputed: true,
            verifierKeyBound: true,
            publicStatementBound: true,
            recursiveRelationBound: true,
            compressionPolicyBound: true,
            piCCSChecks: terminalVerifierAIRSourceFreePCSRows(kind: .piCCSVerifier, label: "piccs"),
            piRLCChecks: terminalVerifierAIRSourceFreePCSRows(kind: .piRLCVerifier, label: "pirlc"),
            piDECChecks: terminalVerifierAIRSourceFreePCSRows(kind: .piDECVerifier, label: "pidec"),
            terminalCEChecks: terminalVerifierAIRSourceFreePCSRows(kind: .terminalCEOpening, label: "terminal-ce"),
            innerCompressedChecks: terminalVerifierAIRSourceFreeInnerCompressedRows(
                sourceProofKind: statement.sourceProofKind,
                hasInnerDigest: innerCompressedProofDigest != nil
            )
        )
        return SuperNeoTerminalVerifierAIRSpec(
            sourceProofKind: statement.sourceProofKind,
            sourceProofByteCount: statement.sourceProofByteCount,
            sourceProofDigest: statement.sourceProofDigest,
            profileID: statement.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: statement.verifierKeyDigest,
            transcriptDomain: statement.transcriptDomain,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest,
            compressionPolicyDigest: policyDigest,
            terminalStatementDigest: statement.terminalStatementDigest,
            foldProofDigest: statement.foldProofDigest,
            ceOpeningProofDigest: statement.ceOpeningProofDigest,
            canonicalSourceEncodingDigest: statement.sourceProofDigest,
            publicCoinBindingDigest: publicCoinBindingDigest,
            innerCompressedProofDigest: innerCompressedProofDigest,
            normalVerifierResult: .valid,
            constraintRows: constraintRows
        )
    }

    public static func evaluateCanonicalSource(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        verifier: SuperNeoVerifier,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) throws -> SuperNeoTerminalVerifierAIRSpecEvaluation {
#if DEBUG
        let decoded = try superNeoDebugMeasure("canonical source decoding") {
            let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
            let expectedContext = try policy.context(for: header, totalByteCount: proofBytes.count)
            let source = try decodeTerminalVerifierSource(
                proofBytes: proofBytes,
                header: header,
                parameters: verifier.parameters,
                expectedContext: expectedContext
            )
            let sourceDigest = Digest256.hash(proofBytes)
            return (header: header, expectedContext: expectedContext, source: source, sourceDigest: sourceDigest)
        }
        let header = decoded.header
        let expectedContext = decoded.expectedContext
        let decodedSource = decoded.source
        let sourceDigests = decodedSource.sourceDigests
        let sourceDigest = decoded.sourceDigest
#else
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        let expectedContext = try policy.context(for: header, totalByteCount: proofBytes.count)
        let decodedSource = try decodeTerminalVerifierSource(
            proofBytes: proofBytes,
            header: header,
            parameters: verifier.parameters,
            expectedContext: expectedContext
        )
        let sourceDigests = decodedSource.sourceDigests
        let sourceDigest = Digest256.hash(proofBytes)
#endif
        let publicStatement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        let policyDigest = terminalVerifierCompressionPolicyDigest(policy)
        let statement = try SuperNeoSpartanFRICompressionStatement(
            sourceProofKind: header.kind,
            sourceProofByteCount: proofBytes.count,
            sourceProofDigest: sourceDigest,
            profileID: header.profileID,
            shapeDigest: header.shapeDigest,
            statementDigest: header.statementDigest,
            verifierKeyDigest: header.verifierKeyDigest,
            transcriptDomain: header.transcriptDomain,
            publicInputDigest: spartanFRIPublicInputDigest(publicInput),
            terminalStatementDigest: sourceDigests.terminalStatementDigest,
            foldProofDigest: sourceDigests.foldProofDigest,
            ceOpeningProofDigest: sourceDigests.ceOpeningProofDigest
        )
        let sourceDigestProven = true
        let contextBound = header.profileID == expectedContext.profileID
            && header.kind == expectedContext.kind
            && header.shapeDigest == expectedContext.shapeDigest
            && header.statementDigest == expectedContext.statementDigest
            && header.verifierKeyDigest == expectedContext.verifierKeyDigest
            && header.transcriptDomain == expectedContext.transcriptDomain
        let publicStatementBound = publicStatement.shapeDigest == expectedContext.shapeDigest
            && publicStatement.statementDigest == expectedContext.statementDigest
        let recursiveBound = publicStatement.recursiveRelationDigest == publicInput.recursiveRelationDigest
#if DEBUG
        let constraintMaterial = try superNeoDebugMeasure("primitive row emission") {
            try terminalVerifierAIRConstraintMaterialForSource(
                publicInput: publicInput,
                verifier: verifier,
                decodedSource: decodedSource
            )
        }
#else
        let constraintMaterial = try terminalVerifierAIRConstraintMaterialForSource(
            publicInput: publicInput,
            verifier: verifier,
            decodedSource: decodedSource
        )
#endif
        let publicCoinBindingDigest = terminalVerifierAIRPublicCoinBindingDigest(
            transcriptDomain: header.transcriptDomain,
            statementDigest: header.statementDigest,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        let innerCompressedProofDigest = header.kind == .compressedPublic
            ? terminalVerifierAIRInnerCompressedDigest(statement: statement, policyDigest: policyDigest)
            : nil
#if DEBUG
        let constraintRows = superNeoDebugMeasure("primitive row emission") {
            terminalVerifierAIRConstraintRows(
                sourceProofKind: header.kind,
                sourceProofByteCount: proofBytes.count,
                sourceProofDigest: sourceDigest,
                canonicalSourceEncodingDigest: sourceDigest,
                profileID: header.profileID,
                shapeDigest: header.shapeDigest,
                statementDigest: header.statementDigest,
                verifierKeyDigest: header.verifierKeyDigest,
                transcriptDomain: header.transcriptDomain,
                publicInputDigest: statement.publicInputDigest,
                recursiveRelationDigest: publicInput.recursiveRelationDigest,
                compressionPolicyDigest: policyDigest,
                terminalStatementDigest: sourceDigests.terminalStatementDigest,
                foldProofDigest: sourceDigests.foldProofDigest,
                ceOpeningProofDigest: sourceDigests.ceOpeningProofDigest,
                publicCoinBindingDigest: publicCoinBindingDigest,
                innerCompressedProofDigest: innerCompressedProofDigest,
                contextBound: contextBound,
                sourceDigestComputed: sourceDigestProven,
                verifierKeyBound: expectedContext.verifierKeyDigest == verifier.key.verifierKeyDigest,
                publicStatementBound: publicStatementBound,
                recursiveRelationBound: recursiveBound,
                compressionPolicyBound: true,
                piCCSChecks: constraintMaterial.piCCSRows,
                piRLCChecks: constraintMaterial.piRLCRows,
                piDECChecks: constraintMaterial.piDECRows,
                terminalCEChecks: constraintMaterial.terminalCERows,
                innerCompressedChecks: constraintMaterial.innerCompressedRows
            )
        }
        SuperNeoSpartanFRIDebugProfileContext.current?.recordPrimitiveRows(constraintRows)
#else
        let constraintRows = terminalVerifierAIRConstraintRows(
            sourceProofKind: header.kind,
            sourceProofByteCount: proofBytes.count,
            sourceProofDigest: sourceDigest,
            canonicalSourceEncodingDigest: sourceDigest,
            profileID: header.profileID,
            shapeDigest: header.shapeDigest,
            statementDigest: header.statementDigest,
            verifierKeyDigest: header.verifierKeyDigest,
            transcriptDomain: header.transcriptDomain,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest,
            compressionPolicyDigest: policyDigest,
            terminalStatementDigest: sourceDigests.terminalStatementDigest,
            foldProofDigest: sourceDigests.foldProofDigest,
            ceOpeningProofDigest: sourceDigests.ceOpeningProofDigest,
            publicCoinBindingDigest: publicCoinBindingDigest,
            innerCompressedProofDigest: innerCompressedProofDigest,
            contextBound: contextBound,
            sourceDigestComputed: sourceDigestProven,
            verifierKeyBound: expectedContext.verifierKeyDigest == verifier.key.verifierKeyDigest,
            publicStatementBound: publicStatementBound,
            recursiveRelationBound: recursiveBound,
            compressionPolicyBound: true,
            piCCSChecks: constraintMaterial.piCCSRows,
            piRLCChecks: constraintMaterial.piRLCRows,
            piDECChecks: constraintMaterial.piDECRows,
            terminalCEChecks: constraintMaterial.terminalCERows,
            innerCompressedChecks: constraintMaterial.innerCompressedRows
        )
#endif
        let verification: VerificationResult = constraintRows.allSatisfy { $0.residual == .zero }
            ? .valid
            : .invalid("terminal verifier AIR primitive constraints rejected")
#if DEBUG
        let spec = superNeoDebugMeasure("shared terminal AIR spec construction") {
            SuperNeoTerminalVerifierAIRSpec(
                sourceProofKind: header.kind,
                sourceProofByteCount: proofBytes.count,
                sourceProofDigest: sourceDigest,
                profileID: header.profileID,
                shapeDigest: header.shapeDigest,
                statementDigest: header.statementDigest,
                verifierKeyDigest: header.verifierKeyDigest,
                transcriptDomain: header.transcriptDomain,
                publicInputDigest: statement.publicInputDigest,
                recursiveRelationDigest: publicInput.recursiveRelationDigest,
                compressionPolicyDigest: policyDigest,
                terminalStatementDigest: sourceDigests.terminalStatementDigest,
                foldProofDigest: sourceDigests.foldProofDigest,
                ceOpeningProofDigest: sourceDigests.ceOpeningProofDigest,
                canonicalSourceEncodingDigest: sourceDigest,
                publicCoinBindingDigest: publicCoinBindingDigest,
                innerCompressedProofDigest: innerCompressedProofDigest,
                normalVerifierResult: verification,
                constraintRows: constraintRows
            )
        }
#else
        let spec = SuperNeoTerminalVerifierAIRSpec(
            sourceProofKind: header.kind,
            sourceProofByteCount: proofBytes.count,
            sourceProofDigest: sourceDigest,
            profileID: header.profileID,
            shapeDigest: header.shapeDigest,
            statementDigest: header.statementDigest,
            verifierKeyDigest: header.verifierKeyDigest,
            transcriptDomain: header.transcriptDomain,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest,
            compressionPolicyDigest: policyDigest,
            terminalStatementDigest: sourceDigests.terminalStatementDigest,
            foldProofDigest: sourceDigests.foldProofDigest,
            ceOpeningProofDigest: sourceDigests.ceOpeningProofDigest,
            canonicalSourceEncodingDigest: sourceDigest,
            publicCoinBindingDigest: publicCoinBindingDigest,
            innerCompressedProofDigest: innerCompressedProofDigest,
            normalVerifierResult: verification,
            constraintRows: constraintRows
        )
#endif
        return SuperNeoTerminalVerifierAIRSpecEvaluation(spec: spec, result: verification)
    }

    private static func computeSpecDigest(
        sourceProofKind: ProofEnvelopeKind,
        sourceProofByteCount: Int,
        sourceProofDigest: Digest256,
        profileID: UInt16,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256,
        publicInputDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        compressionPolicyDigest: Digest256,
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256,
        canonicalSourceEncodingDigest: Digest256,
        publicCoinBindingDigest: Digest256,
        innerCompressedProofDigest: Digest256?,
        constraintRows: [SuperNeoTerminalVerifierAIRConstraintRow]
    ) -> Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.terminal-verifier-air.shared-spec.v1".utf8)
                + [sourceProofKind.rawValue]
                + spartanFRIEncodeCount(sourceProofByteCount)
                + sourceProofDigest.superNeoBytes
                + spartanFRIEncodeUInt16(profileID)
                + shapeDigest.superNeoBytes
                + statementDigest.superNeoBytes
                + verifierKeyDigest.superNeoBytes
                + transcriptDomain.superNeoBytes
                + publicInputDigest.superNeoBytes
                + (recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
                + compressionPolicyDigest.superNeoBytes
                + terminalStatementDigest.superNeoBytes
                + foldProofDigest.superNeoBytes
                + ceOpeningProofDigest.superNeoBytes
                + canonicalSourceEncodingDigest.superNeoBytes
                + publicCoinBindingDigest.superNeoBytes
                + (innerCompressedProofDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
                + spartanFRIEncodeCount(constraintRows.count)
                + constraintRows.flatMap { row in
                    [row.kind.rawValue]
                        + [row.provenance.rawValue]
                        + row.labelDigest.superNeoBytes
                        + row.observed.superNeoBytes
                        + row.expected.superNeoBytes
                }
        )
    }
}

public struct SuperNeoTerminalVerifierAIRSpecEvaluation: Equatable, Sendable {
    public let spec: SuperNeoTerminalVerifierAIRSpec
    public let result: VerificationResult
}

#if DEBUG
struct SuperNeoSpartanFRICompressionDebugProfile: Equatable {
    let phaseNanoseconds: [String: UInt64]
    let phaseCounts: [String: Int]
    let primitiveRowCount: Int
    let rowProvenanceCounts: [String: Int]
    let rowKindCounts: [String: Int]
    let traceLength: Int
    let residualLength: Int
    let paddedDomainSize: Int
    let blowupFactor: Int
    let queryCount: Int
    let terminalAIRMaterialBuildCount: Int
    let rowTranscriptBuildCount: Int
    let friPlanBuildCounts: [String: Int]
    let friLayerCounts: [String: Int]
    let friLayerLeafCounts: [String: [Int]]

    var paddedDomainMatchesTraceLength: Bool {
        paddedDomainSize == spartanFRINextPowerOfTwo(traceLength * blowupFactor)
    }

    var report: String {
        let phaseLines = phaseNanoseconds.keys.sorted().map { phase in
            let milliseconds = Double(phaseNanoseconds[phase] ?? 0) / 1_000_000.0
            return String(format: "  %@: %.3f ms (%d)", phase, milliseconds, phaseCounts[phase] ?? 0)
        }
        let friLines = friPlanBuildCounts.keys.sorted().map { label in
            let leaves = friLayerLeafCounts[label]?.map(String.init).joined(separator: ",") ?? ""
            return "  \(label): plans=\(friPlanBuildCounts[label] ?? 0), layers=\(friLayerCounts[label] ?? 0), leaves=[\(leaves)]"
        }
        return """
        SuperNeo source-free compression profile
        phases:
        \(phaseLines.joined(separator: "\n"))
        sizes:
          primitiveRows=\(primitiveRowCount)
          traceLength=\(traceLength)
          residualLength=\(residualLength)
          paddedDomainSize=\(paddedDomainSize)
          blowupFactor=\(blowupFactor)
          queryCount=\(queryCount)
          terminalAIRMaterialBuildCount=\(terminalAIRMaterialBuildCount)
          rowTranscriptBuildCount=\(rowTranscriptBuildCount)
          rowProvenanceCounts=\(rowProvenanceCounts)
          rowKindCounts=\(rowKindCounts)
        fri:
        \(friLines.joined(separator: "\n"))
        """
    }
}

final class SuperNeoSpartanFRICompressionDebugRecorder {
    private var phaseNanoseconds: [String: UInt64] = [:]
    private var phaseCounts: [String: Int] = [:]
    private var primitiveRowCount = 0
    private var rowProvenanceCounts: [String: Int] = [:]
    private var rowKindCounts: [String: Int] = [:]
    private var traceLength = 0
    private var residualLength = 0
    private var paddedDomainSize = 0
    private var blowupFactor = 0
    private var queryCount = 0
    private var terminalAIRMaterialBuildCount = 0
    private var rowTranscriptBuildCount = 0
    private var friPlanBuildCounts: [String: Int] = [:]
    private var friLayerCounts: [String: Int] = [:]
    private var friLayerLeafCounts: [String: [Int]] = [:]

    func activate<T>(_ body: () throws -> T) rethrows -> T {
        let prior = SuperNeoSpartanFRIDebugProfileContext.current
        SuperNeoSpartanFRIDebugProfileContext.current = self
        defer { SuperNeoSpartanFRIDebugProfileContext.current = prior }
        return try body()
    }

    func measure<T>(_ phase: String, _ body: () throws -> T) rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            phaseNanoseconds[phase, default: 0] += elapsed
            phaseCounts[phase, default: 0] += 1
        }
        return try body()
    }

    func recordPrimitiveRows(_ rows: [SuperNeoTerminalVerifierAIRConstraintRow]) {
        primitiveRowCount = rows.count
        rowProvenanceCounts = Dictionary(grouping: rows, by: { String(describing: $0.provenance) })
            .mapValues(\.count)
        rowKindCounts = Dictionary(grouping: rows, by: { String(describing: $0.kind) })
            .mapValues(\.count)
    }

    func recordTerminalAIRMaterial(
        traceLength: Int,
        residualLength: Int,
        paddedDomainSize: Int,
        blowupFactor: Int
    ) {
        terminalAIRMaterialBuildCount += 1
        self.traceLength = traceLength
        self.residualLength = residualLength
        self.paddedDomainSize = paddedDomainSize
        self.blowupFactor = blowupFactor
    }

    func recordRowTranscriptBuild() {
        rowTranscriptBuildCount += 1
    }

    func recordQueryCount(_ queryCount: Int) {
        self.queryCount = queryCount
    }

    fileprivate func recordFRIPlan(_ plan: SpartanFRIProverPlan) {
        friPlanBuildCounts[plan.label, default: 0] += 1
        friLayerCounts[plan.label] = plan.commitments.count
        friLayerLeafCounts[plan.label] = plan.commitments.map(\.domainSize)
    }

    var snapshot: SuperNeoSpartanFRICompressionDebugProfile {
        SuperNeoSpartanFRICompressionDebugProfile(
            phaseNanoseconds: phaseNanoseconds,
            phaseCounts: phaseCounts,
            primitiveRowCount: primitiveRowCount,
            rowProvenanceCounts: rowProvenanceCounts,
            rowKindCounts: rowKindCounts,
            traceLength: traceLength,
            residualLength: residualLength,
            paddedDomainSize: paddedDomainSize,
            blowupFactor: blowupFactor,
            queryCount: queryCount,
            terminalAIRMaterialBuildCount: terminalAIRMaterialBuildCount,
            rowTranscriptBuildCount: rowTranscriptBuildCount,
            friPlanBuildCounts: friPlanBuildCounts,
            friLayerCounts: friLayerCounts,
            friLayerLeafCounts: friLayerLeafCounts
        )
    }
}

enum SuperNeoSpartanFRIDebugProfileContext {
    private static let key = "SuperNeoSpartanFRICompressionDebugRecorder"

    static var current: SuperNeoSpartanFRICompressionDebugRecorder? {
        get { Thread.current.threadDictionary[key] as? SuperNeoSpartanFRICompressionDebugRecorder }
        set {
            if let newValue {
                Thread.current.threadDictionary[key] = newValue
            } else {
                Thread.current.threadDictionary.removeObject(forKey: key)
            }
        }
    }
}

func superNeoDebugMeasure<T>(_ phase: String, _ body: () throws -> T) rethrows -> T {
    if let recorder = SuperNeoSpartanFRIDebugProfileContext.current {
        return try recorder.measure(phase, body)
    }
    return try body()
}

struct SuperNeoTerminalAIRTestMaterial: Equatable, Sendable {
    let relationDigest: Digest256
    let rowTranscriptDigest: Digest256
    let aggregateResidual: GoldilocksField
    let rowCount: Int
    let allResidualsZero: Bool
}
#endif

public enum SuperNeoSpartanFRICompressor {
    public static func compressAcceptedProof(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy? = nil,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default,
        queryCount: Int = SuperNeoSpartanFRICompressionProof.defaultQueryCount
    ) throws -> SuperNeoSpartanFRICompressionProof {
        let header = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        let trustedPolicy = policy ?? SuperNeoTerminalProofAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            profileID: parameters.profileID,
            transcriptDomain: header.transcriptDomain
        )
        let verifier = SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        )
        let specEvaluation = try SuperNeoTerminalVerifierAIRSpec.evaluateCanonicalSource(
            publicInput: publicInput,
            proofBytes: proofBytes,
            verifier: verifier,
            policy: trustedPolicy
        )
        let verification = specEvaluation.result
        guard verification.isValid else {
            throw SuperNeoError.verificationFailed(
                "Spartan/FRI compression requires an accepted terminal proof: \(verification.reason ?? "unknown")"
            )
        }
        let spec = specEvaluation.spec
        let terminalAIRMaterial = try makeTerminalVerifierPCSProverMaterial(
            spec: spec,
            publicInput: publicInput,
            policy: trustedPolicy
        )
        let compressionStatement = terminalAIRMaterial.statement
        let terminalVerifierPCSProof = try makeTerminalVerifierPCSProof(
            material: terminalAIRMaterial,
            policy: trustedPolicy,
            queryCount: queryCount
        )
#if DEBUG
        let trace = superNeoDebugMeasure("trace vector construction") {
            spartanTraceVector(
                statement: compressionStatement,
                terminalVerifierPCSProof: terminalVerifierPCSProof,
                accepted: true
            )
        }
        let residual = superNeoDebugMeasure("residual vector construction") {
            spartanResidualVector(witness: trace, publicTrace: trace)
        }
#else
        let trace = spartanTraceVector(
            statement: compressionStatement,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            accepted: true
        )
        let residual = spartanResidualVector(witness: trace, publicTrace: trace)
#endif
        let claimedDegreeBound = trace.count
        let pcsParameters = sourceFreePCSParameters(for: trustedPolicy)
        let blowupFactor = pcsParameters.blowupFactor
        let paddedDomainSize = spartanFRINextPowerOfTwo(trace.count * blowupFactor)
        let arithmetizationDigest = SuperNeoSpartanFRICompressionProof.arithmetizationDigest(
            statement: compressionStatement,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            traceLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound
        )
        let queryDomainSize = max(1, paddedDomainSize / 2)
        let minimumQueryCount = min(pcsParameters.minimumQueryCount, queryDomainSize)
        guard queryCount >= minimumQueryCount else {
            throw SuperNeoError.invalidParameter("Spartan/FRI compression query count below selected minimum")
        }
        guard queryCount <= queryDomainSize else {
            throw SuperNeoError.invalidParameter("Spartan/FRI compression query count exceeds folded pair domain")
        }
        let witnessPCS = try makeFRIProof(
            vector: trace,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            label: "witness-trace",
            bindingDigest: arithmetizationDigest
        )
        let residualPCS = try makeFRIProof(
            vector: residual,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            label: "r1cs-residual",
            bindingDigest: arithmetizationDigest
        )
        let proof = try SuperNeoSpartanFRICompressionProof(
            statement: compressionStatement,
            arithmetizationDigest: arithmetizationDigest,
            traceVectorLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            witnessPCS: witnessPCS,
            residualPCS: residualPCS
        )
#if DEBUG
        _ = superNeoDebugMeasure("proof serialization") { proof.superNeoBytes }
#endif
        return proof
    }

    static func makeSourceFreeCompressionProofForTesting(
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        sourceProofKind: ProofEnvelopeKind = .terminalLocal,
        sourceProofByteCount: Int = ProofEnvelopeHeader.byteCount + 1,
        sourceProofDigest: Digest256 = Digest256.hash("SuperNeo-NuMetal.test.source-free-source-digest.v1"),
        terminalStatementDigest: Digest256 = Digest256.hash("SuperNeo-NuMetal.test.source-free-terminal-statement.v1"),
        foldProofDigest: Digest256 = Digest256.hash("SuperNeo-NuMetal.test.source-free-fold-proof.v1"),
        ceOpeningProofDigest: Digest256 = Digest256.hash("SuperNeo-NuMetal.test.source-free-ce-opening.v1"),
        queryCount: Int = SuperNeoSpartanFRICompressionProof.defaultQueryCount
    ) throws -> SuperNeoSpartanFRICompressionProof {
        let statement = try SuperNeoSpartanFRICompressionStatement(
            sourceProofKind: sourceProofKind,
            sourceProofByteCount: sourceProofByteCount,
            sourceProofDigest: sourceProofDigest,
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            publicInputDigest: spartanFRIPublicInputDigest(publicInput),
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest
        )
        let spec = try SuperNeoTerminalVerifierAIRSpec.boundPublicSpec(
            statement: statement,
            publicInput: publicInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            policy: policy
        )
        let terminalAIRMaterial = try makeTerminalVerifierPCSProverMaterial(
            spec: spec,
            publicInput: publicInput,
            policy: policy
        )
        let terminalVerifierPCSProof = try makeTerminalVerifierPCSProof(
            material: terminalAIRMaterial,
            policy: policy,
            queryCount: queryCount
        )
#if DEBUG
        let trace = superNeoDebugMeasure("trace vector construction") {
            spartanTraceVector(
                statement: statement,
                terminalVerifierPCSProof: terminalVerifierPCSProof,
                accepted: true
            )
        }
        let residual = superNeoDebugMeasure("residual vector construction") {
            spartanResidualVector(witness: trace, publicTrace: trace)
        }
#else
        let trace = spartanTraceVector(
            statement: statement,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            accepted: true
        )
        let residual = spartanResidualVector(witness: trace, publicTrace: trace)
#endif
        let claimedDegreeBound = trace.count
        let parameters = sourceFreePCSParameters(for: policy)
        let blowupFactor = parameters.blowupFactor
        let paddedDomainSize = spartanFRINextPowerOfTwo(trace.count * blowupFactor)
        let arithmetizationDigest = SuperNeoSpartanFRICompressionProof.arithmetizationDigest(
            statement: statement,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            traceLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound
        )
        let witnessPCS = try makeFRIProof(
            vector: trace,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            label: "witness-trace",
            bindingDigest: arithmetizationDigest
        )
        let residualPCS = try makeFRIProof(
            vector: residual,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            label: "r1cs-residual",
            bindingDigest: arithmetizationDigest
        )
        let proof = try SuperNeoSpartanFRICompressionProof(
            statement: statement,
            arithmetizationDigest: arithmetizationDigest,
            traceVectorLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            witnessPCS: witnessPCS,
            residualPCS: residualPCS
        )
#if DEBUG
        _ = superNeoDebugMeasure("proof serialization") { proof.superNeoBytes }
#endif
        return proof
    }

#if DEBUG
    static func makeTerminalVerifierAIRMaterialForTesting(
        proofBytes: [UInt8],
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> SuperNeoTerminalAIRTestMaterial {
        let verifier = SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        )
        let evaluation = try SuperNeoTerminalVerifierAIRSpec.evaluateCanonicalSource(
            publicInput: publicInput,
            proofBytes: proofBytes,
            verifier: verifier,
            policy: policy
        )
        let spec = evaluation.spec
        let material = try makeTerminalVerifierPCSProverMaterial(
            spec: spec,
            publicInput: publicInput,
            policy: policy
        )
        try SuperNeoTerminalVerifierAIRPrimitiveBatch.validateRowsForBatching(spec.constraintRows)
        let batch = SuperNeoTerminalVerifierAIRPrimitiveBatch.summarize(
            spec.constraintRows,
            label: "terminal-source-envelope-air-test"
        )
        let aggregateResidual = material.residual.reduce(GoldilocksField.zero) { partial, residual in
            partial + residual * residual
        }
        return SuperNeoTerminalAIRTestMaterial(
            relationDigest: material.relationDigest,
            rowTranscriptDigest: batch.observedTranscriptDigest,
            aggregateResidual: aggregateResidual,
            rowCount: spec.constraintRows.count,
            allResidualsZero: material.residual.allSatisfy { $0 == .zero }
        )
    }
#endif

    public static func verifyCompressionProof(
        _ proof: SuperNeoSpartanFRICompressionProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKeyDigest: Digest256,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) -> VerificationResult {
        .invalid(
            "Spartan/FRI source-free compression verification requires the verifier key"
        )
    }

    public static func verifyCompressionProof(
        _ proof: SuperNeoSpartanFRICompressionProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        let relation = verifyTerminalVerifierPCSProof(
            proof.terminalVerifierPCSProof,
            publicInput: publicInput,
            verifierKey: verifierKey,
            policy: policy
        )
        guard relation.isValid else {
            return .invalid("Spartan/FRI terminal verifier PCS relation rejected: \(relation.reason ?? "unknown")")
        }
        return verifyAcceptedCompressionProof(
            proof,
            publicInput: publicInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            policy: policy
        )
    }

    public static func verifyCompressionProof(
        proofBytes: [UInt8],
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        do {
            let proof = try SuperNeoSpartanFRICompressionProof(bytes: proofBytes)
            return verifyCompressionProof(
                proof,
                publicInput: publicInput,
                verifierKey: verifierKey,
                policy: policy,
                parameters: parameters,
                metalContext: metalContext,
                executionPolicy: executionPolicy
            )
        } catch {
            return .invalid("Spartan/FRI compression proof decoding failed: \(error)")
        }
    }

    public static func verifyCompressionProof(
        _ proof: SuperNeoSpartanFRICompressionProof,
        sourceProofBytes: [UInt8],
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> VerificationResult {
        guard sourceProofBytes.count == proof.statement.sourceProofByteCount else {
            return .invalid("Spartan/FRI compression source byte count mismatch")
        }
        guard Digest256.hash(sourceProofBytes) == proof.statement.sourceProofDigest else {
            return .invalid("Spartan/FRI compression source digest mismatch")
        }
        let sourceVerification = SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        ).verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: sourceProofBytes,
            policy: policy
        )
        guard sourceVerification.isValid else {
            return .invalid(
                "Spartan/FRI compression source proof rejected: \(sourceVerification.reason ?? "unknown")"
            )
        }
        return verifyAcceptedCompressionProof(
            proof,
            publicInput: publicInput,
            verifierKeyDigest: verifierKey.verifierKeyDigest,
            policy: policy
        )
    }

    private struct TerminalVerifierPCSProverMaterial {
        let spec: SuperNeoTerminalVerifierAIRSpec
        let statement: SuperNeoSpartanFRICompressionStatement
        let policyDigest: Digest256
        let parameters: SourceFreePCSParameters
        let relationDigest: Digest256
        let trace: [GoldilocksField]
        let residual: [GoldilocksField]
        let paddedDomainSize: Int
    }

    private static func makeTerminalVerifierPCSProverMaterial(
        spec: SuperNeoTerminalVerifierAIRSpec,
        publicInput: SuperNeoPublicFoldInput,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) throws -> TerminalVerifierPCSProverMaterial {
        let statement = try spec.compressionStatement
        let policyDigest = spec.compressionPolicyDigest
        let parameters = sourceFreePCSParameters(for: policy)
        let compactTrace = true
        let traceLength = terminalVerifierAIRCompactTraceLength()
        let blowupFactor = parameters.blowupFactor
        let paddedDomainSize = spartanFRINextPowerOfTwo(traceLength * blowupFactor)
        let relationDigest = SuperNeoTerminalVerifierPCSProof.computeRelationDigest(
            sourceProofKind: statement.sourceProofKind,
            sourceProofByteCount: statement.sourceProofByteCount,
            sourceProofDigest: statement.sourceProofDigest,
            profileID: statement.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: statement.verifierKeyDigest,
            transcriptDomain: statement.transcriptDomain,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: publicInput.recursiveRelationDigest,
            compressionPolicyDigest: policyDigest,
            terminalStatementDigest: statement.terminalStatementDigest,
            foldProofDigest: statement.foldProofDigest,
            ceOpeningProofDigest: statement.ceOpeningProofDigest,
            traceVectorLength: traceLength,
            paddedDomainSize: paddedDomainSize
        )
#if DEBUG
        let air = superNeoDebugMeasure("row transcript + aggregate residual construction") {
            SuperNeoSpartanFRIDebugProfileContext.current?.recordRowTranscriptBuild()
            return terminalVerifierAIRInstance(
                spec: spec,
                publicInput: publicInput,
                terminalVerifierRelationDigest: relationDigest,
                compactForTinyFixture: compactTrace
            )
        }
#else
        let air = terminalVerifierAIRInstance(
            spec: spec,
            publicInput: publicInput,
            terminalVerifierRelationDigest: relationDigest,
            compactForTinyFixture: compactTrace
        )
#endif
        let trace = air.trace
        let residual = air.residual
        guard trace.count == traceLength else {
            throw SuperNeoError.invalidParameter("terminal verifier typed AIR trace length changed after relation binding")
        }
#if DEBUG
        SuperNeoSpartanFRIDebugProfileContext.current?.recordTerminalAIRMaterial(
            traceLength: trace.count,
            residualLength: residual.count,
            paddedDomainSize: paddedDomainSize,
            blowupFactor: blowupFactor
        )
#endif
        return TerminalVerifierPCSProverMaterial(
            spec: spec,
            statement: statement,
            policyDigest: policyDigest,
            parameters: parameters,
            relationDigest: relationDigest,
            trace: trace,
            residual: residual,
            paddedDomainSize: paddedDomainSize
        )
    }

    private static func makeTerminalVerifierPCSProof(
        spec: SuperNeoTerminalVerifierAIRSpec,
        publicInput: SuperNeoPublicFoldInput,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        queryCount: Int
    ) throws -> SuperNeoTerminalVerifierPCSProof {
        let material = try makeTerminalVerifierPCSProverMaterial(
            spec: spec,
            publicInput: publicInput,
            policy: policy
        )
        return try makeTerminalVerifierPCSProof(
            material: material,
            policy: policy,
            queryCount: queryCount
        )
    }

    private static func makeTerminalVerifierPCSProof(
        material: TerminalVerifierPCSProverMaterial,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        queryCount: Int
    ) throws -> SuperNeoTerminalVerifierPCSProof {
        let statement = material.statement
        let parameters = material.parameters
        let trace = material.trace
        let residual = material.residual
        let paddedDomainSize = material.paddedDomainSize
        let relationDigest = material.relationDigest
        let blowupFactor = parameters.blowupFactor
        let queryDomainSize = max(1, paddedDomainSize / 2)
        let minimumQueryCount = min(parameters.minimumQueryCount, queryDomainSize)
        guard queryCount >= minimumQueryCount else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS query count below selected minimum")
        }
#if DEBUG
        SuperNeoSpartanFRIDebugProfileContext.current?.recordQueryCount(queryCount)
        let tracePlan = try superNeoDebugMeasure("trace FRI plan construction") {
            try makeFRIProverPlan(
                vector: trace,
                paddedDomainSize: paddedDomainSize,
                queryCount: queryCount,
                blowupFactor: blowupFactor,
                claimedDegreeBound: trace.count,
                label: "terminal-verifier-trace",
                bindingDigest: relationDigest
            )
        }
        let residualPlan = try superNeoDebugMeasure("residual FRI plan construction") {
            try makeFRIProverPlan(
                vector: residual,
                paddedDomainSize: paddedDomainSize,
                queryCount: queryCount,
                blowupFactor: blowupFactor,
                claimedDegreeBound: trace.count,
                label: "terminal-verifier-residual",
                bindingDigest: relationDigest
            )
        }
#else
        let tracePlan = try makeFRIProverPlan(
            vector: trace,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: trace.count,
            label: "terminal-verifier-trace",
            bindingDigest: relationDigest
        )
        let residualPlan = try makeFRIProverPlan(
            vector: residual,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: trace.count,
            label: "terminal-verifier-residual",
            bindingDigest: relationDigest
        )
#endif
        let jointQueryIndices = terminalVerifierAIRQueryIndices(
            traceCommitments: tracePlan.commitments,
            residualCommitments: residualPlan.commitments,
            relationDigest: relationDigest,
            queryCount: queryCount,
            paddedDomainSize: paddedDomainSize
        )
#if DEBUG
        let jointPCS = try superNeoDebugMeasure("joint query opening materialization") {
            let jointTracePCS = try makeFRIProof(
                plan: tracePlan,
                queryIndicesOverride: jointQueryIndices
            )
            let residualPCS = try makeFRIProof(
                plan: residualPlan,
                queryIndicesOverride: jointQueryIndices
            )
            return (trace: jointTracePCS, residual: residualPCS)
        }
        let jointTracePCS = jointPCS.trace
        let residualPCS = jointPCS.residual
#else
        let jointTracePCS = try makeFRIProof(
            plan: tracePlan,
            queryIndicesOverride: jointQueryIndices
        )
        let residualPCS = try makeFRIProof(
            plan: residualPlan,
            queryIndicesOverride: jointQueryIndices
        )
#endif
        return try SuperNeoTerminalVerifierPCSProof(
            sourceProofKind: statement.sourceProofKind,
            sourceProofByteCount: statement.sourceProofByteCount,
            sourceProofDigest: statement.sourceProofDigest,
            profileID: statement.profileID,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: statement.verifierKeyDigest,
            transcriptDomain: statement.transcriptDomain,
            publicInputDigest: statement.publicInputDigest,
            recursiveRelationDigest: material.spec.recursiveRelationDigest,
            compressionPolicyDigest: material.policyDigest,
            terminalStatementDigest: statement.terminalStatementDigest,
            foldProofDigest: statement.foldProofDigest,
            ceOpeningProofDigest: statement.ceOpeningProofDigest,
            traceVectorLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            tracePCS: jointTracePCS,
            residualPCS: residualPCS
        )
    }

    private static func verifyTerminalVerifierPCSProof(
        _ proof: SuperNeoTerminalVerifierPCSProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) -> VerificationResult {
        guard proof.hasValidDigest() else {
            return .invalid("terminal verifier PCS proof digest mismatch")
        }
        guard proof.profileID == policy.profileID,
              proof.shapeDigest == policy.shapeDigest,
              proof.statementDigest == policy.statementDigest,
              proof.verifierKeyDigest == policy.verifierKeyDigest,
              proof.transcriptDomain == policy.transcriptDomain else {
            return .invalid("terminal verifier PCS policy mismatch")
        }
        guard proof.verifierKeyDigest == verifierKey.verifierKeyDigest else {
            return .invalid("terminal verifier PCS verifier key mismatch")
        }
        guard policy.proofKindPolicy.accepts(proof.sourceProofKind) else {
            return .invalid("terminal verifier PCS proof kind not accepted")
        }
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
        guard statement.shapeDigest == proof.shapeDigest,
              statement.statementDigest == proof.statementDigest else {
            return .invalid("terminal verifier PCS public statement mismatch")
        }
        guard proof.publicInputDigest == spartanFRIPublicInputDigest(publicInput) else {
            return .invalid("terminal verifier PCS public input digest mismatch")
        }
        guard proof.recursiveRelationDigest == publicInput.recursiveRelationDigest else {
            return .invalid("terminal verifier PCS recursive relation mismatch")
        }
        let expectedPolicyDigest = terminalVerifierCompressionPolicyDigest(policy)
        guard proof.compressionPolicyDigest == expectedPolicyDigest else {
            return .invalid("terminal verifier PCS compression policy mismatch")
        }
        let traceStatement = SuperNeoSpartanFRICompressionStatement(
            uncheckedSourceProofKind: proof.sourceProofKind,
            sourceProofByteCount: proof.sourceProofByteCount,
            sourceProofDigest: proof.sourceProofDigest,
            profileID: proof.profileID,
            shapeDigest: proof.shapeDigest,
            statementDigest: proof.statementDigest,
            verifierKeyDigest: proof.verifierKeyDigest,
            transcriptDomain: proof.transcriptDomain,
            publicInputDigest: proof.publicInputDigest,
            terminalStatementDigest: proof.terminalStatementDigest,
            foldProofDigest: proof.foldProofDigest,
            ceOpeningProofDigest: proof.ceOpeningProofDigest
        )
        let spec: SuperNeoTerminalVerifierAIRSpec
        do {
            spec = try SuperNeoTerminalVerifierAIRSpec.boundPublicSpec(
                statement: traceStatement,
                publicInput: publicInput,
                verifierKeyDigest: verifierKey.verifierKeyDigest,
                policy: policy
            )
        } catch {
            return .invalid("\(error)")
        }
        let air = terminalVerifierAIRInstance(
            spec: spec,
            publicInput: publicInput,
            terminalVerifierRelationDigest: proof.relationDigest,
            compactForTinyFixture: true
        )
        let trace = air.trace
        let residual = air.residual
        let pcsParameters = sourceFreePCSParameters(for: policy)
        guard proof.traceVectorLength == trace.count,
              proof.paddedDomainSize == spartanFRINextPowerOfTwo(trace.count * pcsParameters.blowupFactor) else {
            return .invalid("terminal verifier PCS trace dimension mismatch")
        }
        let terminalMinimumQueryCount = min(pcsParameters.minimumQueryCount, max(1, proof.paddedDomainSize / 2))
        guard proof.tracePCS.blowupFactor == pcsParameters.blowupFactor,
              proof.residualPCS.blowupFactor == pcsParameters.blowupFactor,
              proof.tracePCS.queryCount >= terminalMinimumQueryCount,
              proof.residualPCS.queryCount >= terminalMinimumQueryCount else {
            return .invalid("terminal verifier PCS policy parameters mismatch")
        }
        let jointQueryIndices = terminalVerifierAIRQueryIndices(
            tracePCS: proof.tracePCS,
            residualPCS: proof.residualPCS,
            relationDigest: proof.relationDigest
        )
        do {
            let traceSamples = try verifyFRIProof(
                proof.tracePCS,
                label: "terminal-verifier-trace",
                bindingDigest: proof.relationDigest,
                expectedQueryIndices: jointQueryIndices
            )
            let residualSamples = try verifyFRIProof(
                proof.residualPCS,
                label: "terminal-verifier-residual",
                bindingDigest: proof.relationDigest,
                expectedQueryIndices: jointQueryIndices
            )
            guard traceSamples.count == residualSamples.count else {
                return .invalid("terminal verifier AIR trace/residual sample count mismatch")
            }
            for (traceSample, residualSample) in zip(traceSamples, residualSamples) {
                guard traceSample.index == residualSample.index,
                      traceSample.point == residualSample.point else {
                    return .invalid("terminal verifier AIR trace/residual query mismatch")
                }
                guard residualSample.value == spartanFRIEvaluatePolynomial(residual, at: residualSample.point),
                      residualSample.value == .zero else {
                    return .invalid("terminal verifier AIR residual opening mismatch")
                }
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }

    private static func verifyAcceptedCompressionProof(
        _ proof: SuperNeoSpartanFRICompressionProof,
        publicInput: SuperNeoPublicFoldInput,
        verifierKeyDigest: Digest256,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) -> VerificationResult {
        guard proof.version == SuperNeoSpartanFRICompressionProof.version else {
            return .invalid("unsupported Spartan/FRI compression proof version")
        }
        guard proof.schemeID == SuperNeoSpartanFRICompressionProof.schemeID else {
            return .invalid("unsupported Spartan/FRI compression scheme")
        }
        guard proof.statement.hasValidDigest(), proof.hasValidDigest() else {
            return .invalid("Spartan/FRI compression digest mismatch")
        }
        guard proof.statement.profileID == policy.profileID else {
            return .invalid("Spartan/FRI compression profile mismatch")
        }
        guard proof.statement.shapeDigest == publicInput.shape.shapeDigest,
              proof.statement.statementDigest == CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
                recursiveRelationDigest: publicInput.recursiveRelationDigest
              ).statementDigest else {
            return .invalid("Spartan/FRI compression statement mismatch")
        }
        guard proof.statement.verifierKeyDigest == verifierKeyDigest,
              proof.statement.verifierKeyDigest == policy.verifierKeyDigest else {
            return .invalid("Spartan/FRI compression verifier key mismatch")
        }
        guard proof.statement.transcriptDomain == policy.transcriptDomain else {
            return .invalid("Spartan/FRI compression transcript domain mismatch")
        }
        guard policy.proofKindPolicy.accepts(proof.statement.sourceProofKind) else {
            return .invalid("Spartan/FRI compression source proof kind not accepted")
        }
        guard proof.statement.publicInputDigest == spartanFRIPublicInputDigest(publicInput) else {
            return .invalid("Spartan/FRI compression public input digest mismatch")
        }
        guard proof.terminalVerifierPCSProof.hasValidDigest() else {
            return .invalid("Spartan/FRI terminal verifier PCS digest mismatch")
        }
        guard proof.terminalVerifierPCSProof.sourceProofKind == proof.statement.sourceProofKind,
              proof.terminalVerifierPCSProof.sourceProofByteCount == proof.statement.sourceProofByteCount,
              proof.terminalVerifierPCSProof.sourceProofDigest == proof.statement.sourceProofDigest,
              proof.terminalVerifierPCSProof.profileID == proof.statement.profileID,
              proof.terminalVerifierPCSProof.shapeDigest == proof.statement.shapeDigest,
              proof.terminalVerifierPCSProof.statementDigest == proof.statement.statementDigest,
              proof.terminalVerifierPCSProof.verifierKeyDigest == proof.statement.verifierKeyDigest,
              proof.terminalVerifierPCSProof.transcriptDomain == proof.statement.transcriptDomain,
              proof.terminalVerifierPCSProof.publicInputDigest == proof.statement.publicInputDigest,
              proof.terminalVerifierPCSProof.terminalStatementDigest == proof.statement.terminalStatementDigest,
              proof.terminalVerifierPCSProof.foldProofDigest == proof.statement.foldProofDigest,
              proof.terminalVerifierPCSProof.ceOpeningProofDigest == proof.statement.ceOpeningProofDigest else {
            return .invalid("Spartan/FRI terminal verifier PCS relation mismatch")
        }
        let trace = spartanTraceVector(
            statement: proof.statement,
            terminalVerifierPCSProof: proof.terminalVerifierPCSProof,
            accepted: true
        )
        let pcsParameters = sourceFreePCSParameters(for: policy)
        let expectedPaddedDomainSize = spartanFRINextPowerOfTwo(trace.count * pcsParameters.blowupFactor)
        let expectedArithmetization = SuperNeoSpartanFRICompressionProof.arithmetizationDigest(
            statement: proof.statement,
            terminalVerifierPCSProof: proof.terminalVerifierPCSProof,
            traceLength: trace.count,
            paddedDomainSize: expectedPaddedDomainSize,
            blowupFactor: pcsParameters.blowupFactor,
            claimedDegreeBound: trace.count
        )
        guard proof.arithmetizationDigest == expectedArithmetization else {
            return .invalid("Spartan/FRI arithmetization digest mismatch")
        }
        guard proof.traceVectorLength == trace.count,
              proof.paddedDomainSize == expectedPaddedDomainSize else {
            return .invalid("Spartan/FRI trace dimension mismatch")
        }
        guard proof.witnessPCS.claimedDegreeBound == trace.count,
              proof.residualPCS.claimedDegreeBound == trace.count,
              proof.witnessPCS.blowupFactor == pcsParameters.blowupFactor,
              proof.residualPCS.blowupFactor == pcsParameters.blowupFactor,
              proof.witnessPCS.domainRoot == proof.residualPCS.domainRoot,
              proof.witnessPCS.cosetGenerator == proof.residualPCS.cosetGenerator else {
            return .invalid("Spartan/FRI PCS domain metadata mismatch")
        }
        let minimumQueryCount = min(pcsParameters.minimumQueryCount, max(1, proof.paddedDomainSize / 2))
        guard proof.witnessPCS.queryCount >= minimumQueryCount,
              proof.residualPCS.queryCount >= minimumQueryCount else {
            return .invalid("Spartan/FRI compression query count below selected minimum")
        }
        do {
            let witnessSamples = try verifyFRIProof(
                proof.witnessPCS,
                label: "witness-trace",
                bindingDigest: proof.arithmetizationDigest
            )
            let residualSamples = try verifyFRIProof(
                proof.residualPCS,
                label: "r1cs-residual",
                bindingDigest: proof.arithmetizationDigest
            )
            for sample in witnessSamples {
                guard sample.value == spartanFRIEvaluatePolynomial(trace, at: sample.point) else {
                    return .invalid("Spartan witness trace opening mismatch")
                }
            }
            for sample in residualSamples {
                guard sample.value == .zero else {
                    return .invalid("Spartan residual opening is nonzero")
                }
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }
}

private struct SpartanFRISample {
    let index: Int
    let point: GoldilocksField
    let value: GoldilocksField
}

private struct SpartanFRIMerkleTree {
    let domain: String
    let leaves: [GoldilocksField]
    let points: [GoldilocksField]
    let levels: [[Digest384]]

    init(domain: String, leaves: [GoldilocksField], points: [GoldilocksField]) throws {
        guard !leaves.isEmpty, leaves.count == points.count, leaves.count.nonzeroBitCount == 1 else {
            throw SuperNeoError.invalidParameter("FRI Merkle tree requires a nonempty power-of-two point/value domain")
        }
        self.domain = domain
        self.leaves = leaves
        self.points = points
        let leafDomain = "\(domain)/leaf"
        let nodeDomain = "\(domain)/node"
        var current = try spartanFRIParallelMap(count: leaves.count) { index in
            spartanFRILeafDigest(
                leafDomain: leafDomain,
                index: index,
                leafCount: leaves.count,
                point: points[index],
                value: leaves[index]
            )
        }
        var levels = [current]
        while current.count > 1 {
            let next = try spartanFRIParallelMap(count: current.count / 2) { pairIndex in
                let index = pairIndex * 2
                return SuperNeoSplitQRO.hBind(
                    domain: nodeDomain,
                    frames: [current[index].superNeoBytes, current[index + 1].superNeoBytes]
                )
            }
            levels.append(next)
            current = next
        }
        self.levels = levels
    }

    var root: Digest384 {
        levels.last?.first ?? SuperNeoSplitQRO.hMerkleLeaf(domain: domain, frames: [])
    }

    func opening(at index: Int) throws -> SuperNeoFRIMerkleOpening {
        guard index >= 0, index < leaves.count else {
            throw SuperNeoError.invalidParameter("FRI opening index out of range")
        }
        var pathIndex = index
        var siblings: [SuperNeoFRIMerkleSibling] = []
        siblings.reserveCapacity(max(0, levels.count - 1))
        for level in levels.dropLast() {
            if pathIndex % 2 == 0 {
                siblings.append(SuperNeoFRIMerkleSibling(position: .right, digest: level[pathIndex + 1]))
            } else {
                siblings.append(SuperNeoFRIMerkleSibling(position: .left, digest: level[pathIndex - 1]))
            }
            pathIndex /= 2
        }
        return SuperNeoFRIMerkleOpening(
            index: index,
            leafCount: leaves.count,
            point: points[index],
            value: leaves[index],
            siblings: siblings
        )
    }
}

private func spartanFRIParallelMap<T>(
    count: Int,
    threshold: Int = 256,
    _ body: @escaping (Int) throws -> T
) throws -> [T] {
    guard count > threshold else {
        return try (0..<count).map(body)
    }
    let lock = NSLock()
    var results = Array<Result<T, Error>?>(repeating: nil, count: count)
    DispatchQueue.concurrentPerform(iterations: count) { index in
        let result = Result { try body(index) }
        lock.lock()
        results[index] = result
        lock.unlock()
    }
    return try results.enumerated().map { index, result in
        guard let result else {
            throw SuperNeoError.invalidParameter("FRI parallel map missing result at index \(index)")
        }
        return try result.get()
    }
}

private struct SpartanFRIProverPlan {
    let vectorLength: Int
    let paddedDomainSize: Int
    let queryCount: Int
    let blowupFactor: Int
    let claimedDegreeBound: Int
    let domainRoot: GoldilocksField
    let cosetGenerator: GoldilocksField
    let label: String
    let bindingDigest: Digest256
    let commitments: [SuperNeoFRICommitment]
    let foldingChallenges: [GoldilocksField]
    let finalPolynomial: [GoldilocksField]
    let trees: [SpartanFRIMerkleTree]
}

func makeFRIProof(
    vector: [GoldilocksField],
    paddedDomainSize: Int,
    queryCount: Int,
    blowupFactor: Int = SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
    claimedDegreeBound: Int? = nil,
    label: String,
    bindingDigest: Digest256,
    queryIndicesOverride: [Int]? = nil
) throws -> SuperNeoFRIProof {
    let plan = try makeFRIProverPlan(
        vector: vector,
        paddedDomainSize: paddedDomainSize,
        queryCount: queryCount,
        blowupFactor: blowupFactor,
        claimedDegreeBound: claimedDegreeBound,
        label: label,
        bindingDigest: bindingDigest
    )
    return try makeFRIProof(plan: plan, queryIndicesOverride: queryIndicesOverride)
}

private func makeFRIProverPlan(
    vector: [GoldilocksField],
    paddedDomainSize: Int,
    queryCount: Int,
    blowupFactor: Int = SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
    claimedDegreeBound: Int? = nil,
    label: String,
    bindingDigest: Digest256
) throws -> SpartanFRIProverPlan {
    guard !vector.isEmpty else {
        throw SuperNeoError.invalidParameter("FRI proof requires a nonempty vector")
    }
    guard paddedDomainSize >= vector.count, paddedDomainSize.nonzeroBitCount == 1 else {
        throw SuperNeoError.invalidParameter("FRI proof requires a power-of-two padded domain")
    }
    guard blowupFactor > 0 else {
        throw SuperNeoError.invalidParameter("FRI blowup factor must be positive")
    }
    let degreeBound = claimedDegreeBound ?? vector.count
    guard degreeBound > 0, degreeBound <= vector.count else {
        throw SuperNeoError.invalidParameter("FRI claimed degree bound is invalid")
    }
    guard paddedDomainSize / blowupFactor >= degreeBound else {
        throw SuperNeoError.invalidParameter("FRI proof requires domain at least claimed degree times blowup")
    }
    guard queryCount > 0 else {
        throw SuperNeoError.invalidParameter("FRI query count must be positive")
    }
    let queryDomainSize = max(1, paddedDomainSize / 2)
    guard queryCount <= queryDomainSize else {
        throw SuperNeoError.invalidParameter("FRI query count exceeds folded pair domain")
    }
    let domainRoot = try spartanFRIRootOfUnity(order: paddedDomainSize)
    let cosetGenerator = try spartanFRICosetGenerator(order: paddedDomainSize)
    var coefficients = vector
    var currentDegreeBound = degreeBound
    var currentDomainSize = paddedDomainSize
    var currentRoot = domainRoot
    var currentCoset = cosetGenerator
    var trees: [SpartanFRIMerkleTree] = []
    var commitments: [SuperNeoFRICommitment] = []
    var challenges: [GoldilocksField] = []
    let roundCount = spartanFRIFoldingRoundCount(forDegreeBound: degreeBound)
    trees.reserveCapacity(roundCount + 1)
    commitments.reserveCapacity(roundCount + 1)
    challenges.reserveCapacity(roundCount)
    let baseDomain = "superneo/spartan-fri/\(label)"
    var round = 0
    while true {
        let points = spartanFRIDomainPoints(size: currentDomainSize, root: currentRoot, coset: currentCoset)
        let layerValues = try spartanFRIEvaluatePolynomialOnDomain(
            coefficients,
            size: currentDomainSize,
            root: currentRoot,
            coset: currentCoset
        )
        let tree = try SpartanFRIMerkleTree(domain: "\(baseDomain)/layer-\(round)", leaves: layerValues, points: points)
        let commitment = SuperNeoFRICommitment(domainSize: currentDomainSize, root: tree.root)
        trees.append(tree)
        commitments.append(commitment)
        guard currentDomainSize > 1, currentDegreeBound > 1 else { break }
        let alpha = spartanFRIChallenge(
            bindingDigest: bindingDigest,
            label: label,
            round: round,
            root: tree.root,
            domainSize: currentDomainSize,
            currentDegreeBound: currentDegreeBound,
            domainRoot: currentRoot,
            cosetGenerator: currentCoset,
            blowupFactor: blowupFactor
        )
        challenges.append(alpha)
        coefficients = spartanFRIFoldCoefficients(coefficients, challenge: alpha)
        currentDegreeBound = max(1, (currentDegreeBound + 1) / 2)
        currentDomainSize /= 2
        currentRoot = currentRoot.squared()
        currentCoset = currentCoset.squared()
        round += 1
    }
    let plan = SpartanFRIProverPlan(
        vectorLength: vector.count,
        paddedDomainSize: paddedDomainSize,
        queryCount: queryCount,
        blowupFactor: blowupFactor,
        claimedDegreeBound: degreeBound,
        domainRoot: domainRoot,
        cosetGenerator: cosetGenerator,
        label: label,
        bindingDigest: bindingDigest,
        commitments: commitments,
        foldingChallenges: challenges,
        finalPolynomial: [coefficients.first ?? .zero],
        trees: trees
    )
#if DEBUG
    SuperNeoSpartanFRIDebugProfileContext.current?.recordFRIPlan(plan)
#endif
    return plan
}

private func makeFRIProof(
    plan: SpartanFRIProverPlan,
    queryIndicesOverride: [Int]? = nil
) throws -> SuperNeoFRIProof {
    let queryDomainSize = max(1, plan.paddedDomainSize / 2)
    let roots = plan.commitments.map(\.root)
    let indices: [Int]
    if let queryIndicesOverride {
        try spartanFRIValidateQueryIndices(
            queryIndicesOverride,
            expectedCount: plan.queryCount,
            domainSize: queryDomainSize,
            name: "FRI query override"
        )
        indices = queryIndicesOverride
    } else {
        indices = spartanFRIQueryIndices(
            bindingDigest: plan.bindingDigest,
            label: plan.label,
            roots: roots,
            queryCount: plan.queryCount,
            domainSize: queryDomainSize
        )
    }
    let queryProofs = try indices.map { initialIndex -> SuperNeoFRIQueryProof in
        var layerIndex = 0
        var index = initialIndex
        var layerOpenings: [[SuperNeoFRIMerkleOpening]] = []
        while layerIndex < plan.trees.count - 1 {
            let halfDomain = plan.trees[layerIndex].leaves.count / 2
            let positiveIndex = index % halfDomain
            let negativeIndex = positiveIndex + halfDomain
            let nextIndex = positiveIndex
            layerOpenings.append([
                try plan.trees[layerIndex].opening(at: positiveIndex),
                try plan.trees[layerIndex].opening(at: negativeIndex),
                try plan.trees[layerIndex + 1].opening(at: nextIndex)
            ])
            index = nextIndex
            layerIndex += 1
        }
        return SuperNeoFRIQueryProof(initialIndex: initialIndex, layerOpenings: layerOpenings)
    }
    return try SuperNeoFRIProof(
        vectorLength: plan.vectorLength,
        paddedDomainSize: plan.paddedDomainSize,
        queryCount: indices.count,
        blowupFactor: plan.blowupFactor,
        claimedDegreeBound: plan.claimedDegreeBound,
        domainRoot: plan.domainRoot,
        cosetGenerator: plan.cosetGenerator,
        baseCommitment: plan.commitments[0],
        foldedCommitments: Array(plan.commitments.dropFirst()),
        foldingChallenges: plan.foldingChallenges,
        queryProofs: queryProofs,
        finalPolynomial: plan.finalPolynomial
    )
}

private func verifyFRIProof(
    _ proof: SuperNeoFRIProof,
    label: String,
    bindingDigest: Digest256,
    expectedQueryIndices: [Int]? = nil
) throws -> [SpartanFRISample] {
    guard proof.hasValidDigest() else {
        throw SuperNeoError.verificationFailed("FRI proof digest mismatch")
    }
    guard proof.paddedDomainSize.nonzeroBitCount == 1 else {
        throw SuperNeoError.verificationFailed("FRI domain is not a power of two")
    }
    guard proof.blowupFactor > 0,
          proof.paddedDomainSize / proof.blowupFactor >= proof.claimedDegreeBound else {
        throw SuperNeoError.verificationFailed("FRI domain is smaller than claimed degree times blowup")
    }
    guard proof.domainRoot.pow(UInt64(proof.paddedDomainSize)) == .one,
          proof.paddedDomainSize == 1 || proof.domainRoot.pow(UInt64(proof.paddedDomainSize / 2)) != .one else {
        throw SuperNeoError.verificationFailed("FRI domain root does not have exact padded order")
    }
    guard proof.cosetGenerator != .zero else {
        throw SuperNeoError.verificationFailed("FRI coset generator is zero")
    }
    guard proof.finalPolynomial.count == 1 else {
        throw SuperNeoError.verificationFailed("FRI final polynomial is not constant")
    }
    guard proof.queryCount > 0 else {
        throw SuperNeoError.verificationFailed("FRI query count must be positive")
    }
    guard proof.queryCount <= proof.paddedDomainSize else {
        throw SuperNeoError.verificationFailed("FRI query count exceeds padded domain")
    }
    let queryDomainSize = max(1, proof.paddedDomainSize / 2)
    guard proof.queryCount <= queryDomainSize else {
        throw SuperNeoError.verificationFailed("FRI query count exceeds folded pair domain")
    }
    guard proof.queryProofs.count == proof.queryCount else {
        throw SuperNeoError.verificationFailed("FRI query proof count mismatch")
    }
    guard Set(proof.queryProofs.map(\.initialIndex)).count == proof.queryProofs.count else {
        throw SuperNeoError.verificationFailed("FRI query indices must be unique")
    }
    let commitments = proof.commitments
    guard commitments.count == proof.foldingChallenges.count + 1 else {
        throw SuperNeoError.verificationFailed("FRI commitment/challenge count mismatch")
    }
    guard proof.foldingChallenges.count == spartanFRIFoldingRoundCount(forDegreeBound: proof.claimedDegreeBound) else {
        throw SuperNeoError.verificationFailed("FRI folding round count does not match claimed degree bound")
    }
    guard commitments.first?.domainSize == proof.paddedDomainSize else {
        throw SuperNeoError.verificationFailed("FRI commitment domain chain mismatch")
    }
    for round in 0..<(commitments.count - 1) {
        guard commitments[round].domainSize == commitments[round + 1].domainSize * 2 else {
            throw SuperNeoError.verificationFailed("FRI commitment domain chain mismatch")
        }
    }
    var terminalDegreeBound = proof.claimedDegreeBound
    for _ in proof.foldingChallenges.indices {
        terminalDegreeBound = max(1, (terminalDegreeBound + 1) / 2)
    }
    guard terminalDegreeBound == 1 else {
        throw SuperNeoError.verificationFailed("FRI final layer does not reach a constant degree bound")
    }
    var challengeDomainSize = proof.paddedDomainSize
    var challengeRoot = proof.domainRoot
    var challengeCoset = proof.cosetGenerator
    var challengeDegreeBound = proof.claimedDegreeBound
    var expectedChallenges: [GoldilocksField] = []
    expectedChallenges.reserveCapacity(proof.foldingChallenges.count)
    for round in proof.foldingChallenges.indices {
        expectedChallenges.append(
            spartanFRIChallenge(
                bindingDigest: bindingDigest,
                label: label,
                round: round,
                root: commitments[round].root,
                domainSize: challengeDomainSize,
                currentDegreeBound: challengeDegreeBound,
                domainRoot: challengeRoot,
                cosetGenerator: challengeCoset,
                blowupFactor: proof.blowupFactor
            )
        )
        challengeDomainSize /= 2
        challengeRoot = challengeRoot.squared()
        challengeCoset = challengeCoset.squared()
        challengeDegreeBound = max(1, (challengeDegreeBound + 1) / 2)
    }
    guard expectedChallenges == proof.foldingChallenges else {
        throw SuperNeoError.verificationFailed("FRI folding challenge mismatch")
    }
    let expectedQueries: [Int]
    if let expectedQueryIndices {
        try spartanFRIValidateQueryIndices(
            expectedQueryIndices,
            expectedCount: proof.queryCount,
            domainSize: queryDomainSize,
            name: "FRI expected query schedule"
        )
        expectedQueries = expectedQueryIndices
    } else {
        expectedQueries = spartanFRIQueryIndices(
            bindingDigest: bindingDigest,
            label: label,
            roots: commitments.map(\.root),
            queryCount: proof.queryCount,
            domainSize: queryDomainSize
        )
    }
    guard proof.queryProofs.map(\.initialIndex) == expectedQueries else {
        throw SuperNeoError.verificationFailed("FRI query schedule mismatch")
    }
    let baseDomain = "superneo/spartan-fri/\(label)"
    let layerDomains = commitments.indices.map { "\(baseDomain)/layer-\($0)" }
    let layerPathLengths = commitments.map { spartanFRILog2($0.domainSize) }
    var finalRoot = proof.domainRoot
    var finalCoset = proof.cosetGenerator
    for _ in 0..<proof.foldingChallenges.count {
        finalRoot = finalRoot.squared()
        finalCoset = finalCoset.squared()
    }
    let finalDomainSize = commitments.last?.domainSize ?? 0
    let finalDomain = layerDomains[proof.foldingChallenges.count]
    let finalPoints = spartanFRIDomainPoints(size: finalDomainSize, root: finalRoot, coset: finalCoset)
    let finalTree = try SpartanFRIMerkleTree(
        domain: finalDomain,
        leaves: Array(repeating: proof.finalPolynomial[0], count: finalDomainSize),
        points: finalPoints
    )
    guard finalTree.root == commitments.last?.root else {
        throw SuperNeoError.verificationFailed("FRI final constant check mismatch")
    }

    var initialSamples: [SpartanFRISample] = []
    initialSamples.reserveCapacity(proof.queryProofs.count * 2)
    let invTwo = try GoldilocksField(2).inverse()
    for query in proof.queryProofs {
        var index = query.initialIndex
        var currentDomainSize = proof.paddedDomainSize
        var currentRoot = proof.domainRoot
        var currentCoset = proof.cosetGenerator
        var carried: SpartanFRISample?
        guard query.layerOpenings.count == proof.foldingChallenges.count else {
            throw SuperNeoError.verificationFailed("FRI query layer count mismatch")
        }
        for round in 0..<query.layerOpenings.count {
            let openings = query.layerOpenings[round]
            guard openings.count == 3 else {
                throw SuperNeoError.verificationFailed("FRI query opening arity mismatch")
            }
            let positive = openings[0]
            let negative = openings[1]
            let next = openings[2]
            let halfDomain = currentDomainSize / 2
            let positiveIndex = index % halfDomain
            let negativeIndex = positiveIndex + halfDomain
            let nextIndex = positiveIndex
            guard positive.index == positiveIndex,
                  negative.index == negativeIndex,
                  next.index == nextIndex else {
                throw SuperNeoError.verificationFailed("FRI query index mismatch")
            }
            let positivePoint = spartanFRIDomainPoint(index: positiveIndex, root: currentRoot, coset: currentCoset)
            let negativePoint = spartanFRIDomainPoint(index: negativeIndex, root: currentRoot, coset: currentCoset)
            let nextRoot = currentRoot.squared()
            let nextCoset = currentCoset.squared()
            let nextPoint = spartanFRIDomainPoint(index: nextIndex, root: nextRoot, coset: nextCoset)
            guard positive.point == positivePoint,
                  negative.point == negativePoint,
                  next.point == nextPoint,
                  negative.point == -positive.point,
                  next.point == positive.point.squared() else {
                throw SuperNeoError.verificationFailed("FRI domain point mismatch")
            }
            if let carried {
                guard (positive.index == carried.index && positive.value == carried.value && positive.point == carried.point)
                    || (negative.index == carried.index && negative.value == carried.value && negative.point == carried.point) else {
                    throw SuperNeoError.verificationFailed("FRI folded-layer carry mismatch")
                }
            }
            guard positive.leafCount == commitments[round].domainSize,
                  negative.leafCount == commitments[round].domainSize,
                  next.leafCount == commitments[round + 1].domainSize else {
                throw SuperNeoError.verificationFailed("FRI Merkle opening leaf count mismatch")
            }
            guard positive.siblings.count == layerPathLengths[round],
                  negative.siblings.count == layerPathLengths[round],
                  next.siblings.count == layerPathLengths[round + 1] else {
                throw SuperNeoError.verificationFailed("FRI Merkle opening path length mismatch")
            }
            guard positive.verifies(root: commitments[round].root, domain: layerDomains[round]),
                  negative.verifies(root: commitments[round].root, domain: layerDomains[round]),
                  next.verifies(root: commitments[round + 1].root, domain: layerDomains[round + 1]) else {
                throw SuperNeoError.verificationFailed("FRI Merkle opening mismatch")
            }
            let invTwoX = try (positive.point + positive.point).inverse()
            let evenEvaluation = (positive.value + negative.value) * invTwo
            let oddEvaluation = (positive.value - negative.value) * invTwoX
            let folded = evenEvaluation + proof.foldingChallenges[round] * oddEvaluation
            guard folded == next.value else {
                throw SuperNeoError.verificationFailed("FRI folding equation mismatch")
            }
            if round == query.layerOpenings.count - 1 {
                guard next.value == proof.finalPolynomial[0] else {
                    throw SuperNeoError.verificationFailed("FRI final constant opening mismatch")
                }
            }
            if round == 0 {
                initialSamples.append(SpartanFRISample(index: positive.index, point: positive.point, value: positive.value))
                initialSamples.append(SpartanFRISample(index: negative.index, point: negative.point, value: negative.value))
            }
            carried = SpartanFRISample(index: next.index, point: next.point, value: next.value)
            index = nextIndex
            currentDomainSize /= 2
            currentRoot = nextRoot
            currentCoset = nextCoset
        }
    }
    return initialSamples
}

private struct TerminalVerifierDecodedSource {
    let foldProof: FoldProof
    let foldTranscriptSeed: [UInt8]
    let terminalStatement: TerminalCEStatement
    let ceOpeningProof: CEOpeningProof
    let compressedEnvelope: CompressedTerminalProofEnvelope?
    let sourceDigests: (
        terminalStatementDigest: Digest256,
        foldProofDigest: Digest256,
        ceOpeningProofDigest: Digest256
    )
}

private func decodeTerminalVerifierSource(
    proofBytes: [UInt8],
    header: ProofEnvelopeHeader,
    parameters: SuperNeoParameters,
    expectedContext: ProofEnvelopeContext
) throws -> TerminalVerifierDecodedSource {
    switch header.kind {
    case .terminalLocal:
        let envelope = try TerminalFoldProofEnvelope(bytes: proofBytes, parameters: parameters)
        return TerminalVerifierDecodedSource(
            foldProof: envelope.proof.foldProof,
            foldTranscriptSeed: envelope.header.transcriptBindingBytes,
            terminalStatement: envelope.proof.terminalStatement,
            ceOpeningProof: envelope.proof.ceOpeningProof,
            compressedEnvelope: nil,
            sourceDigests: (
                envelope.proof.terminalStatement.statementDigest,
                Digest256.hash(envelope.proof.foldProof.superNeoBytes),
                Digest256.hash(envelope.proof.ceOpeningProof.superNeoBytes)
            )
        )
    case .compressedPublic:
        let envelope = try CompressedTerminalProofEnvelope(bytes: proofBytes, parameters: parameters)
        let terminalStatement = try TerminalCEStatement(
            profileID: expectedContext.profileID,
            shapeDigest: expectedContext.shapeDigest,
            verifierKeyDigest: expectedContext.verifierKeyDigest,
            claims: envelope.proof.foldProof.outputClaims
        )
        let terminalContext = ProofEnvelopeContext(
            profileID: expectedContext.profileID,
            kind: .terminalLocal,
            shapeDigest: expectedContext.shapeDigest,
            statementDigest: expectedContext.statementDigest,
            verifierKeyDigest: expectedContext.verifierKeyDigest,
            transcriptDomain: expectedContext.transcriptDomain
        )
        return TerminalVerifierDecodedSource(
            foldProof: envelope.proof.foldProof,
            foldTranscriptSeed: terminalContext.transcriptBindingBytes,
            terminalStatement: terminalStatement,
            ceOpeningProof: envelope.proof.ceOpeningProof,
            compressedEnvelope: envelope,
            sourceDigests: (
                envelope.proof.statement.terminalStatementDigest,
                envelope.proof.foldProofDigest,
                envelope.proof.ceOpeningProofDigest
            )
        )
    case .foldReduction, .numiSealTerminal, .numiSealZK:
        throw SuperNeoError.invalidParameter("Spartan/FRI compression source must be terminal or compressed-public")
    }
}

private func spartanTraceVector(
    statement: SuperNeoSpartanFRICompressionStatement,
    terminalVerifierPCSProof: SuperNeoTerminalVerifierPCSProof,
    accepted: Bool
) -> [GoldilocksField] {
    var trace: [GoldilocksField] = [
        GoldilocksField(0x5350_4152_5441_4E31),
        GoldilocksField(UInt64(SuperNeoSpartanFRICompressionProof.version)),
        GoldilocksField(UInt64(statement.sourceProofKind.rawValue)),
        GoldilocksField(UInt64(statement.sourceProofByteCount)),
        GoldilocksField(UInt64(statement.profileID))
    ]
    trace.append(contentsOf: spartanFRIDigestFields(statement.sourceProofDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.shapeDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.statementDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.verifierKeyDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.transcriptDomain))
    trace.append(contentsOf: spartanFRIDigestFields(statement.publicInputDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.terminalStatementDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.foldProofDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.ceOpeningProofDigest))
    trace.append(contentsOf: spartanFRIDigestFields(terminalVerifierPCSProof.relationDigest))
    trace.append(contentsOf: spartanFRIDigest384Fields(terminalVerifierPCSProof.tracePCS.baseCommitment.root))
    trace.append(contentsOf: spartanFRIDigest384Fields(terminalVerifierPCSProof.residualPCS.baseCommitment.root))
    trace.append(contentsOf: spartanFRIDigest384Fields(terminalVerifierPCSProof.proofDigest))
    trace.append(accepted ? .one : .zero)
    return trace
}

private func terminalVerifierCompressionPolicyDigest(_ policy: SuperNeoTerminalProofAcceptancePolicy) -> Digest256 {
    let kindPolicyByte: UInt8
    switch policy.proofKindPolicy {
    case .terminalOrCompressed:
        kindPolicyByte = 0
    case .terminalOnly:
        kindPolicyByte = 1
    case .compressedOnly:
        kindPolicyByte = 2
    }
    let sourceFreePCSByte = policy.sourceFreePCSPolicy.rawValue
    return Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier.compression-policy.v1".utf8)
            + spartanFRIEncodeUInt16(policy.profileID)
            + policy.shapeDigest.superNeoBytes
            + policy.statementDigest.superNeoBytes
            + policy.verifierKeyDigest.superNeoBytes
            + policy.transcriptDomain.superNeoBytes
            + [kindPolicyByte]
            + [sourceFreePCSByte]
            + (policy.maximumProofByteCount.map { [UInt8(1)] + spartanFRIEncodeCount($0) } ?? [UInt8(0)])
    )
}

private struct SourceFreePCSParameters {
    let minimumQueryCount: Int
    let blowupFactor: Int
}

private func sourceFreePCSParameters(
    for policy: SuperNeoTerminalProofAcceptancePolicy
) -> SourceFreePCSParameters {
    switch policy.sourceFreePCSPolicy {
    case .production:
        return SourceFreePCSParameters(
            minimumQueryCount: SuperNeoSpartanFRICompressionProof.defaultQueryCount,
            blowupFactor: SuperNeoSpartanFRICompressionProof.defaultBlowupFactor
        )
    case .sourceFreeTinyPCSFixtureOnly:
        return SourceFreePCSParameters(
            minimumQueryCount: 1,
            blowupFactor: 1
        )
    }
}

private func terminalVerifierAIRPublicCoinBindingDigest(
    transcriptDomain: Digest256,
    statementDigest: Digest256,
    publicInputDigest: Digest256,
    recursiveRelationDigest: Digest256?
) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier-air.public-coins.v1".utf8)
            + transcriptDomain.superNeoBytes
            + statementDigest.superNeoBytes
            + publicInputDigest.superNeoBytes
            + (recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
    )
}

private func terminalVerifierAIRInnerCompressedDigest(
    statement: SuperNeoSpartanFRICompressionStatement,
    policyDigest: Digest256
) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier-air.inner-compressed-proof.v1".utf8)
            + statement.statementCompressionDigest.superNeoBytes
            + policyDigest.superNeoBytes
            + statement.terminalStatementDigest.superNeoBytes
            + statement.foldProofDigest.superNeoBytes
            + statement.ceOpeningProofDigest.superNeoBytes
    )
}

private func terminalVerifierAIRNoInnerCompressedDigest() -> Digest256 {
    Digest256.hash("SuperNeo-NuMetal.terminal-verifier-air.no-inner-compressed-proof.v1")
}

private struct TerminalVerifierAIRConstraintMaterial {
    let piCCSRows: [SuperNeoTerminalVerifierAIRConstraintRow]
    let piRLCRows: [SuperNeoTerminalVerifierAIRConstraintRow]
    let piDECRows: [SuperNeoTerminalVerifierAIRConstraintRow]
    let terminalCERows: [SuperNeoTerminalVerifierAIRConstraintRow]
    let innerCompressedRows: [SuperNeoTerminalVerifierAIRConstraintRow]
}

private func terminalVerifierAIRConstraintMaterialForSource(
    publicInput: SuperNeoPublicFoldInput,
    verifier: SuperNeoVerifier,
    decodedSource: TerminalVerifierDecodedSource
) throws -> TerminalVerifierAIRConstraintMaterial {
    let innerCompressedRows = decodedSource.compressedEnvelope.map {
        terminalVerifierAIRInnerCompressedPrimitiveRows(envelope: $0)
    } ?? terminalVerifierAIRNoInnerCompressedPrimitiveRows()
#if DEBUG
    let foldRows = try superNeoDebugMeasure("fold-boundary primitive row emission") {
        try verifier.terminalVerifierAIRPrimitiveRows(
            publicInput: publicInput,
            proof: decodedSource.foldProof,
            transcriptSeed: decodedSource.foldTranscriptSeed
        )
    }
    let ceRows = try superNeoDebugMeasure("ce-ajtai primitive row emission") {
        try CEOpeningRelation.terminalVerifierAIRPrimitiveRows(
            proof: decodedSource.ceOpeningProof,
            statement: decodedSource.terminalStatement,
            shape: publicInput.shape,
            key: verifier.key,
            parameters: verifier.parameters,
            metalWorkspace: nil,
            executionPolicy: verifier.executionPolicy
        )
    }
#else
    let foldRows = try verifier.terminalVerifierAIRPrimitiveRows(
        publicInput: publicInput,
        proof: decodedSource.foldProof,
        transcriptSeed: decodedSource.foldTranscriptSeed
    )
    let ceRows = try CEOpeningRelation.terminalVerifierAIRPrimitiveRows(
        proof: decodedSource.ceOpeningProof,
        statement: decodedSource.terminalStatement,
        shape: publicInput.shape,
        key: verifier.key,
        parameters: verifier.parameters,
        metalWorkspace: nil,
        executionPolicy: verifier.executionPolicy
    )
#endif
    return TerminalVerifierAIRConstraintMaterial(
        piCCSRows: foldRows.piCCSRows,
        piRLCRows: foldRows.piRLCRows,
        piDECRows: foldRows.piDECRows,
        terminalCERows: ceRows,
        innerCompressedRows: innerCompressedRows
    )
}

private func terminalVerifierAIRConstraintRows(
    sourceProofKind: ProofEnvelopeKind,
    sourceProofByteCount: Int,
    sourceProofDigest: Digest256,
    canonicalSourceEncodingDigest: Digest256,
    profileID: UInt16,
    shapeDigest: Digest256,
    statementDigest: Digest256,
    verifierKeyDigest: Digest256,
    transcriptDomain: Digest256,
    publicInputDigest: Digest256,
    recursiveRelationDigest: Digest256?,
    compressionPolicyDigest: Digest256,
    terminalStatementDigest: Digest256,
    foldProofDigest: Digest256,
    ceOpeningProofDigest: Digest256,
    publicCoinBindingDigest: Digest256,
    innerCompressedProofDigest: Digest256?,
    contextBound: Bool,
    sourceDigestComputed: Bool,
    verifierKeyBound: Bool,
    publicStatementBound: Bool,
    recursiveRelationBound: Bool,
    compressionPolicyBound: Bool,
    piCCSChecks: [SuperNeoTerminalVerifierAIRConstraintRow],
    piRLCChecks: [SuperNeoTerminalVerifierAIRConstraintRow],
    piDECChecks: [SuperNeoTerminalVerifierAIRConstraintRow],
    terminalCEChecks: [SuperNeoTerminalVerifierAIRConstraintRow],
    innerCompressedChecks: [SuperNeoTerminalVerifierAIRConstraintRow]
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    var rows: [SuperNeoTerminalVerifierAIRConstraintRow] = []
    rows.append(.required(
        sourceProofKind == .terminalLocal || sourceProofKind == .compressedPublic,
        kind: .canonicalSourceRepresentation,
        provenance: .canonicalDecoding,
        label: "source-kind-terminal"
    ))
    rows.append(.required(
        sourceProofByteCount > ProofEnvelopeHeader.byteCount,
        kind: .canonicalSourceRepresentation,
        provenance: .canonicalDecoding,
        label: "source-byte-count"
    ))
    rows.append(.required(
        contextBound,
        kind: .canonicalSourceRepresentation,
        provenance: .canonicalDecoding,
        label: "canonical-context-bound"
    ))
    rows.append(.required(
        sourceDigestComputed,
        kind: .canonicalSourceRepresentation,
        provenance: .hashSubrelation,
        label: "source-digest-computed-from-canonical-encoding"
    ))
    rows.append(contentsOf: terminalVerifierAIRDigestRows(
        kind: .canonicalSourceRepresentation,
        provenance: .hashSubrelation,
        label: "source-digest",
        observed: sourceProofDigest,
        expected: canonicalSourceEncodingDigest
    ))
    rows.append(terminalVerifierAIRFieldRow(
        kind: .publicBinding,
        provenance: .publicInputBinding,
        label: "profile-id",
        observed: GoldilocksField(UInt64(profileID)),
        expected: GoldilocksField(UInt64(profileID))
    ))
    for (label, digest) in [
        ("shape", shapeDigest),
        ("statement", statementDigest),
        ("verifier-key", verifierKeyDigest),
        ("transcript-domain", transcriptDomain),
        ("public-input", publicInputDigest),
        ("compression-policy", compressionPolicyDigest),
        ("terminal-statement", terminalStatementDigest),
        ("fold-proof", foldProofDigest),
        ("ce-opening-proof", ceOpeningProofDigest),
        ("public-coin-binding", publicCoinBindingDigest)
    ] {
        rows.append(contentsOf: terminalVerifierAIRDigestRows(
            kind: .publicBinding,
            provenance: .publicInputBinding,
            label: label,
            observed: digest,
            expected: digest
        ))
    }
    rows.append(.required(verifierKeyBound, kind: .publicBinding, provenance: .publicInputBinding, label: "verifier-key-bound"))
    rows.append(.required(publicStatementBound, kind: .publicBinding, provenance: .publicInputBinding, label: "public-statement-bound"))
    rows.append(.required(recursiveRelationBound, kind: .publicBinding, provenance: .publicInputBinding, label: "recursive-relation-bound"))
    rows.append(.required(compressionPolicyBound, kind: .publicBinding, provenance: .publicInputBinding, label: "compression-policy-bound"))
    if let recursiveRelationDigest {
        rows.append(contentsOf: terminalVerifierAIRDigestRows(
            kind: .publicBinding,
            provenance: .publicInputBinding,
            label: "recursive-relation-public-input",
            observed: recursiveRelationDigest,
            expected: recursiveRelationDigest
        ))
    }
    rows.append(contentsOf: piCCSChecks)
    rows.append(contentsOf: piRLCChecks)
    rows.append(contentsOf: piDECChecks)
    rows.append(contentsOf: terminalCEChecks)
    rows.append(contentsOf: innerCompressedChecks)
    return rows
}

private func terminalVerifierAIRRejectedPrimitiveRows(
    kind: SuperNeoTerminalVerifierAIRConstraintKind
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    [
        .required(
            false,
            kind: kind,
            provenance: .canonicalDecoding,
            label: "unsupported-source-kind"
        )
    ]
}

private func terminalVerifierAIRNoInnerCompressedPrimitiveRows(
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    [
        terminalVerifierAIRFieldRow(
            kind: .innerCompressedProofVerifier,
            provenance: .canonicalDecoding,
            label: "inner-compressed-disabled",
            observed: .zero,
            expected: .zero
        )
    ]
}

private func terminalVerifierAIRInnerCompressedPrimitiveRows(
    envelope: CompressedTerminalProofEnvelope
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    let proof = envelope.proof
    let compressionDigest = Digest256.hash(
        CompressedTerminalProof.transcriptDomain.superNeoBytes
            + proof.statement.statementDigest.superNeoBytes
            + proof.foldProofDigest.superNeoBytes
            + proof.ceOpeningProofDigest.superNeoBytes
    )
    var rows: [SuperNeoTerminalVerifierAIRConstraintRow] = [
        terminalVerifierAIRFieldRow(
            kind: .innerCompressedProofVerifier,
            provenance: .canonicalDecoding,
            label: "inner-compressed-kind",
            observed: GoldilocksField(UInt64(envelope.header.kind.rawValue)),
            expected: GoldilocksField(UInt64(ProofEnvelopeKind.compressedPublic.rawValue))
        )
    ]
    rows.append(contentsOf: terminalVerifierAIRDigestRows(
        kind: .innerCompressedProofVerifier,
        provenance: .hashSubrelation,
        label: "inner-compressed-fold-proof-digest",
        observed: proof.foldProofDigest,
        expected: Digest256.hash(proof.foldProof.superNeoBytes)
    ))
    rows.append(contentsOf: terminalVerifierAIRDigestRows(
        kind: .innerCompressedProofVerifier,
        provenance: .hashSubrelation,
        label: "inner-compressed-ce-opening-digest",
        observed: proof.ceOpeningProofDigest,
        expected: Digest256.hash(proof.ceOpeningProof.superNeoBytes)
    ))
    rows.append(contentsOf: terminalVerifierAIRDigestRows(
        kind: .innerCompressedProofVerifier,
        provenance: .hashSubrelation,
        label: "inner-compressed-transcript-digest",
        observed: proof.compressionDigest,
        expected: compressionDigest
    ))
    rows.append(contentsOf: terminalVerifierAIRDigestRows(
        kind: .innerCompressedProofVerifier,
        provenance: .publicInputBinding,
        label: "inner-compressed-header-statement",
        observed: envelope.header.statementDigest,
        expected: proof.statement.context.statementDigest
    ))
    rows.append(contentsOf: terminalVerifierAIRDigestRows(
        kind: .innerCompressedProofVerifier,
        provenance: .publicInputBinding,
        label: "inner-compressed-public-input",
        observed: proof.statement.publicInputDigest,
        expected: proof.statement.publicInputDigest
    ))
    return rows
}

private func terminalVerifierAIRSourceFreePCSRows(
    kind: SuperNeoTerminalVerifierAIRConstraintKind,
    label: String
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    [
        terminalVerifierAIRFieldRow(
            kind: kind,
            provenance: .friPCSVerifier,
            label: "source-free-\(label)-pcs-bound-residual",
            observed: .zero,
            expected: .zero
        )
    ]
}

private func terminalVerifierAIRSourceFreeInnerCompressedRows(
    sourceProofKind: ProofEnvelopeKind,
    hasInnerDigest: Bool
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    if sourceProofKind == .compressedPublic {
        return [
            terminalVerifierAIRFieldRow(
                kind: .innerCompressedProofVerifier,
                provenance: .friPCSVerifier,
                label: "source-free-inner-compressed-domain-separated",
                observed: hasInnerDigest ? .one : .zero,
                expected: .one
            )
        ]
    }
    return [
        terminalVerifierAIRFieldRow(
            kind: .innerCompressedProofVerifier,
            provenance: .friPCSVerifier,
            label: "source-free-inner-compressed-disabled",
            observed: .zero,
            expected: .zero
        )
    ]
}

private func terminalVerifierAIRDigestRows(
    kind: SuperNeoTerminalVerifierAIRConstraintKind,
    provenance: SuperNeoTerminalVerifierAIRRowProvenance = .hashSubrelation,
    label: String,
    observed: Digest256,
    expected: Digest256
) -> [SuperNeoTerminalVerifierAIRConstraintRow] {
    zip(spartanFRIDigestFields(observed), spartanFRIDigestFields(expected)).enumerated().map { index, pair in
        terminalVerifierAIRFieldRow(
            kind: kind,
            provenance: provenance,
            label: "\(label)-limb-\(index)",
            observed: pair.0,
            expected: pair.1
        )
    }
}

private func terminalVerifierAIRFieldRow(
    kind: SuperNeoTerminalVerifierAIRConstraintKind,
    provenance: SuperNeoTerminalVerifierAIRRowProvenance = .primitiveArithmetic,
    label: String,
    observed: GoldilocksField,
    expected: GoldilocksField
) -> SuperNeoTerminalVerifierAIRConstraintRow {
    SuperNeoTerminalVerifierAIRConstraintRow(
        kind: kind,
        provenance: provenance,
        label: label,
        observed: observed,
        expected: expected
    )
}

private enum TerminalVerifierAIRSubrelationKind: UInt8, CaseIterable {
    case canonicalSourceRepresentation = 1
    case publicBinding = 2
    case piCCSVerifier = 3
    case piRLCVerifier = 4
    case piDECVerifier = 5
    case terminalCEOpening = 6
    case innerCompressedProofVerifier = 7
    case acceptAggregation = 8
}

private struct TerminalVerifierAIRSubrelation {
    let kind: TerminalVerifierAIRSubrelationKind
    let enabled: Bool
    let inputDigest: Digest256
    let outputDigest: Digest256
    let constraintDigest: Digest256
    let traceTerms: [GoldilocksField]
    let residualTerms: [GoldilocksField]
}

private struct TerminalVerifierAIRInstance {
    let trace: [GoldilocksField]
    let residual: [GoldilocksField]
    let subrelations: [TerminalVerifierAIRSubrelation]
}

private func terminalVerifierAIRInstance(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    terminalVerifierRelationDigest: Digest256?,
    compactForTinyFixture: Bool = false
) -> TerminalVerifierAIRInstance {
    let recursiveDigest = terminalVerifierAIRRecursiveRelationDigest(publicInput.recursiveRelationDigest)
    let selectedProfileDigest = terminalVerifierAIRSelectedProfileDigest(spec: spec, publicInput: publicInput)
    let priorClaimRoot = terminalVerifierAIRPriorClaimRoot(publicInput)
    let terminalRelationDigest = terminalVerifierRelationDigest ?? terminalVerifierAIRPendingRelationDigest()
    let rowBindingContext = TerminalVerifierAIRRowBindingContext(
        spec: spec,
        terminalVerifierRelationDigest: terminalRelationDigest,
        recursiveDigest: recursiveDigest
    )
    var subrelations = terminalVerifierAIRCoreSubrelations(
        spec: spec,
        publicInput: publicInput,
        terminalVerifierRelationDigest: terminalRelationDigest,
        recursiveDigest: recursiveDigest,
        selectedProfileDigest: selectedProfileDigest,
        priorClaimRoot: priorClaimRoot,
        rowBindingContext: rowBindingContext
    )
    subrelations.append(
        terminalVerifierAIRAcceptSubrelation(
            spec: spec,
            priorResiduals: subrelations.flatMap(\.residualTerms),
            rowBindingContext: rowBindingContext
        )
    )
    if compactForTinyFixture {
        return terminalVerifierAIRPackCompactTrace(
            subrelations: subrelations,
            spec: spec,
            publicInput: publicInput,
            terminalVerifierRelationDigest: terminalRelationDigest,
            recursiveDigest: recursiveDigest,
            selectedProfileDigest: selectedProfileDigest,
            priorClaimRoot: priorClaimRoot
        )
    }
    return terminalVerifierAIRPackTrace(
        subrelations: subrelations,
        spec: spec,
        publicInput: publicInput,
        terminalVerifierRelationDigest: terminalRelationDigest,
        recursiveDigest: recursiveDigest,
        selectedProfileDigest: selectedProfileDigest,
        priorClaimRoot: priorClaimRoot
    )
}

private func terminalVerifierAIRCoreSubrelations(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    terminalVerifierRelationDigest: Digest256,
    recursiveDigest: Digest256,
    selectedProfileDigest: Digest256,
    priorClaimRoot: Digest256,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> [TerminalVerifierAIRSubrelation] {
    [
        terminalVerifierAIRCanonicalSourceSubrelation(
            spec: spec,
            rowBindingContext: rowBindingContext
        ),
        terminalVerifierAIRPublicBindingSubrelation(
            spec: spec,
            publicInput: publicInput,
            terminalVerifierRelationDigest: terminalVerifierRelationDigest,
            recursiveDigest: recursiveDigest,
            selectedProfileDigest: selectedProfileDigest,
            rowBindingContext: rowBindingContext
        ),
        terminalVerifierAIRPiCCSSubrelation(
            spec: spec,
            publicInput: publicInput,
            rowBindingContext: rowBindingContext
        ),
        terminalVerifierAIRPiRLCSubrelation(
            spec: spec,
            publicInput: publicInput,
            recursiveDigest: recursiveDigest,
            priorClaimRoot: priorClaimRoot,
            rowBindingContext: rowBindingContext
        ),
        terminalVerifierAIRPiDECSubrelation(
            spec: spec,
            publicInput: publicInput,
            rowBindingContext: rowBindingContext
        ),
        terminalVerifierAIRTerminalCESubrelation(
            spec: spec,
            publicInput: publicInput,
            rowBindingContext: rowBindingContext
        ),
        terminalVerifierAIRInnerCompressedProofSubrelation(
            spec: spec,
            publicInput: publicInput,
            policyDigest: spec.compressionPolicyDigest,
            rowBindingContext: rowBindingContext
        )
    ]
}

private func terminalVerifierAIRCanonicalSourceSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .canonicalSourceRepresentation,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.canonical-source.v1",
        rowBindingContext: rowBindingContext
    )
    builder.appendRequiredTrue(
        spec.sourceProofKind == .terminalLocal || spec.sourceProofKind == .compressedPublic
    )
    builder.appendPair(
        GoldilocksField(UInt64(spec.sourceProofKind.rawValue)),
        GoldilocksField(UInt64(spec.sourceProofKind.rawValue))
    )
    builder.appendPair(
        GoldilocksField(UInt64(spec.sourceProofByteCount)),
        GoldilocksField(UInt64(spec.sourceProofByteCount))
    )
    builder.appendDigestPair(spec.sourceProofDigest)
    builder.appendDigestPair(spec.canonicalSourceEncodingDigest)
    builder.appendDigestPair(spec.terminalStatementDigest)
    builder.appendDigestPair(spec.foldProofDigest)
    builder.appendDigestPair(spec.ceOpeningProofDigest)
    builder.appendConstraintRows(spec.constraints(for: .canonicalSourceRepresentation))
    return builder.finish()
}

private func terminalVerifierAIRPublicBindingSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    terminalVerifierRelationDigest: Digest256,
    recursiveDigest: Digest256,
    selectedProfileDigest: Digest256,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .publicBinding,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.public-binding.v1",
        rowBindingContext: rowBindingContext
    )
    builder.appendPair(GoldilocksField(UInt64(spec.profileID)), GoldilocksField(UInt64(spec.profileID)))
    builder.appendPair(GoldilocksField(UInt64(publicInput.instances.count)), GoldilocksField(UInt64(publicInput.instances.count)))
    builder.appendPair(GoldilocksField(UInt64(publicInput.priorClaims.count)), GoldilocksField(UInt64(publicInput.priorClaims.count)))
    builder.appendDigestPair(spec.shapeDigest)
    builder.appendDigestPair(spec.statementDigest)
    builder.appendDigestPair(spec.verifierKeyDigest)
    builder.appendDigestPair(spec.transcriptDomain)
    builder.appendDigestPair(spec.publicInputDigest)
    builder.appendDigestPair(recursiveDigest)
    builder.appendDigestPair(spec.compressionPolicyDigest)
    builder.appendDigestPair(terminalVerifierRelationDigest)
    builder.appendDigestPair(selectedProfileDigest)
    builder.appendDigestPair(spec.specDigest)
    builder.appendConstraintRows(spec.constraints(for: .publicBinding))
    return builder.finish()
}

private func terminalVerifierAIRPiCCSSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .piCCSVerifier,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.piccs.v1",
        rowBindingContext: rowBindingContext
    )
    builder.appendDigestPair(spec.statementDigest)
    builder.appendDigestPair(spec.shapeDigest)
    builder.appendDigestPair(spec.publicInputDigest)
    builder.appendDigestPair(spec.foldProofDigest)
    builder.appendPair(GoldilocksField(UInt64(publicInput.instances.count)), GoldilocksField(UInt64(publicInput.instances.count)))
    builder.appendPair(GoldilocksField(UInt64(publicInput.priorClaims.count)), GoldilocksField(UInt64(publicInput.priorClaims.count)))
    builder.appendConstraintRows(spec.constraints(for: .piCCSVerifier))
    return builder.finish()
}

private func terminalVerifierAIRPiRLCSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    recursiveDigest: Digest256,
    priorClaimRoot: Digest256,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .piRLCVerifier,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.pirlc.v1",
        rowBindingContext: rowBindingContext
    )
    builder.appendDigestPair(spec.foldProofDigest)
    builder.appendDigestPair(spec.transcriptDomain)
    builder.appendDigestPair(recursiveDigest)
    builder.appendDigestPair(priorClaimRoot)
    builder.appendDigestPair(spec.publicCoinBindingDigest)
    builder.appendPair(GoldilocksField(UInt64(publicInput.priorClaims.count)), GoldilocksField(UInt64(publicInput.priorClaims.count)))
    builder.appendConstraintRows(spec.constraints(for: .piRLCVerifier))
    return builder.finish()
}

private func terminalVerifierAIRPiDECSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .piDECVerifier,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.pidec.v1",
        rowBindingContext: rowBindingContext
    )
    builder.appendDigestPair(spec.ceOpeningProofDigest)
    builder.appendDigestPair(spec.terminalStatementDigest)
    builder.appendDigestPair(spec.publicInputDigest)
    builder.appendPair(GoldilocksField(UInt64(publicInput.instances.count)), GoldilocksField(UInt64(publicInput.instances.count)))
    builder.appendConstraintRows(spec.constraints(for: .piDECVerifier))
    return builder.finish()
}

private func terminalVerifierAIRTerminalCESubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .terminalCEOpening,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.terminal-ce.v1",
        rowBindingContext: rowBindingContext
    )
    builder.appendDigestPair(spec.terminalStatementDigest)
    builder.appendDigestPair(spec.ceOpeningProofDigest)
    builder.appendDigestPair(spec.verifierKeyDigest)
    builder.appendDigestPair(spec.shapeDigest)
    builder.appendPair(GoldilocksField(UInt64(publicInput.instances.count)), GoldilocksField(UInt64(publicInput.instances.count)))
    builder.appendConstraintRows(spec.constraints(for: .terminalCEOpening))
    return builder.finish()
}

private func terminalVerifierAIRInnerCompressedProofSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    policyDigest: Digest256,
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    let enabled = spec.sourceProofKind == .compressedPublic
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .innerCompressedProofVerifier,
        enabled: enabled,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.inner-compressed-proof.v1",
        rowBindingContext: rowBindingContext
    )
    let selector = enabled ? GoldilocksField.one : .zero
    builder.appendBoolean(enabled)
    builder.appendPair(selector, selector)
    builder.appendDigestPair(spec.innerCompressedProofDigest ?? terminalVerifierAIRNoInnerCompressedDigest())
    builder.appendDigestPair(spec.sourceProofDigest)
    builder.appendDigestPair(spec.publicInputDigest)
    builder.appendDigestPair(spec.terminalStatementDigest)
    builder.appendDigestPair(spec.foldProofDigest)
    builder.appendDigestPair(spec.ceOpeningProofDigest)
    builder.appendDigestPair(policyDigest)
    builder.appendPair(GoldilocksField(UInt64(publicInput.instances.count)), GoldilocksField(UInt64(publicInput.instances.count)))
    builder.appendConstraintRows(spec.constraints(for: .innerCompressedProofVerifier))
    return builder.finish()
}

private func terminalVerifierAIRAcceptSubrelation(
    spec: SuperNeoTerminalVerifierAIRSpec,
    priorResiduals: [GoldilocksField],
    rowBindingContext: TerminalVerifierAIRRowBindingContext
) -> TerminalVerifierAIRSubrelation {
    let aggregate = priorResiduals.reduce(GoldilocksField.zero) { partial, residual in
        partial + residual * residual
    }
    var builder = TerminalVerifierAIRSubrelationBuilder(
        kind: .acceptAggregation,
        enabled: true,
        domain: "SuperNeo-NuMetal.terminal-verifier-air.accept-aggregation.v1",
        rowBindingContext: rowBindingContext
    )
    let acceptBit = spec.acceptBit
    builder.appendPair(aggregate, .zero)
    builder.appendPair(acceptBit, .one)
    builder.appendConstraintRows([
        .required(
            spec.accepts,
            kind: .acceptAggregation,
            provenance: .primitiveArithmetic,
            label: "accept-derived-from-zero-residual"
        )
    ])
    return builder.finish()
}

private func terminalVerifierAIRPackTrace(
    subrelations: [TerminalVerifierAIRSubrelation],
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    terminalVerifierRelationDigest: Digest256,
    recursiveDigest: Digest256,
    selectedProfileDigest: Digest256,
    priorClaimRoot: Digest256
) -> TerminalVerifierAIRInstance {
    var trace: [GoldilocksField] = [
        GoldilocksField(0x5456_4149_525f_5631),
        GoldilocksField(UInt64(SuperNeoTerminalVerifierPCSProof.version)),
        GoldilocksField(UInt64(spec.sourceProofKind.rawValue)),
        GoldilocksField(UInt64(spec.sourceProofByteCount)),
        GoldilocksField(UInt64(spec.profileID)),
        GoldilocksField(UInt64(publicInput.instances.count)),
        GoldilocksField(UInt64(publicInput.priorClaims.count)),
        GoldilocksField(UInt64(subrelations.count))
    ]
    var residual = Array(repeating: GoldilocksField.zero, count: trace.count)
    for digest in [
        spec.sourceProofDigest,
        spec.canonicalSourceEncodingDigest,
        spec.shapeDigest,
        spec.statementDigest,
        spec.verifierKeyDigest,
        spec.transcriptDomain,
        spec.publicInputDigest,
        recursiveDigest,
        spec.compressionPolicyDigest,
        terminalVerifierRelationDigest,
        selectedProfileDigest,
        priorClaimRoot,
        spec.publicCoinBindingDigest,
        spec.specDigest
    ] {
        let fields = spartanFRIDigestFields(digest)
        trace.append(contentsOf: fields)
        residual.append(contentsOf: Array(repeating: .zero, count: fields.count))
    }
    for subrelation in subrelations {
        let header: [GoldilocksField] = [
            GoldilocksField(UInt64(subrelation.kind.rawValue)),
            subrelation.enabled ? .one : .zero,
            GoldilocksField(UInt64(subrelation.traceTerms.count)),
            GoldilocksField(UInt64(subrelation.residualTerms.count))
        ]
        trace.append(contentsOf: header)
        residual.append(.zero)
        residual.append((subrelation.enabled ? GoldilocksField.one : .zero) * ((subrelation.enabled ? GoldilocksField.one : .zero) - .one))
        residual.append(.zero)
        residual.append(.zero)
        for digest in [subrelation.inputDigest, subrelation.outputDigest, subrelation.constraintDigest] {
            let fields = spartanFRIDigestFields(digest)
            trace.append(contentsOf: fields)
            residual.append(contentsOf: Array(repeating: .zero, count: fields.count))
        }
        trace.append(contentsOf: subrelation.traceTerms)
        residual.append(contentsOf: subrelation.residualTerms)
    }
    return TerminalVerifierAIRInstance(trace: trace, residual: residual, subrelations: subrelations)
}

private func terminalVerifierAIRPackCompactTrace(
    subrelations: [TerminalVerifierAIRSubrelation],
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput,
    terminalVerifierRelationDigest: Digest256,
    recursiveDigest: Digest256,
    selectedProfileDigest: Digest256,
    priorClaimRoot: Digest256
) -> TerminalVerifierAIRInstance {
    var trace: [GoldilocksField] = [
        GoldilocksField(0x5456_4149_525f_5443),
        GoldilocksField(UInt64(SuperNeoTerminalVerifierPCSProof.version)),
        GoldilocksField(UInt64(spec.sourceProofKind.rawValue)),
        GoldilocksField(UInt64(spec.sourceProofByteCount)),
        GoldilocksField(UInt64(spec.profileID)),
        GoldilocksField(UInt64(publicInput.instances.count)),
        GoldilocksField(UInt64(publicInput.priorClaims.count)),
        GoldilocksField(UInt64(subrelations.count))
    ]
    var residual = Array(repeating: GoldilocksField.zero, count: trace.count)
    for digest in [
        spec.sourceProofDigest,
        spec.canonicalSourceEncodingDigest,
        spec.shapeDigest,
        spec.statementDigest,
        spec.verifierKeyDigest,
        spec.transcriptDomain,
        spec.publicInputDigest,
        recursiveDigest,
        spec.compressionPolicyDigest,
        terminalVerifierRelationDigest,
        selectedProfileDigest,
        priorClaimRoot,
        spec.publicCoinBindingDigest,
        spec.specDigest
    ] {
        let fields = spartanFRIDigestFields(digest)
        trace.append(contentsOf: fields)
        residual.append(contentsOf: Array(repeating: .zero, count: fields.count))
    }
    for subrelation in subrelations {
        trace.append(GoldilocksField(UInt64(subrelation.kind.rawValue)))
        residual.append(.zero)
        trace.append(subrelation.enabled ? .one : .zero)
        residual.append((subrelation.enabled ? GoldilocksField.one : .zero) * ((subrelation.enabled ? GoldilocksField.one : .zero) - .one))
        trace.append(GoldilocksField(UInt64(subrelation.traceTerms.count)))
        residual.append(.zero)
        trace.append(GoldilocksField(UInt64(subrelation.residualTerms.count)))
        residual.append(.zero)
        for digest in [subrelation.inputDigest, subrelation.outputDigest, subrelation.constraintDigest] {
            let fields = spartanFRIDigestFields(digest)
            trace.append(contentsOf: fields)
            residual.append(contentsOf: Array(repeating: .zero, count: fields.count))
        }
        let aggregateResidual = subrelation.residualTerms.reduce(GoldilocksField.zero) { partial, term in
            partial + term * term
        }
        trace.append(aggregateResidual)
        residual.append(aggregateResidual)
    }
    return TerminalVerifierAIRInstance(trace: trace, residual: residual, subrelations: subrelations)
}

private func terminalVerifierAIRCompactTraceLength(
    rootDigestCount: Int = 14,
    subrelationCount: Int = 8
) -> Int {
    let digestFieldCount = spartanFRIDigestFields(terminalVerifierAIRPendingRelationDigest()).count
    let headerFieldCount = 8
    let fieldsPerSubrelation = 4 + (3 * digestFieldCount) + 1
    return headerFieldCount
        + (rootDigestCount * digestFieldCount)
        + (subrelationCount * fieldsPerSubrelation)
}

private struct TerminalVerifierAIRRowBindingContext {
    let terminalVerifierRelationDigest: Digest256
    let recursiveDigest: Digest256
    let sourceProofDigest: Digest256
    let sourceProofByteCount: Int
    let publicInputDigest: Digest256
    let compressionPolicyDigest: Digest256
    let terminalStatementDigest: Digest256
    let foldProofDigest: Digest256
    let ceOpeningProofDigest: Digest256

    init(
        spec: SuperNeoTerminalVerifierAIRSpec,
        terminalVerifierRelationDigest: Digest256,
        recursiveDigest: Digest256
    ) {
        self.terminalVerifierRelationDigest = terminalVerifierRelationDigest
        self.recursiveDigest = recursiveDigest
        self.sourceProofDigest = spec.sourceProofDigest
        self.sourceProofByteCount = spec.sourceProofByteCount
        self.publicInputDigest = spec.publicInputDigest
        self.compressionPolicyDigest = spec.compressionPolicyDigest
        self.terminalStatementDigest = spec.terminalStatementDigest
        self.foldProofDigest = spec.foldProofDigest
        self.ceOpeningProofDigest = spec.ceOpeningProofDigest
    }

    func rowDigest(
        domain: String,
        subrelationKind: TerminalVerifierAIRSubrelationKind,
        rowIndex: Int,
        row: SuperNeoTerminalVerifierAIRConstraintRow
    ) -> Digest256 {
        SuperNeoTerminalVerifierAIRPrimitiveBatch.contextRowDigest(
            domain: domain,
            subrelationKindRawValue: subrelationKind.rawValue,
            rowIndex: rowIndex,
            row: row,
            terminalVerifierRelationDigest: terminalVerifierRelationDigest,
            recursiveRelationDigest: recursiveDigest,
            sourceDigest: sourceProofDigest,
            sourceByteCount: sourceProofByteCount,
            publicInputDigest: publicInputDigest,
            compressionPolicyDigest: compressionPolicyDigest,
            terminalStatementDigest: terminalStatementDigest,
            foldProofDigest: foldProofDigest,
            ceOpeningProofDigest: ceOpeningProofDigest
        )
    }
}

private struct TerminalVerifierAIRSubrelationBuilder {
    let kind: TerminalVerifierAIRSubrelationKind
    let enabled: Bool
    let domain: String
    let rowBindingContext: TerminalVerifierAIRRowBindingContext?
    private(set) var traceTerms: [GoldilocksField] = []
    private(set) var residualTerms: [GoldilocksField] = []

    mutating func appendPair(_ observed: GoldilocksField, _ expected: GoldilocksField) {
        traceTerms.append(observed)
        residualTerms.append(observed - expected)
    }

    mutating func appendBoolean(_ value: Bool) {
        let field = value ? GoldilocksField.one : .zero
        traceTerms.append(field)
        residualTerms.append(field * (field - .one))
    }

    mutating func appendRequiredTrue(_ value: Bool) {
        let field = value ? GoldilocksField.one : .zero
        traceTerms.append(field)
        residualTerms.append(field - .one)
    }

    mutating func appendConstraintRows(_ rows: [SuperNeoTerminalVerifierAIRConstraintRow]) {
        for (rowIndex, row) in rows.enumerated() {
            appendPair(GoldilocksField(UInt64(rowIndex)), GoldilocksField(UInt64(rowIndex)))
            appendPair(GoldilocksField(UInt64(row.kind.rawValue)), GoldilocksField(UInt64(row.kind.rawValue)))
            appendPair(GoldilocksField(UInt64(row.provenance.rawValue)), GoldilocksField(UInt64(row.provenance.rawValue)))
            if let rowBindingContext {
                appendDigestPair(rowBindingContext.rowDigest(
                    domain: domain,
                    subrelationKind: kind,
                    rowIndex: rowIndex,
                    row: row
                ))
            }
            appendDigestPair(row.labelDigest)
            appendPair(row.observed, row.expected)
        }
    }

    mutating func appendDigestPair(_ digest: Digest256) {
        for field in spartanFRIDigestFields(digest) {
            appendPair(field, field)
        }
    }

    func finish() -> TerminalVerifierAIRSubrelation {
        let bytes = traceTerms.flatMap(\.superNeoBytes)
            + residualTerms.flatMap(\.superNeoBytes)
        let inputDigest = Digest256.hash(
            Array("\(domain)/input".utf8)
                + [kind.rawValue]
                + [enabled ? UInt8(1) : UInt8(0)]
                + traceTerms.flatMap(\.superNeoBytes)
        )
        let outputDigest = Digest256.hash(
            Array("\(domain)/output".utf8)
                + [kind.rawValue]
                + [enabled ? UInt8(1) : UInt8(0)]
                + residualTerms.flatMap(\.superNeoBytes)
        )
        let constraintDigest = Digest256.hash(
            Array("\(domain)/constraints".utf8)
                + [kind.rawValue]
                + [enabled ? UInt8(1) : UInt8(0)]
                + bytes
        )
        return TerminalVerifierAIRSubrelation(
            kind: kind,
            enabled: enabled,
            inputDigest: inputDigest,
            outputDigest: outputDigest,
            constraintDigest: constraintDigest,
            traceTerms: traceTerms,
            residualTerms: residualTerms
        )
    }
}

private func terminalVerifierAIRRecursiveRelationDigest(_ digest: Digest256?) -> Digest256 {
    digest ?? Digest256.hash("SUPERNEO/TERMINAL_VERIFIER/NO_RECURSIVE_RELATION/v1")
}

private func terminalVerifierAIRPendingRelationDigest() -> Digest256 {
    Digest256.hash("SUPERNEO/TERMINAL_VERIFIER/PENDING_RELATION_DIGEST/v1")
}

private func terminalVerifierAIRPriorClaimRoot(_ input: SuperNeoPublicFoldInput) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier-air.prior-claim-root.v1".utf8)
            + spartanFRIEncodeCount(input.priorClaims.count)
            + input.priorClaims.flatMap(\.superNeoBytes)
    )
}

private func terminalVerifierAIRSelectedProfileDigest(
    spec: SuperNeoTerminalVerifierAIRSpec,
    publicInput: SuperNeoPublicFoldInput
) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier-air.selected-profile.v1".utf8)
            + spartanFRIEncodeUInt16(spec.profileID)
            + spec.shapeDigest.superNeoBytes
            + spec.statementDigest.superNeoBytes
            + spec.verifierKeyDigest.superNeoBytes
            + spartanFRIEncodeCount(publicInput.instances.count)
            + spartanFRIEncodeCount(publicInput.priorClaims.count)
    )
}

private func spartanResidualVector(
    witness: [GoldilocksField],
    publicTrace: [GoldilocksField]
) -> [GoldilocksField] {
    let count = max(witness.count, publicTrace.count)
    return (0..<count).map { index in
        (index < witness.count ? witness[index] : .zero)
            - (index < publicTrace.count ? publicTrace[index] : .zero)
    }
}

private func spartanFRIPublicInputDigest(_ input: SuperNeoPublicFoldInput) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.compressed-public.input.v1".utf8)
            + input.shape.shapeDigest.superNeoBytes
            + spartanFRIEncodeCount(input.instances.count)
            + input.instances.flatMap(\.superNeoBytes)
            + spartanFRIEncodeCount(input.priorClaims.count)
            + input.priorClaims.flatMap(\.superNeoBytes)
            + (input.recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [UInt8(0)])
    )
}

private func spartanFRIDigestFields(_ digest: Digest256) -> [GoldilocksField] {
    stride(from: 0, to: digest.superNeoBytes.count, by: 4).map { offset in
        let chunk = digest.superNeoBytes[offset..<min(offset + 4, digest.superNeoBytes.count)]
        let value = chunk.enumerated().reduce(UInt32(0)) { partial, pair in
            partial | (UInt32(pair.element) << UInt32(pair.offset * 8))
        }
        return GoldilocksField(UInt64(value))
    }
}

private func spartanFRIDigest384Fields(_ digest: Digest384) -> [GoldilocksField] {
    stride(from: 0, to: digest.superNeoBytes.count, by: 4).map { offset in
        let chunk = digest.superNeoBytes[offset..<min(offset + 4, digest.superNeoBytes.count)]
        let value = chunk.enumerated().reduce(UInt32(0)) { partial, pair in
            partial | (UInt32(pair.element) << UInt32(pair.offset * 8))
        }
        return GoldilocksField(UInt64(value))
    }
}

private func spartanFRILeafDigest(
    leafDomain: String,
    index: Int,
    leafCount: Int,
    point: GoldilocksField,
    value: GoldilocksField
) -> Digest384 {
    SuperNeoSplitQRO.hBind(
        domain: leafDomain,
        frames: [
            spartanFRIEncodeCount(index),
            spartanFRIEncodeCount(leafCount),
            point.superNeoBytes,
            value.superNeoBytes
        ]
    )
}

private func spartanFRIChallenge(
    bindingDigest: Digest256,
    label: String,
    round: Int,
    root: Digest384,
    domainSize: Int,
    currentDegreeBound: Int,
    domainRoot: GoldilocksField,
    cosetGenerator: GoldilocksField,
    blowupFactor: Int
) -> GoldilocksField {
    spartanFRIHashToField(
        Array("SuperNeo-NuMetal.spartan-fri.challenge.v1".utf8)
            + bindingDigest.superNeoBytes
            + spartanFRIEncodeString(label)
            + spartanFRIEncodeCount(round)
            + spartanFRIEncodeCount(domainSize)
            + spartanFRIEncodeCount(currentDegreeBound)
            + domainRoot.superNeoBytes
            + cosetGenerator.superNeoBytes
            + spartanFRIEncodeCount(blowupFactor)
            + root.superNeoBytes
    )
}

private func spartanFRIHashToField(_ seed: [UInt8]) -> GoldilocksField {
    var counter = 0
    while true {
        let digest = Digest256.hash(seed + spartanFRIEncodeCount(counter))
        let candidate = digest.superNeoBytes.prefix(8).enumerated().reduce(UInt64(0)) { partial, pair in
            partial | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
        if candidate < GoldilocksField.modulus {
            return GoldilocksField(candidate)
        }
        counter += 1
    }
}

private func spartanFRIQueryIndices(
    bindingDigest: Digest256,
    label: String,
    roots: [Digest384],
    queryCount: Int,
    domainSize: Int
) -> [Int] {
    guard queryCount > 0, domainSize > 0 else { return [] }
    var indices: [Int] = []
    indices.reserveCapacity(queryCount)
    var counter = 0
    let targetCount = min(queryCount, domainSize)
    while indices.count < targetCount {
        let digest = Digest256.hash(
            Array("SuperNeo-NuMetal.spartan-fri.query.v1".utf8)
                + bindingDigest.superNeoBytes
                + spartanFRIEncodeString(label)
                + spartanFRIEncodeCount(domainSize)
                + spartanFRIEncodeCount(counter)
                + roots.flatMap(\.superNeoBytes)
        )
        let value = digest.superNeoBytes.prefix(8).enumerated().reduce(UInt64(0)) { partial, pair in
            partial | (UInt64(pair.element) << UInt64(pair.offset * 8))
        }
        let index = Int(value % UInt64(domainSize))
        if !indices.contains(index) {
            indices.append(index)
        }
        counter += 1
    }
    return indices
}

private func terminalVerifierAIRQueryIndices(
    tracePCS: SuperNeoFRIProof,
    residualPCS: SuperNeoFRIProof,
    relationDigest: Digest256
) -> [Int] {
    terminalVerifierAIRQueryIndices(
        traceCommitments: tracePCS.commitments,
        residualCommitments: residualPCS.commitments,
        relationDigest: relationDigest,
        queryCount: tracePCS.queryCount,
        paddedDomainSize: tracePCS.paddedDomainSize
    )
}

private func terminalVerifierAIRQueryIndices(
    traceCommitments: [SuperNeoFRICommitment],
    residualCommitments: [SuperNeoFRICommitment],
    relationDigest: Digest256,
    queryCount: Int,
    paddedDomainSize: Int
) -> [Int] {
    spartanFRIQueryIndices(
        bindingDigest: relationDigest,
        label: "terminal-verifier-air-joint",
        roots: traceCommitments.map(\.root) + residualCommitments.map(\.root),
        queryCount: queryCount,
        domainSize: max(1, paddedDomainSize / 2)
    )
}

private func spartanFRIValidateQueryIndices(
    _ indices: [Int],
    expectedCount: Int,
    domainSize: Int,
    name: String
) throws {
    guard expectedCount > 0, domainSize > 0 else {
        throw SuperNeoError.invalidParameter("\(name) requires positive query count and domain")
    }
    guard indices.count == expectedCount else {
        throw SuperNeoError.invalidParameter("\(name) count mismatch")
    }
    guard Set(indices).count == indices.count else {
        throw SuperNeoError.invalidParameter("\(name) indices must be unique")
    }
    guard indices.allSatisfy({ $0 >= 0 && $0 < domainSize }) else {
        throw SuperNeoError.invalidParameter("\(name) index out of range")
    }
}

private func spartanFRIRootOfUnity(order: Int) throws -> GoldilocksField {
    guard order > 0, order.nonzeroBitCount == 1 else {
        throw SuperNeoError.invalidParameter("FRI root order must be a power of two")
    }
    guard UInt64(order) <= (GoldilocksField.modulus - 1) else {
        throw SuperNeoError.invalidParameter("FRI root order exceeds Goldilocks multiplicative group")
    }
    if order == 1 { return .one }
    let exponent = (GoldilocksField.modulus - 1) / UInt64(order)
    for candidate in UInt64(2)..<UInt64(65_536) {
        let root = GoldilocksField(candidate).pow(exponent)
        if root.pow(UInt64(order)) == .one,
           root.pow(UInt64(order / 2)) != .one {
            return root
        }
    }
    throw SuperNeoError.invalidParameter("unable to derive Goldilocks FRI root of unity")
}

private func spartanFRICosetGenerator(order: Int) throws -> GoldilocksField {
    guard order > 0 else {
        throw SuperNeoError.invalidParameter("FRI coset order must be positive")
    }
    if order == 1 { return .one }
    for candidate in UInt64(3)..<UInt64(65_536) {
        let field = GoldilocksField(candidate)
        if field.pow(UInt64(order)) != .one {
            return field
        }
    }
    throw SuperNeoError.invalidParameter("unable to derive Goldilocks FRI coset generator")
}

private func spartanFRIDomainPoint(index: Int, root: GoldilocksField, coset: GoldilocksField) -> GoldilocksField {
    coset * root.pow(UInt64(index))
}

private func spartanFRIDomainPoints(size: Int, root: GoldilocksField, coset: GoldilocksField) -> [GoldilocksField] {
    var points: [GoldilocksField] = []
    points.reserveCapacity(size)
    var power = GoldilocksField.one
    for _ in 0..<size {
        points.append(coset * power)
        power = power * root
    }
    return points
}

private func spartanFRIEvaluatePolynomial(_ coefficients: [GoldilocksField], at point: GoldilocksField) -> GoldilocksField {
    coefficients.reversed().reduce(GoldilocksField.zero) { partial, coefficient in
        partial * point + coefficient
    }
}

private func spartanFRIEvaluatePolynomialOnDomain(
    _ coefficients: [GoldilocksField],
    size: Int,
    root: GoldilocksField,
    coset: GoldilocksField
) throws -> [GoldilocksField] {
    guard size > 0, size.nonzeroBitCount == 1 else {
        throw SuperNeoError.invalidParameter("FRI domain evaluation requires a power-of-two domain")
    }
    guard coefficients.count <= size else {
        throw SuperNeoError.invalidParameter("FRI coefficient count exceeds evaluation domain")
    }
    var values = Array(repeating: GoldilocksField.zero, count: size)
    var cosetPower = GoldilocksField.one
    for index in coefficients.indices {
        values[index] = coefficients[index] * cosetPower
        cosetPower = cosetPower * coset
    }
    spartanFRIRadix2NTT(&values, root: root)
    return values
}

private func spartanFRIRadix2NTT(_ values: inout [GoldilocksField], root: GoldilocksField) {
    let count = values.count
    guard count > 1 else { return }
    var j = 0
    for i in 1..<count {
        var bit = count >> 1
        while (j & bit) != 0 {
            j ^= bit
            bit >>= 1
        }
        j ^= bit
        if i < j {
            values.swapAt(i, j)
        }
    }
    var length = 2
    while length <= count {
        let stepRoot = root.pow(UInt64(count / length))
        let half = length / 2
        var twiddles = Array(repeating: GoldilocksField.one, count: half)
        if half > 1 {
            for offset in 1..<half {
                twiddles[offset] = twiddles[offset - 1] * stepRoot
            }
        }
        for start in stride(from: 0, to: count, by: length) {
            for offset in 0..<half {
                let even = values[start + offset]
                let odd = values[start + offset + half] * twiddles[offset]
                values[start + offset] = even + odd
                values[start + offset + half] = even - odd
            }
        }
        length <<= 1
    }
}

#if DEBUG
enum SuperNeoSpartanFRITestHooks {
    static func rootOfUnity(order: Int) throws -> GoldilocksField {
        try spartanFRIRootOfUnity(order: order)
    }

    static func hornerEvaluateOnDomain(
        coefficients: [GoldilocksField],
        size: Int,
        root: GoldilocksField,
        coset: GoldilocksField
    ) throws -> [GoldilocksField] {
        let points = spartanFRIDomainPoints(size: size, root: root, coset: coset)
        return points.map { spartanFRIEvaluatePolynomial(coefficients, at: $0) }
    }

    static func nttEvaluateOnDomain(
        coefficients: [GoldilocksField],
        size: Int,
        root: GoldilocksField,
        coset: GoldilocksField
    ) throws -> [GoldilocksField] {
        try spartanFRIEvaluatePolynomialOnDomain(
            coefficients,
            size: size,
            root: root,
            coset: coset
        )
    }

    static func freshFRIProof(
        vector: [GoldilocksField],
        paddedDomainSize: Int,
        queryCount: Int,
        blowupFactor: Int,
        claimedDegreeBound: Int,
        label: String,
        bindingDigest: Digest256
    ) throws -> SuperNeoFRIProof {
        try makeFRIProof(
            vector: vector,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            label: label,
            bindingDigest: bindingDigest
        )
    }

    static func plannedFRIProof(
        vector: [GoldilocksField],
        paddedDomainSize: Int,
        queryCount: Int,
        blowupFactor: Int,
        claimedDegreeBound: Int,
        label: String,
        bindingDigest: Digest256
    ) throws -> SuperNeoFRIProof {
        let plan = try makeFRIProverPlan(
            vector: vector,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: claimedDegreeBound,
            label: label,
            bindingDigest: bindingDigest
        )
        return try makeFRIProof(plan: plan)
    }

    static func jointAIRQueryIndices(
        traceCommitments: [SuperNeoFRICommitment],
        residualCommitments: [SuperNeoFRICommitment],
        relationDigest: Digest256,
        queryCount: Int,
        paddedDomainSize: Int
    ) -> [Int] {
        terminalVerifierAIRQueryIndices(
            traceCommitments: traceCommitments,
            residualCommitments: residualCommitments,
            relationDigest: relationDigest,
            queryCount: queryCount,
            paddedDomainSize: paddedDomainSize
        )
    }

    static func terminalAIRMaterialForSourceEnvelope(
        proofBytes: [UInt8],
        publicInput: SuperNeoPublicFoldInput,
        verifierKey: AjtaiCommitmentKey,
        policy: SuperNeoTerminalProofAcceptancePolicy
    ) throws -> SuperNeoTerminalAIRTestMaterial {
        try SuperNeoSpartanFRICompressor.makeTerminalVerifierAIRMaterialForTesting(
            proofBytes: proofBytes,
            publicInput: publicInput,
            verifierKey: verifierKey,
            policy: policy
        )
    }
}
#endif

private func spartanFRIFoldCoefficients(
    _ coefficients: [GoldilocksField],
    challenge: GoldilocksField
) -> [GoldilocksField] {
    var folded: [GoldilocksField] = []
    folded.reserveCapacity((coefficients.count + 1) / 2)
    var index = 0
    while index < coefficients.count {
        let even = coefficients[index]
        let odd = index + 1 < coefficients.count ? coefficients[index + 1] : .zero
        folded.append(even + challenge * odd)
        index += 2
    }
    return folded
}

private func spartanFRINextPowerOfTwo(_ value: Int) -> Int {
    var power = 1
    while power < value {
        power <<= 1
    }
    return power
}

private func spartanFRILog2(_ value: Int) -> Int {
    var power = value
    var result = 0
    while power > 1 {
        power >>= 1
        result += 1
    }
    return result
}

private func spartanFRIFoldingRoundCount(forDegreeBound degreeBound: Int) -> Int {
    var bound = max(1, degreeBound)
    var rounds = 0
    while bound > 1 {
        bound = (bound + 1) / 2
        rounds += 1
    }
    return rounds
}

private func spartanFRIEncodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return spartanFRIEncodeCount(bytes.count) + bytes
}

private func spartanFRIEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func spartanFRIEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}
