import Foundation

public enum SuperNeoRecursiveCompilerKind: UInt8, Equatable, Sendable {
    case ivc = 1
    case pcd = 2

    public var compilerID: String {
        switch self {
        case .ivc:
            return "superneo-standard-folding-to-ivc-v1"
        case .pcd:
            return "superneo-standard-folding-to-pcd-v1"
        }
    }
}

public struct SuperNeoAccumulator: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.superneo-accumulator.v1")

    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let claims: [CCSEvaluationClaim]
    public let accumulatorDigest: Digest256

    public init(
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        claims: [CCSEvaluationClaim]
    ) {
        let publicClaims = claims.map(superNeoPublicClaim)
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.claims = publicClaims
        self.accumulatorDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    claims: publicClaims
                )
        )
    }

    public init(profileID: UInt16, shape: CCSShape, key: AjtaiCommitmentKey, claims: [CCSEvaluationClaim] = []) {
        self.init(
            profileID: profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            claims: claims
        )
    }

    public var isEmpty: Bool {
        claims.isEmpty
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                profileID: profileID,
                shapeDigest: shapeDigest,
                verifierKeyDigest: verifierKeyDigest,
                claims: claims
            )
            + accumulatorDigest.superNeoBytes
    }

    private static func bodyBytes(
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        claims: [CCSEvaluationClaim]
    ) -> [UInt8] {
        superNeoCompilerEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + superNeoCompilerEncodeCount(claims.count)
            + claims.flatMap(\.superNeoBytes)
    }
}

public struct SuperNeoRecursiveVerifierState: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-verifier-state.v1")
    public static let noParentDigest = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-verifier-state.no-parent.v1")
    public static let genesisStatementDigest = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-verifier-state.genesis-statement.v1")
    public static let genesisProofDigest = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-verifier-state.genesis-proof.v1")
    public static let genesisTranscriptSeedDigest = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-verifier-state.genesis-transcript.v1")
    public static let genesisBoundaryDigest = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-verifier-state.genesis-boundary.v1")

    public let compilerKind: SuperNeoRecursiveCompilerKind
    public let nodeIndex: Int
    public let depth: Int
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let parentNodeIndices: [Int]
    public let parentStateDigests: [Digest256]
    public let parentSetRoot: Digest256?
    public let statementDigest: Digest256
    public let transcriptSeedDigest: Digest256
    public let foldProofDigest: Digest256
    public let reductionBoundaryDigest: Digest256
    public let recursiveRelationDigest: Digest256?
    public let accumulator: SuperNeoAccumulator
    public let stateDigest: Digest256

    public init(
        compilerKind: SuperNeoRecursiveCompilerKind,
        nodeIndex: Int,
        depth: Int,
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        parentNodeIndices: [Int],
        parentStateDigests: [Digest256],
        parentSetRoot: Digest256?,
        statementDigest: Digest256,
        transcriptSeedDigest: Digest256,
        foldProofDigest: Digest256,
        reductionBoundaryDigest: Digest256,
        recursiveRelationDigest: Digest256? = nil,
        accumulator: SuperNeoAccumulator
    ) {
        self.compilerKind = compilerKind
        self.nodeIndex = nodeIndex
        self.depth = depth
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.parentNodeIndices = parentNodeIndices
        self.parentStateDigests = parentStateDigests
        self.parentSetRoot = parentSetRoot
        self.statementDigest = statementDigest
        self.transcriptSeedDigest = transcriptSeedDigest
        self.foldProofDigest = foldProofDigest
        self.reductionBoundaryDigest = reductionBoundaryDigest
        self.recursiveRelationDigest = recursiveRelationDigest
        self.accumulator = accumulator
        self.stateDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    compilerKind: compilerKind,
                    nodeIndex: nodeIndex,
                    depth: depth,
                    profileID: profileID,
                    shapeDigest: shapeDigest,
                    verifierKeyDigest: verifierKeyDigest,
                    parentNodeIndices: parentNodeIndices,
                    parentStateDigests: parentStateDigests,
                    parentSetRoot: parentSetRoot,
                    statementDigest: statementDigest,
                    transcriptSeedDigest: transcriptSeedDigest,
                    foldProofDigest: foldProofDigest,
                    reductionBoundaryDigest: reductionBoundaryDigest,
                    recursiveRelationDigest: recursiveRelationDigest,
                    accumulator: accumulator
                )
        )
    }

    public static func genesis(
        compilerKind: SuperNeoRecursiveCompilerKind,
        profileID: UInt16,
        shape: CCSShape,
        key: AjtaiCommitmentKey
    ) -> Self {
        let accumulator = SuperNeoAccumulator(profileID: profileID, shape: shape, key: key)
        return Self(
            compilerKind: compilerKind,
            nodeIndex: -1,
            depth: 0,
            profileID: profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            parentNodeIndices: [],
            parentStateDigests: [],
            parentSetRoot: nil,
            statementDigest: genesisStatementDigest,
            transcriptSeedDigest: genesisTranscriptSeedDigest,
            foldProofDigest: genesisProofDigest,
            reductionBoundaryDigest: genesisBoundaryDigest,
            accumulator: accumulator
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                compilerKind: compilerKind,
                nodeIndex: nodeIndex,
                depth: depth,
                profileID: profileID,
                shapeDigest: shapeDigest,
                verifierKeyDigest: verifierKeyDigest,
                parentNodeIndices: parentNodeIndices,
                parentStateDigests: parentStateDigests,
                parentSetRoot: parentSetRoot,
                statementDigest: statementDigest,
                transcriptSeedDigest: transcriptSeedDigest,
                foldProofDigest: foldProofDigest,
                reductionBoundaryDigest: reductionBoundaryDigest,
                recursiveRelationDigest: recursiveRelationDigest,
                accumulator: accumulator
            )
            + stateDigest.superNeoBytes
    }

    private static func bodyBytes(
        compilerKind: SuperNeoRecursiveCompilerKind,
        nodeIndex: Int,
        depth: Int,
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        parentNodeIndices: [Int],
        parentStateDigests: [Digest256],
        parentSetRoot: Digest256?,
        statementDigest: Digest256,
        transcriptSeedDigest: Digest256,
        foldProofDigest: Digest256,
        reductionBoundaryDigest: Digest256,
        recursiveRelationDigest: Digest256?,
        accumulator: SuperNeoAccumulator
    ) -> [UInt8] {
        [compilerKind.rawValue]
            + superNeoCompilerEncodeSignedInt(nodeIndex)
            + superNeoCompilerEncodeCount(depth)
            + superNeoCompilerEncodeUInt16(profileID)
            + shapeDigest.superNeoBytes
            + verifierKeyDigest.superNeoBytes
            + superNeoCompilerEncodeCount(parentNodeIndices.count)
            + parentNodeIndices.flatMap(superNeoCompilerEncodeSignedInt)
            + superNeoCompilerEncodeCount(parentStateDigests.count)
            + parentStateDigests.flatMap(\.superNeoBytes)
            + [parentSetRoot == nil ? 0 : 1]
            + (parentSetRoot ?? noParentDigest).superNeoBytes
            + statementDigest.superNeoBytes
            + transcriptSeedDigest.superNeoBytes
            + foldProofDigest.superNeoBytes
            + reductionBoundaryDigest.superNeoBytes
            + (recursiveRelationDigest.map { [UInt8(1)] + $0.superNeoBytes } ?? [])
            + accumulator.accumulatorDigest.superNeoBytes
    }
}

