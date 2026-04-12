import Foundation

public struct NormalizedCCSMapping: Equatable, Sendable {
    public let originalRowCount: Int
    public let originalFieldColumnCount: Int
    public let originalPublicInputCount: Int
    public let normalizedRowCount: Int
    public let normalizedFieldColumnCount: Int
    public let normalizedPublicInputCount: Int
    public let addedIdentityMatrix: Bool

    public var addedRows: Int { normalizedRowCount - originalRowCount }
    public var addedFieldColumns: Int { normalizedFieldColumnCount - originalFieldColumnCount }
    public var addedPublicInputs: Int { normalizedPublicInputCount - originalPublicInputCount }
    public var originalMatrixOffset: Int { addedIdentityMatrix ? 1 : 0 }

    public func normalizedMatrixIndex(forOriginalMatrix index: Int) throws -> Int {
        guard index >= 0 else {
            throw SuperNeoError.invalidParameter("original matrix index must be non-negative")
        }
        return index + originalMatrixOffset
    }

    public func embedPublicInput(_ publicInput: [GoldilocksField]) throws -> [GoldilocksField] {
        guard publicInput.count == originalPublicInputCount else {
            throw SuperNeoError.invalidParameter("public input length does not match normalized CCS mapping")
        }
        return publicInput + Array(repeating: .zero, count: addedPublicInputs)
    }

    public func projectPublicInput(_ normalizedPublicInput: [GoldilocksField]) throws -> [GoldilocksField] {
        guard normalizedPublicInput.count == normalizedPublicInputCount else {
            throw SuperNeoError.invalidParameter("normalized public input length does not match normalized CCS mapping")
        }
        guard Array(normalizedPublicInput.dropFirst(originalPublicInputCount)).allSatisfy({ $0 == .zero }) else {
            throw SuperNeoError.invalidParameter("normalized public input padding must be zero")
        }
        return Array(normalizedPublicInput.prefix(originalPublicInputCount))
    }

    public func embedPrivateWitness(_ privateWitness: [GoldilocksField]) throws -> [GoldilocksField] {
        let originalPrivateCount = originalFieldColumnCount - originalPublicInputCount
        guard originalPrivateCount >= 0, privateWitness.count == originalPrivateCount else {
            throw SuperNeoError.invalidParameter("private witness length does not match normalized CCS mapping")
        }
        let normalizedPrivateCount = normalizedFieldColumnCount - normalizedPublicInputCount
        guard normalizedPrivateCount >= privateWitness.count else {
            throw SuperNeoError.invalidParameter("normalized private witness capacity is smaller than original witness")
        }
        return privateWitness + Array(repeating: .zero, count: normalizedPrivateCount - privateWitness.count)
    }

    public func projectPrivateWitness(_ normalizedPrivateWitness: [GoldilocksField]) throws -> [GoldilocksField] {
        let originalPrivateCount = originalFieldColumnCount - originalPublicInputCount
        let normalizedPrivateCount = normalizedFieldColumnCount - normalizedPublicInputCount
        guard normalizedPrivateWitness.count == normalizedPrivateCount else {
            throw SuperNeoError.invalidParameter("normalized private witness length does not match normalized CCS mapping")
        }
        guard Array(normalizedPrivateWitness.dropFirst(originalPrivateCount)).allSatisfy({ $0 == .zero }) else {
            throw SuperNeoError.invalidParameter("normalized private witness padding must be zero")
        }
        return Array(normalizedPrivateWitness.prefix(originalPrivateCount))
    }

    public func embedFullWitness(
        publicInput: [GoldilocksField],
        privateWitness: [GoldilocksField]
    ) throws -> [GoldilocksField] {
        try embedPublicInput(publicInput) + embedPrivateWitness(privateWitness)
    }

    public func projectFullWitness(_ normalizedWitness: [GoldilocksField]) throws -> [GoldilocksField] {
        guard normalizedWitness.count == normalizedFieldColumnCount else {
            throw SuperNeoError.invalidParameter("normalized witness length does not match normalized CCS mapping")
        }
        let normalizedPublic = Array(normalizedWitness.prefix(normalizedPublicInputCount))
        let normalizedPrivate = Array(normalizedWitness.dropFirst(normalizedPublicInputCount))
        return try projectPublicInput(normalizedPublic) + projectPrivateWitness(normalizedPrivate)
    }
}

public struct SuperNeoFoldingShapeContract: Equatable, Sendable {
    public static let paperNormalized = SuperNeoFoldingShapeContract()

