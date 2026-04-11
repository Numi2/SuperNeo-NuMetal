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

See [Docs/Benchmarking.md](Docs/Benchmarking.md) and `Scripts/run-benchmarks.sh`.
