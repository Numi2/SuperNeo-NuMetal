import Foundation

public struct NumiSealBoundedRecursiveStepRequest: Sendable {
    public let preparedR1CS: SuperNeoPreparedR1CS
    public let trustedContext: NumiSealProductTrustedContext
    public let qroChallenge: SuperNeoQROChallenge
    public let keySeedUTF8: String?
    public let executionPolicy: NumiSealProvingExecutionPolicy
    public let zkMode: String
    public let aggregationLimits: NumiSealAggregationLimits
    public let parameters: SuperNeoParameters
    public let metalContext: MetalExecutionContext?
    public let sourceDecompositionProfile: SuperNeoDecompositionProfile
    public let nextConsumerSessionDigest: Digest256?

    public init(
        preparedR1CS: SuperNeoPreparedR1CS,
        trustedContext: NumiSealProductTrustedContext,
        qroChallenge: SuperNeoQROChallenge,
        keySeedUTF8: String? = nil,
        executionPolicy: NumiSealProvingExecutionPolicy = .defaultProduct,
        zkMode: String = NumiSealZK.maskedDigitTensorMode,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        parameters: SuperNeoParameters = .goldilocks,
        metalContext: MetalExecutionContext? = nil,
        sourceDecompositionProfile: SuperNeoDecompositionProfile = .payPerBit,
        nextConsumerSessionDigest: Digest256? = nil
    ) {
        self.preparedR1CS = preparedR1CS
        self.trustedContext = trustedContext
        self.qroChallenge = qroChallenge
        self.keySeedUTF8 = keySeedUTF8
        self.executionPolicy = executionPolicy
        self.zkMode = zkMode
        self.aggregationLimits = aggregationLimits
        self.parameters = parameters
        self.metalContext = metalContext
        self.sourceDecompositionProfile = sourceDecompositionProfile
        self.nextConsumerSessionDigest = nextConsumerSessionDigest
    }
}

public struct NumiSealBoundedRecursiveStepResult: Sendable {
    public let depth: Int
    public let provingOutput: NumiSealProductProvingOutput
    public let verificationResult: NumiSealProductVerificationResult
    public let artifactDigest: Digest256
    public let productCarryChainRoot: Digest256
    public let recursiveCarryChainRoot: Digest256?
    public let traceExtractorEvidenceDigest: Digest256
    public let qromEvidenceDigest: Digest256
}

