# Sum-Check Prior-Claim Evaluation Batch, 2026-04-14

This pass improves the CPU sum-check prover path for folds that carry prior CE
claims. It does not change the SuperNeo relation, Fiat-Shamir transcript,
challenge derivation, proof bytes, verifier acceptance rules, Ajtai parameters,
or CPU/Metal equality policy.

## Finding

The prover-side Q oracle evaluated each prior transformed ring row coefficient
independently. For every prior claim, matrix, suffix, and coefficient index, it
re-ran the same prefix-weighted row scan. That repeated the same row and prefix
weight traversal 54 times for each ring row.

## Work

- Replaced the per-coefficient prior evaluation helper with a batched helper
  that computes all 54 coefficient evaluations during one prefix-weighted row
  pass.
- Kept the same outer prior-claim, matrix, and coefficient recomposition order
  when adding the gamma-weighted contribution back into Q.
- Preserved constant-shape loop behavior for this helper by iterating every
  coefficient slot instead of adding zero-skipping or witness-dependent early
  exits.

## Validation

Run after this pass:

```sh
Scripts/test-slice.sh fast
swift test --disable-swift-testing --filter ProtocolE2ETests/testPaperLinePiCCSPiRLCAndPiDECReferenceVectors
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```

