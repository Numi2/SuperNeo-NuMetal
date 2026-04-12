import Foundation

public struct FieldModulusDescriptor: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let modulusBytesLittleEndian: [UInt8]

    public static let goldilocks = FieldModulusDescriptor(
        uncheckedModulusBytesLittleEndian: withUnsafeBytes(of: GoldilocksField.modulus.littleEndian, Array.init)
    )

    private init(uncheckedModulusBytesLittleEndian: [UInt8]) {
        self.modulusBytesLittleEndian = uncheckedModulusBytesLittleEndian
    }

    public init(modulusBytesLittleEndian: [UInt8]) throws {
        guard !modulusBytesLittleEndian.isEmpty else {
            throw SuperNeoError.invalidParameter("field modulus descriptor cannot be empty")
        }
        self.modulusBytesLittleEndian = modulusBytesLittleEndian
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeCount(modulusBytesLittleEndian.count) + modulusBytesLittleEndian
    }
}

public struct FieldDescriptor: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let modulus: FieldModulusDescriptor
    public let extensionDegree: UInt32

    public static let goldilocksExt2 = FieldDescriptor(uncheckedModulus: .goldilocks, extensionDegree: 2)

    private init(uncheckedModulus modulus: FieldModulusDescriptor, extensionDegree: UInt32) {
        self.modulus = modulus
        self.extensionDegree = extensionDegree
    }

    public init(modulus: FieldModulusDescriptor, extensionDegree: UInt32) throws {
        guard extensionDegree > 0 else {
            throw SuperNeoError.invalidParameter("extension degree must be positive")
        }
        self.modulus = modulus
        self.extensionDegree = extensionDegree
    }

    public var superNeoBytes: [UInt8] {
        modulus.superNeoBytes + ccsEncodeUInt32(extensionDegree)
    }
}

public struct CyclotomicDescriptor: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let degree: UInt32
    public let relationCoefficients: [Int64]

    public static let cyclotomic54 = CyclotomicDescriptor(
        uncheckedDegree: UInt32(CyclotomicRing54.degree),
        relationCoefficients: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    )

    private init(uncheckedDegree degree: UInt32, relationCoefficients: [Int64]) {
        self.degree = degree
        self.relationCoefficients = relationCoefficients
    }

    public init(degree: UInt32, relationCoefficients: [Int64]) throws {
        guard degree > 0 else {
            throw SuperNeoError.invalidParameter("ring degree must be positive")
        }
        guard relationCoefficients.count == Int(degree) + 1 else {
            throw SuperNeoError.invalidParameter("relation polynomial must have degree + 1 coefficients")
        }
        self.degree = degree
        self.relationCoefficients = relationCoefficients
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeUInt32(degree)
            + ccsEncodeCount(relationCoefficients.count)
            + relationCoefficients.flatMap(ccsEncodeInt64)
    }
}

public struct AjtaiDescriptor: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let kappa: UInt32
    public let ringDegree: UInt32
    public let normBound: UInt32
    public let decompositionLength: UInt32

    public static let goldilocks = AjtaiDescriptor(
        uncheckedKappa: UInt32(SuperNeoParameters.goldilocks.kappa),
        ringDegree: UInt32(SuperNeoParameters.goldilocks.ringDegree),
        normBound: UInt32(SuperNeoParameters.goldilocks.normBound),
        decompositionLength: UInt32(SuperNeoParameters.goldilocks.decompositionLength)
    )

    private init(uncheckedKappa kappa: UInt32, ringDegree: UInt32, normBound: UInt32, decompositionLength: UInt32) {
        self.kappa = kappa
        self.ringDegree = ringDegree
        self.normBound = normBound
        self.decompositionLength = decompositionLength
    }

    public init(kappa: UInt32, ringDegree: UInt32, normBound: UInt32, decompositionLength: UInt32) throws {
        guard kappa > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai kappa must be positive")
        }
        guard ringDegree > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai ring degree must be positive")
        }
        guard normBound > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai norm bound must be positive")
        }
        guard decompositionLength > 0 else {
            throw SuperNeoError.invalidParameter("decomposition length must be positive")
        }
        self.kappa = kappa
        self.ringDegree = ringDegree
        self.normBound = normBound
        self.decompositionLength = decompositionLength
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeUInt32(kappa)
            + ccsEncodeUInt32(ringDegree)
            + ccsEncodeUInt32(normBound)
            + ccsEncodeUInt32(decompositionLength)
    }
}

public struct StrongSamplingSetDescriptor: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let coefficientSet: [Int16]
    public let expansionFactor: UInt32

    public static let goldilocks = StrongSamplingSetDescriptor(
        uncheckedCoefficientSet: SuperNeoParameters.goldilocks.challengeCoefficients.map(Int16.init),
        expansionFactor: UInt32(SuperNeoParameters.goldilocks.challengeExpansionFactor)
    )

    private init(uncheckedCoefficientSet: [Int16], expansionFactor: UInt32) {
        self.coefficientSet = uncheckedCoefficientSet
        self.expansionFactor = expansionFactor
    }

    public init(coefficientSet: [Int16], expansionFactor: UInt32) throws {
        guard !coefficientSet.isEmpty else {
            throw SuperNeoError.invalidParameter("challenge coefficient set cannot be empty")
        }
        guard coefficientSet == Array(Set(coefficientSet)).sorted() else {
            throw SuperNeoError.invalidParameter("challenge coefficient set must be canonical")
        }
        guard expansionFactor > 0 else {
            throw SuperNeoError.invalidParameter("challenge expansion factor must be positive")
        }
        self.coefficientSet = coefficientSet
        self.expansionFactor = expansionFactor
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeCount(coefficientSet.count)
            + coefficientSet.flatMap(ccsEncodeInt16)
            + ccsEncodeUInt32(expansionFactor)
    }
}

public struct RelationMonomial: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let coefficient: GoldilocksField
    public let exponents: [UInt16]

    public init(coefficient: GoldilocksField, exponents: [UInt16]) {
        self.coefficient = coefficient
        self.exponents = exponents
    }

    public var totalDegree: Int {
        exponents.reduce(0) { $0 + Int($1) }
    }

    public var superNeoBytes: [UInt8] {
        coefficient.superNeoBytes
            + ccsEncodeCount(exponents.count)
            + exponents.flatMap(ccsEncodeUInt16)
    }
}