public struct SuperNeoRecursiveCompilerStep: Equatable, Sendable {
    public let compilerKind: SuperNeoRecursiveCompilerKind
    public let nodeIndex: Int
    public let depth: Int
    public let parentNodeIndices: [Int]
    public let statement: CCSStatement
    public let transcriptSeed: [UInt8]
    public let proof: FoldProof
    public let outputAccumulator: SuperNeoAccumulator
    public let reductionBoundaryReport: SuperNeoFoldReductionBoundaryReport
    public let foldRelation: SuperNeoRecursiveFoldRelation?
    public let verifierState: SuperNeoRecursiveVerifierState

    public init(
        compilerKind: SuperNeoRecursiveCompilerKind,
        nodeIndex: Int,
        depth: Int,
        parentNodeIndices: [Int],
        statement: CCSStatement,
        transcriptSeed: [UInt8],
        proof: FoldProof,
        outputAccumulator: SuperNeoAccumulator,
        reductionBoundaryReport: SuperNeoFoldReductionBoundaryReport,
        foldRelation: SuperNeoRecursiveFoldRelation? = nil,
        verifierState: SuperNeoRecursiveVerifierState
    ) {
        self.compilerKind = compilerKind
        self.nodeIndex = nodeIndex
        self.depth = depth
        self.parentNodeIndices = parentNodeIndices
        self.statement = statement
        self.transcriptSeed = transcriptSeed
        self.proof = proof
        self.outputAccumulator = outputAccumulator
        self.reductionBoundaryReport = reductionBoundaryReport
        self.foldRelation = foldRelation
        self.verifierState = verifierState
    }
}

public struct SuperNeoIVCStepRequest: Sendable {
    public let input: SuperNeoFoldInput
    public let transcriptSeed: [UInt8]

    public init(input: SuperNeoFoldInput, transcriptSeed: [UInt8] = []) {
        self.input = input
        self.transcriptSeed = transcriptSeed
    }
}

public struct SuperNeoIVCRun: Sendable {
    public let initialState: SuperNeoRecursiveVerifierState
    public let steps: [SuperNeoRecursiveCompilerStep]
    public let finalState: SuperNeoRecursiveVerifierState

    public init(
        initialState: SuperNeoRecursiveVerifierState,
        steps: [SuperNeoRecursiveCompilerStep],
        finalState: SuperNeoRecursiveVerifierState
    ) {
        self.initialState = initialState
        self.steps = steps
        self.finalState = finalState
    }
}

public struct SuperNeoPCDNodeRequest: Sendable {
    public let input: SuperNeoFoldInput
    public let parentNodeIndices: [Int]
    public let transcriptSeed: [UInt8]

    public init(
        input: SuperNeoFoldInput,
        parentNodeIndices: [Int] = [],
        transcriptSeed: [UInt8] = []
    ) {
        self.input = input
        self.parentNodeIndices = parentNodeIndices
        self.transcriptSeed = transcriptSeed
    }
}

public struct SuperNeoPCDParentTupleBinding: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLE/v1")
    public static let claimRootDomain = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLE/CLAIMS/v1")
    public static let evaluationPointRootDomain = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLE/EVALUATION_POINTS/v1")
    public static let claimValueRootDomain = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLE/CLAIM_VALUES/v1")
    public static let noRecursiveRelationDigest = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLE/NO_RECURSIVE_RELATION/v1")
    public static let noCarryChainRoot = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLE/NO_CARRY_CHAIN_ROOT/v1")

    public let parentPosition: Int
    public let parentNodeIndex: Int
    public let parentDepth: Int
    public let parentStateDigest: Digest256
    public let parentAccumulatorDigest: Digest256
    public let parentPublicStatementDigest: Digest256
    public let parentOutputAccumulatorClaimRoot: Digest256
    public let parentEvaluationPointRoot: Digest256
    public let parentClaimValueRoot: Digest256
    public let parentRecursiveRelationDigest: Digest256?
    public let parentCarryChainRoot: Digest256?
    public let tupleDigest: Digest256

    public init(
        parentPosition: Int,
        parentNodeIndex: Int,
        parentDepth: Int,
        parentStateDigest: Digest256,
        parentAccumulator: SuperNeoAccumulator,
        parentPublicStatementDigest: Digest256,
        parentRecursiveRelationDigest: Digest256?,
        parentCarryChainRoot: Digest256? = nil
    ) throws {
        guard parentPosition >= 0 else {
            throw SuperNeoError.invalidParameter("PCD parent tuple position must be non-negative")
        }
        guard parentNodeIndex >= 0 else {
            throw SuperNeoError.invalidParameter("PCD parent tuple node index must be non-negative")
        }
        guard parentDepth > 0 else {
            throw SuperNeoError.invalidParameter("PCD parent tuple depth must be positive")
        }
        let publicClaims = parentAccumulator.claims.map(superNeoPublicClaim)
        let claimRoot = Self.claimRoot(claims: publicClaims)
        let pointRoot = Self.evaluationPointRoot(claims: publicClaims)
        let valueRoot = Self.claimValueRoot(claims: publicClaims)
        self.parentPosition = parentPosition
        self.parentNodeIndex = parentNodeIndex
        self.parentDepth = parentDepth
        self.parentStateDigest = parentStateDigest
        self.parentAccumulatorDigest = parentAccumulator.accumulatorDigest
        self.parentPublicStatementDigest = parentPublicStatementDigest
        self.parentOutputAccumulatorClaimRoot = claimRoot
        self.parentEvaluationPointRoot = pointRoot
        self.parentClaimValueRoot = valueRoot
        self.parentRecursiveRelationDigest = parentRecursiveRelationDigest
        self.parentCarryChainRoot = parentCarryChainRoot
        self.tupleDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    parentPosition: parentPosition,
                    parentNodeIndex: parentNodeIndex,
                    parentDepth: parentDepth,
                    parentStateDigest: parentStateDigest,
                    parentAccumulatorDigest: parentAccumulator.accumulatorDigest,
                    parentPublicStatementDigest: parentPublicStatementDigest,
                    parentOutputAccumulatorClaimRoot: claimRoot,
                    parentEvaluationPointRoot: pointRoot,
                    parentClaimValueRoot: valueRoot,
                    parentRecursiveRelationDigest: parentRecursiveRelationDigest,
                    parentCarryChainRoot: parentCarryChainRoot
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                parentPosition: parentPosition,
                parentNodeIndex: parentNodeIndex,
                parentDepth: parentDepth,
                parentStateDigest: parentStateDigest,
                parentAccumulatorDigest: parentAccumulatorDigest,
                parentPublicStatementDigest: parentPublicStatementDigest,
                parentOutputAccumulatorClaimRoot: parentOutputAccumulatorClaimRoot,
                parentEvaluationPointRoot: parentEvaluationPointRoot,
                parentClaimValueRoot: parentClaimValueRoot,
                parentRecursiveRelationDigest: parentRecursiveRelationDigest,
                parentCarryChainRoot: parentCarryChainRoot
            )
            + tupleDigest.superNeoBytes
    }

    public static func claimRoot(claims: [CCSEvaluationClaim]) -> Digest256 {
        Digest256.hash(
            claimRootDomain.superNeoBytes
                + superNeoCompilerEncodeCount(claims.count)
                + claims.map(superNeoPublicClaim).flatMap(\.superNeoBytes)
        )
    }

    public static func evaluationPointRoot(claims: [CCSEvaluationClaim]) -> Digest256 {
        var bytes = evaluationPointRootDomain.superNeoBytes
            + superNeoCompilerEncodeCount(claims.count)
        for (index, claim) in claims.map(superNeoPublicClaim).enumerated() {
            bytes += superNeoCompilerEncodeCount(index)
            bytes += superNeoCompilerEncodeCount(claim.point.count)
            bytes += claim.point.flatMap(\.superNeoBytes)
        }
        return Digest256.hash(bytes)
    }

    public static func claimValueRoot(claims: [CCSEvaluationClaim]) -> Digest256 {
        var bytes = claimValueRootDomain.superNeoBytes
            + superNeoCompilerEncodeCount(claims.count)
        for (index, claim) in claims.map(superNeoPublicClaim).enumerated() {
            bytes += superNeoCompilerEncodeCount(index)
            bytes += superNeoCompilerEncodeCount(claim.evaluations.count)
            bytes += claim.evaluations.flatMap(\.superNeoBytes)
        }
        return Digest256.hash(bytes)
    }

    private static func bodyBytes(
        parentPosition: Int,
        parentNodeIndex: Int,
        parentDepth: Int,
        parentStateDigest: Digest256,
        parentAccumulatorDigest: Digest256,
        parentPublicStatementDigest: Digest256,
        parentOutputAccumulatorClaimRoot: Digest256,
        parentEvaluationPointRoot: Digest256,
        parentClaimValueRoot: Digest256,
        parentRecursiveRelationDigest: Digest256?,
        parentCarryChainRoot: Digest256?
    ) -> [UInt8] {
        superNeoCompilerEncodeCount(parentPosition)
            + superNeoCompilerEncodeCount(parentNodeIndex)
            + superNeoCompilerEncodeCount(parentDepth)
            + parentStateDigest.superNeoBytes
            + parentAccumulatorDigest.superNeoBytes
            + parentPublicStatementDigest.superNeoBytes
            + parentOutputAccumulatorClaimRoot.superNeoBytes
            + parentEvaluationPointRoot.superNeoBytes
            + parentClaimValueRoot.superNeoBytes
            + [parentRecursiveRelationDigest == nil ? 0 : 1]
            + (parentRecursiveRelationDigest ?? noRecursiveRelationDigest).superNeoBytes
            + [parentCarryChainRoot == nil ? 0 : 1]
            + (parentCarryChainRoot ?? noCarryChainRoot).superNeoBytes
    }
}

