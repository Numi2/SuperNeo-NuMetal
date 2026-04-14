# Benchmark Metadata Comparison, 2026-04-14

This pass hardens benchmark comparison evidence. It does not change proof
generation, transcript binding, verifier acceptance rules, Ajtai parameters,
Metal kernels, CPU arithmetic, or CPU/Metal equality policy.

## Finding

`Scripts/compare-benchmark-results.swift` thresholded timing rows but did not
compare the metadata that makes those rows interpretable. A baseline captured
under a different benchmark profile, case filter, Metal row-block size,
toolchain, OS, or hardware class could still render a timing comparison as if it
were directly comparable.

## Work

- Added optional metadata inputs to `Scripts/compare-benchmark-results.swift`:
  `--baseline-metadata`, `--candidate-metadata`, `--require-metadata`, and
  `--require-clean-metadata`.
- Added automatic sibling `metadata.json` discovery when both result files live
  beside benchmark metadata.
- Compared benchmark profile, selected cases, relevant benchmark environment
  knobs, toolchain, OS, hardware, Metal device, and Metal availability before
  accepting metadata-aware timing comparisons.
- Kept timing-only comparisons backward-compatible when metadata is absent and
  not required.
- Added a clean-source policy flag for pinned baseline gates that require
  `gitState == clean` on both sides.
- Updated `Scripts/run-benchmarks.sh` to pass baseline and candidate metadata to
  the comparator when baseline metadata is supplied or discoverable.
- Extended the benchmark tooling regression harness with metadata mismatch,
  missing-key, required-metadata, clean-state, and auto-discovery cases.

## Boundary

The comparator intentionally does not require matching git commits or full git
status text. Before/after benchmark comparisons normally change the source tree.
Pinned baseline workflows can require clean metadata to avoid accidental dirty
source claims, while still allowing intentional candidate source differences.

## Validation

Run after this pass:

```sh
Scripts/test-benchmark-tooling-validation.py
git diff --check
Scripts/production-gate.sh --skip-formal
```
