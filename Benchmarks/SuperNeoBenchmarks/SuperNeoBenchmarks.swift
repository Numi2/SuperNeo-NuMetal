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

private let quickOnly = ProcessInfo.processInfo.environment["SUPERNEO_BENCHMARK_PROFILE"] == "quick"
private let benchmarkCases = quickOnly
    ? SuperNeoBenchmarkFixtures.quickCases
    : SuperNeoBenchmarkFixtures.fullCases
private let metalContext = SuperNeoBenchmarkFixtures.makeMetalContextIfAvailable()
private let fixtures = benchmarkCases.map { benchmarkCase in
    do {
        return try SuperNeoBenchmarkFixture(benchmarkCase: benchmarkCase)
    } catch {
        fatalError("failed to build benchmark fixture \(benchmarkCase.label): \(error)")
    }
}

private func requireValid(_ result: VerificationResult) {
    guard result == .valid else {
        fatalError("verification failed: \(result.reason ?? "unknown")")
    }
}

private func requireValid(_ result: FoldReductionResult) {
    guard result.isValid else {
        fatalError("reduction failed: \(result.reason ?? "unknown")")
    }
}

private func registerEndToEndBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let cpuProver = SuperNeoProver(parameters: fixture.parameters, key: fixture.key)
    let verifier = SuperNeoVerifier(parameters: fixture.parameters, key: fixture.key)

    Benchmark("fold/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let output = try cpuProver.foldWithOutput(fixture.input, transcriptSeed: fixture.transcriptSeed)
        requireValid(verifier.reduceFold(
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
        requireValid(result)
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
        requireValid(result)
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
        requireValid(result)
        let bytes = SuperNeoBenchmarkSignpost.measure("serialize") {
            envelope.superNeoBytes
        }
        blackHole(bytes.count)
    }

    if let metalContext {
        let metalProver = SuperNeoProver(parameters: fixture.parameters, key: fixture.key, context: metalContext)
        Benchmark("fold/metal/\(label)", configuration: defaultConfiguration) { _ in
            let output = try metalProver.foldWithOutput(fixture.input, transcriptSeed: fixture.transcriptSeed)
            guard output.proof == fixture.referenceFold.proof else {
                fatalError("Metal fold output did not match CPU reference for \(label)")
            }
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

private func registerKernelBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let backend = SuperNeoCPUBackend(parameters: fixture.parameters)
    let fieldVector = fixture.fieldVector
    let ringVector = fixture.ringVector
    let transformed = fixture.transformedMatrices[1]
    let point = fixture.evaluationPoint
    let referenceCommitment = try! AjtaiCommitter.commitReference(
        key: fixture.key,
        fieldWitness: fieldVector
    )
    let referenceEvaluation = try! backend.multilinearEvaluation(
        matrix: fixture.shape.matrices[1].toSparseFieldMatrix(),
        vector: fieldVector,
        point: point
    )

    Benchmark("kernel/fieldMultiply/\(label)", configuration: defaultConfiguration) { _ in
        let product = zip(fieldVector, fieldVector).map(*)
        blackHole(product.count)
    }

    Benchmark("kernel/ringMultiply/\(label)", configuration: defaultConfiguration) { _ in
        let product = zip(ringVector, ringVector).map(*)
        blackHole(product.count)
    }

    Benchmark("kernel/multilinearEvaluation/\(label)", configuration: defaultConfiguration) { _ in
        let value = try backend.multilinearEvaluation(
            matrix: fixture.shape.matrices[1].toSparseFieldMatrix(),
            vector: fieldVector,
            point: point
        )
        guard value == referenceEvaluation else {
            fatalError("multilinear evaluation changed for \(label)")
        }
        blackHole(value)
    }

    Benchmark("kernel/ajtaiCommit/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let commitment = try AjtaiCommitter.commitReference(
            key: fixture.key,
            fieldWitness: fieldVector
        )
        guard commitment == referenceCommitment else {
            fatalError("CPU commitment changed for \(label)")
        }
        blackHole(commitment.elements.count)
    }

    if let metalContext {
        let metalBackend = SuperNeoMetalBackend(context: metalContext)
        let referenceRows = try! transformed.multiplied(by: ringVector)
        let referenceMetalCommitment = try! AjtaiCommitter.commit(
            key: fixture.key,
            fieldWitness: fieldVector,
            context: metalContext
        )
        guard referenceMetalCommitment == referenceCommitment else {
            fatalError("Metal commitment setup did not match CPU reference for \(label)")
        }

        Benchmark("kernel/ajtaiCommit/metal/\(label)", configuration: defaultConfiguration) { _ in
            let commitment = try AjtaiCommitter.commit(
                key: fixture.key,
                fieldWitness: fieldVector,
                context: metalContext
            )
            guard commitment == referenceCommitment else {
                fatalError("Metal commitment changed for \(label)")
            }
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(commitment.elements.count)
        }

        Benchmark("kernel/transformedEvaluation/metal/\(label)", configuration: defaultConfiguration) { _ in
            let rows = try metalBackend.transformedMatrixVector(matrix: transformed, vector: ringVector)
            guard rows == referenceRows else {
                fatalError("Metal transformed rows changed for \(label)")
            }
            let evaluation = try metalBackend.transformedEvaluation(rows: rows, rHat: MultilinearEvaluation.checkedBasis(at: point))
            blackHole(metalContext.lastCommandBufferGPUTimeSeconds ?? 0)
            blackHole(evaluation.count)
        }
    }
}

let benchmarks: @Sendable () -> Void = {
    let metadataDirectory = URL(fileURLWithPath: "benchmark-results", isDirectory: true)
    let profile = quickOnly ? "quick" : "full"
    try? SuperNeoBenchmarkMetadata().write(to: metadataDirectory, profile: profile, fixtures: fixtures)

    for fixture in fixtures {
        registerEndToEndBenchmarks(fixture)
    }

    for fixture in fixtures.prefix(quickOnly ? 1 : 4) {
        registerStageBenchmarks(fixture)
        registerKernelBenchmarks(fixture)
    }
}
