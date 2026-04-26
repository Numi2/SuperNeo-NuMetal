import XCTest
@_spi(Benchmarking) @testable import SuperNeo_NuMetal

final class PayPerBitProfileEvaluationTests: XCTestCase {
    func testBinaryVectorDropsFixedDecompositionPlanes() throws {
        let vector = Array(repeating: GoldilocksField.one, count: 64)
        let evaluation = try SuperNeoPayPerBitProfileEvaluation(fieldVector: vector)

        XCTAssertEqual(evaluation.fieldElementCount, 64)
        XCTAssertEqual(evaluation.paddedFieldSlotCount, 108)
        XCTAssertEqual(evaluation.ringColumnCount, 2)
        XCTAssertEqual(evaluation.paddingFieldSlotCount, 44)
        XCTAssertEqual(evaluation.signedBitWidthMaximum, 1)
        XCTAssertEqual(evaluation.currentFixedDecompositionSlotCount, 108 * 14)
        XCTAssertEqual(evaluation.payPerBitDenseSlotCount, 64)
        XCTAssertEqual(evaluation.payPerBitPaddedSlotCount, 108)
        XCTAssertEqual(evaluation.payPerBitActiveDigitSlotCount, 64)
        XCTAssertEqual(evaluation.fixedToPayPerBitPaddedSlotRatio, 14)
        XCTAssertEqual(evaluation.fixedToPayPerBitOpeningRatio, 14)
        XCTAssertTrue(evaluation.currentProfileCanRepresentAllValues)
    }

    func testSmallSignedValuesUseActualBitWidth() throws {
        let vector: [GoldilocksField] = [
            .zero,
            .one,
            -.one,
            GoldilocksField(2),
            -GoldilocksField(2)
        ]
        let evaluation = try SuperNeoPayPerBitProfileEvaluation(fieldVector: vector)

        XCTAssertEqual(evaluation.nonzeroFieldElementCount, 4)
        XCTAssertEqual(evaluation.signedBitWidthMaximum, 2)
        XCTAssertEqual(evaluation.signedBitWidthSum, 6)
        XCTAssertEqual(evaluation.payPerBitDenseSlotCount, 10)
        XCTAssertEqual(evaluation.payPerBitActiveDigitSlotCount, 6)
        XCTAssertEqual(evaluation.fixedToPayPerBitOpeningRatio, 7)
        XCTAssertTrue(evaluation.currentProfileCanRepresentAllValues)
    }

    func testCurrentProfileRepresentabilityBoundaryIsReported() throws {
        let withinBound = try SuperNeoPayPerBitProfileEvaluation(
            fieldVector: [GoldilocksField((1 << 14) - 1)]
        )
        let beyondBound = try SuperNeoPayPerBitProfileEvaluation(
            fieldVector: [GoldilocksField(1 << 14)]
        )

        XCTAssertTrue(withinBound.currentProfileCanRepresentAllValues)
        XCTAssertFalse(beyondBound.currentProfileCanRepresentAllValues)
    }

    func testOptimizedCommitmentSkipsFixedPayPerBitLimbsAndRecomposes() throws {
        let vector = (0..<64).map { index in
            index % 3 == 0 ? GoldilocksField.one : GoldilocksField.zero
        }
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-optimized-commitment-test".utf8)
        )
        let direct = try AjtaiCommitter.commitReference(key: key, fieldWitness: vector)
        let result = try SuperNeoPayPerBitCommitter.commitReference(key: key, fieldVector: vector)
        let recomposedVector = try SuperNeoPayPerBitCommitter.recomposeFieldVector(result.plan)
        let recomposedCommitment = try SuperNeoPayPerBitCommitter.recomposeCommitment(result.commitments)

