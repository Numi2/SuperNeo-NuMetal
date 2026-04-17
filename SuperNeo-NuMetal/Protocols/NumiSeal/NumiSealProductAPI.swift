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
            proofTranscriptDigest: proofTranscriptDigest
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
            ctcoContextBinder: proofHeader.ctcoContextBinder,
            ctcoRoot: ctco.root,
            challengeTapeSeed: challengeTapeSeed,
            evidenceDigest: evidenceDigest
        )
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
        proofTranscriptDigest: Digest256
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
            CTCOTraceBlock(label: "proof-transcript", bytes: proofTranscriptDigest.superNeoBytes)
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
    public let compilerFamily: String
    public let challengeOracleBits: Int
    public let bindingOracleBits: Int
    public let bindingTargetEventCount: Int
    public let queryCapLog2: Int
    public let collisionBoundFormula: String
    public let evidenceDigest: Digest256

    public static func ctco(traceEvidence: NumiSealProductTraceExtractorEvidence) -> Self {
        let compilerFamily = "ctco"
        let challengeOracleBits = Digest256.byteCount * 8
        let bindingOracleBits = Digest384.byteCount * 8
        let bindingTargetEventCount = 9
        let queryCapLog2 = 64
        let collisionBoundFormula = "4 * bindingTargetEventCount * Q_H^2 / 2^bindingOracleBits"
        let evidenceDigest = ctcoDigest(
            contextBinder: traceEvidence.ctcoContextBinder,
            root: traceEvidence.ctcoRoot,
            challengeTapeSeed: traceEvidence.challengeTapeSeed,
            traceEvidenceDigest: traceEvidence.evidenceDigest
        )
        return Self(
            compilerFamily: compilerFamily,
            challengeOracleBits: challengeOracleBits,
            bindingOracleBits: bindingOracleBits,
            bindingTargetEventCount: bindingTargetEventCount,
            queryCapLog2: queryCapLog2,
            collisionBoundFormula: collisionBoundFormula,
            evidenceDigest: evidenceDigest
        )
    }

    static func ctcoDigest(
        contextBinder: Digest384,
        root: Digest384,
        challengeTapeSeed: Digest256,
        traceEvidenceDigest: Digest256
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.product.qrom.ctco.evidence.v1",
            bytes: numiSealEncodeString("ctco")
                + numiSealEncodeCount(Digest256.byteCount * 8)
                + numiSealEncodeCount(Digest384.byteCount * 8)
                + numiSealEncodeCount(9)
                + numiSealEncodeCount(64)
                + numiSealEncodeString("4 * bindingTargetEventCount * Q_H^2 / 2^bindingOracleBits")
                + contextBinder.superNeoBytes
                + root.superNeoBytes
                + challengeTapeSeed.superNeoBytes
                + traceEvidenceDigest.superNeoBytes
        )
    }
}

public struct NumiSealProductProvingOutput: Sendable {
    public let artifact: NumiSealProductArtifact
    public let trustedContext: NumiSealProductTrustedContext
    public let sourcePublicInput: SuperNeoPublicFoldInput
    public let verifierKey: AjtaiCommitmentKey
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
        keySeedUTF8: String? = nil,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.nonZKMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
    ) throws -> NumiSealProductProvingOutput {
        let artifact = try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: preparedR1CS,
                workload: trustedContext.workload,
                bitCount: trustedContext.bitCount,
                publicInputs: trustedContext.publicInputs,
                keySeedUTF8: keySeedUTF8,
                workloadParameters: trustedContext.workloadParameters,
                sourceApplicationPathUTF8: trustedContext.sourceApplicationPathUTF8,
                laneID: trustedContext.laneID,
                executionPolicy: executionPolicy,
                zkMode: zkMode,
                aggregationLimits: aggregationLimits,
                parameters: parameters,
                metalContext: metalContext,
                recursiveCarryParent: recursiveCarryParent
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
            traceExtractorEvidence: traceEvidence,
            qromEvidence: .ctco(traceEvidence: traceEvidence)
        )
    }

    public static func proveOneHotVector(
        bits: [Bool],
        keySeedUTF8: String,
        sourceApplicationPathUTF8: String = "unbound",
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.nonZKMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
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
            keySeedUTF8: keySeedUTF8,
            executionPolicy: executionPolicy,
            zkMode: zkMode,
            aggregationLimits: aggregationLimits,
            parameters: parameters,
            metalContext: metalContext,
            recursiveCarryParent: recursiveCarryParent
        )
    }

    public static func proveBinaryAddition(
        left: UInt64,
        right: UInt64,
        operandBits: Int,
        keySeedUTF8: String,
        sourceApplicationPathUTF8: String = "unbound",
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.nonZKMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
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
            keySeedUTF8: keySeedUTF8,
            executionPolicy: executionPolicy,
            zkMode: zkMode,
            aggregationLimits: aggregationLimits,
            parameters: parameters,
            metalContext: metalContext,
            recursiveCarryParent: recursiveCarryParent
        )
    }
}

public extension SuperNeoR1CSProgram {
    func proveNumiSealProduct(
        input: Input,
        keySeedUTF8: String,
        trustedContext: NumiSealProductTrustedContext,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.nonZKMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
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
            keySeedUTF8: keySeedUTF8,
            executionPolicy: executionPolicy,
            zkMode: zkMode,
            aggregationLimits: aggregationLimits,
            parameters: parameters,
            metalContext: metalContext,
            recursiveCarryParent: recursiveCarryParent
        )
    }
}
