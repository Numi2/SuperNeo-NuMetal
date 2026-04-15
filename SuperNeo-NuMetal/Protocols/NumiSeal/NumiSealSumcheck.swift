import Foundation

public enum NumiSealSumcheckOracle {
    public static let maxDegreePerRound = 4
    public static let maximumReferenceVariableCount = 12

    public static func prove(
        linearResidual: NumiSealLinearResidual,
        digitTensor: NumiSealDigitTensor
    ) throws -> SumcheckProof {
        try validateBindings(linearResidual: linearResidual, digitTensor: digitTensor)
        let context = try makeContext(linearResidual: linearResidual, digitTensor: digitTensor)
        var oracle = try makeReferenceOracle(context: context)
        var transcript = makeTranscript(context: context)
        return try SumcheckProver.prove(
            oracle: &oracle,
            claimedSum: linearResidual.residualValue,
            transcript: &transcript
        )
    }

    public static func verify(
        proof: SumcheckProof,
        linearResidual: NumiSealLinearResidual,
        digitTensor: NumiSealDigitTensor
    ) throws -> Bool {
        try validateBindings(linearResidual: linearResidual, digitTensor: digitTensor)
        guard proof.claimedSum == linearResidual.residualValue else { return false }
        let context = try makeContext(linearResidual: linearResidual, digitTensor: digitTensor)
        var transcript = makeTranscript(context: context)
        return try SumcheckVerifier.verify(
            proof: proof,
            transcript: &transcript,
            expectedDegree: maxDegreePerRound,
            expectedRoundCount: context.variableCount
        ) { point, value in
            try evaluate(context: context, at: point) == value
        }
    }

    public static func verifyFinalOpening(
        proof: SumcheckProof,
        linearResidualDigest: Digest256,
        scalarizationStatementDigest: Digest256,
        digitTensorDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        claimedDigitEvaluation: GoldilocksExt2
    ) throws -> Bool {
        let slotCount = try checkedSlotCount(columnCount: columnCount)
        let paddedSlotCount = nextPowerOfTwo(slotCount)
        let variableCount = try log2Exact(paddedSlotCount)
        guard variableCount <= maximumReferenceVariableCount else {
            throw SuperNeoError.invalidParameter("NumiSeal reference sum-check variable count is too large")
        }
        guard activeDigitCount >= 0, activeDigitCount <= slotCount else {
            throw SuperNeoError.invalidParameter("NumiSeal active digit count exceeds tensor size")
        }
        guard proof.finalPoint.count == variableCount else { return false }
        let weights = deriveWeights(
            linearResidualDigest: linearResidualDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            digitTensorDigest: digitTensorDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            columnCount: columnCount,
            activeDigitCount: activeDigitCount,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount
        )
        var transcript = makeTranscript(
            linearResidualDigest: linearResidualDigest,
            scalarizationStatementDigest: scalarizationStatementDigest,
            digitTensorDigest: digitTensorDigest,
            laneKey: laneKey,
            aggregateIndex: aggregateIndex,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount,
            weightDigest: weights.digest
        )
        return try SumcheckVerifier.verify(
            proof: proof,
            transcript: &transcript,
            expectedDegree: maxDegreePerRound,
            expectedRoundCount: variableCount
        ) { point, value in
            let padding = try paddingEvaluation(
                activeDigitCount: activeDigitCount,
                paddedSlotCount: paddedSlotCount,
                at: point
            )
            let language = claimedDigitEvaluation
                * (claimedDigitEvaluation - .one)
                * (claimedDigitEvaluation + .one)
            let paddingTerm = padding * claimedDigitEvaluation
            let residualTerm = proof.claimedSum * eqZero(at: point)
            let expected = residualTerm + weights.language * language + weights.padding * paddingTerm
            return value == expected
        }
    }

