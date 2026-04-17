# Changelog

All notable repository-level changes are recorded here. This project currently
uses research/integration release wording only; production-security release
claims remain blocked by the release packet no-go items.

## Unreleased

### Production Readiness

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
  keeping production claims disabled.
- Added a checked selected-depth loss accounting ledger and validator for the
  current depth-1 product theorem boundary, pinning source-fold, terminal-seal,
  carry, ZK simulator, QROM, extractor, transcript-collision, product-ops
  replay, constant-time, and release-distribution loss terms while keeping
  production claims disabled.
- Added checked extractor loss accounting, QROM transcript schedule, QROM
  transform preconditions, QROM interactive reduction, and QROM Fiat-Shamir
  accounting manifests,
  validators, mutation tests,
  release-evidence wiring, and Lean theorem hooks. These pin the extractor
  input/rewind contract, proof-kind transcript labels, symbolic `Q_H` query
  families, the conditional `Q_H = 2^64` adversary-query cap, selected-depth
  protocol challenge-derivation budget, transform theorem-family obligations,
  public-coin protocol formulas, code-enforced NumiSeal challenge maxima,
  DFM20 QROM loss multiplier, QROM loss contract, and collision-to-ledger
  mapping while keeping concrete extractor and production QROM loss claims
  disabled.
- Added checked QROM sampler/encoding evidence, validator, mutation tests,
  release-evidence wiring, and production-gate coverage. The evidence pins
  exact rejection-sampling arithmetic for Goldilocks, Ext2, Phi81, CE ternary,
  and NumiSealZK masked-residual challenges plus structured transcript frame
  injectivity under the QRO abstraction, while leaving hash instantiation,
  numeric digest collision bounds, proof-kind malleability bounds, the
  out-of-budget DFM20 loss repair, and the final production QROM theorem
  disabled.
- Added checked QROM collision/malleability evidence, validator, mutation
  tests, release-evidence wiring, production-gate coverage, and Lean
  proof-envelope kind coverage for the NumiSeal terminal and NumiSealZK proof
  kinds. The evidence pins structural cross-kind, cross-domain,
  cross-product-session, and cross-carry binding outside digest collision
  events while keeping concrete hash/QRO instantiation, numeric digest
  collision bounds, proof-kind malleability bounds, QROM loss repair, and
  total-loss integration disabled.
- Added a checked total-loss budget manifest, validator, mutation tests,
  release-evidence wiring, and Lean theorem hook. The budget pins exact
  rational selected-depth summation, ten component bounds, nine required
  selected-depth numeric terms, and the `2^-128` threshold while keeping
  production claims disabled.
- Added a checked release distribution evidence manifest, validator, mutation
  tests, release-evidence wiring, and Lean theorem hook. The evidence pins
  required artifact families, provenance fields, unsigned research-artifact
  status, signing/notarization/branch-protection promotion flags, and the
  `epsilon_release` loss hook while keeping production release claims disabled.
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

### Remaining Production-Security Blockers

- Self-owned cryptographic and implementation review record.
- Scoped Swift SIL/LLVM/assembly review, hardware counters, power/contention,
  and broader device-lane evidence beyond the pinned compiler/hardware
  observation lanes in the local constant-time release evidence.
- Product integration for provenance, replay protection, trusted context, access
  control, persistence, logging, and user-facing policy.
- NumiSeal product/carry/ZK theorem and conformance-vector promotion; the
  NumiSeal end-to-end theorem scope and product cryptographic security dossier
  are checked, while production-security NumiSeal product claims still require
  concrete Swift extractor implementation, numeric extractor loss
  instantiation, product recursive typed carry vectors, selected total-loss
  budget instantiation, simulator coupling beyond the exact field-mask
  distribution lemma, QROM transform precondition closure,
  numeric digest collision and proof-kind malleability bounds over the
  structurally pinned residual events, per-kind interactive security bounds,
  repair of the current
  out-of-budget DFM20 QROM numeric loss finding, conservative
  post-quantum parameter closure, competitive proof-size/latency evidence, and
  side-channel evidence.
- Signed artifacts, signed provenance, notarization/publication proof, archived
  release evidence, numeric `epsilon_release` budget instantiation, and
  repository branch-protection enforcement.
