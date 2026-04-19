# Schema Compatibility Policy, 2026-04-16

This document defines compatibility rules for public SuperNeo artifact surfaces.
It covers JSON proof artifacts, vector manifests, NumiSeal artifacts, NumiSeal
manifests, and binary proof envelopes.

## Current Public Versions

| Surface | Current version |
| --- | --- |
| R1CS/vector JSON artifact | `artifactVersion = 1` |
| R1CS/vector JSON Schema | `test-vector-artifact-v1.json` |
| R1CS/vector manifest | `manifestVersion = 1` |
| NumiSeal JSON artifact | `artifactVersion = 1` |
| NumiSeal JSON Schema | `numiseal-test-vector-artifact-v1.json` |
| NumiSeal product JSON artifact | `artifactVersion = 2` |
| NumiSeal product JSON Schema | `numiseal-product-artifact-v2.schema.json` |
| NumiSeal manifest | `manifestVersion = 1` |
| NumiSeal end-to-end theorem scope manifest | `schemaVersion = 1` |
| NumiSealZK mask-distribution evidence manifest | `schemaVersion = 1` |
| NumiSealZK simulator-coupling evidence manifest | `schemaVersion = 1` |
| Product cryptographic security dossier manifest | `schemaVersion = 1` |
| Product selected-depth loss accounting manifest | `schemaVersion = 1` |
| Product Swift trace/extractor evidence manifest | `schemaVersion = 1` |
| Product extractor loss accounting manifest | `schemaVersion = 1` |
| Product QROM Fiat-Shamir accounting manifest | `schemaVersion = 1` |
| Product QROM transcript schedule manifest | `schemaVersion = 1` |
| Product QROM sampler/encoding evidence manifest | `schemaVersion = 1` |
| Product QROM collision/malleability evidence manifest | `schemaVersion = 1` |
| Product QROM CTCO instantiation manifest | `schemaVersion = 1` |
| Product QROM transform preconditions manifest | `schemaVersion = 1` |
| Product QROM interactive reduction manifest | `schemaVersion = 1` |
| Product total-loss budget manifest | `schemaVersion = 1` |
| Product release distribution evidence manifest | `schemaVersion = 1` |
| Constant-time source/formal scope manifest | `schemaVersion = 1` |
| Constant-time Swift/LLVM/Metal lowering evidence manifest | `schemaVersion = 1` |
| Constant-time release evidence manifest | `schemaVersion = 1` |
| E2E proof metrics manifest | `schemaVersion = 1` |
| Benchmark coverage manifest | `schemaVersion = 1` |
| Proof envelope header | `ProofEnvelopeHeader.version = 5` |
| NumiSeal proof envelope kind | `4` |

## Compatibility Rules

- Public artifact parsers must reject unknown top-level JSON keys unless a new
  artifact version explicitly allows them.
- Public artifact parsers must reject duplicate JSON object keys before normal
  decoding.
- Public manifest validators must reject unknown manifest keys, duplicate vector
  entries, duplicate strict commands, missing checked coverage, and
  unmanifested checked vector files.
- Changing the meaning, requiredness, digest binding, or verification semantics
  of an existing field requires a new artifact version.
- Adding a new proof envelope kind does not require a new envelope version when
  the versioned header semantics are unchanged, but parsers must fail closed on
  unsupported kinds.
- Changing header layout, transcript binding, digest framing, or body-length
  semantics requires a new `ProofEnvelopeHeader.version`.
- Deterministic test-vector seeds must not be reused as production randomness
  policy.

## R1CS/Vector Artifact Policy

Version `1` is fixed to the checked one-hot and binary-addition workload
families. It accepts proof kinds:

- `fold`,
- `terminal`,
- `compressed-terminal`.

Production verifiers must pin trusted public inputs, verifier-key digest, shape
digest, statement digest, and proof-kind policy outside the artifact.

## NumiSeal Artifact Policy

Version `1` is fixed to the checked immediate-residual NumiSeal artifact family.
It accepts only:

- `proofKind = "numiseal-terminal"`,
- `residualMode = "immediate"`,
- `keyColumnCount = 2`,
- `publicInputCount = 54`,
- `privateWitnessCount = 10`.

Production verifiers must pin trusted key seed or verifier-key digest, shape
digest, statement digest, transcript-domain digest, public-statement digest,
obligation root, lane-summary root, aggregate digests, component digest root,
proof-transcript digest, and public inputs outside the artifact.

