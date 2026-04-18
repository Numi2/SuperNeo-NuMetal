import Foundation

public enum NumiSealArtifactVerificationError: Error, Equatable, CustomStringConvertible {
    case invalid(String)

    public var description: String {
        switch self {
        case .invalid(let message):
            return message
        }
    }
}

public struct NumiSealArtifact: Codable, Equatable, Sendable {
    public static let artifactVersion: UInt32 = 1
    public static let proofKind = "numiseal-terminal"
    public static let residualMode = "immediate"
    public static let topLevelKeys: Set<String> = [
        "aggregateDigestsHex",
        "artifactVersion",
        "ceRandomSeedsUTF8",
        "componentDigestRootHex",
        "foldTranscriptSeedUTF8",
        "keyColumnCount",
        "keySeedUTF8",
        "laneIDsUTF8",
        "laneSummaryRootHex",
        "maximumAggregatesPerLane",
        "maximumLaneCount",
        "maximumObligationsPerAggregate",
        "obligationRootHex",
        "privateWitnessCount",
        "profile",
        "proofEnvelopeBase64",
        "proofKind",
        "proofTranscriptDigestHex",
        "publicInputCount",
        "publicInputs",
        "publicStatementDigestHex",
        "residualMode",
        "shapeDigestHex",
        "sourceFoldDigestSeedsUTF8",
        "statementDigestHex",
        "transcriptDomainHex",
        "verifierKeyDigestHex",
        "workload",
    ]

    public let artifactVersion: UInt32
    public let workload: String
    public let profile: String
    public let proofKind: String
    public let residualMode: String
    public let keySeedUTF8: String
    public let keyColumnCount: Int
    public let foldTranscriptSeedUTF8: String
    public let laneIDsUTF8: [String]
    public let sourceFoldDigestSeedsUTF8: [String]
    public let ceRandomSeedsUTF8: [String]
    public let maximumObligationsPerAggregate: Int
    public let maximumLaneCount: Int
    public let maximumAggregatesPerLane: Int
    public let publicInputCount: Int
    public let privateWitnessCount: Int
    public let publicInputs: [UInt64]
    public let shapeDigestHex: String
    public let statementDigestHex: String
    public let verifierKeyDigestHex: String
    public let transcriptDomainHex: String
    public let publicStatementDigestHex: String
    public let obligationRootHex: String
    public let laneSummaryRootHex: String
    public let aggregateDigestsHex: [String]
    public let componentDigestRootHex: String
    public let proofTranscriptDigestHex: String
    public let proofEnvelopeBase64: String

    public init(
        artifactVersion: UInt32,
        workload: String,
        profile: String,
        proofKind: String,
        residualMode: String,
        keySeedUTF8: String,
        keyColumnCount: Int,
        foldTranscriptSeedUTF8: String,
        laneIDsUTF8: [String],
        sourceFoldDigestSeedsUTF8: [String],
        ceRandomSeedsUTF8: [String],
        maximumObligationsPerAggregate: Int,
        maximumLaneCount: Int,
        maximumAggregatesPerLane: Int,
        publicInputCount: Int,
        privateWitnessCount: Int,
        publicInputs: [UInt64],
        shapeDigestHex: String,
        statementDigestHex: String,
        verifierKeyDigestHex: String,
        transcriptDomainHex: String,
        publicStatementDigestHex: String,
        obligationRootHex: String,
        laneSummaryRootHex: String,
        aggregateDigestsHex: [String],
        componentDigestRootHex: String,
        proofTranscriptDigestHex: String,
        proofEnvelopeBase64: String
    ) {
        self.artifactVersion = artifactVersion
        self.workload = workload
        self.profile = profile
        self.proofKind = proofKind
        self.residualMode = residualMode
        self.keySeedUTF8 = keySeedUTF8
        self.keyColumnCount = keyColumnCount
        self.foldTranscriptSeedUTF8 = foldTranscriptSeedUTF8
        self.laneIDsUTF8 = laneIDsUTF8
        self.sourceFoldDigestSeedsUTF8 = sourceFoldDigestSeedsUTF8
        self.ceRandomSeedsUTF8 = ceRandomSeedsUTF8
        self.maximumObligationsPerAggregate = maximumObligationsPerAggregate
        self.maximumLaneCount = maximumLaneCount
        self.maximumAggregatesPerLane = maximumAggregatesPerLane
        self.publicInputCount = publicInputCount
        self.privateWitnessCount = privateWitnessCount
        self.publicInputs = publicInputs
        self.shapeDigestHex = shapeDigestHex
        self.statementDigestHex = statementDigestHex
        self.verifierKeyDigestHex = verifierKeyDigestHex
        self.transcriptDomainHex = transcriptDomainHex
        self.publicStatementDigestHex = publicStatementDigestHex
        self.obligationRootHex = obligationRootHex
        self.laneSummaryRootHex = laneSummaryRootHex
        self.aggregateDigestsHex = aggregateDigestsHex
        self.componentDigestRootHex = componentDigestRootHex
        self.proofTranscriptDigestHex = proofTranscriptDigestHex
        self.proofEnvelopeBase64 = proofEnvelopeBase64
    }

