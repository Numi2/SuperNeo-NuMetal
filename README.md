# SuperNeo NuMetal

Swift package implementing the SuperNeo lattice folding protocol (CCS, sum-check, commitments, optional Metal kernels). Targets macOS 14+.

## Tests

Quick inner loop:

```sh
Scripts/test-slice.sh fast
```

Full suite (CPU-heavy; may take on the order of a minute):

```sh
Scripts/test-slice.sh all
```

Direct SwiftPM (XCTest only; skips the unused Swift Testing harness):

```sh
swift test --disable-swift-testing
```

**Details:** test slices, class-to-filter mapping, `swift test` troubleshooting (SwiftPM lock, long runs, `--scratch-path`), and forwarding extra arguments are documented in [SuperNeo-NuMetalTests/README.md](SuperNeo-NuMetalTests/README.md).

## Benchmarks

Run the quick benchmark profile before changing performance-sensitive code:

```sh
Scripts/run-benchmarks.sh quick
```

Run the larger scaling profile when touching Metal kernels, sparse transformed evaluation, Ajtai commitments, or protocol batching:

```sh
Scripts/run-benchmarks.sh scaling
```

Run the full local profile on pinned Apple Silicon hardware only:

```sh
Scripts/run-benchmarks.sh full
```

The benchmark runner executes the XCTest gate first, builds the benchmark package in Release, and writes:

- `benchmark-results/metadata.json`
- `benchmark-results/report.md`
- `benchmark-results/results.json`

Profiles:

- `quick`: `m = 64, 256`, CPU plus Metal when available.
- `scaling`: `m = 1024, 4096, 16384`, binary witnesses, CPU plus Metal when available.
- `full`: selected coverage across `m = 64, 256, 1024, 4096, 16384`, fresh counts `K = 1, 2, 4, 8, 16`, prior counts `k = 0, 1, 2, 4`, and binary/ternary/small witnesses.

To isolate large cases without changing benchmark definitions:

```sh
SUPERNEO_BENCHMARK_CASE_FILTER=m1024,m4096 Scripts/run-benchmarks.sh scaling
```

For Metal transformed-evaluation row-block tuning:

```sh
SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128 SUPERNEO_BENCHMARK_CASE_FILTER=m4096 Scripts/run-benchmarks.sh scaling
```

Benchmark groups:

- `fold/*`: end-to-end prover cost.
- `reduceFold/*`: public reduction verifier cost.
- `terminalVerify/*`: local terminal CE verification cost.
- `proofEnvelope/*`: serialization, parsing, and verification round-trip.
- `stage/*`: sum-check, PiCCS, PiRLC, and PiDEC stage costs.
- `kernel/*`: field/ring kernels, transformed evaluation, Ajtai commitment, and combined workspace commit-plus-evaluation hot paths.

Current Metal tuning baseline:

- `SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=128` is the default. It won end-to-end at `m1024` and tied the best full-fold result at `m4096`.
- Ajtai workspace batching stays at max batch size `16`; b32 was slower in the measured scaling profile.
- The combined workspace commit-plus-evaluation path is the protocol baseline for PiCCS/PiDEC.

Latest local scaling snapshot:

| Case | CPU fold | Metal fold | Workspace Ajtai | Workspace transformed eval | Combined commit/eval |
| --- | ---: | ---: | ---: | ---: | ---: |
| `m1024-K2-k0-binary` | 578 ms | 74 ms | 5.64 ms | 17 ms | 17 ms |
| `m4096-K2-k0-binary` | 4.37 s | 247 ms | 12.7 ms | 50 ms | 52 ms |
| `m16384-K2-k0-binary` | 50 s | 950 ms | 21 ms | 137 ms | 180 ms |

Detailed benchmark policy, correctness gates, CI notes, and runner implementation details are in [Docs/Benchmarking.md](Docs/Benchmarking.md).
