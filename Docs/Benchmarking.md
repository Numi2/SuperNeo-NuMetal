# SuperNeo Benchmarking

Run the quick profile before changing performance-sensitive code:

```sh
Scripts/run-benchmarks.sh quick
```

Run the full local profile on pinned Apple Silicon hardware:

```sh
Scripts/run-benchmarks.sh full
```

The runner executes the existing XCTest suite through SwiftPM first, runs the benchmarks in Release, then writes:

- `benchmark-results/metadata.json`
- `benchmark-results/report.md`
- `benchmark-results/results.json`

Benchmarks are built and run from `Benchmarks/Package.swift` with `package-benchmark`, keeping the benchmark plugin out of the main `swift test` graph. The dependency disables package-benchmark's default Jemalloc trait so the suite runs on stock macOS without `brew install jemalloc`. The script records wall-clock, total malloc count, and leaked-memory metrics, then renders a Markdown summary with proof sizes and derived folds/sec, constraints/sec, and commitments/sec where applicable. The script disables SwiftPM's command-plugin sandbox so the benchmark child process can discover the system Metal device, and passes package-directory write permission so benchmark exports can be written under `benchmark-results/`. The Xcode project remains the source of truth for app/framework development; the root `Package.swift` exists to run tests reproducibly from the command line, while the benchmark package owns benchmark-only dependencies.

Profiles:

- `quick`: `m = 64, 256`, CPU plus Metal when available.
- `scaling`: `m = 1024, 4096, 16384`, binary witnesses, CPU plus Metal when available.
- `full`: selected scaling coverage across `m = 64, 256, 1024, 4096, 16384`, fresh counts `K = 1, 2, 4, 8, 16`, prior counts `k = 0, 1, 2, 4`, and binary/ternary/small witnesses.

Metal benchmarks are registered only when `MetalExecutionContext` can create a device inside the benchmark runner process. If the runner reports Metal unavailable, CPU benchmarks still run and the existing XCTest Metal coverage remains the correctness gate for Metal kernels.

Set `SUPERNEO_BENCHMARK_CASE_FILTER` to a comma-separated list of label fragments, for example `m1024,m4096`, to isolate large scaling cases while preserving the same benchmark definitions.
For Metal row-block tuning runs, set `SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE` in the benchmark process and record the value with the generated report.