public struct NumiSealBoundedRecursiveAccounting: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.bounded-recursive-accounting.v1")

    public let theoremID: String
    public let selectedDepth: Int
    public let requestedDepth: Int
    public let finalCarryChainRoot: Digest256
    public let stepArtifactDigests: [Digest256]
    public let stepProductCarryChainRoots: [Digest256]
    public let stepTraceExtractorEvidenceDigests: [Digest256]
    public let stepQromEvidenceDigests: [Digest256]
    public let accountingDigest: Digest256

    public init(
        requestedDepth: Int,
        finalCarryChainRoot: Digest256,
        stepArtifactDigests: [Digest256],
        stepProductCarryChainRoots: [Digest256],
        stepTraceExtractorEvidenceDigests: [Digest256],
        stepQromEvidenceDigests: [Digest256]
    ) throws {
        guard requestedDepth > 0 else {
            throw SuperNeoError.invalidParameter("bounded recursive accounting requires positive depth")
        }
        guard requestedDepth <= NumiSealProductTheoremLimits.selectedDepth else {
            throw SuperNeoError.invalidParameter("bounded recursive accounting exceeds selected theorem depth")
        }
        guard stepArtifactDigests.count == requestedDepth,
              stepProductCarryChainRoots.count == requestedDepth,
              stepTraceExtractorEvidenceDigests.count == requestedDepth,
              stepQromEvidenceDigests.count == requestedDepth else {
            throw SuperNeoError.invalidParameter("bounded recursive accounting step digest count mismatch")
        }
        self.theoremID = NumiSealProductTheoremLimits.theoremID
        self.selectedDepth = NumiSealProductTheoremLimits.selectedDepth
        self.requestedDepth = requestedDepth
        self.finalCarryChainRoot = finalCarryChainRoot
        self.stepArtifactDigests = stepArtifactDigests
        self.stepProductCarryChainRoots = stepProductCarryChainRoots
        self.stepTraceExtractorEvidenceDigests = stepTraceExtractorEvidenceDigests
        self.stepQromEvidenceDigests = stepQromEvidenceDigests
        self.accountingDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    theoremID: NumiSealProductTheoremLimits.theoremID,
                    selectedDepth: NumiSealProductTheoremLimits.selectedDepth,
                    requestedDepth: requestedDepth,
                    finalCarryChainRoot: finalCarryChainRoot,
                    stepArtifactDigests: stepArtifactDigests,
                    stepProductCarryChainRoots: stepProductCarryChainRoots,
                    stepTraceExtractorEvidenceDigests: stepTraceExtractorEvidenceDigests,
                    stepQromEvidenceDigests: stepQromEvidenceDigests
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                theoremID: theoremID,
                selectedDepth: selectedDepth,
                requestedDepth: requestedDepth,
                finalCarryChainRoot: finalCarryChainRoot,
                stepArtifactDigests: stepArtifactDigests,
                stepProductCarryChainRoots: stepProductCarryChainRoots,
                stepTraceExtractorEvidenceDigests: stepTraceExtractorEvidenceDigests,
                stepQromEvidenceDigests: stepQromEvidenceDigests
            )
            + accountingDigest.superNeoBytes
    }

    private static func bodyBytes(
        theoremID: String,
        selectedDepth: Int,
        requestedDepth: Int,
        finalCarryChainRoot: Digest256,
        stepArtifactDigests: [Digest256],
        stepProductCarryChainRoots: [Digest256],
        stepTraceExtractorEvidenceDigests: [Digest256],
        stepQromEvidenceDigests: [Digest256]
    ) -> [UInt8] {
        numiSealEncodeString(theoremID)
            + numiSealEncodeCount(selectedDepth)
            + numiSealEncodeCount(requestedDepth)
            + finalCarryChainRoot.superNeoBytes
            + numiSealEncodeCount(stepArtifactDigests.count)
            + stepArtifactDigests.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(stepProductCarryChainRoots.count)
            + stepProductCarryChainRoots.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(stepTraceExtractorEvidenceDigests.count)
            + stepTraceExtractorEvidenceDigests.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(stepQromEvidenceDigests.count)
            + stepQromEvidenceDigests.flatMap(\.superNeoBytes)
    }
}

public struct NumiSealBoundedRecursiveRun: Sendable {
    public let maximumDepth: Int
    public let steps: [NumiSealBoundedRecursiveStepResult]
    public let accounting: NumiSealBoundedRecursiveAccounting

    public var finalStep: NumiSealBoundedRecursiveStepResult? {
        steps.last
    }
}

public struct NumiSealBoundedPCDNodeRequest: Sendable {
    public let step: NumiSealBoundedRecursiveStepRequest
    public let parentNodeIndices: [Int]
    public let primaryCarryParentIndex: Int?

    public init(
        step: NumiSealBoundedRecursiveStepRequest,
        parentNodeIndices: [Int] = [],
        primaryCarryParentIndex: Int? = nil
    ) {
        self.step = step
        self.parentNodeIndices = parentNodeIndices
        self.primaryCarryParentIndex = primaryCarryParentIndex
    }
}

