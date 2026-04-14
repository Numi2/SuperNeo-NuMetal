import Foundation

struct BenchmarkResult: Decodable {
    let name: String
    let unit: String
    let value: Double
    let extra: String?
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

func p95(from extra: String?) -> String {
    guard let extra else { return "" }
    for line in extra.split(separator: "\n") where line.contains("95th percentile") {
        return String(line.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces)
    }
    return ""
}

func nanoseconds(_ value: Double) -> String {
    switch value {
    case ..<1_000:
        return String(format: "%.3g ns", value)
    case ..<1_000_000:
        return String(format: "%.3g μs", value / 1_000)
    case ..<1_000_000_000:
        return String(format: "%.3g ms", value / 1_000_000)
    default:
        return String(format: "%.3g s", value / 1_000_000_000)
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

let resultPath = CommandLine.arguments.dropFirst().first ?? "benchmark-results/results.json"
let reportPath = CommandLine.arguments.dropFirst().dropFirst().first ?? "benchmark-results/report.md"
let resultURL = URL(fileURLWithPath: resultPath)
let reportURL = URL(fileURLWithPath: reportPath)

guard let data = try? Data(contentsOf: resultURL) else {
    fail("missing benchmark result JSON at \(resultPath)")
}

let decoder = JSONDecoder()
let results: [BenchmarkResult]
do {
    results = try decoder.decode([BenchmarkResult].self, from: data)
} catch {
    fail("failed to decode benchmark result JSON at \(resultPath): \(error)")
}
let wallClock = results.filter { $0.name.contains(" - Time (wall clock)") }
guard !wallClock.isEmpty else {
    fail("benchmark result JSON at \(resultPath) did not contain wall-clock timing rows")
}
let mallocCounts = Dictionary(uniqueKeysWithValues: results
    .filter { $0.name.contains(" - Malloc (total)") }
    .map { (baseBenchmarkName($0.name), String(format: "%.0f %@", $0.value, $0.unit)) })
let gpuTimes = Dictionary(uniqueKeysWithValues: results
    .filter { $0.name.contains(" - GPU command buffer time") }
    .map { (baseBenchmarkName($0.name), nanoseconds($0.value)) })

let selectedPrefixes = [
    "fold/cpu/",
    "fold/metal/",
    "fold/prepared/",
    "reduceFold/cpu/",
    "terminalVerify/cpu/",
    "proofEnvelope/roundTrip/",
    "ceOpeningProof/",
    "compressedEnvelope/",
    "stage/",
    "kernel/fieldMultiply/",
    "kernel/ringMultiply/",
    "kernel/ringScalarMultiply/",
    "kernel/ajtaiCommit/",
    "kernel/combinedCommitEval/",
    "kernel/transformedEvaluation/"
]

var lines = [
    "",
    "",
    "## Timing Summary",
    "",
    "| Benchmark | Time | GPU | p95 | Derived | Allocations |",
    "| --- | ---: | ---: | ---: | ---: | ---: |"
]

for result in wallClock.sorted(by: { $0.name < $1.name }) {
    let benchmark = baseBenchmarkName(result.name)
    guard selectedPrefixes.contains(where: { benchmark.hasPrefix($0) }) else { continue }
    var derived = ""
    if let elapsed = seconds(value: result.value, unit: result.unit), elapsed > 0 {
        if benchmark.hasPrefix("fold/") {
            let foldsPerSecond = 1 / elapsed
            if let constraints = caseConstraintCount(benchmark) {
                derived = String(format: "%.2f folds/s, %.0f constraints/s", foldsPerSecond, Double(constraints) / elapsed)
            } else {
                derived = String(format: "%.2f folds/s", foldsPerSecond)
            }
        } else if benchmark.contains("ajtaiCommit") {
            derived = String(format: "%.2f commitments/s", 1 / elapsed)
        }
    }
    lines.append(
        "| `\(benchmark)`"
            + " | \(String(format: "%.3g %@", result.value, result.unit))"
            + " | \(gpuTimes[benchmark] ?? "")"
            + " | \(p95(from: result.extra))"
            + " | \(derived)"
            + " | \(mallocCounts[benchmark] ?? "") |"
    )
}

let existing = (try? String(contentsOf: reportURL, encoding: .utf8)) ?? ""
let trimmed = existing.replacingOccurrences(
    of: #"\n+## Timing Summary\n[\s\S]*$"#,
    with: "",
    options: .regularExpression
)
try (trimmed + lines.joined(separator: "\n") + "\n").write(to: reportURL, atomically: true, encoding: .utf8)