public struct RelationPolynomial: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let variableCount: UInt16
    public let monomials: [RelationMonomial]

    public init(variableCount: UInt16, monomials: [RelationMonomial]) throws {
        var byExponent: [[UInt16]: GoldilocksField] = [:]
        for monomial in monomials {
            guard monomial.exponents.count == Int(variableCount) else {
                throw SuperNeoError.invalidParameter("relation monomial exponent count must match variable count")
            }
            guard monomial.coefficient != .zero else { continue }
            byExponent[monomial.exponents, default: .zero] = byExponent[monomial.exponents, default: .zero] + monomial.coefficient
        }
        self.variableCount = variableCount
        self.monomials = byExponent
            .filter { $0.value != .zero }
            .map { RelationMonomial(coefficient: $0.value, exponents: $0.key) }
            .sorted { lhs, rhs in
                lhs.exponents == rhs.exponents
                    ? lhs.coefficient.rawValue < rhs.coefficient.rawValue
                    : lhs.exponents.lexicographicallyPrecedes(rhs.exponents)
            }
    }

    public static func hadamardProduct(variableCount: Int) throws -> Self {
        guard variableCount > 0, variableCount <= Int(UInt16.max) else {
            throw SuperNeoError.invalidParameter("relation variable count out of range")
        }
        return try Self(
            variableCount: UInt16(variableCount),
            monomials: [
                RelationMonomial(
                    coefficient: .one,
                    exponents: Array(repeating: 1, count: variableCount)
                )
            ]
        )
    }

    public var degree: Int {
        monomials.map(\.totalDegree).max() ?? 0
    }

    public func evaluate(_ values: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard values.count == Int(variableCount) else {
            throw SuperNeoError.invalidParameter("relation evaluation arity mismatch")
        }
        var result = GoldilocksExt2.zero
        for monomial in monomials {
            var term = GoldilocksExt2(monomial.coefficient)
            for (value, exponent) in zip(values, monomial.exponents) {
                term = term * pow(value, Int(exponent))
            }
            result = result + term
        }
        return result
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeUInt16(variableCount)
            + ccsEncodeCount(monomials.count)
            + monomials.flatMap(\.superNeoBytes)
    }

    private func pow(_ value: GoldilocksExt2, _ exponent: Int) -> GoldilocksExt2 {
        guard exponent > 0 else { return .one }
        var result = GoldilocksExt2.one
        var base = value
        var exp = exponent
        while exp > 0 {
            if exp & 1 == 1 { result = result * base }
            exp >>= 1
            if exp > 0 { base = base * base }
        }
        return result
    }
}

public struct SparseMatrixCSR: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let rowCount: Int
    public let columnCount: Int
    public let rowOffsets: [Int]
    public let columnIndices: [Int]
    public let values: [GoldilocksField]

    public init(rowCount: Int, columnCount: Int, rowOffsets: [Int], columnIndices: [Int], values: [GoldilocksField]) throws {
        guard rowCount > 0, columnCount > 0 else {
            throw SuperNeoError.invalidParameter("CSR matrix dimensions must be positive")
        }
        guard rowOffsets.count == rowCount + 1, rowOffsets.first == 0 else {
            throw SuperNeoError.invalidParameter("CSR row offsets must have rowCount + 1 entries and start at zero")
        }
        guard columnIndices.count == values.count, rowOffsets.last == values.count else {
            throw SuperNeoError.invalidParameter("CSR matrix offsets must match value count")
        }
        guard rowOffsets.allSatisfy({ $0 >= 0 && $0 <= values.count }) else {
            throw SuperNeoError.invalidParameter("CSR row offsets out of bounds")
        }
        for row in 0..<rowCount {
            let start = rowOffsets[row]
            let end = rowOffsets[row + 1]
            guard start <= end else {
                throw SuperNeoError.invalidParameter("CSR row offsets must be nondecreasing")
            }
            var previousColumn: Int?
            for index in start..<end {
                let column = columnIndices[index]
                guard column >= 0, column < columnCount else {
                    throw SuperNeoError.invalidParameter("CSR column index out of bounds")
                }
                guard values[index] != .zero else {
                    throw SuperNeoError.invalidParameter("CSR matrices must omit zero entries")
                }
                if let previousColumn {
                    guard previousColumn < column else {
                        throw SuperNeoError.invalidParameter("CSR column indices must be strictly increasing within each row")
                    }
                }
                previousColumn = column
            }
        }
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.rowOffsets = rowOffsets
        self.columnIndices = columnIndices
        self.values = values
    }

    public init(_ matrix: SparseFieldMatrix) throws {
        var rows = Array(repeating: [(column: Int, value: GoldilocksField)](), count: matrix.rows)
        for entry in matrix.entries where entry.value != .zero {
            rows[entry.row].append((entry.column, entry.value))
        }
        var rowOffsets = [0]
        var columnIndices: [Int] = []
        var values: [GoldilocksField] = []
        for row in rows {
            var combined: [Int: GoldilocksField] = [:]
            for entry in row {
                combined[entry.column, default: .zero] = combined[entry.column, default: .zero] + entry.value
            }
            for column in combined.keys.sorted() {
                let value = combined[column] ?? .zero
                if value == .zero { continue }
                columnIndices.append(column)
                values.append(value)
            }
            rowOffsets.append(columnIndices.count)
        }
        try self.init(
            rowCount: matrix.rows,
            columnCount: matrix.columns,
            rowOffsets: rowOffsets,
            columnIndices: columnIndices,
            values: values
        )
    }

    public func toSparseFieldMatrix() throws -> SparseFieldMatrix {
        try checkedSparseFieldMatrix()
    }

    fileprivate func uncheckedSparseFieldMatrix() -> SparseFieldMatrix {
        var entries: [SparseFieldMatrix.Entry] = []
        entries.reserveCapacity(values.count)
        for row in 0..<rowCount {
            for index in rowOffsets[row]..<rowOffsets[row + 1] {
                entries.append(
                    SparseFieldMatrix.Entry(row: row, column: columnIndices[index], value: values[index])
                )
            }
        }
        return SparseFieldMatrix(uncheckedRows: rowCount, columns: columnCount, entries: entries)
    }

    private func checkedSparseFieldMatrix() throws -> SparseFieldMatrix {
        try SparseFieldMatrix(
            rows: rowCount,
            columns: columnCount,
            entries: uncheckedSparseFieldMatrix().entries
        )
    }

    public func multiplied(by vector: [GoldilocksField]) throws -> [GoldilocksField] {
        try toSparseFieldMatrix().multiplied(by: vector)
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeCount(rowCount)
            + ccsEncodeCount(columnCount)
            + ccsEncodeCount(rowOffsets.count)
            + rowOffsets.flatMap(ccsEncodeCount)
            + ccsEncodeCount(columnIndices.count)
            + columnIndices.flatMap(ccsEncodeCount)
            + ccsEncodeCount(values.count)
            + values.flatMap(\.superNeoBytes)
    }
}

