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

public struct SuperNeoPayPerBitDecompositionPlan: Equatable, Sendable {
    public enum Schedule: UInt8, Equatable, Sendable {
        case sparsePublic = 0
        case constantSecret = 1
    }

    public let fieldElementCount: Int
    public let paddedFieldSlotCount: Int
    public let ringColumnCount: Int
    public let activeLimbCount: Int
    public let fixedLimbCount: Int
    public let activeDigitSlotCount: Int
    public let limbs: [[GoldilocksField]]
    public let schedule: Schedule

    public init(
        fieldElementCount: Int,
        paddedFieldSlotCount: Int,
        ringColumnCount: Int,
        activeLimbCount: Int,
        fixedLimbCount: Int,
        activeDigitSlotCount: Int,
        limbs: [[GoldilocksField]],
        schedule: Schedule = .sparsePublic
    ) {
        self.fieldElementCount = fieldElementCount
        self.paddedFieldSlotCount = paddedFieldSlotCount
        self.ringColumnCount = ringColumnCount
        self.activeLimbCount = activeLimbCount
        self.fixedLimbCount = fixedLimbCount
        self.activeDigitSlotCount = activeDigitSlotCount
        self.limbs = limbs
        self.schedule = schedule
    }

    public var skippedFixedLimbCount: Int {
        max(0, fixedLimbCount - activeLimbCount)
    }

    public var activePaddedSlotCount: Int {
        paddedFieldSlotCount * activeLimbCount
    }

    public var fixedPaddedSlotCount: Int {
        paddedFieldSlotCount * fixedLimbCount
    }

    public var fixedToActivePaddedSlotRatio: Double {
        Double(fixedPaddedSlotCount) / Double(max(1, activePaddedSlotCount))
    }
}

public struct SuperNeoPayPerBitCommitmentResult: Equatable, Sendable {
    public let plan: SuperNeoPayPerBitDecompositionPlan
    public let packedLimbs: [[CyclotomicRing54]]
    public let commitments: [AjtaiCommitment]
    public let commitmentWorkProfiles: [AjtaiCommitmentWorkProfile]

    public var totalActiveRotationTerms: Int {
        commitmentWorkProfiles.reduce(0) { $0 + $1.activeRotationTerms }
    }

    public var totalSmallCoefficientScalings: Int {
        commitmentWorkProfiles.reduce(0) { $0 + $1.smallCoefficientScalings }
    }

    public var totalFullWidthCoefficientScalings: Int {
        commitmentWorkProfiles.reduce(0) { $0 + $1.fullWidthCoefficientScalings }
    }

    public var usesOnlySmallCoefficientScalings: Bool {
        commitmentWorkProfiles.allSatisfy(\.usesOnlySmallCoefficientScalings)
    }
}

@_spi(Benchmarking) public struct SuperNeoPayPerBitOpeningWorkProfile: Equatable, Sendable {
    public let limbCount: Int
    public let zeroLimbCount: Int
    public let activeDigitSlotCount: Int
    public let paddedDigitSlotCount: Int
    public let transformedMatrixCount: Int

    public var skippedDigitSlotCount: Int {
        paddedDigitSlotCount - activeDigitSlotCount
    }
}

@_spi(Benchmarking) public struct SuperNeoPayPerBitOpeningArtifacts: Equatable, Sendable {
    public let commitments: [AjtaiCommitment]
    public let evaluations: [[CyclotomicExt2Ring54]]
    public let commitmentWorkProfiles: [AjtaiCommitmentWorkProfile]
    public let openingWorkProfile: SuperNeoPayPerBitOpeningWorkProfile
}

@_spi(Benchmarking) public enum SuperNeoPayPerBitOpeningOracle {
    public static func makeConstantScheduleOpeningArtifacts(
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        packedLimbs: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        recordWorkProfiles: Bool = true
    ) throws -> SuperNeoPayPerBitOpeningArtifacts {
        let rHat = try validateOpeningInputs(
            key: key,
            transformedMatrices: transformedMatrices,
            packedLimbs: packedLimbs,
            point: point
        )
        guard packedLimbs.count == key.parameters.decompositionLength else {
            throw SuperNeoError.invalidParameter("pay-per-bit constant-schedule opening requires full fixed limb count")
        }
        let commitmentWorkProfile = payPerBitConstantScheduleWorkProfile(key: key)
        let commitments = try packedLimbs.map {
            try AjtaiCommitter.commitConstantWorkReference(key: key, message: $0)
        }
        let evaluations = try packedLimbs.map { packed in
            try transformedMatrices.map {
                try $0.evaluatedProductConstantWork(by: packed, rHat: rHat)
            }
        }
        let paddedDigitSlotCount = packedLimbs.count * key.matrix.columns * CyclotomicRing54.degree
        return SuperNeoPayPerBitOpeningArtifacts(
            commitments: commitments,
            evaluations: evaluations,
            commitmentWorkProfiles: recordWorkProfiles
                ? Array(repeating: commitmentWorkProfile, count: packedLimbs.count)
                : [],
            openingWorkProfile: SuperNeoPayPerBitOpeningWorkProfile(
                limbCount: packedLimbs.count,
                zeroLimbCount: 0,
                activeDigitSlotCount: paddedDigitSlotCount,
                paddedDigitSlotCount: paddedDigitSlotCount,
                transformedMatrixCount: transformedMatrices.count
            )
        )
    }

