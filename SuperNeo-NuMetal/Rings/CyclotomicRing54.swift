import Foundation

public struct CyclotomicRing54: Equatable, Hashable, Sendable {
    public static let degree = 54
    public var coefficients: [GoldilocksField]

    public init(_ coefficients: [GoldilocksField]) {
        if coefficients.count == Self.degree {
            self.coefficients = coefficients
        } else if coefficients.count < Self.degree {
            self.coefficients = coefficients + Array(repeating: .zero, count: Self.degree - coefficients.count)
        } else {
            self.coefficients = Self.reduce(coefficients)
        }
    }

    public static let zero = CyclotomicRing54([])
    public static let one = CyclotomicRing54([.one])

    public subscript(index: Int) -> GoldilocksField {
        get { coefficients[index] }
        set { coefficients[index] = newValue }
    }

    public var constantTerm: GoldilocksField { coefficients[0] }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(zip(lhs.coefficients, rhs.coefficients).map(+))
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(zip(lhs.coefficients, rhs.coefficients).map(-))
    }

    public static prefix func - (value: Self) -> Self {
        Self(value.coefficients.map { -$0 })
    }

    public static func * (lhs: Self, rhs: Self) -> Self {
        var product = Array(repeating: GoldilocksField.zero, count: degree * 2 - 1)
        for i in 0..<degree {
            for j in 0..<degree {
                product[i + j] = product[i + j] + lhs.coefficients[i] * rhs.coefficients[j]
            }
        }
        return Self(Self.reduce(product))
    }

    public func scaled(by scalar: GoldilocksField) -> Self {
        Self(coefficients.map { $0 * scalar })
    }

    public func infinityNorm() -> UInt64 {
        coefficients.map { value in
            let raw = value.rawValue
            let half = GoldilocksField.modulus / 2
            return raw <= half ? raw : GoldilocksField.modulus - raw
        }.max() ?? 0
    }

    public var littleEndianBytes: [UInt8] {
        coefficients.flatMap(\.littleEndianBytes)
    }

    public init(littleEndianBytes bytes: [UInt8]) throws {
        guard bytes.count == Self.degree * 8 else {
            throw SuperNeoError.invalidEncoding("ring element must be \(Self.degree * 8) bytes")
        }
        var coeffs: [GoldilocksField] = []
        coeffs.reserveCapacity(Self.degree)
        for offset in stride(from: 0, to: bytes.count, by: 8) {
            coeffs.append(try GoldilocksField(littleEndianBytes: bytes[offset..<offset + 8]))
        }
        self.coefficients = coeffs
    }

    static func reduce(_ input: [GoldilocksField]) -> [GoldilocksField] {
        var work = input
        if work.count < degree { work += Array(repeating: .zero, count: degree - work.count) }
        if work.count == degree { return work }
        for exponent in stride(from: work.count - 1, through: degree, by: -1) {
            let value = work[exponent]
            work[exponent] = .zero
            let shifted = exponent - degree
            // X^54 = -X^27 - 1 for Phi(X) = X^54 + X^27 + 1.
            work[shifted] = work[shifted] - value
            work[shifted + 27] = work[shifted + 27] - value
        }
        return Array(work.prefix(degree))
    }

    public static func innerProductTransform(_ vector: [GoldilocksField]) throws -> [GoldilocksField] {
        guard vector.count == degree else {
            throw SuperNeoError.invalidParameter("inner-product transform requires \(degree) coefficients")
        }
        let basis = try dualBasis.get()
        var output = Array(repeating: GoldilocksField.zero, count: degree)
        for (index, scalar) in vector.enumerated() {
            for coeff in 0..<degree {
                output[coeff] = output[coeff] + scalar * basis[index][coeff]
            }
        }
        return output
    }

    private static let dualBasis: Result<[[GoldilocksField]], SuperNeoError> = {
        var gram = Array(repeating: Array(repeating: GoldilocksField.zero, count: degree), count: degree)
        for row in 0..<degree {
            for column in 0..<degree {
                gram[row][column] = reducedMonomialConstant(exponent: row + column)
            }
        }
        do {
            return .success(try invert(gram))
        } catch let error as SuperNeoError {
            return .failure(error)
        } catch {
            return .failure(.invalidParameter("\(error)"))
        }
    }()

    private static func reducedMonomialConstant(exponent: Int) -> GoldilocksField {
        var polynomial = Array(repeating: GoldilocksField.zero, count: exponent + 1)
        polynomial[exponent] = .one
        return reduce(polynomial)[0]
    }

    private static func invert(_ matrix: [[GoldilocksField]]) throws -> [[GoldilocksField]] {
        var augmented = Array(repeating: Array(repeating: GoldilocksField.zero, count: degree * 2), count: degree)
        for row in 0..<degree {
            for column in 0..<degree {
                augmented[row][column] = matrix[row][column]
            }
            augmented[row][degree + row] = .one
        }

        for pivot in 0..<degree {
            guard let nonZero = (pivot..<degree).first(where: { augmented[$0][pivot] != .zero }) else {
                throw SuperNeoError.invalidParameter("constant-term pairing matrix must be invertible")
            }
            if nonZero != pivot {
                augmented.swapAt(pivot, nonZero)
            }

            let pivotValue = augmented[pivot][pivot]
            let inverse = try pivotValue.inverse()
            for column in 0..<(degree * 2) {
                augmented[pivot][column] = augmented[pivot][column] * inverse
            }

            for row in 0..<degree where row != pivot {
                let factor = augmented[row][pivot]
                if factor == .zero { continue }
                for column in 0..<(degree * 2) {
                    augmented[row][column] = augmented[row][column] - factor * augmented[pivot][column]
                }
            }
        }

        return augmented.map { Array($0[degree..<(degree * 2)]) }
    }
}

