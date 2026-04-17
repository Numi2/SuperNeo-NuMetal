import Benchmark
import Foundation
@_spi(Benchmarking) import SuperNeo_NuMetal

private enum SuperNeoBenchmarkMetrics {
    static let gpuCommandBufferTime = BenchmarkMetric.custom(
        "GPU command buffer time",
        polarity: .prefersSmaller,
        useScalingFactor: false
    )
    static let metalEncodeWallTime = BenchmarkMetric.custom(
        "Metal encode wall time",
        polarity: .prefersSmaller,
        useScalingFactor: false
    )
    static let metalCommitWallTime = BenchmarkMetric.custom(
        "Metal commit wall time",
        polarity: .prefersSmaller,
        useScalingFactor: false
    )
    static let metalWaitWallTime = BenchmarkMetric.custom(
        "Metal wait wall time",
        polarity: .prefersSmaller,
        useScalingFactor: false
    )
}

private let benchmarkMetrics: [BenchmarkMetric] = [
    .wallClock,
    .mallocCountTotal,
    .memoryLeaked,
    SuperNeoBenchmarkMetrics.gpuCommandBufferTime,
    SuperNeoBenchmarkMetrics.metalEncodeWallTime,
    SuperNeoBenchmarkMetrics.metalCommitWallTime,
    SuperNeoBenchmarkMetrics.metalWaitWallTime
]

