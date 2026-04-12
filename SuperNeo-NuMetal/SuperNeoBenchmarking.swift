import Foundation
import Metal
import os

@_spi(Benchmarking) public enum SuperNeoBenchmarkSignpost {
    private static let log = OSLog(subsystem: "SuperNeo_NuMetal", category: "benchmark")
    private static let enabled = ProcessInfo.processInfo.environment["SUPERNEO_BENCHMARK_SIGNPOSTS"] == "1"

    public static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        guard enabled else { return try body() }
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        defer {
            os_signpost(.end, log: log, name: name, signpostID: signpostID)
        }
        return try body()
    }
}

@_spi(Benchmarking) public enum SuperNeoBenchmarkWitnessKind: String, CaseIterable, Sendable {
    case binary
    case ternary
    case small
}

@_spi(Benchmarking) public struct SuperNeoBenchmarkCase: Hashable, Sendable {
    public let rowCount: Int
    public let freshCount: Int
    public let priorCount: Int
    public let witnessKind: SuperNeoBenchmarkWitnessKind

    public init(
        rowCount: Int,
        freshCount: Int,
        priorCount: Int,
        witnessKind: SuperNeoBenchmarkWitnessKind
    ) {
        self.rowCount = rowCount
        self.freshCount = freshCount
        self.priorCount = priorCount
        self.witnessKind = witnessKind
    }

    public var label: String {
        "m\(rowCount)-K\(freshCount)-k\(priorCount)-\(witnessKind.rawValue)"
    }
}

@_spi(Benchmarking) public struct SuperNeoBenchmarkFixture: Sendable {
    public let benchmarkCase: SuperNeoBenchmarkCase
    public let parameters: SuperNeoParameters
    public let shape: CCSShape
    public let key: AjtaiCommitmentKey
    public let input: SuperNeoFoldInput
    public let publicInput: SuperNeoPublicFoldInput
    public let transcriptSeed: [UInt8]
    public let fieldVector: [GoldilocksField]
    public let ringVector: [CyclotomicRing54]
    public let transformedMatrices: [RingMatrix]
    public let transformedSparseMatrices: [SparseRingMatrixCSR]
    public let evaluationPoint: [GoldilocksExt2]
    public let referenceFold: FoldProverOutput
    public let piCCSClaimsWithWitness: [CCSEvaluationClaim]
    public let foldedClaimWithWitness: CCSEvaluationClaim
    public let proofEnvelopeContext: ProofEnvelopeContext
    public let proofEnvelopeBytes: [UInt8]
    public let proofEnvelopeOutputClaims: [CCSEvaluationClaim]