    public static func makeOpeningArtifacts(
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        packedLimbs: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        recordWorkProfiles: Bool = true
    ) throws -> SuperNeoPayPerBitOpeningArtifacts {
        let rHat = try validateOpeningInputs(
            key: key,
            transformedMatrices: transformedMatrices,
            packedLimbs: packedLimbs,
            point: point
        )

        let sparseLimbs = packedLimbs.map(SparsePackedRingVector.init)
        let commitmentProfiles = try recordWorkProfiles
            ? zip(packedLimbs, sparseLimbs).map { packed, sparse in
                sparse.isZero
                    ? payPerBitZeroWorkProfile(key: key)
                    : try AjtaiCommitter.workProfile(key: key, message: packed)
            }
            : []
        let commitments = try zip(packedLimbs, sparseLimbs).map { packed, sparse -> AjtaiCommitment in
            if sparse.isZero {
                return payPerBitZeroCommitment(parameters: key.parameters)
            }
            return try AjtaiCommitter.commitReference(key: key, message: packed)
        }
        let evaluations = try sparseLimbs.map { sparse -> [CyclotomicExt2Ring54] in
            if sparse.isZero {
                return Array(repeating: .zero, count: transformedMatrices.count)
            }
            return try transformedMatrices.map {
                try evaluateSparseTransformedMatrix($0, by: sparse, rHat: rHat)
            }
        }
        let activeDigitSlotCount = sparseLimbs.reduce(0) { $0 + $1.nonzeroTermCount }
        let paddedDigitSlotCount = packedLimbs.count * key.matrix.columns * CyclotomicRing54.degree
        return SuperNeoPayPerBitOpeningArtifacts(
            commitments: commitments,
            evaluations: evaluations,
            commitmentWorkProfiles: commitmentProfiles,
            openingWorkProfile: SuperNeoPayPerBitOpeningWorkProfile(
                limbCount: packedLimbs.count,
                zeroLimbCount: sparseLimbs.reduce(0) { $0 + ($1.isZero ? 1 : 0) },
                activeDigitSlotCount: activeDigitSlotCount,
                paddedDigitSlotCount: paddedDigitSlotCount,
                transformedMatrixCount: transformedMatrices.count
            )
        )
    }

    private static func validateOpeningInputs(
        key: AjtaiCommitmentKey,
        transformedMatrices: [SparseRingMatrixCSR],
        packedLimbs: [[CyclotomicRing54]],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        guard !packedLimbs.isEmpty else {
            throw SuperNeoError.invalidParameter("pay-per-bit opening requires at least one limb")
        }
        guard key.matrix.rows == key.parameters.kappa else {
            throw SuperNeoError.invalidParameter("Ajtai matrix row count must equal kappa")
        }
        guard packedLimbs.allSatisfy({ $0.count == key.matrix.columns }) else {
            throw SuperNeoError.invalidParameter("pay-per-bit packed limb length must match key column count")
        }
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        for matrix in transformedMatrices {
            guard matrix.columns == key.matrix.columns else {
                throw SuperNeoError.invalidParameter("pay-per-bit transformed matrix column count mismatch")
            }
            guard matrix.rows == rHat.count else {
                throw SuperNeoError.invalidParameter("pay-per-bit transformed matrix evaluation basis mismatch")
            }
        }
        return rHat
    }

    private static func evaluateSparseTransformedMatrix(
        _ matrix: SparseRingMatrixCSR,
        by vector: SparsePackedRingVector,
        rHat: [GoldilocksExt2]
    ) throws -> CyclotomicExt2Ring54 {
        guard vector.columnCount == matrix.columns else {
            throw SuperNeoError.invalidParameter("sparse transformed matrix/vector dimension mismatch")
        }
        guard rHat.count == matrix.rows else {
            throw SuperNeoError.invalidParameter("sparse transformed matrix evaluation basis length mismatch")
        }
        var coefficients = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for row in 0..<matrix.rows {
            let weight = rHat[row]
            for matrixIndex in matrix.rowOffsets[row]..<matrix.rowOffsets[row + 1] {
                let terms = vector.termsByColumn[matrix.columnIndices[matrixIndex]]
                guard !terms.isEmpty else { continue }
                accumulateWeightedSparseProduct(
                    matrix.values[matrixIndex],
                    rhsTerms: terms,
                    weight: weight,
                    into: &coefficients
                )
            }
        }
        return CyclotomicExt2Ring54(coefficients)
    }