public struct CyclotomicExt2Ring54: Equatable, Hashable, Sendable {
    public static let degree = CyclotomicRing54.degree
    public var coefficients: [GoldilocksExt2]

    public init(_ coefficients: [GoldilocksExt2]) {
        if coefficients.count == Self.degree {
            self.coefficients = coefficients
        } else if coefficients.count < Self.degree {
            self.coefficients = coefficients + Array(repeating: .zero, count: Self.degree - coefficients.count)
        } else {
            self.coefficients = Self.reduce(coefficients)
        }
    }

    public init(baseRing: CyclotomicRing54) {
        self.init(baseRing.coefficients.map { GoldilocksExt2($0) })
    }

    public static let zero = CyclotomicExt2Ring54([])
    public static let one = CyclotomicExt2Ring54([.one])

    public subscript(index: Int) -> GoldilocksExt2 {
        get { coefficients[index] }
        set { coefficients[index] = newValue }
    }

    public var constantTerm: GoldilocksExt2 { coefficients[0] }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(zip(lhs.coefficients, rhs.coefficients).map(+))
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(zip(lhs.coefficients, rhs.coefficients).map(-))
    }

    public static prefix func - (value: Self) -> Self {
        Self(value.coefficients.map { -$0 })
    }

    public static func * (lhs: CyclotomicRing54, rhs: Self) -> Self {
        var product = Array(repeating: GoldilocksExt2.zero, count: degree * 2 - 1)
        for i in 0..<degree {
            let left = GoldilocksExt2(lhs.coefficients[i])
            for j in 0..<degree {
                product[i + j] = product[i + j] + left * rhs.coefficients[j]
            }
        }
        return Self(Self.reduce(product))
    }

    public static func * (lhs: Self, rhs: CyclotomicRing54) -> Self {
        rhs * lhs
    }

    public var littleEndianBytes: [UInt8] {
        coefficients.flatMap(\.littleEndianBytes)
    }

    public init(littleEndianBytes bytes: [UInt8]) throws {
        guard bytes.count == Self.degree * 16 else {
            throw SuperNeoError.invalidEncoding("extension-ring element must be \(Self.degree * 16) bytes")
        }
        var coeffs: [GoldilocksExt2] = []
        coeffs.reserveCapacity(Self.degree)
        for offset in stride(from: 0, to: bytes.count, by: 16) {
            coeffs.append(try GoldilocksExt2(littleEndianBytes: bytes[offset..<offset + 16]))
        }
        self.coefficients = coeffs
    }

    private static func reduce(_ input: [GoldilocksExt2]) -> [GoldilocksExt2] {
        var work = input
        if work.count < degree { work += Array(repeating: .zero, count: degree - work.count) }
        if work.count == degree { return work }
        for exponent in stride(from: work.count - 1, through: degree, by: -1) {
            let value = work[exponent]
            work[exponent] = .zero
            let shifted = exponent - degree
            work[shifted] = work[shifted] - value
            work[shifted + 27] = work[shifted + 27] - value
        }
        return Array(work.prefix(degree))
    }
}

