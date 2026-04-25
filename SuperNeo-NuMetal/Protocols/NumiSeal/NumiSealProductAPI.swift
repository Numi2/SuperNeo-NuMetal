import Foundation

public struct NumiSealProductTrustedContext: Equatable, Sendable {
    public let workload: String
    public let bitCount: Int
    public let publicInputs: [UInt64]
    public let workloadParameters: [String: String]
    public let sourceApplicationPathUTF8: String
    public let laneID: NumiSealLaneID

    public init(
        workload: String,
        bitCount: Int,
        publicInputs: [UInt64],
        workloadParameters: [String: String],
        sourceApplicationPathUTF8: String = "unbound",
        laneID: NumiSealLaneID = .product
    ) throws {
        guard !workload.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal product workload is required")
        }
        guard bitCount > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal product bit count must be positive")
        }
        self.workload = workload
        self.bitCount = bitCount
        self.publicInputs = publicInputs
        self.workloadParameters = workloadParameters
        self.sourceApplicationPathUTF8 = sourceApplicationPathUTF8
        self.laneID = laneID
    }

    public var contextDigest: Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.product.frontend-context.v1",
            bytes: Self.contextBytes(
                workload: workload,
                bitCount: bitCount,
                publicInputs: publicInputs,
                workloadParameters: workloadParameters,
                sourceApplicationPathUTF8: sourceApplicationPathUTF8,
                laneID: laneID
            )
        )
    }

    static func contextBytes(
        workload: String,
        bitCount: Int,
        publicInputs: [UInt64],
        workloadParameters: [String: String],
        sourceApplicationPathUTF8: String,
        laneID: NumiSealLaneID
    ) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes += numiSealEncodeString(workload)
        bytes += numiSealEncodeCount(bitCount)
        bytes += numiSealEncodeCount(publicInputs.count)
        for input in publicInputs {
            bytes += withUnsafeBytes(of: input.littleEndian, Array.init)
        }
        let sortedParameters = workloadParameters.sorted { $0.key < $1.key }
        bytes += numiSealEncodeCount(sortedParameters.count)
        for (key, value) in sortedParameters {
            bytes += numiSealEncodeString(key)
            bytes += numiSealEncodeString(value)
        }
        bytes += numiSealEncodeString(sourceApplicationPathUTF8)
        bytes += laneID.superNeoBytes
        return bytes
    }
}

public struct NumiSealProductTraceExtractorEvidence: Equatable, Sendable {
    public let frontendContextDigest: Digest256
    public let sourceFoldEnvelopeDigest: Digest256
    public let sourceFoldOutputClaimDigests: [Digest256]
    public let proofEnvelopeDigest: Digest256
    public let publicStatementDigest: Digest256
    public let obligationRoot: Digest256
    public let laneSummaryRoot: Digest256
    public let aggregateDigests: [Digest256]
    public let componentDigestRoot: Digest256
    public let proofTranscriptDigest: Digest256
    public let recursiveCarryChainRoot: Digest256?
    public let ctcoContextBinder: Digest384
    public let ctcoRoot: Digest384
    public let challengeTapeSeed: Digest256
    public let evidenceDigest: Digest256

