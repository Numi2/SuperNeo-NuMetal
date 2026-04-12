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
        for coefficientIndex in 0..<CyclotomicRing54.degree {
            var total = GoldilocksExt2.zero
            for row in rows.indices {
                let coefficient = rows[row].coefficients[coefficientIndex]
                guard coefficient != .zero else { continue }
                total = total + rHat[row].scaled(by: coefficient)
            }
            coefficients[coefficientIndex] = total
        }
        return coefficients
    }

    public func transformedEvaluation(
        matrix: RingMatrix,
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        let rows = try matrix.multiplied(by: vector)
        return try transformedEvaluation(rows: rows, rHat: MultilinearEvaluation.checkedBasis(at: point))
    }

    public func transformedEvaluation(
        matrix: SparseRingMatrixCSR,
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        let rows = try matrix.multiplied(by: vector)
        return try transformedEvaluation(rows: rows, rHat: MultilinearEvaluation.checkedBasis(at: point))
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

    public func makeProver(key: AjtaiCommitmentKey) -> SuperNeoProver {
        SuperNeoProver(parameters: parameters, key: key, context: nil)
    }

    public func makeVerifier(key: AjtaiCommitmentKey) -> SuperNeoVerifier {
        SuperNeoVerifier(parameters: parameters, key: key, context: nil)
    }

}
