import Foundation

public struct NumiSealAggregationLimits: Equatable, Sendable {
    public let maximumObligationsPerAggregate: Int

    public init(maximumObligationsPerAggregate: Int) throws {
        guard maximumObligationsPerAggregate > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate limit must be positive")
        }
        self.maximumObligationsPerAggregate = maximumObligationsPerAggregate
    }

    public static func defaultLimits(parameters: SuperNeoParameters = .goldilocks) -> Self {
        Self(uncheckedMaximumObligationsPerAggregate: parameters.maxFreshBatchCount + parameters.maxPriorClaimCount)
    }

    private init(uncheckedMaximumObligationsPerAggregate: Int) {
        precondition(uncheckedMaximumObligationsPerAggregate > 0)
        self.maximumObligationsPerAggregate = uncheckedMaximumObligationsPerAggregate
    }
}

public struct NumiSealLaneAggregate: Equatable, Sendable, SuperNeoByteEncodable {
    public let laneKey: NumiSealLaneKey
    public let aggregateIndex: Int
    public let obligationDigests: [Digest256]
    public let challenges: [CyclotomicRing54]
    public let aggregateCommitment: AjtaiCommitment
    public let aggregatePublicInputEncoding: PublicInputEncoding
    public let evalPoint: [GoldilocksExt2]
    public let aggregateMatrixEvaluations: [CyclotomicExt2Ring54]
    public let aggregateDigest: Digest256

    public var aggregateInstance: CEInstance {
        CEInstance(
            commitment: aggregateCommitment,
            publicInputEncoding: aggregatePublicInputEncoding,
            evalPoint: evalPoint,
            matrixEvals: aggregateMatrixEvaluations
        )
    }

    public init(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        obligationDigests: [Digest256],
        challenges: [CyclotomicRing54],
        aggregateCommitment: AjtaiCommitment,
        aggregatePublicInputEncoding: PublicInputEncoding,
        evalPoint: [GoldilocksExt2],
        aggregateMatrixEvaluations: [CyclotomicExt2Ring54]
    ) throws {
        try Self.validate(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            obligationDigests: obligationDigests,
            challenges: challenges,
            aggregateCommitment: aggregateCommitment,
            evalPoint: evalPoint,
            aggregateMatrixEvaluations: aggregateMatrixEvaluations
        )
        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.obligationDigests = obligationDigests
        self.challenges = challenges
        self.aggregateCommitment = aggregateCommitment
        self.aggregatePublicInputEncoding = aggregatePublicInputEncoding
        self.evalPoint = evalPoint
        self.aggregateMatrixEvaluations = aggregateMatrixEvaluations
        self.aggregateDigest = Self.digestBody(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            obligationDigests: obligationDigests,
            challenges: challenges,
            aggregateCommitment: aggregateCommitment,
            aggregatePublicInputEncoding: aggregatePublicInputEncoding,
            evalPoint: evalPoint,
            aggregateMatrixEvaluations: aggregateMatrixEvaluations
        )
    }

    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        let laneKey = try reader.readNumiSealLaneKey()
        let aggregateIndex = try reader.readCount(
            maximum: NumiSealWireLimits.maximumAggregateCount,
            name: "NumiSeal aggregate index"
        )
        let obligationCount = try reader.readCount(
            maximum: NumiSealWireLimits.maximumObligationCount,
            name: "NumiSeal aggregate obligation",
            elementByteWidth: Digest256.byteCount
        )
        guard obligationCount > 0 else {
            throw SuperNeoError.invalidEncoding("NumiSeal aggregate cannot be empty")
        }
        let obligationDigests = try (0..<obligationCount).map { _ in
            try Digest256(reader.readData(count: Digest256.byteCount))
        }
        let challengeCount = try reader.readCount(
            maximum: obligationCount,
            name: "NumiSeal aggregate challenge",
            elementByteWidth: CyclotomicRing54.degree * 8
        )
        guard challengeCount == obligationCount else {
            throw SuperNeoError.invalidEncoding("NumiSeal aggregate challenge count mismatch")
        }
        let challenges = try (0..<challengeCount).map { _ in try reader.readNumiSealRing() }
        let aggregateCommitment = try reader.readNumiSealCommitment(parameters: parameters)
        let aggregatePublicInputEncoding = try reader.readNumiSealPublicInputEncoding()
        let evalPoint = try reader.readNumiSealEvaluationPoint()
        let aggregateMatrixEvaluations = try reader.readNumiSealMatrixEvaluations()
        let aggregateDigest = try Digest256(reader.readData(count: Digest256.byteCount))
        try reader.finish()