    public static func make(
        artifact: NumiSealProductArtifact,
        trustedContext: NumiSealProductTrustedContext
    ) throws -> Self {
        let proofBytes = try artifact.proofEnvelopeBytes()
        let proofHeader = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        let sourceFoldEnvelopeDigest = try Digest256(
            hexDigest: artifact.sourceFoldEnvelopeDigestHex,
            name: "NumiSeal trace source fold envelope digest"
        )
        let sourceFoldOutputClaimDigests = try artifact.sourceFoldOutputClaimDigestsHex.map {
            try Digest256(hexDigest: $0, name: "NumiSeal trace source fold output claim digest")
        }
        let proofEnvelopeDigest = try Digest256(
            hexDigest: artifact.proofEnvelopeDigestHex,
            name: "NumiSeal trace proof envelope digest"
        )
        let publicStatementDigest = try Digest256(
            hexDigest: artifact.publicStatementDigestHex,
            name: "NumiSeal trace public statement digest"
        )
        let obligationRoot = try Digest256(
            hexDigest: artifact.obligationRootHex,
            name: "NumiSeal trace obligation root"
        )
        let laneSummaryRoot = try Digest256(
            hexDigest: artifact.laneSummaryRootHex,
            name: "NumiSeal trace lane summary root"
        )
        let aggregateDigests = try artifact.aggregateDigestsHex.map {
            try Digest256(hexDigest: $0, name: "NumiSeal trace aggregate digest")
        }
        let componentDigestRoot = try Digest256(
            hexDigest: artifact.componentDigestRootHex,
            name: "NumiSeal trace component digest root"
        )
        let proofTranscriptDigest = try Digest256(
            hexDigest: artifact.proofTranscriptDigestHex,
            name: "NumiSeal trace proof transcript digest"
        )
        let recursiveCarryChainRoot = try recursiveCarryChainRootForTrace(artifact)
        let frontendContextDigest = trustedContext.contextDigest
        let traceBlocks = Self.ctcoTraceBlocks(
            frontendContextDigest: frontendContextDigest,
            sourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            sourceFoldOutputClaimDigests: sourceFoldOutputClaimDigests,
            proofEnvelopeDigest: proofEnvelopeDigest,
            publicStatementDigest: publicStatementDigest,
            obligationRoot: obligationRoot,
            laneSummaryRoot: laneSummaryRoot,
            aggregateDigests: aggregateDigests,
            componentDigestRoot: componentDigestRoot,
            proofTranscriptDigest: proofTranscriptDigest,
            recursiveCarryChainRoot: recursiveCarryChainRoot
        )
        let ctco = CTCOMoveOneCommitment(
            proofKind: proofHeader.kind,
            contextBinder: proofHeader.ctcoContextBinder,
            traceBlocks: traceBlocks
        )
        let challengeTapeSeed = SuperNeoSplitQRO.challengeTapeSeed(
            proofKind: proofHeader.kind,
            contextBinder: proofHeader.ctcoContextBinder,
            root: ctco.root,
            label: "numiseal-product-api-trace"
        )
        let evidenceDigest = Self.evidenceDigest(
            traceBlocks: traceBlocks,
            contextBinder: proofHeader.ctcoContextBinder,
            ctcoRoot: ctco.root,
            challengeTapeSeed: challengeTapeSeed
        )
        return Self(
            frontendContextDigest: frontendContextDigest,
            sourceFoldEnvelopeDigest: sourceFoldEnvelopeDigest,
            sourceFoldOutputClaimDigests: sourceFoldOutputClaimDigests,
            proofEnvelopeDigest: proofEnvelopeDigest,
            publicStatementDigest: publicStatementDigest,
            obligationRoot: obligationRoot,
            laneSummaryRoot: laneSummaryRoot,
            aggregateDigests: aggregateDigests,
            componentDigestRoot: componentDigestRoot,
            proofTranscriptDigest: proofTranscriptDigest,
            recursiveCarryChainRoot: recursiveCarryChainRoot,
            ctcoContextBinder: proofHeader.ctcoContextBinder,
            ctcoRoot: ctco.root,
            challengeTapeSeed: challengeTapeSeed,
            evidenceDigest: evidenceDigest
        )
    }

