import Foundation

public struct NumiSealWitnessedObligation: Equatable, Sendable {
    public let obligation: NumiSealObligation
    public let claim: CCSEvaluationClaim

    public init(
        obligation: NumiSealObligation,
        claim: CCSEvaluationClaim
    ) throws {
        let obligationInstance = CEInstance(
            commitment: obligation.commitment,
            publicInputEncoding: obligation.publicInputEncoding,
            evalPoint: obligation.evalPoint,
            matrixEvals: obligation.matrixEvaluations
        )
        guard CEInstance(claim) == obligationInstance else {
            throw SuperNeoError.invalidParameter("NumiSeal witnessed obligation claim does not match obligation")
        }
        guard claim.witness != nil else {
            throw SuperNeoError.invalidParameter("NumiSeal witnessed obligation is missing witness")
        }

        self.obligation = obligation
        self.claim = claim
    }
}

public struct NumiSealVerificationResult: Equatable, Sendable {
    public let isValid: Bool
    public let reason: String?
    public let envelope: NumiSealProofEnvelope?

    public static func valid(envelope: NumiSealProofEnvelope) -> Self {
        Self(isValid: true, reason: nil, envelope: envelope)
    }

    public static func invalid(_ reason: String) -> Self {
        Self(isValid: false, reason: reason, envelope: nil)
    }
}

public struct NumiSealAggregateDigitTensorInput: Equatable, Sendable {
    public let message: [CyclotomicRing54]
    public let activeDigitCount: Int?

    public init(
        message: [CyclotomicRing54],
        activeDigitCount: Int? = nil
    ) throws {
        guard !message.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate digit tensor input message cannot be empty")
        }
        self.message = message
        self.activeDigitCount = activeDigitCount
    }
}

public struct NumiSealProvingPlan: Equatable, Sendable {
    public let publicStatement: NumiSealPublicStatement
    public let aggregates: [NumiSealLaneAggregate]

    public var aggregateCount: Int { aggregates.count }
    public var aggregateDigests: [Digest256] { aggregates.map(\.aggregateDigest) }

    public init(
        publicStatement: NumiSealPublicStatement,
        aggregates: [NumiSealLaneAggregate]
    ) throws {
        guard !aggregates.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal proving plan requires aggregates")
        }
        self.publicStatement = publicStatement
        self.aggregates = aggregates
    }
}

public final class NumiSealProver: @unchecked Sendable {
    public let shape: CCSShape
    public let key: AjtaiCommitmentKey
    public let parameters: SuperNeoParameters
    public let metalWorkspace: SuperNeoMetalWorkspace?
    public let executionPolicy: SuperNeoExecutionPolicy

    public init(
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) {
        self.shape = shape
        self.key = key
        self.parameters = parameters
        self.metalWorkspace = metalWorkspace
        self.executionPolicy = executionPolicy
    }

