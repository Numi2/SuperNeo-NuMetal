import Foundation

public struct AjtaiCommitmentKey: Equatable, Sendable {
    public let parameters: SuperNeoParameters
    public let matrix: RingMatrix

    public init(parameters: SuperNeoParameters = .goldilocks, columns: Int, seed: [UInt8]) throws {
        guard columns > 0 else { throw SuperNeoError.invalidParameter("Ajtai key requires at least one column") }
        let elementCount = try checkedAjtaiKeyElementCount(parameters: parameters, columns: columns)
        var rng = DeterministicRNG(seed: seed)
        var elements: [CyclotomicRing54] = []
        elements.reserveCapacity(elementCount)
        for _ in 0..<elementCount {
            let coeffs = (0..<parameters.ringDegree).map { _ in rng.nextField() }
            elements.append(CyclotomicRing54(coeffs))
        }
        self.parameters = parameters
        self.matrix = try RingMatrix(rows: parameters.kappa, columns: columns, elements: elements)
    }

    public init(parameters: SuperNeoParameters = .goldilocks, matrix: RingMatrix) throws {
        guard matrix.rows == parameters.kappa else {
            throw SuperNeoError.invalidParameter("Ajtai matrix row count must equal kappa")
        }
        guard matrix.columns > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai matrix requires at least one column")
        }
        self.parameters = parameters
        self.matrix = matrix
    }

    public var verifierKeyDigest: Digest256 {
        var bytes = Array("SuperNeo-NuMetal.ajtai-verifier-key.v1".utf8)
        bytes.append(contentsOf: ajtaiDigestEncodeUInt16(parameters.profileID))
        bytes.append(contentsOf: ajtaiDigestEncodeUInt64(UInt64(parameters.kappa)))
        bytes.append(contentsOf: ajtaiDigestEncodeUInt64(UInt64(parameters.ringDegree)))
        bytes.append(contentsOf: ajtaiDigestEncodeUInt64(UInt64(parameters.normBound)))
        bytes.append(contentsOf: ajtaiDigestEncodeUInt64(UInt64(parameters.decompositionLength)))
        bytes.append(contentsOf: ajtaiDigestEncodeUInt64(UInt64(matrix.rows)))
        bytes.append(contentsOf: ajtaiDigestEncodeUInt64(UInt64(matrix.columns)))
        bytes.append(contentsOf: matrix.elements.flatMap(\.littleEndianBytes))
        return Digest256.hash(bytes)
    }
}

private func checkedAjtaiKeyElementCount(parameters: SuperNeoParameters, columns: Int) throws -> Int {
    let product = parameters.kappa.multipliedReportingOverflow(by: columns)
    guard !product.overflow else {
        throw SuperNeoError.invalidParameter("Ajtai key dimensions overflow")
    }
    return product.partialValue
}

private func ajtaiDigestEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func ajtaiDigestEncodeUInt64(_ value: UInt64) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

public struct AjtaiCommitment: Equatable, Sendable {
    public var elements: [CyclotomicRing54]

    public init(_ elements: [CyclotomicRing54]) {
        self.elements = elements
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, +)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        combine(lhs, rhs, -)
    }

    public func scaled(by scalar: CyclotomicRing54) -> Self {
        if let baseScalar = scalar.baseFieldScalar {
            return scaled(by: baseScalar)
        }
        return Self(elements.map { scalar * $0 })
    }

    public func scaled(by scalar: GoldilocksField) -> Self {
        return Self(elements.map { $0.scaled(by: scalar) })
    }

    public var littleEndianBytes: [UInt8] {
        elements.flatMap(\.littleEndianBytes)
    }

    private static func combine(
        _ lhs: Self,
        _ rhs: Self,
        _ operation: (CyclotomicRing54, CyclotomicRing54) -> CyclotomicRing54
    ) -> Self {
        let count = max(lhs.elements.count, rhs.elements.count)
        let elements = (0..<count).map { index in
            operation(
                index < lhs.elements.count ? lhs.elements[index] : .zero,
                index < rhs.elements.count ? rhs.elements[index] : .zero
            )
        }
        return Self(elements)
    }
}

public struct AjtaiCommitmentWorkProfile: Equatable, Sendable {
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

    public var skippedZeroMessageCoefficients: Int {
        messageCoefficientSlots - nonzeroMessageCoefficients
    }

    public var usesOnlySmallCoefficientScalings: Bool {
        fullWidthCoefficientScalings == 0
    }
}

public struct AjtaiMatvecSchedule: Equatable, Sendable {
    public static let `default` = AjtaiMatvecSchedule(
        uncheckedColumnTileSize: 8,
        uncheckedRowTileSize: SuperNeoParameters.goldilocks.kappa,
        uncheckedMaxBatchSize: 16,
        uncheckedKernel: .coefficient
    )