public struct SuperNeoPCDParentSetBinding: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.superneo-pcd.parent-set.v1")
    public static let orderedParentTupleRootDomain = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLES/v1")

    public let nodeIndex: Int
    public let parentNodeIndices: [Int]
    public let parentStateDigests: [Digest256]
    public let parentAccumulatorDigests: [Digest256]
    public let parentTupleBindings: [SuperNeoPCDParentTupleBinding]
    public let orderedParentTupleRoot: Digest256
    public let parentSetRoot: Digest256

    public init(
        nodeIndex: Int,
        parentNodeIndices: [Int],
        parentStateDigests: [Digest256],
        parentAccumulatorDigests: [Digest256],
        parentTupleBindings: [SuperNeoPCDParentTupleBinding]
    ) throws {
        guard nodeIndex >= 0 else {
            throw SuperNeoError.invalidParameter("PCD node index must be non-negative")
        }
        guard parentNodeIndices.count == Set(parentNodeIndices).count else {
            throw SuperNeoError.invalidParameter("PCD parent indices must be unique")
        }
        guard parentStateDigests.count == parentNodeIndices.count,
              parentAccumulatorDigests.count == parentNodeIndices.count,
              parentTupleBindings.count == parentNodeIndices.count else {
            throw SuperNeoError.invalidParameter("PCD parent binding digest count mismatch")
        }
        guard parentTupleBindings.map(\.parentPosition) == Array(parentNodeIndices.indices),
              parentTupleBindings.map(\.parentNodeIndex) == parentNodeIndices,
              parentTupleBindings.map(\.parentStateDigest) == parentStateDigests,
              parentTupleBindings.map(\.parentAccumulatorDigest) == parentAccumulatorDigests else {
            throw SuperNeoError.invalidParameter("PCD parent tuple binding mismatch")
        }
        let orderedParentTupleRoot = Self.orderedParentTupleRoot(
            fanIn: parentNodeIndices.count,
            tupleBindings: parentTupleBindings
        )
        self.nodeIndex = nodeIndex
        self.parentNodeIndices = parentNodeIndices
        self.parentStateDigests = parentStateDigests
        self.parentAccumulatorDigests = parentAccumulatorDigests
        self.parentTupleBindings = parentTupleBindings
        self.orderedParentTupleRoot = orderedParentTupleRoot
        self.parentSetRoot = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    nodeIndex: nodeIndex,
                    parentNodeIndices: parentNodeIndices,
                    parentStateDigests: parentStateDigests,
                    parentAccumulatorDigests: parentAccumulatorDigests,
                    parentTupleBindings: parentTupleBindings,
                    orderedParentTupleRoot: orderedParentTupleRoot
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                nodeIndex: nodeIndex,
                parentNodeIndices: parentNodeIndices,
                parentStateDigests: parentStateDigests,
                parentAccumulatorDigests: parentAccumulatorDigests,
                parentTupleBindings: parentTupleBindings,
                orderedParentTupleRoot: orderedParentTupleRoot
            )
            + parentSetRoot.superNeoBytes
    }

    public static func orderedParentTupleRoot(
        fanIn: Int,
        tupleBindings: [SuperNeoPCDParentTupleBinding]
    ) -> Digest256 {
        Digest256.hash(
            orderedParentTupleRootDomain.superNeoBytes
                + superNeoCompilerEncodeCount(fanIn)
                + superNeoCompilerEncodeCount(tupleBindings.count)
                + tupleBindings.flatMap(\.superNeoBytes)
        )
    }

    private static func bodyBytes(
        nodeIndex: Int,
        parentNodeIndices: [Int],
        parentStateDigests: [Digest256],
        parentAccumulatorDigests: [Digest256],
        parentTupleBindings: [SuperNeoPCDParentTupleBinding],
        orderedParentTupleRoot: Digest256
    ) -> [UInt8] {
        superNeoCompilerEncodeCount(nodeIndex)
            + superNeoCompilerEncodeCount(parentNodeIndices.count)
            + parentNodeIndices.flatMap(superNeoCompilerEncodeCount)
            + superNeoCompilerEncodeCount(parentStateDigests.count)
            + parentStateDigests.flatMap(\.superNeoBytes)
            + superNeoCompilerEncodeCount(parentAccumulatorDigests.count)
            + parentAccumulatorDigests.flatMap(\.superNeoBytes)
            + superNeoCompilerEncodeCount(parentTupleBindings.count)
            + parentTupleBindings.flatMap(\.superNeoBytes)
            + orderedParentTupleRoot.superNeoBytes
    }
}