    private static func validateBindings(
        linearResidual: NumiSealLinearResidual,
        digitTensor: NumiSealDigitTensor
    ) throws {
        let statement = linearResidual.statement
        guard statement.laneKey == digitTensor.laneKey else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check digit tensor lane mismatch")
        }
        guard statement.aggregateIndex == digitTensor.aggregateIndex else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check digit tensor aggregate mismatch")
        }
    }

    private static func makeReferenceOracle(
        context: Context
    ) throws -> EvaluatingSumcheckOracle {
        try EvaluatingSumcheckOracle(
            numVars: context.variableCount,
            maxDegreePerRound: maxDegreePerRound
        ) { point in
            try evaluate(context: context, at: point)
        }
    }

    private static func makeContext(
        linearResidual: NumiSealLinearResidual,
        digitTensor: NumiSealDigitTensor
    ) throws -> Context {
        let slotCount = digitTensor.digits.count
        let paddedSlotCount = nextPowerOfTwo(slotCount)
        let variableCount = try log2Exact(paddedSlotCount)
        guard variableCount <= maximumReferenceVariableCount else {
            throw SuperNeoError.invalidParameter("NumiSeal reference sum-check variable count is too large")
        }
        var digitValues = digitTensor.digits.map(\.fieldElement)
        digitValues += Array(repeating: .zero, count: paddedSlotCount - digitValues.count)
        var paddingSelector = Array(repeating: GoldilocksField.zero, count: paddedSlotCount)
        if digitTensor.activeDigitCount < paddedSlotCount {
            for index in digitTensor.activeDigitCount..<paddedSlotCount {
                paddingSelector[index] = .one
            }
        }
        let weights = deriveWeights(
            linearResidualDigest: linearResidual.residualDigest,
            scalarizationStatementDigest: linearResidual.statement.statementDigest,
            digitTensorDigest: digitTensor.digest,
            laneKey: digitTensor.laneKey,
            aggregateIndex: digitTensor.aggregateIndex,
            columnCount: digitTensor.columnCount,
            activeDigitCount: digitTensor.activeDigitCount,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount
        )
        return Context(
            linearResidual: linearResidual,
            digitTensorDigest: digitTensor.digest,
            paddedSlotCount: paddedSlotCount,
            variableCount: variableCount,
            digitValues: digitValues,
            paddingSelector: paddingSelector,
            languageWeight: weights.language,
            paddingWeight: weights.padding,
            weightDigest: weights.digest
        )
    }

    private static func makeTranscript(context: Context) -> SumCheckTranscript {
        makeTranscript(
            linearResidualDigest: context.linearResidual.residualDigest,
            scalarizationStatementDigest: context.linearResidual.statement.statementDigest,
            digitTensorDigest: context.digitTensorDigest,
            laneKey: context.linearResidual.statement.laneKey,
            aggregateIndex: context.linearResidual.statement.aggregateIndex,
            paddedSlotCount: context.paddedSlotCount,
            variableCount: context.variableCount,
            weightDigest: context.weightDigest
        )
    }

    private static func makeTranscript(
        linearResidualDigest: Digest256,
        scalarizationStatementDigest: Digest256,
        digitTensorDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        paddedSlotCount: Int,
        variableCount: Int,
        weightDigest: Digest256
    ) -> SumCheckTranscript {
        var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.numiseal.sumcheck.v1")
        transcript.absorb(linearResidualDigest.superNeoBytes)
        transcript.absorb(scalarizationStatementDigest.superNeoBytes)
        transcript.absorb(digitTensorDigest.superNeoBytes)
        transcript.absorb(laneKey.superNeoBytes)
        transcript.absorb(numiSealEncodeCount(aggregateIndex))
        transcript.absorb(numiSealEncodeCount(paddedSlotCount))
        transcript.absorb(numiSealEncodeCount(variableCount))
        transcript.absorb(weightDigest.superNeoBytes)
        return transcript
    }

    private static func evaluate(
        context: Context,
        at point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        guard point.count == context.variableCount else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check point length mismatch")
        }
        let digit = try MultilinearEvaluation.evaluate(context.digitValues, at: point)
        let padding = try MultilinearEvaluation.evaluate(context.paddingSelector, at: point)
        let language = digit * (digit - .one) * (digit + .one)
        let paddingTerm = padding * digit
        let residualTerm = context.linearResidual.residualValue * eqZero(at: point)
        return residualTerm + context.languageWeight * language + context.paddingWeight * paddingTerm
    }

    private static func deriveWeights(
        linearResidualDigest: Digest256,
        scalarizationStatementDigest: Digest256,
        digitTensorDigest: Digest256,
        laneKey: NumiSealLaneKey,
        aggregateIndex: Int,
        columnCount: Int,
        activeDigitCount: Int,
        paddedSlotCount: Int,
        variableCount: Int
    ) -> (language: GoldilocksExt2, padding: GoldilocksExt2, digest: Digest256) {
        var transcript = SumCheckTranscript(domainSeparator: "SuperNeo-NuMetal.numiseal.sumcheck-weights.v1")
        transcript.absorb(linearResidualDigest.superNeoBytes)
        transcript.absorb(scalarizationStatementDigest.superNeoBytes)
        transcript.absorb(digitTensorDigest.superNeoBytes)
        transcript.absorb(laneKey.superNeoBytes)
        transcript.absorb(numiSealEncodeCount(aggregateIndex))
        transcript.absorb(numiSealEncodeCount(columnCount))
        transcript.absorb(numiSealEncodeCount(activeDigitCount))
        transcript.absorb(numiSealEncodeCount(paddedSlotCount))
        transcript.absorb(numiSealEncodeCount(variableCount))
        let language = transcript.challengeExt2()
        let padding = transcript.challengeExt2()
        let digest = NumiSealEncoding.digest(
            label: "numiseal.sumcheck-weights.v1",
            bytes: linearResidualDigest.superNeoBytes
                + digitTensorDigest.superNeoBytes
                + numiSealEncodeCount(paddedSlotCount)
                + numiSealEncodeCount(variableCount)
                + language.superNeoBytes
                + padding.superNeoBytes
        )
        return (language, padding, digest)
    }

    private static func eqZero(at point: [GoldilocksExt2]) -> GoldilocksExt2 {
        point.reduce(.one) { partial, coordinate in
            partial * (.one - coordinate)
        }
    }

    private static func nextPowerOfTwo(_ value: Int) -> Int {
        var power = 1
        while power < value {
            power <<= 1
        }
        return power
    }

    private static func checkedSlotCount(columnCount: Int) throws -> Int {
        guard columnCount > 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor column count must be positive")
        }
        let product = columnCount.multipliedReportingOverflow(by: CyclotomicRing54.degree)
        guard !product.overflow else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor dimensions overflow")
        }
        return product.partialValue
    }

    private static func paddingEvaluation(
        activeDigitCount: Int,
        paddedSlotCount: Int,
        at point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        var selector = Array(repeating: GoldilocksField.zero, count: paddedSlotCount)
        if activeDigitCount < paddedSlotCount {
            for index in activeDigitCount..<paddedSlotCount {
                selector[index] = .one
            }
        }
        return try MultilinearEvaluation.evaluate(selector, at: point)
    }

    private static func log2Exact(_ value: Int) throws -> Int {
        guard value > 0, (value & (value - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("NumiSeal sum-check size must be a positive power of two")
        }
        var exponent = 0
        var remaining = value
        while remaining > 1 {
            remaining >>= 1
            exponent += 1
        }
        return exponent
    }

    private struct Context {
        let linearResidual: NumiSealLinearResidual
        let digitTensorDigest: Digest256
        let paddedSlotCount: Int
        let variableCount: Int
        let digitValues: [GoldilocksField]
        let paddingSelector: [GoldilocksField]
        let languageWeight: GoldilocksExt2
        let paddingWeight: GoldilocksExt2
        let weightDigest: Digest256
    }
}
