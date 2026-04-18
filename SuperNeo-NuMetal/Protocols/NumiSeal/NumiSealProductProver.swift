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
    public let recursiveCarryParent: NumiSealProductRecursiveCarryParent?

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
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
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
        self.recursiveCarryParent = recursiveCarryParent
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

    public static func canonicalDigest(_ artifact: NumiSealProductArtifact) throws -> Digest256 {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return Digest256.hash([UInt8](try encoder.encode(artifact)))
    }
}

public final class NumiSealProductVerificationResult: @unchecked Sendable, Equatable {
    public let sourceFoldResult: FoldReductionResult
    public let numiSealResult: NumiSealVerificationResult

    public init(
        sourceFoldResult: FoldReductionResult,
        numiSealResult: NumiSealVerificationResult
    ) {
        self.sourceFoldResult = sourceFoldResult
        self.numiSealResult = numiSealResult
    }

    public static func == (
        lhs: NumiSealProductVerificationResult,
        rhs: NumiSealProductVerificationResult
    ) -> Bool {
        lhs.sourceFoldResult == rhs.sourceFoldResult
            && lhs.numiSealResult == rhs.numiSealResult
    }
}

enum NumiSealProductRecursiveCarryMetadata {
    static let parentArtifactDigest = "recursiveCarryParentArtifactDigest"
    static let parentSourceFoldEnvelopeDigest = "recursiveCarryParentSourceFoldEnvelopeDigest"
    static let parentProductProofEnvelopeDigest = "recursiveCarryParentProductProofEnvelopeDigest"
    static let parentProducerProofEnvelopeDigest = "recursiveCarryParentProducerProofEnvelopeDigest"
    static let parentPublicStatementDigest = "recursiveCarryParentPublicStatementDigest"
    static let consumerSessionDigest = "recursiveCarryConsumerSessionDigest"
    static let nextRecursionLevel = "recursiveCarryNextRecursionLevel"
    static let claimCount = "recursiveCarryClaimCount"
    static let contextRoot = "recursiveCarryContextRoot"
    static let replayRoot = "recursiveCarryReplayRoot"

    static let keys: Set<String> = [
        parentArtifactDigest,
        parentSourceFoldEnvelopeDigest,
        parentProductProofEnvelopeDigest,
        parentProducerProofEnvelopeDigest,
        parentPublicStatementDigest,
        consumerSessionDigest,
        nextRecursionLevel,
        claimCount,
        contextRoot,
        replayRoot
    ]

    static func digestRoot(label: String, digests: [Digest256]) -> Digest256 {
        NumiSealEncoding.digest(
            label: label,
            bytes: numiSealEncodeCount(digests.count) + digests.flatMap(\.superNeoBytes)
        )
    }
}

public struct NumiSealProductRecursiveCarryReplayBinding: Equatable, Hashable, Sendable {
    public let parentArtifactDigest: Digest256
    public let parentSourceFoldEnvelopeDigest: Digest256
    public let parentProductProofEnvelopeDigest: Digest256
    public let parentProducerProofEnvelopeDigest: Digest256
    public let parentPublicStatementDigest: Digest256
    public let consumerSessionDigest: Digest256
    public let nextRecursionLevel: Int
    public let claimCount: Int
    public let contextRoot: Digest256
    public let replayRoot: Digest256

    public init(
        parentArtifactDigest: Digest256,
        parentSourceFoldEnvelopeDigest: Digest256,
        parentProductProofEnvelopeDigest: Digest256,
        parentProducerProofEnvelopeDigest: Digest256,
        parentPublicStatementDigest: Digest256,
        consumerSessionDigest: Digest256,
        nextRecursionLevel: Int,
        claimCount: Int,
        contextRoot: Digest256,
        replayRoot: Digest256
    ) throws {
        guard nextRecursionLevel > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry next recursion level is invalid")
        }
        guard claimCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry claim count is invalid")
        }
        self.parentArtifactDigest = parentArtifactDigest
        self.parentSourceFoldEnvelopeDigest = parentSourceFoldEnvelopeDigest
        self.parentProductProofEnvelopeDigest = parentProductProofEnvelopeDigest
        self.parentProducerProofEnvelopeDigest = parentProducerProofEnvelopeDigest
        self.parentPublicStatementDigest = parentPublicStatementDigest
        self.consumerSessionDigest = consumerSessionDigest
        self.nextRecursionLevel = nextRecursionLevel
        self.claimCount = claimCount
        self.contextRoot = contextRoot
        self.replayRoot = replayRoot
    }

    public var bindingDigest: Digest256 {
        var bytes = Array("SuperNeo-NuMetal.numiseal.product.recursive-carry.replay-binding.v1".utf8)
        bytes += parentArtifactDigest.superNeoBytes
        bytes += parentSourceFoldEnvelopeDigest.superNeoBytes
        bytes += parentProductProofEnvelopeDigest.superNeoBytes
        bytes += parentProducerProofEnvelopeDigest.superNeoBytes
        bytes += parentPublicStatementDigest.superNeoBytes
        bytes += consumerSessionDigest.superNeoBytes
        bytes += numiSealEncodeCount(nextRecursionLevel)
        bytes += numiSealEncodeCount(claimCount)
        bytes += contextRoot.superNeoBytes
        bytes += replayRoot.superNeoBytes
        return Digest256.hash(bytes)
    }

    public var hBindBindingDigest: Digest384 {
        SuperNeoSplitQRO.hBind(
            domain: "superneo/numiseal/ctco/carry/replay-binding/v2",
            frames: [
                Array("SuperNeo-NuMetal.numiseal.product.recursive-carry.replay-binding.v1".utf8),
                parentArtifactDigest.superNeoBytes,
                parentSourceFoldEnvelopeDigest.superNeoBytes,
                parentProductProofEnvelopeDigest.superNeoBytes,
                parentProducerProofEnvelopeDigest.superNeoBytes,
                parentPublicStatementDigest.superNeoBytes,
                consumerSessionDigest.superNeoBytes,
                numiSealEncodeCount(nextRecursionLevel),
                numiSealEncodeCount(claimCount),
                contextRoot.superNeoBytes,
                replayRoot.superNeoBytes
            ]
        )
    }

    init(metadata: [String: String]) throws {
        try self.init(
            parentArtifactDigest: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.parentArtifactDigest
            ),
            parentSourceFoldEnvelopeDigest: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.parentSourceFoldEnvelopeDigest
            ),
            parentProductProofEnvelopeDigest: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.parentProductProofEnvelopeDigest
            ),
            parentProducerProofEnvelopeDigest: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.parentProducerProofEnvelopeDigest
            ),
            parentPublicStatementDigest: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.parentPublicStatementDigest
            ),
            consumerSessionDigest: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.consumerSessionDigest
            ),
            nextRecursionLevel: Self.positiveInt(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.nextRecursionLevel
            ),
            claimCount: Self.positiveInt(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.claimCount
            ),
            contextRoot: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.contextRoot
            ),
            replayRoot: Self.digest(
                metadata,
                key: NumiSealProductRecursiveCarryMetadata.replayRoot
            )
        )
    }

    private static func digest(_ metadata: [String: String], key: String) throws -> Digest256 {
        guard let value = metadata[key] else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry metadata is incomplete")
        }
        return try Digest256(hexDigest: value, name: "NumiSeal recursive carry metadata \(key)")
    }

    private static func positiveInt(_ metadata: [String: String], key: String) throws -> Int {
        guard let value = metadata[key], let parsed = Int(value), parsed > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry metadata \(key) is invalid")
        }
        return parsed
    }
}

