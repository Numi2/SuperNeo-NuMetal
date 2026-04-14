import Dispatch
import Foundation
import Security

public struct DecompositionProof: Equatable, Sendable {
    public let commitments: [AjtaiCommitment]
    public let evaluations: [[CyclotomicExt2Ring54]]

    public init(commitments: [AjtaiCommitment], evaluations: [[CyclotomicExt2Ring54]]) {
        self.commitments = commitments
        self.evaluations = evaluations
    }
}

public struct PiCCSSection: Equatable, Sendable {
    public let sumCheck: SumcheckProof
    public let finalClaims: [CCSEvaluationClaim]

    public init(sumCheck: SumcheckProof, finalClaims: [CCSEvaluationClaim]) {
        self.sumCheck = sumCheck
        self.finalClaims = finalClaims.map(\.publicDataOnly)
    }
}

public struct PiRLCSection: Equatable, Sendable {
    public let challenges: [CyclotomicRing54]
    public let foldedClaim: CCSEvaluationClaim

    public init(challenges: [CyclotomicRing54], foldedClaim: CCSEvaluationClaim) {
        self.challenges = challenges
        self.foldedClaim = foldedClaim.publicDataOnly
    }
}

public struct PiDECSection: Equatable, Sendable {
    public let decomposition: DecompositionProof
    public let outputClaims: [CCSEvaluationClaim]

    public init(decomposition: DecompositionProof, outputClaims: [CCSEvaluationClaim]) {
        self.decomposition = decomposition
        self.outputClaims = outputClaims.map(\.publicDataOnly)
    }
}

public struct FoldStepProof: Equatable, Sendable {
    public let piCCS: PiCCSSection
    public let piRLC: PiRLCSection
    public let piDEC: PiDECSection

    public init(piCCS: PiCCSSection, piRLC: PiRLCSection, piDEC: PiDECSection) {
        self.piCCS = piCCS
        self.piRLC = piRLC
        self.piDEC = piDEC
    }

    public init(_ proof: FoldProof) {
        self.init(piCCS: proof.piCCS, piRLC: proof.piRLC, piDEC: proof.piDEC)
    }
}

public struct FoldProof: Equatable, Sendable {
    public let sumCheck: SumcheckProof
    public let randomLinearCombinationChallenges: [CyclotomicRing54]
    public let piCCSClaims: [CCSEvaluationClaim]
    public let foldedClaim: CCSEvaluationClaim
    public let decomposition: DecompositionProof
    public let outputClaims: [CCSEvaluationClaim]

    public init(
        sumCheck: SumcheckProof,
        randomLinearCombinationChallenges: [CyclotomicRing54],
        piCCSClaims: [CCSEvaluationClaim],
        foldedClaim: CCSEvaluationClaim,
        decomposition: DecompositionProof,
        outputClaims: [CCSEvaluationClaim]
    ) {
        self.sumCheck = sumCheck
        self.randomLinearCombinationChallenges = randomLinearCombinationChallenges
        self.piCCSClaims = piCCSClaims.map(\.publicDataOnly)
        self.foldedClaim = foldedClaim.publicDataOnly
        self.decomposition = decomposition
        self.outputClaims = outputClaims.map(\.publicDataOnly)
    }

    public init(piCCS: PiCCSSection, piRLC: PiRLCSection, piDEC: PiDECSection) {
        self.init(
            sumCheck: piCCS.sumCheck,
            randomLinearCombinationChallenges: piRLC.challenges,
            piCCSClaims: piCCS.finalClaims,
            foldedClaim: piRLC.foldedClaim,
            decomposition: piDEC.decomposition,
            outputClaims: piDEC.outputClaims
        )
    }

    public var piCCS: PiCCSSection {
        PiCCSSection(sumCheck: sumCheck, finalClaims: piCCSClaims)
    }

    public var piRLC: PiRLCSection {
        PiRLCSection(challenges: randomLinearCombinationChallenges, foldedClaim: foldedClaim)
    }

    public var piDEC: PiDECSection {
        PiDECSection(decomposition: decomposition, outputClaims: outputClaims)
    }

    public var stepProof: FoldStepProof {
        FoldStepProof(self)
    }
}

public struct FoldProverOutput: Equatable, Sendable {
    public let proof: FoldProof
    public let outputClaims: [CCSEvaluationClaim]

    public init(proof: FoldProof, outputClaims: [CCSEvaluationClaim]) {
        self.proof = proof
        self.outputClaims = outputClaims
    }
}

@_spi(Benchmarking) public struct SuperNeoPreparedFoldContext: Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let executionPolicy: SuperNeoExecutionPolicy
    public let compiledShape: CompiledCCSShape
    public let metalWorkspace: SuperNeoMetalWorkspace?

    init(
        profileID: UInt16,
        shapeDigest: Digest256,
        verifierKeyDigest: Digest256,
        executionPolicy: SuperNeoExecutionPolicy,
        compiledShape: CompiledCCSShape,
        metalWorkspace: SuperNeoMetalWorkspace?
    ) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.executionPolicy = executionPolicy
        self.compiledShape = compiledShape
        self.metalWorkspace = metalWorkspace
    }
}

@_spi(Benchmarking) public struct SuperNeoPreparedPiRLCTranscript: Sendable {
    fileprivate let transcriptAfterSumCheck: SumCheckTranscript
    public let sumCheckFinalPoint: [GoldilocksExt2]
    public let claimCount: Int

    fileprivate init(
        transcriptAfterSumCheck: SumCheckTranscript,
        sumCheckFinalPoint: [GoldilocksExt2],
        claimCount: Int
    ) {
        self.transcriptAfterSumCheck = transcriptAfterSumCheck
        self.sumCheckFinalPoint = sumCheckFinalPoint
        self.claimCount = claimCount
    }
}

public struct TerminalFoldProof: Equatable, Sendable {
    public let foldProof: FoldProof
    public let terminalStatement: TerminalCEStatement
    public let ceOpeningProof: CEOpeningProof

    public var outputClaims: [CCSEvaluationClaim] {
        terminalStatement.outputClaims
    }

    public init(
        foldProof: FoldProof,
        terminalStatement: TerminalCEStatement,
        ceOpeningProof: CEOpeningProof
    ) {
        self.foldProof = foldProof
        self.terminalStatement = terminalStatement
        self.ceOpeningProof = ceOpeningProof
    }
}

public struct FoldReductionResult: Equatable, Sendable {
    /// True only when the interactive fold reduction accepted.
    /// This is not a complete proof of the terminal CCS relation.
    public let isReductionAccepted: Bool
    public let reason: String?
    public let outputClaims: [CCSEvaluationClaim]
    /// Successful reductions always require a terminal CE relation check before
    /// an application can accept the original statement.
    public let requiresTerminalRelationCheck: Bool

    @available(*, unavailable, message: "A fold reduction is not a complete proof. Use isReductionAccepted, then verify terminal CE relation with verifyTerminalFold/verifyFold output claims.")
    public var isValid: Bool {
        isReductionAccepted && !requiresTerminalRelationCheck
    }

    public static func reduced(outputClaims: [CCSEvaluationClaim]) -> FoldReductionResult {
        FoldReductionResult(
            isReductionAccepted: true,
            reason: nil,
            outputClaims: outputClaims.map(\.publicDataOnly),
            requiresTerminalRelationCheck: true
        )
    }

    public static func invalid(_ reason: String) -> FoldReductionResult {
        FoldReductionResult(
            isReductionAccepted: false,
            reason: reason,
            outputClaims: [],
            requiresTerminalRelationCheck: false
        )
    }
}

public struct CEOpeningStatement: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let instance: CEInstance

    public var claim: CCSEvaluationClaim {
        CCSEvaluationClaim(
            commitment: instance.commitment,
            publicInput: instance.publicInput,
            point: instance.evalPoint,
            evaluations: instance.matrixEvals,
            witness: nil
        )
    }

    public init(profileID: UInt16, shapeDigest: Digest256, verifierKeyDigest: Digest256, instance: CEInstance) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.instance = instance
    }

    public init(profileID: UInt16, shape: CCSShape, key: AjtaiCommitmentKey, instance: CEInstance) {
        self.init(
            profileID: profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            instance: instance
        )
    }

    public init(profileID: UInt16, shapeDigest: Digest256, verifierKeyDigest: Digest256, claim: CCSEvaluationClaim) {
        self.init(
            profileID: profileID,
            shapeDigest: shapeDigest,
            verifierKeyDigest: verifierKeyDigest,
            instance: CEInstance(claim)
        )
    }

    public init(profileID: UInt16, shape: CCSShape, key: AjtaiCommitmentKey, claim: CCSEvaluationClaim) {
        self.init(
            profileID: profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            claim: claim
        )
    }
}

public struct TerminalCEStatement: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let openings: [CEOpeningStatement]

    public var outputClaims: [CCSEvaluationClaim] {
        openings.map(\.claim)
    }

    public init(profileID: UInt16, shapeDigest: Digest256, verifierKeyDigest: Digest256, openings: [CEOpeningStatement]) throws {
        guard openings.allSatisfy({ $0.profileID == profileID }) else {
            throw SuperNeoError.invalidParameter("terminal CE statement profile mismatch")
        }
        guard openings.allSatisfy({ $0.shapeDigest == shapeDigest }) else {
            throw SuperNeoError.invalidParameter("terminal CE statement shape mismatch")
        }
        guard openings.allSatisfy({ $0.verifierKeyDigest == verifierKeyDigest }) else {
            throw SuperNeoError.invalidParameter("terminal CE statement verifier key mismatch")
        }
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.verifierKeyDigest = verifierKeyDigest
        self.openings = openings
    }

    public init(profileID: UInt16, shape: CCSShape, key: AjtaiCommitmentKey, openings: [CEOpeningStatement]) throws {
        try self.init(
            profileID: profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            openings: openings
        )
    }

    public init(profileID: UInt16, shapeDigest: Digest256, verifierKeyDigest: Digest256, claims: [CCSEvaluationClaim]) throws {
        let openings = claims.map {
            CEOpeningStatement(
                profileID: profileID,
                shapeDigest: shapeDigest,
                verifierKeyDigest: verifierKeyDigest,
                claim: $0
            )
        }
        try self.init(
            profileID: profileID,
            shapeDigest: shapeDigest,
            verifierKeyDigest: verifierKeyDigest,
            openings: openings
        )
    }

    public init(profileID: UInt16, shape: CCSShape, key: AjtaiCommitmentKey, claims: [CCSEvaluationClaim]) throws {
        try self.init(
            profileID: profileID,
            shapeDigest: shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            claims: claims
        )
    }
}

public struct CEOpeningWitness: Equatable, Sendable {
    public let witness: [GoldilocksField]

    public init(_ witness: [GoldilocksField]) {
        self.witness = witness
    }

    public init?(claim: CCSEvaluationClaim) {
        guard let witness = claim.witness else { return nil }
        self.init(witness)
    }
}

public struct CEOpeningProofCommitments: Equatable, Sendable {
    public let maskLinearDigest: Digest256
    public let permutedMaskDigest: Digest256
    public let permutedMaskedWitnessDigest: Digest256

    public init(
        maskLinearDigest: Digest256,
        permutedMaskDigest: Digest256,
        permutedMaskedWitnessDigest: Digest256
    ) {
        self.maskLinearDigest = maskLinearDigest
        self.permutedMaskDigest = permutedMaskDigest
        self.permutedMaskedWitnessDigest = permutedMaskedWitnessDigest
    }
}

public struct CEOpeningLinearResponse: Equatable, Sendable {
    public let permutation: [Int]
    public let vector: [GoldilocksField]

    public init(permutation: [Int], vector: [GoldilocksField]) {
        self.permutation = permutation
        self.vector = vector
    }
}

public struct CEOpeningNormResponse: Equatable, Sendable {
    public let permutedMask: [GoldilocksField]
    public let permutedWitness: [GoldilocksField]

    public init(permutedMask: [GoldilocksField], permutedWitness: [GoldilocksField]) {
        self.permutedMask = permutedMask
        self.permutedWitness = permutedWitness
    }
}

public enum CEOpeningProofResponse: Equatable, Sendable {
    case mask([CEOpeningLinearResponse])
    case maskedWitness([CEOpeningLinearResponse])
    case permutedWitness([CEOpeningNormResponse])
}

public struct CEOpeningProofRound: Equatable, Sendable {
    public let commitments: [CEOpeningProofCommitments]
    public let response: CEOpeningProofResponse

    public init(commitments: [CEOpeningProofCommitments], response: CEOpeningProofResponse) {
        self.commitments = commitments
        self.response = response
    }
}

public struct CEOpeningProof: Equatable, Sendable {
    public static let roundCount = 219
    @available(*, unavailable, renamed: "roundCount", message: "CE opening proofs are canonical and must contain exactly roundCount rounds.")
    public static let minimumRoundCount = roundCount
    public let rounds: [CEOpeningProofRound]

    public init(rounds: [CEOpeningProofRound]) throws {
        guard rounds.count == Self.roundCount else {
            throw SuperNeoError.invalidParameter("CE opening proof must contain exactly \(Self.roundCount) Stern rounds")
        }
        self.rounds = rounds
    }
}

public enum CEOpeningRelation {
    private static let proofRoundCount = CEOpeningProof.roundCount
    private static let proofRoundBatchSize = 32

