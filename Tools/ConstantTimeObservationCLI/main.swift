import CryptoKit
import Foundation
@_spi(Benchmarking) import SuperNeo_NuMetal

private struct Options {
    var outputPath = "Evidence/ConstantTime/swift-llvm-metal-v1/observations/gpu-observation-corpus-v1.json"
    var iterations = 3
}

private struct Corpus: Codable {
    let schemaVersion: Int
    let corpusID: String
    let claimStatus: String
    let generatedAtUTC: String
    let policy: String
    let sampleModel: String
    let statisticalClaim: String
    let observationModel: [String]
    let metalDevice: String
    let sampleClasses: [SampleClass]
    let samples: [Sample]
    let summary: Summary
    let residualBoundaries: [String]
}

private struct SampleClass: Codable {
    let classID: String
    let publicShape: String
    let publicStatement: String
    let secretDescription: String
}

private struct Sample: Codable {
    let policy: String
    let classID: String
    let iteration: Int
    let processWallTimeNanoseconds: UInt64
    let operationTimings: [OperationTiming]
    let resultDigestsHex: [String: String]
}

private struct OperationTiming: Codable {
    let operation: String
    let commandCount: Int
    let elementCount: Int
    let encodeWallTimeNanoseconds: UInt64
    let commitWallTimeNanoseconds: UInt64
    let waitWallTimeNanoseconds: UInt64
    let gpuTimeNanoseconds: UInt64?
}

private struct Summary: Codable {
    let successfulSampleCount: Int
    let classSummaries: [ClassSummary]
    let maxClassMeanRatio: Double?
}

private struct ClassSummary: Codable {
    let classID: String
    let sampleCount: Int
    let meanNanoseconds: UInt64
    let minNanoseconds: UInt64
    let maxNanoseconds: UInt64
}

private enum CLIError: Error, CustomStringConvertible {
    case invalidArgument(String)
    case invariant(String)

    var description: String {
        switch self {
        case .invalidArgument(let message), .invariant(let message): return message
        }
    }
}

private let sampleClasses = [
    SampleClass(
        classID: "low-index-secret-mass",
        publicShape: "8 ring elements, 54 coefficients each",
        publicStatement: "same tensor length and public kernel launch shape",
        secretDescription: "non-zero digit mass near the first ring/coefficient"
    ),
    SampleClass(
        classID: "high-index-secret-mass",
        publicShape: "8 ring elements, 54 coefficients each",
        publicStatement: "same tensor length and public kernel launch shape",
        secretDescription: "non-zero digit mass near the last ring/coefficient"
    )
]

do {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    guard options.iterations > 0 else {
        throw CLIError.invalidArgument("--iterations must be positive")
    }
    let corpus = try generateCorpus(iterations: options.iterations)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(corpus)
    let outputURL = URL(fileURLWithPath: options.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: outputURL, options: .atomic)
    print("wrote \(options.outputPath)")
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

private func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--output":
            index += 1
            guard index < arguments.count else { throw CLIError.invalidArgument("--output requires a path") }
            options.outputPath = arguments[index]
        case "--iterations":
            index += 1
            guard index < arguments.count, let value = Int(arguments[index]) else {
                throw CLIError.invalidArgument("--iterations requires an integer")
            }
            options.iterations = value
        case "--help", "-h":
            throw CLIError.invalidArgument("usage: superneo-ct-observe [--output path] [--iterations n]")
        default:
            throw CLIError.invalidArgument("unknown argument: \(argument)")
        }
        index += 1
    }
    return options
}