public struct SuperNeoRecursiveFoldRelationInput: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-fold-relation.input.v1")
    public static let noOrderedParentTupleRoot = Digest256.hash("SUPERNEO/PCD/PARENT_TUPLES/ABSENT/v1")

    public let compilerKind: SuperNeoRecursiveCompilerKind
    public let nodeIndex: Int
    public let depth: Int
    public let fanInArity: Int
    public let parentNodeIndices: [Int]
    public let parentStateDigests: [Digest256]
    public let parentAccumulatorDigests: [Digest256]
    public let parentStatementDigests: [Digest256]
    public let parentOutputAccumulators: [SuperNeoAccumulator]
    public let parentTupleBindings: [SuperNeoPCDParentTupleBinding]
    public let orderedParentTupleRoot: Digest256?
    public let childTransitionStatement: CCSStatement
    public let parentSetRoot: Digest256?
    public let relationInputDigest: Digest256

    public init(
        compilerKind: SuperNeoRecursiveCompilerKind,
        nodeIndex: Int,
        depth: Int,
        parentNodeIndices: [Int],
        parentStates: [SuperNeoRecursiveVerifierState],
        parentStatements: [CCSStatement],
        childTransitionStatement: CCSStatement,
        parentSetRoot: Digest256?,
        parentTupleBindings suppliedParentTupleBindings: [SuperNeoPCDParentTupleBinding]? = nil
    ) throws {
        guard parentStates.count == parentNodeIndices.count,
              parentStatements.count == parentNodeIndices.count else {
            throw SuperNeoError.invalidParameter("recursive fold relation parent count mismatch")
        }
        guard parentStates.map(\.nodeIndex) == parentNodeIndices else {
            throw SuperNeoError.invalidParameter("recursive fold relation parent state order mismatch")
        }
        guard childTransitionStatement.priorCEInstances.isEmpty,
              childTransitionStatement.recursiveRelationDigest == nil else {
            throw SuperNeoError.invalidParameter("recursive fold relation child transition must exclude parent accumulators")
        }
        for (parentState, parentStatement) in zip(parentStates, parentStatements) {
            guard parentState.compilerKind == compilerKind else {
                throw SuperNeoError.invalidParameter("recursive fold relation parent compiler kind mismatch")
            }
            guard parentState.shapeDigest == childTransitionStatement.shapeDigest,
                  parentState.accumulator.shapeDigest == childTransitionStatement.shapeDigest else {
                throw SuperNeoError.invalidParameter("recursive fold relation parent shape mismatch")
            }
            guard parentState.statementDigest == parentStatement.statementDigest else {
                throw SuperNeoError.invalidParameter("recursive fold relation parent statement mismatch")
            }
        }
        let parentTupleBindings = try suppliedParentTupleBindings ?? Self.makeParentTupleBindings(
            parentNodeIndices: parentNodeIndices,
            parentStates: parentStates,
            parentStatements: parentStatements
        )
        guard parentTupleBindings.count == parentNodeIndices.count else {
            throw SuperNeoError.invalidParameter("recursive fold relation parent tuple count mismatch")
        }
        guard parentTupleBindings.map(\.parentPosition) == Array(parentNodeIndices.indices),
              parentTupleBindings.map(\.parentNodeIndex) == parentNodeIndices,
              parentTupleBindings.map(\.parentStateDigest) == parentStates.map(\.stateDigest),
              parentTupleBindings.map(\.parentAccumulatorDigest) == parentStates.map(\.accumulator.accumulatorDigest),
              parentTupleBindings.map(\.parentPublicStatementDigest) == parentStatements.map(\.statementDigest) else {
            throw SuperNeoError.invalidParameter("recursive fold relation parent tuple mismatch")
        }
        let orderedParentTupleRoot = parentTupleBindings.isEmpty
            ? nil
            : SuperNeoPCDParentSetBinding.orderedParentTupleRoot(
                fanIn: parentNodeIndices.count,
                tupleBindings: parentTupleBindings
            )
        self.compilerKind = compilerKind
        self.nodeIndex = nodeIndex
        self.depth = depth
        self.fanInArity = parentNodeIndices.count
        self.parentNodeIndices = parentNodeIndices
        self.parentStateDigests = parentStates.map(\.stateDigest)
        self.parentAccumulatorDigests = parentStates.map(\.accumulator.accumulatorDigest)
        self.parentStatementDigests = parentStatements.map(\.statementDigest)
        self.parentOutputAccumulators = parentStates.map(\.accumulator)
        self.parentTupleBindings = parentTupleBindings
        self.orderedParentTupleRoot = orderedParentTupleRoot
        self.childTransitionStatement = childTransitionStatement
        self.parentSetRoot = parentSetRoot
        self.relationInputDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + Self.bodyBytes(
                    compilerKind: compilerKind,
                    nodeIndex: nodeIndex,
                    depth: depth,
                    fanInArity: parentNodeIndices.count,
                    parentNodeIndices: parentNodeIndices,
                    parentStateDigests: parentStates.map(\.stateDigest),
                    parentAccumulatorDigests: parentStates.map(\.accumulator.accumulatorDigest),
                    parentStatementDigests: parentStatements.map(\.statementDigest),
                    parentOutputAccumulators: parentStates.map(\.accumulator),
                    parentTupleBindings: parentTupleBindings,
                    orderedParentTupleRoot: orderedParentTupleRoot,
                    childTransitionStatement: childTransitionStatement,
                    parentSetRoot: parentSetRoot
                )
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                compilerKind: compilerKind,
                nodeIndex: nodeIndex,
                depth: depth,
                fanInArity: fanInArity,
                parentNodeIndices: parentNodeIndices,
                parentStateDigests: parentStateDigests,
                parentAccumulatorDigests: parentAccumulatorDigests,
                parentStatementDigests: parentStatementDigests,
                parentOutputAccumulators: parentOutputAccumulators,
                parentTupleBindings: parentTupleBindings,
                orderedParentTupleRoot: orderedParentTupleRoot,
                childTransitionStatement: childTransitionStatement,
                parentSetRoot: parentSetRoot
            )
            + relationInputDigest.superNeoBytes
    }

    private static func bodyBytes(
        compilerKind: SuperNeoRecursiveCompilerKind,
        nodeIndex: Int,
        depth: Int,
        fanInArity: Int,
        parentNodeIndices: [Int],
        parentStateDigests: [Digest256],
        parentAccumulatorDigests: [Digest256],
        parentStatementDigests: [Digest256],
        parentOutputAccumulators: [SuperNeoAccumulator],
        parentTupleBindings: [SuperNeoPCDParentTupleBinding],
        orderedParentTupleRoot: Digest256?,
        childTransitionStatement: CCSStatement,
        parentSetRoot: Digest256?
    ) -> [UInt8] {
        [compilerKind.rawValue]
            + superNeoCompilerEncodeSignedInt(nodeIndex)
            + superNeoCompilerEncodeCount(depth)
            + superNeoCompilerEncodeCount(fanInArity)
            + superNeoCompilerEncodeCount(parentNodeIndices.count)
            + parentNodeIndices.flatMap(superNeoCompilerEncodeSignedInt)
            + superNeoCompilerEncodeCount(parentStateDigests.count)
            + parentStateDigests.flatMap(\.superNeoBytes)
            + superNeoCompilerEncodeCount(parentAccumulatorDigests.count)
            + parentAccumulatorDigests.flatMap(\.superNeoBytes)
            + superNeoCompilerEncodeCount(parentStatementDigests.count)
            + parentStatementDigests.flatMap(\.superNeoBytes)
            + superNeoCompilerEncodeCount(parentOutputAccumulators.count)
            + parentOutputAccumulators.flatMap(\.superNeoBytes)
            + superNeoCompilerEncodeCount(parentTupleBindings.count)
            + parentTupleBindings.flatMap(\.superNeoBytes)
            + [orderedParentTupleRoot == nil ? 0 : 1]
            + (orderedParentTupleRoot ?? noOrderedParentTupleRoot).superNeoBytes
            + childTransitionStatement.superNeoBytes
            + [parentSetRoot == nil ? 0 : 1]
            + (parentSetRoot ?? SuperNeoRecursiveVerifierState.noParentDigest).superNeoBytes
    }

    private static func makeParentTupleBindings(
        parentNodeIndices: [Int],
        parentStates: [SuperNeoRecursiveVerifierState],
        parentStatements: [CCSStatement]
    ) throws -> [SuperNeoPCDParentTupleBinding] {
        try zip(parentNodeIndices.indices, zip(parentNodeIndices, zip(parentStates, parentStatements))).map { item in
            let position = item.0
            let parentNodeIndex = item.1.0
            let parentState = item.1.1.0
            let parentStatement = item.1.1.1
            return try SuperNeoPCDParentTupleBinding(
                parentPosition: position,
                parentNodeIndex: parentNodeIndex,
                parentDepth: parentState.depth,
                parentStateDigest: parentState.stateDigest,
                parentAccumulator: parentState.accumulator,
                parentPublicStatementDigest: parentStatement.statementDigest,
                parentRecursiveRelationDigest: parentState.recursiveRelationDigest
            )
        }
    }
}

