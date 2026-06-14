# Production Readiness Audit Packet, 2026-04-16

Formal status: completed formal protocol theorem.

This is the archived reviewer entry point. It records historical
repository-local evidence and links to machine-readable artifacts. It is not a
production deployment approval.

## Smoke Result

Command:

```sh
Scripts/check-smoke.sh
```

Result: passed.

This command is the default build/test/CLI smoke. It does not run the archived
release evidence validators below.

## Claim Boundaries

Repository-local claim: the checked bounded-depth evidence surface is internally
consistent for development and release-candidate use.

Not claimed: production post-quantum security, production QROM security,
whole-stack constant-time certification, public distribution assurance, hosted
operations security, or independent cryptographic and implementation review.

## External Assurance Boundaries

Before external production wording, keep a self-owned production-hardening record
covering:

- independent cryptographic and implementation review,
- deployed trusted context, provenance, replay, access-control, persistence, and
  audit systems,
- side-channel and release-distribution evidence,
- artifact digest provenance,
- hosted operations replay behavior, and
- broader benchmark evidence.

## Required Human Docs

- `Docs/WhatThisProves.md`
- `Docs/ProofEnvelope.md`
- `Docs/CLI.md`
- `Docs/AuditBlockerNarrowing-2026-04-16.md`
- `Docs/ProductIntegrationLayer-2026-04-16.md`
- `Docs/ConstantTimeEvidence-2026-04-16.md`
- `Docs/E2EProofMetrics-2026-04-16.md`
- `Docs/ProductOperationsReadiness-2026-04-16.md`
- `Docs/CryptographicSecurityDossier-2026-04-16.md`
- `Docs/ReleaseEngineering-2026-04-16.md`
- `Docs/SchemaCompatibility-2026-04-16.md`
- `Docs/ReleaseCandidateRunbook-2026-04-16.md`
- `Docs/Benchmarking.md`

## Required Machine Evidence

- `TestVectors/numiseal-conformance-scope-v1.json`
- `TestVectors/numiseal-end-to-end-theorem-scope-v1.json`
- `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`
- `TestVectors/product-crypto-security-dossier-v1.json`
- `TestVectors/product-selected-depth-loss-accounting-v1.json`
- `TestVectors/product-extractor-loss-accounting-v1.json`
- `TestVectors/product-qrom-public-coin-accounting-v1.json`
- `TestVectors/product-qrom-transcript-schedule-v1.json`
- `TestVectors/product-qrom-sampler-encoding-evidence-v1.json`
- `TestVectors/product-qrom-collision-malleability-evidence-v1.json`
- `TestVectors/product-qrom-transform-preconditions-v1.json`
- `TestVectors/product-qrom-interactive-reduction-v1.json`
- `TestVectors/product-total-loss-budget-v1.json`
- `TestVectors/product-release-distribution-evidence-v1.json`
- `TestVectors/constant-time-scope-v1.json`
- `TestVectors/constant-time-lowering-evidence-v1.json`
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
- `TestVectors/e2e-proof-metrics-v1.json`
- `TestVectors/benchmark-coverage-v1.json`

## Historical Required Validators

These validators belong to the archived production-readiness evidence packet,
not the default repository smoke command.

- `Scripts/legacy-gates/validate-release-readiness-policy.py`
- `Scripts/legacy-gates/validate-doc-links.py`
- `Scripts/legacy-gates/validate-numiseal-conformance-scope.py`
- `Scripts/legacy-gates/test-numiseal-conformance-scope-validation.py`
- `Scripts/legacy-gates/validate-constant-time-scope.py`
- `Scripts/legacy-gates/test-constant-time-scope-validation.py`
- `Scripts/legacy-gates/validate-constant-time-lowering-evidence.py`
- `Scripts/legacy-gates/test-constant-time-lowering-evidence-validation.py`
- `Scripts/legacy-gates/generate-constant-time-release-evidence.py`
- `Scripts/legacy-gates/validate-numiseal-product-artifact-schema.py`
- `Scripts/legacy-gates/test-numiseal-product-artifact-schema-validation.py`
- `Scripts/legacy-gates/validate-product-crypto-security-dossier.py`
- `Scripts/legacy-gates/test-product-crypto-security-dossier-validation.py`
- `Scripts/legacy-gates/validate-product-selected-depth-loss-accounting.py`
- `Scripts/legacy-gates/test-product-selected-depth-loss-accounting-validation.py`
- `Scripts/legacy-gates/validate-product-extractor-loss-accounting.py`
- `Scripts/legacy-gates/test-product-extractor-loss-accounting-validation.py`
- `Scripts/legacy-gates/validate-product-qrom-public-coin-accounting.py`
- `Scripts/legacy-gates/test-product-qrom-public-coin-accounting-validation.py`
- `Scripts/legacy-gates/validate-product-qrom-transcript-schedule.py`
- `Scripts/legacy-gates/test-product-qrom-transcript-schedule-validation.py`
- `Scripts/legacy-gates/validate-product-qrom-sampler-encoding-evidence.py`
- `Scripts/legacy-gates/test-product-qrom-sampler-encoding-evidence-validation.py`
- `Scripts/legacy-gates/validate-product-qrom-collision-malleability-evidence.py`
- `Scripts/legacy-gates/test-product-qrom-collision-malleability-evidence-validation.py`
- `Scripts/legacy-gates/validate-product-qrom-transform-preconditions.py`
- `Scripts/legacy-gates/test-product-qrom-transform-preconditions-validation.py`
- `Scripts/legacy-gates/validate-product-qrom-interactive-reduction.py`
- `Scripts/legacy-gates/test-product-qrom-interactive-reduction-validation.py`
- `Scripts/legacy-gates/validate-product-total-loss-budget.py`
- `Scripts/legacy-gates/test-product-total-loss-budget-validation.py`
- `Scripts/legacy-gates/validate-product-release-distribution-evidence.py`
- `Scripts/legacy-gates/test-product-release-distribution-evidence-validation.py`
- `Scripts/legacy-gates/validate-e2e-proof-metrics.py`
- `Scripts/legacy-gates/test-e2e-proof-metrics-validation.py`
- `Scripts/legacy-gates/validate-benchmark-coverage.py`
- `Scripts/legacy-gates/test-benchmark-coverage-validation.py`
- `Scripts/legacy-gates/validate-product-ops-surface.py`
- `Scripts/legacy-gates/test-product-ops-surface-validation.py`
- `Scripts/legacy-gates/generate-release-candidate-evidence.py`
- `Scripts/legacy-gates/validate-release-candidate-evidence.py`

## Evidence Keywords

- NumiSeal end-to-end theorem scope
- recursive folding knowledge soundness
- typed carry producer/consumer
- NumiSealZK simulation/privacy
- exact rejection-sampled field mask distribution
- bounded-depth product security theorem
- selected-depth loss accounting
- extractor loss-accounting validation
- QROM public-coin accounting validation
- QROM transcript schedule validation
- QROM sampler/encoding evidence validation
- QROM collision/malleability structural evidence validation
- QROM interactive reduction validation
- QROM transform precondition validation
- total-loss budget validation
- release distribution evidence validation
- ProductSecurityTheorem
- QRO/QROM
- Module-SIS
- signed revocation feed