private func generateCorpus(iterations: Int) throws -> Corpus {
    let context = try MetalExecutionContext()
    let backend = SuperNeoMetalBackend(context: context)
    try context.prewarmSuperNeoPipelines()
    var samples: [Sample] = []
    for iteration in 0..<iterations {
        for sampleClass in sampleClasses {
            samples.append(try runSample(
                backend: backend,
                context: context,
                sampleClass: sampleClass,
                iteration: iteration
            ))
        }
    }
    return Corpus(
        schemaVersion: 1,
        corpusID: "superneo-gpu-metal-kernel-observation-corpus-v1",
        claimStatus: "local-non-certifying-observation-corpus",
        generatedAtUTC: utcNow(),
        policy: "direct-metal-secret-bearing-kernel-observation",
        sampleModel: "same public launch dimensions with different secret coefficient positions",
        statisticalClaim: "none; pinned local GPU kernel smoke corpus only",
        observationModel: [
            "Metal command-buffer encode/commit/wait wall-clock timing",
            "Metal command-buffer gpuStartTime/gpuEndTime when available",
            "CPU reference equality for every observed GPU kernel"
        ],
        metalDevice: context.device.name,
        sampleClasses: sampleClasses,
        samples: samples,
        summary: summarize(samples),
        residualBoundaries: [
            "This corpus is local wall-clock and Metal command timing evidence, not a GPU microarchitectural proof.",
            "Hardware counters, power/contention measurements, and additional Apple GPU families remain production promotion inputs."
        ]
    )
}

private func runSample(
    backend: SuperNeoMetalBackend,
    context: MetalExecutionContext,
    sampleClass: SampleClass,
    iteration: Int
) throws -> Sample {
    let digitTensor = makeDigitTensor(classID: sampleClass.classID, iteration: iteration)
    let mask = makeMaskTensor(iteration: iteration)
    let lhs = makeFieldVector(seed: 11 + UInt64(iteration), count: 432)
    let rhs = makeFieldVector(seed: sampleClass.classID == "low-index-secret-mass" ? 23 : 29, count: 432)
    let point = makeFieldVector(seed: 37 + UInt64(iteration), count: 6)
    let terms = [
        makeFieldVector(seed: 41, count: 128),
        makeFieldVector(seed: sampleClass.classID == "low-index-secret-mass" ? 43 : 47, count: 128),
        makeFieldVector(seed: 53 + UInt64(iteration), count: 128)
    ]
    let weights = [GoldilocksField(3), GoldilocksField(5), GoldilocksField(7)]
    var timings: [OperationTiming] = []
    var digests: [String: String] = [:]

    let start = DispatchTime.now().uptimeNanoseconds

    let masked = try backend.numiSealApplyMask(digitTensor: digitTensor, mask: mask)
    try require(masked == (try SuperNeoMetalBackend.numiSealApplyMaskReference(digitTensor: digitTensor, mask: mask)))
    timings.append(try timing(context: context, operation: "numiseal_apply_mask_kernel"))
    digests["numiseal_apply_mask_kernel"] = digest(masked)

    let folded = try backend.numiSealDenseFold(lhs: lhs, rhs: rhs, challenge: GoldilocksField(9))
    try require(folded == (try SuperNeoMetalBackend.numiSealDenseFoldReference(lhs: lhs, rhs: rhs, challenge: GoldilocksField(9))))
    timings.append(try timing(context: context, operation: "numiseal_dense_fold_kernel"))
    digests["numiseal_dense_fold_kernel"] = digest(folded)

    let eqWeights = try backend.numiSealEqualityWeights(point: point)
    try require(eqWeights == (try SuperNeoMetalBackend.numiSealEqualityWeightsReference(point: point)))
    timings.append(try timing(context: context, operation: "numiseal_eq_weight_kernel"))
    digests["numiseal_eq_weight_kernel"] = digest(eqWeights)

    let accumulation = try backend.numiSealSumcheckAccumulate(terms: terms, weights: weights)
    try require(accumulation == (try SuperNeoMetalBackend.numiSealSumcheckAccumulateReference(terms: terms, weights: weights)))
    timings.append(try timing(context: context, operation: "numiseal_sumcheck_accumulate_kernel"))
    digests["numiseal_sumcheck_accumulate_kernel"] = digest(accumulation)

    let fused = try backend.numiSealApplyMaskAndAccumulate(digitTensor: digitTensor, mask: mask, weights: weights)
    try require(fused == (try SuperNeoMetalBackend.numiSealApplyMaskAndAccumulateReference(digitTensor: digitTensor, mask: mask, weights: weights)))
    timings.append(try timing(context: context, operation: "numiseal_mask_accumulate_kernel"))
    digests["numiseal_mask_accumulate_kernel.maskedTensor"] = digest(fused.maskedTensor)
    digests["numiseal_mask_accumulate_kernel.accumulation"] = digest(fused.accumulation)

    let end = DispatchTime.now().uptimeNanoseconds
    return Sample(
        policy: "direct-metal-secret-bearing-kernel-observation",
        classID: sampleClass.classID,
        iteration: iteration,
        processWallTimeNanoseconds: end - start,
        operationTimings: timings,
        resultDigestsHex: digests
    )
}