The shared `NumiSealArtifactVerifier` is the compatibility boundary for
metadata validation, public-obligation reconstruction, policy construction,
envelope checks, expected-context checks, and verifier dispatch.

Version `2` is the public NumiSeal product wrapper. It accepts only:

- `proofKind = "numiseal-terminal"` with `sealMode = "numiseal-terminal-v2"`
  and `zkMode = "none"`, or
- `proofKind = "numiseal-zk"` with `sealMode = "numiseal-zk-v1"` and
  `zkMode = "masked-digit-tensor-v1"`,
- a source fold-reduction envelope,
- a NumiSeal terminal or NumiSealZK envelope,
- source fold output-claim digests,
- NumiSeal public statement roots and aggregate digests,
- explicit `carryMode`, `zkMode`, `metalMode`, and `executionPolicy` metadata.

Version `2` must not accept caller-supplied digit tensors. The product prover
derives NumiSeal digit tensors internally from aggregate witness material. The
artifact is verified by reducing the source fold envelope first, rebuilding
output-claim digests, rebuilding NumiSeal obligations, then verifying either the
NumiSeal terminal envelope or the outer NumiSealZK envelope with embedded base
terminal proof acceptance.

`NumiSealZK` uses proof-envelope kind `5` and body version `13`, not product
artifact version `2` by default. The kind `5` body carries
`zkMode = "masked-digit-tensor-v1"`, a randomness-session digest,
declared-leakage digest, embedded kind `4` base proof body, mask statements,
masked residual statements, component root, and transcript digest. Masked
residual statement version `2` adds an accumulation-challenge digest derived
from the lane proof, mask statement, and accumulation weights. Kind `5`
verification parses `NumiSealZKProofEnvelope`, checks mask-statement/session
binding and masked residual bindings, recomputes the accumulation-challenge
binding and public equality-weight digest, then re-envelopes the embedded base
proof as kind `4` for existing NumiSeal terminal acceptance. Public product
artifacts default to `zkMode = "masked-digit-tensor-v1"`; callers may request
`zkMode = "none"` for non-ZK terminal artifacts while side-channel privacy
claims remain outside proof bytes and product verification. Deployment owners
can keep side-channel evidence as release metadata while private development
continues without certificate checks in proof acceptance.

The side-channel certificate is not part of artifact schema v2. It is separate
signed product-control evidence so artifact bytes, provenance bytes, and
certificate bytes can be revoked and rotated independently. The certificate
binds context ID, release build digest, proof kind, seal mode, ZK mode, Metal
mode, execution policy, declared leakage digest, ZK body versions, Metal
workspace feature digest, reviewed kernels/stages, and evidence digests.

`TestVectors/numiseal-conformance-scope-v1.json` is the checked NumiSeal
product/carry/ZK conformance-scope manifest. It is not a proof artifact schema;
it pins which implementation files, conformance vectors, and focused tests are
inside the current NumiSeal theorem and vector-promotion scope.

`TestVectors/numiseal-end-to-end-theorem-scope-v1.json` is the checked NumiSeal
end-to-end theorem scope manifest. It is not a proof artifact schema and does
not affect proof bytes. It pins the Lean modules, relation components, theorem
surfaces, conformance vectors, and promotion rule for the current
evidence-parametric NumiSeal product/carry/ZK theorem, including recursive
folding knowledge soundness, typed carry producer/consumer composition, and
NumiSealZK simulation/privacy under the declared public-leakage model.

`TestVectors/numiseal-zk-mask-distribution-evidence-v1.json` is the checked
NumiSealZK mask-distribution evidence manifest. It is not a proof artifact
schema and does not affect proof bytes. It pins the exact rejection-sampled
field mask distribution used by `NumiSealZKMaskSampler`, including the mask
expansion domain, 64-bit candidate space, Goldilocks modulus, rejection count,
zero statistical distance after rejection, public-leakage binding, and the
promotion boundary that keeps broader ZK privacy claims evidence-parametric.

`TestVectors/product-crypto-security-dossier-v1.json` is the checked product
cryptographic security dossier manifest. It is not a proof artifact schema and
does not affect proof bytes. It pins the bounded-depth product security
theorem, `ProductSecurityTheorem` import surface, source fold relation,
NumiSeal terminal relation, NumiSealZK masked residual relation, typed
recursive carry relation, transcript binding, artifact/proof-envelope binding,
verifier acceptance policy, Module-SIS parameter dossier, Fiat-Shamir/QROM
position, proof-size/latency boundary, implementation-hardening boundary, and
promotion rule that enables repository-local product-security, recursive carry,
ZK privacy, performance, constant-time, and release-distribution claims.

