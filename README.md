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
| Package | macOS 14+ Swift package with library product `SuperNeo_NuMetal`, CLI executable `superneo`, formal-vector helper `superneo-formal-vectors`, and constant-time observation helper `superneo-ct-observe`. |
| Proof modes | Fold reductions, terminal proofs with public CE opening material, and compressed public terminal envelopes. |
| Workloads | Bundled one-hot vector and 8-bit binary-addition CCS workloads. |
| Backends | CPU reference implementation plus selected Metal acceleration. Default routing avoids Metal on small shapes and keeps Metal as an acceleration path, not a trust oracle. |
| Assurance policies | `.highAssurance` for covered constant-work CPU paths, `.cpuRedundantMetal` for covered CPU-rechecked Metal outputs, and terminal proof acceptance policies for application verifier contexts. |
| Test vectors | Fold, terminal, and compressed-terminal artifacts with manifest-bound trusted context. |
| Benchmarks | Latest local Apple M4 quick slice is pinned under `benchmark-results/`; whole-stack row coverage is checked by `TestVectors/benchmark-coverage-v1.json`. |
| Formalization | Completed protocol theorem track, checked NumiSeal end-to-end theorem scope, checked bounded-depth product cryptographic security dossier, checked selected-depth loss accounting contract, checked extractor, QROM transcript schedule, QROM transform preconditions, QROM interactive reduction, and QROM Fiat-Shamir accounting contracts, checked total-loss budget contract, and conditional constant-trace plus Swift/LLVM/Metal lowering evidence models in Lean 4, tracked by `Docs/FormalStatus.json`, `TestVectors/numiseal-conformance-scope-v1.json`, `TestVectors/numiseal-end-to-end-theorem-scope-v1.json`, `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`, `TestVectors/product-crypto-security-dossier-v1.json`, `TestVectors/product-selected-depth-loss-accounting-v1.json`, `TestVectors/product-extractor-loss-accounting-v1.json`, `TestVectors/product-qrom-transcript-schedule-v1.json`, `TestVectors/product-qrom-transform-preconditions-v1.json`, `TestVectors/product-qrom-interactive-reduction-v1.json`, `TestVectors/product-qrom-fiat-shamir-accounting-v1.json`, `TestVectors/product-total-loss-budget-v1.json`, `TestVectors/constant-time-scope-v1.json`, `TestVectors/constant-time-lowering-evidence-v1.json`, and `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`. |
| Product ops | Local signed context/provenance/revocation feed, replay ledger, audit export, and machine-readable operations readiness status for private integration work. |

## Highlights

- Terminal application acceptance now has a reusable policy API. Callers can
  pin trusted statement context, reject fold reductions before terminal
  verification, choose terminal-only, compressed-only, or either terminal proof
  form, and set a maximum proof byte count.
- Swift/Lean conformance bridges now compare executable Swift vectors against
  Lean-emitted Ext2 and CE proof byte vectors in the production gate, with
  mutation tests for fail-closed drift detection.
- Benchmark instrumentation now splits Metal command-buffer GPU time from host
  encode, commit, and wait time so reports can distinguish device work from
  submission overhead.
- Whole-stack benchmark coverage now includes source fold proving/verifying,
  stage and kernel rows, Metal rows, NumiSeal terminal/ZK product prove/verify,
  typed recursive carry child prove/verify, and local product-control replay
  and audit encoding rows.
- The Lean formal track has a conservative tagged bad-event composition layer,
  while the full protocol theorem remains intentionally blocked on mechanized
  probability composition and Swift equivalence proofs.

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
- Terminal proof acceptance policy APIs for trusted verifier contexts, accepted
  proof-kind policy, and proof byte limits.
- R1CS-to-CCS helper surfaces for the bundled one-hot vector and binary-addition
  workloads.
- CPU reference execution plus Metal kernels for selected field, ring,
  commitment, transformed-evaluation, and fused commit/evaluation workloads.
- Adaptive Metal routing that keeps small default proofs on CPU while preserving
  forced Metal policies for large-shape acceleration, benchmark coverage, and
  kernel development.
- Differential CPU/Metal checking where both paths exist.
- Hardening around proof-envelope parsing, verifier-context binding, duplicate
  JSON keys, artifact schemas, workload metadata, key-seed domain separation,
  Metal workspace invariants, checked allocation sizes, and high-assurance
  execution policies.
