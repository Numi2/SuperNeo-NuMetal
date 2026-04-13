# SuperNeo NuMetal

Swift and Metal implementation work for the SuperNeo lattice folding protocol on Apple Silicon.

## Abstract

SuperNeo NuMetal implements a post-quantum-oriented folding stack for Customizable Constraint Systems (CCS) over the `Goldilocks/Phi81(d=54)` profile. The repository includes exact field and ring arithmetic, Ajtai-style lattice commitments, transcript-bound folding stages, proof-envelope serialization, CPU reference execution, and optional Metal acceleration for Apple GPUs.

The project is built around reproducibility and verifier discipline. Public objects are bound through shape digests, statement digests, verifier-key digests, domain-separated transcripts, and versioned proof envelopes. Production CE opening proofs use Apple Security framework randomness before statement-bound deterministic expansion. Metal is treated as an acceleration path, not a trust oracle: CPU and Metal outputs are differentially checked where both paths exist.

## What Is Implemented

- Goldilocks base field and degree-2 extension arithmetic.
- Degree-54 cyclotomic ring arithmetic for the SuperNeo embedding.
- Norm-preserving field-to-ring witness packing.
- Ajtai commitment profile with `kappa = 18`, decomposition length `14`, and claimed profile security of `129` bits.
- Sum-check, PiCCS, PiRLC, PiDEC, reduction verification, terminal CE verification, compressed public envelopes, and opt-in CE opening proofs.
- Deterministic byte serialization for proof envelopes, commitments, public inputs, evaluation claims, and verifier-key material.
- CPU reference paths plus Metal kernels for selected field, ring, commitment, transformed-evaluation, and fused commit/evaluation workloads.
- Cryptographic hardening for production CE entropy, mixed-witness PiRLC rejection, Metal workspace shape/key invariants, checked CE vector subtraction, and CPU/Metal differential coverage.

## Current Benchmark Signal

Latest pinned local quick profile on Apple M4, measured 2026-04-12. See the linked reports for hardware, toolchain, proof sizes, validation, and caveats.

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

Recent scaling reference points on Apple M4:

| Case | CPU fold | Metal fold | Notes |
| --- | ---: | ---: | --- |
| `m1024` | 578 ms | 74 ms | row-block 128 baseline |
| `m4096` | 4.37 s | 247 ms | row-block 128 and 256 effectively tied |
| `m16384` | 50 s | 950 ms | row-block 128 completed the scaling run |

Benchmark correctness gates run protocol verification before exporting results. The latest CSR/CE batch pass also validated both checked-in test vectors and added regression tests for the optimized multilinear equality formula and CSR transform equivalence.

The staged lead-audit pass produced additional local quick-profile evidence without rewriting tracked hardware-class reports:

| Row | Local audit quick result | Notes |
| --- | ---: | --- |
| `fold/cpu/m64-K1-k0-binary` | 4.109 ms | direct CSR, in-place multilinear layers and basis, zero-skip CPU transformed evaluation |
| `fold/cpu/m256-K2-k1-binary` | 36 ms | quick profile second case |
| `kernel/multilinearEvaluation/m64-K1-k0-binary` | 1.750 us | benchmark now excludes CSR rehydration setup |
| `kernel/transformedEvaluation/cpu/m64-K1-k0-binary` | 38 us | public CPU backend path |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 28 us | sparse transformed-row path |
| `stage/piDEC/m64-K1-k0-binary` | 2.150 ms | local wall-clock evidence |

Treat these rows as local audit evidence until a full hardware-class report is pinned.

## Quick Start

Run the test suite:

```sh
swift test --disable-swift-testing
```

Run the production gate:

```sh
Scripts/production-gate.sh
```

Include the quick benchmark gate in the same local run:

```sh
Scripts/production-gate.sh --with-benchmarks
```

Run the fast test slice:

```sh
Scripts/test-slice.sh fast
```

Validate golden test vectors:

```sh
swift Scripts/validate-test-vectors.swift
```