public struct CCSShape: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public static let currentVersion: UInt32 = 1

    public let version: UInt32
    public let field: FieldDescriptor
    public let cyclotomic: CyclotomicDescriptor
    public let ajtai: AjtaiDescriptor
    public let challenges: StrongSamplingSetDescriptor
    public let m: Int
    public let nField: Int
    public let nRing: Int
    public let nPublicField: Int
    public let numMatrices: Int
    public let relationDegree: Int
    public let matrices: [SparseMatrixCSR]
    public let relationPolynomial: RelationPolynomial
    public let hasIdentityFirstMatrix: Bool
    public let shapeDigest: Digest256

    public init(
        version: UInt32 = Self.currentVersion,
        field: FieldDescriptor = .goldilocksExt2,
        cyclotomic: CyclotomicDescriptor = .cyclotomic54,
        ajtai: AjtaiDescriptor = .goldilocks,
        challenges: StrongSamplingSetDescriptor = .goldilocks,
        m: Int,
        nField: Int,
        nRing: Int,
        nPublicField: Int,
        matrices: [SparseMatrixCSR],
        relationPolynomial: RelationPolynomial,
        hasIdentityFirstMatrix: Bool
    ) throws {
        let relationDegree = relationPolynomial.degree
        try Self.validate(
            version: version,
            field: field,
            cyclotomic: cyclotomic,
            ajtai: ajtai,
            challenges: challenges,
            m: m,
            nField: nField,
            nRing: nRing,
            nPublicField: nPublicField,
            matrices: matrices,
            relationPolynomial: relationPolynomial,
            relationDegree: relationDegree,
            hasIdentityFirstMatrix: hasIdentityFirstMatrix
        )
        self.version = version
        self.field = field
        self.cyclotomic = cyclotomic
        self.ajtai = ajtai
        self.challenges = challenges
        self.m = m
        self.nField = nField
        self.nRing = nRing
        self.nPublicField = nPublicField
        self.numMatrices = matrices.count
        self.relationDegree = relationDegree
        self.matrices = matrices
        self.relationPolynomial = relationPolynomial
        self.hasIdentityFirstMatrix = hasIdentityFirstMatrix
        self.shapeDigest = Digest256.hash(
            Self.bodyBytes(
                version: version,
                field: field,
                cyclotomic: cyclotomic,
                ajtai: ajtai,
                challenges: challenges,
                m: m,
                nField: nField,
                nRing: nRing,
                nPublicField: nPublicField,
                numMatrices: matrices.count,
                relationDegree: relationDegree,
                matrices: matrices,
                relationPolynomial: relationPolynomial,
                hasIdentityFirstMatrix: hasIdentityFirstMatrix
            )
        )
    }

    public static func hadamardProduct(matrices: [SparseFieldMatrix], publicInputCount: Int) throws -> Self {
        try Self(
            matrices: matrices,
            publicInputCount: publicInputCount,
            relationPolynomial: try RelationPolynomial.hadamardProduct(variableCount: matrices.count)
        )
    }

    public init(
        matrices: [SparseFieldMatrix],
        publicInputCount: Int,
        relationPolynomial: RelationPolynomial
    ) throws {
        let csr = try matrices.map(SparseMatrixCSR.init)
        guard let first = csr.first else {
            throw SuperNeoError.invalidParameter("CCS shape requires at least one matrix")
        }
        try self.init(
            m: first.rowCount,
            nField: first.columnCount,
            nRing: (first.columnCount + CyclotomicRing54.degree - 1) / CyclotomicRing54.degree,
            nPublicField: publicInputCount,
            matrices: csr,
            relationPolynomial: relationPolynomial,
            hasIdentityFirstMatrix: csr.first?.isIdentityPrefix == true
        )
    }

    public var structure: CCSStructure {
        CCSStructure(
            matrices: matrices.map { $0.uncheckedSparseFieldMatrix() },
            relationPolynomial: relationPolynomial
        )
    }

    public var superNeoBytes: [UInt8] {
        shapeDigest.superNeoBytes + Self.bodyBytes(
            version: version,
            field: field,
            cyclotomic: cyclotomic,
            ajtai: ajtai,
            challenges: challenges,
            m: m,
            nField: nField,
            nRing: nRing,
            nPublicField: nPublicField,
            numMatrices: numMatrices,
            relationDegree: relationDegree,
            matrices: matrices,
            relationPolynomial: relationPolynomial,
            hasIdentityFirstMatrix: hasIdentityFirstMatrix
        )
    }

    private static func bodyBytes(
        version: UInt32,
        field: FieldDescriptor,
        cyclotomic: CyclotomicDescriptor,
        ajtai: AjtaiDescriptor,
        challenges: StrongSamplingSetDescriptor,
        m: Int,
        nField: Int,
        nRing: Int,
        nPublicField: Int,
        numMatrices: Int,
        relationDegree: Int,
        matrices: [SparseMatrixCSR],
        relationPolynomial: RelationPolynomial,
        hasIdentityFirstMatrix: Bool
    ) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: ccsEncodeUInt32(version))
        bytes.append(contentsOf: field.superNeoBytes)
        bytes.append(contentsOf: cyclotomic.superNeoBytes)
        bytes.append(contentsOf: ajtai.superNeoBytes)
        bytes.append(contentsOf: challenges.superNeoBytes)
        bytes.append(contentsOf: ccsEncodeCount(m))
        bytes.append(contentsOf: ccsEncodeCount(nField))
        bytes.append(contentsOf: ccsEncodeCount(nRing))
        bytes.append(contentsOf: ccsEncodeCount(nPublicField))
        bytes.append(contentsOf: ccsEncodeCount(numMatrices))
        bytes.append(contentsOf: ccsEncodeCount(relationDegree))
        bytes.append(contentsOf: ccsEncodeCount(matrices.count))
        for matrix in matrices {
            bytes.append(contentsOf: matrix.superNeoBytes)
        }
        bytes.append(contentsOf: relationPolynomial.superNeoBytes)
        bytes.append(hasIdentityFirstMatrix ? 1 : 0)
        return bytes
    }

    private static func validate(
        version: UInt32,
        field: FieldDescriptor,
        cyclotomic: CyclotomicDescriptor,
        ajtai: AjtaiDescriptor,
        challenges: StrongSamplingSetDescriptor,
        m: Int,
        nField: Int,
        nRing: Int,
        nPublicField: Int,
        matrices: [SparseMatrixCSR],
        relationPolynomial: RelationPolynomial,
        relationDegree: Int,
        hasIdentityFirstMatrix: Bool
    ) throws {
        guard version == Self.currentVersion else {
            throw SuperNeoError.invalidParameter("unsupported CCS shape version")
        }
        guard field == .goldilocksExt2 else {
            throw SuperNeoError.invalidParameter("CCS shape field descriptor must match GoldilocksExt2")
        }
        guard cyclotomic == .cyclotomic54 else {
            throw SuperNeoError.invalidParameter("CCS shape cyclotomic descriptor must match Phi_54")
        }
        guard ajtai == .goldilocks else {
            throw SuperNeoError.invalidParameter("CCS shape Ajtai descriptor must match Goldilocks profile")
        }
        guard challenges == .goldilocks else {
            throw SuperNeoError.invalidParameter("CCS shape challenge descriptor must match Goldilocks profile")
        }
        guard m > 0, (m & (m - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("CCS row count must be a positive power of two")
        }
        guard nField > 0, nRing > 0, nPublicField >= 0, nPublicField <= nField else {
            throw SuperNeoError.invalidParameter("invalid CCS dimensions")
        }
        guard nRing == (nField + Int(cyclotomic.degree) - 1) / Int(cyclotomic.degree) else {
            throw SuperNeoError.invalidParameter("nRing must be ceil(nField / ringDegree)")
        }
        guard !matrices.isEmpty, matrices.count == Int(relationPolynomial.variableCount) else {
            throw SuperNeoError.invalidParameter("matrix count must match relation polynomial arity")
        }
        guard relationDegree == relationPolynomial.degree else {
            throw SuperNeoError.invalidParameter("relation degree must match relation polynomial")
        }
        for matrix in matrices {
            guard matrix.rowCount == m, matrix.columnCount == nField else {
                throw SuperNeoError.invalidParameter("all CCS matrices must match shape dimensions")
            }
        }
        if hasIdentityFirstMatrix {
            guard matrices[0].isIdentityPrefix else {
                throw SuperNeoError.invalidParameter("first CCS matrix is not the declared identity")
            }
        }
    }
}

