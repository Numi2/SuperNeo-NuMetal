import Foundation

struct BenchmarkResult: Decodable {
    let name: String
    let unit: String
    let value: Double
    let extra: String?
}

struct TimingRow {
    let benchmark: String
    let seconds: Double
    let value: Double
    let unit: String
}

enum BenchmarkClass: String {
    case kernel
    case protocolPath = "protocol"
    case other
}

struct Options {
    var baselinePath: String?
    var candidatePath: String?
    var outputPath: String?
    var kernelThreshold = 0.05
    var protocolThreshold = 0.10
    var warnOnly = false
    var allowMissing = false
}

struct ComparisonRow {
    let benchmark: String
    let benchmarkClass: BenchmarkClass
    let baseline: TimingRow
    let candidate: TimingRow
    let ratio: Double
    let threshold: Double
    let status: String
    let isFailure: Bool
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

func usage() -> Never {
    fail("""
    Usage:
      swift Scripts/compare-benchmark-results.swift baseline.json candidate.json [--output comparison.md] [--kernel-threshold 0.05] [--protocol-threshold 0.10] [--warn-only] [--allow-missing]
    """)
}

func parseOptions(_ arguments: [String]) -> Options {
    var options = Options()
    var positionals: [String] = []
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--output":
            index += 1
            guard index < arguments.count else { usage() }
            options.outputPath = arguments[index]
        case "--kernel-threshold":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0 else { usage() }
            options.kernelThreshold = value
        case "--protocol-threshold":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0 else { usage() }
            options.protocolThreshold = value
        case "--warn-only":
            options.warnOnly = true
        case "--allow-missing":
            options.allowMissing = true
        case "--help", "-h":
            usage()
        default:
            guard !argument.hasPrefix("--") else { usage() }
            positionals.append(argument)
        }
        index += 1
    }
    guard positionals.count == 2 else { usage() }
    options.baselinePath = positionals[0]
    options.candidatePath = positionals[1]
    return options
}

