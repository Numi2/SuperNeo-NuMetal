import XCTest
import Metal
@testable import SuperNeo_NuMetal

private let encodedCountByteWidth = 8
private let proofEnvelopeVerifierKeyDigestOffset = 4 + 2 + 2 + 1 + (2 * Digest256.byteCount)
private let ceOpeningStatementVerifierKeyDigestOffset = 2 + Digest256.byteCount
private let terminalCEStatementVerifierKeyDigestOffset = 2 + Digest256.byteCount
private let compressedStatementContextVerifierKeyDigestOffset =
    Digest256.byteCount + 2 + 1 + (2 * Digest256.byteCount)
private let compressedStatementVerifierKeyDigestOffset =
    compressedStatementContextVerifierKeyDigestOffset + (4 * Digest256.byteCount)

class SuperNeoTestCase: XCTestCase {
    func requireMetalDevice(file: StaticString = #filePath, line: UInt = #line) throws -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip(
                "Metal device unavailable; CPU-only environments intentionally skip Metal differential coverage",
                file: file,
                line: line
            )
        }
        return device
    }
}

final class AlgebraCoreTests: SuperNeoTestCase {
    // MARK: - Tier 0: deterministic algebra and backend differential properties

    func testTier0GoldilocksAndExtensionFieldsSeededLaws() throws {
        let u = GoldilocksExt2(.zero, .one)
        XCTAssertEqual(u * u, GoldilocksExt2(GoldilocksExt2.nonResidue))

        let boundaryValues = [
            GoldilocksField.zero,
            .one,
            GoldilocksField(1 << 32),
            GoldilocksField((1 << 32) - 1),
            GoldilocksField(GoldilocksField.modulus - 2),
            GoldilocksField(GoldilocksField.modulus - 1),
            GoldilocksField(UInt64.max)
        ]
        XCTAssertEqual(GoldilocksField(UInt64.max), GoldilocksField((1 << 32) - 2))
        XCTAssertEqual(GoldilocksField(1 << 32) * GoldilocksField(1 << 32), GoldilocksField((1 << 32) - 1))

        var generator = SeededTestGenerator(seed: 0x5355_5045_524E_454F)
        var triples: [(GoldilocksField, GoldilocksField, GoldilocksField)] = []
        for index in 0..<128 {
            let a = index < boundaryValues.count ? boundaryValues[index] : generator.field()
            triples.append((a, generator.field(), generator.field()))
        }

        for (a, b, c) in triples {
            XCTAssertEqual(a + b, b + a)
            XCTAssertEqual(a * b, b * a)
            XCTAssertEqual((a + b) + c, a + (b + c))
            XCTAssertEqual((a * b) * c, a * (b * c))
            XCTAssertEqual(a * (b + c), (a * b) + (a * c))
            XCTAssertEqual((a + b) - b, a)
            XCTAssertEqual(try GoldilocksField(littleEndianBytes: a.littleEndianBytes[...]), a)
            if a != .zero {
                XCTAssertEqual(try a.inverse() * a, .one)
                XCTAssertEqual(a.pow(GoldilocksField.modulus - 1), .one)
            }

            let x = GoldilocksExt2(a, b)
            let y = GoldilocksExt2(b, c)
            let z = GoldilocksExt2(c, a)
            XCTAssertEqual(x + y, y + x)
            XCTAssertEqual(x * y, y * x)
            XCTAssertEqual((x + y) + z, x + (y + z))
            XCTAssertEqual((x * y) * z, x * (y * z))
            XCTAssertEqual(x * (y + z), (x * y) + (x * z))
            XCTAssertEqual(try GoldilocksExt2(littleEndianBytes: x.littleEndianBytes[...]), x)
            if x != .zero {
                XCTAssertEqual(try x.inverse() * x, .one)
            }
        }

        XCTAssertThrowsSuperNeoError(try GoldilocksField.zero.inverse(), .divisionByZero)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksField(littleEndianBytes: withUnsafeBytes(of: GoldilocksField.modulus.littleEndian, Array.init)[...]),
            .invalidEncoding("non-canonical Goldilocks element")
        )
        XCTAssertThrowsSuperNeoError(
            try GoldilocksField(littleEndianBytes: [UInt8](repeating: 0, count: 7)[...]),
            .invalidEncoding("Goldilocks element must be 8 bytes")
        )
        XCTAssertThrowsSuperNeoError(try GoldilocksExt2.zero.inverse(), .divisionByZero)
        XCTAssertThrowsSuperNeoError(
            try GoldilocksExt2(littleEndianBytes: [UInt8](repeating: 0, count: 15)[...]),
            .invalidEncoding("GoldilocksExt2 element must be 16 bytes")
        )
    }

    func testTier0CyclotomicRingSeededLawsAndEmbedding() throws {
        let x27 = monomialRing(27)
        let x54 = monomialRing(54)
        let x108 = monomialRing(108)
        XCTAssertEqual(x54 + x27 + .one, .zero)
        XCTAssertEqual(x108, x27)

        var high = Array(repeating: GoldilocksField.zero, count: 55)
        high[54] = .one
        let reduced = CyclotomicRing54(high)
        XCTAssertEqual(reduced[0], -GoldilocksField.one)
        XCTAssertEqual(reduced[27], -GoldilocksField.one)

        var generator = SeededTestGenerator(seed: 0x434C_4F54_4F4D_4943)
        for _ in 0..<32 {
            let a = generator.ring()
            let b = generator.ring()
            let c = generator.ring()
            let scalar = generator.field()

            XCTAssertEqual(a + b, b + a)
            XCTAssertEqual(a * .one, a)
            XCTAssertEqual(a * b, b * a)
            XCTAssertEqual((a * b) * c, a * (b * c))
            XCTAssertEqual(a * (b + c), (a * b) + (a * c))
            XCTAssertEqual(a.scaled(by: scalar), CyclotomicRing54(a.coefficients.map { $0 * scalar }))
            XCTAssertEqual(try CyclotomicRing54(littleEndianBytes: a.littleEndianBytes), a)
        }

        let vector = (0..<109).map { GoldilocksField(UInt64(($0 * 17 + 5) % 251)) }
        let padded = try SuperNeoEmbedding.packPadded(vector)
        let unpacked = SuperNeoEmbedding.unpack(padded)
        XCTAssertEqual(Array(unpacked.prefix(vector.count)), vector)
        XCTAssertEqual(Array(unpacked.dropFirst(vector.count)), Array(repeating: .zero, count: 53))
        XCTAssertTrue(try SuperNeoEmbedding.preservesNorm(Array(unpacked)))

        XCTAssertThrowsSuperNeoError(
            try SuperNeoEmbedding.pack(Array(vector.prefix(55))),
            .invalidParameter("field vector length must be a multiple of 54")
        )
        XCTAssertThrowsSuperNeoError(
            try CyclotomicRing54(littleEndianBytes: Array(CyclotomicRing54.one.littleEndianBytes.dropLast())),
            .invalidEncoding("ring element must be 432 bytes")
        )
        XCTAssertThrowsSuperNeoError(
            try RingMatrix(rows: Int.max, columns: 2, elements: []),
            .invalidParameter("ring matrix dimensions do not match element count")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseRingMatrixCSR(
                rows: 2,
                columns: 3,
                rowOffsets: [0, 2, 1],
                columnIndices: [0],
                values: [.one]
            ),
            .invalidParameter("sparse ring row offsets out of bounds")
        )
    }

}

final class CommitmentCoreTests: SuperNeoTestCase {
    func testTier0AjtaiCommitmentSeededLinearityCorpus() throws {
        var generator = SeededTestGenerator(seed: 0x414A_5441_4943_4F4D)
        for columns in [1, 2, 4] {
            let keyA = try AjtaiCommitmentKey(columns: columns, seed: Array("ajtai-\(columns)".utf8))
            let keyB = try AjtaiCommitmentKey(columns: columns, seed: Array("ajtai-\(columns)".utf8))
            XCTAssertEqual(keyA, keyB)

            for _ in 0..<8 {
                let messageA = (0..<columns).map { _ in generator.ring() }
                let messageB = (0..<columns).map { _ in generator.ring() }
                let commitA = try AjtaiCommitter.commitReference(key: keyA, message: messageA)
                let commitB = try AjtaiCommitter.commitReference(key: keyA, message: messageB)
                let combinedMessage = zip(messageA, messageB).map(+)
                let combinedCommit = try AjtaiCommitter.commitReference(key: keyA, message: combinedMessage)
                XCTAssertEqual(commitA + commitB, combinedCommit)
            }
        }

        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("columns".utf8))
        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitter.commitReference(key: key, fieldWitness: Array(repeating: .one, count: 54)),
            .invalidParameter("Ajtai packed witness has 1 ring columns, expected 2")
        )
        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitter.commitReference(key: key, message: [CyclotomicRing54.one]),
            .invalidParameter("ring matrix/vector dimension mismatch")
        )
    }

    func testTier0AjtaiWorkProfileTracksSparseSmallCoefficientCost() throws {
        let rows = SuperNeoParameters.goldilocks.kappa
        let columns = 2
        let matrixElements = (0..<rows).flatMap { row in
            (0..<columns).map { column in
                var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
                coefficients[0] = .one
                coefficients[1 + ((row * columns + column) % (CyclotomicRing54.degree - 1))] =
                    GoldilocksField(UInt64(7 + row + column))
                return CyclotomicRing54(coefficients)
            }
        }
        let key = try AjtaiCommitmentKey(
            matrix: try RingMatrix(rows: rows, columns: columns, elements: matrixElements)
        )

        func ring(_ entries: [(Int, GoldilocksField)]) -> CyclotomicRing54 {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            for (index, value) in entries {
                coefficients[index] = value
            }
            return CyclotomicRing54(coefficients)
        }

        let binaryMessage = [
            ring([(0, .one), (13, .one), (53, .one)]),
            ring([(1, .one), (27, .one), (40, .one)])
        ]
        let binaryProfile = try AjtaiCommitter.workProfile(key: key, message: binaryMessage)
        XCTAssertEqual(binaryProfile.matrixRows, rows)
        XCTAssertEqual(binaryProfile.matrixColumns, columns)
        XCTAssertEqual(binaryProfile.ringDegree, CyclotomicRing54.degree)
        XCTAssertEqual(binaryProfile.messageCoefficientSlots, columns * CyclotomicRing54.degree)
        XCTAssertEqual(binaryProfile.nonzeroMessageCoefficients, 6)
        XCTAssertEqual(binaryProfile.smallMessageCoefficients, 6)
        XCTAssertEqual(binaryProfile.fullWidthMessageCoefficients, 0)
        XCTAssertEqual(binaryProfile.skippedZeroMessageCoefficients, columns * CyclotomicRing54.degree - 6)
        XCTAssertEqual(binaryProfile.activeRotationTerms, rows * 6)
        XCTAssertEqual(binaryProfile.smallCoefficientScalings, rows * 6 * 2)
        XCTAssertEqual(binaryProfile.fullWidthCoefficientScalings, 0)
        XCTAssertTrue(binaryProfile.usesOnlySmallCoefficientScalings)
        XCTAssertLessThan(binaryProfile.activeRotationTerms, rows * columns * CyclotomicRing54.degree)
        XCTAssertEqual(
            try AjtaiCommitter.commitReference(key: key, message: binaryMessage),
            AjtaiCommitment(try key.matrix.multiplied(by: binaryMessage))
        )

        let smallAndFullMessage = [
            ring([(0, GoldilocksField(3)), (1, -GoldilocksField(3)), (2, GoldilocksField(2))]),
            ring([(5, GoldilocksField(5)), (6, -GoldilocksField(2))])
        ]
        let mixedProfile = try AjtaiCommitter.workProfile(key: key, message: smallAndFullMessage)
        XCTAssertEqual(mixedProfile.nonzeroMessageCoefficients, 5)
        XCTAssertEqual(mixedProfile.smallMessageCoefficients, 2)
        XCTAssertEqual(mixedProfile.fullWidthMessageCoefficients, 3)
        XCTAssertEqual(mixedProfile.activeRotationTerms, rows * 5)
        XCTAssertEqual(mixedProfile.smallCoefficientScalings, rows * 2 * 2)
        XCTAssertEqual(mixedProfile.fullWidthCoefficientScalings, rows * 3 * 2)
        XCTAssertFalse(mixedProfile.usesOnlySmallCoefficientScalings)
        XCTAssertEqual(
            try AjtaiCommitter.commitReference(key: key, message: smallAndFullMessage),
            AjtaiCommitment(try key.matrix.multiplied(by: smallAndFullMessage))
        )

        XCTAssertThrowsSuperNeoError(
            try AjtaiCommitter.workProfile(key: key, message: [CyclotomicRing54.one]),
            .invalidParameter("ring matrix/vector dimension mismatch")
        )
    }

}

final class EvaluationCoreTests: SuperNeoTestCase {
    func testTier0MultilinearEvaluationMatchesDirectHypercubeOracle() throws {
        var generator = SeededTestGenerator(seed: 0x4D55_4C54_494C_494E)
        for dimension in 1...6 {
            for _ in 0..<16 {
                let vector = (0..<(1 << dimension)).map { _ in generator.field() }
                let point = (0..<dimension).map { _ in generator.ext2() }
                let basis = try MultilinearEvaluation.checkedBasis(at: point)

                XCTAssertEqual(basis.reduce(.zero, +), .one)
                XCTAssertEqual(
                    try MultilinearEvaluation.evaluate(vector, at: point),
                    directMultilinearEvaluation(vector, at: point)
                )
                for index in vector.indices {
                    let booleanPoint = (0..<dimension).map { bit in
                        ((index >> bit) & 1) == 0 ? GoldilocksExt2.zero : .one
                    }
                    XCTAssertEqual(try MultilinearEvaluation.evaluate(vector, at: booleanPoint), GoldilocksExt2(vector[index]))
                }
            }
        }

        let point = [
            GoldilocksExt2(GoldilocksField(2), GoldilocksField(1)),
            GoldilocksExt2(GoldilocksField(3), GoldilocksField(4))
        ]
        XCTAssertThrowsSuperNeoError(
            try MultilinearEvaluation.evaluate([.one, .one, .one], at: point),
            .invalidParameter("vector length must equal 2^point.count")
        )
        XCTAssertThrowsSuperNeoError(
            try MultilinearEvaluation.eq(point, [.one]),
            .invalidParameter("eq vector length mismatch")
        )
    }

}

final class ProtocolShapeTests: SuperNeoTestCase {
    // MARK: - Tier 1: transcript, matrix, and shape soundness

