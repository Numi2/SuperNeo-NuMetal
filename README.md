# SuperNeo NuMetal

SuperNeo NuMetal is a Swift implementation of the SuperNeo lattice folding protocol for macOS 14+. It provides the core algebra, commitment, transcript, proof-envelope, CPU prover/verifier, and optional Metal acceleration paths needed to fold committed CCS instances over the Goldilocks field.

## Overview

SuperNeo is a post-quantum-oriented folding construction for Customizable Constraint Systems (CCS). A folding protocol reduces many committed instance-witness claims into a smaller claim while preserving verifier-checkable consistency, making it a useful primitive for incrementally verifiable computation, proof-carrying data, and recursive proof systems where prover cost and recursion overhead matter.

This package implements the SuperNeo protocol shape over the `Goldilocks/Phi81(d=54)` parameter profile:

- Arithmetic over the Goldilocks prime field and a degree-2 extension field.
- Ring operations in the cyclotomic quotient used by the SuperNeo embedding, with degree `54`.
- Norm-preserving field-to-ring packing for CCS witnesses.
- Ajtai-style lattice commitments with `kappa = 18`, decomposition length `14`, and a claimed profile security level of `129` bits.
- Sum-check, PiCCS, PiRLC, PiDEC, terminal verification, compressed public envelopes, and opt-in CE opening proofs.
- Deterministic byte serialization for public inputs, proof envelopes, commitments, evaluation claims, and verifier-key digests.
- CPU reference paths plus Metal kernels for field/ring arithmetic, Ajtai commitments, sparse transformed evaluation, and fused commit-plus-evaluation workloads.

Public data is domain separated and bound through transcript digests, shape digests, statement digests, verifier-key digests, and versioned proof envelopes so benchmarked proof objects can be parsed, round-tripped, and verified reproducibly.

## Documentation

Start with these documents before treating a proof as meaningful:

- [Parameters](Docs/Parameters.md): the implemented `Goldilocks/Phi81(d=54)` profile and how it maps to the Neo/SuperNeo paper.
- [Threat model](Docs/ThreatModel.md): assumptions, trust boundaries, adversary model, and current non-goals.
- [Proof envelope format](Docs/ProofEnvelope.md): the versioned binary container and transcript/context binding rules.
- [What this proves](Docs/WhatThisProves.md): the distinction between fold reductions, terminal proofs, compressed public envelopes, and full application claims.
- [CLI demo and test vector](Docs/CLI.md): one-hot CCS workload, `superneo prove`, `verify`, `inspect`, and the checked-in golden vector.
- [GPU determinism](Docs/GPUDeterminism.md): what the Metal path promises, how it is checked against the CPU oracle, and what remains out of scope.
- [Paper reproduction harness](Docs/PaperReproduction.md): maps `superneopaper.md` claims to pinned commands, benchmark selectors, logs, and generated reports.
- [Roadmap status](Docs/RoadmapStatus.md): concrete artifact map for legibility, usability, credibility, and influence.

## Demo CLI

Build and run the executable target:

```sh
swift run superneo prove --bits 0,0,1,0,0,0,0,0 --output /tmp/one-hot-proof.json
swift run superneo verify /tmp/one-hot-proof.json
swift run superneo inspect /tmp/one-hot-proof.json
```

The CLI includes a one-hot vector workload and an 8-bit binary-addition workload:

```sh
swift run superneo prove --workload binary-add --operand-bits 8 --lhs 13 --rhs 29 --output /tmp/binary-add-proof.json
swift run superneo verify /tmp/binary-add-proof.json
```

The default proof kind is a fast fold reduction, so verification reports that
terminal CE verification is still required. Use `--kind terminal` for a complete
terminal proof; it is currently much larger and slower because it includes the
public CE opening proof.

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

Latest CPU-path audit snapshot (2026-04-12):

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

Detailed benchmark policy, correctness gates, CI notes, runner implementation
details, and hardware-class report links are in
[Docs/Benchmarking.md](Docs/Benchmarking.md).
