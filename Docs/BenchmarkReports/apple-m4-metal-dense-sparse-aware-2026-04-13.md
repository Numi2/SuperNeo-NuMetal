# Apple M4 Metal Benchmark Report - Sparse-Aware Dense Matvec

Generated locally on 2026-04-13 after a Metal-focused benchmark pass.

## Environment

| Field | Value |
| --- | --- |
| Machine | MacBook Air |
| Chip | Apple M4 |
| CPU cores | 10 (4 performance, 6 efficiency) |
| Memory | 24 GB |
| OS | macOS 26.3, build 25D5087f |
| Xcode | Xcode 26.4, build 17E192 |
| Swift | Apple Swift 6.3, target `arm64-apple-macosx26.0` |
| Metal device | Apple M4, Metal 4 |
| Benchmark profile | `scaling` with `SUPERNEO_BENCHMARK_CASE_FILTER=m4096,m16384` |
| Source head | `8a56de5824abc6ed795bc1cfdda9cb8cfe04ab9e` with this pass dirty |

## Research Notes

The SuperNeo paper keeps the prover work centered on Ajtai commitments and the
transformed CCS matrix evaluations over the SuperNeo field-to-ring embedding.
This pass therefore treated dense transformed-matrix evaluation as a benchmark
surface, not as a cryptographic surface.

Apple's Metal guidance used for this pass:

- [Metal Feature Set Tables](https://developer.apple.com/metal/capabilities/)
  classify M4-series GPUs as Apple9 and list support for 64-bit integer math,
  nonuniform threadgroups, and SIMD-scoped reductions.
- [Persistent Objects](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/PersistentObjects.html)
  recommends creating command queues, pipelines, and reusable resources once and
  reusing them.
- [Command Buffers](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/CommandBuffers.html)
  recommends submitting as few command buffers as practical without starving the
  GPU.
- [Buffer Bindings](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/BufferBindings.html)
  recommends `setBytes` for very small dynamic data. I measured that approach
  for these kernels, but rejected it because it regressed sparse transformed
  rows in this backend.

## Accepted Change

The dense transformed-matvec benchmark receives a separate sparse-aware Metal
kernel for wide dense matrices. It first checks whether each dense ring entry is
zero before invoking the full reduced ring-product accumulation. The production
route only selects this kernel for dense transformed matrices with at least 128
ring columns; smaller dense rows stay on the original kernel.

This is a scheduling and kernel-work reduction only. It does not change the
Goldilocks arithmetic, cyclotomic relation, transformed matrix representation,
proof data, transcript binding, verifier behavior, or CPU/Metal equality gate.

## Validation

| Command | Result |
| --- | --- |
| `swift test --disable-swift-testing` | 75 XCTest cases, 0 failures |
| Metal differential test | Added a 128-column mostly-zero dense matrix case that forces the sparse-aware kernel and compares exactly against CPU `RingMatrix.multiplied(by:)` |

Benchmark rows still assert exact CPU/Metal equality before reporting timing.

## Timing

The controlled baseline below was measured by temporarily disabling the new
sparse-aware dense route (`threshold = Int.max`) and running the same dense Metal
benchmark filter on the same dirty source. The final row restores the production
threshold (`128`).

| Benchmark | Controlled baseline | Final | Change |
| --- | ---: | ---: | ---: |
| `kernel/transformedEvaluation/metalDense/m4096-K2-k0-binary` | 75 ms | 77 ms | flat |
| `kernel/transformedEvaluation/metalDense/m16384-K2-k0-binary` | 3274 ms | 1911 ms | 1.71x faster |

Focused Metal rows after the accepted change measured:

| Benchmark | Final |
| --- | ---: |
| `fold/metal/m4096-K2-k0-binary` | 111 ms |
| `fold/metal/m16384-K2-k0-binary` | 364 ms |
| `kernel/combinedCommitEval/batchWorkspace/metal/m4096-K2-k0-binary` | 44 ms |
| `kernel/combinedCommitEval/batchWorkspace/metal/m16384-K2-k0-binary` | 151 ms |

Those end-to-end and workspace rows are included as context only. The accepted
change targets dense transformed-matvec; sparse batch evaluation and Ajtai
workspace rows showed high local variance and should not be treated as changed
by this pass.

## Rejected Work

- Directly rewriting `ring_mul_kernel` to use the reduced accumulation helper
  regressed standalone Metal ring multiplication, so it was reverted.
- Switching the default Ajtai schedule to the existing tiled kernel regressed
  `m4096` Ajtai rows and was neutral at `m16384`, so the coefficient schedule
  remains the default.
- Binding dynamic `uint` parameter blocks with `setBytes` matched Apple's
  general guidance for small dynamic data, but it regressed sparse transformed
  rows in this backend. The params-buffer path remains in place.

## Notes

The large dense row is not the main production path; SuperNeo's real prover path
uses sparse transformed matrices and workspace batch buffers. This change is
kept because it improves a registered Metal benchmark without weakening the
production sparse path, and because the new route is thresholded away from small
dense matrices where the zero scan does not pay for itself.