`TestVectors/product-selected-depth-loss-accounting-v1.json` is the checked
selected-depth loss accounting manifest. It is not a proof artifact schema and
does not affect proof bytes. It pins the selected-depth loss expression,
recursive-promotion loss expression, source-fold, terminal-seal, carry,
proof-level ZK simulator loss, QROM, extractor, transcript collision, product-ops replay,
constant-time, and release-distribution loss terms, and the promotion rule that
enables repository-local product-security and recursive carry claims once all
required selected-depth terms are instantiated and inside budget.

`TestVectors/product-extractor-loss-accounting-v1.json` is the checked product
extractor loss accounting manifest. It is not a proof artifact schema and does
not affect proof bytes. It pins source-fold extractor, terminal-seal extractor,
product-envelope composition extractor, future recursive carry extractor,
accepted input bindings, deterministic replay model, and the promotion rule
that allows the selected-depth extractor claim and repository-local product
security promotion while keeping promoted-depth carry extraction gated.

`TestVectors/product-qrom-fiat-shamir-accounting-v1.json` is the checked
Product QROM Fiat-Shamir accounting manifest. It is not a proof artifact schema
and does not affect proof bytes. It pins proof-kind transcript interfaces,
challenge families, domain separation, QROM loss symbols, the mapping from
`epsilon_transcript_collision` to the ledger's `epsilon_collision`, and the
promotion rule that enables production QROM claims from the checked CTCO
split-QRO accounting. Per-kind interactive security and proof-level NumiSealZK
simulator coupling are exported outside `epsilon_qrom` by checked evidence.

`TestVectors/product-qrom-transcript-schedule-v1.json` is the checked Product
QROM transcript schedule manifest. It is not a proof artifact schema and does
not affect proof bytes. It pins proof-kind order, envelope kinds, public
challenge labels, transcript bindings, symbolic quantum random-oracle query
families, per-kind protocol challenge-derivation maxima, the conditional
`Q_H = 2^64` query cap, and the promotion rule that enables production QROM
claims for the checked CTCO transcript schedule. Per-kind interactive security
and proof-level NumiSealZK simulator coupling are exported outside
`epsilon_qrom` by checked evidence.

`TestVectors/product-qrom-sampler-encoding-evidence-v1.json` is the checked
Product QROM sampler/encoding evidence manifest. It is not a proof artifact
schema and does not affect proof bytes. It pins exact rejection-sampling
arithmetic for Goldilocks, Ext2, Phi81, terminal CE ternary, and NumiSealZK
masked-residual challenges under the QRO abstraction, plus structured
64-bit-length-prefixed transcript frame encoding. The Lean theorem path uses
the well-formed transcript object and 384-bit theorem-critical binding digests.
The promotion rule enables production QROM claims for this checked encoding
surface.

`TestVectors/product-qrom-collision-malleability-evidence-v1.json` is the
checked Product QROM collision/malleability evidence manifest. It is not a
proof artifact schema and does not affect proof bytes. It pins accepted
proof-kind separation, proof-envelope transcript-binding injectivity,
transcript-domain enforcement, proof-kind acceptance policy,
artifact/provenance digest binding, product replay identity, NumiSeal component
root binding, and typed carry replay binding. The promotion rule enables
production QROM claims for the checked collision and malleability surface.

`TestVectors/product-qrom-transform-preconditions-v1.json` is the checked
Product QROM transform preconditions manifest. It is not a proof artifact
schema and does not affect proof bytes. It pins primary QROM Fiat-Shamir
source references, the legacy fail-closed measure-and-reprogram diagnostic
profile, proof-kind theorem-family fit, CTCO/Merkle-straightline replacement
target, precondition rows, symbolic loss interface, delayed-message and
unique-response CTCO data, and the promotion rule that enables production QROM
claims for the checked transform precondition surface.

`TestVectors/product-qrom-interactive-reduction-v1.json` is the checked
Product QROM interactive reduction manifest. It is not a proof artifact schema
and does not affect proof bytes. It pins public-coin protocol formulas, the
selected `Q_H = 2^64` policy, DFM20 reduction multiplier, per-proof-kind
challenge-count formulas, selected-depth protocol challenge-derivation budget,
and the production QROM promotion rule. The DFM20 row is retained as a legacy
diagnostic; the active theorem path is split-oracle CTCO or Merkle-straightline
with 384-bit binding digests.

