# Release Engineering Policy, 2026-04-16

This document defines the release discipline for the current repository scope.
It is intentionally conservative: a passing release gate permits tagged
research/integration releases, not production-security claims.

## Release Classes

### Research or Integration Release

A research or integration release may be tagged when all of the following are
true:

- `Scripts/production-gate.sh` passes locally without `--skip-formal`.
- `.github/workflows/production-gate.yml` runs the full macOS production gate
  without `--skip-formal`.
- The Ubuntu formal cross-check passes.
- `Docs/ProductionReadinessAuditPacket-2026-04-16.md` is current.
- `CHANGELOG.md` records user-facing changes and residual
  production-security blockers.
- `Docs/ReleaseCandidateRunbook-2026-04-16.md` has been followed.
- `Docs/E2EProofMetrics-2026-04-16.md` reflects current checked proof-size
  and product-smoke budgets.
- `Docs/Benchmarking.md` and `TestVectors/benchmark-coverage-v1.json` reflect
  current whole-stack benchmark row coverage.
- `Docs/ConstantTimeEvidence-2026-04-16.md` reflects current source/formal
  scope and Swift/LLVM/Metal lowering evidence semantics.
- `Docs/ProductOperationsReadiness-2026-04-16.md` reflects current product
  operations readiness status semantics and signed revocation feed semantics.
- `Docs/CryptographicSecurityDossier-2026-04-16.md` reflects the current
  bounded-depth product security theorem, Fiat-Shamir/QROM position, Module-SIS
  parameter dossier, selected-depth loss accounting, product extractor loss
  accounting, product QROM transcript schedule, product QROM sampler and
  encoding evidence, product QROM collision/malleability structural evidence,
  product QROM transform preconditions, product QROM interactive reduction,
  product QROM Fiat-Shamir accounting, product total-loss budget, and
  product release distribution evidence boundaries.
- Any changed public proof envelope, artifact, or manifest schema is documented
  in `Docs/SchemaCompatibility-2026-04-16.md`.
- Release notes explicitly use research/integration wording and do not claim
  production-secure SNARK status, formal constant-time behavior, or completed
  production-security NumiSeal product/carry/ZK theorem instantiations.

### Production-Security Release

A production-security release is blocked until every no-go item in
`Docs/ProductionReadinessAuditPacket-2026-04-16.md` is either completed or
replaced by an explicit, narrower deployment threat model.

At minimum, this requires:

