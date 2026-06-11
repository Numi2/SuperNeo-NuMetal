# SuperNeo NuMetal

SuperNeo NuMetal is a Swift and Metal research implementation of the SuperNeo
folding stack over the `Goldilocks/Phi81(d=54)` profile. The repository contains
the Swift prover/verifier, NumiSeal product proof paths, proof-envelope and
compression experiments, Metal acceleration lanes, checked evidence manifests,
benchmark tooling, and a Lean 4 formal track under `Formal/`.

The repository-local status is: completed formal protocol theorem, checked
bounded-depth product/evidence surface, and release-candidate tooling. This is
not an independently audited production SNARK or a production post-quantum
security claim.

## Current Implementation Snapshot

### Core Folding Stack

- CCS/R1CS frontends, Goldilocks field arithmetic, Phi81 ring arithmetic,
  Ajtai commitments, PiCCS/PiRLC/PiDEC folding, terminal CE opening checks, and
  compressed terminal envelopes are implemented in `SuperNeo-NuMetal/`.
- `reduceFold` verifies the public fold reduction; terminal acceptance requires
  `verifyTerminalFold` or terminal-envelope verification.
- Proof envelopes bind proof kind, profile, shape, public statement, verifier
  key, transcript domain, and exact body length.
- Source-fold product artifacts use `sourceDecompositionProfile =
  "pay-per-bit-v1"`; fixed 14-limb source decomposition is no longer the
  selected product path.

### Product Path

- Product proving defaults to NumiSealZK with `zkMode =
  "masked-digit-tensor-v1"`.
- Product artifacts must be `NumiSealProductArtifact.artifactVersion == 2`.
- Product verification uses the explicit QRO public-coin architecture described
  in `Docs/QROProductArchitecture-2026-04-25.md`.
- Artifact-selected transcript seeds and legacy self-described NumiSeal JSON
  are not product acceptance paths.
- Signed issued-QRO packs bind trusted context, provenance inputs, verifier key,
  public inputs, transcript domain, issue window, and single-use replay policy.
- Product-control verification binds replay/audit state, CTCO roots, QROM
  evidence metadata, trace evidence, carry context, aggregate digests, and proof
  transcript digests.

### Proof Compression And Performance Work

- `SuperNeoSpartanFRICompressor` implements an experimental Spartan/FRI-style
  compression path for accepted terminal or compressed-terminal source proofs.
- The compression path includes terminal-verifier AIR material, FRI PCS proofs,
  Merkle openings, query schedule checks, residual checks, source-bound
  verification, and verifier-key-required source-free verification.
- Metal acceleration covers batched SHAKE/SHA-256 hashing, CE challenge
  seed-chain work, FRI domain evaluation/NTT experiments, Ajtai batch
  commitments, transformed matrix evaluation, and combined commit/eval
  workspace paths.
- Default and high-assurance policies keep secret-bearing work on the
  constant-work CPU path; accelerated and CPU-redundant Metal modes are explicit
  opt-ins.

### Formal And Evidence Track

- Lean sources under `Formal/` cover the repository model: transcript
  well-formedness, typed digest domains, proof-envelope binding, Phi81/Goldilocks
  surfaces, PiCCS/PiRLC/PiDEC soundness surfaces, terminal CE accounting,
  NumiSeal typed carry, QRO/QROM ledgers, and the product theorem wiring.
- `TestVectors/` contains strict vector schemas and machine-readable evidence
  manifests for product security, QROM accounting, loss budgets, release
  distribution, constant-time scope/lowering, E2E proof metrics, and benchmark
  coverage.
- `Scripts/production-gate.sh` is the repository-local release-candidate gate.

## Repository Map

- `SuperNeo-NuMetal/`: Swift library implementation, protocol paths, proof
  compression, serialization, product integration, and Metal backend.
- `SuperNeoCLI/`: `superneo` development and product-smoke CLI.
- `SuperNeo-NuMetalTests/`: protocol, product, compression, verifier-negative,
  policy, and Metal differential tests.
- `Formal/`: Lean 4 formal workspace.
- `Docs/`: architecture, proof semantics, product, release, operations,
  benchmark, and security-boundary notes.
- `TestVectors/`: checked public vectors, schemas, and evidence fixtures.
- `Evidence/`: constant-time and compiler-lowering evidence records.
- `Scripts/`: validation, release, benchmark, estimator, reproduction, and
  evidence-generation tooling.