public extension NumiSealProductArtifact {
    func recursiveCarryReplayBinding() throws -> NumiSealProductRecursiveCarryReplayBinding? {
        try NumiSealProductVerifier.validateMetadata(self)
        guard carryMode == "typed-required" else {
            return nil
        }
        return try NumiSealProductRecursiveCarryReplayBinding(metadata: executionPolicyMetadata)
    }
}

public final class NumiSealProductRecursiveCarryParent: @unchecked Sendable {
    public let parentProductArtifactDigest: Digest256
    public let parentSourceFoldEnvelopeDigest: Digest256
    public let parentProductProofEnvelopeDigest: Digest256
    public let parentProducerProofEnvelopeDigest: Digest256
    public let parentPublicStatementDigest: Digest256
    public let consumerSessionDigest: Digest256
    public let nextRecursionLevel: Int
    public let acceptedProducerEnvelope: NumiSealProofEnvelope

    private static func equalBytes(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for index in lhs.indices where lhs[index] != rhs[index] {
            return false
        }
        return true
    }

    private static func equalDigest(_ lhs: Digest256, _ rhs: Digest256) -> Bool {
        equalBytes(lhs.bytes, rhs.bytes)
    }

    private static func equalLaneID(_ lhs: NumiSealLaneID, _ rhs: NumiSealLaneID) -> Bool {
        equalBytes(lhs.bytes, rhs.bytes)
    }

    private static func equalLaneKey(_ lhs: NumiSealLaneKey, _ rhs: NumiSealLaneKey) -> Bool {
        lhs.profileID == rhs.profileID
            && equalDigest(lhs.shapeDigest, rhs.shapeDigest)
            && equalDigest(lhs.verifierKeyDigest, rhs.verifierKeyDigest)
            && equalDigest(lhs.evalPointDigest, rhs.evalPointDigest)
            && equalLaneID(lhs.laneID, rhs.laneID)
    }