public struct NumiSealBoundedPCDParentSetBinding: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.bounded-pcd.parent-set.v1")

    public let nodeIndex: Int
    public let parentNodeIndices: [Int]
    public let primaryCarryParentIndex: Int?
    public let parentArtifactDigests: [Digest256]
    public let parentCarryChainRoots: [Digest256]
    public let parentTraceExtractorEvidenceDigests: [Digest256]
    public let parentQromEvidenceDigests: [Digest256]
    public let parentSetRoot: Digest256

    public init(
        nodeIndex: Int,
        parentNodeIndices: [Int],
        primaryCarryParentIndex: Int?,
        parentArtifactDigests: [Digest256],
        parentCarryChainRoots: [Digest256],
        parentTraceExtractorEvidenceDigests: [Digest256],
        parentQromEvidenceDigests: [Digest256]
    ) throws {
        guard nodeIndex >= 0 else {
            throw SuperNeoError.invalidParameter("bounded PCD node index must be non-negative")
        }
        guard parentNodeIndices.count == Set(parentNodeIndices).count else {
            throw SuperNeoError.invalidParameter("bounded PCD parent indices must be unique")
        }
        guard parentArtifactDigests.count == parentNodeIndices.count,
              parentCarryChainRoots.count == parentNodeIndices.count,
              parentTraceExtractorEvidenceDigests.count == parentNodeIndices.count,
              parentQromEvidenceDigests.count == parentNodeIndices.count else {
            throw SuperNeoError.invalidParameter("bounded PCD parent binding digest count mismatch")
        }
        if let primaryCarryParentIndex {
            guard parentNodeIndices.contains(primaryCarryParentIndex) else {
                throw SuperNeoError.invalidParameter("bounded PCD primary carry parent must be in the parent set")
            }
        }
        self.nodeIndex = nodeIndex
        self.parentNodeIndices = parentNodeIndices
        self.primaryCarryParentIndex = primaryCarryParentIndex
        self.parentArtifactDigests = parentArtifactDigests
        self.parentCarryChainRoots = parentCarryChainRoots
        self.parentTraceExtractorEvidenceDigests = parentTraceExtractorEvidenceDigests
        self.parentQromEvidenceDigests = parentQromEvidenceDigests
        self.parentSetRoot = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    nodeIndex: nodeIndex,
                    parentNodeIndices: parentNodeIndices,
                    primaryCarryParentIndex: primaryCarryParentIndex,
                    parentArtifactDigests: parentArtifactDigests,
                    parentCarryChainRoots: parentCarryChainRoots,
                    parentTraceExtractorEvidenceDigests: parentTraceExtractorEvidenceDigests,
                    parentQromEvidenceDigests: parentQromEvidenceDigests
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                nodeIndex: nodeIndex,
                parentNodeIndices: parentNodeIndices,
                primaryCarryParentIndex: primaryCarryParentIndex,
                parentArtifactDigests: parentArtifactDigests,
                parentCarryChainRoots: parentCarryChainRoots,
                parentTraceExtractorEvidenceDigests: parentTraceExtractorEvidenceDigests,
                parentQromEvidenceDigests: parentQromEvidenceDigests
            )
            + parentSetRoot.superNeoBytes
    }

    private static func bodyBytes(
        nodeIndex: Int,
        parentNodeIndices: [Int],
        primaryCarryParentIndex: Int?,
        parentArtifactDigests: [Digest256],
        parentCarryChainRoots: [Digest256],
        parentTraceExtractorEvidenceDigests: [Digest256],
        parentQromEvidenceDigests: [Digest256]
    ) -> [UInt8] {
        numiSealEncodeCount(nodeIndex)
            + numiSealEncodeCount(parentNodeIndices.count)
            + parentNodeIndices.flatMap(numiSealEncodeCount)
            + [primaryCarryParentIndex == nil ? 0 : 1]
            + numiSealEncodeCount(primaryCarryParentIndex ?? 0)
            + numiSealEncodeCount(parentArtifactDigests.count)
            + parentArtifactDigests.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(parentCarryChainRoots.count)
            + parentCarryChainRoots.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(parentTraceExtractorEvidenceDigests.count)
            + parentTraceExtractorEvidenceDigests.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(parentQromEvidenceDigests.count)
            + parentQromEvidenceDigests.flatMap(\.superNeoBytes)
    }
}

