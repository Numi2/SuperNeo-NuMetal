import Foundation

public struct NormalizedCCSMapping: Equatable, Sendable {
    public let originalRowCount: Int
    public let originalFieldColumnCount: Int
    public let originalPublicInputCount: Int
    public let normalizedRowCount: Int
    public let normalizedFieldColumnCount: Int
    public let normalizedPublicInputCount: Int

    public var addedRows: Int { normalizedRowCount - originalRowCount }
    public var addedFieldColumns: Int { normalizedFieldColumnCount - originalFieldColumnCount }
    public var addedPublicInputs: Int { normalizedPublicInputCount - originalPublicInputCount }
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
            normalizedPublicInputCount: normalizedPublicInputCount
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