public struct CompiledCCSShape: Equatable, Sendable {
    public let shape: CCSShape
    public let transformedMatrices: [RingMatrix]
    public let transformedSparseMatrices: [SparseRingMatrixCSR]

    public init(shape: CCSShape, includeDense: Bool = true, includeSparse: Bool = true) throws {
        guard includeDense || includeSparse else {
            throw SuperNeoError.invalidParameter("compiled CCS shape must include at least one transformed representation")
        }
        let fieldMatrices = try shape.matrices.map { try $0.toSparseFieldMatrix() }
        let transformedMatrices = includeDense
            ? try fieldMatrices.map { try $0.transformedForSuperNeo() }
            : []
        let transformedSparseMatrices = includeSparse
            ? try fieldMatrices.map { try $0.transformedSparseForSuperNeo() }
            : []
        guard !includeDense || transformedMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("compiled CCS shape matrix count mismatch")
        }
        guard !includeSparse || transformedSparseMatrices.count == shape.numMatrices else {
            throw SuperNeoError.invalidParameter("compiled CCS sparse matrix count mismatch")
        }
        self.shape = shape
        self.transformedMatrices = transformedMatrices
        self.transformedSparseMatrices = transformedSparseMatrices
    }
}

extension CCSShape {
    public func compiledForSuperNeo() throws -> CompiledCCSShape {
        try CompiledCCSShape(shape: self)
    }

    public func compiledSparseForSuperNeo() throws -> CompiledCCSShape {
        try CompiledCCSShape(shape: self, includeDense: false, includeSparse: true)
    }

    public func compiledDenseForSuperNeo() throws -> CompiledCCSShape {
        try CompiledCCSShape(shape: self, includeDense: true, includeSparse: false)
    }
}