public struct NumiSealBoundedPCDNodeResult: Sendable {
    public let nodeIndex: Int
    public let parentSetBinding: NumiSealBoundedPCDParentSetBinding?
    public let step: NumiSealBoundedRecursiveStepResult
}

public struct NumiSealBoundedPCDAccounting: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.numiseal.bounded-pcd-accounting.v1")

    public let theoremID: String
    public let selectedDepth: Int
    public let maximumDepth: Int
    public let nodeCount: Int
    public let terminalNodeIndices: [Int]
    public let finalPCDRoot: Digest256
    public let nodeArtifactDigests: [Digest256]
    public let nodeCarryChainRoots: [Digest256]
    public let nodeParentSetRoots: [Digest256]
    public let accountingDigest: Digest256

    public init(
        maximumDepth: Int,
        nodeResults: [NumiSealBoundedPCDNodeResult]
    ) throws {
        guard maximumDepth > 0, maximumDepth <= NumiSealProductTheoremLimits.selectedDepth else {
            throw SuperNeoError.invalidParameter("bounded PCD accounting exceeds selected theorem depth")
        }
        guard !nodeResults.isEmpty else {
            throw SuperNeoError.invalidParameter("bounded PCD accounting requires at least one node")
        }
        let parentIndices = Set(nodeResults.flatMap { $0.parentSetBinding?.parentNodeIndices ?? [] })
        let terminalIndices = nodeResults.map(\.nodeIndex).filter { !parentIndices.contains($0) }
        let finalRoot = Digest256.hash(
            SuperNeoSplitQRO.framedBytes(
                domain: "superneo/numiseal/bounded-pcd/final-root/v1",
                frames: terminalIndices.map(numiSealEncodeCount)
                    + nodeResults
                    .filter { terminalIndices.contains($0.nodeIndex) }
                    .map { $0.step.productCarryChainRoot.superNeoBytes }
            )
        )
        let artifactDigests = nodeResults.map(\.step.artifactDigest)
        let carryRoots = nodeResults.map(\.step.productCarryChainRoot)
        let parentSetRoots = nodeResults.map {
            $0.parentSetBinding?.parentSetRoot ?? Digest256.hash("bounded-pcd/root-node/\($0.nodeIndex)")
        }
        self.theoremID = NumiSealProductTheoremLimits.theoremID
        self.selectedDepth = NumiSealProductTheoremLimits.selectedDepth
        self.maximumDepth = maximumDepth
        self.nodeCount = nodeResults.count
        self.terminalNodeIndices = terminalIndices
        self.finalPCDRoot = finalRoot
        self.nodeArtifactDigests = artifactDigests
        self.nodeCarryChainRoots = carryRoots
        self.nodeParentSetRoots = parentSetRoots
        self.accountingDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    theoremID: NumiSealProductTheoremLimits.theoremID,
                    selectedDepth: NumiSealProductTheoremLimits.selectedDepth,
                    maximumDepth: maximumDepth,
                    nodeCount: nodeResults.count,
                    terminalNodeIndices: terminalIndices,
                    finalPCDRoot: finalRoot,
                    nodeArtifactDigests: artifactDigests,
                    nodeCarryChainRoots: carryRoots,
                    nodeParentSetRoots: parentSetRoots
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                theoremID: theoremID,
                selectedDepth: selectedDepth,
                maximumDepth: maximumDepth,
                nodeCount: nodeCount,
                terminalNodeIndices: terminalNodeIndices,
                finalPCDRoot: finalPCDRoot,
                nodeArtifactDigests: nodeArtifactDigests,
                nodeCarryChainRoots: nodeCarryChainRoots,
                nodeParentSetRoots: nodeParentSetRoots
            )
            + accountingDigest.superNeoBytes
    }

    private static func bodyBytes(
        theoremID: String,
        selectedDepth: Int,
        maximumDepth: Int,
        nodeCount: Int,
        terminalNodeIndices: [Int],
        finalPCDRoot: Digest256,
        nodeArtifactDigests: [Digest256],
        nodeCarryChainRoots: [Digest256],
        nodeParentSetRoots: [Digest256]
    ) -> [UInt8] {
        numiSealEncodeString(theoremID)
            + numiSealEncodeCount(selectedDepth)
            + numiSealEncodeCount(maximumDepth)
            + numiSealEncodeCount(nodeCount)
            + numiSealEncodeCount(terminalNodeIndices.count)
            + terminalNodeIndices.flatMap(numiSealEncodeCount)
            + finalPCDRoot.superNeoBytes
            + numiSealEncodeCount(nodeArtifactDigests.count)
            + nodeArtifactDigests.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(nodeCarryChainRoots.count)
            + nodeCarryChainRoots.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(nodeParentSetRoots.count)
            + nodeParentSetRoots.flatMap(\.superNeoBytes)
    }
}

