import Foundation
import Metal

public final class SuperNeoMetalBackend: @unchecked Sendable {
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
        let coefficientCount = rings.count * CyclotomicRing54.degree
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
        let coefficientCount = lhs.count * CyclotomicRing54.degree
        let outputBuffer = try context.makeEmptyBuffer(count: coefficientCount, as: UInt64.self)
        try context.dispatch1D(
            pipelineName: "ring_mul_kernel",
            buffers: [lhsBuffer, rhsBuffer, outputBuffer],
            elementCount: lhs.count
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
        var commitments: [AjtaiCommitment] = []
        commitments.reserveCapacity(messages.count)

        var batchStart = 0
        while batchStart < messages.count {
            let batchEnd = min(batchStart + planned.maxBatchSize, messages.count)
            let batchMessages = Array(messages[batchStart..<batchEnd])
            commitments.append(contentsOf: try ajtaiCommitmentsBatch(
                key: key,
                messages: batchMessages,
                schedule: planned,
                matrixBuffer: matrixBuffer
            ))
            batchStart = batchEnd
        }

        return commitments
    }

    public func transformedMatrixVector(matrix: RingMatrix, vector: [CyclotomicRing54]) throws -> [CyclotomicRing54] {
        guard matrix.columns == vector.count else {
            throw SuperNeoError.invalidParameter("transformed matrix/vector dimension mismatch")
        }
        guard matrix.rows > 0 else { return [] }
        let matrixBuffer = try context.makeBuffer(flatten(matrix.elements))
        let vectorBuffer = try context.makeBuffer(flatten(vector))
        let outputCount = matrix.rows * CyclotomicRing54.degree
        let outputBuffer = try context.makeEmptyBuffer(count: outputCount, as: UInt64.self)
        let params = try [
            checkedUInt32(matrix.rows, name: "transformed matrix row count"),
            checkedUInt32(matrix.columns, name: "transformed matrix column count")
        ]
        let paramsBuffer = try context.makeBuffer(params)
        try context.dispatch1D(
            pipelineName: "transformed_matvec_kernel",
            buffers: [matrixBuffer, vectorBuffer, outputBuffer, paramsBuffer],
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
        let paramsBuffer = try context.makeBuffer([
            checkedUInt32(rows.count, name: "transformed evaluation row count")
        ])
        try context.dispatch1D(
            pipelineName: "transformed_eval_dot_kernel",
            buffers: [rowsBuffer, rHatBuffer, outputBuffer, paramsBuffer],
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
        let tileCount = (columnCount + schedule.columnTileSize - 1) / schedule.columnTileSize
        let partialRingCount = batchCount * tileCount * rowCount
        let outputRingCount = batchCount * rowCount

        let messageBuffer = try context.makeBuffer(flattenCoefficientMajorMessages(
            messages,
            columnCount: columnCount
        ))
        let partialBuffer = try context.makeEmptyBuffer(
            count: partialRingCount * CyclotomicRing54.degree,
            as: UInt64.self
        )
        let outputBuffer = try context.makeEmptyBuffer(
            count: outputRingCount * CyclotomicRing54.degree,
            as: UInt64.self
        )
        let params = try [
            checkedUInt32(rowCount, name: "Ajtai row count"),
            checkedUInt32(columnCount, name: "Ajtai column count"),
            checkedUInt32(schedule.columnTileSize, name: "Ajtai column tile size"),
            checkedUInt32(tileCount, name: "Ajtai tile count"),
            checkedUInt32(batchCount, name: "Ajtai batch count")
        ]
        let paramsBuffer = try context.makeBuffer(params)

        try context.dispatch1DSequence([
            MetalDispatchCommand(
                pipelineName: "ajtai_matvec_tile_kernel",
                buffers: [matrixBuffer, messageBuffer, partialBuffer, paramsBuffer],
                elementCount: partialRingCount,
                threadsPerThreadgroup: schedule.rowTileSize
            ),
            MetalDispatchCommand(
                pipelineName: "ajtai_matvec_reduce_kernel",
                buffers: [partialBuffer, outputBuffer, paramsBuffer],
                elementCount: outputRingCount,
                threadsPerThreadgroup: schedule.rowTileSize
            )
        ])

        let output = try inflateRings(outputBuffer.array(
            of: UInt64.self,
            count: outputRingCount * CyclotomicRing54.degree
        ))
        return stride(from: 0, to: output.count, by: rowCount).map {
            AjtaiCommitment(Array(output[$0..<$0 + rowCount]))
        }
    }

    private func flatten(_ rings: [CyclotomicRing54]) -> [UInt64] {
        rings.flatMap { $0.coefficients.map(\.rawValue) }
    }

    private func flattenCoefficientMajorMessages(
        _ messages: [[CyclotomicRing54]],
        columnCount: Int
    ) -> [UInt64] {
        var raw: [UInt64] = []
        raw.reserveCapacity(messages.count * columnCount * CyclotomicRing54.degree)
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

    private func checkedUInt32(_ value: Int, name: String) throws -> UInt32 {
        guard let converted = UInt32(exactly: value) else {
            throw SuperNeoError.invalidParameter("\(name) does not fit in UInt32")
        }
        return converted
    }
}