        XCTAssertEqual(result.plan.activeLimbCount, 1)
        XCTAssertEqual(result.plan.skippedFixedLimbCount, key.parameters.decompositionLength - 1)
        XCTAssertEqual(result.plan.activeDigitSlotCount, vector.filter { $0 != .zero }.count)
        XCTAssertEqual(recomposedVector, vector)
        XCTAssertEqual(recomposedCommitment, direct)
        XCTAssertTrue(result.usesOnlySmallCoefficientScalings)
        XCTAssertLessThan(result.plan.activePaddedSlotCount, result.plan.fixedPaddedSlotCount)
    }

    func testConstantScheduleCommitmentKeepsFullPrivateLimbSchedule() throws {
        let vector = (0..<64).map { index in
            index % 5 == 0 ? GoldilocksField.one : GoldilocksField.zero
        }
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-constant-commitment-test".utf8)
        )
        let direct = try AjtaiCommitter.commitConstantWorkReference(key: key, fieldWitness: vector)
        let result = try SuperNeoPayPerBitCommitter.commitConstantScheduleReference(key: key, fieldVector: vector)
        let recomposedVector = try SuperNeoPayPerBitCommitter.recomposeFieldVector(result.plan)
        let recomposedCommitment = try SuperNeoPayPerBitCommitter.recomposeCommitment(result.commitments)

        XCTAssertEqual(result.plan.schedule, .constantSecret)
        XCTAssertEqual(result.plan.activeLimbCount, key.parameters.decompositionLength)
        XCTAssertEqual(result.plan.skippedFixedLimbCount, 0)
        XCTAssertEqual(result.plan.activeDigitSlotCount, result.plan.fixedPaddedSlotCount)
        XCTAssertEqual(result.commitments.count, key.parameters.decompositionLength)
        XCTAssertEqual(recomposedVector, vector)
        XCTAssertEqual(recomposedCommitment, direct)
        XCTAssertFalse(result.usesOnlySmallCoefficientScalings)
    }

    func testConstantScheduleCommitmentWorkDoesNotExposeWitnessSparsity() throws {
        let sparseVector = (0..<64).map { index in
            index == 0 ? GoldilocksField.one : GoldilocksField.zero
        }
        let denseVector = Array(repeating: GoldilocksField.one, count: 64)
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: sparseVector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-constant-sparsity-test".utf8)
        )

        let sparse = try SuperNeoPayPerBitCommitter.commitConstantScheduleReference(
            key: key,
            fieldVector: sparseVector
        )
        let dense = try SuperNeoPayPerBitCommitter.commitConstantScheduleReference(
            key: key,
            fieldVector: denseVector
        )

        XCTAssertEqual(sparse.plan.schedule, .constantSecret)
        XCTAssertEqual(dense.plan.schedule, .constantSecret)
        XCTAssertEqual(sparse.plan.activeDigitSlotCount, sparse.plan.fixedPaddedSlotCount)
        XCTAssertEqual(dense.plan.activeDigitSlotCount, dense.plan.fixedPaddedSlotCount)
        XCTAssertEqual(sparse.plan.activeLimbCount, key.parameters.decompositionLength)
        XCTAssertEqual(dense.plan.activeLimbCount, key.parameters.decompositionLength)
        XCTAssertEqual(sparse.commitments.count, key.parameters.decompositionLength)
        XCTAssertEqual(dense.commitments.count, key.parameters.decompositionLength)
        XCTAssertEqual(sparse.commitmentWorkProfiles, dense.commitmentWorkProfiles)
    }

    func testPrivateWitnessEvidenceUsesConstantScheduleByDefault() throws {
        let vector = (0..<64).map { index in
            index == 0 ? GoldilocksField.one : GoldilocksField.zero
        }
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-private-evidence-test".utf8)
        )
        let commitment = try AjtaiCommitter.commitConstantWorkReference(key: key, fieldWitness: vector)
        let evidence = try SuperNeoPayPerBitWitnessEvidence(
            key: key,
            witnesses: [vector],
            expectedCommitments: [commitment]
        )

        XCTAssertTrue(evidence.hasValidDigest())
        XCTAssertEqual(evidence.maxActiveLimbCount, key.parameters.decompositionLength)
        XCTAssertEqual(evidence.totalSkippedFixedLimbCount, 0)
        XCTAssertEqual(evidence.totalActivePaddedSlotCount, evidence.totalFixedPaddedSlotCount)
    }

    func testOptimizedWitnessEvidenceCanExposeSparseBenchmarkCounts() throws {
        let vector = (0..<64).map { index in
            index == 0 ? GoldilocksField.one : GoldilocksField.zero
        }
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-optimized-evidence-test".utf8)
        )
        let commitment = try AjtaiCommitter.commitReference(key: key, fieldWitness: vector)
        let evidence = try SuperNeoPayPerBitWitnessEvidence(
            key: key,
            witnesses: [vector],
            expectedCommitments: [commitment],
            executionPolicy: SuperNeoExecutionPolicy(secretArithmetic: .optimized)
        )

        XCTAssertTrue(evidence.hasValidDigest())
        XCTAssertEqual(evidence.maxActiveLimbCount, 1)
        XCTAssertGreaterThan(evidence.totalSkippedFixedLimbCount, 0)
        XCTAssertLessThan(evidence.totalActivePaddedSlotCount, evidence.totalFixedPaddedSlotCount)
    }

    func testOptimizedCommitmentUsesOnlyRequiredSignedLimbs() throws {
        let vector: [GoldilocksField] = [
            .zero,
            .one,
            -.one,
            GoldilocksField(2),
            -GoldilocksField(2),
            GoldilocksField(3)
        ]
        let plan = try SuperNeoPayPerBitCommitter.decompositionPlan(fieldVector: vector)

        XCTAssertEqual(plan.activeLimbCount, 2)
        XCTAssertEqual(plan.activeDigitSlotCount, 6)
        XCTAssertEqual(try SuperNeoPayPerBitCommitter.recomposeFieldVector(plan), vector)
    }

    func testOptimizedCommitmentSkipsZeroLimbsInsideActiveRange() throws {
        var vector = Array(repeating: GoldilocksField.zero, count: 64)
        vector[0] = GoldilocksField(4)
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-zero-limb-commitment-test".utf8)
        )
        let direct = try AjtaiCommitter.commitReference(key: key, fieldWitness: vector)
        let result = try SuperNeoPayPerBitCommitter.commitReference(key: key, fieldVector: vector)
        let zeroCommitment = AjtaiCommitment(Array(repeating: .zero, count: key.parameters.kappa))

        XCTAssertEqual(result.plan.activeLimbCount, 3)
        XCTAssertEqual(result.plan.activeDigitSlotCount, 1)
        XCTAssertEqual(result.commitments[0], zeroCommitment)
        XCTAssertEqual(result.commitments[1], zeroCommitment)
        XCTAssertEqual(result.commitmentWorkProfiles[0].activeRotationTerms, 0)
        XCTAssertEqual(result.commitmentWorkProfiles[1].activeRotationTerms, 0)
        XCTAssertGreaterThan(result.commitmentWorkProfiles[2].activeRotationTerms, 0)
        XCTAssertEqual(try SuperNeoPayPerBitCommitter.recomposeCommitment(result.commitments), direct)
    }

    func testConstantScheduleOpeningOracleDoesNotExposeSparseLimbWork() throws {
        var vector = Array(repeating: GoldilocksField.zero, count: 64)
        vector[0] = GoldilocksField(4)
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-constant-opening-test".utf8)
        )
        let plan = try SuperNeoPayPerBitCommitter.constantScheduleDecompositionPlan(fieldVector: vector)
        let packedLimbs = try plan.limbs.map { try SuperNeoEmbedding.packPadded($0) }
        let transformedMatrix = try SparseFieldMatrix.identity(size: vector.count).transformedSparseForSuperNeo()
        let point = (0..<6).map { index in
            GoldilocksExt2(GoldilocksField(UInt64(index + 2)), GoldilocksField(UInt64(index + 17)))
        }
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)

        let constant = try SuperNeoPayPerBitOpeningOracle.makeConstantScheduleOpeningArtifacts(
            key: key,
            transformedMatrices: [transformedMatrix],
            packedLimbs: packedLimbs,
            point: point
        )
        let denseCommitments = try packedLimbs.map {
            try AjtaiCommitter.commitConstantWorkReference(key: key, message: $0)
        }
        let denseEvaluations = try packedLimbs.map { packed in
            [try transformedMatrix.evaluatedProductConstantWork(by: packed, rHat: rHat)]
        }

        XCTAssertEqual(plan.schedule, .constantSecret)
        XCTAssertEqual(constant.openingWorkProfile.limbCount, key.parameters.decompositionLength)
        XCTAssertEqual(constant.openingWorkProfile.zeroLimbCount, 0)
        XCTAssertEqual(
            constant.openingWorkProfile.activeDigitSlotCount,
            constant.openingWorkProfile.paddedDigitSlotCount
        )
        XCTAssertEqual(constant.commitments, denseCommitments)
        XCTAssertEqual(constant.evaluations, denseEvaluations)
        XCTAssertEqual(constant.commitmentWorkProfiles.count, key.parameters.decompositionLength)
        let expectedWorkProfile = constant.commitmentWorkProfiles[0]
        XCTAssertTrue(constant.commitmentWorkProfiles.allSatisfy { $0 == expectedWorkProfile })
    }

    func testSparseOpeningOracleSkipsZeroLimbsAndMatchesDenseArtifacts() throws {
        var vector = Array(repeating: GoldilocksField.zero, count: 64)
        vector[0] = GoldilocksField(4)
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: vector.count) / CyclotomicRing54.degree,
            seed: Array("pay-per-bit-sparse-opening-test".utf8)
        )
        let plan = try SuperNeoPayPerBitCommitter.decompositionPlan(fieldVector: vector)
        let packedLimbs = try plan.limbs.map { try SuperNeoEmbedding.packPadded($0) }
        let transformedMatrix = try SparseFieldMatrix.identity(size: vector.count).transformedSparseForSuperNeo()
        let point = (0..<6).map { index in
            GoldilocksExt2(GoldilocksField(UInt64(index + 2)), GoldilocksField(UInt64(index + 17)))
        }
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        let sparse = try SuperNeoPayPerBitOpeningOracle.makeOpeningArtifacts(
            key: key,
            transformedMatrices: [transformedMatrix],
            packedLimbs: packedLimbs,
            point: point
        )
        let hotPath = try SuperNeoPayPerBitOpeningOracle.makeOpeningArtifacts(
            key: key,
            transformedMatrices: [transformedMatrix],
            packedLimbs: packedLimbs,
            point: point,
            recordWorkProfiles: false
        )
        let denseCommitments = try packedLimbs.map { try AjtaiCommitter.commitReference(key: key, message: $0) }
        let denseEvaluations = try packedLimbs.map { packed in
            [try transformedMatrix.evaluatedProduct(by: packed, rHat: rHat)]
        }

        XCTAssertEqual(plan.activeLimbCount, 3)
        XCTAssertEqual(sparse.openingWorkProfile.zeroLimbCount, 2)
        XCTAssertEqual(sparse.openingWorkProfile.activeDigitSlotCount, 1)
        XCTAssertGreaterThan(sparse.openingWorkProfile.skippedDigitSlotCount, 0)
        XCTAssertEqual(sparse.commitments, denseCommitments)
        XCTAssertEqual(sparse.evaluations, denseEvaluations)
        XCTAssertTrue(hotPath.commitmentWorkProfiles.isEmpty)
        XCTAssertEqual(hotPath.commitments, denseCommitments)
        XCTAssertEqual(hotPath.evaluations, denseEvaluations)
    }
}
