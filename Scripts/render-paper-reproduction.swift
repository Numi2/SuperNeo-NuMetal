import Foundation

struct BenchmarkResult: Decodable {
    let name: String
    let unit: String
    let value: Double
    let extra: String?
}

struct PaperClaim: Encodable {
    let id: String
    let paperSource: String
    let paperClaim: String
    let repositoryEvidence: [String]
    let commands: [String]
    let benchmarkSelectors: [String]
    let generatedArtifacts: [String]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func seconds(value: Double, unit: String) -> Double? {
    switch unit {
    case "ns": return value / 1_000_000_000
    case "μs", "us": return value / 1_000_000
    case "ms": return value / 1_000
    case "s": return value
    default: return nil
    }
}

func baseBenchmarkName(_ name: String) -> String {
    if let range = name.range(of: " - ") {
        return String(name[..<range.lowerBound])
    }
    return name
}

func caseConstraintCount(_ benchmark: String) -> Int? {
    guard let range = benchmark.range(of: #"m\d+"#, options: .regularExpression) else { return nil }
    return Int(benchmark[range].dropFirst())
}

func formattedTime(_ result: BenchmarkResult) -> String {
    String(format: "%.3g %@", result.value, result.unit)
}

func derivedRate(_ benchmark: String, _ result: BenchmarkResult) -> String {
    guard let elapsed = seconds(value: result.value, unit: result.unit), elapsed > 0 else { return "" }
    if benchmark.hasPrefix("fold/") {
        if let constraints = caseConstraintCount(benchmark) {
            return String(format: "%.2f folds/s; %.0f constraints/s", 1 / elapsed, Double(constraints) / elapsed)
        }
        return String(format: "%.2f folds/s", 1 / elapsed)
    }
    if benchmark.contains("ajtaiCommit") {
        return String(format: "%.2f commitments/s", 1 / elapsed)
    }
    return ""
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    fail("usage: swift Scripts/render-paper-reproduction.swift <output-dir> <mode>")
}

let outputDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
let mode = arguments[1]
let benchmarkProfile = mode == "plan" || mode == "snapshot" ? "quick" : mode
let benchmarkDirectory = outputDirectory.appendingPathComponent("benchmark-results", isDirectory: true)
let resultsURL = benchmarkDirectory.appendingPathComponent("results.json")
let metadataURL = benchmarkDirectory.appendingPathComponent("metadata.json")
let reportURL = outputDirectory.appendingPathComponent("report.md")
let claimMapURL = outputDirectory.appendingPathComponent("claim-map.json")
let commandsURL = outputDirectory.appendingPathComponent("commands.sh")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let claims = [
    PaperClaim(
        id: "D1-parameters-module-sis-profile",
        paperSource: "superneopaper.md Appendix B.2 and Appendix D.8",
        paperClaim: "Goldilocks profile uses Phi_81 with d=54, kappa=18, b=2, k=14, C=[-2,-1,0,1,2], T=216, and about 129-bit Module-SIS security under the paper estimator.",
        repositoryEvidence: [
            "Docs/Parameters.md",
            "Docs/LatticeEstimatorReproduction.md",
            "SuperNeoParameterProfile.goldilocksPhi81",
            "Scripts/reproduce-lattice-estimator.sh",
            "Scripts/validate-lattice-estimator-artifact.py",
            "ProtocolShapeTests/testGoldilocksParameterProfileMatchesPaperProfile"
        ],
        commands: [
            "swift test --disable-swift-testing --filter ProtocolShapeTests/testGoldilocksParameterProfileMatchesPaperProfile",
            "Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json",
            "Scripts/validate-lattice-estimator-artifact.py --expect-status not_run lattice-estimator-results/superneo-goldilocks-phi81.json",
            "Scripts/reproduce-lattice-estimator.sh lattice-estimator-results/superneo-goldilocks-phi81.json"
        ],
        benchmarkSelectors: [],
        generatedArtifacts: [
            "logs/parameter-profile.txt",
            "lattice-estimator/superneo-goldilocks-phi81.json",
            "report.md"
        ]
    ),
    PaperClaim(
        id: "D2-pay-per-bit-commitment-cost-model",
        paperSource: "superneopaper.md Section 1.1 D2, Section 2.3, Appendix B.2",
        paperClaim: "The SuperNeo embedding is norm-preserving and commitment work is driven by active small witness coefficients rather than full-width field values in every slot.",
        repositoryEvidence: [
            "SuperNeoEmbedding.packPadded",
            "AjtaiCommitter.workProfile",
            "kernel/ajtaiCommit/workProfile benchmark"
        ],
        commands: [
            "Scripts/run-benchmarks.sh \(benchmarkProfile)"
        ],
        benchmarkSelectors: [
            "kernel/ajtaiCommit/workProfile/",
            "kernel/ajtaiCommit/cpu/",
            "kernel/ajtaiCommit/metal/"
        ],
        generatedArtifacts: [
            "benchmark-results/results.json",
            "report.md"
        ]
    ),
    PaperClaim(
        id: "D3-field-native-folding-stages",
        paperSource: "superneopaper.md Section 7.3 through Section 7.5",
        paperClaim: "SuperNeo folds CCS claims through PiCCS, PiRLC, and PiDEC, using field-native sum-check before decomposing large-norm folded claims back to small-norm CE claims.",
        repositoryEvidence: [
            "FoldProof.sumCheck",
            "FoldProof.piCCSClaims",
            "FoldProof.randomLinearCombinationChallenges",
            "FoldProof.decomposition",
            "ProtocolE2ETests"
        ],
        commands: [
            "Scripts/test-slice.sh protocol",
            "Scripts/run-benchmarks.sh \(benchmarkProfile)"
        ],
        benchmarkSelectors: [
            "stage/sumcheck/",
            "stage/piCCSClaims/",
            "stage/piRLC/",
            "stage/piDEC/",
            "fold/cpu/",
            "reduceFold/cpu/"
        ],
        generatedArtifacts: [
            "logs/protocol.txt",
            "benchmark-results/results.json",
            "report.md"
        ]
    ),
    PaperClaim(
        id: "D4-general-ccs-not-simd-only",
        paperSource: "superneopaper.md Figure 1, Section 2.3, Section 7.3",
        paperClaim: "SuperNeo supports general CCS rather than requiring SIMD-shaped constraints.",
        repositoryEvidence: [
            "SuperNeoR1CSBuilder",
            "SuperNeoCCSNormalizer",
            "SuperNeoOneHotVectorWorkload",
            "SuperNeoBinaryAdditionWorkload",
            "UsabilitySurfaceTests"
        ],
        commands: [
            "swift test --disable-swift-testing --filter UsabilitySurfaceTests",
            "swift run superneo verify TestVectors/one-hot-vector-fold-v1.json",
            "swift run superneo verify TestVectors/binary-addition-u8-fold-v1.json",
            "swift Scripts/validate-test-vectors.swift"
        ],
        benchmarkSelectors: [],
        generatedArtifacts: [
            "logs/usability.txt",
            "logs/golden-vector-verify.txt",
            "test-vectors/one-hot-vector-fold-v1.json",
            "test-vectors/binary-addition-u8-fold-v1.json",
            "test-vectors/manifest.json",
            "test-vectors/artifact.schema.json"
        ]
    ),
    PaperClaim(
        id: "D5-small-field-goldilocks-native",
        paperSource: "superneopaper.md Section 1.1 D5 and Appendix B.2",
        paperClaim: "The implementation runs natively over the Goldilocks field and Phi81 ring profile.",
        repositoryEvidence: [
            "GoldilocksField",
            "GoldilocksExt2",
            "CyclotomicRing54",
            "Docs/Parameters.md"
        ],
        commands: [
            "Scripts/test-slice.sh fast"
        ],
        benchmarkSelectors: [
            "kernel/fieldMultiply/",
            "kernel/ringMultiply/",
            "kernel/ringScalarMultiply/"
        ],
        generatedArtifacts: [
            "logs/fast.txt",
            "benchmark-results/results.json"
        ]
    ),
    PaperClaim(
        id: "D6-low-recursion-overhead-proxy",
        paperSource: "superneopaper.md Section 1.1 D6 and Section 7.5",
        paperClaim: "The folding output is a bounded set of decomposed CE claims; terminal verification is explicit and separate from fold reduction.",
        repositoryEvidence: [
            "FoldReductionResult.requiresTerminalRelationCheck",
            "SuperNeoVerifier.reduceFold",
            "SuperNeoVerifier.verifyFold",
            "ProofEnvelopeKind.foldReduction",
            "ProofEnvelopeKind.terminalLocal"
        ],
        commands: [
            "swift run superneo verify TestVectors/one-hot-vector-fold-v1.json",
            "Scripts/test-slice.sh protocol"
        ],
        benchmarkSelectors: [
            "reduceFold/cpu/",
            "terminalVerify/cpu/",
            "proofEnvelope/roundTrip/"
        ],
        generatedArtifacts: [
            "logs/golden-vector-verify.txt",
            "benchmark-results/report.md",
            "report.md"
        ]
    ),
    PaperClaim(
        id: "apple-silicon-metal-acceleration",
        paperSource: "Repository differentiated implementation claim, grounded against SuperNeo stages and Appendix B.2 profile",
        paperClaim: "CPU and Metal paths produce the same protocol outputs where both are available; Metal is an accelerator, not a separate trust assumption.",
        repositoryEvidence: [
            "MetalDifferentialTests",
            "Docs/GPUDeterminism.md",
            "fold/metal benchmarks",
            "kernel/combinedCommitEval/batchWorkspace/metal benchmarks"
        ],
        commands: [
            "Scripts/test-slice.sh metal",
            "Scripts/run-benchmarks.sh \(benchmarkProfile)"
        ],
        benchmarkSelectors: [
            "fold/metal/",
            "kernel/transformedEvaluation/metal",
            "kernel/combinedCommitEval/batchWorkspace/metal/"
        ],
        generatedArtifacts: [
            "logs/metal.txt",
            "benchmark-results/results.json",
            "report.md"
        ]
    )
]

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(claims).write(to: claimMapURL, options: .atomic)

let commands = """
#!/usr/bin/env bash
set -euo pipefail

# Pinned commands for this reproduction artifact.
swift test --disable-swift-testing --filter ProtocolShapeTests/testGoldilocksParameterProfileMatchesPaperProfile
swift test --disable-swift-testing --filter UsabilitySurfaceTests
swift run superneo verify TestVectors/one-hot-vector-fold-v1.json
swift run superneo verify TestVectors/binary-addition-u8-fold-v1.json
swift run superneo inspect TestVectors/one-hot-vector-fold-v1.json
swift run superneo inspect TestVectors/binary-addition-u8-fold-v1.json
swift Scripts/validate-test-vectors.swift
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/test-slice.sh fast
Scripts/test-slice.sh protocol
Scripts/test-slice.sh metal
Scripts/run-benchmarks.sh \(benchmarkProfile)
"""
try commands.write(to: commandsURL, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: commandsURL.path)

let results: [BenchmarkResult]
if FileManager.default.fileExists(atPath: resultsURL.path) {
    let data: Data
    do {
        data = try Data(contentsOf: resultsURL)
        results = try JSONDecoder().decode([BenchmarkResult].self, from: data)
    } catch {
        fail("failed to decode benchmark results at \(resultsURL.path): \(error)")
    }
} else {
    results = []
}

if mode != "plan", results.isEmpty {
    fail("no benchmark results found under \(resultsURL.path)")
}

let metadata = (try? String(contentsOf: metadataURL, encoding: .utf8)) ?? "{}"
let wallClock = results
    .filter { $0.name.contains(" - Time (wall clock)") }
    .map { (baseBenchmarkName($0.name), $0) }

func timingRows(for selectors: [String]) -> [String] {
    let matches = wallClock
        .filter { benchmark, _ in selectors.contains { benchmark.hasPrefix($0) } }
        .sorted { $0.0 < $1.0 }
    guard !matches.isEmpty else {
        return ["| No matching benchmark rows in this artifact. |  |  |"]
    }
    return matches.map { benchmark, result in
        "| `\(benchmark)` | \(formattedTime(result)) | \(derivedRate(benchmark, result)) |"
    }
}

func conciseBenchmarkSummary() -> [String] {
    let preferredPrefixes = [
        "fold/cpu/",
        "fold/metal/",
        "reduceFold/cpu/",
        "terminalVerify/cpu/",
        "proofEnvelope/roundTrip/",
        "stage/piCCSClaims/",
        "stage/piRLC/",
        "stage/piDEC/",
        "kernel/ajtaiCommit/workProfile/",
        "kernel/combinedCommitEval/batchWorkspace/metal/"
    ]
    let rows = wallClock
        .filter { benchmark, _ in preferredPrefixes.contains { benchmark.hasPrefix($0) } }
        .sorted { $0.0 < $1.0 }
    guard !rows.isEmpty else {
        return ["No benchmark result rows were present. Run `Scripts/reproduce-superneo-paper.sh quick` or use `snapshot` with existing `benchmark-results/`."]
    }
    return rows.map { benchmark, result in
        "- `\(benchmark)`: \(formattedTime(result)) \(derivedRate(benchmark, result))"
            .trimmingCharacters(in: .whitespaces)
    }
}

var report: [String] = [
    "# SuperNeo Paper Reproduction Report",
    "",
    "Mode: `\(mode)`",
    "",
    "This artifact maps the bundled Neo/SuperNeo paper claims to repository commands, tests, benchmark selectors, and generated files. It is an implementation-reproduction harness: it does not re-prove the paper's theorems. It records the exact Module-SIS estimator parameters in dry-run mode; full lattice-estimator execution is a separate Sage-backed command and is only claimed when that artifact reports `status: ran`.",
    "",
    "## Generated Artifacts",
    "",
    "- `claim-map.json`: machine-readable claim map.",
    "- `commands.sh`: pinned command list.",
    "- `logs/`: command outputs captured by the harness when the selected mode runs commands.",
    "- `benchmark-results/`: copied benchmark JSON, metadata, and benchmark report when available.",
    "- `test-vectors/`: copied public vectors used by the reproduction checks.",
    "- `lattice-estimator/`: derived Module-SIS estimator parameters for the implemented profile.",
    "",
    "## Environment Metadata",
    "",
    "```json",
    metadata.trimmingCharacters(in: .whitespacesAndNewlines),
    "```",
    "",
    "## Claim Map",
    "",
    "| ID | Paper source | Repository evidence | Commands | Benchmark selectors |",
    "| --- | --- | --- | --- | --- |"
]

for claim in claims {
    report.append(
        "| `\(claim.id)`"
            + " | \(claim.paperSource)"
            + " | \(claim.repositoryEvidence.map { "`\($0)`" }.joined(separator: "<br>"))"
            + " | \(claim.commands.map { "`\($0)`" }.joined(separator: "<br>"))"
            + " | \(claim.benchmarkSelectors.map { "`\($0)`" }.joined(separator: "<br>")) |"
    )
}

report.append(contentsOf: [
    "",
    "## Benchmark Summary",
    ""
])
report.append(contentsOf: conciseBenchmarkSummary())

report.append(contentsOf: [
    "",
    "## Claim-To-Benchmark Rows"
])

for claim in claims where !claim.benchmarkSelectors.isEmpty {
    report.append(contentsOf: [
        "",
        "### \(claim.id)",
        "",
        "| Benchmark | Time | Derived rate |",
        "| --- | ---: | ---: |"
    ])
    report.append(contentsOf: timingRows(for: claim.benchmarkSelectors))
}

report.append(contentsOf: [
    "",
    "## Proof-Vector Check",
    "",
    "The checked-in vectors are `TestVectors/one-hot-vector-fold-v1.json` and `TestVectors/binary-addition-u8-fold-v1.json`. The reproduction command verifies fold-reduction envelopes and must report that terminal CE relation checking remains required. This is intentional: kind `fold` is not terminal acceptance.",
    "",
    "## Required Interpretation",
    "",
    "A passing artifact supports the implementation claims listed above. It does not certify production security. Side-channel and malicious-GPU resistance depend on using the explicit high-assurance execution policy and on the remaining boundaries documented in `Docs/HighAssuranceHardening-2026-04-13.md`. Independent Module-SIS estimation is only claimed when `Scripts/reproduce-lattice-estimator.sh` completes a non-dry-run Sage/lattice-estimator execution."
])

try report.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
