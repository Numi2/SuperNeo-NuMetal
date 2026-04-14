import Foundation
import Metal

fileprivate struct SparseRingMatrixBuffers {
    let rowOffsets: MTLBuffer
    let columnIndices: MTLBuffer
    let values: MTLBuffer
    let matvecParams: MTLBuffer
    let dotParams: MTLBuffer
    let rows: Int
    let columns: Int
}

fileprivate struct SparseRingMatrixBatchBuffers {
    let rowOffsets: MTLBuffer
    let columnIndices: MTLBuffer
    let values: MTLBuffer
    let matrixCount: Int
    let rows: Int
    let columns: Int
}

fileprivate enum SparseEvaluationDispatchPlan {
    case rowPartial(wordCount: Int)
    case blocked(wordCount: Int)
    case fused
}

public final class SuperNeoMetalWorkspace: @unchecked Sendable {
    public let context: MetalExecutionContext
    public let key: AjtaiCommitmentKey
    public let shapeDigest: Digest256?
    public let transformedMatrixCount: Int
    public let transformedMatricesDigest: Digest256

    fileprivate let keyMatrixBuffer: MTLBuffer
    fileprivate let transformedSparseMatrices: [SparseRingMatrixCSR]
    fileprivate let transformedMatrixBuffers: [SparseRingMatrixBuffers]
    fileprivate let transformedMatrixBatchBuffers: SparseRingMatrixBatchBuffers?

    public convenience init(
        context: MetalExecutionContext,
        key: AjtaiCommitmentKey,
        compiledShape: CompiledCCSShape
    ) throws {
        try self.init(
            context: context,
            key: key,
            transformedSparseMatrices: compiledShape.transformedSparseMatrices,
            shapeDigest: compiledShape.shape.shapeDigest
        )
    }

    public init(
        context: MetalExecutionContext,
        key: AjtaiCommitmentKey,
        transformedSparseMatrices: [SparseRingMatrixCSR],
        shapeDigest: Digest256? = nil
    ) throws {
        guard key.matrix.rows == key.parameters.kappa else {
            throw SuperNeoError.invalidParameter("Ajtai matrix row count must equal kappa")
        }
        guard key.matrix.columns > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai matrix must have at least one column")
        }
        guard transformedSparseMatrices.allSatisfy({ $0.columns == key.matrix.columns }) else {
            throw SuperNeoError.invalidParameter("transformed matrix column count must match Ajtai key columns")
        }

