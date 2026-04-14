#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
COMPARE = ROOT / "Scripts" / "compare-benchmark-results.swift"
RENDER = ROOT / "Scripts" / "render-benchmark-report.swift"
RUN_BENCHMARKS = ROOT / "Scripts" / "run-benchmarks.sh"


def timing_row(
    benchmark: str,
    value: float,
    unit: str,
    extra: str | None = None,
) -> dict[str, Any]:
    return {
        "name": f"{benchmark} - Time (wall clock)",
        "unit": unit,
        "value": value,
        "extra": extra,
    }


def malloc_row(benchmark: str, value: float) -> dict[str, Any]:
    return {
        "name": f"{benchmark} - Malloc (total)",
        "unit": "#",
        "value": value,
        "extra": None,
    }


def nanosecond_metric_row(benchmark: str, metric: str, value: float) -> dict[str, Any]:
    return {
        "name": f"{benchmark} - {metric}",
        "unit": "ns",
        "value": value,
        "extra": None,
    }


def write_json(path: Path, rows: list[dict[str, Any]]) -> None:
    path.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")


def benchmark_metadata(
    *,
    profile: str = "quick",
    cases: str = "m256-case",
    case_filter: str = "m256",
    chip: str = "Apple M4",
    git_state: str = "dirty",
) -> dict[str, str]:
    return {
        "benchmarkProfile": profile,
        "benchmarkCases": cases,
        "swiftVersion": "Swift test toolchain",
        "xcodeVersion": "Xcode test toolchain",
        "osVersion": "TestOS 1.0",
        "modelName": "Test Mac",
        "chip": chip,
        "cpuCores": "10",
        "memory": "24 GB",
        "metalDevice": chip,
        "metalSupport": "available",
        "gitState": git_state,
        "env.SUPERNEO_BENCHMARK_PROFILE": profile,
        "env.SUPERNEO_BENCHMARK_CASE_FILTER": case_filter,
        "env.SUPERNEO_BENCHMARK_CE": "",
        "env.SUPERNEO_BENCHMARK_SIGNPOSTS": "",
        "env.SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE": "",
        "env.SUPERNEO_METAL_EVAL_ROW_PARTIAL_THRESHOLD": "",
        "env.SUPERNEO_METAL_EVAL_ROW_PARTIAL_MAX_WORDS": "",
    }