    func testRealSumcheckVerifierAcceptsTranscriptBoundProof() throws {
        let proof = makeToySumcheckProof()
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")

        let accepted = try SumcheckVerifier.verify(
            proof: proof,
            transcript: &transcript,
            expectedDegree: 1,
            expectedRoundCount: 2
        ) { point, value in
            value == toySumcheckPolynomial(point[0], point[1])
        }

        XCTAssertTrue(accepted)
    }

    func testSumcheckProverProofIsTranscriptAndFinalCheckBound() throws {
        let evaluator: ([GoldilocksExt2]) throws -> GoldilocksExt2 = { point in
            self.toySumcheckPolynomial(point[0], point[1])
        }
        let claimed = try (0..<4).reduce(GoldilocksExt2.zero) { partial, bits in
            let x = (bits & 1) == 0 ? GoldilocksExt2.zero : .one
            let y = (bits & 2) == 0 ? GoldilocksExt2.zero : .one
            return partial + (try evaluator([x, y]))
        }
        var proverTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("seed".utf8))
        var oracle = try EvaluatingSumcheckOracle(numVars: 2, maxDegreePerRound: 1, evaluator: evaluator)
        let proof = try SumcheckProver.prove(oracle: &oracle, claimedSum: claimed, transcript: &proverTranscript)

        var verifierTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("seed".utf8))
        XCTAssertTrue(
            try SumcheckVerifier.verify(
                proof: proof,
                transcript: &verifierTranscript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { point, value in
                try evaluator(point) == value
            }
        )

        verifierTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("wrong-seed".utf8))
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: proof,
                transcript: &verifierTranscript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { point, value in
                try evaluator(point) == value
            }
        )

        verifierTranscript = SumCheckTranscript(domainSeparator: "strict.sumcheck", seed: Array("seed".utf8))
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: proof,
                transcript: &verifierTranscript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { _, _ in
                false
            }
        )
    }

    func testSumcheckProverRejectsOracleClaimMismatch() throws {
        let evaluator: ([GoldilocksExt2]) throws -> GoldilocksExt2 = { point in
            point[0]
        }
        var oracle = try EvaluatingSumcheckOracle(numVars: 1, maxDegreePerRound: 1, evaluator: evaluator)
        var transcript = SumCheckTranscript(domainSeparator: "strict.sumcheck.invalid")

        XCTAssertThrowsSuperNeoError(
            try SumcheckProver.prove(oracle: &oracle, claimedSum: .zero, transcript: &transcript),
            .invalidParameter("sum-check oracle round polynomial does not match running claim")
        )
    }

    func testRealSumcheckVerifierRejectsTamperedRoundPolynomial() throws {
        let proof = makeToySumcheckProof()
        let badRound = SumcheckRound(coeffs: [proof.rounds[0].coeffs[0] + .one, proof.rounds[0].coeffs[1]])
        let tampered = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: [badRound, proof.rounds[1]],
            finalPoint: proof.finalPoint,
            finalValue: proof.finalValue
        )
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")

        let accepted = try SumcheckVerifier.verify(
            proof: tampered,
            transcript: &transcript,
            expectedDegree: 1,
            expectedRoundCount: 2
        ) { _, _ in true }

        XCTAssertFalse(accepted)
    }

    func testRealSumcheckVerifierRejectsWrongDegreeAndFinalPoint() throws {
        let proof = makeToySumcheckProof()
        var tooHighDegreeRounds = proof.rounds
        tooHighDegreeRounds[0] = SumcheckRound(coeffs: proof.rounds[0].coeffs + [.zero])
        let tooHighDegree = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: tooHighDegreeRounds,
            finalPoint: proof.finalPoint,
            finalValue: proof.finalValue
        )
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: tooHighDegree,
                transcript: &transcript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { _, _ in true }
        )

        let wrongPoint = SumcheckProof(
            claimedSum: proof.claimedSum,
            rounds: proof.rounds,
            finalPoint: [proof.finalPoint[0] + .one, proof.finalPoint[1]],
            finalValue: proof.finalValue
        )
        transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")
        XCTAssertFalse(
            try SumcheckVerifier.verify(
                proof: wrongPoint,
                transcript: &transcript,
                expectedDegree: 1,
                expectedRoundCount: 2
            ) { _, _ in true }
        )
    }

    func testSuperNeoMatrixTransformMatchesFieldMatrixVector() throws {
        let entries = [
            SparseFieldMatrix.Entry(row: 0, column: 0, value: GoldilocksField(3)),
            SparseFieldMatrix.Entry(row: 0, column: 17, value: GoldilocksField(5)),
            SparseFieldMatrix.Entry(row: 1, column: 9, value: GoldilocksField(7)),
            SparseFieldMatrix.Entry(row: 1, column: 53, value: GoldilocksField(11))
        ]
        let matrix = try SparseFieldMatrix(rows: 2, columns: 54, entries: entries)
        let vector = (0..<54).map { GoldilocksField(UInt64($0 + 1)) }

        let fieldProduct = try matrix.multiplied(by: vector)
        let ringConstants = try SuperNeoCPUBackend().matrixVectorConstants(matrix: matrix, vector: vector)
        let denseRows = try matrix.transformedForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector))
        let sparseRows = try matrix.transformedSparseForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector))

        XCTAssertEqual(ringConstants, fieldProduct)
        XCTAssertEqual(sparseRows, denseRows)
    }

    func testSuperNeoMatrixTransformHandlesMultipleRingColumnsAndDuplicateEntries() throws {
        let entries = [
            SparseFieldMatrix.Entry(row: 0, column: 0, value: GoldilocksField(3)),
            SparseFieldMatrix.Entry(row: 0, column: 54, value: GoldilocksField(5)),
            SparseFieldMatrix.Entry(row: 1, column: 17, value: GoldilocksField(7)),
            SparseFieldMatrix.Entry(row: 1, column: 17, value: GoldilocksField(11)),
            SparseFieldMatrix.Entry(row: 2, column: 69, value: GoldilocksField(13)),
            SparseFieldMatrix.Entry(row: 3, column: 1, value: GoldilocksField(19))
        ]
        let matrix = try SparseFieldMatrix(rows: 4, columns: 70, entries: entries)
        let vector = (0..<70).map { GoldilocksField(UInt64(($0 * 9 + 4) % 29)) }

        XCTAssertEqual(
            try SuperNeoCPUBackend().matrixVectorConstants(matrix: matrix, vector: vector),
            try matrix.multiplied(by: vector)
        )
        XCTAssertEqual(
            try matrix.transformedSparseForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector)),
            try matrix.transformedForSuperNeo().multiplied(by: SuperNeoEmbedding.packPadded(vector))
        )
        XCTAssertThrowsSuperNeoError(
            try matrix.multiplied(by: Array(vector.dropLast())),
            .invalidParameter("field matrix/vector mismatch")
        )
    }

    func testSparseMatrixCSRCanonicalizesAndRejectsNonCanonicalRows() throws {
        let matrix = try SparseFieldMatrix(
            rows: 2,
            columns: 4,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 3, value: GoldilocksField(5)),
                SparseFieldMatrix.Entry(row: 0, column: 3, value: GoldilocksField(7)),
                SparseFieldMatrix.Entry(row: 0, column: 1, value: GoldilocksField(9)),
                SparseFieldMatrix.Entry(row: 1, column: 2, value: GoldilocksField(4)),
                SparseFieldMatrix.Entry(row: 1, column: 2, value: -GoldilocksField(4)),
                SparseFieldMatrix.Entry(row: 1, column: 0, value: .zero)
            ]
        )
        let csr = try SparseMatrixCSR(matrix)

        XCTAssertEqual(csr.rowOffsets, [0, 2, 2])
        XCTAssertEqual(csr.columnIndices, [1, 3])
        XCTAssertEqual(csr.values, [GoldilocksField(9), GoldilocksField(12)])
        XCTAssertEqual(try csr.toSparseFieldMatrix().multiplied(by: [.one, .one, .one, .one]), [GoldilocksField(21), .zero])
        XCTAssertThrowsSuperNeoError(
            try SparseMatrixCSR(rowCount: 1, columnCount: 4, rowOffsets: [0, 2], columnIndices: [2, 1], values: [.one, .one]),
            .invalidParameter("CSR column indices must be strictly increasing within each row")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseMatrixCSR(rowCount: 1, columnCount: 4, rowOffsets: [0, 1], columnIndices: [0], values: [.zero]),
            .invalidParameter("CSR matrices must omit zero entries")
        )
        XCTAssertThrowsSuperNeoError(
            try SparseMatrixCSR(
                rowCount: 2,
                columnCount: 4,
                rowOffsets: [0, 2, 1],
                columnIndices: [0],
                values: [.one]
            ),
            .invalidParameter("CSR row offsets out of bounds")
        )
    }

    func testCCSShapeEncodingRoundTripsAndBindsDigest() throws {
        let identity = try SparseFieldMatrix.identity(size: 2)
        let shape = try CCSShape.hadamardProduct(matrices: [identity], publicInputCount: 2)

        let reparsed = try CCSShape(bytes: shape.superNeoBytes)

        XCTAssertEqual(reparsed, shape)
        XCTAssertEqual(reparsed.shapeDigest, shape.shapeDigest)
        XCTAssertEqual(reparsed.matrices[0], try SparseMatrixCSR(identity))
        XCTAssertTrue(reparsed.hasIdentityFirstMatrix)
    }

    func testGoldilocksParameterProfileMatchesPaperProfile() {
        let profile = SuperNeoParameterProfile.goldilocksPhi81

        XCTAssertEqual(profile.profileID, SuperNeoParameters.goldilocks.profileID)
        XCTAssertEqual(profile.parameters.kappa, 18)
        XCTAssertEqual(profile.parameters.normBound, 2)
        XCTAssertEqual(profile.parameters.normRoots, [-.one, .zero, .one])
        XCTAssertEqual(profile.normRoots, profile.parameters.normRoots)
        XCTAssertEqual(profile.parameters.decompositionLength, 14)
        XCTAssertEqual(profile.parameters.challengeCoefficients, [-2, -1, 0, 1, 2])
        XCTAssertEqual(profile.parameters.challengeExpansionFactor, 216)
        XCTAssertEqual(profile.maxFreshBatchCount, 61)
        XCTAssertEqual(profile.claimedSecurityBits, 129)
        XCTAssertEqual(profile.cyclotomicIndex, 81)
        XCTAssertEqual(profile.cyclotomicRelationCoefficients.count, CyclotomicRing54.degree + 1)
    }

    func testCCSShapeRejectsTamperedDigest() throws {
        let shape = try CCSShape.hadamardProduct(matrices: [SparseFieldMatrix.identity(size: 2)], publicInputCount: 2)
        var bytes = shape.superNeoBytes
        bytes[0] ^= 1

        XCTAssertThrowsError(try CCSShape(bytes: bytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("CCS shape digest mismatch"))
        }
    }

    func testCCSShapeReaderRejectsHugeCSRCountsBeforeAllocation() throws {
        let shape = try CCSShape.hadamardProduct(matrices: [SparseFieldMatrix.identity(size: 2)], publicInputCount: 1)
        var bytes = shape.superNeoBytes
        let firstCSRRowCountOffset = 602
        let firstCSRRowOffsetCountOffset = 618
        writeUInt64(UInt64(1 << 30), into: &bytes, at: firstCSRRowCountOffset)
        writeUInt64(UInt64(1 << 30), into: &bytes, at: firstCSRRowOffsetCountOffset)

        XCTAssertThrowsSuperNeoError(
            try CCSShape(bytes: bytes),
            .invalidEncoding("CSR row offset count exceeds remaining byte capacity")
        )
    }

    func testCCSShapeRejectsNonCanonicalRelationAndDescriptorBytes() throws {
        let monomials = [
            RelationMonomial(coefficient: .one, exponents: [1, 0]),
            RelationMonomial(coefficient: GoldilocksField(2), exponents: [0, 1]),
            RelationMonomial(coefficient: GoldilocksField(3), exponents: [1, 0])
        ]
        let polynomial = try RelationPolynomial(variableCount: 2, monomials: monomials)
        XCTAssertEqual(
            polynomial.monomials,
            [
                RelationMonomial(coefficient: GoldilocksField(2), exponents: [0, 1]),
                RelationMonomial(coefficient: GoldilocksField(4), exponents: [1, 0])
            ]
        )

        XCTAssertThrowsSuperNeoError(
            try RelationPolynomial(variableCount: 2, monomials: [RelationMonomial(coefficient: .one, exponents: [1])]),
            .invalidParameter("relation monomial exponent count must match variable count")
        )
        XCTAssertThrowsSuperNeoError(
            try StrongSamplingSetDescriptor(coefficientSet: [0, -1, 1], expansionFactor: 1),
            .invalidParameter("challenge coefficient set must be canonical")
        )
        XCTAssertThrowsSuperNeoError(
            try CyclotomicDescriptor(degree: 54, relationCoefficients: [1, 0]),
            .invalidParameter("relation polynomial must have degree + 1 coefficients")
        )
    }

    func testCCSShapeRejectsFalseIdentityDeclaration() throws {
        let matrix = try SparseFieldMatrix(
            rows: 2,
            columns: 2,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 1, value: .one),
                SparseFieldMatrix.Entry(row: 1, column: 0, value: .one)
            ]
        )

        XCTAssertThrowsError(
            try CCSShape(
                m: 2,
                nField: 2,
                nRing: 1,
                nPublicField: 2,
                matrices: [try SparseMatrixCSR(matrix)],
                relationPolynomial: try RelationPolynomial.hadamardProduct(variableCount: 1),
                hasIdentityFirstMatrix: true
            )
        ) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidParameter("first CCS matrix is not the declared identity"))
        }
    }

    func testFoldInputCarriesSerializableCustomRelationFromStructure() throws {
        let matrix = try SparseFieldMatrix.identity(size: 2)
        let relation = try RelationPolynomial(
            variableCount: 1,
            monomials: [
                RelationMonomial(coefficient: GoldilocksField(7), exponents: [1])
            ]
        )
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)

        let input = try SuperNeoFoldInput(structure: structure, instances: [], witnesses: [])

        XCTAssertEqual(input.shape.relationPolynomial, relation)
        XCTAssertEqual(input.structure.relationPolynomial, relation)
        XCTAssertEqual(
            try input.structure.evaluateRelation([GoldilocksExt2(GoldilocksField(3))]),
            GoldilocksExt2(GoldilocksField(21))
        )
    }

    func testFoldInputRejectsClosureOnlyCCSStructure() throws {
        let matrix = try SparseFieldMatrix.identity(size: 2)
        let structure = CCSStructure(matrices: [matrix]) { _ in
            GoldilocksExt2.zero
        }

        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(structure: structure, instances: [], witnesses: []),
            .invalidParameter("fold input requires a serializable CCS relation polynomial")
        )
    }

    func testCCSAndCEInstanceEncodingRoundTripsPackedPublicInputs() throws {
        let key = try AjtaiCommitmentKey(columns: 1, seed: Array("instance-key".utf8))
        let publicInput = (0..<54).map { GoldilocksField(UInt64($0 & 1)) }
        let commitment = try SuperNeoCPUBackend().commit(key: key, message: publicInput)
        let ccs = CCSInstance(commitment: commitment, publicInput: publicInput)
        let ce = CEInstance(
            commitment: commitment,
            publicInput: publicInput,
            evalPoint: [GoldilocksExt2(GoldilocksField(3), GoldilocksField(5))],
            matrixEvals: [CyclotomicRing54([GoldilocksField(7), GoldilocksField(11)])]
        )

        let reparsedCCS = try CCSInstance(bytes: ccs.superNeoBytes)
        let reparsedCE = try CEInstance(bytes: ce.superNeoBytes)

        XCTAssertEqual(reparsedCCS, ccs)
        XCTAssertEqual(reparsedCCS.publicInput, publicInput)
        XCTAssertEqual(reparsedCCS.packedPublicInput, try SuperNeoEmbedding.pack(publicInput))
        XCTAssertEqual(reparsedCE, ce)
        XCTAssertEqual(reparsedCE.packedPublicInput, try SuperNeoEmbedding.pack(publicInput))
    }

    func testPublicInputEncodingRejectsTamperedPackedForm() throws {
        let publicInput = (0..<55).map { GoldilocksField(UInt64(($0 * 7 + 1) % 31)) }
        var packed = PublicInputEncoding(field: publicInput).packed
        var badRing = packed[1]
        badRing[0] = badRing[0] + .one
        packed[1] = badRing

        XCTAssertThrowsSuperNeoError(
            try PublicInputEncoding(field: publicInput, packed: packed),
            .invalidParameter("packed public input does not match field public input")
        )
    }

    func testCCSStatementDigestChangesWithPublicInstance() throws {
        let shape = try CCSShape.hadamardProduct(matrices: [SparseFieldMatrix.identity(size: 2)], publicInputCount: 2)
        let key = try AjtaiCommitmentKey(columns: 1, seed: Array("statement-key".utf8))
        let firstInput = Array(repeating: GoldilocksField.one, count: 54)
        let secondInput = [GoldilocksField.zero] + Array(repeating: GoldilocksField.one, count: 53)
        let first = CCSInstance(
            commitment: try SuperNeoCPUBackend().commit(key: key, message: firstInput),
            publicInput: firstInput
        )
        let second = CCSInstance(
            commitment: try SuperNeoCPUBackend().commit(key: key, message: secondInput),
            publicInput: secondInput
        )

        let firstStatement = CCSStatement(shapeDigest: shape.shapeDigest, ccsInstances: [first])
        let secondStatement = CCSStatement(shapeDigest: shape.shapeDigest, ccsInstances: [second])
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: firstStatement,
            verifierKeyDigest: key.verifierKeyDigest
        )

        XCTAssertNotEqual(firstStatement.statementDigest, secondStatement.statementDigest)
        XCTAssertEqual(context.shapeDigest, shape.shapeDigest)
        XCTAssertEqual(context.statementDigest, firstStatement.statementDigest)
    }

}

