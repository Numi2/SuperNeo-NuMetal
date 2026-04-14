# SuperNeo NuMetal

SuperNeo NuMetal is a research-grade Swift and Metal implementation of the
SuperNeo lattice folding protocol for Customizable Constraint Systems (CCS) on
Apple platforms.

The implemented public profile is `Goldilocks/Phi81(d=54)`: Goldilocks field
arithmetic, a degree-54 cyclotomic ring, Ajtai-style lattice commitments,
folding protocol stages, versioned proof envelopes, checked test vectors,
benchmark tooling, and an assumption-scoped Lean formalization track.

This repository is intended for protocol research, implementation validation,
benchmarking, and reproducibility work. It is not a production-audited
cryptographic library.

## Status

| Area | Current state |
| --- | --- |
| Profile | `Goldilocks/Phi81(d=54)`, `profileID = 1`. |
| Package | macOS 14+ Swift package with library product `SuperNeo_NuMetal` and executable product `superneo`. |
| Proof modes | Fold reductions, terminal proofs with public CE opening material, and compressed public terminal envelopes. |
| Workloads | Bundled one-hot vector and 8-bit binary-addition CCS workloads. |
| Backends | CPU reference implementation plus selected Metal acceleration. Metal is treated as an acceleration path, not a trust oracle. |
| Assurance policies | `.highAssurance` for covered constant-work CPU paths and `.cpuRedundantMetal` for covered CPU-rechecked Metal outputs. |
| Test vectors | Fold, terminal, and compressed-terminal artifacts with manifest-bound trusted context. |
| Benchmarks | Latest local Apple M4 quick slice is pinned under `benchmark-results/` and summarized below. |
| Formalization | Conditional protocol formalization in Lean 4, tracked by `Docs/FormalStatus.json`. |

## Capabilities

- Goldilocks base field arithmetic and degree-2 extension arithmetic.
- Degree-54 cyclotomic ring arithmetic for `Phi_81(X) = X^54 + X^27 + 1`.
- Norm-preserving field-to-ring witness packing for the SuperNeo embedding.
- Ajtai commitment profile with `kappa = 18`, decomposition length `14`, norm
  bound `2`, and a paper-derived claimed profile security level of `129` bits.
- `PiCCS`, `PiRLC`, `PiDEC`, fold reduction verification, terminal CE
  verification, compressed public terminal envelopes, and opt-in CE opening
  proofs.
- Deterministic serialization for proof envelopes, commitments, public inputs,
  evaluation claims, verifier-key material, and test-vector artifacts.
- R1CS-to-CCS helper surfaces for the bundled one-hot vector and binary-addition
  workloads.
- CPU reference execution plus Metal kernels for selected field, ring,
  commitment, transformed-evaluation, and fused commit/evaluation workloads.
- Differential CPU/Metal checking where both paths exist.
- Hardening around proof-envelope parsing, verifier-context binding, duplicate
  JSON keys, artifact schemas, workload metadata, key-seed domain separation,
  Metal workspace invariants, checked allocation sizes, and high-assurance
  execution policies.

Core profile constants are documented in [Docs/Parameters.md](Docs/Parameters.md).

| Quantity | Value |
| --- | ---: |
| Base field modulus | `2^64 - 2^32 + 1` |
| Extension field | `F_q[u] / (u^2 - 7)` |
| Cyclotomic polynomial | `X^54 + X^27 + 1` |
| Ring degree | `54` |
| Ajtai rows | `18` |
| Decomposition length | `14` |
| RLC challenge coefficients | `[-2, -1, 0, 1, 2]` |
| Challenge expansion factor | `216` |
| Maximum fresh batch count | `61` |
| Maximum prior CE claim count | `14` |

## Scope and Trust Model

Verifier acceptance is meaningful only relative to the supplied CCS shape,
public inputs, proof kind, verifier key, proof envelope context, and terminal
relation policy. Application code must own expected context, key distribution,
artifact provenance, replay policy, and user-facing acceptance semantics.

A fold reduction verifies the public reduction and returns output
commitment-evaluation claims. Callers that need terminal acceptance should
verify a terminal or compressed-terminal proof and require terminal proof kind
at the policy boundary.

Current boundaries:

- no production audit or independent security certification,
- no general compiler from programs to CCS,
- no application-layer policy engine, persistence layer, replay-protection
  system, or user-facing verification product,