public struct SuperNeoRecursiveFoldRelation: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.superneo-recursive-fold-relation.v1")

    public let input: SuperNeoRecursiveFoldRelationInput
    public let outputAccumulator: SuperNeoAccumulator
    public let relationDigest: Digest256

    public init(
        input: SuperNeoRecursiveFoldRelationInput,
        outputAccumulator: SuperNeoAccumulator
    ) {
        self.input = input
        self.outputAccumulator = outputAccumulator
        self.relationDigest = Digest256.hash(
            Self.domain.superNeoBytes
                + input.relationInputDigest.superNeoBytes
                + outputAccumulator.superNeoBytes
        )
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + input.superNeoBytes
            + outputAccumulator.superNeoBytes
            + relationDigest.superNeoBytes
    }
}

public struct SuperNeoPCDNodeResult: Equatable, Sendable {
    public let nodeIndex: Int
    public let parentSetBinding: SuperNeoPCDParentSetBinding?
    public let step: SuperNeoRecursiveCompilerStep

    public init(
        nodeIndex: Int,
        parentSetBinding: SuperNeoPCDParentSetBinding?,
        step: SuperNeoRecursiveCompilerStep
    ) {
        self.nodeIndex = nodeIndex
        self.parentSetBinding = parentSetBinding
        self.step = step
    }
}

public struct SuperNeoPCDRun: Sendable {
    public let initialState: SuperNeoRecursiveVerifierState
    public let nodes: [SuperNeoPCDNodeResult]
    public let terminalNodeIndices: [Int]
    public let finalPCDRoot: Digest256

    public init(
        initialState: SuperNeoRecursiveVerifierState,
        nodes: [SuperNeoPCDNodeResult],
        terminalNodeIndices: [Int],
        finalPCDRoot: Digest256
    ) {
        self.initialState = initialState
        self.nodes = nodes
        self.terminalNodeIndices = terminalNodeIndices
        self.finalPCDRoot = finalPCDRoot
    }
}

private struct SuperNeoProvedRecursiveStep {
    let step: SuperNeoRecursiveCompilerStep
    let privateOutputClaims: [CCSEvaluationClaim]
}

public enum SuperNeoFoldingCompiler {
    public static func proveIVC(
        requests: [SuperNeoIVCStepRequest],
        prover: SuperNeoProver,
        verifier: SuperNeoVerifier? = nil,
        maximumDepth: Int? = nil
    ) throws -> SuperNeoIVCRun {
        guard !requests.isEmpty else {
            throw SuperNeoError.invalidParameter("IVC compiler requires at least one step")
        }
        let limit = maximumDepth ?? requests.count
        guard limit > 0, requests.count <= limit else {
            throw SuperNeoError.invalidParameter("IVC request count exceeds maximum depth")
        }
        let baseShape = requests[0].input.shape
        let stepVerifier = verifier ?? SuperNeoVerifier(
            parameters: prover.parameters,
            key: prover.key,
            context: prover.context,
            executionPolicy: prover.executionPolicy
        )
        var privateAccumulatorClaims: [CCSEvaluationClaim] = []
        let initialState = SuperNeoRecursiveVerifierState.genesis(
            compilerKind: .ivc,
            profileID: prover.parameters.profileID,
            shape: baseShape,
            key: prover.key
        )
        var currentState = initialState
        var steps: [SuperNeoRecursiveCompilerStep] = []
        steps.reserveCapacity(requests.count)

        for (stepIndex, request) in requests.enumerated() {
            guard request.input.priorClaims.isEmpty else {
                throw SuperNeoError.invalidParameter("IVC compiler owns prior accumulator injection")
            }
            guard request.input.shape.shapeDigest == baseShape.shapeDigest else {
                throw SuperNeoError.invalidParameter("IVC step shape changed")
            }
            let input = SuperNeoFoldInput(
                shape: request.input.shape,
                instances: request.input.instances,
                witnesses: request.input.witnesses,
                priorClaims: privateAccumulatorClaims
            )
            let provedStep = try proveRecursiveStep(
                compilerKind: .ivc,
                nodeIndex: stepIndex,
                depth: stepIndex + 1,
                parentNodeIndices: stepIndex == 0 ? [] : [stepIndex - 1],
                parentStates: stepIndex == 0 ? [] : [currentState],
                parentStatements: stepIndex == 0 ? [] : [steps[stepIndex - 1].statement],
                parentSetRoot: nil,
                input: input,
                transcriptSeed: request.transcriptSeed,
                prover: prover,
                verifier: stepVerifier
            )
            let step = provedStep.step
            steps.append(step)
            privateAccumulatorClaims = provedStep.privateOutputClaims
            currentState = step.verifierState
        }

        return SuperNeoIVCRun(
            initialState: initialState,
            steps: steps,
            finalState: currentState
        )
    }

