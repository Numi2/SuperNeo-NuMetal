# SuperNeo NuMetal

SuperNeo NuMetal is a Swift implementation of the SuperNeo lattice folding protocol for macOS 14+. It provides the core algebra, commitment, transcript, proof-envelope, CPU prover/verifier, and optional Metal acceleration paths needed to fold committed CCS instances over the Goldilocks field.

## Overview

SuperNeo is a post-quantum-oriented folding construction for Customizable Constraint Systems (CCS). A folding protocol reduces many committed instance-witness claims into a smaller claim while preserving verifier-checkable consistency, making it a useful primitive for incrementally verifiable computation, proof-carrying data, and recursive proof systems where prover cost and recursion overhead matter.

This package implements the SuperNeo protocol shape over the `Goldilocks/Phi54` parameter profile:

- Arithmetic over the Goldilocks prime field and a degree-2 extension field.
- Ring operations in the cyclotomic quotient used by the SuperNeo embedding, with degree `54`.
- Norm-preserving field-to-ring packing for CCS witnesses.
- Ajtai-style lattice commitments with `kappa = 18`, decomposition length `14`, and a claimed profile security level of `129` bits.
- Sum-check, PiCCS, PiRLC, PiDEC, terminal verification, compressed public envelopes, and opt-in CE opening proofs.
- Deterministic byte serialization for public inputs, proof envelopes, commitments, evaluation claims, and verifier-key digests.
- CPU reference paths plus Metal kernels for field/ring arithmetic, Ajtai commitments, sparse transformed evaluation, and fused commit-plus-evaluation workloads.

Public data is domain separated and bound through transcript digests, shape digests, statement digests, verifier-key digests, and versioned proof envelopes so benchmarked proof objects can be parsed, round-tripped, and verified reproducibly.

## Cryptographic Model

SuperNeo replaces elliptic-curve commitments with lattice commitments so the folding layer is plausibly post-quantum under structured lattice assumptions, specifically the Module-SIS assumption used by Ajtai commitments. Witness vectors are committed after SuperNeo's norm-preserving embedding maps field elements into ring elements. This lets the implementation keep commitment costs tied to small witness coefficients while running the folding checks over field-native arithmetic instead of expensive ring-native sum-check arithmetic.

The protocol stack separates three concerns:

- **Algebraic relation checking:** CCS matrices are transformed into the SuperNeo ring representation, evaluated sparsely where possible, and checked through sum-check-derived protocol stages.
- **Commitment binding:** Ajtai commitments bind packed witness data to verifier-key material derived from seeded commitment matrices.
- **Transcript soundness:** Fiat-Shamir challenges are derived from domain-separated transcripts that absorb public inputs, commitments, claims, shape metadata, and proof messages before sampling challenges.

The codebase includes CPU and Metal implementations for performance-critical kernels, but correctness is not delegated to the GPU. Metal outputs are differentially checked against CPU behavior in tests and benchmark gates, and full protocol benchmarks must still pass reduction, terminal verification, and proof-envelope verification.


## Tests

Quick inner loop:

```sh
Scripts/test-slice.sh fast
```

Full suite (CPU-heavy; current local runs can take several minutes):

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
- `ceOpeningProof/*` and `compressedEnvelope/*`: opt-in CE proof verification targets enabled with `SUPERNEO_BENCHMARK_CE=1`.
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

Latest CPU-path audit snapshot (2026-04-12):

| Case | Before | After | Notes |
| --- | ---: | ---: | --- |
| `fold/cpu/m64` | 25 ms | 16 ms | sparse transformed protocol path |
| `stage/piCCSClaims/m64` | 2.61 ms | 0.925 ms | sparse transformed evaluation |
| `stage/piDEC/m64` | 17 ms | 10.068 ms | single-pass extension-ring row evaluation |
| `terminalVerify/cpu/m64` | 23 ms | 12 ms | reused sparse CE verification matrices |
| `ajtaiCommit/cpu/m64` | 173 us | 137 us | fused CPU Ajtai matvec |
| `fold/cpu/m1024` | 595 ms | 237 ms | sparse-only CPU shape compilation |
| `stage/piCCSClaims/m1024` | 99 ms | 27 ms | sparse transformed protocol path |
| `stage/piDEC/m1024` | 449 ms | 174 ms | precomputed `rHat` reused across coefficients |
| `terminalVerify/cpu/m1024` | 520 ms | 189 ms | batched local CE verification reuse |
| `proofEnvelope/roundTrip/m1024` | 504 ms | 148 ms | protocol CPU path improvements |
| `compressed public XCTest` | 317 s | 61.009 s | cached CE targets plus chunked prover and batched verifier private-linear work |
| `ceOpeningProof/*` | opt-in | opt-in | opt-in CE proof prove/verify targets, including Metal prove/verify when available |
| `ajtaiCommit/cpu/m1024` | 3.38 ms | 2.876 ms | fused CPU Ajtai matvec |
| `ajtaiCommit/batch/cpu/m1024` | 43 ms | 37 ms | fused CPU Ajtai matvec |

Detailed benchmark policy, correctness gates, CI notes, and runner implementation details are in [Docs/Benchmarking.md](Docs/Benchmarking.md).