    private static func accumulateWeightedSparseProduct(
        _ lhs: CyclotomicRing54,
        rhsTerms: [(index: Int, value: GoldilocksField)],
        weight: GoldilocksExt2,
        into coefficients: inout [GoldilocksExt2]
    ) {
        for leftIndex in 0..<CyclotomicRing54.degree {
            let left = lhs.coefficients[leftIndex]
            guard left != .zero else { continue }
            for term in rhsTerms {
                let product = scaleBySmallOrFull(left, by: term.value)
                guard product != .zero else { continue }
                accumulateWeightedReducedProduct(
                    product,
                    exponent: leftIndex + term.index,
                    weight: weight,
                    into: &coefficients
                )
            }
        }
    }

    private static func accumulateWeightedReducedProduct(
        _ value: GoldilocksField,
        exponent: Int,
        weight: GoldilocksExt2,
        into coefficients: inout [GoldilocksExt2]
    ) {
        let weighted = weight.scaled(by: value)
        if exponent < CyclotomicRing54.degree {
            coefficients[exponent] = coefficients[exponent] + weighted
        } else if exponent < CyclotomicRing54.degree + 27 {
            let reduced = exponent - CyclotomicRing54.degree
            coefficients[reduced] = coefficients[reduced] - weighted
            coefficients[exponent - 27] = coefficients[exponent - 27] - weighted
        } else {
            let reduced = exponent - CyclotomicRing54.degree - 27
            coefficients[reduced] = coefficients[reduced] + weighted
        }
    }

    private static func scaleBySmallOrFull(_ value: GoldilocksField, by scalar: GoldilocksField) -> GoldilocksField {
        if value == .zero || scalar == .zero { return .zero }
        if scalar == .one { return value }
        let doubled = value + value
        if scalar == GoldilocksField(2) { return doubled }
        if scalar == -GoldilocksField.one { return -value }
        if scalar == -GoldilocksField(2) { return -doubled }
        return value * scalar
    }
}

private struct SparsePackedRingVector {
    let termsByColumn: [[(index: Int, value: GoldilocksField)]]
    let nonzeroTermCount: Int

    init(_ vector: [CyclotomicRing54]) {
        var total = 0
        termsByColumn = vector.map { ring in
            var terms: [(index: Int, value: GoldilocksField)] = []
            terms.reserveCapacity(CyclotomicRing54.degree)
            for index in 0..<CyclotomicRing54.degree {
                let value = ring.coefficients[index]
                guard value != .zero else { continue }
                terms.append((index, value))
            }
            total += terms.count
            return terms
        }
        nonzeroTermCount = total
    }

    var columnCount: Int {
        termsByColumn.count
    }

    var isZero: Bool {
        nonzeroTermCount == 0
    }
}

public struct SuperNeoPayPerBitWitnessEvidence: Equatable, Sendable, SuperNeoByteEncodable {
    public static let domain = Digest256.hash("SuperNeo-NuMetal.pay-per-bit.witness-evidence.v1")
    public static let version: UInt16 = 1

    public let version: UInt16
    public let profileID: UInt16
    public let witnessCount: Int
    public let directCommitmentDigests: [Digest256]
    public let recomposedCommitmentDigests: [Digest256]
    public let optimizedLimbCommitmentRoots: [Digest256]
    public let maxActiveLimbCount: Int
    public let totalActiveDigitSlotCount: Int
    public let totalActivePaddedSlotCount: Int
    public let totalFixedPaddedSlotCount: Int
    public let totalSkippedFixedLimbCount: Int
    public let totalActiveRotationTerms: Int
    public let totalSmallCoefficientScalings: Int
    public let totalFullWidthCoefficientScalings: Int
    public let evidenceDigest: Digest256

    public init(
        key: AjtaiCommitmentKey,
        witnesses: [[GoldilocksField]],
        expectedCommitments: [AjtaiCommitment],
        parameters: SuperNeoParameters = .goldilocks,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("pay-per-bit witness evidence parameter mismatch")
        }
        guard !witnesses.isEmpty else {
            throw SuperNeoError.invalidParameter("pay-per-bit witness evidence requires at least one witness")
        }
        guard witnesses.count == expectedCommitments.count else {
            throw SuperNeoError.invalidParameter("pay-per-bit witness evidence commitment count mismatch")
        }