Run the quick benchmark profile:

```sh
Scripts/run-benchmarks.sh quick
```

Run a CLI proof demo:

```sh
swift run superneo prove --bits 0,0,1,0,0,0,0,0 --output /tmp/one-hot-proof.json
swift run superneo verify /tmp/one-hot-proof.json
swift run superneo inspect /tmp/one-hot-proof.json
```

Run the binary-addition workload:

```sh
swift run superneo prove --workload binary-add --operand-bits 8 --lhs 13 --rhs 29 --output /tmp/binary-add-proof.json
swift run superneo verify /tmp/binary-add-proof.json
```

The default CLI proof kind is a fold reduction. Use `--kind terminal` when you need a complete terminal proof with public CE opening proof material.

For artifacts received outside a trusted local demo loop, verify with pinned
context instead of relying only on artifact-supplied metadata. Pass
`--key-seed`, `--expected-verifier-key-digest`, `--expected-shape-digest`,
`--expected-statement-digest`, and `--expected-public-inputs`; add
`--require-terminal` when a fold reduction is not sufficient for the caller.

## Documentation

Core documentation:

- [Parameters](Docs/Parameters.md): implemented parameter profile and paper mapping.
- [Threat Model](Docs/ThreatModel.md): assumptions, trust boundaries, attacker model, and non-goals.
- [What This Proves](Docs/WhatThisProves.md): what fold reductions, terminal proofs, compressed public envelopes, and application claims do and do not establish.
- [Proof Envelope](Docs/ProofEnvelope.md): versioned binary container and context binding.
- [GPU Determinism](Docs/GPUDeterminism.md): CPU/Metal relationship, determinism claims, and remaining GPU risks.
- [CLI](Docs/CLI.md): command-line proof demo and golden-vector workflow.
- [Benchmarking](Docs/Benchmarking.md): benchmark profiles, correctness gates, baseline policy, CI notes, and detailed benchmark tables.
- [Lead Audit, 2026-04-12](Docs/LeadAudit-2026-04-12.md): cryptographic hardening, backend benchmark work, validation commands, and local audit evidence.
- [Paper Reproduction](Docs/PaperReproduction.md): reproducibility harness and claim map.
- [Roadmap Status](Docs/RoadmapStatus.md): current artifact map and project status.

Benchmark reports:

- [Apple M4 quick profile, 2026-04-12](Docs/BenchmarkReports/apple-m4-quick-2026-04-12.md)
- [Apple M4 exact-arithmetic quick profile, 2026-04-12](Docs/BenchmarkReports/apple-m4-quick-exact-arithmetic-2026-04-12.md)
- [Apple M4 CSR transform and CE batch quick profile, 2026-04-12](Docs/BenchmarkReports/apple-m4-quick-csr-ce-batch-2026-04-12.md)
- [Apple M4 scalar, transcript, and sumcheck quick profile, 2026-04-13](Docs/BenchmarkReports/apple-m4-quick-scalar-transcript-sumcheck-2026-04-13.md)

Reference and generated documentation:

- [DocC module overview](SuperNeo-NuMetal/SuperNeo_NuMetal.docc/SuperNeo_NuMetal.md)
- [SuperNeo paper notes](SuperNeo-NuMetal/SuperNeo_NuMetal.docc/superneopaper.md)
- [Test vector README](TestVectors/README.md)
- [Test vector schema](TestVectors/artifact.schema.json)
- [Test vector manifest](TestVectors/manifest.json)
- [One-hot vector fold artifact](TestVectors/one-hot-vector-fold-v1.json)
- [Binary-addition u8 fold artifact](TestVectors/binary-addition-u8-fold-v1.json)
- [Test suite notes](SuperNeo-NuMetalTests/README.md)

## Trust Posture

This is cryptographic systems code. Treat performance numbers as meaningful only when paired with the documented correctness gates. Do not infer broader application security from a fold reduction alone; the proof meaning depends on the statement, terminal checks, public CE opening material, and the threat model.