    static func recursiveCarryChainRootForTrace(_ artifact: NumiSealProductArtifact) throws -> Digest256? {
        guard artifact.carryMode == "typed-required" else {
            return nil
        }
        guard let raw = artifact.executionPolicyMetadata[NumiSealProductRecursiveCarryMetadata.chainRoot] else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry metadata is incomplete")
        }
        return try Digest256(hexDigest: raw, name: "NumiSeal trace recursive carry chain root")
    }

    static func ctcoTraceBlocks(
        frontendContextDigest: Digest256,
        sourceFoldEnvelopeDigest: Digest256,
        sourceFoldOutputClaimDigests: [Digest256],
        proofEnvelopeDigest: Digest256,
        publicStatementDigest: Digest256,
        obligationRoot: Digest256,
        laneSummaryRoot: Digest256,
        aggregateDigests: [Digest256],
        componentDigestRoot: Digest256,
        proofTranscriptDigest: Digest256,
        recursiveCarryChainRoot: Digest256?
    ) -> [CTCOTraceBlock] {
        [
            CTCOTraceBlock(label: "frontend-context", bytes: frontendContextDigest.superNeoBytes),
            CTCOTraceBlock(label: "source-fold-envelope", bytes: sourceFoldEnvelopeDigest.superNeoBytes),
            CTCOTraceBlock(
                label: "source-fold-output-claims",
                bytes: numiSealEncodeCount(sourceFoldOutputClaimDigests.count)
                    + sourceFoldOutputClaimDigests.flatMap(\.superNeoBytes)
            ),
            CTCOTraceBlock(label: "product-proof-envelope", bytes: proofEnvelopeDigest.superNeoBytes),
            CTCOTraceBlock(label: "public-statement", bytes: publicStatementDigest.superNeoBytes),
            CTCOTraceBlock(label: "obligation-root", bytes: obligationRoot.superNeoBytes),
            CTCOTraceBlock(label: "lane-summary-root", bytes: laneSummaryRoot.superNeoBytes),
            CTCOTraceBlock(
                label: "aggregate-digests",
                bytes: numiSealEncodeCount(aggregateDigests.count) + aggregateDigests.flatMap(\.superNeoBytes)
            ),
            CTCOTraceBlock(label: "component-root", bytes: componentDigestRoot.superNeoBytes),
            CTCOTraceBlock(label: "proof-transcript", bytes: proofTranscriptDigest.superNeoBytes),
            CTCOTraceBlock(
                label: "recursive-carry-chain-root",
                bytes: recursiveCarryChainRoot.map { [1] + $0.superNeoBytes } ?? [0]
            )
        ]
    }

    static func evidenceDigest(
        traceBlocks: [CTCOTraceBlock],
        contextBinder: Digest384,
        ctcoRoot: Digest384,
        challengeTapeSeed: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.product.trace-extractor-equivalence.v1",
            bytes: traceBlocks.flatMap { block in
                numiSealEncodeString(block.label) + numiSealEncodeCount(block.bytes.count) + block.bytes
            }
            + contextBinder.superNeoBytes
            + ctcoRoot.superNeoBytes
            + challengeTapeSeed.superNeoBytes
        )
    }
}

public struct NumiSealProductQROMEvidence: Equatable, Sendable {
    public static let ctcoBindingTargetEventCount = 11

    public let compilerFamily: String
    public let challengeOracleBits: Int
    public let bindingOracleBits: Int
    public let bindingTargetEventCount: Int
    public let qroChallengeDigest: Digest384
    public let queryCapLog2: Int
    public let collisionBoundFormula: String
    public let evidenceDigest: Digest256

    public static func ctco(
        traceEvidence: NumiSealProductTraceExtractorEvidence,
        qroChallenge: SuperNeoQROChallenge
    ) -> Self {
        let compilerFamily = "ctco"
        let challengeOracleBits = Digest256.byteCount * 8
        let bindingOracleBits = Digest384.byteCount * 8
        let bindingTargetEventCount = Self.ctcoBindingTargetEventCount
        let queryCapLog2 = 64
        let collisionBoundFormula = "4 * bindingTargetEventCount * Q_H^2 / 2^bindingOracleBits"
        let evidenceDigest = ctcoDigest(
            contextBinder: traceEvidence.ctcoContextBinder,
            root: traceEvidence.ctcoRoot,
            challengeTapeSeed: traceEvidence.challengeTapeSeed,
            traceEvidenceDigest: traceEvidence.evidenceDigest,
            qroChallengeDigest: qroChallenge.challengeDigest
        )
        return Self(
            compilerFamily: compilerFamily,
            challengeOracleBits: challengeOracleBits,
            bindingOracleBits: bindingOracleBits,
            bindingTargetEventCount: bindingTargetEventCount,
            qroChallengeDigest: qroChallenge.challengeDigest,
            queryCapLog2: queryCapLog2,
            collisionBoundFormula: collisionBoundFormula,
            evidenceDigest: evidenceDigest
        )
    }