        var directDigests: [Digest256] = []
        var recomposedDigests: [Digest256] = []
        var limbRoots: [Digest256] = []
        var maxActiveLimbCount = 0
        var totalActiveDigitSlotCount = 0
        var totalActivePaddedSlotCount = 0
        var totalFixedPaddedSlotCount = 0
        var totalSkippedFixedLimbCount = 0
        var totalActiveRotationTerms = 0
        var totalSmallCoefficientScalings = 0
        var totalFullWidthCoefficientScalings = 0

        directDigests.reserveCapacity(witnesses.count)
        recomposedDigests.reserveCapacity(witnesses.count)
        limbRoots.reserveCapacity(witnesses.count)

        for (witness, expectedCommitment) in zip(witnesses, expectedCommitments) {
            let direct = executionPolicy.usesConstantWorkCPU
                ? try AjtaiCommitter.commitConstantWorkReference(key: key, fieldWitness: witness)
                : try AjtaiCommitter.commitReference(key: key, fieldWitness: witness)
            guard direct == expectedCommitment else {
                throw SuperNeoError.invalidParameter("pay-per-bit witness evidence commitment mismatch")
            }
            let optimized = executionPolicy.usesConstantWorkCPU
                ? try SuperNeoPayPerBitCommitter.commitConstantScheduleReference(
                    key: key,
                    fieldVector: witness,
                    parameters: parameters
                )
                : try SuperNeoPayPerBitCommitter.commitReference(
                    key: key,
                    fieldVector: witness,
                    parameters: parameters
                )
            let recomposed = try SuperNeoPayPerBitCommitter.recomposeCommitment(
                optimized.commitments,
                parameters: parameters
            )
            guard recomposed == direct else {
                throw SuperNeoError.verificationFailed("pay-per-bit optimized commitments do not recompose")
            }

            directDigests.append(Digest256.hash(direct.superNeoBytes))
            recomposedDigests.append(Digest256.hash(recomposed.superNeoBytes))
            limbRoots.append(Self.limbCommitmentRoot(optimized.commitments))
            maxActiveLimbCount = max(maxActiveLimbCount, optimized.plan.activeLimbCount)
            totalActiveDigitSlotCount += optimized.plan.activeDigitSlotCount
            totalActivePaddedSlotCount += optimized.plan.activePaddedSlotCount
            totalFixedPaddedSlotCount += optimized.plan.fixedPaddedSlotCount
            totalSkippedFixedLimbCount += optimized.plan.skippedFixedLimbCount
            totalActiveRotationTerms += optimized.totalActiveRotationTerms
            totalSmallCoefficientScalings += optimized.totalSmallCoefficientScalings
            totalFullWidthCoefficientScalings += optimized.totalFullWidthCoefficientScalings
        }