private let defaultConfiguration = Benchmark.Configuration(
    metrics: benchmarkMetrics,
    maxDuration: .seconds(3),
    maxIterations: 20
)
private let expensiveConfiguration = Benchmark.Configuration(
    metrics: benchmarkMetrics,
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
    } catch let error as BenchmarkInvariantError {
        failBenchmarkSetup("\(message): \(error.message)")
    } catch {
        failBenchmarkSetup(message)
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

private func benchmarkSetupStep<T>(_ name: String, _ body: () throws -> T) throws -> T {
    do {
        return try body()
    } catch let error as BenchmarkInvariantError {
        throw error
    } catch {
        throw BenchmarkInvariantError(message: name)
    }
}

private func requireValid(_ result: VerificationResult) throws {
    guard result == .valid else {
        throw BenchmarkInvariantError(message: "verification failed: \(result.reason ?? "unknown")")
    }
}

private func requireValid(_ result: FoldReductionResult) throws {
    guard result.isReductionAccepted else {
        throw BenchmarkInvariantError(message: "reduction failed: \(result.reason ?? "unknown")")
    }
}

private func requireValid(_ result: NumiSealProductVerificationResult) throws {
    guard result.sourceFoldResult.isReductionAccepted else {
        throw BenchmarkInvariantError(
            message: "NumiSeal product source fold failed: \(result.sourceFoldResult.reason ?? "unknown")"
        )
    }
    guard result.numiSealResult.isValid else {
        throw BenchmarkInvariantError(
            message: "NumiSeal product proof failed: \(result.numiSealResult.reason ?? "unknown")"
        )
    }
}

private final class NumiSealProductBenchmarkFixture {
    let prepared: SuperNeoPreparedR1CS
    let terminalRequest: NumiSealProvingRequest
    let terminalArtifact: NumiSealProductArtifact
    let zkRequest: NumiSealProvingRequest
    let zkArtifact: NumiSealProductArtifact
    let recursiveParent: NumiSealProductRecursiveCarryParent
    let recursiveChildRequest: NumiSealProvingRequest
    let recursiveChildArtifact: NumiSealProductArtifact
    let recursiveIdentity: SuperNeoProductProofIdentity
    let auditEvent: SuperNeoAuditLogEvent

    init() throws {
        let workload = try benchmarkSetupStep("build one-hot workload") {
            try SuperNeoOneHotVectorWorkload(bitCount: 2)
        }
        let keySeed = "superneo-benchmark-numiseal-product-key"
        let prepared = try benchmarkSetupStep("prepare NumiSeal benchmark R1CS") {
            try workload.prepareForFolding(
                bits: [false, true],
                keySeed: Array(keySeed.utf8)
            )
        }
        let laneID = try benchmarkSetupStep("build NumiSeal benchmark lane") {
            try NumiSealLaneID("product")
        }
        let limits = try benchmarkSetupStep("build NumiSeal benchmark aggregation limits") {
            try NumiSealAggregationLimits(maximumObligationsPerAggregate: 32)
        }
        let prover = NumiSealProductProver()
        let verifier = NumiSealProductVerifier()
        let workloadParameters = ["selectedCount": "1"]
        let terminalRequest = NumiSealProvingRequest(
            preparedR1CS: prepared,
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            keySeedUTF8: keySeed,
            workloadParameters: workloadParameters,
            laneID: laneID,
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: limits
        )
        let terminalArtifact = try benchmarkSetupStep("prove NumiSeal terminal product fixture") {
            try prover.prove(terminalRequest)
        }
        let terminalResult = try benchmarkSetupStep("verify NumiSeal terminal product fixture") {
            try verifier.verify(
                artifact: terminalArtifact,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            )
        }
        let zkRequest = NumiSealProvingRequest(
            preparedR1CS: prepared,
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            keySeedUTF8: keySeed,
            workloadParameters: workloadParameters,
            laneID: laneID,
            executionPolicy: .zkHighAssuranceCPU,
            zkMode: NumiSealZK.maskedDigitTensorMode,
            aggregationLimits: limits
        )
        let zkArtifact = try benchmarkSetupStep("prove NumiSealZK product fixture") {
            try prover.prove(zkRequest)
        }
        let zkResult = try benchmarkSetupStep("verify NumiSealZK product fixture") {
            try verifier.verify(
                artifact: zkArtifact,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance
            )
        }
        let recursiveParent = try benchmarkSetupStep("build recursive carry parent fixture") {
            try NumiSealProductRecursiveCarryParent(
                artifact: terminalArtifact,
                verificationResult: terminalResult,
                consumerSessionDigest: Digest256.hash("superneo-benchmark-recursive-carry-child-session"),
                nextRecursionLevel: 1
            )
        }
        let recursiveChildRequest = NumiSealProvingRequest(
            preparedR1CS: prepared,
            workload: "one-hot-vector-v1",
            bitCount: 2,
            publicInputs: [1],
            keySeedUTF8: keySeed,
            workloadParameters: workloadParameters,
            laneID: laneID,
            executionPolicy: .zkHighAssuranceCPU,
            aggregationLimits: limits,
            recursiveCarryParent: recursiveParent
        )
        let recursiveChildArtifact = try benchmarkSetupStep("prove recursive carry child product fixture") {
            try prover.prove(recursiveChildRequest)
        }
        let recursiveChildResult = try benchmarkSetupStep("verify recursive carry child product fixture") {
            try verifier.verify(
                artifact: recursiveChildArtifact,
                sourcePublicInput: prepared.publicFoldInput,
                key: prepared.key,
                executionPolicy: .highAssurance,
                recursiveCarryParent: recursiveParent
            )
        }
        guard let recursiveBinding = try benchmarkSetupStep(
            "decode recursive carry replay binding from child product fixture",
            { try recursiveChildArtifact.recursiveCarryReplayBinding() }
        ) else {
            throw BenchmarkInvariantError(message: "recursive product benchmark child did not emit carry replay binding")
        }
        let recursiveIdentity = try benchmarkSetupStep("build recursive product replay identity fixture") {
            try SuperNeoProductProofIdentity(
                expectedContextID: "superneo-benchmark-product-context",
                statementDigest: Digest256(
                    hexDigest: recursiveChildArtifact.statementDigestHex,
                    name: "benchmark recursive child statement digest"
                ),
                proofEnvelopeDigest: Digest256(
                    hexDigest: recursiveChildArtifact.proofEnvelopeDigestHex,
                    name: "benchmark recursive child proof envelope digest"
                ),
                artifactDigest: NumiSealProductArtifact.canonicalDigest(recursiveChildArtifact),
                provenanceDigest: Digest256.hash("superneo-benchmark-recursive-child-provenance"),
                recursiveCarryReplayBindingDigest: recursiveBinding.bindingDigest
            )
        }
        let auditEvent = SuperNeoAuditLogEvent(
            decision: "accepted",
            artifactDigestHex: recursiveIdentity.artifactDigest.hexString,
            proofEnvelopeDigestHex: recursiveIdentity.proofEnvelopeDigest.hexString,
            provenanceDigestHex: recursiveIdentity.provenanceDigest.hexString,
            proofKind: SuperNeoProductProofKind.numiSealTerminal.rawValue,
            carryMode: recursiveChildArtifact.carryMode,
            recursiveCarryReplayBindingDigestHex: recursiveBinding.bindingDigest.hexString,
            recursiveCarryContextRootHex: recursiveBinding.contextRoot.hexString,
            recursiveCarryReplayRootHex: recursiveBinding.replayRoot.hexString,
            recursiveCarryParentArtifactDigestHex: recursiveBinding.parentArtifactDigest.hexString,
            recursiveCarryParentProofEnvelopeDigestHex: recursiveBinding.parentProductProofEnvelopeDigest.hexString,
            recursiveCarryParentProvenanceDigestHex: Digest256.hash("superneo-benchmark-parent-provenance").hexString,
            recursiveCarryParentAcceptedReplayDigestHex: Digest256.hash("superneo-benchmark-parent-replay").hexString,
            recursiveCarryConsumerSessionDigestHex: recursiveBinding.consumerSessionDigest.hexString,
            recursiveCarryNextRecursionLevel: recursiveBinding.nextRecursionLevel,
            recursiveCarryClaimCount: recursiveBinding.claimCount,
            contextID: recursiveIdentity.expectedContextID,
            statementDigestHex: recursiveIdentity.statementDigest.hexString,
            toolVersion: "superneo-benchmark",
            releaseBuildDigestHex: Digest256.hash("superneo-benchmark-release-build").hexString
        )
        try requireValid(terminalResult)
        try requireValid(zkResult)
        try requireValid(recursiveChildResult)

        self.prepared = prepared
        self.terminalRequest = terminalRequest
        self.terminalArtifact = terminalArtifact
        self.zkRequest = zkRequest
        self.zkArtifact = zkArtifact
        self.recursiveParent = recursiveParent
        self.recursiveChildRequest = recursiveChildRequest
        self.recursiveChildArtifact = recursiveChildArtifact
        self.recursiveIdentity = recursiveIdentity
        self.auditEvent = auditEvent
    }
}

private func timingNanoseconds(_ seconds: Double) -> Int {
    max(0, Int((seconds * 1_000_000_000).rounded()))
}

private func recordMetalTiming(_ benchmark: Benchmark, context: MetalExecutionContext) {
    guard let timing = context.lastCommandBufferTiming else { return }
    let encodeNanoseconds = timingNanoseconds(timing.encodeWallTimeSeconds)
    let commitNanoseconds = timingNanoseconds(timing.commitWallTimeSeconds)
    let waitNanoseconds = timingNanoseconds(timing.waitWallTimeSeconds)
    if let seconds = timing.gpuTimeSeconds {
        let nanoseconds = timingNanoseconds(seconds)
        benchmark.measurement(SuperNeoBenchmarkMetrics.gpuCommandBufferTime, nanoseconds)
        blackHole(nanoseconds)
    }
    benchmark.measurement(SuperNeoBenchmarkMetrics.metalEncodeWallTime, encodeNanoseconds)
    benchmark.measurement(SuperNeoBenchmarkMetrics.metalCommitWallTime, commitNanoseconds)
    benchmark.measurement(SuperNeoBenchmarkMetrics.metalWaitWallTime, waitNanoseconds)
    blackHole(timing.commandCount)
    blackHole(timing.elementCount)
    blackHole(encodeNanoseconds)
    blackHole(commitNanoseconds)
    blackHole(waitNanoseconds)
}

private func registerEndToEndBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let cpuProver = SuperNeoProver(parameters: fixture.parameters, key: fixture.key)
    let verifier = SuperNeoVerifier(parameters: fixture.parameters, key: fixture.key)
    let cpuPreparedContext = benchmarkSetupValue("failed to prepare CPU fold context for \(label)") {
        try cpuProver.prepareFoldContext(for: fixture.input)
    }

    Benchmark("fold/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let output = try cpuProver.foldWithOutput(fixture.input, transcriptSeed: fixture.transcriptSeed)
        try requireValid(verifier.reduceFold(
            publicInput: fixture.publicInput,
            proof: output.proof,
            transcriptSeed: fixture.transcriptSeed
        ))
        blackHole(output.proof.outputClaims.count)
    }

    Benchmark("fold/prepared/cpu/\(label)", configuration: defaultConfiguration) { _ in
        let output = try cpuProver.foldWithOutput(
            fixture.input,
            transcriptSeed: fixture.transcriptSeed,
            preparedContext: cpuPreparedContext
        )
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
        let metalProver = SuperNeoProver(
            parameters: fixture.parameters,
            key: fixture.key,
            context: metalContext,
            executionPolicy: .metalAccelerated
        )
        let metalPreparedContext = benchmarkSetupValue("failed to prepare Metal fold context for \(label)") {
            try metalProver.prepareFoldContext(for: fixture.input)
        }
        Benchmark("fold/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let output = try metalProver.foldWithOutput(fixture.input, transcriptSeed: fixture.transcriptSeed)
            try requireBenchmarkInvariant(
                output.proof == fixture.referenceFold.proof,
                "Metal fold output did not match CPU reference for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(output.outputClaims.count)
        }

        Benchmark("fold/prepared/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let output = try metalProver.foldWithOutput(
                fixture.input,
                transcriptSeed: fixture.transcriptSeed,
                preparedContext: metalPreparedContext
            )
            try requireBenchmarkInvariant(
                output.proof == fixture.referenceFold.proof,
                "prepared Metal fold output did not match CPU reference for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(output.outputClaims.count)
        }
    }
}

private func registerStageBenchmarks(_ fixture: SuperNeoBenchmarkFixture) {
    let label = fixture.benchmarkCase.label
    let prover = SuperNeoProver(parameters: fixture.parameters, key: fixture.key)
    let claims = fixture.piCCSClaimsWithWitness
    let foldedClaim = fixture.foldedClaimWithWitness
    let preparedContext = benchmarkSetupValue("failed to prepare stage fold context for \(label)") {
        try prover.prepareFoldContext(for: fixture.input)
    }
    let preparedPiRLCTranscript = benchmarkSetupValue("failed to prepare PiRLC transcript for \(label)") {
        try prover.preparePiRLCTranscript(
            input: fixture.input,
            sumCheck: fixture.referenceFold.proof.sumCheck,
            claims: claims,
            transcriptSeed: fixture.transcriptSeed
        )
    }

    Benchmark("stage/sumcheck/\(label)", configuration: defaultConfiguration) { _ in
        let proof = try prover.benchmarkSumCheckProof(
            input: fixture.input,
            transcriptSeed: fixture.transcriptSeed
        )
        blackHole(proof.finalPoint.count)
    }

    Benchmark("stage/prepared/sumcheck/\(label)", configuration: defaultConfiguration) { _ in
        let proof = try prover.benchmarkSumCheckProof(
            input: fixture.input,
            transcriptSeed: fixture.transcriptSeed,
            preparedContext: preparedContext
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

    Benchmark("stage/prepared/piCCSClaims/\(label)", configuration: defaultConfiguration) { _ in
        let claims = try prover.benchmarkPiCCSClaims(
            input: fixture.input,
            point: fixture.referenceFold.proof.sumCheck.finalPoint,
            preparedContext: preparedContext
        )
        blackHole(claims.count)
    }

    Benchmark("stage/piRLC/\(label)", configuration: defaultConfiguration) { _ in
        let rlc = try prover.benchmarkPiRLC(
            claims: claims,
            preparedTranscript: preparedPiRLCTranscript
        )
        blackHole(rlc.challenges.count)
    }

    Benchmark("stage/prepared/piRLC/\(label)", configuration: defaultConfiguration) { _ in
        let rlc = try prover.benchmarkPiRLC(
            claims: claims,
            preparedTranscript: preparedPiRLCTranscript
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

    Benchmark("stage/prepared/piDEC/\(label)", configuration: defaultConfiguration) { _ in
        let decomposition = try prover.benchmarkPiDEC(
            foldedClaim,
            shape: fixture.shape,
            preparedContext: preparedContext
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
        try CEOpeningRelation.proveLocalBatchDeterministic(
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
        try prover.compressedTerminalFoldEnvelopeDeterministic(
            fixture.input,
            context: compressedContext,
            ceRandomSeed: compressedCESeed
        )
    }
    let compressedEnvelopeBytes = compressedEnvelope.superNeoBytes

    Benchmark("ceOpeningProof/prove/cpu/\(label)", configuration: expensiveConfiguration) { _ in
        let proof = try CEOpeningRelation.proveLocalBatchDeterministic(
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

    Benchmark("compressedEnvelope/prove/cpu/\(label)", configuration: expensiveConfiguration) { _ in
        let envelope = try prover.compressedTerminalFoldEnvelopeDeterministic(
            fixture.input,
            context: compressedContext,
            ceRandomSeed: compressedCESeed
        )
        try requireBenchmarkInvariant(envelope == compressedEnvelope, "CPU compressed envelope changed for \(label)")
        blackHole(envelope.superNeoBytes.count)
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
        let metalProver = SuperNeoProver(
            parameters: fixture.parameters,
            key: fixture.key,
            context: metalContext,
            executionPolicy: .metalAccelerated
        )
        let metalVerifier = SuperNeoVerifier(
            parameters: fixture.parameters,
            key: fixture.key,
            context: metalContext,
            executionPolicy: .metalAccelerated
        )

        Benchmark("ceOpeningProof/prove/metal/\(label)", configuration: expensiveConfiguration) { benchmark in
            let proof = try CEOpeningRelation.proveLocalBatchDeterministic(
                statement: terminalStatement,
                witnesses: terminalWitnesses,
                shape: fixture.shape,
                key: fixture.key,
                parameters: fixture.parameters,
                randomSeed: ceProofSeed,
                metalWorkspace: metalWorkspace
            )
            try requireBenchmarkInvariant(proof == ceOpeningProof, "Metal CE opening proof changed for \(label)")
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(proof.rounds.count)
        }

        Benchmark("ceOpeningProof/verify/metal/\(label)", configuration: expensiveConfiguration) { benchmark in
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
            recordMetalTiming(benchmark, context: metalContext)
        }

        Benchmark("compressedEnvelope/prove/metal/\(label)", configuration: expensiveConfiguration) { benchmark in
            let envelope = try metalProver.compressedTerminalFoldEnvelopeDeterministic(
                fixture.input,
                context: compressedContext,
                ceRandomSeed: compressedCESeed
            )
            try requireBenchmarkInvariant(envelope == compressedEnvelope, "Metal compressed envelope changed for \(label)")
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(envelope.superNeoBytes.count)
        }

        Benchmark("compressedEnvelope/verify/metal/\(label)", configuration: expensiveConfiguration) { benchmark in
            try requireValid(metalVerifier.verifyCompressedTerminalFoldEnvelope(
                publicInput: fixture.publicInput,
                proofBytes: compressedEnvelopeBytes,
                context: compressedContext
            ))
            recordMetalTiming(benchmark, context: metalContext)
        }
    }
}

private func registerNumiSealProductBenchmarks(_ fixture: NumiSealProductBenchmarkFixture) {
    let label = "one-hot-u2"
    let prover = NumiSealProductProver()
    let verifier = NumiSealProductVerifier()

    Benchmark("numisealProduct/prove/cpu/\(label)-terminal", configuration: expensiveConfiguration) { _ in
        let artifact = try prover.prove(fixture.terminalRequest)
        let result = try verifier.verify(
            artifact: artifact,
            sourcePublicInput: fixture.prepared.publicFoldInput,
            key: fixture.prepared.key,
            executionPolicy: .highAssurance
        )
        try requireValid(result)
        blackHole(try artifact.proofEnvelopeBytes().count)
    }

    Benchmark("numisealProduct/verify/cpu/\(label)-terminal", configuration: defaultConfiguration) { _ in
        let result = try verifier.verify(
            artifact: fixture.terminalArtifact,
            sourcePublicInput: fixture.prepared.publicFoldInput,
            key: fixture.prepared.key,
            executionPolicy: .highAssurance
        )
        try requireValid(result)
    }

    Benchmark("numisealProduct/prove/cpu/\(label)-zk", configuration: expensiveConfiguration) { _ in
        let artifact = try prover.prove(fixture.zkRequest)
        let result = try verifier.verify(
            artifact: artifact,
            sourcePublicInput: fixture.prepared.publicFoldInput,
            key: fixture.prepared.key,
            executionPolicy: .highAssurance
        )
        try requireValid(result)
        blackHole(try artifact.proofEnvelopeBytes().count)
    }

    Benchmark("numisealProduct/verify/cpu/\(label)-zk", configuration: defaultConfiguration) { _ in
        let result = try verifier.verify(
            artifact: fixture.zkArtifact,
            sourcePublicInput: fixture.prepared.publicFoldInput,
            key: fixture.prepared.key,
            executionPolicy: .highAssurance
        )
        try requireValid(result)
    }

    Benchmark("numisealProduct/recursiveCarry/prove/cpu/\(label)-child", configuration: expensiveConfiguration) { _ in
        let artifact = try prover.prove(fixture.recursiveChildRequest)
        let result = try verifier.verify(
            artifact: artifact,
            sourcePublicInput: fixture.prepared.publicFoldInput,
            key: fixture.prepared.key,
            executionPolicy: .highAssurance,
            recursiveCarryParent: fixture.recursiveParent
        )
        try requireValid(result)
        blackHole(try artifact.recursiveCarryReplayBinding()?.bindingDigest)
    }

    Benchmark("numisealProduct/recursiveCarry/verify/cpu/\(label)-child", configuration: defaultConfiguration) { _ in
        let result = try verifier.verify(
            artifact: fixture.recursiveChildArtifact,
            sourcePublicInput: fixture.prepared.publicFoldInput,
            key: fixture.prepared.key,
            executionPolicy: .highAssurance,
            recursiveCarryParent: fixture.recursiveParent
        )
        try requireValid(result)
    }

    Benchmark("productControls/replayIdentity/cpu/recursive-carry", configuration: defaultConfiguration) { _ in
        let digest = fixture.recursiveIdentity.localReplayDigest
        try requireBenchmarkInvariant(
            fixture.recursiveIdentity.recursiveCarryReplayBindingDigestColumn != "none",
            "recursive carry replay digest was not bound into product identity"
        )
        blackHole(digest)
    }

    Benchmark("productControls/auditEventEncode/cpu/recursive-carry", configuration: defaultConfiguration) { _ in
        let data = try SuperNeoCanonicalJSON.encode(fixture.auditEvent)
        try requireBenchmarkInvariant(!data.isEmpty, "recursive carry audit event encoded to an empty payload")
        blackHole(data.count)
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
    let referenceWorkProfile = benchmarkSetupValue("failed to build Ajtai work profile for \(label)") {
        try AjtaiCommitter.workProfile(key: fixture.key, message: ringVector)
    }
    requireBenchmarkSetupInvariant(
        referenceWorkProfile.usesOnlySmallCoefficientScalings,
        "Ajtai fixture requires full-width coefficient scaling for \(label)"
    )
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
    let multilinearEvaluationMatrix = benchmarkSetupValue("failed to prepare multilinear evaluation matrix for \(label)") {
        try fixture.shape.matrices[1].toSparseFieldMatrix()
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
            matrix: multilinearEvaluationMatrix,
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

    Benchmark("kernel/ajtaiCommit/workProfile/\(label)", configuration: defaultConfiguration) { _ in
        let workProfile = try AjtaiCommitter.workProfile(key: fixture.key, message: ringVector)
        try requireBenchmarkInvariant(
            workProfile.usesOnlySmallCoefficientScalings,
            "Ajtai work profile regressed to full-width coefficient scaling for \(label)"
        )
        try requireBenchmarkInvariant(
            workProfile.messageCoefficientSlots == ringVector.count * CyclotomicRing54.degree,
            "Ajtai work profile changed message slot accounting for \(label)"
        )
        blackHole(workProfile.activeRotationTerms)
        blackHole(workProfile.smallCoefficientScalings)
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

        Benchmark("kernel/fieldMultiply/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let product = try metalBackend.multiply(fieldVector, fieldVector)
            try requireBenchmarkInvariant(product == zip(fieldVector, fieldVector).map(*), "Metal field multiply changed for \(label)")
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(product.count)
        }

        Benchmark("kernel/ringMultiply/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let product = try metalBackend.multiply(ringVector, ringVector)
            try requireBenchmarkInvariant(product == zip(ringVector, ringVector).map(*), "Metal ring multiply changed for \(label)")
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(product.count)
        }

        Benchmark("kernel/ringScalarMultiply/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let product = try metalBackend.multiply(ringVector, by: scalarVector)
            try requireBenchmarkInvariant(
                product == zip(ringVector, scalarVector).map { $0.scaled(by: $1) },
                "Metal ring scalar multiply changed for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(product.count)
        }

        Benchmark("kernel/ajtaiCommit/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let commitment = try AjtaiCommitter.commit(
                key: fixture.key,
                fieldWitness: fieldVector,
                context: metalContext
            )
            try requireBenchmarkInvariant(commitment == referenceCommitment, "Metal commitment changed for \(label)")
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(commitment.elements.count)
        }

        Benchmark("kernel/ajtaiCommit/batch/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let commitments = try metalBackend.ajtaiCommitments(key: fixture.key, messages: batchMessages)
            try requireBenchmarkInvariant(commitments == referenceBatchCommitments, "Metal batch commitment changed for \(label)")
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(commitments.count)
        }

        Benchmark("kernel/ajtaiCommit/batchWorkspace/metal/\(label)", configuration: defaultConfiguration) { benchmark in
            let commitments = try metalWorkspace.ajtaiCommitments(messages: batchMessages)
            try requireBenchmarkInvariant(
                commitments == referenceBatchCommitments,
                "Metal workspace batch commitment changed for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(commitments.count)
        }

        Benchmark("kernel/transformedEvaluation/metalDense/\(label)", configuration: defaultConfiguration) { benchmark in
            let rows = try metalBackend.transformedMatrixVector(matrix: transformed, vector: ringVector)
            try requireBenchmarkInvariant(rows == referenceRows, "Metal transformed rows changed for \(label)")
            let evaluation = try metalBackend.transformedEvaluation(rows: rows, rHat: rHat)
            try requireBenchmarkInvariant(
                evaluation == referenceTransformedEvaluation,
                "Metal transformed evaluation changed for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(evaluation.count)
        }

        Benchmark("kernel/transformedEvaluation/metalSparse/\(label)", configuration: defaultConfiguration) { benchmark in
            let rows = try metalBackend.transformedMatrixVector(matrix: sparseTransformed, vector: ringVector)
            try requireBenchmarkInvariant(rows == referenceSparseRows, "Metal sparse transformed rows changed for \(label)")
            let evaluation = try metalBackend.transformedEvaluation(rows: rows, rHat: rHat)
            try requireBenchmarkInvariant(
                evaluation == referenceTransformedEvaluation,
                "Metal sparse transformed evaluation changed for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(evaluation.count)
        }

        Benchmark("kernel/transformedEvaluation/metalSparseBatch/\(label)", configuration: defaultConfiguration) { benchmark in
            let evaluations = try metalBackend.transformedEvaluations(
                matrices: sparseBatchMatrices,
                vectors: batchMessages,
                point: point
            )
            try requireBenchmarkInvariant(
                evaluations == referenceSparseBatchEvaluations,
                "Metal sparse batch transformed evaluation changed for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(evaluations.count)
        }

        Benchmark("kernel/transformedEvaluation/metalSparseBatchWorkspace/\(label)", configuration: defaultConfiguration) { benchmark in
            let evaluations = try metalWorkspace.transformedEvaluations(
                vectors: batchMessages,
                point: point
            )
            try requireBenchmarkInvariant(
                evaluations == referenceSparseBatchEvaluations,
                "Metal workspace sparse batch transformed evaluation changed for \(label)"
            )
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(evaluations.count)
        }

        Benchmark("kernel/combinedCommitEval/batchWorkspace/metal/\(label)", configuration: defaultConfiguration) { benchmark in
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
            recordMetalTiming(benchmark, context: metalContext)
            blackHole(combined.commitments.count + combined.evaluations.count)
        }

        if benchmarkProfile == "scaling" {
            let schedule16 = benchmarkSetupValue("failed to build batch-16 Ajtai schedule for \(label)") {
                try AjtaiMatvecSchedule(maxBatchSize: 16)
            }
            let schedule32 = benchmarkSetupValue("failed to build batch-32 Ajtai schedule for \(label)") {
                try AjtaiMatvecSchedule(maxBatchSize: 32)
            }

            Benchmark("kernel/ajtaiCommit/batchWorkspace16/b32/metal/\(label)", configuration: defaultConfiguration) { benchmark in
                let commitments = try metalWorkspace.ajtaiCommitments(
                    messages: batchSizingMessages,
                    schedule: schedule16
                )
                try requireBenchmarkInvariant(
                    commitments == referenceBatchSizingCommitments,
                    "Metal workspace batch-16 commitments changed for \(label)"
                )
                recordMetalTiming(benchmark, context: metalContext)
                blackHole(commitments.count)
            }

            Benchmark("kernel/ajtaiCommit/batchWorkspace32/b32/metal/\(label)", configuration: defaultConfiguration) { benchmark in
                let commitments = try metalWorkspace.ajtaiCommitments(
                    messages: batchSizingMessages,
                    schedule: schedule32
                )
                try requireBenchmarkInvariant(
                    commitments == referenceBatchSizingCommitments,
                    "Metal workspace batch-32 commitments changed for \(label)"
                )
                recordMetalTiming(benchmark, context: metalContext)
                blackHole(commitments.count)
            }

            Benchmark("kernel/combinedCommitEval/batchWorkspace32/b32/metal/\(label)", configuration: defaultConfiguration) { benchmark in
                let combined = try metalWorkspace.commitmentsAndTransformedEvaluations(
                    messages: batchSizingMessages,
                    point: point,
                    schedule: schedule32
                )
                try requireBenchmarkInvariant(
                    combined.commitments == referenceBatchSizingCommitments,
                    "Metal combined workspace batch-32 commitments changed for \(label)"
                )
                recordMetalTiming(benchmark, context: metalContext)
                blackHole(combined.commitments.count + combined.evaluations.count)
            }
        }
    }
}

let benchmarks: @Sendable () -> Void = {
    let metadataDirectory = URL(fileURLWithPath: "benchmark-results", isDirectory: true)
    let numiSealProductFixture = benchmarkSetupValue("failed to build NumiSeal product benchmark fixture") {
        try NumiSealProductBenchmarkFixture()
    }
    try? SuperNeoBenchmarkMetadata().write(to: metadataDirectory, profile: benchmarkProfile, fixtures: fixtures)

    for fixture in fixtures {
        registerEndToEndBenchmarks(fixture)
    }
    registerNumiSealProductBenchmarks(numiSealProductFixture)

    let kernelFixtureLimit = benchmarkProfile == "scaling" ? fixtures.count : (benchmarkProfile == "quick" ? 1 : 4)
    for fixture in fixtures.prefix(kernelFixtureLimit) {
        registerStageBenchmarks(fixture)
        registerKernelBenchmarks(fixture)
    }

    if includeCEBenchmarks {
        for fixture in fixtures {
            registerCEBenchmarks(fixture)
        }
    }
}
