import Foundation

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
    public let isValid: Bool
    public let reason: String?
    public let outputClaims: [CCSEvaluationClaim]

    public static func valid(outputClaims: [CCSEvaluationClaim]) -> FoldReductionResult {
        FoldReductionResult(
            isValid: true,
            reason: nil,
            outputClaims: outputClaims.map(\.publicDataOnly)
        )
    }

    public static func invalid(_ reason: String) -> FoldReductionResult {
        FoldReductionResult(isValid: false, reason: reason, outputClaims: [])
    }
}

public struct CEOpeningStatement: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
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

    public init(profileID: UInt16, shapeDigest: Digest256, instance: CEInstance) {
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.instance = instance
    }

    public init(profileID: UInt16, shape: CCSShape, instance: CEInstance) {
        self.init(profileID: profileID, shapeDigest: shape.shapeDigest, instance: instance)
    }

    public init(profileID: UInt16, shapeDigest: Digest256, claim: CCSEvaluationClaim) {
        self.init(profileID: profileID, shapeDigest: shapeDigest, instance: CEInstance(claim))
    }

    public init(profileID: UInt16, shape: CCSShape, claim: CCSEvaluationClaim) {
        self.init(profileID: profileID, shapeDigest: shape.shapeDigest, claim: claim)
    }
}

public struct TerminalCEStatement: Equatable, Sendable {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let openings: [CEOpeningStatement]

    public var outputClaims: [CCSEvaluationClaim] {
        openings.map(\.claim)
    }

    public init(profileID: UInt16, shapeDigest: Digest256, openings: [CEOpeningStatement]) throws {
        guard openings.allSatisfy({ $0.profileID == profileID }) else {
            throw SuperNeoError.invalidParameter("terminal CE statement profile mismatch")
        }
        guard openings.allSatisfy({ $0.shapeDigest == shapeDigest }) else {
            throw SuperNeoError.invalidParameter("terminal CE statement shape mismatch")
        }
        self.profileID = profileID
        self.shapeDigest = shapeDigest
        self.openings = openings
    }

    public init(profileID: UInt16, shape: CCSShape, openings: [CEOpeningStatement]) throws {
        try self.init(profileID: profileID, shapeDigest: shape.shapeDigest, openings: openings)
    }

    public init(profileID: UInt16, shapeDigest: Digest256, claims: [CCSEvaluationClaim]) throws {
        let openings = claims.map {
            CEOpeningStatement(profileID: profileID, shapeDigest: shapeDigest, claim: $0)
        }
        try self.init(profileID: profileID, shapeDigest: shapeDigest, openings: openings)
    }

    public init(profileID: UInt16, shape: CCSShape, claims: [CCSEvaluationClaim]) throws {
        try self.init(profileID: profileID, shapeDigest: shape.shapeDigest, claims: claims)
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
    public static let minimumRoundCount = 219
    public let rounds: [CEOpeningProofRound]

    public init(rounds: [CEOpeningProofRound]) throws {
        guard rounds.count >= Self.minimumRoundCount else {
            throw SuperNeoError.invalidParameter("CE opening proof has too few Stern rounds")
        }
        self.rounds = rounds
    }
}

public enum CEOpeningRelation {
    private static let proofRoundCount = CEOpeningProof.minimumRoundCount

    public static func proveLocalBatch(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        randomSeed: [UInt8]? = nil
    ) throws -> CEOpeningProof {
        guard statement.profileID == parameters.profileID else {
            throw SuperNeoError.invalidParameter("terminal CE statement profile mismatch")
        }
        guard statement.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.invalidParameter("terminal CE statement shape mismatch")
        }
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("CE opening proof key parameters mismatch")
        }
        guard statement.openings.count == witnesses.count, !witnesses.isEmpty else {
            throw SuperNeoError.invalidParameter("CE opening proof witness count mismatch")
        }

        let transformedMatrices = try shape.compiledForSuperNeo().transformedMatrices
        _ = try makePrivateTargets(
            statement: statement,
            witnesses: witnesses,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices,
            parameters: parameters
        )
        let privateWitnesses = try witnesses.map {
            try privateWitness(from: $0.witness, shape: shape)
        }
        let seed = randomSeed ?? makeSystemRandomSeed()
        var rng = DeterministicRNG(seed: seed + statement.superNeoBytes)
        var transcript = makeCEOpeningTranscript(statement: statement)
        transcript.absorb(ceEncodeCount(Self.proofRoundCount))
        var rounds: [CEOpeningProofRound] = []
        rounds.reserveCapacity(Self.proofRoundCount)

        for roundIndex in 0..<Self.proofRoundCount {
            var commitments: [CEOpeningProofCommitments] = []
            var openings: [(permutation: [Int], mask: [GoldilocksField], masked: [GoldilocksField])] = []
            commitments.reserveCapacity(statement.openings.count)
            openings.reserveCapacity(statement.openings.count)

            for openingIndex in statement.openings.indices {
                let witness = privateWitnesses[openingIndex]
                let permutation = samplePermutation(count: witness.count, rng: &rng)
                let mask = (0..<witness.count).map { _ in rng.nextField() }
                let masked = ceVectorAdd(mask, witness)
                let maskInstance = try makePrivateLinearInstance(
                    privateVector: mask,
                    opening: statement.openings[openingIndex],
                    shape: shape,
                    key: key,
                    transformedMatrices: transformedMatrices
                )
                let permutedMask = applyPermutation(mask, permutation)
                let permutedMasked = applyPermutation(masked, permutation)
                commitments.append(CEOpeningProofCommitments(
                    maskLinearDigest: ceOpeningDigest(
                        tag: 1,
                        roundIndex: roundIndex,
                        openingIndex: openingIndex,
                        payload: ceEncodePermutation(permutation) + maskInstance.superNeoBytes
                    ),
                    permutedMaskDigest: ceOpeningDigest(
                        tag: 2,
                        roundIndex: roundIndex,
                        openingIndex: openingIndex,
                        payload: ceEncodeVector(permutedMask)
                    ),
                    permutedMaskedWitnessDigest: ceOpeningDigest(
                        tag: 3,
                        roundIndex: roundIndex,
                        openingIndex: openingIndex,
                        payload: ceEncodeVector(permutedMasked)
                    )
                ))
                openings.append((permutation, mask, masked))
            }

            transcript.absorb(commitments.flatMap(\.superNeoBytes))
            let challenge = ceOpeningChallenge(transcript: &transcript)
            let response: CEOpeningProofResponse
            switch challenge {
            case 0:
                response = .mask(openings.map {
                    CEOpeningLinearResponse(permutation: $0.permutation, vector: $0.mask)
                })
            case 1:
                response = .maskedWitness(openings.map {
                    CEOpeningLinearResponse(permutation: $0.permutation, vector: $0.masked)
                })
            default:
                response = .permutedWitness(openings.enumerated().map { index, opening in
                    CEOpeningNormResponse(
                        permutedMask: applyPermutation(opening.mask, opening.permutation),
                        permutedWitness: applyPermutation(privateWitnesses[index], opening.permutation)
                    )
                })
            }
            transcript.absorb(response.superNeoBytes)
            rounds.append(CEOpeningProofRound(commitments: commitments, response: response))
        }

