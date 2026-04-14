# SuperNeo Benchmarking

Run the quick profile before changing performance-sensitive code:

```sh
Scripts/run-benchmarks.sh quick
```

To produce a paper-claim reproduction artifact that includes benchmark outputs,
test-vector checks, command logs, and a claim map, run:

```sh
Scripts/reproduce-superneo-paper.sh quick
```

The artifact format is documented in
[PaperReproduction.md](PaperReproduction.md).

Run the full local profile on pinned Apple Silicon hardware:

```sh
Scripts/run-benchmarks.sh full
```

The runner executes the existing XCTest suite through SwiftPM first, runs the benchmarks in Release, then writes:

- `benchmark-results/metadata.json`
- `benchmark-results/report.md`
- `benchmark-results/results.json`

The runner deletes stale root and benchmark-package artifacts before each run,
requires a fresh non-empty `Current_run.json` from the benchmark plugin, and
refuses to render a report if metadata or the base report was not regenerated.
The report renderer fails on malformed result JSON and on result files without
wall-clock rows, so benchmark reports should not silently fall back to stale or
empty evidence.

Benchmarks are built and run from `Benchmarks/Package.swift` with `package-benchmark`, keeping the benchmark plugin out of the main `swift test` graph. The dependency disables package-benchmark's default Jemalloc trait so the suite runs on stock macOS without `brew install jemalloc`. The script records wall-clock, total malloc count, and leaked-memory metrics, then renders a Markdown summary with proof sizes and derived folds/sec, constraints/sec, and commitments/sec where applicable. The script disables SwiftPM's command-plugin sandbox so the benchmark child process can discover the system Metal device, and passes package-directory write permission so benchmark exports can be written under `benchmark-results/`. The Xcode project remains the source of truth for app/framework development; the root `Package.swift` exists to run tests reproducibly from the command line, while the benchmark package owns benchmark-only dependencies.

Profiles:

- `quick`: `m = 64, 256`, CPU plus Metal when available.
- `scaling`: `m = 1024, 4096, 16384`, binary witnesses, CPU plus Metal when available.
- `full`: selected scaling coverage across `m = 64, 256, 1024, 4096, 16384`, fresh counts `K = 1, 2, 4, 8, 16`, prior counts `k = 0, 1, 2, 4`, and binary/ternary/small witnesses.

Metal benchmarks are registered only when `MetalExecutionContext` can create a device inside the benchmark runner process. If the runner reports Metal unavailable, CPU benchmarks still run and the existing XCTest Metal coverage remains the correctness gate for Metal kernels.

Set `SUPERNEO_BENCHMARK_CASE_FILTER` to a comma-separated list of label fragments, for example `m1024,m4096`, to isolate large scaling cases while preserving the same benchmark definitions.
For Metal row-block tuning runs, set `SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE` in the benchmark process and record the value with the generated report.
When `SUPERNEO_BENCHMARK_CE=1` is set, CE proof and compressed-envelope
benchmarks are registered for every selected fixture after case filtering. Use
`SUPERNEO_BENCHMARK_CASE_FILTER` for targeted CE runs on large profiles; CE
proof generation and verification are intentionally much heavier than fold-only
rows.