    public let columnTileSize: Int
    public let rowTileSize: Int
    public let maxBatchSize: Int
    public let kernel: AjtaiMatvecKernel

    public init(
        columnTileSize: Int = 8,
        rowTileSize: Int = SuperNeoParameters.goldilocks.kappa,
        maxBatchSize: Int = 16,
        kernel: AjtaiMatvecKernel = .coefficient
    ) throws {
        guard columnTileSize > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai column tile size must be positive")
        }
        guard rowTileSize > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai row tile size must be positive")
        }
        guard maxBatchSize > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai max batch size must be positive")
        }
        self.columnTileSize = columnTileSize
        self.rowTileSize = rowTileSize
        self.maxBatchSize = maxBatchSize
        self.kernel = kernel
    }

    public func planned(for key: AjtaiCommitmentKey, messageCount: Int) -> Self {
        let boundedColumns = max(1, min(columnTileSize, key.matrix.columns))
        let boundedRows = max(1, min(rowTileSize, key.matrix.rows))
        let boundedBatch = max(1, min(maxBatchSize, max(1, messageCount)))
        return AjtaiMatvecSchedule(
            uncheckedColumnTileSize: boundedColumns,
            uncheckedRowTileSize: boundedRows,
            uncheckedMaxBatchSize: boundedBatch,
            uncheckedKernel: kernel
        )
    }

    private init(
        uncheckedColumnTileSize: Int,
        uncheckedRowTileSize: Int,
        uncheckedMaxBatchSize: Int,
        uncheckedKernel: AjtaiMatvecKernel
    ) {
        self.columnTileSize = uncheckedColumnTileSize
        self.rowTileSize = uncheckedRowTileSize
        self.maxBatchSize = uncheckedMaxBatchSize
        self.kernel = uncheckedKernel
    }
}

public enum AjtaiMatvecKernel: Equatable, Sendable {
    case coefficient
    case tiled
}

public enum AjtaiMatvecScheduler {
    public static func commit(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54],
        context: MetalExecutionContext,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> AjtaiCommitment {
        guard let commitment = try commitBatch(
            key: key,
            messages: [message],
            context: context,
            schedule: schedule
        ).first else {
            throw SuperNeoError.invalidParameter("Ajtai scheduler produced no commitment")
        }
        return commitment
    }

