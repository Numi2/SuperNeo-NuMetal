import Foundation

public enum NumiSealProvingExecutionPolicy: String, Codable, Equatable, Sendable {
    case zkMetalAccelerated = "zk-metal-accelerated"
    case zkRedundantMetal = "zk-redundant-metal"
    case zkHighAssuranceCPU = "zk-high-assurance-cpu"
    case defaultProduct = "default-product"

    public func resolvedSuperNeoPolicy(metalContext: MetalExecutionContext?) -> SuperNeoExecutionPolicy {
        switch self {
        case .zkMetalAccelerated:
            return .metalAccelerated
        case .zkRedundantMetal:
            return .cpuRedundantMetal
        case .zkHighAssuranceCPU:
            return .highAssurance
        case .defaultProduct:
            return metalContext == nil ? .highAssurance : .cpuRedundantMetal
        }
    }

    public func resolvedMetalMode(metalContext: MetalExecutionContext?) -> String {
        switch self {
        case .zkMetalAccelerated:
            return metalContext == nil ? "unavailable" : "secret-bearing-metal-accelerated"
        case .zkRedundantMetal:
            return metalContext == nil ? "unavailable" : "secret-bearing-metal-cpu-redundant"
        case .zkHighAssuranceCPU:
            return "cpu-reference"
        case .defaultProduct:
            return metalContext == nil ? "cpu-reference" : "secret-bearing-metal-cpu-redundant"
        }
    }
}

public enum NumiSealZK {
    public static let maskedDigitTensorMode = "masked-digit-tensor-v1"
    public static let nonZKMode = "none"
    public static let proofKind = "numiseal-zk"
    public static let sealMode = "numiseal-zk-v1"
}

public extension NumiSealLaneID {
    static let product = try! NumiSealLaneID("product")

    var utf8String: String {
        String(decoding: bytes, as: UTF8.self)
    }
}

public final class NumiSealMetalProvingWorkspace: @unchecked Sendable {
    public let baseWorkspace: SuperNeoMetalWorkspace
    public let provingPolicy: NumiSealProvingExecutionPolicy
    public let featureDigest: Digest256

    public init(
        baseWorkspace: SuperNeoMetalWorkspace,
        provingPolicy: NumiSealProvingExecutionPolicy
    ) {
        self.baseWorkspace = baseWorkspace
        self.provingPolicy = provingPolicy
        self.featureDigest = Digest256.hash(
            Array("SuperNeo-NuMetal.numiseal.metal-proving-workspace.v1".utf8)
                + Array(provingPolicy.rawValue.utf8)
                + baseWorkspace.key.verifierKeyDigest.superNeoBytes
                + (baseWorkspace.shapeDigest?.superNeoBytes ?? Digest256.hash("shape-unbound").superNeoBytes)
                + baseWorkspace.transformedMatricesDigest.superNeoBytes
        )
    }

    public var supportedStages: [String] {
        [
            "ajtai-batch-commitment",
            "transformed-evaluation",
            "decomposition-commitment",
            "residual-ce-opening",
            "masked-digit-tensor-application",
            "dense-layer-folding",
            "equality-weight-evaluation",
            "sumcheck-polynomial-accumulation",
            "fused-mask-sumcheck-accumulation"
        ]
    }

    public func applyMask(
        digitTensor: [CyclotomicRing54],
        mask: [CyclotomicRing54]
    ) throws -> [CyclotomicRing54] {
        if usesCPUReferenceOnly {
            return try SuperNeoMetalBackend.numiSealApplyMaskReference(
                digitTensor: digitTensor,
                mask: mask
            )
        }
        let backend = SuperNeoMetalBackend(context: baseWorkspace.context)
        let output = try backend.numiSealApplyMask(digitTensor: digitTensor, mask: mask)
        if requiresCPUOracle {
            let reference = try SuperNeoMetalBackend.numiSealApplyMaskReference(
                digitTensor: digitTensor,
                mask: mask
            )
            guard output == reference else {
                throw SuperNeoError.metalFailure("NumiSeal Metal mask application diverged from CPU oracle")
            }
        }
        return output
    }

    public func denseFold(
        lhs: [GoldilocksField],
        rhs: [GoldilocksField],
        challenge: GoldilocksField
    ) throws -> [GoldilocksField] {
        if usesCPUReferenceOnly {
            return try SuperNeoMetalBackend.numiSealDenseFoldReference(
                lhs: lhs,
                rhs: rhs,
                challenge: challenge
            )
        }
        let backend = SuperNeoMetalBackend(context: baseWorkspace.context)
        let output = try backend.numiSealDenseFold(lhs: lhs, rhs: rhs, challenge: challenge)
        if requiresCPUOracle {
            let reference = try SuperNeoMetalBackend.numiSealDenseFoldReference(
                lhs: lhs,
                rhs: rhs,
                challenge: challenge
            )
            guard output == reference else {
                throw SuperNeoError.metalFailure("NumiSeal Metal dense fold diverged from CPU oracle")
            }
        }
        return output
    }

    public func equalityWeights(point: [GoldilocksField]) throws -> [GoldilocksField] {
        if usesCPUReferenceOnly {
            return try SuperNeoMetalBackend.numiSealEqualityWeightsReference(point: point)
        }
        let backend = SuperNeoMetalBackend(context: baseWorkspace.context)
        let output = try backend.numiSealEqualityWeights(point: point)
        if requiresCPUOracle {
            let reference = try SuperNeoMetalBackend.numiSealEqualityWeightsReference(point: point)
            guard output == reference else {
                throw SuperNeoError.metalFailure("NumiSeal Metal equality weights diverged from CPU oracle")
            }
        }
        return output
    }