public struct SuperNeoParameters: Equatable, Sendable {
    public static let goldilocks = SuperNeoParameters()
    public let profileID: UInt16 = 1
    public let ringDegree = 54
    public let kappa = 18
    public let normBound = 2
    public let normRoots: [GoldilocksField] = [-.one, .zero, .one]
    public let decompositionLength = 14
    public let challengeCoefficients: [Int8] = [-2, -1, 0, 1, 2]
    public let challengeExpansionFactor = 216
    public let maxFreshBatchCount = 61
    public let maxPriorClaimCount = 14
    public let claimedSecurityBits = 129

    public init() {}
}

public struct SuperNeoParameterProfile: Equatable, Sendable {
    public static let goldilocksPhi54 = SuperNeoParameterProfile(
        profileID: SuperNeoParameters.goldilocks.profileID,
        name: "Goldilocks/Phi54",
        parameters: .goldilocks,
        fieldModulus: GoldilocksField.modulus,
        extensionDegree: 2,
        cyclotomicDegree: CyclotomicRing54.degree,
        cyclotomicRelationCoefficients: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
        normRoots: SuperNeoParameters.goldilocks.normRoots,
        maxFreshBatchCount: SuperNeoParameters.goldilocks.maxFreshBatchCount,
        maxPriorClaimCount: SuperNeoParameters.goldilocks.maxPriorClaimCount,
        claimedSecurityBits: SuperNeoParameters.goldilocks.claimedSecurityBits
    )

    public let profileID: UInt16
    public let name: String
    public let parameters: SuperNeoParameters
    public let fieldModulus: UInt64
    public let extensionDegree: Int
    public let cyclotomicDegree: Int
    public let cyclotomicRelationCoefficients: [Int64]
    public let normRoots: [GoldilocksField]
    public let maxFreshBatchCount: Int
    public let maxPriorClaimCount: Int
    public let claimedSecurityBits: Int
}

public enum SuperNeoEmbedding {
    public static func paddedLength(forFieldElementCount count: Int) -> Int {
        let remainder = count % CyclotomicRing54.degree
        return remainder == 0 ? count : count + CyclotomicRing54.degree - remainder
    }

    public static func packPadded(_ vector: [GoldilocksField]) throws -> [CyclotomicRing54] {
        let paddedLength = paddedLength(forFieldElementCount: vector.count)
        let padded = paddedLength == vector.count
            ? vector
            : vector + Array(repeating: .zero, count: paddedLength - vector.count)
        return try pack(padded)
    }

    public static func pack(_ vector: [GoldilocksField]) throws -> [CyclotomicRing54] {
        guard vector.count % CyclotomicRing54.degree == 0 else {
            throw SuperNeoError.invalidParameter("field vector length must be a multiple of 54")
        }
        return stride(from: 0, to: vector.count, by: CyclotomicRing54.degree).map {
            CyclotomicRing54(Array(vector[$0..<$0 + CyclotomicRing54.degree]))
        }
    }

    public static func unpack(_ vector: [CyclotomicRing54]) -> [GoldilocksField] {
        vector.flatMap(\.coefficients)
    }

    public static func preservesNorm(_ vector: [GoldilocksField]) throws -> Bool {
        let packed = try pack(vector)
        let original = vector.map { value -> UInt64 in
            let raw = value.rawValue
            return raw <= GoldilocksField.modulus / 2 ? raw : GoldilocksField.modulus - raw
        }.max() ?? 0
        let embedded = packed.map { $0.infinityNorm() }.max() ?? 0
        return original == embedded
    }
}