- no production zero-knowledge claim for arbitrary application statements,
- no completed formal constant-time or side-channel proof, and
- no completed full formal protocol theorem.

The concise proof semantics are documented in
[Docs/WhatThisProves.md](Docs/WhatThisProves.md), and the operational threat
model is documented in [Docs/ThreatModel.md](Docs/ThreatModel.md).

## Requirements

- macOS 14 or newer.
- Swift tools version 6.1 or newer through Xcode or the Xcode command-line
  tools.
- A Metal-capable Apple platform for GPU acceleration and Metal benchmark rows.
  CPU tests and CPU proof paths remain available without Metal benchmark rows.
- Lean 4 through `elan` for the optional formalization workspace.
- SageMath plus the pinned upstream lattice-estimator checkout for full
  estimator reproduction. Dry-run estimator parameter derivation does not
  require SageMath.

The root Swift package has no third-party package dependencies. Benchmark-only
dependencies are isolated under [Benchmarks/Package.swift](Benchmarks/Package.swift).

## Repository Layout

| Path | Purpose |
| --- | --- |
| [SuperNeo-NuMetal](SuperNeo-NuMetal) | Main Swift library implementation. |
| [SuperNeoCLI](SuperNeoCLI) | `superneo` command-line integration demo. |
| [SuperNeo-NuMetalTests](SuperNeo-NuMetalTests) | XCTest coverage and usability-surface tests. |
| [TestVectors](TestVectors) | Checked-in public proof artifacts, manifest, and JSON schema. |
| [Benchmarks](Benchmarks) | Swift package-benchmark suite. |
| [Scripts](Scripts) | Production gate, benchmark, validation, and reproduction scripts. |
| [Docs](Docs) | Protocol, security, benchmark, hardening, and formalization documentation. |
| [Formal](Formal) | Lean 4/Lake formalization workspace. |

## Quick Start

Run the XCTest suite:

```sh
swift test --disable-swift-testing
```

Run the fast local slice:

```sh
Scripts/test-slice.sh fast
```

Run the local release-readiness gate:

```sh
Scripts/production-gate.sh
```

Include the quick benchmark profile in the same gate:

```sh
Scripts/production-gate.sh --with-benchmarks
```

Validate checked-in test vectors:

```sh
swift Scripts/validate-test-vectors.swift
```

Run the quick benchmark profile:

```sh
Scripts/run-benchmarks.sh quick
```

Compare a benchmark run against a hardware-class baseline:

```sh
SUPERNEO_BENCHMARK_BASELINE=path/to/baseline-results.json Scripts/run-benchmarks.sh quick
```

## CLI

Generate, verify, and inspect the default one-hot fold artifact:

```sh
swift run superneo prove \
  --workload one-hot \
  --bits 0,0,1,0,0,0,0,0 \
  --output /tmp/one-hot-proof.json

swift run superneo verify /tmp/one-hot-proof.json
swift run superneo inspect /tmp/one-hot-proof.json
```

Generate and verify an 8-bit binary-addition fold artifact proving
`13 + 29 = 42` without revealing the private operands:

```sh
swift run superneo prove \
  --workload binary-add \
  --operand-bits 8 \
  --lhs 13 \
  --rhs 29 \
  --output /tmp/binary-add-proof.json

swift run superneo verify /tmp/binary-add-proof.json
```

Generate a terminal proof when the verifier needs complete terminal CE
verification instead of a fold-only reduction:

```sh
swift run superneo prove \
  --workload one-hot \
  --kind terminal \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-terminal-proof.json

swift run superneo verify --require-terminal /tmp/one-hot-terminal-proof.json
```

Generate a compressed terminal proof with compressed public terminal statement
material:

```sh
swift run superneo prove \
  --workload one-hot \
  --kind compressed-terminal \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-compressed-terminal-proof.json

swift run superneo verify --require-terminal /tmp/one-hot-compressed-terminal-proof.json
```

The CLI proof generator uses the repository's `.highAssurance` execution
policy. It remains an integration demo, not a production policy engine. More
detail is available in [Docs/CLI.md](Docs/CLI.md).

## Artifact Verification

The short form is a local self-consistency check:

```sh
swift run superneo verify path/to/artifact.json
```