    public func prove(
        witnessedObligations: [NumiSealWitnessedObligation],
        policy: NumiSealAcceptancePolicy,
        digitTensorMessage: [CyclotomicRing54],
        activeDigitCount: Int? = nil,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        carryClaimsByAggregate: [NumiSealAggregateKey: NumiSealCarryClaim] = [:]
    ) throws -> NumiSealProofEnvelope {
        guard !digitTensorMessage.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal prover digit tensor message cannot be empty")
        }
        return try prove(
            witnessedObligations: witnessedObligations,
            policy: policy,
            digitTensorInputs: [
                NumiSealAggregateDigitTensorInput(
                    message: digitTensorMessage,
                    activeDigitCount: activeDigitCount
                )
            ],
            aggregationLimits: aggregationLimits,
            carryClaimsByAggregate: carryClaimsByAggregate
        )
    }

    public func prove(
        witnessedObligations: [NumiSealWitnessedObligation],
        policy: NumiSealAcceptancePolicy,
        digitTensorInputs: [NumiSealAggregateDigitTensorInput],
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits(),
        carryClaimsByAggregate: [NumiSealAggregateKey: NumiSealCarryClaim] = [:]
    ) throws -> NumiSealProofEnvelope {
        let plan = try provingPlan(
            obligations: witnessedObligations.map(\.obligation),
            policy: policy,
            aggregationLimits: aggregationLimits
        )
        return try prove(
            witnessedObligations: witnessedObligations,
            policy: policy,
            plan: plan,
            digitTensorInputs: digitTensorInputs,
            carryClaimsByAggregate: carryClaimsByAggregate
        )
    }

    @_spi(Benchmarking) public func proveDeterministic(
        witnessedObligations: [NumiSealWitnessedObligation],
        policy: NumiSealAcceptancePolicy,
        digitTensorInputs: [NumiSealAggregateDigitTensorInput],
        ceRandomSeeds: [[UInt8]],
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits()
    ) throws -> NumiSealProofEnvelope {
        let plan = try provingPlan(
            obligations: witnessedObligations.map(\.obligation),
            policy: policy,
            aggregationLimits: aggregationLimits
        )
        return try prove(
            witnessedObligations: witnessedObligations,
            policy: policy,
            plan: plan,
            digitTensorInputs: digitTensorInputs,
            ceRandomSeeds: ceRandomSeeds
        )
    }

    public func provingPlan(
        obligations: [NumiSealObligation],
        policy: NumiSealAcceptancePolicy,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits()
    ) throws -> NumiSealProvingPlan {
        try validateContext(policy: policy)
        let canonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: obligations,
            policy: policy
        )
        let publicStatement = try NumiSealPublicStatement(
            canonicalization: canonicalization,
            policy: policy
        )
        let aggregates = try NumiSealLaneAggregation.aggregate(
            canonicalization: canonicalization,
            policy: policy,
            parameters: parameters,
            limits: aggregationLimits,
            executionPolicy: executionPolicy
        )
        return try NumiSealProvingPlan(
            publicStatement: publicStatement,
            aggregates: aggregates
        )
    }

    private func prove(
        witnessedObligations: [NumiSealWitnessedObligation],
        policy: NumiSealAcceptancePolicy,
        plan: NumiSealProvingPlan,
        digitTensorInputs: [NumiSealAggregateDigitTensorInput],
        ceRandomSeeds: [[UInt8]]? = nil,
        carryClaimsByAggregate: [NumiSealAggregateKey: NumiSealCarryClaim] = [:]
    ) throws -> NumiSealProofEnvelope {
        guard digitTensorInputs.count == plan.aggregateCount else {
            throw SuperNeoError.invalidParameter("NumiSeal prover digit tensor input count must match aggregate count")
        }
        if let ceRandomSeeds {
            guard ceRandomSeeds.count == plan.aggregateCount else {
                throw SuperNeoError.invalidParameter("NumiSeal prover CE random seed count must match aggregate count")
            }
        }
        let aggregateKeys = try Set(plan.aggregates.map {
            try NumiSealAggregateKey(laneKey: $0.laneKey, aggregateIndex: $0.aggregateIndex)
        })
        guard Set(carryClaimsByAggregate.keys).isSubset(of: aggregateKeys) else {
            throw SuperNeoError.invalidParameter("NumiSeal carry claim targets an aggregate outside the proving plan")
        }

        let claimsByDigest = try Self.claimsByDigest(from: witnessedObligations)
        let laneProofs = try zip(plan.aggregates, digitTensorInputs).enumerated().map { offset, pair in
            let (aggregate, tensorInput) = pair
            let aggregateClaims = try Self.claims(for: aggregate, claimsByDigest: claimsByDigest)
            let witnessedAggregate = try NumiSealAggregateEvaluationOracle.witnessedAggregateClaim(
                aggregate: aggregate,
                claims: aggregateClaims,
                shape: shape,
                executionPolicy: executionPolicy
            )
            let digitTensor = try NumiSealDigitTensor(
                laneKey: aggregate.laneKey,
                aggregateIndex: aggregate.aggregateIndex,
                message: tensorInput.message,
                activeDigitCount: tensorInput.activeDigitCount
            )
            let decompositionKey = try NumiSealDecompositionKeyDerivation(
                verifierKeyDigest: policy.verifierKeyDigest,
                laneKey: aggregate.laneKey,
                aggregateIndex: aggregate.aggregateIndex,
                requiredColumnCount: digitTensor.columnCount
            )
            let decomposition = try NumiSealDecompositionCommitment(
                keyDerivation: decompositionKey,
                digitTensor: digitTensor,
                parameters: parameters,
                executionPolicy: executionPolicy
            )
            let scalarization = try NumiSealLinearResidual(
                publicStatement: plan.publicStatement,
                aggregate: aggregate,
                decomposition: decomposition
            )
            let sumcheckProof = try NumiSealSumcheckOracle.prove(
                linearResidual: scalarization,
                digitTensor: digitTensor
            )
            let residualCE: NumiSealResidualCEBuildResult
            if let randomSeed = ceRandomSeeds?[offset] {
                residualCE = try NumiSealResidualCEBuilder.proveImmediateOpeningDeterministic(
                    publicStatement: plan.publicStatement,
                    aggregate: aggregate,
                    decomposition: decomposition,
                    digitTensor: digitTensor,
                    linearResidual: scalarization,
                    sumcheckProof: sumcheckProof,
                    aggregateClaim: witnessedAggregate,
                    shape: shape,
                    key: key,
                    parameters: parameters,
                    randomSeed: randomSeed,
                    metalWorkspace: metalWorkspace,
                    executionPolicy: executionPolicy
                )
            } else {
                residualCE = try NumiSealResidualCEBuilder.proveImmediateOpening(
                    publicStatement: plan.publicStatement,
                    aggregate: aggregate,
                    decomposition: decomposition,
                    digitTensor: digitTensor,
                    linearResidual: scalarization,
                    sumcheckProof: sumcheckProof,
                    aggregateClaim: witnessedAggregate,
                    shape: shape,
                    key: key,
                    parameters: parameters,
                    metalWorkspace: metalWorkspace,
                    executionPolicy: executionPolicy
                )
            }
            let aggregateKey = try NumiSealAggregateKey(
                laneKey: aggregate.laneKey,
                aggregateIndex: aggregate.aggregateIndex
            )
            return try NumiSealLaneProof(
                laneKey: aggregate.laneKey,
                aggregateIndex: aggregate.aggregateIndex,
                aggregateDigest: aggregate.aggregateDigest,
                decompositionKeyDigest: decomposition.decompositionKeyDigest,
                decompositionCommitment: decomposition.commitment,
                scalarizationDigest: scalarization.residualDigest,
                sumcheckProof: sumcheckProof,
                residualOpening: residualCE.residualOpening,
                optionalCarryClaim: carryClaimsByAggregate[aggregateKey]
            )
        }
        let proof = try NumiSealProof(
            publicStatement: plan.publicStatement,
            laneProofs: laneProofs
        )
        return try NumiSealProofEnvelope(
            context: ProofEnvelopeContext(
                profileID: policy.profileID,
                kind: .numiSealTerminal,
                shapeDigest: policy.shapeDigest,
                statementDigest: policy.statementDigest,
                verifierKeyDigest: policy.verifierKeyDigest,
                transcriptDomain: policy.transcriptDomain
            ),
            proof: proof
        )
    }

    private func validateContext(policy: NumiSealAcceptancePolicy) throws {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("NumiSeal prover key parameters mismatch")
        }
        guard key.matrix.columns == shape.nRing else {
            throw SuperNeoError.invalidParameter("NumiSeal prover key shape mismatch")
        }
        guard policy.profileID == parameters.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal prover policy profile mismatch")
        }
        guard policy.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal prover policy shape mismatch")
        }
        guard policy.verifierKeyDigest == key.verifierKeyDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal prover policy verifier key mismatch")
        }
    }

    private static func claimsByDigest(
        from witnessedObligations: [NumiSealWitnessedObligation]
    ) throws -> [Digest256: CCSEvaluationClaim] {
        var claimsByDigest: [Digest256: CCSEvaluationClaim] = [:]
        for witnessed in witnessedObligations {
            let digest = NumiSealCanonicalization.obligationDigest(witnessed.obligation)
            guard claimsByDigest[digest] == nil else {
                throw SuperNeoError.invalidParameter("NumiSeal witnessed obligations must be unique")
            }
            claimsByDigest[digest] = witnessed.claim
        }
        return claimsByDigest
    }

    private static func claims(
        for aggregate: NumiSealLaneAggregate,
        claimsByDigest: [Digest256: CCSEvaluationClaim]
    ) throws -> [CCSEvaluationClaim] {
        try aggregate.obligationDigests.map { digest in
            guard let claim = claimsByDigest[digest] else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate obligation is missing witness")
            }
            return claim
        }
    }
}