    public static func proveLocalBatch(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> CEOpeningProof {
        try proveLocalBatchImpl(
            statement: statement,
            witnesses: witnesses,
            shape: shape,
            key: key,
            parameters: parameters,
            randomnessSeed: try makeSystemRandomSeed(),
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
    }

    static func proveLocalBatchForTesting(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        randomSeed: [UInt8],
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> CEOpeningProof {
        try proveLocalBatchImpl(
            statement: statement,
            witnesses: witnesses,
            shape: shape,
            key: key,
            parameters: parameters,
            randomnessSeed: randomSeed,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
    }

    @_spi(Benchmarking) public static func proveLocalBatchDeterministic(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        randomSeed: [UInt8],
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> CEOpeningProof {
        try proveLocalBatchImpl(
            statement: statement,
            witnesses: witnesses,
            shape: shape,
            key: key,
            parameters: parameters,
            randomnessSeed: randomSeed,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
    }

    private static func proveLocalBatchImpl(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        randomnessSeed: [UInt8],
        metalWorkspace: SuperNeoMetalWorkspace?,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> CEOpeningProof {
        guard statement.profileID == parameters.profileID else {
            throw SuperNeoError.invalidParameter("terminal CE statement profile mismatch")
        }
        guard statement.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.invalidParameter("terminal CE statement shape mismatch")
        }
        guard statement.verifierKeyDigest == key.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("terminal CE statement verifier key mismatch")
        }
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("CE opening proof key parameters mismatch")
        }
        try validateCommitmentKey(key, matches: shape, role: "CE opening")
        guard statement.openings.count == witnesses.count, !witnesses.isEmpty else {
            throw SuperNeoError.invalidParameter("CE opening proof witness count mismatch")
        }

        let transformedMatrices = try shape.compiledSparseForSuperNeo().transformedSparseMatrices
        let privateWitnesses = try witnesses.map {
            try privateWitness(from: $0.witness, shape: shape)
        }
        try validatePrivateOpenings(
            statement: statement,
            witnesses: witnesses,
            privateWitnesses: privateWitnesses,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let proverContext = try CEOpeningPrivateLinearBatchContext(
            statement: statement,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        var rng = DeterministicRNG(seed: ceOpeningProverRandomSeed(
            randomnessSeed: randomnessSeed,
            statement: statement
        ))
        var transcript = makeCEOpeningTranscript(statement: statement)
        transcript.absorb(ceEncodeCount(Self.proofRoundCount))
        var rounds: [CEOpeningProofRound] = []
        rounds.reserveCapacity(Self.proofRoundCount)

        var roundStart = 0
        while roundStart < Self.proofRoundCount {
            let roundEnd = min(roundStart + Self.proofRoundBatchSize, Self.proofRoundCount)
            let batchedRounds = try makeProverRoundBatch(
                roundRange: roundStart..<roundEnd,
                privateWitnesses: privateWitnesses,
                statement: statement,
                proverContext: proverContext,
                rng: &rng
            )

            for roundMaterial in batchedRounds {
                transcript.absorb(roundMaterial.commitments.flatMap(\.superNeoBytes))
                let challenge = ceOpeningChallenge(transcript: &transcript)
                let response: CEOpeningProofResponse
                switch challenge {
                case 0:
                    response = .mask(roundMaterial.openings.map {
                        CEOpeningLinearResponse(permutation: $0.permutation, vector: $0.mask)
                    })
                case 1:
                    response = .maskedWitness(roundMaterial.openings.map {
                        CEOpeningLinearResponse(permutation: $0.permutation, vector: $0.masked)
                    })
                default:
                    response = .permutedWitness(roundMaterial.openings.enumerated().map { index, opening in
                        CEOpeningNormResponse(
                            permutedMask: opening.permutedMask,
                            permutedWitness: applyPermutation(privateWitnesses[index], opening.permutation)
                        )
                    })
                }
                transcript.absorb(response.superNeoBytes)
                rounds.append(CEOpeningProofRound(commitments: roundMaterial.commitments, response: response))
            }
            roundStart = roundEnd
        }

        return try CEOpeningProof(rounds: rounds)
    }

    public static func verify(
        proof: CEOpeningProof,
        statement: TerminalCEStatement,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard statement.verifierKeyDigest == key.verifierKeyDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard key.matrix.columns == shape.nRing else { return false }
        guard !statement.openings.isEmpty else { return false }
        guard proof.rounds.count == CEOpeningProof.roundCount else { return false }
        guard statement.openings.allSatisfy({
            $0.instance.publicInput.allSatisfy { signedMagnitude($0) < UInt64(parameters.normBound) }
        }) else {
            return false
        }

        let transformedMatrices = try shape.compiledSparseForSuperNeo().transformedSparseMatrices
        let verifierContext = try SuperNeoBenchmarkSignpost.measure("ceVerifyPrepare") {
            try CEOpeningVerifierContext(
                statement: statement,
                shape: shape,
                key: key,
                transformedMatrices: transformedMatrices,
                metalWorkspace: metalWorkspace,
                parameters: parameters,
                executionPolicy: executionPolicy
            )
        }
        return try verifyBatchedProofResponses(
            proof: proof,
            statement: statement,
            verifierContext: verifierContext
        )
    }

    public static func verifyLocal(
        statement: CEOpeningStatement,
        witness: CEOpeningWitness,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard statement.verifierKeyDigest == key.verifierKeyDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard key.matrix.columns == shape.nRing else { return false }
        let transformedMatrices = try shape.compiledSparseForSuperNeo().transformedSparseMatrices
        return try verifyLocal(
            statement: statement,
            witness: witness,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    private static func verifyLocal(
        statement: CEOpeningStatement,
        witness: CEOpeningWitness,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard statement.verifierKeyDigest == key.verifierKeyDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard key.matrix.columns == shape.nRing else { return false }
        let openedClaim = CCSEvaluationClaim(
            commitment: statement.instance.commitment,
            publicInput: statement.instance.publicInput,
            point: statement.instance.evalPoint,
            evaluations: statement.instance.matrixEvals,
            witness: witness.witness
        )
        return try SuperNeoProtocolOracle.verifyEvaluationClaimOpenings(
            shape: shape,
            transformedMatrices: transformedMatrices,
            claims: [openedClaim],
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    public static func verifyLocalBatch(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        try verifyLocalBatchOpenings(
            statement: statement,
            witnesses: witnesses,
            shape: shape,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy,
            requireTerminalDecompositionCount: false
        )
    }

    public static func verifyTerminalLocalBatch(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        try verifyLocalBatchOpenings(
            statement: statement,
            witnesses: witnesses,
            shape: shape,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy,
            requireTerminalDecompositionCount: true
        )
    }

    private static func verifyLocalBatchOpenings(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy,
        requireTerminalDecompositionCount: Bool
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard statement.verifierKeyDigest == key.verifierKeyDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard key.matrix.columns == shape.nRing else { return false }
        guard statement.openings.count == witnesses.count else { return false }
        guard !statement.openings.isEmpty else { return false }
        if requireTerminalDecompositionCount {
            guard statement.openings.count == parameters.decompositionLength else { return false }
        }

        let transformedMatrices = try shape.compiledSparseForSuperNeo().transformedSparseMatrices
        let openedClaims = zip(statement.openings, witnesses).map { opening, witness in
            CCSEvaluationClaim(
                commitment: opening.instance.commitment,
                publicInput: opening.instance.publicInput,
                point: opening.instance.evalPoint,
                evaluations: opening.instance.matrixEvals,
                witness: witness.witness
            )
        }
        return try SuperNeoProtocolOracle.verifyEvaluationClaimOpenings(
            shape: shape,
            transformedMatrices: transformedMatrices,
            claims: openedClaims,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }
}

public struct SuperNeoPublicFoldInput: Sendable {
    public let shape: CCSShape
    public let structure: CCSStructure
    public let instances: [CCSInstance]
    public let priorClaims: [CCSEvaluationClaim]

    public init(
        shape: CCSShape,
        instances: [CCSInstance],
        priorClaims: [CCSEvaluationClaim] = []
    ) {
        self.shape = shape
        self.structure = shape.structure
        self.instances = instances
        self.priorClaims = priorClaims.map(\.publicDataOnly)
    }

    public init(_ input: SuperNeoFoldInput) {
        self.init(
            shape: input.shape,
            instances: input.instances,
            priorClaims: input.priorClaims
        )
    }
}

public struct SuperNeoFoldInput: Sendable {
    public let shape: CCSShape
    public let structure: CCSStructure
    public let instances: [CCSInstance]
    public let witnesses: [CCSWitness]
    public let priorClaims: [CCSEvaluationClaim]

    public init(
        shape: CCSShape,
        instances: [CCSInstance],
        witnesses: [CCSWitness],
        priorClaims: [CCSEvaluationClaim] = []
    ) {
        self.shape = shape
        self.structure = shape.structure
        self.instances = instances
        self.witnesses = witnesses
        self.priorClaims = priorClaims
    }

    public init(
        structure: CCSStructure,
        instances: [CCSInstance],
        witnesses: [CCSWitness],
        priorClaims: [CCSEvaluationClaim] = []
    ) throws {
        guard let relationPolynomial = structure.relationPolynomial else {
            throw SuperNeoError.invalidParameter("fold input requires a serializable CCS relation polynomial")
        }
        let publicInputCount = instances.first?.publicInput.count ?? 0
        try SuperNeoFoldingShapeContract.paperNormalized.validate(
            structure,
            publicInputCount: publicInputCount
        )
        let shape = try CCSShape(
            matrices: structure.matrices,
            publicInputCount: publicInputCount,
            relationPolynomial: relationPolynomial
        )
        try SuperNeoFoldingShapeContract.paperNormalized.validate(shape)
        self.shape = shape
        self.structure = shape.structure
        self.instances = instances
        self.witnesses = witnesses
        self.priorClaims = priorClaims
    }
}

public struct CCSQOracle: SumcheckOracle {
    public let numVars: Int
    public let maxDegreePerRound: Int
    public let alpha: [GoldilocksExt2]
    public let gamma: GoldilocksExt2

    private let shape: CCSShape
    private let freshCount: Int
    private let priorCount: Int
    private let priorClaims: [CCSEvaluationClaim]
    private let relationSourceEvaluator: RelationSourceEvaluationPlan
    private let freshRelationMatrixRows: [[[GoldilocksField]]]
    private let allWitnessRows: [[GoldilocksField]]
    private let priorTransformedRows: [[[CyclotomicRing54]]]
    private let priorEvalPoint: [GoldilocksExt2]?
    private let normEvaluator: NormEvaluationPlan
    private let gammaPowers: [GoldilocksExt2]
    private let samplePoints: [GoldilocksExt2]
    private let polynomialInterpolator: QPolynomialInterpolator

    public init(
        shape: CCSShape,
        instances: [CCSInstance],
        witnesses: [CCSWitness],
        priorClaims: [CCSEvaluationClaim],
        alpha: [GoldilocksExt2],
        gamma: GoldilocksExt2,
        transformedSparseMatrices: [SparseRingMatrixCSR]? = nil,
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws {
        guard instances.count == witnesses.count else {
            throw SuperNeoError.invalidParameter("Q oracle instances and witnesses must have the same count")
        }
        let numVars = try log2Exact(shape.m)
        guard alpha.count == numVars else {
            throw SuperNeoError.invalidParameter("Q oracle alpha length must match log2(m)")
        }
        guard parameters.normBound >= 2 else {
            throw SuperNeoError.invalidParameter("norm bound must be at least two")
        }
        try SuperNeoFoldingShapeContract.paperNormalized.validate(shape)
        let freshWitnesses = zip(instances, witnesses).map { instance, witness in
            witness.fullZ(for: instance)
        }
        for witness in freshWitnesses {
            guard witness.count == shape.nField else {
                throw SuperNeoError.invalidParameter("Q oracle fresh witness length must match shape.nField")
            }
        }
        let priorWitnesses = try priorClaims.map { claim -> [GoldilocksField] in
            guard let witness = claim.witness else {
                throw SuperNeoError.invalidParameter("Q oracle requires prior CE witnesses on prover side")
            }
            guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
                throw SuperNeoError.invalidParameter("Q oracle prior witness length must match the original or padded ring length")
            }
            guard claim.point.count == numVars else {
                throw SuperNeoError.invalidParameter("Q oracle prior evaluation point length mismatch")
            }
            guard claim.evaluations.count == shape.numMatrices else {
                throw SuperNeoError.invalidParameter("Q oracle prior evaluation arity mismatch")
            }
            return witness
        }
        if let firstPriorPoint = priorClaims.first?.point {
            for claim in priorClaims {
                guard claim.point == firstPriorPoint else {
                    throw SuperNeoError.invalidParameter("Q oracle prior CE claims must use the same evaluation point")
                }
            }
        }
        let maxDegreePerRound = try piCCSMaxDegreePerRound(shape: shape, parameters: parameters)
        let relationSourceEvaluator = try RelationSourceEvaluationPlan(
            polynomial: shape.relationPolynomial,
            matrices: shape.matrices
        )
        let relationSourceMatrices = try relationSourceEvaluator.sourceVariableIndices.map {
            try shape.matrices[$0].toSparseFieldMatrix()
        }
        var freshRelationMatrixRows = Array(
            repeating: Array(repeating: [GoldilocksField](), count: relationSourceMatrices.count),
            count: freshWitnesses.count
        )
        for (witnessIndex, witness) in freshWitnesses.enumerated() {
            for (sourceIndex, matrix) in relationSourceMatrices.enumerated() {
                freshRelationMatrixRows[witnessIndex][sourceIndex] = try matrix.multiplied(by: witness)
            }
        }
        let allWitnessRows = freshWitnesses + priorWitnesses
        let priorTransformedRows: [[[CyclotomicRing54]]]
        if priorWitnesses.isEmpty {
            priorTransformedRows = []
        } else {
            let transformedMatrices = try transformedSparseMatrices ?? shape.compiledSparseForSuperNeo().transformedSparseMatrices
            priorTransformedRows = try priorWitnesses.map { witness in
                let packedWitness = try packedEvaluationWitness(witness, shape: shape)
                return try transformedMatrices.map { matrix in
                    if executionPolicy.usesConstantWorkCPU {
                        return try matrix.multipliedConstantWork(by: packedWitness)
                    }
                    return try matrix.multiplied(by: packedWitness)
                }
            }
        }
        let maxPriorExponent = max(0, priorClaims.count * shape.numMatrices * CyclotomicRing54.degree - 1)
        let maxQExponent = max((2 * freshWitnesses.count) + priorClaims.count, maxPriorExponent)

        self.shape = shape
        self.freshCount = freshWitnesses.count
        self.priorCount = priorClaims.count
        self.priorClaims = priorClaims
        self.relationSourceEvaluator = relationSourceEvaluator
        self.alpha = alpha
        self.gamma = gamma
        self.numVars = numVars
        self.maxDegreePerRound = maxDegreePerRound
        self.freshRelationMatrixRows = freshRelationMatrixRows
        self.allWitnessRows = allWitnessRows
        self.priorTransformedRows = priorTransformedRows
        self.priorEvalPoint = priorClaims.first?.point
        self.normEvaluator = NormEvaluationPlan(roots: parameters.normRoots)
        self.gammaPowers = try makeGammaPowers(gamma, through: maxQExponent)
        let samplePoints = (0...maxDegreePerRound).map { GoldilocksExt2(GoldilocksField(UInt64($0))) }
        self.samplePoints = samplePoints
        self.polynomialInterpolator = try QPolynomialInterpolator(samplePoints: samplePoints)
    }

    public func claimedSumFromPriorClaims() throws -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        guard priorCount > 0 else { return .zero }
        for priorIndex in priorClaims.indices {
            let claim = priorClaims[priorIndex]
            for matrixIndex in claim.evaluations.indices {
                for coeffIndex in 0..<CyclotomicRing54.degree {
                    let exponent = priorExponent(priorIndex: priorIndex, matrixIndex: matrixIndex, coefficientIndex: coeffIndex)
                    total = total + power(exponent) * claim.evaluations[matrixIndex].coefficients[coeffIndex]
                }
            }
        }
        // The sum-check claim is over Q itself. Q contains gamma^(2K+k) * Eval,
        // so the prior-evaluation contribution must be scaled here as well.
        return power((2 * freshCount) + priorCount) * total
    }

    public mutating func roundPolynomial(prefix: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
        guard prefix.count < numVars else {
            throw SuperNeoError.invalidParameter("sum-check prefix is already complete")
        }
        let values = try samplePoints.map { sample in
            try partialHypercubeSum(fixedPrefix: prefix + [sample])
        }
        return try polynomialInterpolator.interpolate(values: values)
    }

    public mutating func finalEvaluation(point: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard point.count == numVars else {
            throw SuperNeoError.invalidParameter("sum-check final point length mismatch")
        }
        return try partialHypercubeSum(fixedPrefix: point)
    }

    private func partialHypercubeSum(fixedPrefix: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard fixedPrefix.count <= numVars else {
            throw SuperNeoError.invalidParameter("sum-check prefix is longer than variable count")
        }
        let remaining = numVars - fixedPrefix.count
        guard remaining < Int.bitWidth - 1, fixedPrefix.count < Int.bitWidth - 1 else {
            throw SuperNeoError.invalidParameter("sum-check hypercube is too large for CPU oracle")
        }
        let prefixWeights = multilinearBasisWeights(fixedPrefix)
        let prefixWidth = prefixWeights.count
        let alphaFixedEq = try fixedPrefixEq(fixedPrefix, target: alpha)
        let suffixCount = 1 << remaining
        let alphaSuffixEq = try suffixEqWeights(
            fixedEq: alphaFixedEq,
            target: alpha,
            fixedCount: fixedPrefix.count
        )
        let priorSuffixEq: [GoldilocksExt2]?
        if let priorEvalPoint {
            priorSuffixEq = try suffixEqWeights(
                fixedEq: try fixedPrefixEq(fixedPrefix, target: priorEvalPoint),
                target: priorEvalPoint,
                fixedCount: fixedPrefix.count
            )
        } else {
            priorSuffixEq = nil
        }
        let priorSuffixCount = priorSuffixEq?.count ?? suffixCount
        guard alphaSuffixEq.count == suffixCount, priorSuffixCount == suffixCount else {
            throw SuperNeoError.invalidParameter("sum-check suffix equality table length mismatch")
        }
        var total = GoldilocksExt2.zero
        for suffixBits in 0..<suffixCount {
            total = total + (try evaluateQ(
                suffixBits: suffixBits,
                fixedCount: fixedPrefix.count,
                prefixWidth: prefixWidth,
                prefixWeights: prefixWeights,
                alphaEq: alphaSuffixEq[suffixBits],
                priorEq: priorSuffixEq?[suffixBits]
            ))
        }
        return total
    }

    private func evaluateQ(
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2],
        alphaEq: GoldilocksExt2,
        priorEq: GoldilocksExt2?
    ) throws -> GoldilocksExt2 {
        let f = try evaluateF(suffixBits: suffixBits, fixedCount: fixedCount, prefixWidth: prefixWidth, prefixWeights: prefixWeights)
        let norm = evaluateNorm(suffixBits: suffixBits, fixedCount: fixedCount, prefixWidth: prefixWidth, prefixWeights: prefixWeights)
        let eval = try evaluatePriorClaims(priorEq: priorEq, suffixBits: suffixBits, fixedCount: fixedCount, prefixWidth: prefixWidth, prefixWeights: prefixWeights)
        return alphaEq * (f + power(freshCount) * norm)
            + power((2 * freshCount) + priorCount) * eval
    }

    private func evaluateF(
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        guard !relationSourceEvaluator.isZero else { return .zero }
        var total = GoldilocksExt2.zero
        for witnessIndex in 0..<freshCount {
            var sourceValues = Array(
                repeating: GoldilocksExt2.zero,
                count: relationSourceEvaluator.sourceVariableIndices.count
            )
            for sourceIndex in freshRelationMatrixRows[witnessIndex].indices {
                sourceValues[sourceIndex] = weightedRowEvaluation(
                    rows: freshRelationMatrixRows[witnessIndex][sourceIndex],
                    suffixBits: suffixBits,
                    fixedCount: fixedCount,
                    prefixWidth: prefixWidth,
                    prefixWeights: prefixWeights
                )
            }
            let relationValue = try relationSourceEvaluator.evaluate(sourceValues: sourceValues)
            total = total + power(witnessIndex) * relationValue
        }
        return total
    }

    private func evaluateNorm(
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        for witnessIndex in allWitnessRows.indices {
            let zAtPoint = weightedRowEvaluation(
                rows: allWitnessRows[witnessIndex],
                suffixBits: suffixBits,
                fixedCount: fixedCount,
                prefixWidth: prefixWidth,
                prefixWeights: prefixWeights
            )
            total = total + power(witnessIndex) * normEvaluator.evaluate(zAtPoint)
        }
        return total
    }

    private func evaluatePriorClaims(
        priorEq: GoldilocksExt2?,
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        guard let priorEq else { return .zero }
        var total = GoldilocksExt2.zero
        var coefficientEvaluations = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for priorIndex in 0..<priorCount {
            for matrixIndex in 0..<shape.numMatrices {
                weightedRingCoefficientEvaluations(
                    rows: priorTransformedRows[priorIndex][matrixIndex],
                    suffixBits: suffixBits,
                    fixedCount: fixedCount,
                    prefixWidth: prefixWidth,
                    prefixWeights: prefixWeights,
                    into: &coefficientEvaluations
                )
                for coeffIndex in 0..<CyclotomicRing54.degree {
                    let exponent = priorExponent(priorIndex: priorIndex, matrixIndex: matrixIndex, coefficientIndex: coeffIndex)
                    total = total + power(exponent) * coefficientEvaluations[coeffIndex]
                }
            }
        }
        return priorEq * total
    }

    private func fixedPrefixEq(
        _ fixedPrefix: [GoldilocksExt2],
        target: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        guard fixedPrefix.count <= target.count else {
            throw SuperNeoError.invalidParameter("sum-check fixed prefix is longer than equality target")
        }
        var result = GoldilocksExt2.one
        for index in fixedPrefix.indices {
            let ab = fixedPrefix[index] * target[index]
            result = result * (.one - fixedPrefix[index] - target[index] + ab + ab)
        }
        return result
    }

    private func suffixEqWeights(
        fixedEq: GoldilocksExt2,
        target: [GoldilocksExt2],
        fixedCount: Int
    ) throws -> [GoldilocksExt2] {
        guard fixedCount <= target.count else {
            throw SuperNeoError.invalidParameter("sum-check fixed prefix is longer than equality target")
        }
        var weights = [fixedEq]
        for index in fixedCount..<target.count {
            let oldCount = weights.count
            weights.append(contentsOf: repeatElement(.zero, count: oldCount))
            let highWeight = target[index]
            let lowWeight = GoldilocksExt2.one - highWeight
            for weightIndex in 0..<oldCount {
                let previous = weights[weightIndex]
                weights[weightIndex] = previous * lowWeight
                weights[weightIndex + oldCount] = previous * highWeight
            }
        }
        return weights
    }

    private func weightedRowEvaluation(
        rows: [GoldilocksField],
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        let suffixBase = suffixBits << fixedCount
        for prefixBits in 0..<prefixWidth {
            let row = suffixBase | prefixBits
            total = total + prefixWeights[prefixBits].scaled(by: rows[row])
        }
        return total
    }

    private func weightedRingCoefficientEvaluations(
        rows: [CyclotomicRing54],
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2],
        into coefficients: inout [GoldilocksExt2]
    ) {
        for coefficientIndex in 0..<CyclotomicRing54.degree {
            coefficients[coefficientIndex] = .zero
        }
        let suffixBase = suffixBits << fixedCount
        for prefixBits in 0..<prefixWidth {
            let row = suffixBase | prefixBits
            let weight = prefixWeights[prefixBits]
            let rowCoefficients = rows[row].coefficients
            for coefficientIndex in 0..<CyclotomicRing54.degree {
                coefficients[coefficientIndex] = coefficients[coefficientIndex]
                    + weight.scaled(by: rowCoefficients[coefficientIndex])
            }
        }
    }

    private func priorExponent(priorIndex: Int, matrixIndex: Int, coefficientIndex: Int) -> Int {
        priorIndex + priorCount * matrixIndex + priorCount * shape.numMatrices * coefficientIndex
    }

    private func power(_ exponent: Int) -> GoldilocksExt2 {
        gammaPowers[exponent]
    }
}

private struct PublicQVerifierState {
    let numVars: Int
    let maxDegreePerRound: Int
    let alpha: [GoldilocksExt2]
    let gamma: GoldilocksExt2

    private let shape: CCSShape
    private let freshCount: Int
    private let priorCount: Int
    private let priorEvalPoint: [GoldilocksExt2]?
    private let relationEvaluator: RelationEvaluationPlan
    private let normEvaluator: NormEvaluationPlan
    private let gammaPowers: [GoldilocksExt2]

    init(
        shape: CCSShape,
        freshCount: Int,
        priorClaims: [CCSEvaluationClaim],
        alpha: [GoldilocksExt2],
        gamma: GoldilocksExt2,
        parameters: SuperNeoParameters
    ) throws {
        let numVars = try log2Exact(shape.m)
        guard alpha.count == numVars else {
            throw SuperNeoError.invalidParameter("public Q verifier alpha length must match log2(m)")
        }
        try SuperNeoFoldingShapeContract.paperNormalized.validate(shape)
        guard parameters.normBound >= 2 else {
            throw SuperNeoError.invalidParameter("norm bound must be at least two")
        }
        if let firstPriorPoint = priorClaims.first?.point {
            for claim in priorClaims {
                guard claim.point == firstPriorPoint else {
                    throw SuperNeoError.invalidParameter("prior CE claims must use the same evaluation point")
                }
            }
        }

        let priorCount = priorClaims.count
        let maxPriorExponent = max(0, priorCount * shape.numMatrices * CyclotomicRing54.degree - 1)
        let maxQExponent = max((2 * freshCount) + priorCount, maxPriorExponent)

        self.shape = shape
        self.freshCount = freshCount
        self.priorCount = priorCount
        self.priorEvalPoint = priorClaims.first?.point
        self.relationEvaluator = try RelationEvaluationPlan(
            polynomial: shape.relationPolynomial,
            variableCount: shape.numMatrices
        )
        self.alpha = alpha
        self.gamma = gamma
        self.numVars = numVars
        self.maxDegreePerRound = try piCCSMaxDegreePerRound(shape: shape, parameters: parameters)
        self.normEvaluator = NormEvaluationPlan(roots: parameters.normRoots)
        self.gammaPowers = try makeGammaPowers(gamma, through: maxQExponent)
    }

    func claimedSum(from priorClaims: [CCSEvaluationClaim]) throws -> GoldilocksExt2 {
        guard priorClaims.count == priorCount else {
            throw SuperNeoError.invalidParameter("prior claim count changed after public Q challenge derivation")
        }
        var total = GoldilocksExt2.zero
        for priorIndex in priorClaims.indices {
            let claim = priorClaims[priorIndex]
            guard claim.evaluations.count == shape.numMatrices else {
                throw SuperNeoError.invalidParameter("prior CE claim evaluation arity mismatch")
            }
            for matrixIndex in claim.evaluations.indices {
                for coeffIndex in 0..<CyclotomicRing54.degree {
                    let exponent = priorExponent(
                        priorIndex: priorIndex,
                        matrixIndex: matrixIndex,
                        coefficientIndex: coeffIndex
                    )
                    total = total + power(exponent) * claim.evaluations[matrixIndex].coefficients[coeffIndex]
                }
            }
        }
        // The sum-check claim is over Q itself. Q contains gamma^(2K+k) * Eval,
        // so the prior-evaluation contribution must be scaled here as well.
        return power((2 * freshCount) + priorCount) * total
    }

    func finalEvaluation(
        instances: [CCSInstance],
        priorClaims: [CCSEvaluationClaim],
        proofClaims: [CCSEvaluationClaim],
        point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        try validateProofClaims(
            instances: instances,
            priorClaims: priorClaims,
            proofClaims: proofClaims,
            point: point
        )
        let f = try evaluateF(proofClaims: proofClaims)
        let norm = try evaluateNorm(proofClaims: proofClaims)
        let eval = try evaluatePriorClaims(proofClaims: proofClaims, point: point)
        return try MultilinearEvaluation.eq(point, alpha)
            * (f + power(freshCount) * norm)
            + power((2 * freshCount) + priorCount) * eval
    }

    private func validateProofClaims(
        instances: [CCSInstance],
        priorClaims: [CCSEvaluationClaim],
        proofClaims: [CCSEvaluationClaim],
        point: [GoldilocksExt2]
    ) throws {
        guard instances.count == freshCount, priorClaims.count == priorCount else {
            throw SuperNeoError.invalidParameter("public Q verifier input count mismatch")
        }
        guard point.count == numVars else {
            throw SuperNeoError.invalidParameter("public Q final point length mismatch")
        }
        guard proofClaims.count == freshCount + priorCount else {
            throw SuperNeoError.invalidParameter("proof PiCCS final claim count mismatch")
        }
        for (index, claim) in proofClaims.enumerated() {
            guard claim.point == point else {
                throw SuperNeoError.invalidParameter("proof PiCCS final claim point mismatch at index \(index)")
            }
            guard claim.publicInput.count == shape.nPublicField else {
                throw SuperNeoError.invalidParameter("proof PiCCS public input length mismatch at index \(index)")
            }
            guard claim.evaluations.count == shape.numMatrices else {
                throw SuperNeoError.invalidParameter("proof PiCCS evaluation arity mismatch at index \(index)")
            }
        }
        for index in 0..<freshCount {
            guard proofClaims[index].commitment == instances[index].commitment,
                  proofClaims[index].publicInput == instances[index].publicInput else {
                throw SuperNeoError.invalidParameter("fresh PiCCS final claim does not match public instance at index \(index)")
            }
        }
        for priorIndex in 0..<priorCount {
            let proofIndex = freshCount + priorIndex
            guard proofClaims[proofIndex].commitment == priorClaims[priorIndex].commitment,
                  proofClaims[proofIndex].publicInput == priorClaims[priorIndex].publicInput else {
                throw SuperNeoError.invalidParameter("prior PiCCS final claim does not match prior CE claim at index \(priorIndex)")
            }
        }
    }

    private func evaluateF(proofClaims: [CCSEvaluationClaim]) throws -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        let referencedVariables = relationEvaluator.referencedVariableIndices
        for witnessIndex in 0..<freshCount {
            var relationValues = Array(repeating: GoldilocksExt2.zero, count: referencedVariables.count)
            for valueIndex in relationValues.indices {
                let matrixIndex = referencedVariables[valueIndex]
                relationValues[valueIndex] = proofClaims[witnessIndex].evaluations[matrixIndex].constantTerm
            }
            let relationValue = try relationEvaluator.evaluate(referencedValues: relationValues)
            total = total + power(witnessIndex) * relationValue
        }
        return total
    }

    private func evaluateNorm(proofClaims: [CCSEvaluationClaim]) throws -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        for witnessIndex in proofClaims.indices {
            guard let zAtPoint = proofClaims[witnessIndex].evaluations.first?.constantTerm else {
                throw SuperNeoError.invalidParameter("proof PiCCS claim is missing the identity-matrix evaluation")
            }
            total = total + power(witnessIndex) * normEvaluator.evaluate(zAtPoint)
        }
        return total
    }

    private func evaluatePriorClaims(
        proofClaims: [CCSEvaluationClaim],
        point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        guard let priorEvalPoint else { return .zero }
        let eq = try MultilinearEvaluation.eq(point, priorEvalPoint)
        var total = GoldilocksExt2.zero
        for priorIndex in 0..<priorCount {
            let claim = proofClaims[freshCount + priorIndex]
            for matrixIndex in 0..<shape.numMatrices {
                for coeffIndex in 0..<CyclotomicRing54.degree {
                    let exponent = priorExponent(
                        priorIndex: priorIndex,
                        matrixIndex: matrixIndex,
                        coefficientIndex: coeffIndex
                    )
                    total = total + power(exponent) * claim.evaluations[matrixIndex].coefficients[coeffIndex]
                }
            }
        }
        return eq * total
    }

    private func priorExponent(priorIndex: Int, matrixIndex: Int, coefficientIndex: Int) -> Int {
        priorIndex + priorCount * matrixIndex + priorCount * shape.numMatrices * coefficientIndex
    }

    private func power(_ exponent: Int) -> GoldilocksExt2 {
        gammaPowers[exponent]
    }
}

public final class SuperNeoProver: @unchecked Sendable {
    public let parameters: SuperNeoParameters
    public let key: AjtaiCommitmentKey
    public let context: MetalExecutionContext?
    public let executionPolicy: SuperNeoExecutionPolicy

    public init(
        parameters: SuperNeoParameters = .goldilocks,
        key: AjtaiCommitmentKey,
        context: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) {
        self.parameters = parameters
        self.key = key
        self.context = context
        self.executionPolicy = executionPolicy
    }

    public func fold(_ input: SuperNeoFoldInput, transcriptSeed: [UInt8] = []) throws -> FoldProof {
        try foldWithOutput(input, transcriptSeed: transcriptSeed).proof
    }

    @_spi(Benchmarking) public func prepareFoldContext(
        for input: SuperNeoFoldInput
    ) throws -> SuperNeoPreparedFoldContext {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("prover key parameters do not match prover parameters")
        }
        try validateCommitmentKey(key, matches: input.shape, role: "prover")
        try validateFoldInput(input, parameters: parameters)
        let compiledShape = try input.shape.compiledSparseForSuperNeo()
        let metalWorkspace = try makeMetalWorkspace(compiledShape: compiledShape)
        return SuperNeoPreparedFoldContext(
            profileID: parameters.profileID,
            shapeDigest: input.shape.shapeDigest,
            verifierKeyDigest: key.verifierKeyDigest,
            executionPolicy: executionPolicy,
            compiledShape: compiledShape,
            metalWorkspace: metalWorkspace
        )
    }

    @_spi(Benchmarking) public func preparePiRLCTranscript(
        input: SuperNeoFoldInput,
        sumCheck: SumcheckProof,
        claims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) throws -> SuperNeoPreparedPiRLCTranscript {
        try validateFoldInput(input, parameters: parameters)
        let publicInput = SuperNeoPublicFoldInput(input)
        var transcript = makeFoldTranscript(input: publicInput, transcriptSeed: transcriptSeed)
        let qState = try makePublicQState(input: publicInput, transcript: &transcript, parameters: parameters)
        guard sumCheck.claimedSum == (try qState.claimedSum(from: publicInput.priorClaims)) else {
            throw SuperNeoError.invalidParameter("sum-check claimed sum mismatch")
        }
        try replaySumCheckTranscript(
            sumCheck,
            into: &transcript,
            expectedDegree: qState.maxDegreePerRound,
            expectedRoundCount: qState.numVars
        )
        guard claims.count == publicInput.instances.count + publicInput.priorClaims.count else {
            throw SuperNeoError.invalidParameter("PiRLC claim count must match fold input")
        }
        guard claims.allSatisfy({ $0.point == sumCheck.finalPoint }) else {
            throw SuperNeoError.invalidParameter("PiRLC claims must use the sum-check final point")
        }
        guard try qState.finalEvaluation(
            instances: publicInput.instances,
            priorClaims: publicInput.priorClaims,
            proofClaims: claims,
            point: sumCheck.finalPoint
        ) == sumCheck.finalValue else {
            throw SuperNeoError.invalidParameter("sum-check final value mismatch")
        }
        return SuperNeoPreparedPiRLCTranscript(
            transcriptAfterSumCheck: transcript,
            sumCheckFinalPoint: sumCheck.finalPoint,
            claimCount: claims.count
        )
    }

    public func foldWithOutput(_ input: SuperNeoFoldInput, transcriptSeed: [UInt8] = []) throws -> FoldProverOutput {
        let preparedContext = try prepareFoldContext(for: input)
        return try foldWithOutput(
            input,
            transcriptSeed: transcriptSeed,
            preparedContext: preparedContext
        )
    }

    @_spi(Benchmarking) public func foldWithOutput(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = [],
        preparedContext: SuperNeoPreparedFoldContext
    ) throws -> FoldProverOutput {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("prover key parameters do not match prover parameters")
        }
        try validateCommitmentKey(key, matches: input.shape, role: "prover")
        try validateFoldInput(input, parameters: parameters)
        try validatePreparedFoldContext(preparedContext, shape: input.shape)

        let compiledShape = preparedContext.compiledShape
        let metalWorkspace = preparedContext.metalWorkspace

        var transcript = makeFoldTranscript(input: input, transcriptSeed: transcriptSeed)
        let sumCheck = try SuperNeoBenchmarkSignpost.measure("sumcheck") {
            try makeSumCheckProof(input: input, compiledShape: compiledShape, transcript: &transcript)
        }
        let piCCSClaims = try SuperNeoBenchmarkSignpost.measure("piCCSClaims") {
            try makePiCCSOutputClaims(
                input: input,
                point: sumCheck.finalPoint,
                compiledShape: compiledShape,
                metalWorkspace: metalWorkspace
            )
        }
        absorbEvaluationClaimBatch(piCCSClaims, into: &transcript)
        let rlc = try SuperNeoBenchmarkSignpost.measure("piRLC") {
            try randomLinearCombination(claims: piCCSClaims, transcript: &transcript)
        }
        let decomposition = try SuperNeoBenchmarkSignpost.measure("piDEC") {
            try decompose(
                rlc.foldedClaim,
                shape: input.shape,
                compiledShape: compiledShape,
                metalWorkspace: metalWorkspace
            )
        }
        let proof = FoldProof(
            sumCheck: sumCheck,
            randomLinearCombinationChallenges: rlc.challenges,
            piCCSClaims: piCCSClaims,
            foldedClaim: rlc.foldedClaim,
            decomposition: decomposition.proof,
            outputClaims: decomposition.claims
        )
        return FoldProverOutput(proof: proof, outputClaims: decomposition.claims)
    }

    private func validatePreparedFoldContext(
        _ preparedContext: SuperNeoPreparedFoldContext,
        shape: CCSShape
    ) throws {
        guard preparedContext.profileID == parameters.profileID else {
            throw SuperNeoError.invalidParameter("prepared fold context profile mismatch")
        }
        guard preparedContext.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.invalidParameter("prepared fold context shape digest mismatch")
        }
        guard preparedContext.compiledShape.shape == shape else {
            throw SuperNeoError.invalidParameter("prepared fold context compiled shape mismatch")
        }
        guard preparedContext.compiledShape.transformedSparseMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("prepared fold context transformed matrix count mismatch")
        }
        guard preparedContext.verifierKeyDigest == key.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("prepared fold context verifier key digest mismatch")
        }
        guard preparedContext.executionPolicy == executionPolicy else {
            throw SuperNeoError.invalidParameter("prepared fold context execution policy mismatch")
        }

        let expectsMetalWorkspace = context != nil && !executionPolicy.usesConstantWorkCPU
        guard (preparedContext.metalWorkspace != nil) == expectsMetalWorkspace else {
            throw SuperNeoError.invalidParameter("prepared fold context Metal workspace availability mismatch")
        }
        guard let metalWorkspace = preparedContext.metalWorkspace else { return }
        guard let context else {
            throw SuperNeoError.invalidParameter("prepared fold context Metal workspace requires a Metal context")
        }
        guard metalWorkspace.context === context else {
            throw SuperNeoError.invalidParameter("prepared fold context Metal execution context mismatch")
        }
        guard metalWorkspace.key == key else {
            throw SuperNeoError.invalidParameter("prepared fold context Metal workspace key mismatch")
        }
        guard metalWorkspace.transformedMatrixCount == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("prepared fold context Metal workspace transformed matrix count mismatch")
        }
        if let workspaceShapeDigest = metalWorkspace.shapeDigest {
            guard workspaceShapeDigest == shape.shapeDigest else {
                throw SuperNeoError.invalidParameter("prepared fold context Metal workspace shape digest mismatch")
            }
        }
        let expectedDigest = SuperNeoMetalWorkspace.transformedMatricesDigest(
            for: preparedContext.compiledShape.transformedSparseMatrices
        )
        guard metalWorkspace.transformedMatricesDigest == expectedDigest else {
            throw SuperNeoError.invalidParameter("prepared fold context Metal workspace transformed matrix digest mismatch")
        }
    }

