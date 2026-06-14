# Benchmarking

This page is the current benchmark entry point. It is intentionally short; raw
reports live under `benchmark-results/`. Old checked report snapshots live under
`Docs/Archive/compliance/BenchmarkReports/` for reference only.

## Commands

```sh
Scripts/run-benchmarks.sh quick
Scripts/run-benchmarks.sh scaling
Scripts/run-benchmarks.sh full
Scripts/reproduce-superneo-paper.sh quick
```

Use `quick` before performance-sensitive edits. Use `full` only when refreshing
checked performance evidence. Benchmark comparison is warning-only by default;
set `SUPERNEO_BENCHMARK_COMPARE_FAIL_ON_REGRESSION=1` only for an explicit
release or performance-investigation run.

## Coverage Map

`TestVectors/Archive/compliance/benchmark-coverage-v1.json` is an archived map
of benchmark row prefixes to:

- `Benchmarks/SuperNeoBenchmarks/SuperNeoBenchmarks.swift`
- `Scripts/render-benchmark-report.swift`
- `Scripts/compare-benchmark-results.swift`

It is not a development gate.

## Profiles

- `quick`: small CPU rows plus Metal when available.
- `scaling`: larger fold and commitment rows.
- `full`: selected proof, fold, NumiSeal, product-control, and heavier
  performance rows.

Useful filters:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m1024,m4096 Scripts/run-benchmarks.sh scaling
SUPERNEO_BENCHMARK_CE=1 Scripts/run-benchmarks.sh quick
```

## Boundaries

Benchmark reports are local measurements for investigation. They do not claim
hosted throughput, capacity planning, universal hardware performance, competitor
superiority, or release readiness. Historical same-hardware comparison material
lives under `Docs/Archive/compliance/`.
