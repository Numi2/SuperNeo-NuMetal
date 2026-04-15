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
        var oracle = OptimizedDenseOracle(context: context)
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
        guard columnCount <= NumiSealWireLimits.maximumDigitTensorColumnCount else {
            throw SuperNeoError.invalidParameter("NumiSeal digit tensor column count is too large")
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

    private static func makeContext(
        linearResidual: NumiSealLinearResidual,
        digitTensor: NumiSealDigitTensor
    ) throws -> Context {
        let slotCount = digitTensor.digits.count
        let paddedSlotCount = nextPowerOfTwo(slotCount)
        let variableCount = try log2Exact(paddedSlotCount)
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

    private struct OptimizedDenseOracle: SumcheckOracle {
        let numVars: Int
        let maxDegreePerRound = NumiSealSumcheckOracle.maxDegreePerRound

        private let residualValue: GoldilocksExt2
        private let languageWeight: GoldilocksExt2
        private let paddingWeight: GoldilocksExt2
        private var digitLayer: [GoldilocksExt2]
        private var paddingLayer: [GoldilocksExt2]
        private var fixedEqZeroPrefix = GoldilocksExt2.one
        private var foldedPrefix: [GoldilocksExt2] = []

        init(context: Context) {
            self.numVars = context.variableCount
            self.residualValue = context.linearResidual.residualValue
            self.languageWeight = context.languageWeight
            self.paddingWeight = context.paddingWeight
            self.digitLayer = context.digitValues.map { GoldilocksExt2($0) }
            self.paddingLayer = context.paddingSelector.map { GoldilocksExt2($0) }
            self.foldedPrefix.reserveCapacity(context.variableCount)
        }

        mutating func roundPolynomial(prefix: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
            guard prefix.count < numVars else {
                throw SuperNeoError.invalidParameter("NumiSeal sum-check prefix is already complete")
            }
            try advance(to: prefix)
            guard digitLayer.count == paddingLayer.count, digitLayer.count > 1, digitLayer.count.isMultiple(of: 2) else {
                throw SuperNeoError.invalidParameter("NumiSeal dense sum-check layer has invalid width")
            }

            var coeffs = Array(repeating: GoldilocksExt2.zero, count: maxDegreePerRound + 1)
            let three = GoldilocksField(3)
            let halfWidth = digitLayer.count / 2
            for index in 0..<halfWidth {
                let lowIndex = index * 2
                let highIndex = lowIndex + 1
                let d0 = digitLayer[lowIndex]
                let d1 = digitLayer[highIndex]
                let p0 = paddingLayer[lowIndex]
                let p1 = paddingLayer[highIndex]

                let da = d0
                let db = d1 - d0
                let pa = p0
                let pb = p1 - p0
                let daSquared = da * da
                let dbSquared = db * db

                let language0 = daSquared * da - da
                let language1 = (daSquared * db).scaled(by: three) - db
                let language2 = (da * dbSquared).scaled(by: three)
                let language3 = dbSquared * db
                let padding0 = pa * da
                let padding1 = pa * db + pb * da
                let padding2 = pb * db

                coeffs[0] = coeffs[0] + languageWeight * language0 + paddingWeight * padding0
                coeffs[1] = coeffs[1] + languageWeight * language1 + paddingWeight * padding1
                coeffs[2] = coeffs[2] + languageWeight * language2 + paddingWeight * padding2
                coeffs[3] = coeffs[3] + languageWeight * language3
            }

            let residualPrefix = residualValue * fixedEqZeroPrefix
            coeffs[0] = coeffs[0] + residualPrefix
            coeffs[1] = coeffs[1] - residualPrefix
            return coeffs
        }

        mutating func finalEvaluation(point: [GoldilocksExt2]) throws -> GoldilocksExt2 {
            guard point.count == numVars else {
                throw SuperNeoError.invalidParameter("NumiSeal sum-check final point length mismatch")
            }
            try advance(to: point)
            guard digitLayer.count == 1, paddingLayer.count == 1 else {
                throw SuperNeoError.invalidParameter("NumiSeal dense sum-check final layer has invalid width")
            }
            let digit = digitLayer[0]
            let padding = paddingLayer[0]
            let language = digit * (digit - .one) * (digit + .one)
            let paddingTerm = padding * digit
            let residualTerm = residualValue * fixedEqZeroPrefix
            return residualTerm + languageWeight * language + paddingWeight * paddingTerm
        }

        private mutating func advance(to prefix: [GoldilocksExt2]) throws {
            guard prefix.count <= numVars else {
                throw SuperNeoError.invalidParameter("NumiSeal sum-check prefix is longer than variable count")
            }
            guard prefix.count >= foldedPrefix.count else {
                throw SuperNeoError.invalidParameter("NumiSeal dense sum-check oracle cannot rewind")
            }
            guard Array(prefix.prefix(foldedPrefix.count)) == foldedPrefix else {
                throw SuperNeoError.invalidParameter("NumiSeal dense sum-check prefix changed after folding")
            }
            while foldedPrefix.count < prefix.count {
                let challenge = prefix[foldedPrefix.count]
                try foldLayer(by: challenge)
                fixedEqZeroPrefix = fixedEqZeroPrefix * (.one - challenge)
                foldedPrefix.append(challenge)
            }
        }

        private mutating func foldLayer(by challenge: GoldilocksExt2) throws {
            guard digitLayer.count == paddingLayer.count, digitLayer.count > 1, digitLayer.count.isMultiple(of: 2) else {
                throw SuperNeoError.invalidParameter("NumiSeal dense sum-check layer has invalid width")
            }
            let lowWeight = GoldilocksExt2.one - challenge
            let halfWidth = digitLayer.count / 2
            var nextDigitLayer: [GoldilocksExt2] = []
            var nextPaddingLayer: [GoldilocksExt2] = []
            nextDigitLayer.reserveCapacity(halfWidth)
            nextPaddingLayer.reserveCapacity(halfWidth)
            for index in 0..<halfWidth {
                let lowIndex = index * 2
                let highIndex = lowIndex + 1
                nextDigitLayer.append(digitLayer[lowIndex] * lowWeight + digitLayer[highIndex] * challenge)
                nextPaddingLayer.append(paddingLayer[lowIndex] * lowWeight + paddingLayer[highIndex] * challenge)
            }
            digitLayer = nextDigitLayer
            paddingLayer = nextPaddingLayer
        }
    }
}