    public func sumcheckAccumulate(
        terms: [[GoldilocksField]],
        weights: [GoldilocksField]
    ) throws -> [GoldilocksField] {
        if usesCPUReferenceOnly {
            return try SuperNeoMetalBackend.numiSealSumcheckAccumulateReference(terms: terms, weights: weights)
        }
        let backend = SuperNeoMetalBackend(context: baseWorkspace.context)
        let output = try backend.numiSealSumcheckAccumulate(terms: terms, weights: weights)
        if requiresCPUOracle {
            let reference = try SuperNeoMetalBackend.numiSealSumcheckAccumulateReference(terms: terms, weights: weights)
            guard output == reference else {
                throw SuperNeoError.metalFailure("NumiSeal Metal sum-check accumulation diverged from CPU oracle")
            }
        }
        return output
    }

    public func applyMaskAndAccumulate(
        digitTensor: [CyclotomicRing54],
        mask: [CyclotomicRing54],
        weights: [GoldilocksField]
    ) throws -> NumiSealMaskedAccumulationResult {
        if usesCPUReferenceOnly {
            return try SuperNeoMetalBackend.numiSealApplyMaskAndAccumulateReference(
                digitTensor: digitTensor,
                mask: mask,
                weights: weights
            )
        }
        let backend = SuperNeoMetalBackend(context: baseWorkspace.context)
        let output = try backend.numiSealApplyMaskAndAccumulate(
            digitTensor: digitTensor,
            mask: mask,
            weights: weights
        )
        if requiresCPUOracle {
            let reference = try SuperNeoMetalBackend.numiSealApplyMaskAndAccumulateReference(
                digitTensor: digitTensor,
                mask: mask,
                weights: weights
            )
            guard output == reference else {
                throw SuperNeoError.metalFailure("NumiSeal Metal fused mask accumulation diverged from CPU oracle")
            }
        }
        return output
    }

    private var usesCPUReferenceOnly: Bool {
        provingPolicy == .zkHighAssuranceCPU
    }

    private var requiresCPUOracle: Bool {
        provingPolicy == .zkRedundantMetal || provingPolicy == .defaultProduct
    }
}

public struct NumiSealProvingRequest: Sendable {
    public let preparedR1CS: SuperNeoPreparedR1CS
    public let workload: String
    public let bitCount: Int
    public let publicInputs: [UInt64]
    public let keySeedUTF8: String?
    public let workloadParameters: [String: String]
    public let sourceApplicationPathUTF8: String?
    public let laneID: NumiSealLaneID
    public let executionPolicy: NumiSealProvingExecutionPolicy
    public let zkMode: String
    public let aggregationLimits: NumiSealAggregationLimits
    public let parameters: SuperNeoParameters
    public let metalContext: MetalExecutionContext?

    public init(
        preparedR1CS: SuperNeoPreparedR1CS,
        workload: String,
        bitCount: Int,
        publicInputs: [UInt64],
        keySeedUTF8: String? = nil,
        workloadParameters: [String: String] = [:],
        sourceApplicationPathUTF8: String? = nil,
        laneID: NumiSealLaneID = .product,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.nonZKMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil
    ) {
        self.preparedR1CS = preparedR1CS
        self.workload = workload
        self.bitCount = bitCount
        self.publicInputs = publicInputs
        self.keySeedUTF8 = keySeedUTF8
        self.workloadParameters = workloadParameters
        self.sourceApplicationPathUTF8 = sourceApplicationPathUTF8
        self.laneID = laneID
        self.executionPolicy = executionPolicy
        self.zkMode = zkMode
        self.aggregationLimits = aggregationLimits
        self.parameters = parameters
        self.metalContext = metalContext
    }
}

public struct NumiSealProductArtifact: Codable, Equatable, Sendable {
    public static let artifactVersion: UInt32 = 2
    public static let proofKind = "numiseal-terminal"
    public static let zkProofKind = NumiSealZK.proofKind
    public static let topLevelKeys: Set<String> = [
        "artifactVersion",
        "workload",
        "profile",
        "proofKind",
        "sealMode",
        "carryMode",
        "zkMode",
        "metalMode",
        "executionPolicy",
        "bitCount",
        "keySeedUTF8",
        "workloadParameters",
        "sourceApplicationPathUTF8",
        "publicInputs",
        "commitmentBase64",
        "sourceFoldEnvelopeBase64",
        "numiSealProofEnvelopeBase64",
        "sourceFoldEnvelopeDigestHex",
        "sourceFoldOutputClaimDigestsHex",
        "sourceFoldOutputClaimCount",
        "shapeDigestHex",
        "sourceStatementDigestHex",
        "statementDigestHex",
        "verifierKeyDigestHex",
        "transcriptDomainHex",
        "publicStatementDigestHex",
        "obligationRootHex",
        "laneSummaryRootHex",
        "aggregateDigestsHex",
        "componentDigestRootHex",
        "proofTranscriptDigestHex",
        "laneIDsUTF8",
        "maximumObligationsPerAggregate",
        "maximumLaneCount",
        "maximumAggregatesPerLane",
        "proofEnvelopeDigestHex",
        "executionPolicyMetadata"
    ]