- A checked constant-time source/formal scope for the first Swift Goldilocks and
  NumiSealZK Metal slices, plus a checked Swift/LLVM/Metal lowering evidence
  contract with explicit compiler/runtime/hardware boundaries and pinned local
  Swift SIL/LLVM/assembly, Metal AIR/metallib, runtime allocation-review,
  CPU/GPU observation evidence, and compiler/hardware observation lane reports.
- A checked NumiSeal end-to-end theorem scope for the current product/carry/ZK
  relation, with release evidence pinned while extractor, simulator, and QROM
  instantiations remain explicit production-security boundaries.
- Checked theorem surfaces for recursive folding knowledge soundness, typed
  carry producer/consumer composition, and NumiSealZK simulation/privacy under
  an explicit public-leakage model.
- Exact rejection-sampled field mask distribution for NumiSealZK masks, with a
  checked evidence manifest binding the sampler domain, Goldilocks acceptance
  set, rejection count, and zero statistical distance after rejection.
- A checked product cryptographic security dossier tying source fold, terminal
  NumiSeal, NumiSealZK masked residual, typed carry, transcript, artifact,
  proof-envelope, verifier-policy, and composition theorem surfaces to a
  bounded-depth product theorem while keeping QROM, post-quantum, ZK privacy,
  recursive carry, performance, and constant-time production claims disabled.
- A checked selected-depth loss accounting ledger for the current depth-1
  product claim boundary. It pins the source-fold, terminal-seal, carry,
  ZK-simulator, QROM, extractor, transcript-collision, product-ops replay,
  constant-time, and release distribution loss terms while keeping every hard
  production claim disabled.
- Checked extractor loss accounting, QROM transcript schedule, QROM transform
  preconditions, QROM interactive reduction, and QROM Fiat-Shamir accounting
  contracts in
  `TestVectors/product-extractor-loss-accounting-v1.json`,
  `TestVectors/product-qrom-transcript-schedule-v1.json`,
  `TestVectors/product-qrom-transform-preconditions-v1.json`,
  `TestVectors/product-qrom-interactive-reduction-v1.json`, and
  `TestVectors/product-qrom-fiat-shamir-accounting-v1.json`. These pin the
  extractor inputs, transcript rewind schedule, proof-kind transcript labels,
  oracle query families, transform theorem-family obligations, exact PCIP
  challenge-count formulas, the DFM20 loss multiplier, QROM symbols, and
  selected-depth formulas while keeping concrete production reduction claims
  disabled.
- A checked total-loss budget contract in
  `TestVectors/product-total-loss-budget-v1.json` that evaluates the exact
  selected-depth rational sum format, maps `epsilon_transcript_collision` into
  the ledger's `epsilon_collision` term, and refuses promotion until every
  required numeric bound is instantiated and below `2^-128`.
- A canonical local product operations readiness status exposed by
  `product-status --format json` and embedded in product audit exports.
- A required signed revocation feed for local product controls, with effective
  revocation checked before product acceptance and feed digest bound into audit
  decisions.
- Depth-1 typed recursive carry product verification in local product controls,
  with signed parent provenance, prior parent replay acceptance, recursive carry
  replay roots, and single-use carry consumption bound into SQLite replay and
  JSONL audit records.

Core profile constants are documented in [Docs/Parameters.md](Docs/Parameters.md).

## Complete Stack Snapshot

The current repository stack is:

- **Arithmetic and encoding:** Goldilocks base field, Goldilocks quadratic
  extension, Phi81 cyclotomic ring, canonical byte encodings, duplicate-key JSON
  rejection, and checked proof-envelope framing.
- **Commitment layer:** Ajtai commitments over the pinned Goldilocks/Phi81
  profile, deterministic key derivation, batch commitment paths, and CPU/Metal
  differential checks.
- **Constraint/frontend layer:** R1CS builders for checked one-hot and binary
  addition workloads, R1CS-to-CCS preparation, paper-normalization checks, and
  public-input packing.
- **Folding layer:** fold-reduction envelopes, terminal and compressed-terminal
  acceptance, CE opening proofs, transcript binding, and verifier policies that
  keep reductions separate from terminal product acceptance.
