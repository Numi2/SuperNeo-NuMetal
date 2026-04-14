# Transformed Evaluation Fusion, 2026-04-14

This pass improves CPU transformed-evaluation paths used by PiDEC and local CE
opening checks. It does not change the SuperNeo relation, Fiat-Shamir
transcript, challenge derivation, proof bytes, verifier acceptance rules, Ajtai
parameters, Metal kernels, or CPU/Metal equality policy.

## Finding

Several CPU paths multiplied a transformed ring matrix by a packed witness,
materialized all intermediate ring rows, and then immediately scanned those rows
to compute the extension-ring multilinear evaluation. That split was simple but
forced allocation and a second row pass on paths that only need the final
evaluated extension-ring element.

## Work

- Added fused dense and sparse ring-matrix product-evaluation helpers that
  accumulate the weighted product directly into the 54 extension coefficients.
- Kept separate constant-work helpers. The high-assurance path still uses
  constant-work ring products and does not branch on product coefficient values.
- Routed CPU PiDEC, evaluation-claim opening, CE private-linear target
  construction, and `SuperNeoCPUBackend` transformed-evaluation entry points
  through the fused helpers.
- Added a focused transform test that compares dense, sparse, default,
  constant-work, and `SuperNeoCPUBackend` fused outputs against the independent
  row-evaluation oracle.

## Measurement

Targeted Apple M4 quick slice:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```

The measured `stage/piDEC/m256-K2-k1-binary` row moved from about `9.42 ms` in
the preceding dirty run to about `8.82 ms` after this pass. The
`kernel/transformedEvaluation/cpuSparse/m256-K2-k1-binary` row moved from about
`125 us` to about `116 us`. Metal rows were noisy in the same run and are not
claimed as improved by this CPU-only change.

## Validation

Run after this pass:

```sh
swift test --disable-swift-testing --filter ProtocolShapeTests/testSuperNeoMatrixTransformHandlesMultipleRingColumnsAndDuplicateEntries
swift test --disable-swift-testing --filter ProtocolE2ETests/testPaperLinePiCCSPiRLCAndPiDECReferenceVectors
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```
