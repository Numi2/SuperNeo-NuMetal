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

public enum SuperNeoFoldingShapeRequirement: Equatable, Hashable, Sendable, CustomStringConvertible {
    case positivePowerOfTwoRows(rowCount: Int)
    case squareFieldShape(rowCount: Int, fieldColumnCount: Int)
    case identityFirstMatrix
    case wholeRingPublicInput(publicInputCount: Int, ringDegree: Int)

    public var description: String {
        switch self {
        case .positivePowerOfTwoRows:
            return "CCS row count must be a positive power of two"
        case .squareFieldShape:
            return "shape.nField must equal shape.m"
        case .identityFirstMatrix:
            return "M1 must be the identity matrix"
        case .wholeRingPublicInput:
            return "public input length must contain whole ring columns for R-module folding"
        }
    }

    public var diagnostic: String {
        switch self {
        case .positivePowerOfTwoRows(let rowCount):
            return "\(description) (rowCount: \(rowCount))"
        case .squareFieldShape(let rowCount, let fieldColumnCount):
            return "\(description) (m: \(rowCount), nField: \(fieldColumnCount))"
        case .identityFirstMatrix:
            return description
        case .wholeRingPublicInput(let publicInputCount, let ringDegree):
            return "\(description) (nPublicField: \(publicInputCount), ringDegree: \(ringDegree))"
        }
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
        !normalizationRequirements(for: shape).isEmpty
    }

    public func normalizationRequirements(for shape: CCSShape) -> [SuperNeoFoldingShapeRequirement] {
        normalizationRequirements(
            rowCount: shape.m,
            fieldColumnCount: shape.nField,
            publicInputCount: shape.nPublicField,
            hasIdentityFirstMatrix: shape.hasIdentityFirstMatrix
        )
    }

    public func normalizationRequirements(
        for structure: CCSStructure,
        publicInputCount: Int
    ) throws -> [SuperNeoFoldingShapeRequirement] {
        guard publicInputCount >= 0 else {
            throw SuperNeoError.invalidParameter("public input count must be non-negative")
        }
        guard let first = structure.matrices.first else {
            throw SuperNeoError.invalidParameter("CCS structure requires at least one matrix")
        }
        for matrix in structure.matrices {
            guard matrix.rows == first.rows, matrix.columns == first.columns else {
                throw SuperNeoError.invalidParameter("CCS structure matrices must have matching dimensions")
            }
        }
        return normalizationRequirements(
            rowCount: first.rows,
            fieldColumnCount: first.columns,
            publicInputCount: publicInputCount,
            hasIdentityFirstMatrix: isIdentityPrefix(first)
        )
    }

    public func validate(_ shape: CCSShape) throws {
        let requirements = normalizationRequirements(for: shape)
        guard requirements.isEmpty else {
            throw Self.unsupported(requirements)
        }
    }

    public func validate(_ structure: CCSStructure, publicInputCount: Int) throws {
        let requirements = try normalizationRequirements(for: structure, publicInputCount: publicInputCount)
        guard requirements.isEmpty else {
            throw Self.unsupported(requirements)
        }
    }

    private func normalizationRequirements(
        rowCount: Int,
        fieldColumnCount: Int,
        publicInputCount: Int,
        hasIdentityFirstMatrix: Bool
    ) -> [SuperNeoFoldingShapeRequirement] {
        var requirements: [SuperNeoFoldingShapeRequirement] = []
        if requiresPowerOfTwoRows, rowCount <= 0 || (rowCount & (rowCount - 1)) != 0 {
            requirements.append(.positivePowerOfTwoRows(rowCount: rowCount))
        }
        if requiresSquareFieldShape, fieldColumnCount != rowCount {
            requirements.append(.squareFieldShape(rowCount: rowCount, fieldColumnCount: fieldColumnCount))
        }
        if requiresIdentityFirstMatrix, !hasIdentityFirstMatrix {
            requirements.append(.identityFirstMatrix)
        }
        if requiresWholeRingPublicInput, publicInputCount % CyclotomicRing54.degree != 0 {
            requirements.append(.wholeRingPublicInput(
                publicInputCount: publicInputCount,
                ringDegree: CyclotomicRing54.degree
            ))
        }
        return requirements
    }

    private static func unsupported(_ requirements: [SuperNeoFoldingShapeRequirement]) -> SuperNeoError {
        let requirement = requirements.map(\.description).joined(separator: "; ")
        return .invalidParameter(
            "SuperNeo folding requires a paper-normalized CCS shape: \(requirement); use SuperNeoCCSNormalizer.normalize(...) for general CCS inputs"
        )
    }

    private func isIdentityPrefix(_ matrix: SparseFieldMatrix) -> Bool {
        (try? SparseMatrixCSR(matrix).isIdentityPrefix) == true
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

public struct SuperNeoPreparedFoldInput: Sendable {
    public let normalized: NormalizedCCS
    public let key: AjtaiCommitmentKey
    public let originalNormalizationRequirements: [SuperNeoFoldingShapeRequirement]

    public var requiresNormalization: Bool {
        !originalNormalizationRequirements.isEmpty
    }

    public var foldInput: SuperNeoFoldInput {
        normalized.foldInput
    }

    public var publicFoldInput: SuperNeoPublicFoldInput {
        normalized.publicFoldInput
    }
}

public enum SuperNeoCCSNormalizer {
    /// Prover-side preparation for arbitrary serializable CCS inputs.
    /// Commitments are recomputed against the returned key after any padding or shape changes.
    public static func prepareForFolding(
        structure: CCSStructure,
        instances: [CCSInstance],
        witnesses: [CCSWitness],
        priorClaims: [CCSEvaluationClaim] = [],
        keySeed: [UInt8],
        parameters: SuperNeoParameters = .goldilocks
    ) throws -> SuperNeoPreparedFoldInput {
        guard !instances.isEmpty else {
            throw SuperNeoError.invalidParameter("fold preparation requires at least one CCS instance")
        }
        let publicInputCount = instances.first?.publicInput.count ?? 0
        let requirements = try SuperNeoFoldingShapeContract.paperNormalized.normalizationRequirements(
            for: structure,
            publicInputCount: publicInputCount
        )
        let result = try normalize(
            structure: structure,
            instances: instances,
            witnesses: witnesses,
            priorClaims: priorClaims,
            keySeed: keySeed,
            parameters: parameters
        )
        try SuperNeoFoldingShapeContract.paperNormalized.validate(result.normalized.shape)
        return SuperNeoPreparedFoldInput(
            normalized: result.normalized,
            key: result.key,
            originalNormalizationRequirements: requirements
        )
    }

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
        try SuperNeoFoldingShapeContract.paperNormalized.validate(shape)
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