    static func ctcoDigest(
        contextBinder: Digest384,
        root: Digest384,
        challengeTapeSeed: Digest256,
        traceEvidenceDigest: Digest256,
        qroChallengeDigest: Digest384
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.product.qrom.ctco.qro-evidence.v1",
            bytes: numiSealEncodeString("ctco")
                + numiSealEncodeCount(Digest256.byteCount * 8)
                + numiSealEncodeCount(Digest384.byteCount * 8)
                + numiSealEncodeCount(Self.ctcoBindingTargetEventCount)
                + numiSealEncodeCount(64)
                + numiSealEncodeString("4 * bindingTargetEventCount * Q_H^2 / 2^bindingOracleBits")
                + contextBinder.superNeoBytes
                + root.superNeoBytes
                + challengeTapeSeed.superNeoBytes
                + traceEvidenceDigest.superNeoBytes
                + qroChallengeDigest.superNeoBytes
        )
    }
}

public struct NumiSealProductConcreteExtraction: Equatable, Sendable {
    public let sourceFoldHeader: ProofEnvelopeHeader
    public let productProofHeader: ProofEnvelopeHeader
    public let sourceFoldOutputClaims: [CCSEvaluationClaim]
    public let sourceFoldOutputClaimDigests: [Digest256]
    public let obligations: [NumiSealObligation]
    public let publicStatementDigest: Digest256
    public let obligationRoot: Digest256
    public let laneSummaryRoot: Digest256
    public let aggregateDigests: [Digest256]
    public let componentDigestRoot: Digest256
    public let proofTranscriptDigest: Digest256
    public let traceExtractorEvidence: NumiSealProductTraceExtractorEvidence
    public let qromEvidence: NumiSealProductQROMEvidence
    public let extractionDigest: Digest256

    public init(
        sourceFoldHeader: ProofEnvelopeHeader,
        productProofHeader: ProofEnvelopeHeader,
        sourceFoldOutputClaims: [CCSEvaluationClaim],
        sourceFoldOutputClaimDigests: [Digest256],
        obligations: [NumiSealObligation],
        publicStatementDigest: Digest256,
        obligationRoot: Digest256,
        laneSummaryRoot: Digest256,
        aggregateDigests: [Digest256],
        componentDigestRoot: Digest256,
        proofTranscriptDigest: Digest256,
        traceExtractorEvidence: NumiSealProductTraceExtractorEvidence,
        qromEvidence: NumiSealProductQROMEvidence
    ) {
        self.sourceFoldHeader = sourceFoldHeader
        self.productProofHeader = productProofHeader
        self.sourceFoldOutputClaims = sourceFoldOutputClaims.map(Self.publicDataOnly)
        self.sourceFoldOutputClaimDigests = sourceFoldOutputClaimDigests
        self.obligations = obligations
        self.publicStatementDigest = publicStatementDigest
        self.obligationRoot = obligationRoot
        self.laneSummaryRoot = laneSummaryRoot
        self.aggregateDigests = aggregateDigests
        self.componentDigestRoot = componentDigestRoot
        self.proofTranscriptDigest = proofTranscriptDigest
        self.traceExtractorEvidence = traceExtractorEvidence
        self.qromEvidence = qromEvidence
        self.extractionDigest = Self.digest(
            sourceFoldHeader: sourceFoldHeader,
            productProofHeader: productProofHeader,
            sourceFoldOutputClaims: self.sourceFoldOutputClaims,
            sourceFoldOutputClaimDigests: sourceFoldOutputClaimDigests,
            obligations: obligations,
            publicStatementDigest: publicStatementDigest,
            obligationRoot: obligationRoot,
            laneSummaryRoot: laneSummaryRoot,
            aggregateDigests: aggregateDigests,
            componentDigestRoot: componentDigestRoot,
            proofTranscriptDigest: proofTranscriptDigest,
            traceExtractorEvidenceDigest: traceExtractorEvidence.evidenceDigest,
            qromEvidenceDigest: qromEvidence.evidenceDigest
        )
    }

