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
- `full`: selected scaling coverage across `m = 64, 256, 1024, 4096, 16384`, fresh counts `K = 1, 2, 4, 8, 16`, prior counts `k = 0, 1, 2, 4`, and binary/ternary/small witnesses.

Metal benchmarks are registered only when `MetalExecutionContext` can create a device inside the benchmark runner process. If the runner reports Metal unavailable, CPU benchmarks still run and the existing XCTest Metal coverage remains the correctness gate for Metal kernels.

Benchmark groups:

- `fold/*`: end-to-end prover cost.
- `reduceFold/*`: public reduction verifier cost.
- `terminalVerify/*`: local terminal CE verification cost.
- `proofEnvelope/*`: serialization, parsing, and verification round-trip.
- `stage/*`: sum-check, PiCCS, PiRLC, and PiDEC stage costs.
- `kernel/*`: field, ring, multilinear evaluation, transformed evaluation, and Ajtai commitment hot paths.

Correctness gates:

- CPU and Metal benchmark outputs are compared when both paths exist.
- Full protocol benchmarks must pass reduction and terminal verification.
- Proof envelope benchmarks must parse, round-trip, and verify.

Baseline policy:

- Store baselines per hardware class, for example `apple-m4-release`.
- Treat stable kernel regressions over 5% and full protocol regressions over 10% as failures.
- Use Instruments or `xcrun xctrace record --template 'Metal System Trace'` only after the benchmark suite identifies a hotspot.

CI:

- `.github/workflows/superneo-benchmarks.yml` runs the quick profile on macOS and uploads `benchmark-results`.
- Add hardware-class baselines before enabling threshold failures in CI; otherwise public macOS runner variance will produce noisy failures.