    public func foldEnvelope(_ input: SuperNeoFoldInput, context: ProofEnvelopeContext) throws -> FoldProofEnvelope {
        try validateEnvelopeContext(
            context,
            publicInput: SuperNeoPublicFoldInput(input),
            key: key,
            expectedKind: .foldReduction
        )
        let proof = try fold(input, transcriptSeed: context.transcriptBindingBytes)
        return try FoldProofEnvelope(context: context, proof: proof)
    }

    public func terminalFold(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = []
    ) throws -> TerminalFoldProof {
        try terminalFoldImpl(input, transcriptSeed: transcriptSeed, ceRandomSeed: nil)
    }

    func terminalFoldForTesting(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = [],
        ceRandomSeed: [UInt8]
    ) throws -> TerminalFoldProof {
        try terminalFoldImpl(input, transcriptSeed: transcriptSeed, ceRandomSeed: ceRandomSeed)
    }

    @_spi(Benchmarking) public func terminalFoldDeterministic(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = [],
        ceRandomSeed: [UInt8]
    ) throws -> TerminalFoldProof {
        try terminalFoldImpl(input, transcriptSeed: transcriptSeed, ceRandomSeed: ceRandomSeed)
    }

    private func terminalFoldImpl(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8],
        ceRandomSeed: [UInt8]?
    ) throws -> TerminalFoldProof {
        let components = try makeTerminalFoldComponents(
            input,
            transcriptSeed: transcriptSeed,
            ceRandomSeed: ceRandomSeed
        )
        return TerminalFoldProof(
            foldProof: components.foldProof,
            terminalStatement: components.terminalStatement,
            ceOpeningProof: components.ceOpeningProof
        )
    }

    private struct TerminalFoldComponents {
        let foldProof: FoldProof
        let terminalStatement: TerminalCEStatement
        let ceOpeningProof: CEOpeningProof
    }

    private func makeTerminalFoldComponents(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8],
        ceRandomSeed: [UInt8]?
    ) throws -> TerminalFoldComponents {
        let fold = try foldWithOutput(input, transcriptSeed: transcriptSeed)
        let terminalStatement = try TerminalCEStatement(
            profileID: parameters.profileID,
            shape: input.shape,
            key: key,
            claims: fold.outputClaims
        )
        let witnesses = try fold.outputClaims.map { claim -> CEOpeningWitness in
            guard let witness = CEOpeningWitness(claim: claim) else {
                throw SuperNeoError.invalidParameter("terminal CE proof requires prover-side output witnesses")
            }
            return witness
        }
        let metalWorkspace = try makeCEOpeningMetalWorkspace(shape: input.shape)
        let ceOpeningProof: CEOpeningProof
        if let ceRandomSeed {
            ceOpeningProof = try CEOpeningRelation.proveLocalBatchForTesting(
                statement: terminalStatement,
                witnesses: witnesses,
                shape: input.shape,
                key: key,
                parameters: parameters,
                randomSeed: ceRandomSeed,
                metalWorkspace: metalWorkspace,
                executionPolicy: executionPolicy
            )
        } else {
            ceOpeningProof = try CEOpeningRelation.proveLocalBatch(
                statement: terminalStatement,
                witnesses: witnesses,
                shape: input.shape,
                key: key,
                parameters: parameters,
                metalWorkspace: metalWorkspace,
                executionPolicy: executionPolicy
            )
        }
        return TerminalFoldComponents(
            foldProof: fold.proof,
            terminalStatement: terminalStatement,
            ceOpeningProof: ceOpeningProof
        )
    }

    public func terminalFoldEnvelope(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext
    ) throws -> TerminalFoldProofEnvelope {
        try terminalFoldEnvelopeImpl(input, context: context, ceRandomSeed: nil)
    }

    func terminalFoldEnvelopeForTesting(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]
    ) throws -> TerminalFoldProofEnvelope {
        try terminalFoldEnvelopeImpl(input, context: context, ceRandomSeed: ceRandomSeed)
    }

    @_spi(Benchmarking) public func terminalFoldEnvelopeDeterministic(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]
    ) throws -> TerminalFoldProofEnvelope {
        try terminalFoldEnvelopeImpl(input, context: context, ceRandomSeed: ceRandomSeed)
    }

    private func terminalFoldEnvelopeImpl(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]?
    ) throws -> TerminalFoldProofEnvelope {
        guard context.kind == .terminalLocal else {
            throw SuperNeoError.invalidParameter("terminal fold envelope context must be terminalLocal")
        }
        try validateEnvelopeContext(
            context,
            publicInput: SuperNeoPublicFoldInput(input),
            key: key,
            expectedKind: .terminalLocal
        )
        let proof = try terminalFoldImpl(
            input,
            transcriptSeed: context.transcriptBindingBytes,
            ceRandomSeed: ceRandomSeed
        )
        return try TerminalFoldProofEnvelope(context: context, proof: proof)
    }

    public func compressedTerminalFoldEnvelope(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext
    ) throws -> CompressedTerminalProofEnvelope {
        try compressedTerminalFoldEnvelopeImpl(input, context: context, ceRandomSeed: nil)
    }

    func compressedTerminalFoldEnvelopeForTesting(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]
    ) throws -> CompressedTerminalProofEnvelope {
        try compressedTerminalFoldEnvelopeImpl(input, context: context, ceRandomSeed: ceRandomSeed)
    }

    @_spi(Benchmarking) public func compressedTerminalFoldEnvelopeDeterministic(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]
    ) throws -> CompressedTerminalProofEnvelope {
        try compressedTerminalFoldEnvelopeImpl(input, context: context, ceRandomSeed: ceRandomSeed)
    }

    private func compressedTerminalFoldEnvelopeImpl(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]?
    ) throws -> CompressedTerminalProofEnvelope {
        guard context.kind == .compressedPublic else {
            throw SuperNeoError.invalidParameter("compressed terminal fold envelope context must be compressedPublic")
        }
        let publicInput = SuperNeoPublicFoldInput(input)
        try validateEnvelopeContext(
            context,
            publicInput: publicInput,
            key: key,
            expectedKind: .compressedPublic
        )
        let terminalContext = ProofEnvelopeContext(
            profileID: context.profileID,
            kind: .terminalLocal,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: context.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain
        )
        let terminal = try makeTerminalFoldComponents(
            input,
            transcriptSeed: terminalContext.transcriptBindingBytes,
            ceRandomSeed: ceRandomSeed
        )
        let statement = CompressedTerminalStatement(
            context: context,
            publicInputDigest: compressedPublicInputDigest(publicInput),
            terminalStatementDigest: terminal.terminalStatement.statementDigest,
            verifierKeyDigest: key.verifierKeyDigest
        )
        return try CompressedTerminalProofEnvelope(
            context: context,
            proof: CompressedTerminalProof(
                statement: statement,
                foldProof: terminal.foldProof,
                ceOpeningProof: terminal.ceOpeningProof
            )
        )
    }

    private func makeSumCheckProof(
        input: SuperNeoFoldInput,
        compiledShape: CompiledCCSShape? = nil,
        transcript: inout SumCheckTranscript
    ) throws -> SumcheckProof {
        let sparseMatrices = try compiledShape?.transformedSparseMatrices
            ?? input.shape.compiledSparseForSuperNeo().transformedSparseMatrices
        try validatePriorCEClaimWitnesses(
            input: input,
            key: key,
            transformedMatrices: sparseMatrices,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        var oracle = try makeQOracle(
            input: input,
            compiledShape: compiledShape,
            transcript: &transcript,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
        let claimedSum = try oracle.claimedSumFromPriorClaims()
        return try SumcheckProver.prove(oracle: &oracle, claimedSum: claimedSum, transcript: &transcript)
    }

    private func makePiCCSOutputClaims(input: SuperNeoFoldInput, point: [GoldilocksExt2]) throws -> [CCSEvaluationClaim] {
        let compiledShape = try input.shape.compiledSparseForSuperNeo()
        return try SuperNeoProtocolOracle.makePiCCSOutputClaims(
            input: input,
            key: key,
            compiledShape: compiledShape,
            metalWorkspace: try makeMetalWorkspace(compiledShape: compiledShape),
            point: point,
            executionPolicy: executionPolicy
        )
    }

    private func makePiCCSOutputClaims(
        input: SuperNeoFoldInput,
        point: [GoldilocksExt2],
        compiledShape: CompiledCCSShape,
        metalWorkspace: SuperNeoMetalWorkspace?
    ) throws -> [CCSEvaluationClaim] {
        try SuperNeoProtocolOracle.makePiCCSOutputClaims(
            input: input,
            key: key,
            compiledShape: compiledShape,
            metalWorkspace: metalWorkspace,
            point: point,
            executionPolicy: executionPolicy
        )
    }

    private func randomLinearCombination(
        claims: [CCSEvaluationClaim],
        transcript: inout SumCheckTranscript
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        let challenges = claims.map { _ in transcript.challengeRing() }
        return (
            try SuperNeoProtocolOracle.randomLinearCombination(
                claims: claims,
                challenges: challenges,
                executionPolicy: executionPolicy
            ),
            challenges
        )
    }

    private func decompose(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        let compiledShape = try shape.compiledSparseForSuperNeo()
        return try SuperNeoProtocolOracle.decompose(
            claim,
            shape: shape,
            key: key,
            compiledShape: compiledShape,
            metalWorkspace: try makeMetalWorkspace(compiledShape: compiledShape),
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    private func decompose(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape,
        compiledShape: CompiledCCSShape,
        metalWorkspace: SuperNeoMetalWorkspace?
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        try SuperNeoProtocolOracle.decompose(
            claim,
            shape: shape,
            key: key,
            compiledShape: compiledShape,
            metalWorkspace: metalWorkspace,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    private func makeMetalWorkspace(compiledShape: CompiledCCSShape) throws -> SuperNeoMetalWorkspace? {
        guard let context, !executionPolicy.usesConstantWorkCPU else { return nil }
        return try SuperNeoMetalWorkspace(
            context: context,
            key: key,
            compiledShape: compiledShape
        )
    }

    private func makeCEOpeningMetalWorkspace(shape: CCSShape) throws -> SuperNeoMetalWorkspace? {
        guard context != nil else { return nil }
        let compiledShape = try shape.compiledSparseForSuperNeo()
        return try makeMetalWorkspace(compiledShape: compiledShape)
    }
}

public final class SuperNeoVerifier: @unchecked Sendable {
    public let parameters: SuperNeoParameters
    public let key: AjtaiCommitmentKey
    public let context: MetalExecutionContext?
    public let executionPolicy: SuperNeoExecutionPolicy
    public static let terminalRelationCheckRequiredReason = "fold reduction output claims require a terminal CE relation check"

    public init(
        parameters: SuperNeoParameters = .goldilocks,
        key: AjtaiCommitmentKey,
        context: MetalExecutionContext? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) {
        self.parameters = parameters
        self.key = key
        self.context = context
        self.executionPolicy = executionPolicy
    }

    @available(*, deprecated, message: "Use reduceFold(...) for fold reductions, or verifyFold(..., outputClaims:) for terminal local verification.")
    public func verifyFold(input: SuperNeoFoldInput, proof: FoldProof, transcriptSeed: [UInt8] = []) -> VerificationResult {
        verifyFold(publicInput: SuperNeoPublicFoldInput(input), proof: proof, transcriptSeed: transcriptSeed)
    }

    @available(*, deprecated, message: "Use reduceFold(...) for fold reductions, or verifyFold(..., outputClaims:) for terminal local verification.")
    public func verifyFold(
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        let reduction = reduceFold(publicInput: publicInput, proof: proof, transcriptSeed: transcriptSeed)
        guard reduction.isReductionAccepted else {
            return .invalid(reduction.reason ?? "fold reduction verification failed")
        }
        return .invalid(Self.terminalRelationCheckRequiredReason)
    }

    public func verifyTerminalFold(
        input: SuperNeoFoldInput,
        proof: FoldProof,
        outputClaims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        verifyFold(input: input, proof: proof, outputClaims: outputClaims, transcriptSeed: transcriptSeed)
    }

    public func verifyTerminalFold(
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        outputClaims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        verifyFold(publicInput: publicInput, proof: proof, outputClaims: outputClaims, transcriptSeed: transcriptSeed)
    }

    public func verifyTerminalFold(
        input: SuperNeoFoldInput,
        proof: TerminalFoldProof,
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        verifyTerminalFold(
            publicInput: SuperNeoPublicFoldInput(input),
            proof: proof,
            transcriptSeed: transcriptSeed
        )
    }

    public func verifyTerminalFold(
        publicInput: SuperNeoPublicFoldInput,
        proof: TerminalFoldProof,
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        do {
            let reduction = reduceFold(
                publicInput: publicInput,
                proof: proof.foldProof,
                transcriptSeed: transcriptSeed
            )
            guard reduction.isReductionAccepted else {
                return .invalid(reduction.reason ?? "fold reduction verification failed")
            }
            guard proof.terminalStatement.profileID == parameters.profileID else {
                return .invalid("terminal CE statement profile mismatch")
            }
            guard proof.terminalStatement.shapeDigest == publicInput.shape.shapeDigest else {
                return .invalid("terminal CE statement shape mismatch")
            }
            guard proof.terminalStatement.verifierKeyDigest == key.verifierKeyDigest else {
                return .invalid("terminal CE statement verifier key mismatch")
            }
            guard proof.outputClaims.hasSamePublicData(as: reduction.outputClaims) else {
                return .invalid("terminal CE statement does not match fold reduction output")
            }
            guard try CEOpeningRelation.verify(
                proof: proof.ceOpeningProof,
                statement: proof.terminalStatement,
                shape: publicInput.shape,
                key: key,
                parameters: parameters,
                metalWorkspace: try makeCEOpeningMetalWorkspace(shape: publicInput.shape),
                executionPolicy: executionPolicy
            ) else {
                return .invalid("terminal CE opening proof verification failed")
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }

    public func verifyFold(
        input: SuperNeoFoldInput,
        proof: FoldProof,
        outputClaims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        verifyFold(
            publicInput: SuperNeoPublicFoldInput(input),
            proof: proof,
            outputClaims: outputClaims,
            transcriptSeed: transcriptSeed
        )
    }

    public func verifyFold(
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        outputClaims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) -> VerificationResult {
        do {
            let reduction = reduceFold(publicInput: publicInput, proof: proof, transcriptSeed: transcriptSeed)
            guard reduction.isReductionAccepted else {
                return .invalid(reduction.reason ?? "fold reduction verification failed")
            }
            guard outputClaims.hasSamePublicData(as: reduction.outputClaims) else {
                return .invalid("terminal CE claims do not match fold reduction output")
            }
            let witnesses = outputClaims.compactMap(CEOpeningWitness.init(claim:))
            guard witnesses.count == outputClaims.count else {
                return .invalid("terminal CE relation check failed")
            }
            let terminalStatement = try TerminalCEStatement(
                profileID: parameters.profileID,
                shape: publicInput.shape,
                key: key,
                claims: outputClaims
            )
            guard try CEOpeningRelation.verifyTerminalLocalBatch(
                statement: terminalStatement,
                witnesses: witnesses,
                shape: publicInput.shape,
                key: key,
                parameters: parameters,
                executionPolicy: executionPolicy
            ) else {
                return .invalid("terminal CE relation check failed")
            }
            return .valid
        } catch {
            return .invalid("\(error)")
        }
    }

    public func reduceFold(input: SuperNeoFoldInput, proof: FoldProof, transcriptSeed: [UInt8] = []) -> FoldReductionResult {
        reduceFold(publicInput: SuperNeoPublicFoldInput(input), proof: proof, transcriptSeed: transcriptSeed)
    }

    public func reduceFold(
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        transcriptSeed: [UInt8] = []
    ) -> FoldReductionResult {
        SuperNeoBenchmarkSignpost.measure("reduceFold") {
            reduceFoldBody(publicInput: publicInput, proof: proof, transcriptSeed: transcriptSeed)
        }
    }

    private func reduceFoldBody(
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        transcriptSeed: [UInt8]
    ) -> FoldReductionResult {
        do {
            guard key.parameters == parameters else { return .invalid("verifier key parameters do not match verifier parameters") }
            try validateCommitmentKey(key, matches: publicInput.shape, role: "verifier")
            try validatePublicFoldInput(publicInput, parameters: parameters)
            guard proof.outputClaims.count == parameters.decompositionLength else {
                return .invalid("decomposition output count must equal \(parameters.decompositionLength)")
            }
            guard proof.decomposition.commitments == proof.outputClaims.map(\.commitment) else {
                return .invalid("decomposition commitments must match output claims")
            }
            guard proof.decomposition.evaluations == proof.outputClaims.map(\.evaluations) else {
                return .invalid("decomposition evaluations must match output claims")
            }
            guard proof.foldedClaim.commitment.elements.count == parameters.kappa else {
                return .invalid("folded commitment has wrong length")
            }
            guard proof.piCCSClaims.count == publicInput.instances.count + publicInput.priorClaims.count else {
                return .invalid("proof PiCCS final claim count mismatch")
            }
            try validateProofPublicData(publicInput: publicInput, proof: proof, parameters: parameters)

            var transcript = makeFoldTranscript(input: publicInput, transcriptSeed: transcriptSeed)
            let qState = try makePublicQState(input: publicInput, transcript: &transcript, parameters: parameters)
            let claimedSum = try qState.claimedSum(from: publicInput.priorClaims)
            guard proof.sumCheck.claimedSum == claimedSum else {
                return .invalid("sum-check claimed sum mismatch")
            }
            let sumcheckAccepted = try SumcheckVerifier.verify(
                proof: proof.sumCheck,
                transcript: &transcript,
                expectedDegree: qState.maxDegreePerRound,
                expectedRoundCount: qState.numVars
            ) { point, value in
                try qState.finalEvaluation(
                    instances: publicInput.instances,
                    priorClaims: publicInput.priorClaims,
                    proofClaims: proof.piCCSClaims,
                    point: point
                ) == value
            }
            guard sumcheckAccepted else {
                return .invalid("sum-check verification failed")
            }
            absorbEvaluationClaimBatch(proof.piCCSClaims, into: &transcript)

            guard proof.randomLinearCombinationChallenges.count == proof.piCCSClaims.count else {
                return .invalid("wrong number of random-linear-combination challenges")
            }

            let expectedChallenges = proof.piCCSClaims.map { _ in transcript.challengeRing() }
            guard proof.randomLinearCombinationChallenges == expectedChallenges else {
                return .invalid("random-linear-combination challenge mismatch")
            }

            let expectedRLC = try randomLinearCombination(
                claims: proof.piCCSClaims,
                challenges: proof.randomLinearCombinationChallenges
            )
            guard proof.foldedClaim.hasSamePublicData(as: expectedRLC) else {
                return .invalid("folded claim does not match random linear combination")
            }

            guard try verifyDecomposition(folded: expectedRLC, parts: proof.outputClaims, shape: publicInput.shape) else {
                return .invalid("decomposition does not match folded witness")
            }
            return .reduced(outputClaims: proof.outputClaims)
        } catch {
            return .invalid("\(error)")
        }
    }

    @available(*, deprecated, message: "Use reduceFoldEnvelope(...) for fold reductions, or verifyFoldEnvelope(..., outputClaims:) for terminal local verification.")
    public func verifyFoldEnvelope(
        input: SuperNeoFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> VerificationResult {
        verifyFoldEnvelope(
            publicInput: SuperNeoPublicFoldInput(input),
            proofBytes: proofBytes,
            context: expectedContext
        )
    }

    @available(*, deprecated, message: "Use reduceFoldEnvelope(...) for fold reductions, or verifyFoldEnvelope(..., outputClaims:) for terminal local verification.")
    public func verifyFoldEnvelope(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> VerificationResult {
        let reduction = reduceFoldEnvelope(
            publicInput: publicInput,
            proofBytes: proofBytes,
            context: expectedContext
        )
        guard reduction.isReductionAccepted else {
            return .invalid(reduction.reason ?? "fold reduction verification failed")
        }
        return .invalid(Self.terminalRelationCheckRequiredReason)
    }

    public func verifyFoldEnvelope(
        input: SuperNeoFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext,
        outputClaims: [CCSEvaluationClaim]
    ) -> VerificationResult {
        verifyFoldEnvelope(
            publicInput: SuperNeoPublicFoldInput(input),
            proofBytes: proofBytes,
            context: expectedContext,
            outputClaims: outputClaims
        )
    }

    public func verifyFoldEnvelope(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext,
        outputClaims: [CCSEvaluationClaim]
    ) -> VerificationResult {
        do {
            let envelope = try FoldProofEnvelope(bytes: proofBytes, parameters: parameters)
            guard envelope.header.profileID == expectedContext.profileID else {
                return .invalid("profile mismatch")
            }
            guard envelope.header.kind == expectedContext.kind else {
                return .invalid("proof kind mismatch")
            }
            guard envelope.header.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("shape digest mismatch")
            }
            guard envelope.header.statementDigest == expectedContext.statementDigest else {
                return .invalid("statement digest mismatch")
            }
            guard envelope.header.verifierKeyDigest == expectedContext.verifierKeyDigest else {
                return .invalid("verifier key digest mismatch")
            }
            guard expectedContext.verifierKeyDigest == key.verifierKeyDigest else {
                return .invalid("input verifier key digest mismatch")
            }
            guard envelope.header.transcriptDomain == expectedContext.transcriptDomain else {
                return .invalid("transcript domain mismatch")
            }
            guard publicInput.shape.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("input shape digest mismatch")
            }
            let statement = CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
            )
            guard statement.statementDigest == expectedContext.statementDigest else {
                return .invalid("input statement digest mismatch")
            }
            return verifyFold(
                publicInput: publicInput,
                proof: envelope.proof,
                outputClaims: outputClaims,
                transcriptSeed: envelope.header.transcriptBindingBytes
            )
        } catch {
            return .invalid("\(error)")
        }
    }

    public func verifyTerminalFoldEnvelope(
        input: SuperNeoFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> VerificationResult {
        verifyTerminalFoldEnvelope(
            publicInput: SuperNeoPublicFoldInput(input),
            proofBytes: proofBytes,
            context: expectedContext
        )
    }

    public func verifyTerminalFoldEnvelope(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> VerificationResult {
        do {
            let envelope = try TerminalFoldProofEnvelope(bytes: proofBytes, parameters: parameters)
            guard envelope.header.profileID == expectedContext.profileID else {
                return .invalid("profile mismatch")
            }
            guard envelope.header.kind == expectedContext.kind else {
                return .invalid("proof kind mismatch")
            }
            guard envelope.header.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("shape digest mismatch")
            }
            guard envelope.header.statementDigest == expectedContext.statementDigest else {
                return .invalid("statement digest mismatch")
            }
            guard envelope.header.verifierKeyDigest == expectedContext.verifierKeyDigest else {
                return .invalid("verifier key digest mismatch")
            }
            guard expectedContext.verifierKeyDigest == key.verifierKeyDigest else {
                return .invalid("input verifier key digest mismatch")
            }
            guard envelope.header.transcriptDomain == expectedContext.transcriptDomain else {
                return .invalid("transcript domain mismatch")
            }
            guard publicInput.shape.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("input shape digest mismatch")
            }
            let statement = CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
            )
            guard statement.statementDigest == expectedContext.statementDigest else {
                return .invalid("input statement digest mismatch")
            }
            return verifyTerminalFold(
                publicInput: publicInput,
                proof: envelope.proof,
                transcriptSeed: envelope.header.transcriptBindingBytes
            )
        } catch {
            return .invalid("\(error)")
        }
    }

    public func verifyCompressedTerminalFoldEnvelope(
        input: SuperNeoFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> VerificationResult {
        verifyCompressedTerminalFoldEnvelope(
            publicInput: SuperNeoPublicFoldInput(input),
            proofBytes: proofBytes,
            context: expectedContext
        )
    }

    public func verifyCompressedTerminalFoldEnvelope(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> VerificationResult {
        do {
            let envelope = try CompressedTerminalProofEnvelope(bytes: proofBytes, parameters: parameters)
            guard envelope.header.profileID == expectedContext.profileID else {
                return .invalid("profile mismatch")
            }
            guard envelope.header.kind == expectedContext.kind, expectedContext.kind == .compressedPublic else {
                return .invalid("proof kind mismatch")
            }
            guard envelope.header.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("shape digest mismatch")
            }
            guard envelope.header.statementDigest == expectedContext.statementDigest else {
                return .invalid("statement digest mismatch")
            }
            guard envelope.header.verifierKeyDigest == expectedContext.verifierKeyDigest else {
                return .invalid("verifier key digest mismatch")
            }
            guard expectedContext.verifierKeyDigest == key.verifierKeyDigest else {
                return .invalid("input verifier key digest mismatch")
            }
            guard envelope.header.transcriptDomain == expectedContext.transcriptDomain else {
                return .invalid("transcript domain mismatch")
            }
            guard publicInput.shape.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("input shape digest mismatch")
            }
            let statement = CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
            )
            guard statement.statementDigest == expectedContext.statementDigest else {
                return .invalid("input statement digest mismatch")
            }
            guard envelope.proof.statement.context == expectedContext else {
                return .invalid("compressed statement context mismatch")
            }
            guard envelope.proof.statement.publicInputDigest == compressedPublicInputDigest(publicInput) else {
                return .invalid("compressed public input digest mismatch")
            }
            guard envelope.proof.statement.verifierKeyDigest == key.verifierKeyDigest else {
                return .invalid("compressed verifier key digest mismatch")
            }
            let terminalStatement = try TerminalCEStatement(
                profileID: expectedContext.profileID,
                shapeDigest: expectedContext.shapeDigest,
                verifierKeyDigest: expectedContext.verifierKeyDigest,
                claims: envelope.proof.foldProof.outputClaims
            )
            guard envelope.proof.statement.terminalStatementDigest == terminalStatement.statementDigest else {
                return .invalid("compressed terminal statement digest mismatch")
            }
            let terminalContext = ProofEnvelopeContext(
                profileID: expectedContext.profileID,
                kind: .terminalLocal,
                shapeDigest: expectedContext.shapeDigest,
                statementDigest: expectedContext.statementDigest,
                verifierKeyDigest: expectedContext.verifierKeyDigest,
                transcriptDomain: expectedContext.transcriptDomain
            )
            let terminalProof = TerminalFoldProof(
                foldProof: envelope.proof.foldProof,
                terminalStatement: terminalStatement,
                ceOpeningProof: envelope.proof.ceOpeningProof
            )
            return verifyTerminalFold(
                publicInput: publicInput,
                proof: terminalProof,
                transcriptSeed: terminalContext.transcriptBindingBytes
            )
        } catch {
            return .invalid("\(error)")
        }
    }

    public func reduceFoldEnvelope(
        input: SuperNeoFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> FoldReductionResult {
        reduceFoldEnvelope(
            publicInput: SuperNeoPublicFoldInput(input),
            proofBytes: proofBytes,
            context: expectedContext
        )
    }

    public func reduceFoldEnvelope(
        publicInput: SuperNeoPublicFoldInput,
        proofBytes: [UInt8],
        context expectedContext: ProofEnvelopeContext
    ) -> FoldReductionResult {
        do {
            let envelope = try FoldProofEnvelope(bytes: proofBytes, parameters: parameters)
            guard envelope.header.profileID == expectedContext.profileID else {
                return .invalid("profile mismatch")
            }
            guard envelope.header.kind == expectedContext.kind else {
                return .invalid("proof kind mismatch")
            }
            guard envelope.header.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("shape digest mismatch")
            }
            guard envelope.header.statementDigest == expectedContext.statementDigest else {
                return .invalid("statement digest mismatch")
            }
            guard envelope.header.verifierKeyDigest == expectedContext.verifierKeyDigest else {
                return .invalid("verifier key digest mismatch")
            }
            guard expectedContext.verifierKeyDigest == key.verifierKeyDigest else {
                return .invalid("input verifier key digest mismatch")
            }
            guard envelope.header.transcriptDomain == expectedContext.transcriptDomain else {
                return .invalid("transcript domain mismatch")
            }
            guard publicInput.shape.shapeDigest == expectedContext.shapeDigest else {
                return .invalid("input shape digest mismatch")
            }
            let statement = CCSStatement(
                shapeDigest: publicInput.shape.shapeDigest,
                ccsInstances: publicInput.instances,
                priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
            )
            guard statement.statementDigest == expectedContext.statementDigest else {
                return .invalid("input statement digest mismatch")
            }
            return reduceFold(
                publicInput: publicInput,
                proof: envelope.proof,
                transcriptSeed: envelope.header.transcriptBindingBytes
            )
        } catch {
            return .invalid("\(error)")
        }
    }

    private func randomLinearCombination(
        claims: [CCSEvaluationClaim],
        challenges: [CyclotomicRing54]
    ) throws -> CCSEvaluationClaim {
        try SuperNeoProtocolOracle.randomLinearCombination(claims: claims, challenges: challenges)
    }

    private func verifyDecomposition(
        folded: CCSEvaluationClaim,
        parts: [CCSEvaluationClaim],
        shape: CCSShape
    ) throws -> Bool {
        try SuperNeoProtocolOracle.verifyDecomposition(
            folded: folded,
            parts: parts,
            shape: shape,
            parameters: parameters
        )
    }

    private func makeCEOpeningMetalWorkspace(shape: CCSShape) throws -> SuperNeoMetalWorkspace? {
        guard let context else { return nil }
        let compiledShape = try shape.compiledSparseForSuperNeo()
        return try SuperNeoMetalWorkspace(
            context: context,
            key: key,
            compiledShape: compiledShape
        )
    }
}

private enum SuperNeoProtocolOracle {
    static func makePiCCSOutputClaims(
        input: SuperNeoFoldInput,
        key: AjtaiCommitmentKey,
        compiledShape: CompiledCCSShape,
        metalWorkspace: SuperNeoMetalWorkspace?,
        point: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> [CCSEvaluationClaim] {
        var claimInputs: [(commitment: AjtaiCommitment, publicInput: [GoldilocksField], witness: [GoldilocksField])] = []
        claimInputs.reserveCapacity(input.instances.count + input.priorClaims.count)
        for (instance, witness) in zip(input.instances, input.witnesses) {
            claimInputs.append((
                commitment: instance.commitment,
                publicInput: instance.publicInput,
                witness: witness.fullZ(for: instance)
            ))
        }
        for claim in input.priorClaims {
            guard let witness = claim.witness else {
                throw SuperNeoError.invalidParameter("prover requires prior CE witnesses")
            }
            claimInputs.append((
                commitment: claim.commitment,
                publicInput: claim.publicInput,
                witness: witness
            ))
        }

        let packedWitnesses = try claimInputs.map { claimInput -> [CyclotomicRing54] in
            guard isValidEvaluationWitnessLength(claimInput.witness.count, shape: input.shape) else {
                throw SuperNeoError.invalidParameter("evaluation witness length must match the original or padded ring length")
            }
            guard publicInputMatchesWitnessPrefix(claimInput.publicInput, witness: claimInput.witness) else {
                throw SuperNeoError.invalidParameter("evaluation public input must be a prefix of the witness")
            }
            return try packedEvaluationWitness(claimInput.witness, shape: input.shape)
        }

        let recomputedCommitments: [AjtaiCommitment]
        let evaluations: [[CyclotomicExt2Ring54]]
        if let metalWorkspace, !executionPolicy.usesConstantWorkCPU {
            let combined = try metalWorkspace.commitmentsAndTransformedEvaluations(
                messages: packedWitnesses,
                point: point
            )
            recomputedCommitments = combined.commitments
            evaluations = combined.evaluations
            if executionPolicy.requiresMetalCPUCheck {
                let cpuArtifacts = try makeCPUOpeningArtifacts(
                    key: key,
                    transformedMatrices: compiledShape.transformedSparseMatrices,
                    packedWitnesses: packedWitnesses,
                    point: point,
                    executionPolicy: executionPolicy,
                    useParallel: shouldParallelizeOpeningBatch(shape: input.shape, count: packedWitnesses.count)
                )
                guard recomputedCommitments == cpuArtifacts.map(\.commitment),
                      evaluations == cpuArtifacts.map(\.evaluations) else {
                    throw SuperNeoError.metalFailure("Metal PiCCS output failed CPU cross-check")
                }
            }
        } else {
            let cpuArtifacts = try makeCPUOpeningArtifacts(
                key: key,
                transformedMatrices: compiledShape.transformedSparseMatrices,
                packedWitnesses: packedWitnesses,
                point: point,
                executionPolicy: executionPolicy,
                useParallel: shouldParallelizeOpeningBatch(shape: input.shape, count: packedWitnesses.count)
            )
            recomputedCommitments = cpuArtifacts.map(\.commitment)
            evaluations = cpuArtifacts.map(\.evaluations)
        }
        for index in claimInputs.indices where recomputedCommitments[index] != claimInputs[index].commitment {
            throw SuperNeoError.verificationFailed("instance commitment does not match witness")
        }

        return claimInputs.indices.map { index in
            CCSEvaluationClaim(
                commitment: claimInputs[index].commitment,
                publicInput: claimInputs[index].publicInput,
                point: point,
                evaluations: evaluations[index],
                witness: claimInputs[index].witness
            )
        }
    }

    private static func makeCPUOpeningArtifacts(
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        packedWitnesses: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy,
        useParallel: Bool
    ) throws -> [(commitment: AjtaiCommitment, evaluations: [CyclotomicExt2Ring54])] {
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        return try orderedParallelMap(
            packedWitnesses,
            useParallel: useParallel
        ) { packed -> (commitment: AjtaiCommitment, evaluations: [CyclotomicExt2Ring54]) in
            let commitment = try commitReference(key: key, message: packed, executionPolicy: executionPolicy)
            let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
                try evaluateTransformedMatrix(
                    matrix,
                    by: packed,
                    rHat: rHat,
                    executionPolicy: executionPolicy
                )
            }
            return (commitment, evaluations)
        }
    }

    private static func commitReference(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> AjtaiCommitment {
        if executionPolicy.usesConstantWorkCPU {
            return try AjtaiCommitter.commitConstantWorkReference(key: key, message: message)
        }
        return try AjtaiCommitter.commitReference(key: key, message: message)
    }

    fileprivate static func evaluateTransformedMatrix(
        _ matrix: SparseRingMatrixCSR,
        by packed: [CyclotomicRing54],
        rHat: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> CyclotomicExt2Ring54 {
        if executionPolicy.usesConstantWorkCPU {
            return try matrix.evaluatedProductConstantWork(by: packed, rHat: rHat)
        }
        return try matrix.evaluatedProduct(by: packed, rHat: rHat)
    }

    static func randomLinearCombination(
        claims: [CCSEvaluationClaim],
        challenges: [CyclotomicRing54],
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> CCSEvaluationClaim {
        guard let first = claims.first else { throw SuperNeoError.invalidParameter("cannot fold zero claims") }
        guard challenges.count == claims.count else {
            throw SuperNeoError.invalidParameter("RLC challenge count mismatch")
        }
        guard first.commitment.elements.count > 0 else {
            throw SuperNeoError.invalidParameter("RLC commitment cannot be empty")
        }
        let carriesWitnesses = first.witness != nil
        guard claims.allSatisfy({ ($0.witness != nil) == carriesWitnesses }) else {
            throw SuperNeoError.invalidParameter("RLC claims must either all carry witnesses or all be public")
        }
        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: first.commitment.elements.count))
        let paddedPublicInputCount = SuperNeoEmbedding.paddedLength(forFieldElementCount: first.publicInput.count)
        var publicInput = Array(repeating: CyclotomicRing54.zero, count: paddedPublicInputCount / CyclotomicRing54.degree)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: first.evaluations.count)
        let witnessRingCount = carriesWitnesses
            ? SuperNeoEmbedding.paddedLength(forFieldElementCount: first.witness?.count ?? 0) / CyclotomicRing54.degree
            : 0
        var witnessRings = Array(repeating: CyclotomicRing54.zero, count: witnessRingCount)

        for (challenge, claim) in zip(challenges, claims) {
            guard claim.commitment.elements.count == first.commitment.elements.count else {
                throw SuperNeoError.invalidParameter("RLC commitment lengths must match")
            }
            guard claim.point == first.point else {
                throw SuperNeoError.invalidParameter("RLC claims must share an evaluation point")
            }
            guard claim.publicInput.count == first.publicInput.count else {
                throw SuperNeoError.invalidParameter("RLC public input lengths must match")
            }
            for index in commitment.elements.indices {
                commitment.elements[index] = commitment.elements[index] + challenge * claim.commitment.elements[index]
            }
            let packedInput = try SuperNeoEmbedding.packPadded(claim.publicInput)
            guard packedInput.count == publicInput.count else {
                throw SuperNeoError.invalidParameter("public input ring lengths must match")
            }
            for index in publicInput.indices {
                publicInput[index] = publicInput[index] + challenge * packedInput[index]
            }
            guard claim.evaluations.count == evaluations.count else {
                throw SuperNeoError.invalidParameter("evaluation vector lengths must match")
            }
            for index in evaluations.indices {
                evaluations[index] = evaluations[index] + challenge * claim.evaluations[index]
            }
            if let witness = claim.witness {
                let packedWitness = try SuperNeoEmbedding.packPadded(witness)
                guard packedWitness.count == witnessRings.count else {
                    throw SuperNeoError.invalidParameter("witness ring lengths must match")
                }
                for index in packedWitness.indices {
                    let product = executionPolicy.usesConstantWorkCPU
                        ? challenge.multipliedConstantWork(by: packedWitness[index])
                        : challenge * packedWitness[index]
                    witnessRings[index] = witnessRings[index] + product
                }
            }
        }

        return CCSEvaluationClaim(
            commitment: commitment,
            publicInput: Array(SuperNeoEmbedding.unpack(publicInput).prefix(first.publicInput.count)),
            point: first.point,
            evaluations: evaluations,
            witness: carriesWitnesses ? SuperNeoEmbedding.unpack(witnessRings) : nil
        )
    }

    static func verifyEvaluationClaimOpening(
        shape: CCSShape,
        transformedMatrices: [SparseRingMatrixCSR],
        claim: CCSEvaluationClaim,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        try verifyEvaluationClaimOpenings(
            shape: shape,
            transformedMatrices: transformedMatrices,
            claims: [claim],
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        )
    }

    static func verifyEvaluationClaimOpenings(
        shape: CCSShape,
        transformedMatrices: [SparseRingMatrixCSR],
        claims: [CCSEvaluationClaim],
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        guard transformedMatrices.count == shape.numMatrices else { return false }
        let numVars = try log2Exact(shape.m)
        var basisCache: [(point: [GoldilocksExt2], basis: [GoldilocksExt2])] = []

        func evaluationBasis(for point: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
            if let cached = basisCache.first(where: { $0.point == point }) {
                return cached.basis
            }
            let basis = try MultilinearEvaluation.checkedBasis(at: point)
            basisCache.append((point: point, basis: basis))
            return basis
        }

        let preparedClaims = try claims.map { claim in
            (
                claim: claim,
                rHat: try evaluationBasis(for: claim.point)
            )
        }
        let results = try orderedParallelMap(
            preparedClaims,
            useParallel: shouldParallelizeOpeningBatch(shape: shape, count: preparedClaims.count)
        ) { prepared in
            try verifyEvaluationClaimOpening(
                shape: shape,
                transformedMatrices: transformedMatrices,
                claim: prepared.claim,
                key: key,
                parameters: parameters,
                numVars: numVars,
                rHat: prepared.rHat,
                executionPolicy: executionPolicy
            )
        }
        return results.allSatisfy { $0 }
    }

    private static func verifyEvaluationClaimOpening(
        shape: CCSShape,
        transformedMatrices: [SparseRingMatrixCSR],
        claim: CCSEvaluationClaim,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters,
        numVars: Int,
        rHat: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> Bool {
        guard let witness = claim.witness else { return false }
        guard isValidEvaluationWitnessLength(witness.count, shape: shape) else { return false }
        guard claim.publicInput.count == shape.nPublicField else { return false }
        guard publicInputMatchesWitnessPrefix(claim.publicInput, witness: witness) else { return false }
        guard claim.point.count == numVars else { return false }
        guard claim.evaluations.count == shape.numMatrices else { return false }
        guard claim.commitment.elements.count == parameters.kappa else { return false }
        guard witness.allSatisfy({ signedMagnitude($0) < UInt64(parameters.normBound) }) else {
            return false
        }

        let packed = try packedEvaluationWitness(witness, shape: shape)
        let recomputed = try commitReference(key: key, message: packed, executionPolicy: executionPolicy)
        guard recomputed == claim.commitment else { return false }

        let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
            try evaluateTransformedMatrix(
                matrix,
                by: packed,
                rHat: rHat,
                executionPolicy: executionPolicy
            )
        }
        return evaluations == claim.evaluations
    }

    private static func publicInputMatchesWitnessPrefix(
        _ publicInput: [GoldilocksField],
        witness: [GoldilocksField]
    ) -> Bool {
        guard publicInput.count <= witness.count else { return false }
        for index in publicInput.indices where publicInput[index] != witness[index] {
            return false
        }
        return true
    }

    static func makeEvaluationInstance(
        shape: CCSShape,
        transformedMatrices: [SparseRingMatrixCSR],
        witness: [GoldilocksField],
        publicInput: [GoldilocksField],
        point: [GoldilocksExt2],
        key: AjtaiCommitmentKey,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> CEInstance {
        guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
            throw SuperNeoError.invalidParameter("evaluation witness length must match the original or padded ring length")
        }
        guard publicInputMatchesWitnessPrefix(publicInput, witness: witness) else {
            throw SuperNeoError.invalidParameter("evaluation public input must be a prefix of the witness")
        }
        guard transformedMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("compiled transformed matrix count mismatch")
        }
        let packed = try packedEvaluationWitness(witness, shape: shape)
        let commitment = try commitReference(key: key, message: packed, executionPolicy: executionPolicy)
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
            try evaluateTransformedMatrix(
                matrix,
                by: packed,
                rHat: rHat,
                executionPolicy: executionPolicy
            )
        }
        return CEInstance(
            commitment: commitment,
            publicInput: publicInput,
            evalPoint: point,
            matrixEvals: evaluations
        )
    }

    static func decompose(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        compiledShape: CompiledCCSShape,
        metalWorkspace: SuperNeoMetalWorkspace?,
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        guard let witness = claim.witness else {
            throw SuperNeoError.invalidParameter("decomposition requires folded witness")
        }
        guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
            throw SuperNeoError.invalidParameter("decomposition witness length must match the original or padded ring length")
        }
        guard claim.publicInput.count == shape.nPublicField else {
            throw SuperNeoError.invalidParameter("decomposition public input length must match shape.nPublicField")
        }
        guard claim.evaluations.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("decomposition folded evaluation arity mismatch")
        }
        let limbs = try splitSignedBase(witness, base: parameters.normBound, count: parameters.decompositionLength)
        let publicInputLimbs = try splitSignedBase(
            claim.publicInput,
            base: parameters.normBound,
            count: parameters.decompositionLength
        )
        let useParallelCPUOpenings = shouldParallelizeOpeningBatch(shape: shape, count: limbs.count)
        let packedLimbs = try orderedParallelMap(limbs, useParallel: useParallelCPUOpenings) {
            try packedEvaluationWitness($0, shape: shape)
        }
        let limbCommitments: [AjtaiCommitment]
        let limbEvaluations: [[CyclotomicExt2Ring54]]
        if let metalWorkspace, !executionPolicy.usesConstantWorkCPU {
            let combined = try metalWorkspace.commitmentsAndTransformedEvaluations(
                messages: packedLimbs,
                point: claim.point
            )
            limbCommitments = combined.commitments
            limbEvaluations = combined.evaluations
            if executionPolicy.requiresMetalCPUCheck {
                let cpuArtifacts = try makeCPUOpeningArtifacts(
                    key: key,
                    transformedMatrices: compiledShape.transformedSparseMatrices,
                    packedWitnesses: packedLimbs,
                    point: claim.point,
                    executionPolicy: executionPolicy,
                    useParallel: useParallelCPUOpenings
                )
                guard limbCommitments == cpuArtifacts.map(\.commitment),
                      limbEvaluations == cpuArtifacts.map(\.evaluations) else {
                    throw SuperNeoError.metalFailure("Metal decomposition output failed CPU cross-check")
                }
            }
        } else {
            let openingArtifacts = try makeCPUOpeningArtifacts(
                key: key,
                transformedMatrices: compiledShape.transformedSparseMatrices,
                packedWitnesses: packedLimbs,
                point: claim.point,
                executionPolicy: executionPolicy,
                useParallel: useParallelCPUOpenings
            )
            limbCommitments = openingArtifacts.map(\.commitment)
            limbEvaluations = openingArtifacts.map(\.evaluations)
        }
        let limbClaims = limbs.enumerated().map { index, limb -> CCSEvaluationClaim in
            let commitment = limbCommitments[index]
            return CCSEvaluationClaim(
                commitment: commitment,
                publicInput: publicInputLimbs[index],
                point: claim.point,
                evaluations: limbEvaluations[index],
                witness: limb
            )
        }
        guard try verifyDecomposition(folded: claim, parts: limbClaims, shape: shape, parameters: parameters) else {
            throw SuperNeoError.verificationFailed("decomposition limbs do not recompose to folded claim")
        }
        return (
            DecompositionProof(commitments: limbClaims.map(\.commitment), evaluations: limbClaims.map(\.evaluations)),
            limbClaims
        )
    }

    static func verifyDecomposition(
        folded: CCSEvaluationClaim,
        parts: [CCSEvaluationClaim],
        shape: CCSShape,
        parameters: SuperNeoParameters
    ) throws -> Bool {
        guard parts.count == parameters.decompositionLength else { return false }
        guard folded.evaluations.count == shape.numMatrices else { return false }
        guard folded.point.count == (try log2Exact(shape.m)) else { return false }
        guard folded.publicInput.count == shape.nPublicField else { return false }

        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: folded.commitment.elements.count))
        let foldedPackedInput = try SuperNeoEmbedding.packPadded(folded.publicInput)
        var publicInput = Array(repeating: CyclotomicRing54.zero, count: foldedPackedInput.count)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: folded.evaluations.count)
        let scalars = try decompositionScalars(base: parameters.normBound, count: parts.count)

        for (index, part) in parts.enumerated() {
            guard part.point == folded.point else { return false }
            guard part.evaluations.count == folded.evaluations.count else { return false }
            guard part.publicInput.count == folded.publicInput.count else { return false }
            guard part.commitment.elements.count == folded.commitment.elements.count else { return false }
            guard part.publicInput.allSatisfy({ signedMagnitude($0) < UInt64(parameters.normBound) }) else { return false }

            let scalar = scalars[index]
            for commitmentIndex in commitment.elements.indices {
                commitment.elements[commitmentIndex] = commitment.elements[commitmentIndex]
                    + part.commitment.elements[commitmentIndex].scaled(by: scalar)
            }

            let packedPartInput = try SuperNeoEmbedding.packPadded(part.publicInput)
            guard packedPartInput.count == publicInput.count else { return false }
            for inputIndex in publicInput.indices {
                publicInput[inputIndex] = publicInput[inputIndex] + packedPartInput[inputIndex].scaled(by: scalar)
            }
            for evalIndex in evaluations.indices {
                evaluations[evalIndex] = evaluations[evalIndex] + part.evaluations[evalIndex].scaled(by: scalar)
            }
        }

        return commitment == folded.commitment
            && publicInput == foldedPackedInput
            && evaluations == folded.evaluations
    }
}

