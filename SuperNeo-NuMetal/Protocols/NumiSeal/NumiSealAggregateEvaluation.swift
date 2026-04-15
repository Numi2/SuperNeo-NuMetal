import Foundation

public enum NumiSealAggregateEvaluationOracle {
    public static func witnessedAggregateClaim(
        aggregate: NumiSealLaneAggregate,
        claims: [CCSEvaluationClaim],
        shape: CCSShape,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> CCSEvaluationClaim {
        guard aggregate.obligationDigests.count == aggregate.challenges.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate obligation/challenge count mismatch")
        }
        guard claims.count == aggregate.challenges.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate claim count mismatch")
        }
        guard let first = claims.first else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate cannot be empty")
        }
        guard aggregate.laneKey.shapeDigest == shape.shapeDigest else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate shape mismatch")
        }
        guard aggregate.evalPoint.count == (try log2ExactRowCount(shape.m)) else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate evaluation point length mismatch")
        }
        guard first.point == aggregate.evalPoint else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate evaluation point mismatch")
        }
        guard first.publicInput.count == shape.nPublicField else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate public input length must match shape")
        }
        guard first.commitment.elements.count == aggregate.aggregateCommitment.elements.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate commitment length mismatch")
        }
        guard first.publicInput.count == aggregate.aggregatePublicInputEncoding.field.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate public input length mismatch")
        }
        guard first.evaluations.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate matrix evaluation length must match shape")
        }
        guard first.evaluations.count == aggregate.aggregateMatrixEvaluations.count else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate matrix evaluation length mismatch")
        }

        var aggregateCommitment = AjtaiCommitment(
            Array(repeating: CyclotomicRing54.zero, count: first.commitment.elements.count)
        )
        var aggregatePublicInput = Array(
            repeating: CyclotomicRing54.zero,
            count: SuperNeoEmbedding.paddedLength(forFieldElementCount: first.publicInput.count) / CyclotomicRing54.degree
        )
        var aggregateEvaluations = Array(
            repeating: CyclotomicExt2Ring54.zero,
            count: first.evaluations.count
        )
        var aggregateWitness = Array(repeating: CyclotomicRing54.zero, count: shape.nRing)
        var allWitnessesUseFieldLength = true

        for (challenge, claim) in zip(aggregate.challenges, claims) {
            guard let witness = claim.witness else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate claim is missing witness")
            }
            guard claim.point == aggregate.evalPoint else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate claim evaluation point mismatch")
            }
            guard claim.commitment.elements.count == aggregateCommitment.elements.count else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate claim commitment length mismatch")
            }
            guard claim.publicInput.count == first.publicInput.count else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate claim public input length mismatch")
            }
            guard claim.evaluations.count == aggregateEvaluations.count else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate claim matrix evaluation length mismatch")
            }
            guard witnessPrefixMatches(claim.publicInput, witness: witness) else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate claim public input does not match witness")
            }

            let packedPublicInput = try SuperNeoEmbedding.packPadded(claim.publicInput)
            guard packedPublicInput.count == aggregatePublicInput.count else {
                throw SuperNeoError.invalidParameter("NumiSeal aggregate packed public input length mismatch")
            }
            let packedWitness = try packWitness(witness, shape: shape)
            allWitnessesUseFieldLength = allWitnessesUseFieldLength && witness.count == shape.nField

            for index in aggregateCommitment.elements.indices {
                let product = executionPolicy.usesConstantWorkCPU
                    ? challenge.multipliedConstantWork(by: claim.commitment.elements[index])
                    : challenge * claim.commitment.elements[index]
                aggregateCommitment.elements[index] = aggregateCommitment.elements[index] + product
            }
            for index in aggregatePublicInput.indices {
                let product = executionPolicy.usesConstantWorkCPU
                    ? challenge.multipliedConstantWork(by: packedPublicInput[index])
                    : challenge * packedPublicInput[index]
                aggregatePublicInput[index] = aggregatePublicInput[index] + product
            }
            for index in aggregateEvaluations.indices {
                aggregateEvaluations[index] = aggregateEvaluations[index] + challenge * claim.evaluations[index]
            }
            for index in aggregateWitness.indices {
                let product = executionPolicy.usesConstantWorkCPU
                    ? challenge.multipliedConstantWork(by: packedWitness[index])
                    : challenge * packedWitness[index]
                aggregateWitness[index] = aggregateWitness[index] + product
            }
        }

        let aggregatePublicInputField = Array(
            SuperNeoEmbedding.unpack(aggregatePublicInput).prefix(first.publicInput.count)
        )
        guard aggregateCommitment == aggregate.aggregateCommitment else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate commitment does not match claims")
        }
        guard PublicInputEncoding(field: aggregatePublicInputField) == aggregate.aggregatePublicInputEncoding else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate public input does not match claims")
        }
        guard aggregateEvaluations == aggregate.aggregateMatrixEvaluations else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate matrix evaluations do not match claims")
        }

        let unpackedWitness = SuperNeoEmbedding.unpack(aggregateWitness)
        let witness = allWitnessesUseFieldLength
            ? Array(unpackedWitness.prefix(shape.nField))
            : unpackedWitness
        return CCSEvaluationClaim(
            commitment: aggregate.aggregateCommitment,
            publicInput: aggregate.aggregatePublicInputEncoding.field,
            point: aggregate.evalPoint,
            evaluations: aggregate.aggregateMatrixEvaluations,
            witness: witness
        )
    }

    public static func verifyAggregateOpening(
        aggregate: NumiSealLaneAggregate,
        witness: [GoldilocksField],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        parameters: SuperNeoParameters = .goldilocks,
        transformedMatrices: [SparseRingMatrixCSR]? = nil,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> Bool {
        guard aggregate.laneKey.profileID == parameters.profileID else { return false }
        guard aggregate.laneKey.shapeDigest == shape.shapeDigest else { return false }
        guard aggregate.laneKey.verifierKeyDigest == key.verifierKeyDigest else { return false }
        guard key.parameters == parameters else { return false }
        guard key.matrix.columns == shape.nRing else { return false }
        guard aggregate.aggregateCommitment.elements.count == parameters.kappa else { return false }
        guard aggregate.aggregatePublicInputEncoding.field.count == shape.nPublicField else { return false }
        guard aggregate.evalPoint.count == (try log2ExactRowCount(shape.m)) else { return false }
        guard aggregate.laneKey.evalPointDigest == NumiSealCanonicalization.evalPointDigest(aggregate.evalPoint) else {
            return false
        }
        guard aggregate.aggregateMatrixEvaluations.count == shape.numMatrices else { return false }
        guard witnessPrefixMatches(aggregate.aggregatePublicInputEncoding.field, witness: witness) else {
            return false
        }

        let matrices = try transformedMatrices ?? shape.compiledSparseForSuperNeo().transformedSparseMatrices
        guard matrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate transformed matrix count mismatch")
        }
        let packedWitness = try packWitness(witness, shape: shape)
        let commitment = try commit(
            key: key,
            message: packedWitness,
            executionPolicy: executionPolicy
        )
        guard commitment == aggregate.aggregateCommitment else { return false }

        let rHat = try MultilinearEvaluation.checkedBasis(at: aggregate.evalPoint)
        let evaluations = try matrices.map { matrix in
            try evaluateTransformedMatrix(
                matrix,
                by: packedWitness,
                rHat: rHat,
                executionPolicy: executionPolicy
            )
        }
        return evaluations == aggregate.aggregateMatrixEvaluations
    }

    private static func packWitness(
        _ witness: [GoldilocksField],
        shape: CCSShape
    ) throws -> [CyclotomicRing54] {
        guard witness.count == shape.nField || witness.count == shape.nRing * CyclotomicRing54.degree else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate witness length must match shape.nField or padded ring length")
        }
        let packed = try SuperNeoEmbedding.packPadded(witness)
        guard packed.count == shape.nRing else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate witness ring length mismatch")
        }
        return packed
    }

    private static func witnessPrefixMatches(
        _ publicInput: [GoldilocksField],
        witness: [GoldilocksField]
    ) -> Bool {
        guard publicInput.count <= witness.count else { return false }
        for index in publicInput.indices where publicInput[index] != witness[index] {
            return false
        }
        return true
    }

    private static func log2ExactRowCount(_ value: Int) throws -> Int {
        guard value > 0, (value & (value - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal aggregate row count must be a positive power of two")
        }
        var exponent = 0
        var remaining = value
        while remaining > 1 {
            remaining >>= 1
            exponent += 1
        }
        return exponent
    }

    private static func commit(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> AjtaiCommitment {
        if executionPolicy.usesConstantWorkCPU {
            return try AjtaiCommitter.commitConstantWorkReference(key: key, message: message)
        }
        return try AjtaiCommitter.commitReference(key: key, message: message)
    }

    private static func evaluateTransformedMatrix(
        _ matrix: SparseRingMatrixCSR,
        by witness: [CyclotomicRing54],
        rHat: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> CyclotomicExt2Ring54 {
        if executionPolicy.usesConstantWorkCPU {
            return try matrix.evaluatedProductConstantWork(by: witness, rHat: rHat)
        }
        return try matrix.evaluatedProduct(by: witness, rHat: rHat)
    }
}