- **NumiSeal layer:** canonical obligations, lane aggregation, public statement
  roots, scalarized residual checks, terminal product artifacts, strict expected
  context pins, and a product proving API for generated R1CS programs.
- **NumiSealZK layer:** kind-5 masked digit tensor artifacts, exact
  rejection-sampled field masks, randomness-session binding, mask-reuse
  rejection, ZK proof body validation, and optional signed side-channel evidence.
- **Recursive carry layer:** typed carry statements, producer/consumer context
  binding, parent-child product carry with `typed-required` child artifacts, and
  local product controls that require signed parent provenance plus prior parent
  replay acceptance for depth-1 child acceptance.
- **Product controls:** signed trusted context packs, signed artifact provenance,
  signed revocation feeds, local operator profiles, SQLite replay, hash-chained
  JSONL audit, product status/export commands, local retry/readiness policy, and
  signed side-channel certificate checking for reviewed ZK lanes.
- **Evidence and formalization:** Lean conformance checks, Swift/Lean vector
  bridges, theorem-scope manifests, parameter/security dossiers, constant-time
  source/lowering evidence manifests, and benchmark/proof-size manifests,
  including `TestVectors/product-selected-depth-loss-accounting-v1.json`,
  `TestVectors/product-extractor-loss-accounting-v1.json`,
  `TestVectors/product-qrom-transcript-schedule-v1.json`,
  `TestVectors/product-qrom-fiat-shamir-accounting-v1.json`,
  `TestVectors/product-qrom-transform-preconditions-v1.json`,
  `TestVectors/product-qrom-interactive-reduction-v1.json`,
  `TestVectors/product-total-loss-budget-v1.json`, and
  `TestVectors/benchmark-coverage-v1.json`.
- **Acceleration:** CPU reference path, Metal kernels for selected field/ring
  and NumiSeal workloads, adaptive routing, redundant CPU/Metal checking, and
  pinned Metal workspace evidence for side-channel review.
- **Benchmarking and budgets:** quick/full benchmark profiles, metadata-aware
  baseline comparison, report rendering, proof-size budgets, NumiSeal product
  smoke budgets, and a checked whole-stack benchmark coverage manifest.

Still intentionally not claimed as complete production security: hosted product
operations, selected-depth loss accounting is contracted but not fully
instantiated, extractor loss accounting, QROM transcript schedule, QROM
transform preconditions, QROM interactive reduction, and QROM Fiat-Shamir
accounting are contracted but not numerically instantiated, the
total-loss budget is checked but still missing every required numeric term,
full ZK simulator composition,
release signing/notarized distribution, and CPU/Swift/LLVM/Metal constant-time
evidence closure for every production hardware lane.

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
For checked NumiSeal artifacts, `SuperNeoNumiSealProductVerifier` provides a
protocol-based integration facade for those product-owned hooks.

A fold reduction verifies the public reduction and returns output
commitment-evaluation claims. Callers that need terminal acceptance should
verify a terminal or compressed-terminal proof and require terminal proof kind
at the policy boundary. `SuperNeoTerminalProofAcceptancePolicy` also lets
applications restrict accepted terminal envelope forms and reject oversized
proof bytes before the expensive verifier path.

Current boundaries:

- no production deployment certification,
- no general compiler from programs to CCS,
- no deployed persistence layer, durable replay-protection system, or
  user-facing verification product,
- no production zero-knowledge claim for arbitrary application statements,
- no production hardware constant-time certificate for Swift/LLVM/Metal
  lowering and selected CPU/GPU lanes, and
- no completed production-security concrete Swift extractor implementation,
  numeric extractor loss bound, simulator coupling beyond the exact field-mask
  distribution lemma, side-channel privacy evidence, QROM theorem
  instantiation, numeric QROM loss bound, selected total-loss budget closure,
  or product-level post-quantum parameter dossier that clears the conservative
  sensitivity rows.