Examples:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m1024,m4096 Scripts/run-benchmarks.sh scaling
SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128 SUPERNEO_BENCHMARK_CASE_FILTER=m4096 Scripts/run-benchmarks.sh scaling
```

Benchmark groups:

- `fold/*`: end-to-end prover cost.
- `reduceFold/*`: public reduction verifier cost.
- `terminalVerify/*`: local terminal CE verification cost.
- `proofEnvelope/*`: serialization, parsing, and verification round-trip.
- `ceOpeningProof/*`: opt-in public CE opening proof verification. Enable with `SUPERNEO_BENCHMARK_CE=1`.
- `compressedEnvelope/*`: opt-in compressed public terminal envelope verification. Enable with `SUPERNEO_BENCHMARK_CE=1`.
- `stage/*`: sum-check, PiCCS, PiRLC, and PiDEC stage costs.
- `kernel/*`: field multiplication, ring multiplication, ring-scalar multiplication, multilinear evaluation, dense/sparse/batched/workspace transformed evaluation, single/batched/workspace Ajtai commitment hot paths, and combined workspace commit-plus-evaluation dispatch.

Correctness gates:

- CPU and Metal benchmark outputs are compared when both paths exist.
- Full protocol benchmarks must pass reduction and terminal verification.
- Proof envelope benchmarks must parse, round-trip, and verify.

Baseline policy:

- Store baselines per hardware class, for example `apple-m4-release`.
- Treat stable kernel regressions over 5% and full protocol regressions over 10% as failures.
- Use Instruments or `xcrun xctrace record --template 'Metal System Trace'` only after the benchmark suite identifies a hotspot.

Current Metal scaling baseline:

- `SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128` is the default. It won end-to-end at `m1024` and tied the best full-fold result at `m4096`; `256` can win isolated transformed evaluation but did not improve the complete fold path.
- Ajtai workspace batching stays at max batch size `16`. The measured b32 path was slower at `m1024` and `m16384`, including the combined commit/evaluation path.
- The combined workspace commit-plus-evaluation path is the baseline for PiCCS/PiDEC protocol measurements.

Latest local scaling snapshot:

| Case | CPU fold | Metal fold | Workspace Ajtai | Workspace transformed eval | Combined commit/eval |
| --- | ---: | ---: | ---: | ---: | ---: |
| `m1024-K2-k0-binary` | 578 ms | 74 ms | 5.64 ms | 17 ms | 17 ms |
| `m4096-K2-k0-binary` | 4.37 s | 247 ms | 12.7 ms | 50 ms | 52 ms |
| `m16384-K2-k0-binary` | 50 s | 950 ms | 21 ms | 137 ms | 180 ms |

Current CPU-path baseline:

- CPU protocol evaluation uses sparse transformed CCS matrices by default. Dense transformed matrices are retained for dense-specific benchmarks and comparisons. Benchmark fixtures use a nonzero identity-consistency relation plus an auxiliary sparse matrix so relation checks are real while sparse transformed-evaluation kernels stay covered.
- CPU PiDEC evaluates extension-ring rows by computing `rHat` once and accumulating all 54 ring coefficients in one pass.
- Local CE batch verification compiles the sparse CCS shape once and reuses transformed matrices across openings.
- Public CE proof generation and verification precompute per-opening evaluation bases, check cheap transcript digests before expensive private-linear reconstruction, chunk prover private-linear work across Stern rounds, and batch verifier challenge-0/1 private-linear jobs after the transcript scan. CPU CE batches fuse each opening's commitment and transformed evaluations in one parallel pass; provers and verifiers with a Metal context route same-point CE batches through the combined workspace commit-plus-evaluation path.
- CPU Ajtai commitment uses a fused coefficient-buffer matvec for the reference path.

Latest CPU-path audit snapshot, measured locally on 2026-04-12:

| Case | Previous baseline | Current baseline | Change |
| --- | ---: | ---: | ---: |
| `fold/cpu/m64` | 25 ms | 16 ms | 1.56x faster |
| `stage/piCCSClaims/m64` | 2.61 ms | 0.925 ms | 2.82x faster |
| `stage/piDEC/m64` | 17 ms | 10.068 ms | 1.69x faster |
| `terminalVerify/cpu/m64` | 23 ms | 12 ms | 1.92x faster |
| `ajtaiCommit/cpu/m64` | 173 us | 137 us | 1.26x faster |
| `fold/cpu/m1024` | 595 ms | 237 ms | 2.51x faster |
| `stage/piCCSClaims/m1024` | 99 ms | 27 ms | 3.67x faster |
| `stage/piDEC/m1024` | 449 ms | 174 ms | 2.58x faster |
| `terminalVerify/cpu/m1024` | 520 ms | 189 ms | 2.75x faster |
| `proofEnvelope/roundTrip/m1024` | 504 ms | 148 ms | 3.41x faster |
| `ajtaiCommit/cpu/m1024` | 3.38 ms | 2.876 ms | 1.18x faster |
| `ajtaiCommit/batch/cpu/m1024` | 43 ms | 37 ms | 1.16x faster |
| `compressed public XCTest` | 317 s | 61.009 s | 5.20x faster |

The full XCTest slice still includes a deliberately heavy compressed-envelope path. Before CE proof optimization, `testCompressedPublicEnvelopeRoundTripsAndBindsPublicInputs` passed but took 317 s. After per-opening target caching, cheap digest prechecks, chunked prover private-linear batches, and batched verifier private-linear reconstruction, the same test passed locally on 2026-04-12 in 61.009 s. Future CE work should compare the opt-in `ceOpeningProof/verify/*` and `compressedEnvelope/verify/*` benchmarks with that end-to-end test.

Measured row-block tuning notes:

- `m1024`: row block 128 gave the best complete Metal fold at 74 ms. Row block 256 improved isolated combined/eval timing but regressed complete fold timing to 98 ms.
- `m4096`: row blocks 128 and 256 were effectively tied for complete Metal fold timing at 247 ms and 246 ms respectively; 128 remains the default because it is stronger at `m1024` and does not materially regress `m4096`.
- `m16384`: row block 128 completed the full-profile scaling run with Metal fold at 950 ms versus CPU fold at 50 s.

CI:

- `.github/workflows/superneo-benchmarks.yml` runs the quick profile on macOS and uploads `benchmark-results`.
- Add hardware-class baselines before enabling threshold failures in CI; otherwise public macOS runner variance will produce noisy failures.
