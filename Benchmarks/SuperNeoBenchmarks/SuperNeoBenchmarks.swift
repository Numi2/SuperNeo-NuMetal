import Benchmark
import Foundation
@_spi(Benchmarking) import SuperNeo_NuMetal

private let defaultConfiguration = Benchmark.Configuration(
    metrics: [
        .wallClock,
        .mallocCountTotal,
        .memoryLeaked
    ],
    maxDuration: .seconds(3),
    maxIterations: 20
)
private let expensiveConfiguration = Benchmark.Configuration(
    metrics: [
        .wallClock,
        .mallocCountTotal,
        .memoryLeaked
    ],
    maxDuration: .seconds(1),
    maxIterations: 1
)

private let benchmarkProfile = ProcessInfo.processInfo.environment["SUPERNEO_BENCHMARK_PROFILE"] ?? "quick"
private let includeCEBenchmarks = ProcessInfo.processInfo.environment["SUPERNEO_BENCHMARK_CE"] == "1"
private let benchmarkCaseFilters = ProcessInfo.processInfo.environment["SUPERNEO_BENCHMARK_CASE_FILTER"]?
    .split(separator: ",")
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty } ?? []
private let benchmarkCases = SuperNeoBenchmarkFixtures.cases(profile: benchmarkProfile)
    .filter { benchmarkCase in
        benchmarkCaseFilters.isEmpty || benchmarkCaseFilters.contains { benchmarkCase.label.contains($0) }
    }
private let metalContext = SuperNeoBenchmarkFixtures.makeMetalContextIfAvailable()
private let fixtures = benchmarkCases.map { benchmarkCase in
    benchmarkSetupValue("failed to build benchmark fixture \(benchmarkCase.label)") {
        try SuperNeoBenchmarkFixture(benchmarkCase: benchmarkCase)
    }
}

private struct BenchmarkInvariantError: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

private func failBenchmarkSetup(_ message: String) -> Never {
    preconditionFailure(message)
}

private func benchmarkSetupValue<T>(_ message: String, _ body: () throws -> T) -> T {
    do {
        return try body()
    } catch {
        failBenchmarkSetup("\(message): \(error)")
    }
}

private func requireBenchmarkSetupInvariant(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String) {
    guard condition() else {
        failBenchmarkSetup(message())
    }
}

private func requireBenchmarkInvariant(_ condition: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String) throws {
    guard try condition() else {
        throw BenchmarkInvariantError(message: message())
    }
}

private func requireValid(_ result: VerificationResult) throws {
    guard result == .valid else {
        throw BenchmarkInvariantError(message: "verification failed: \(result.reason ?? "unknown")")
    }
}

private func requireValid(_ result: FoldReductionResult) throws {
    guard result.isValid else {
        throw BenchmarkInvariantError(message: "reduction failed: \(result.reason ?? "unknown")")
    }
}

private func registerEndToEndBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let cpuProver = SuperNeoProver(parameters: fixture.parameters, key: fixture.key)
    let verifier = SuperNeoVerifier(parameters: fixture.parameters, key: fixture.key)

    Benchmark("fold/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let output = try cpuProver.foldWithOutput(fixture.input, transcriptSeed: fixture.transcriptSeed)
        try requireValid(verifier.reduceFold(
            publicInput: fixture.publicInput,
            proof: output.proof,
            transcriptSeed: fixture.transcriptSeed
        ))
        blackHole(output.proof.outputClaims.count)
    }

    Benchmark("reduceFold/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let result = verifier.reduceFold(
            publicInput: fixture.publicInput,
            proof: fixture.referenceFold.proof,
            transcriptSeed: fixture.transcriptSeed
        )
        try requireValid(result)
        blackHole(result.outputClaims.count)
    }

    Benchmark("terminalVerify/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let result = SuperNeoBenchmarkSignpost.measure("terminalVerify") {
            verifier.verifyFold(
                publicInput: fixture.publicInput,
                proof: fixture.referenceFold.proof,
                outputClaims: fixture.referenceFold.outputClaims,
                transcriptSeed: fixture.transcriptSeed
            )
        }
        try requireValid(result)
    }

    Benchmark("proofEnvelope/roundTrip/\(label)", configuration: defaultConfiguration) { _ in
        let envelope = try SuperNeoBenchmarkSignpost.measure("parse") {
            try FoldProofEnvelope(bytes: fixture.proofEnvelopeBytes, parameters: fixture.parameters)
        }
        let result = verifier.verifyFoldEnvelope(
            publicInput: fixture.publicInput,
            proofBytes: envelope.superNeoBytes,
            context: fixture.proofEnvelopeContext,
            outputClaims: fixture.proofEnvelopeOutputClaims
        )
        try requireValid(result)
        let bytes = SuperNeoBenchmarkSignpost.measure("serialize") {
            envelope.superNeoBytes
        }
        blackHole(bytes.count)
    }

    if let metalContext {
        let metalProver = SuperNeoProver(parameters: fixture.parameters, key: fixture.key, context: metalContext)
        Benchmark("fold/metal/\(label)", configuration: defaultConfiguration) { _ in
            let output = try metalProver.foldWithOutput(fixture.input, transcriptSeed: fixture.transcriptSeed)
            try requireBenchmarkInvariant(
                output.proof == fixture.referenceFold.proof,
                "Metal fold output did not match CPU reference for \(label)"
            )
            blackHole(output.outputClaims.count)
        }
    }
}