Examples:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m1024,m4096 Scripts/run-benchmarks.sh scaling
SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128 SUPERNEO_BENCHMARK_CASE_FILTER=m4096 Scripts/run-benchmarks.sh scaling
```

Benchmark groups:

- `fold/cpu/*` and `fold/metal/*`: cold end-to-end prover cost, including
  per-call sparse CCS compilation and Metal workspace construction when a Metal
  context is supplied.
- `fold/prepared/*`: steady-state end-to-end prover cost using an explicit
  `SuperNeoPreparedFoldContext` prepared during benchmark setup. The prepared
  context reuses the transformed sparse CCS shape and, on Metal rows, the bound
  `SuperNeoMetalWorkspace`; each proof call still validates the context against
  the prover profile, shape digest, verifier key digest, execution policy, and
  Metal execution context before use.
- `reduceFold/*`: public reduction verifier cost.
- `terminalVerify/*`: local terminal CE verification cost.
- `proofEnvelope/*`: serialization, parsing, and verification round-trip.
- `ceOpeningProof/*`: opt-in public CE opening proof proving and verification. Enable with `SUPERNEO_BENCHMARK_CE=1`.
- `compressedEnvelope/*`: opt-in compressed public terminal envelope proving and verification. Enable with `SUPERNEO_BENCHMARK_CE=1`.
- `stage/*`: sum-check, PiCCS, PiRLC, and PiDEC stage costs. Rows under
  `stage/prepared/*` use the same prepared-context lifetime split as
  `fold/prepared/*`.
- `kernel/*`: field multiplication, ring multiplication, ring-scalar multiplication, multilinear evaluation, dense/sparse/batched/workspace transformed evaluation, single/batched/workspace Ajtai commitment hot paths, and combined workspace commit-plus-evaluation dispatch.

Correctness gates:

- CPU and Metal benchmark outputs are compared when both paths exist.
- Full protocol benchmarks must pass reduction and terminal verification.
- Proof envelope benchmarks must parse, round-trip, and verify.

Baseline policy:

- Store baselines per hardware class, for example `apple-m4-release`.
- Treat stable kernel regressions over 5% and full protocol regressions over 10% as failures.
- Use the comparator to enforce those thresholds on matching benchmark JSON
  artifacts:

```sh
swift Scripts/compare-benchmark-results.swift \
  path/to/baseline-results.json \
  benchmark-results/results.json \
  --baseline-metadata path/to/baseline-metadata.json \
  --candidate-metadata benchmark-results/metadata.json \
  --output benchmark-results/comparison.md
```

- `Scripts/run-benchmarks.sh` runs the same comparison automatically when
  `SUPERNEO_BENCHMARK_BASELINE` points to a baseline `results.json`. Optional
  controls are `SUPERNEO_BENCHMARK_KERNEL_THRESHOLD`,
  `SUPERNEO_BENCHMARK_PROTOCOL_THRESHOLD`,
  `SUPERNEO_BENCHMARK_COMPARE_WARN_ONLY=1`, and
  `SUPERNEO_BENCHMARK_COMPARE_ALLOW_MISSING=1`.
- Benchmark comparison is metadata-aware when `--baseline-metadata` and
  `--candidate-metadata` are passed, or when both `results.json` files have
  sibling `metadata.json` files. The comparator checks benchmark profile,
  selected cases, relevant benchmark environment knobs, toolchain, OS, hardware,
  Metal device, and Metal availability. Set
  `SUPERNEO_BENCHMARK_BASELINE_METADATA` to pass a baseline metadata file
  explicitly through `Scripts/run-benchmarks.sh`.
- Set `SUPERNEO_BENCHMARK_REQUIRE_METADATA=1` for pinned baseline gates that
  must fail instead of falling back to timing-only comparison, and
  `SUPERNEO_BENCHMARK_REQUIRE_CLEAN_METADATA=1` when both sides must report
  `gitState == clean`.
- Missing candidate rows are failures by default, because deleted benchmark
  coverage can otherwise hide regressions. Use allow-missing only for targeted
  local runs where the selected case set is intentionally narrower than the
  baseline.
- `Scripts/test-benchmark-tooling-validation.py` mutation-tests the benchmark
  comparator and Markdown report renderer so malformed result JSON, unsupported
  units, duplicate wall-clock rows, missing rows, and threshold regressions keep
  failing closed.
- Use Instruments or `xcrun xctrace record --template 'Metal System Trace'` only after the benchmark suite identifies a hotspot.

Hardware-class reports:

- [Apple M4 quick profile, 2026-04-12](BenchmarkReports/apple-m4-quick-2026-04-12.md)
- [Apple M4 exact-arithmetic quick profile, 2026-04-12](BenchmarkReports/apple-m4-quick-exact-arithmetic-2026-04-12.md)
- [Apple M4 CSR transform and CE batch quick profile, 2026-04-12](BenchmarkReports/apple-m4-quick-csr-ce-batch-2026-04-12.md)
- [Apple M4 scalar, transcript, and sumcheck quick profile, 2026-04-13](BenchmarkReports/apple-m4-quick-scalar-transcript-sumcheck-2026-04-13.md)
- [Apple M4 scaling parallel-opening and small-coefficient pass, 2026-04-13](BenchmarkReports/apple-m4-scaling-opening-smallcoeff-2026-04-13.md)
- [Apple M4 Metal sparse-aware dense matvec pass, 2026-04-13](BenchmarkReports/apple-m4-metal-dense-sparse-aware-2026-04-13.md)
- [Apple M4 prepared-context quick profile, 2026-04-13](BenchmarkReports/apple-m4-prepared-context-2026-04-13.md)
- [Lead audit, 2026-04-12](LeadAudit-2026-04-12.md)

Add one report per Apple Silicon generation before making generation-to-generation
claims. Each report must record chip, model, OS build, Xcode, Swift, Metal
device, benchmark profile, source commit, environment variables, proof sizes,
and the timing rows used in README or release claims.

Generated metadata records the repository root, short and full commit hash,
clean/dirty source state, selected benchmark profile, selected cases, and the
benchmark environment variables that alter registration or execution, including
`SUPERNEO_BENCHMARK_CASE_FILTER`, `SUPERNEO_BENCHMARK_CE`,
`SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE`, benchmark-baseline comparison path,
baseline metadata path, metadata requirement controls, thresholds, and
comparison failure-mode controls.

Current Metal scaling baseline:

- `SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128` is the default. It won end-to-end at `m1024` and tied the best full-fold result at `m4096`; `256` can win isolated transformed evaluation but did not improve the complete fold path.
- Ajtai workspace batching stays at max batch size `16`. The measured b32 path was slower at `m1024` and `m16384`, including the combined commit/evaluation path.
- The combined workspace commit-plus-evaluation path is the baseline for PiCCS/PiDEC protocol measurements.

Latest local scaling snapshot:

Rows use the earliest matching local scaling artifact as the starting point,
then the measured row-block tuning passes. The selected/current column is the
documented baseline, not necessarily the fastest isolated microbenchmark.

| Case / metric | Starting scaling | Row block 128 | Row block 256 | Selected/current | Notes |
| --- | ---: | ---: | ---: | ---: | --- |
| `m1024 CPU fold` | 595 ms | 578 ms | 577 ms | 578 ms | CPU variance across tuning runs |
| `m1024 Metal fold` | 87 ms | 74 ms | 98 ms | 74 ms | row block 128 wins complete fold |
| `m1024 workspace Ajtai` | 4.74 ms | 5.64 ms | 5.29 ms | 5.64 ms | selected with row block 128 baseline |
| `m1024 workspace transformed eval` | 13 ms | 17 ms | 14 ms | 17 ms | isolated row differs from complete fold winner |
| `m1024 combined commit/eval` | 14 ms | 17 ms | 15 ms | 17 ms | isolated row differs from complete fold winner |
| `m4096 CPU fold` | - | 4.37 s | 4.40 s | 4.37 s | first recorded during row-block tuning |
| `m4096 Metal fold` | - | 247 ms | 246 ms | 247 ms | effectively tied; 128 remains default from m1024 |
| `m4096 workspace Ajtai` | - | 12.7 ms | 19.0 ms | 12.7 ms | row block 128 baseline |
| `m4096 workspace transformed eval` | - | 50 ms | 45 ms | 50 ms | row block 256 wins isolated eval only |
| `m4096 combined commit/eval` | - | 52 ms | 50 ms | 52 ms | row block 256 wins isolated combined row only |
| `m16384 CPU fold` | - | 50 s | - | 50 s | first recorded in row-block 128 scaling run |
| `m16384 Metal fold` | - | 950 ms | - | 950 ms | row block 128 completed full-profile scaling |
| `m16384 workspace Ajtai` | - | 21 ms | - | 21 ms | row block 128 scaling run |
| `m16384 workspace transformed eval` | - | 137 ms | - | 137 ms | row block 128 scaling run |
| `m16384 combined commit/eval` | - | 180 ms | - | 180 ms | row block 128 scaling run |

Current CPU-path baseline:

- CPU protocol evaluation uses sparse transformed CCS matrices by default. Dense transformed matrices are retained for dense-specific benchmarks and comparisons. Benchmark fixtures use a nonzero identity-consistency relation plus an auxiliary sparse matrix so relation checks are real while sparse transformed-evaluation kernels stay covered.
- CSR field-matrix multiplication runs directly from canonical CSR storage. The
  multilinear evaluation kernel and multilinear basis generator also fold and
  expand layers in place, so CPU kernel rows avoid entry-list reconstruction and
  per-round layer allocation.
- CPU transformed evaluation skips zero row coefficients before extension-field
  scaling, preserving the coefficient-first accumulation order while respecting
  sparse transformed-row structure.
- Goldilocks field multiplication uses the modulus identity `2^64 == 2^32 - 1 mod p` directly instead of a generic 128-bit modulus loop. Field operators return canonical raw values without re-entering public normalization when the result is already known to be canonical.
- `GoldilocksExt2` multiplication uses the three-multiply Karatsuba identity, and CPU row-evaluation paths scale extension elements by base-field coefficients directly instead of promoting the scalar into a full extension multiply.
- `CyclotomicRing54` multiplication and base-ring-by-extension-ring multiplication accumulate directly into the 54 reduced output coefficients using `X^54 = -X^27 - 1`, avoiding the temporary 107-coefficient product and second reduction pass. Fixed-degree ring add/sub/scale paths also avoid map/zip allocation churn.
- Ring products whose coefficients are all in `{0, +/-1, +/-2}` use exact
  add/sub/double coefficient scaling after a per-ring small-coefficient scan.
  Generic ring products stay on the full-width Goldilocks multiplication loop.
- CPU transformed-evaluation paths can fuse sparse/dense ring matrix products
  with the multilinear extension-ring accumulation, avoiding intermediate row
  materialization when PiDEC and local CE checks only need the evaluated
  extension-ring element. The high-assurance route keeps a separate
  constant-work fused helper.
- CPU PiDEC computes `rHat` once per point and accumulates all 54 extension-ring
  coefficients in one pass.
- CPU PiDEC and terminal CE opening verification parallelize independent opening
  batches with ordered result collection. The current gate admits `m256`
  decomposition-sized batches with at least 8 openings while preserving the
  existing large-shape gate for batches with at least 4 openings at `m >= 1024`;
  smaller smoke-profile cases stay sequential.
- Metal dense transformed matvec uses a sparse-aware kernel for wide dense
  matrices (`columns >= 128`) so registered dense benchmark rows avoid full
  ring-product work on zero dense entries. Sparse workspace paths remain the
  production path for prover-scale transformed evaluations.
- CPU sum-check factors equality products into fixed-prefix and Boolean-suffix
  components instead of rebuilding full points and recomputing complete equality
  polynomials for every suffix. PiDEC verifier recomposition uses base-field
  scalar powers directly, and protocol extension-row evaluation skips zero
  coefficients before extension-field scaling.
- CPU sum-check builds relation evaluation plans from the public serialized CCS
  relation. The prover source plan precomputes fresh matrix rows only for
  live relation sources, merges exact-equal public CSR matrices, and cancels
  terms after public source aliasing. Public verifier final-Q checks still
  evaluate the original relation over proof-claim variables.
- Sum-check prior-claim evaluation computes all 54 coefficients of a
  prefix-weighted transformed ring row in one pass instead of rescanning the same
  prefix row once per coefficient. The recomposition order and transcript inputs
  are unchanged.
- Sum-check public and shape-derived work precomputes Boolean-suffix equality
  weights per fixed prefix and caches the fixed Q-polynomial interpolation
  basis. The default public norm-root polynomial `[-1, 0, 1]` is evaluated as
  `z * (z^2 - 1)` through a setup-time plan, with the generic root-product path
  retained for non-default parameters. The latest targeted `m256` report
  generated on 2026-04-14T03:00:20Z recorded `16 ms` for standard sum-check
  and `16 ms` for prepared sum-check; this pass is not an aggregate throughput
  claim.
- Local CE batch verification compiles the sparse CCS shape once and reuses transformed matrices across openings.
- Fold benchmarks now expose both cold and prepared lifetimes. The cold
  `fold/cpu/*` and `fold/metal/*` rows continue to represent the compatibility
  API. The `fold/prepared/*` and `stage/prepared/*` rows move transformed sparse
  matrix compilation and Metal workspace allocation into benchmark setup, so
  repeated-proof runs measure transcript, sum-check, PiCCS, PiRLC, PiDEC, and
  backend kernel work without hiding setup churn in each iteration.
- `stage/piRLC/*` rows prepare and validate the post-sum-check transcript during
  benchmark setup, then measure only PiCCS claim absorption, challenge-ring
  derivation, and random-linear-combination arithmetic. The older SPI helpers
  remain available for integration-style timing but no longer define the stage
  row boundary.
- Public CE proof generation and verification precompute per-opening evaluation bases, check cheap transcript digests before expensive private-linear reconstruction, chunk prover private-linear work across Stern rounds, and batch verifier challenge-0/1 private-linear jobs after the transcript scan. CPU CE batches fuse each opening's commitment and transformed evaluations in one parallel pass; provers and verifiers with a Metal context route same-point CE batches through the combined workspace commit-plus-evaluation path.
- CPU Ajtai commitment uses a fused coefficient-buffer matvec for the reference path.

Latest exact-arithmetic quick snapshot, measured locally on 2026-04-12:

| Case | Previous local quick | Exact-arithmetic quick | Change |
| --- | ---: | ---: | ---: |
| `fold/cpu/m64` | 47 ms | 5.27 ms | 8.91x faster |
| `fold/cpu/m256` | 366 ms | 41 ms | 8.93x faster |
| `fold/metal/m64` | 26 ms | 12.5 ms | 2.08x faster |
| `fold/metal/m256` | 245 ms | 60 ms | 4.08x faster |
| `terminalVerify/cpu/m64` | 47 ms | 5.19 ms | 9.06x faster |
| `terminalVerify/cpu/m256` | 205 ms | 20 ms | 10.25x faster |
| `proofEnvelope/roundTrip/m64` | 64 ms | 8.94 ms | 7.16x faster |
| `proofEnvelope/roundTrip/m256` | 179 ms | 24 ms | 7.46x faster |
| `stage/piCCSClaims/m64` | 5.08 ms | 1.34 ms | 3.79x faster |
| `stage/piDEC/m64` | 36 ms | 3.35 ms | 10.75x faster |
| `kernel/transformedEvaluation/cpuSparse/m64` | 583 us | 40 us | 14.58x faster |

The exact-arithmetic snapshot did not change parameters, transcript binding,
serialization, verifier acceptance, Ajtai key material, or CPU/Metal equality
requirements. Validation for this pass included `Scripts/run-benchmarks.sh quick`
with 69 XCTest cases, `swift Scripts/validate-test-vectors.swift`, seeded
equivalence checks against the previous field reduction/addition formulas,
seeded extension-field equivalence checks for the Karatsuba formula, and quick
benchmark correctness gates.

Latest CSR transform and CE batch quick snapshot, measured locally on
2026-04-12:

| Case | Previous local quick | CSR/CE batch quick | Change |
| --- | ---: | ---: | ---: |
| `fold/cpu/m64` | 5.465 ms | 4.349 ms | 1.26x faster |
| `fold/cpu/m256` | 42 ms | 38 ms | 1.11x faster |
| `fold/metal/m64` | 19 ms | 14.29 ms | 1.33x faster |
| `fold/metal/m256` | 69 ms | 63 ms | 1.10x faster |
| `stage/sumcheck/m64` | 1.848 ms | 0.302 ms | 6.12x faster |
| `stage/piCCSClaims/m64` | 1.509 ms | 0.337 ms | 4.48x faster |
| `stage/piRLC/m64` | 2.086 ms | 1.016 ms | 2.05x faster |
| `stage/piDEC/m64` | 3.686 ms | 2.302 ms | 1.60x faster |
| `terminalVerify/cpu/m64` | 5.434 ms | 3.299 ms | 1.65x faster |
| `terminalVerify/cpu/m256` | 20 ms | 13 ms | 1.54x faster |
| `proofEnvelope/roundTrip/m64` | 9.135 ms | 6.744 ms | 1.35x faster |
| `proofEnvelope/roundTrip/m256` | 25 ms | 17 ms | 1.47x faster |

This pass did not change proof parameters, transcript binding, serialization,
verifier acceptance, Ajtai key material, or CPU/Metal equality requirements.
Validation included `Scripts/run-benchmarks.sh quick` with 71 XCTest cases,
`swift Scripts/validate-test-vectors.swift`, an independent CSR transform
oracle test, and seeded checks for the optimized multilinear equality formula.

Latest CPU-path audit snapshot, measured locally on 2026-04-12:

Rows use the earliest local measurement recorded for that case, then the
CPU-path audit result when that pass measured it, then the exact-arithmetic
quick result when the quick profile includes that case.

| Case | Starting point | CPU-path audit | Exact arithmetic quick | Notes |
| --- | ---: | ---: | ---: | --- |
| `fold/cpu/m64` | 25 ms | 16 ms | 5.27 ms | sparse transformed protocol path, then exact field and ring arithmetic |
| `stage/piCCSClaims/m64` | 2.61 ms | 0.925 ms | 1.34 ms | sparse transformed evaluation; exact quick result remains faster than the starting point |
| `stage/piDEC/m64` | 17 ms | 10.068 ms | 3.35 ms | single-pass extension-ring row evaluation plus exact base-scalar extension scaling |
| `terminalVerify/cpu/m64` | 23 ms | 12 ms | 5.19 ms | reused sparse CE verification matrices plus exact arithmetic |
| `proofEnvelope/roundTrip/m64` | 64 ms | - | 8.94 ms | exact arithmetic quick profile |
| `ajtaiCommit/cpu/m64` | 173 us | 137 us | 63 us | fused CPU Ajtai matvec plus lower exact-ring cost |
| `fold/cpu/m256` | 366 ms | - | 41 ms | exact arithmetic quick profile |
| `terminalVerify/cpu/m256` | 205 ms | - | 20 ms | exact arithmetic quick profile |
| `proofEnvelope/roundTrip/m256` | 179 ms | - | 24 ms | exact arithmetic quick profile |
| `fold/cpu/m1024` | 595 ms | 237 ms | - | not part of the exact-arithmetic quick profile |
| `stage/piCCSClaims/m1024` | 99 ms | 27 ms | - | not part of the exact-arithmetic quick profile |
| `stage/piDEC/m1024` | 449 ms | 174 ms | - | not part of the exact-arithmetic quick profile |
| `terminalVerify/cpu/m1024` | 520 ms | 189 ms | - | not part of the exact-arithmetic quick profile |
| `proofEnvelope/roundTrip/m1024` | 504 ms | 148 ms | - | not part of the exact-arithmetic quick profile |
| `compressed public XCTest` | 317 s | 61.009 s | - | cached CE targets plus chunked prover and batched verifier private-linear work |
| `ceOpeningProof/*` | opt-in | opt-in | - | opt-in CE proof prove/verify targets, including Metal prove/verify when available |
| `ajtaiCommit/cpu/m1024` | 3.38 ms | 2.876 ms | - | not part of the exact-arithmetic quick profile |
| `ajtaiCommit/batch/cpu/m1024` | 43 ms | 37 ms | - | not part of the exact-arithmetic quick profile |

The full XCTest slice still includes a deliberately heavy compressed-envelope path. Before CE proof optimization, `testCompressedPublicEnvelopeRoundTripsAndBindsPublicInputs` passed but took 317 s. After per-opening target caching, cheap digest prechecks, chunked prover private-linear batches, and batched verifier private-linear reconstruction, the same test passed locally on 2026-04-12 in 61.009 s. Future CE work should compare the opt-in `ceOpeningProof/verify/*` and `compressedEnvelope/verify/*` benchmarks with that end-to-end test.

Latest CE quick evidence, measured locally on 2026-04-12 with
`SUPERNEO_BENCHMARK_CE=1 Scripts/run-benchmarks.sh quick`:

| Case | CE prove CPU | CE prove Metal | CE verify CPU | CE verify Metal | Compressed prove CPU | Compressed verify CPU |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K1-k0-binary` | 725 ms | 1067 ms | 479 ms | 649 ms | 784 ms | 542 ms |
| `m256-K2-k1-binary` | 2563 ms | 4367 ms | 1849 ms | 3077 ms | 2808 ms | 1969 ms |

The same run measured `compressedEnvelope/prove/metal` at 1080 ms for `m64`
and 4539 ms for `m256`, and `compressedEnvelope/verify/metal` at 732 ms for
`m64` and 3158 ms for `m256`. On these quick-profile cases, the Metal CE path
is slower than CPU because launch and batching overhead dominate; treat those
rows as coverage and hotspot direction, not an acceleration claim.

Measured row-block tuning notes:

- `m1024`: row block 128 gave the best complete Metal fold at 74 ms. Row block 256 improved isolated combined/eval timing but regressed complete fold timing to 98 ms.
- `m4096`: row blocks 128 and 256 were effectively tied for complete Metal fold timing at 247 ms and 246 ms respectively; 128 remains the default because it is stronger at `m1024` and does not materially regress `m4096`.
- `m16384`: row block 128 completed the full-profile scaling run with Metal fold at 950 ms versus CPU fold at 50 s.

Latest scaling CPU pass, measured locally on 2026-04-13:

| Case | Starting row | Final row | Change |
| --- | ---: | ---: | ---: |
| `fold/cpu/m4096-K2-k0-binary` | 202 ms | 174 ms | 1.16x faster |
| `terminalVerify/cpu/m4096-K2-k0-binary` | 144 ms | 113 ms | 1.27x faster |
| `proofEnvelope/roundTrip/m4096-K2-k0-binary` | 157 ms | 119 ms | 1.32x faster |
| `stage/piDEC/m4096-K2-k0-binary` | 137 ms | 106 ms | 1.29x faster |
| `fold/cpu/m16384-K2-k0-binary` | 796 ms | 686 ms | 1.16x faster |
| `terminalVerify/cpu/m16384-K2-k0-binary` | 572 ms | 428 ms | 1.34x faster |
| `proofEnvelope/roundTrip/m16384-K2-k0-binary` | 765 ms | 431 ms | 1.78x faster |
| `stage/piDEC/m16384-K2-k0-binary` | 589 ms | 411 ms | 1.43x faster |

This pass parallelized independent large CPU opening batches and added exact
small-coefficient ring arithmetic. It did not change the cryptographic profile,
transcript binding, serialization, verifier acceptance rules, or Metal
determinism requirements. A PiRLC ring-column parallelization experiment was
rejected after it regressed `m16384 stage/piRLC`.

Latest Metal dense-matvec pass, measured locally on 2026-04-13:

| Case | Controlled baseline | Final row | Change |
| --- | ---: | ---: | ---: |
| `kernel/transformedEvaluation/metalDense/m4096-K2-k0-binary` | 75 ms | 77 ms | flat |
| `kernel/transformedEvaluation/metalDense/m16384-K2-k0-binary` | 3274 ms | 1911 ms | 1.71x faster |

This pass added a thresholded sparse-aware dense Metal kernel. The route is
intentionally limited to wide dense matrices because the zero scan does not pay
for itself on smaller dense rows. Direct Metal ring-multiply rewriting, tiled
Ajtai as the default schedule, and `setBytes` parameter binding were measured
and rejected after regressions in targeted rows.

CI:

- `.github/workflows/superneo-benchmarks.yml` runs the quick profile on macOS and uploads `benchmark-results`.
- Add hardware-class baselines before enabling threshold failures in CI; otherwise public macOS runner variance will produce noisy failures.
- Until a pinned runner class has a stable baseline, CI can set
  `SUPERNEO_BENCHMARK_COMPARE_WARN_ONLY=1` to upload `comparison.md` without
  blocking unrelated pull requests.