public struct NumiSealBoundedPCDRun: Sendable {
    public let maximumDepth: Int
    public let maximumFanIn: Int
    public let nodes: [NumiSealBoundedPCDNodeResult]
    public let accounting: NumiSealBoundedPCDAccounting
}

public enum NumiSealBoundedRecursiveDriver {
    public static func proveAndVerify(
        requests: [NumiSealBoundedRecursiveStepRequest],
        maximumDepth: Int = NumiSealProductTheoremLimits.selectedDepth,
        verifier: NumiSealProductVerifier = NumiSealProductVerifier()
    ) throws -> NumiSealBoundedRecursiveRun {
        guard !requests.isEmpty else {
            throw SuperNeoError.invalidParameter("bounded recursive driver requires at least one step")
        }
        guard maximumDepth > 0, maximumDepth <= NumiSealProductTheoremLimits.selectedDepth else {
            throw SuperNeoError.invalidParameter("bounded recursive driver maximum depth exceeds selected theorem depth")
        }
        guard requests.count <= maximumDepth else {
            throw SuperNeoError.invalidParameter("bounded recursive driver request count exceeds maximum depth")
        }

        var parent: NumiSealProductRecursiveCarryParent?
        var stepResults: [NumiSealBoundedRecursiveStepResult] = []
        stepResults.reserveCapacity(requests.count)

        for (index, request) in requests.enumerated() {
            let step = try proveAndVerifyStep(
                request: request,
                depth: index + 1,
                recursiveCarryParent: parent,
                verifier: verifier
            )
            stepResults.append(step)

            if index + 1 < requests.count {
                parent = try NumiSealProductRecursiveCarryParent(
                    artifact: step.provingOutput.artifact,
                    verificationResult: step.verificationResult,
                    consumerSessionDigest: request.nextConsumerSessionDigest
                        ?? defaultConsumerSessionDigest(
                            stepIndex: index,
                            artifactDigest: step.artifactDigest,
                            productCarryChainRoot: step.productCarryChainRoot
                        ),
                    nextRecursionLevel: index + 1
                )
            }
        }

        guard let finalRoot = stepResults.last?.productCarryChainRoot else {
            throw SuperNeoError.invalidParameter("bounded recursive driver produced no final root")
        }
        let accounting = try NumiSealBoundedRecursiveAccounting(
            requestedDepth: stepResults.count,
            finalCarryChainRoot: finalRoot,
            stepArtifactDigests: stepResults.map(\.artifactDigest),
            stepProductCarryChainRoots: stepResults.map(\.productCarryChainRoot),
            stepTraceExtractorEvidenceDigests: stepResults.map(\.traceExtractorEvidenceDigest),
            stepQromEvidenceDigests: stepResults.map(\.qromEvidenceDigest)
        )
        return NumiSealBoundedRecursiveRun(
            maximumDepth: maximumDepth,
            steps: stepResults,
            accounting: accounting
        )
    }