private func registerStageBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let prover = SuperNeoProver(parameters: fixture.parameters, key: fixture.key)
    let claims = fixture.piCCSClaimsWithWitness
    let foldedClaim = fixture.foldedClaimWithWitness

    Benchmark("stage/sumcheck/\(label)", configuration: defaultConfiguration) { _ in
        let proof = try prover.benchmarkSumCheckProof(
            input: fixture.input,
            transcriptSeed: fixture.transcriptSeed
        )
        blackHole(proof.finalPoint.count)
    }

    Benchmark("stage/piCCSClaims/\(label)", configuration: defaultConfiguration) { _ in
        let claims = try prover.benchmarkPiCCSClaims(
            input: fixture.input,
            point: fixture.referenceFold.proof.sumCheck.finalPoint
        )
        blackHole(claims.count)
    }

    Benchmark("stage/piRLC/\(label)", configuration: defaultConfiguration) { _ in
        let rlc = try prover.benchmarkPiRLC(
            input: fixture.input,
            claims: claims,
            transcriptSeed: fixture.transcriptSeed
        )
        blackHole(rlc.challenges.count)
    }

    Benchmark("stage/piDEC/\(label)", configuration: defaultConfiguration) { _ in
        let decomposition = try prover.benchmarkPiDEC(
            foldedClaim,
            shape: fixture.shape
        )
        blackHole(decomposition.claims.count)
    }
}