        let backend = SuperNeoMetalBackend(context: context)
        self.context = context
        self.key = key
        self.shapeDigest = shapeDigest
        self.transformedMatrixCount = transformedSparseMatrices.count
        self.transformedMatricesDigest = Self.transformedMatricesDigest(for: transformedSparseMatrices)
        self.keyMatrixBuffer = try context.makeBuffer(backend.flatten(key.matrix.elements))
        self.transformedSparseMatrices = transformedSparseMatrices
        let batchBuffers = try backend.makeSparseRingMatrixBatchBuffers(transformedSparseMatrices)
        self.transformedMatrixBatchBuffers = batchBuffers
        if batchBuffers == nil {
            self.transformedMatrixBuffers = try transformedSparseMatrices.map {
                try backend.makeSparseRingMatrixBuffers($0)
            }
        } else {
            self.transformedMatrixBuffers = []
        }
    }

    public func ajtaiCommitments(
        messages: [[CyclotomicRing54]],
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> [AjtaiCommitment] {
        if executionPolicy.usesConstantWorkCPU {
            return try cpuAjtaiCommitments(messages: messages, executionPolicy: executionPolicy)
        }
        let commitments = try SuperNeoMetalBackend(context: context).ajtaiCommitments(
            key: key,
            messages: messages,
            schedule: schedule,
            matrixBuffer: keyMatrixBuffer
        )
        if executionPolicy.requiresMetalCPUCheck {
            guard commitments == (try cpuAjtaiCommitments(messages: messages, executionPolicy: executionPolicy)) else {
                throw SuperNeoError.metalFailure("Metal workspace Ajtai commitments failed CPU cross-check")
            }
        }
        return commitments
    }

    public func transformedEvaluations(
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> [CyclotomicExt2Ring54] {
        guard let evaluations = try transformedEvaluations(
            vectors: [vector],
            point: point,
            executionPolicy: executionPolicy
        ).first else {
            return []
        }
        return evaluations
    }

    public func transformedEvaluations(
        vectors: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> [[CyclotomicExt2Ring54]] {
        if executionPolicy.usesConstantWorkCPU {
            return try cpuTransformedEvaluations(vectors: vectors, point: point, executionPolicy: executionPolicy)
        }
        let evaluations: [[CyclotomicExt2Ring54]]
        if let transformedMatrixBatchBuffers {
            evaluations = try SuperNeoMetalBackend(context: context).transformedEvaluations(
                batchBuffers: transformedMatrixBatchBuffers,
                vectors: vectors,
                point: point
            )
        } else {
            evaluations = try SuperNeoMetalBackend(context: context).transformedEvaluations(
                matrixBuffers: transformedMatrixBuffers,
                vectors: vectors,
                point: point
            )
        }
        if executionPolicy.requiresMetalCPUCheck {
            guard evaluations == (try cpuTransformedEvaluations(vectors: vectors, point: point, executionPolicy: executionPolicy)) else {
                throw SuperNeoError.metalFailure("Metal workspace transformed evaluations failed CPU cross-check")
            }
        }
        return evaluations
    }

    public func commitmentsAndTransformedEvaluations(
        messages: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        schedule: AjtaiMatvecSchedule = .default,
        executionPolicy: SuperNeoExecutionPolicy = .default
    ) throws -> (commitments: [AjtaiCommitment], evaluations: [[CyclotomicExt2Ring54]]) {
        if executionPolicy.usesConstantWorkCPU {
            return (
                try cpuAjtaiCommitments(messages: messages, executionPolicy: executionPolicy),
                try cpuTransformedEvaluations(vectors: messages, point: point, executionPolicy: executionPolicy)
            )
        }
        guard let transformedMatrixBatchBuffers else {
            return (
                try ajtaiCommitments(messages: messages, schedule: schedule, executionPolicy: executionPolicy),
                try transformedEvaluations(vectors: messages, point: point, executionPolicy: executionPolicy)
            )
        }
        let combined = try SuperNeoMetalBackend(context: context).commitmentsAndTransformedEvaluations(
            key: key,
            messages: messages,
            point: point,
            schedule: schedule,
            matrixBuffer: keyMatrixBuffer,
            batchBuffers: transformedMatrixBatchBuffers
        )
        if executionPolicy.requiresMetalCPUCheck {
            let cpuCommitments = try cpuAjtaiCommitments(messages: messages, executionPolicy: executionPolicy)
            let cpuEvaluations = try cpuTransformedEvaluations(vectors: messages, point: point, executionPolicy: executionPolicy)
            guard combined.commitments == cpuCommitments, combined.evaluations == cpuEvaluations else {
                throw SuperNeoError.metalFailure("Metal workspace combined commit/eval failed CPU cross-check")
            }
        }
        return combined
    }

    private func cpuAjtaiCommitments(
        messages: [[CyclotomicRing54]],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> [AjtaiCommitment] {
        try messages.map { message in
            if executionPolicy.usesConstantWorkCPU {
                return try AjtaiCommitter.commitConstantWorkReference(key: key, message: message)
            }
            return try AjtaiCommitter.commitReference(key: key, message: message)
        }
    }

    private func cpuTransformedEvaluations(
        vectors: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> [[CyclotomicExt2Ring54]] {
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        return try vectors.map { vector in
            try transformedSparseMatrices.map { matrix in
                let rows: [CyclotomicRing54]
                if executionPolicy.usesConstantWorkCPU {
                    rows = try matrix.multipliedConstantWork(by: vector)
                } else {
                    rows = try matrix.multiplied(by: vector)
                }
                return try Self.evaluateExtensionRingRows(
                    rows,
                    rHat: rHat,
                    constantWork: executionPolicy.usesConstantWorkCPU
                )
            }
        }
    }

    private static func evaluateExtensionRingRows(
        _ rows: [CyclotomicRing54],
        rHat: [GoldilocksExt2],
        constantWork: Bool
    ) throws -> CyclotomicExt2Ring54 {
        guard rows.count == rHat.count else {
            throw SuperNeoError.invalidParameter("extension-ring row/rHat length mismatch")
        }
        var coefficients = Array(repeating: GoldilocksExt2.zero, count: CyclotomicRing54.degree)
        for rowIndex in rows.indices {
            let weight = rHat[rowIndex]
            let rowCoefficients = rows[rowIndex].coefficients
            for coefficientIndex in 0..<CyclotomicRing54.degree {
                let coefficient = rowCoefficients[coefficientIndex]
                if !constantWork, coefficient == .zero {
                    continue
                }
                coefficients[coefficientIndex] = coefficients[coefficientIndex]
                    + (constantWork || coefficient != .one ? weight.scaled(by: coefficient) : weight)
            }
        }
        return CyclotomicExt2Ring54(coefficients)
    }

    public static func transformedMatricesDigest(for matrices: [SparseRingMatrixCSR]) -> Digest256 {
        var bytes = Array("SuperNeo-NuMetal.metal.transformed-matrices.v1".utf8)
        bytes.append(contentsOf: metalDigestEncodeCount(matrices.count))
        for matrix in matrices {
            bytes.append(contentsOf: metalDigestEncodeCount(matrix.rows))
            bytes.append(contentsOf: metalDigestEncodeCount(matrix.columns))
            bytes.append(contentsOf: metalDigestEncodeCount(matrix.rowOffsets.count))
            matrix.rowOffsets.forEach { bytes.append(contentsOf: metalDigestEncodeCount($0)) }
            bytes.append(contentsOf: metalDigestEncodeCount(matrix.columnIndices.count))
            matrix.columnIndices.forEach { bytes.append(contentsOf: metalDigestEncodeCount($0)) }
            bytes.append(contentsOf: metalDigestEncodeCount(matrix.values.count))
            matrix.values.forEach { bytes.append(contentsOf: $0.littleEndianBytes) }
        }
        return Digest256.hash(bytes)
    }
}

public final class SuperNeoMetalBackend: @unchecked Sendable {
    private static let fusedEvaluationRowBlockSize: Int = {
        guard let rawValue = ProcessInfo.processInfo.environment["SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE"],
              let value = Int(rawValue),
              value > 0 else {
            return 128
        }
        return value
    }()
    private static let fusedEvaluationRowPartialThreshold: Int = {
        guard let rawValue = ProcessInfo.processInfo.environment["SUPERNEO_METAL_EVAL_ROW_PARTIAL_THRESHOLD"],
              let value = Int(rawValue),
              value > 0 else {
            // Correct but not a default win on the current m64 local benchmark;
            // keep it available for hardware/profile tuning.
            return Int.max
        }
        return value
    }()
    private static let fusedEvaluationRowPartialMaxWordCount: Int = {
        guard let rawValue = ProcessInfo.processInfo.environment["SUPERNEO_METAL_EVAL_ROW_PARTIAL_MAX_WORDS"],
              let value = Int(rawValue),
              value > 0 else {
            return 4_194_304
        }
        return value
    }()
    private static let fusedEvaluationBlockedRowThreshold = 512
    private static let sparseAwareDenseMatvecColumnThreshold = 128

    public let context: MetalExecutionContext

    public init(context: MetalExecutionContext) {
        self.context = context
    }

    public func add(_ lhs: [GoldilocksField], _ rhs: [GoldilocksField]) throws -> [GoldilocksField] {
        try binaryFieldOperation(lhs, rhs, pipelineName: "goldilocks_add_kernel")
    }

    public func subtract(_ lhs: [GoldilocksField], _ rhs: [GoldilocksField]) throws -> [GoldilocksField] {
        try binaryFieldOperation(lhs, rhs, pipelineName: "goldilocks_sub_kernel")
    }

    public func multiply(_ lhs: [GoldilocksField], _ rhs: [GoldilocksField]) throws -> [GoldilocksField] {
        try binaryFieldOperation(lhs, rhs, pipelineName: "goldilocks_mul_kernel")
    }

    public func add(_ lhs: [CyclotomicRing54], _ rhs: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard lhs.count == rhs.count else {
            throw SuperNeoError.invalidParameter("ring vector length mismatch")
        }
        let output = try binaryRawOperation(flatten(lhs), flatten(rhs), pipelineName: "ring_add_kernel")
        return try inflateRings(output)
    }

    public func multiply(_ rings: [CyclotomicRing54], by scalars: [GoldilocksField]) throws -> [CyclotomicRing54] {
        guard rings.count == scalars.count else {
            throw SuperNeoError.invalidParameter("ring/scalar vector length mismatch")
        }
        guard !rings.isEmpty else { return [] }
        let ringBuffer = try context.makeBuffer(flatten(rings))
        let scalarBuffer = try context.makeBuffer(scalars.map(\.rawValue))
        let coefficientCount = try checkedProduct(
            [rings.count, CyclotomicRing54.degree],
            name: "ring scalar output coefficient count"
        )
        let outputBuffer = try context.makeEmptyBuffer(count: coefficientCount, as: UInt64.self)
        try context.dispatch1D(
            pipelineName: "ring_scalar_mul_kernel",
            buffers: [ringBuffer, scalarBuffer, outputBuffer],
            elementCount: coefficientCount
        )
        return try inflateRings(outputBuffer.array(of: UInt64.self, count: coefficientCount))
    }

    public func multiply(_ lhs: [CyclotomicRing54], _ rhs: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard lhs.count == rhs.count else {
            throw SuperNeoError.invalidParameter("ring vector length mismatch")
        }
        guard !lhs.isEmpty else { return [] }
        let lhsBuffer = try context.makeBuffer(flatten(lhs))
        let rhsBuffer = try context.makeBuffer(flatten(rhs))
        let coefficientCount = try checkedProduct(
            [lhs.count, CyclotomicRing54.degree],
            name: "ring multiplication output coefficient count"
        )
        let outputBuffer = try context.makeEmptyBuffer(count: coefficientCount, as: UInt64.self)
        try context.dispatch1D(
            pipelineName: "ring_mul_kernel",
            buffers: [lhsBuffer, rhsBuffer, outputBuffer],
            elementCount: coefficientCount
        )
        return try inflateRings(outputBuffer.array(of: UInt64.self, count: coefficientCount))
    }

    public func ajtaiCommitment(
        key: AjtaiCommitmentKey,
        message: [CyclotomicRing54],
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> AjtaiCommitment {
        guard let commitment = try ajtaiCommitments(
            key: key,
            messages: [message],
            schedule: schedule
        ).first else {
            throw SuperNeoError.invalidParameter("Ajtai scheduler produced no commitment")
        }
        return commitment
    }

    public func ajtaiCommitments(
        key: AjtaiCommitmentKey,
        messages: [[CyclotomicRing54]],
        schedule: AjtaiMatvecSchedule = .default
    ) throws -> [AjtaiCommitment] {
        guard key.matrix.rows == key.parameters.kappa else {
            throw SuperNeoError.invalidParameter("Ajtai matrix row count must equal kappa")
        }
        guard key.matrix.columns > 0 else {
            throw SuperNeoError.invalidParameter("Ajtai matrix must have at least one column")
        }
        guard messages.allSatisfy({ $0.count == key.matrix.columns }) else {
            throw SuperNeoError.invalidParameter("Ajtai message length must equal key column count")
        }
        guard !messages.isEmpty else { return [] }

        let planned = schedule.planned(for: key, messageCount: messages.count)
        let matrixBuffer = try context.makeBuffer(flatten(key.matrix.elements))
        return try ajtaiCommitments(
            key: key,
            messages: messages,
            schedule: planned,
            matrixBuffer: matrixBuffer
        )
    }

    fileprivate func ajtaiCommitments(
        key: AjtaiCommitmentKey,
        messages: [[CyclotomicRing54]],
        schedule: AjtaiMatvecSchedule,
        matrixBuffer: MTLBuffer
    ) throws -> [AjtaiCommitment] {
        guard !messages.isEmpty else { return [] }
        guard messages.allSatisfy({ $0.count == key.matrix.columns }) else {
            throw SuperNeoError.invalidParameter("Ajtai message length must equal key column count")
        }

        let planned = schedule.planned(for: key, messageCount: messages.count)
        var commitments: [AjtaiCommitment] = []
        commitments.reserveCapacity(messages.count)

        var batchStart = 0
        while batchStart < messages.count {
            let batchEnd = min(batchStart + planned.maxBatchSize, messages.count)
            let batchMessages = Array(messages[batchStart..<batchEnd])
            switch planned.kernel {
            case .coefficient:
                commitments.append(contentsOf: try ajtaiCommitmentsCoefficientBatch(
                    key: key,
                    messages: batchMessages,
                    matrixBuffer: matrixBuffer
                ))
            case .tiled:
                commitments.append(contentsOf: try ajtaiCommitmentsBatch(
                    key: key,
                    messages: batchMessages,
                    schedule: planned,
                    matrixBuffer: matrixBuffer
                ))
            }
            batchStart = batchEnd
        }

        return commitments
    }

    private func ajtaiCommitmentsCoefficientBatch(
        key: AjtaiCommitmentKey,
        messages: [[CyclotomicRing54]],
        matrixBuffer: MTLBuffer
    ) throws -> [AjtaiCommitment] {
        let rowCount = key.matrix.rows
        let columnCount = key.matrix.columns
        let batchCount = messages.count
        let outputRingCount = try checkedProduct([batchCount, rowCount], name: "Ajtai output ring count")
        let outputCoefficientCount = try checkedProduct(
            [outputRingCount, CyclotomicRing54.degree],
            name: "Ajtai output coefficient count"
        )
        let messageWords = flatten(messages)
        let messageBuffer = try context.makeBuffer(messageWords)
        let outputBuffer = try context.makeEmptyBuffer(
            count: outputCoefficientCount,
            as: UInt64.self
        )
        let params = try [
            checkedUInt32(rowCount, name: "Ajtai row count"),
            checkedUInt32(columnCount, name: "Ajtai column count"),
            checkedUInt32(batchCount, name: "Ajtai batch count")
        ]
        let pipelineName = rawWordsUseOnlySmallCoefficients(messageWords)
            ? "ajtai_matvec_ring_batch_coeff_small_message_kernel"
            : "ajtai_matvec_ring_batch_coeff_kernel"
        try context.dispatch1D(
            pipelineName: pipelineName,
            buffers: [matrixBuffer, messageBuffer, outputBuffer],
            inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 3, values: params)],
            countBufferIndex: 4,
            elementCount: outputCoefficientCount
        )

        return try ajtaiCommitmentResults(
            outputBuffer: outputBuffer,
            outputRingCount: outputRingCount,
            rowCount: rowCount
        )
    }

    public func transformedMatrixVector(matrix: RingMatrix, vector: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard matrix.columns == vector.count else {
            throw SuperNeoError.invalidParameter("transformed matrix/vector dimension mismatch")
        }
        guard matrix.rows > 0 else { return [] }
        let matrixBuffer = try context.makeBuffer(flatten(matrix.elements))
        let vectorBuffer = try context.makeBuffer(flatten(vector))
        let outputCount = try checkedProduct(
            [matrix.rows, CyclotomicRing54.degree],
            name: "transformed matrix output coefficient count"
        )
        let outputBuffer = try context.makeEmptyBuffer(count: outputCount, as: UInt64.self)
        let params = try [
            checkedUInt32(matrix.rows, name: "transformed matrix row count"),
            checkedUInt32(matrix.columns, name: "transformed matrix column count")
        ]
        let pipelineName = matrix.columns >= Self.sparseAwareDenseMatvecColumnThreshold
            ? "transformed_matvec_sparse_aware_kernel"
            : "transformed_matvec_kernel"
        try context.dispatch1D(
            pipelineName: pipelineName,
            buffers: [matrixBuffer, vectorBuffer, outputBuffer],
            inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 3, values: params)],
            countBufferIndex: 4,
            elementCount: matrix.rows
        )
        return try inflateRings(outputBuffer.array(of: UInt64.self, count: outputCount))
    }

    public func transformedMatrixVector(matrix: SparseRingMatrixCSR, vector: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard matrix.columns == vector.count else {
            throw SuperNeoError.invalidParameter("sparse transformed matrix/vector dimension mismatch")
        }
        guard matrix.rows > 0 else { return [] }
        let rowOffsetsBuffer = try context.makeBuffer(try checkedUInt32Array(matrix.rowOffsets, name: "sparse row offset"))
        let columnIndicesBuffer = try context.makeBuffer(try checkedUInt32Array(matrix.columnIndices, name: "sparse column index"))
        let valuesBuffer = try context.makeBuffer(flatten(matrix.values))
        let vectorBuffer = try context.makeBuffer(flatten(vector))
        let outputCount = try checkedProduct(
            [matrix.rows, CyclotomicRing54.degree],
            name: "sparse transformed matrix output coefficient count"
        )
        let outputBuffer = try context.makeEmptyBuffer(count: outputCount, as: UInt64.self)
        let params = try [
            checkedUInt32(matrix.rows, name: "sparse transformed matrix row count"),
            checkedUInt32(matrix.columns, name: "sparse transformed matrix column count"),
            checkedUInt32(matrix.values.count, name: "sparse transformed matrix value count")
        ]
        try context.dispatch1D(
            pipelineName: "sparse_transformed_matvec_kernel",
            buffers: [rowOffsetsBuffer, columnIndicesBuffer, valuesBuffer, vectorBuffer, outputBuffer],
            inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 5, values: params)],
            countBufferIndex: 6,
            elementCount: matrix.rows
        )
        return try inflateRings(outputBuffer.array(of: UInt64.self, count: outputCount))
    }

    public func transformedEvaluation(rows: [CyclotomicRing54], rHat: [GoldilocksExt2]) throws -> [GoldilocksExt2] {
        guard rows.count == rHat.count else {
            throw SuperNeoError.invalidParameter("transformed evaluation row/rHat length mismatch")
        }
        guard !rows.isEmpty else { return Array(repeating: .zero, count: CyclotomicRing54.degree) }
        let rowsBuffer = try context.makeBuffer(flatten(rows))
        let rHatBuffer = try context.makeBuffer(flattenExt2(rHat))
        let outputBuffer = try context.makeEmptyBuffer(count: CyclotomicRing54.degree * 2, as: UInt64.self)
        let params = try [
            checkedUInt32(rows.count, name: "transformed evaluation row count")
        ]
        try context.dispatch1D(
            pipelineName: "transformed_eval_dot_kernel",
            buffers: [rowsBuffer, rHatBuffer, outputBuffer],
            inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 3, values: params)],
            countBufferIndex: 4,
            elementCount: CyclotomicRing54.degree
        )
        return inflateExt2(outputBuffer.array(of: UInt64.self, count: CyclotomicRing54.degree * 2))
    }

    public func transformedEvaluation(
        matrix: RingMatrix,
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        guard rHat.count == matrix.rows else {
            throw SuperNeoError.invalidParameter("evaluation point dimension must match transformed matrix row count")
        }
        let rows = try transformedMatrixVector(matrix: matrix, vector: vector)
        return try transformedEvaluation(rows: rows, rHat: rHat)
    }

    public func transformedEvaluation(
        matrix: SparseRingMatrixCSR,
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [GoldilocksExt2] {
        guard let evaluation = try transformedEvaluations(
            matrices: [matrix],
            vectors: [vector],
            point: point
        ).first?.first else {
            throw SuperNeoError.invalidParameter("sparse transformed evaluation produced no result")
        }
        return evaluation.coefficients
    }

    public func transformedEvaluations(
        matrices: [SparseRingMatrixCSR],
        vector: [CyclotomicRing54],
        point: [GoldilocksExt2]
    ) throws -> [CyclotomicExt2Ring54] {
        guard let evaluations = try transformedEvaluations(
            matrices: matrices,
            vectors: [vector],
            point: point
        ).first else {
            return []
        }
        return evaluations
    }

    public func transformedEvaluations(
        matrices: [SparseRingMatrixCSR],
        vectors: [[CyclotomicRing54]],
        point: [GoldilocksExt2]
    ) throws -> [[CyclotomicExt2Ring54]] {
        guard !vectors.isEmpty else { return [] }
        guard !matrices.isEmpty else {
            return Array(repeating: [], count: vectors.count)
        }

        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        for matrix in matrices {
            guard matrix.rows == rHat.count else {
                throw SuperNeoError.invalidParameter("evaluation point dimension must match sparse transformed matrix row count")
            }
        }
        let firstMatrix = matrices[0]
        let canUseBatchBuffers = matrices.allSatisfy {
            $0.rows == firstMatrix.rows && $0.columns == firstMatrix.columns
        }
        if canUseBatchBuffers, let batchBuffers = try makeSparseRingMatrixBatchBuffers(matrices) {
            return try transformedEvaluations(
                batchBuffers: batchBuffers,
                vectors: vectors,
                point: point
            )
        }

        let matrixBuffers = try matrices.map { try makeSparseRingMatrixBuffers($0) }

        return try transformedEvaluations(
            matrixBuffers: matrixBuffers,
            vectors: vectors,
            point: point
        )
    }

    fileprivate func transformedEvaluations(
        matrixBuffers: [SparseRingMatrixBuffers],
        vectors: [[CyclotomicRing54]],
        point: [GoldilocksExt2]
    ) throws -> [[CyclotomicExt2Ring54]] {
        guard !vectors.isEmpty else { return [] }
        guard !matrixBuffers.isEmpty else {
            return Array(repeating: [], count: vectors.count)
        }

        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        let rHatBuffer = try context.makeBuffer(flattenExt2(rHat))
        for buffers in matrixBuffers where buffers.rows != rHat.count {
            throw SuperNeoError.invalidParameter("evaluation point dimension must match sparse transformed matrix row count")
        }

        let vectorBuffers = try vectors.map { vector -> MTLBuffer in
            for buffers in matrixBuffers where buffers.columns != vector.count {
                throw SuperNeoError.invalidParameter("sparse transformed matrix/vector dimension mismatch")
            }
            return try context.makeBuffer(flatten(vector))
        }

        var commands: [MetalDispatchCommand] = []
        commands.reserveCapacity(try checkedProduct(
            [vectors.count, matrixBuffers.count, 2],
            name: "sparse transformed evaluation command count"
        ))
        var outputBuffers = Array(repeating: [MTLBuffer](), count: vectors.count)

        for vectorIndex in vectors.indices {
            outputBuffers[vectorIndex].reserveCapacity(matrixBuffers.count)
            for matrixIndex in matrixBuffers.indices {
                let buffers = matrixBuffers[matrixIndex]
                let rowCoefficientCount = try checkedProduct(
                    [buffers.rows, CyclotomicRing54.degree],
                    name: "sparse transformed evaluation row coefficient count"
                )
                let rowsBuffer = try context.makeEmptyBuffer(count: rowCoefficientCount, as: UInt64.self)
                let outputBuffer = try context.makeEmptyBuffer(
                    count: CyclotomicRing54.degree * 2,
                    as: UInt64.self
                )
                outputBuffers[vectorIndex].append(outputBuffer)
                commands.append(MetalDispatchCommand(
                    pipelineName: "sparse_transformed_matvec_kernel",
                    buffers: [
                        buffers.rowOffsets,
                        buffers.columnIndices,
                        buffers.values,
                        vectorBuffers[vectorIndex],
                        rowsBuffer,
                        buffers.matvecParams
                    ],
                    elementCount: buffers.rows
                ))
                commands.append(MetalDispatchCommand(
                    pipelineName: "transformed_eval_dot_kernel",
                    buffers: [
                        rowsBuffer,
                        rHatBuffer,
                        outputBuffer,
                        buffers.dotParams
                    ],
                    elementCount: CyclotomicRing54.degree,
                    barrierAfter: false
                ))
            }
        }

        try context.dispatch1DSequence(commands)
        return outputBuffers.map { vectorOutputs in
            vectorOutputs.map { outputBuffer in
                CyclotomicExt2Ring54(inflateExt2(outputBuffer.array(
                    of: UInt64.self,
                    count: CyclotomicRing54.degree * 2
                )))
            }
        }
    }

    fileprivate func transformedEvaluations(
        batchBuffers: SparseRingMatrixBatchBuffers,
        vectors: [[CyclotomicRing54]],
        point: [GoldilocksExt2]
    ) throws -> [[CyclotomicExt2Ring54]] {
        guard !vectors.isEmpty else { return [] }
        guard batchBuffers.matrixCount > 0 else {
            return Array(repeating: [], count: vectors.count)
        }
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        guard rHat.count == batchBuffers.rows else {
            throw SuperNeoError.invalidParameter("evaluation point dimension must match sparse transformed matrix row count")
        }
        for vector in vectors where vector.count != batchBuffers.columns {
            throw SuperNeoError.invalidParameter("sparse transformed matrix/vector dimension mismatch")
        }

        let vectorWords = flatten(vectors)
        let rHatWords = flattenExt2(rHat)
        let outputWordCount = try checkedProduct(
            [vectors.count, batchBuffers.matrixCount, CyclotomicRing54.degree, 2],
            name: "sparse transformed evaluation output word count"
        )
        let rowBlockSize = Self.fusedEvaluationRowBlockSize
        let rowBlockCount = try checkedCeilDiv(
            batchBuffers.rows,
            by: rowBlockSize,
            name: "sparse transformed evaluation row block count"
        )
        let dispatchPlan: SparseEvaluationDispatchPlan
        if batchBuffers.rows >= Self.fusedEvaluationRowPartialThreshold,
           batchBuffers.rows < Self.fusedEvaluationBlockedRowThreshold {
            let rowPartialWordCount = try checkedProduct(
                [vectors.count, batchBuffers.matrixCount, batchBuffers.rows, CyclotomicRing54.degree, 2],
                name: "sparse transformed evaluation row partial word count"
            )
            if rowPartialWordCount <= Self.fusedEvaluationRowPartialMaxWordCount {
                dispatchPlan = .rowPartial(wordCount: rowPartialWordCount)
            } else {
                dispatchPlan = .fused
            }
        } else if batchBuffers.rows >= Self.fusedEvaluationBlockedRowThreshold, rowBlockCount > 1 {
            let partialWordCount = try checkedProduct(
                [vectors.count, batchBuffers.matrixCount, rowBlockCount, CyclotomicRing54.degree, 2],
                name: "sparse transformed evaluation partial word count"
            )
            dispatchPlan = .blocked(wordCount: partialWordCount)
        } else {
            dispatchPlan = .fused
        }

        var requests = try [
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: vectorWords.count,
                    as: UInt64.self,
                    role: "sparse transformed evaluation vector buffer"
                ),
                role: "sparse transformed evaluation vector buffer"
            ),
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: rHatWords.count,
                    as: UInt64.self,
                    role: "sparse transformed evaluation rHat buffer"
                ),
                role: "sparse transformed evaluation rHat buffer"
            ),
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: outputWordCount,
                    as: UInt64.self,
                    role: "sparse transformed evaluation output buffer"
                ),
                role: "sparse transformed evaluation output buffer"
            )
        ]
        switch dispatchPlan {
        case .rowPartial(let wordCount), .blocked(let wordCount):
            requests.append(try MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: wordCount,
                    as: UInt64.self,
                    role: "sparse transformed evaluation partial buffer"
                ),
                role: "sparse transformed evaluation partial buffer"
            ))
        case .fused:
            break
        }

        return try context.withTemporaryBuffers(requests) { temporaryBuffers in
            let vectorBuffer = temporaryBuffers[0]
            let rHatBuffer = temporaryBuffers[1]
            let outputBuffer = temporaryBuffers[2]
            try context.copyValues(vectorWords, to: vectorBuffer, role: "sparse transformed evaluation vector buffer")
            try context.copyValues(rHatWords, to: rHatBuffer, role: "sparse transformed evaluation rHat buffer")

            switch dispatchPlan {
            case .rowPartial:
                let partialBuffer = temporaryBuffers[3]
                let params = try [
                    checkedUInt32(batchBuffers.matrixCount, name: "sparse transformed matrix batch count"),
                    checkedUInt32(batchBuffers.rows, name: "sparse transformed matrix row count"),
                    checkedUInt32(batchBuffers.columns, name: "sparse transformed matrix column count"),
                    checkedUInt32(vectors.count, name: "sparse transformed vector batch count")
                ]
                try context.dispatch1DSequence([
                    MetalDispatchCommand(
                        pipelineName: "sparse_transformed_eval_row_partial_kernel",
                        buffers: [
                            batchBuffers.rowOffsets,
                            batchBuffers.columnIndices,
                            batchBuffers.values,
                            vectorBuffer,
                            rHatBuffer,
                            partialBuffer
                        ],
                        inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 6, values: params)],
                        elementCount: try checkedProduct(
                            [vectors.count, batchBuffers.matrixCount, batchBuffers.rows],
                            name: "sparse transformed evaluation row partial element count"
                        ),
                        countBufferIndex: 7
                    ),
                    MetalDispatchCommand(
                        pipelineName: "sparse_transformed_eval_row_reduce_kernel",
                        buffers: [
                            partialBuffer,
                            outputBuffer
                        ],
                        inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 2, values: params)],
                        elementCount: try checkedProduct(
                            [vectors.count, batchBuffers.matrixCount, CyclotomicRing54.degree],
                            name: "sparse transformed evaluation row reduce element count"
                        ),
                        countBufferIndex: 3,
                        barrierAfter: false
                    )
                ])
            case .blocked:
                let partialBuffer = temporaryBuffers[3]
                let params = try [
                    checkedUInt32(batchBuffers.matrixCount, name: "sparse transformed matrix batch count"),
                    checkedUInt32(batchBuffers.rows, name: "sparse transformed matrix row count"),
                    checkedUInt32(batchBuffers.columns, name: "sparse transformed matrix column count"),
                    checkedUInt32(vectors.count, name: "sparse transformed vector batch count"),
                    checkedUInt32(rowBlockSize, name: "sparse transformed row block size"),
                    checkedUInt32(rowBlockCount, name: "sparse transformed row block count")
                ]
                try context.dispatch1DSequence([
                    MetalDispatchCommand(
                        pipelineName: "sparse_transformed_eval_block_partial_kernel",
                        buffers: [
                            batchBuffers.rowOffsets,
                            batchBuffers.columnIndices,
                            batchBuffers.values,
                            vectorBuffer,
                            rHatBuffer,
                            partialBuffer
                        ],
                        inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 6, values: params)],
                        elementCount: try checkedProduct(
                            [vectors.count, batchBuffers.matrixCount, rowBlockCount, CyclotomicRing54.degree],
                            name: "sparse transformed evaluation partial element count"
                        ),
                        countBufferIndex: 7
                    ),
                    MetalDispatchCommand(
                        pipelineName: "sparse_transformed_eval_block_reduce_kernel",
                        buffers: [
                            partialBuffer,
                            outputBuffer
                        ],
                        inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 2, values: params)],
                        elementCount: try checkedProduct(
                            [vectors.count, batchBuffers.matrixCount, CyclotomicRing54.degree],
                            name: "sparse transformed evaluation reduce element count"
                        ),
                        countBufferIndex: 3,
                        barrierAfter: false
                    )
                ])
            case .fused:
                let params = try [
                    checkedUInt32(batchBuffers.matrixCount, name: "sparse transformed matrix batch count"),
                    checkedUInt32(batchBuffers.rows, name: "sparse transformed matrix row count"),
                    checkedUInt32(batchBuffers.columns, name: "sparse transformed matrix column count"),
                    checkedUInt32(vectors.count, name: "sparse transformed vector batch count")
                ]
                try context.dispatch1D(
                    pipelineName: "sparse_transformed_eval_fused_kernel",
                    buffers: [
                        batchBuffers.rowOffsets,
                        batchBuffers.columnIndices,
                        batchBuffers.values,
                        vectorBuffer,
                        rHatBuffer,
                        outputBuffer
                    ],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 6, values: params)],
                    countBufferIndex: 7,
                    elementCount: try checkedProduct(
                        [vectors.count, batchBuffers.matrixCount, CyclotomicRing54.degree],
                        name: "sparse transformed evaluation fused element count"
                    )
                )
            }

            return try transformedEvaluationResults(
                outputBuffer: outputBuffer,
                outputWordCount: outputWordCount,
                vectorCount: vectors.count,
                matrixCount: batchBuffers.matrixCount
            )
        }
    }

    fileprivate func commitmentsAndTransformedEvaluations(
        key: AjtaiCommitmentKey,
        messages: [[CyclotomicRing54]],
        point: [GoldilocksExt2],
        schedule: AjtaiMatvecSchedule,
        matrixBuffer: MTLBuffer,
        batchBuffers: SparseRingMatrixBatchBuffers
    ) throws -> (commitments: [AjtaiCommitment], evaluations: [[CyclotomicExt2Ring54]]) {
        guard !messages.isEmpty else {
            return ([], [])
        }
        guard key.matrix.rows == key.parameters.kappa else {
            throw SuperNeoError.invalidParameter("Ajtai matrix row count must equal kappa")
        }
        guard messages.allSatisfy({ $0.count == key.matrix.columns }) else {
            throw SuperNeoError.invalidParameter("Ajtai message length must equal key column count")
        }
        guard batchBuffers.matrixCount > 0 else {
            return (try ajtaiCommitments(
                key: key,
                messages: messages,
                schedule: schedule,
                matrixBuffer: matrixBuffer
            ), Array(repeating: [], count: messages.count))
        }
        let planned = schedule.planned(for: key, messageCount: messages.count)
        guard messages.count <= planned.maxBatchSize else {
            return (
                try ajtaiCommitments(key: key, messages: messages, schedule: planned, matrixBuffer: matrixBuffer),
                try transformedEvaluations(batchBuffers: batchBuffers, vectors: messages, point: point)
            )
        }
        let rHat = try MultilinearEvaluation.checkedBasis(at: point)
        guard rHat.count == batchBuffers.rows else {
            throw SuperNeoError.invalidParameter("evaluation point dimension must match sparse transformed matrix row count")
        }
        guard batchBuffers.columns == key.matrix.columns else {
            throw SuperNeoError.invalidParameter("Ajtai key and transformed matrices must share ring column count")
        }

        let rowCount = key.matrix.rows
        let columnCount = key.matrix.columns
        let batchCount = messages.count
        let vectorWords = flatten(messages)
        let useSmallMessageAjtaiKernel = rawWordsUseOnlySmallCoefficients(vectorWords)
        let rHatWords = flattenExt2(rHat)
        let commitmentOutputRingCount = try checkedProduct(
            [batchCount, rowCount],
            name: "combined commitment output ring count"
        )
        let commitmentOutputCoefficientCount = try checkedProduct(
            [commitmentOutputRingCount, CyclotomicRing54.degree],
            name: "combined commitment output coefficient count"
        )
        let evaluationOutputWordCount = try checkedProduct(
            [batchCount, batchBuffers.matrixCount, CyclotomicRing54.degree, 2],
            name: "combined evaluation output word count"
        )

        let coefficientMajorMessageWords: [UInt64]?
        let ajtaiPartialCoefficientCount: Int?
        let tileCount: Int?
        switch planned.kernel {
        case .coefficient:
            coefficientMajorMessageWords = nil
            ajtaiPartialCoefficientCount = nil
            tileCount = nil
        case .tiled:
            let plannedTileCount = try checkedCeilDiv(columnCount, by: planned.columnTileSize, name: "Ajtai tile count")
            let partialRingCount = try checkedProduct(
                [batchCount, plannedTileCount, rowCount],
                name: "Ajtai partial ring count"
            )
            coefficientMajorMessageWords = try flattenCoefficientMajorMessages(
                messages,
                columnCount: columnCount
            )
            ajtaiPartialCoefficientCount = try checkedProduct(
                [partialRingCount, CyclotomicRing54.degree],
                name: "Ajtai partial coefficient count"
            )
            tileCount = plannedTileCount
        }

        let rowBlockSize = Self.fusedEvaluationRowBlockSize
        let rowBlockCount = try checkedCeilDiv(
            batchBuffers.rows,
            by: rowBlockSize,
            name: "combined sparse transformed evaluation row block count"
        )
        let evaluationDispatchPlan: SparseEvaluationDispatchPlan
        if batchBuffers.rows >= Self.fusedEvaluationRowPartialThreshold,
           batchBuffers.rows < Self.fusedEvaluationBlockedRowThreshold {
            let rowPartialWordCount = try checkedProduct(
                [batchCount, batchBuffers.matrixCount, batchBuffers.rows, CyclotomicRing54.degree, 2],
                name: "combined evaluation row partial word count"
            )
            if rowPartialWordCount <= Self.fusedEvaluationRowPartialMaxWordCount {
                evaluationDispatchPlan = .rowPartial(wordCount: rowPartialWordCount)
            } else {
                evaluationDispatchPlan = .fused
            }
        } else if batchBuffers.rows >= Self.fusedEvaluationBlockedRowThreshold, rowBlockCount > 1 {
            let partialWordCount = try checkedProduct(
                [batchCount, batchBuffers.matrixCount, rowBlockCount, CyclotomicRing54.degree, 2],
                name: "combined evaluation partial word count"
            )
            evaluationDispatchPlan = .blocked(wordCount: partialWordCount)
        } else {
            evaluationDispatchPlan = .fused
        }

        var requests = try [
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: vectorWords.count,
                    as: UInt64.self,
                    role: "combined commit/eval vector buffer"
                ),
                role: "combined commit/eval vector buffer"
            ),
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: rHatWords.count,
                    as: UInt64.self,
                    role: "combined commit/eval rHat buffer"
                ),
                role: "combined commit/eval rHat buffer"
            ),
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: commitmentOutputCoefficientCount,
                    as: UInt64.self,
                    role: "combined commitment output buffer"
                ),
                role: "combined commitment output buffer"
            ),
            MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: evaluationOutputWordCount,
                    as: UInt64.self,
                    role: "combined evaluation output buffer"
                ),
                role: "combined evaluation output buffer"
            )
        ]
        var coefficientMajorBufferIndex: Int?
        var ajtaiPartialBufferIndex: Int?
        if let coefficientMajorMessageWords, let ajtaiPartialCoefficientCount {
            coefficientMajorBufferIndex = requests.count
            requests.append(try MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: coefficientMajorMessageWords.count,
                    as: UInt64.self,
                    role: "combined tiled Ajtai message buffer"
                ),
                role: "combined tiled Ajtai message buffer"
            ))
            ajtaiPartialBufferIndex = requests.count
            requests.append(try MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: ajtaiPartialCoefficientCount,
                    as: UInt64.self,
                    role: "combined tiled Ajtai partial buffer"
                ),
                role: "combined tiled Ajtai partial buffer"
            ))
        }
        var evaluationPartialBufferIndex: Int?
        switch evaluationDispatchPlan {
        case .rowPartial(let wordCount), .blocked(let wordCount):
            evaluationPartialBufferIndex = requests.count
            requests.append(try MetalTemporaryBufferRequest(
                byteLength: context.temporaryBufferByteLength(
                    count: wordCount,
                    as: UInt64.self,
                    role: "combined evaluation partial buffer"
                ),
                role: "combined evaluation partial buffer"
            ))
        case .fused:
            break
        }

        return try context.withTemporaryBuffers(requests) { temporaryBuffers in
            let vectorBuffer = temporaryBuffers[0]
            let rHatBuffer = temporaryBuffers[1]
            let commitmentOutputBuffer = temporaryBuffers[2]
            let evaluationOutputBuffer = temporaryBuffers[3]
            try context.copyValues(vectorWords, to: vectorBuffer, role: "combined commit/eval vector buffer")
            try context.copyValues(rHatWords, to: rHatBuffer, role: "combined commit/eval rHat buffer")

            var commands: [MetalDispatchCommand] = []
            switch planned.kernel {
            case .coefficient:
                let ajtaiParams = try [
                    checkedUInt32(rowCount, name: "Ajtai row count"),
                    checkedUInt32(columnCount, name: "Ajtai column count"),
                    checkedUInt32(batchCount, name: "Ajtai batch count")
                ]
                commands.append(MetalDispatchCommand(
                    pipelineName: useSmallMessageAjtaiKernel
                        ? "ajtai_matvec_ring_batch_coeff_small_message_kernel"
                        : "ajtai_matvec_ring_batch_coeff_kernel",
                    buffers: [matrixBuffer, vectorBuffer, commitmentOutputBuffer],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 3, values: ajtaiParams)],
                    elementCount: commitmentOutputCoefficientCount,
                    countBufferIndex: 4,
                    barrierAfter: false
                ))
            case .tiled:
                guard let tileCount,
                      let coefficientMajorMessageWords,
                      let coefficientMajorBufferIndex,
                      let ajtaiPartialBufferIndex else {
                    throw SuperNeoError.metalFailure("combined tiled Ajtai temporary buffers were not prepared")
                }
                let coefficientMajorMessageBuffer = temporaryBuffers[coefficientMajorBufferIndex]
                let partialBuffer = temporaryBuffers[ajtaiPartialBufferIndex]
                try context.copyValues(
                    coefficientMajorMessageWords,
                    to: coefficientMajorMessageBuffer,
                    role: "combined tiled Ajtai message buffer"
                )
                let partialRingCount = try checkedProduct(
                    [batchCount, tileCount, rowCount],
                    name: "Ajtai partial ring count"
                )
                let ajtaiParams = try [
                    checkedUInt32(rowCount, name: "Ajtai row count"),
                    checkedUInt32(columnCount, name: "Ajtai column count"),
                    checkedUInt32(planned.columnTileSize, name: "Ajtai column tile size"),
                    checkedUInt32(tileCount, name: "Ajtai tile count"),
                    checkedUInt32(batchCount, name: "Ajtai batch count")
                ]
                commands.append(MetalDispatchCommand(
                    pipelineName: "ajtai_matvec_tile_kernel",
                    buffers: [matrixBuffer, coefficientMajorMessageBuffer, partialBuffer],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 3, values: ajtaiParams)],
                    elementCount: partialRingCount,
                    threadsPerThreadgroup: planned.rowTileSize,
                    countBufferIndex: 4
                ))
                commands.append(MetalDispatchCommand(
                    pipelineName: "ajtai_matvec_reduce_kernel",
                    buffers: [partialBuffer, commitmentOutputBuffer],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 2, values: ajtaiParams)],
                    elementCount: commitmentOutputRingCount,
                    threadsPerThreadgroup: planned.rowTileSize,
                    countBufferIndex: 3,
                    barrierAfter: false
                ))
            }

            switch evaluationDispatchPlan {
            case .rowPartial:
                guard let evaluationPartialBufferIndex else {
                    throw SuperNeoError.metalFailure("combined row-partial evaluation buffer was not prepared")
                }
                let partialBuffer = temporaryBuffers[evaluationPartialBufferIndex]
                let params = try [
                    checkedUInt32(batchBuffers.matrixCount, name: "sparse transformed matrix batch count"),
                    checkedUInt32(batchBuffers.rows, name: "sparse transformed matrix row count"),
                    checkedUInt32(batchBuffers.columns, name: "sparse transformed matrix column count"),
                    checkedUInt32(batchCount, name: "sparse transformed vector batch count")
                ]
                commands.append(MetalDispatchCommand(
                    pipelineName: "sparse_transformed_eval_row_partial_kernel",
                    buffers: [
                        batchBuffers.rowOffsets,
                        batchBuffers.columnIndices,
                        batchBuffers.values,
                        vectorBuffer,
                        rHatBuffer,
                        partialBuffer
                    ],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 6, values: params)],
                    elementCount: try checkedProduct(
                        [batchCount, batchBuffers.matrixCount, batchBuffers.rows],
                        name: "combined evaluation row partial element count"
                    ),
                    countBufferIndex: 7
                ))
                commands.append(MetalDispatchCommand(
                    pipelineName: "sparse_transformed_eval_row_reduce_kernel",
                    buffers: [
                        partialBuffer,
                        evaluationOutputBuffer
                    ],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 2, values: params)],
                    elementCount: try checkedProduct(
                        [batchCount, batchBuffers.matrixCount, CyclotomicRing54.degree],
                        name: "combined evaluation row reduce element count"
                    ),
                    countBufferIndex: 3,
                    barrierAfter: false
                ))
            case .blocked:
                guard let evaluationPartialBufferIndex else {
                    throw SuperNeoError.metalFailure("combined blocked evaluation buffer was not prepared")
                }
                let partialBuffer = temporaryBuffers[evaluationPartialBufferIndex]
                let params = try [
                    checkedUInt32(batchBuffers.matrixCount, name: "sparse transformed matrix batch count"),
                    checkedUInt32(batchBuffers.rows, name: "sparse transformed matrix row count"),
                    checkedUInt32(batchBuffers.columns, name: "sparse transformed matrix column count"),
                    checkedUInt32(batchCount, name: "sparse transformed vector batch count"),
                    checkedUInt32(rowBlockSize, name: "sparse transformed row block size"),
                    checkedUInt32(rowBlockCount, name: "sparse transformed row block count")
                ]
                commands.append(MetalDispatchCommand(
                    pipelineName: "sparse_transformed_eval_block_partial_kernel",
                    buffers: [
                        batchBuffers.rowOffsets,
                        batchBuffers.columnIndices,
                        batchBuffers.values,
                        vectorBuffer,
                        rHatBuffer,
                        partialBuffer
                    ],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 6, values: params)],
                    elementCount: try checkedProduct(
                        [batchCount, batchBuffers.matrixCount, rowBlockCount, CyclotomicRing54.degree],
                        name: "combined evaluation partial element count"
                    ),
                    countBufferIndex: 7
                ))
                commands.append(MetalDispatchCommand(
                    pipelineName: "sparse_transformed_eval_block_reduce_kernel",
                    buffers: [
                        partialBuffer,
                        evaluationOutputBuffer
                    ],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 2, values: params)],
                    elementCount: try checkedProduct(
                        [batchCount, batchBuffers.matrixCount, CyclotomicRing54.degree],
                        name: "combined evaluation reduce element count"
                    ),
                    countBufferIndex: 3,
                    barrierAfter: false
                ))
            case .fused:
                let params = try [
                    checkedUInt32(batchBuffers.matrixCount, name: "sparse transformed matrix batch count"),
                    checkedUInt32(batchBuffers.rows, name: "sparse transformed matrix row count"),
                    checkedUInt32(batchBuffers.columns, name: "sparse transformed matrix column count"),
                    checkedUInt32(batchCount, name: "sparse transformed vector batch count")
                ]
                commands.append(MetalDispatchCommand(
                    pipelineName: "sparse_transformed_eval_fused_kernel",
                    buffers: [
                        batchBuffers.rowOffsets,
                        batchBuffers.columnIndices,
                        batchBuffers.values,
                        vectorBuffer,
                        rHatBuffer,
                        evaluationOutputBuffer
                    ],
                    inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 6, values: params)],
                    elementCount: try checkedProduct(
                        [batchCount, batchBuffers.matrixCount, CyclotomicRing54.degree],
                        name: "combined evaluation fused element count"
                    ),
                    countBufferIndex: 7,
                    barrierAfter: false
                ))
            }

            try context.dispatch1DSequence(commands)
            return (
                try ajtaiCommitmentResults(
                    outputBuffer: commitmentOutputBuffer,
                    outputRingCount: commitmentOutputRingCount,
                    rowCount: rowCount
                ),
                try transformedEvaluationResults(
                    outputBuffer: evaluationOutputBuffer,
                    outputWordCount: evaluationOutputWordCount,
                    vectorCount: batchCount,
                    matrixCount: batchBuffers.matrixCount
                )
            )
        }
    }

    private func binaryFieldOperation(
        _ lhs: [GoldilocksField],
        _ rhs: [GoldilocksField],
        pipelineName: String
    ) throws -> [GoldilocksField] {
        guard lhs.count == rhs.count else {
            throw SuperNeoError.invalidParameter("field vector length mismatch")
        }
        let output = try binaryRawOperation(lhs.map(\.rawValue), rhs.map(\.rawValue), pipelineName: pipelineName)
        return output.map { GoldilocksField($0) }
    }

    private func rawWordsUseOnlySmallCoefficients(_ words: [UInt64]) -> Bool {
        words.allSatisfy(isSmallMessageCoefficient)
    }

    private func isSmallMessageCoefficient(_ word: UInt64) -> Bool {
        word == 0
            || word == 1
            || word == 2
            || word == GoldilocksField.modulus - 1
            || word == GoldilocksField.modulus - 2
    }

    private func binaryRawOperation(
        _ lhs: [UInt64],
        _ rhs: [UInt64],
        pipelineName: String
    ) throws -> [UInt64] {
        guard lhs.count == rhs.count else {
            throw SuperNeoError.invalidParameter("raw vector length mismatch")
        }
        guard !lhs.isEmpty else { return [] }
        let lhsBuffer = try context.makeBuffer(lhs)
        let rhsBuffer = try context.makeBuffer(rhs)
        let outputBuffer = try context.makeEmptyBuffer(count: lhs.count, as: UInt64.self)
        try context.dispatch1D(
            pipelineName: pipelineName,
            buffers: [lhsBuffer, rhsBuffer, outputBuffer],
            elementCount: lhs.count
        )
        return outputBuffer.array(of: UInt64.self, count: lhs.count)
    }

    private func ajtaiCommitmentsBatch(
        key: AjtaiCommitmentKey,
        messages: [[CyclotomicRing54]],
        schedule: AjtaiMatvecSchedule,
        matrixBuffer: MTLBuffer
    ) throws -> [AjtaiCommitment] {
        let rowCount = key.matrix.rows
        let columnCount = key.matrix.columns
        let batchCount = messages.count
        let tileCount = try checkedCeilDiv(columnCount, by: schedule.columnTileSize, name: "Ajtai tile count")
        let partialRingCount = try checkedProduct([batchCount, tileCount, rowCount], name: "Ajtai partial ring count")
        let outputRingCount = try checkedProduct([batchCount, rowCount], name: "Ajtai output ring count")
        let partialCoefficientCount = try checkedProduct(
            [partialRingCount, CyclotomicRing54.degree],
            name: "Ajtai partial coefficient count"
        )
        let outputCoefficientCount = try checkedProduct(
            [outputRingCount, CyclotomicRing54.degree],
            name: "Ajtai output coefficient count"
        )

        let messageBuffer = try context.makeBuffer(try flattenCoefficientMajorMessages(
            messages,
            columnCount: columnCount
        ))
        let partialBuffer = try context.makeEmptyBuffer(
            count: partialCoefficientCount,
            as: UInt64.self
        )
        let outputBuffer = try context.makeEmptyBuffer(
            count: outputCoefficientCount,
            as: UInt64.self
        )
        let params = try [
            checkedUInt32(rowCount, name: "Ajtai row count"),
            checkedUInt32(columnCount, name: "Ajtai column count"),
            checkedUInt32(schedule.columnTileSize, name: "Ajtai column tile size"),
            checkedUInt32(tileCount, name: "Ajtai tile count"),
            checkedUInt32(batchCount, name: "Ajtai batch count")
        ]

        try context.dispatch1DSequence([
            MetalDispatchCommand(
                pipelineName: "ajtai_matvec_tile_kernel",
                buffers: [matrixBuffer, messageBuffer, partialBuffer],
                inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 3, values: params)],
                elementCount: partialRingCount,
                threadsPerThreadgroup: schedule.rowTileSize,
                countBufferIndex: 4
            ),
            MetalDispatchCommand(
                pipelineName: "ajtai_matvec_reduce_kernel",
                buffers: [partialBuffer, outputBuffer],
                inlineUInt32Buffers: [MetalInlineUInt32Buffer(index: 2, values: params)],
                elementCount: outputRingCount,
                threadsPerThreadgroup: schedule.rowTileSize,
                countBufferIndex: 3,
                barrierAfter: false
            )
        ])

        let output = try inflateRings(outputBuffer.array(
            of: UInt64.self,
            count: outputCoefficientCount
        ))
        return stride(from: 0, to: output.count, by: rowCount).map {
            AjtaiCommitment(Array(output[$0..<$0 + rowCount]))
        }
    }

    fileprivate func makeSparseRingMatrixBuffers(_ matrix: SparseRingMatrixCSR) throws -> SparseRingMatrixBuffers {
        guard matrix.rows > 0 else {
            throw SuperNeoError.invalidParameter("sparse transformed matrix must have at least one row")
        }
        return SparseRingMatrixBuffers(
            rowOffsets: try context.makeBuffer(try checkedUInt32Array(matrix.rowOffsets, name: "sparse row offset")),
            columnIndices: try context.makeBuffer(try checkedUInt32Array(matrix.columnIndices, name: "sparse column index")),
            values: try context.makeBuffer(flatten(matrix.values)),
            matvecParams: try context.makeBuffer([
                checkedUInt32(matrix.rows, name: "sparse transformed matrix row count"),
                checkedUInt32(matrix.columns, name: "sparse transformed matrix column count"),
                checkedUInt32(matrix.values.count, name: "sparse transformed matrix value count")
            ]),
            dotParams: try context.makeBuffer([
                checkedUInt32(matrix.rows, name: "transformed evaluation row count")
            ]),
            rows: matrix.rows,
            columns: matrix.columns
        )
    }

    fileprivate func makeSparseRingMatrixBatchBuffers(_ matrices: [SparseRingMatrixCSR]) throws -> SparseRingMatrixBatchBuffers? {
        guard let first = matrices.first else { return nil }
        guard first.rows > 0 else {
            throw SuperNeoError.invalidParameter("sparse transformed matrix must have at least one row")
        }

        var rowOffsets: [Int] = []
        rowOffsets.reserveCapacity(try checkedProduct(
            [matrices.count, try checkedSum(first.rows, 1, name: "sparse batch row offset count")],
            name: "sparse batch row offset count"
        ))
        var columnIndices: [Int] = []
        var values: [CyclotomicRing54] = []
        var entryBase = 0

        for matrix in matrices {
            guard matrix.rows == first.rows, matrix.columns == first.columns else {
                throw SuperNeoError.invalidParameter("sparse transformed matrices in a batch must share dimensions")
            }
            rowOffsets.append(contentsOf: try matrix.rowOffsets.map {
                try checkedSum(entryBase, $0, name: "sparse batch row offset")
            })
            columnIndices.append(contentsOf: matrix.columnIndices)
            values.append(contentsOf: matrix.values)
            entryBase = try checkedSum(entryBase, matrix.values.count, name: "sparse batch entry base")
        }

        return SparseRingMatrixBatchBuffers(
            rowOffsets: try context.makeBuffer(try checkedUInt32Array(rowOffsets, name: "sparse batch row offset")),
            columnIndices: try context.makeBuffer(try checkedUInt32Array(columnIndices, name: "sparse batch column index")),
            values: try context.makeBuffer(flatten(values)),
            matrixCount: matrices.count,
            rows: first.rows,
            columns: first.columns
        )
    }

    fileprivate func flatten(_ rings: [CyclotomicRing54]) -> [UInt64] {
        rings.flatMap { $0.coefficients.map(\.rawValue) }
    }

    private func flatten(_ ringBatches: [[CyclotomicRing54]]) -> [UInt64] {
        ringBatches.flatMap { flatten($0) }
    }

    private func flattenCoefficientMajorMessages(
        _ messages: [[CyclotomicRing54]],
        columnCount: Int
    ) throws -> [UInt64] {
        var raw: [UInt64] = []
        raw.reserveCapacity(try checkedProduct(
            [messages.count, columnCount, CyclotomicRing54.degree],
            name: "coefficient-major message word count"
        ))
        for message in messages {
            for coefficientIndex in 0..<CyclotomicRing54.degree {
                for column in 0..<columnCount {
                    raw.append(message[column].coefficients[coefficientIndex].rawValue)
                }
            }
        }
        return raw
    }

    private func flattenExt2(_ values: [GoldilocksExt2]) -> [UInt64] {
        values.flatMap { [$0.c0.rawValue, $0.c1.rawValue] }
    }

    private func inflateRings(_ raw: [UInt64]) throws -> [CyclotomicRing54] {
        guard raw.count % CyclotomicRing54.degree == 0 else {
            throw SuperNeoError.invalidParameter("raw ring coefficient count is not divisible by ring degree")
        }
        var rings: [CyclotomicRing54] = []
        rings.reserveCapacity(raw.count / CyclotomicRing54.degree)
        for offset in stride(from: 0, to: raw.count, by: CyclotomicRing54.degree) {
            let coefficients = raw[offset..<offset + CyclotomicRing54.degree].map { GoldilocksField($0) }
            rings.append(CyclotomicRing54(coefficients))
        }
        return rings
    }

    private func inflateExt2(_ raw: [UInt64]) -> [GoldilocksExt2] {
        stride(from: 0, to: raw.count, by: 2).map {
            GoldilocksExt2(GoldilocksField(raw[$0]), GoldilocksField(raw[$0 + 1]))
        }
    }

    private func transformedEvaluationResults(
        outputBuffer: MTLBuffer,
        outputWordCount: Int,
        vectorCount: Int,
        matrixCount: Int
    ) throws -> [[CyclotomicExt2Ring54]] {
        let raw = outputBuffer.array(of: UInt64.self, count: outputWordCount)
        let ringWordCount = try checkedProduct(
            [CyclotomicRing54.degree, 2],
            name: "transformed evaluation ring word count"
        )
        let expectedWordCount = try checkedProduct(
            [vectorCount, matrixCount, ringWordCount],
            name: "transformed evaluation output word count"
        )
        guard expectedWordCount == outputWordCount else {
            throw SuperNeoError.invalidParameter("transformed evaluation output word count mismatch")
        }
        var evaluations = Array(repeating: [CyclotomicExt2Ring54](), count: vectorCount)
        var offset = 0
        for vectorIndex in 0..<vectorCount {
            evaluations[vectorIndex].reserveCapacity(matrixCount)
            for _ in 0..<matrixCount {
                let endOffset = try checkedSum(offset, ringWordCount, name: "transformed evaluation output offset")
                guard endOffset <= raw.count else {
                    throw SuperNeoError.invalidParameter("transformed evaluation output buffer is too short")
                }
                let words = Array(raw[offset..<endOffset])
                evaluations[vectorIndex].append(CyclotomicExt2Ring54(inflateExt2(words)))
                offset = endOffset
            }
        }
        return evaluations
    }

    private func ajtaiCommitmentResults(
        outputBuffer: MTLBuffer,
        outputRingCount: Int,
        rowCount: Int
    ) throws -> [AjtaiCommitment] {
        let outputCoefficientCount = try checkedProduct(
            [outputRingCount, CyclotomicRing54.degree],
            name: "Ajtai output coefficient count"
        )
        let output = try inflateRings(outputBuffer.array(
            of: UInt64.self,
            count: outputCoefficientCount
        ))
        return stride(from: 0, to: output.count, by: rowCount).map {
            AjtaiCommitment(Array(output[$0..<$0 + rowCount]))
        }
    }

    private func checkedProduct(_ factors: [Int], name: String) throws -> Int {
        var result = 1
        for factor in factors {
            guard factor >= 0 else {
                throw SuperNeoError.invalidParameter("\(name) contains a negative factor")
            }
            let product = result.multipliedReportingOverflow(by: factor)
            guard !product.overflow else {
                throw SuperNeoError.invalidParameter("\(name) overflows Int")
            }
            result = product.partialValue
        }
        return result
    }

    private func checkedSum(_ left: Int, _ right: Int, name: String) throws -> Int {
        guard left >= 0, right >= 0 else {
            throw SuperNeoError.invalidParameter("\(name) contains a negative value")
        }
        let sum = left.addingReportingOverflow(right)
        guard !sum.overflow else {
            throw SuperNeoError.invalidParameter("\(name) overflows Int")
        }
        return sum.partialValue
    }

    private func checkedCeilDiv(_ numerator: Int, by denominator: Int, name: String) throws -> Int {
        guard numerator >= 0, denominator > 0 else {
            throw SuperNeoError.invalidParameter("\(name) has invalid operands")
        }
        let adjusted = try checkedSum(numerator, denominator - 1, name: name)
        return adjusted / denominator
    }

    private func checkedUInt32(_ value: Int, name: String) throws -> UInt32 {
        guard let converted = UInt32(exactly: value) else {
            throw SuperNeoError.invalidParameter("\(name) does not fit in UInt32")
        }
        return converted
    }

    private func checkedUInt32Array(_ values: [Int], name: String) throws -> [UInt32] {
        try values.map { try checkedUInt32($0, name: name) }
    }
}

private func metalDigestEncodeCount(_ value: Int) -> [UInt8] {
    withUnsafeBytes(of: UInt64(value).littleEndian, Array.init)
}