final class ProtocolSmokeTests: SuperNeoTestCase {
    // MARK: - Tier 2: fold smoke checks

    func testCPUOracleFoldVerifiesWithoutMetalContext() throws {
        let fixture = try makeFoldFixture()

        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFold(input: fixture.input, proof: fold.proof, transcriptSeed: fixture.seed)
        let result = verifier.verifyFold(
            input: fixture.input,
            proof: fold.proof,
            outputClaims: fold.outputClaims,
            transcriptSeed: fixture.seed
        )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(reduction.outputClaims, fold.proof.outputClaims)
        XCTAssertEqual(result, .valid)
    }

}

final class CEOpeningProtocolTests: SuperNeoTestCase {
    // MARK: - Tier 2: CE opening proof checks

    func testLocalCEOpeningRelationBindsStatementAndWitness() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: claim
        )

        XCTAssertNil(statement.claim.witness)
        XCTAssertEqual(statement.instance, CEInstance(claim))
        XCTAssertTrue(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: witness,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let wrongProfile = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID + 1,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: claim
        )
        XCTAssertNotEqual(statement.statementDigest, wrongProfile.statementDigest)
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: wrongProfile,
            witness: witness,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        var tamperedEvaluations = claim.evaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        let tamperedStatement = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: replacing(claim, evaluations: tamperedEvaluations)
        )
        XCTAssertNotEqual(statement.statementDigest, tamperedStatement.statementDigest)
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: tamperedStatement,
            witness: witness,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let terminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let terminalWitnesses = try fold.outputClaims.map { claim in
            try XCTUnwrap(CEOpeningWitness(claim: claim))
        }
        XCTAssertEqual(terminalStatement.openings.count, fixture.key.parameters.decompositionLength)
        XCTAssertTrue(terminalStatement.openings.allSatisfy { $0.claim.witness == nil })
        XCTAssertTrue(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let shortTerminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: Array(fold.outputClaims.dropLast())
        )
        XCTAssertFalse(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: shortTerminalStatement,
            witnesses: Array(terminalWitnesses.dropLast()),
            shape: fixture.input.shape,
            key: fixture.key
        ))

        XCTAssertThrowsSuperNeoError(
            try TerminalCEStatement(
                profileID: fixture.key.parameters.profileID,
                shape: fixture.input.shape,
                key: fixture.key,
                openings: [wrongProfile] + terminalStatement.openings.dropFirst()
            ),
            .invalidParameter("terminal CE statement profile mismatch")
        )

        var badWitnessValues = witness.witness
        badWitnessValues[0] = badWitnessValues[0] + .one
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: CEOpeningWitness(badWitnessValues),
            shape: fixture.input.shape,
            key: fixture.key
        ))
        var badTerminalWitnesses = terminalWitnesses
        badTerminalWitnesses[0] = CEOpeningWitness(badWitnessValues)
        XCTAssertFalse(try CEOpeningRelation.verifyLocalBatch(
            statement: terminalStatement,
            witnesses: badTerminalWitnesses,
            shape: fixture.input.shape,
            key: fixture.key
        ))
    }

    func testCEOpeningProofVerifiesPublicStatementWithoutWitness() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [claim]
        )

        let proof = try CEOpeningRelation.proveLocalBatchForTesting(
            statement: statement,
            witnesses: [witness],
            shape: fixture.input.shape,
            key: fixture.key,
            randomSeed: Array("ce-opening-proof".utf8)
        )
        XCTAssertNil(statement.openings[0].claim.witness)
        XCTAssertTrue(try CEOpeningRelation.verify(
            proof: proof,
            statement: statement,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        let reparsed = try CEOpeningProof(bytes: proof.superNeoBytes)
        XCTAssertEqual(reparsed, proof)
        XCTAssertTrue(try CEOpeningRelation.verify(
            proof: reparsed,
            statement: statement,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        XCTAssertThrowsSuperNeoError(
            try CEOpeningProof(rounds: proof.rounds + [proof.rounds[0]]),
            .invalidParameter("CE opening proof must contain exactly \(CEOpeningProof.roundCount) Stern rounds")
        )

        var tamperedEvaluations = claim.evaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        let tamperedStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [replacing(claim, evaluations: tamperedEvaluations)]
        )
        XCTAssertFalse(try CEOpeningRelation.verify(
            proof: proof,
            statement: tamperedStatement,
            shape: fixture.input.shape,
            key: fixture.key
        ))

        var tamperedProofBytes = proof.superNeoBytes
        tamperedProofBytes[tamperedProofBytes.count - 1] ^= 1
        if let tamperedProof = try? CEOpeningProof(bytes: tamperedProofBytes) {
            XCTAssertFalse(try CEOpeningRelation.verify(
                proof: tamperedProof,
                statement: statement,
                shape: fixture.input.shape,
                key: fixture.key
            ))
        }
    }

    func testCEOpeningRejectsStaleMetalWorkspaceForShape() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: [claim]
        )
        let tamperedMatrix = try SparseFieldMatrix(
            rows: fixture.input.shape.m,
            columns: fixture.input.shape.nField,
            entries: (0..<fixture.input.shape.m).map { row in
                SparseFieldMatrix.Entry(
                    row: row,
                    column: row,
                    value: row == 0 ? GoldilocksField(2) : .one
                )
            }
        )
        let staleWorkspace = try SuperNeoMetalWorkspace(
            context: context,
            key: fixture.key,
            transformedSparseMatrices: [try tamperedMatrix.transformedSparseForSuperNeo()]
        )

        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: statement,
                witnesses: [witness],
                shape: fixture.input.shape,
                key: fixture.key,
                randomSeed: Array("ce-opening-stale-workspace".utf8),
                metalWorkspace: staleWorkspace
            ),
            .invalidParameter("CE opening Metal workspace transformed matrix digest mismatch")
        )
    }

    func testCEOpeningRejectsAjtaiKeyColumnCountThatDoesNotMatchShape() throws {
        let fixture = try makeFoldFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let claim = try XCTUnwrap(fold.outputClaims.first)
        let witness = try XCTUnwrap(CEOpeningWitness(claim: claim))
        let statement = CEOpeningStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claim: claim
        )
        let terminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let terminalWitnesses = try fold.outputClaims.map { claim in
            try XCTUnwrap(CEOpeningWitness(claim: claim))
        }
        let mismatchedKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing + 1,
            seed: Array("ce-opening-key-mismatch".utf8)
        )

        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: witness,
            shape: fixture.input.shape,
            key: mismatchedKey
        ))
        XCTAssertFalse(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.input.shape,
            key: mismatchedKey
        ))
        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: terminalStatement,
                witnesses: terminalWitnesses,
                shape: fixture.input.shape,
                key: mismatchedKey,
                randomSeed: Array("ce-opening-key-mismatch-proof".utf8)
            ),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )
        let mismatchedKeyStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: mismatchedKey,
            claims: fold.outputClaims
        )
        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: mismatchedKeyStatement,
                witnesses: terminalWitnesses,
                shape: fixture.input.shape,
                key: mismatchedKey,
                randomSeed: Array("ce-opening-key-column-mismatch-proof".utf8)
            ),
            .invalidParameter("CE opening key column count must match shape.nRing")
        )

        let sameWidthWrongKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing,
            seed: Array("ce-opening-same-width-wrong-key".utf8)
        )
        XCTAssertFalse(try CEOpeningRelation.verifyLocal(
            statement: statement,
            witness: witness,
            shape: fixture.input.shape,
            key: sameWidthWrongKey
        ))
        XCTAssertFalse(try CEOpeningRelation.verifyTerminalLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.input.shape,
            key: sameWidthWrongKey
        ))
        XCTAssertThrowsSuperNeoError(
            try CEOpeningRelation.proveLocalBatchForTesting(
                statement: terminalStatement,
                witnesses: terminalWitnesses,
                shape: fixture.input.shape,
                key: sameWidthWrongKey,
                randomSeed: Array("ce-opening-same-width-wrong-key-proof".utf8)
            ),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )
    }

}

final class ProtocolE2ETests: SuperNeoTestCase {
    // MARK: - Tier 2: end-to-end protocol and adversarial proof checks