    public convenience init(
        artifact: NumiSealProductArtifact,
        verificationResult: NumiSealProductVerificationResult,
        consumerSessionDigest: Digest256,
        nextRecursionLevel: Int
    ) throws {
        guard verificationResult.sourceFoldResult.isReductionAccepted else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent source fold is not accepted")
        }
        guard verificationResult.numiSealResult.isValid,
              let parentEnvelope = verificationResult.numiSealResult.envelope else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent proof is not accepted")
        }
        try self.init(
            acceptedArtifact: artifact,
            acceptedProducerEnvelope: parentEnvelope,
            consumerSessionDigest: consumerSessionDigest,
            nextRecursionLevel: nextRecursionLevel
        )
    }

    public init(
        acceptedArtifact artifact: NumiSealProductArtifact,
        acceptedProducerEnvelope parentEnvelope: NumiSealProofEnvelope,
        consumerSessionDigest: Digest256,
        nextRecursionLevel: Int
    ) throws {
        guard nextRecursionLevel > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal recursive carry next recursion level must be positive")
        }
        let artifactDigest = try NumiSealProductArtifact.canonicalDigest(artifact)
        let sourceFoldEnvelopeDigest = try Digest256(
            hexDigest: artifact.sourceFoldEnvelopeDigestHex,
            name: "NumiSeal recursive carry parent source fold envelope digest"
        )
        let productProofEnvelopeDigest = try Digest256(
            hexDigest: artifact.proofEnvelopeDigestHex,
            name: "NumiSeal recursive carry parent product proof envelope digest"
        )
        let proofBytes = try artifact.proofEnvelopeBytes()
        guard Digest256.hash(proofBytes) == productProofEnvelopeDigest else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent product proof envelope digest mismatch")
        }
        let producerProofEnvelopeDigest = Digest256.hash(parentEnvelope.superNeoBytes)
        if artifact.zkMode == NumiSealZK.nonZKMode {
            guard producerProofEnvelopeDigest == productProofEnvelopeDigest else {
                throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent terminal envelope digest mismatch")
            }
        }
        guard parentEnvelope.proof.publicStatement.digest.hexString == artifact.publicStatementDigestHex else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent public statement mismatch")
        }
        guard parentEnvelope.proof.laneProofs.map(\.aggregateDigest.hexString) == artifact.aggregateDigestsHex else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent aggregate digest mismatch")
        }
        self.parentProductArtifactDigest = artifactDigest
        self.parentSourceFoldEnvelopeDigest = sourceFoldEnvelopeDigest
        self.parentProductProofEnvelopeDigest = productProofEnvelopeDigest
        self.parentProducerProofEnvelopeDigest = producerProofEnvelopeDigest
        self.parentPublicStatementDigest = parentEnvelope.proof.publicStatement.digest
        self.consumerSessionDigest = consumerSessionDigest
        self.nextRecursionLevel = nextRecursionLevel
        self.acceptedProducerEnvelope = parentEnvelope
    }

    public static func acceptedProducerEnvelope(
        from artifact: NumiSealProductArtifact,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> NumiSealProofEnvelope {
        let proofBytes = try artifact.proofEnvelopeBytes()
        switch artifact.zkMode {
        case NumiSealZK.nonZKMode:
            return try NumiSealProofEnvelope(bytes: proofBytes, parameters: parameters)
        case NumiSealZK.maskedDigitTensorMode:
            let zkEnvelope = try NumiSealZKProofEnvelope(bytes: proofBytes, parameters: parameters)
            let terminalContext = ProofEnvelopeContext(
                profileID: zkEnvelope.header.profileID,
                kind: .numiSealTerminal,
                shapeDigest: zkEnvelope.header.shapeDigest,
                statementDigest: zkEnvelope.header.statementDigest,
                verifierKeyDigest: zkEnvelope.header.verifierKeyDigest,
                transcriptDomain: zkEnvelope.header.transcriptDomain
            )
            return try NumiSealProofEnvelope(context: terminalContext, proof: zkEnvelope.proof.baseProof)
        default:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product ZK mode")
        }
    }

    @inline(never)
    public func laneProof(laneKey: NumiSealLaneKey, aggregateIndex: Int) throws -> NumiSealLaneProof {
        let laneProofs = acceptedProducerEnvelope.proof.laneProofs
        if laneProofs.count == 1 {
            let only = laneProofs[0]
            guard Self.equalLaneKey(only.laneKey, laneKey) && only.aggregateIndex == aggregateIndex else {
                throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent lane proof not found")
            }
            return only
        }
        for laneProof in laneProofs
            where Self.equalLaneKey(laneProof.laneKey, laneKey) && laneProof.aggregateIndex == aggregateIndex {
            return laneProof
        }
        throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent lane proof not found")
    }

    @inline(never)
    public func laneProof(laneID: NumiSealLaneID, aggregateIndex: Int) throws -> NumiSealLaneProof {
        let laneProofs = acceptedProducerEnvelope.proof.laneProofs
        if laneProofs.count == 1 {
            let only = laneProofs[0]
            guard Self.equalLaneID(only.laneKey.laneID, laneID) && only.aggregateIndex == aggregateIndex else {
                throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent lane proof not found")
            }
            return only
        }
        var match: NumiSealLaneProof?
        var matchCount = 0
        for laneProof in laneProofs
            where Self.equalLaneID(laneProof.laneKey.laneID, laneID) && laneProof.aggregateIndex == aggregateIndex {
            match = laneProof
            matchCount += 1
        }
        guard matchCount == 1, let match else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent lane proof not found")
        }
        return match
    }

    @inline(never)
    public func context(for parentLaneProof: NumiSealLaneProof) throws -> NumiSealProductCarryContext {
        let laneProofDigest = parentLaneProof.proofDigest
        let laneProofs = acceptedProducerEnvelope.proof.laneProofs
        var found = false
        if laneProofs.count == 1 {
            found = Self.equalDigest(laneProofs[0].proofDigest, laneProofDigest)
        } else {
            for laneProof in laneProofs where Self.equalDigest(laneProof.proofDigest, laneProofDigest) {
                found = true
                break
            }
        }
        guard found else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent lane proof not found")
        }
        return try NumiSealProductCarryContext(
            consumerSessionDigest: consumerSessionDigest,
            parentProductArtifactDigest: parentProductArtifactDigest,
            parentSourceFoldEnvelopeDigest: parentSourceFoldEnvelopeDigest,
            parentProductProofEnvelopeDigest: parentProductProofEnvelopeDigest,
            parentProducerProofEnvelopeDigest: parentProducerProofEnvelopeDigest,
            parentPublicStatementDigest: parentPublicStatementDigest,
            laneKey: parentLaneProof.laneKey,
            aggregateIndex: parentLaneProof.aggregateIndex,
            nextRecursionLevel: nextRecursionLevel
        )
    }

    public func metadata(
        claimCount: Int,
        contextRoot: Digest256,
        replayRoot: Digest256
    ) -> [String: String] {
        [
            NumiSealProductRecursiveCarryMetadata.parentArtifactDigest: parentProductArtifactDigest.hexString,
            NumiSealProductRecursiveCarryMetadata.parentSourceFoldEnvelopeDigest: parentSourceFoldEnvelopeDigest.hexString,
            NumiSealProductRecursiveCarryMetadata.parentProductProofEnvelopeDigest: parentProductProofEnvelopeDigest.hexString,
            NumiSealProductRecursiveCarryMetadata.parentProducerProofEnvelopeDigest: parentProducerProofEnvelopeDigest.hexString,
            NumiSealProductRecursiveCarryMetadata.parentPublicStatementDigest: parentPublicStatementDigest.hexString,
            NumiSealProductRecursiveCarryMetadata.consumerSessionDigest: consumerSessionDigest.hexString,
            NumiSealProductRecursiveCarryMetadata.nextRecursionLevel: "\(nextRecursionLevel)",
            NumiSealProductRecursiveCarryMetadata.claimCount: "\(claimCount)",
            NumiSealProductRecursiveCarryMetadata.contextRoot: contextRoot.hexString,
            NumiSealProductRecursiveCarryMetadata.replayRoot: replayRoot.hexString
        ]
    }
}

public final class NumiSealProductProver: @unchecked Sendable {
    public init() {}