@_spi(Benchmarking) extension SuperNeoProver {
    public func benchmarkSumCheckProof(
        input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = []
    ) throws -> SumcheckProof {
        try validateFoldInput(input, parameters: parameters)
        var transcript = makeFoldTranscript(input: input, transcriptSeed: transcriptSeed)
        return try makeSumCheckProof(input: input, transcript: &transcript)
    }

    public func benchmarkSumCheckProof(
        input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = [],
        preparedContext: SuperNeoPreparedFoldContext
    ) throws -> SumcheckProof {
        try validateFoldInput(input, parameters: parameters)
        try validatePreparedFoldContext(preparedContext, shape: input.shape)
        var transcript = makeFoldTranscript(input: input, transcriptSeed: transcriptSeed)
        return try makeSumCheckProof(
            input: input,
            compiledShape: preparedContext.compiledShape,
            transcript: &transcript
        )
    }

    public func benchmarkPiCCSClaims(
        input: SuperNeoFoldInput,
        point: [GoldilocksExt2]
    ) throws -> [CCSEvaluationClaim] {
        try validateFoldInput(input, parameters: parameters)
        return try makePiCCSOutputClaims(input: input, point: point)
    }

    public func benchmarkPiCCSClaims(
        input: SuperNeoFoldInput,
        point: [GoldilocksExt2],
        preparedContext: SuperNeoPreparedFoldContext
    ) throws -> [CCSEvaluationClaim] {
        try validateFoldInput(input, parameters: parameters)
        try validatePreparedFoldContext(preparedContext, shape: input.shape)
        return try makePiCCSOutputClaims(
            input: input,
            point: point,
            compiledShape: preparedContext.compiledShape,
            metalWorkspace: preparedContext.metalWorkspace
        )
    }