        self.version = Self.version
        self.profileID = parameters.profileID
        self.witnessCount = witnesses.count
        self.directCommitmentDigests = directDigests
        self.recomposedCommitmentDigests = recomposedDigests
        self.optimizedLimbCommitmentRoots = limbRoots
        self.maxActiveLimbCount = maxActiveLimbCount
        self.totalActiveDigitSlotCount = totalActiveDigitSlotCount
        self.totalActivePaddedSlotCount = totalActivePaddedSlotCount
        self.totalFixedPaddedSlotCount = totalFixedPaddedSlotCount
        self.totalSkippedFixedLimbCount = totalSkippedFixedLimbCount
        self.totalActiveRotationTerms = totalActiveRotationTerms
        self.totalSmallCoefficientScalings = totalSmallCoefficientScalings
        self.totalFullWidthCoefficientScalings = totalFullWidthCoefficientScalings
        self.evidenceDigest = Self.computeEvidenceDigest(
            version: Self.version,
            profileID: parameters.profileID,
            witnessCount: witnesses.count,
            directCommitmentDigests: directDigests,
            recomposedCommitmentDigests: recomposedDigests,
            optimizedLimbCommitmentRoots: limbRoots,
            maxActiveLimbCount: maxActiveLimbCount,
            totalActiveDigitSlotCount: totalActiveDigitSlotCount,
            totalActivePaddedSlotCount: totalActivePaddedSlotCount,
            totalFixedPaddedSlotCount: totalFixedPaddedSlotCount,
            totalSkippedFixedLimbCount: totalSkippedFixedLimbCount,
            totalActiveRotationTerms: totalActiveRotationTerms,
            totalSmallCoefficientScalings: totalSmallCoefficientScalings,
            totalFullWidthCoefficientScalings: totalFullWidthCoefficientScalings
        )
    }

    public var skippedToActivePaddedSlotRatio: Double {
        Double(totalFixedPaddedSlotCount) / Double(max(1, totalActivePaddedSlotCount))
    }

    public var superNeoBytes: [UInt8] {
        Self.domain.superNeoBytes
            + Self.bodyBytes(
                version: version,
                profileID: profileID,
                witnessCount: witnessCount,
                directCommitmentDigests: directCommitmentDigests,
                recomposedCommitmentDigests: recomposedCommitmentDigests,
                optimizedLimbCommitmentRoots: optimizedLimbCommitmentRoots,
                maxActiveLimbCount: maxActiveLimbCount,
                totalActiveDigitSlotCount: totalActiveDigitSlotCount,
                totalActivePaddedSlotCount: totalActivePaddedSlotCount,
                totalFixedPaddedSlotCount: totalFixedPaddedSlotCount,
                totalSkippedFixedLimbCount: totalSkippedFixedLimbCount,
                totalActiveRotationTerms: totalActiveRotationTerms,
                totalSmallCoefficientScalings: totalSmallCoefficientScalings,
                totalFullWidthCoefficientScalings: totalFullWidthCoefficientScalings
            )
            + evidenceDigest.superNeoBytes
    }

    public func hasValidDigest() -> Bool {
        evidenceDigest == Self.computeEvidenceDigest(
            version: version,
            profileID: profileID,
            witnessCount: witnessCount,
            directCommitmentDigests: directCommitmentDigests,
            recomposedCommitmentDigests: recomposedCommitmentDigests,
            optimizedLimbCommitmentRoots: optimizedLimbCommitmentRoots,
            maxActiveLimbCount: maxActiveLimbCount,
            totalActiveDigitSlotCount: totalActiveDigitSlotCount,
            totalActivePaddedSlotCount: totalActivePaddedSlotCount,
            totalFixedPaddedSlotCount: totalFixedPaddedSlotCount,
            totalSkippedFixedLimbCount: totalSkippedFixedLimbCount,
            totalActiveRotationTerms: totalActiveRotationTerms,
            totalSmallCoefficientScalings: totalSmallCoefficientScalings,
            totalFullWidthCoefficientScalings: totalFullWidthCoefficientScalings
        )
    }

    private static func limbCommitmentRoot(_ commitments: [AjtaiCommitment]) -> Digest256 {
        Digest256.hash(
            Array("SuperNeo-NuMetal.pay-per-bit.limb-commitment-root.v1".utf8)
                + payPerBitEncodeCount(commitments.count)
                + commitments.flatMap { Digest256.hash($0.superNeoBytes).superNeoBytes }
        )
    }

    private static func computeEvidenceDigest(
        version: UInt16,
        profileID: UInt16,
        witnessCount: Int,
        directCommitmentDigests: [Digest256],
        recomposedCommitmentDigests: [Digest256],
        optimizedLimbCommitmentRoots: [Digest256],
        maxActiveLimbCount: Int,
        totalActiveDigitSlotCount: Int,
        totalActivePaddedSlotCount: Int,
        totalFixedPaddedSlotCount: Int,
        totalSkippedFixedLimbCount: Int,
        totalActiveRotationTerms: Int,
        totalSmallCoefficientScalings: Int,
        totalFullWidthCoefficientScalings: Int
    ) -> Digest256 {
        Digest256.hash(
            Self.domain.superNeoBytes
                + bodyBytes(
                    version: version,
                    profileID: profileID,
                    witnessCount: witnessCount,
                    directCommitmentDigests: directCommitmentDigests,
                    recomposedCommitmentDigests: recomposedCommitmentDigests,
                    optimizedLimbCommitmentRoots: optimizedLimbCommitmentRoots,
                    maxActiveLimbCount: maxActiveLimbCount,
                    totalActiveDigitSlotCount: totalActiveDigitSlotCount,
                    totalActivePaddedSlotCount: totalActivePaddedSlotCount,
                    totalFixedPaddedSlotCount: totalFixedPaddedSlotCount,
                    totalSkippedFixedLimbCount: totalSkippedFixedLimbCount,
                    totalActiveRotationTerms: totalActiveRotationTerms,
                    totalSmallCoefficientScalings: totalSmallCoefficientScalings,
                    totalFullWidthCoefficientScalings: totalFullWidthCoefficientScalings
                )
        )
    }

    private static func bodyBytes(
        version: UInt16,
        profileID: UInt16,
        witnessCount: Int,
        directCommitmentDigests: [Digest256],
        recomposedCommitmentDigests: [Digest256],
        optimizedLimbCommitmentRoots: [Digest256],
        maxActiveLimbCount: Int,
        totalActiveDigitSlotCount: Int,
        totalActivePaddedSlotCount: Int,
        totalFixedPaddedSlotCount: Int,
        totalSkippedFixedLimbCount: Int,
        totalActiveRotationTerms: Int,
        totalSmallCoefficientScalings: Int,
        totalFullWidthCoefficientScalings: Int
    ) -> [UInt8] {
        payPerBitEncodeUInt16(version)
            + payPerBitEncodeUInt16(profileID)
            + payPerBitEncodeCount(witnessCount)
            + payPerBitEncodeCount(directCommitmentDigests.count)
            + directCommitmentDigests.flatMap(\.superNeoBytes)
            + payPerBitEncodeCount(recomposedCommitmentDigests.count)
            + recomposedCommitmentDigests.flatMap(\.superNeoBytes)
            + payPerBitEncodeCount(optimizedLimbCommitmentRoots.count)
            + optimizedLimbCommitmentRoots.flatMap(\.superNeoBytes)
            + payPerBitEncodeCount(maxActiveLimbCount)
            + payPerBitEncodeCount(totalActiveDigitSlotCount)
            + payPerBitEncodeCount(totalActivePaddedSlotCount)
            + payPerBitEncodeCount(totalFixedPaddedSlotCount)
            + payPerBitEncodeCount(totalSkippedFixedLimbCount)
            + payPerBitEncodeCount(totalActiveRotationTerms)
            + payPerBitEncodeCount(totalSmallCoefficientScalings)
            + payPerBitEncodeCount(totalFullWidthCoefficientScalings)
    }
}