    @inline(never)
    public func prove(_ request: NumiSealProvingRequest) throws -> NumiSealProductArtifact {
        let prepared = request.preparedR1CS
        let parameters = request.parameters
        guard prepared.key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("NumiSeal product request key parameter mismatch")
        }
        guard request.zkMode == NumiSealZK.nonZKMode || request.zkMode == NumiSealZK.maskedDigitTensorMode else {
            throw SuperNeoError.invalidParameter("unsupported NumiSeal product ZK mode")
        }
        try NumiSealProductTheoremLimits.validate(request: request)
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
        try NumiSealProductTheoremLimits.validateSourceFoldOutputClaimCount(sourceFold.outputClaims.count)
        let sourceEnvelope = try FoldProofEnvelope(context: sourceContext, proof: sourceFold.proof)
        let sourceEnvelopeBytes = sourceEnvelope.superNeoBytes
        let sourceEnvelopeDigest = Digest256.hash(sourceEnvelopeBytes)
        let sourceEnvelopeCTCO = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: sourceEnvelopeBytes)
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
        try NumiSealProductTheoremLimits.validate(plan: plan)
        let tensorInputs = try Self.derivedDigitTensorInputs(
            plan: plan,
            witnessedObligations: obligations,
            shape: publicInput.shape,
            executionPolicy: superNeoPolicy
        )
        let recursiveCarry = try Self.makeRecursiveCarryClaims(
            parent: request.recursiveCarryParent,
            plan: plan
        )
        let numiSealEnvelope = try numiSealProver.prove(
            witnessedObligations: obligations,
            policy: acceptancePolicy,
            digitTensorInputs: tensorInputs,
            aggregationLimits: request.aggregationLimits,
            carryClaimsByAggregate: recursiveCarry.claimsByAggregate
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
            let zkSimulatorCouplingDigest = NumiSealEncoding.digest(
                label: "numiseal.zk.product.simulator-coupling.v1",
                bytes: Digest256.hash(numiSealEnvelope.superNeoBytes).superNeoBytes
                    + zkEnvelope.proof.randomnessSessionDigest.superNeoBytes
                    + zkEnvelope.proof.leakageDigest.superNeoBytes
                    + numiSealEncodeCount(zkEnvelope.proof.maskedResidualStatements.count)
                    + zkEnvelope.proof.componentDigestRoot.superNeoBytes
                    + zkEnvelope.proof.transcriptDigest.superNeoBytes
            )
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
                    "zkMaskedResidualStatementCount": "\(zkEnvelope.proof.maskedResidualStatements.count)",
                    "zkSimulatorCouplingSurface": "terminal-base-proof-to-masked-residual-session-v1",
                    "zkSimulatorCouplingEvidenceDigest": zkSimulatorCouplingDigest.hexString
                ]
            )
        default:
            throw SuperNeoError.invalidParameter("unsupported NumiSeal product ZK mode")
        }
        let productCarryMode = request.recursiveCarryParent == nil ? "none" : "typed-required"
        let sourceApplicationPath = request.sourceApplicationPathUTF8 ?? "unbound"
        let frontendContext = try NumiSealProductTrustedContext(
            workload: request.workload,
            bitCount: request.bitCount,
            publicInputs: request.publicInputs,
            workloadParameters: request.workloadParameters,
            sourceApplicationPathUTF8: sourceApplicationPath,
            laneID: request.laneID
        )
        let productProofHeader = try ProofEnvelopeHeader.parsePrefix(from: numiSealProductProof.envelopeBytes)
        let productProofEnvelopeCTCO = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: numiSealProductProof.envelopeBytes)
        let traceBlocks = NumiSealProductTraceExtractorEvidence.ctcoTraceBlocks(
            frontendContextDigest: frontendContext.contextDigest,
            sourceFoldEnvelopeDigest: sourceEnvelopeDigest,
            sourceFoldOutputClaimDigests: outputClaimDigests,
            proofEnvelopeDigest: numiSealProductProof.envelopeDigest,
            publicStatementDigest: numiSealEnvelope.proof.publicStatement.digest,
            obligationRoot: numiSealEnvelope.proof.publicStatement.obligationRoot,
            laneSummaryRoot: numiSealEnvelope.proof.publicStatement.laneSummaryRoot,
            aggregateDigests: numiSealEnvelope.proof.laneProofs.map(\.aggregateDigest),
            componentDigestRoot: numiSealProductProof.componentDigestRoot,
            proofTranscriptDigest: numiSealProductProof.transcriptDigest
        )
        let ctcoCommitment = CTCOMoveOneCommitment(
            proofKind: productProofHeader.kind,
            contextBinder: productProofHeader.ctcoContextBinder,
            traceBlocks: traceBlocks
        )
        let ctcoChallengeSeed = SuperNeoSplitQRO.challengeTapeSeed(
            proofKind: productProofHeader.kind,
            contextBinder: productProofHeader.ctcoContextBinder,
            root: ctcoCommitment.root,
            label: "numiseal-product-api-trace"
        )
        let traceEvidenceDigest = NumiSealProductTraceExtractorEvidence.evidenceDigest(
            traceBlocks: traceBlocks,
            contextBinder: productProofHeader.ctcoContextBinder,
            ctcoRoot: ctcoCommitment.root,
            challengeTapeSeed: ctcoChallengeSeed
        )
        let qromEvidenceDigest = NumiSealProductQROMEvidence.ctcoDigest(
            contextBinder: productProofHeader.ctcoContextBinder,
            root: ctcoCommitment.root,
            challengeTapeSeed: ctcoChallengeSeed,
            traceEvidenceDigest: traceEvidenceDigest
        )
        let concreteExtractorDigest = NumiSealProductConcreteExtraction.digest(
            sourceFoldHeader: sourceEnvelope.header,
            productProofHeader: productProofHeader,
            sourceFoldOutputClaims: sourceFold.outputClaims.map(NumiSealProductConcreteExtraction.publicDataOnly),
            sourceFoldOutputClaimDigests: outputClaimDigests,
            obligations: obligations.map(\.obligation),
            publicStatementDigest: numiSealEnvelope.proof.publicStatement.digest,
            obligationRoot: numiSealEnvelope.proof.publicStatement.obligationRoot,
            laneSummaryRoot: numiSealEnvelope.proof.publicStatement.laneSummaryRoot,
            aggregateDigests: numiSealEnvelope.proof.laneProofs.map(\.aggregateDigest),
            componentDigestRoot: numiSealProductProof.componentDigestRoot,
            proofTranscriptDigest: numiSealProductProof.transcriptDigest,
            traceExtractorEvidenceDigest: traceEvidenceDigest,
            qromEvidenceDigest: qromEvidenceDigest
        )
        var policyMetadata = [
            "sourceFoldKind": "fold-reduction",
            "numiSealProofKind": numiSealProductProof.proofKind,
            "digitTensorDerivation": "aggregate-witness-digest-ternary-v1",
            "frontendObligationPath": "r1cs-prepared-to-source-fold-output-claims-v1",
            "frontendContextDigest": frontendContext.contextDigest.hexString,
            "swiftTraceExtractorSurface": "source-fold-output-claims-to-numiseal-obligations-v1",
            "swiftTraceExtractorEvidenceDigest": traceEvidenceDigest.hexString,
            "swiftConcreteExtractorSurface": "post-acceptance-source-fold-terminal-envelope-replay-v1",
            "swiftConcreteExtractorEvidenceDigest": concreteExtractorDigest.hexString,
            "ctcoCompilerFamily": "ctco",
            "ctcoContextBinder384Hex": productProofHeader.ctcoContextBinder.hexString,
            "ctcoRoot384Hex": ctcoCommitment.root.hexString,
            "ctcoChallengeTapeSeedHex": ctcoChallengeSeed.hexString,
            "sourceFoldCTCORoot384Hex": sourceEnvelopeCTCO.root.hexString,
            "sourceFoldCTCOChallengeTapeSeedHex": sourceEnvelopeCTCO.challengeTapeSeed.hexString,
            "proofEnvelopeCTCORoot384Hex": productProofEnvelopeCTCO.root.hexString,
            "proofEnvelopeCTCOChallengeTapeSeedHex": productProofEnvelopeCTCO.challengeTapeSeed.hexString,
            "qromChallengeOracleBits": "\(Digest256.byteCount * 8)",
            "qromBindingOracleBits": "\(Digest384.byteCount * 8)",
            "qromBindingTargetEventCount": "9",
            "qromQueryCapLog2": "64",
            "qromEvidenceDigest": qromEvidenceDigest.hexString,
            "recursiveCarryMaximumSupportedDepth": "\(max(1, request.recursiveCarryParent?.nextRecursionLevel ?? 1))",
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
        for (key, value) in recursiveCarry.metadata {
            policyMetadata[key] = value
        }
        let artifact = NumiSealProductArtifact(
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
            sourceApplicationPathUTF8: sourceApplicationPath,
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
        try NumiSealProductVerifier.validateMetadata(artifact)
        return artifact
    }

    private static func makeRecursiveCarryClaims(
        parent: NumiSealProductRecursiveCarryParent?,
        plan: NumiSealProvingPlan
    ) throws -> (
        claimsByAggregate: [NumiSealAggregateKey: NumiSealCarryClaim],
        metadata: [String: String]
    ) {
        guard let parent else {
            return ([:], [:])
        }
        var claimsByAggregate: [NumiSealAggregateKey: NumiSealCarryClaim] = [:]
        var contextDigests: [Digest256] = []
        var replayIdentities: [Digest256] = []
        let producer = NumiSealTypedCarryProducer()
        for aggregate in plan.aggregates {
            let parentLaneProof = try parent.laneProof(
                laneID: aggregate.laneKey.laneID,
                aggregateIndex: aggregate.aggregateIndex
            )
            let carryContext = try parent.context(for: parentLaneProof)
            let statement = try producer.produce(
                fromAcceptedParent: parent.acceptedProducerEnvelope,
                parentProofAccepted: true,
                laneProof: parentLaneProof,
                consumerContextDigest: carryContext.contextDigest,
                nextRecursionLevel: parent.nextRecursionLevel
            )
            guard statement.laneKey.laneID == aggregate.laneKey.laneID,
                  statement.aggregateIndex == aggregate.aggregateIndex else {
                throw SuperNeoError.verificationFailed("NumiSeal recursive carry statement target mismatch")
            }
            let aggregateKey = try NumiSealAggregateKey(
                laneKey: aggregate.laneKey,
                aggregateIndex: aggregate.aggregateIndex
            )
            claimsByAggregate[aggregateKey] = try NumiSealCarryClaim(statement.superNeoBytes)
            contextDigests.append(carryContext.contextDigest)
            replayIdentities.append(NumiSealCarryConsumer.replayIdentity(for: statement))
        }
        guard claimsByAggregate.count == plan.aggregateCount else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry claim count mismatch")
        }
        let contextRoot = NumiSealProductRecursiveCarryMetadata.digestRoot(
            label: "numiseal.product-carry.context-root.v1",
            digests: contextDigests
        )
        let replayRoot = NumiSealProductRecursiveCarryMetadata.digestRoot(
            label: "numiseal.product-carry.replay-root.v1",
            digests: replayIdentities
        )
        return (
            claimsByAggregate,
            parent.metadata(
                claimCount: claimsByAggregate.count,
                contextRoot: contextRoot,
                replayRoot: replayRoot
            )
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

    @inline(never)
    public func verify(
        artifact: NumiSealProductArtifact,
        sourcePublicInput: SuperNeoPublicFoldInput,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
    ) throws -> NumiSealProductVerificationResult {
        try Self.validateMetadata(artifact)
        let sourceBytes = try artifact.sourceFoldEnvelopeBytes()
        let numiSealBytes = try artifact.proofEnvelopeBytes()
        _ = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: sourceBytes)
        _ = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: numiSealBytes)
        let sourceDigest = Digest256.hash(sourceBytes)
        try Self.requireBoundDigest(
            sourceDigest,
            matchesHex: artifact.sourceFoldEnvelopeDigestHex,
            kind: .foldReduction,
            label: "source-fold-envelope"
        ) {
            throw SuperNeoError.verificationFailed("NumiSeal product source fold digest mismatch")
        }
        let proofKind = try ProofEnvelopeHeader.parsePrefix(from: numiSealBytes).kind
        try Self.requireBoundDigest(
            Digest256.hash(numiSealBytes),
            matchesHex: artifact.proofEnvelopeDigestHex,
            kind: proofKind,
            label: "product-proof-envelope"
        ) {
            throw SuperNeoError.verificationFailed("NumiSeal product proof envelope digest mismatch")
        }

        let sourceStatement = CCSStatement(
            shapeDigest: sourcePublicInput.shape.shapeDigest,
            ccsInstances: sourcePublicInput.instances,
            priorCEInstances: sourcePublicInput.priorClaims.map { CEInstance($0) }
        )
        try Self.requireBoundDigest(sourceStatement.shapeDigest, matchesHex: artifact.shapeDigestHex, kind: .foldReduction, label: "shape") {
            throw SuperNeoError.verificationFailed("NumiSeal product shape digest mismatch")
        }
        try Self.requireBoundDigest(
            sourceStatement.statementDigest,
            matchesHex: artifact.sourceStatementDigestHex,
            kind: .foldReduction,
            label: "source-statement"
        ) {
            throw SuperNeoError.verificationFailed("NumiSeal product source statement digest mismatch")
        }
        try Self.requireBoundDigest(
            sourceStatement.statementDigest,
            matchesHex: artifact.statementDigestHex,
            kind: proofKind,
            label: "product-statement"
        ) {
            throw SuperNeoError.verificationFailed("NumiSeal product source statement digest mismatch")
        }
        try Self.requireBoundDigest(key.verifierKeyDigest, matchesHex: artifact.verifierKeyDigestHex, kind: proofKind, label: "verifier-key") {
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
        try Self.requireBoundDigestList(
            outputDigests,
            matchesHex: artifact.sourceFoldOutputClaimDigestsHex,
            kind: .foldReduction,
            label: "source-fold-output-claims"
        ) {
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
        try Self.requireBoundDigest(publicProof.publicStatement.digest, matchesHex: artifact.publicStatementDigestHex, kind: proofKind, label: "public-statement") {
            throw SuperNeoError.verificationFailed("NumiSeal product public statement digest mismatch")
        }
        try Self.requireBoundDigest(publicProof.publicStatement.obligationRoot, matchesHex: artifact.obligationRootHex, kind: proofKind, label: "obligation-root") {
            throw SuperNeoError.verificationFailed("NumiSeal product obligation root mismatch")
        }
        try Self.requireBoundDigest(publicProof.publicStatement.laneSummaryRoot, matchesHex: artifact.laneSummaryRootHex, kind: proofKind, label: "lane-summary-root") {
            throw SuperNeoError.verificationFailed("NumiSeal product lane summary root mismatch")
        }
        try Self.requireBoundDigestList(publicProof.laneProofs.map(\.aggregateDigest), matchesHex: artifact.aggregateDigestsHex, kind: proofKind, label: "aggregate-digests") {
            throw SuperNeoError.verificationFailed("NumiSeal product aggregate digest mismatch")
        }
        try Self.requireBoundDigest(componentDigestRoot, matchesHex: artifact.componentDigestRootHex, kind: proofKind, label: "component-root") {
            throw SuperNeoError.verificationFailed("NumiSeal product component root mismatch")
        }
        try Self.requireBoundDigest(proofTranscriptDigest, matchesHex: artifact.proofTranscriptDigestHex, kind: proofKind, label: "proof-transcript") {
            throw SuperNeoError.verificationFailed("NumiSeal product transcript digest mismatch")
        }
        try Self.validateRecursiveCarryBindings(
            artifact: artifact,
            proof: publicProof,
            acceptedCarryMode: acceptedCarryMode,
            recursiveCarryParent: recursiveCarryParent
        )
        return NumiSealProductVerificationResult(
            sourceFoldResult: sourceResult,
            numiSealResult: numiSealResult
        )
    }

    @inline(never)
    private static func validateRecursiveCarryBindings(
        artifact: NumiSealProductArtifact,
        proof: NumiSealProof,
        acceptedCarryMode: NumiSealCarryMode,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent?
    ) throws {
        guard acceptedCarryMode == .typedRequired else {
            if NumiSealProductRecursiveCarryMetadata.keys.contains(where: {
                artifact.executionPolicyMetadata[$0] != nil
            }) {
                throw SuperNeoError.invalidEncoding(
                    "NumiSeal recursive carry metadata requires typed-required carry mode"
                )
            }
            return
        }
        guard let recursiveCarryParent else {
            throw SuperNeoError.verificationFailed(
                "NumiSeal typed-required product carry requires recursive carry parent context"
            )
        }
        try validateRecursiveCarryParentMetadata(
            artifact: artifact,
            parent: recursiveCarryParent
        )
        guard let rawClaimCount = artifact.executionPolicyMetadata[NumiSealProductRecursiveCarryMetadata.claimCount],
              let expectedClaimCount = Int(rawClaimCount),
              expectedClaimCount == proof.laneProofs.count else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry claim count mismatch")
        }

        var consumer = NumiSealCarryConsumer()
        var contextDigests: [Digest256] = []
        var replayIdentities: [Digest256] = []
        for laneProof in proof.laneProofs {
            guard let statement = laneProof.optionalCarryClaim?.typedStatement else {
                throw SuperNeoError.verificationFailed("NumiSeal typed carry claim required by policy")
            }
            guard statement.laneKey.laneID == laneProof.laneKey.laneID,
                  statement.aggregateIndex == laneProof.aggregateIndex else {
                throw SuperNeoError.verificationFailed("NumiSeal recursive carry statement target mismatch")
            }
            let parentLaneProof = try recursiveCarryParent.laneProof(
                laneKey: statement.laneKey,
                aggregateIndex: laneProof.aggregateIndex
            )
            let carryContext = try recursiveCarryParent.context(for: parentLaneProof)
            let accepted = try consumer.consume(
                statement,
                parentProofAccepted: true,
                expectedProducerProofEnvelopeDigest: recursiveCarryParent.parentProducerProofEnvelopeDigest,
                expectedProducerProofTranscriptDigest: recursiveCarryParent.acceptedProducerEnvelope.proof.transcriptDigest,
                expectedParentStatementDigest: recursiveCarryParent.acceptedProducerEnvelope.header.statementDigest,
                expectedParentPublicStatementDigest: recursiveCarryParent.parentPublicStatementDigest,
                expectedConsumerContextDigest: carryContext.contextDigest,
                minimumNextRecursionLevel: recursiveCarryParent.nextRecursionLevel
            )
            contextDigests.append(carryContext.contextDigest)
            replayIdentities.append(accepted.replayIdentity)
        }
        let contextRoot = NumiSealProductRecursiveCarryMetadata.digestRoot(
            label: "numiseal.product-carry.context-root.v1",
            digests: contextDigests
        )
        let replayRoot = NumiSealProductRecursiveCarryMetadata.digestRoot(
            label: "numiseal.product-carry.replay-root.v1",
            digests: replayIdentities
        )
        guard artifact.executionPolicyMetadata[NumiSealProductRecursiveCarryMetadata.contextRoot] == contextRoot.hexString else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry context root mismatch")
        }
        guard artifact.executionPolicyMetadata[NumiSealProductRecursiveCarryMetadata.replayRoot] == replayRoot.hexString else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry replay root mismatch")
        }
    }

    private static func boundDigest(_ digest: Digest256, kind: ProofEnvelopeKind, label: String) -> Digest384 {
        SuperNeoTheoremBinding.digestBinder(kind: kind, label: label, digest: digest)
    }

    private static func boundDigestList(_ digests: [Digest256], kind: ProofEnvelopeKind, label: String) -> Digest384 {
        SuperNeoTheoremBinding.digestListBinder(kind: kind, label: label, digests: digests)
    }

    private static func requireBoundDigest(
        _ actual: Digest256,
        matchesHex expectedHex: String,
        kind: ProofEnvelopeKind,
        label: String,
        onMismatch: () throws -> Never
    ) throws {
        let expected = try Digest256(hexDigest: expectedHex, name: "NumiSeal product \(label)")
        guard boundDigest(actual, kind: kind, label: label) == boundDigest(expected, kind: kind, label: label) else {
            try onMismatch()
        }
    }

    private static func requireBoundDigestList(
        _ actual: [Digest256],
        matchesHex expectedHex: [String],
        kind: ProofEnvelopeKind,
        label: String,
        onMismatch: () throws -> Never
    ) throws {
        let expected = try expectedHex.map { try Digest256(hexDigest: $0, name: "NumiSeal product \(label)") }
        guard boundDigestList(actual, kind: kind, label: label) == boundDigestList(expected, kind: kind, label: label) else {
            try onMismatch()
        }
    }

    @inline(never)
    private static func validateRecursiveCarryParentMetadata(
        artifact: NumiSealProductArtifact,
        parent: NumiSealProductRecursiveCarryParent
    ) throws {
        let metadata = artifact.executionPolicyMetadata
        guard metadata[NumiSealProductRecursiveCarryMetadata.parentArtifactDigest] == parent.parentProductArtifactDigest.hexString,
              metadata[NumiSealProductRecursiveCarryMetadata.parentSourceFoldEnvelopeDigest] == parent.parentSourceFoldEnvelopeDigest.hexString,
              metadata[NumiSealProductRecursiveCarryMetadata.parentProductProofEnvelopeDigest] == parent.parentProductProofEnvelopeDigest.hexString,
              metadata[NumiSealProductRecursiveCarryMetadata.parentProducerProofEnvelopeDigest] == parent.parentProducerProofEnvelopeDigest.hexString,
              metadata[NumiSealProductRecursiveCarryMetadata.parentPublicStatementDigest] == parent.parentPublicStatementDigest.hexString,
              metadata[NumiSealProductRecursiveCarryMetadata.consumerSessionDigest] == parent.consumerSessionDigest.hexString,
              metadata[NumiSealProductRecursiveCarryMetadata.nextRecursionLevel] == "\(parent.nextRecursionLevel)" else {
            throw SuperNeoError.verificationFailed("NumiSeal recursive carry parent metadata mismatch")
        }
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
        switch acceptedCarryMode {
        case .typedRequired:
            try validateRecursiveCarryMetadata(artifact.executionPolicyMetadata)
        case .none, .typedOptional:
            guard !NumiSealProductRecursiveCarryMetadata.keys.contains(where: {
                artifact.executionPolicyMetadata[$0] != nil
            }) else {
                throw SuperNeoError.invalidEncoding(
                    "NumiSeal recursive carry metadata requires typed-required carry mode"
                )
            }
        case .optional, .required:
            throw SuperNeoError.invalidEncoding("unsupported NumiSeal product carry mode")
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
        try NumiSealProductTheoremLimits.validate(artifact: artifact)
        try validateCTCOMetadata(artifact)
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

    private static func validateCTCOMetadata(_ artifact: NumiSealProductArtifact) throws {
        let expected = try ctcoEvidence(for: artifact)
        let sourceEnvelopeCTCO = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: artifact.sourceFoldEnvelopeBytes())
        let proofEnvelopeCTCO = try ProofEnvelopeCTCOVerifier.verify(envelopeBytes: artifact.proofEnvelopeBytes())
        let metadata = artifact.executionPolicyMetadata
        guard metadata["ctcoCompilerFamily"] == "ctco" else {
            throw SuperNeoError.invalidEncoding("NumiSeal product CTCO compiler metadata mismatch")
        }
        let contextBinder = try Digest384(
            hexDigest: requiredMetadata(metadata, "ctcoContextBinder384Hex"),
            name: "NumiSeal product CTCO context binder"
        )
        guard contextBinder == expected.contextBinder else {
            throw SuperNeoError.invalidEncoding("NumiSeal product CTCO context binder mismatch")
        }
        let root = try Digest384(
            hexDigest: requiredMetadata(metadata, "ctcoRoot384Hex"),
            name: "NumiSeal product CTCO root"
        )
        guard root == expected.root else {
            throw SuperNeoError.invalidEncoding("NumiSeal product CTCO root mismatch")
        }
        let challengeSeed = try Digest256(
            hexDigest: requiredMetadata(metadata, "ctcoChallengeTapeSeedHex"),
            name: "NumiSeal product CTCO challenge seed"
        )
        guard challengeSeed == expected.challengeTapeSeed else {
            throw SuperNeoError.invalidEncoding("NumiSeal product CTCO challenge seed mismatch")
        }
        let sourceRoot = try Digest384(
            hexDigest: requiredMetadata(metadata, "sourceFoldCTCORoot384Hex"),
            name: "NumiSeal product source-fold CTCO root"
        )
        guard sourceRoot == sourceEnvelopeCTCO.root else {
            throw SuperNeoError.invalidEncoding("NumiSeal product source-fold CTCO root mismatch")
        }
        let sourceSeed = try Digest256(
            hexDigest: requiredMetadata(metadata, "sourceFoldCTCOChallengeTapeSeedHex"),
            name: "NumiSeal product source-fold CTCO challenge seed"
        )
        guard sourceSeed == sourceEnvelopeCTCO.challengeTapeSeed else {
            throw SuperNeoError.invalidEncoding("NumiSeal product source-fold CTCO challenge seed mismatch")
        }
        let proofRoot = try Digest384(
            hexDigest: requiredMetadata(metadata, "proofEnvelopeCTCORoot384Hex"),
            name: "NumiSeal product proof-envelope CTCO root"
        )
        guard proofRoot == proofEnvelopeCTCO.root else {
            throw SuperNeoError.invalidEncoding("NumiSeal product proof-envelope CTCO root mismatch")
        }
        let proofSeed = try Digest256(
            hexDigest: requiredMetadata(metadata, "proofEnvelopeCTCOChallengeTapeSeedHex"),
            name: "NumiSeal product proof-envelope CTCO challenge seed"
        )
        guard proofSeed == proofEnvelopeCTCO.challengeTapeSeed else {
            throw SuperNeoError.invalidEncoding("NumiSeal product proof-envelope CTCO challenge seed mismatch")
        }
        guard metadata["qromChallengeOracleBits"] == "\(Digest256.byteCount * 8)",
              metadata["qromBindingOracleBits"] == "\(Digest384.byteCount * 8)",
              metadata["qromBindingTargetEventCount"] == "9",
              metadata["qromQueryCapLog2"] == "64" else {
            throw SuperNeoError.invalidEncoding("NumiSeal product QROM width metadata mismatch")
        }
        let qromEvidenceDigest = try Digest256(
            hexDigest: requiredMetadata(metadata, "qromEvidenceDigest"),
            name: "NumiSeal product QROM evidence digest"
        )
        guard SuperNeoTheoremBinding.digestBinder(
            kind: expected.proofKind,
            label: "qrom-evidence-digest",
            digest: qromEvidenceDigest
        ) == SuperNeoTheoremBinding.digestBinder(
            kind: expected.proofKind,
            label: "qrom-evidence-digest",
            digest: expected.qromEvidenceDigest
        ) else {
            throw SuperNeoError.invalidEncoding("NumiSeal product QROM evidence digest mismatch")
        }
    }

    private static func ctcoEvidence(
        for artifact: NumiSealProductArtifact
    ) throws -> (
        proofKind: ProofEnvelopeKind,
        contextBinder: Digest384,
        root: Digest384,
        challengeTapeSeed: Digest256,
        qromEvidenceDigest: Digest256
    ) {
        let proofBytes = try artifact.proofEnvelopeBytes()
        let proofHeader = try ProofEnvelopeHeader.parsePrefix(from: proofBytes)
        let frontendContext = try productTrustedContext(from: artifact)
        let traceBlocks = try NumiSealProductTraceExtractorEvidence.ctcoTraceBlocks(
            frontendContextDigest: frontendContext.contextDigest,
            sourceFoldEnvelopeDigest: Digest256(
                hexDigest: artifact.sourceFoldEnvelopeDigestHex,
                name: "NumiSeal product CTCO source fold envelope digest"
            ),
            sourceFoldOutputClaimDigests: artifact.sourceFoldOutputClaimDigestsHex.map {
                try Digest256(hexDigest: $0, name: "NumiSeal product CTCO source output claim digest")
            },
            proofEnvelopeDigest: Digest256(
                hexDigest: artifact.proofEnvelopeDigestHex,
                name: "NumiSeal product CTCO proof envelope digest"
            ),
            publicStatementDigest: Digest256(
                hexDigest: artifact.publicStatementDigestHex,
                name: "NumiSeal product CTCO public statement digest"
            ),
            obligationRoot: Digest256(
                hexDigest: artifact.obligationRootHex,
                name: "NumiSeal product CTCO obligation root"
            ),
            laneSummaryRoot: Digest256(
                hexDigest: artifact.laneSummaryRootHex,
                name: "NumiSeal product CTCO lane summary root"
            ),
            aggregateDigests: artifact.aggregateDigestsHex.map {
                try Digest256(hexDigest: $0, name: "NumiSeal product CTCO aggregate digest")
            },
            componentDigestRoot: Digest256(
                hexDigest: artifact.componentDigestRootHex,
                name: "NumiSeal product CTCO component root"
            ),
            proofTranscriptDigest: Digest256(
                hexDigest: artifact.proofTranscriptDigestHex,
                name: "NumiSeal product CTCO proof transcript digest"
            )
        )
        let commitment = CTCOMoveOneCommitment(
            proofKind: proofHeader.kind,
            contextBinder: proofHeader.ctcoContextBinder,
            traceBlocks: traceBlocks
        )
        let challengeSeed = SuperNeoSplitQRO.challengeTapeSeed(
            proofKind: proofHeader.kind,
            contextBinder: proofHeader.ctcoContextBinder,
            root: commitment.root,
            label: "numiseal-product-api-trace"
        )
        let traceEvidenceDigest = NumiSealProductTraceExtractorEvidence.evidenceDigest(
            traceBlocks: traceBlocks,
            contextBinder: proofHeader.ctcoContextBinder,
            ctcoRoot: commitment.root,
            challengeTapeSeed: challengeSeed
        )
        let qromEvidenceDigest = NumiSealProductQROMEvidence.ctcoDigest(
            contextBinder: proofHeader.ctcoContextBinder,
            root: commitment.root,
            challengeTapeSeed: challengeSeed,
            traceEvidenceDigest: traceEvidenceDigest
        )
        return (
            proofHeader.kind,
            proofHeader.ctcoContextBinder,
            commitment.root,
            challengeSeed,
            qromEvidenceDigest
        )
    }

    private static func productTrustedContext(from artifact: NumiSealProductArtifact) throws -> NumiSealProductTrustedContext {
        guard let laneIDValue = artifact.laneIDsUTF8.first, artifact.laneIDsUTF8.count == 1 else {
            throw SuperNeoError.invalidEncoding("NumiSeal product CTCO metadata requires exactly one lane id")
        }
        return try NumiSealProductTrustedContext(
            workload: artifact.workload,
            bitCount: artifact.bitCount,
            publicInputs: artifact.publicInputs,
            workloadParameters: artifact.workloadParameters,
            sourceApplicationPathUTF8: artifact.sourceApplicationPathUTF8 ?? "unbound",
            laneID: NumiSealLaneID(laneIDValue)
        )
    }

    private static func requiredMetadata(_ metadata: [String: String], _ key: String) throws -> String {
        guard let value = metadata[key], !value.isEmpty else {
            throw SuperNeoError.invalidEncoding("NumiSeal product CTCO metadata is incomplete")
        }
        return value
    }

    private static func validateRecursiveCarryMetadata(_ metadata: [String: String]) throws {
        for key in NumiSealProductRecursiveCarryMetadata.keys {
            guard let value = metadata[key], !value.isEmpty else {
                throw SuperNeoError.invalidEncoding("NumiSeal recursive carry metadata is incomplete")
            }
        }
        for key in [
            NumiSealProductRecursiveCarryMetadata.parentArtifactDigest,
            NumiSealProductRecursiveCarryMetadata.parentSourceFoldEnvelopeDigest,
            NumiSealProductRecursiveCarryMetadata.parentProductProofEnvelopeDigest,
            NumiSealProductRecursiveCarryMetadata.parentProducerProofEnvelopeDigest,
            NumiSealProductRecursiveCarryMetadata.parentPublicStatementDigest,
            NumiSealProductRecursiveCarryMetadata.consumerSessionDigest,
            NumiSealProductRecursiveCarryMetadata.contextRoot,
            NumiSealProductRecursiveCarryMetadata.replayRoot
        ] {
            _ = try Digest256(hexDigest: metadata[key] ?? "", name: "NumiSeal recursive carry metadata \(key)")
        }
        guard let rawNextLevel = metadata[NumiSealProductRecursiveCarryMetadata.nextRecursionLevel],
              let nextLevel = Int(rawNextLevel),
              nextLevel > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry next recursion level is invalid")
        }
        guard let rawClaimCount = metadata[NumiSealProductRecursiveCarryMetadata.claimCount],
              let claimCount = Int(rawClaimCount),
              claimCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal recursive carry claim count is invalid")
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
        zkMode: String = NumiSealZK.nonZKMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        recursiveCarryParent: NumiSealProductRecursiveCarryParent? = nil
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
                zkMode: zkMode,
                aggregationLimits: aggregationLimits,
                parameters: parameters,
                metalContext: metalContext,
                recursiveCarryParent: recursiveCarryParent
            )
        )
    }
}
