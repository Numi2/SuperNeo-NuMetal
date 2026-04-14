# Metal Performance Optimization, 2026-04-14

This pass addresses the Metal performance audit around small shapes, transformed
evaluation workspace memory, GPU timing visibility, ring multiplication shape,
and Ajtai coefficient work. It does not change the SuperNeo relation,
Fiat-Shamir transcript, proof bytes, verifier acceptance rules, parameter
profile, or CPU oracle policy.

## Research Basis

Apple's Metal guidance shaped the implementation decisions:

- Keep GPU submission overhead visible. Command buffers execute asynchronously,
  but CPU waits and host-side encoding/allocation can dominate small workloads.
- Reuse long-lived resources where possible. Buffer allocation and data upload
  should not sit in the hottest proof loops when workspace lifetime can own the
  static data.
- Size compute work around Apple GPU execution geometry. Apple documents SIMD
  groups of width 32, up to 1024 threads per threadgroup, and 32 KiB of
  threadgroup memory; reductions should use SIMD-group/threadgroup locality
  before touching main memory.
- Tune memory access to the data layout. Sparse row traversal should avoid
  repeatedly scanning the same rows when a row-block or coefficient-tile schedule
  can improve locality.

References:

- [Metal command organization and execution model](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Cmd-Submiss/Cmd-Submiss.html)
- [Metal data-parallel compute processing](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Compute-Ctx/Compute-Ctx.html)
- [Metal resource options best practices](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/ResourceOptions.html)
- [Scale compute workloads across Apple GPUs](https://developer.apple.com/la/videos/play/wwdc2022/10159/)
- [Metal feature set tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf)

## Findings

- Small shapes are not automatically GPU-shaped. The local m256 quick report
  showed forced Metal fold timing at 41 ms versus CPU at 28 ms. The default
  execution policy now routes Metal automatically only at `m >= 1024`; benchmark
  and kernel-development callers can still force Metal with
  `.metalAccelerated`.
- The transformed-evaluation workspace was uploading both per-matrix CSR buffers
  and batched CSR buffers even when normal compiled CCS shapes use the batched
  path. The workspace now builds batched buffers first and lazily materializes
  fallback per-matrix buffers only when required.
- GPU timing was captured but hidden. Benchmarks now export a
  `GPU command buffer time` metric and render a `GPU` column beside wall-clock
  time. This separates device execution time from encoding, allocation, upload,
  readback, and synchronous wait overhead.
- Standalone ring multiplication was not GPU-shaped as one thread per ring. The
  kernel now dispatches one thread per output coefficient. This improves
  parallelism, but standalone ring multiply remains launch/synchronization
  dominated on small rows and should not drive default routing decisions.
- The fused sparse transformed-evaluation kernel still repeats sparse-row
  traversal across coefficient lanes. A row-partial schedule was added behind
  environment knobs for future tuning, but it remains disabled by default after
  the local m64 A/B run showed correctness without a performance win.
- Ajtai coefficient work benefits from the decomposition message shape. A
  dedicated small-message coefficient kernel now handles scalars in
  `{0, 1, 2, -1, -2}` with add/sub/double operations and falls back to the
  generic coefficient kernel for full-width messages.

## Work Completed

- Added `SuperNeoMetalRoutingPolicy` with automatic and forced routing modes.
  `.default` uses automatic routing; `.metalAccelerated` and
  `.cpuRedundantMetal` force Metal when a context is supplied and secret-bearing
  GPU work is allowed.
- Made `SuperNeoPreparedFoldContext` and protocol workspace creation respect the
  routing policy before building Metal workspaces.
- Removed duplicate transformed matrix GPU uploads for the common batched CSR
  path.
- Added `GPU command buffer time` as a benchmark metric, rendered it in
  generated reports, and included it in `Scripts/run-benchmarks.sh`.
- Added context-owned temporary buffer reuse and inline `UInt32` parameter
  binding for hot dispatch paths.
- Reworked `ring_mul_kernel` from one thread per ring to one thread per output
  coefficient.
- Added the experimental row-partial transformed-evaluation kernels and routing
  plan.
- Added the Ajtai small-message coefficient kernel and routed standalone
  coefficient-batch commitments plus combined commit/evaluation through it when
  message words are decomposition-sized.
- Extended benchmark metadata and metadata-aware comparison to include
  `SUPERNEO_METAL_EVAL_ROW_PARTIAL_THRESHOLD` and
  `SUPERNEO_METAL_EVAL_ROW_PARTIAL_MAX_WORDS`.

## Current Policy

Default proof construction uses CPU for small shapes even if a Metal context is
available. This avoids regressions where GPU launch, allocation, and readback
costs dominate useful device work. Forced Metal rows remain in the benchmark
suite so kernel work stays measurable and CPU/Metal differential coverage stays
active.

Large-shape Metal remains the intended acceleration path. Existing scaling
evidence keeps `SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128` as the default because
it won the complete `m1024` fold path and did not materially regress the
complete `m4096` path.

The row-partial transformed-evaluation schedule is intentionally opt-in:

```sh
SUPERNEO_METAL_EVAL_ROW_PARTIAL_THRESHOLD=1024 \
SUPERNEO_METAL_EVAL_ROW_PARTIAL_MAX_WORDS=16777216 \
Scripts/run-benchmarks.sh scaling
```

Any report using those knobs must retain the generated metadata, because the
baseline comparator treats the knob values as part of the comparable hardware
and execution environment.

## Measurement

Targeted local smoke after the small-message Ajtai pass:

| Row | Wall-clock p50 | GPU p50 |
| --- | ---: | ---: |
| `kernel/ajtaiCommit/batchWorkspace/metal/m64-K1-k0-binary` | 513 us | 136 us |
| `kernel/ajtaiCommit/metal/m64-K1-k0-binary` | 389 us | 146 us |
| `kernel/combinedCommitEval/batchWorkspace/metal/m64-K1-k0-binary` | 3.394 ms | 2.693 ms |

Earlier scratch-buffer smoke for the same combined m64 workspace row measured
about 3.961 ms wall-clock and 3.322 ms GPU command-buffer time. Treat the
improvement as targeted local evidence, not a cross-hardware claim.

## Validation

Run after this pass:

```sh
swift test --disable-swift-testing
swift test -c release --disable-swift-testing --filter SuperNeo_NuMetalTests.MetalDifferentialTests
cd Benchmarks && swift build -c release
```

The full debug suite passed with 89 tests and 0 failures. The Release
Metal-differential slice passed. The benchmark package Release build passed;
only upstream `package-benchmark` deprecation warnings were emitted.

## Remaining Work

- Profile the combined commit/evaluation command stream in Instruments Metal
  System Trace to split encoding, upload, GPU execution, readback, and wait time.
- Revisit row-partial transformed evaluation on `m1024+` with GPU counters
  before enabling it by default.
- Evaluate a coefficient-tile/threadgroup reduction design for sparse
  transformed evaluation so 54 coefficient lanes do not independently rescan the
  same sparse rows.
- Evaluate a term-parallel/threadgroup-reduction Ajtai schedule for larger
  messages. The current small-message path is deliberately narrow and keyed to
  decomposition coefficients.
- Keep standalone ring multiplication on CPU by default unless a future
  coefficient-tile or NTT-style kernel proves useful after launch overhead is
  amortized.