private func registerCEBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let prover = SuperNeoProver(parameters: fixture.parameters, key: fixture.key)
    let verifier = SuperNeoVerifier(parameters: fixture.parameters, key: fixture.key)
    let terminalStatement = benchmarkSetupValue("failed to build terminal CE statement for \(label)") {
        try TerminalCEStatement(
            profileID: fixture.parameters.profileID,
            shape: fixture.shape,
            key: fixture.key,
            claims: fixture.referenceFold.outputClaims
        )
    }
    let terminalWitnesses = fixture.referenceFold.outputClaims.compactMap(CEOpeningWitness.init(claim:))
    requireBenchmarkSetupInvariant(
        terminalWitnesses.count == fixture.referenceFold.outputClaims.count,
        "CE benchmark fixture is missing terminal witnesses for \(label)"
    )
    let ceProofSeed = Array("superneo-benchmark-ce-opening-\(label)".utf8)
    let ceOpeningProof = benchmarkSetupValue("failed to build CE opening proof for \(label)") {
        try CEOpeningRelation.proveLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.shape,
            key: fixture.key,
            parameters: fixture.parameters,
            randomSeed: ceProofSeed
        )
    }

    let compressedStatement = CCSStatement(
        shapeDigest: fixture.shape.shapeDigest,
        ccsInstances: fixture.publicInput.instances,
        priorCEInstances: fixture.publicInput.priorClaims.map { CEInstance($0) }
    )
    let compressedContext = ProofEnvelopeContext(
        profileID: fixture.parameters.profileID,
        kind: .compressedPublic,
        statement: compressedStatement,
        verifierKeyDigest: fixture.key.verifierKeyDigest
    )
    let compressedCESeed = Array("superneo-benchmark-compressed-ce-\(label)".utf8)
    let compressedEnvelope = benchmarkSetupValue("failed to build compressed terminal envelope for \(label)") {
        try prover.compressedTerminalFoldEnvelope(
            fixture.input,
            context: compressedContext,
            ceRandomSeed: compressedCESeed
        )
    }
    let compressedEnvelopeBytes = compressedEnvelope.superNeoBytes

    Benchmark("ceOpeningProof/prove/cpu/\(label)", configuration: expensiveConfiguration) { _ in
        let proof = try CEOpeningRelation.proveLocalBatch(
            statement: terminalStatement,
            witnesses: terminalWitnesses,
            shape: fixture.shape,
            key: fixture.key,
            parameters: fixture.parameters,
            randomSeed: ceProofSeed
        )
        try requireBenchmarkInvariant(proof == ceOpeningProof, "CPU CE opening proof changed for \(label)")
        blackHole(proof.rounds.count)
    }

    Benchmark("ceOpeningProof/verify/cpu/\(label)", configuration: expensiveConfiguration) { _ in
        try requireBenchmarkInvariant(
            try CEOpeningRelation.verify(
                proof: ceOpeningProof,
                statement: terminalStatement,
                shape: fixture.shape,
                key: fixture.key,
                parameters: fixture.parameters
            ),
            "CE opening proof verification failed for \(label)"
        )
    }

    Benchmark("compressedEnvelope/verify/cpu/\(label)", configuration: expensiveConfiguration) { _ in
        try requireValid(verifier.verifyCompressedTerminalFoldEnvelope(
            publicInput: fixture.publicInput,
            proofBytes: compressedEnvelopeBytes,
            context: compressedContext
        ))
    }

    if let metalContext {
        let compiledShape = benchmarkSetupValue("failed to compile CE benchmark shape for \(label)") {
            try fixture.shape.compiledSparseForSuperNeo()
        }
        let metalWorkspace = benchmarkSetupValue("failed to build CE Metal workspace for \(label)") {
            try SuperNeoMetalWorkspace(
                context: metalContext,
                key: fixture.key,
                compiledShape: compiledShape
            )
        }
        let metalProver = SuperNeoProver(parameters: fixture.parameters, key: fixture.key, context: metalContext)
        let metalVerifier = SuperNeoVerifier(parameters: fixture.parameters, key: fixture.key, context: metalContext)

        Benchmark("ceOpeningProof/prove/metal/\(label)", configuration: expensiveConfiguration) { _ in
            let proof = try CEOpeningRelation.proveLocalBatch(
                statement: terminalStatement,
                witnesses: terminalWitnesses,
                shape: fixture.shape,
                key: fixture.key,
                parameters: fixture.parameters,
                randomSeed: ceProofSeed,
                metalWorkspace: metalWorkspace
            )
            try requireBenchmarkInvariant(proof == ceOpeningProof, "Metal CE opening proof changed for \(label)")
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(proof.rounds.count)
        }

        Benchmark("ceOpeningProof/verify/metal/\(label)", configuration: expensiveConfiguration) { _ in
            try requireBenchmarkInvariant(
                try CEOpeningRelation.verify(
                    proof: ceOpeningProof,
                    statement: terminalStatement,
                    shape: fixture.shape,
                    key: fixture.key,
                    parameters: fixture.parameters,
                    metalWorkspace: metalWorkspace
                ),
                "Metal CE opening proof verification failed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
        }

        Benchmark("compressedEnvelope/prove/metal/\(label)", configuration: expensiveConfiguration) { _ in
            let envelope = try metalProver.compressedTerminalFoldEnvelope(
                fixture.input,
                context: compressedContext,
                ceRandomSeed: compressedCESeed
            )
            try requireBenchmarkInvariant(envelope == compressedEnvelope, "Metal compressed envelope changed for \(label)")
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(envelope.superNeoBytes.count)
        }

        Benchmark("compressedEnvelope/verify/metal/\(label)", configuration: expensiveConfiguration) { _ in
            try requireValid(metalVerifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: fixture.publicInput,
                proofBytes: compressedEnvelopeBytes,
                context: compressedContext
            ))
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
        }
    }
}