    public static func digest(
        sourceFoldHeader: ProofEnvelopeHeader,
        productProofHeader: ProofEnvelopeHeader,
        sourceFoldOutputClaims: [CCSEvaluationClaim],
        sourceFoldOutputClaimDigests: [Digest256],
        obligations: [NumiSealObligation],
        publicStatementDigest: Digest256,
        obligationRoot: Digest256,
        laneSummaryRoot: Digest256,
        aggregateDigests: [Digest256],
        componentDigestRoot: Digest256,
        proofTranscriptDigest: Digest256,
        traceExtractorEvidenceDigest: Digest256,
        qromEvidenceDigest: Digest256
    ) -> Digest256 {
        let publicClaims = sourceFoldOutputClaims.map(Self.publicDataOnly)
        return NumiSealEncoding.digest(
            label: "numiseal.product.concrete-extractor.v1",
            bytes: sourceFoldHeader.superNeoBytes
                + productProofHeader.superNeoBytes
                + numiSealEncodeCount(publicClaims.count)
                + publicClaims.flatMap { CEInstance($0).superNeoBytes }
                + numiSealEncodeCount(sourceFoldOutputClaimDigests.count)
                + sourceFoldOutputClaimDigests.flatMap(\.superNeoBytes)
                + numiSealEncodeCount(obligations.count)
                + obligations.flatMap(\.superNeoBytes)
                + publicStatementDigest.superNeoBytes
                + obligationRoot.superNeoBytes
                + laneSummaryRoot.superNeoBytes
                + numiSealEncodeCount(aggregateDigests.count)
                + aggregateDigests.flatMap(\.superNeoBytes)
                + componentDigestRoot.superNeoBytes
                + proofTranscriptDigest.superNeoBytes
                + traceExtractorEvidenceDigest.superNeoBytes
                + qromEvidenceDigest.superNeoBytes
        )
    }

    public static func publicDataOnly(_ claim: CCSEvaluationClaim) -> CCSEvaluationClaim {
        CCSEvaluationClaim(
            commitment: claim.commitment,
            publicInput: claim.publicInput,
            point: claim.point,
            evaluations: claim.evaluations,
            witness: nil
        )
    }
}