public enum SuperNeoPayPerBitCommitter {
    public static func decompositionPlan(
        fieldVector: [GoldilocksField],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPayPerBitDecompositionPlan {
        guard !fieldVector.isEmpty else {
            throw SuperNeoError.invalidParameter("pay-per-bit commitment requires a nonempty field vector")
        }
        guard parameters.normBound == 2 else {
            throw SuperNeoError.invalidParameter("pay-per-bit optimized commitment currently requires base-2 decomposition")
        }
        let paddedLength = SuperNeoEmbedding.paddedLength(forFieldElementCount: fieldVector.count)
        let activeLimbCount = try activeBinaryLimbCount(fieldVector, parameters: parameters)
        var limbs = Array(
            repeating: Array(repeating: GoldilocksField.zero, count: fieldVector.count),
            count: activeLimbCount
        )
        var activeDigitSlotCount = 0
        for (valueIndex, value) in fieldVector.enumerated() {
            var magnitude = SuperNeoPayPerBitProfileEvaluation.signedMagnitude(value)
            let sign: GoldilocksField = value.rawValue <= GoldilocksField.modulus / 2 ? .one : -.one
            var limbIndex = 0
            while magnitude > 0 {
                if (magnitude & 1) == 1 {
                    limbs[limbIndex][valueIndex] = sign
                    activeDigitSlotCount += 1
                }
                magnitude >>= 1
                limbIndex += 1
            }
        }
        return SuperNeoPayPerBitDecompositionPlan(
            fieldElementCount: fieldVector.count,
            paddedFieldSlotCount: paddedLength,
            ringColumnCount: paddedLength / CyclotomicRing54.degree,
            activeLimbCount: activeLimbCount,
            fixedLimbCount: parameters.decompositionLength,
            activeDigitSlotCount: activeDigitSlotCount,
            limbs: limbs,
            schedule: .sparsePublic
        )
    }

    public static func constantScheduleDecompositionPlan(
        fieldVector: [GoldilocksField],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPayPerBitDecompositionPlan {
        guard !fieldVector.isEmpty else {
            throw SuperNeoError.invalidParameter("pay-per-bit commitment requires a nonempty field vector")
        }
        guard parameters.normBound == 2 else {
            throw SuperNeoError.invalidParameter("pay-per-bit constant-schedule commitment currently requires base-2 decomposition")
        }
        let paddedLength = SuperNeoEmbedding.paddedLength(forFieldElementCount: fieldVector.count)
        let limbs = try SuperNeoPayPerBitConstantSchedule.splitSignedBase(
            fieldVector,
            base: parameters.normBound,
            count: parameters.decompositionLength
        )
        return SuperNeoPayPerBitDecompositionPlan(
            fieldElementCount: fieldVector.count,
            paddedFieldSlotCount: paddedLength,
            ringColumnCount: paddedLength / CyclotomicRing54.degree,
            activeLimbCount: parameters.decompositionLength,
            fixedLimbCount: parameters.decompositionLength,
            activeDigitSlotCount: paddedLength * parameters.decompositionLength,
            limbs: limbs,
            schedule: .constantSecret
        )
    }

    public static func commitReference(
        key: AjtaiCommitmentKey,
        fieldVector: [GoldilocksField],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPayPerBitCommitmentResult {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("pay-per-bit commitment parameter mismatch")
        }
        let plan = try decompositionPlan(fieldVector: fieldVector, parameters: parameters)
        guard plan.ringColumnCount == key.matrix.columns else {
            throw SuperNeoError.invalidParameter(
                "pay-per-bit packed witness has \(plan.ringColumnCount) ring columns, expected \(key.matrix.columns)"
            )
        }
        let packedLimbs = try plan.limbs.map { try SuperNeoEmbedding.packPadded($0) }
        let sparseLimbs = packedLimbs.map(SparsePackedRingVector.init)
        let workProfiles = try zip(packedLimbs, sparseLimbs).map { packed, sparse in
            sparse.isZero
                ? payPerBitZeroWorkProfile(key: key)
                : try AjtaiCommitter.workProfile(key: key, message: packed)
        }
        let commitments = try zip(packedLimbs, sparseLimbs).map { packed, sparse in
            sparse.isZero
                ? payPerBitZeroCommitment(parameters: parameters)
                : try AjtaiCommitter.commitReference(key: key, message: packed)
        }
        return SuperNeoPayPerBitCommitmentResult(
            plan: plan,
            packedLimbs: packedLimbs,
            commitments: commitments,
            commitmentWorkProfiles: workProfiles
        )
    }

    public static func commitConstantScheduleReference(
        key: AjtaiCommitmentKey,
        fieldVector: [GoldilocksField],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPayPerBitCommitmentResult {
        guard key.parameters == parameters else {
            throw SuperNeoError.invalidParameter("pay-per-bit commitment parameter mismatch")
        }
        let plan = try constantScheduleDecompositionPlan(fieldVector: fieldVector, parameters: parameters)
        guard plan.ringColumnCount == key.matrix.columns else {
            throw SuperNeoError.invalidParameter(
                "pay-per-bit packed witness has \(plan.ringColumnCount) ring columns, expected \(key.matrix.columns)"
            )
        }
        let packedLimbs = try plan.limbs.map { try SuperNeoEmbedding.packPadded($0) }
        let workProfile = payPerBitConstantScheduleWorkProfile(key: key)
        let workProfiles = Array(repeating: workProfile, count: packedLimbs.count)
        let commitments = try packedLimbs.map {
            try AjtaiCommitter.commitConstantWorkReference(key: key, message: $0)
        }
        return SuperNeoPayPerBitCommitmentResult(
            plan: plan,
            packedLimbs: packedLimbs,
            commitments: commitments,
            commitmentWorkProfiles: workProfiles
        )
    }

    public static func recomposeFieldVector(
        _ plan: SuperNeoPayPerBitDecompositionPlan,
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> [GoldilocksField] {
        try validateDecompositionPlan(plan, parameters: parameters)
        let scalars = try binaryScalars(count: plan.activeLimbCount, parameters: parameters)
        var output = Array(repeating: GoldilocksField.zero, count: plan.fieldElementCount)
        for (limbIndex, limb) in plan.limbs.enumerated() {
            let scalar = scalars[limbIndex]
            for valueIndex in limb.indices {
                output[valueIndex] = output[valueIndex] + limb[valueIndex] * scalar
            }
        }
        return output
    }

    public static func recomposeCommitment(
        _ commitments: [AjtaiCommitment],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> AjtaiCommitment {
        guard let first = commitments.first else {
            throw SuperNeoError.invalidParameter("pay-per-bit scalar count is outside the selected profile")
        }
        let rowCount = first.elements.count
        guard rowCount > 0 else {
            throw SuperNeoError.invalidParameter("pay-per-bit commitment row count mismatch")
        }
        guard commitments.allSatisfy({ $0.elements.count == rowCount }) else {
            throw SuperNeoError.invalidParameter("pay-per-bit commitment row count mismatch")
        }
        let scalars = try binaryScalars(count: commitments.count, parameters: parameters)
        var recomposed = first.scaled(by: scalars[0])
        for (commitment, scalar) in zip(commitments.dropFirst(), scalars.dropFirst()) {
            recomposed = recomposed + commitment.scaled(by: scalar)
        }
        return recomposed
    }

    private static func validateDecompositionPlan(
        _ plan: SuperNeoPayPerBitDecompositionPlan,
        parameters: SuperNeoParameters
    ) throws {
        guard plan.fieldElementCount > 0 else {
            throw SuperNeoError.invalidParameter("pay-per-bit decomposition field element count must be positive")
        }
        let expectedPaddedLength = SuperNeoEmbedding.paddedLength(forFieldElementCount: plan.fieldElementCount)
        guard plan.paddedFieldSlotCount == expectedPaddedLength else {
            throw SuperNeoError.invalidParameter("pay-per-bit decomposition padded length mismatch")
        }
        guard plan.ringColumnCount == expectedPaddedLength / CyclotomicRing54.degree else {
            throw SuperNeoError.invalidParameter("pay-per-bit decomposition ring column count mismatch")
        }
        guard plan.fixedLimbCount == parameters.decompositionLength else {
            throw SuperNeoError.invalidParameter("pay-per-bit decomposition fixed limb count mismatch")
        }
        guard plan.activeLimbCount > 0, plan.activeLimbCount <= parameters.decompositionLength else {
            throw SuperNeoError.invalidParameter(
                "pay-per-bit decomposition active limb count is outside the selected profile"
            )
        }
        guard plan.activeLimbCount <= plan.fixedLimbCount else {
            throw SuperNeoError.invalidParameter(
                "pay-per-bit decomposition active limb count is outside the selected profile"
            )
        }
        guard plan.limbs.count == plan.activeLimbCount else {
            throw SuperNeoError.invalidParameter("pay-per-bit decomposition limb count mismatch")
        }

        var sparseActiveDigitSlotCount = 0
        for limb in plan.limbs {
            guard limb.count == plan.fieldElementCount else {
                throw SuperNeoError.invalidParameter("pay-per-bit limb width mismatch")
            }
            for digit in limb {
                guard isSignedBinaryDigit(digit) else {
                    throw SuperNeoError.invalidParameter("pay-per-bit decomposition digit outside signed binary domain")
                }
                if plan.schedule == .sparsePublic, digit != .zero {
                    sparseActiveDigitSlotCount += 1
                }
            }
        }
        switch plan.schedule {
        case .sparsePublic:
            guard plan.activeDigitSlotCount == sparseActiveDigitSlotCount else {
                throw SuperNeoError.invalidParameter("pay-per-bit active digit count mismatch")
            }
        case .constantSecret:
            guard plan.activeLimbCount == plan.fixedLimbCount,
                  plan.activeDigitSlotCount == plan.fixedPaddedSlotCount else {
                throw SuperNeoError.invalidParameter("pay-per-bit constant-schedule accounting mismatch")
            }
        }
    }

    private static func isSignedBinaryDigit(_ value: GoldilocksField) -> Bool {
        value == .zero || value == .one || value == -GoldilocksField.one
    }

    private static func activeBinaryLimbCount(
        _ fieldVector: [GoldilocksField],
        parameters: SuperNeoParameters
    ) throws -> Int {
        var count = 1
        for value in fieldVector {
            count = max(count, SuperNeoPayPerBitProfileEvaluation.signedMagnitudeBitWidth(value))
        }
        guard count <= parameters.decompositionLength else {
            throw SuperNeoError.invalidParameter(
                "pay-per-bit optimized commitment requires \(count) limbs, exceeding profile maximum \(parameters.decompositionLength)"
            )
        }
        return count
    }

    private static func binaryScalars(
        count: Int,
        parameters: SuperNeoParameters
    ) throws -> [GoldilocksField] {
        guard count > 0, count <= parameters.decompositionLength else {
            throw SuperNeoError.invalidParameter("pay-per-bit scalar count is outside the selected profile")
        }
        var scalars: [GoldilocksField] = []
        scalars.reserveCapacity(count)
        var value = GoldilocksField.one
        for _ in 0..<count {
            scalars.append(value)
            value = value + value
        }
        return scalars
    }
}

private func payPerBitEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func payPerBitEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func payPerBitZeroCommitment(parameters: SuperNeoParameters) -> AjtaiCommitment {
    AjtaiCommitment(Array(repeating: .zero, count: parameters.kappa))
}

private func payPerBitZeroWorkProfile(key: AjtaiCommitmentKey) -> AjtaiCommitmentWorkProfile {
    AjtaiCommitmentWorkProfile(
        matrixRows: key.matrix.rows,
        matrixColumns: key.matrix.columns,
        ringDegree: CyclotomicRing54.degree,
        messageCoefficientSlots: key.matrix.columns * CyclotomicRing54.degree,
        nonzeroMessageCoefficients: 0,
        smallMessageCoefficients: 0,
        fullWidthMessageCoefficients: 0,
        activeRotationTerms: 0,
        smallCoefficientScalings: 0,
        fullWidthCoefficientScalings: 0
    )
}

private func payPerBitConstantScheduleWorkProfile(key: AjtaiCommitmentKey) -> AjtaiCommitmentWorkProfile {
    let messageCoefficientSlots = key.matrix.columns * CyclotomicRing54.degree
    let scheduledProducts = key.matrix.rows
        * key.matrix.columns
        * CyclotomicRing54.degree
        * CyclotomicRing54.degree
    return AjtaiCommitmentWorkProfile(
        matrixRows: key.matrix.rows,
        matrixColumns: key.matrix.columns,
        ringDegree: CyclotomicRing54.degree,
        messageCoefficientSlots: messageCoefficientSlots,
        nonzeroMessageCoefficients: messageCoefficientSlots,
        smallMessageCoefficients: 0,
        fullWidthMessageCoefficients: messageCoefficientSlots,
        activeRotationTerms: scheduledProducts,
        smallCoefficientScalings: 0,
        fullWidthCoefficientScalings: scheduledProducts
    )
}