def write_metadata(path: Path, metadata: dict[str, str]) -> None:
    path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_compare(
    baseline: Path,
    candidate: Path,
    *arguments: str,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["swift", str(COMPARE), str(baseline), str(candidate), *arguments],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def run_render(results: Path, report: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["swift", str(RENDER), str(results), str(report)],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_success(name: str, result: subprocess.CompletedProcess[str]) -> None:
    if result.returncode != 0:
        raise AssertionError(
            f"{name}: command failed unexpectedly\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )


def expect_failure(
    name: str,
    result: subprocess.CompletedProcess[str],
    expected_output: str,
) -> None:
    combined_output = result.stdout + result.stderr
    if result.returncode == 0:
        raise AssertionError(f"{name}: command succeeded unexpectedly")
    if expected_output not in combined_output:
        raise AssertionError(
            f"{name}: expected output to contain {expected_output!r}, got {combined_output!r}"
        )


def test_benchmark_comparator(temp_root: Path) -> None:
    baseline = temp_root / "baseline.json"
    candidate = temp_root / "candidate.json"
    output = temp_root / "comparison.md"

    baseline_rows = [
        timing_row("kernel/fieldMultiply/m256-case", 100, "ns"),
        timing_row("fold/cpu/m256-case", 10, "ms"),
        timing_row("stage/sumcheck/m256-case", 20, "ms"),
    ]
    candidate_rows = [
        timing_row("kernel/fieldMultiply/m256-case", 104, "ns"),
        timing_row("fold/cpu/m256-case", 10.9, "ms"),
        timing_row("stage/sumcheck/m256-case", 18, "ms"),
    ]
    write_json(baseline, baseline_rows)
    write_json(candidate, candidate_rows)

    result = run_compare(baseline, candidate, "--output", str(output))
    expect_success("baseline comparison", result)
    comparison = output.read_text(encoding="utf-8")
    require("- Result: PASS" in comparison, "comparison output did not record PASS")
    require("kernel/fieldMultiply/m256-case" in comparison, "comparison missing kernel row")
    require("stage/sumcheck/m256-case" in comparison, "comparison missing stage row")

    write_json(candidate, [timing_row("kernel/fieldMultiply/m256-case", 106, "ns")])
    expect_failure(
        "kernel threshold regression",
        run_compare(baseline, candidate, "--allow-missing"),
        "FAIL",
    )

    write_json(candidate, [timing_row("fold/cpu/m256-case", 11.1, "ms")])
    expect_failure(
        "protocol threshold regression",
        run_compare(baseline, candidate, "--allow-missing"),
        "FAIL",
    )

    warn_result = run_compare(baseline, candidate, "--allow-missing", "--warn-only")
    expect_success("warn-only regression", warn_result)
    require("- Result: WARN" in warn_result.stdout, "warn-only output did not record WARN")

    write_json(candidate, [timing_row("kernel/fieldMultiply/m256-case", 95, "ns")])
    expect_failure(
        "missing candidate rows",
        run_compare(baseline, candidate),
        "Missing Candidate Rows",
    )

    missing_allowed = run_compare(baseline, candidate, "--allow-missing")
    expect_success("allow missing rows", missing_allowed)
    require(
        "treated as warnings" in missing_allowed.stdout,
        "allow-missing output did not mark missing rows as warnings",
    )

    write_json(candidate, [timing_row("unknown/row", 1, "ms")])
    expect_failure(
        "no overlap",
        run_compare(baseline, candidate),
        "benchmark result files have no overlapping wall-clock rows",
    )

    write_json(
        candidate,
        [
            timing_row("kernel/fieldMultiply/m256-case", 95, "ns"),
            timing_row("kernel/fieldMultiply/m256-case", 96, "ns"),
        ],
    )
    expect_failure(
        "duplicate wall-clock row",
        run_compare(baseline, candidate),
        "duplicate wall-clock row for kernel/fieldMultiply/m256-case",
    )

    write_json(candidate, [timing_row("kernel/fieldMultiply/m256-case", 1, "fortnight")])
    expect_failure(
        "unsupported time unit",
        run_compare(baseline, candidate),
        "unsupported benchmark time unit",
    )


def test_benchmark_metadata_comparison(temp_root: Path) -> None:
    baseline = temp_root / "metadata-baseline.json"
    candidate = temp_root / "metadata-candidate.json"
    baseline_metadata = temp_root / "baseline-metadata.json"
    candidate_metadata = temp_root / "candidate-metadata.json"
    rows = [timing_row("fold/cpu/m256-case", 10, "ms")]
    write_json(baseline, rows)
    write_json(candidate, rows)
    write_metadata(baseline_metadata, benchmark_metadata())
    write_metadata(candidate_metadata, benchmark_metadata())

    result = run_compare(
        baseline,
        candidate,
        "--baseline-metadata",
        str(baseline_metadata),
        "--candidate-metadata",
        str(candidate_metadata),
    )
    expect_success("metadata comparison success", result)
    require(
        "- Metadata comparison: PASS" in result.stdout,
        "metadata comparison did not record PASS",
    )

    write_metadata(candidate_metadata, benchmark_metadata(chip="Apple M3"))
    expect_failure(
        "metadata hardware mismatch",
        run_compare(
            baseline,
            candidate,
            "--baseline-metadata",
            str(baseline_metadata),
            "--candidate-metadata",
            str(candidate_metadata),
        ),
        "Metadata Checks",
    )

    write_metadata(candidate_metadata, benchmark_metadata(cases="m1024-case"))
    expect_failure(
        "metadata case mismatch",
        run_compare(
            baseline,
            candidate,
            "--baseline-metadata",
            str(baseline_metadata),
            "--candidate-metadata",
            str(candidate_metadata),
        ),
        "benchmarkCases",
    )

    missing_key = benchmark_metadata()
    missing_key.pop("env.SUPERNEO_BENCHMARK_CASE_FILTER")
    write_metadata(candidate_metadata, missing_key)
    expect_failure(
        "metadata missing key",
        run_compare(
            baseline,
            candidate,
            "--baseline-metadata",
            str(baseline_metadata),
            "--candidate-metadata",
            str(candidate_metadata),
        ),
        "missing candidate metadata",
    )

    write_metadata(candidate_metadata, benchmark_metadata())
    expect_failure(
        "one explicit metadata path",
        run_compare(baseline, candidate, "--baseline-metadata", str(baseline_metadata)),
        "requires both --baseline-metadata and --candidate-metadata",
    )

    expect_failure(
        "required inferred metadata missing",
        run_compare(baseline, candidate, "--require-metadata"),
        "metadata comparison required",
    )

    write_metadata(baseline_metadata, benchmark_metadata(git_state="clean"))
    write_metadata(candidate_metadata, benchmark_metadata(git_state="dirty"))
    expect_failure(
        "clean metadata required",
        run_compare(
            baseline,
            candidate,
            "--baseline-metadata",
            str(baseline_metadata),
            "--candidate-metadata",
            str(candidate_metadata),
            "--require-clean-metadata",
        ),
        "requires clean git state",
    )

    write_metadata(candidate_metadata, benchmark_metadata(git_state="clean"))
    clean_result = run_compare(
        baseline,
        candidate,
        "--baseline-metadata",
        str(baseline_metadata),
        "--candidate-metadata",
        str(candidate_metadata),
        "--require-clean-metadata",
    )
    expect_success("clean metadata comparison", clean_result)

    baseline_dir = temp_root / "auto-baseline"
    candidate_dir = temp_root / "auto-candidate"
    baseline_dir.mkdir()
    candidate_dir.mkdir()
    auto_baseline = baseline_dir / "results.json"
    auto_candidate = candidate_dir / "results.json"
    write_json(auto_baseline, rows)
    write_json(auto_candidate, rows)
    write_metadata(baseline_dir / "metadata.json", benchmark_metadata())
    write_metadata(candidate_dir / "metadata.json", benchmark_metadata())
    auto_result = run_compare(auto_baseline, auto_candidate)
    expect_success("auto metadata comparison", auto_result)
    require(
        "- Metadata comparison: PASS" in auto_result.stdout,
        "auto metadata comparison did not run",
    )


def test_benchmark_report_renderer(temp_root: Path) -> None:
    results = temp_root / "results.json"
    report = temp_root / "report.md"
    write_json(
        results,
        [
            timing_row(
                "fold/cpu/m256-case",
                10,
                "ms",
                "95th percentile: 12 ms\n",
            ),
            malloc_row("fold/cpu/m256-case", 3),
            nanosecond_metric_row("fold/cpu/m256-case", "GPU command buffer time", 2_500_000),
            nanosecond_metric_row("fold/cpu/m256-case", "Metal encode wall time", 80_000),
            nanosecond_metric_row("fold/cpu/m256-case", "Metal commit wall time", 4_000),
            nanosecond_metric_row("fold/cpu/m256-case", "Metal wait wall time", 2_750_000),
            timing_row("kernel/ajtaiCommit/cpu/m256-case", 250, "us"),
            malloc_row("kernel/ajtaiCommit/cpu/m256-case", 7),
        ],
    )
    report.write_text("# Existing Metadata\n\nkeep this block\n", encoding="utf-8")

    result = run_render(results, report)
    expect_success("render valid benchmark report", result)
    rendered = report.read_text(encoding="utf-8")
    require("# Existing Metadata" in rendered, "renderer dropped existing metadata")
    require("## Timing Summary" in rendered, "renderer missing timing summary")
    require("| Benchmark | Time | GPU | Encode | Commit | Wait | p95 | Derived | Allocations |" in rendered, "renderer missing timing split columns")
    require("`fold/cpu/m256-case`" in rendered, "renderer missing fold row")
    require("100.00 folds/s, 25600 constraints/s" in rendered, "renderer missing derived fold rate")
    require("2.5 ms" in rendered, "renderer missing GPU metric")
    require("80 μs" in rendered, "renderer missing Metal encode metric")
    require("4 μs" in rendered, "renderer missing Metal commit metric")
    require("2.75 ms" in rendered, "renderer missing Metal wait metric")
    require("12 ms" in rendered, "renderer missing p95")
    require("3 #" in rendered, "renderer missing malloc count")
    require("4000.00 commitments/s" in rendered, "renderer missing commitment rate")

    results.write_text("{ not json\n", encoding="utf-8")
    expect_failure(
        "render malformed JSON",
        run_render(results, report),
        "failed to decode benchmark result JSON",
    )

    write_json(results, [malloc_row("fold/cpu/m256-case", 1)])
    expect_failure(
        "render missing wall-clock rows",
        run_render(results, report),
        "did not contain wall-clock timing rows",
    )


def test_benchmark_runner_exports_metal_timing_metrics() -> None:
    script = RUN_BENCHMARKS.read_text(encoding="utf-8")
    for metric in [
        '"GPU command buffer time"',
        '"Metal encode wall time"',
        '"Metal commit wall time"',
        '"Metal wait wall time"',
    ]:
        require(metric in script, f"run-benchmarks.sh missing metric {metric}")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="superneo-benchmark-tooling-") as raw_tmp:
        temp_root = Path(raw_tmp)
        test_benchmark_comparator(temp_root)
        test_benchmark_metadata_comparison(temp_root)
        test_benchmark_report_renderer(temp_root)
        test_benchmark_runner_exports_metal_timing_metrics()
    print("benchmark tooling validation regression tests passed")


if __name__ == "__main__":
    main()