    func testFoldRejectsPartialRingPublicInputForRModuleFolding() throws {
        let publicInput = [GoldilocksField.one]
        let privateWitness = Array(repeating: GoldilocksField.zero, count: 63)
        let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
        let structure = CCSStructure.hadamardProduct(matrices: [matrix])
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("partial-public-input".utf8))
        let commitment = try backend.commit(key: key, message: publicInput + privateWitness)

        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(
                structure: structure,
                instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
                witnesses: [CCSWitness(privateWitness)]
            ),
            .invalidParameter("public input length must contain whole ring columns for R-module folding")
        )
        let shape = try CCSShape(
            matrices: structure.matrices,
            publicInputCount: publicInput.count,
            relationPolynomial: try XCTUnwrap(structure.relationPolynomial)
        )
        let reduction = SuperNeoVerifier(key: key).reduceFold(
            publicInput: SuperNeoPublicFoldInput(
                shape: shape,
                instances: [CCSInstance(commitment: commitment, publicInput: publicInput)]
            ),
            proof: makeEmptyFoldProofForShape(shape)
        )
        XCTAssertFalse(reduction.isReductionAccepted)
        XCTAssertFalse(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(
            reduction.reason,
            "invalidParameter(\"public input length must contain whole ring columns for R-module folding\")"
        )
    }

    func testPaperLinePiCCSPiRLCAndPiDECReferenceVectors() throws {
        let fixture = try makePaperAuditFixture()
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(fixture.input, transcriptSeed: fixture.seed)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let publicInput = SuperNeoPublicFoldInput(fixture.input)

        let reduction = verifier.reduceFold(
            publicInput: publicInput,
            proof: fold.proof,
            transcriptSeed: fixture.seed
        )
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(publicInput.instances.count, 2)
        XCTAssertEqual(publicInput.priorClaims.count, 2)
        XCTAssertEqual(fold.proof.piCCSClaims.count, 4)

        let transcriptState = try assertPiCCSMatchesPaperReference(
            input: publicInput,
            proof: fold.proof,
            seed: fixture.seed
        )
        try assertPiRLCMatchesPaperReference(
            input: publicInput,
            proof: fold.proof,
            transcriptState: transcriptState
        )
        try assertPiDECMatchesPaperReference(
            folded: fold.proof.foldedClaim,
            proofOutputClaims: fold.proof.outputClaims,
            witnessOutputClaims: fold.outputClaims,
            parameters: fixture.key.parameters
        )

        XCTAssertEqual(
            verifier.verifyTerminalFold(
                publicInput: publicInput,
                proof: fold.proof,
                outputClaims: fold.outputClaims,
                transcriptSeed: fixture.seed
            ),
            .valid
        )
    }

    func testFoldRejectsAjtaiKeyColumnCountThatDoesNotMatchShape() throws {
        let fixture = try makeFoldFixture()
        let mismatchedKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing + 1,
            seed: Array("shape-key-mismatch".utf8)
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: mismatchedKey).fold(fixture.input, transcriptSeed: fixture.seed),
            .invalidParameter("prover key column count must match shape.nRing")
        )

        XCTAssertInvalid(
            SuperNeoVerifier(key: mismatchedKey).reduceFold(
                publicInput: SuperNeoPublicFoldInput(fixture.input),
                proof: makeEmptyFoldProofForShape(fixture.input.shape),
                transcriptSeed: fixture.seed
            ),
            reason: "invalidParameter(\"verifier key column count must match shape.nRing\")"
        )
    }

    func testPriorCEClaimPublicProjectionMustMatchActiveShape() throws {
        let fixture = try makePaperAuditFixture()
        var priorClaims = fixture.input.priorClaims
        let shortenedPublicInput = Array(priorClaims[0].publicInput.dropLast())
        priorClaims[0] = replacing(priorClaims[0], publicInput: shortenedPublicInput)
        let input = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: fixture.key).fold(input, transcriptSeed: fixture.seed),
            .invalidParameter("prior CE public input length must match shape.nPublicField")
        )

        XCTAssertInvalid(
            SuperNeoVerifier(key: fixture.key).reduceFold(
                publicInput: SuperNeoPublicFoldInput(input),
                proof: makeEmptyFoldProofForShape(input.shape),
                transcriptSeed: fixture.seed
            ),
            reason: "invalidParameter(\"prior CE public input length must match shape.nPublicField\")"
        )
    }

    func testProverRejectsPriorCEClaimWhenEvaluationDoesNotMatchWitness() throws {
        let fixture = try makePaperAuditFixture()
        var priorClaims = fixture.input.priorClaims
        var tamperedEvaluations = priorClaims[0].evaluations
        tamperedEvaluations[0] = tamperedEvaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        priorClaims[0] = replacing(priorClaims[0], evaluations: tamperedEvaluations)
        let input = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: fixture.key).fold(input, transcriptSeed: fixture.seed),
            .invalidParameter("prior CE claim witness does not satisfy its commitment/evaluation opening")
        )
    }

    func testProverRejectsPriorCEWitnessWhenPublicProjectionDoesNotMatchOpening() throws {
        let fixture = try makePaperAuditFixture()
        var priorClaims = fixture.input.priorClaims
        var shiftedPublicInput = priorClaims[0].publicInput
        shiftedPublicInput[0] = shiftedPublicInput[0] + .one
        priorClaims[0] = replacing(priorClaims[0], publicInput: shiftedPublicInput)
        let input = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: fixture.input.instances,
            witnesses: fixture.input.witnesses,
            priorClaims: priorClaims
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoProver(key: fixture.key).fold(input, transcriptSeed: fixture.seed),
            .invalidParameter("prior CE public input must be a prefix of its witness")
        )
    }

    func testPublicFoldVerifierDoesNotTreatReductionAsTerminalProof() throws {
        let forged = try makeForgedReductionFixture()

        let verifier = SuperNeoVerifier(key: forged.key)
        let reduction = verifier.reduceFold(
            publicInput: forged.publicInput,
            proof: forged.proof,
            transcriptSeed: forged.seed
        )
        let terminalWithForgedClaims = verifier.verifyTerminalFold(
            publicInput: forged.publicInput,
            proof: forged.proof,
            outputClaims: forged.proof.outputClaims,
            transcriptSeed: forged.seed
        )

        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertInvalid(terminalWithForgedClaims, reason: "terminal CE relation check failed")
    }

    func testVerifierRejectsTamperedPiCCSClaimBinding() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var claims = proof.piCCSClaims
        claims[0] = replacing(claims[0], commitment: claims[0].commitment + unitCommitment(parameters: fixture.key.parameters))
        let tampered = replacing(proof, piCCSClaims: claims)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertInvalid(result)
    }

    func testVerifierRejectsTamperedPiCCSEvaluation() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var claims = proof.piCCSClaims
        var evaluations = claims[0].evaluations
        evaluations[0] = evaluations[0] + CyclotomicExt2Ring54([GoldilocksExt2(.one)])
        claims[0] = replacing(claims[0], evaluations: evaluations)
        let tampered = replacing(proof, piCCSClaims: claims)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertInvalid(result)
    }

    func testVerifierRejectsTamperedFoldedClaimPublicInput() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var publicInput = proof.foldedClaim.publicInput
        publicInput[0] = publicInput[0] + .one
        let tampered = replacing(proof, foldedClaim: replacing(proof.foldedClaim, publicInput: publicInput))

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertInvalid(result, reason: "folded claim does not match random linear combination")
    }

    func testVerifierRejectsMalformedDecompositionOutput() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var outputClaims = proof.outputClaims
        var badPublicInput = outputClaims[0].publicInput
        badPublicInput[0] = GoldilocksField(UInt64(fixture.key.parameters.normBound))
        outputClaims[0] = replacing(outputClaims[0], publicInput: badPublicInput)

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(
            input: fixture.input,
            proof: replacing(proof, outputClaims: outputClaims),
            transcriptSeed: fixture.seed
        )

        XCTAssertInvalid(result, reason: "decomposition does not match folded witness")

        let missingOutput = replacing(proof, outputClaims: Array(proof.outputClaims.dropLast()))
        let missingResult = SuperNeoVerifier(key: fixture.key).reduceFold(
            input: fixture.input,
            proof: missingOutput,
            transcriptSeed: fixture.seed
        )
        XCTAssertInvalid(missingResult, reason: "decomposition output count must equal 14")
    }

    func testProofEnvelopeRoundTripsThroughVerifierTranscript() throws {
        let fixture = try makeFoldFixture()
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: fixture.input.instances
            ),
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )

        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: context.transcriptBindingBytes
        )
        let envelope = try FoldProofEnvelope(context: context, proof: fold.proof)
        let reparsed = try FoldProofEnvelope(bytes: envelope.superNeoBytes)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reduction = verifier.reduceFoldEnvelope(
            input: fixture.input,
            proofBytes: reparsed.superNeoBytes,
            context: context
        )
        let result = verifier.verifyFoldEnvelope(
            input: fixture.input,
            proofBytes: reparsed.superNeoBytes,
            context: context,
            outputClaims: fold.outputClaims
        )

        XCTAssertEqual(reparsed.header.profileID, context.profileID)
        XCTAssertEqual(reparsed.header.kind, .foldReduction)
        XCTAssertEqual(reparsed.header.shapeDigest, context.shapeDigest)
        XCTAssertEqual(reparsed.header.statementDigest, context.statementDigest)
        XCTAssertEqual(reparsed.header.verifierKeyDigest, fixture.key.verifierKeyDigest)
        XCTAssertEqual(reparsed.header.bodyLength, UInt32(reparsed.proof.superNeoBytes.count))
        XCTAssertTrue(reduction.isReductionAccepted, reduction.reason ?? "")
        XCTAssertTrue(reduction.requiresTerminalRelationCheck)
        XCTAssertEqual(result, .valid)
    }

    func testProofEnvelopeBindsVerifierKeyDigest() throws {
        let fixture = try makeFoldFixture()
        let statement = CCSStatement(
            shapeDigest: fixture.input.shape.shapeDigest,
            ccsInstances: fixture.input.instances
        )
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        let sameWidthWrongKey = try AjtaiCommitmentKey(
            columns: fixture.input.shape.nRing,
            seed: Array("fold-envelope-same-width-wrong-key".utf8)
        )
        let wrongDigestContext = ProofEnvelopeContext(
            profileID: context.profileID,
            kind: context.kind,
            shapeDigest: context.shapeDigest,
            statementDigest: context.statementDigest,
            verifierKeyDigest: sameWidthWrongKey.verifierKeyDigest,
            transcriptDomain: context.transcriptDomain
        )
        let verifier = SuperNeoVerifier(key: fixture.key)

        XCTAssertThrowsSuperNeoError(
            try fixture.backend.makeProver(key: fixture.key).foldEnvelope(
                fixture.input,
                context: wrongDigestContext
            ),
            .invalidParameter("proof envelope context verifier key digest mismatch")
        )
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: wrongDigestContext
            ),
            reason: "verifier key digest mismatch"
        )
        XCTAssertInvalid(
            SuperNeoVerifier(key: sameWidthWrongKey).reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: context
            ),
            reason: "input verifier key digest mismatch"
        )

        var mutatedHeader = proofBytes
        mutatedHeader[proofEnvelopeVerifierKeyDigestOffset] ^= 0x01
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: mutatedHeader,
                context: context
            ),
            reason: "verifier key digest mismatch"
        )
    }

    func testProofEnvelopeBodyMutationCorpusNeverVerifies() throws {
        let fixture = try makeFoldFixture()
        let context = ProofEnvelopeContext(
            profileID: 1,
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: fixture.input.instances
            ),
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: context.transcriptBindingBytes
        )
        let proofBytes = try FoldProofEnvelope(context: context, proof: fold.proof).superNeoBytes
        let bodyStart = ProofEnvelopeHeader.byteCount
        let mutationOffsets = [
            bodyStart,
            bodyStart + 8,
            bodyStart + 64,
            bodyStart + 257,
            proofBytes.count / 2,
            proofBytes.count - 9,
            proofBytes.count - 1
        ].filter { $0 >= bodyStart && $0 < proofBytes.count }

        let verifier = SuperNeoVerifier(key: fixture.key)
        for offset in mutationOffsets {
            var mutated = proofBytes
            mutated[offset] ^= 0x01
            guard (try? FoldProofEnvelope(bytes: mutated)) != nil else {
                continue
            }

            XCTAssertInvalid(verifier.verifyFoldEnvelope(
                input: fixture.input,
                proofBytes: mutated,
                context: context,
                outputClaims: fold.outputClaims
            ))
        }
    }

    func testTerminalLocalEnvelopeRoundTripsAndRequiresPublicCEProof() throws {
        let fixture = try makeFoldFixture()
        let context = ProofEnvelopeContext(
            profileID: 1,
            kind: .terminalLocal,
            statement: CCSStatement(
                shapeDigest: fixture.input.shape.shapeDigest,
                ccsInstances: fixture.input.instances
            ),
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let fold = try fixture.backend.makeProver(key: fixture.key).foldWithOutput(
            fixture.input,
            transcriptSeed: context.transcriptBindingBytes
        )
        let terminalStatement = try TerminalCEStatement(
            profileID: fixture.key.parameters.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: fold.outputClaims
        )
        let proof = TerminalFoldProof(
            foldProof: fold.proof,
            terminalStatement: terminalStatement,
            ceOpeningProof: try invalidCEOpeningProof(openingCount: terminalStatement.openings.count)
        )
        let envelope = try TerminalFoldProofEnvelope(context: context, proof: proof)
        let reparsed = try TerminalFoldProofEnvelope(bytes: envelope.superNeoBytes)
        let verifier = SuperNeoVerifier(key: fixture.key)

        XCTAssertEqual(reparsed.header.kind, .terminalLocal)
        XCTAssertEqual(reparsed.header.bodyLength, UInt32(reparsed.proof.superNeoBytes.count))
        XCTAssertTrue(reparsed.proof.outputClaims.allSatisfy { $0.witness == nil })
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: envelope.superNeoBytes),
            .invalidEncoding("fold proof envelope kind mismatch")
        )
        XCTAssertInvalid(
            verifier.verifyTerminalFoldEnvelope(
                input: fixture.input,
                proofBytes: reparsed.superNeoBytes,
                context: context
            ),
            reason: "terminal CE opening proof verification failed"
        )

        let terminalStatementOffset = ProofEnvelopeHeader.byteCount + proof.foldProof.superNeoBytes.count
        var mutatedTerminalStatementKey = envelope.superNeoBytes
        mutatedTerminalStatementKey[terminalStatementOffset + terminalCEStatementVerifierKeyDigestOffset] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try TerminalFoldProofEnvelope(bytes: mutatedTerminalStatementKey),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )

        var mutatedFirstOpeningKey = envelope.superNeoBytes
        let firstOpeningOffset = terminalStatementOffset
            + terminalCEStatementVerifierKeyDigestOffset
            + Digest256.byteCount
            + encodedCountByteWidth
        mutatedFirstOpeningKey[firstOpeningOffset + ceOpeningStatementVerifierKeyDigestOffset] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try TerminalFoldProofEnvelope(bytes: mutatedFirstOpeningKey),
            .invalidParameter("terminal CE statement verifier key mismatch")
        )
    }

    func testCompressedPublicEnvelopeRoundTripsAndBindsPublicInputs() throws {
        let fixture = try makeFoldFixture()
        let statement = CCSStatement(
            shapeDigest: fixture.input.shape.shapeDigest,
            ccsInstances: fixture.input.instances
        )
        let context = ProofEnvelopeContext(
            profileID: 1,
            kind: .compressedPublic,
            statement: statement,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let envelope = try fixture.backend.makeProver(key: fixture.key).compressedTerminalFoldEnvelopeForTesting(
            fixture.input,
            context: context,
            ceRandomSeed: Array("compressed-ce".utf8)
        )
        let reparsed = try CompressedTerminalProofEnvelope(bytes: envelope.superNeoBytes)
        let verifier = SuperNeoVerifier(key: fixture.key)
        let reconstructedTerminalStatement = try TerminalCEStatement(
            profileID: context.profileID,
            shape: fixture.input.shape,
            key: fixture.key,
            claims: reparsed.proof.foldProof.outputClaims
        )
        let reconstructedTerminalProof = TerminalFoldProof(
            foldProof: reparsed.proof.foldProof,
            terminalStatement: reconstructedTerminalStatement,
            ceOpeningProof: reparsed.proof.ceOpeningProof
        )

        XCTAssertEqual(reparsed.header.kind, .compressedPublic)
        XCTAssertEqual(reparsed.header.bodyLength, UInt32(reparsed.proof.superNeoBytes.count))
        XCTAssertLessThan(reparsed.proof.superNeoBytes.count, reconstructedTerminalProof.superNeoBytes.count)
        XCTAssertEqual(reparsed.proof.statement.terminalStatementDigest, reconstructedTerminalStatement.statementDigest)
        XCTAssertEqual(reparsed.proof.foldProofDigest, Digest256.hash(reparsed.proof.foldProof.superNeoBytes))
        XCTAssertEqual(reparsed.proof.ceOpeningProofDigest, Digest256.hash(reparsed.proof.ceOpeningProof.superNeoBytes))
        XCTAssertEqual(
            verifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: SuperNeoPublicFoldInput(fixture.input),
                proofBytes: reparsed.superNeoBytes,
                context: context
            ),
            .valid
        )

        var tamperedInput = fixture.input
        var tamperedInstancePublic = tamperedInput.instances[0].publicInput
        tamperedInstancePublic[0] = tamperedInstancePublic[0] + .one
        tamperedInput = SuperNeoFoldInput(
            shape: fixture.input.shape,
            instances: [CCSInstance(commitment: fixture.input.instances[0].commitment, publicInput: tamperedInstancePublic)],
            witnesses: fixture.input.witnesses,
            priorClaims: fixture.input.priorClaims
        )
        XCTAssertInvalid(
            verifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: SuperNeoPublicFoldInput(tamperedInput),
                proofBytes: reparsed.superNeoBytes,
                context: context
            ),
            reason: "input statement digest mismatch"
        )

        var mutatedHeaderKey = envelope.superNeoBytes
        mutatedHeaderKey[proofEnvelopeVerifierKeyDigestOffset] ^= 0x01
        XCTAssertInvalid(
            verifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: SuperNeoPublicFoldInput(fixture.input),
                proofBytes: mutatedHeaderKey,
                context: context
            ),
            reason: "verifier key digest mismatch"
        )

        var mutatedFoldProofDigest = envelope.superNeoBytes
        mutatedFoldProofDigest[ProofEnvelopeHeader.byteCount + reparsed.proof.statement.superNeoBytes.count] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try CompressedTerminalProofEnvelope(bytes: mutatedFoldProofDigest),
            .invalidEncoding("compressed fold proof digest mismatch")
        )

        var mutatedCompressedContextKey = envelope.superNeoBytes
        mutatedCompressedContextKey[
            ProofEnvelopeHeader.byteCount + compressedStatementContextVerifierKeyDigestOffset
        ] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try CompressedTerminalProofEnvelope(bytes: mutatedCompressedContextKey),
            .invalidEncoding("compressed terminal proof transcript mismatch")
        )

        var mutatedCompressedRelationKey = envelope.superNeoBytes
        mutatedCompressedRelationKey[
            ProofEnvelopeHeader.byteCount + compressedStatementVerifierKeyDigestOffset
        ] ^= 0x01
        XCTAssertThrowsSuperNeoError(
            try CompressedTerminalProofEnvelope(bytes: mutatedCompressedRelationKey),
            .invalidEncoding("compressed terminal proof transcript mismatch")
        )
    }

    func testCCSNormalizerPadsGeneralShapeIntoPaperNormalizedInput() throws {
        let publicInput = [GoldilocksField.one]
        let witness = [GoldilocksField.zero, GoldilocksField.one]
        let matrix = try SparseFieldMatrix(
            rows: 3,
            columns: 3,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 0, value: .one),
                SparseFieldMatrix.Entry(row: 1, column: 1, value: .one),
                SparseFieldMatrix.Entry(row: 2, column: 2, value: .one)
            ]
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)
        let originalCommitment = AjtaiCommitment(Array(repeating: .zero, count: SuperNeoParameters.goldilocks.kappa))
        let result = try SuperNeoCCSNormalizer.normalize(
            structure: structure,
            instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
            witnesses: [CCSWitness(witness)],
            keySeed: Array("normalized-key".utf8)
        )

        XCTAssertEqual(result.normalized.shape.m, 64)
        XCTAssertEqual(result.normalized.shape.nField, 64)
        XCTAssertEqual(result.normalized.shape.nPublicField, 54)
        XCTAssertTrue(result.normalized.shape.hasIdentityFirstMatrix)
        XCTAssertEqual(result.normalized.mapping.originalRowCount, 3)
        XCTAssertEqual(result.normalized.mapping.addedPublicInputs, 53)
        XCTAssertTrue(result.normalized.mapping.addedIdentityMatrix)
        XCTAssertEqual(try result.normalized.mapping.normalizedMatrixIndex(forOriginalMatrix: 0), 1)
        XCTAssertEqual(result.normalized.instances[0].publicInput.count, 54)
        XCTAssertEqual(result.normalized.witnesses[0].values.count, 10)
        XCTAssertFalse(SuperNeoFoldingShapeContract.paperNormalized.requiresNormalization(result.normalized.shape))
        XCTAssertNoThrow(try SuperNeoFoldingShapeContract.paperNormalized.validate(result.normalized.shape))

        let normalizedPublic = try result.normalized.mapping.embedPublicInput(publicInput)
        let normalizedPrivate = try result.normalized.mapping.embedPrivateWitness(witness)
        let normalizedWitness = try result.normalized.mapping.embedFullWitness(
            publicInput: publicInput,
            privateWitness: witness
        )
        XCTAssertEqual(result.normalized.instances[0].publicInput, normalizedPublic)
        XCTAssertEqual(result.normalized.witnesses[0].values, normalizedPrivate)
        XCTAssertEqual(try result.normalized.mapping.projectPublicInput(normalizedPublic), publicInput)
        XCTAssertEqual(try result.normalized.mapping.projectPrivateWitness(normalizedPrivate), witness)
        XCTAssertEqual(try result.normalized.mapping.projectFullWitness(normalizedWitness), publicInput + witness)

        let originalRows = try matrix.multiplied(by: publicInput + witness)
        let normalizedMatrixRows = try result.normalized.shape.structure.matrices[1].multiplied(by: normalizedWitness)
        let normalizedIdentityRows = try result.normalized.shape.structure.matrices[0].multiplied(by: normalizedWitness)
        XCTAssertEqual(Array(normalizedMatrixRows.prefix(originalRows.count)), originalRows)
        XCTAssertTrue(normalizedMatrixRows.dropFirst(originalRows.count).allSatisfy { $0 == .zero })
        XCTAssertEqual(normalizedIdentityRows, normalizedWitness)

        XCTAssertNoThrow(try SuperNeoVerifier(key: result.key).reduceFold(input: result.normalized.foldInput, proof: SuperNeoProver(key: result.key).fold(result.normalized.foldInput)))
    }

    func testDirectFoldInputRequiresPaperNormalizedShapeContract() throws {
        let matrix = try SparseFieldMatrix(
            rows: 4,
            columns: 5,
            entries: (0..<4).map {
                SparseFieldMatrix.Entry(row: $0, column: $0, value: .one)
            }
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)

        let shape = try CCSShape(
            matrices: [matrix],
            publicInputCount: 0,
            relationPolynomial: relation
        )
        XCTAssertTrue(SuperNeoFoldingShapeContract.paperNormalized.requiresNormalization(shape))
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldingShapeContract.paperNormalized.validate(shape),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: shape.nField must equal shape.m; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
        XCTAssertThrowsSuperNeoError(
            try SuperNeoFoldInput(structure: structure, instances: [], witnesses: []),
            .invalidParameter(
                "SuperNeo folding requires a paper-normalized CCS shape: shape.nField must equal shape.m; use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
            )
        )
    }

    func testCCSNormalizerRejectsPriorClaimsBeforeChangingShapeAndKey() throws {
        let publicInput = [GoldilocksField.one]
        let witness = [GoldilocksField.zero, GoldilocksField.one]
        let matrix = try SparseFieldMatrix(
            rows: 3,
            columns: 3,
            entries: [
                SparseFieldMatrix.Entry(row: 0, column: 0, value: .one),
                SparseFieldMatrix.Entry(row: 1, column: 1, value: .one),
                SparseFieldMatrix.Entry(row: 2, column: 2, value: .one)
            ]
        )
        let relation = try RelationPolynomial(variableCount: 1, monomials: [])
        let structure = CCSStructure(matrices: [matrix], relationPolynomial: relation)
        let originalCommitment = AjtaiCommitment(Array(repeating: .zero, count: SuperNeoParameters.goldilocks.kappa))
        let priorClaim = CCSEvaluationClaim(
            commitment: originalCommitment,
            publicInput: publicInput,
            point: [GoldilocksExt2.zero, GoldilocksExt2.zero],
            evaluations: [CyclotomicExt2Ring54.zero],
            witness: publicInput + witness
        )

        XCTAssertThrowsSuperNeoError(
            try SuperNeoCCSNormalizer.normalize(
                structure: structure,
                instances: [CCSInstance(commitment: originalCommitment, publicInput: publicInput)],
                witnesses: [CCSWitness(witness)],
                priorClaims: [priorClaim],
                keySeed: Array("normalized-key-with-prior".utf8)
            ),
            .invalidParameter("normalization requires empty prior CE claims; normalize before producing prior claims")
        )
    }

    func testProofEnvelopeRejectsProfileMismatchBeforeTranscriptVerification() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        let wrongContext = makeEnvelopeContext(
            for: fixture.input,
            profileID: 8,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )

        let result = SuperNeoVerifier(key: fixture.key).reduceFoldEnvelope(
            input: fixture.input,
            proofBytes: proofBytes,
            context: wrongContext
        )

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "profile mismatch")
    }

    func testProofEnvelopeRejectsTrailingBytes() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        proofBytes.append(0)

        XCTAssertThrowsError(try FoldProofEnvelope(bytes: proofBytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("trailing proof bytes"))
        }
    }

    func testProofEnvelopeRejectsHeaderTamperingAndLengthMismatch() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        var wrongMagic = proofBytes
        wrongMagic[0] ^= 1
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: wrongMagic),
            .invalidEncoding("wrong proof magic")
        )

        var wrongVersion = proofBytes
        wrongVersion[4] = 0
        wrongVersion[5] = 0
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: wrongVersion),
            .invalidEncoding("unsupported proof version")
        )

        var tooLongBody = proofBytes
        writeUInt32(UInt32(proofBytes.count - ProofEnvelopeHeader.byteCount + 1), into: &tooLongBody, at: ProofEnvelopeHeader.byteCount - 4)
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: tooLongBody),
            .invalidEncoding("unexpected end of proof bytes")
        )
    }

    func testProofEnvelopeRejectsKindMismatch() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        proofBytes[8] = ProofEnvelopeKind.terminalLocal.rawValue
        XCTAssertThrowsSuperNeoError(
            try FoldProofEnvelope(bytes: proofBytes),
            .invalidEncoding("fold proof envelope kind mismatch")
        )

        let wrongContext = makeEnvelopeContext(
            for: fixture.input,
            kind: .terminalLocal,
            verifierKeyDigest: fixture.key.verifierKeyDigest
        )
        let result = SuperNeoVerifier(key: fixture.key).reduceFoldEnvelope(
            input: fixture.input,
            proofBytes: try fixture.backend.makeProver(key: fixture.key).foldEnvelope(fixture.input, context: context).superNeoBytes,
            context: wrongContext
        )
        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "proof kind mismatch")
    }

    func testProofEnvelopeRejectsShapeStatementAndTranscriptDomainMismatch() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        let proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes
        let verifier = SuperNeoVerifier(key: fixture.key)

        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    shapeDigest: .hash("wrong-shape"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            reason: "shape digest mismatch"
        )
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    statementDigest: .hash("wrong-statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            reason: "statement digest mismatch"
        )
        XCTAssertInvalid(
            verifier.reduceFoldEnvelope(
                input: fixture.input,
                proofBytes: proofBytes,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    verifierKeyDigest: fixture.key.verifierKeyDigest,
                    transcriptDomain: .hash("wrong-domain")
                )
            ),
            reason: "transcript domain mismatch"
        )
    }

    func testProverEnvelopeRejectsMismatchedContextBinding() throws {
        let fixture = try makeFoldFixture()
        let prover = fixture.backend.makeProver(key: fixture.key)
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)

        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    profileID: context.profileID + 1,
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context profile mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    kind: .terminalLocal,
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context kind mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    shapeDigest: .hash("prover-wrong-shape"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context shape digest mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.foldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    statementDigest: .hash("prover-wrong-statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context statement digest mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.terminalFoldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    kind: .terminalLocal,
                    statementDigest: .hash("terminal-wrong-statement"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context statement digest mismatch")
        )
        XCTAssertThrowsSuperNeoError(
            try prover.compressedTerminalFoldEnvelope(
                fixture.input,
                context: makeEnvelopeContext(
                    for: fixture.input,
                    kind: .compressedPublic,
                    shapeDigest: .hash("compressed-wrong-shape"),
                    verifierKeyDigest: fixture.key.verifierKeyDigest
                )
            ),
            .invalidParameter("proof envelope context shape digest mismatch")
        )
    }

    func testProofEnvelopeRejectsNonCanonicalFieldEncoding() throws {
        let fixture = try makeFoldFixture()
        let context = makeEnvelopeContext(for: fixture.input, verifierKeyDigest: fixture.key.verifierKeyDigest)
        var proofBytes = try fixture.backend.makeProver(key: fixture.key)
            .foldEnvelope(fixture.input, context: context)
            .superNeoBytes

        let firstFieldOffset = ProofEnvelopeHeader.byteCount
        let nonCanonical = withUnsafeBytes(of: GoldilocksField.modulus.littleEndian, Array.init)
        proofBytes.replaceSubrange(firstFieldOffset..<firstFieldOffset + 8, with: nonCanonical)

        XCTAssertThrowsError(try FoldProofEnvelope(bytes: proofBytes)) { error in
            XCTAssertEqual(error as? SuperNeoError, .invalidEncoding("non-canonical Goldilocks element"))
        }
    }

    func testVerifierRejectsTamperedRLCChallenge() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var challenges = proof.randomLinearCombinationChallenges
        challenges[0] = challenges[0] + .one
        let tampered = FoldProof(
            sumCheck: proof.sumCheck,
            randomLinearCombinationChallenges: challenges,
            piCCSClaims: proof.piCCSClaims,
            foldedClaim: proof.foldedClaim,
            decomposition: proof.decomposition,
            outputClaims: proof.outputClaims
        )

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "random-linear-combination challenge mismatch")
    }

    func testVerifierRejectsTamperedDecompositionCommitment() throws {
        let fixture = try makeFoldFixture()
        let proof = try fixture.backend.makeProver(key: fixture.key).fold(fixture.input, transcriptSeed: fixture.seed)
        var outputClaims = proof.outputClaims
        let brokenCommitment = outputClaims[0].commitment
            + AjtaiCommitment(Array(repeating: CyclotomicRing54.one, count: fixture.key.parameters.kappa))
        outputClaims[0] = CCSEvaluationClaim(
            commitment: brokenCommitment,
            publicInput: outputClaims[0].publicInput,
            point: outputClaims[0].point,
            evaluations: outputClaims[0].evaluations,
            witness: outputClaims[0].witness
        )
        let tampered = FoldProof(
            sumCheck: proof.sumCheck,
            randomLinearCombinationChallenges: proof.randomLinearCombinationChallenges,
            piCCSClaims: proof.piCCSClaims,
            foldedClaim: proof.foldedClaim,
            decomposition: proof.decomposition,
            outputClaims: outputClaims
        )

        let result = SuperNeoVerifier(key: fixture.key).reduceFold(input: fixture.input, proof: tampered, transcriptSeed: fixture.seed)

        XCTAssertFalse(result.isReductionAccepted)
        XCTAssertFalse(result.requiresTerminalRelationCheck)
        XCTAssertEqual(result.reason, "decomposition commitments must match output claims")
    }

}

