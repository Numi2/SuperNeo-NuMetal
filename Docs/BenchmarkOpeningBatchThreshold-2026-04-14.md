# Opening Batch Parallel Threshold, 2026-04-14

This pass adjusts when independent CPU opening batches use the existing ordered
parallel execution path. It does not change the SuperNeo relation,
Fiat-Shamir transcript, challenge derivation, proof bytes, verifier acceptance
rules, Ajtai parameters, Metal kernels, or CPU/Metal equality policy.

## Finding

PiDEC decomposition at `m256` creates 14 independent limb openings, but the
previous CPU opening heuristic only enabled parallelism for shapes with
`m >= 1024`. On Apple M4 this left the m256 PiDEC stage mostly serialized even
though each limb opening runs the same commitment and transformed-evaluation
checks independently.

## Work

- Expanded the opening-batch heuristic to parallelize batches with at least 8
  openings when `m >= 256`.
- Preserved the existing large-shape behavior for batches with at least 4
  openings when `m >= 1024`.
- Kept `orderedParallelMap` as the execution primitive, so outputs are collected
  in the original order and verifier-facing proof data remains deterministic.
- Kept the branch based only on public shape and batch count. High-assurance
  CPU openings still use the constant-work per-opening routines selected by the
  execution policy.

## Measurement

Targeted Apple M4 quick slice:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
```

The targeted dirty-tree report generated on 2026-04-14 after this pass recorded:

| Row | Before | After |
| --- | ---: | ---: |
| `stage/piDEC/m256-K2-k1-binary` | `8.84 ms` | `2.69 ms` |
| `stage/prepared/piDEC/m256-K2-k1-binary` | `8.92 ms` | `2.67 ms` |
| `fold/prepared/cpu/m256-K2-k1-binary` | `34 ms` | `28 ms` |
| `terminalVerify/cpu/m256-K2-k1-binary` | `12 ms` | `4.82 ms` |

The Metal rows in the same targeted run varied substantially and are not used as
evidence for this CPU threshold change.

## Validation

Run after this pass:

```sh
swift test --disable-swift-testing --filter ProtocolE2ETests/testPaperLinePiCCSPiRLCAndPiDECReferenceVectors
swift test --disable-swift-testing --filter ProtocolShapeTests/testSuperNeoMatrixTransformHandlesMultipleRingColumnsAndDuplicateEntries
SUPERNEO_BENCHMARK_CASE_FILTER=m256 Scripts/run-benchmarks.sh quick
Scripts/test-slice.sh fast
Scripts/production-gate.sh
```