    public let requiresIdentityFirstMatrix: Bool
    public let requiresSquareFieldShape: Bool
    public let requiresPowerOfTwoRows: Bool
    public let requiresWholeRingPublicInput: Bool

    public init(
        requiresIdentityFirstMatrix: Bool = true,
        requiresSquareFieldShape: Bool = true,
        requiresPowerOfTwoRows: Bool = true,
        requiresWholeRingPublicInput: Bool = true
    ) {
        self.requiresIdentityFirstMatrix = requiresIdentityFirstMatrix
        self.requiresSquareFieldShape = requiresSquareFieldShape
        self.requiresPowerOfTwoRows = requiresPowerOfTwoRows
        self.requiresWholeRingPublicInput = requiresWholeRingPublicInput
    }

    public func requiresNormalization(_ shape: CCSShape) -> Bool {
        if requiresPowerOfTwoRows, shape.m <= 0 || (shape.m & (shape.m - 1)) != 0 { return true }
        if requiresSquareFieldShape, shape.nField != shape.m { return true }
        if requiresIdentityFirstMatrix, !shape.hasIdentityFirstMatrix { return true }
        if requiresWholeRingPublicInput, shape.nPublicField % CyclotomicRing54.degree != 0 { return true }
        return false
    }

    public func validate(_ shape: CCSShape) throws {
        if requiresPowerOfTwoRows {
            guard shape.m > 0, (shape.m & (shape.m - 1)) == 0 else {
                throw Self.unsupported("CCS row count must be a positive power of two")
            }
        }
        if requiresSquareFieldShape {
            guard shape.nField == shape.m else {
                throw Self.unsupported("shape.nField must equal shape.m")
            }
        }
        if requiresIdentityFirstMatrix {
            guard shape.hasIdentityFirstMatrix else {
                throw Self.unsupported("M1 must be the identity matrix")
            }
        }
        if requiresWholeRingPublicInput {
            guard shape.nPublicField % CyclotomicRing54.degree == 0 else {
                throw SuperNeoError.invalidParameter("public input length must contain whole ring columns for R-module folding")
            }
        }
    }

    private static func unsupported(_ requirement: String) -> SuperNeoError {
        .invalidParameter(
            "SuperNeo folding requires a paper-normalized CCS shape: \(requirement); use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
        )
    }
}

public struct NormalizedCCS: Sendable {
    public let shape: CCSShape
    public let instances: [CCSInstance]
    public let witnesses: [CCSWitness]
    public let priorClaims: [CCSEvaluationClaim]
    public let mapping: NormalizedCCSMapping

    public var foldInput: SuperNeoFoldInput {
        SuperNeoFoldInput(
            shape: shape,
            instances: instances,
            witnesses: witnesses,
            priorClaims: priorClaims
        )
    }

    public var publicFoldInput: SuperNeoPublicFoldInput {
        SuperNeoPublicFoldInput(foldInput)
    }
}

