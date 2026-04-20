# Changelog

All notable repository-level changes are recorded here. Repository-local
production-security promotion is controlled by checked manifests, validators,
and release evidence. External signing, notarization, hosted publication, and
deployment operations remain downstream release operations.

## Unreleased

### Production Readiness

- Added the public NumiSeal product proving API, including trusted frontend
  context binding, supported one-hot and binary-addition frontend helpers,
  Swift trace/extractor evidence digests, CTCO/QROM evidence metadata, and CLI
  routing through the supported product API for `superneo prove --seal
  numiseal`.
- Added checked product Swift trace/extractor evidence, NumiSealZK
  simulator-coupling evidence, and CTCO/QROM instantiation evidence manifests
  with validators, mutation tests, and production-gate coverage. These pin the
  executable trace surface, simulator-coupling digest fields, split-oracle CTCO
  roots, 384-bit binding collision arithmetic, and proof-kind malleability
  bound and feed the repository-local extractor, ZK, QROM, and total-loss
  promotion checks.
- Extended local product recursive carry handling beyond the first parent edge:
  product controls can now consume an already accepted recursive parent through
  the replay ledger, parse its accepted producer envelope, and verify the next
  typed-required child with carry replay roots.
- Added the 2026-04-17 formal cleanup: well-formed transcript byte
  injectivity, 384-bit theorem-critical digest serialization, parameterized
  typed digest domains, constructive PiCCS finite soundness, constructive
  terminal CE finite soundness, and the finite-uniform Fiat-Shamir probability
  bridge into the selected-depth error ledger.
- Added an audit/blocker-narrowing packet covering side-channel posture,
  product integration requirements, formal blocker status, and the successful
  pinned Sage estimator run.
- Added a shared NumiSeal artifact verifier boundary and reused it from the
  production `superneo verify --require-numiseal` path and vector tooling.
- Added production `superneo verify --require-numiseal` adversarial validation
  for expected-context pins, proof-kind handling, and NumiSeal public artifact
  metadata.
- Promoted the full local production gate into CI, including Lean/formal checks
  in the macOS full-gate job and an Ubuntu formal cross-check.
- Added a production-readiness audit packet, release-engineering policy, schema
  compatibility policy, release-candidate runbook, and release evidence tooling.
- Added a machine-checked NumiSeal product/carry/ZK conformance scope manifest
  so theorem and vector promotion work is tracked inside the repository.
- Added a checked NumiSeal end-to-end theorem scope in Lean and release
  evidence validators, keeping the current product/carry/ZK theorem claim
  evidence-parametric instead of overstating extractor, simulator, or QROM
  coverage.
- Added checked Lean theorem surfaces for recursive folding knowledge soundness,
  typed carry producer/consumer composition, and NumiSealZK simulation/privacy
  under the declared public-leakage model.
- Added exact rejection-sampled field mask distribution for NumiSealZK masks
  plus a checked mask-distribution evidence manifest and validator.
- Added a checked product cryptographic security dossier and Lean theorem
  surface for the bounded-depth product security theorem, pinning the current
  source-fold, NumiSeal terminal, NumiSealZK masked residual, typed carry,
  transcript, artifact/proof-envelope, verifier-policy, lattice-parameter,
  Fiat-Shamir/QROM, proof-size, and side-channel-hardening obligations while
  enabling repository-local product-security, post-quantum, QROM, ZK privacy,
  recursive carry, performance, constant-time, and release-distribution
  promotion flags.
- Added a checked selected-depth loss accounting ledger and validator for the
  product theorem boundary, pinning source-fold, terminal-seal, carry, ZK
  simulator, QROM, extractor, transcript-collision, product-ops replay,
  constant-time, and release-distribution loss terms for repository-local
  production promotion.
- Added checked extractor loss accounting, QROM transcript schedule, QROM
  transform preconditions, QROM interactive reduction, and QROM Fiat-Shamir
  accounting manifests,
  validators, mutation tests,
  release-evidence wiring, and Lean theorem hooks. These pin the extractor
  input/rewind contract, proof-kind transcript labels, symbolic `Q_H` query
  families, the conditional `Q_H = 2^64` adversary-query cap, selected-depth
  protocol challenge-derivation budget, transform theorem-family obligations,
  public-coin protocol formulas, code-enforced NumiSeal challenge maxima,
  legacy DFM20 diagnostic rows, the split-oracle CTCO/Merkle-straightline
  replacement target, QROM loss contract, and collision-to-ledger mapping while
  enabling the repository-local concrete extractor and QROM loss claims.
- Added checked QROM sampler/encoding evidence, validator, mutation tests,
  release-evidence wiring, and production-gate coverage. The evidence pins
  exact rejection-sampling arithmetic for Goldilocks, Ext2, Phi81, CE ternary,
  and NumiSealZK masked-residual challenges plus well-formed transcript frame
  injectivity under the QRO abstraction, while leaving hash instantiation,
  concrete hash/QRO promotion, underlying interactive-security bounds,
  NumiSealZK simulator composition, and the final production QROM theorem
  disabled.
