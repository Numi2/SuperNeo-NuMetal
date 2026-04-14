import Foundation

public struct SuperNeoCPUBackend: Sendable {
    public let parameters: SuperNeoParameters

    public init(parameters: SuperNeoParameters = .goldilocks) {
        self.parameters = parameters
    }

    public func embed(_ vector: [GoldilocksField]) throws -> [CyclotomicRing54] {
        try SuperNeoEmbedding.packPadded(vector)
    }

    public func commit(key: AjtaiCommitmentKey, message: [GoldilocksField]) throws -> AjtaiCommitment {
        try AjtaiCommitter.commitReference(key: key, fieldWitness: message)
    }

    public func commitConstantWork(key: AjtaiCommitmentKey, message: [GoldilocksField]) throws -> AjtaiCommitment {
        try AjtaiCommitter.commitConstantWorkReference(key: key, fieldWitness: message)
    }

    public func commitConstantWork(key: AjtaiCommitmentKey, message: [CyclotomicRing54]) throws -> AjtaiCommitment {
        try AjtaiCommitter.commitConstantWorkReference(key: key, message: message)
    }

    public func transformedMatrix(_ matrix: SparseFieldMatrix) throws -> RingMatrix {
        try matrix.transformedForSuperNeo()
    }

    public func transformedSparseMatrix(_ matrix: SparseFieldMatrix) throws -> SparseRingMatrixCSR {
        try matrix.transformedSparseForSuperNeo()
    }

    public func transformedMatrixVector(
        matrix: SparseFieldMatrix,
        vector: [GoldilocksField]
    ) throws -> [CyclotomicRing54] {
        let transformed = try matrix.transformedForSuperNeo()
        return try transformed.multiplied(by: embed(vector))
    }

    public func transformedSparseMatrixVector(
        matrix: SparseFieldMatrix,
        vector: [GoldilocksField]
    ) throws -> [CyclotomicRing54] {
        let transformed = try matrix.transformedSparseForSuperNeo()
        return try transformed.multiplied(by: embed(vector))
    }

    public func transformedEvaluation(
        rows: [CyclotomicRing54],
        rHat: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        guard rows.count == rHat.count else {
            throw SuperNeoError.invalidParameter("transformed evaluation row/rHat length mismatch")
        }
        var coefficients = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for row in rows.indices {
            let weight = rHat[row]
            let rowCoefficients = rows[row].coefficients
            for coefficientIndex in 0..<CyclotomicRing54.degree {
                let coefficient = rowCoefficients[coefficientIndex]
                guard coefficient != .zero else { continue }
                coefficients[coefficientIndex] = coefficients[coefficientIndex] + weight.scaled(by: coefficient)
            }
        }
        return coefficients
    }

    public func transformedEvaluation(
        matrix: RingMatrix,
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        try matrix.evaluatedProduct(
            by: vector,
            rHat: MultilinearEvaluation.checkedBasis(at: point)
        ).coefficients
    }

    public func transformedEvaluation(
        matrix: SparseRingMatrixCSR,
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        try matrix.evaluatedProduct(
            by: vector,
            rHat: MultilinearEvaluation.checkedBasis(at: point)
        ).coefficients
    }

    public func matrixVectorConstants(
        matrix: SparseFieldMatrix,
        vector: [GoldilocksField]
    ) throws -> [GoldilocksField] {
        try transformedMatrixVector(matrix: matrix, vector: vector).map(\.constantTerm)
    }

    public func multilinearEvaluation(
        matrix: SparseFieldMatrix,
        vector: [GoldilocksField],
        point: [GoldilocksExt2]
    ) throws -> GoldilocksExt2 {
        let product = try matrix.multiplied(by: vector)
        return try MultilinearEvaluation.evaluate(product, at: point)
    }

    public func makeProver(
        key: AjtaiCommitmentKey,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> SuperNeoProver {
        SuperNeoProver(parameters: parameters, key: key, context: nil, executionPolicy: executionPolicy)
    }

    public func makeVerifier(
        key: AjtaiCommitmentKey,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) -> SuperNeoVerifier {
        SuperNeoVerifier(parameters: parameters, key: key, context: nil, executionPolicy: executionPolicy)
    }

}