- self-owned cryptographic and implementation review,
- side-channel review and evidence capture for Swift, LLVM, Metal lowering,
  runtime allocation, selected CPU/GPU observation lanes, and expansion beyond
  the pinned local `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
  smoke corpus,
- product integration policy for trusted context, replay protection,
  provenance, and signed revocation feeds,
- NumiSeal conformance-scope promotion plus concrete Swift extractor
  implementation and numeric extractor loss accounting, product recursive
  typed carry vectors, simulator coupling beyond the exact rejection-sampled
  field mask distribution, numeric digest collision and proof-kind
  malleability bounds over the structurally pinned QROM residual events, repair
  of the current out-of-budget DFM20 QROM numeric loss finding, selected
  total-loss budget closure, and product
  cryptographic security dossier promotion beyond depth 1,
- selected-depth loss accounting instantiated for extractor, QROM,
  ZK-simulator, hosted product-ops replay, constant-time side-channel, and
  signed release-distribution terms,
- pinned Sage-backed lattice-estimator evidence,
- release signing/provenance,
- branch protection requiring the full production gate.

## Required Release Evidence

Each release candidate should record:

- commit hash,
- dirty/clean source state,
- exact `Scripts/production-gate.sh` output summary,
- benchmark profile and hardware class if performance claims are included,
- benchmark coverage manifest digest,
- lattice-estimator artifact path and validation status if security-estimate
  claims are included,
- artifact schema versions and any compatibility changes,
- proof envelope version,
- known residual boundaries,
- NumiSeal conformance-scope digest.
- NumiSeal end-to-end theorem scope digest.
- recursive folding knowledge soundness scope digest.
- typed carry producer/consumer theorem scope digest.
- NumiSealZK simulation/privacy leakage-model digest.
- NumiSealZK mask-distribution evidence digest.
- product cryptographic security dossier digest.
- bounded-depth product security theorem status.
- selected-depth loss accounting digest.
- product extractor loss accounting digest.
- product QROM transcript schedule digest.
- product QROM sampler and encoding evidence digest.
- product QROM collision/malleability structural evidence digest.
- product QROM transform preconditions digest.
- product QROM interactive reduction digest.
- product QROM Fiat-Shamir accounting digest.
- product total-loss budget digest.
- product release distribution evidence digest.
- constant-time source/formal scope digest.
- constant-time lowering evidence digest.
- constant-time release evidence digest.
- constant-time compiler and hardware observation lane digests.
- E2E proof metrics digest.
- benchmark coverage manifest digest.
- product operations readiness status version.
- signed revocation feed policy.

`Scripts/generate-release-candidate-evidence.py` generates this evidence in a
machine-readable JSON packet, and `Scripts/validate-release-candidate-evidence.py`
checks that the packet was produced from the full production gate and current
public surface versions. `Scripts/validate-numiseal-conformance-scope.py`
checks the NumiSeal product/carry/ZK scope manifest and the checked
`TestVectors/numiseal-end-to-end-theorem-scope-v1.json` theorem-scope manifest
that release evidence pins. That theorem scope includes recursive folding
knowledge soundness, typed carry producer/consumer composition, and NumiSealZK
simulation/privacy under the declared public-leakage model, and the release
packet separately pins exact rejection-sampled field mask distribution evidence
in `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`.
`Scripts/test-numiseal-conformance-scope-validation.py` mutation-tests those
promotion guards.
`Scripts/validate-numiseal-zk-mask-distribution-evidence.py` checks the concrete
NumiSealZK mask sampler arithmetic and promotion boundary.
`Scripts/validate-product-crypto-security-dossier.py` checks
`TestVectors/product-crypto-security-dossier-v1.json`, including the
bounded-depth product security theorem surface, ProductSecurityTheorem import,
Fiat-Shamir/QROM target and disabled production claim, Module-SIS parameter
tuple, conservative post-quantum boundary, proof-size/latency boundary, and
implementation-hardening boundary.
`Scripts/validate-product-selected-depth-loss-accounting.py` checks
`TestVectors/product-selected-depth-loss-accounting-v1.json`, including the
current depth-1 loss expression, the recursive promotion expression, the ten
component loss terms, and the fail-closed blockers for extractor, QROM,
transcript collision, ZK-simulator, hosted product operations, release
signing/notarization, and CPU/Swift/LLVM/Metal constant-time evidence closure.
`Scripts/validate-product-extractor-loss-accounting.py` checks
`TestVectors/product-extractor-loss-accounting-v1.json`, including source-fold
extractor, terminal-seal extractor, product-envelope composition extractor,
future recursive carry extractor, and the fail-closed numeric loss budget.
`Scripts/validate-product-qrom-fiat-shamir-accounting.py` checks
`TestVectors/product-qrom-fiat-shamir-accounting-v1.json`, including
proof-kind transcript interfaces, QROM loss symbols, challenge families,
domain separation, the `epsilon_transcript_collision` to `epsilon_collision`
ledger mapping, the instantiated conditional `Q_H = 2^64` cap, and the
fail-closed quantum random-oracle loss budget.
`Scripts/validate-product-qrom-transcript-schedule.py` checks
`TestVectors/product-qrom-transcript-schedule-v1.json`, including the product
QROM transcript schedule, proof-kind order, public challenge labels, symbolic
`Q_H` query families, per-kind protocol challenge-derivation maxima, and the
fail-closed QROM promotion rule.
`Scripts/validate-product-qrom-sampler-encoding-evidence.py` checks
`TestVectors/product-qrom-sampler-encoding-evidence-v1.json`, including
product QROM sampler and encoding evidence, exact rejection-sampling arithmetic
for Goldilocks, Ext2, Phi81, CE ternary, and NumiSealZK masked-residual
challenges, structured transcript frame injectivity, and the fail-closed QROM
promotion rule.
`Scripts/validate-product-qrom-collision-malleability-evidence.py` checks
`TestVectors/product-qrom-collision-malleability-evidence-v1.json`, including
product QROM collision/malleability structural evidence, accepted proof-kind
separation, proof-envelope transcript-binding injectivity, artifact/provenance
digest binding, product replay identity binding, NumiSeal component-root
binding, typed carry replay binding, and the fail-closed boundary that keeps
concrete hash/QRO instantiation, numeric digest collision bounds, proof-kind
malleability bounds, QROM reduction repair, and total-loss integration open.
`Scripts/validate-product-qrom-transform-preconditions.py` checks
`TestVectors/product-qrom-transform-preconditions-v1.json`, including the
product QROM transform preconditions, primary QROM Fiat-Shamir source basis,
selected measure-and-reprogram profile, per-proof-kind theorem-family fit,
DFM20 `((2*Q_H+n+1)^(2n)/n!)` loss interface, and fail-closed production
QROM promotion rule.
`Scripts/validate-product-qrom-interactive-reduction.py` checks
`TestVectors/product-qrom-interactive-reduction-v1.json`, including the
product QROM interactive reduction ledger, public-coin protocol formulas,
selected `Q_H = 2^64` policy, code-enforced NumiSeal challenge maxima, DFM20
loss multiplier, selected-depth protocol challenge-derivation budget,
out-of-budget numeric finding, and fail-closed production QROM promotion rule.
`Scripts/validate-product-total-loss-budget.py` checks
`TestVectors/product-total-loss-budget-v1.json`, including exact rational
summation, the `2^-128` selected threshold, ten component bounds, nine
selected-depth required terms, and the fail-closed total-loss budget validation.
`Scripts/validate-product-release-distribution-evidence.py` checks
`TestVectors/product-release-distribution-evidence-v1.json`, including product
release distribution evidence for required artifact families, provenance
fields, unsigned research-artifact status, signing/notarization/branch-protection
promotion flags, the `epsilon_release` loss symbol, and release-evidence
packet binding.
`Scripts/validate-constant-time-scope.py` checks the constant-time
source/formal scope manifest and the formal declarations recorded in
`Docs/ConstantTimeEvidence-2026-04-16.md`.
`Scripts/validate-constant-time-lowering-evidence.py` checks the
Swift/LLVM/Metal lowering proof contract, runtime/hardware TCB obligations, and
promotion rule recorded in `TestVectors/constant-time-lowering-evidence-v1.json`;
it also verifies the pinned local Swift SIL/LLVM/assembly artifacts, Metal
AIR/metallib artifacts, runtime allocation review, CPU/GPU observation corpora,
and compiler/hardware observation lane reports under
`Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`. Regenerate those
artifacts with `Scripts/generate-constant-time-release-evidence.py` before a
release candidate when the scoped source or toolchain changes.
`Scripts/validate-e2e-proof-metrics.py` checks deterministic checked-vector
proof sizes and generated NumiSeal product smoke budgets recorded in
`Docs/E2EProofMetrics-2026-04-16.md`.
`Scripts/validate-benchmark-coverage.py` checks
`TestVectors/benchmark-coverage-v1.json`, including source registration,
report-renderer coverage, baseline-comparator coverage, production-gate wiring,
and the boundary that this is not a fresh hardware timing report.
`Scripts/test-benchmark-coverage-validation.py` mutation-tests those row
coverage guards.
`Scripts/validate-product-ops-surface.py` checks product operations readiness
status, signed revocation feed wiring, CLI JSON mode, audit export binding, and
production-gate wiring recorded in
`Docs/ProductOperationsReadiness-2026-04-16.md`.

## Signing And Provenance

Release artifacts should be signed before distribution. Until signed artifacts
are implemented, published artifacts must be treated as unsigned research
artifacts. `TestVectors/product-release-distribution-evidence-v1.json` is the
fail-closed contract for this state: it records that no release signing key,
signed provenance format, notarization/publication path, hosted branch-protection
evidence, archived release evidence, or numeric `epsilon_release` bound is
instantiated yet.

Required future provenance fields:

- repository URL,
- commit hash,
- build host class,
- Swift toolchain version,
- Lean toolchain version,
- production-gate result,
- artifact hash,
- artifact signature digest,
- release signing key digest,
- provenance format version,
- release evidence digest,
- product cryptographic security dossier digest,
- selected-depth loss accounting digest,
- product total-loss budget digest,
- constant-time release evidence digest,
- benchmark coverage digest,
- notarization or publication proof digest,
- hosted branch-protection evidence digest,
- archived release evidence digest.

## Branch Protection

Protected branches should require:

- the macOS full production gate job,
- the Ubuntu Lean formal cross-check job,
- code review for changes under `SuperNeo-NuMetal/`, `SuperNeoCLI/`,
  `Tools/`, `Scripts/`, `Formal/`, `.github/workflows/`, and `TestVectors/`.

Benchmarks and full Sage-backed estimator runs may remain opt-in because they
depend on hardware and external tooling, but performance or security-estimate
release claims must point to pinned artifacts generated by those lanes.