final class MetalDifferentialTests: SuperNeoTestCase {
    // MARK: - Tier 0: Metal differential kernels

    func testTier0MetalSeededDifferentialCorpusMatchesCPUOracle() throws {
        let device = try requireMetalDevice()
        let context = try MetalExecutionContext(device: device)
        let backend = SuperNeoMetalBackend(context: context)
        var generator = SeededTestGenerator(seed: 0x4D45_5441_4C44_4946)
        var lhs = (0..<128).map { _ in generator.field() }
        var rhs = (0..<128).map { _ in generator.field() }
        lhs.replaceSubrange(0..<6, with: [
            .zero,
            .one,
            GoldilocksField(1 << 32),
            GoldilocksField((1 << 32) - 1),
            GoldilocksField(GoldilocksField.modulus - 1),
            GoldilocksField(UInt64.max)
        ])
        rhs.replaceSubrange(0..<6, with: [
            .one,
            GoldilocksField(GoldilocksField.modulus - 1),
            GoldilocksField(7),
            GoldilocksField(GoldilocksField.modulus - 2),
            GoldilocksField(11),
            GoldilocksField(1 << 32)
        ])

        XCTAssertEqual(try backend.add(lhs, rhs), zip(lhs, rhs).map(+))
        XCTAssertEqual(try backend.subtract(lhs, rhs), zip(lhs, rhs).map(-))
        XCTAssertEqual(try backend.multiply(lhs, rhs), zip(lhs, rhs).map(*))

        let multiplicationBoundaries = [
            GoldilocksField.zero,
            .one,
            GoldilocksField(2),
            GoldilocksField(1 << 32),
            GoldilocksField((1 << 32) - 1),
            GoldilocksField((1 << 32) + 1),
            GoldilocksField(GoldilocksField.modulus - 3),
            GoldilocksField(GoldilocksField.modulus - 2),
            GoldilocksField(GoldilocksField.modulus - 1)
        ]
        var boundaryLhs: [GoldilocksField] = []
        var boundaryRhs: [GoldilocksField] = []
        for lhs in multiplicationBoundaries {
            for rhs in multiplicationBoundaries {
                boundaryLhs.append(lhs)
                boundaryRhs.append(rhs)
            }
        }
        XCTAssertEqual(try backend.multiply(boundaryLhs, boundaryRhs), zip(boundaryLhs, boundaryRhs).map(*))

        let rings = (0..<8).map { _ in generator.ring() }
        let otherRings = (0..<8).map { _ in generator.ring() }
        let scalars = (0..<8).map { _ in generator.field() }
        XCTAssertEqual(try backend.add(rings, otherRings), zip(rings, otherRings).map(+))
        XCTAssertEqual(try backend.multiply(rings, by: scalars), zip(rings, scalars).map { $0.scaled(by: $1) })
        XCTAssertEqual(try backend.multiply(rings, otherRings), zip(rings, otherRings).map(*))

        func sparseRing(_ entries: [(Int, GoldilocksField)]) -> CyclotomicRing54 {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            for (index, value) in entries {
                coefficients[index] = value
            }
            return CyclotomicRing54(coefficients)
        }

        let smallScalars: [GoldilocksField] = [
            .zero,
            .one,
            GoldilocksField(2),
            -GoldilocksField.one,
            -GoldilocksField(2),
            GoldilocksField(3),
            GoldilocksField(5),
            -GoldilocksField(7)
        ]
        XCTAssertEqual(
            try backend.multiply(rings, by: smallScalars),
            zip(rings, smallScalars).map { $0.scaled(by: $1) }
        )

        let sparseSmallRings = [
            sparseRing([(0, .one), (53, -GoldilocksField(2))]),
            sparseRing([(3, GoldilocksField(2)), (41, -GoldilocksField.one)])
        ]
        let sparseSmallOtherRings = [
            sparseRing([(1, .one), (28, GoldilocksField(2))]),
            sparseRing([(0, -GoldilocksField.one), (52, -GoldilocksField(2))])
        ]
        XCTAssertEqual(
            try backend.multiply(sparseSmallRings, sparseSmallOtherRings),
            zip(sparseSmallRings, sparseSmallOtherRings).map(*)
        )

        let key = try AjtaiCommitmentKey(columns: 3, seed: Array("metal-ajtai-seeded".utf8))
        let message = (0..<3).map { _ in generator.ring() }
        XCTAssertEqual(
            try backend.ajtaiCommitment(key: key, message: message),
            try AjtaiCommitter.commitReference(key: key, message: message)
        )
        let smallMessage = [
            sparseRing([(0, .one), (13, GoldilocksField(2)), (53, -GoldilocksField.one)]),
            sparseRing([(1, -GoldilocksField(2)), (27, .one)]),
            sparseRing([(5, .one), (40, GoldilocksField(2))])
        ]
        let smallProfile = try AjtaiCommitter.workProfile(key: key, message: smallMessage)
        XCTAssertTrue(smallProfile.usesOnlySmallCoefficientScalings)
        XCTAssertLessThan(smallProfile.activeRotationTerms, key.matrix.rows * key.matrix.columns * CyclotomicRing54.degree)
        let smallReference = try AjtaiCommitter.commitReference(key: key, message: smallMessage)
        XCTAssertEqual(try backend.ajtaiCommitment(key: key, message: smallMessage), smallReference)
        let smallTiledSchedule = try AjtaiMatvecSchedule(
            columnTileSize: 2,
            rowTileSize: 2,
            maxBatchSize: 2,
            kernel: .tiled
        )
        XCTAssertEqual(
            try backend.ajtaiCommitments(
                key: key,
                messages: [smallMessage, smallMessage],
                schedule: smallTiledSchedule
            ),
            [smallReference, smallReference]
        )

        let matrix = try RingMatrix(
            rows: 4,
            columns: 3,
            elements: (0..<12).map { _ in generator.ring() }
        )
        let sparseMatrix = try SparseRingMatrixCSR(matrix)
        let vector = (0..<3).map { _ in generator.ring() }
        let rows = try matrix.multiplied(by: vector)
        let sparseRows = try sparseMatrix.multiplied(by: vector)
        let point = [generator.ext2(), generator.ext2()]
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)

