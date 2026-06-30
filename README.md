# SuperNeo NuMetal

SuperNeo NuMetal is a Swift and Metal research implementation of the SuperNeo
folding stack over the `Goldilocks/Phi81(d=54)` profile. The repository contains
the Swift prover/verifier, NumiSeal product proof paths, proof-envelope and
compression experiments, Metal acceleration lanes, verifier-negative tests,
stable proof vectors, malformed-artifact fuzzing, and a Lean 4 formal track
under `Formal/`.

The repository-local status is: active cryptographic implementation research.
This is not an independently audited production SNARK, a release-candidate
packet, or a production post-quantum security claim.

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
- Product-control verification accepts only `proofKind = "numiseal-zk"`, requires
  signed trusted context/provenance/QRO material, requires the trusted context
  key seed, and rejects unbound source application context.
- Product verification uses the explicit QRO public-coin architecture described
  in `Docs/QROProductArchitecture-2026-04-25.md`.
- Artifact-selected transcript seeds and legacy self-described NumiSeal JSON
  are not product acceptance paths.
- Signed issued-QRO packs bind trusted context, provenance inputs, verifier key,
  public inputs, transcript domain, issue window, and single-use replay policy.
- Product-context verification binds replay/audit state, CTCO roots, QRO/QROM
  transcript metadata, carry context, aggregate digests, and proof transcript
  digests.
- Billable usage is intentionally separate from local proof acceptance. See
  `Docs/BusinessRevenueModel.md` and
  `SuperNeo-NuMetal/ProductIntegration/ProductRevenueLogic.swift`.

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

### Formal And Attack Track

- Lean sources under `Formal/` cover the repository model: transcript
  well-formedness, typed digest domains, proof-envelope binding, Phi81/Goldilocks
  surfaces, PiCCS/PiRLC/PiDEC soundness surfaces, terminal CE accounting,
  NumiSeal typed carry, QRO/QROM ledgers, and the product theorem wiring.
- `TestVectors/` contains checked public vectors and fixtures for wire-format
  compatibility, verifier behavior, and regression testing.
- `Scripts/fuzz-malformed-artifacts.sh`, `Scripts/test-slice.sh attack`, and
  `Scripts/regenerate-test-vectors.sh` are the preferred checks when touching
  verifier acceptance, canonical serialization, or transcript binding.
- `Scripts/check-smoke.sh` is the only daily smoke check. Historical policy,
  wording, and evidence gates are quarantined under `Scripts/legacy-gates/`.

## Repository Map

- `SuperNeo-NuMetal/`: Swift library implementation, protocol paths, proof
  compression, serialization, product integration, and Metal backend.
- `SuperNeoCLI/`: `superneo` development and product-smoke CLI.
- `SuperNeo-NuMetalTests/`: protocol, product, compression, verifier-negative,
  policy, and Metal differential tests.
- `Formal/`: Lean 4 formal workspace.
- `Docs/`: active construction, proof semantics, threat model, parameter,
  transcript, and security-boundary notes.
- `TestVectors/`: checked public vectors, schemas, and evidence fixtures.
- `Evidence/`: constant-time and compiler-lowering evidence records.
- `Scripts/`: smoke, benchmark, estimator, reproduction, and attack-oriented
  development tooling.
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

Run the default smoke check:

```sh
Scripts/check-smoke.sh
```

Run the active crypto-development attack bundle:

```sh
Scripts/check-crypto-dev.sh
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

## Measurement Costs And Benchmarks

Benchmark rows are rendered by `Scripts/render-benchmark-report.swift` from
`benchmark-results/results.json`. Fresh local runs write to
`benchmark-results/`; old checked snapshots live under
`Docs/Archive/compliance/BenchmarkReports/` for reference only.

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
  proof envelope, `1730112 B` canonical artifact.
- ZK overhead versus terminal in this smoke: `+1210 B` proof envelope and
  `+1364 B` canonical artifact.
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

## Daily Check

Run the default build, focused smoke-test, and CLI prove/verify check:

```sh
Scripts/check-smoke.sh
```

The smoke check is intentionally small. It verifies that the package builds,
the fast unit slice passes, a tiny proof verifies, and checked JSON vectors
still parse. It is not a release gate.

For release-candidate checks, use `Scripts/check-release-candidate.sh`. It runs
the smoke path, malformed-artifact fuzzing, attack tests, supported completion
slice, and product/revenue regression tests. It is still not a substitute for
external cryptographic review or hosted-operations validation.

Historical policy, wording, release-readiness, QROM, conformance, benchmark,
and evidence scripts live in `Scripts/legacy-gates/`. They are retained for
reference, but they do not block development.

Run malformed-artifact fuzzing when touching serialization or verifier code:

```sh
Scripts/check-crypto-dev.sh
Scripts/fuzz-malformed-artifacts.sh
Scripts/test-slice.sh attack
```

The fuzzer generates one valid tiny proof, mutates artifact metadata and proof
envelope bytes, and requires the CLI verifier to reject every mutant.

Regenerate the active public proof vectors when changing artifact format,
statement binding, transcript layout, or proof generation:

```sh
Scripts/regenerate-test-vectors.sh
Scripts/regenerate-test-vectors.sh --check
Scripts/regenerate-test-vectors.sh --write
```

The default mode writes regenerated vectors to a temporary directory and verifies
them. Use `--check` to compare regenerated bytes with the checked vectors, and
`--write` only when intentionally refreshing `TestVectors/`.

## Crypto Development Focus

Start with `Docs/PrimitiveSpec.md` when changing protocol behavior. It is the
short working spec for the primitive, statement binding, transcript design, and
canonical serialization.

Prefer checks that directly catch broken cryptography or implementation bugs:

- negative verifier tests,
- malformed proof fuzzing,
- stable test-vector generation,
- transcript/domain-separation review,
- canonical serialization tests,
- parameter-set review,
- constant-time code-shape review,
- prover/verifier simplification.

Rule for new checks: if a check does not directly catch a broken proof, broken
verifier, bad encoding, bad parameter, or side-channel hazard, it must not block
development.

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

Use `quick` before performance-sensitive edits. Benchmark comparisons warn by
default; use `SUPERNEO_BENCHMARK_COMPARE_FAIL_ON_REGRESSION=1` only for an
explicit release or performance-investigation run. Heavy CE proof and
compressed-envelope rows are opt-in:

```sh
SUPERNEO_BENCHMARK_CE=1 Scripts/run-benchmarks.sh quick
```

## Human Source Of Truth

- `Docs/WhatThisProves.md`: proof semantics and claim boundaries.
- `Docs/PrimitiveSpec.md`: concise construction and attack-surface spec.
- `Docs/ThreatModel.md`: assets, adversary model, and explicit non-goals.
- `Docs/Parameters.md`: selected parameter profile and estimator pointers.
- `Docs/QROProductArchitecture-2026-04-25.md`: selected product QRO path.
- `Docs/ProofEnvelope.md`: proof-envelope binding and parser rules.
- `Docs/CLI.md`: active CLI surface.
- `Docs/RoadmapStatus.md`: compact architecture and priority map.
- `Docs/ProductIntegrationLayer-2026-04-16.md`: product integration layer.
- `Docs/GPUDeterminism.md`: Metal acceleration and trust policies.
- `Docs/CryptographicSideChannelAudit-2026-04-25.md`: constant-time/code-shape
  review notes.
- `Docs/Benchmarking.md`: benchmark commands; reporting only, not a development
  gate.
- `Docs/Archive/compliance/`: old release, dossier, conformance, benchmark, and
  product-control evidence material kept for reference only.
- `Docs/SuperNeoPaperImplementationTracks-2026-04-25.md`: paper-to-repo
  implementation tracker.
- `math-audit.md` and `notes-math-ai.md`: formal audit and theorem-package
  notes.

## Claim Boundary

Repository-local claim: the implementation has a defined primitive surface,
explicit statement/transcript binding, focused verifier-negative tests, stable
proof vectors, and malformed-artifact fuzzing for the active verifier path.

Not claimed: production post-quantum security, production QROM security,
whole-stack constant-time certification, hosted operations security, public
distribution assurance, general external program compilation, or independent
cryptographic and implementation review.

## Do Not Reintroduce

- Fixed-14 source-fold decomposition as the default product path.
- Product acceptance through artifact-selected Fiat-Shamir transcript seeds.
- Self-described legacy NumiSeal JSON verification.
- Product-control acceptance of fold, terminal, compressed-terminal, or
  NumiSeal-terminal artifacts.
- Silent promotion of optimized pay-per-bit, Metal, proof-compression, or
  concrete-hash lanes into high-assurance product defaults.
- Production-security wording that is not backed by the checked evidence set.