    public var artifactVersion: UInt32
    public var workload: String
    public var profile: String
    public var proofKind: String
    public var sealMode: String
    public var carryMode: String
    public var zkMode: String
    public var metalMode: String
    public var executionPolicy: String
    public var bitCount: Int
    public var keySeedUTF8: String?
    public var workloadParameters: [String: String]
    public var sourceApplicationPathUTF8: String?
    public var publicInputs: [UInt64]
    public var commitmentBase64: String
    public var sourceFoldEnvelopeBase64: String
    public var numiSealProofEnvelopeBase64: String
    public var sourceFoldEnvelopeDigestHex: String
    public var sourceFoldOutputClaimDigestsHex: [String]
    public var sourceFoldOutputClaimCount: Int
    public var shapeDigestHex: String
    public var sourceStatementDigestHex: String
    public var statementDigestHex: String
    public var verifierKeyDigestHex: String
    public var transcriptDomainHex: String
    public var publicStatementDigestHex: String
    public var obligationRootHex: String
    public var laneSummaryRootHex: String
    public var aggregateDigestsHex: [String]
    public var componentDigestRootHex: String
    public var proofTranscriptDigestHex: String
    public var laneIDsUTF8: [String]
    public var maximumObligationsPerAggregate: Int
    public var maximumLaneCount: Int
    public var maximumAggregatesPerLane: Int
    public var proofEnvelopeDigestHex: String
    public var executionPolicyMetadata: [String: String]

    public init(
        artifactVersion: UInt32 = Self.artifactVersion,
        workload: String,
        profile: String,
        proofKind: String = Self.proofKind,
        sealMode: String,
        carryMode: String,
        zkMode: String,
        metalMode: String,
        executionPolicy: String,
        bitCount: Int,
        keySeedUTF8: String?,
        workloadParameters: [String: String],
        sourceApplicationPathUTF8: String?,
        publicInputs: [UInt64],
        commitmentBase64: String,
        sourceFoldEnvelopeBase64: String,
        numiSealProofEnvelopeBase64: String,
        sourceFoldEnvelopeDigestHex: String,
        sourceFoldOutputClaimDigestsHex: [String],
        sourceFoldOutputClaimCount: Int,
        shapeDigestHex: String,
        sourceStatementDigestHex: String,
        statementDigestHex: String,
        verifierKeyDigestHex: String,
        transcriptDomainHex: String,
        publicStatementDigestHex: String,
        obligationRootHex: String,
        laneSummaryRootHex: String,
        aggregateDigestsHex: [String],
        componentDigestRootHex: String,
        proofTranscriptDigestHex: String,
        laneIDsUTF8: [String],
        maximumObligationsPerAggregate: Int,
        maximumLaneCount: Int,
        maximumAggregatesPerLane: Int,
        proofEnvelopeDigestHex: String,
        executionPolicyMetadata: [String: String]
    ) {
        self.artifactVersion = artifactVersion
        self.workload = workload
        self.profile = profile
        self.proofKind = proofKind
        self.sealMode = sealMode
        self.carryMode = carryMode
        self.zkMode = zkMode
        self.metalMode = metalMode
        self.executionPolicy = executionPolicy
        self.bitCount = bitCount
        self.keySeedUTF8 = keySeedUTF8
        self.workloadParameters = workloadParameters
        self.sourceApplicationPathUTF8 = sourceApplicationPathUTF8
        self.publicInputs = publicInputs
        self.commitmentBase64 = commitmentBase64
        self.sourceFoldEnvelopeBase64 = sourceFoldEnvelopeBase64
        self.numiSealProofEnvelopeBase64 = numiSealProofEnvelopeBase64
        self.sourceFoldEnvelopeDigestHex = sourceFoldEnvelopeDigestHex
        self.sourceFoldOutputClaimDigestsHex = sourceFoldOutputClaimDigestsHex
        self.sourceFoldOutputClaimCount = sourceFoldOutputClaimCount
        self.shapeDigestHex = shapeDigestHex
        self.sourceStatementDigestHex = sourceStatementDigestHex
        self.statementDigestHex = statementDigestHex
        self.verifierKeyDigestHex = verifierKeyDigestHex
        self.transcriptDomainHex = transcriptDomainHex
        self.publicStatementDigestHex = publicStatementDigestHex
        self.obligationRootHex = obligationRootHex
        self.laneSummaryRootHex = laneSummaryRootHex
        self.aggregateDigestsHex = aggregateDigestsHex
        self.componentDigestRootHex = componentDigestRootHex
        self.proofTranscriptDigestHex = proofTranscriptDigestHex
        self.laneIDsUTF8 = laneIDsUTF8
        self.maximumObligationsPerAggregate = maximumObligationsPerAggregate
        self.maximumLaneCount = maximumLaneCount
        self.maximumAggregatesPerLane = maximumAggregatesPerLane
        self.proofEnvelopeDigestHex = proofEnvelopeDigestHex
        self.executionPolicyMetadata = executionPolicyMetadata
    }

    public func sourceFoldEnvelopeBytes() throws -> [UInt8] {
        guard let data = Data(base64Encoded: sourceFoldEnvelopeBase64) else {
            throw SuperNeoError.invalidEncoding("NumiSeal product source fold envelope is not valid base64")
        }
        return [UInt8](data)
    }

    public func proofEnvelopeBytes() throws -> [UInt8] {
        guard let data = Data(base64Encoded: numiSealProofEnvelopeBase64) else {
            throw SuperNeoError.invalidEncoding("NumiSeal product proof envelope is not valid base64")
        }
        return [UInt8](data)
    }
}

public struct NumiSealProductVerificationResult: Equatable, Sendable {
    public let sourceFoldResult: FoldReductionResult
    public let numiSealResult: NumiSealVerificationResult

    public init(
        sourceFoldResult: FoldReductionResult,
        numiSealResult: NumiSealVerificationResult
    ) {
        self.sourceFoldResult = sourceFoldResult
        self.numiSealResult = numiSealResult
    }
}

public final class NumiSealProductProver: @unchecked Sendable {
    public init() {}