public final class NumiSealVerifier: @unchecked Sendable {
    public let shape: CCSShape
    public let key: AjtaiCommitmentKey
    public let parameters: SuperNeoParameters
    public let metalWorkspace: SuperNeoMetalWorkspace?
    public let executionPolicy: SuperNeoExecutionPolicy

    public init(
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        metalWorkspace: SuperNeoMetalWorkspace? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) {
        self.shape = shape
        self.key = key
        self.parameters = parameters
        self.metalWorkspace = metalWorkspace
        self.executionPolicy = executionPolicy
    }

    public func verify(
        proofBytes: [UInt8],
        obligations: [NumiSealObligation],
        policy: NumiSealTerminalProofAcceptancePolicy,
        aggregationLimits: NumiSealAggregationLimits = .defaultLimits()
    ) -> NumiSealVerificationResult {
        do {
            let envelope = try policy.preflight(proofBytes: proofBytes, parameters: parameters)
            try verifyPublicAssembly(
                proof: envelope.proof,
                obligations: obligations,
                policy: policy,
                aggregationLimits: aggregationLimits
            )
            try policy.verify(
                proof: envelope.proof,
                shape: shape,
                key: key,
                parameters: parameters,
                metalWorkspace: metalWorkspace,
                executionPolicy: executionPolicy
            )
            return .valid(envelope: envelope)
        } catch {
            return .invalid("\(error)")
        }
    }