    public static func proveAndVerifyPCD(
        requests: [NumiSealBoundedPCDNodeRequest],
        maximumDepth: Int = NumiSealProductTheoremLimits.selectedDepth,
        maximumFanIn: Int = 2,
        verifier: NumiSealProductVerifier = NumiSealProductVerifier()
    ) throws -> NumiSealBoundedPCDRun {
        guard !requests.isEmpty else {
            throw SuperNeoError.invalidParameter("bounded PCD driver requires at least one node")
        }
        guard maximumDepth > 0, maximumDepth <= NumiSealProductTheoremLimits.selectedDepth else {
            throw SuperNeoError.invalidParameter("bounded PCD driver maximum depth exceeds selected theorem depth")
        }
        guard maximumFanIn > 0 else {
            throw SuperNeoError.invalidParameter("bounded PCD driver maximum fan-in must be positive")
        }

        var nodeResults: [NumiSealBoundedPCDNodeResult] = []
        nodeResults.reserveCapacity(requests.count)

        for (nodeIndex, nodeRequest) in requests.enumerated() {
            let parents = try validatePCDParents(
                nodeRequest.parentNodeIndices,
                nodeIndex: nodeIndex,
                maximumFanIn: maximumFanIn,
                nodeResults: nodeResults
            )
            let depth = (parents.map(\.step.depth).max() ?? 0) + 1
            guard depth <= maximumDepth else {
                throw SuperNeoError.invalidParameter("bounded PCD node exceeds selected maximum depth")
            }
            let primaryParentIndex = try resolvedPrimaryCarryParentIndex(
                requested: nodeRequest.primaryCarryParentIndex,
                parentNodeIndices: nodeRequest.parentNodeIndices
            )
            let parentBinding = try makePCDParentSetBinding(
                nodeIndex: nodeIndex,
                parentNodeIndices: nodeRequest.parentNodeIndices,
                primaryCarryParentIndex: primaryParentIndex,
                parents: parents
            )
            let boundRequest = try requestByBindingPCDParentSet(
                nodeRequest.step,
                nodeIndex: nodeIndex,
                parentBinding: parentBinding
            )
            let primaryParent = try primaryParentIndex.map { parentIndex in
                guard let parentNode = nodeResults.first(where: { $0.nodeIndex == parentIndex }) else {
                    throw SuperNeoError.invalidParameter("bounded PCD primary parent was not produced")
                }
                return try NumiSealProductRecursiveCarryParent(
                    artifact: parentNode.step.provingOutput.artifact,
                    verificationResult: parentNode.step.verificationResult,
                    consumerSessionDigest: nodeRequest.step.nextConsumerSessionDigest
                        ?? defaultPCDConsumerSessionDigest(
                            nodeIndex: nodeIndex,
                            parentSetRoot: parentBinding?.parentSetRoot,
                            primaryParentArtifactDigest: parentNode.step.artifactDigest,
                            primaryParentCarryChainRoot: parentNode.step.productCarryChainRoot
                        ),
                    nextRecursionLevel: parentNode.step.depth
                )
            }
            let step = try proveAndVerifyStep(
                request: boundRequest,
                depth: depth,
                recursiveCarryParent: primaryParent,
                verifier: verifier
            )
            nodeResults.append(
                NumiSealBoundedPCDNodeResult(
                    nodeIndex: nodeIndex,
                    parentSetBinding: parentBinding,
                    step: step
                )
            )
        }

        let accounting = try NumiSealBoundedPCDAccounting(
            maximumDepth: maximumDepth,
            nodeResults: nodeResults
        )
        return NumiSealBoundedPCDRun(
            maximumDepth: maximumDepth,
            maximumFanIn: maximumFanIn,
            nodes: nodeResults,
            accounting: accounting
        )
    }