    public func benchmarkPiRLC(
        input: SuperNeoFoldInput,
        claims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        try validateFoldInput(input, parameters: parameters)
        let sumCheck = try benchmarkSumCheckProof(input: input, transcriptSeed: transcriptSeed)
        let preparedTranscript = try preparePiRLCTranscript(
            input: input,
            sumCheck: sumCheck,
            claims: claims,
            transcriptSeed: transcriptSeed
        )
        return try benchmarkPiRLC(claims: claims, preparedTranscript: preparedTranscript)
    }

    public func benchmarkPiRLC(
        input: SuperNeoFoldInput,
        claims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = [],
        preparedContext: SuperNeoPreparedFoldContext
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        try validateFoldInput(input, parameters: parameters)
        try validatePreparedFoldContext(preparedContext, shape: input.shape)
        let sumCheck = try benchmarkSumCheckProof(
            input: input,
            transcriptSeed: transcriptSeed,
            preparedContext: preparedContext
        )
        let preparedTranscript = try preparePiRLCTranscript(
            input: input,
            sumCheck: sumCheck,
            claims: claims,
            transcriptSeed: transcriptSeed
        )
        return try benchmarkPiRLC(claims: claims, preparedTranscript: preparedTranscript)
    }

    public func benchmarkPiRLC(
        claims: [CCSEvaluationClaim],
        preparedTranscript: SuperNeoPreparedPiRLCTranscript
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        guard claims.count == preparedTranscript.claimCount else {
            throw SuperNeoError.invalidParameter("PiRLC claim count does not match prepared transcript")
        }
        guard claims.allSatisfy({ $0.point == preparedTranscript.sumCheckFinalPoint }) else {
            throw SuperNeoError.invalidParameter("PiRLC claims must use the sum-check final point")
        }
        var transcript = preparedTranscript.transcriptAfterSumCheck
        absorbEvaluationClaimBatch(claims, into: &transcript)
        return try randomLinearCombination(claims: claims, transcript: &transcript)
    }

    public func benchmarkPiRLC(
        input: SuperNeoFoldInput,
        claims: [CCSEvaluationClaim],
        sumCheck: SumcheckProof,
        transcriptSeed: [UInt8] = []
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        let preparedTranscript = try preparePiRLCTranscript(
            input: input,
            sumCheck: sumCheck,
            claims: claims,
            transcriptSeed: transcriptSeed
        )
        return try benchmarkPiRLC(claims: claims, preparedTranscript: preparedTranscript)
    }

    public func benchmarkPiRLC(
        input: SuperNeoFoldInput,
        claims: [CCSEvaluationClaim],
        sumCheck: SumcheckProof,
        transcriptSeed: [UInt8] = [],
        preparedContext: SuperNeoPreparedFoldContext
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        try validatePreparedFoldContext(preparedContext, shape: input.shape)
        return try benchmarkPiRLC(
            input: input,
            claims: claims,
            sumCheck: sumCheck,
            transcriptSeed: transcriptSeed
        )
    }

    public func benchmarkPiDEC(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        try decompose(claim, shape: shape)
    }

    public func benchmarkPiDEC(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape,
        preparedContext: SuperNeoPreparedFoldContext
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        try validatePreparedFoldContext(preparedContext, shape: shape)
        return try decompose(
            claim,
            shape: shape,
            compiledShape: preparedContext.compiledShape,
            metalWorkspace: preparedContext.metalWorkspace
        )
    }
}

private func isValidEvaluationWitnessLength(_ count: Int, shape: CCSShape) -> Bool {
    count == shape.nField || count == shape.nRing * CyclotomicRing54.degree
}

private func packedEvaluationWitness(_ witness: [GoldilocksField], shape: CCSShape) throws -> [CyclotomicRing54] {
    guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
        throw SuperNeoError.invalidParameter("evaluation witness length must be shape.nField or its padded ring length")
    }
    let packed = try SuperNeoEmbedding.packPadded(witness)
    guard packed.count == shape.nRing else {
        throw SuperNeoError.invalidParameter("evaluation witness ring length mismatch")
    }
    return packed
}