    public static func verifyIVC(
        _ run: SuperNeoIVCRun,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        verifier: SuperNeoVerifier? = nil,
        maximumDepth: Int? = nil
    ) -> VerificationResult {
        do {
            guard !run.steps.isEmpty else {
                return .invalid("IVC run has no steps")
            }
            let depthLimit = maximumDepth ?? run.steps.count
            guard depthLimit > 0, run.steps.count <= depthLimit else {
                return .invalid("IVC run exceeds maximum depth")
            }
            let stepVerifier = verifier ?? SuperNeoVerifier(parameters: parameters, key: key)
            var currentState = SuperNeoRecursiveVerifierState.genesis(
                compilerKind: .ivc,
                profileID: parameters.profileID,
                shape: shape,
                key: key
            )
            guard run.initialState == currentState else {
                return .invalid("IVC initial recursive verifier state mismatch")
            }

            for (stepIndex, step) in run.steps.enumerated() {
                guard step.compilerKind == .ivc, step.nodeIndex == stepIndex else {
                    return .invalid("IVC step index mismatch")
                }
                guard step.depth == stepIndex + 1 else {
                    return .invalid("IVC step depth mismatch")
                }
                let expectedParents = stepIndex == 0 ? [] : [stepIndex - 1]
                guard step.parentNodeIndices == expectedParents else {
                    return .invalid("IVC parent chain mismatch")
                }
                let expectedParentStates = stepIndex == 0 ? [] : [currentState]
                currentState = try verifyRecursiveStep(
                    step,
                    shape: shape,
                    key: key,
                    parameters: parameters,
                    parentStates: expectedParentStates,
                    parentStatements: stepIndex == 0 ? [] : [run.steps[stepIndex - 1].statement],
                    parentAccumulatorClaims: currentState.accumulator.claims,
                    parentSetRoot: nil,
                    expectedCompilerKind: .ivc,
                    verifier: stepVerifier
                )
            }
            guard currentState == run.finalState else {
                return .invalid("IVC final recursive verifier state mismatch")
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }

    public static func provePCD(
        requests: [SuperNeoPCDNodeRequest],
        prover: SuperNeoProver,
        verifier: SuperNeoVerifier? = nil,
        maximumDepth: Int? = nil,
        maximumFanIn: Int = 2
    ) throws -> SuperNeoPCDRun {
        guard !requests.isEmpty else {
            throw SuperNeoError.invalidParameter("PCD compiler requires at least one node")
        }
        guard maximumFanIn > 0 else {
            throw SuperNeoError.invalidParameter("PCD maximum fan-in must be positive")
        }
        let baseShape = requests[0].input.shape
        let depthLimit = maximumDepth ?? requests.count
        let stepVerifier = verifier ?? SuperNeoVerifier(
            parameters: prover.parameters,
            key: prover.key,
            context: prover.context,
            executionPolicy: prover.executionPolicy
        )
        let initialState = SuperNeoRecursiveVerifierState.genesis(
            compilerKind: .pcd,
            profileID: prover.parameters.profileID,
            shape: baseShape,
            key: prover.key
        )
        var nodes: [SuperNeoPCDNodeResult] = []
        var privateAccumulatorClaimsByNode: [[CCSEvaluationClaim]] = []
        nodes.reserveCapacity(requests.count)
        privateAccumulatorClaimsByNode.reserveCapacity(requests.count)

        for (nodeIndex, request) in requests.enumerated() {
            guard request.input.priorClaims.isEmpty else {
                throw SuperNeoError.invalidParameter("PCD compiler owns parent accumulator injection")
            }
            guard request.input.shape.shapeDigest == baseShape.shapeDigest else {
                throw SuperNeoError.invalidParameter("PCD node shape changed")
            }
            let parents = try validatePCDParents(
                request.parentNodeIndices,
                nodeIndex: nodeIndex,
                maximumFanIn: maximumFanIn,
                nodes: nodes
            )
            let depth = (parents.map { $0.step.depth }.max() ?? 0) + 1
            guard depth <= depthLimit else {
                throw SuperNeoError.invalidParameter("PCD node exceeds maximum depth")
            }
            let parentStates = parents.map(\.step.verifierState)
            let parentStatements = parents.map(\.step.statement)
            let parentBinding = try makePCDParentSetBinding(
                nodeIndex: nodeIndex,
                parentNodeIndices: request.parentNodeIndices,
                parentStates: parentStates,
                parentStatements: parentStatements
            )
            let parentClaims = request.parentNodeIndices.flatMap { privateAccumulatorClaimsByNode[$0] }
            let input = SuperNeoFoldInput(
                shape: request.input.shape,
                instances: request.input.instances,
                witnesses: request.input.witnesses,
                priorClaims: parentClaims
            )
            let provedStep = try proveRecursiveStep(
                compilerKind: .pcd,
                nodeIndex: nodeIndex,
                depth: depth,
                parentNodeIndices: request.parentNodeIndices,
                parentStates: parentStates,
                parentStatements: parentStatements,
                parentSetRoot: parentBinding?.parentSetRoot,
                input: input,
                transcriptSeed: request.transcriptSeed,
                prover: prover,
                verifier: stepVerifier
            )
            let step = provedStep.step
            nodes.append(
                SuperNeoPCDNodeResult(
                    nodeIndex: nodeIndex,
                    parentSetBinding: parentBinding,
                    step: step
                )
            )
            privateAccumulatorClaimsByNode.append(provedStep.privateOutputClaims)
        }

        let terminalNodeIndices = terminalIndices(for: nodes)
        return SuperNeoPCDRun(
            initialState: initialState,
            nodes: nodes,
            terminalNodeIndices: terminalNodeIndices,
            finalPCDRoot: pcdFinalRoot(terminalNodeIndices: terminalNodeIndices, nodes: nodes)
        )
    }

    public static func verifyPCD(
        _ run: SuperNeoPCDRun,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        verifier: SuperNeoVerifier? = nil,
        maximumFanIn: Int = 2,
        maximumDepth: Int? = nil
    ) -> VerificationResult {
        do {
            guard !run.nodes.isEmpty else {
                return .invalid("PCD run has no nodes")
            }
            guard maximumFanIn > 0 else {
                return .invalid("PCD maximum fan-in must be positive")
            }
            let depthLimit = maximumDepth ?? run.nodes.count
            guard depthLimit > 0 else {
                return .invalid("PCD maximum depth must be positive")
            }
            let stepVerifier = verifier ?? SuperNeoVerifier(parameters: parameters, key: key)
            let expectedInitial = SuperNeoRecursiveVerifierState.genesis(
                compilerKind: .pcd,
                profileID: parameters.profileID,
                shape: shape,
                key: key
            )
            guard run.initialState == expectedInitial else {
                return .invalid("PCD initial recursive verifier state mismatch")
            }
            var verifiedNodes: [SuperNeoPCDNodeResult] = []
            verifiedNodes.reserveCapacity(run.nodes.count)

            for (nodeIndex, node) in run.nodes.enumerated() {
                guard node.nodeIndex == nodeIndex, node.step.nodeIndex == nodeIndex else {
                    return .invalid("PCD node index mismatch")
                }
                guard node.step.compilerKind == .pcd else {
                    return .invalid("PCD compiler kind mismatch")
                }
                let parents = try validatePCDParents(
                    node.step.parentNodeIndices,
                    nodeIndex: nodeIndex,
                    maximumFanIn: maximumFanIn,
                    nodes: verifiedNodes
                )
                let parentStates = parents.map(\.step.verifierState)
                let parentStatements = parents.map(\.step.statement)
                let expectedDepth = (parents.map { $0.step.depth }.max() ?? 0) + 1
                guard node.step.depth == expectedDepth else {
                    return .invalid("PCD node depth mismatch")
                }
                guard node.step.depth <= depthLimit else {
                    return .invalid("PCD run exceeds maximum depth")
                }
                let expectedBinding = try makePCDParentSetBinding(
                    nodeIndex: nodeIndex,
                    parentNodeIndices: node.step.parentNodeIndices,
                    parentStates: parentStates,
                    parentStatements: parentStatements
                )
                let parentClaims = parents.flatMap(\.step.outputAccumulator.claims)
                _ = try verifyRecursiveStep(
                    node.step,
                    shape: shape,
                    key: key,
                    parameters: parameters,
                    parentStates: parentStates,
                    parentStatements: parentStatements,
                    parentAccumulatorClaims: parentClaims,
                    parentSetRoot: expectedBinding?.parentSetRoot,
                    expectedCompilerKind: .pcd,
                    verifier: stepVerifier
                )
                guard node.step.parentNodeIndices == (node.parentSetBinding?.parentNodeIndices ?? []) else {
                    return .invalid("PCD parent binding mismatch")
                }
                guard node.parentSetBinding == expectedBinding else {
                    return .invalid("PCD parent set root mismatch")
                }
                verifiedNodes.append(node)
            }

            let expectedTerminalIndices = terminalIndices(for: verifiedNodes)
            guard run.terminalNodeIndices == expectedTerminalIndices else {
                return .invalid("PCD terminal node set mismatch")
            }
            guard run.finalPCDRoot == pcdFinalRoot(terminalNodeIndices: expectedTerminalIndices, nodes: verifiedNodes) else {
                return .invalid("PCD final root mismatch")
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }

    private static func proveRecursiveStep(
        compilerKind: SuperNeoRecursiveCompilerKind,
        nodeIndex: Int,
        depth: Int,
        parentNodeIndices: [Int],
        parentStates: [SuperNeoRecursiveVerifierState],
        parentStatements: [CCSStatement],
        parentSetRoot: Digest256?,
        input: SuperNeoFoldInput,
        transcriptSeed: [UInt8],
        prover: SuperNeoProver,
        verifier: SuperNeoVerifier
    ) throws -> SuperNeoProvedRecursiveStep {
        let childTransitionStatement = CCSStatement(
            shapeDigest: input.shape.shapeDigest,
            ccsInstances: input.instances,
            priorCEInstances: []
        )
        let relationInput = try SuperNeoRecursiveFoldRelationInput(
            compilerKind: compilerKind,
            nodeIndex: nodeIndex,
            depth: depth,
            parentNodeIndices: parentNodeIndices,
            parentStates: parentStates,
            parentStatements: parentStatements,
            childTransitionStatement: childTransitionStatement,
            parentSetRoot: parentSetRoot
        )
        let relationBoundInput = SuperNeoFoldInput(
            shape: input.shape,
            instances: input.instances,
            witnesses: input.witnesses,
            priorClaims: input.priorClaims,
            recursiveRelationDigest: relationInput.relationInputDigest
        )
        let output = try prover.foldWithOutput(relationBoundInput, transcriptSeed: transcriptSeed)
        let publicInput = SuperNeoPublicFoldInput(relationBoundInput)
        let reduction = verifier.reduceFold(
            publicInput: publicInput,
            proof: output.proof,
            transcriptSeed: transcriptSeed
        )
        guard reduction.isReductionAccepted, let report = reduction.boundaryReport, report.isAccepted else {
            throw SuperNeoError.verificationFailed(reduction.reason ?? "recursive compiler step reduction rejected")
        }
        guard superNeoSamePublicClaims(reduction.outputClaims, output.outputClaims) else {
            throw SuperNeoError.verificationFailed("recursive compiler output accumulator mismatch")
        }
        let statement = SuperNeoFoldingCompiler.statement(from: publicInput)
        let accumulator = SuperNeoAccumulator(
            profileID: prover.parameters.profileID,
            shape: input.shape,
            key: prover.key,
            claims: output.outputClaims
        )
        let foldRelation = SuperNeoRecursiveFoldRelation(
            input: relationInput,
            outputAccumulator: accumulator
        )
        let state = SuperNeoRecursiveVerifierState(
            compilerKind: compilerKind,
            nodeIndex: nodeIndex,
            depth: depth,
            profileID: prover.parameters.profileID,
            shapeDigest: input.shape.shapeDigest,
            verifierKeyDigest: prover.key.verifierKeyDigest,
            parentNodeIndices: parentNodeIndices,
            parentStateDigests: parentStates.map(\.stateDigest),
            parentSetRoot: parentSetRoot,
            statementDigest: statement.statementDigest,
            transcriptSeedDigest: Digest256.hash(transcriptSeed),
            foldProofDigest: Digest256.hash(output.proof.superNeoBytes),
            reductionBoundaryDigest: reductionBoundaryDigest(report),
            recursiveRelationDigest: foldRelation.relationDigest,
            accumulator: accumulator
        )
        let step = SuperNeoRecursiveCompilerStep(
            compilerKind: compilerKind,
            nodeIndex: nodeIndex,
            depth: depth,
            parentNodeIndices: parentNodeIndices,
            statement: statement,
            transcriptSeed: transcriptSeed,
            proof: output.proof,
            outputAccumulator: accumulator,
            reductionBoundaryReport: report,
            foldRelation: foldRelation,
            verifierState: state
        )
        return SuperNeoProvedRecursiveStep(step: step, privateOutputClaims: output.outputClaims)
    }

    private static func verifyRecursiveStep(
        _ step: SuperNeoRecursiveCompilerStep,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        parentStates: [SuperNeoRecursiveVerifierState],
        parentStatements: [CCSStatement],
        parentAccumulatorClaims: [CCSEvaluationClaim],
        parentSetRoot: Digest256?,
        expectedCompilerKind: SuperNeoRecursiveCompilerKind,
        verifier: SuperNeoVerifier
    ) throws -> SuperNeoRecursiveVerifierState {
        guard step.compilerKind == expectedCompilerKind else {
            throw SuperNeoError.verificationFailed("recursive compiler kind mismatch")
        }
        guard step.statement.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.verificationFailed("recursive compiler statement shape mismatch")
        }
        guard step.outputAccumulator.profileID == parameters.profileID,
              step.outputAccumulator.shapeDigest == shape.shapeDigest,
              step.outputAccumulator.verifierKeyDigest == key.verifierKeyDigest else {
            throw SuperNeoError.verificationFailed("recursive compiler accumulator context mismatch")
        }
        let childTransitionStatement = CCSStatement(
            shapeDigest: shape.shapeDigest,
            ccsInstances: step.statement.ccsInstances,
            priorCEInstances: []
        )
        let expectedRelationInput = try SuperNeoRecursiveFoldRelationInput(
            compilerKind: step.compilerKind,
            nodeIndex: step.nodeIndex,
            depth: step.depth,
            parentNodeIndices: step.parentNodeIndices,
            parentStates: parentStates,
            parentStatements: parentStatements,
            childTransitionStatement: childTransitionStatement,
            parentSetRoot: parentSetRoot
        )
        guard let foldRelation = step.foldRelation else {
            throw SuperNeoError.verificationFailed("recursive compiler folded relation missing")
        }
        guard foldRelation.input == expectedRelationInput else {
            throw SuperNeoError.verificationFailed("recursive compiler folded relation input mismatch")
        }
        guard step.statement.recursiveRelationDigest == expectedRelationInput.relationInputDigest else {
            throw SuperNeoError.verificationFailed("recursive compiler folded relation digest mismatch")
        }
        let priorClaims = step.statement.priorCEInstances.map(superNeoClaim)
        guard superNeoSamePublicClaims(priorClaims, parentAccumulatorClaims) else {
            throw SuperNeoError.verificationFailed("recursive compiler prior accumulator mismatch")
        }
        let publicInput = SuperNeoPublicFoldInput(
            shape: shape,
            instances: step.statement.ccsInstances,
            priorClaims: priorClaims,
            recursiveRelationDigest: expectedRelationInput.relationInputDigest
        )
        guard statement(from: publicInput) == step.statement else {
            throw SuperNeoError.verificationFailed("recursive compiler statement digest mismatch")
        }
        let reduction = verifier.reduceFold(
            publicInput: publicInput,
            proof: step.proof,
            transcriptSeed: step.transcriptSeed
        )
        guard reduction.isReductionAccepted, let report = reduction.boundaryReport, report.isAccepted else {
            throw SuperNeoError.verificationFailed(reduction.reason ?? "recursive compiler reduction rejected")
        }
        guard superNeoSamePublicClaims(reduction.outputClaims, step.outputAccumulator.claims) else {
            throw SuperNeoError.verificationFailed("recursive compiler output accumulator mismatch")
        }
        let expectedRelation = SuperNeoRecursiveFoldRelation(
            input: expectedRelationInput,
            outputAccumulator: step.outputAccumulator
        )
        guard foldRelation == expectedRelation else {
            throw SuperNeoError.verificationFailed("recursive compiler folded relation output mismatch")
        }
        let expectedState = SuperNeoRecursiveVerifierState(
            compilerKind: step.compilerKind,
            nodeIndex: step.nodeIndex,
            depth: step.depth,
            profileID: parameters.profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            parentNodeIndices: step.parentNodeIndices,
            parentStateDigests: parentStates.map(\.stateDigest),
            parentSetRoot: parentSetRoot,
            statementDigest: step.statement.statementDigest,
            transcriptSeedDigest: Digest256.hash(step.transcriptSeed),
            foldProofDigest: Digest256.hash(step.proof.superNeoBytes),
            reductionBoundaryDigest: reductionBoundaryDigest(report),
            recursiveRelationDigest: expectedRelation.relationDigest,
            accumulator: step.outputAccumulator
        )
        guard step.verifierState == expectedState else {
            throw SuperNeoError.verificationFailed("recursive verifier state transition mismatch")
        }
        return expectedState
    }

    private static func statement(from publicInput: SuperNeoPublicFoldInput) -> CCSStatement {
        CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map(CEInstance.init),
            recursiveRelationDigest: publicInput.recursiveRelationDigest
        )
    }

    private static func validatePCDParents(
        _ parentNodeIndices: [Int],
        nodeIndex: Int,
        maximumFanIn: Int,
        nodes: [SuperNeoPCDNodeResult]
    ) throws -> [SuperNeoPCDNodeResult] {
        guard parentNodeIndices.count <= maximumFanIn else {
            throw SuperNeoError.invalidParameter("PCD parent fan-in exceeds configured maximum")
        }
        guard parentNodeIndices.count == Set(parentNodeIndices).count else {
            throw SuperNeoError.invalidParameter("PCD parent indices must be unique")
        }
        return try parentNodeIndices.map { parentIndex in
            guard parentIndex >= 0, parentIndex < nodeIndex else {
                throw SuperNeoError.invalidParameter("PCD parent index must refer to an earlier node")
            }
            guard let parent = nodes.first(where: { $0.nodeIndex == parentIndex }) else {
                throw SuperNeoError.invalidParameter("PCD parent node was not produced")
            }
            return parent
        }
    }

    private static func makePCDParentSetBinding(
        nodeIndex: Int,
        parentNodeIndices: [Int],
        parentStates: [SuperNeoRecursiveVerifierState],
        parentStatements: [CCSStatement]
    ) throws -> SuperNeoPCDParentSetBinding? {
        guard !parentNodeIndices.isEmpty else { return nil }
        guard parentStatements.count == parentStates.count else {
            throw SuperNeoError.invalidParameter("PCD parent binding statement count mismatch")
        }
        let tupleBindings = try zip(parentNodeIndices.indices, zip(parentNodeIndices, zip(parentStates, parentStatements))).map { item in
            let position = item.0
            let parentNodeIndex = item.1.0
            let parentState = item.1.1.0
            let parentStatement = item.1.1.1
            return try SuperNeoPCDParentTupleBinding(
                parentPosition: position,
                parentNodeIndex: parentNodeIndex,
                parentDepth: parentState.depth,
                parentStateDigest: parentState.stateDigest,
                parentAccumulator: parentState.accumulator,
                parentPublicStatementDigest: parentStatement.statementDigest,
                parentRecursiveRelationDigest: parentState.recursiveRelationDigest
            )
        }
        return try SuperNeoPCDParentSetBinding(
            nodeIndex: nodeIndex,
            parentNodeIndices: parentNodeIndices,
            parentStateDigests: parentStates.map(\.stateDigest),
            parentAccumulatorDigests: parentStates.map(\.accumulator.accumulatorDigest),
            parentTupleBindings: tupleBindings
        )
    }

    private static func terminalIndices(for nodes: [SuperNeoPCDNodeResult]) -> [Int] {
        let parentIndices = Set(nodes.flatMap(\.step.parentNodeIndices))
        return nodes.map(\.nodeIndex).filter { !parentIndices.contains($0) }
    }

    private static func pcdFinalRoot(terminalNodeIndices: [Int], nodes: [SuperNeoPCDNodeResult]) -> Digest256 {
        let terminalNodes = terminalNodeIndices.compactMap { index in
            nodes.first(where: { $0.nodeIndex == index })
        }
        return Digest256.hash(
            Array("SuperNeo-NuMetal.superneo-pcd.final-root.v1".utf8)
                + superNeoCompilerEncodeCount(terminalNodeIndices.count)
                + terminalNodeIndices.flatMap(superNeoCompilerEncodeCount)
                + terminalNodes.flatMap { node in
                    node.step.verifierState.stateDigest.superNeoBytes
                        + node.step.outputAccumulator.accumulatorDigest.superNeoBytes
                }
        )
    }
}

private func superNeoPublicClaim(_ claim: CCSEvaluationClaim) -> CCSEvaluationClaim {
    CCSEvaluationClaim(
        commitment: claim.commitment,
        publicInput: claim.publicInput,
        point: claim.point,
        evaluations: claim.evaluations,
        witness: nil
    )
}

private func superNeoClaim(_ instance: CEInstance) -> CCSEvaluationClaim {
    CCSEvaluationClaim(
        commitment: instance.commitment,
        publicInput: instance.publicInput,
        point: instance.evalPoint,
        evaluations: instance.matrixEvals,
        witness: nil
    )
}

private func superNeoSamePublicClaims(_ lhs: [CCSEvaluationClaim], _ rhs: [CCSEvaluationClaim]) -> Bool {
    lhs.map(superNeoPublicClaim) == rhs.map(superNeoPublicClaim)
}

private func reductionBoundaryDigest(_ report: SuperNeoFoldReductionBoundaryReport) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.superneo-recursive-boundary-report.v1".utf8)
            + (report.preconditionFailureReason.map { [UInt8(1)] + superNeoCompilerEncodeString($0) } ?? [UInt8(0)])
            + superNeoCompilerChecksBytes(report.piCCSChecks)
            + superNeoCompilerChecksBytes(report.piRLCChecks)
            + superNeoCompilerChecksBytes(report.piDECChecks)
    )
}