    public func proofEnvelopeBytes() throws -> [UInt8] {
        guard let data = Data(base64Encoded: proofEnvelopeBase64) else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof envelope is not valid base64")
        }
        return [UInt8](data)
    }
}

public struct NumiSealArtifactExpectedContext: Equatable, Sendable {
    public let trustedKeySeedUTF8: String?
    public let verifierKeyDigest: Digest256?
    public let shapeDigest: Digest256?
    public let statementDigest: Digest256?
    public let transcriptDomainDigest: Digest256?
    public let publicStatementDigest: Digest256?
    public let obligationRoot: Digest256?
    public let laneSummaryRoot: Digest256?
    public let aggregateDigests: [Digest256]?
    public let componentDigestRoot: Digest256?
    public let proofTranscriptDigest: Digest256?
    public let publicInputs: [UInt64]?

    public init(
        trustedKeySeedUTF8: String? = nil,
        verifierKeyDigest: Digest256? = nil,
        shapeDigest: Digest256? = nil,
        statementDigest: Digest256? = nil,
        transcriptDomainDigest: Digest256? = nil,
        publicStatementDigest: Digest256? = nil,
        obligationRoot: Digest256? = nil,
        laneSummaryRoot: Digest256? = nil,
        aggregateDigests: [Digest256]? = nil,
        componentDigestRoot: Digest256? = nil,
        proofTranscriptDigest: Digest256? = nil,
        publicInputs: [UInt64]? = nil
    ) {
        self.trustedKeySeedUTF8 = trustedKeySeedUTF8
        self.verifierKeyDigest = verifierKeyDigest
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.transcriptDomainDigest = transcriptDomainDigest
        self.publicStatementDigest = publicStatementDigest
        self.obligationRoot = obligationRoot
        self.laneSummaryRoot = laneSummaryRoot
        self.aggregateDigests = aggregateDigests
        self.componentDigestRoot = componentDigestRoot
        self.proofTranscriptDigest = proofTranscriptDigest
        self.publicInputs = publicInputs
    }
}

public struct NumiSealArtifactVerificationMaterial: Equatable, Sendable {
    public let shape: CCSShape
    public let key: AjtaiCommitmentKey
    public let obligations: [NumiSealObligation]
    public let policy: NumiSealAcceptancePolicy
    public let terminalPolicy: NumiSealTerminalProofAcceptancePolicy
    public let aggregationLimits: NumiSealAggregationLimits
    public let plan: NumiSealProvingPlan

    public init(
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        obligations: [NumiSealObligation],
        policy: NumiSealAcceptancePolicy,
        terminalPolicy: NumiSealTerminalProofAcceptancePolicy,
        aggregationLimits: NumiSealAggregationLimits,
        plan: NumiSealProvingPlan
    ) {
        self.shape = shape
        self.key = key
        self.obligations = obligations
        self.policy = policy
        self.terminalPolicy = terminalPolicy
        self.aggregationLimits = aggregationLimits
        self.plan = plan
    }
}