private func timing(context: MetalExecutionContext, operation: String) throws -> OperationTiming {
    guard let timing = context.lastCommandBufferTiming else {
        throw CLIError.invariant("missing Metal timing for \(operation)")
    }
    return OperationTiming(
        operation: operation,
        commandCount: timing.commandCount,
        elementCount: timing.elementCount,
        encodeWallTimeNanoseconds: nanoseconds(timing.encodeWallTimeSeconds),
        commitWallTimeNanoseconds: nanoseconds(timing.commitWallTimeSeconds),
        waitWallTimeNanoseconds: nanoseconds(timing.waitWallTimeSeconds),
        gpuTimeNanoseconds: timing.gpuTimeSeconds.map(nanoseconds)
    )
}

private func nanoseconds(_ seconds: Double) -> UInt64 {
    UInt64(max(0, (seconds * 1_000_000_000).rounded()))
}

private func makeDigitTensor(classID: String, iteration: Int) -> [CyclotomicRing54] {
    (0..<8).map { ringIndex in
        var coefficients = makeFieldVector(seed: UInt64(101 + iteration + ringIndex), count: CyclotomicRing54.degree)
        if classID == "low-index-secret-mass" {
            coefficients[0] = ringIndex == 0 ? GoldilocksField(97) : coefficients[0]
        } else {
            coefficients[CyclotomicRing54.degree - 1] = ringIndex == 7 ? GoldilocksField(193) : coefficients[CyclotomicRing54.degree - 1]
        }
        return CyclotomicRing54(coefficients)
    }
}

private func makeMaskTensor(iteration: Int) -> [CyclotomicRing54] {
    (0..<8).map { ringIndex in
        CyclotomicRing54(makeFieldVector(seed: UInt64(211 + iteration + ringIndex), count: CyclotomicRing54.degree))
    }
}

private func makeFieldVector(seed: UInt64, count: Int) -> [GoldilocksField] {
    var state = seed == 0 ? 1 : seed
    return (0..<count).map { _ in
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return GoldilocksField(state % 1_000_003)
    }
}

private func digest(_ fields: [GoldilocksField]) -> String {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(fields.count * 8)
    fields.forEach { bytes += $0.littleEndianBytes }
    return sha256Hex(bytes)
}

private func digest(_ rings: [CyclotomicRing54]) -> String {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(rings.count * CyclotomicRing54.degree * 8)
    rings.forEach { bytes += $0.littleEndianBytes }
    return sha256Hex(bytes)
}

private func sha256Hex(_ bytes: [UInt8]) -> String {
    SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
}

private func require(_ condition: Bool) throws {
    guard condition else {
        throw CLIError.invariant("CPU reference and Metal result mismatch")
    }
}

private func summarize(_ samples: [Sample]) -> Summary {
    let grouped = Dictionary(grouping: samples, by: \.classID)
    let classSummaries = grouped.keys.sorted().map { classID -> ClassSummary in
        let values = grouped[classID]!.map(\.processWallTimeNanoseconds)
        let mean = UInt64(Double(values.reduce(0, +)) / Double(values.count))
        return ClassSummary(
            classID: classID,
            sampleCount: values.count,
            meanNanoseconds: mean,
            minNanoseconds: values.min() ?? 0,
            maxNanoseconds: values.max() ?? 0
        )
    }
    let means = classSummaries.map(\.meanNanoseconds).filter { $0 > 0 }
    let ratio: Double?
    if let minMean = means.min(), let maxMean = means.max(), minMean > 0, means.count >= 2 {
        ratio = Double(maxMean) / Double(minMean)
    } else {
        ratio = nil
    }
    return Summary(
        successfulSampleCount: samples.count,
        classSummaries: classSummaries,
        maxClassMeanRatio: ratio
    )
}

private func utcNow() -> String {
    ISO8601DateFormatter().string(from: Date())
}