public struct RingMatrix: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    public var elements: [CyclotomicRing54]

    public init(rows: Int, columns: Int, elements: [CyclotomicRing54]) throws {
        guard rows >= 0, columns >= 0 else {
            throw SuperNeoError.invalidParameter("ring matrix dimensions do not match element count")
        }
        let (elementCount, overflow) = rows.multipliedReportingOverflow(by: columns)
        guard !overflow, elements.count == elementCount else {
            throw SuperNeoError.invalidParameter("ring matrix dimensions do not match element count")
        }
        self.rows = rows
        self.columns = columns
        self.elements = elements
    }

    public subscript(row: Int, column: Int) -> CyclotomicRing54 {
        get { elements[row * columns + column] }
        set { elements[row * columns + column] = newValue }
    }

    public func multiplied(by vector: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard vector.count == columns else {
            throw SuperNeoError.invalidParameter("ring matrix/vector dimension mismatch")
        }
        var output = Array(repeating: CyclotomicRing54.zero, count: rows)
        for row in 0..<rows {
            var acc = CyclotomicRing54.zero
            for column in 0..<columns {
                acc = acc + self[row, column] * vector[column]
            }
            output[row] = acc
        }
        return output
    }
}

public struct SparseRingMatrixCSR: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    public let rowOffsets: [Int]
    public let columnIndices: [Int]
    public let values: [CyclotomicRing54]

    public init(
        rows: Int,
        columns: Int,
        rowOffsets: [Int],
        columnIndices: [Int],
        values: [CyclotomicRing54]
    ) throws {
        guard rows >= 0, columns >= 0 else {
            throw SuperNeoError.invalidParameter("sparse ring matrix dimensions must be nonnegative")
        }
        guard rowOffsets.count == rows + 1, rowOffsets.first == 0 else {
            throw SuperNeoError.invalidParameter("sparse ring row offsets must have rows + 1 entries and start at zero")
        }
        guard columnIndices.count == values.count, rowOffsets.last == values.count else {
            throw SuperNeoError.invalidParameter("sparse ring matrix offsets must match value count")
        }
        guard rowOffsets.allSatisfy({ $0 >= 0 && $0 <= values.count }) else {
            throw SuperNeoError.invalidParameter("sparse ring row offsets out of bounds")
        }
        for row in 0..<rows {
            let start = rowOffsets[row]
            let end = rowOffsets[row + 1]
            guard start <= end else {
                throw SuperNeoError.invalidParameter("sparse ring row offsets must be nondecreasing")
            }
            var previousColumn: Int?
            for index in start..<end {
                let column = columnIndices[index]
                guard column >= 0, column < columns else {
                    throw SuperNeoError.invalidParameter("sparse ring column index out of bounds")
                }
                guard values[index] != .zero else {
                    throw SuperNeoError.invalidParameter("sparse ring matrices must omit zero entries")
                }
                if let previousColumn {
                    guard previousColumn < column else {
                        throw SuperNeoError.invalidParameter("sparse ring column indices must be strictly increasing within each row")
                    }
                }
                previousColumn = column
            }
        }
        self.rows = rows
        self.columns = columns
        self.rowOffsets = rowOffsets
        self.columnIndices = columnIndices
        self.values = values
    }

    public init(_ dense: RingMatrix) throws {
        var rowOffsets = [0]
        var columnIndices: [Int] = []
        var values: [CyclotomicRing54] = []
        for row in 0..<dense.rows {
            for column in 0..<dense.columns {
                let value = dense[row, column]
                guard value != .zero else { continue }
                columnIndices.append(column)
                values.append(value)
            }
            rowOffsets.append(columnIndices.count)
        }
        try self.init(
            rows: dense.rows,
            columns: dense.columns,
            rowOffsets: rowOffsets,
            columnIndices: columnIndices,
            values: values
        )
    }

    public func dense() throws -> RingMatrix {
        let (elementCount, overflow) = rows.multipliedReportingOverflow(by: columns)
        guard !overflow else {
            throw SuperNeoError.invalidParameter("sparse ring dense dimensions overflow")
        }
        var elements = Array(repeating: CyclotomicRing54.zero, count: elementCount)
        for row in 0..<rows {
            for index in rowOffsets[row]..<rowOffsets[row + 1] {
                elements[row * columns + columnIndices[index]] = values[index]
            }
        }
        return try RingMatrix(rows: rows, columns: columns, elements: elements)
    }

    public func multiplied(by vector: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard vector.count == columns else {
            throw SuperNeoError.invalidParameter("sparse ring matrix/vector dimension mismatch")
        }
        var output = Array(repeating: CyclotomicRing54.zero, count: rows)
        for row in 0..<rows {
            var acc = CyclotomicRing54.zero
            for index in rowOffsets[row]..<rowOffsets[row + 1] {
                acc = acc + values[index] * vector[columnIndices[index]]
            }
            output[row] = acc
        }
        return output
    }
}