private func validateCommitmentKey(_ key: AjtaiCommitmentKey, matches shape: CCSShape, role: String) throws {
    guard key.matrix.columns == shape.nRing else {
        throw SuperNeoError.invalidParameter("\(role) key column count must match shape.nRing")
    }
}

private func validateEnvelopeContext(
    _ context: ProofEnvelopeContext,
    publicInput: SuperNeoPublicFoldInput,
    key: AjtaiCommitmentKey,
    expectedKind: ProofEnvelopeKind
) throws {
    guard context.profileID == key.parameters.profileID else {
        throw SuperNeoError.invalidParameter("proof envelope context profile mismatch")
    }
    guard context.kind == expectedKind else {
        throw SuperNeoError.invalidParameter("proof envelope context kind mismatch")
    }
    guard context.shapeDigest == publicInput.shape.shapeDigest else {
        throw SuperNeoError.invalidParameter("proof envelope context shape digest mismatch")
    }
    let statement = CCSStatement(
        shapeDigest: publicInput.shape.shapeDigest,
        ccsInstances: publicInput.instances,
        priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
    )
    guard context.statementDigest == statement.statementDigest else {
        throw SuperNeoError.invalidParameter("proof envelope context statement digest mismatch")
    }
    guard context.verifierKeyDigest == key.verifierKeyDigest else {
        throw SuperNeoError.invalidParameter("proof envelope context verifier key digest mismatch")
    }
}

private func validateFoldInput(_ input: SuperNeoFoldInput, parameters: SuperNeoParameters) throws {
    guard !input.instances.isEmpty else {
        throw SuperNeoError.invalidParameter("fold input requires at least one CCS instance")
    }
    guard input.instances.count == input.witnesses.count else {
        throw SuperNeoError.invalidParameter("instances and witnesses must have the same count")
    }
    guard !input.shape.matrices.isEmpty else {
        throw SuperNeoError.invalidParameter("CCS structure requires at least one matrix")
    }
    let rows = input.shape.m
    try SuperNeoFoldingShapeContract.paperNormalized.validate(input.shape)
    try validateStrongSamplingCapacity(
        freshCount: input.instances.count,
        priorCount: input.priorClaims.count,
        parameters: parameters
    )
    for matrix in input.shape.matrices {
        guard matrix.rowCount == rows, matrix.columnCount == input.shape.nField else {
            throw SuperNeoError.invalidParameter("all CCS matrices must have the same row count")
        }
    }
    for (instance, witness) in zip(input.instances, input.witnesses) {
        guard instance.publicInput.count == input.shape.nPublicField else {
            throw SuperNeoError.invalidParameter("public input length must match shape.nPublicField")
        }
        guard witness.fullZ(for: instance).count == input.shape.nField else {
            throw SuperNeoError.invalidParameter("full witness length must match shape.nField")
        }
    }
    for claim in input.priorClaims {
        guard claim.commitment.elements.count == parameters.kappa else {
            throw SuperNeoError.invalidParameter("prior CE commitment has wrong length")
        }
        guard claim.publicInput.count == input.shape.nPublicField else {
            throw SuperNeoError.invalidParameter("prior CE public input length must match shape.nPublicField")
        }
        guard claim.point.count == (try log2Exact(rows)), claim.evaluations.count == input.shape.numMatrices else {
            throw SuperNeoError.invalidParameter("prior CE claim shape mismatch")
        }
        if let witness = claim.witness {
            guard isValidEvaluationWitnessLength(witness.count, shape: input.shape) else {
                throw SuperNeoError.invalidParameter("prior CE witness length mismatch")
            }
            guard claim.publicInput.count <= witness.count,
                  Array(witness.prefix(claim.publicInput.count)) == claim.publicInput else {
                throw SuperNeoError.invalidParameter("prior CE public input must be a prefix of its witness")
            }
        }
    }
}

private func validatePublicFoldInput(_ input: SuperNeoPublicFoldInput, parameters: SuperNeoParameters) throws {
    guard !input.instances.isEmpty else {
        throw SuperNeoError.invalidParameter("public fold input requires at least one CCS instance")
    }
    guard !input.shape.matrices.isEmpty else {
        throw SuperNeoError.invalidParameter("CCS structure requires at least one matrix")
    }
    let rows = input.shape.m
    try SuperNeoFoldingShapeContract.paperNormalized.validate(input.shape)
    try validateStrongSamplingCapacity(
        freshCount: input.instances.count,
        priorCount: input.priorClaims.count,
        parameters: parameters
    )
    for matrix in input.shape.matrices {
        guard matrix.rowCount == rows, matrix.columnCount == input.shape.nField else {
            throw SuperNeoError.invalidParameter("all CCS matrices must have the same row count")
        }
    }
    for instance in input.instances {
        guard instance.commitment.elements.count == parameters.kappa else {
            throw SuperNeoError.invalidParameter("instance commitment has wrong length")
        }
        guard instance.publicInput.count == input.shape.nPublicField else {
            throw SuperNeoError.invalidParameter("public input length must match shape.nPublicField")
        }
    }
    var priorEvalPoint: [GoldilocksExt2]?
    for claim in input.priorClaims {
        guard claim.commitment.elements.count == parameters.kappa else {
            throw SuperNeoError.invalidParameter("prior CE commitment has wrong length")
        }
        guard claim.publicInput.count == input.shape.nPublicField else {
            throw SuperNeoError.invalidParameter("prior CE public input length must match shape.nPublicField")
        }
        guard claim.point.count == (try log2Exact(rows)), claim.evaluations.count == input.shape.numMatrices else {
            throw SuperNeoError.invalidParameter("prior CE claim shape mismatch")
        }
        if let existing = priorEvalPoint {
            guard claim.point == existing else {
                throw SuperNeoError.invalidParameter("prior CE claims must use the same evaluation point")
            }
        } else {
            priorEvalPoint = claim.point
        }
    }
}

private func validateProofPublicData(
    publicInput: SuperNeoPublicFoldInput,
    proof: FoldProof,
    parameters: SuperNeoParameters
) throws {
    let numVars = try log2Exact(publicInput.shape.m)
    let allClaims = proof.piCCSClaims + [proof.foldedClaim] + proof.outputClaims
    for claim in allClaims {
        guard claim.commitment.elements.count == parameters.kappa else {
            throw SuperNeoError.invalidParameter("proof commitment has wrong length")
        }
        guard claim.publicInput.count == publicInput.shape.nPublicField else {
            throw SuperNeoError.invalidParameter("proof public input length mismatch")
        }
        guard claim.point.count == numVars else {
            throw SuperNeoError.invalidParameter("proof evaluation point length mismatch")
        }
        guard claim.evaluations.count == publicInput.shape.numMatrices else {
            throw SuperNeoError.invalidParameter("proof evaluation arity mismatch")
        }
    }
    for claim in proof.piCCSClaims {
        guard claim.point == proof.sumCheck.finalPoint else {
            throw SuperNeoError.invalidParameter("PiCCS final claims must be evaluated at the sum-check final point")
        }
    }
}

private func makePublicQState(
    input: SuperNeoPublicFoldInput,
    transcript: inout SumCheckTranscript,
    parameters: SuperNeoParameters
) throws -> PublicQVerifierState {
    let numVars = try log2Exact(input.shape.m)
    let alpha = (0..<numVars).map { _ in transcript.challengeExt2() }
    let gamma = transcript.challengeExt2()
    return try PublicQVerifierState(
        shape: input.shape,
        freshCount: input.instances.count,
        priorClaims: input.priorClaims,
        alpha: alpha,
        gamma: gamma,
        parameters: parameters
    )
}

private func makeFoldTranscript(input: SuperNeoFoldInput, transcriptSeed: [UInt8]) -> SumCheckTranscript {
    return makeFoldTranscript(input: SuperNeoPublicFoldInput(input), transcriptSeed: transcriptSeed)
}

private func makeFoldTranscript(input: SuperNeoPublicFoldInput, transcriptSeed: [UInt8]) -> SumCheckTranscript {
    var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.fold", seed: transcriptSeed)
    transcript.absorb(input.shape.shapeDigest.superNeoBytes)
    transcript.absorb(transcriptEncodeCount(input.instances.count))
    input.instances.forEach { transcript.absorb($0.superNeoBytes) }
    transcript.absorb(transcriptEncodeCount(input.priorClaims.count))
    input.priorClaims.forEach { transcript.absorb($0.superNeoBytes) }
    return transcript
}

private func absorbEvaluationClaimBatch(
    _ claims: [CCSEvaluationClaim],
    into transcript: inout SumCheckTranscript
) {
    transcript.absorb(transcriptEncodeCount(claims.count))
    claims.forEach { transcript.absorb($0.superNeoBytes) }
}

private func replaySumCheckTranscript(
    _ proof: SumcheckProof,
    into transcript: inout SumCheckTranscript,
    expectedDegree: Int,
    expectedRoundCount: Int
) throws {
    guard expectedDegree >= 0 else {
        throw SuperNeoError.invalidParameter("sum-check expected degree must be nonnegative")
    }
    guard proof.rounds.count == expectedRoundCount else {
        throw SuperNeoError.invalidParameter("sum-check round count mismatch")
    }
    guard proof.finalPoint.count == proof.rounds.count else {
        throw SuperNeoError.invalidParameter("sum-check final point length mismatch")
    }

    transcript.absorb(proof.claimedSum.superNeoBytes)
    var claim = proof.claimedSum
    var prefix: [GoldilocksExt2] = []
    prefix.reserveCapacity(proof.rounds.count)

    for round in proof.rounds {
        guard !round.coeffs.isEmpty, round.coeffs.count <= expectedDegree + 1 else {
            throw SuperNeoError.invalidParameter("sum-check round polynomial degree mismatch")
        }
        let g0 = SumcheckVerifier.evaluatePolynomial(round.coeffs, at: .zero)
        let g1 = SumcheckVerifier.evaluatePolynomial(round.coeffs, at: .one)
        guard g0 + g1 == claim else {
            throw SuperNeoError.invalidParameter("sum-check round polynomial does not match running claim")
        }

        transcript.absorb(round.superNeoBytes)
        let challenge = transcript.challengeExt2()
        prefix.append(challenge)
        claim = SumcheckVerifier.evaluatePolynomial(round.coeffs, at: challenge)
    }

    guard prefix == proof.finalPoint else {
        throw SuperNeoError.invalidParameter("sum-check final point transcript mismatch")
    }
    guard claim == proof.finalValue else {
        throw SuperNeoError.invalidParameter("sum-check final value transcript mismatch")
    }
}

private func compressedPublicInputDigest(_ input: SuperNeoPublicFoldInput) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.compressed-public.input.v1".utf8)
            + input.shape.shapeDigest.superNeoBytes
            + transcriptEncodeCount(input.instances.count)
            + input.instances.flatMap(\.superNeoBytes)
            + transcriptEncodeCount(input.priorClaims.count)
            + input.priorClaims.flatMap(\.superNeoBytes)
    )
}

private func transcriptEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func makeQOracle(
    input: SuperNeoFoldInput,
    compiledShape: CompiledCCSShape? = nil,
    transcript: inout SumCheckTranscript,
    parameters: SuperNeoParameters,
    executionPolicy: SuperNeoExecutionPolicy = .default
) throws -> CCSQOracle {
    let numVars = try log2Exact(input.shape.m)
    let alpha = (0..<numVars).map { _ in transcript.challengeExt2() }
    let gamma = transcript.challengeExt2()
    return try CCSQOracle(
        shape: input.shape,
        instances: input.instances,
        witnesses: input.witnesses,
        priorClaims: input.priorClaims,
        alpha: alpha,
        gamma: gamma,
        transformedSparseMatrices: compiledShape?.transformedSparseMatrices,
        parameters: parameters,
        executionPolicy: executionPolicy
    )
}

extension ProofEnvelopeContext {
    public var transcriptBindingBytes: [UInt8] {
        ProofEnvelopeHeader(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain,
            bodyLength: 0
        ).transcriptBindingBytes
    }
}

extension CCSEvaluationClaim {
    fileprivate var publicDataOnly: CCSEvaluationClaim {
        CCSEvaluationClaim(
            commitment: commitment,
            publicInput: publicInput,
            point: point,
            evaluations: evaluations,
            witness: nil
        )
    }

    fileprivate func hasSamePublicData(as other: CCSEvaluationClaim) -> Bool {
        commitment == other.commitment
            && publicInput == other.publicInput
            && point == other.point
            && evaluations == other.evaluations
    }
}

extension Array where Element == CCSEvaluationClaim {
    fileprivate func hasSamePublicData(as other: [CCSEvaluationClaim]) -> Bool {
        count == other.count && zip(self, other).allSatisfy { $0.hasSamePublicData(as: $1) }
    }
}

private func log2Exact(_ value: Int) throws -> Int {
    guard value > 0, (value & (value - 1)) == 0 else {
        throw SuperNeoError.invalidParameter("value must be a positive power of two")
    }
    return value.trailingZeroBitCount
}

private func piCCSMaxDegreePerRound(shape: CCSShape, parameters: SuperNeoParameters) throws -> Int {
    guard !parameters.normRoots.isEmpty else {
        throw SuperNeoError.invalidParameter("PiCCS norm roots cannot be empty")
    }
    return max(shape.relationDegree, parameters.normRoots.count) + 1
}

private func centeredFieldElement(_ value: Int) -> GoldilocksField {
    value >= 0 ? GoldilocksField(UInt64(value)) : -GoldilocksField(UInt64(-value))
}

private func makeGammaPowers(_ gamma: GoldilocksExt2, through maxExponent: Int) throws -> [GoldilocksExt2] {
    guard maxExponent >= 0 else {
        throw SuperNeoError.invalidParameter("gamma power table cannot have negative size")
    }
    var powers = Array(repeating: GoldilocksExt2.one, count: maxExponent + 1)
    guard maxExponent > 0 else { return powers }
    for exponent in 1...maxExponent {
        powers[exponent] = powers[exponent - 1] * gamma
    }
    return powers
}

private struct NormEvaluationPlan {
    private enum Strategy {
        case balancedTernary
        case generic([GoldilocksExt2])
    }

    private let strategy: Strategy

    init(roots: [GoldilocksField]) {
        if roots == [-GoldilocksField.one, .zero, .one] {
            strategy = .balancedTernary
        } else {
            strategy = .generic(roots.map { GoldilocksExt2($0) })
        }
    }

    func evaluate(_ value: GoldilocksExt2) -> GoldilocksExt2 {
        switch strategy {
        case .balancedTernary:
            return value * ((value * value) - .one)
        case .generic(let roots):
            var product = GoldilocksExt2.one
            for root in roots {
                product = product * (value - root)
            }
            return product
        }
    }
}

private struct RelationEvaluationPlan {
    fileprivate struct Factor {
        let valueIndex: Int
        let exponent: Int
    }

    fileprivate struct Term {
        let coefficient: GoldilocksField
        let factors: [Factor]
    }

    let referencedVariableIndices: [Int]

    private let terms: [Term]

    init(polynomial: RelationPolynomial, variableCount: Int) throws {
        guard variableCount == Int(polynomial.variableCount) else {
            throw SuperNeoError.invalidParameter("relation evaluation plan arity mismatch")
        }
        var referencedVariables: Set<Int> = []
        var rawTerms: [(coefficient: GoldilocksField, factors: [(variableIndex: Int, exponent: Int)])] = []
        rawTerms.reserveCapacity(polynomial.monomials.count)
        for monomial in polynomial.monomials {
            var factors: [(variableIndex: Int, exponent: Int)] = []
            factors.reserveCapacity(monomial.exponents.count)
            for (variableIndex, exponent) in monomial.exponents.enumerated() where exponent > 0 {
                referencedVariables.insert(variableIndex)
                factors.append((variableIndex: variableIndex, exponent: Int(exponent)))
            }
            rawTerms.append((coefficient: monomial.coefficient, factors: factors))
        }
        let referencedVariableIndices = referencedVariables.sorted()
        var valueIndexByVariable = Array(repeating: -1, count: variableCount)
        for (valueIndex, variableIndex) in referencedVariableIndices.enumerated() {
            valueIndexByVariable[variableIndex] = valueIndex
        }
        let terms = rawTerms.map { rawTerm in
            Term(
                coefficient: rawTerm.coefficient,
                factors: rawTerm.factors.map { factor in
                    Factor(valueIndex: valueIndexByVariable[factor.variableIndex], exponent: factor.exponent)
                }
            )
        }
        self.terms = terms
        self.referencedVariableIndices = referencedVariableIndices
    }

    func evaluate(referencedValues: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard referencedValues.count == referencedVariableIndices.count else {
            throw SuperNeoError.invalidParameter("relation evaluation referenced value count mismatch")
        }
        var result = GoldilocksExt2.zero
        for term in terms {
            var value = GoldilocksExt2(term.coefficient)
            for factor in term.factors {
                let factorValue = referencedValues[factor.valueIndex]
                switch factor.exponent {
                case 1:
                    value = value * factorValue
                default:
                    value = value * pow(factorValue, factor.exponent)
                }
            }
            result = result + value
        }
        return result
    }

    private func pow(_ value: GoldilocksExt2, _ exponent: Int) -> GoldilocksExt2 {
        guard exponent > 0 else { return .one }
        var result = GoldilocksExt2.one
        var base = value
        var exp = exponent
        while exp > 0 {
            if exp & 1 == 1 {
                result = result * base
            }
            exp >>= 1
            if exp > 0 {
                base = base * base
            }
        }
        return result
    }
}

private struct RelationSourceEvaluationPlan {
    private struct SourceExponent: Hashable {
        let sourceIndex: Int
        let exponent: Int
    }

    private struct SourceTermKey: Hashable {
        let factors: [SourceExponent]
    }

    private struct Factor {
        let sourceIndex: Int
        let exponent: Int
    }

    private struct Term {
        let coefficient: GoldilocksField
        let factors: [Factor]
    }

    let sourceVariableIndices: [Int]
    var isZero: Bool { terms.isEmpty }

    private let terms: [Term]

    init(polynomial: RelationPolynomial, matrices: [SparseMatrixCSR]) throws {
        guard Int(polynomial.variableCount) == matrices.count else {
            throw SuperNeoError.invalidParameter("relation source evaluation plan arity mismatch")
        }

        var sourceIndexByMatrix: [SparseMatrixCSR: Int] = [:]
        var rawSourceVariableIndices: [Int] = []
        var coefficientByKey: [SourceTermKey: GoldilocksField] = [:]
        rawSourceVariableIndices.reserveCapacity(matrices.count)
        coefficientByKey.reserveCapacity(polynomial.monomials.count)

        for monomial in polynomial.monomials {
            var exponentBySourceIndex: [Int: Int] = [:]
            for (variableIndex, exponent) in monomial.exponents.enumerated() where exponent > 0 {
                let rawSourceIndex: Int
                let matrix = matrices[variableIndex]
                if let existing = sourceIndexByMatrix[matrix] {
                    rawSourceIndex = existing
                } else {
                    rawSourceIndex = rawSourceVariableIndices.count
                    sourceIndexByMatrix[matrix] = rawSourceIndex
                    rawSourceVariableIndices.append(variableIndex)
                }
                exponentBySourceIndex[rawSourceIndex, default: 0] += Int(exponent)
            }
            var factors = exponentBySourceIndex.map { entry in
                SourceExponent(sourceIndex: entry.key, exponent: entry.value)
            }
            factors.sort { lhs, rhs in
                if lhs.sourceIndex == rhs.sourceIndex {
                    return lhs.exponent < rhs.exponent
                }
                return lhs.sourceIndex < rhs.sourceIndex
            }
            let key = SourceTermKey(factors: factors)
            coefficientByKey[key, default: .zero] = coefficientByKey[key, default: .zero] + monomial.coefficient
        }

        let nonzeroRawTerms = coefficientByKey
            .filter { $0.value != .zero }
            .sorted { lhs, rhs in Self.isOrdered(lhs.key, before: rhs.key) }
        var usedRawSourceIndices = Set<Int>()
        for (key, _) in nonzeroRawTerms {
            for factor in key.factors {
                usedRawSourceIndices.insert(factor.sourceIndex)
            }
        }
        let orderedRawSourceIndices = usedRawSourceIndices.sorted()
        var compactSourceIndexByRawSource = Array(repeating: -1, count: rawSourceVariableIndices.count)
        for (compactSourceIndex, rawSourceIndex) in orderedRawSourceIndices.enumerated() {
            compactSourceIndexByRawSource[rawSourceIndex] = compactSourceIndex
        }
        let sourceVariableIndices = orderedRawSourceIndices.map { rawSourceVariableIndices[$0] }
        let terms = nonzeroRawTerms.map { entry in
            Term(
                coefficient: entry.value,
                factors: entry.key.factors.map { factor in
                    Factor(
                        sourceIndex: compactSourceIndexByRawSource[factor.sourceIndex],
                        exponent: factor.exponent
                    )
                }
            )
        }

        self.sourceVariableIndices = sourceVariableIndices
        self.terms = terms
    }