    private static func proveAndVerifyStep(
        request: NumiSealBoundedRecursiveStepRequest,
        depth: Int,
        recursiveCarryParent parent: NumiSealProductRecursiveCarryParent?,
        verifier: NumiSealProductVerifier
    ) throws -> NumiSealBoundedRecursiveStepResult {
        let output = try NumiSealProductAPI.provePreparedR1CS(
            preparedR1CS: request.preparedR1CS,
            trustedContext: request.trustedContext,
            qroChallenge: request.qroChallenge,
            keySeedUTF8: request.keySeedUTF8,
            executionPolicy: request.executionPolicy,
            zkMode: request.zkMode,
            aggregationLimits: request.aggregationLimits,
            parameters: request.parameters,
            metalContext: request.metalContext,
            recursiveCarryParent: parent,
            sourceDecompositionProfile: request.sourceDecompositionProfile
        )
        let verification = try verifier.verify(
            artifact: output.artifact,
            sourcePublicInput: output.sourcePublicInput,
            key: output.verifierKey,
            qroChallenge: output.qroChallenge,
            parameters: request.parameters,
            metalContext: request.metalContext,
            executionPolicy: request.executionPolicy.resolvedSuperNeoPolicy(metalContext: request.metalContext),
            recursiveCarryParent: parent,
            trustedContext: request.trustedContext
        )
        guard verification.sourceFoldResult.isReductionAccepted, verification.numiSealResult.isValid else {
            throw SuperNeoError.verificationFailed("bounded recursive driver produced an unaccepted step")
        }
        let artifactDigest = try output.artifactDigest
        return NumiSealBoundedRecursiveStepResult(
            depth: depth,
            provingOutput: output,
            verificationResult: verification,
            artifactDigest: artifactDigest,
            productCarryChainRoot: verification.productCarryChainRoot,
            recursiveCarryChainRoot: verification.recursiveCarryChainRoot,
            traceExtractorEvidenceDigest: output.traceExtractorEvidence.evidenceDigest,
            qromEvidenceDigest: output.qromEvidence.evidenceDigest
        )
    }

    private static func validatePCDParents(
        _ parentNodeIndices: [Int],
        nodeIndex: Int,
        maximumFanIn: Int,
        nodeResults: [NumiSealBoundedPCDNodeResult]
    ) throws -> [NumiSealBoundedPCDNodeResult] {
        guard parentNodeIndices.count <= maximumFanIn else {
            throw SuperNeoError.invalidParameter("bounded PCD parent fan-in exceeds configured maximum")
        }
        guard parentNodeIndices.count == Set(parentNodeIndices).count else {
            throw SuperNeoError.invalidParameter("bounded PCD parent indices must be unique")
        }
        var parents: [NumiSealBoundedPCDNodeResult] = []
        parents.reserveCapacity(parentNodeIndices.count)
        for parentIndex in parentNodeIndices {
            guard parentIndex >= 0, parentIndex < nodeIndex else {
                throw SuperNeoError.invalidParameter("bounded PCD parent index must refer to an earlier node")
            }
            guard let parent = nodeResults.first(where: { $0.nodeIndex == parentIndex }) else {
                throw SuperNeoError.invalidParameter("bounded PCD parent node was not produced")
            }
            parents.append(parent)
        }
        return parents
    }

    private static func resolvedPrimaryCarryParentIndex(
        requested: Int?,
        parentNodeIndices: [Int]
    ) throws -> Int? {
        if let requested {
            guard parentNodeIndices.contains(requested) else {
                throw SuperNeoError.invalidParameter("bounded PCD primary carry parent must be in the parent set")
            }
            return requested
        }
        return parentNodeIndices.count == 1 ? parentNodeIndices[0] : nil
    }

