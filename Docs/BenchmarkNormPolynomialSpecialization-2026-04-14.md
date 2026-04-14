# Sum-Check Norm Polynomial Specialization, 2026-04-14

This pass specializes evaluation of the SuperNeo profile's public norm-root
polynomial inside the sum-check Q path. It does not change the norm relation,
Fiat-Shamir transcript, challenge derivation, proof bytes, verifier acceptance
rules, Ajtai parameters, Metal kernels, or CPU/Metal equality policy.

## Finding

The implemented Goldilocks profile fixes the norm roots to `[-1, 0, 1]`, so
the norm factor is exactly:

```text
(z + 1) * z * (z - 1) = z * (z^2 - 1)
```

The prover and public verifier were still evaluating the roots through a
generic product loop. The roots are public profile parameters, so selecting a
specialized evaluator at setup time does not depend on witness values or
transcript challenges.

## Work

- Added a private norm evaluation plan derived from public profile roots.
- Specialized the default `[-1, 0, 1]` root set to `z * (z^2 - 1)`.
- Kept a generic root-product fallback for non-default parameter sets.
- Reused the same plan in the prover Q oracle and public verifier final-Q
  recomputation so both sides preserve identical algebra.
- Left `GoldilocksExt2.scaled(by:)` unchanged; adding value-based fast paths
  there would risk introducing secret-dependent branches into generic scaling
  paths.

## Measurement

Targeted Apple M4 quick slice:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```

The dirty-tree report generated on 2026-04-14T03:00:20Z recorded:

- `stage/sumcheck/m256-K2-k1-binary`: `16 ms`
- `stage/prepared/sumcheck/m256-K2-k1-binary`: `16 ms`
- `fold/cpu/m256-K2-k1-binary`: `28 ms`
- `fold/prepared/cpu/m256-K2-k1-binary`: `27 ms`

This is a correctness-preserving algebra cleanup, not a claimed aggregate
throughput win. The standard sum-check row stayed at the previous local `16 ms`
level and the prepared row moved from `15 ms` to `16 ms`, which is within the
resolution/noise of this quick aggregate slice.

## Validation

Run after this pass:

```sh
swift test --disable-swift-testing --filter ProtocolShapeTests/testSumcheckProverProofIsTranscriptAndFinalCheckBound
swift test --disable-swift-testing --filter ProtocolE2ETests/testPaperLinePiCCSPiRLCAndPiDECReferenceVectors
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
swift Scripts/validate-test-vectors.swift
Scripts/test-vector-manifest-validation.py
Scripts/production-gate.sh --skip-formal
```