    func evaluate(sourceValues: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard sourceValues.count == sourceVariableIndices.count else {
            throw SuperNeoError.invalidParameter("relation source evaluation value count mismatch")
        }
        var result = GoldilocksExt2.zero
        for term in terms {
            var value = GoldilocksExt2(term.coefficient)
            for factor in term.factors {
                let sourceValue = sourceValues[factor.sourceIndex]
                switch factor.exponent {
                case 1:
                    value = value * sourceValue
                default:
                    value = value * pow(sourceValue, factor.exponent)
                }
            }
            result = result + value
        }
        return result
    }

    private static func isOrdered(_ lhs: SourceTermKey, before rhs: SourceTermKey) -> Bool {
        let sharedCount = min(lhs.factors.count, rhs.factors.count)
        for index in 0..<sharedCount {
            let lhsFactor = lhs.factors[index]
            let rhsFactor = rhs.factors[index]
            if lhsFactor.sourceIndex != rhsFactor.sourceIndex {
                return lhsFactor.sourceIndex < rhsFactor.sourceIndex
            }
            if lhsFactor.exponent != rhsFactor.exponent {
                return lhsFactor.exponent < rhsFactor.exponent
            }
        }
        return lhs.factors.count < rhs.factors.count
    }

    private func pow(_ value: GoldilocksExt2, _ exponent: Int) -> GoldilocksExt2 {
        guard exponent > 0 else { return .one }
        var result = GoldilocksExt2.one
        var base = value
        var exp = exponent
        while exp > 0 {
            if exp & 1 == 1 {
                result = result * base
            }
            exp >>= 1
            if exp > 0 {
                base = base * base
            }
        }
        return result
    }
}

private func validateStrongSamplingCapacity(
    freshCount: Int,
    priorCount: Int,
    parameters: SuperNeoParameters
) throws {
    guard freshCount >= 0, priorCount >= 0 else {
        throw SuperNeoError.invalidParameter("fold batch counts must be nonnegative")
    }
    guard freshCount <= parameters.maxFreshBatchCount else {
        throw SuperNeoError.invalidParameter("fresh CCS batch exceeds profile maximum")
    }
    guard priorCount <= parameters.maxPriorClaimCount else {
        throw SuperNeoError.invalidParameter("prior CE batch exceeds profile maximum")
    }
    let (batchCount, countOverflow) = freshCount.addingReportingOverflow(priorCount)
    guard !countOverflow else {
        throw SuperNeoError.invalidParameter("fold batch count overflows Int")
    }
    guard batchCount > 0 else {
        throw SuperNeoError.invalidParameter("fold batch requires at least one claim")
    }
    let foldedBound = try foldedNormBound(parameters: parameters)
    let multiplier = UInt64(batchCount)
    let expansion = UInt64(parameters.challengeExpansionFactor)
    let baseSlack = UInt64(parameters.normBound - 1)
    let (leftA, overflowA) = multiplier.multipliedReportingOverflow(by: expansion)
    let (left, overflowB) = leftA.multipliedReportingOverflow(by: baseSlack)
    guard !overflowA, !overflowB, left < foldedBound else {
        throw SuperNeoError.invalidParameter("fold batch exceeds strong-sampling norm budget")
    }
}

private struct CEPrivateTarget: Equatable {
    let commitment: AjtaiCommitment
    let matrixEvals: [CyclotomicExt2Ring54]
}

private struct CEPrivateLinearComputation: Equatable, Sendable {
    let commitment: AjtaiCommitment
    let matrixEvals: [CyclotomicExt2Ring54]
}

private struct CEOpeningProverRoundMaterial {
    let openings: [CEOpeningProverOpeningMaterial]
    let commitments: [CEOpeningProofCommitments]
}

private struct CEOpeningProverOpeningMaterial {
    let permutation: [Int]
    let permutationBytes: [UInt8]
    let mask: [GoldilocksField]
    let masked: [GoldilocksField]
    let permutedMask: [GoldilocksField]
    let permutedMasked: [GoldilocksField]
}

private struct CEOpeningVerifierLinearJob {
    let challenge: Int
    let roundIndex: Int
    let openingIndex: Int
    let permutationBytes: [UInt8]
    let vector: [GoldilocksField]
    let commitments: CEOpeningProofCommitments
}

private func ceParallelMap<T: Sendable>(
    count: Int,
    _ body: @Sendable (Int) throws -> T
) throws -> [T] {
    guard count > 1 else {
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
            throw SuperNeoError.invalidParameter("CE parallel map missing result at index \(index)")
        }
        return try result.get()
    }
}

private func makeProverRoundBatch(
    roundRange: Range<Int>,
    privateWitnesses: [[GoldilocksField]],
    statement: TerminalCEStatement,
    proverContext: CEOpeningPrivateLinearBatchContext,
    rng: inout DeterministicRNG
) throws -> [CEOpeningProverRoundMaterial] {
    guard statement.openings.count == privateWitnesses.count else {
        throw SuperNeoError.invalidParameter("CE opening proof witness count mismatch")
    }
    let openingCount = statement.openings.count
    guard openingCount > 0 else {
        throw SuperNeoError.invalidParameter("CE opening proof requires at least one opening")
    }
    let batchCount = roundRange.count * openingCount
    var batchedOpenings: [[CEOpeningProverOpeningMaterial]] = []
    var vectors: [[GoldilocksField]] = []
    var openingIndices: [Int] = []
    batchedOpenings.reserveCapacity(roundRange.count)
    vectors.reserveCapacity(batchCount)
    openingIndices.reserveCapacity(batchCount)

    for _ in roundRange {
        var roundOpenings: [CEOpeningProverOpeningMaterial] = []
        roundOpenings.reserveCapacity(openingCount)
        for openingIndex in statement.openings.indices {
            let witness = privateWitnesses[openingIndex]
            let permutation = samplePermutation(count: witness.count, rng: &rng)
            let mask = (0..<witness.count).map { _ in rng.nextField() }
            let masked = ceVectorAdd(mask, witness)
            let material = CEOpeningProverOpeningMaterial(
                permutation: permutation,
                permutationBytes: ceEncodePermutation(permutation),
                mask: mask,
                masked: masked,
                permutedMask: applyPermutation(mask, permutation),
                permutedMasked: applyPermutation(masked, permutation)
            )
            roundOpenings.append(material)
            vectors.append(mask)
            openingIndices.append(openingIndex)
        }
        batchedOpenings.append(roundOpenings)
    }

    let maskInstances = try SuperNeoBenchmarkSignpost.measure("ceProverPrivateLinearBatch") {
        try proverContext.makePrivateLinearInstances(
            vectors: vectors,
            openingIndices: openingIndices
        )
    }
    guard maskInstances.count == batchCount else {
        throw SuperNeoError.invalidParameter("CE opening prover batch output count mismatch")
    }

    var flatIndex = 0
    return batchedOpenings.enumerated().map { roundOffset, openings in
        let roundIndex = roundRange.lowerBound + roundOffset
        var commitments: [CEOpeningProofCommitments] = []
        commitments.reserveCapacity(openingCount)
        for (openingIndex, opening) in openings.enumerated() {
            let maskInstance = maskInstances[flatIndex]
            commitments.append(CEOpeningProofCommitments(
                maskLinearDigest: ceOpeningDigest(
                    tag: 1,
                    roundIndex: roundIndex,
                    openingIndex: openingIndex,
                    payload: opening.permutationBytes + maskInstance.superNeoBytes
                ),
                permutedMaskDigest: ceOpeningDigest(
                    tag: 2,
                    roundIndex: roundIndex,
                    openingIndex: openingIndex,
                    payload: ceEncodeVector(opening.permutedMask)
                ),
                permutedMaskedWitnessDigest: ceOpeningDigest(
                    tag: 3,
                    roundIndex: roundIndex,
                    openingIndex: openingIndex,
                    payload: ceEncodeVector(opening.permutedMasked)
                )
            ))
            flatIndex += 1
        }
        return CEOpeningProverRoundMaterial(openings: openings, commitments: commitments)
    }
}

private struct CEOpeningPrivateLinearBatchContext {
    let shape: CCSShape
    let key: AjtaiCommitmentKey
    let transformedMatrices: [SparseRingMatrixCSR]
    let metalWorkspace: SuperNeoMetalWorkspace?
    let executionPolicy: SuperNeoExecutionPolicy
    let openings: [CEOpeningPrivateLinearOpeningContext]

    init(
        statement: TerminalCEStatement,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws {
        guard transformedMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("compiled transformed matrix count mismatch")
        }
        if let metalWorkspace {
            guard metalWorkspace.key == key else {
                throw SuperNeoError.invalidParameter("CE opening Metal workspace key mismatch")
            }
            guard metalWorkspace.transformedMatrixCount == transformedMatrices.count else {
                throw SuperNeoError.invalidParameter("CE opening Metal workspace transformed matrix count mismatch")
            }
            if let shapeDigest = metalWorkspace.shapeDigest {
                guard shapeDigest == shape.shapeDigest else {
                    throw SuperNeoError.invalidParameter("CE opening Metal workspace shape digest mismatch")
                }
            }
            let expectedDigest = SuperNeoMetalWorkspace.transformedMatricesDigest(for: transformedMatrices)
            guard metalWorkspace.transformedMatricesDigest == expectedDigest else {
                throw SuperNeoError.invalidParameter("CE opening Metal workspace transformed matrix digest mismatch")
            }
        }
        let expectedPointCount = try log2Exact(shape.m)
        self.shape = shape
        self.key = key
        self.transformedMatrices = transformedMatrices
        self.metalWorkspace = metalWorkspace
        self.executionPolicy = executionPolicy
        self.openings = try statement.openings.map { opening in
            try CEOpeningPrivateLinearOpeningContext(
                opening: opening,
                shape: shape,
                expectedPointCount: expectedPointCount
            )
        }
    }

    func opening(at index: Int) -> CEOpeningPrivateLinearOpeningContext {
        openings[index]
    }

    func makePrivateLinearInstances(
        vectors: [[GoldilocksField]],
        openingIndices: [Int]
    ) throws -> [CEInstance] {
        guard vectors.count == openingIndices.count else {
            throw SuperNeoError.invalidParameter("CE opening private-linear batch count mismatch")
        }

        let packedWitnesses = try zip(vectors, openingIndices).map { vector, openingIndex in
            try opening(at: openingIndex).packedZeroPublicWitness(privateVector: vector, shape: shape)
        }
        if let metalWorkspace,
           !executionPolicy.usesConstantWorkCPU,
           let sharedPoint = sharedEvaluationPoint(for: openingIndices) {
            let computations = try SuperNeoBenchmarkSignpost.measure("ceMetalCombinedCommitEval") {
                try makeMetalPrivateLinearComputations(
                    packedWitnesses: packedWitnesses,
                    point: sharedPoint,
                    metalWorkspace: metalWorkspace
                )
            }
            if executionPolicy.requiresMetalCPUCheck {
                let cpuComputations = try makeCPUPrivateLinearComputations(
                    packedWitnesses: packedWitnesses,
                    openingIndices: openingIndices
                )
                guard computations == cpuComputations else {
                    throw SuperNeoError.metalFailure("Metal CE private-linear batch failed CPU cross-check")
                }
            }
            return openingIndices.indices.map { index in
                let openingContext = opening(at: openingIndices[index])
                return CEInstance(
                    commitment: computations[index].commitment,
                    publicInput: openingContext.publicZeros,
                    evalPoint: openingContext.statement.instance.evalPoint,
                    matrixEvals: computations[index].matrixEvals
                )
            }
        }

        let computations = try SuperNeoBenchmarkSignpost.measure("ceCPUCombinedCommitEval") {
            try makeCPUPrivateLinearComputations(
                packedWitnesses: packedWitnesses,
                openingIndices: openingIndices
            )
        }

        return openingIndices.indices.map { index in
            let openingContext = opening(at: openingIndices[index])
            return CEInstance(
                commitment: computations[index].commitment,
                publicInput: openingContext.publicZeros,
                evalPoint: openingContext.statement.instance.evalPoint,
                matrixEvals: computations[index].matrixEvals
            )
        }
    }

    private func makeCPUPrivateLinearComputations(
        packedWitnesses: [[CyclotomicRing54]],
        openingIndices: [Int]
    ) throws -> [CEPrivateLinearComputation] {
        try ceParallelMap(count: packedWitnesses.count) { index in
            let packed = packedWitnesses[index]
            let openingIndex = openingIndices[index]
            let openingContext = opening(at: openingIndex)
            let commitment: AjtaiCommitment
            if executionPolicy.usesConstantWorkCPU {
                commitment = try AjtaiCommitter.commitConstantWorkReference(key: key, message: packed)
            } else {
                commitment = try AjtaiCommitter.commitReference(key: key, message: packed)
            }
            let matrixEvals = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
                try SuperNeoProtocolOracle.evaluateTransformedMatrix(
                    matrix,
                    by: packed,
                    rHat: openingContext.rHat,
                    executionPolicy: executionPolicy
                )
            }
            return CEPrivateLinearComputation(commitment: commitment, matrixEvals: matrixEvals)
        }
    }

    private func makeMetalPrivateLinearComputations(
        packedWitnesses: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        metalWorkspace: SuperNeoMetalWorkspace
    ) throws -> [CEPrivateLinearComputation] {
        guard !packedWitnesses.isEmpty else { return [] }
        let maxBatchSize = AjtaiMatvecSchedule.default.maxBatchSize
        var computations: [CEPrivateLinearComputation] = []
        computations.reserveCapacity(packedWitnesses.count)

        var batchStart = 0
        while batchStart < packedWitnesses.count {
            let batchEnd = min(batchStart + maxBatchSize, packedWitnesses.count)
            let combined = try metalWorkspace.commitmentsAndTransformedEvaluations(
                messages: Array(packedWitnesses[batchStart..<batchEnd]),
                point: point
            )
            guard combined.commitments.count == batchEnd - batchStart,
                  combined.evaluations.count == batchEnd - batchStart else {
                throw SuperNeoError.invalidParameter("CE opening Metal batch output count mismatch")
            }
            computations.append(contentsOf: combined.commitments.indices.map { index in
                CEPrivateLinearComputation(
                    commitment: combined.commitments[index],
                    matrixEvals: combined.evaluations[index]
                )
            })
            batchStart = batchEnd
        }
        return computations
    }

    private func sharedEvaluationPoint(for openingIndices: [Int]) -> [GoldilocksExt2]? {
        guard let firstIndex = openingIndices.first else { return [] }
        let firstPoint = opening(at: firstIndex).statement.instance.evalPoint
        for openingIndex in openingIndices.dropFirst() where opening(at: openingIndex).statement.instance.evalPoint != firstPoint {
            return nil
        }
        return firstPoint
    }
}

private struct CEOpeningPrivateLinearOpeningContext {
    let statement: CEOpeningStatement
    let publicZeros: [GoldilocksField]
    let rHat: [GoldilocksExt2]

    init(
        opening: CEOpeningStatement,
        shape: CCSShape,
        expectedPointCount: Int
    ) throws {
        guard opening.instance.publicInput.count == shape.nPublicField else {
            throw SuperNeoError.invalidParameter("CE opening public input length mismatch")
        }
        guard opening.instance.evalPoint.count == expectedPointCount else {
            throw SuperNeoError.invalidParameter("CE opening evaluation point length mismatch")
        }
        guard opening.instance.matrixEvals.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("CE opening matrix evaluation arity mismatch")
        }

        let publicZeros = Array(repeating: GoldilocksField.zero, count: opening.instance.publicInput.count)
        let rHat = try MultilinearEvaluation.checkedBasis(at: opening.instance.evalPoint)

        self.statement = opening
        self.publicZeros = publicZeros
        self.rHat = rHat
    }

    func acceptsPrivateVector(count: Int, shape: CCSShape) throws -> Bool {
        try isValidPrivateVectorLength(count, publicInputCount: publicZeros.count, shape: shape)
    }

    func packedZeroPublicWitness(privateVector: [GoldilocksField], shape: CCSShape) throws -> [CyclotomicRing54] {
        guard try acceptsPrivateVector(count: privateVector.count, shape: shape) else {
            throw SuperNeoError.invalidParameter("CE opening private vector length mismatch")
        }
        return try packedEvaluationWitness(publicZeros + privateVector, shape: shape)
    }
}

private struct CEOpeningVerifierContext {
    let linearContext: CEOpeningPrivateLinearBatchContext
    let parameters: SuperNeoParameters
    let targets: [CEPrivateTarget]

    var shape: CCSShape { linearContext.shape }

    init(
        statement: TerminalCEStatement,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        parameters: SuperNeoParameters,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws {
        let linearContext = try CEOpeningPrivateLinearBatchContext(
            statement: statement,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
        self.linearContext = linearContext
        self.parameters = parameters
        self.targets = try makeCEPrivateTargets(
            openingContexts: linearContext.openings,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices,
            metalWorkspace: metalWorkspace,
            executionPolicy: executionPolicy
        )
    }

    func opening(at index: Int) -> CEOpeningPrivateLinearOpeningContext {
        linearContext.opening(at: index)
    }

    func target(at index: Int) -> CEPrivateTarget {
        targets[index]
    }

    func makePrivateLinearInstances(
        vectors: [[GoldilocksField]],
        openingIndices: [Int]
    ) throws -> [CEInstance] {
        try linearContext.makePrivateLinearInstances(vectors: vectors, openingIndices: openingIndices)
    }
}

private func makeCEPrivateTarget(
    openingContext: CEOpeningPrivateLinearOpeningContext,
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [SparseRingMatrixCSR],
    executionPolicy: SuperNeoExecutionPolicy
) throws -> CEPrivateTarget {
    let opening = openingContext.statement
    guard opening.instance.commitment.elements.count == key.parameters.kappa else {
        throw SuperNeoError.invalidParameter("CE opening commitment has wrong length")
    }
    let packedPublicWitness = try makeCEPublicPackedWitness(openingContext: openingContext, shape: shape)
    let publicCommitment = try SuperNeoBenchmarkSignpost.measure("ceTargetAjtaiCommit") {
        if executionPolicy.usesConstantWorkCPU {
            return try AjtaiCommitter.commitConstantWorkReference(key: key, message: packedPublicWitness)
        }
        return try AjtaiCommitter.commitReference(key: key, message: packedPublicWitness)
    }
    let publicEvaluations = try SuperNeoBenchmarkSignpost.measure("ceTargetTransformedEval") {
        try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
            try SuperNeoProtocolOracle.evaluateTransformedMatrix(
                matrix,
                by: packedPublicWitness,
                rHat: openingContext.rHat,
                executionPolicy: executionPolicy
            )
        }
    }

    return CEPrivateTarget(
        commitment: opening.instance.commitment - publicCommitment,
        matrixEvals: try ceVectorSubtract(opening.instance.matrixEvals, publicEvaluations)
    )
}

private func makeCEPrivateTargets(
    openingContexts: [CEOpeningPrivateLinearOpeningContext],
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [SparseRingMatrixCSR],
    metalWorkspace: SuperNeoMetalWorkspace?,
    executionPolicy: SuperNeoExecutionPolicy
) throws -> [CEPrivateTarget] {
    guard !openingContexts.isEmpty else { return [] }
    guard let metalWorkspace, !executionPolicy.usesConstantWorkCPU else {
        return try ceParallelMap(count: openingContexts.count) { index in
            try makeCEPrivateTarget(
                openingContext: openingContexts[index],
                shape: shape,
                key: key,
                transformedMatrices: transformedMatrices,
                executionPolicy: executionPolicy
            )
        }
    }

    var groupedIndices: [(point: [GoldilocksExt2], indices: [Int])] = []
    for index in openingContexts.indices {
        let point = openingContexts[index].statement.instance.evalPoint
        if let groupIndex = groupedIndices.firstIndex(where: { $0.point == point }) {
            groupedIndices[groupIndex].indices.append(index)
        } else {
            groupedIndices.append((point: point, indices: [index]))
        }
    }

    var targets = Array<CEPrivateTarget?>(repeating: nil, count: openingContexts.count)
    for group in groupedIndices {
        let packedWitnesses = try group.indices.map {
            try makeCEPublicPackedWitness(openingContext: openingContexts[$0], shape: shape)
        }
        let combined = try SuperNeoBenchmarkSignpost.measure("ceTargetMetalCombinedCommitEval") {
            try metalWorkspace.commitmentsAndTransformedEvaluations(
                messages: packedWitnesses,
                point: group.point
            )
        }
        guard combined.commitments.count == group.indices.count,
              combined.evaluations.count == group.indices.count else {
            throw SuperNeoError.invalidParameter("CE opening Metal target output count mismatch")
        }
        for (offset, openingIndex) in group.indices.enumerated() {
            let opening = openingContexts[openingIndex].statement
            guard opening.instance.commitment.elements.count == key.parameters.kappa else {
                throw SuperNeoError.invalidParameter("CE opening commitment has wrong length")
            }
            targets[openingIndex] = CEPrivateTarget(
                commitment: opening.instance.commitment - combined.commitments[offset],
                matrixEvals: try ceVectorSubtract(opening.instance.matrixEvals, combined.evaluations[offset])
            )
            if executionPolicy.requiresMetalCPUCheck {
                let cpuTarget = try makeCEPrivateTarget(
                    openingContext: openingContexts[openingIndex],
                    shape: shape,
                    key: key,
                    transformedMatrices: transformedMatrices,
                    executionPolicy: executionPolicy
                )
                guard targets[openingIndex] == cpuTarget else {
                    throw SuperNeoError.metalFailure("Metal CE target preparation failed CPU cross-check")
                }
            }
        }
    }

    return try targets.enumerated().map { index, target in
        guard let target else {
            throw SuperNeoError.invalidParameter("CE opening target missing at index \(index)")
        }
        return target
    }
}

private func makeCEPublicPackedWitness(
    openingContext: CEOpeningPrivateLinearOpeningContext,
    shape: CCSShape
) throws -> [CyclotomicRing54] {
    let publicInput = openingContext.statement.instance.publicInput
    let publicPrivateCount = shape.nField - publicInput.count
    guard publicPrivateCount >= 0 else {
        throw SuperNeoError.invalidParameter("CE opening public input exceeds witness length")
    }
    return try packedEvaluationWitness(
        publicInput + Array(repeating: GoldilocksField.zero, count: publicPrivateCount),
        shape: shape
    )
}

private func validatePrivateOpenings(
    statement: TerminalCEStatement,
    witnesses: [CEOpeningWitness],
    privateWitnesses: [[GoldilocksField]],
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [SparseRingMatrixCSR],
    parameters: SuperNeoParameters,
    executionPolicy: SuperNeoExecutionPolicy
) throws {
    guard witnesses.count == privateWitnesses.count else {
        throw SuperNeoError.invalidParameter("CE opening private witness count mismatch")
    }
    try zip(statement.openings.indices, zip(statement.openings, witnesses)).forEach { index, pair in
        let (opening, witness) = pair
        guard privateWitnesses[index].count + opening.instance.publicInput.count == witness.witness.count else {
            throw SuperNeoError.invalidParameter("CE opening private witness length mismatch")
        }
        let openedClaim = CCSEvaluationClaim(
            commitment: opening.instance.commitment,
            publicInput: opening.instance.publicInput,
            point: opening.instance.evalPoint,
            evaluations: opening.instance.matrixEvals,
            witness: witness.witness
        )
        guard try SuperNeoProtocolOracle.verifyEvaluationClaimOpening(
            shape: shape,
            transformedMatrices: transformedMatrices,
            claim: openedClaim,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        ) else {
            throw SuperNeoError.invalidParameter("CE opening witness does not satisfy statement")
        }
    }
}

private func privateWitness(from witness: [GoldilocksField], shape: CCSShape) throws -> [GoldilocksField] {
    guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
        throw SuperNeoError.invalidParameter("CE opening witness length must match the original or padded ring length")
    }
    guard witness.count >= shape.nPublicField else {
        throw SuperNeoError.invalidParameter("CE opening witness length is shorter than public input")
    }
    return Array(witness.dropFirst(shape.nPublicField))
}