    public static func commit(
        key: AjtaiCommitmentKey,
        fieldWitness: [GoldilocksField],
        context: MetalExecutionContext,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> AjtaiCommitment {
        try commit(
            key: key,
            message: packFieldWitness(fieldWitness, key: key),
            context: context,
            schedule: schedule
        )
    }

    public static func commitBatch(
        key: AjtaiCommitmentKey,
        messages: [[CyclotomicRing54]],
        context: MetalExecutionContext,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> [AjtaiCommitment] {
        try SuperNeoMetalBackend(context: context).ajtaiCommitments(
            key: key,
            messages: messages,
            schedule: schedule
        )
    }

    public static func commitBatch(
        key: AjtaiCommitmentKey,
        fieldWitnesses: [[GoldilocksField]],
        context: MetalExecutionContext,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> [AjtaiCommitment] {
        let messages = try fieldWitnesses.map { try packFieldWitness($0, key: key) }
        return try commitBatch(
            key: key,
            messages: messages,
            context: context,
            schedule: schedule
        )
    }

    public static func foldMessages(
        _ messages: [[CyclotomicRing54]],
        challenges: [CyclotomicRing54]
    ) throws -> [CyclotomicRing54] {
        guard let first = messages.first else {
            throw SuperNeoError.invalidParameter("cannot fold zero Ajtai messages")
        }
        guard messages.count == challenges.count else {
            throw SuperNeoError.invalidParameter("Ajtai fold challenge count mismatch")
        }
        var folded = Array(repeating: CyclotomicRing54.zero, count: first.count)
        for (challenge, message) in zip(challenges, messages) {
            guard message.count == folded.count else {
                throw SuperNeoError.invalidParameter("Ajtai fold message lengths must match")
            }
            for index in message.indices {
                folded[index] = folded[index] + challenge * message[index]
            }
        }
        return folded
    }

    public static func foldFieldWitnesses(
        key: AjtaiCommitmentKey,
        fieldWitnesses: [[GoldilocksField]],
        challenges: [CyclotomicRing54]
    ) throws -> [CyclotomicRing54] {
        let messages = try fieldWitnesses.map { try packFieldWitness($0, key: key) }
        return try foldMessages(messages, challenges: challenges)
    }

    public static func foldAndCommit(
        key: AjtaiCommitmentKey,
        fieldWitnesses: [[GoldilocksField]],
        challenges: [CyclotomicRing54],
        context: MetalExecutionContext,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> AjtaiCommitment {
        let folded = try foldFieldWitnesses(
            key: key,
            fieldWitnesses: fieldWitnesses,
            challenges: challenges
        )
        return try commit(
            key: key,
            message: folded,
            context: context,
            schedule: schedule
        )
    }

    fileprivate static func packFieldWitness(
        _ fieldWitness: [GoldilocksField],
        key: AjtaiCommitmentKey
    ) throws -> [CyclotomicRing54] {
        let packed = try SuperNeoEmbedding.packPadded(fieldWitness)
        guard packed.count == key.matrix.columns else {
            throw SuperNeoError.invalidParameter(
                "Ajtai packed witness has \(packed.count) ring columns, expected \(key.matrix.columns)"
            )
        }
        return packed
    }
}

public enum AjtaiCommitter {
    public static func workProfile(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54]
    ) throws -> AjtaiCommitmentWorkProfile {
        guard message.count == key.matrix.columns else {
            throw SuperNeoError.invalidParameter("ring matrix/vector dimension mismatch")
        }

        let messageTerms = message.map(nonzeroTerms)
        let nonzeroMessageCoefficients = messageTerms.reduce(0) { $0 + $1.count }
        let smallMessageCoefficients = messageTerms.reduce(0) { partial, terms in
            partial + terms.filter(\.isSmall).count
        }
        let fullWidthMessageCoefficients = nonzeroMessageCoefficients - smallMessageCoefficients
        var activeRotationTerms = 0
        var smallCoefficientScalings = 0
        var fullWidthCoefficientScalings = 0

        for row in 0..<key.matrix.rows {
            let rowStart = row * key.matrix.columns
            for column in 0..<key.matrix.columns {
                let nonzeroMatrixCoefficients = key.matrix.elements[rowStart + column].coefficients.reduce(0) {
                    $0 + ($1 == .zero ? 0 : 1)
                }
                guard nonzeroMatrixCoefficients > 0 else { continue }
                for term in messageTerms[column] {
                    activeRotationTerms += 1
                    if term.isSmall {
                        smallCoefficientScalings += nonzeroMatrixCoefficients
                    } else {
                        fullWidthCoefficientScalings += nonzeroMatrixCoefficients
                    }
                }
            }
        }

        return AjtaiCommitmentWorkProfile(
            matrixRows: key.matrix.rows,
            matrixColumns: key.matrix.columns,
            ringDegree: CyclotomicRing54.degree,
            messageCoefficientSlots: message.count * CyclotomicRing54.degree,
            nonzeroMessageCoefficients: nonzeroMessageCoefficients,
            smallMessageCoefficients: smallMessageCoefficients,
            fullWidthMessageCoefficients: fullWidthMessageCoefficients,
            activeRotationTerms: activeRotationTerms,
            smallCoefficientScalings: smallCoefficientScalings,
            fullWidthCoefficientScalings: fullWidthCoefficientScalings
        )
    }

    public static func commit(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54],
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> AjtaiCommitment {
        try SuperNeoBenchmarkSignpost.measure("commit") {
            if let context {
                return try AjtaiMatvecScheduler.commit(
                    key: key,
                    message: message,
                    context: context,
                    schedule: schedule
                )
            }
            return try commitReference(key: key, message: message)
        }
    }

    public static func commit(
        key: AjtaiCommitmentKey,
        fieldWitness: [GoldilocksField],
        context: MetalExecutionContext? = nil,
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> AjtaiCommitment {
        try SuperNeoBenchmarkSignpost.measure("commit") {
            if let context {
                return try AjtaiMatvecScheduler.commit(
                    key: key,
                    fieldWitness: fieldWitness,
                    context: context,
                    schedule: schedule
                )
            }
            return try commitReference(key: key, fieldWitness: fieldWitness)
        }
    }

    public static func commitReference(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54]
    ) throws -> AjtaiCommitment {
        AjtaiCommitment(try fusedCommitmentRows(matrix: key.matrix, message: message))
    }

    public static func commitConstantWorkReference(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54]
    ) throws -> AjtaiCommitment {
        AjtaiCommitment(try fusedConstantWorkCommitmentRows(matrix: key.matrix, message: message))
    }

    public static func commitReference(
        key: AjtaiCommitmentKey,
        fieldWitness: [GoldilocksField]
    ) throws -> AjtaiCommitment {
        try commitReference(
            key: key,
            message: AjtaiMatvecScheduler.packFieldWitness(fieldWitness, key: key)
        )
    }

    public static func commitConstantWorkReference(
        key: AjtaiCommitmentKey,
        fieldWitness: [GoldilocksField]
    ) throws -> AjtaiCommitment {
        try commitConstantWorkReference(
            key: key,
            message: AjtaiMatvecScheduler.packFieldWitness(fieldWitness, key: key)
        )
    }

    private static func fusedCommitmentRows(
        matrix: RingMatrix,
        message: [CyclotomicRing54]
    ) throws -> [CyclotomicRing54] {
        guard message.count == matrix.columns else {
            throw SuperNeoError.invalidParameter("ring matrix/vector dimension mismatch")
        }
        let messageTerms = message.map(nonzeroTerms)
        var output: [CyclotomicRing54] = []
        output.reserveCapacity(matrix.rows)
        for row in 0..<matrix.rows {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            let rowStart = row * matrix.columns
            for column in 0..<matrix.columns {
                accumulateProduct(
                    matrix.elements[rowStart + column],
                    rhsTerms: messageTerms[column],
                    into: &coefficients
                )
            }
            output.append(CyclotomicRing54(coefficients))
        }
        return output
    }

    private static func fusedConstantWorkCommitmentRows(
        matrix: RingMatrix,
        message: [CyclotomicRing54]
    ) throws -> [CyclotomicRing54] {
        guard message.count == matrix.columns else {
            throw SuperNeoError.invalidParameter("ring matrix/vector dimension mismatch")
        }
        var output: [CyclotomicRing54] = []
        output.reserveCapacity(matrix.rows)
        for row in 0..<matrix.rows {
            var coefficients = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
            let rowStart = row * matrix.columns
            for column in 0..<matrix.columns {
                accumulateConstantWorkProduct(
                    matrix.elements[rowStart + column],
                    rhs: message[column],
                    into: &coefficients
                )
            }
            output.append(CyclotomicRing54(coefficients))
        }
        return output
    }

    private static func nonzeroTerms(_ value: CyclotomicRing54) -> [(index: Int, value: GoldilocksField, isSmall: Bool)] {
        var terms: [(index: Int, value: GoldilocksField, isSmall: Bool)] = []
        terms.reserveCapacity(CyclotomicRing54.degree)
        for index in 0..<CyclotomicRing54.degree {
            let coefficient = value.coefficients[index]
            if coefficient != .zero {
                terms.append((index, coefficient, isSmallCoefficient(coefficient)))
            }
        }
        return terms
    }

    private static func accumulateProduct(
        _ lhs: CyclotomicRing54,
        rhsTerms: [(index: Int, value: GoldilocksField, isSmall: Bool)],
        into coefficients: inout [GoldilocksField]
    ) {
        guard !rhsTerms.isEmpty else { return }
        for leftIndex in 0..<CyclotomicRing54.degree {
            let left = lhs.coefficients[leftIndex]
            if left == .zero { continue }
            for term in rhsTerms {
                let product = scaleBySmallOrFull(left, by: term.value)
                if product == .zero { continue }
                let exponent = leftIndex + term.index
                if exponent < CyclotomicRing54.degree {
                    coefficients[exponent] = coefficients[exponent] + product
                } else if exponent < CyclotomicRing54.degree + 27 {
                    let reduced = exponent - CyclotomicRing54.degree
                    coefficients[reduced] = coefficients[reduced] - product
                    coefficients[exponent - 27] = coefficients[exponent - 27] - product
                } else {
                    let reduced = exponent - CyclotomicRing54.degree - 27
                    coefficients[reduced] = coefficients[reduced] + product
                }
            }
        }
    }

    private static func accumulateConstantWorkProduct(
        _ lhs: CyclotomicRing54,
        rhs: CyclotomicRing54,
        into coefficients: inout [GoldilocksField]
    ) {
        for leftIndex in 0..<CyclotomicRing54.degree {
            let left = lhs.coefficients[leftIndex]
            for rightIndex in 0..<CyclotomicRing54.degree {
                accumulateReducedProduct(
                    left * rhs.coefficients[rightIndex],
                    exponent: leftIndex + rightIndex,
                    into: &coefficients
                )
            }
        }
    }

    private static func accumulateReducedProduct(
        _ value: GoldilocksField,
        exponent: Int,
        into coefficients: inout [GoldilocksField]
    ) {
        if exponent < CyclotomicRing54.degree {
            coefficients[exponent] = coefficients[exponent] + value
        } else if exponent < CyclotomicRing54.degree + 27 {
            let reduced = exponent - CyclotomicRing54.degree
            coefficients[reduced] = coefficients[reduced] - value
            coefficients[exponent - 27] = coefficients[exponent - 27] - value
        } else {
            let reduced = exponent - CyclotomicRing54.degree - 27
            coefficients[reduced] = coefficients[reduced] + value
        }
    }

    private static func isSmallCoefficient(_ value: GoldilocksField) -> Bool {
        value == .one
            || value == GoldilocksField(2)
            || value == -GoldilocksField.one
            || value == -GoldilocksField(2)
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