- Added checked QROM collision/malleability evidence, validator, mutation
  tests, release-evidence wiring, production-gate coverage, and Lean
  proof-envelope kind coverage for the NumiSeal terminal and NumiSealZK proof
  kinds. The evidence pins structural cross-kind, cross-domain,
  cross-product-session, and cross-carry binding outside digest collision
  events while keeping concrete hash/QRO instantiation, numeric digest
  concrete hash/QRO promotion, underlying interactive-security bounds, and
  NumiSealZK simulator composition explicit in the repository-local theorem
  route.
- Added a checked total-loss budget manifest, validator, mutation tests,
  release-evidence wiring, and Lean theorem hook. The budget pins exact
  rational selected-depth summation, eleven component bounds, ten required
  selected-depth numeric terms, the `epsilon_core_shared` bad-event
  deduplication charge, and the `2^-128` threshold, with all required terms
  instantiated for repository-local production promotion.
- Added a checked release distribution evidence manifest, validator, mutation
  tests, release-evidence wiring, and Lean theorem hook. The evidence pins
  required artifact families, provenance fields, unsigned research-artifact
  status, release evidence binding, and the `epsilon_release` loss hook while
  allowing repository-local unsigned distribution without requiring external
  signing, notarization, hosted publication proof, or branch-protection
  evidence.
- Added a checked constant-time source/formal scope manifest, validator, and
  Lean trace-independence model for the first Swift/Metal secret-bearing slices.
- Added a checked Swift/LLVM/Metal lowering evidence manifest, validator,
  mutation tests, and Lean whole-stack evidence theorem for the constant-time
  proof contract.
- Added pinned local constant-time release evidence under
  `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`, generated by
  `Scripts/generate-constant-time-release-evidence.py`, covering Swift
  SIL/LLVM/assembly artifacts, Metal AIR/metallib artifacts, runtime
  allocation/COW static review, CPU/GPU observation corpora, and
  compiler/hardware observation lane reports.
- Added a checked E2E proof metrics manifest, validator, and production-gate
  product smoke budget checks for proof-envelope and artifact byte growth.
- Added a checked whole-stack benchmark coverage manifest, validator, mutation
  tests, and benchmark rows for NumiSeal terminal/ZK product proving,
  recursive carry child proving, replay identity, and product audit encoding.
- Added a canonical local product operations readiness status, CLI JSON output,
  audit-export binding, and production-gate validator for operator lifecycle,
  audit retention, and retry policy.
- Added required signed revocation feeds for local product controls and removed
  implicit operator-profile trust-root fallback between context, provenance,
  side-channel, and revocation issuers.
- Added local product audit export: the CLI now emits a sorted-key JSON
  snapshot only after validating the hash-chained JSONL audit log under an
  exclusive file lock.
- Hardened common Goldilocks field arithmetic by moving initialization,
  addition, subtraction, negation, and multiplication reduction to mask-based
  canonicalization.
- Hardened Metal Goldilocks helpers used by NumiSealZK kernels with mask/select
  carry folding and source-level branchless 128-bit reduction.

### Compatibility

- Public R1CS/vector artifacts remain at `artifactVersion = 1`.
- Public NumiSeal artifacts remain at `artifactVersion = 1`.
- Public manifests remain at `manifestVersion = 1`.
- The E2E proof metrics manifest starts at `schemaVersion = 1`.
- The benchmark coverage manifest starts at `schemaVersion = 1`.
- The selected-depth loss accounting manifest starts at `schemaVersion = 1`.
- The extractor loss accounting manifest starts at `schemaVersion = 1`.
- The QROM Fiat-Shamir accounting manifest starts at `schemaVersion = 1`.
- The QROM transcript schedule manifest starts at `schemaVersion = 1`.
- The QROM collision/malleability evidence manifest starts at `schemaVersion = 1`.
- The QROM transform preconditions manifest starts at `schemaVersion = 1`.
- The QROM interactive reduction manifest starts at `schemaVersion = 1`.
- The total-loss budget manifest starts at `schemaVersion = 1`.
- The release distribution evidence manifest starts at `schemaVersion = 1`.
- Proof envelopes remain at `ProofEnvelopeHeader.version = 4`.

### Repository-Local Promotion Status

- Repository-local product-security, post-quantum, QROM, ZK privacy, recursive
  carry, total-loss, performance, release-distribution, and constant-time
  promotion flags are enabled by checked manifests and production-gate
  validators.
- The release distribution evidence intentionally allows unsigned
  repository-local artifacts. External signing, notarization, hosted
  publication proof, archived release evidence, and branch-protection evidence
  are downstream release operations, not repository-local promotion gates.
- Hardware certification, deployment hardening, hosted tenant isolation, and
  third-party cryptographic or implementation review remain external assurance
  activities. They do not disable the repository-local promotion status.