    private func verifyPublicAssembly(
        proof: NumiSealProof,
        obligations: [NumiSealObligation],
        policy: NumiSealTerminalProofAcceptancePolicy,
        aggregationLimits: NumiSealAggregationLimits
    ) throws {
        let acceptancePolicy = NumiSealAcceptancePolicy(
            profileID: policy.profileID,
            shapeDigest: policy.shapeDigest,
            statementDigest: policy.statementDigest,
            verifierKeyDigest: policy.verifierKeyDigest,
            transcriptDomain: policy.transcriptDomain,
            acceptedLaneIDs: policy.acceptedLaneIDs,
            maximumProofByteCount: policy.maximumProofByteCount
        )
        let canonicalization = try NumiSealCanonicalization.canonicalize(
            obligations: obligations,
            policy: acceptancePolicy
        )
        let expectedPublicStatement = try NumiSealPublicStatement(
            canonicalization: canonicalization,
            policy: acceptancePolicy
        )
        guard proof.publicStatement == expectedPublicStatement else {
            throw SuperNeoError.verificationFailed("NumiSeal verifier public statement mismatch")
        }
        let expectedAggregates = try NumiSealLaneAggregation.aggregate(
            canonicalization: canonicalization,
            policy: acceptancePolicy,
            parameters: parameters,
            limits: aggregationLimits,
            executionPolicy: executionPolicy
        )
        guard proof.laneProofs.count == expectedAggregates.count else {
            throw SuperNeoError.verificationFailed("NumiSeal verifier aggregate count mismatch")
        }

        for (laneProof, aggregate) in zip(proof.laneProofs, expectedAggregates) {
            guard laneProof.laneKey == aggregate.laneKey else {
                throw SuperNeoError.verificationFailed("NumiSeal verifier lane key mismatch")
            }
            guard laneProof.aggregateIndex == aggregate.aggregateIndex else {
                throw SuperNeoError.verificationFailed("NumiSeal verifier aggregate index mismatch")
            }
            guard laneProof.aggregateDigest == aggregate.aggregateDigest else {
                throw SuperNeoError.verificationFailed("NumiSeal verifier aggregate digest mismatch")
            }
            guard laneProof.residualOpening.residualStatement.publicStatementDigest == proof.publicStatement.digest else {
                throw SuperNeoError.verificationFailed("NumiSeal verifier residual public statement mismatch")
            }
            guard laneProof.residualOpening.residualStatement.aggregateDigest == aggregate.aggregateDigest else {
                throw SuperNeoError.verificationFailed("NumiSeal verifier residual aggregate mismatch")
            }
        }
    }
}
