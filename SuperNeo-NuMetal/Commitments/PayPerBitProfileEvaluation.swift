import Foundation

@_spi(Benchmarking) public struct SuperNeoPayPerBitProfileEvaluation: Codable, Equatable, Sendable {
    public let fieldElementCount: Int
    public let paddedFieldSlotCount: Int
    public let ringColumnCount: Int
    public let ringDegree: Int
    public let paddingFieldSlotCount: Int
    public let nonzeroFieldElementCount: Int
    public let signedBitWidthMaximum: Int
    public let signedBitWidthSum: Int
    public let fixedDecompositionLength: Int
    public let currentFixedDecompositionSlotCount: Int
    public let payPerBitDenseSlotCount: Int
    public let payPerBitPaddedSlotCount: Int
    public let payPerBitActiveDigitSlotCount: Int
    public let currentProfileCanRepresentAllValues: Bool

    public init(
        fieldVector: [GoldilocksField],
        parameters: SuperNeoParameters = .goldilocks
    ) throws {
        guard !fieldVector.isEmpty else {
            throw SuperNeoError.invalidParameter("pay-per-bit profile evaluation requires a nonempty field vector")
        }
        let paddedLength = SuperNeoEmbedding.paddedLength(forFieldElementCount: fieldVector.count)
        let bitWidths = fieldVector.map(Self.signedMagnitudeBitWidth)
        let maxBitWidth = bitWidths.max() ?? 0
        let effectiveDenseBitWidth = max(1, maxBitWidth)

        fieldElementCount = fieldVector.count
        paddedFieldSlotCount = paddedLength
        ringColumnCount = paddedLength / CyclotomicRing54.degree
        ringDegree = CyclotomicRing54.degree
        paddingFieldSlotCount = paddedLength - fieldVector.count
        nonzeroFieldElementCount = fieldVector.reduce(0) { $0 + ($1 == .zero ? 0 : 1) }
        signedBitWidthMaximum = maxBitWidth
        signedBitWidthSum = bitWidths.reduce(0, +)
        fixedDecompositionLength = parameters.decompositionLength
        currentFixedDecompositionSlotCount = paddedLength * parameters.decompositionLength
        payPerBitDenseSlotCount = fieldVector.count * effectiveDenseBitWidth
        payPerBitPaddedSlotCount = paddedLength * effectiveDenseBitWidth
        payPerBitActiveDigitSlotCount = signedBitWidthSum
        currentProfileCanRepresentAllValues = bitWidths.allSatisfy { $0 <= parameters.decompositionLength }
    }

    public var ringPaddingRatio: Double {
        Double(paddedFieldSlotCount) / Double(fieldElementCount)
    }

    public var fixedToPayPerBitDenseSlotRatio: Double {
        Double(currentFixedDecompositionSlotCount) / Double(max(1, payPerBitDenseSlotCount))
    }

    public var fixedToPayPerBitPaddedSlotRatio: Double {
        Double(currentFixedDecompositionSlotCount) / Double(max(1, payPerBitPaddedSlotCount))
    }

    public var fixedToPayPerBitActiveDigitRatio: Double {
        Double(currentFixedDecompositionSlotCount) / Double(max(1, payPerBitActiveDigitSlotCount))
    }

    public var fixedToPayPerBitOpeningRatio: Double {
        Double(fixedDecompositionLength) / Double(max(1, signedBitWidthMaximum))
    }

    public static func signedMagnitude(_ value: GoldilocksField) -> UInt64 {
        let raw = value.rawValue
        let half = GoldilocksField.modulus / 2
        return raw <= half ? raw : GoldilocksField.modulus - raw
    }

    public static func signedMagnitudeBitWidth(_ value: GoldilocksField) -> Int {
        let magnitude = signedMagnitude(value)
        guard magnitude > 0 else { return 0 }
        return UInt64.bitWidth - magnitude.leadingZeroBitCount
    }
}

@_spi(Benchmarking) public struct SuperNeoPayPerBitBenchmarkRow: Codable, Equatable, Sendable {
    public let caseLabel: String
    public let witnessKind: String
    public let rowCount: Int
    public let freshCount: Int
    public let priorCount: Int
    public let evaluation: SuperNeoPayPerBitProfileEvaluation
    public let currentCommitmentProfile: SuperNeoCurrentCommitmentWorkSummary

    public init(
        caseLabel: String,
        witnessKind: String,
        rowCount: Int,
        freshCount: Int,
        priorCount: Int,
        evaluation: SuperNeoPayPerBitProfileEvaluation,
        currentCommitmentProfile: SuperNeoCurrentCommitmentWorkSummary
    ) {
        self.caseLabel = caseLabel
        self.witnessKind = witnessKind
        self.rowCount = rowCount
        self.freshCount = freshCount
        self.priorCount = priorCount
        self.evaluation = evaluation
        self.currentCommitmentProfile = currentCommitmentProfile
    }
}

@_spi(Benchmarking) public struct SuperNeoCurrentCommitmentWorkSummary: Codable, Equatable, Sendable {
    public let matrixRows: Int
    public let matrixColumns: Int
    public let ringDegree: Int
    public let messageCoefficientSlots: Int
    public let nonzeroMessageCoefficients: Int
    public let smallMessageCoefficients: Int
    public let fullWidthMessageCoefficients: Int
    public let activeRotationTerms: Int
    public let smallCoefficientScalings: Int
    public let fullWidthCoefficientScalings: Int

    public init(_ profile: AjtaiCommitmentWorkProfile) {
        matrixRows = profile.matrixRows
        matrixColumns = profile.matrixColumns
        ringDegree = profile.ringDegree
        messageCoefficientSlots = profile.messageCoefficientSlots
        nonzeroMessageCoefficients = profile.nonzeroMessageCoefficients
        smallMessageCoefficients = profile.smallMessageCoefficients
        fullWidthMessageCoefficients = profile.fullWidthMessageCoefficients
        activeRotationTerms = profile.activeRotationTerms
        smallCoefficientScalings = profile.smallCoefficientScalings
        fullWidthCoefficientScalings = profile.fullWidthCoefficientScalings
    }
}