For artifacts received from another process or party, pin the expected verifier
context outside the artifact:

```sh
swift run superneo verify \
  --key-seed <trusted-key-seed> \
  --expected-verifier-key-digest <trusted-verifier-key-digest-hex> \
  --expected-shape-digest <trusted-shape-digest-hex> \
  --expected-statement-digest <trusted-statement-digest-hex> \
  --expected-public-inputs <trusted-public-inputs> \
  --require-terminal \
  path/to/artifact.json
```

Without trusted context arguments, the verifier reads the seed and digests from
the artifact itself, which is useful for demos but not a policy decision. The
proof envelope binds proof bytes to profile ID, proof kind, CCS shape digest,
statement digest, verifier-key digest, transcript domain, and body length. See
[Docs/ProofEnvelope.md](Docs/ProofEnvelope.md).

## Test Vectors

Checked-in vectors are intended for compatibility and cross-implementation
testing:

| File | Workload | Proof kind |
| --- | --- | --- |
| [TestVectors/one-hot-vector-fold-v1.json](TestVectors/one-hot-vector-fold-v1.json) | one-hot vector | fold |
| [TestVectors/one-hot-vector-terminal-v1.json](TestVectors/one-hot-vector-terminal-v1.json) | one-hot vector | terminal |
| [TestVectors/one-hot-vector-compressed-terminal-v1.json](TestVectors/one-hot-vector-compressed-terminal-v1.json) | one-hot vector | compressed-terminal |
| [TestVectors/binary-addition-u8-fold-v1.json](TestVectors/binary-addition-u8-fold-v1.json) | 8-bit binary addition | fold |
| [TestVectors/binary-addition-u8-terminal-v1.json](TestVectors/binary-addition-u8-terminal-v1.json) | 8-bit binary addition | terminal |

`TestVectors/manifest.json` is the trusted context for checked-in vectors:
hashes, byte counts, public inputs, key seeds, digests, proof-kind requirements,
and strict verification commands. `TestVectors/artifact.schema.json` is the
machine-readable artifact schema.

```sh
swift Scripts/validate-test-vectors.swift
```

See [TestVectors/README.md](TestVectors/README.md) for reconstruction rules and
schema expectations.

## Benchmarks

Benchmark results are meaningful only with the documented correctness gates.
The benchmark runner verifies protocol outputs before exporting results and
compares CPU/Metal outputs where both paths exist.

Latest local benchmark snapshot:

| Field | Value |
| --- | --- |
| Generated | `2026-04-14T03:00:20Z` |
| Source commit | `31d69f0` |
| Source state | dirty |
| Host | MacBook Air, Apple M4, 10 CPU cores, 24 GB memory |
| Toolchain | Swift 6.3, Xcode 26.4 |
| OS | macOS 26.5 build `25F5042g` |
| Profile | `quick` |
| Case filter | `m256-K2-k1-binary` |
| Metal device | Apple M4 |

Proof size for the latest case:

| Case | Constraints | Proof | Envelope | Sum-check | PiCCS | PiRLC | PiDEC | Output claims |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `m256-K2-k1-binary` | 256 | 344,616 B | 344,757 B | 880 B | 32,856 B | 12,248 B | 145,280 B | 153,328 B |

Selected timing rows from the same run:

| Row | Time | Derived rate |
| --- | ---: | ---: |
| `fold/cpu/m256-K2-k1-binary` | 28 ms | 35.71 folds/s, 9,143 constraints/s |
| `fold/metal/m256-K2-k1-binary` | 41 ms | 24.39 folds/s, 6,244 constraints/s |
| `fold/prepared/cpu/m256-K2-k1-binary` | 27 ms | 37.04 folds/s, 9,481 constraints/s |
| `fold/prepared/metal/m256-K2-k1-binary` | 38 ms | 26.32 folds/s, 6,737 constraints/s |
| `stage/sumcheck/m256-K2-k1-binary` | 16 ms |  |
| `stage/piCCSClaims/m256-K2-k1-binary` | 4.64 ms |  |
| `stage/piRLC/m256-K2-k1-binary` | 2.18 ms |  |
| `stage/piDEC/m256-K2-k1-binary` | 2.64 ms |  |
| `reduceFold/cpu/m256-K2-k1-binary` | 2.37 ms |  |
| `terminalVerify/cpu/m256-K2-k1-binary` | 4.83 ms |  |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 9.09 ms |  |
| `kernel/ajtaiCommit/batch/cpu/m256-K2-k1-binary` | 5.34 ms | 187.23 commitments/s |
| `kernel/ajtaiCommit/batch/metal/m256-K2-k1-binary` | 1.79 ms | 559.60 commitments/s |
| `kernel/transformedEvaluation/cpuSparse/m256-K2-k1-binary` | 83 us |  |
| `kernel/transformedEvaluation/metalSparse/m256-K2-k1-binary` | 4.13 ms |  |