        return try CEOpeningProof(rounds: rounds)
    }

    public static func verify(
        proof: CEOpeningProof,
        statement: TerminalCEStatement,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard !statement.openings.isEmpty else { return false }
        guard proof.rounds.count >= CEOpeningProof.minimumRoundCount else { return false }
        guard statement.openings.allSatisfy({
            $0.instance.publicInput.allSatisfy { signedMagnitude($0) < UInt64(parameters.normBound) }
        }) else {
            return false
        }

        let transformedMatrices = try shape.compiledForSuperNeo().transformedMatrices
        var transcript = makeCEOpeningTranscript(statement: statement)
        transcript.absorb(ceEncodeCount(proof.rounds.count))

        for (roundIndex, round) in proof.rounds.enumerated() {
            guard round.commitments.count == statement.openings.count else { return false }
            transcript.absorb(round.commitments.flatMap(\.superNeoBytes))
            let challenge = ceOpeningChallenge(transcript: &transcript)
            guard try verifyRoundResponse(
                round.response,
                challenge: challenge,
                roundIndex: roundIndex,
                commitments: round.commitments,
                statement: statement,
                shape: shape,
                key: key,
                transformedMatrices: transformedMatrices,
                parameters: parameters
            ) else {
                return false
            }
            transcript.absorb(round.response.superNeoBytes)
        }
        return true
    }

    public static func verifyLocal(
        statement: CEOpeningStatement,
        witness: CEOpeningWitness,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard key.parameters == parameters else { return false }
        let transformedMatrices = try shape.compiledForSuperNeo().transformedMatrices
        let openedClaim = CCSEvaluationClaim(
            commitment: statement.instance.commitment,
            publicInput: statement.instance.publicInput,
            point: statement.instance.evalPoint,
            evaluations: statement.instance.matrixEvals,
            witness: witness.witness
        )
        return try SuperNeoProtocolOracle.verifyEvaluationClaimOpening(
            shape: shape,
            transformedMatrices: transformedMatrices,
            claim: openedClaim,
            key: key,
            parameters: parameters
        )
    }

    public static func verifyLocalBatch(
        statement: TerminalCEStatement,
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> Bool {
        guard statement.profileID == parameters.profileID else { return false }
        guard statement.shapeDigest == shape.shapeDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard statement.openings.count == witnesses.count else { return false }
        guard statement.openings.count == parameters.decompositionLength else { return false }

        for (opening, witness) in zip(statement.openings, witnesses) {
            guard try verifyLocal(
                statement: opening,
                witness: witness,
                shape: shape,
                key: key,
                parameters: parameters
            ) else {
                return false
            }
        }
        return true
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
        let shape = try CCSShape(
            matrices: structure.matrices,
            publicInputCount: publicInputCount,
            relationPolynomial: relationPolynomial
        )
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
    private let freshMatrixRows: [[[GoldilocksField]]]
    private let allWitnessRows: [[GoldilocksField]]
    private let priorTransformedRows: [[[CyclotomicRing54]]]
    private let priorEvalPoint: [GoldilocksExt2]?
    private let normRoots: [GoldilocksExt2]
    private let gammaPowers: [GoldilocksExt2]

    public init(
        shape: CCSShape,
        instances: [CCSInstance],
        witnesses: [CCSWitness],
        priorClaims: [CCSEvaluationClaim],
        alpha: [GoldilocksExt2],
        gamma: GoldilocksExt2,
        parameters: SuperNeoParameters = .goldilocks
    ) throws {
        guard instances.count == witnesses.count else {
            throw SuperNeoError.invalidParameter("Q oracle instances and witnesses must have the same count")
        }
        let numVars = try log2Exact(shape.m)
        guard alpha.count == numVars else {
            throw SuperNeoError.invalidParameter("Q oracle alpha length must match log2(m)")
        }
        guard shape.hasIdentityFirstMatrix else {
            throw SuperNeoError.invalidParameter("Q oracle requires M1 = I for direct norm checks")
        }
        guard parameters.normBound >= 2 else {
            throw SuperNeoError.invalidParameter("norm bound must be at least two")
        }
        guard shape.nField == shape.m else {
            throw SuperNeoError.invalidParameter("Q oracle requires the paper-normalized shape.nField == shape.m")
        }
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
        let matrices = try shape.matrices.map { try $0.toSparseFieldMatrix() }
        let transformedMatrices = try shape.compiledForSuperNeo().transformedMatrices
        let maxDegreePerRound = try piCCSMaxDegreePerRound(shape: shape, parameters: parameters)
        let freshMatrixRows = try freshWitnesses.map { witness in
            try matrices.map { matrix in try matrix.multiplied(by: witness) }
        }
        let allWitnessRows = freshWitnesses + priorWitnesses
        let priorTransformedRows = try priorWitnesses.map { witness in
            let packedWitness = try packedEvaluationWitness(witness, shape: shape)
            return try transformedMatrices.map { matrix in try matrix.multiplied(by: packedWitness) }
        }
        let maxPriorExponent = max(0, priorClaims.count * shape.numMatrices * CyclotomicRing54.degree - 1)
        let maxQExponent = max((2 * freshWitnesses.count) + priorClaims.count, maxPriorExponent)

        self.shape = shape
        self.freshCount = freshWitnesses.count
        self.priorCount = priorClaims.count
        self.priorClaims = priorClaims
        self.alpha = alpha
        self.gamma = gamma
        self.numVars = numVars
        self.maxDegreePerRound = maxDegreePerRound
        self.freshMatrixRows = freshMatrixRows
        self.allWitnessRows = allWitnessRows
        self.priorTransformedRows = priorTransformedRows
        self.priorEvalPoint = priorClaims.first?.point
        self.normRoots = parameters.normRoots.map { GoldilocksExt2($0) }
        self.gammaPowers = try makeGammaPowers(gamma, through: maxQExponent)
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
        let samplePoints = (0...maxDegreePerRound).map { GoldilocksExt2(GoldilocksField(UInt64($0))) }
        let values = try samplePoints.map { sample in
            try partialHypercubeSum(fixedPrefix: prefix + [sample])
        }
        return try interpolateQPolynomial(samplePoints: samplePoints, values: values)
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
        let suffixCount = 1 << remaining
        var total = GoldilocksExt2.zero
        for suffixBits in 0..<suffixCount {
            var point = fixedPrefix
            point.reserveCapacity(numVars)
            for bit in 0..<remaining {
                point.append(((suffixBits >> bit) & 1) == 0 ? .zero : .one)
            }
            total = total + (try evaluateQ(
                point: point,
                suffixBits: suffixBits,
                fixedCount: fixedPrefix.count,
                prefixWidth: prefixWidth,
                prefixWeights: prefixWeights
            ))
        }
        return total
    }

    private func evaluateQ(
        point: [GoldilocksExt2],
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        let f = try evaluateF(suffixBits: suffixBits, fixedCount: fixedCount, prefixWidth: prefixWidth, prefixWeights: prefixWeights)
        let norm = evaluateNorm(suffixBits: suffixBits, fixedCount: fixedCount, prefixWidth: prefixWidth, prefixWeights: prefixWeights)
        let eval = try evaluatePriorClaims(point: point, suffixBits: suffixBits, fixedCount: fixedCount, prefixWidth: prefixWidth, prefixWeights: prefixWeights)
        return try MultilinearEvaluation.eq(point, alpha)
            * (f + power(freshCount) * norm)
            + power((2 * freshCount) + priorCount) * eval
    }

    private func evaluateF(
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        for witnessIndex in 0..<freshCount {
            var matrixValues = Array(repeating: GoldilocksExt2.zero, count: shape.numMatrices)
            for matrixIndex in 0..<shape.numMatrices {
                matrixValues[matrixIndex] = weightedRowEvaluation(
                    rows: freshMatrixRows[witnessIndex][matrixIndex],
                    suffixBits: suffixBits,
                    fixedCount: fixedCount,
                    prefixWidth: prefixWidth,
                    prefixWeights: prefixWeights
                )
            }
            total = total + power(witnessIndex) * (try shape.relationPolynomial.evaluate(matrixValues))
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
            let product = normRoots.reduce(GoldilocksExt2.one) { $0 * (zAtPoint - $1) }
            total = total + power(witnessIndex) * product
        }
        return total
    }

    private func evaluatePriorClaims(
        point: [GoldilocksExt2],
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        guard let priorEvalPoint else { return .zero }
        let eq = try MultilinearEvaluation.eq(point, priorEvalPoint)
        var total = GoldilocksExt2.zero
        for priorIndex in 0..<priorCount {
            for matrixIndex in 0..<shape.numMatrices {
                for coeffIndex in 0..<CyclotomicRing54.degree {
                    let coefficientEvaluation = weightedRingCoefficientEvaluation(
                        rows: priorTransformedRows[priorIndex][matrixIndex],
                        coefficientIndex: coeffIndex,
                        suffixBits: suffixBits,
                        fixedCount: fixedCount,
                        prefixWidth: prefixWidth,
                        prefixWeights: prefixWeights
                    )
                    let exponent = priorExponent(priorIndex: priorIndex, matrixIndex: matrixIndex, coefficientIndex: coeffIndex)
                    total = total + power(exponent) * coefficientEvaluation
                }
            }
        }
        return eq * total
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
            total = total + prefixWeights[prefixBits] * GoldilocksExt2(rows[row])
        }
        return total
    }

    private func weightedRingCoefficientEvaluation(
        rows: [CyclotomicRing54],
        coefficientIndex: Int,
        suffixBits: Int,
        fixedCount: Int,
        prefixWidth: Int,
        prefixWeights: [GoldilocksExt2]
    ) -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        let suffixBase = suffixBits << fixedCount
        for prefixBits in 0..<prefixWidth {
            let row = suffixBase | prefixBits
            total = total + prefixWeights[prefixBits] * GoldilocksExt2(rows[row].coefficients[coefficientIndex])
        }
        return total
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
    private let normRoots: [GoldilocksExt2]
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
        guard shape.hasIdentityFirstMatrix else {
            throw SuperNeoError.invalidParameter("public Q verifier requires M1 = I for direct norm checks")
        }
        guard shape.nField == shape.m else {
            throw SuperNeoError.invalidParameter("public Q verifier requires shape.nField == shape.m")
        }
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
        self.alpha = alpha
        self.gamma = gamma
        self.numVars = numVars
        self.maxDegreePerRound = try piCCSMaxDegreePerRound(shape: shape, parameters: parameters)
        self.normRoots = parameters.normRoots.map { GoldilocksExt2($0) }
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
        for witnessIndex in 0..<freshCount {
            let matrixValues = proofClaims[witnessIndex].evaluations.map(\.constantTerm)
            total = total + power(witnessIndex) * (try shape.relationPolynomial.evaluate(matrixValues))
        }
        return total
    }

    private func evaluateNorm(proofClaims: [CCSEvaluationClaim]) throws -> GoldilocksExt2 {
        var total = GoldilocksExt2.zero
        for witnessIndex in proofClaims.indices {
            guard let zAtPoint = proofClaims[witnessIndex].evaluations.first?.constantTerm else {
                throw SuperNeoError.invalidParameter("proof PiCCS claim is missing the identity-matrix evaluation")
            }
            let product = normRoots.reduce(GoldilocksExt2.one) { $0 * (zAtPoint - $1) }
            total = total + power(witnessIndex) * product
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

    public init(parameters: SuperNeoParameters = .goldilocks, key: AjtaiCommitmentKey, context: MetalExecutionContext? = nil) {
        self.parameters = parameters
        self.key = key
        self.context = context
    }

    public func fold(_ input: SuperNeoFoldInput, transcriptSeed: [UInt8] = []) throws -> FoldProof {
        try foldWithOutput(input, transcriptSeed: transcriptSeed).proof
    }

    public func foldWithOutput(_ input: SuperNeoFoldInput, transcriptSeed: [UInt8] = []) throws -> FoldProverOutput {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("prover key parameters do not match prover parameters")
        }
        try validateFoldInput(input, parameters: parameters)

        var transcript = makeFoldTranscript(input: input, transcriptSeed: transcriptSeed)
        let sumCheck = try SuperNeoBenchmarkSignpost.measure("sumcheck") {
            try makeSumCheckProof(input: input, transcript: &transcript)
        }
        let piCCSClaims = try SuperNeoBenchmarkSignpost.measure("piCCSClaims") {
            try makePiCCSOutputClaims(input: input, point: sumCheck.finalPoint)
        }
        absorbEvaluationClaimBatch(piCCSClaims, into: &transcript)
        let rlc = try SuperNeoBenchmarkSignpost.measure("piRLC") {
            try randomLinearCombination(claims: piCCSClaims, transcript: &transcript)
        }
        let decomposition = try SuperNeoBenchmarkSignpost.measure("piDEC") {
            try decompose(rlc.foldedClaim, shape: input.shape)
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

    public func foldEnvelope(_ input: SuperNeoFoldInput, context: ProofEnvelopeContext) throws -> FoldProofEnvelope {
        let proof = try fold(input, transcriptSeed: context.transcriptBindingBytes)
        return try FoldProofEnvelope(context: context, proof: proof)
    }

    public func terminalFold(
        _ input: SuperNeoFoldInput,
        transcriptSeed: [UInt8] = [],
        ceRandomSeed: [UInt8]? = nil
    ) throws -> TerminalFoldProof {
        let fold = try foldWithOutput(input, transcriptSeed: transcriptSeed)
        let terminalStatement = try TerminalCEStatement(
            profileID: parameters.profileID,
            shape: input.shape,
            claims: fold.outputClaims
        )
        let witnesses = try fold.outputClaims.map { claim -> CEOpeningWitness in
            guard let witness = CEOpeningWitness(claim: claim) else {
                throw SuperNeoError.invalidParameter("terminal CE proof requires prover-side output witnesses")
            }
            return witness
        }
        let ceOpeningProof = try CEOpeningRelation.proveLocalBatch(
            statement: terminalStatement,
            witnesses: witnesses,
            shape: input.shape,
            key: key,
            parameters: parameters,
            randomSeed: ceRandomSeed
        )
        return TerminalFoldProof(
            foldProof: fold.proof,
            terminalStatement: terminalStatement,
            ceOpeningProof: ceOpeningProof
        )
    }

    public func terminalFoldEnvelope(
        _ input: SuperNeoFoldInput,
        context: ProofEnvelopeContext,
        ceRandomSeed: [UInt8]? = nil
    ) throws -> TerminalFoldProofEnvelope {
        guard context.kind == .terminalLocal else {
            throw SuperNeoError.invalidParameter("terminal fold envelope context must be terminalLocal")
        }
        let proof = try terminalFold(
            input,
            transcriptSeed: context.transcriptBindingBytes,
            ceRandomSeed: ceRandomSeed
        )
        return try TerminalFoldProofEnvelope(context: context, proof: proof)
    }

    private func makeSumCheckProof(
        input: SuperNeoFoldInput,
        transcript: inout SumCheckTranscript
    ) throws -> SumcheckProof {
        var oracle = try makeQOracle(input: input, transcript: &transcript, parameters: parameters)
        let claimedSum = try oracle.claimedSumFromPriorClaims()
        return try SumcheckProver.prove(oracle: &oracle, claimedSum: claimedSum, transcript: &transcript)
    }

    private func makePiCCSOutputClaims(input: SuperNeoFoldInput, point: [GoldilocksExt2]) throws -> [CCSEvaluationClaim] {
        try SuperNeoProtocolOracle.makePiCCSOutputClaims(
            input: input,
            key: key,
            context: context,
            point: point
        )
    }

    private func randomLinearCombination(
        claims: [CCSEvaluationClaim],
        transcript: inout SumCheckTranscript
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        let challenges = claims.map { _ in transcript.challengeRing() }
        return (try SuperNeoProtocolOracle.randomLinearCombination(claims: claims, challenges: challenges), challenges)
    }

    private func decompose(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        try SuperNeoProtocolOracle.decompose(
            claim,
            shape: shape,
            key: key,
            context: context,
            parameters: parameters
        )
    }
}

public final class SuperNeoVerifier: @unchecked Sendable {
    public let parameters: SuperNeoParameters
    public let key: AjtaiCommitmentKey
    public static let terminalRelationCheckRequiredReason = "fold reduction output claims require a terminal CE relation check"

    public init(parameters: SuperNeoParameters = .goldilocks, key: AjtaiCommitmentKey) {
        self.parameters = parameters
        self.key = key
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
        guard reduction.isValid else {
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
            guard reduction.isValid else {
                return .invalid(reduction.reason ?? "fold reduction verification failed")
            }
            guard proof.terminalStatement.profileID == parameters.profileID else {
                return .invalid("terminal CE statement profile mismatch")
            }
            guard proof.terminalStatement.shapeDigest == publicInput.shape.shapeDigest else {
                return .invalid("terminal CE statement shape mismatch")
            }
            guard proof.outputClaims.hasSamePublicData(as: reduction.outputClaims) else {
                return .invalid("terminal CE statement does not match fold reduction output")
            }
            guard try CEOpeningRelation.verify(
                proof: proof.ceOpeningProof,
                statement: proof.terminalStatement,
                shape: publicInput.shape,
                key: key,
                parameters: parameters
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
            guard reduction.isValid else {
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
                claims: outputClaims
            )
            guard try CEOpeningRelation.verifyLocalBatch(
                statement: terminalStatement,
                witnesses: witnesses,
                shape: publicInput.shape,
                key: key,
                parameters: parameters
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
            return .valid(outputClaims: proof.outputClaims)
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
        guard reduction.isValid else {
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
}

private enum SuperNeoProtocolOracle {
    static func makePiCCSOutputClaims(
        input: SuperNeoFoldInput,
        key: AjtaiCommitmentKey,
        context: MetalExecutionContext?,
        point: [GoldilocksExt2]
    ) throws -> [CCSEvaluationClaim] {
        let compiledShape = try input.shape.compiledForSuperNeo()
        let freshClaims = try zip(input.instances, input.witnesses).map { instance, witness in
            let z = witness.fullZ(for: instance)
            return try makeEvaluationClaim(
                shape: input.shape,
                transformedMatrices: compiledShape.transformedMatrices,
                commitment: instance.commitment,
                publicInput: instance.publicInput,
                witness: z,
                key: key,
                context: context,
                point: point
            )
        }
        let priorClaims = try input.priorClaims.map { claim in
            guard let witness = claim.witness else {
                throw SuperNeoError.invalidParameter("prover requires prior CE witnesses")
            }
            return try makeEvaluationClaim(
                shape: input.shape,
                transformedMatrices: compiledShape.transformedMatrices,
                commitment: claim.commitment,
                publicInput: claim.publicInput,
                witness: witness,
                key: key,
                context: context,
                point: point,
            )
        }
        return freshClaims + priorClaims
    }

    static func randomLinearCombination(
        claims: [CCSEvaluationClaim],
        challenges: [CyclotomicRing54]
    ) throws -> CCSEvaluationClaim {
        guard let first = claims.first else { throw SuperNeoError.invalidParameter("cannot fold zero claims") }
        guard challenges.count == claims.count else {
            throw SuperNeoError.invalidParameter("RLC challenge count mismatch")
        }
        guard first.commitment.elements.count > 0 else {
            throw SuperNeoError.invalidParameter("RLC commitment cannot be empty")
        }
        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: first.commitment.elements.count))
        let paddedPublicInputCount = SuperNeoEmbedding.paddedLength(forFieldElementCount: first.publicInput.count)
        var publicInput = Array(repeating: CyclotomicRing54.zero, count: paddedPublicInputCount / CyclotomicRing54.degree)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: first.evaluations.count)
        var witnessRings: [CyclotomicRing54]? = first.witness.map { _ in [] }

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
            commitment = commitment + claim.commitment.scaled(by: challenge)
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
                if witnessRings?.isEmpty == true {
                    witnessRings = Array(repeating: CyclotomicRing54.zero, count: packedWitness.count)
                }
                guard packedWitness.count == witnessRings?.count else {
                    throw SuperNeoError.invalidParameter("witness ring lengths must match")
                }
                var accumulated = witnessRings ?? Array(repeating: CyclotomicRing54.zero, count: packedWitness.count)
                for index in packedWitness.indices {
                    accumulated[index] = accumulated[index] + challenge * packedWitness[index]
                }
                witnessRings = accumulated
            }
        }

        return CCSEvaluationClaim(
            commitment: commitment,
            publicInput: Array(SuperNeoEmbedding.unpack(publicInput).prefix(first.publicInput.count)),
            point: first.point,
            evaluations: evaluations,
            witness: witnessRings.map { rings in
                SuperNeoEmbedding.unpack(rings)
            }
        )
    }

    private static func makeEvaluationClaim(
        shape: CCSShape,
        transformedMatrices: [RingMatrix],
        commitment: AjtaiCommitment,
        publicInput: [GoldilocksField],
        witness: [GoldilocksField],
        key: AjtaiCommitmentKey,
        context: MetalExecutionContext?,
        point: [GoldilocksExt2]
    ) throws -> CCSEvaluationClaim {
        guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
            throw SuperNeoError.invalidParameter("evaluation witness length must match the original or padded ring length")
        }
        guard publicInput.count <= witness.count, Array(witness.prefix(publicInput.count)) == publicInput else {
            throw SuperNeoError.invalidParameter("evaluation public input must be a prefix of the witness")
        }
        let packed = try packedEvaluationWitness(witness, shape: shape)
        let recomputed = try AjtaiCommitter.commit(key: key, fieldWitness: witness, context: context)
        guard recomputed == commitment else {
            throw SuperNeoError.verificationFailed("instance commitment does not match witness")
        }
        guard transformedMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("compiled transformed matrix count mismatch")
        }
        let metalBackend = context.map { SuperNeoMetalBackend(context: $0) }
        let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
            try evaluateTransformedMatrix(matrix, packed: packed, point: point, metalBackend: metalBackend)
        }
        return CCSEvaluationClaim(
            commitment: commitment,
            publicInput: publicInput,
            point: point,
            evaluations: evaluations,
            witness: witness
        )
    }

    static func verifyEvaluationClaimOpening(
        shape: CCSShape,
        transformedMatrices: [RingMatrix],
        claim: CCSEvaluationClaim,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters
    ) throws -> Bool {
        guard let witness = claim.witness else { return false }
        guard isValidEvaluationWitnessLength(witness.count, shape: shape) else { return false }
        guard claim.publicInput.count == shape.nPublicField else { return false }
        guard claim.publicInput.count <= witness.count,
              Array(witness.prefix(claim.publicInput.count)) == claim.publicInput else {
            return false
        }
        guard claim.point.count == (try log2Exact(shape.m)) else { return false }
        guard claim.evaluations.count == shape.numMatrices else { return false }
        guard claim.commitment.elements.count == parameters.kappa else { return false }
        guard witness.allSatisfy({ signedMagnitude($0) < UInt64(parameters.normBound) }) else {
            return false
        }

        let recomputed = try AjtaiCommitter.commitReference(key: key, fieldWitness: witness)
        guard recomputed == claim.commitment else { return false }
        guard transformedMatrices.count == shape.numMatrices else { return false }

        let packed = try packedEvaluationWitness(witness, shape: shape)
        let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
            let rows = try matrix.multiplied(by: packed)
            return try evaluateExtensionRingRows(rows, at: claim.point)
        }
        return evaluations == claim.evaluations
    }

    static func makeEvaluationInstance(
        shape: CCSShape,
        transformedMatrices: [RingMatrix],
        witness: [GoldilocksField],
        publicInput: [GoldilocksField],
        point: [GoldilocksExt2],
        key: AjtaiCommitmentKey
    ) throws -> CEInstance {
        guard isValidEvaluationWitnessLength(witness.count, shape: shape) else {
            throw SuperNeoError.invalidParameter("evaluation witness length must match the original or padded ring length")
        }
        guard publicInput.count <= witness.count, Array(witness.prefix(publicInput.count)) == publicInput else {
            throw SuperNeoError.invalidParameter("evaluation public input must be a prefix of the witness")
        }
        guard transformedMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("compiled transformed matrix count mismatch")
        }
        let packed = try packedEvaluationWitness(witness, shape: shape)
        let commitment = try AjtaiCommitter.commitReference(key: key, fieldWitness: witness)
        let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
            let rows = try matrix.multiplied(by: packed)
            return try evaluateExtensionRingRows(rows, at: point)
        }
        return CEInstance(
            commitment: commitment,
            publicInput: publicInput,
            evalPoint: point,
            matrixEvals: evaluations
        )
    }

    private static func evaluateTransformedMatrix(
        _ matrix: RingMatrix,
        packed: [CyclotomicRing54],
        point: [GoldilocksExt2],
        metalBackend: SuperNeoMetalBackend?
    ) throws -> CyclotomicExt2Ring54 {
        if let metalBackend {
            return CyclotomicExt2Ring54(try metalBackend.transformedEvaluation(
                matrix: matrix,
                vector: packed,
                point: point
            ))
        }
        let rows = try matrix.multiplied(by: packed)
        return try evaluateExtensionRingRows(rows, at: point)
    }

    private static func evaluateExtensionRingRows(_ rows: [CyclotomicRing54], at point: [GoldilocksExt2]) throws -> CyclotomicExt2Ring54 {
        var coefficients = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for coefficientIndex in 0..<CyclotomicRing54.degree {
            let coefficientVector = rows.map { $0.coefficients[coefficientIndex] }
            coefficients[coefficientIndex] = try MultilinearEvaluation.evaluate(coefficientVector, at: point)
        }
        return CyclotomicExt2Ring54(coefficients)
    }

    static func decompose(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        context: MetalExecutionContext?,
        parameters: SuperNeoParameters
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
        let transformedMatrices = try shape.compiledForSuperNeo().transformedMatrices
        let metalBackend = context.map { SuperNeoMetalBackend(context: $0) }
        let limbs = try splitSignedBase(witness, base: parameters.normBound, count: parameters.decompositionLength)
        let publicInputLimbs = try splitSignedBase(
            claim.publicInput,
            base: parameters.normBound,
            count: parameters.decompositionLength
        )
        let limbClaims = try limbs.enumerated().map { index, limb -> CCSEvaluationClaim in
            let commitment = try AjtaiCommitter.commit(key: key, fieldWitness: limb, context: context)
            let packed = try packedEvaluationWitness(limb, shape: shape)
            let evaluations = try transformedMatrices.map { matrix -> CyclotomicExt2Ring54 in
                try evaluateTransformedMatrix(matrix, packed: packed, point: claim.point, metalBackend: metalBackend)
            }
            return CCSEvaluationClaim(
                commitment: commitment,
                publicInput: publicInputLimbs[index],
                point: claim.point,
                evaluations: evaluations,
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

        for (index, part) in parts.enumerated() {
            guard part.point == folded.point else { return false }
            guard part.evaluations.count == folded.evaluations.count else { return false }
            guard part.publicInput.count == folded.publicInput.count else { return false }
            guard part.commitment.elements.count == folded.commitment.elements.count else { return false }
            guard part.publicInput.allSatisfy({ signedMagnitude($0) < UInt64(parameters.normBound) }) else { return false }

            let scalar = try decompositionScalar(base: parameters.normBound, exponent: index)
            commitment = commitment + part.commitment.scaled(by: scalar)

            let packedPartInput = try SuperNeoEmbedding.packPadded(part.publicInput)
            guard packedPartInput.count == publicInput.count else { return false }
            for inputIndex in publicInput.indices {
                publicInput[inputIndex] = publicInput[inputIndex] + scalar * packedPartInput[inputIndex]
            }
            for evalIndex in evaluations.indices {
                evaluations[evalIndex] = evaluations[evalIndex] + scalar * part.evaluations[evalIndex]
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

    public func benchmarkPiCCSClaims(
        input: SuperNeoFoldInput,
        point: [GoldilocksExt2]
    ) throws -> [CCSEvaluationClaim] {
        try validateFoldInput(input, parameters: parameters)
        return try makePiCCSOutputClaims(input: input, point: point)
    }

    public func benchmarkPiRLC(
        input: SuperNeoFoldInput,
        claims: [CCSEvaluationClaim],
        transcriptSeed: [UInt8] = []
    ) throws -> (foldedClaim: CCSEvaluationClaim, challenges: [CyclotomicRing54]) {
        try validateFoldInput(input, parameters: parameters)
        var transcript = makeFoldTranscript(input: input, transcriptSeed: transcriptSeed)
        _ = try makeSumCheckProof(input: input, transcript: &transcript)
        absorbEvaluationClaimBatch(claims, into: &transcript)
        return try randomLinearCombination(claims: claims, transcript: &transcript)
    }

    public func benchmarkPiDEC(
        _ claim: CCSEvaluationClaim,
        shape: CCSShape
    ) throws -> (proof: DecompositionProof, claims: [CCSEvaluationClaim]) {
        try decompose(claim, shape: shape)
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
    guard rows > 0, (rows & (rows - 1)) == 0 else {
        throw SuperNeoError.invalidParameter("CCS row count must be a power of two")
    }
    guard input.shape.nField == rows else {
        throw SuperNeoError.invalidParameter("fold input requires shape.nField == shape.m")
    }
    try validateRingModulePublicInput(shape: input.shape)
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
        guard claim.point.count == (try log2Exact(rows)), claim.evaluations.count == input.shape.numMatrices else {
            throw SuperNeoError.invalidParameter("prior CE claim shape mismatch")
        }
        if let witness = claim.witness {
            guard isValidEvaluationWitnessLength(witness.count, shape: input.shape) else {
                throw SuperNeoError.invalidParameter("prior CE witness length mismatch")
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
    guard rows > 0, (rows & (rows - 1)) == 0 else {
        throw SuperNeoError.invalidParameter("CCS row count must be a power of two")
    }
    guard input.shape.nField == rows else {
        throw SuperNeoError.invalidParameter("public fold input requires shape.nField == shape.m")
    }
    guard input.shape.hasIdentityFirstMatrix else {
        throw SuperNeoError.invalidParameter("public fold input requires M1 = I")
    }
    try validateRingModulePublicInput(shape: input.shape)
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

private func validateRingModulePublicInput(shape: CCSShape) throws {
    guard shape.nPublicField % CyclotomicRing54.degree == 0 else {
        throw SuperNeoError.invalidParameter("public input length must contain whole ring columns for R-module folding")
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

private func transcriptEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func makeQOracle(
    input: SuperNeoFoldInput,
    transcript: inout SumCheckTranscript,
    parameters: SuperNeoParameters
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
        parameters: parameters
    )
}

extension ProofEnvelopeContext {
    public var transcriptBindingBytes: [UInt8] {
        ProofEnvelopeHeader(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
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

private struct CEPrivateTarget {
    let commitment: AjtaiCommitment
    let matrixEvals: [CyclotomicExt2Ring54]
}

private func makePrivateTargets(
    statement: TerminalCEStatement,
    witnesses: [CEOpeningWitness],
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [RingMatrix],
    parameters: SuperNeoParameters
) throws -> [CEPrivateTarget] {
    try zip(statement.openings, witnesses).map { opening, witness in
        guard try CEOpeningRelation.verifyLocal(
            statement: opening,
            witness: witness,
            shape: shape,
            key: key,
            parameters: parameters
        ) else {
            throw SuperNeoError.invalidParameter("CE opening witness does not satisfy statement")
        }
        let privateCount = try privateWitness(from: witness.witness, shape: shape).count
        return try privateTargetForStatementOpening(
            opening,
            privateCount: privateCount,
            shape: shape,
            key: key,
            transformedMatrices: transformedMatrices
        )
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

private func makePrivateLinearInstance(
    privateVector: [GoldilocksField],
    opening: CEOpeningStatement,
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [RingMatrix]
) throws -> CEInstance {
    let publicZeros = Array(repeating: GoldilocksField.zero, count: opening.instance.publicInput.count)
    return try SuperNeoProtocolOracle.makeEvaluationInstance(
        shape: shape,
        transformedMatrices: transformedMatrices,
        witness: publicZeros + privateVector,
        publicInput: publicZeros,
        point: opening.instance.evalPoint,
        key: key
    )
}

private func subtractTarget(_ instance: CEInstance, target: CEPrivateTarget) -> CEInstance {
    CEInstance(
        commitment: instance.commitment - target.commitment,
        publicInput: instance.publicInput,
        evalPoint: instance.evalPoint,
        matrixEvals: ceVectorSubtract(instance.matrixEvals, target.matrixEvals)
    )
}

private func verifyRoundResponse(
    _ response: CEOpeningProofResponse,
    challenge: Int,
    roundIndex: Int,
    commitments: [CEOpeningProofCommitments],
    statement: TerminalCEStatement,
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [RingMatrix],
    parameters: SuperNeoParameters
) throws -> Bool {
    switch (challenge, response) {
    case (0, .mask(let openings)):
        guard openings.count == statement.openings.count else { return false }
        for index in openings.indices {
            let opening = openings[index]
            guard isValidPermutation(opening.permutation, count: opening.vector.count) else { return false }
            guard try isValidPrivateVectorLength(
                opening.vector.count,
                publicInputCount: statement.openings[index].instance.publicInput.count,
                shape: shape
            ) else {
                return false
            }
            let maskInstance = try makePrivateLinearInstance(
                privateVector: opening.vector,
                opening: statement.openings[index],
                shape: shape,
                key: key,
                transformedMatrices: transformedMatrices
            )
            guard commitments[index].maskLinearDigest == ceOpeningDigest(
                tag: 1,
                roundIndex: roundIndex,
                openingIndex: index,
                payload: ceEncodePermutation(opening.permutation) + maskInstance.superNeoBytes
            ) else {
                return false
            }
            let permutedMask = applyPermutation(opening.vector, opening.permutation)
            guard commitments[index].permutedMaskDigest == ceOpeningDigest(
                tag: 2,
                roundIndex: roundIndex,
                openingIndex: index,
                payload: ceEncodeVector(permutedMask)
            ) else {
                return false
            }
        }
        return true

    case (1, .maskedWitness(let openings)):
        guard openings.count == statement.openings.count else { return false }
        for index in openings.indices {
            let opening = openings[index]
            guard isValidPermutation(opening.permutation, count: opening.vector.count) else { return false }
            guard try isValidPrivateVectorLength(
                opening.vector.count,
                publicInputCount: statement.openings[index].instance.publicInput.count,
                shape: shape
            ) else {
                return false
            }
            let maskedInstance = try makePrivateLinearInstance(
                privateVector: opening.vector,
                opening: statement.openings[index],
                shape: shape,
                key: key,
                transformedMatrices: transformedMatrices
            )
            let target = try privateTargetForStatementOpening(
                statement.openings[index],
                privateCount: opening.vector.count,
                shape: shape,
                key: key,
                transformedMatrices: transformedMatrices
            )
            let maskInstance = subtractTarget(maskedInstance, target: target)
            guard commitments[index].maskLinearDigest == ceOpeningDigest(
                tag: 1,
                roundIndex: roundIndex,
                openingIndex: index,
                payload: ceEncodePermutation(opening.permutation) + maskInstance.superNeoBytes
            ) else {
                return false
            }
            let permutedMasked = applyPermutation(opening.vector, opening.permutation)
            guard commitments[index].permutedMaskedWitnessDigest == ceOpeningDigest(
                tag: 3,
                roundIndex: roundIndex,
                openingIndex: index,
                payload: ceEncodeVector(permutedMasked)
            ) else {
                return false
            }
        }
        return true

    case (2, .permutedWitness(let openings)):
        guard openings.count == statement.openings.count else { return false }
        for index in openings.indices {
            let opening = openings[index]
            guard opening.permutedMask.count == opening.permutedWitness.count else { return false }
            guard try isValidPrivateVectorLength(
                opening.permutedWitness.count,
                publicInputCount: statement.openings[index].instance.publicInput.count,
                shape: shape
            ) else {
                return false
            }
            guard opening.permutedWitness.allSatisfy({ signedMagnitude($0) < UInt64(parameters.normBound) }) else {
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

    default:
        return false
    }
}

private func privateTargetForStatementOpening(
    _ opening: CEOpeningStatement,
    privateCount: Int,
    shape: CCSShape,
    key: AjtaiCommitmentKey,
    transformedMatrices: [RingMatrix]
) throws -> CEPrivateTarget {
    guard opening.instance.commitment.elements.count == key.parameters.kappa else {
        throw SuperNeoError.invalidParameter("CE opening commitment has wrong length")
    }
    guard opening.instance.publicInput.count == shape.nPublicField else {
        throw SuperNeoError.invalidParameter("CE opening public input length mismatch")
    }
    guard opening.instance.evalPoint.count == (try log2Exact(shape.m)) else {
        throw SuperNeoError.invalidParameter("CE opening evaluation point length mismatch")
    }
    guard opening.instance.matrixEvals.count == shape.numMatrices else {
        throw SuperNeoError.invalidParameter("CE opening matrix evaluation arity mismatch")
    }
    let publicWitness = opening.instance.publicInput + Array(repeating: GoldilocksField.zero, count: privateCount)
    let publicInstance = try SuperNeoProtocolOracle.makeEvaluationInstance(
        shape: shape,
        transformedMatrices: transformedMatrices,
        witness: publicWitness,
        publicInput: opening.instance.publicInput,
        point: opening.instance.evalPoint,
        key: key
    )
    return CEPrivateTarget(
        commitment: opening.instance.commitment - publicInstance.commitment,
        matrixEvals: ceVectorSubtract(opening.instance.matrixEvals, publicInstance.matrixEvals)
    )
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

private func ceVectorSubtract(_ lhs: [CyclotomicExt2Ring54], _ rhs: [CyclotomicExt2Ring54]) -> [CyclotomicExt2Ring54] {
    zip(lhs, rhs).map(-)
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

private func makeSystemRandomSeed() -> [UInt8] {
    var generator = SystemRandomNumberGenerator()
    return (0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
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
        let previous = weights
        weights = Array(repeating: .zero, count: previous.count * 2)
        for index in previous.indices {
            weights[index] = previous[index] * (.one - challenge)
            weights[index + previous.count] = previous[index] * challenge
        }
    }
    return weights
}

private func interpolateQPolynomial(
    samplePoints: [GoldilocksExt2],
    values: [GoldilocksExt2]
) throws -> [GoldilocksExt2] {
    guard samplePoints.count == values.count, !samplePoints.isEmpty else {
        throw SuperNeoError.invalidParameter("interpolation sample count mismatch")
    }
    var coefficients = Array(repeating: GoldilocksExt2.zero, count: values.count)
    for index in samplePoints.indices {
        var basis = [GoldilocksExt2.one]
        var denominator = GoldilocksExt2.one
        for other in samplePoints.indices where other != index {
            basis = multiplyQPolynomial(basis, byLinearTermWithRoot: samplePoints[other])
            denominator = denominator * (samplePoints[index] - samplePoints[other])
        }
        let scale = values[index] * (try denominator.inverse())
        for coeffIndex in basis.indices {
            coefficients[coeffIndex] = coefficients[coeffIndex] + basis[coeffIndex] * scale
        }
    }
    while coefficients.count > 1, coefficients.last == .zero {
        coefficients.removeLast()
    }
    return coefficients
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

private func decompositionScalar(base: Int, exponent: Int) throws -> CyclotomicRing54 {
    guard base >= 2, exponent >= 0 else {
        throw SuperNeoError.invalidParameter("invalid decomposition scalar")
    }
    let radix = GoldilocksField(UInt64(base))
    var value = GoldilocksField.one
    for _ in 0..<exponent {
        value = value * radix
    }
    return CyclotomicRing54([value])
}

private func signedMagnitude(_ value: GoldilocksField) -> UInt64 {
    value.rawValue <= GoldilocksField.modulus / 2
        ? value.rawValue
        : GoldilocksField.modulus - value.rawValue
}
