import Foundation
@_spi(Benchmarking) import SuperNeo_NuMetal

private struct Options {
    var profile = "quick"
    var format = "markdown"
    var outputPath: String?
}

private struct ReportRow: Codable {
    let caseLabel: String
    let witnessKind: String
    let rowCount: Int
    let freshCount: Int
    let priorCount: Int
    let fieldElementCount: Int
    let ringColumnCount: Int
    let paddingFieldSlotCount: Int
    let nonzeroFieldElementCount: Int
    let signedBitWidthMaximum: Int
    let currentFixedDecompositionSlotCount: Int
    let payPerBitDenseSlotCount: Int
    let payPerBitPaddedSlotCount: Int
    let payPerBitActiveDigitSlotCount: Int
    let currentProfileCanRepresentAllValues: Bool
    let fixedToPayPerBitDenseSlotRatio: Double
    let fixedToPayPerBitPaddedSlotRatio: Double
    let fixedToPayPerBitActiveDigitRatio: Double
    let fixedToPayPerBitOpeningRatio: Double
    let currentActiveRotationTerms: Int
    let currentSmallCoefficientScalings: Int
    let currentFullWidthCoefficientScalings: Int
}

private func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func requireValue() throws -> String {
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw SuperNeoError.invalidParameter("\(argument) requires a value")
            }
            index = valueIndex
            return arguments[valueIndex]
        }
        switch argument {
        case "--profile":
            options.profile = try requireValue()
        case "--format":
            let format = try requireValue()
            guard format == "markdown" || format == "json" else {
                throw SuperNeoError.invalidParameter("--format must be markdown or json")
            }
            options.format = format
        case "--output":
            options.outputPath = try requireValue()
        case "--help", "-h":
            print(usage())
            exit(0)
        default:
            throw SuperNeoError.invalidParameter("unknown argument \(argument)")
        }
        index += 1
    }
    return options
}

private func usage() -> String {
    """
    Usage:
      superneo-payperbit-eval [--profile quick|scaling|full] [--format markdown|json] [--output path]

    Models current SuperNeo ring packing and fixed decomposition against a
    Neo/SuperNeo-family pay-per-bit commitment profile for the benchmark cases.
    """
}