    public func prove(_ request: NumiSealProvingRequest) throws -> NumiSealProductArtifact {
        let prepared = request.preparedR1CS
        let parameters = request.parameters
        guard prepared.key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("NumiSeal product request key parameter mismatch")
        }
        guard request.zkMode == NumiSealZK.nonZKMode || request.zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoError.invalidParameter("unsupported NumiSeal product ZK mode")
        }
        let publicInput = prepared.publicFoldInput
        let sourceStatement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
        )
        let sourceContext = ProofEnvelopeContext(
            profileID: parameters.profileID,
            kind: .foldReduction,
            statement: sourceStatement,
            verifierKeyDigest: prepared.key.verifierKeyDigest
        )
        let superNeoPolicy = request.executionPolicy.resolvedSuperNeoPolicy(metalContext: request.metalContext)
        let sourceProver = SuperNeoProver(
            parameters: parameters,
            key: prepared.key,
            context: request.metalContext,
            executionPolicy: superNeoPolicy
        )
        let sourceFold = try sourceProver.foldWithOutput(
            prepared.foldInput,
            transcriptSeed: sourceContext.transcriptBindingBytes
        )
        let sourceEnvelope = try FoldProofEnvelope(context: sourceContext, proof: sourceFold.proof)
        let sourceEnvelopeBytes = sourceEnvelope.superNeoBytes
        let sourceEnvelopeDigest = Digest256.hash(sourceEnvelopeBytes)
        let outputClaimDigests = try sourceFold.outputClaims.enumerated().map { index, claim in
            try Self.sourceFoldOutputClaimDigest(
                sourceFoldEnvelopeDigest: sourceEnvelopeDigest,
                claim: claim,
                outputIndex: index
            )
        }

        let obligations = try Self.makeWitnessedObligations(
            claims: sourceFold.outputClaims,
            laneID: request.laneID,
            profileID: parameters.profileID,
            statement: sourceStatement,
            verifierKeyDigest: prepared.key.verifierKeyDigest,
            sourceFoldOutputClaimDigests: outputClaimDigests
        )
        let acceptedLaneIDs: Set<NumiSealLaneID> = [request.laneID]
        let acceptancePolicy = NumiSealAcceptancePolicy(
            statement: sourceStatement,
            verifierKeyDigest: prepared.key.verifierKeyDigest,
            profileID: parameters.profileID,
            acceptedLaneIDs: acceptedLaneIDs
        )
        let metalWorkspace = try Self.makeMetalWorkspace(
            prepared: prepared,
            context: request.metalContext,
            executionPolicy: superNeoPolicy
        )
        let numiSealProver = NumiSealProver(
            shape: publicInput.shape,
            key: prepared.key,
            parameters: parameters,
            metalWorkspace: metalWorkspace,
            executionPolicy: superNeoPolicy
        )
        let plan = try numiSealProver.provingPlan(
            obligations: obligations.map(\.obligation),
            policy: acceptancePolicy,
            aggregationLimits: request.aggregationLimits
        )
        let tensorInputs = try Self.derivedDigitTensorInputs(
            plan: plan,
            witnessedObligations: obligations,
            shape: publicInput.shape,
            executionPolicy: superNeoPolicy
        )
        let numiSealEnvelope = try numiSealProver.prove(
            witnessedObligations: obligations,
            policy: acceptancePolicy,
            digitTensorInputs: tensorInputs,
            aggregationLimits: request.aggregationLimits
        )
        let digitTensors = try zip(plan.aggregates, tensorInputs).map { aggregate, tensorInput in
            try NumiSealDigitTensor(
                laneKey: aggregate.laneKey,
                aggregateIndex: aggregate.aggregateIndex,
                message: tensorInput.message,
                activeDigitCount: tensorInput.activeDigitCount
            )
        }
        let numiSealProductProof: (
            proofKind: String,
            sealMode: String,
            zkMode: String,
            envelopeBytes: [UInt8],
            envelopeDigest: Digest256,
            componentDigestRoot: Digest256,
            transcriptDigest: Digest256,
            extraMetadata: [String: String]
        )
        switch request.zkMode {
        case NumiSealZK.nonZKMode:
            let bytes = numiSealEnvelope.superNeoBytes
            numiSealProductProof = (
                proofKind: NumiSealProductArtifact.proofKind,
                sealMode: "numiseal-terminal-v2",
                zkMode: NumiSealZK.nonZKMode,
                envelopeBytes: bytes,
                envelopeDigest: Digest256.hash(bytes),
                componentDigestRoot: numiSealEnvelope.proof.componentDigestRoot,
                transcriptDigest: numiSealEnvelope.proof.transcriptDigest,
                extraMetadata: [:]
            )
        case NumiSealZK.maskedDigitTensorMode:
            let provingWorkspace = metalWorkspace.map {
                NumiSealMetalProvingWorkspace(
                    baseWorkspace: $0,
                    provingPolicy: request.executionPolicy
                )
            }
            let freshSession = try NumiSealZKRandomnessSession.fresh(label: "product")
            let zkEnvelope = try NumiSealZKProver().prove(
                terminalEnvelope: numiSealEnvelope,
                digitTensors: digitTensors,
                randomnessSessionMaterial: freshSession.material,
                randomnessSessionLabel: "product",
                provingWorkspace: provingWorkspace
            )
            let bytes = zkEnvelope.superNeoBytes
            numiSealProductProof = (
                proofKind: NumiSealProductArtifact.zkProofKind,
                sealMode: NumiSealZK.sealMode,
                zkMode: NumiSealZK.maskedDigitTensorMode,
                envelopeBytes: bytes,
                envelopeDigest: Digest256.hash(bytes),
                componentDigestRoot: zkEnvelope.proof.componentDigestRoot,
                transcriptDigest: zkEnvelope.proof.transcriptDigest,
                extraMetadata: [
                    "zkProofBodyVersion": "\(zkEnvelope.proof.bodyVersion)",
                    "zkMaskedResidualStatementVersion": "\(NumiSealZKMaskedResidualStatement.version)",
                    "zkRandomnessSessionDigest": zkEnvelope.proof.randomnessSessionDigest.hexString,
                    "zkLeakageDigest": zkEnvelope.proof.leakageDigest.hexString,
                    "zkMaskedResidualStatementCount": "\(zkEnvelope.proof.maskedResidualStatements.count)"
                ]
            )
        default:
            throw SuperNeoError.invalidParameter("unsupported NumiSeal product ZK mode")
        }
        let productCarryMode = "none"
        var policyMetadata = [
            "sourceFoldKind": "fold-reduction",
            "numiSealProofKind": numiSealProductProof.proofKind,
            "digitTensorDerivation": "aggregate-witness-digest-ternary-v1",
            "terminalCarryPolicy": productCarryMode,
            "metalWorkspaceFeatureDigest": metalWorkspace.map { workspace in
                NumiSealMetalProvingWorkspace(
                    baseWorkspace: workspace,
                    provingPolicy: request.executionPolicy
                ).featureDigest.hexString
            } ?? "none"
        ]
        for (key, value) in numiSealProductProof.extraMetadata {
            policyMetadata[key] = value
        }
        return NumiSealProductArtifact(
            workload: request.workload,
            profile: SuperNeoParameterProfile.goldilocksPhi81.name,
            proofKind: numiSealProductProof.proofKind,
            sealMode: numiSealProductProof.sealMode,
            carryMode: productCarryMode,
            zkMode: numiSealProductProof.zkMode,
            metalMode: request.executionPolicy.resolvedMetalMode(metalContext: request.metalContext),
            executionPolicy: request.executionPolicy.rawValue,
            bitCount: request.bitCount,
            keySeedUTF8: request.keySeedUTF8,
            workloadParameters: request.workloadParameters,
            sourceApplicationPathUTF8: request.sourceApplicationPathUTF8 ?? "unbound",
            publicInputs: request.publicInputs,
            commitmentBase64: Data(publicInput.instances[0].commitment.littleEndianBytes).base64EncodedString(),
            sourceFoldEnvelopeBase64: Data(sourceEnvelopeBytes).base64EncodedString(),
            numiSealProofEnvelopeBase64: Data(numiSealProductProof.envelopeBytes).base64EncodedString(),
            sourceFoldEnvelopeDigestHex: sourceEnvelopeDigest.hexString,
            sourceFoldOutputClaimDigestsHex: outputClaimDigests.map(\.hexString),
            sourceFoldOutputClaimCount: outputClaimDigests.count,
            shapeDigestHex: sourceStatement.shapeDigest.hexString,
            sourceStatementDigestHex: sourceStatement.statementDigest.hexString,
            statementDigestHex: sourceStatement.statementDigest.hexString,
            verifierKeyDigestHex: prepared.key.verifierKeyDigest.hexString,
            transcriptDomainHex: acceptancePolicy.transcriptDomain.hexString,
            publicStatementDigestHex: numiSealEnvelope.proof.publicStatement.digest.hexString,
            obligationRootHex: numiSealEnvelope.proof.publicStatement.obligationRoot.hexString,
            laneSummaryRootHex: numiSealEnvelope.proof.publicStatement.laneSummaryRoot.hexString,
            aggregateDigestsHex: numiSealEnvelope.proof.laneProofs.map(\.aggregateDigest.hexString),
            componentDigestRootHex: numiSealProductProof.componentDigestRoot.hexString,
            proofTranscriptDigestHex: numiSealProductProof.transcriptDigest.hexString,
            laneIDsUTF8: [request.laneID.utf8String],
            maximumObligationsPerAggregate: request.aggregationLimits.maximumObligationsPerAggregate,
            maximumLaneCount: numiSealEnvelope.proof.publicStatement.laneSummaries.count,
            maximumAggregatesPerLane: numiSealEnvelope.proof.laneProofs.count,
            proofEnvelopeDigestHex: numiSealProductProof.envelopeDigest.hexString,
            executionPolicyMetadata: policyMetadata
        )
    }

    public static func sourceFoldOutputClaimDigest(
        sourceFoldEnvelopeDigest: Digest256,
        claim: CCSEvaluationClaim,
        outputIndex: Int
    ) throws -> Digest256 {
        guard outputIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal source output claim index must be non-negative")
        }
        let publicClaim = CCSEvaluationClaim(
            commitment: claim.commitment,
            publicInput: claim.publicInput,
            point: claim.point,
            evaluations: claim.evaluations,
            witness: nil
        )
        return NumiSealEncoding.digest(
            label: "numiseal.source-fold-output-claim.v2",
            bytes: sourceFoldEnvelopeDigest.superNeoBytes
                + numiSealEncodeCount(outputIndex)
                + CEInstance(publicClaim).superNeoBytes
        )
    }

    public static func makeObligations(
        claims: [CCSEvaluationClaim],
        laneID: NumiSealLaneID,
        profileID: UInt16,
        statement: CCSStatement,
        verifierKeyDigest: Digest256,
        sourceFoldOutputClaimDigests: [Digest256]
    ) throws -> [NumiSealObligation] {
        guard claims.count == sourceFoldOutputClaimDigests.count else {
            throw SuperNeoError.invalidParameter("NumiSeal source output claim digest count mismatch")
        }
        return zip(claims, sourceFoldOutputClaimDigests).map { claim, sourceDigest in
            NumiSealObligation(
                laneID: laneID,
                profileID: profileID,
                statement: statement,
                verifierKeyDigest: verifierKeyDigest,
                instance: CEInstance(claim),
                sourceFoldDigest: sourceDigest
            )
        }
    }

    private static func makeWitnessedObligations(
        claims: [CCSEvaluationClaim],
        laneID: NumiSealLaneID,
        profileID: UInt16,
        statement: CCSStatement,
        verifierKeyDigest: Digest256,
        sourceFoldOutputClaimDigests: [Digest256]
    ) throws -> [NumiSealWitnessedObligation] {
        let obligations = try makeObligations(
            claims: claims,
            laneID: laneID,
            profileID: profileID,
            statement: statement,
            verifierKeyDigest: verifierKeyDigest,
            sourceFoldOutputClaimDigests: sourceFoldOutputClaimDigests
        )
        return try zip(obligations, claims).map { obligation, claim in
            try NumiSealWitnessedObligation(obligation: obligation, claim: claim)
        }
    }

    private static func derivedDigitTensorInputs(
        plan: NumiSealProvingPlan,
        witnessedObligations: [NumiSealWitnessedObligation],
        shape: CCSShape,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> [NumiSealAggregateDigitTensorInput] {
        var claimsByDigest: [Digest256: CCSEvaluationClaim] = [:]
        for witnessed in witnessedObligations {
            claimsByDigest[NumiSealCanonicalization.obligationDigest(witnessed.obligation)] = witnessed.claim
        }
        return try plan.aggregates.map { aggregate in
            let claims = try aggregate.obligationDigests.map { digest -> CCSEvaluationClaim in
                guard let claim = claimsByDigest[digest] else {
                    throw SuperNeoError.invalidParameter("NumiSeal product aggregate is missing a witnessed claim")
                }
                return claim
            }
            let aggregateClaim = try NumiSealAggregateEvaluationOracle.witnessedAggregateClaim(
                aggregate: aggregate,
                claims: claims,
                shape: shape,
                executionPolicy: executionPolicy
            )
            guard let witness = aggregateClaim.witness else {
                throw SuperNeoError.invalidParameter("NumiSeal product aggregate witness is missing")
            }
            return try digitTensorInput(derivedFrom: witness)
        }
    }

    private static func digitTensorInput(derivedFrom witness: [GoldilocksField]) throws -> NumiSealAggregateDigitTensorInput {
        guard !witness.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal product digit tensor cannot derive from an empty witness")
        }
        var seed = Array("SuperNeo-NuMetal.numiseal.product.digit-tensor.aggregate-witness-digest.v1".utf8)
        seed.append(contentsOf: numiSealEncodeCount(witness.count))
        for field in witness {
            seed.append(contentsOf: field.superNeoBytes)
        }
        let activeDigitCount = CyclotomicRing54.degree
        var randomBytes: [UInt8] = []
        var counter = 0
        while randomBytes.count < activeDigitCount {
            randomBytes.append(
                contentsOf: Digest256.hash(seed + numiSealEncodeCount(counter)).superNeoBytes
            )
            counter += 1
        }
        var digits: [NumiSealTernaryDigit] = []
        digits.reserveCapacity(activeDigitCount)
        for byte in randomBytes.prefix(activeDigitCount) {
            switch byte % 3 {
            case 0:
                digits.append(.zero)
            case 1:
                digits.append(.one)
            default:
                digits.append(.minusOne)
            }
        }
        let message = [CyclotomicRing54(digits.map(\.fieldElement))]
        return try NumiSealAggregateDigitTensorInput(
            message: message,
            activeDigitCount: activeDigitCount
        )
    }

    private static func makeMetalWorkspace(
        prepared: SuperNeoPreparedR1CS,
        context: MetalExecutionContext?,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> SuperNeoMetalWorkspace? {
        guard let context, executionPolicy.usesMetalAcceleration(for: prepared.publicFoldInput.shape) else {
            return nil
        }
        let compiledShape = try prepared.publicFoldInput.shape.compiledSparseForSuperNeo()
        return try SuperNeoMetalWorkspace(
            context: context,
            key: prepared.key,
            compiledShape: compiledShape
        )
    }
}