        XCTAssertEqual(sparseRows, rows)
        XCTAssertEqual(try backend.transformedMatrixVector(matrix: matrix, vector: vector), rows)
        XCTAssertEqual(try backend.transformedMatrixVector(matrix: sparseMatrix, vector: vector), rows)
        XCTAssertEqual(try backend.transformedEvaluation(rows: rows, rHat: rHat), directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(try backend.transformedEvaluation(matrix: matrix, vector: vector, point: point), directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(try backend.transformedEvaluation(matrix: sparseMatrix, vector: vector, point: point), directTransformedEvaluation(rows: rows, rHat: rHat))

        let secondVector = (0..<3).map { _ in generator.ring() }
        let secondRows = try sparseMatrix.multiplied(by: secondVector)
        let batchedEvaluations = try backend.transformedEvaluations(
            matrices: [sparseMatrix, sparseMatrix],
            vectors: [vector, secondVector],
            point: point
        )
        XCTAssertEqual(batchedEvaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(batchedEvaluations[0][1].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(batchedEvaluations[1][0].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))
        XCTAssertEqual(batchedEvaluations[1][1].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))

        let workspace = try SuperNeoMetalWorkspace(
            context: context,
            key: key,
            transformedSparseMatrices: [sparseMatrix]
        )
        XCTAssertEqual(
            try workspace.ajtaiCommitments(messages: [message, message]),
            [
                try AjtaiCommitter.commitReference(key: key, message: message),
                try AjtaiCommitter.commitReference(key: key, message: message)
            ]
        )
        let tiledSchedule = try AjtaiMatvecSchedule(columnTileSize: 1, rowTileSize: 2, maxBatchSize: 1, kernel: .tiled)
        XCTAssertEqual(
            try workspace.ajtaiCommitments(messages: [message, message], schedule: tiledSchedule),
            [
                try AjtaiCommitter.commitReference(key: key, message: message),
                try AjtaiCommitter.commitReference(key: key, message: message)
            ]
        )
        let workspaceEvaluations = try workspace.transformedEvaluations(
            vectors: [vector, secondVector],
            point: point
        )
        XCTAssertEqual(workspaceEvaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(workspaceEvaluations[1][0].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))
        let combinedWorkspaceResults = try workspace.commitmentsAndTransformedEvaluations(
            messages: [vector, secondVector],
            point: point
        )
        XCTAssertEqual(combinedWorkspaceResults.commitments, [
            try AjtaiCommitter.commitReference(key: key, message: vector),
            try AjtaiCommitter.commitReference(key: key, message: secondVector)
        ])
        XCTAssertEqual(combinedWorkspaceResults.evaluations[0][0].coefficients, directTransformedEvaluation(rows: rows, rHat: rHat))
        XCTAssertEqual(combinedWorkspaceResults.evaluations[1][0].coefficients, directTransformedEvaluation(rows: secondRows, rHat: rHat))

        let blockedRows = 1024
        let blockedColumns = 3
        func blockedRing(row: Int, bias: Int) -> CyclotomicRing54 {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            coefficients[(row + bias) % CyclotomicRing54.degree] = GoldilocksField(UInt64((row % 251) + 1))
            coefficients[(row * 7 + bias + 11) % CyclotomicRing54.degree] = GoldilocksField(UInt64((row % 127) + 2))
            return CyclotomicRing54(coefficients)
        }

        func blockedSparseMatrix(bias: Int, extraEntryStride: Int) throws -> SparseRingMatrixCSR {
            var rowOffsets = [0]
            var columnIndices: [Int] = []
            var values: [CyclotomicRing54] = []
            for row in 0..<blockedRows {
                var entries = [((row + bias) % blockedColumns, blockedRing(row: row, bias: bias))]
                if row % extraEntryStride == 0 {
                    entries.append(((row + bias + 1) % blockedColumns, blockedRing(row: row, bias: bias + 19)))
                }
                for (column, value) in entries.sorted(by: { $0.0 < $1.0 }) {
                    columnIndices.append(column)
                    values.append(value)
                }
                rowOffsets.append(columnIndices.count)
            }
            return try SparseRingMatrixCSR(
                rows: blockedRows,
                columns: blockedColumns,
                rowOffsets: rowOffsets,
                columnIndices: columnIndices,
                values: values
            )
        }

        let blockedMatrices = [
            try blockedSparseMatrix(bias: 1, extraEntryStride: 5),
            try blockedSparseMatrix(bias: 2, extraEntryStride: 7)
        ]
        let blockedPoint = (0..<10).map { index -> GoldilocksExt2 in
            let c0 = GoldilocksField(UInt64(index + 2))
            let c1 = GoldilocksField(UInt64(index * 3 + 5))
            return GoldilocksExt2(c0, c1)
        }
        let blockedRHat = try MultilinearEvaluation.checkedBasis(at: blockedPoint)
        let blockedVectors = [vector, secondVector]
        let blockedWorkspace = try SuperNeoMetalWorkspace(
            context: context,
            key: key,
            transformedSparseMatrices: blockedMatrices
        )
        let blockedEvaluations = try blockedWorkspace.transformedEvaluations(
            vectors: blockedVectors,
            point: blockedPoint
        )
        let blockedCombined = try blockedWorkspace.commitmentsAndTransformedEvaluations(
            messages: blockedVectors,
            point: blockedPoint
        )
        XCTAssertEqual(blockedCombined.commitments, try blockedVectors.map {
            try AjtaiCommitter.commitReference(key: key, message: $0)
        })
        for vectorIndex in blockedVectors.indices {
            for matrixIndex in blockedMatrices.indices {
                let blockedMatrixRows = try blockedMatrices[matrixIndex].multiplied(by: blockedVectors[vectorIndex])
                XCTAssertEqual(
                    blockedEvaluations[vectorIndex][matrixIndex].coefficients,
                    directTransformedEvaluation(rows: blockedMatrixRows, rHat: blockedRHat)
                )
                XCTAssertEqual(
                    blockedCombined.evaluations[vectorIndex][matrixIndex].coefficients,
                    directTransformedEvaluation(rows: blockedMatrixRows, rHat: blockedRHat)
                )
            }
        }
    }

}

struct SeededTestGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 0x9E37_79B9_7F4A_7C15 &+ 0xD1B5_4A32_D192_ED03
        var value = state
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return value
    }

    mutating func field() -> GoldilocksField {
        GoldilocksField(next())
    }

    mutating func ext2() -> GoldilocksExt2 {
        GoldilocksExt2(field(), field())
    }

    mutating func ring() -> CyclotomicRing54 {
        CyclotomicRing54((0..<CyclotomicRing54.degree).map { _ in field() })
    }
}

extension SuperNeoTestCase {

    func directMultilinearEvaluation(_ vector: [GoldilocksField], at point: [GoldilocksExt2]) -> GoldilocksExt2 {
        var accumulator = GoldilocksExt2.zero
        for (index, value) in vector.enumerated() {
            var weight = GoldilocksExt2.one
            for dimension in point.indices {
                weight = weight * (((index >> dimension) & 1) == 0 ? (.one - point[dimension]) : point[dimension])
            }
            accumulator = accumulator + GoldilocksExt2(value) * weight
        }
        return accumulator
    }

    func directTransformedEvaluation(rows: [CyclotomicRing54], rHat: [GoldilocksExt2]) -> [GoldilocksExt2] {
        var output = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for (row, weight) in zip(rows, rHat) {
            for coefficient in 0..<CyclotomicRing54.degree {
                output[coefficient] = output[coefficient] + GoldilocksExt2(row[coefficient]) * weight
            }
        }
        return output
    }

    func monomialRing(_ exponent: Int) -> CyclotomicRing54 {
        var coefficients = Array(repeating: GoldilocksField.zero, count: exponent + 1)
        coefficients[exponent] = .one
        return CyclotomicRing54(coefficients)
    }

