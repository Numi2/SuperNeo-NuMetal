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
        var digest = spartanFRILeafDigest(domain: domain, index: index, leafCount: leafCount, point: point, value: value)
        for sibling in siblings {
            switch sibling.position {
            case .left:
                digest = SuperNeoSplitQRO.hMerkleNode(domain: domain, left: sibling.digest, right: digest)
            case .right:
                digest = SuperNeoSplitQRO.hMerkleNode(domain: domain, left: digest, right: sibling.digest)
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
    public static let relationTag = "terminal-verifier-execution-air/fold-piccs-pirlc-pidec-ce-ajtai-modsis/v1"

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
              tracePCS.claimedDegreeBound == traceVectorLength,
              residualPCS.claimedDegreeBound == traceVectorLength,
              tracePCS.blowupFactor == SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
              residualPCS.blowupFactor == SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
              tracePCS.domainRoot == residualPCS.domainRoot,
              tracePCS.cosetGenerator == residualPCS.cosetGenerator else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS proof dimensions do not match")
        }
        let minimumQueryCount = min(SuperNeoSpartanFRICompressionProof.defaultQueryCount, max(1, paddedDomainSize / 2))
        guard tracePCS.queryCount >= minimumQueryCount,
              residualPCS.queryCount >= minimumQueryCount else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS query count below selected minimum")
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
              witnessPCS.blowupFactor == Self.defaultBlowupFactor,
              residualPCS.blowupFactor == Self.defaultBlowupFactor,
              witnessPCS.domainRoot == residualPCS.domainRoot,
              witnessPCS.cosetGenerator == residualPCS.cosetGenerator else {
            throw SuperNeoError.invalidParameter("Spartan/FRI PCS domain metadata does not match trace")
        }
        let minimumQueryCount = min(Self.defaultQueryCount, max(1, paddedDomainSize / 2))
        guard witnessPCS.queryCount >= minimumQueryCount,
              residualPCS.queryCount >= minimumQueryCount else {
            throw SuperNeoError.invalidParameter("Spartan/FRI compression query count below selected minimum")
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
        let verification = SuperNeoVerifier(
            parameters: parameters,
            key: verifierKey,
            context: metalContext,
            executionPolicy: executionPolicy
        ).verifyTerminalProofEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            policy: trustedPolicy
        )
        guard verification.isValid else {
            throw SuperNeoError.verificationFailed(
                "Spartan/FRI compression requires an accepted terminal proof: \(verification.reason ?? "unknown")"
            )
        }
        let sourceDigests = try sourceComponentDigests(proofBytes: proofBytes, header: header, parameters: parameters)
        let compressionStatement = try SuperNeoSpartanFRICompressionStatement(
            sourceProofKind: header.kind,
            sourceProofByteCount: proofBytes.count,
            sourceProofDigest: Digest256.hash(proofBytes),
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
        let terminalVerifierPCSProof = try makeTerminalVerifierPCSProof(
            statement: compressionStatement,
            publicInput: publicInput,
            policy: trustedPolicy,
            queryCount: queryCount
        )
        let trace = spartanTraceVector(
            statement: compressionStatement,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            accepted: true
        )
        let residual = spartanResidualVector(witness: trace, publicTrace: trace)
        let claimedDegreeBound = trace.count
        let blowupFactor = SuperNeoSpartanFRICompressionProof.defaultBlowupFactor
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
        let minimumQueryCount = min(SuperNeoSpartanFRICompressionProof.defaultQueryCount, queryDomainSize)
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
        return try SuperNeoSpartanFRICompressionProof(
            statement: compressionStatement,
            arithmetizationDigest: arithmetizationDigest,
            traceVectorLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            terminalVerifierPCSProof: terminalVerifierPCSProof,
            witnessPCS: witnessPCS,
            residualPCS: residualPCS
        )
    }

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

    private static func makeTerminalVerifierPCSProof(
        statement: SuperNeoSpartanFRICompressionStatement,
        publicInput: SuperNeoPublicFoldInput,
        policy: SuperNeoTerminalProofAcceptancePolicy,
        queryCount: Int
    ) throws -> SuperNeoTerminalVerifierPCSProof {
        let policyDigest = terminalVerifierCompressionPolicyDigest(policy)
        let trace = terminalVerifierExecutionTraceVector(
            statement: statement,
            publicInput: publicInput,
            policyDigest: policyDigest,
            accepted: true
        )
        let residual = terminalVerifierExecutionResidualVector(trace: trace)
        let blowupFactor = SuperNeoSpartanFRICompressionProof.defaultBlowupFactor
        let paddedDomainSize = spartanFRINextPowerOfTwo(trace.count * blowupFactor)
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
            traceVectorLength: trace.count,
            paddedDomainSize: paddedDomainSize
        )
        let queryDomainSize = max(1, paddedDomainSize / 2)
        let minimumQueryCount = min(SuperNeoSpartanFRICompressionProof.defaultQueryCount, queryDomainSize)
        guard queryCount >= minimumQueryCount else {
            throw SuperNeoError.invalidParameter("terminal verifier PCS query count below selected minimum")
        }
        let tracePCS = try makeFRIProof(
            vector: trace,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: trace.count,
            label: "terminal-verifier-trace",
            bindingDigest: relationDigest
        )
        let residualPCS = try makeFRIProof(
            vector: residual,
            paddedDomainSize: paddedDomainSize,
            queryCount: queryCount,
            blowupFactor: blowupFactor,
            claimedDegreeBound: trace.count,
            label: "terminal-verifier-residual",
            bindingDigest: relationDigest
        )
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
            recursiveRelationDigest: publicInput.recursiveRelationDigest,
            compressionPolicyDigest: policyDigest,
            terminalStatementDigest: statement.terminalStatementDigest,
            foldProofDigest: statement.foldProofDigest,
            ceOpeningProofDigest: statement.ceOpeningProofDigest,
            traceVectorLength: trace.count,
            paddedDomainSize: paddedDomainSize,
            tracePCS: tracePCS,
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
        let trace = terminalVerifierExecutionTraceVector(
            statement: traceStatement,
            publicInput: publicInput,
            policyDigest: expectedPolicyDigest,
            accepted: true
        )
        let residual = terminalVerifierExecutionResidualVector(trace: trace)
        guard proof.traceVectorLength == trace.count,
              proof.paddedDomainSize == spartanFRINextPowerOfTwo(trace.count * SuperNeoSpartanFRICompressionProof.defaultBlowupFactor) else {
            return .invalid("terminal verifier PCS trace dimension mismatch")
        }
        do {
            let traceSamples = try verifyFRIProof(
                proof.tracePCS,
                label: "terminal-verifier-trace",
                bindingDigest: proof.relationDigest
            )
            let residualSamples = try verifyFRIProof(
                proof.residualPCS,
                label: "terminal-verifier-residual",
                bindingDigest: proof.relationDigest
            )
            for sample in traceSamples {
                guard sample.value == spartanFRIEvaluatePolynomial(trace, at: sample.point) else {
                    return .invalid("terminal verifier trace opening mismatch")
                }
            }
            for sample in residualSamples {
                guard sample.value == spartanFRIEvaluatePolynomial(residual, at: sample.point),
                      sample.value == .zero else {
                    return .invalid("terminal verifier residual opening mismatch")
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
        let expectedPaddedDomainSize = spartanFRINextPowerOfTwo(trace.count * SuperNeoSpartanFRICompressionProof.defaultBlowupFactor)
        let expectedArithmetization = SuperNeoSpartanFRICompressionProof.arithmetizationDigest(
            statement: proof.statement,
            terminalVerifierPCSProof: proof.terminalVerifierPCSProof,
            traceLength: trace.count,
            paddedDomainSize: expectedPaddedDomainSize,
            blowupFactor: SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
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
              proof.witnessPCS.blowupFactor == SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
              proof.residualPCS.blowupFactor == SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
              proof.witnessPCS.domainRoot == proof.residualPCS.domainRoot,
              proof.witnessPCS.cosetGenerator == proof.residualPCS.cosetGenerator else {
            return .invalid("Spartan/FRI PCS domain metadata mismatch")
        }
        let minimumQueryCount = min(SuperNeoSpartanFRICompressionProof.defaultQueryCount, max(1, proof.paddedDomainSize / 2))
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
        var current = leaves.indices.map { index in
            spartanFRILeafDigest(
                domain: domain,
                index: index,
                leafCount: leaves.count,
                point: points[index],
                value: leaves[index]
            )
        }
        var levels = [current]
        while current.count > 1 {
            var next: [Digest384] = []
            next.reserveCapacity(current.count / 2)
            for index in stride(from: 0, to: current.count, by: 2) {
                next.append(SuperNeoSplitQRO.hMerkleNode(domain: domain, left: current[index], right: current[index + 1]))
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

func makeFRIProof(
    vector: [GoldilocksField],
    paddedDomainSize: Int,
    queryCount: Int,
    blowupFactor: Int = SuperNeoSpartanFRICompressionProof.defaultBlowupFactor,
    claimedDegreeBound: Int? = nil,
    label: String,
    bindingDigest: Digest256
) throws -> SuperNeoFRIProof {
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
    var allLayerPoints: [[GoldilocksField]] = []
    var allLayers: [[GoldilocksField]] = []
    var commitments: [SuperNeoFRICommitment] = []
    var challenges: [GoldilocksField] = []
    let baseDomain = "superneo/spartan-fri/\(label)"
    var round = 0
    while true {
        let points = spartanFRIDomainPoints(size: currentDomainSize, root: currentRoot, coset: currentCoset)
        let layerValues = points.map { spartanFRIEvaluatePolynomial(coefficients, at: $0) }
        let tree = try SpartanFRIMerkleTree(domain: "\(baseDomain)/layer-\(round)", leaves: layerValues, points: points)
        let commitment = SuperNeoFRICommitment(domainSize: currentDomainSize, root: tree.root)
        allLayerPoints.append(points)
        allLayers.append(layerValues)
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
    let finalPolynomial = [coefficients.first ?? .zero]
    let roots = commitments.map(\.root)
    let indices = spartanFRIQueryIndices(
        bindingDigest: bindingDigest,
        label: label,
        roots: roots,
        queryCount: queryCount,
        domainSize: queryDomainSize
    )
    let trees = try allLayers.indices.map { layer in
        try SpartanFRIMerkleTree(
            domain: "\(baseDomain)/layer-\(layer)",
            leaves: allLayers[layer],
            points: allLayerPoints[layer]
        )
    }
    let queryProofs = try indices.map { initialIndex -> SuperNeoFRIQueryProof in
        var layerIndex = 0
        var index = initialIndex
        var layerOpenings: [[SuperNeoFRIMerkleOpening]] = []
        while layerIndex < allLayers.count - 1 {
            let halfDomain = allLayers[layerIndex].count / 2
            let positiveIndex = index % halfDomain
            let negativeIndex = positiveIndex + halfDomain
            let nextIndex = positiveIndex
            layerOpenings.append([
                try trees[layerIndex].opening(at: positiveIndex),
                try trees[layerIndex].opening(at: negativeIndex),
                try trees[layerIndex + 1].opening(at: nextIndex)
            ])
            index = nextIndex
            layerIndex += 1
        }
        return SuperNeoFRIQueryProof(initialIndex: initialIndex, layerOpenings: layerOpenings)
    }
    return try SuperNeoFRIProof(
        vectorLength: vector.count,
        paddedDomainSize: paddedDomainSize,
        queryCount: indices.count,
        blowupFactor: blowupFactor,
        claimedDegreeBound: degreeBound,
        domainRoot: domainRoot,
        cosetGenerator: cosetGenerator,
        baseCommitment: commitments[0],
        foldedCommitments: Array(commitments.dropFirst()),
        foldingChallenges: challenges,
        queryProofs: queryProofs,
        finalPolynomial: finalPolynomial
    )
}

private func verifyFRIProof(
    _ proof: SuperNeoFRIProof,
    label: String,
    bindingDigest: Digest256
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
    let expectedQueries = spartanFRIQueryIndices(
        bindingDigest: bindingDigest,
        label: label,
        roots: commitments.map(\.root),
        queryCount: proof.queryCount,
        domainSize: queryDomainSize
    )
    guard proof.queryProofs.map(\.initialIndex) == expectedQueries else {
        throw SuperNeoError.verificationFailed("FRI query schedule mismatch")
    }
    let baseDomain = "superneo/spartan-fri/\(label)"
    var finalRoot = proof.domainRoot
    var finalCoset = proof.cosetGenerator
    for _ in 0..<proof.foldingChallenges.count {
        finalRoot = finalRoot.squared()
        finalCoset = finalCoset.squared()
    }
    let finalDomainSize = commitments.last?.domainSize ?? 0
    let finalDomain = "\(baseDomain)/layer-\(proof.foldingChallenges.count)"
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
            let layerDomain = "\(baseDomain)/layer-\(round)"
            let nextDomain = "\(baseDomain)/layer-\(round + 1)"
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
            guard positive.siblings.count == spartanFRILog2(commitments[round].domainSize),
                  negative.siblings.count == spartanFRILog2(commitments[round].domainSize),
                  next.siblings.count == spartanFRILog2(commitments[round + 1].domainSize) else {
                throw SuperNeoError.verificationFailed("FRI Merkle opening path length mismatch")
            }
            guard positive.verifies(root: commitments[round].root, domain: layerDomain),
                  negative.verifies(root: commitments[round].root, domain: layerDomain),
                  next.verifies(root: commitments[round + 1].root, domain: nextDomain) else {
                throw SuperNeoError.verificationFailed("FRI Merkle opening mismatch")
            }
            let invTwo = try GoldilocksField(2).inverse()
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

private func sourceComponentDigests(
    proofBytes: [UInt8],
    header: ProofEnvelopeHeader,
    parameters: SuperNeoParameters
) throws -> (terminalStatementDigest: Digest256, foldProofDigest: Digest256, ceOpeningProofDigest: Digest256) {
    switch header.kind {
    case .terminalLocal:
        let envelope = try TerminalFoldProofEnvelope(bytes: proofBytes, parameters: parameters)
        return (
            envelope.proof.terminalStatement.statementDigest,
            Digest256.hash(envelope.proof.foldProof.superNeoBytes),
            Digest256.hash(envelope.proof.ceOpeningProof.superNeoBytes)
        )
    case .compressedPublic:
        let envelope = try CompressedTerminalProofEnvelope(bytes: proofBytes, parameters: parameters)
        return (
            envelope.proof.statement.terminalStatementDigest,
            envelope.proof.foldProofDigest,
            envelope.proof.ceOpeningProofDigest
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
    return Digest256.hash(
        Array("SuperNeo-NuMetal.terminal-verifier.compression-policy.v1".utf8)
            + spartanFRIEncodeUInt16(policy.profileID)
            + policy.shapeDigest.superNeoBytes
            + policy.statementDigest.superNeoBytes
            + policy.verifierKeyDigest.superNeoBytes
            + policy.transcriptDomain.superNeoBytes
            + [kindPolicyByte]
            + (policy.maximumProofByteCount.map { [UInt8(1)] + spartanFRIEncodeCount($0) } ?? [UInt8(0)])
    )
}

private func terminalVerifierExecutionTraceVector(
    statement: SuperNeoSpartanFRICompressionStatement,
    publicInput: SuperNeoPublicFoldInput,
    policyDigest: Digest256,
    accepted: Bool
) -> [GoldilocksField] {
    var trace: [GoldilocksField] = [
        GoldilocksField(0x5456_4552_4946_5931),
        GoldilocksField(UInt64(SuperNeoTerminalVerifierPCSProof.version)),
        GoldilocksField(UInt64(statement.sourceProofKind.rawValue)),
        GoldilocksField(UInt64(statement.sourceProofByteCount)),
        GoldilocksField(UInt64(statement.profileID)),
        GoldilocksField(UInt64(publicInput.instances.count)),
        GoldilocksField(UInt64(publicInput.priorClaims.count))
    ]
    trace.append(contentsOf: spartanFRIDigestFields(statement.sourceProofDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.shapeDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.statementDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.verifierKeyDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.transcriptDomain))
    trace.append(contentsOf: spartanFRIDigestFields(statement.publicInputDigest))
    trace.append(contentsOf: spartanFRIDigestFields(publicInput.recursiveRelationDigest ?? Digest256.hash("SUPERNEO/TERMINAL_VERIFIER/NO_RECURSIVE_RELATION/v1")))
    trace.append(contentsOf: spartanFRIDigestFields(policyDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.terminalStatementDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.foldProofDigest))
    trace.append(contentsOf: spartanFRIDigestFields(statement.ceOpeningProofDigest))
    trace.append(contentsOf: [
        .one, // canonical source envelope decoding
        .one, // source digest and byte-count binding
        .one, // verifier key binding
        .one, // public statement binding
        .one, // recursiveRelationDigest binding
        .one, // fold boundary verification
        .one, // PiCCS verification
        .one, // PiRLC verification
        .one, // PiDEC verification
        .one, // terminal CE opening verification
        .one, // Ajtai commitment verification
        .one, // Module-SIS low-norm checks
        accepted ? .one : .zero
    ])
    return trace
}

private func terminalVerifierExecutionResidualVector(trace: [GoldilocksField]) -> [GoldilocksField] {
    guard trace.count >= 13 else {
        return trace.map { $0 - $0 }
    }
    var residual = Array(repeating: GoldilocksField.zero, count: trace.count)
    let flagStart = trace.count - 13
    for index in flagStart..<trace.count {
        residual[index] = trace[index] * (trace[index] - .one)
    }
    residual[trace.count - 1] = trace[trace.count - 1] - .one
    return residual
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
    domain: String,
    index: Int,
    leafCount: Int,
    point: GoldilocksField,
    value: GoldilocksField
) -> Digest384 {
    SuperNeoSplitQRO.hMerkleLeaf(
        domain: domain,
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
