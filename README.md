# SuperNeo NuMetal

Research-grade Swift and Metal implementation of the SuperNeo lattice folding
protocol for Customizable Constraint Systems (CCS) on Apple platforms.

The implemented public profile is `Goldilocks/Phi81(d=54)`: Goldilocks field
arithmetic, a degree-54 cyclotomic ring, Ajtai-style lattice commitments,
folding protocol stages, versioned proof envelopes, CLI proof artifacts,
checked-in test vectors, benchmark tooling, and a Lean formalization track.

> Status: serious research implementation. This repository is not a
> production-audited cryptographic library and should not be described as a
> production-secure SNARK, IVC, or PCD system.

## Contents

- [Project Status](#project-status)
- [What Is Implemented](#what-is-implemented)
- [What This Does Not Claim](#what-this-does-not-claim)
- [Requirements](#requirements)
- [Repository Layout](#repository-layout)
- [Quick Start](#quick-start)
- [CLI Examples](#cli-examples)
- [External Artifact Verification](#external-artifact-verification)
- [Test Vectors](#test-vectors)
- [Benchmarks](#benchmarks)
- [Formalization And Reproduction](#formalization-and-reproduction)
- [Documentation Map](#documentation-map)
- [Trust Posture](#trust-posture)

## Project Status

| Area | Current state |
| --- | --- |
| Parameter profile | One implemented public profile: `Goldilocks/Phi81(d=54)`, `profileID = 1`. |
| Swift package | macOS 14+ package with library product `SuperNeo_NuMetal` and executable product `superneo`. |
| Proof paths | Fold reductions, terminal local proofs with public CE opening material, and compressed public terminal envelopes. |
| CLI surface | Integration demo for one-hot vector and binary-addition CCS workloads. |
| Backends | CPU reference implementation plus selected Metal acceleration. Metal is an acceleration path, not a trust oracle. |
| Assurance modes | `.highAssurance` and `.cpuRedundantMetal` execution policies are available for covered CPU-only or CPU-rechecked paths. |
| Benchmarks | Pinned Apple M4 reports exist. Cross-generation performance claims are intentionally out of scope until more reports are pinned. |
| Formal status | Conditional protocol formalization in Lean 4. Assumption-scoped theorem groups are tracked by `Docs/FormalStatus.json`. |

## What Is Implemented

- Goldilocks base field arithmetic and degree-2 extension arithmetic.
- Degree-54 cyclotomic ring arithmetic for `Phi_81(X) = X^54 + X^27 + 1`.
- Norm-preserving field-to-ring witness packing for the SuperNeo embedding.
- Ajtai commitment profile with `kappa = 18`, decomposition length `14`, norm
  bound `2`, and a paper-derived claimed profile security level of `129` bits.
- `PiCCS`, `PiRLC`, `PiDEC`, fold reduction verification, terminal CE
  verification, compressed public terminal envelopes, and opt-in CE opening
  proofs.
- Deterministic binary serialization for proof envelopes, commitments, public
  inputs, evaluation claims, verifier-key material, and test-vector artifacts.
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

## What This Does Not Claim

This repository does not currently provide:

- a production-audited cryptographic library,
- a general compiler from programs to CCS,
- a standalone application proving system with policy, persistence, replay
  protection, or user-facing verification semantics,
- a production zero-knowledge claim for arbitrary application statements,
- formal constant-time or side-channel resistance,
- a completed formal proof of every protocol theorem, or
- an independently certified security estimate.

A fold reduction is not a complete application proof. It verifies the public
reduction and returns output commitment-evaluation (CE) claims. Callers that
need terminal acceptance must verify a terminal proof and require terminal proof
kind at the policy boundary.

See [Docs/WhatThisProves.md](Docs/WhatThisProves.md) for the precise proof
semantics.

## Requirements

- macOS 14 or newer.
- Swift tools version 6.1 or newer, through Xcode or the Xcode command-line
  tools.
- A Metal-capable Apple platform for GPU acceleration and Metal benchmark rows.
  CPU tests and CPU proof paths remain available without registering Metal
  benchmark rows.
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

Run the production gate used by local release-readiness checks:

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

Run the quick benchmark profile directly:

```sh
Scripts/run-benchmarks.sh quick
```

Compare a benchmark run against a hardware-class baseline:

```sh
SUPERNEO_BENCHMARK_BASELINE=path/to/baseline-results.json Scripts/run-benchmarks.sh quick
```

## CLI Examples

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

The CLI proof generator uses the repository's `.highAssurance` execution policy.
It is still an integration demo, not a production policy engine.

More detail is available in [Docs/CLI.md](Docs/CLI.md).

## External Artifact Verification

The short `superneo verify path/to/artifact.json` form is a local
self-consistency check. For artifacts received from another process or party,
the caller should pin the expected verifier context outside the artifact:

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

Use `--require-terminal` whenever a fold reduction is not sufficient for the
application. Without trusted context arguments, the verifier reads the seed and
digests from the artifact itself, which is useful for demos but not a policy
decision.

The proof envelope binds proof bytes to profile ID, proof kind, CCS shape
digest, statement digest, verifier-key digest, transcript domain, and body
length. See [Docs/ProofEnvelope.md](Docs/ProofEnvelope.md).

## Test Vectors

Checked-in vectors are intended for compatibility and cross-implementation
testing:

| File | Workload | Proof kind |
| --- | --- | --- |
| [TestVectors/one-hot-vector-fold-v1.json](TestVectors/one-hot-vector-fold-v1.json) | one-hot vector | fold |
| [TestVectors/one-hot-vector-terminal-v1.json](TestVectors/one-hot-vector-terminal-v1.json) | one-hot vector | terminal |
| [TestVectors/binary-addition-u8-fold-v1.json](TestVectors/binary-addition-u8-fold-v1.json) | 8-bit binary addition | fold |

`TestVectors/manifest.json` is the trusted context for checked-in vectors:
hashes, byte counts, public inputs, key seeds, digests, proof-kind requirements,
and strict verification commands. `TestVectors/artifact.schema.json` is the
machine-readable artifact schema.

Run:

```sh
swift Scripts/validate-test-vectors.swift
```

See [TestVectors/README.md](TestVectors/README.md) for reconstruction rules and
schema expectations.

## Benchmarks

Benchmark results are only meaningful when paired with the documented
correctness gates. The benchmark runner verifies protocol outputs before
exporting results and compares CPU/Metal outputs where both paths exist.

Latest pinned local quick profile on Apple M4, measured 2026-04-12:

| Case | Earlier local quick | Latest quick | Speedup |
| --- | ---: | ---: | ---: |
| `fold/cpu/m64` | 5.465 ms | 4.349 ms | 1.26x |
| `fold/cpu/m256` | 42 ms | 38 ms | 1.11x |
| `fold/metal/m64` | 19 ms | 14.29 ms | 1.33x |
| `fold/metal/m256` | 69 ms | 63 ms | 1.10x |
| `stage/sumcheck/m64` | 1.848 ms | 0.302 ms | 6.12x |
| `stage/piCCSClaims/m64` | 1.509 ms | 0.337 ms | 4.48x |
| `stage/piRLC/m64` | 2.086 ms | 1.016 ms | 2.05x |
| `stage/piDEC/m64` | 3.686 ms | 2.302 ms | 1.60x |
| `terminalVerify/cpu/m64` | 5.434 ms | 3.299 ms | 1.65x |
| `terminalVerify/cpu/m256` | 20 ms | 13 ms | 1.54x |
| `proofEnvelope/roundTrip/m64` | 9.135 ms | 6.744 ms | 1.35x |
| `proofEnvelope/roundTrip/m256` | 25 ms | 17 ms | 1.47x |

Recent Apple M4 scaling reference points:

| Case | CPU fold | Metal fold | Notes |
| --- | ---: | ---: | --- |
| `m1024` | 578 ms | 74 ms | row-block 128 baseline |
| `m4096` | 4.37 s | 247 ms | row-block 128 and 256 effectively tied |
| `m16384` | 50 s | 950 ms | row-block 128 completed the scaling run |

Prepared-context rows, CE proof rows, compressed-envelope rows, row-block tuning,
and exact-arithmetic reports live in [Docs/Benchmarking.md](Docs/Benchmarking.md)
and [Docs/BenchmarkReports](Docs/BenchmarkReports).

## Formalization And Reproduction

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

## Documentation Map

Protocol and semantics:

- [Parameters](Docs/Parameters.md)
- [Threat Model](Docs/ThreatModel.md)
- [What This Proves](Docs/WhatThisProves.md)
- [Proof Envelope](Docs/ProofEnvelope.md)
- [GPU Determinism](Docs/GPUDeterminism.md)

Usage, artifacts, and validation:

- [CLI](Docs/CLI.md)
- [Test Vector README](TestVectors/README.md)
- [Test Vector Schema](TestVectors/artifact.schema.json)
- [Test Vector Manifest](TestVectors/manifest.json)
- [Test Suite Notes](SuperNeo-NuMetalTests/README.md)

Benchmarking and readiness:

- [Benchmarking](Docs/Benchmarking.md)
- [Production Readiness, 2026-04-13](Docs/ProductionReadiness-2026-04-13.md)
- [High-Assurance Hardening, 2026-04-13](Docs/HighAssuranceHardening-2026-04-13.md)
- [Lead Audit, 2026-04-12](Docs/LeadAudit-2026-04-12.md)
- [Roadmap Status](Docs/RoadmapStatus.md)

Formalization and reproduction:

- [Formal Verification](Docs/FormalVerification.md)
- [Paper Reproduction](Docs/PaperReproduction.md)
- [Lattice Estimator Reproduction](Docs/LatticeEstimatorReproduction.md)
- [Formal Status Manifest](Docs/FormalStatus.json)
- [DocC Module Overview](SuperNeo-NuMetal/SuperNeo_NuMetal.docc/SuperNeo_NuMetal.md)
- [Bundled SuperNeo Paper Notes](SuperNeo-NuMetal/SuperNeo_NuMetal.docc/superneopaper.md)

Detailed dated hardening notes for artifact parsing, workload canonicality,
key-seed domain separation, terminal vectors, Ajtai keys, and formal promotion
passes are kept under [Docs](Docs).

## Trust Posture

Verifier acceptance is meaningful only relative to the supplied CCS shape,
public inputs, proof kind, verifier key, proof envelope context, and terminal
relation policy. Application code must own expected context, key distribution,
artifact provenance, replay policy, and user-facing acceptance semantics.

Metal output should be treated as an acceleration result. Use
`.cpuRedundantMetal` when covered Metal outputs must be checked against CPU
computation, or `.highAssurance` when covered prover work should stay on the
constant-work CPU paths provided by this repository.

The concise public description is:

> SuperNeo NuMetal is a research-grade Swift/Metal implementation of the
> SuperNeo folding protocol over `Goldilocks/Phi81(d=54)`, with versioned proof
> envelopes, checked test vectors, benchmark gates, and an assumption-scoped
> formalization track.