- `Benchmarks/`: Swift Benchmark-based performance harness.

## SwiftPM Products

- `SuperNeo_NuMetal`: library target.
- `superneo`: main CLI.
- `superneo-formal-vectors`: Swift-to-formal vector emission.
- `superneo-ct-observe`: constant-time observation tooling.
- `superneo-payperbit-eval`: pay-per-bit profile evaluation tooling.

## Quick Start

Build the CLI:

```sh
swift build --product superneo
```

Run the default completion gate:

```sh
Scripts/production-gate.sh
```

Create and verify a fold artifact:

```sh
swift run superneo prove \
  --workload one-hot \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-fold.json

swift run superneo verify /tmp/one-hot-fold.json
```

Create and verify a terminal artifact:

```sh
swift run superneo prove \
  --workload one-hot \
  --kind compressed-terminal \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-terminal.json

swift run superneo verify --require-terminal /tmp/one-hot-terminal.json
```

Run a local NumiSealZK smoke proof with explicit QRO public coins:

```sh
swift run superneo prove \
  --seal numiseal \
  --bits 0,1 \
  --qro-session-id local-product-session-v1 \
  --qro-public-coin-hex 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --max-obligations-per-aggregate 32 \
  --output /tmp/numiseal-zk-product.json

swift run superneo verify \
  --qro-session-id local-product-session-v1 \
  --qro-public-coin-hex 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  /tmp/numiseal-zk-product.json
```

Use product-control verification when validating signed context/provenance,
issued-QRO, replay, revocation, and audit inputs:

```sh
swift run superneo verify \
  --product \
  --operator-profile profile.json \
  --context-pack context.json \
  --artifact-provenance provenance.json \
  --qro-challenge-pack issued-qro.json \
  --revocation-feed revocations.json \
  /tmp/numiseal-zk-product.json
```

## Measurement Costs And Benchmarks

Benchmark rows are rendered by `Scripts/render-benchmark-report.swift` from
`benchmark-results/results.json`. Fresh local runs write to
`benchmark-results/`; checked snapshots under `Docs/BenchmarkReports/` are
release evidence only when explicitly refreshed.

The timing table records more than one cost:

- `Time`: benchmark wall-clock time.
- `GPU`: Metal command-buffer execution time when the row uses Metal.
- `Encode`, `Commit`, `Wait`: CPU-side Metal dispatch costs.
- `p95`: package-benchmark 95th percentile when present.
- `Derived`: folds/s, constraints/s, or commitments/s where the row has a
  meaningful rate.
- `Allocations`: total allocation count from the benchmark harness.

Fresh local quick measurements were regenerated on 2026-04-27 from the current
working tree. Metadata: Apple M4 MacBook Air, 24 GB RAM, macOS 26.5, Swift 6.3,
Xcode 26.4, benchmark profile `quick`, cases `m64-K1-k0-binary` and
`m256-K2-k1-binary`. The current report is `benchmark-results/report.md`.

