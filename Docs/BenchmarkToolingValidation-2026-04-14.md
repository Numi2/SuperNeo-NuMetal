# Benchmark Tooling Validation, 2026-04-14

This pass hardens the benchmark evidence pipeline rather than cryptographic
arithmetic. It does not change proof generation, transcript binding, verifier
acceptance rules, Ajtai parameters, Metal kernels, or CPU/Metal equality policy.

## Finding

The benchmark comparator and report renderer are part of the repository's
performance-claim trust boundary. The runner already invokes them, and the docs
describe their failure modes, but there was no dedicated mutation harness for
the comparator and only historical manual coverage for malformed report-input
handling. That left room for future edits to accidentally turn missing rows,
duplicate timing rows, unsupported units, or threshold regressions into silent
benchmark evidence drift.

## Work

- Added `Scripts/test-benchmark-tooling-validation.py`.
- Covered benchmark comparator pass/fail behavior for kernel and protocol
  thresholds.
- Covered `--warn-only` and `--allow-missing` behavior so targeted local runs
  remain explicit and auditable.
- Added negative fixtures for missing rows, no overlapping rows, duplicate
  wall-clock rows, and unsupported time units.
- Added report-renderer checks for preserving existing metadata, writing timing
  rows, deriving fold/constraint and commitment rates, carrying p95 and malloc
  columns, and failing closed on malformed or timing-free result JSON.
- Wired the harness into `Scripts/production-gate.sh`.

## Validation

Run after this pass:

```sh
Scripts/test-benchmark-tooling-validation.py
git diff --check
Scripts/production-gate.sh --skip-formal
```