    public init(
        benchmarkCase: SuperNeoBenchmarkCase,
        parameters: SuperNeoParameters = .goldilocks
    ) throws {
        guard benchmarkCase.rowCount > CyclotomicRing54.degree else {
            throw SuperNeoError.invalidParameter("benchmark row count must exceed one public ring column")
        }
        guard benchmarkCase.rowCount > 0, (benchmarkCase.rowCount & (benchmarkCase.rowCount - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("benchmark row count must be a power of two")
        }
        guard benchmarkCase.freshCount > 0 else {
            throw SuperNeoError.invalidParameter("benchmark fresh count must be positive")
        }
        guard benchmarkCase.priorCount <= parameters.decompositionLength else {
            throw SuperNeoError.invalidParameter("benchmark prior count exceeds decomposition length")
        }

        self.benchmarkCase = benchmarkCase
        self.parameters = parameters
        self.transcriptSeed = Array("superneo-benchmark-\(benchmarkCase.label)".utf8)

        let shape = try SuperNeoBenchmarkFixtures.makeShape(rowCount: benchmarkCase.rowCount)
        let key = try AjtaiCommitmentKey(
            parameters: parameters,
            columns: shape.nRing,
            seed: Array("superneo-benchmark-key-\(benchmarkCase.rowCount)".utf8)
        )
        let priorClaims = try SuperNeoBenchmarkFixtures.makePriorClaims(
            count: benchmarkCase.priorCount,
            shape: shape,
            key: key,
            kind: benchmarkCase.witnessKind,
            seedPrefix: "superneo-benchmark-prior-\(benchmarkCase.label)"
        )
        let (instances, witnesses, fieldVector) = try SuperNeoBenchmarkFixtures.makeInstances(
            count: benchmarkCase.freshCount,
            shape: shape,
            key: key,
            kind: benchmarkCase.witnessKind,
            seedPrefix: "superneo-benchmark-fresh-\(benchmarkCase.label)"
        )
        let input = SuperNeoFoldInput(
            shape: shape,
            instances: instances,
            witnesses: witnesses,
            priorClaims: priorClaims
        )
        let publicInput = SuperNeoPublicFoldInput(input)
        let compiledShape = try shape.compiledForSuperNeo()
        let transformedMatrices = compiledShape.transformedMatrices
        let transformedSparseMatrices = compiledShape.transformedSparseMatrices
        let numVars = try SuperNeoBenchmarkFixtures.log2Exact(benchmarkCase.rowCount)
        let evaluationPoint = try SuperNeoBenchmarkFixtures.makeEvaluationPoint(count: numVars, seed: transcriptSeed)
        let prover = SuperNeoProver(parameters: parameters, key: key)
        let referenceFold = try prover.foldWithOutput(input, transcriptSeed: transcriptSeed)
        let piCCSClaimsWithWitness = try prover.benchmarkPiCCSClaims(
            input: input,
            point: referenceFold.proof.sumCheck.finalPoint
        )
        let rlcWithWitness = try prover.benchmarkPiRLC(
            input: input,
            claims: piCCSClaimsWithWitness,
            transcriptSeed: transcriptSeed
        )
        let statement = CCSStatement(
            shapeDigest: shape.shapeDigest,
            ccsInstances: publicInput.instances,
            priorCEInstances: publicInput.priorClaims.map { CEInstance($0) }
        )
        let proofEnvelopeContext = ProofEnvelopeContext(
            profileID: parameters.profileID,
            statement: statement,
            verifierKeyDigest: key.verifierKeyDigest
        )
        let proofEnvelopeFold = try prover.foldWithOutput(
            input,
            transcriptSeed: proofEnvelopeContext.transcriptBindingBytes
        )
        let proofEnvelope = try FoldProofEnvelope(
            context: proofEnvelopeContext,
            proof: proofEnvelopeFold.proof
        )

        self.shape = shape
        self.key = key
        self.input = input
        self.publicInput = publicInput
        self.fieldVector = fieldVector
        self.ringVector = try SuperNeoEmbedding.packPadded(fieldVector)
        self.transformedMatrices = transformedMatrices
        self.transformedSparseMatrices = transformedSparseMatrices
        self.evaluationPoint = evaluationPoint
        self.referenceFold = referenceFold
        self.piCCSClaimsWithWitness = piCCSClaimsWithWitness
        self.foldedClaimWithWitness = rlcWithWitness.foldedClaim
        self.proofEnvelopeContext = proofEnvelopeContext
        self.proofEnvelopeBytes = proofEnvelope.superNeoBytes
        self.proofEnvelopeOutputClaims = proofEnvelopeFold.outputClaims
    }
}

@_spi(Benchmarking) public enum SuperNeoBenchmarkFixtures {
    public static let quickCases: [SuperNeoBenchmarkCase] = [
        SuperNeoBenchmarkCase(rowCount: 64, freshCount: 1, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 2, priorCount: 1, witnessKind: .binary)
    ]