public final class NumiSealProductVerifier: @unchecked Sendable {
    public init() {}

    private static let terminalCarryPolicyMetadataKey = "terminalCarryPolicy"

    private static func acceptedCarryMode(for artifactCarryMode: String) throws -> NumiSealCarryMode {
        switch artifactCarryMode {
        case "none":
            return .none
        case "typed-optional":
            return .typedOptional
        case "typed-required":
            return .typedRequired
        default:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product carry mode")
        }
    }

    private static func productCarryModeLabel(_ carryMode: NumiSealCarryMode) throws -> String {
        switch carryMode {
        case .none:
            return "none"
        case .typedOptional:
            return "typed-optional"
        case .typedRequired:
            return "typed-required"
        case .optional, .required:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product carry mode")
        }
    }

    public func verify(
        artifact: NumiSealProductArtifact,
        sourcePublicInput: SuperNeoPublicFoldInput,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws -> NumiSealProductVerificationResult {
        try Self.validateMetadata(artifact)
        let sourceBytes = try artifact.sourceFoldEnvelopeBytes()
        let numiSealBytes = try artifact.proofEnvelopeBytes()
        let sourceDigest = Digest256.hash(sourceBytes)
        guard sourceDigest.hexString == artifact.sourceFoldEnvelopeDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product source fold digest mismatch")
        }
        guard Digest256.hash(numiSealBytes).hexString == artifact.proofEnvelopeDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product proof envelope digest mismatch")
        }

