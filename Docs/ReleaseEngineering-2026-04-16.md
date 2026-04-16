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
- `Docs/ConstantTimeEvidence-2026-04-16.md` reflects current source/formal
  scope and Swift/LLVM/Metal lowering evidence semantics.
- `Docs/ProductOperationsReadiness-2026-04-16.md` reflects current product
  operations readiness status semantics and signed revocation feed semantics.
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
- NumiSeal conformance-scope promotion plus concrete Swift extractor evidence,
  typed carry producer vectors, concrete mask-distribution distance evidence,
  and QROM loss instantiations,
- pinned Sage-backed lattice-estimator evidence,
- release signing/provenance,
- branch protection requiring the full production gate.

## Required Release Evidence

Each release candidate should record:

- commit hash,
- dirty/clean source state,
- exact `Scripts/production-gate.sh` output summary,
- benchmark profile and hardware class if performance claims are included,
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
- constant-time source/formal scope digest.
- constant-time lowering evidence digest.
- constant-time release evidence digest.
- constant-time compiler and hardware observation lane digests.
- E2E proof metrics digest.
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
simulation/privacy under the declared public-leakage model.
`Scripts/test-numiseal-conformance-scope-validation.py` mutation-tests those
promotion guards.
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
`Scripts/validate-product-ops-surface.py` checks product operations readiness
status, signed revocation feed wiring, CLI JSON mode, audit export binding, and
production-gate wiring recorded in
`Docs/ProductOperationsReadiness-2026-04-16.md`.

## Signing And Provenance

Release artifacts should be signed before distribution. Until signed artifacts
are implemented, published artifacts must be treated as unsigned research
artifacts.

Required future provenance fields:

- repository URL,
- commit hash,
- build host class,
- Swift toolchain version,
- Lean toolchain version,
- production-gate result,
- artifact hash.

## Branch Protection

Protected branches should require:

- the macOS full production gate job,
- the Ubuntu Lean formal cross-check job,
- code review for changes under `SuperNeo-NuMetal/`, `SuperNeoCLI/`,
  `Tools/`, `Scripts/`, `Formal/`, `.github/workflows/`, and `TestVectors/`.

Benchmarks and full Sage-backed estimator runs may remain opt-in because they
depend on hardware and external tooling, but performance or security-estimate
release claims must point to pinned artifacts generated by those lanes.