The concise proof semantics are documented in
[Docs/WhatThisProves.md](Docs/WhatThisProves.md), and the operational threat
model is documented in [Docs/ThreatModel.md](Docs/ThreatModel.md). The current
release-gate evidence and remaining production no-go items are collected in
[Docs/ProductionReadinessAuditPacket-2026-04-16.md](Docs/ProductionReadinessAuditPacket-2026-04-16.md).
Release discipline and public artifact compatibility are tracked in
[Docs/ReleaseEngineering-2026-04-16.md](Docs/ReleaseEngineering-2026-04-16.md)
and [Docs/SchemaCompatibility-2026-04-16.md](Docs/SchemaCompatibility-2026-04-16.md).
The NumiSeal product-integration facade is recorded in
[Docs/ProductIntegrationLayer-2026-04-16.md](Docs/ProductIntegrationLayer-2026-04-16.md).
The product cryptographic theorem dossier is tracked in
[Docs/CryptographicSecurityDossier-2026-04-16.md](Docs/CryptographicSecurityDossier-2026-04-16.md).
Release candidates should follow
[Docs/ReleaseCandidateRunbook-2026-04-16.md](Docs/ReleaseCandidateRunbook-2026-04-16.md)
and record user-facing changes in [CHANGELOG.md](CHANGELOG.md).

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

Validate the checked proof-size and product-smoke budgets:

```sh
Scripts/validate-e2e-proof-metrics.py
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

Inspect and verify a checked NumiSeal terminal vector through the main
`superneo` verifier surface:

```sh
swift run superneo inspect TestVectors/numiseal-terminal-single-aggregate-v1.json
swift run superneo verify \
  --require-numiseal \
  TestVectors/numiseal-terminal-single-aggregate-v1.json
```

NumiSeal artifacts are verifier-only in `superneo`; omitting
`--require-numiseal` fails closed so kind `4` envelopes cannot be accepted by
legacy terminal policy by accident.

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

For NumiSeal terminal artifacts, use `--require-numiseal` and additionally pin
the transcript-domain, public-statement, obligation-root, lane-summary-root,
aggregate, component-root, and proof-transcript digests when the artifact comes
from another party. The production CLI and vector validator share the library
`NumiSealArtifactVerifier` core for those NumiSeal artifact checks.

Without trusted context arguments, the verifier reads the seed and digests from
the artifact itself, which is useful for demos but not a policy decision. The
proof envelope binds proof bytes to profile ID, proof kind, CCS shape digest,
statement digest, verifier-key digest, transcript domain, and body length. See
[Docs/ProofEnvelope.md](Docs/ProofEnvelope.md).

Library integrations should prefer a terminal acceptance policy over manual
proof-kind dispatch:

```swift
let policy = SuperNeoTerminalProofAcceptancePolicy(
    publicInput: publicInput,
    verifierKeyDigest: key.verifierKeyDigest,
    proofKindPolicy: .compressedOnly,
    maximumProofByteCount: 4 * 1024 * 1024
)