private func registerKernelBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let backend = SuperNeoCPUBackend(parameters: fixture.parameters)
    let fieldVector = fixture.fieldVector
    let ringVector = fixture.ringVector
    let transformed = fixture.transformedMatrices[1]
    let sparseTransformed = fixture.transformedSparseMatrices[1]
    let sparseBatchMatrices = fixture.transformedSparseMatrices
    let point = fixture.evaluationPoint
    let rHat = benchmarkSetupValue("failed to build multilinear basis for \(label)") {
        try MultilinearEvaluation.checkedBasis(at: point)
    }
    let scalarVector = Array(fieldVector.prefix(ringVector.count))
    let batchMessages = Array(repeating: ringVector, count: fixture.parameters.decompositionLength)
    let referenceBatchCommitments = benchmarkSetupValue("failed to build reference batch commitments for \(label)") {
        try batchMessages.map {
            try AjtaiCommitter.commitReference(key: fixture.key, message: $0)
        }
    }
    let batchSizingMessages = Array(repeating: ringVector, count: 32)
    let referenceBatchSizingCommitments = benchmarkProfile == "scaling"
        ? benchmarkSetupValue("failed to build reference sizing commitments for \(label)") {
            try batchSizingMessages.map { try AjtaiCommitter.commitReference(key: fixture.key, message: $0) }
        }
        : []
    let referenceCommitment = benchmarkSetupValue("failed to build reference commitment for \(label)") {
        try AjtaiCommitter.commitReference(
            key: fixture.key,
            fieldWitness: fieldVector
        )
    }
    let referenceEvaluation = benchmarkSetupValue("failed to build reference multilinear evaluation for \(label)") {
        try backend.multilinearEvaluation(
            matrix: fixture.shape.matrices[1].toSparseFieldMatrix(),
            vector: fieldVector,
            point: point
        )
    }
    let referenceSparseBatchEvaluations = benchmarkSetupValue("failed to build reference sparse batch evaluations for \(label)") {
        try batchMessages.map { message in
            try sparseBatchMatrices.map { matrix in
                CyclotomicExt2Ring54(try backend.transformedEvaluation(
                    matrix: matrix,
                    vector: message,
                    point: point
                ))
            }
        }
    }

    Benchmark("kernel/fieldMultiply/\(label)", configuration: defaultConfiguration) { _ in
        let product = zip(fieldVector, fieldVector).map(*)
        blackHole(product.count)
    }

    Benchmark("kernel/ringMultiply/\(label)", configuration: defaultConfiguration) { _ in
        let product = zip(ringVector, ringVector).map(*)
        blackHole(product.count)
    }

    Benchmark("kernel/ringScalarMultiply/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let product = zip(ringVector, scalarVector).map { $0.scaled(by: $1) }
        blackHole(product.count)
    }

    Benchmark("kernel/multilinearEvaluation/\(label)", configuration: defaultConfiguration) { _ in
        let value = try backend.multilinearEvaluation(
            matrix: fixture.shape.matrices[1].toSparseFieldMatrix(),
            vector: fieldVector,
            point: point
        )
        try requireBenchmarkInvariant(value == referenceEvaluation, "multilinear evaluation changed for \(label)")
        blackHole(value)
    }

    Benchmark("kernel/transformedEvaluation/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let evaluation = try backend.transformedEvaluation(matrix: transformed, vector: ringVector, point: point)
        blackHole(evaluation.count)
    }

    Benchmark("kernel/transformedEvaluation/cpuSparse/\(label)", configuration: defaultConfiguration) { _ in
        let evaluation = try backend.transformedEvaluation(matrix: sparseTransformed, vector: ringVector, point: point)
        blackHole(evaluation.count)
    }

    Benchmark("kernel/ajtaiCommit/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let commitment = try AjtaiCommitter.commitReference(
            key: fixture.key,
            fieldWitness: fieldVector
        )
        try requireBenchmarkInvariant(commitment == referenceCommitment, "CPU commitment changed for \(label)")
        blackHole(commitment.elements.count)
    }

    Benchmark("kernel/ajtaiCommit/batch/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let commitments = try batchMessages.map {
            try AjtaiCommitter.commitReference(key: fixture.key, message: $0)
        }
        try requireBenchmarkInvariant(commitments == referenceBatchCommitments, "CPU batch commitment changed for \(label)")
        blackHole(commitments.count)
    }

    if let metalContext {
        let metalBackend = SuperNeoMetalBackend(context: metalContext)
        let metalWorkspace = benchmarkSetupValue("failed to build kernel Metal workspace for \(label)") {
            try SuperNeoMetalWorkspace(
                context: metalContext,
                key: fixture.key,
                transformedSparseMatrices: sparseBatchMatrices
            )
        }
        let referenceRows = benchmarkSetupValue("failed to build dense reference rows for \(label)") {
            try transformed.multiplied(by: ringVector)
        }
        let referenceSparseRows = benchmarkSetupValue("failed to build sparse reference rows for \(label)") {
            try sparseTransformed.multiplied(by: ringVector)
        }
        let referenceTransformedEvaluation = benchmarkSetupValue("failed to build transformed reference evaluation for \(label)") {
            try backend.transformedEvaluation(rows: referenceRows, rHat: rHat)
        }
        let referenceMetalCommitment = benchmarkSetupValue("failed to build Metal reference commitment for \(label)") {
            try AjtaiCommitter.commit(
                key: fixture.key,
                fieldWitness: fieldVector,
                context: metalContext
            )
        }
        requireBenchmarkSetupInvariant(
            referenceMetalCommitment == referenceCommitment,
            "Metal commitment setup did not match CPU reference for \(label)"
        )

        Benchmark("kernel/fieldMultiply/metal/\(label)", configuration: defaultConfiguration) { _ in
            let product = try metalBackend.multiply(fieldVector, fieldVector)
            try requireBenchmarkInvariant(product == zip(fieldVector, fieldVector).map(*), "Metal field multiply changed for \(label)")
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(product.count)
        }

        Benchmark("kernel/ringMultiply/metal/\(label)", configuration: defaultConfiguration) { _ in
            let product = try metalBackend.multiply(ringVector, ringVector)
            try requireBenchmarkInvariant(product == zip(ringVector, ringVector).map(*), "Metal ring multiply changed for \(label)")
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(product.count)
        }

        Benchmark("kernel/ringScalarMultiply/metal/\(label)", configuration: defaultConfiguration) { _ in
            let product = try metalBackend.multiply(ringVector, by: scalarVector)
            try requireBenchmarkInvariant(
                product == zip(ringVector, scalarVector).map { $0.scaled(by: $1) },
                "Metal ring scalar multiply changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(product.count)
        }

        Benchmark("kernel/ajtaiCommit/metal/\(label)", configuration: defaultConfiguration) { _ in
            let commitment = try AjtaiCommitter.commit(
                key: fixture.key,
                fieldWitness: fieldVector,
                context: metalContext
            )
            try requireBenchmarkInvariant(commitment == referenceCommitment, "Metal commitment changed for \(label)")
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(commitment.elements.count)
        }

        Benchmark("kernel/ajtaiCommit/batch/metal/\(label)", configuration: defaultConfiguration) { _ in
            let commitments = try metalBackend.ajtaiCommitments(key: fixture.key, messages: batchMessages)
            try requireBenchmarkInvariant(commitments == referenceBatchCommitments, "Metal batch commitment changed for \(label)")
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(commitments.count)
        }

        Benchmark("kernel/ajtaiCommit/batchWorkspace/metal/\(label)", configuration: defaultConfiguration) { _ in
            let commitments = try metalWorkspace.ajtaiCommitments(messages: batchMessages)
            try requireBenchmarkInvariant(
                commitments == referenceBatchCommitments,
                "Metal workspace batch commitment changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(commitments.count)
        }

        Benchmark("kernel/transformedEvaluation/metalDense/\(label)", configuration: defaultConfiguration) { _ in
            let rows = try metalBackend.transformedMatrixVector(matrix: transformed, vector: ringVector)
            try requireBenchmarkInvariant(rows == referenceRows, "Metal transformed rows changed for \(label)")
            let evaluation = try metalBackend.transformedEvaluation(rows: rows, rHat: rHat)
            try requireBenchmarkInvariant(
                evaluation == referenceTransformedEvaluation,
                "Metal transformed evaluation changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(evaluation.count)
        }

        Benchmark("kernel/transformedEvaluation/metalSparse/\(label)", configuration: defaultConfiguration) { _ in
            let rows = try metalBackend.transformedMatrixVector(matrix: sparseTransformed, vector: ringVector)
            try requireBenchmarkInvariant(rows == referenceSparseRows, "Metal sparse transformed rows changed for \(label)")
            let evaluation = try metalBackend.transformedEvaluation(rows: rows, rHat: rHat)
            try requireBenchmarkInvariant(
                evaluation == referenceTransformedEvaluation,
                "Metal sparse transformed evaluation changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(evaluation.count)
        }

        Benchmark("kernel/transformedEvaluation/metalSparseBatch/\(label)", configuration: defaultConfiguration) { _ in
            let evaluations = try metalBackend.transformedEvaluations(
                matrices: sparseBatchMatrices,
                vectors: batchMessages,
                point: point
            )
            try requireBenchmarkInvariant(
                evaluations == referenceSparseBatchEvaluations,
                "Metal sparse batch transformed evaluation changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(evaluations.count)
        }

        Benchmark("kernel/transformedEvaluation/metalSparseBatchWorkspace/\(label)", configuration: defaultConfiguration) { _ in
            let evaluations = try metalWorkspace.transformedEvaluations(
                vectors: batchMessages,
                point: point
            )
            try requireBenchmarkInvariant(
                evaluations == referenceSparseBatchEvaluations,
                "Metal workspace sparse batch transformed evaluation changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(evaluations.count)
        }

        Benchmark("kernel/combinedCommitEval/batchWorkspace/metal/\(label)", configuration: defaultConfiguration) { _ in
            let combined = try metalWorkspace.commitmentsAndTransformedEvaluations(
                messages: batchMessages,
                point: point
            )
            try requireBenchmarkInvariant(
                combined.commitments == referenceBatchCommitments,
                "Metal combined workspace commitments changed for \(label)"
            )
            try requireBenchmarkInvariant(
                combined.evaluations == referenceSparseBatchEvaluations,
                "Metal combined workspace transformed evaluations changed for \(label)"
            )
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(combined.commitments.count + combined.evaluations.count)
        }

        if benchmarkProfile == "scaling" {
            let schedule16 = benchmarkSetupValue("failed to build batch-16 Ajtai schedule for \(label)") {
                try AjtaiMatvecSchedule(maxBatchSize: 16)
            }
            let schedule32 = benchmarkSetupValue("failed to build batch-32 Ajtai schedule for \(label)") {
                try AjtaiMatvecSchedule(maxBatchSize: 32)
            }

            Benchmark("kernel/ajtaiCommit/batchWorkspace16/b32/metal/\(label)", configuration: defaultConfiguration) { _ in
                let commitments = try metalWorkspace.ajtaiCommitments(
                    messages: batchSizingMessages,
                    schedule: schedule16
                )
                try requireBenchmarkInvariant(
                    commitments == referenceBatchSizingCommitments,
                    "Metal workspace batch-16 commitments changed for \(label)"
                )
                blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
                blackHole(commitments.count)
            }

            Benchmark("kernel/ajtaiCommit/batchWorkspace32/b32/metal/\(label)", configuration: defaultConfiguration) { _ in
                let commitments = try metalWorkspace.ajtaiCommitments(
                    messages: batchSizingMessages,
                    schedule: schedule32
                )
                try requireBenchmarkInvariant(
                    commitments == referenceBatchSizingCommitments,
                    "Metal workspace batch-32 commitments changed for \(label)"
                )
                blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
                blackHole(commitments.count)
            }

            Benchmark("kernel/combinedCommitEval/batchWorkspace32/b32/metal/\(label)", configuration: defaultConfiguration) { _ in
                let combined = try metalWorkspace.commitmentsAndTransformedEvaluations(
                    messages: batchSizingMessages,
                    point: point,
                    schedule: schedule32
                )
                try requireBenchmarkInvariant(
                    combined.commitments == referenceBatchSizingCommitments,
                    "Metal combined workspace batch-32 commitments changed for \(label)"
                )
                blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
                blackHole(combined.commitments.count + combined.evaluations.count)
            }
        }
    }
}

let benchmarks: @Sendable () -> Void = {
    let metadataDirectory = URL(fileURLWithPath: "benchmark-results", isDirectory: true)
    try? SuperNeoBenchmarkMetadata().write(to: metadataDirectory, profile: benchmarkProfile, fixtures: fixtures)

    for fixture in fixtures {
        registerEndToEndBenchmarks(fixture)
    }

    let kernelFixtureLimit = benchmarkProfile == "scaling" ? fixtures.count : (benchmarkProfile == "quick" ? 1 : 4)
    for fixture in fixtures.prefix(kernelFixtureLimit) {
        registerStageBenchmarks(fixture)
        registerKernelBenchmarks(fixture)
    }

    if includeCEBenchmarks, let fixture = fixtures.first {
        registerCEBenchmarks(fixture)
    }
}
