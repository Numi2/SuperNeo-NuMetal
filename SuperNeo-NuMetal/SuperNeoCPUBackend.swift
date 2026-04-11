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

    public func transformedMatrixVector(
        matrix: SparseFieldMatrix,
        vector: [GoldilocksField]
    ) throws -> [CyclotomicRing54] {
        let transformed = try matrix.transformedForSuperNeo()
        return try transformed.multiplied(by: embed(vector))
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

}