    func XCTAssertThrowsSuperNeoError<T>(
        _ expression: @autoclosure () throws -> T,
        _ expected: SuperNeoError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(error as? SuperNeoError, expected, file: file, line: line)
        }
    }

    func XCTAssertInvalid(
        _ result: VerificationResult,
        reason: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(result.isValid, file: file, line: line)
        if let reason {
            XCTAssertEqual(result.reason, reason, file: file, line: line)
        }
    }

    func XCTAssertInvalid(
        _ result: FoldReductionResult,
        reason: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(result.isReductionAccepted, file: file, line: line)
        XCTAssertFalse(result.requiresTerminalRelationCheck, file: file, line: line)
        if let reason {
            XCTAssertEqual(result.reason, reason, file: file, line: line)
        }
    }

    func unitCommitment(parameters: SuperNeoParameters) -> AjtaiCommitment {
        AjtaiCommitment([CyclotomicRing54.one] + Array(repeating: .zero, count: parameters.kappa - 1))
    }

    func invalidCEOpeningProof(openingCount: Int) throws -> CEOpeningProof {
        let zeroDigest = try Digest256(Array(repeating: 0, count: Digest256.byteCount))
        let commitments = Array(
            repeating: CEOpeningProofCommitments(
                maskLinearDigest: zeroDigest,
                permutedMaskDigest: zeroDigest,
                permutedMaskedWitnessDigest: zeroDigest
            ),
            count: openingCount
        )
        let responses = Array(
            repeating: CEOpeningNormResponse(permutedMask: [], permutedWitness: []),
            count: openingCount
        )
        let round = CEOpeningProofRound(
            commitments: commitments,
            response: .permutedWitness(responses)
        )
        return try CEOpeningProof(
            rounds: Array(repeating: round, count: CEOpeningProof.roundCount)
        )
    }

    func replacing(
        _ proof: FoldProof,
        sumCheck: SumcheckProof? = nil,
        randomLinearCombinationChallenges: [CyclotomicRing54]? = nil,
        piCCSClaims: [CCSEvaluationClaim]? = nil,
        foldedClaim: CCSEvaluationClaim? = nil,
        decomposition: DecompositionProof? = nil,
        outputClaims: [CCSEvaluationClaim]? = nil
    ) -> FoldProof {
        FoldProof(
            sumCheck: sumCheck ?? proof.sumCheck,
            randomLinearCombinationChallenges: randomLinearCombinationChallenges ?? proof.randomLinearCombinationChallenges,
            piCCSClaims: piCCSClaims ?? proof.piCCSClaims,
            foldedClaim: foldedClaim ?? proof.foldedClaim,
            decomposition: decomposition ?? proof.decomposition,
            outputClaims: outputClaims ?? proof.outputClaims
        )
    }

    func replacing(
        _ claim: CCSEvaluationClaim,
        commitment: AjtaiCommitment? = nil,
        publicInput: [GoldilocksField]? = nil,
        point: [GoldilocksExt2]? = nil,
        evaluations: [CyclotomicExt2Ring54]? = nil
    ) -> CCSEvaluationClaim {
        CCSEvaluationClaim(
            commitment: commitment ?? claim.commitment,
            publicInput: publicInput ?? claim.publicInput,
            point: point ?? claim.point,
            evaluations: evaluations ?? claim.evaluations,
            witness: claim.witness
        )
    }

    func writeUInt32(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
        bytes.replaceSubrange(offset..<offset + 4, with: withUnsafeBytes(of: value.littleEndian, Array.init))
    }

    func writeUInt64(_ value: UInt64, into bytes: inout [UInt8], at offset: Int) {
        bytes.replaceSubrange(offset..<offset + 8, with: withUnsafeBytes(of: value.littleEndian, Array.init))
    }

    func makeEmptyFoldProofForShape(_ shape: CCSShape) -> FoldProof {
        let point = Array(repeating: GoldilocksExt2.zero, count: shape.m.trailingZeroBitCount)
        let emptyClaim = CCSEvaluationClaim(
            commitment: AjtaiCommitment([]),
            publicInput: [],
            point: point,
            evaluations: [CyclotomicExt2Ring54](),
            witness: nil as [GoldilocksField]?
        )
        return FoldProof(
            sumCheck: SumcheckProof(
                claimedSum: .zero,
                rounds: [],
                finalPoint: point,
                finalValue: .zero
            ),
            randomLinearCombinationChallenges: [],
            piCCSClaims: [],
            foldedClaim: emptyClaim,
            decomposition: DecompositionProof(commitments: [], evaluations: []),
            outputClaims: []
        )
    }

    struct PaperReferenceTranscriptState {
        let alpha: [GoldilocksExt2]
        let gamma: GoldilocksExt2
        let transcriptAfterSumcheck: SumCheckTranscript
    }

    func makePaperAuditFixture() throws -> (
        backend: SuperNeoCPUBackend,
        key: AjtaiCommitmentKey,
        input: SuperNeoFoldInput,
        seed: [UInt8]
    ) {
        let bootstrap = try makePaperAuditInput(priorClaims: [])
        let bootstrapFold = try bootstrap.backend.makeProver(key: bootstrap.key).foldWithOutput(
            bootstrap.input,
            transcriptSeed: Array("paper-audit-prior".utf8)
        )
        let priorClaims = Array(bootstrapFold.outputClaims.prefix(2))
        let input = try makePaperAuditInput(priorClaims: priorClaims)
        return (
            input.backend,
            input.key,
            input.input,
            Array("paper-audit-fold".utf8)
        )
    }

    func makePaperAuditInput(
        priorClaims: [CCSEvaluationClaim]
    ) throws -> (
        backend: SuperNeoCPUBackend,
        key: AjtaiCommitmentKey,
        input: SuperNeoFoldInput
    ) {
        let identity = try SparseFieldMatrix.identity(size: 64)
        let relation = try RelationPolynomial(
            variableCount: 2,
            monomials: [
                RelationMonomial(coefficient: .one, exponents: [1, 0]),
                RelationMonomial(coefficient: -GoldilocksField.one, exponents: [0, 1])
            ]
        )
        let shape = try CCSShape(
            matrices: [identity, identity],
            publicInputCount: CyclotomicRing54.degree,
            relationPolynomial: relation
        )
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("paper-audit-key".utf8))
        let publicInputs = [
            (0..<CyclotomicRing54.degree).map { index in
                [GoldilocksField.one, -GoldilocksField.one, .zero][index % 3]
            },
            (0..<CyclotomicRing54.degree).map { index in
                [-GoldilocksField.one, .zero, GoldilocksField.one][index % 3]
            }
        ]
        let privateWitnesses = [
            (0..<10).map { index in [GoldilocksField.zero, GoldilocksField.one][index % 2] },
            (0..<10).map { index in [GoldilocksField.one, GoldilocksField.zero][index % 2] }
        ]
        let instances = try zip(publicInputs, privateWitnesses).map { publicInput, privateWitness in
            return CCSInstance(
                commitment: try backend.commit(key: key, message: publicInput + privateWitness),
                publicInput: publicInput
            )
        }
        let witnesses = privateWitnesses.map(CCSWitness.init)
        let input = SuperNeoFoldInput(
            shape: shape,
            instances: instances,
            witnesses: witnesses,
            priorClaims: priorClaims
        )
        return (backend, key, input)
    }

    func assertPiCCSMatchesPaperReference(
        input: SuperNeoPublicFoldInput,
        proof: FoldProof,
        seed: [UInt8]
    ) throws -> PaperReferenceTranscriptState {
        var transcript = makePublicFoldTranscript(input: input, seed: seed)
        let numVars = try log2ForTest(input.shape.m)
        let alpha = (0..<numVars).map { _ in transcript.challengeExt2() }
        let gamma = transcript.challengeExt2()
        let claimedSum = try paperReferenceClaimedSum(input: input, gamma: gamma)
        XCTAssertEqual(proof.sumCheck.claimedSum, claimedSum)

        let accepted = try SumcheckVerifier.verify(
            proof: proof.sumCheck,
            transcript: &transcript,
            expectedDegree: paperReferenceMaxDegreePerRound(shape: input.shape, parameters: .goldilocks),
            expectedRoundCount: numVars
        ) { point, value in
            try self.paperReferenceFinalQ(
                input: input,
                proofClaims: proof.piCCSClaims,
                point: point,
                alpha: alpha,
                gamma: gamma
            ) == value
        }
        XCTAssertTrue(accepted)
        XCTAssertEqual(proof.sumCheck.finalValue, try paperReferenceFinalQ(
            input: input,
            proofClaims: proof.piCCSClaims,
            point: proof.sumCheck.finalPoint,
            alpha: alpha,
            gamma: gamma
        ))

        return PaperReferenceTranscriptState(
            alpha: alpha,
            gamma: gamma,
            transcriptAfterSumcheck: transcript
        )
    }

    func assertPiRLCMatchesPaperReference(
        input: SuperNeoPublicFoldInput,
        proof: FoldProof,
        transcriptState: PaperReferenceTranscriptState
    ) throws {
        var transcript = transcriptState.transcriptAfterSumcheck
        transcript.absorb(transcriptEncodeCount(proof.piCCSClaims.count))
        proof.piCCSClaims.forEach { transcript.absorb($0.superNeoBytes) }

        let expectedChallenges = proof.piCCSClaims.map { _ in transcript.challengeRing() }
        XCTAssertEqual(proof.randomLinearCombinationChallenges, expectedChallenges)
        XCTAssertStrongSamplingCapacity(
            freshCount: input.instances.count,
            priorCount: input.priorClaims.count,
            parameters: .goldilocks
        )
        expectedChallenges.forEach {
            XCTAssertStrongSamplingChallenge($0, parameters: .goldilocks)
        }

        let folded = try paperReferenceRandomLinearCombination(
            claims: proof.piCCSClaims,
            challenges: expectedChallenges
        )
        XCTAssertEqual(proof.foldedClaim.commitment, folded.commitment)
        XCTAssertEqual(proof.foldedClaim.publicInput, folded.publicInput)
        XCTAssertEqual(proof.foldedClaim.point, folded.point)
        XCTAssertEqual(proof.foldedClaim.evaluations, folded.evaluations)
    }

    func assertPiDECMatchesPaperReference(
        folded: CCSEvaluationClaim,
        proofOutputClaims: [CCSEvaluationClaim],
        witnessOutputClaims: [CCSEvaluationClaim],
        parameters: SuperNeoParameters
    ) throws {
        XCTAssertEqual(proofOutputClaims.count, parameters.decompositionLength)
        XCTAssertEqual(proofOutputClaims.count, witnessOutputClaims.count)
        for (proofClaim, witnessClaim) in zip(proofOutputClaims, witnessOutputClaims) {
            XCTAssertClaimsSharePublicData(proofClaim, witnessClaim)
            XCTAssertTrue(proofClaim.publicInput.allSatisfy { signedMagnitudeForTest($0) < UInt64(parameters.normBound) })
            guard let witness = witnessClaim.witness else {
                XCTFail("decomposition output claim is missing its local witness")
                continue
            }
            XCTAssertTrue(witness.allSatisfy { signedMagnitudeForTest($0) < UInt64(parameters.normBound) })
        }

        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: folded.commitment.elements.count))
        let foldedPackedInput = try SuperNeoEmbedding.packPadded(folded.publicInput)
        var packedInput = Array(repeating: CyclotomicRing54.zero, count: foldedPackedInput.count)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: folded.evaluations.count)

        for (index, part) in proofOutputClaims.enumerated() {
            let scalar = try decompositionScalarForTest(base: parameters.normBound, exponent: index)
            for commitmentIndex in commitment.elements.indices {
                commitment.elements[commitmentIndex] = commitment.elements[commitmentIndex]
                    + scalar * part.commitment.elements[commitmentIndex]
            }

            let packedPartInput = try SuperNeoEmbedding.packPadded(part.publicInput)
            XCTAssertEqual(packedPartInput.count, packedInput.count)
            for inputIndex in packedInput.indices {
                packedInput[inputIndex] = packedInput[inputIndex] + scalar * packedPartInput[inputIndex]
            }
            for evalIndex in evaluations.indices {
                evaluations[evalIndex] = evaluations[evalIndex] + scalar * part.evaluations[evalIndex]
            }
        }

        XCTAssertEqual(commitment, folded.commitment)
        XCTAssertEqual(packedInput, foldedPackedInput)
        XCTAssertEqual(evaluations, folded.evaluations)
    }

    func paperReferenceClaimedSum(
        input: SuperNeoPublicFoldInput,
        gamma: GoldilocksExt2
    ) throws -> GoldilocksExt2 {
        let freshCount = input.instances.count
        let priorCount = input.priorClaims.count
        guard priorCount > 0 else { return .zero }

        var total = GoldilocksExt2.zero
        for priorIndex in input.priorClaims.indices {
            let claim = input.priorClaims[priorIndex]
            XCTAssertEqual(claim.evaluations.count, input.shape.numMatrices)
            for matrixIndex in 0..<input.shape.numMatrices {
                for coefficientIndex in 0..<CyclotomicRing54.degree {
                    let exponent = paperPriorExponent(
                        priorIndex: priorIndex,
                        matrixIndex: matrixIndex,
                        coefficientIndex: coefficientIndex,
                        priorCount: priorCount,
                        matrixCount: input.shape.numMatrices
                    )
                    total = total
                        + powExt2ForTest(gamma, exponent) * claim.evaluations[matrixIndex].coefficients[coefficientIndex]
                }
            }
        }
        return powExt2ForTest(gamma, (2 * freshCount) + priorCount) * total
    }

    func paperReferenceFinalQ(
        input: SuperNeoPublicFoldInput,
        proofClaims: [CCSEvaluationClaim],
        point: [GoldilocksExt2],
        alpha: [GoldilocksExt2],
        gamma: GoldilocksExt2
    ) throws -> GoldilocksExt2 {
        let freshCount = input.instances.count
        let priorCount = input.priorClaims.count
        XCTAssertEqual(proofClaims.count, freshCount + priorCount)

        var relationPart = GoldilocksExt2.zero
        for freshIndex in 0..<freshCount {
            let matrixValues = proofClaims[freshIndex].evaluations.map(\.constantTerm)
            relationPart = relationPart
                + powExt2ForTest(gamma, freshIndex) * (try input.shape.relationPolynomial.evaluate(matrixValues))
        }

        let normRoots = SuperNeoParameters.goldilocks.normRoots.map { GoldilocksExt2($0) }
        var normPart = GoldilocksExt2.zero
        for claimIndex in proofClaims.indices {
            guard let zAtPoint = proofClaims[claimIndex].evaluations.first?.constantTerm else {
                throw SuperNeoError.invalidParameter("paper reference claim is missing identity evaluation")
            }
            let product = normRoots.reduce(GoldilocksExt2.one) { partial, root in
                partial * (zAtPoint - root)
            }
            normPart = normPart + powExt2ForTest(gamma, claimIndex) * product
        }

        var priorEvalPart = GoldilocksExt2.zero
        if let priorPoint = input.priorClaims.first?.point {
            let eq = try MultilinearEvaluation.eq(point, priorPoint)
            var inner = GoldilocksExt2.zero
            for priorIndex in 0..<priorCount {
                let claim = proofClaims[freshCount + priorIndex]
                for matrixIndex in 0..<input.shape.numMatrices {
                    for coefficientIndex in 0..<CyclotomicRing54.degree {
                        let exponent = paperPriorExponent(
                            priorIndex: priorIndex,
                            matrixIndex: matrixIndex,
                            coefficientIndex: coefficientIndex,
                            priorCount: priorCount,
                            matrixCount: input.shape.numMatrices
                        )
                        inner = inner
                            + powExt2ForTest(gamma, exponent) * claim.evaluations[matrixIndex].coefficients[coefficientIndex]
                    }
                }
            }
            priorEvalPart = eq * inner
        }

        return try MultilinearEvaluation.eq(point, alpha)
            * (relationPart + powExt2ForTest(gamma, freshCount) * normPart)
            + powExt2ForTest(gamma, (2 * freshCount) + priorCount) * priorEvalPart
    }

    func paperReferenceRandomLinearCombination(
        claims: [CCSEvaluationClaim],
        challenges: [CyclotomicRing54]
    ) throws -> CCSEvaluationClaim {
        guard let first = claims.first else {
            throw SuperNeoError.invalidParameter("paper reference RLC needs at least one claim")
        }
        XCTAssertEqual(claims.count, challenges.count)

        var commitment = AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: first.commitment.elements.count))
        let packedPublicInputCount = SuperNeoEmbedding.paddedLength(forFieldElementCount: first.publicInput.count)
        var publicInput = Array(repeating: CyclotomicRing54.zero, count: packedPublicInputCount / CyclotomicRing54.degree)
        var evaluations = Array(repeating: CyclotomicExt2Ring54.zero, count: first.evaluations.count)

        for (challenge, claim) in zip(challenges, claims) {
            XCTAssertEqual(claim.commitment.elements.count, commitment.elements.count)
            XCTAssertEqual(claim.point, first.point)
            XCTAssertEqual(claim.publicInput.count, first.publicInput.count)
            XCTAssertEqual(claim.evaluations.count, evaluations.count)

            for index in commitment.elements.indices {
                commitment.elements[index] = commitment.elements[index] + challenge * claim.commitment.elements[index]
            }

            let packedInput = try SuperNeoEmbedding.packPadded(claim.publicInput)
            XCTAssertEqual(packedInput.count, publicInput.count)
            for index in publicInput.indices {
                publicInput[index] = publicInput[index] + challenge * packedInput[index]
            }
            for index in evaluations.indices {
                evaluations[index] = evaluations[index] + challenge * claim.evaluations[index]
            }
        }

        return CCSEvaluationClaim(
            commitment: commitment,
            publicInput: Array(SuperNeoEmbedding.unpack(publicInput).prefix(first.publicInput.count)),
            point: first.point,
            evaluations: evaluations
        )
    }

    func paperReferenceMaxDegreePerRound(shape: CCSShape, parameters: SuperNeoParameters) -> Int {
        max(shape.relationDegree, parameters.normRoots.count) + 1
    }

    func paperPriorExponent(
        priorIndex: Int,
        matrixIndex: Int,
        coefficientIndex: Int,
        priorCount: Int,
        matrixCount: Int
    ) -> Int {
        priorIndex + priorCount * matrixIndex + priorCount * matrixCount * coefficientIndex
    }

    func powExt2ForTest(_ base: GoldilocksExt2, _ exponent: Int) -> GoldilocksExt2 {
        guard exponent > 0 else { return .one }
        return (0..<exponent).reduce(GoldilocksExt2.one) { value, _ in value * base }
    }

    func decompositionScalarForTest(base: Int, exponent: Int) throws -> CyclotomicRing54 {
        guard base > 0, exponent >= 0 else {
            throw SuperNeoError.invalidParameter("invalid decomposition scalar")
        }
        var value: UInt64 = 1
        for _ in 0..<exponent {
            let (next, overflow) = value.multipliedReportingOverflow(by: UInt64(base))
            guard !overflow else {
                throw SuperNeoError.invalidParameter("decomposition scalar overflow")
            }
            value = next
        }
        return CyclotomicRing54([GoldilocksField(value)])
    }

    func XCTAssertStrongSamplingCapacity(
        freshCount: Int,
        priorCount: Int,
        parameters: SuperNeoParameters,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let batchCount = UInt64(freshCount + priorCount)
        let left = batchCount
            * UInt64(parameters.challengeExpansionFactor)
            * UInt64(parameters.normBound - 1)
        let right = (0..<parameters.decompositionLength).reduce(UInt64(1)) { value, _ in
            value * UInt64(parameters.normBound)
        }
        XCTAssertLessThan(left, right, file: file, line: line)
    }

    func XCTAssertStrongSamplingChallenge(
        _ challenge: CyclotomicRing54,
        parameters: SuperNeoParameters,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let allowed = Set(parameters.challengeCoefficients.map(Int.init))
        for coefficient in challenge.coefficients {
            guard let centered = centeredSmallIntForTest(coefficient) else {
                XCTFail("challenge coefficient is outside the expected small range", file: file, line: line)
                continue
            }
            XCTAssertTrue(allowed.contains(centered), file: file, line: line)
        }
    }

    func XCTAssertClaimsSharePublicData(
        _ lhs: CCSEvaluationClaim,
        _ rhs: CCSEvaluationClaim,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.commitment, rhs.commitment, file: file, line: line)
        XCTAssertEqual(lhs.publicInput, rhs.publicInput, file: file, line: line)
        XCTAssertEqual(lhs.point, rhs.point, file: file, line: line)
        XCTAssertEqual(lhs.evaluations, rhs.evaluations, file: file, line: line)
    }

    func log2ForTest(_ value: Int) throws -> Int {
        guard value > 0, (value & (value - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("test value must be a positive power of two")
        }
        return value.trailingZeroBitCount
    }

    func centeredFieldForTest(_ value: Int) -> GoldilocksField {
        value >= 0 ? GoldilocksField(UInt64(value)) : -GoldilocksField(UInt64(-value))
    }

    func centeredSmallIntForTest(_ value: GoldilocksField) -> Int? {
        if value.rawValue <= 2 { return Int(value.rawValue) }
        let negative = GoldilocksField.modulus - value.rawValue
        if negative <= 2 { return -Int(negative) }
        return nil
    }

    func makeForgedReductionFixture() throws -> (
        key: AjtaiCommitmentKey,
        publicInput: SuperNeoPublicFoldInput,
        proof: FoldProof,
        seed: [UInt8]
    ) {
        let publicInput = [GoldilocksField.one] + Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree - 1)
        let shape = try CCSShape.hadamardProduct(
            matrices: [SparseFieldMatrix.identity(size: 64)],
            publicInputCount: publicInput.count
        )
        let key = try AjtaiCommitmentKey(columns: 2, seed: Array("forged-key".utf8))
        let committedInvalidWitness = publicInput + Array(repeating: GoldilocksField.zero, count: 10)
        let commitment = try SuperNeoCPUBackend().commit(key: key, message: committedInvalidWitness)
        let instance = CCSInstance(commitment: commitment, publicInput: publicInput)
        let publicFoldInput = SuperNeoPublicFoldInput(shape: shape, instances: [instance])
        let seed = Array("forged".utf8)

        var transcript = makePublicFoldTranscript(input: publicFoldInput, seed: seed)
        for _ in 0..<6 { _ = transcript.challengeExt2() }
        _ = transcript.challengeExt2()

        let claimedSum = GoldilocksExt2.zero
        transcript.absorb(claimedSum.superNeoBytes)
        var rounds: [SumcheckRound] = []
        var finalPoint: [GoldilocksExt2] = []
        for _ in 0..<6 {
            let round = SumcheckRound(coeffs: [.zero])
            rounds.append(round)
            transcript.absorb(round.superNeoBytes)
            finalPoint.append(transcript.challengeExt2())
        }
        let sumCheck = SumcheckProof(
            claimedSum: claimedSum,
            rounds: rounds,
            finalPoint: finalPoint,
            finalValue: .zero
        )

        let piClaim = CCSEvaluationClaim(
            commitment: commitment,
            publicInput: publicInput,
            point: finalPoint,
            evaluations: [CyclotomicExt2Ring54.zero]
        )
        transcript.absorb(transcriptEncodeCount(1))
        transcript.absorb(piClaim.superNeoBytes)
        let challenge = transcript.challengeRing()
        let foldedCommitment = commitment.scaled(by: challenge)
        let foldedInputRing = challenge * (try SuperNeoEmbedding.packPadded(publicInput))[0]
        let foldedPublicInput = Array(SuperNeoEmbedding.unpack([foldedInputRing]).prefix(publicInput.count))
        let foldedClaim = CCSEvaluationClaim(
            commitment: foldedCommitment,
            publicInput: foldedPublicInput,
            point: finalPoint,
            evaluations: [CyclotomicExt2Ring54.zero]
        )

        let publicInputLimbs = splitSignedBaseForTest(
            foldedPublicInput,
            base: key.parameters.normBound,
            count: key.parameters.decompositionLength
        )
        let outputClaims = (0..<key.parameters.decompositionLength).map { index in
            CCSEvaluationClaim(
                commitment: index == 0
                    ? foldedCommitment
                    : AjtaiCommitment(Array(repeating: CyclotomicRing54.zero, count: key.parameters.kappa)),
                publicInput: publicInputLimbs[index],
                point: finalPoint,
                evaluations: [CyclotomicExt2Ring54.zero]
            )
        }

        return (
            key,
            publicFoldInput,
            FoldProof(
                sumCheck: sumCheck,
                randomLinearCombinationChallenges: [challenge],
                piCCSClaims: [piClaim],
                foldedClaim: foldedClaim,
                decomposition: DecompositionProof(
                    commitments: outputClaims.map(\.commitment),
                    evaluations: outputClaims.map(\.evaluations)
                ),
                outputClaims: outputClaims
            ),
            seed
        )
    }

    func makePublicFoldTranscript(input: SuperNeoPublicFoldInput, seed: [UInt8]) -> SumCheckTranscript {
        var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.fold", seed: seed)
        transcript.absorb(input.shape.shapeDigest.superNeoBytes)
        transcript.absorb(transcriptEncodeCount(input.instances.count))
        input.instances.forEach { transcript.absorb($0.superNeoBytes) }
        transcript.absorb(transcriptEncodeCount(input.priorClaims.count))
        input.priorClaims.forEach { transcript.absorb($0.superNeoBytes) }
        return transcript
    }

    func transcriptEncodeCount(_ value: Int) -> [UInt8] {
        withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
    }

    func splitSignedBaseForTest(_ values: [GoldilocksField], base: Int, count: Int) -> [[GoldilocksField]] {
        var limbs = Array(repeating: Array(repeating: GoldilocksField.zero, count: values.count), count: count)
        let radix = UInt64(base)
        for (index, value) in values.enumerated() {
            var raw = signedMagnitudeForTest(value)
            let isNegative = value.rawValue > GoldilocksField.modulus / 2
            for limb in 0..<count {
                let digit = raw % radix
                if digit != 0 {
                    let fieldDigit = GoldilocksField(digit)
                    limbs[limb][index] = isNegative ? -fieldDigit : fieldDigit
                }
                raw /= radix
            }
        }
        return limbs
    }

    func signedMagnitudeForTest(_ value: GoldilocksField) -> UInt64 {
        value.rawValue <= GoldilocksField.modulus / 2
            ? value.rawValue
            : GoldilocksField.modulus - value.rawValue
    }

    func makeFoldFixture() throws -> (
        backend: SuperNeoCPUBackend,
        key: AjtaiCommitmentKey,
        input: SuperNeoFoldInput,
        seed: [UInt8]
    ) {
        let publicInput = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
        let privateWitness = Array(repeating: GoldilocksField.zero, count: 10)
        let matrix = try SparseFieldMatrix.identity(size: publicInput.count + privateWitness.count)
        let structure = CCSStructure.hadamardProduct(matrices: [matrix])
        let backend = SuperNeoCPUBackend()
        let key = try AjtaiCommitmentKey(
            columns: SuperNeoEmbedding.paddedLength(forFieldElementCount: publicInput.count + privateWitness.count) / CyclotomicRing54.degree,
            seed: Array("fold-key".utf8)
        )
        let commitment = try backend.commit(key: key, message: publicInput + privateWitness)
        let input = try SuperNeoFoldInput(
            structure: structure,
            instances: [CCSInstance(commitment: commitment, publicInput: publicInput)],
            witnesses: [CCSWitness(privateWitness)]
        )
        return (backend, key, input, Array("fold".utf8))
    }

    func makeEnvelopeContext(
        for input: SuperNeoFoldInput,
        profileID: UInt16 = 1,
        kind: ProofEnvelopeKind = .foldReduction,
        shapeDigest: Digest256? = nil,
        statementDigest: Digest256? = nil,
        verifierKeyDigest: Digest256 = .hash("test-verifier-key"),
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1")
    ) -> ProofEnvelopeContext {
        let publicInput = SuperNeoPublicFoldInput(input)
        let statement = CCSStatement(
            shapeDigest: publicInput.shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
        )
        return ProofEnvelopeContext(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest ?? publicInput.shape.shapeDigest,
            statementDigest: statementDigest ?? statement.statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }

    func makeEnvelopeContext(
        profileID: UInt16 = 1,
        kind: ProofEnvelopeKind = .foldReduction,
        shapeDigest: Digest256 = .hash("test-shape"),
        statementDigest: Digest256 = .hash("test-statement"),
        verifierKeyDigest: Digest256 = .hash("test-verifier-key"),
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1")
    ) -> ProofEnvelopeContext {
        ProofEnvelopeContext(
            profileID: profileID,
            kind: kind,
            shapeDigest: shapeDigest,
            statementDigest: statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }

    func makeToySumcheckProof() -> SumcheckProof {
        let claimed = GoldilocksExt2(GoldilocksField(31))
        var transcript = SumCheckTranscript(domainSeparator: "test.sumcheck")
        transcript.absorb(claimed.superNeoBytes)

        let round1 = SumcheckRound(coeffs: [
            GoldilocksExt2(GoldilocksField(9)),
            GoldilocksExt2(GoldilocksField(13))
        ])
        transcript.absorb(round1.superNeoBytes)
        let r1 = transcript.challengeExt2()

        let round2 = SumcheckRound(coeffs: [
            GoldilocksExt2(GoldilocksField(2)) + GoldilocksExt2(GoldilocksField(3)) * r1,
            GoldilocksExt2(GoldilocksField(5)) + GoldilocksExt2(GoldilocksField(7)) * r1
        ])
        transcript.absorb(round2.superNeoBytes)
        let r2 = transcript.challengeExt2()

        return SumcheckProof(
            claimedSum: claimed,
            rounds: [round1, round2],
            finalPoint: [r1, r2],
            finalValue: toySumcheckPolynomial(r1, r2)
        )
    }

    func toySumcheckPolynomial(_ x: GoldilocksExt2, _ y: GoldilocksExt2) -> GoldilocksExt2 {
        GoldilocksExt2(GoldilocksField(2))
            + GoldilocksExt2(GoldilocksField(3)) * x
            + GoldilocksExt2(GoldilocksField(5)) * y
            + GoldilocksExt2(GoldilocksField(7)) * x * y
    }
}