The full generated report is
[benchmark-results/report.md](benchmark-results/report.md). Benchmark profiles,
correctness gates, metadata-aware baseline comparison, and hardware-class report
policy are documented in [Docs/Benchmarking.md](Docs/Benchmarking.md).

Do not use these numbers for cross-generation claims. Current pinned README
figures cover the latest local Apple M4 quick slice only.

## Formalization and Reproduction

Build the Lean workspace:

```sh
cd Formal
lake build
```

Validate the formal status manifest and regression harness:

```sh
Scripts/validate-formal-status.py
Scripts/test-formal-status-validation.py
```

Generate a paper-claim reproduction artifact:

```sh
Scripts/reproduce-superneo-paper.sh quick
```

Record the implemented Module-SIS estimator tuple without running SageMath:

```sh
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py \
  --expect-status not_run \
  --expect-latest-status absent \
  lattice-estimator-results/superneo-goldilocks-phi81.json
```

Full estimator reproduction requires SageMath and the pinned upstream
`malb/lattice-estimator` source configured by the script. Latest-upstream runs
are drift monitoring only and should not replace pinned evidence.

See [Docs/FormalVerification.md](Docs/FormalVerification.md),
[Docs/PaperReproduction.md](Docs/PaperReproduction.md), and
[Docs/LatticeEstimatorReproduction.md](Docs/LatticeEstimatorReproduction.md).

## Documentation

Core references:

- [Parameters](Docs/Parameters.md)
- [Threat Model](Docs/ThreatModel.md)
- [Proof Semantics](Docs/WhatThisProves.md)
- [Proof Envelope](Docs/ProofEnvelope.md)
- [CLI](Docs/CLI.md)
- [Benchmarking](Docs/Benchmarking.md)
- [Formal Verification](Docs/FormalVerification.md)
- [Paper Reproduction](Docs/PaperReproduction.md)
- [Lattice Estimator Reproduction](Docs/LatticeEstimatorReproduction.md)
- [Roadmap Status](Docs/RoadmapStatus.md)

Recent implementation and hardening notes:

- [Benchmark Metadata Comparison, 2026-04-14](Docs/BenchmarkMetadataComparison-2026-04-14.md)
- [PiRLC Benchmark Isolation, 2026-04-14](Docs/BenchmarkPiRLCIsolation-2026-04-14.md)
- [Opening Batch Parallel Threshold, 2026-04-14](Docs/BenchmarkOpeningBatchThreshold-2026-04-14.md)
- [Relation Evaluation Plan, 2026-04-14](Docs/BenchmarkRelationEvaluationPlan-2026-04-14.md)
- [Sum-Check Prior-Claim Evaluation Batch, 2026-04-14](Docs/BenchmarkSumcheckPriorBatch-2026-04-14.md)
- [Sum-Check Public Precompute Cleanup, 2026-04-14](Docs/BenchmarkSumcheckPublicPrecompute-2026-04-14.md)
- [Transformed Evaluation Fusion, 2026-04-14](Docs/BenchmarkTransformedEvaluationFusion-2026-04-14.md)
- [Binary Addition Terminal Vector, 2026-04-14](Docs/BinaryAdditionTerminalVector-2026-04-14.md)
- [Compressed Terminal Vector, 2026-04-14](Docs/CompressedTerminalVector-2026-04-14.md)
- [Vector Manifest Duplicate Key Hardening, 2026-04-14](Docs/VectorManifestDuplicateKeyHardening-2026-04-14.md)

Detailed dated notes for artifact parsing, workload canonicality, key-seed
domain separation, terminal vectors, Ajtai keys, benchmark passes, and formal
promotion are kept under [Docs](Docs).