    public static let fullCases: [SuperNeoBenchmarkCase] = [
        SuperNeoBenchmarkCase(rowCount: 64, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 1_024, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 4_096, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 16_384, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 1, priorCount: 0, witnessKind: .ternary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 4, priorCount: 0, witnessKind: .ternary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 8, priorCount: 0, witnessKind: .ternary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 16, priorCount: 0, witnessKind: .ternary),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 2, priorCount: 1, witnessKind: .small),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 2, priorCount: 2, witnessKind: .small),
        SuperNeoBenchmarkCase(rowCount: 256, freshCount: 2, priorCount: 4, witnessKind: .small)
    ]

    public static let scalingCases: [SuperNeoBenchmarkCase] = [
        SuperNeoBenchmarkCase(rowCount: 1_024, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 4_096, freshCount: 2, priorCount: 0, witnessKind: .binary),
        SuperNeoBenchmarkCase(rowCount: 16_384, freshCount: 2, priorCount: 0, witnessKind: .binary)
    ]

    public static func cases(profile: String) -> [SuperNeoBenchmarkCase] {
        switch profile {
        case "quick":
            return quickCases
        case "scaling":
            return scalingCases
        case "full":
            return fullCases
        default:
            return fullCases
        }
    }

    public static func makeMetalContextIfAvailable() -> MetalExecutionContext? {
        guard let context = try? MetalExecutionContext() else { return nil }
        try? context.prewarmSuperNeoPipelines()
        return context
    }

    public static func makeShape(rowCount: Int) throws -> CCSShape {
        let identity = try SparseFieldMatrix.identity(size: rowCount)
        let sparse = try makeSparseMatrix(rowCount: rowCount, nonzerosPerRow: 4)
        let relation = try RelationPolynomial(variableCount: 2, monomials: [])
        return try CCSShape(
            matrices: [identity, sparse],
            publicInputCount: CyclotomicRing54.degree,
            relationPolynomial: relation
        )
    }

    public static func makeEvaluationPoint(count: Int, seed: [UInt8]) throws -> [GoldilocksExt2] {
        var rng = DeterministicRNG(seed: seed + Array(".eval-point".utf8))
        return (0..<count).map { _ in rng.nextExt2() }
    }

    public static func log2Exact(_ value: Int) throws -> Int {
        guard value > 0, (value & (value - 1)) == 0 else {
            throw SuperNeoError.invalidParameter("value is not a positive power of two")
        }
        return value.trailingZeroBitCount
    }

    static func makePriorClaims(
        count: Int,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        kind: SuperNeoBenchmarkWitnessKind,
        seedPrefix: String
    ) throws -> [CCSEvaluationClaim] {
        guard count > 0 else { return [] }
        let (instances, witnesses, _) = try makeInstances(
            count: 1,
            shape: shape,
            key: key,
            kind: kind,
            seedPrefix: seedPrefix
        )
        let input = SuperNeoFoldInput(shape: shape, instances: instances, witnesses: witnesses)
        let fold = try SuperNeoProver(key: key).foldWithOutput(
            input,
            transcriptSeed: Array("\(seedPrefix)-fold".utf8)
        )
        return Array(fold.outputClaims.prefix(count))
    }

    static func makeInstances(
        count: Int,
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        kind: SuperNeoBenchmarkWitnessKind,
        seedPrefix: String
    ) throws -> (instances: [CCSInstance], witnesses: [CCSWitness], firstFieldVector: [GoldilocksField]) {
        var instances: [CCSInstance] = []
        var witnesses: [CCSWitness] = []
        var firstFieldVector: [GoldilocksField] = []
        instances.reserveCapacity(count)
        witnesses.reserveCapacity(count)
        for index in 0..<count {
            let publicInput = makeVector(
                count: shape.nPublicField,
                kind: kind,
                seed: Array("\(seedPrefix)-public-\(index)".utf8)
            )
            let privateWitness = makeVector(
                count: shape.nField - shape.nPublicField,
                kind: kind,
                seed: Array("\(seedPrefix)-private-\(index)".utf8)
            )
            let fullWitness = publicInput + privateWitness
            if index == 0 {
                firstFieldVector = fullWitness
            }
            instances.append(CCSInstance(
                commitment: try AjtaiCommitter.commitReference(key: key, fieldWitness: fullWitness),
                publicInput: publicInput
            ))
            witnesses.append(CCSWitness(privateWitness))
        }
        return (instances, witnesses, firstFieldVector)
    }

    private static func makeSparseMatrix(rowCount: Int, nonzerosPerRow: Int) throws -> SparseFieldMatrix {
        var entries: [SparseFieldMatrix.Entry] = []
        entries.reserveCapacity(rowCount * nonzerosPerRow)
        for row in 0..<rowCount {
            var columns = Set<Int>()
            columns.insert(row)
            for offset in 1..<nonzerosPerRow {
                columns.insert((row + offset * 17) % rowCount)
            }
            for (position, column) in columns.sorted().enumerated() {
                entries.append(SparseFieldMatrix.Entry(
                    row: row,
                    column: column,
                    value: GoldilocksField(UInt64(position + 1))
                ))
            }
        }
        return try SparseFieldMatrix(rows: rowCount, columns: rowCount, entries: entries)
    }

    private static func makeVector(
        count: Int,
        kind: SuperNeoBenchmarkWitnessKind,
        seed: [UInt8]
    ) -> [GoldilocksField] {
        var rng = DeterministicRNG(seed: seed)
        return (0..<count).map { index in
            switch kind {
            case .binary:
                return (rng.nextUInt64() & 1) == 0 ? .zero : .one
            case .ternary:
                switch Int(rng.nextUInt64() % 3) {
                case 0: return -GoldilocksField.one
                case 1: return .zero
                default: return .one
                }
            case .small:
                let value = Int(rng.nextUInt64() % 5) - 2
                if value >= 0 { return GoldilocksField(UInt64(value)) }
                return -GoldilocksField(UInt64(-value))
            }
        }
    }
}

@_spi(Benchmarking) public struct SuperNeoBenchmarkMetadata: Sendable {
    public let generatedAt: String
    public let gitCommit: String
    public let swiftVersion: String
    public let xcodeVersion: String
    public let osVersion: String
    public let modelName: String
    public let chip: String
    public let cpuCores: String
    public let memory: String
    public let metalDevice: String
    public let metalSupport: String