    private static func makePCDParentSetBinding(
        nodeIndex: Int,
        parentNodeIndices: [Int],
        primaryCarryParentIndex: Int?,
        parents: [NumiSealBoundedPCDNodeResult]
    ) throws -> NumiSealBoundedPCDParentSetBinding? {
        guard !parentNodeIndices.isEmpty else {
            return nil
        }
        return try NumiSealBoundedPCDParentSetBinding(
            nodeIndex: nodeIndex,
            parentNodeIndices: parentNodeIndices,
            primaryCarryParentIndex: primaryCarryParentIndex,
            parentArtifactDigests: parents.map(\.step.artifactDigest),
            parentCarryChainRoots: parents.map(\.step.productCarryChainRoot),
            parentTraceExtractorEvidenceDigests: parents.map(\.step.traceExtractorEvidenceDigest),
            parentQromEvidenceDigests: parents.map(\.step.qromEvidenceDigest)
        )
    }

    private static func requestByBindingPCDParentSet(
        _ request: NumiSealBoundedRecursiveStepRequest,
        nodeIndex: Int,
        parentBinding: NumiSealBoundedPCDParentSetBinding?
    ) throws -> NumiSealBoundedRecursiveStepRequest {
        guard let parentBinding else {
            return request
        }
        var workloadParameters = request.trustedContext.workloadParameters
        workloadParameters["pcdNodeIndex"] = "\(nodeIndex)"
        workloadParameters["pcdParentCount"] = "\(parentBinding.parentNodeIndices.count)"
        workloadParameters["pcdParentIndices"] = parentBinding.parentNodeIndices.map(String.init).joined(separator: ",")
        workloadParameters["pcdParentSetRoot"] = parentBinding.parentSetRoot.hexString
        if let primary = parentBinding.primaryCarryParentIndex {
            workloadParameters["pcdPrimaryCarryParentIndex"] = "\(primary)"
        }
        let trustedContext = try NumiSealProductTrustedContext(
            workload: request.trustedContext.workload,
            bitCount: request.trustedContext.bitCount,
            publicInputs: request.trustedContext.publicInputs,
            workloadParameters: workloadParameters,
            sourceApplicationPathUTF8: request.trustedContext.sourceApplicationPathUTF8,
            laneID: request.trustedContext.laneID
        )
        return NumiSealBoundedRecursiveStepRequest(
            preparedR1CS: request.preparedR1CS,
            trustedContext: trustedContext,
            qroChallenge: request.qroChallenge,
            keySeedUTF8: request.keySeedUTF8,
            executionPolicy: request.executionPolicy,
            zkMode: request.zkMode,
            aggregationLimits: request.aggregationLimits,
            parameters: request.parameters,
            metalContext: request.metalContext,
            sourceDecompositionProfile: request.sourceDecompositionProfile,
            nextConsumerSessionDigest: request.nextConsumerSessionDigest
        )
    }

    private static func defaultConsumerSessionDigest(
        stepIndex: Int,
        artifactDigest: Digest256,
        productCarryChainRoot: Digest256
    ) -> Digest256 {
        Digest256.hash(
            SuperNeoSplitQRO.framedBytes(
                domain: "superneo/numiseal/bounded-recursive-driver/session/v1",
                frames: [
                    numiSealEncodeCount(stepIndex),
                    artifactDigest.superNeoBytes,
                    productCarryChainRoot.superNeoBytes
                ]
            )
        )
    }

    private static func defaultPCDConsumerSessionDigest(
        nodeIndex: Int,
        parentSetRoot: Digest256?,
        primaryParentArtifactDigest: Digest256,
        primaryParentCarryChainRoot: Digest256
    ) -> Digest256 {
        Digest256.hash(
            SuperNeoSplitQRO.framedBytes(
                domain: "superneo/numiseal/bounded-pcd-driver/session/v1",
                frames: [
                    numiSealEncodeCount(nodeIndex),
                    parentSetRoot?.superNeoBytes ?? Digest256.hash("bounded-pcd/no-parent-set").superNeoBytes,
                    primaryParentArtifactDigest.superNeoBytes,
                    primaryParentCarryChainRoot.superNeoBytes
                ]
            )
        )
    }
}