public struct SparseFieldMatrix: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let row: Int
        public let column: Int
        public let value: GoldilocksField

        public init(row: Int, column: Int, value: GoldilocksField) {
            self.row = row
            self.column = column
            self.value = value
        }
    }

    public let rows: Int
    public let columns: Int
    public var entries: [Entry]

    public init(rows: Int, columns: Int, entries: [Entry]) throws {
        guard rows > 0, columns > 0 else { throw SuperNeoError.invalidParameter("matrix dimensions must be positive") }
        for entry in entries {
            guard entry.row >= 0, entry.row < rows, entry.column >= 0, entry.column < columns else {
                throw SuperNeoError.invalidParameter("sparse matrix entry out of bounds")
            }
        }
        self.rows = rows
        self.columns = columns
        self.entries = entries
    }

    fileprivate init(uncheckedRows rows: Int, columns: Int, entries: [Entry]) {
        self.rows = rows
        self.columns = columns
        self.entries = entries
    }

    public static func identity(size: Int) throws -> Self {
        try Self(rows: size, columns: size, entries: (0..<size).map { Entry(row: $0, column: $0, value: .one) })
    }

    public func multiplied(by vector: [GoldilocksField]) throws -> [GoldilocksField] {
        guard vector.count == columns else { throw SuperNeoError.invalidParameter("field matrix/vector mismatch") }
        var output = Array(repeating: GoldilocksField.zero, count: rows)
        for entry in entries {
            output[entry.row] = output[entry.row] + entry.value * vector[entry.column]
        }
        return output
    }

    public func transformedForSuperNeo() throws -> RingMatrix {
        let ringColumns = (columns + CyclotomicRing54.degree - 1) / CyclotomicRing54.degree
        let (elementCount, overflow) = rows.multipliedReportingOverflow(by: ringColumns)
        guard !overflow else {
            throw SuperNeoError.invalidParameter("transformed matrix dimensions overflow")
        }
        var elements = Array(repeating: CyclotomicRing54.zero, count: elementCount)
        for entry in entries {
            let ringColumn = entry.column / CyclotomicRing54.degree
            let coeff = entry.column % CyclotomicRing54.degree
            var current = elements[entry.row * ringColumns + ringColumn]
            current = current + CyclotomicRing54(try CyclotomicRing54.innerProductTransform(unitVector(index: coeff, value: entry.value)))
            elements[entry.row * ringColumns + ringColumn] = current
        }
        return try RingMatrix(rows: rows, columns: ringColumns, elements: elements)
    }

    public func transformedSparseForSuperNeo() throws -> SparseRingMatrixCSR {
        let ringColumns = (columns + CyclotomicRing54.degree - 1) / CyclotomicRing54.degree
        var rowValues = Array(repeating: [Int: CyclotomicRing54](), count: rows)
        for entry in entries where entry.value != .zero {
            let ringColumn = entry.column / CyclotomicRing54.degree
            let coeff = entry.column % CyclotomicRing54.degree
            let transformed = CyclotomicRing54(try CyclotomicRing54.innerProductTransform(unitVector(index: coeff, value: entry.value)))
            rowValues[entry.row][ringColumn, default: .zero] = rowValues[entry.row][ringColumn, default: .zero] + transformed
        }

        var rowOffsets = [0]
        var columnIndices: [Int] = []
        var values: [CyclotomicRing54] = []
        for row in rowValues {
            for column in row.keys.sorted() {
                guard let value = row[column], value != .zero else { continue }
                columnIndices.append(column)
                values.append(value)
            }
            rowOffsets.append(columnIndices.count)
        }
        return try SparseRingMatrixCSR(
            rows: rows,
            columns: ringColumns,
            rowOffsets: rowOffsets,
            columnIndices: columnIndices,
            values: values
        )
    }

    private func unitVector(index: Int, value: GoldilocksField) -> [GoldilocksField] {
        var vector = Array(repeating: GoldilocksField.zero, count: CyclotomicRing54.degree)
        vector[index] = value
        return vector
    }
}

public enum MultilinearEvaluation {
    public static func basis(at point: [GoldilocksExt2]) -> [GoldilocksExt2] {
        (try? checkedBasis(at: point)) ?? []
    }

    public static func checkedBasis(at point: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
        var weights = [GoldilocksExt2.one]
        for challenge in point {
            guard weights.count <= Int.max / 2 else {
                throw SuperNeoError.invalidParameter("multilinear basis dimension is too large")
            }
            let previous = weights
            weights = Array(repeating: .zero, count: previous.count * 2)
            for index in previous.indices {
                weights[index] = previous[index] * (.one - challenge)
                weights[index + previous.count] = previous[index] * challenge
            }
        }
        return weights
    }

    public static func evaluate(_ vector: [GoldilocksField], at point: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard point.count < Int.bitWidth - 1 else {
            throw SuperNeoError.invalidParameter("multilinear evaluation dimension is too large")
        }
        let expected = 1 << point.count
        guard vector.count == expected else {
            throw SuperNeoError.invalidParameter("vector length must equal 2^point.count")
        }
        var layer = vector.map { GoldilocksExt2($0) }
        for challenge in point {
            var next: [GoldilocksExt2] = []
            next.reserveCapacity(layer.count / 2)
            for index in stride(from: 0, to: layer.count, by: 2) {
                next.append(layer[index] * (.one - challenge) + layer[index + 1] * challenge)
            }
            layer = next
        }
        return layer[0]
    }

    public static func eq(_ lhs: [GoldilocksExt2], _ rhs: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        guard lhs.count == rhs.count else { throw SuperNeoError.invalidParameter("eq vector length mismatch") }
        var result = GoldilocksExt2.one
        for (a, b) in zip(lhs, rhs) {
            result = result * (a * b + (.one - a) * (.one - b))
        }
        return result
    }
}

public struct CCSStructure: Equatable, Sendable {
    public let matrices: [SparseFieldMatrix]
    public let relationPolynomial: RelationPolynomial?
    public let constraintPolynomial: @Sendable ([GoldilocksExt2]) throws -> GoldilocksExt2

    public init(matrices: [SparseFieldMatrix], relationPolynomial: RelationPolynomial) {
        self.matrices = matrices
        self.relationPolynomial = relationPolynomial
        self.constraintPolynomial = { values in
            try relationPolynomial.evaluate(values)
        }
    }

    public init(
        matrices: [SparseFieldMatrix],
        constraintPolynomial: @escaping @Sendable ([GoldilocksExt2]) throws -> GoldilocksExt2
    ) {
        self.matrices = matrices
        self.relationPolynomial = nil
        self.constraintPolynomial = constraintPolynomial
    }

    public func evaluateRelation(_ values: [GoldilocksExt2]) throws -> GoldilocksExt2 {
        try constraintPolynomial(values)
    }

    public static func hadamardProduct(matrices: [SparseFieldMatrix]) -> Self {
        if let relationPolynomial = try? RelationPolynomial.hadamardProduct(variableCount: matrices.count) {
            return Self(matrices: matrices, relationPolynomial: relationPolynomial)
        }
        return Self(matrices: matrices) { values in
            values.reduce(.one, *)
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.matrices == rhs.matrices && lhs.relationPolynomial == rhs.relationPolynomial
    }
}

public struct PublicInputEncoding: Equatable, Hashable, Sendable, SuperNeoByteEncodable {
    public let field: [GoldilocksField]
    public let packed: [CyclotomicRing54]