        let sourceStatement = CCSStatement(
            shapeDigest: sourcePublicInput.shape.shapeDigest,
            ccsInstances: sourcePublicInput.instances,
            priorCEInstances: sourcePublicInput.priorClaims.map { CEInstance($0) }
        )
        guard sourceStatement.shapeDigest.hexString == artifact.shapeDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product shape digest mismatch")
        }
        guard sourceStatement.statementDigest.hexString == artifact.sourceStatementDigestHex,
              sourceStatement.statementDigest.hexString == artifact.statementDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product source statement digest mismatch")
        }
        guard key.verifierKeyDigest.hexString == artifact.verifierKeyDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product verifier key digest mismatch")
        }

        let sourceContext = ProofEnvelopeContext(
            profileID: parameters.profileID,
            kind: .foldReduction,
            statement: sourceStatement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let sourceVerifier = SuperNeoVerifier(
            parameters: parameters,
            key: key,
            context: metalContext,
            executionPolicy: executionPolicy
        )
        let sourceResult = sourceVerifier.reduceFoldEnvelope(
            publicInput: sourcePublicInput,
            proofBytes: sourceBytes,
            context: sourceContext
        )
        guard sourceResult.isReductionAccepted else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal product source fold rejected: \(sourceResult.reason ?? "unknown reason")"
            )
        }
        guard sourceResult.outputClaims.count == artifact.sourceFoldOutputClaimCount else {
            throw SuperNeoError.verificationFailed("NumiSeal product source output claim count mismatch")
        }
        let outputDigests = try sourceResult.outputClaims.enumerated().map { index, claim in
            try NumiSealProductProver.sourceFoldOutputClaimDigest(
                sourceFoldEnvelopeDigest: sourceDigest,
                claim: claim,
                outputIndex: index
            )
        }
        guard outputDigests.map(\.hexString) == artifact.sourceFoldOutputClaimDigestsHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product source output claim digest mismatch")
        }
        guard let laneIDValue = artifact.laneIDsUTF8.first, artifact.laneIDsUTF8.count == 1 else {
            throw SuperNeoError.verificationFailed("NumiSeal product currently requires exactly one lane id")
        }
        let laneID = try NumiSealLaneID(laneIDValue)
        let acceptedCarryMode = try Self.acceptedCarryMode(for: artifact.carryMode)
        let obligations = try NumiSealProductProver.makeObligations(
            claims: sourceResult.outputClaims,
            laneID: laneID,
            profileID: parameters.profileID,
            statement: sourceStatement,
            verifierKeyDigest: key.verifierKeyDigest,
            sourceFoldOutputClaimDigests: outputDigests
        )
        let acceptancePolicy = try NumiSealTerminalProofAcceptancePolicy(
            profileID: parameters.profileID,
            shapeDigest: sourceStatement.shapeDigest,
            statementDigest: sourceStatement.statementDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            transcriptDomain: Digest256(hexDigest: artifact.transcriptDomainHex, name: "NumiSeal transcript domain"),
            acceptedLaneIDs: [laneID],
            maximumLaneCount: artifact.maximumLaneCount,
            maximumAggregatesPerLane: artifact.maximumAggregatesPerLane,
            acceptedResidualMode: .immediate,
            acceptedCarryMode: acceptedCarryMode
        )
        let compiledShape = try sourcePublicInput.shape.compiledSparseForSuperNeo()
        let metalWorkspace = try metalContext.map {
            try SuperNeoMetalWorkspace(context: $0, key: key, compiledShape: compiledShape)
        }
        let numiSealVerifier = NumiSealVerifier(
            shape: sourcePublicInput.shape,
            key: key,
            parameters: parameters,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        let aggregationLimits = try NumiSealAggregationLimits(
            maximumObligationsPerAggregate: artifact.maximumObligationsPerAggregate
        )
        let numiSealResult: NumiSealVerificationResult
        let publicProof: NumiSealProof
        let componentDigestRoot: Digest256
        let proofTranscriptDigest: Digest256
        switch artifact.zkMode {
        case NumiSealZK.nonZKMode:
            numiSealResult = numiSealVerifier.verify(
                proofBytes: numiSealBytes,
                obligations: obligations,
                policy: acceptancePolicy,
                aggregationLimits: aggregationLimits
            )
            guard numiSealResult.isValid, let envelope = numiSealResult.envelope else {
                throw SuperNeoError.verificationFailed(
                    "NumiSeal product proof rejected: \(numiSealResult.reason ?? "unknown reason")"
                )
            }
            publicProof = envelope.proof
            componentDigestRoot = envelope.proof.componentDigestRoot
            proofTranscriptDigest = envelope.proof.transcriptDigest
        case NumiSealZK.maskedDigitTensorMode:
            let zkResult = NumiSealZKVerifier(terminalVerifier: numiSealVerifier).verify(
                proofBytes: numiSealBytes,
                obligations: obligations,
                policy: acceptancePolicy,
                aggregationLimits: aggregationLimits,
                parameters: parameters
            )
            guard zkResult.isValid,
                  let zkEnvelope = zkResult.envelope,
                  let baseResult = zkResult.baseResult,
                  let baseEnvelope = baseResult.envelope else {
                throw SuperNeoError.verificationFailed(
                    "NumiSeal product ZK proof rejected: \(zkResult.reason ?? "unknown reason")"
                )
            }
            numiSealResult = baseResult
            publicProof = baseEnvelope.proof
            componentDigestRoot = zkEnvelope.proof.componentDigestRoot
            proofTranscriptDigest = zkEnvelope.proof.transcriptDigest
        default:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product ZK mode")
        }
        guard publicProof.publicStatement.digest.hexString == artifact.publicStatementDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product public statement digest mismatch")
        }
        guard publicProof.publicStatement.obligationRoot.hexString == artifact.obligationRootHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product obligation root mismatch")
        }
        guard publicProof.publicStatement.laneSummaryRoot.hexString == artifact.laneSummaryRootHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product lane summary root mismatch")
        }
        guard publicProof.laneProofs.map(\.aggregateDigest.hexString) == artifact.aggregateDigestsHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product aggregate digest mismatch")
        }
        guard componentDigestRoot.hexString == artifact.componentDigestRootHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product component root mismatch")
        }
        guard proofTranscriptDigest.hexString == artifact.proofTranscriptDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal product transcript digest mismatch")
        }
        return NumiSealProductVerificationResult(
            sourceFoldResult: sourceResult,
            numiSealResult: numiSealResult
        )
    }

    public static func validateMetadata(_ artifact: NumiSealProductArtifact) throws {
        guard artifact.artifactVersion == NumiSealProductArtifact.artifactVersion else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product artifact version")
        }
        guard artifact.proofKind == NumiSealProductArtifact.proofKind
                || artifact.proofKind == NumiSealProductArtifact.zkProofKind else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product proof kind")
        }
        guard artifact.sealMode == "numiseal-terminal-v2" || artifact.sealMode == NumiSealZK.sealMode else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product seal mode")
        }
        let acceptedCarryMode = try acceptedCarryMode(for: artifact.carryMode)
        let carryPolicyLabel = try productCarryModeLabel(acceptedCarryMode)
        guard artifact.executionPolicyMetadata[terminalCarryPolicyMetadataKey] == carryPolicyLabel else {
            throw SuperNeoError.invalidEncoding("NumiSeal product terminal carry policy metadata mismatch")
        }
        guard artifact.zkMode == NumiSealZK.nonZKMode || artifact.zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product ZK mode")
        }
        switch (artifact.proofKind, artifact.sealMode, artifact.zkMode) {
        case (NumiSealProductArtifact.proofKind, "numiseal-terminal-v2", NumiSealZK.nonZKMode),
             (NumiSealProductArtifact.zkProofKind, NumiSealZK.sealMode, NumiSealZK.maskedDigitTensorMode):
            break
        default:
            throw SuperNeoError.invalidEncoding("NumiSeal product proof kind, seal mode, and ZK mode are inconsistent")
        }
        guard artifact.sourceFoldOutputClaimCount == artifact.sourceFoldOutputClaimDigestsHex.count else {
            throw SuperNeoError.invalidEncoding("NumiSeal product source claim count mismatch")
        }
        guard artifact.maximumObligationsPerAggregate > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal product aggregate limit must be positive")
        }
        _ = try Digest256(hexDigest: artifact.shapeDigestHex, name: "NumiSeal shape digest")
        _ = try Digest256(hexDigest: artifact.sourceStatementDigestHex, name: "NumiSeal source statement digest")
        _ = try Digest256(hexDigest: artifact.statementDigestHex, name: "NumiSeal statement digest")
        _ = try Digest256(hexDigest: artifact.verifierKeyDigestHex, name: "NumiSeal verifier key digest")
        _ = try Digest256(hexDigest: artifact.transcriptDomainHex, name: "NumiSeal transcript domain")
        _ = try Digest256(hexDigest: artifact.publicStatementDigestHex, name: "NumiSeal public statement digest")
        _ = try Digest256(hexDigest: artifact.obligationRootHex, name: "NumiSeal obligation root")
        _ = try Digest256(hexDigest: artifact.laneSummaryRootHex, name: "NumiSeal lane summary root")
        _ = try Digest256(hexDigest: artifact.componentDigestRootHex, name: "NumiSeal component root")
        _ = try Digest256(hexDigest: artifact.proofTranscriptDigestHex, name: "NumiSeal transcript digest")
        _ = try Digest256(hexDigest: artifact.proofEnvelopeDigestHex, name: "NumiSeal proof envelope digest")
        _ = try Digest256(hexDigest: artifact.sourceFoldEnvelopeDigestHex, name: "NumiSeal source fold digest")
        for digest in artifact.sourceFoldOutputClaimDigestsHex {
            _ = try Digest256(hexDigest: digest, name: "NumiSeal source output claim digest")
        }
        for digest in artifact.aggregateDigestsHex {
            _ = try Digest256(hexDigest: digest, name: "NumiSeal aggregate digest")
        }
    }
}