public enum NumiSealProductConcreteExtractor {
    public static func extract(
        artifact: NumiSealProductArtifact,
        trustedContext: NumiSealProductTrustedContext,
        sourcePublicInput: SuperNeoPublicFoldInput,
        key: AjtaiCommitmentKey,
        qroChallenge: SuperNeoQROChallenge,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
    ) throws -> NumiSealProductConcreteExtraction {
        try requireTrustedContext(trustedContext, matches: artifact)
        let verification = try NumiSealProductVerifier().verify(
            artifact: artifact,
            sourcePublicInput: sourcePublicInput,
            key: key,
            qroChallenge: qroChallenge,
            parameters: parameters,
            metalContext: metalContext,
            executionPolicy: executionPolicy,
            recursiveCarryParent: recursiveCarryParent
        )
        guard verification.sourceFoldResult.isReductionAccepted else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal product extractor requires accepted source fold reduction"
            )
        }
        guard verification.numiSealResult.isValid,
              let terminalEnvelope = verification.numiSealResult.envelope else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal product extractor requires accepted terminal seal proof"
            )
        }

        let sourceBytes = try artifact.sourceFoldEnvelopeBytes()
        let proofBytes = try artifact.proofEnvelopeBytes()
        let sourceHeader = try ProofEnvelopeHeader.parsePrefix(from: sourceBytes)
        let productHeader = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        let sourceDigest = Digest256.hash(sourceBytes)
        let sourceStatement = CCSStatement(
            shapeDigest: sourcePublicInput.shape.shapeDigest,
            ccsInstances: sourcePublicInput.instances,
            priorCEInstances: sourcePublicInput.priorClaims.map { CEInstance($0) }
        )
        let sourceOutputClaims = verification.sourceFoldResult.outputClaims
        let sourceOutputDigests = try sourceOutputClaims.enumerated().map { index, claim in
            try NumiSealProductProver.sourceFoldOutputClaimDigest(
                sourceFoldEnvelopeDigest: sourceDigest,
                claim: claim,
                outputIndex: index
            )
        }
        guard sourceOutputDigests.map(\.hexString) == artifact.sourceFoldOutputClaimDigestsHex else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal product extractor source output digest mismatch"
            )
        }
        guard let laneIDValue = artifact.laneIDsUTF8.first, artifact.laneIDsUTF8.count == 1 else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal product extractor requires exactly one lane id"
            )
        }
        let laneID = try NumiSealLaneID(laneIDValue)
        let obligations = try NumiSealProductProver.makeObligations(
            claims: sourceOutputClaims,
            laneID: laneID,
            profileID: parameters.profileID,
            statement: sourceStatement,
            verifierKeyDigest: key.verifierKeyDigest,
            sourceFoldOutputClaimDigests: sourceOutputDigests
        )
        let proof = terminalEnvelope.proof
        let aggregateDigests = proof.laneProofs.map(\.aggregateDigest)
        let componentDigestRoot: Digest256
        let proofTranscriptDigest: Digest256
        switch artifact.zkMode {
        case NumiSealZK.nonZKMode:
            componentDigestRoot = proof.componentDigestRoot
            proofTranscriptDigest = proof.transcriptDigest
        case NumiSealZK.maskedDigitTensorMode:
            let zkEnvelope = try NumiSealZKProofEnvelope(bytes: proofBytes, parameters: parameters)
            componentDigestRoot = zkEnvelope.proof.componentDigestRoot
            proofTranscriptDigest = zkEnvelope.proof.transcriptDigest
            guard zkEnvelope.proof.baseProof == proof else {
                throw SuperNeoError.verificationFailed(
                    "NumiSeal product extractor ZK base proof mismatch"
                )
            }
        default:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product ZK mode")
        }
        guard proof.publicStatement.digest.hexString == artifact.publicStatementDigestHex,
              proof.publicStatement.obligationRoot.hexString == artifact.obligationRootHex,
              proof.publicStatement.laneSummaryRoot.hexString == artifact.laneSummaryRootHex,
              aggregateDigests.map(\.hexString) == artifact.aggregateDigestsHex,
              componentDigestRoot.hexString == artifact.componentDigestRootHex,
              proofTranscriptDigest.hexString == artifact.proofTranscriptDigestHex else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal product extractor terminal binding mismatch"
            )
        }
        let traceEvidence = try NumiSealProductTraceExtractorEvidence.make(
            artifact: artifact,
            trustedContext: trustedContext
        )
        let qromEvidence = NumiSealProductQROMEvidence.ctco(
            traceEvidence: traceEvidence,
            qroChallenge: qroChallenge
        )
        return NumiSealProductConcreteExtraction(
            sourceFoldHeader: sourceHeader,
            productProofHeader: productHeader,
            sourceFoldOutputClaims: sourceOutputClaims,
            sourceFoldOutputClaimDigests: sourceOutputDigests,
            obligations: obligations,
            publicStatementDigest: proof.publicStatement.digest,
            obligationRoot: proof.publicStatement.obligationRoot,
            laneSummaryRoot: proof.publicStatement.laneSummaryRoot,
            aggregateDigests: aggregateDigests,
            componentDigestRoot: componentDigestRoot,
            proofTranscriptDigest: proofTranscriptDigest,
            traceExtractorEvidence: traceEvidence,
            qromEvidence: qromEvidence
        )
    }

    private static func requireTrustedContext(
        _ trustedContext: NumiSealProductTrustedContext,
        matches artifact: NumiSealProductArtifact
    ) throws {
        guard artifact.workload == trustedContext.workload,
              artifact.bitCount == trustedContext.bitCount,
              artifact.publicInputs == trustedContext.publicInputs,
              artifact.workloadParameters == trustedContext.workloadParameters,
              artifact.sourceApplicationPathUTF8 == trustedContext.sourceApplicationPathUTF8,
              artifact.laneIDsUTF8 == [trustedContext.laneID.utf8String],
              artifact.executionPolicyMetadata["frontendContextDigest"] == trustedContext.contextDigest.hexString else {
            throw SuperNeoError.invalidParameter(
                "NumiSeal product extractor trusted context mismatch"
            )
        }
    }
}