| Surface | Row | Measurement |
| --- | --- | ---: |
| Source fold prover | `fold/cpu/m256-K2-k1-binary` | 606 ms, 1.65 folds/s, 422 constraints/s |
| Source fold prover | `fold/prepared/cpu/m256-K2-k1-binary` | 567 ms, 1.76 folds/s, 451 constraints/s |
| Source fold prover | `fold/metal/m256-K2-k1-binary` | 83 ms, 12.05 folds/s, 3084 constraints/s |
| Source fold prover | `fold/prepared/metal/m256-K2-k1-binary` | 78 ms, 12.82 folds/s, 3282 constraints/s |
| Source fold prover | `fold/cpu/m64-K1-k0-binary` | 117 ms, 8.55 folds/s, 547 constraints/s |
| Source fold prover | `fold/prepared/cpu/m64-K1-k0-binary` | 117 ms, 8.55 folds/s, 547 constraints/s |
| Source fold prover | `fold/metal/m64-K1-k0-binary` | 24 ms, 41.67 folds/s, 2667 constraints/s |
| Source fold prover | `fold/prepared/metal/m64-K1-k0-binary` | 25 ms, 40.00 folds/s, 2560 constraints/s |
| Source fold verifier | `reduceFold/cpu/m256-K2-k1-binary` | 12 ms |
| Source fold verifier | `reduceFold/cpu/m64-K1-k0-binary` | 5.44 ms |
| Terminal verifier | `terminalVerify/cpu/m256-K2-k1-binary` | 42 ms |
| Terminal verifier | `terminalVerify/cpu/m64-K1-k0-binary` | 40 ms |
| Fold stages | `stage/sumcheck`, `stage/piCCSClaims`, `stage/piRLC`, `stage/piDEC` on `m64-K1-k0-binary` | 602 us, 2.55 ms, 1.29 ms, 34 ms |
| Prepared stages | `stage/prepared/sumcheck`, `stage/prepared/piCCSClaims`, `stage/prepared/piRLC`, `stage/prepared/piDEC` on `m64-K1-k0-binary` | 556 us, 2.58 ms, 149 us, 35 ms |
| NumiSeal terminal product | `numisealProduct/prove` / `verify` on `one-hot-u2-terminal` | 278 ms / 90 ms |
| NumiSealZK product | `numisealProduct/prove` / `verify` on `one-hot-u2-zk` | 274 ms / 87 ms |
| Recursive carry child | `numisealProduct/recursiveCarry/prove` / `verify` | 291 ms / 92 ms |
| Product controls | `productControls/replayIdentity` / `auditEventEncode` | 26 us / 13.2 us |
| Ajtai commitment | `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | 48 us, 20833.33 commitments/s |
| Pay-per-bit optimized commit | `kernel/ajtaiCommit/payPerBitOptimized/cpu/m64-K1-k0-binary` | 51 us, 19607.84 commitments/s |
| Ajtai work-profile cost | `kernel/ajtaiCommit/workProfile/m64-K1-k0-binary` | 2.12 us, 470588.24 commitments/s |

Fresh fold proof-size rows from the same report:

| Case | Constraints | Proof | Envelope | Sum-check | PiCCS | PiRLC | PiDEC | Output claims |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K1-k0-binary` | 64 | 951800 B | 951941 B | 672 B | 10920 B | 11352 B | 145280 B | 152880 B |
| `m256-K2-k1-binary` | 256 | 1000120 B | 1000261 B | 880 B | 32856 B | 12248 B | 145280 B | 153328 B |

Metal fold benchmark rows now compare against a same-policy CPU oracle
(`.metalAccelerated`) and still require normal CPU verifier acceptance. Do not
compare these rows byte-for-byte against the default constant-work CPU fold:
the default and accelerated policies can produce different valid PiDEC/output
claim shapes. Other Metal kernel rows still record dispatch costs; for example
`kernel/fieldMultiply/metal/m64-K1-k0-binary` measured 2.02 ms while the CPU
field multiply row measured 458 ns, so small-kernel Metal rows remain
dispatch-bound.

Fresh local CLI artifact byte counts for the same `one-hot-u2` NumiSeal product
smoke:

- NumiSeal terminal product: `1028837 B` source-fold envelope, `244225 B`
  product proof envelope, `1728748 B` canonical artifact.
- NumiSealZK product: `1028837 B` source-fold envelope, `245435 B` product
  proof envelope, `1732166 B` canonical artifact.
- ZK overhead versus terminal in this smoke: `+1210 B` proof envelope and
  `+3418 B` canonical artifact.
- Both fresh CLI smokes reported `sourceFoldOutputClaimCount = 14` under
  `sourceDecompositionProfile = "pay-per-bit-v1"`.

Pay-per-bit measurement is split between protocol acceptance and cost-model
evidence. Product verification requires `pay-per-bit-v1`, while
`superneo-payperbit-eval` reports how fixed 14-limb decomposition compares to
pay-per-bit accounting:

```sh
swift run superneo-payperbit-eval \
  --profile full \
  --format markdown \
  --output benchmark-results/payperbit-profile-evaluation.md
```

Representative full-profile model rows:

| Case | Current slots | Padded ppb slots | Active digit slots | Padded ratio | Active ratio | Opening ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K2-k0-binary` | 1512 | 108 | 29 | 14.00x | 52.14x | 14.00x |
| `m256-K2-k0-binary` | 3780 | 270 | 129 | 14.00x | 29.30x | 14.00x |
| `m1024-K2-k0-binary` | 14364 | 1026 | 525 | 14.00x | 27.36x | 14.00x |
| `m256-K2-k1-small` | 3780 | 540 | 282 | 7.00x | 13.40x | 7.00x |

These ratios are measurement/model evidence for explicit optimized lanes. They
do not silently change high-assurance product defaults.

## Validation

Run the default build, focused smoke-test, and CLI prove/verify check:

```sh
Scripts/production-gate.sh
```

Run focused optional checks after README, docs, or evidence edits:

```sh
python3 Scripts/validate-doc-links.py
python3 Scripts/validate-product-ops-surface.py
python3 Scripts/validate-benchmark-coverage.py
python3 Scripts/validate-product-extractor-loss-accounting.py
python3 Scripts/validate-product-release-distribution-evidence.py
```

Build the formal import wall:

```sh
cd Formal
lake build SuperNeoFormal
```

Run benchmark profiles:

```sh
Scripts/run-benchmarks.sh quick
Scripts/run-benchmarks.sh scaling
Scripts/run-benchmarks.sh full
Scripts/reproduce-superneo-paper.sh quick
```

Use `quick` before performance-sensitive edits. Use `full` only when refreshing
checked benchmark evidence. Heavy CE proof and compressed-envelope rows are
opt-in:

```sh
SUPERNEO_BENCHMARK_CE=1 Scripts/run-benchmarks.sh quick
```

## Machine Evidence To Keep In Sync

Product/security behavior is evidence-parametric. Any product proof-path,
transcript, policy, schema, compression, or benchmark change should be reconciled
with the relevant manifests:

The `TestVectors/product-extractor-loss-accounting-v1.json` manifest is the
checked extractor loss accounting surface for the selected-depth product
security theorem.

- `TestVectors/numiseal-conformance-scope-v1.json`
- `TestVectors/numiseal-end-to-end-theorem-scope-v1.json`
- `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`
- `TestVectors/product-crypto-security-dossier-v1.json`
- `TestVectors/product-selected-depth-loss-accounting-v1.json`
- `TestVectors/product-extractor-loss-accounting-v1.json`
- `TestVectors/product-total-loss-budget-v1.json`
- `TestVectors/product-release-distribution-evidence-v1.json`
- `TestVectors/product-qrom-public-coin-accounting-v1.json`
- `TestVectors/product-qrom-transcript-schedule-v1.json`
- `TestVectors/product-qrom-sampler-encoding-evidence-v1.json`
- `TestVectors/product-qrom-collision-malleability-evidence-v1.json`
- `TestVectors/product-qrom-transform-preconditions-v1.json`
- `TestVectors/product-qrom-interactive-reduction-v1.json`
- `TestVectors/constant-time-scope-v1.json`
- `TestVectors/constant-time-lowering-evidence-v1.json`
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
- `TestVectors/e2e-proof-metrics-v1.json`
- `TestVectors/benchmark-coverage-v1.json`

## Human Source Of Truth

- `Docs/WhatThisProves.md`: proof semantics and claim boundaries.
- `Docs/QROProductArchitecture-2026-04-25.md`: selected product QRO path.
- `Docs/ProofEnvelope.md`: proof-envelope binding and parser rules.
- `Docs/CLI.md`: active CLI surface.
- `Docs/RoadmapStatus.md`: compact architecture and priority map.
- `Docs/ProductIntegrationLayer-2026-04-16.md`: product integration layer.
- `Docs/ProductOperationsReadiness-2026-04-16.md`: local product-control state.
- `Docs/CryptographicSecurityDossier-2026-04-16.md`: evidence-parametric
  security dossier.
- `Docs/Benchmarking.md`: benchmark commands and coverage contract.
- `Docs/BenchmarkReports/README.md`: checked benchmark report landing area.
- `Docs/GPUDeterminism.md`: Metal acceleration and trust policies.
- `Docs/ProductionReadinessAuditPacket-2026-04-16.md`: release-candidate gate
  packet.
- `Docs/SuperNeoPaperImplementationTracks-2026-04-25.md`: paper-to-repo
  implementation tracker.
- `math-audit.md` and `notes-math-ai.md`: formal audit and theorem-package
  notes.

## Claim Boundary

Repository-local claim: the checked bounded-depth evidence surface is internally
consistent for development and release-candidate use.

Not claimed: production post-quantum security, production QROM security,
whole-stack constant-time certification, hosted operations security, public
distribution assurance, general external program compilation, or independent
cryptographic and implementation review.

## Do Not Reintroduce

- Fixed-14 source-fold decomposition as the default product path.
- Product acceptance through artifact-selected Fiat-Shamir transcript seeds.
- Self-described legacy NumiSeal JSON verification.
- Silent promotion of optimized pay-per-bit, Metal, proof-compression, or
  concrete-hash lanes into high-assurance product defaults.
- Production-security wording that is not backed by the checked evidence set.