func seconds(value: Double, unit: String) -> Double? {
    switch unit {
    case "ns": return value / 1_000_000_000
    case "\u{03BC}s", "us": return value / 1_000_000
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

func benchmarkClass(_ benchmark: String) -> BenchmarkClass {
    if benchmark.hasPrefix("kernel/") {
        return .kernel
    }
    if benchmark.hasPrefix("fold/")
        || benchmark.hasPrefix("reduceFold/")
        || benchmark.hasPrefix("terminalVerify/")
        || benchmark.hasPrefix("proofEnvelope/")
        || benchmark.hasPrefix("ceOpeningProof/")
        || benchmark.hasPrefix("compressedEnvelope/")
        || benchmark.hasPrefix("stage/") {
        return .protocolPath
    }
    return .other
}

func threshold(for benchmarkClass: BenchmarkClass, options: Options) -> Double {
    switch benchmarkClass {
    case .kernel:
        return options.kernelThreshold
    case .protocolPath, .other:
        return options.protocolThreshold
    }
}

func loadTimingRows(_ path: String) -> [String: TimingRow] {
    let url = URL(fileURLWithPath: path)
    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        fail("failed to read benchmark result JSON at \(path): \(error)")
    }
    let results: [BenchmarkResult]
    do {
        results = try JSONDecoder().decode([BenchmarkResult].self, from: data)
    } catch {
        fail("failed to decode benchmark result JSON at \(path): \(error)")
    }

    var rows: [String: TimingRow] = [:]
    for result in results where result.name.contains(" - Time (wall clock)") {
        let benchmark = baseBenchmarkName(result.name)
        guard let normalizedSeconds = seconds(value: result.value, unit: result.unit) else {
            fail("unsupported benchmark time unit '\(result.unit)' for \(benchmark) in \(path)")
        }
        guard normalizedSeconds > 0 else {
            fail("non-positive benchmark time for \(benchmark) in \(path)")
        }
        guard rows[benchmark] == nil else {
            fail("duplicate wall-clock row for \(benchmark) in \(path)")
        }
        rows[benchmark] = TimingRow(
            benchmark: benchmark,
            seconds: normalizedSeconds,
            value: result.value,
            unit: result.unit
        )
    }
    guard !rows.isEmpty else {
        fail("benchmark result JSON at \(path) did not contain wall-clock timing rows")
    }
    return rows
}

func formatDuration(_ seconds: Double) -> String {
    if seconds < 0.000_001 {
        return String(format: "%.3g ns", seconds * 1_000_000_000)
    }
    if seconds < 0.001 {
        return String(format: "%.3g us", seconds * 1_000_000)
    }
    if seconds < 1 {
        return String(format: "%.3g ms", seconds * 1_000)
    }
    return String(format: "%.3g s", seconds)
}

func formatPercent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

func formatChange(_ ratio: Double) -> String {
    if abs(ratio - 1) < 0.000_001 {
        return "unchanged"
    }
    if ratio > 1 {
        return String(format: "%.2fx slower", ratio)
    }
    return String(format: "%.2fx faster", 1 / ratio)
}

func markdownEscaped(_ value: String) -> String {
    value
        .replacingOccurrences(of: "|", with: "\\|")
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\n", with: "<br>")
}

func compare(
    baseline: [String: TimingRow],
    candidate: [String: TimingRow],
    options: Options
) -> (rows: [ComparisonRow], missing: [String], added: [String]) {
    let baselineKeys = Set(baseline.keys)
    let candidateKeys = Set(candidate.keys)
    let common = baselineKeys.intersection(candidateKeys).sorted()
    guard !common.isEmpty else {
        fail("benchmark result files have no overlapping wall-clock rows")
    }

    let rows = common.map { benchmark -> ComparisonRow in
        let baselineRow = baseline[benchmark]!
        let candidateRow = candidate[benchmark]!
        let ratio = candidateRow.seconds / baselineRow.seconds
        let classification = benchmarkClass(benchmark)
        let allowed = threshold(for: classification, options: options)
        let regression = ratio - 1
        let isFailure = regression > allowed
        let status: String
        if isFailure {
            status = "FAIL"
        } else if regression > 0 {
            status = "within threshold"
        } else if ratio < 1 {
            status = "faster"
        } else {
            status = "unchanged"
        }
        return ComparisonRow(
            benchmark: benchmark,
            benchmarkClass: classification,
            baseline: baselineRow,
            candidate: candidateRow,
            ratio: ratio,
            threshold: allowed,
            status: status,
            isFailure: isFailure
        )
    }
    return (
        rows,
        baselineKeys.subtracting(candidateKeys).sorted(),
        candidateKeys.subtracting(baselineKeys).sorted()
    )
}

func renderMarkdown(
    rows: [ComparisonRow],
    missing: [String],
    added: [String],
    options: Options
) -> String {
    let failingRows = rows.filter(\.isFailure)
    let missingFailures = options.allowMissing ? [] : missing
    let pass = failingRows.isEmpty && missingFailures.isEmpty
    var lines = [
        "# SuperNeo Benchmark Comparison",
        "",
        "- Baseline: `\(markdownEscaped(options.baselinePath ?? ""))`",
        "- Candidate: `\(markdownEscaped(options.candidatePath ?? ""))`",
        "- Kernel threshold: \(formatPercent(options.kernelThreshold))",
        "- Protocol threshold: \(formatPercent(options.protocolThreshold))",
        "- Missing baseline rows: \(options.allowMissing ? "warning" : "failure")",
        "- Mode: \(options.warnOnly ? "warn only" : "failing gate")",
        "- Result: \(pass ? "PASS" : (options.warnOnly ? "WARN" : "FAIL"))",
        "",
        "## Timing Rows",
        "",
        "| Benchmark | Class | Baseline | Candidate | Change | Threshold | Status |",
        "| --- | --- | ---: | ---: | ---: | ---: | --- |"
    ]

    for row in rows.sorted(by: { $0.benchmark < $1.benchmark }) {
        lines.append(
            "| `\(markdownEscaped(row.benchmark))`"
                + " | \(row.benchmarkClass.rawValue)"
                + " | \(formatDuration(row.baseline.seconds))"
                + " | \(formatDuration(row.candidate.seconds))"
                + " | \(formatChange(row.ratio))"
                + " | \(formatPercent(row.threshold))"
                + " | \(row.status) |"
        )
    }

    if !missing.isEmpty {
        lines += [
            "",
            "## Missing Candidate Rows",
            "",
            options.allowMissing
                ? "These rows existed in the baseline but not in the candidate and were treated as warnings."
                : "These rows existed in the baseline but not in the candidate and failed the comparison.",
            ""
        ]
        lines += missing.map { "- `\(markdownEscaped($0))`" }
    }

    if !added.isEmpty {
        lines += [
            "",
            "## Added Candidate Rows",
            "",
            "These rows exist only in the candidate and were not thresholded.",
            ""
        ]
        lines += added.map { "- `\(markdownEscaped($0))`" }
    }

    return lines.joined(separator: "\n") + "\n"
}

let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
let baselineRows = loadTimingRows(options.baselinePath!)
let candidateRows = loadTimingRows(options.candidatePath!)
let comparison = compare(baseline: baselineRows, candidate: candidateRows, options: options)
let markdown = renderMarkdown(
    rows: comparison.rows,
    missing: comparison.missing,
    added: comparison.added,
    options: options
)

if let outputPath = options.outputPath {
    do {
        try markdown.write(toFile: outputPath, atomically: true, encoding: .utf8)
    } catch {
        fail("failed to write benchmark comparison to \(outputPath): \(error)")
    }
} else {
    print(markdown, terminator: "")
}

let hasTimingFailures = comparison.rows.contains(where: \.isFailure)
let hasMissingFailures = !options.allowMissing && !comparison.missing.isEmpty
if (hasTimingFailures || hasMissingFailures) && !options.warnOnly {
    exit(1)
}