public struct NumiSealProductProvingOutput: Sendable {
    public let artifact: NumiSealProductArtifact
    public let trustedContext: NumiSealProductTrustedContext
    public let sourcePublicInput: SuperNeoPublicFoldInput
    public let verifierKey: AjtaiCommitmentKey
    public let qroChallenge: SuperNeoQROChallenge
    public let traceExtractorEvidence: NumiSealProductTraceExtractorEvidence
    public let qromEvidence: NumiSealProductQROMEvidence

    public var artifactDigest: Digest256 {
        get throws {
            try NumiSealProductArtifact.canonicalDigest(artifact)
        }
    }
}

public enum NumiSealProductAPI {
    public static func provePreparedR1CS(
        preparedR1CS: SuperNeoPreparedR1CS,
        trustedContext: NumiSealProductTrustedContext,
        qroChallenge: SuperNeoQROChallenge,
        keySeedUTF8: String? = nil,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil,
        sourceDecompositionProfile: SuperNeoDecompositionProfile = .payPerBit
    ) throws -> NumiSealProductProvingOutput {
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: preparedR1CS,
                workload: trustedContext.workload,
                bitCount: trustedContext.bitCount,
                publicInputs: trustedContext.publicInputs,
                qroChallenge: qroChallenge,
                keySeedUTF8: keySeedUTF8,
                workloadParameters: trustedContext.workloadParameters,
                sourceApplicationPathUTF8: trustedContext.sourceApplicationPathUTF8,
                laneID: trustedContext.laneID,
                executionPolicy: executionPolicy,
                zkMode: zkMode,
                aggregationLimits: aggregationLimits,
                parameters: parameters,
                metalContext: metalContext,
                recursiveCarryParent: recursiveCarryParent,
                sourceDecompositionProfile: sourceDecompositionProfile
            )
        )
        let traceEvidence = try NumiSealProductTraceExtractorEvidence.make(
            artifact: artifact,
            trustedContext: trustedContext
        )
        return NumiSealProductProvingOutput(
            artifact: artifact,
            trustedContext: trustedContext,
            sourcePublicInput: preparedR1CS.publicFoldInput,
            verifierKey: preparedR1CS.key,
            qroChallenge: qroChallenge,
            traceExtractorEvidence: traceEvidence,
            qromEvidence: .ctco(traceEvidence: traceEvidence, qroChallenge: qroChallenge)
        )
    }

    public static func proveOneHotVector(
        bits: [Bool],
        keySeedUTF8: String,
        qroChallenge: SuperNeoQROChallenge,
        sourceApplicationPathUTF8: String = "unbound",
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil,
        sourceDecompositionProfile: SuperNeoDecompositionProfile = .payPerBit
    ) throws -> NumiSealProductProvingOutput {
        let workload = try SuperNeoOneHotVectorWorkload(bitCount: bits.count)
        let superNeoPolicy = executionPolicy.resolvedSuperNeoPolicy(metalContext: metalContext)
        let prepared = try workload.prepareForFolding(
            bits: bits,
            keySeed: Array(keySeedUTF8.utf8),
            parameters: parameters,
            executionPolicy: superNeoPolicy
        )
        let context = try NumiSealProductTrustedContext(
            workload: "one-hot-vector-v1",
            bitCount: bits.count,
            publicInputs: [1],
            workloadParameters: ["selectedCount": "\(bits.filter { $0 }.count)"],
            sourceApplicationPathUTF8: sourceApplicationPathUTF8
        )
        return try provePreparedR1CS(
            preparedR1CS: prepared,
            trustedContext: context,
            qroChallenge: qroChallenge,
            keySeedUTF8: keySeedUTF8,
            executionPolicy: executionPolicy,
            zkMode: zkMode,
            aggregationLimits: aggregationLimits,
            parameters: parameters,
            metalContext: metalContext,
            recursiveCarryParent: recursiveCarryParent,
            sourceDecompositionProfile: sourceDecompositionProfile
        )
    }

    public static func proveBinaryAddition(
        left: UInt64,
        right: UInt64,
        operandBits: Int,
        keySeedUTF8: String,
        qroChallenge: SuperNeoQROChallenge,
        sourceApplicationPathUTF8: String = "unbound",
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil,
        sourceDecompositionProfile: SuperNeoDecompositionProfile = .payPerBit
    ) throws -> NumiSealProductProvingOutput {
        let workload = try SuperNeoBinaryAdditionWorkload(bitCount: operandBits)
        let sum = left.addingReportingOverflow(right)
        guard !sum.overflow else {
            throw SuperNeoError.invalidParameter("binary addition operands overflow UInt64")
        }
        let superNeoPolicy = executionPolicy.resolvedSuperNeoPolicy(metalContext: metalContext)
        let prepared = try workload.prepareForFolding(
            left: left,
            right: right,
            keySeed: Array(keySeedUTF8.utf8),
            parameters: parameters,
            executionPolicy: superNeoPolicy
        )
        let publicInputs = try workload.publicInput(sum: sum.partialValue).map(\.rawValue)
        let context = try NumiSealProductTrustedContext(
            workload: "binary-addition-v1",
            bitCount: operandBits,
            publicInputs: publicInputs,
            workloadParameters: [
                "leftBitCount": "\(operandBits)",
                "publicSum": "\(sum.partialValue)"
            ],
            sourceApplicationPathUTF8: sourceApplicationPathUTF8
        )
        return try provePreparedR1CS(
            preparedR1CS: prepared,
            trustedContext: context,
            qroChallenge: qroChallenge,
            keySeedUTF8: keySeedUTF8,
            executionPolicy: executionPolicy,
            zkMode: zkMode,
            aggregationLimits: aggregationLimits,
            parameters: parameters,
            metalContext: metalContext,
            recursiveCarryParent: recursiveCarryParent,
            sourceDecompositionProfile: sourceDecompositionProfile
        )
    }
}