private func makeVector(
    count: Int,
    kind: SuperNeoBenchmarkWitnessKind,
    seed: [UInt8]
) -> [GoldilocksField] {
    var rng = DeterministicRNG(seed: seed)
    return (0..<count).map { _ in
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

private func makeRows(profile: String) throws -> [ReportRow] {
    let cases = SuperNeoBenchmarkFixtures.cases(profile: profile)
    return try cases.map { benchmarkCase in
        let shape = try SuperNeoBenchmarkFixtures.makeShape(rowCount: benchmarkCase.rowCount)
        let key = try AjtaiCommitmentKey(
            columns: shape.nRing,
            seed: Array("superneo-payperbit-eval-key-\(benchmarkCase.rowCount)".utf8)
        )
        let vector = makeVector(
            count: shape.nField,
            kind: benchmarkCase.witnessKind,
            seed: Array("superneo-payperbit-eval-\(benchmarkCase.label)".utf8)
        )
        let evaluation = try SuperNeoPayPerBitProfileEvaluation(fieldVector: vector)
        let message = try SuperNeoEmbedding.packPadded(vector)
        let currentWork = try SuperNeoCurrentCommitmentWorkSummary(
            AjtaiCommitter.workProfile(key: key, message: message)
        )
        return ReportRow(
            caseLabel: benchmarkCase.label,
            witnessKind: benchmarkCase.witnessKind.rawValue,
            rowCount: benchmarkCase.rowCount,
            freshCount: benchmarkCase.freshCount,
            priorCount: benchmarkCase.priorCount,
            fieldElementCount: evaluation.fieldElementCount,
            ringColumnCount: evaluation.ringColumnCount,
            paddingFieldSlotCount: evaluation.paddingFieldSlotCount,
            nonzeroFieldElementCount: evaluation.nonzeroFieldElementCount,
            signedBitWidthMaximum: evaluation.signedBitWidthMaximum,
            currentFixedDecompositionSlotCount: evaluation.currentFixedDecompositionSlotCount,
            payPerBitDenseSlotCount: evaluation.payPerBitDenseSlotCount,
            payPerBitPaddedSlotCount: evaluation.payPerBitPaddedSlotCount,
            payPerBitActiveDigitSlotCount: evaluation.payPerBitActiveDigitSlotCount,
            currentProfileCanRepresentAllValues: evaluation.currentProfileCanRepresentAllValues,
            fixedToPayPerBitDenseSlotRatio: evaluation.fixedToPayPerBitDenseSlotRatio,
            fixedToPayPerBitPaddedSlotRatio: evaluation.fixedToPayPerBitPaddedSlotRatio,
            fixedToPayPerBitActiveDigitRatio: evaluation.fixedToPayPerBitActiveDigitRatio,
            fixedToPayPerBitOpeningRatio: evaluation.fixedToPayPerBitOpeningRatio,
            currentActiveRotationTerms: currentWork.activeRotationTerms,
            currentSmallCoefficientScalings: currentWork.smallCoefficientScalings,
            currentFullWidthCoefficientScalings: currentWork.fullWidthCoefficientScalings
        )
    }
}

private func renderMarkdown(rows: [ReportRow], profile: String) -> String {
    var lines = [
        "# SuperNeo Pay-Per-Bit Profile Evaluation",
        "",
        "Profile: `\(profile)`",
        "",
        "This report is a model, not a protocol replacement. It compares the current fixed 14-limb decomposition and degree-54 ring packing against a Neo/SuperNeo-family pay-per-bit profile that charges by the signed bit width of witness values.",
        "",
        "| Case | nField | nRing | Pad | Nonzero | Max bits | Current slots | Dense ppb slots | Padded ppb slots | Active digit slots | Dense ratio | Padded ratio | Active ratio | Opening ratio | Current rotations |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
    ]
    for row in rows {
        lines.append(
            "| `\(row.caseLabel)`"
                + " | \(row.fieldElementCount)"
                + " | \(row.ringColumnCount)"
                + " | \(row.paddingFieldSlotCount)"
                + " | \(row.nonzeroFieldElementCount)"
                + " | \(row.signedBitWidthMaximum)"
                + " | \(row.currentFixedDecompositionSlotCount)"
                + " | \(row.payPerBitDenseSlotCount)"
                + " | \(row.payPerBitPaddedSlotCount)"
                + " | \(row.payPerBitActiveDigitSlotCount)"
                + " | \(formatRatio(row.fixedToPayPerBitDenseSlotRatio))"
                + " | \(formatRatio(row.fixedToPayPerBitPaddedSlotRatio))"
                + " | \(formatRatio(row.fixedToPayPerBitActiveDigitRatio))"
                + " | \(formatRatio(row.fixedToPayPerBitOpeningRatio))"
                + " | \(row.currentActiveRotationTerms) |"
        )
    }
    lines += [
        "",
        "## Readout",
        "",
        "- `Current slots` is `ceil(nField / 54) * 54 * 14`, matching the current fixed base-2 decomposition length.",
        "- `Dense ppb slots` is `nField * max(1, signed bit width)`, the conservative pay-per-bit model for fixed-width values.",
        "- `Padded ppb slots` keeps degree-54 ring padding but drops unused decomposition planes.",
        "- `Active digit slots` counts only nonzero signed binary digits and is useful as a lower-bound implementation target.",
        "- `Opening ratio` estimates how many decomposition commitments can disappear when the witness only needs fewer bit planes."
    ]
    return lines.joined(separator: "\n") + "\n"
}

private func formatRatio(_ value: Double) -> String {
    String(format: "%.2fx", value)
}

private let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
private let rows = try makeRows(profile: options.profile)
private let output: String
if options.format == "json" {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    output = String(data: try encoder.encode(rows), encoding: .utf8) ?? "[]"
} else {
    output = renderMarkdown(rows: rows, profile: options.profile)
}

if let outputPath = options.outputPath {
    let url = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try output.write(to: url, atomically: true, encoding: .utf8)
} else {
    print(output, terminator: "")
}