        let expectedDigest = Self.digestBody(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            obligationDigests: obligationDigests,
            challenges: challenges,
            aggregateCommitment: aggregateCommitment,
            aggregatePublicInputEncoding: aggregatePublicInputEncoding,
            evalPoint: evalPoint,
            aggregateMatrixEvaluations: aggregateMatrixEvaluations
        )
        guard aggregateDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("NumiSeal aggregate digest mismatch")
        }
        try Self.validate(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            obligationDigests: obligationDigests,
            challenges: challenges,
            aggregateCommitment: aggregateCommitment,
            evalPoint: evalPoint,
            aggregateMatrixEvaluations: aggregateMatrixEvaluations
        )

        self.laneKey = laneKey
        self.aggregateIndex = aggregateIndex
        self.obligationDigests = obligationDigests
        self.challenges = challenges
        self.aggregateCommitment = aggregateCommitment
        self.aggregatePublicInputEncoding = aggregatePublicInputEncoding
        self.evalPoint = evalPoint
        self.aggregateMatrixEvaluations = aggregateMatrixEvaluations
        self.aggregateDigest = aggregateDigest
    }

    public var superNeoBytes: [UInt8] {
        Self.bodyBytes(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            obligationDigests: obligationDigests,
            challenges: challenges,
            aggregateCommitment: aggregateCommitment,
            aggregatePublicInputEncoding: aggregatePublicInputEncoding,
            evalPoint: evalPoint,
            aggregateMatrixEvaluations: aggregateMatrixEvaluations
        ) + aggregateDigest.superNeoBytes
    }

    private static func validate(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        obligationDigests: [Digest256],
        challenges: [CyclotomicRing54],
        aggregateCommitment: AjtaiCommitment,
        evalPoint: [GoldilocksExt2],
        aggregateMatrixEvaluations: [CyclotomicExt2Ring54]
    ) throws {
        guard aggregateIndex >= 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate index must be non-negative")
        }
        guard !obligationDigests.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate cannot be empty")
        }
        guard obligationDigests.count == challenges.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate challenge count mismatch")
        }
        guard aggregateCommitment.elements.count == SuperNeoParameters.goldilocks.kappa else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate commitment has wrong length")
        }
        guard laneKey.evalPointDigest == NumiSealCanonicalization.evalPointDigest(evalPoint) else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate evaluation point digest mismatch")
        }
        guard !aggregateMatrixEvaluations.isEmpty else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate requires matrix evaluations")
        }
    }

    private static func digestBody(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        obligationDigests: [Digest256],
        challenges: [CyclotomicRing54],
        aggregateCommitment: AjtaiCommitment,
        aggregatePublicInputEncoding: PublicInputEncoding,
        evalPoint: [GoldilocksExt2],
        aggregateMatrixEvaluations: [CyclotomicExt2Ring54]
    ) -> Digest256 {
        NumiSealEncoding.digest(
            label: "numiseal.lane-aggregate.v1",
            bytes: bodyBytes(
                laneKey: laneKey,
                aggregateIndex: aggregateIndex,
                obligationDigests: obligationDigests,
                challenges: challenges,
                aggregateCommitment: aggregateCommitment,
                aggregatePublicInputEncoding: aggregatePublicInputEncoding,
                evalPoint: evalPoint,
                aggregateMatrixEvaluations: aggregateMatrixEvaluations
            )
        )
    }

    private static func bodyBytes(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        obligationDigests: [Digest256],
        challenges: [CyclotomicRing54],
        aggregateCommitment: AjtaiCommitment,
        aggregatePublicInputEncoding: PublicInputEncoding,
        evalPoint: [GoldilocksExt2],
        aggregateMatrixEvaluations: [CyclotomicExt2Ring54]
    ) -> [UInt8] {
        laneKey.superNeoBytes
            + numiSealEncodeCount(aggregateIndex)
            + numiSealEncodeCount(obligationDigests.count)
            + obligationDigests.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(challenges.count)
            + challenges.flatMap(\.superNeoBytes)
            + aggregateCommitment.superNeoBytes
            + aggregatePublicInputEncoding.superNeoBytes
            + numiSealEncodeCount(evalPoint.count)
            + evalPoint.flatMap(\.superNeoBytes)
            + numiSealEncodeCount(aggregateMatrixEvaluations.count)
            + aggregateMatrixEvaluations.flatMap(\.superNeoBytes)
    }
}