public extension SuperNeoR1CSProgram {
    func proveNumiSealProduct(
        input: Input,
        keySeedUTF8: String,
        trustedContext: NumiSealProductTrustedContext,
        qroChallenge: SuperNeoQROChallenge,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil,
        sourceDecompositionProfile: SuperNeoDecompositionProfile = .payPerBit
    ) throws -> NumiSealProductProvingOutput {
        let assignment = try assignment(for: input)
        let prepared = try builder.prepareForFolding(
            publicInput: assignment.publicInput,
            privateWitness: assignment.privateWitness,
            keySeed: Array(keySeedUTF8.utf8),
            parameters: parameters,
            executionPolicy: executionPolicy.resolvedSuperNeoPolicy(metalContext: metalContext)
        )
        return try NumiSealProductAPI.provePreparedR1CS(
            preparedR1CS: prepared,
            trustedContext: trustedContext,
            qroChallenge: qroChallenge,
            keySeedUTF8: keySeedUTF8,
            executionPolicy: executionPolicy,
            zkMode: zkMode,
            aggregationLimits: aggregationLimits,
            parameters: parameters,
            metalContext: metalContext,
            recursiveCarryParent: recursiveCarryParent,
            sourceDecompositionProfile: sourceDecompositionProfile
        )
    }
}