let result = verifier.verifyTerminalProofEnvelope(
    publicInput: publicInput,
    proofBytes: proofBytes,
    policy: policy
)
```

Use `.terminalOrCompressed` when both complete terminal envelope forms are
acceptable. Use `.terminalOnly` or `.compressedOnly` when resource policy,
artifact policy, or deployment compatibility requires one form.

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
machine-readable artifact schema. NumiSeal uses
`TestVectors/numiseal-manifest.json` plus
`TestVectors/numiseal-artifact.schema.json`, with schema and manifest mutation
checks in the production gate.
`TestVectors/e2e-proof-metrics-v1.json` pins exact checked-vector proof-envelope
bytes and generated product-smoke size budgets without adding certificate or
metrics material to proof bytes.
`TestVectors/product-selected-depth-loss-accounting-v1.json` pins the
selected-depth loss accounting contract for the current depth-1 product
security boundary while keeping extractor, QROM, simulator, hosted-ops,
release-signing, and CT evidence claims disabled.
`TestVectors/product-extractor-loss-accounting-v1.json` pins the extractor
loss accounting contract for source-fold extraction, terminal-seal extraction,
product-envelope composition, and future recursive carry extraction.
`TestVectors/product-qrom-fiat-shamir-accounting-v1.json` pins QROM
Fiat-Shamir accounting for fold, terminal, compressed-terminal, NumiSeal
terminal, and NumiSealZK product transcript interfaces.
`TestVectors/product-qrom-transcript-schedule-v1.json` pins the QROM
transcript schedule for fold, terminal, compressed-terminal, NumiSeal terminal,
and NumiSealZK product proof kinds, including public challenge labels and
symbolic quantum random-oracle query families.
`TestVectors/product-qrom-transform-preconditions-v1.json` pins the QROM
transform precondition dossier for the selected fail-closed measure-and-reprogram
profile, including theorem-family fit, interactive protocol, round schedule,
uniform challenges, transcript encoding, query-bound, and reduction-loss
obligations.
`TestVectors/product-qrom-interactive-reduction-v1.json` pins the exact
public-coin interactive protocol formulas, selected `Q_H = 2^64` policy, DFM20
`((2*Q_H+n+1)^(2n)/n!)` multiplier, and per-proof-kind open loss inputs; it
still blocks production QROM claims until NumiSeal numeric challenge maxima,
sampler uniformity proofs, and interactive security bounds are instantiated.
`TestVectors/product-total-loss-budget-v1.json` pins the total-loss budget
contract, exact rational summation rule, required selected-depth component
bounds, and the mapping that keeps transcript collision out of the core
`epsilon_qrom` term and into the ledger's `epsilon_collision` term.
`TestVectors/benchmark-coverage-v1.json` pins the benchmark row families that
must remain registered, rendered, baseline-comparable, and production-gated for
the source fold, kernels, Metal, NumiSeal product, recursive carry, and product
controls.

```sh
swift Scripts/validate-test-vectors.swift
```

See [TestVectors/README.md](TestVectors/README.md) for reconstruction rules and
schema expectations.

## Benchmarks

Benchmark results are meaningful only with the documented correctness gates.
The benchmark runner verifies protocol outputs before exporting results and
compares CPU/Metal outputs where both paths exist.

Current performance highlights:

- Default execution uses automatic Metal routing and keeps small shapes on CPU;
  use `.metalAccelerated` when a caller wants to force GPU work for a known
  workload or benchmark row.
- Generated benchmark reports now include a GPU command-buffer column for Metal
  rows plus Metal encode, commit, and wait wall-time columns for host-side
  submission visibility.
- The latest Metal audit pass removed duplicate workspace CSR uploads, added
  scratch-buffer reuse and inline dispatch parameters, introduced a
  coefficient-parallel ring-multiply kernel, and added a narrow Ajtai
  small-message coefficient kernel for decomposition-sized messages.
- The row-partial sparse transformed-evaluation schedule is available for
  tuning but remains opt-in because the local small-shape A/B run was slower
  than the blocked baseline.
- Quick benchmark coverage now includes NumiSeal terminal product prove/verify,
  NumiSealZK product prove/verify, typed recursive carry child prove/verify,
  replay identity construction, and product audit-event encoding. The coverage
  contract is checked by `TestVectors/benchmark-coverage-v1.json` and
  `Scripts/validate-benchmark-coverage.py`.

Latest local benchmark snapshot:

| Field | Value |
| --- | --- |
| Generated | `2026-04-16T22:33:05Z` |
| Source commit | `6d0a85f` |
| Source state | dirty |
| Host | MacBook Air, Apple M4, 10 CPU cores, 24 GB memory |
| Toolchain | Swift 6.3, Xcode 26.4 |
| OS | macOS 26.5 build `25F5042g` |
| Profile | `quick` |
| Case filter | none |
| Metal device | Apple M4 |

Proof sizes for the latest quick cases:

| Case | Constraints | Proof | Envelope | Sum-check | PiCCS | PiRLC | PiDEC | Output claims |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K1-k0-binary` | 64 | 321,128 B | 321,269 B | 672 B | 10,920 B | 11,352 B | 145,280 B | 152,880 B |
| `m256-K2-k1-binary` | 256 | 344,616 B | 344,757 B | 880 B | 32,856 B | 12,248 B | 145,280 B | 153,328 B |

Selected timing rows from the same run:

| Row | Time | Derived rate |
| --- | ---: | ---: |
| `fold/cpu/m256-K2-k1-binary` | 19 ms | 52.63 folds/s, 13,474 constraints/s |
| `fold/metal/m256-K2-k1-binary` | 58 ms | 17.24 folds/s, 4,414 constraints/s |
| `fold/prepared/cpu/m256-K2-k1-binary` | 20 ms | 50.00 folds/s, 12,800 constraints/s |
| `fold/prepared/metal/m256-K2-k1-binary` | 33 ms | 30.30 folds/s, 7,758 constraints/s |
| `stage/sumcheck/m64-K1-k0-binary` | 231 us |  |
| `stage/piCCSClaims/m64-K1-k0-binary` | 274 us |  |
| `stage/piRLC/m64-K1-k0-binary` | 284 us |  |
| `stage/piDEC/m64-K1-k0-binary` | 1.23 ms |  |
| `reduceFold/cpu/m256-K2-k1-binary` | 1.79 ms |  |
| `terminalVerify/cpu/m256-K2-k1-binary` | 3.58 ms |  |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 7.97 ms |  |
| `kernel/ajtaiCommit/batch/cpu/m64-K1-k0-binary` | 677 us | 1,477.10 commitments/s |
| `kernel/ajtaiCommit/batch/metal/m64-K1-k0-binary` | 1.84 ms | 542.89 commitments/s |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 22 us |  |
| `kernel/transformedEvaluation/metalSparse/m64-K1-k0-binary` | 4.38 ms |  |
| `numisealProduct/prove/cpu/one-hot-u2-terminal` | 174 ms |  |
| `numisealProduct/verify/cpu/one-hot-u2-terminal` | 59 ms |  |
| `numisealProduct/prove/cpu/one-hot-u2-zk` | 176 ms |  |
| `numisealProduct/verify/cpu/one-hot-u2-zk` | 65 ms |  |
| `numisealProduct/recursiveCarry/prove/cpu/one-hot-u2-child` | 176 ms |  |
| `numisealProduct/recursiveCarry/verify/cpu/one-hot-u2-child` | 62 ms |  |
| `productControls/replayIdentity/cpu/recursive-carry` | 23 us |  |
| `productControls/auditEventEncode/cpu/recursive-carry` | 12.6 us |  |

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

Compare executable Swift formal vectors against Lean-emitted vectors:

```sh
Scripts/compare-formal-ext2-vectors.py
Scripts/compare-formal-ce-vectors.py
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
- [Application Acceptance Policy](Docs/ApplicationAcceptancePolicy-2026-04-14.md)
- [Product Integration Layer](Docs/ProductIntegrationLayer-2026-04-16.md)
- [CLI](Docs/CLI.md)
- [Benchmarking](Docs/Benchmarking.md)
- [GPU Determinism](Docs/GPUDeterminism.md)
- [Formal Verification](Docs/FormalVerification.md)
- [Paper Reproduction](Docs/PaperReproduction.md)
- [Lattice Estimator Reproduction](Docs/LatticeEstimatorReproduction.md)
- [Roadmap Status](Docs/RoadmapStatus.md)

Recent implementation and hardening notes:

- [Benchmark Metadata Comparison, 2026-04-14](Docs/BenchmarkMetadataComparison-2026-04-14.md)
- [Application Acceptance Policy, 2026-04-14](Docs/ApplicationAcceptancePolicy-2026-04-14.md)
- [PiRLC Benchmark Isolation, 2026-04-14](Docs/BenchmarkPiRLCIsolation-2026-04-14.md)
- [Opening Batch Parallel Threshold, 2026-04-14](Docs/BenchmarkOpeningBatchThreshold-2026-04-14.md)
- [Relation Evaluation Plan, 2026-04-14](Docs/BenchmarkRelationEvaluationPlan-2026-04-14.md)
- [Sum-Check Prior-Claim Evaluation Batch, 2026-04-14](Docs/BenchmarkSumcheckPriorBatch-2026-04-14.md)
- [Sum-Check Public Precompute Cleanup, 2026-04-14](Docs/BenchmarkSumcheckPublicPrecompute-2026-04-14.md)
- [Transformed Evaluation Fusion, 2026-04-14](Docs/BenchmarkTransformedEvaluationFusion-2026-04-14.md)
- [Metal Performance Optimization, 2026-04-14](Docs/MetalPerformanceOptimization-2026-04-14.md)
- [Binary Addition Terminal Vector, 2026-04-14](Docs/BinaryAdditionTerminalVector-2026-04-14.md)
- [Compressed Terminal Vector, 2026-04-14](Docs/CompressedTerminalVector-2026-04-14.md)
- [Vector Manifest Duplicate Key Hardening, 2026-04-14](Docs/VectorManifestDuplicateKeyHardening-2026-04-14.md)

Detailed dated notes for artifact parsing, workload canonicality, key-seed
domain separation, terminal vectors, Ajtai keys, benchmark passes, and formal
promotion are kept under [Docs](Docs).