public enum NumiSealLaneAggregation {
    public static func aggregate(
        canonicalization: NumiSealCanonicalizationResult,
        policy: NumiSealAcceptancePolicy,
        parameters: SuperNeoParameters = .goldilocks,
        limits: NumiSealAggregationLimits = .defaultLimits(),
        executionPolicy: SuperNeoExecutionPolicy = .highAssurance
    ) throws -> [NumiSealLaneAggregate] {
        let publicStatement = try NumiSealPublicStatement(
            canonicalization: canonicalization,
            policy: policy
        )
        try publicStatement.validate(against: policy)
        guard parameters.profileID == policy.profileID else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregation parameter profile mismatch")
        }
        guard limits.maximumObligationsPerAggregate > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate limit must be positive")
        }

        var aggregates: [NumiSealLaneAggregate] = []
        var obligationOffset = 0
        for summary in canonicalization.laneSummaries {
            let laneEnd = obligationOffset + summary.obligationCount
            guard laneEnd <= canonicalization.obligations.count else {
                throw SuperNeoError.invalidParameter("NumiSeal lane summary exceeds canonical obligation count")
            }
            let laneObligations = Array(canonicalization.obligations[obligationOffset..<laneEnd])
            guard laneObligations.allSatisfy({ $0.laneKey == summary.laneKey }) else {
                throw SuperNeoError.invalidParameter("NumiSeal lane summary does not match canonical obligations")
            }

            var chunkStart = 0
            while chunkStart < laneObligations.count {
                let chunkEnd = min(chunkStart + limits.maximumObligationsPerAggregate, laneObligations.count)
                let chunk = Array(laneObligations[chunkStart..<chunkEnd])
                let aggregateIndex = aggregates.count
                let obligationDigests = chunk.map(\.obligationDigest)
                let challenges = challengesForAggregate(
                    publicStatement: publicStatement,
                    laneKey: summary.laneKey,
                    aggregateIndex: aggregateIndex,
                    obligationDigests: obligationDigests,
                    parameters: parameters
                )
                aggregates.append(try makeAggregate(
                    laneKey: summary.laneKey,
                    aggregateIndex: aggregateIndex,
                    canonicalObligations: chunk,
                    obligationDigests: obligationDigests,
                    challenges: challenges,
                    executionPolicy: executionPolicy
                ))
                chunkStart = chunkEnd
            }
            obligationOffset = laneEnd
        }
        guard obligationOffset == canonicalization.obligations.count else {
            throw SuperNeoError.invalidParameter("NumiSeal lane summaries do not cover all canonical obligations")
        }
        return aggregates
    }

    private static func challengesForAggregate(
        publicStatement: NumiSealPublicStatement,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        obligationDigests: [Digest256],
        parameters: SuperNeoParameters
    ) -> [CyclotomicRing54] {
        var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.numiseal.rlc.v1")
        transcript.absorb(publicStatement.digest.superNeoBytes)
        transcript.absorb(laneKey.superNeoBytes)
        transcript.absorb(numiSealEncodeCount(aggregateIndex))
        transcript.absorb(numiSealEncodeCount(obligationDigests.count))
        obligationDigests.forEach { transcript.absorb($0.superNeoBytes) }
        return obligationDigests.map { _ in transcript.challengeRing(parameters: parameters) }
    }

    private static func makeAggregate(
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        canonicalObligations: [NumiSealCanonicalObligation],
        obligationDigests: [Digest256],
        challenges: [CyclotomicRing54],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> NumiSealLaneAggregate {
        guard let first = canonicalObligations.first?.obligation else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate cannot be empty")
        }
        guard canonicalObligations.count == challenges.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate challenge count mismatch")
        }

        var aggregateCommitment = AjtaiCommitment(
            Array(repeating: CyclotomicRing54.zero, count: first.commitment.elements.count)
        )
        var aggregatePublicInput = Array(
            repeating: CyclotomicRing54.zero,
            count: first.publicInputEncoding.packed.count
        )
        var aggregateEvaluations = Array(
            repeating: CyclotomicExt2Ring54.zero,
            count: first.matrixEvaluations.count
        )

        for (challenge, canonicalObligation) in zip(challenges, canonicalObligations) {
            let obligation = canonicalObligation.obligation
            guard canonicalObligation.laneKey == laneKey else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate lane key mismatch")
            }
            guard obligation.evalPoint == first.evalPoint else {
                throw SuperNeoError.invalidParameter("NumiSeal lane aggregate evaluation points must match")
            }
            guard obligation.publicInput.count == first.publicInput.count else {
                throw SuperNeoError.invalidParameter("NumiSeal lane aggregate public input lengths must match")
            }
            guard obligation.publicInputEncoding.packed.count == aggregatePublicInput.count else {
                throw SuperNeoError.invalidParameter("NumiSeal lane aggregate packed public input lengths must match")
            }
            guard obligation.commitment.elements.count == aggregateCommitment.elements.count else {
                throw SuperNeoError.invalidParameter("NumiSeal lane aggregate commitment lengths must match")
            }
            guard obligation.matrixEvaluations.count == aggregateEvaluations.count else {
                throw SuperNeoError.invalidParameter("NumiSeal lane aggregate matrix evaluation lengths must match")
            }

            for index in aggregateCommitment.elements.indices {
                let product = executionPolicy.usesConstantWorkCPU
                    ? challenge.multipliedConstantWork(by: obligation.commitment.elements[index])
                    : challenge * obligation.commitment.elements[index]
                aggregateCommitment.elements[index] = aggregateCommitment.elements[index] + product
            }
            for index in aggregatePublicInput.indices {
                let product = executionPolicy.usesConstantWorkCPU
                    ? challenge.multipliedConstantWork(by: obligation.publicInputEncoding.packed[index])
                    : challenge * obligation.publicInputEncoding.packed[index]
                aggregatePublicInput[index] = aggregatePublicInput[index] + product
            }
            for index in aggregateEvaluations.indices {
                aggregateEvaluations[index] = aggregateEvaluations[index] + challenge * obligation.matrixEvaluations[index]
            }
        }

        let aggregatePublicInputField = Array(
            SuperNeoEmbedding.unpack(aggregatePublicInput).prefix(first.publicInput.count)
        )
        return try NumiSealLaneAggregate(
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            obligationDigests: obligationDigests,
            challenges: challenges,
            aggregateCommitment: aggregateCommitment,
            aggregatePublicInputEncoding: PublicInputEncoding(field: aggregatePublicInputField),
            evalPoint: first.evalPoint,
            aggregateMatrixEvaluations: aggregateEvaluations
        )
    }
}