public struct NumiSealArtifactVerificationReport: Equatable, Sendable {
    public let material: NumiSealArtifactVerificationMaterial
    public let envelope: NumiSealProofEnvelope
    public let verificationResult: NumiSealVerificationResult

    public init(
        material: NumiSealArtifactVerificationMaterial,
        envelope: NumiSealProofEnvelope,
        verificationResult: NumiSealVerificationResult
    ) {
        self.material = material
        self.envelope = envelope
        self.verificationResult = verificationResult
    }
}

public enum NumiSealArtifactVerifier {
    public static func verify(
        artifact: NumiSealArtifact,
        expectedContext: NumiSealArtifactExpectedContext,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealArtifactVerificationReport {
        try validateMetadata(artifact)
        let keySeed = try trustedVerificationKeySeed(from: expectedContext)
        if let expectedPublicInputs = expectedContext.publicInputs {
            guard artifact.publicInputs == expectedPublicInputs else {
                throw NumiSealArtifactVerificationError.invalid("artifact public inputs do not match expected public inputs")
            }
        }

        let proofBytes = try artifact.proofEnvelopeBytes()
        let envelope = try validatedEnvelope(from: artifact, parameters: parameters)
        let material = try makeVerificationMaterial(
            from: artifact,
            keySeed: keySeed,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        try validateMaterial(material, against: artifact)
        try validateExpectedContext(
            artifact: artifact,
            material: material,
            expectedContext: expectedContext
        )

        let verifier = NumiSealVerifier(
            shape: material.shape,
            key: material.key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let result = verifier.verify(
            proofBytes: proofBytes,
            obligations: material.obligations,
            policy: material.terminalPolicy,
            aggregationLimits: material.aggregationLimits
        )
        guard result.isValid else {
            throw NumiSealArtifactVerificationError.invalid(
                "NumiSeal terminal proof rejected: \(result.reason ?? "unknown reason")"
            )
        }
        guard result.envelope == envelope else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal verifier returned a different envelope")
        }

        return NumiSealArtifactVerificationReport(
            material: material,
            envelope: envelope,
            verificationResult: result
        )
    }

    public static func verifySelfDescribedTestVector(
        artifact: NumiSealArtifact,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealArtifactVerificationReport {
        try verify(
            artifact: artifact,
            expectedContext: NumiSealArtifactExpectedContext(
                trustedKeySeedUTF8: artifact.keySeedUTF8,
                verifierKeyDigest: try Digest256(hexDigest: artifact.verifierKeyDigestHex)
            ),
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    public static func validateMetadata(_ artifact: NumiSealArtifact) throws {
        guard artifact.artifactVersion == NumiSealArtifact.artifactVersion else {
            throw NumiSealArtifactVerificationError.invalid("unsupported NumiSeal artifact version")
        }
        guard artifact.profile == SuperNeoParameterProfile.goldilocksPhi81.name else {
            throw NumiSealArtifactVerificationError.invalid("unsupported NumiSeal profile: \(artifact.profile)")
        }
        guard artifact.proofKind == NumiSealArtifact.proofKind else {
            throw NumiSealArtifactVerificationError.invalid("unsupported NumiSeal proof kind: \(artifact.proofKind)")
        }
        guard artifact.residualMode == NumiSealArtifact.residualMode else {
            throw NumiSealArtifactVerificationError.invalid("unsupported NumiSeal residual mode: \(artifact.residualMode)")
        }
        guard artifact.publicInputCount > 0 else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal public input count must be positive")
        }
        guard artifact.privateWitnessCount >= 0 else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal private witness count cannot be negative")
        }
        guard artifact.publicInputs.count == artifact.publicInputCount else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal public input count mismatch")
        }
        _ = try publicFields(artifact.publicInputs)
        guard artifact.keyColumnCount == expectedKeyColumnCount(artifact) else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal key column count mismatch")
        }
        guard !artifact.laneIDsUTF8.isEmpty else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal artifact must include at least one lane ID")
        }
        guard artifact.laneIDsUTF8.count == artifact.sourceFoldDigestSeedsUTF8.count else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal lane/source seed count mismatch")
        }
        guard artifact.maximumObligationsPerAggregate > 0 else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal maximum obligations per aggregate must be positive")
        }
        guard artifact.maximumLaneCount > 0 else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal maximum lane count must be positive")
        }
        guard artifact.maximumAggregatesPerLane > 0 else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal maximum aggregates per lane must be positive")
        }
        guard !artifact.aggregateDigestsHex.isEmpty else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal artifact must include aggregate digests")
        }
        guard artifact.ceRandomSeedsUTF8.count == artifact.aggregateDigestsHex.count else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal CE seed count must match aggregate digest count")
        }

        for (name, digest) in [
            ("shapeDigestHex", artifact.shapeDigestHex),
            ("statementDigestHex", artifact.statementDigestHex),
            ("verifierKeyDigestHex", artifact.verifierKeyDigestHex),
            ("transcriptDomainHex", artifact.transcriptDomainHex),
            ("publicStatementDigestHex", artifact.publicStatementDigestHex),
            ("obligationRootHex", artifact.obligationRootHex),
            ("laneSummaryRootHex", artifact.laneSummaryRootHex),
            ("componentDigestRootHex", artifact.componentDigestRootHex),
            ("proofTranscriptDigestHex", artifact.proofTranscriptDigestHex),
        ] {
            _ = try Digest256(hexDigest: digest, name: "NumiSeal \(name)")
        }
        for digest in artifact.aggregateDigestsHex {
            _ = try Digest256(hexDigest: digest, name: "NumiSeal aggregate digest")
        }
    }

    public static func validatedEnvelope(
        from artifact: NumiSealArtifact,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> NumiSealProofEnvelope {
        let proofBytes = try artifact.proofEnvelopeBytes()
        _ = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: proofBytes)
        let envelope = try NumiSealProofEnvelope(bytes: proofBytes, parameters: parameters)
        try validateEnvelope(envelope, artifact: artifact)
        return envelope
    }

    public static func makeVerificationMaterial(
        from artifact: NumiSealArtifact,
        keySeed: String? = nil,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> NumiSealArtifactVerificationMaterial {
        let publicInput = try publicFields(artifact.publicInputs)
        let privateWitness = Array(repeating: GoldilocksField.zero, count: artifact.privateWitnessCount)
        let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
        let structure = CCSStructure.hadamardProduct(matrices: [matrix])
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(
            columns: artifact.keyColumnCount,
            seed: Array((keySeed ?? artifact.keySeedUTF8).utf8)
        )
        let commitment = try backend.commit(key: key, message: publicInput + privateWitness)
        let input = try SuperNeoFoldInput(
            structure: structure,
            instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
            witnesses: [CCSWitness(privateWitness)]
        )
        let fold = try backend.makeProver(
            key: key,
            executionPolicy: executionPolicy
        ).foldWithOutput(input, transcriptSeed: Array(artifact.foldTranscriptSeedUTF8.utf8))
        let publicFoldInput = SuperNeoPublicFoldInput(input)
        let statement = CCSStatement(
            shapeDigest: publicFoldInput.shape.shapeDigest,
            ccsInstances: publicFoldInput.instances
        )
        let claims = Array(fold.outputClaims.prefix(artifact.laneIDsUTF8.count))
        guard claims.count == artifact.laneIDsUTF8.count else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal fold did not produce enough output claims")
        }
        let laneIDs = try artifact.laneIDsUTF8.map(NumiSealLaneID.init)
        let obligations = zip(zip(laneIDs, claims), artifact.sourceFoldDigestSeedsUTF8).map { pair, sourceSeed in
            let (laneID, claim) = pair
            return NumiSealObligation(
                laneID: laneID,
                profileID: key.parameters.profileID,
                statement: statement,
                verifierKeyDigest: key.verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: Digest256.hash(sourceSeed)
            )
        }
        let transcriptDomain = try Digest256(
            hexDigest: artifact.transcriptDomainHex,
            name: "NumiSeal transcript domain"
        )
        let policy = NumiSealAcceptancePolicy(
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest,
            profileID: parameters.profileID,
            transcriptDomain: transcriptDomain,
            acceptedLaneIDs: Set(laneIDs)
        )
        let aggregationLimits = try NumiSealAggregationLimits(
            maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate
        )
        let prover = NumiSealProver(
            shape: input.shape,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let plan = try prover.provingPlan(
            obligations: obligations,
            policy: policy,
            aggregationLimits: aggregationLimits
        )
        let terminalPolicy = NumiSealTerminalProofAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumLaneCount: artifact.maximumLaneCount,
            maximumAggregatesPerLane: artifact.maximumAggregatesPerLane,
            acceptedResidualMode: .immediate,
            acceptedCarryMode: .none
        )
        return NumiSealArtifactVerificationMaterial(
            shape: input.shape,
            key: key,
            obligations: obligations,
            policy: policy,
            terminalPolicy: terminalPolicy,
            aggregationLimits: aggregationLimits,
            plan: plan
        )
    }

    public static func validateMaterial(
        _ material: NumiSealArtifactVerificationMaterial,
        against artifact: NumiSealArtifact
    ) throws {
        try requireBoundDigest(
            material.shape.shapeDigest,
            matchesHex: artifact.shapeDigestHex,
            label: "shape"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal artifact shape digest does not match reconstructed material")
        }
        try requireBoundDigest(
            material.policy.statementDigest,
            matchesHex: artifact.statementDigestHex,
            label: "statement"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal artifact statement digest does not match reconstructed material")
        }
        try requireBoundDigest(
            material.key.verifierKeyDigest,
            matchesHex: artifact.verifierKeyDigestHex,
            label: "verifier-key"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal artifact verifier key digest does not match regenerated key")
        }
        try requireBoundDigest(
            material.policy.transcriptDomain,
            matchesHex: artifact.transcriptDomainHex,
            label: "transcript-domain"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal artifact transcript domain does not match verification policy")
        }
        try requireBoundDigest(
            material.plan.publicStatement.digest,
            matchesHex: artifact.publicStatementDigestHex,
            label: "public-statement"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal public statement digest does not match reconstructed obligations")
        }
        try requireBoundDigest(
            material.plan.publicStatement.obligationRoot,
            matchesHex: artifact.obligationRootHex,
            label: "obligation-root"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal obligation root does not match reconstructed obligations")
        }
        try requireBoundDigest(
            material.plan.publicStatement.laneSummaryRoot,
            matchesHex: artifact.laneSummaryRootHex,
            label: "lane-summary-root"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal lane summary root does not match reconstructed obligations")
        }
        try requireBoundDigestList(
            material.plan.aggregateDigests,
            matchesHex: artifact.aggregateDigestsHex,
            label: "aggregate-digests"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal aggregate digests do not match reconstructed obligations")
        }
        guard material.plan.aggregateCount == artifact.ceRandomSeedsUTF8.count else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal CE seed count does not match reconstructed aggregate count")
        }
    }

    public static func validateEnvelope(
        _ envelope: NumiSealProofEnvelope,
        artifact: NumiSealArtifact
    ) throws {
        guard envelope.header.kind == .numiSealTerminal else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof envelope kind mismatch")
        }
        let artifactContext = try ProofEnvelopeContext(
            profileID: SuperNeoParameterProfile.goldilocksPhi81.profileID,
            kind: .numiSealTerminal,
            shapeDigest: Digest256(hexDigest: artifact.shapeDigestHex, name: "NumiSeal shape digest"),
            statementDigest: Digest256(hexDigest: artifact.statementDigestHex, name: "NumiSeal statement digest"),
            verifierKeyDigest: Digest256(hexDigest: artifact.verifierKeyDigestHex, name: "NumiSeal verifier key digest"),
            transcriptDomain: Digest256(hexDigest: artifact.transcriptDomainHex, name: "NumiSeal transcript domain")
        )
        guard envelope.header.ctcoContextBinder == artifactContext.ctcoContextBinder else {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof envelope CTCO context binder mismatch")
        }
        try requireBoundDigest(
            envelope.proof.publicStatement.digest,
            matchesHex: artifact.publicStatementDigestHex,
            label: "public-statement"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof public statement digest mismatch")
        }
        try requireBoundDigest(
            envelope.proof.publicStatement.obligationRoot,
            matchesHex: artifact.obligationRootHex,
            label: "obligation-root"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof obligation root mismatch")
        }
        try requireBoundDigest(
            envelope.proof.publicStatement.laneSummaryRoot,
            matchesHex: artifact.laneSummaryRootHex,
            label: "lane-summary-root"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof lane summary root mismatch")
        }
        try requireBoundDigestList(
            envelope.proof.laneProofs.map(\.aggregateDigest),
            matchesHex: artifact.aggregateDigestsHex,
            label: "aggregate-digests"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof aggregate digest mismatch")
        }
        try requireBoundDigest(
            envelope.proof.componentDigestRoot,
            matchesHex: artifact.componentDigestRootHex,
            label: "component-root"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof component digest root mismatch")
        }
        try requireBoundDigest(
            envelope.proof.transcriptDigest,
            matchesHex: artifact.proofTranscriptDigestHex,
            label: "proof-transcript"
        ) {
            throw NumiSealArtifactVerificationError.invalid("NumiSeal proof transcript digest mismatch")
        }
    }

    public static func validateExpectedContext(
        artifact: NumiSealArtifact,
        material: NumiSealArtifactVerificationMaterial,
        expectedContext: NumiSealArtifactExpectedContext
    ) throws {
        if let shapeDigest = expectedContext.shapeDigest {
            guard boundDigest(material.shape.shapeDigest, label: "expected-shape")
                    == boundDigest(shapeDigest, label: "expected-shape") else {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal shape digest does not match expected shape digest")
            }
        }
        if let statementDigest = expectedContext.statementDigest {
            guard boundDigest(material.policy.statementDigest, label: "expected-statement")
                    == boundDigest(statementDigest, label: "expected-statement") else {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal statement digest does not match expected statement digest")
            }
        }
        if let verifierKeyDigest = expectedContext.verifierKeyDigest {
            guard boundDigest(material.key.verifierKeyDigest, label: "expected-verifier-key")
                    == boundDigest(verifierKeyDigest, label: "expected-verifier-key") else {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal verifier key digest does not match expected verifier key digest")
            }
        }
        if let transcriptDomainDigest = expectedContext.transcriptDomainDigest {
            guard boundDigest(material.policy.transcriptDomain, label: "expected-transcript-domain")
                    == boundDigest(transcriptDomainDigest, label: "expected-transcript-domain") else {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal transcript domain does not match expected transcript domain")
            }
        }
        if let publicStatementDigest = expectedContext.publicStatementDigest {
            try requireBoundDigest(publicStatementDigest, matchesHex: artifact.publicStatementDigestHex, label: "expected-public-statement") {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal public statement digest does not match expected public statement digest")
            }
        }
        if let obligationRoot = expectedContext.obligationRoot {
            try requireBoundDigest(obligationRoot, matchesHex: artifact.obligationRootHex, label: "expected-obligation-root") {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal obligation root does not match expected obligation root")
            }
        }
        if let laneSummaryRoot = expectedContext.laneSummaryRoot {
            try requireBoundDigest(laneSummaryRoot, matchesHex: artifact.laneSummaryRootHex, label: "expected-lane-summary-root") {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal lane summary root does not match expected lane summary root")
            }
        }
        if let aggregateDigests = expectedContext.aggregateDigests {
            try requireBoundDigestList(aggregateDigests, matchesHex: artifact.aggregateDigestsHex, label: "expected-aggregate-digests") {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal aggregate digests do not match expected aggregate digests")
            }
        }
        if let componentDigestRoot = expectedContext.componentDigestRoot {
            try requireBoundDigest(componentDigestRoot, matchesHex: artifact.componentDigestRootHex, label: "expected-component-root") {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal component digest root does not match expected component digest root")
            }
        }
        if let proofTranscriptDigest = expectedContext.proofTranscriptDigest {
            try requireBoundDigest(proofTranscriptDigest, matchesHex: artifact.proofTranscriptDigestHex, label: "expected-proof-transcript") {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal proof transcript digest does not match expected proof transcript digest")
            }
        }
    }

    private static func trustedVerificationKeySeed(
        from expectedContext: NumiSealArtifactExpectedContext
    ) throws -> String? {
        if let trustedKeySeed = expectedContext.trustedKeySeedUTF8 {
            guard !trustedKeySeed.isEmpty else {
                throw NumiSealArtifactVerificationError.invalid("NumiSeal trusted key seed must not be empty")
            }
            return trustedKeySeed
        }
        guard expectedContext.verifierKeyDigest != nil else {
            throw NumiSealArtifactVerificationError.invalid(
                "NumiSeal verification requires a trusted key seed or verifier key digest in expected context"
            )
        }
        return nil
    }

    public static func expectedKeyColumnCount(_ artifact: NumiSealArtifact) -> Int {
        expectedKeyColumnCount(
            publicInputCount: artifact.publicInputCount,
            privateWitnessCount: artifact.privateWitnessCount
        )
    }

    public static func expectedKeyColumnCount(
        publicInputCount: Int,
        privateWitnessCount: Int
    ) -> Int {
        SuperNeoEmbedding.paddedLength(forFieldElementCount: publicInputCount + privateWitnessCount)
            / CyclotomicRing54.degree
    }

    private static func publicFields(_ values: [UInt64]) throws -> [GoldilocksField] {
        try values.map { value in
            guard value < GoldilocksField.modulus else {
                throw NumiSealArtifactVerificationError.invalid("public input field element is not canonical")
            }
            return GoldilocksField(value)
        }
    }

    private static func boundDigest(_ digest: Digest256, label: String) -> Digest384 {
        SuperNeoTheoremBinding.digestBinder(kind: .numiSealTerminal, label: label, digest: digest)
    }

    private static func boundDigestList(_ digests: [Digest256], label: String) -> Digest384 {
        SuperNeoTheoremBinding.digestListBinder(kind: .numiSealTerminal, label: label, digests: digests)
    }

    private static func requireBoundDigest(
        _ actual: Digest256,
        matchesHex expectedHex: String,
        label: String,
        onMismatch: () throws -> Never
    ) throws {
        let expected = try Digest256(hexDigest: expectedHex, name: "NumiSeal \(label)")
        guard boundDigest(actual, label: label) == boundDigest(expected, label: label) else {
            try onMismatch()
        }
    }

    private static func requireBoundDigestList(
        _ actual: [Digest256],
        matchesHex expectedHex: [String],
        label: String,
        onMismatch: () throws -> Never
    ) throws {
        let expected = try expectedHex.map { try Digest256(hexDigest: $0, name: "NumiSeal \(label)") }
        guard boundDigestList(actual, label: label) == boundDigestList(expected, label: label) else {
            try onMismatch()
        }
    }
}

public extension Digest256 {
    init(hexDigest raw: String, name: String = "digest") throws {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw NumiSealArtifactVerificationError.invalid("\(name) must be a 64-character lowercase or uppercase hex digest")
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(Digest256.byteCount)
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            guard let byte = UInt8(value[index..<next], radix: 16) else {
                throw NumiSealArtifactVerificationError.invalid("\(name) must be a valid hex digest")
            }
            bytes.append(byte)
            index = next
        }
        try self.init(bytes)
    }

    var hexString: String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