private func validatePriorCEClaimWitnesses(
    input: SuperNeoFoldInput,
    key: AjtaiCommitmentKey,
    transformedMatrices: [SparseRingMatrixCSR],
    parameters: SuperNeoParameters,
    executionPolicy: SuperNeoExecutionPolicy = .default
) throws {
    guard !input.priorClaims.isEmpty else { return }
    guard transformedMatrices.count == input.shape.numMatrices else {
        throw SuperNeoError.invalidParameter("compiled transformed matrix count mismatch")
    }
    for claim in input.priorClaims {
        guard try SuperNeoProtocolOracle.verifyEvaluationClaimOpening(
            shape: input.shape,
            transformedMatrices: transformedMatrices,
            claim: claim,
            key: key,
            parameters: parameters,
            executionPolicy: executionPolicy
        ) else {
            throw SuperNeoError.invalidParameter("prior CE claim witness does not satisfy its commitment/evaluation opening")
        }
    }
}

private func subtractTarget(_ instance: CEInstance, target: CEPrivateTarget) throws -> CEInstance {
    let matrixEvals = try ceVectorSubtract(instance.matrixEvals, target.matrixEvals)
    return CEInstance(
        commitment: instance.commitment - target.commitment,
        publicInput: instance.publicInput,
        evalPoint: instance.evalPoint,
        matrixEvals: matrixEvals
    )
}

private func verifyBatchedProofResponses(
    proof: CEOpeningProof,
    statement: TerminalCEStatement,
    verifierContext: CEOpeningVerifierContext
) throws -> Bool {
    var transcript = makeCEOpeningTranscript(statement: statement)
    transcript.absorb(ceEncodeCount(proof.rounds.count))

    let jobs: [CEOpeningVerifierLinearJob]? = try SuperNeoBenchmarkSignpost.measure("ceVerifyResponseScan") { () -> [CEOpeningVerifierLinearJob]? in
        var jobs: [CEOpeningVerifierLinearJob] = []
        jobs.reserveCapacity(proof.rounds.count * statement.openings.count)

        for (roundIndex, round) in proof.rounds.enumerated() {
            guard round.commitments.count == statement.openings.count else { return nil }
            transcript.absorb(round.commitments.flatMap(\.superNeoBytes))
            let challenge = ceOpeningChallenge(transcript: &transcript)
            let roundJobs: [CEOpeningVerifierLinearJob]?
            switch (challenge, round.response) {
            case (0, .mask(let openings)):
                roundJobs = try collectMaskRoundLinearJobs(
                    openings: openings,
                    roundIndex: roundIndex,
                    commitments: round.commitments,
                    statement: statement,
                    verifierContext: verifierContext
                )
            case (1, .maskedWitness(let openings)):
                roundJobs = try collectMaskedWitnessRoundLinearJobs(
                    openings: openings,
                    roundIndex: roundIndex,
                    commitments: round.commitments,
                    statement: statement,
                    verifierContext: verifierContext
                )
            case (2, .permutedWitness(let openings)):
                guard try verifyPermutedWitnessRoundResponse(
                    openings: openings,
                    roundIndex: roundIndex,
                    commitments: round.commitments,
                    statement: statement,
                    verifierContext: verifierContext
                ) else {
                    return nil
                }
                roundJobs = []
            default:
                return nil
            }
            guard let roundJobs else { return nil }
            jobs.append(contentsOf: roundJobs)
            transcript.absorb(round.response.superNeoBytes)
        }
        return jobs
    }

    guard let jobs else { return false }
    return try verifyCollectedLinearJobs(jobs, verifierContext: verifierContext)
}

private func collectMaskRoundLinearJobs(
    openings: [CEOpeningLinearResponse],
    roundIndex: Int,
    commitments: [CEOpeningProofCommitments],
    statement: TerminalCEStatement,
    verifierContext: CEOpeningVerifierContext
) throws -> [CEOpeningVerifierLinearJob]? {
    guard openings.count == statement.openings.count else { return nil }
    var jobs: [CEOpeningVerifierLinearJob] = []
    jobs.reserveCapacity(openings.count)

    for index in openings.indices {
        let opening = openings[index]
        guard isValidPermutation(opening.permutation, count: opening.vector.count) else { return nil }
        guard try verifierContext.opening(at: index).acceptsPrivateVector(
            count: opening.vector.count,
            shape: verifierContext.shape
        ) else {
            return nil
        }
        let permutedMask = applyPermutation(opening.vector, opening.permutation)
        guard commitments[index].permutedMaskDigest == ceOpeningDigest(
            tag: 2,
            roundIndex: roundIndex,
            openingIndex: index,
            payload: ceEncodeVector(permutedMask)
        ) else {
            return nil
        }
        jobs.append(CEOpeningVerifierLinearJob(
            challenge: 0,
            roundIndex: roundIndex,
            openingIndex: index,
            permutationBytes: ceEncodePermutation(opening.permutation),
            vector: opening.vector,
            commitments: commitments[index]
        ))
    }
    return jobs
}

private func collectMaskedWitnessRoundLinearJobs(
    openings: [CEOpeningLinearResponse],
    roundIndex: Int,
    commitments: [CEOpeningProofCommitments],
    statement: TerminalCEStatement,
    verifierContext: CEOpeningVerifierContext
) throws -> [CEOpeningVerifierLinearJob]? {
    guard openings.count == statement.openings.count else { return nil }
    var jobs: [CEOpeningVerifierLinearJob] = []
    jobs.reserveCapacity(openings.count)

    for index in openings.indices {
        let opening = openings[index]
        guard isValidPermutation(opening.permutation, count: opening.vector.count) else { return nil }
        guard try verifierContext.opening(at: index).acceptsPrivateVector(
            count: opening.vector.count,
            shape: verifierContext.shape
        ) else {
            return nil
        }
        let permutedMasked = applyPermutation(opening.vector, opening.permutation)
        guard commitments[index].permutedMaskedWitnessDigest == ceOpeningDigest(
            tag: 3,
            roundIndex: roundIndex,
            openingIndex: index,
            payload: ceEncodeVector(permutedMasked)
        ) else {
            return nil
        }
        jobs.append(CEOpeningVerifierLinearJob(
            challenge: 1,
            roundIndex: roundIndex,
            openingIndex: index,
            permutationBytes: ceEncodePermutation(opening.permutation),
            vector: opening.vector,
            commitments: commitments[index]
        ))
    }
    return jobs
}

private func verifyCollectedLinearJobs(
    _ jobs: [CEOpeningVerifierLinearJob],
    verifierContext: CEOpeningVerifierContext
) throws -> Bool {
    guard !jobs.isEmpty else { return true }
    let instances = try SuperNeoBenchmarkSignpost.measure("ceVerifyPrivateLinearBatch") {
        try verifierContext.makePrivateLinearInstances(
            vectors: jobs.map(\.vector),
            openingIndices: jobs.map(\.openingIndex)
        )
    }
    guard instances.count == jobs.count else {
        throw SuperNeoError.invalidParameter("CE opening verifier batch output count mismatch")
    }

    for index in jobs.indices {
        let job = jobs[index]
        let instance: CEInstance
        switch job.challenge {
        case 0:
            instance = instances[index]
        case 1:
            instance = try subtractTarget(instances[index], target: verifierContext.target(at: job.openingIndex))
        default:
            throw SuperNeoError.invalidParameter("unexpected CE verifier private-linear challenge")
        }
        guard job.commitments.maskLinearDigest == ceOpeningDigest(
            tag: 1,
            roundIndex: job.roundIndex,
            openingIndex: job.openingIndex,
            payload: job.permutationBytes + instance.superNeoBytes
        ) else {
            return false
        }
    }
    return true
}

private func verifyPermutedWitnessRoundResponse(
    openings: [CEOpeningNormResponse],
    roundIndex: Int,
    commitments: [CEOpeningProofCommitments],
    statement: TerminalCEStatement,
    verifierContext: CEOpeningVerifierContext
) throws -> Bool {
    guard openings.count == statement.openings.count else { return false }
    for index in openings.indices {
        let opening = openings[index]
        guard opening.permutedMask.count == opening.permutedWitness.count else { return false }
        guard try verifierContext.opening(at: index).acceptsPrivateVector(
            count: opening.permutedWitness.count,
            shape: verifierContext.shape
        ) else {
            return false
        }
        guard opening.permutedWitness.allSatisfy({
            signedMagnitude($0) < UInt64(verifierContext.parameters.normBound)
        }) else {
            return false
        }
        guard commitments[index].permutedMaskDigest == ceOpeningDigest(
            tag: 2,
            roundIndex: roundIndex,
            openingIndex: index,
            payload: ceEncodeVector(opening.permutedMask)
        ) else {
            return false
        }
        let masked = ceVectorAdd(opening.permutedMask, opening.permutedWitness)
        guard commitments[index].permutedMaskedWitnessDigest == ceOpeningDigest(
            tag: 3,
            roundIndex: roundIndex,
            openingIndex: index,
            payload: ceEncodeVector(masked)
        ) else {
            return false
        }
    }
    return true
}

private func isValidPrivateVectorLength(_ privateCount: Int, publicInputCount: Int, shape: CCSShape) throws -> Bool {
    let total = publicInputCount + privateCount
    return publicInputCount == shape.nPublicField && isValidEvaluationWitnessLength(total, shape: shape)
}

private func makeCEOpeningTranscript(statement: TerminalCEStatement) -> SumCheckTranscript {
    var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.ce-opening.stern")
    transcript.absorb(statement.superNeoBytes)
    return transcript
}

private func ceOpeningChallenge(transcript: inout SumCheckTranscript) -> Int {
    let bound = GoldilocksField.modulus - (GoldilocksField.modulus % 3)
    while true {
        let raw = transcript.challengeField().rawValue
        if raw < bound {
            return Int(raw % 3)
        }
    }
}

private func ceOpeningDigest(tag: UInt8, roundIndex: Int, openingIndex: Int, payload: [UInt8]) -> Digest256 {
    Digest256.hash(
        Array("SuperNeo-NuMetal.ce-opening.commitment".utf8)
            + [tag]
            + ceEncodeCount(roundIndex)
            + ceEncodeCount(openingIndex)
            + ceEncodeCount(payload.count)
            + payload
    )
}

private func ceEncodeVector(_ vector: [GoldilocksField]) -> [UInt8] {
    ceEncodeCount(vector.count) + vector.flatMap(\.superNeoBytes)
}

private func ceEncodePermutation(_ permutation: [Int]) -> [UInt8] {
    ceEncodeCount(permutation.count) + permutation.flatMap { index in
        withUnsafeBytes(of: UInt64(index).littleEndian, Array.init)
    }
}

private func ceEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func ceVectorAdd(_ lhs: [GoldilocksField], _ rhs: [GoldilocksField]) -> [GoldilocksField] {
    zip(lhs, rhs).map(+)
}

private func ceVectorSubtract(_ lhs: [CyclotomicExt2Ring54], _ rhs: [CyclotomicExt2Ring54]) throws -> [CyclotomicExt2Ring54] {
    guard lhs.count == rhs.count else {
        throw SuperNeoError.invalidParameter("CE vector length mismatch")
    }
    return zip(lhs, rhs).map(-)
}

private func applyPermutation(_ vector: [GoldilocksField], _ permutation: [Int]) -> [GoldilocksField] {
    permutation.map { vector[$0] }
}

private func isValidPermutation(_ permutation: [Int], count: Int) -> Bool {
    guard permutation.count == count else { return false }
    var seen = Array(repeating: false, count: count)
    for index in permutation {
        guard index >= 0, index < count, !seen[index] else { return false }
        seen[index] = true
    }
    return true
}

private func samplePermutation(count: Int, rng: inout DeterministicRNG) -> [Int] {
    guard count > 1 else { return Array(0..<count) }
    var permutation = Array(0..<count)
    for index in stride(from: count - 1, through: 1, by: -1) {
        let swapIndex = ceUniformIndex(upperBound: index + 1, rng: &rng)
        permutation.swapAt(index, swapIndex)
    }
    return permutation
}

private func ceUniformIndex(upperBound: Int, rng: inout DeterministicRNG) -> Int {
    guard upperBound > 1 else { return 0 }
    let bound = UInt64(upperBound)
    let limit = UInt64.max - (UInt64.max % bound)
    while true {
        let value = rng.nextUInt64()
        if value < limit {
            return Int(value % bound)
        }
    }
}

private func ceOpeningProverRandomSeed(randomnessSeed: [UInt8], statement: TerminalCEStatement) -> [UInt8] {
    let statementBytes = statement.superNeoBytes
    return Digest256.hash(
        Array("SuperNeo-NuMetal.ce-opening.prover-rng.v1".utf8)
            + ceEncodeCount(randomnessSeed.count)
            + randomnessSeed
            + ceEncodeCount(statementBytes.count)
            + statementBytes
    ).bytes
}

private func makeSystemRandomSeed() throws -> [UInt8] {
    var seed = [UInt8](repeating: 0, count: 32)
    let status = seed.withUnsafeMutableBytes { bytes in
        SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
    }
    guard status == errSecSuccess else {
        throw SuperNeoError.randomnessUnavailable("SecRandomCopyBytes failed with OSStatus \(status)")
    }
    return seed
}

private func foldedNormBound(parameters: SuperNeoParameters) throws -> UInt64 {
    guard parameters.normBound >= 2, parameters.decompositionLength > 0 else {
        throw SuperNeoError.invalidParameter("invalid decomposition norm parameters")
    }
    var bound: UInt64 = 1
    let base = UInt64(parameters.normBound)
    for _ in 0..<parameters.decompositionLength {
        let (next, overflow) = bound.multipliedReportingOverflow(by: base)
        guard !overflow else {
            throw SuperNeoError.invalidParameter("folded norm bound overflows UInt64")
        }
        bound = next
    }
    return bound
}

private func multilinearBasisWeights(_ point: [GoldilocksExt2]) -> [GoldilocksExt2] {
    var weights = [GoldilocksExt2.one]
    for challenge in point {
        let oldCount = weights.count
        weights.append(contentsOf: repeatElement(.zero, count: oldCount))
        let lowWeight = GoldilocksExt2.one - challenge
        for index in 0..<oldCount {
            let previous = weights[index]
            weights[index] = previous * lowWeight
            weights[index + oldCount] = previous * challenge
        }
    }
    return weights
}

private struct QPolynomialInterpolator {
    private let basisCoefficients: [[GoldilocksExt2]]

    init(samplePoints: [GoldilocksExt2]) throws {
        guard !samplePoints.isEmpty else {
            throw SuperNeoError.invalidParameter("interpolation sample count mismatch")
        }
        var basisCoefficients: [[GoldilocksExt2]] = []
        basisCoefficients.reserveCapacity(samplePoints.count)
        for index in samplePoints.indices {
            var basis = [GoldilocksExt2.one]
            var denominator = GoldilocksExt2.one
            for other in samplePoints.indices where other != index {
                basis = multiplyQPolynomial(basis, byLinearTermWithRoot: samplePoints[other])
                denominator = denominator * (samplePoints[index] - samplePoints[other])
            }
            let inverseDenominator = try denominator.inverse()
            basisCoefficients.append(basis.map { $0 * inverseDenominator })
        }
        self.basisCoefficients = basisCoefficients
    }

    func interpolate(values: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
        guard values.count == basisCoefficients.count else {
            throw SuperNeoError.invalidParameter("interpolation sample count mismatch")
        }
        var coefficients = Array(repeating: GoldilocksExt2.zero, count: values.count)
        for index in basisCoefficients.indices {
            let value = values[index]
            let basis = basisCoefficients[index]
            for coeffIndex in basis.indices {
                coefficients[coeffIndex] = coefficients[coeffIndex] + basis[coeffIndex] * value
            }
        }
        while coefficients.count > 1, coefficients.last == .zero {
            coefficients.removeLast()
        }
        return coefficients
    }
}

private func multiplyQPolynomial(
    _ coeffs: [GoldilocksExt2],
    byLinearTermWithRoot root: GoldilocksExt2
) -> [GoldilocksExt2] {
    var output = Array(repeating: GoldilocksExt2.zero, count: coeffs.count + 1)
    for index in coeffs.indices {
        output[index] = output[index] - coeffs[index] * root
        output[index + 1] = output[index + 1] + coeffs[index]
    }
    return output
}

private func splitSignedBase(_ values: [GoldilocksField], base: Int, count: Int) throws -> [[GoldilocksField]] {
    guard base >= 2 else {
        throw SuperNeoError.invalidParameter("decomposition base must be at least two")
    }
    guard count > 0 else {
        throw SuperNeoError.invalidParameter("decomposition limb count must be positive")
    }
    var limbs = Array(repeating: Array(repeating: GoldilocksField.zero, count: values.count), count: count)
    let radix = UInt64(base)
    for (index, value) in values.enumerated() {
        var raw = signedMagnitude(value)
        let isNegative = value.rawValue > GoldilocksField.modulus / 2
        for limb in 0..<count {
            let digit = raw % radix
            if digit != 0 {
                let fieldDigit = GoldilocksField(digit)
                limbs[limb][index] = isNegative ? -fieldDigit : fieldDigit
            }
            raw /= radix
        }
        guard raw == 0 else {
            throw SuperNeoError.invalidParameter("value exceeds signed base-\(base) decomposition bound with \(count) limbs")
        }
    }
    return limbs
}

private func decompositionScalars(base: Int, count: Int) throws -> [GoldilocksField] {
    guard base >= 2, count > 0 else {
        throw SuperNeoError.invalidParameter("invalid decomposition scalar table")
    }
    let radix = GoldilocksField(UInt64(base))
    var scalars = Array(repeating: GoldilocksField.one, count: count)
    guard count > 1 else { return scalars }
    for index in 1..<count {
        scalars[index] = scalars[index - 1] * radix
    }
    return scalars
}

private func signedMagnitude(_ value: GoldilocksField) -> UInt64 {
    value.rawValue <= GoldilocksField.modulus / 2
        ? value.rawValue
        : GoldilocksField.modulus - value.rawValue
}

private func shouldParallelizeOpeningBatch(shape: CCSShape, count: Int) -> Bool {
    (count >= 8 && shape.m >= 256) || (count >= 4 && shape.m >= 1_024)
}

private func orderedParallelMap<Input, Output>(
    _ inputs: [Input],
    useParallel: Bool,
    _ transform: @escaping (Input) throws -> Output
) throws -> [Output] {
    guard useParallel, inputs.count > 1 else {
        return try inputs.map(transform)
    }

    let lock = NSLock()
    var results = Array<Result<Output, Error>?>(repeating: nil, count: inputs.count)

    DispatchQueue.concurrentPerform(iterations: inputs.count) { index in
        let result = Result {
            try transform(inputs[index])
        }
        lock.lock()
        results[index] = result
        lock.unlock()
    }

    var ordered: [Output] = []
    ordered.reserveCapacity(inputs.count)
    for result in results {
        guard let result else {
            throw SuperNeoError.invalidParameter("parallel opening batch did not produce an output")
        }
        ordered.append(try result.get())
    }
    return ordered
}
