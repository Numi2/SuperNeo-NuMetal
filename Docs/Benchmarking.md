# Benchmarking

This page is the current benchmark entry point. It is intentionally short; raw
reports live under `benchmark-results/` and checked report snapshots live under
`Docs/BenchmarkReports/`.

## Commands

```sh
Scripts/run-benchmarks.sh quick
Scripts/run-benchmarks.sh scaling
Scripts/run-benchmarks.sh full
Scripts/reproduce-superneo-paper.sh quick
```

Use `quick` before performance-sensitive edits. Use `full` only when refreshing
checked performance evidence.

## Coverage Contract

`TestVectors/benchmark-coverage-v1.json` is the source of truth for benchmark
coverage. It binds benchmark row prefixes to:

- `Benchmarks/SuperNeoBenchmarks/SuperNeoBenchmarks.swift`
- `Scripts/render-benchmark-report.swift`
- `Scripts/compare-benchmark-results.swift`
- `Scripts/production-gate.sh`

The production gate validates this with:

```sh
Scripts/validate-benchmark-coverage.py
Scripts/test-benchmark-coverage-validation.py
```

## Profiles

- `quick`: small CPU rows plus Metal when available.
- `scaling`: larger fold and commitment rows.
- `full`: selected proof, fold, NumiSeal, product-controls, and release evidence
  rows.

Useful filters:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m1024,m4096 Scripts/run-benchmarks.sh scaling
SUPERNEO_BENCHMARK_CE=1 Scripts/run-benchmarks.sh quick
```

## Boundaries

The checked benchmark coverage supports repository-local performance evidence.
It does not claim hosted throughput, capacity planning, universal hardware
performance, or competitor superiority. Same-hardware competitor evidence is
pinned separately by `Docs/CompetitivePerformance-2026-04-21.md` and
`TestVectors/competitive-performance-comparison-v1.json`.