public enum SuperNeoCCSNormalizer {
    public static func normalize(
        structure: CCSStructure,
        instances: [CCSInstance],
        witnesses: [CCSWitness],
        priorClaims: [CCSEvaluationClaim] = [],
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> (normalized: NormalizedCCS, key: AjtaiCommitmentKey) {
        guard let relationPolynomial = structure.relationPolynomial else {
            throw SuperNeoError.invalidParameter("normalization requires a serializable CCS relation polynomial")
        }
        guard !structure.matrices.isEmpty else {
            throw SuperNeoError.invalidParameter("normalization requires at least one CCS matrix")
        }
        guard instances.count == witnesses.count else {
            throw SuperNeoError.invalidParameter("normalization instance and witness count mismatch")
        }
        guard priorClaims.isEmpty else {
            throw SuperNeoError.invalidParameter("normalization requires empty prior CE claims; normalize before producing prior claims")
        }

        let originalRows = structure.matrices[0].rows
        let originalColumns = structure.matrices[0].columns
        for matrix in structure.matrices {
            guard matrix.rows == originalRows, matrix.columns == originalColumns else {
                throw SuperNeoError.invalidParameter("normalization requires rectangular matrices with matching dimensions")
            }
        }

        let originalPublicInputCount = instances.first?.publicInput.count ?? 0
        for instance in instances {
            guard instance.publicInput.count == originalPublicInputCount else {
                throw SuperNeoError.invalidParameter("normalization requires uniform public input lengths")
            }
        }

        let normalizedPublicInputCount = roundUpToMultiple(originalPublicInputCount, CyclotomicRing54.degree)
        let minimumColumns = max(originalColumns + (normalizedPublicInputCount - originalPublicInputCount), normalizedPublicInputCount)
        let normalizedSize = nextPowerOfTwo(max(originalRows, minimumColumns, 1))

        let normalizedMatrixResult = try makeNormalizedMatrices(
            matrices: structure.matrices,
            originalPublicInputCount: originalPublicInputCount,
            normalizedPublicInputCount: normalizedPublicInputCount,
            normalizedSize: normalizedSize
        )
        let normalizedRelation = normalizedMatrixResult.addedIdentity
            ? try prependIgnoredIdentityVariable(to: relationPolynomial)
            : relationPolynomial
        let shape = try CCSShape(
            matrices: normalizedMatrixResult.matrices,
            publicInputCount: normalizedPublicInputCount,
            relationPolynomial: normalizedRelation
        )
        let key = try AjtaiCommitmentKey(parameters: parameters, columns: shape.nRing, seed: keySeed)

        let normalizedPairs = try zip(instances, witnesses).map { instance, witness -> (CCSInstance, CCSWitness) in
            let normalizedPublic = instance.publicInput
                + Array(repeating: GoldilocksField.zero, count: normalizedPublicInputCount - originalPublicInputCount)
            let fullOriginal = instance.publicInput + witness.values
            guard fullOriginal.count == originalColumns else {
                throw SuperNeoError.invalidParameter("normalization witness length does not match matrix column count")
            }
            let normalizedPrivate = witness.values
                + Array(repeating: GoldilocksField.zero, count: normalizedSize - normalizedPublicInputCount - witness.values.count)
            let fullNormalized = normalizedPublic + normalizedPrivate
            let commitment = try AjtaiCommitter.commitReference(key: key, fieldWitness: fullNormalized)
            return (CCSInstance(commitment: commitment, publicInput: normalizedPublic), CCSWitness(normalizedPrivate))
        }

        let mapping = NormalizedCCSMapping(
            originalRowCount: originalRows,
            originalFieldColumnCount: originalColumns,
            originalPublicInputCount: originalPublicInputCount,
            normalizedRowCount: normalizedSize,
            normalizedFieldColumnCount: normalizedSize,
            normalizedPublicInputCount: normalizedPublicInputCount,
            addedIdentityMatrix: normalizedMatrixResult.addedIdentity
        )

        return (
            NormalizedCCS(
                shape: shape,
                instances: normalizedPairs.map(\.0),
                witnesses: normalizedPairs.map(\.1),
                priorClaims: priorClaims,
                mapping: mapping
            ),
            key
        )
    }

    private static func makeNormalizedMatrices(
        matrices: [SparseFieldMatrix],
        originalPublicInputCount: Int,
        normalizedPublicInputCount: Int,
        normalizedSize: Int
    ) throws -> (matrices: [SparseFieldMatrix], addedIdentity: Bool) {
        let publicPadding = normalizedPublicInputCount - originalPublicInputCount
        let identity = try SparseFieldMatrix.identity(size: normalizedSize)
        let shifted = try matrices.map { matrix in
            var entries: [SparseFieldMatrix.Entry] = []
            entries.reserveCapacity(matrix.entries.count)
            for entry in matrix.entries {
                let normalizedColumn = entry.column < originalPublicInputCount
                    ? entry.column
                    : entry.column + publicPadding
                entries.append(SparseFieldMatrix.Entry(
                    row: entry.row,
                    column: normalizedColumn,
                    value: entry.value
                ))
            }
            return try SparseFieldMatrix(rows: normalizedSize, columns: normalizedSize, entries: entries)
        }
        if shifted.first == identity {
            return (shifted, false)
        }
        return ([identity] + shifted, true)
    }

    private static func prependIgnoredIdentityVariable(to relationPolynomial: RelationPolynomial) throws -> RelationPolynomial {
        let variableCount = Int(relationPolynomial.variableCount) + 1
        guard variableCount <= Int(UInt16.max) else {
            throw SuperNeoError.invalidParameter("normalized relation variable count out of range")
        }
        return try RelationPolynomial(
            variableCount: UInt16(variableCount),
            monomials: relationPolynomial.monomials.map {
                RelationMonomial(coefficient: $0.coefficient, exponents: [0] + $0.exponents)
            }
        )
    }

    private static func roundUpToMultiple(_ value: Int, _ multiple: Int) -> Int {
        let remainder = value % multiple
        return remainder == 0 ? value : value + multiple - remainder
    }

    private static func nextPowerOfTwo(_ value: Int) -> Int {
        guard value > 1 else { return 1 }
        var result = 1
        while result < value {
            result <<= 1
        }
        return result
    }
}