    public init(field: [GoldilocksField]) {
        self.field = field
        self.packed = ccsPackPaddedToRings(field)
    }

    public init(field: [GoldilocksField], packed: [CyclotomicRing54]) throws {
        let expectedPacked = ccsPackPaddedToRings(field)
        guard packed == expectedPacked else {
            throw SuperNeoError.invalidParameter("packed public input does not match field public input")
        }
        self.field = field
        self.packed = packed
    }

    public var superNeoBytes: [UInt8] {
        ccsEncodeCount(field.count)
            + field.flatMap(\.superNeoBytes)
            + ccsEncodeCount(packed.count)
            + packed.flatMap(\.superNeoBytes)
    }
}

public struct CCSInstance: Equatable, Sendable {
    public let commitment: AjtaiCommitment
    public let publicInputEncoding: PublicInputEncoding

    public var publicInput: [GoldilocksField] { publicInputEncoding.field }
    public var packedPublicInput: [CyclotomicRing54] { publicInputEncoding.packed }

    public init(commitment: AjtaiCommitment, publicInput: [GoldilocksField]) {
        self.commitment = commitment
        self.publicInputEncoding = PublicInputEncoding(field: publicInput)
    }

    public init(commitment: AjtaiCommitment, publicInputEncoding: PublicInputEncoding) {
        self.commitment = commitment
        self.publicInputEncoding = publicInputEncoding
    }
}

extension CCSInstance: SuperNeoByteEncodable {
    public var superNeoBytes: [UInt8] {
        commitment.superNeoBytes + publicInputEncoding.superNeoBytes
    }
}

public struct CCSWitness: Equatable, Sendable {
    public let values: [GoldilocksField]
    public var privateWitness: [GoldilocksField] { values }

    public init(_ values: [GoldilocksField]) {
        self.values = values
    }

    public func fullZ(publicInput: [GoldilocksField]) -> [GoldilocksField] {
        publicInput + values
    }

    public func fullZ(for instance: CCSInstance) -> [GoldilocksField] {
        fullZ(publicInput: instance.publicInput)
    }
}

public struct CCSEvaluationClaim: Equatable, Sendable {
    public let commitment: AjtaiCommitment
    public let publicInput: [GoldilocksField]
    public let point: [GoldilocksExt2]
    public let evaluations: [CyclotomicExt2Ring54]
    public let witness: [GoldilocksField]?

    public init(
        commitment: AjtaiCommitment,
        publicInput: [GoldilocksField],
        point: [GoldilocksExt2],
        evaluations: [CyclotomicExt2Ring54],
        witness: [GoldilocksField]? = nil
    ) {
        self.commitment = commitment
        self.publicInput = publicInput
        self.point = point
        self.evaluations = evaluations
        self.witness = witness
    }

    public init(
        commitment: AjtaiCommitment,
        publicInput: [GoldilocksField],
        point: [GoldilocksExt2],
        evaluations: [CyclotomicRing54],
        witness: [GoldilocksField]? = nil
    ) {
        self.init(
            commitment: commitment,
            publicInput: publicInput,
            point: point,
            evaluations: evaluations.map(CyclotomicExt2Ring54.init(baseRing:)),
            witness: witness
        )
    }
}

public struct CEInstance: Equatable, Sendable, SuperNeoByteEncodable {
    public let commitment: AjtaiCommitment
    public let publicInputEncoding: PublicInputEncoding
    public let evalPoint: [GoldilocksExt2]
    public let matrixEvals: [CyclotomicExt2Ring54]

    public var publicInput: [GoldilocksField] { publicInputEncoding.field }
    public var packedPublicInput: [CyclotomicRing54] { publicInputEncoding.packed }

    public init(
        commitment: AjtaiCommitment,
        publicInput: [GoldilocksField],
        evalPoint: [GoldilocksExt2],
        matrixEvals: [CyclotomicExt2Ring54]
    ) {
        self.commitment = commitment
        self.publicInputEncoding = PublicInputEncoding(field: publicInput)
        self.evalPoint = evalPoint
        self.matrixEvals = matrixEvals
    }

    public init(
        commitment: AjtaiCommitment,
        publicInputEncoding: PublicInputEncoding,
        evalPoint: [GoldilocksExt2],
        matrixEvals: [CyclotomicExt2Ring54]
    ) {
        self.commitment = commitment
        self.publicInputEncoding = publicInputEncoding
        self.evalPoint = evalPoint
        self.matrixEvals = matrixEvals
    }

    public init(
        commitment: AjtaiCommitment,
        publicInput: [GoldilocksField],
        evalPoint: [GoldilocksExt2],
        matrixEvals: [CyclotomicRing54]
    ) {
        self.init(
            commitment: commitment,
            publicInput: publicInput,
            evalPoint: evalPoint,
            matrixEvals: matrixEvals.map(CyclotomicExt2Ring54.init(baseRing:))
        )
    }

    public init(
        commitment: AjtaiCommitment,
        publicInputEncoding: PublicInputEncoding,
        evalPoint: [GoldilocksExt2],
        matrixEvals: [CyclotomicRing54]
    ) {
        self.init(
            commitment: commitment,
            publicInputEncoding: publicInputEncoding,
            evalPoint: evalPoint,
            matrixEvals: matrixEvals.map(CyclotomicExt2Ring54.init(baseRing:))
        )
    }

    public init(_ claim: CCSEvaluationClaim) {
        self.init(
            commitment: claim.commitment,
            publicInput: claim.publicInput,
            evalPoint: claim.point,
            matrixEvals: claim.evaluations
        )
    }

    public var superNeoBytes: [UInt8] {
        commitment.superNeoBytes
            + publicInputEncoding.superNeoBytes
            + ccsEncodeCount(evalPoint.count)
            + evalPoint.flatMap(\.superNeoBytes)
            + ccsEncodeCount(matrixEvals.count)
            + matrixEvals.flatMap(\.superNeoBytes)
    }
}

public struct CCSStatement: Equatable, Sendable, SuperNeoByteEncodable {
    public let shapeDigest: Digest256
    public let ccsInstances: [CCSInstance]
    public let priorCEInstances: [CEInstance]
    public let statementDigest: Digest256