`TestVectors/product-total-loss-budget-v1.json` is the checked product
total-loss budget manifest. It is not a proof artifact schema and does not
affect proof bytes. It pins exact rational selected-depth summation,
`2^-128` budget threshold, eleven component bounds, ten required selected-depth
terms, shared-core bad-event deduplication, and the promotion rule that enables
production total-loss and product-security claims after all required numeric
bounds are instantiated and inside budget.

`TestVectors/product-release-distribution-evidence-v1.json` is the checked
Product release distribution evidence manifest. It is not a proof artifact
schema and does not affect proof bytes. It pins required release artifact
families, provenance fields, release evidence binding, unsigned artifact
status, the `epsilon_release` loss symbol, and the promotion rule that enables
repository-local release-distribution claims from artifact digests, release
evidence digests, full production-gate evidence, and selected total-loss budget
binding.

`TestVectors/constant-time-scope-v1.json` is the checked constant-time
source/formal scope manifest. It is not a proof artifact schema; it pins audited
source markers, source-level forbidden branch patterns, formal trace-declaration
names, and explicit compiler/runtime/hardware boundaries.

`TestVectors/constant-time-lowering-evidence-v1.json` is the checked
Swift/LLVM/Metal lowering evidence contract. It is not a proof artifact schema;
it pins compiler lowering surfaces, required release artifacts,
runtime/hardware TCB obligations, and the promotion rule for production
constant-time language.

`Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json` is the pinned local
constant-time release evidence manifest. It is not a proof artifact schema and
does not affect proof bytes. It pins local Swift optimized SIL, Swift optimized
LLVM IR, Swift target assembly, Swift compiler generation report, Metal AIR
object, linked metallib, Metal generation report, runtime allocation/COW static
review, CPU observation corpus, direct GPU kernel observation corpus, compiler
observation lane report, and hardware observation lane report used by the
lowering evidence validator.

`TestVectors/e2e-proof-metrics-v1.json` is the checked proof-size and product
smoke budget manifest. It is not a proof artifact schema; it pins exact checked
vector artifact bytes, decoded proof-envelope bytes, generated NumiSeal product
smoke budgets, and the benchmark lane required before latency claims.

`TestVectors/benchmark-coverage-v1.json` is the checked whole-stack benchmark
coverage manifest. It is not a proof artifact schema and does not affect proof
bytes. It pins required benchmark row families for source fold proving,
verifying, stage costs, CPU kernels, Metal kernels, NumiSeal product terminal
and ZK proving/verifying, typed recursive carry child proving/verifying, and
local product-control replay/audit encoding. It proves row registration,
report-renderer inclusion, baseline-comparator inclusion, and production-gate
wiring; fresh hardware timing and competitor-performance claims remain separate
release evidence.

`SuperNeoProductOperationsStatus.formatVersion = 2` is the local product
operations readiness document version. It is emitted by
`product-status --format json` and embedded in product audit exports as
`operationsStatus`; it is not a proof artifact and must not affect proof bytes.
Version `2` adds signed revocation feed identity, sequence, issuer-key digest,
and feed digest fields.

`SuperNeoSignedRevocationFeed.payload.formatVersion = 1` is the signed
revocation-distribution document version. It is separate from proof artifacts
and trusted context packs so revocations can be rotated without changing proof
bytes.

Typed carry is a policy refinement over the existing carry slot. Legacy raw carry
fixtures remain under `.optional`/`.required`; product recursive carry must use
`NumiSealCarryStatement` and `.typedOptional`/`.typedRequired`.

## Version Bump Checklist

Before introducing a new public artifact or envelope version:

1. Update the relevant JSON Schema.
2. Update parser allowlists and duplicate-key coverage.
3. Add checked vectors or a migration fixture.
4. Add manifest entries with strict production verification commands.
5. Add schema validator coverage.
6. Add mutation tests for old/new compatibility boundaries.
7. Update `Docs/ProofEnvelope.md`, `Docs/CLI.md`, and
   `Docs/ProductionReadinessAuditPacket-2026-04-16.md`.
8. Run `Scripts/production-gate.sh` without `--skip-formal`.
