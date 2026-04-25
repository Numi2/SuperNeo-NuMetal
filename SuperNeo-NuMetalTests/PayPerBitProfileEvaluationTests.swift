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
}