    public init(shapeDigest: Digest256, ccsInstances: [CCSInstance], priorCEInstances: [CEInstance] = []) {
        self.shapeDigest = shapeDigest
        self.ccsInstances = ccsInstances
        self.priorCEInstances = priorCEInstances
        self.statementDigest = Digest256.hash(
            Self.bodyBytes(
                shapeDigest: shapeDigest,
                ccsInstances: ccsInstances,
                priorCEInstances: priorCEInstances
            )
        )
    }

    public var superNeoBytes: [UInt8] {
        statementDigest.superNeoBytes
            + Self.bodyBytes(
                shapeDigest: shapeDigest,
                ccsInstances: ccsInstances,
                priorCEInstances: priorCEInstances
            )
    }

    private static func bodyBytes(
        shapeDigest: Digest256,
        ccsInstances: [CCSInstance],
        priorCEInstances: [CEInstance]
    ) -> [UInt8] {
        shapeDigest.superNeoBytes
            + ccsEncodeCount(ccsInstances.count)
            + ccsInstances.flatMap(\.superNeoBytes)
            + ccsEncodeCount(priorCEInstances.count)
            + priorCEInstances.flatMap(\.superNeoBytes)
    }
}

extension ProofEnvelopeContext {
    public init(
        profileID: UInt16 = SuperNeoParameterProfile.goldilocksPhi54.profileID,
        kind: ProofEnvelopeKind = .foldReduction,
        statement: CCSStatement,
        verifierKeyDigest: Digest256,
        transcriptDomain: Digest256 = .hash("SuperNeo-NuMetal.fold.v1")
    ) {
        self.init(
            profileID: profileID,
            kind: kind,
            shapeDigest: statement.shapeDigest,
            statementDigest: statement.statementDigest,
            verifierKeyDigest: verifierKeyDigest,
            transcriptDomain: transcriptDomain
        )
    }
}

extension CCSShape {
    public init(bytes: [UInt8]) throws {
        var reader = ByteReader(bytes)
        self = try reader.readCCSShape()
        try reader.finish()
    }
}

extension CCSInstance {
    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        self = try reader.readCCSInstance(parameters: parameters)
        try reader.finish()
    }
}

extension CEInstance {
    public init(bytes: [UInt8], parameters: SuperNeoParameters = .goldilocks) throws {
        var reader = ByteReader(bytes)
        self = try reader.readCEInstance(parameters: parameters)
        try reader.finish()
    }
}

extension ByteReader {
    public mutating func readCCSShape() throws -> CCSShape {
        let expectedDigest = try Digest256(readData(count: Digest256.byteCount))
        let bodyStartVersion = try readUInt32()
        let modulusLength = try readCount(maximum: 1024, name: "field modulus")
        let modulusBytes = try readData(count: modulusLength)
        let modulus = try FieldModulusDescriptor(modulusBytesLittleEndian: modulusBytes)
        let extensionDegree = try readUInt32()
        let field = try FieldDescriptor(
            modulus: modulus,
            extensionDegree: extensionDegree
        )
        let cyclotomicDegree = try readUInt32()
        let relationCoefficientCount = try readCount(maximum: 4096, name: "cyclotomic relation coefficient")
        let cyclotomic = try CyclotomicDescriptor(
            degree: cyclotomicDegree,
            relationCoefficients: try (0..<relationCoefficientCount).map { _ in try readInt64() }
        )
        let ajtai = try AjtaiDescriptor(
            kappa: try readUInt32(),
            ringDegree: try readUInt32(),
            normBound: try readUInt32(),
            decompositionLength: try readUInt32()
        )
        let challengeCount = try readCount(maximum: 1024, name: "challenge coefficient")
        let challengeCoefficients = try (0..<challengeCount).map { _ in try readInt16() }
        let challengeExpansionFactor = try readUInt32()
        let challenges = try StrongSamplingSetDescriptor(
            coefficientSet: challengeCoefficients,
            expansionFactor: challengeExpansionFactor
        )
        let m = try readCount(maximum: 1 << 30, name: "CCS row")
        let nField = try readCount(maximum: 1 << 30, name: "CCS field column")
        let nRing = try readCount(maximum: 1 << 30, name: "CCS ring column")
        let nPublicField = try readCount(maximum: 1 << 30, name: "CCS public field")
        let numMatrices = try readCount(maximum: 4096, name: "CCS matrix")
        let relationDegree = try readCount(maximum: 4096, name: "relation degree")
        let matrixCount = try readCount(maximum: 4096, name: "CCS matrix payload")
        guard matrixCount == numMatrices else {
            throw SuperNeoError.invalidEncoding("CCS matrix count mismatch")
        }
        let matrices = try (0..<matrixCount).map { _ in try readSparseMatrixCSR() }
        let relationPolynomial = try readRelationPolynomial()
        let identityFlag = try readData(count: 1)
        guard identityFlag[0] == 0 || identityFlag[0] == 1 else {
            throw SuperNeoError.invalidEncoding("invalid CCS identity flag")
        }
        let shape = try CCSShape(
            version: bodyStartVersion,
            field: field,
            cyclotomic: cyclotomic,
            ajtai: ajtai,
            challenges: challenges,
            m: m,
            nField: nField,
            nRing: nRing,
            nPublicField: nPublicField,
            matrices: matrices,
            relationPolynomial: relationPolynomial,
            hasIdentityFirstMatrix: identityFlag[0] == 1
        )
        guard shape.relationDegree == relationDegree else {
            throw SuperNeoError.invalidEncoding("encoded relation degree mismatch")
        }
        guard shape.shapeDigest == expectedDigest else {
            throw SuperNeoError.invalidEncoding("CCS shape digest mismatch")
        }
        return shape
    }

    public mutating func readCCSInstance(parameters: SuperNeoParameters = .goldilocks) throws -> CCSInstance {
        let commitment = try readAjtaiCommitment(parameters: parameters)
        return try CCSInstance(
            commitment: commitment,
            publicInputEncoding: readPublicInputEncoding()
        )
    }

