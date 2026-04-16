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
| Constant-time source/formal scope manifest | `schemaVersion = 1` |
| Constant-time Swift/LLVM/Metal lowering evidence manifest | `schemaVersion = 1` |
| Constant-time release evidence manifest | `schemaVersion = 1` |
| E2E proof metrics manifest | `schemaVersion = 1` |
| Proof envelope header | `ProofEnvelopeHeader.version = 4` |
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
artifacts default to `zkMode = "none"`; explicit product proving may request
`zkMode = "masked-digit-tensor-v1"` while side-channel privacy claims remain
outside proof bytes and product verification. Deployment owners can keep
side-channel evidence as release metadata while private development continues
without certificate checks in proof acceptance.

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
does not affect proof bytes. It pins the local Metal AIR object, linked
metallib, Metal generation report, runtime allocation/COW static review, CPU
observation corpus, and direct GPU kernel observation corpus used by the
lowering evidence validator.

`TestVectors/e2e-proof-metrics-v1.json` is the checked proof-size and product
smoke budget manifest. It is not a proof artifact schema; it pins exact checked
vector artifact bytes, decoded proof-envelope bytes, generated NumiSeal product
smoke budgets, and the benchmark lane required before latency claims.

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