    public init() {
        generatedAt = ISO8601DateFormatter().string(from: Date())
        gitCommit = Self.shell(["git", "rev-parse", "--short", "HEAD"])
        swiftVersion = Self.shell(["swift", "--version"])
        xcodeVersion = Self.shell(["xcodebuild", "-version"]).replacingOccurrences(of: "\n", with: " ")
        let processInfo = ProcessInfo.processInfo
        osVersion = processInfo.operatingSystemVersionString
        let hardware = Self.systemProfiler()
        modelName = hardware["Model Name"] ?? "unknown"
        chip = hardware["Chip"] ?? hardware["Chipset Model"] ?? "unknown"
        cpuCores = hardware["Total Number of Cores"] ?? "unknown"
        memory = hardware["Memory"] ?? "unknown"
        if let device = MTLCreateSystemDefaultDevice() {
            metalDevice = device.name
            metalSupport = "available"
        } else {
            metalDevice = "none"
            metalSupport = "unavailable"
        }
    }

    public var jsonObject: [String: String] {
        [
            "generatedAt": generatedAt,
            "gitCommit": gitCommit,
            "swiftVersion": swiftVersion,
            "xcodeVersion": xcodeVersion,
            "osVersion": osVersion,
            "modelName": modelName,
            "chip": chip,
            "cpuCores": cpuCores,
            "memory": memory,
            "metalDevice": metalDevice,
            "metalSupport": metalSupport
        ]
    }

    public var markdown: String {
        """
        # SuperNeo Benchmark Metadata

        | Field | Value |
        | --- | --- |
        | Generated | \(generatedAt) |
        | Git commit | \(gitCommit) |
        | Swift | \(swiftVersion.replacingOccurrences(of: "\n", with: " ")) |
        | Xcode | \(xcodeVersion) |
        | OS | \(osVersion) |
        | Model | \(modelName) |
        | Chip | \(chip) |
        | CPU cores | \(cpuCores) |
        | Memory | \(memory) |
        | Metal device | \(metalDevice) |
        | Metal support | \(metalSupport) |
        """
    }

    public func write(to directory: URL, profile: String, fixtures: [SuperNeoBenchmarkFixture] = []) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jsonData = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        )
        try jsonData.write(to: directory.appendingPathComponent("metadata.json"))
        let report = markdown
            + "\n\n## Benchmark Profile\n\n"
            + "- Profile: `\(profile)`\n"
            + "- Cases: \(fixtures.map { "`\($0.benchmarkCase.label)`" }.joined(separator: ", "))\n"
            + Self.proofSizeMarkdown(for: fixtures)
        try report.write(
            to: directory.appendingPathComponent("report.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func proofSizeMarkdown(for fixtures: [SuperNeoBenchmarkFixture]) -> String {
        guard !fixtures.isEmpty else { return "" }
        var lines = [
            "",
            "## Proof Sizes",
            "",
            "| Case | Constraints | Proof | Envelope | Sum-check | PiCCS | PiRLC | PiDEC | Output claims |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
        ]
        for fixture in fixtures {
            let proof = fixture.referenceFold.proof
            let piCCSBytes = proof.piCCSClaims.reduce(0) { $0 + $1.superNeoBytes.count }
            let piRLCBytes = proof.randomLinearCombinationChallenges.reduce(0) { $0 + $1.superNeoBytes.count }
                + proof.foldedClaim.superNeoBytes.count
            let outputClaimsBytes = proof.outputClaims.reduce(0) { $0 + $1.superNeoBytes.count }
            lines.append(
                "| `\(fixture.benchmarkCase.label)`"
                    + " | \(fixture.benchmarkCase.rowCount)"
                    + " | \(proof.superNeoBytes.count)"
                    + " | \(fixture.proofEnvelopeBytes.count)"
                    + " | \(proof.sumCheck.superNeoBytes.count)"
                    + " | \(piCCSBytes)"
                    + " | \(piRLCBytes)"
                    + " | \(proof.decomposition.superNeoBytes.count)"
                    + " | \(outputClaimsBytes) |"
            )
        }
        return "\n" + lines.joined(separator: "\n")
    }

    private static func shell(_ arguments: [String]) -> String {
        guard let executable = arguments.first else { return "unknown" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + Array(arguments.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "unknown" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        } catch {
            return "unknown"
        }
    }

    private static func systemProfiler() -> [String: String] {
        let output = shell(["system_profiler", "SPHardwareDataType", "SPDisplaysDataType"])
        var values: [String: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            values[key] = value
        }
        return values
    }
}