    public mutating func readCEInstance(parameters: SuperNeoParameters = .goldilocks) throws -> CEInstance {
        let commitment = try readAjtaiCommitment(parameters: parameters)
        let publicInputEncoding = try readPublicInputEncoding()
        let evalPointCount = try readCount(maximum: 64, name: "CE eval point")
        let evalPoint = try (0..<evalPointCount).map { _ in try readGoldilocksExt2Public() }
        let matrixEvalCount = try readCount(maximum: 4096, name: "CE matrix eval")
        let matrixEvals = try (0..<matrixEvalCount).map { _ in try readCyclotomicExt2Ring54() }
        return CEInstance(
            commitment: commitment,
            publicInputEncoding: publicInputEncoding,
            evalPoint: evalPoint,
            matrixEvals: matrixEvals
        )
    }

    private mutating func readSparseMatrixCSR() throws -> SparseMatrixCSR {
        let rowCount = try readCount(maximum: 1 << 30, name: "CSR row")
        let columnCount = try readCount(maximum: 1 << 30, name: "CSR column")
        let (rowOffsetMaximum, rowOffsetOverflow) = rowCount.addingReportingOverflow(1)
        guard !rowOffsetOverflow else {
            throw SuperNeoError.invalidEncoding("CSR row offset count exceeds canonical bound")
        }
        let rowOffsetCount = try readCount(maximum: rowOffsetMaximum, name: "CSR row offset", elementByteWidth: 8)
        let rowOffsets = try (0..<rowOffsetCount).map { _ in try readCount(maximum: 1 << 30, name: "CSR row offset value") }
        let columnIndexCount = try readCount(maximum: 1 << 30, name: "CSR column index", elementByteWidth: 8)
        let maxColumnIndex = max(0, columnCount - 1)
        let columnIndices = try (0..<columnIndexCount).map { _ in try readCount(maximum: maxColumnIndex, name: "CSR column index value") }
        let valueCount = try readCount(maximum: columnIndexCount, name: "CSR value", elementByteWidth: 8)
        let values = try (0..<valueCount).map { _ in try readGoldilocksFieldPublic() }
        return try SparseMatrixCSR(
            rowCount: rowCount,
            columnCount: columnCount,
            rowOffsets: rowOffsets,
            columnIndices: columnIndices,
            values: values
        )
    }

    private mutating func readRelationPolynomial() throws -> RelationPolynomial {
        let variableCount = try readUInt16()
        let monomialCount = try readCount(maximum: 1 << 20, name: "relation monomial")
        let monomials = try (0..<monomialCount).map { _ -> RelationMonomial in
            let coefficient = try readGoldilocksFieldPublic()
            let exponentCount = try readCount(maximum: Int(variableCount), name: "relation exponent")
            let exponents = try (0..<exponentCount).map { _ in try readUInt16() }
            return RelationMonomial(coefficient: coefficient, exponents: exponents)
        }
        let polynomial = try RelationPolynomial(variableCount: variableCount, monomials: monomials)
        guard polynomial.monomials == monomials else {
            throw SuperNeoError.invalidEncoding("relation polynomial is not canonical")
        }
        return polynomial
    }

    private mutating func readPublicInputEncoding() throws -> PublicInputEncoding {
        let fieldCount = try readCount(maximum: 1 << 20, name: "public input field", elementByteWidth: 8)
        let field = try (0..<fieldCount).map { _ in try readGoldilocksFieldPublic() }
        let packedCount = try readCount(maximum: 1 << 20, name: "public input packed", elementByteWidth: CyclotomicRing54.degree * 8)
        let packed = try (0..<packedCount).map { _ in try readCyclotomicRing54() }
        return try PublicInputEncoding(field: field, packed: packed)
    }

    private mutating func readAjtaiCommitment(parameters: SuperNeoParameters) throws -> AjtaiCommitment {
        AjtaiCommitment(try (0..<parameters.kappa).map { _ in try readCyclotomicRing54() })
    }

    private mutating func readGoldilocksFieldPublic() throws -> GoldilocksField {
        try GoldilocksField(littleEndianBytes: readData(count: 8)[...])
    }

    private mutating func readGoldilocksExt2Public() throws -> GoldilocksExt2 {
        try GoldilocksExt2(littleEndianBytes: readData(count: 16)[...])
    }

    private mutating func readCyclotomicRing54() throws -> CyclotomicRing54 {
        try CyclotomicRing54(littleEndianBytes: readData(count: CyclotomicRing54.degree * 8))
    }

    private mutating func readCyclotomicExt2Ring54() throws -> CyclotomicExt2Ring54 {
        try CyclotomicExt2Ring54(littleEndianBytes: readData(count: CyclotomicRing54.degree * 16))
    }

    private mutating func readInt16() throws -> Int16 {
        Int16(bitPattern: try readUInt16())
    }

    private mutating func readInt64() throws -> Int64 {
        Int64(bitPattern: try readUInt64())
    }
}

private extension SparseMatrixCSR {
    var isIdentityPrefix: Bool {
        guard rowCount <= columnCount else { return false }
        for row in 0..<rowCount {
            let start = rowOffsets[row]
            let end = rowOffsets[row + 1]
            guard end == start + 1,
                  columnIndices[start] == row,
                  values[start] == .one else {
                return false
            }
        }
        return true
    }
}

private func ccsPadToRingMultiple(_ values: [GoldilocksField]) -> [GoldilocksField] {
    let remainder = values.count % CyclotomicRing54.degree
    if remainder == 0 { return values }
    return values + Array(repeating: .zero, count: CyclotomicRing54.degree - remainder)
}

private func ccsPackPaddedToRings(_ values: [GoldilocksField]) -> [CyclotomicRing54] {
    let padded = ccsPadToRingMultiple(values)
    return stride(from: 0, to: padded.count, by: CyclotomicRing54.degree).map { offset in
        CyclotomicRing54(Array(padded[offset..<offset + CyclotomicRing54.degree]))
    }
}

private func ccsEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}

private func ccsEncodeUInt16(_ value: UInt16) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func ccsEncodeUInt32(_ value: UInt32) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func ccsEncodeInt16(_ value: Int16) -> [UInt8] {
    withUnsafeBytes(of: UInt16(bitPattern: value).littleEndian, Array.init)
}

private func ccsEncodeInt64(_ value: Int64) -> [UInt8] {
    withUnsafeBytes(of: UInt64(bitPattern: value).littleEndian, Array.init)
}