public extension SuperNeoR1CSProgram {
    func proveNumiSeal(
        input: Input,
        keySeed: [UInt8],
        workload: String,
        bitCount: Int,
        publicInputs: [UInt64],
        keySeedUTF8: String? = nil,
        workloadParameters: [String: String] = [:],
        sourceApplicationPathUTF8: String? = nil,
        laneID: NumiSealLaneID = .product,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil
    ) throws -> NumiSealProductArtifact {
        let assignment = try assignment(for: input)
        let prepared = try builder.prepareForFolding(
            publicInput: assignment.publicInput,
            privateWitness: assignment.privateWitness,
            keySeed: keySeed,
            parameters: parameters,
            executionPolicy: executionPolicy.resolvedSuperNeoPolicy(metalContext: metalContext)
        )
        return try NumiSealProductProver().prove(
            NumiSealProvingRequest(
                preparedR1CS: prepared,
                workload: workload,
                bitCount: bitCount,
                publicInputs: publicInputs,
                keySeedUTF8: keySeedUTF8,
                workloadParameters: workloadParameters,
                sourceApplicationPathUTF8: sourceApplicationPathUTF8,
                laneID: laneID,
                executionPolicy: executionPolicy,
                aggregationLimits: aggregationLimits,
                parameters: parameters,
                metalContext: metalContext
            )
        )
    }
}