private func superNeoCompilerChecksBytes(_ checks: [SuperNeoReductionBoundaryCheck]) -> [UInt8] {
    var bytes = superNeoCompilerEncodeCount(checks.count)
    for check in checks {
        bytes.append(contentsOf: Array(check.component.rawValue.utf8))
        bytes.append(0)
        bytes.append(contentsOf: Array(check.strength.rawValue.utf8))
        bytes.append(0)
        bytes.append(contentsOf: superNeoCompilerEncodeSignedInt(check.index))
        bytes.append(contentsOf: superNeoCompilerEncodeCount(check.inputClaimCount))
        bytes.append(contentsOf: superNeoCompilerEncodeCount(check.outputClaimCount))
        bytes.append(contentsOf: check.inputCommitmentProjectionDigest.superNeoBytes)
        bytes.append(contentsOf: check.outputCommitmentProjectionDigest.superNeoBytes)
        bytes.append(check.isAccepted ? 1 : 0)
        if let reason = check.reason {
            bytes.append(1)
            bytes.append(contentsOf: superNeoCompilerEncodeString(reason))
        } else {
            bytes.append(0)
        }
    }
    return bytes
}

private func superNeoCompilerEncodeString(_ value: String) -> [UInt8] {
    let bytes = Array(value.utf8)
    return superNeoCompilerEncodeCount(bytes.count) + bytes
}

private func superNeoCompilerEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func superNeoCompilerEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func superNeoCompilerEncodeSignedInt(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(bitPattern: Int64(value)).littleEndian, Array.init)
}
