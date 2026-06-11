# Release Engineering, 2026-04-16

This is the compact release policy. It separates ordinary research builds from
repository-local production-security promotion.

## Release Classes

### Research or Integration Release

Allowed for development, benchmarks, and integration demos. It must not claim
production post-quantum security, production QROM security, whole-stack
constant-time behavior, or independent cryptographic and implementation review.

### Archived Repository-Local Production-Security Promotion

Repository-local production-security promotion is no longer part of the default
completion gate. Historical evidence validators remain in the repository, but
production-security wording should not be promoted from the default build gate.

Default completion command:

```sh
Scripts/production-gate.sh
```

Release records must include artifact digest provenance when separate release
evidence validation is intentionally run.

## Historical Evidence And Validators

- `Scripts/validate-numiseal-conformance-scope.py`
- `Scripts/test-numiseal-conformance-scope-validation.py`
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
- `Docs/CryptographicSecurityDossier-2026-04-16.md`
- `Scripts/validate-constant-time-scope.py`
- `Scripts/validate-constant-time-lowering-evidence.py`
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
- `Scripts/validate-e2e-proof-metrics.py`
- `Scripts/validate-product-ops-surface.py`
- `Scripts/generate-release-candidate-evidence.py`

## Required Digest Labels

Product release evidence must record these labels:

- product operations readiness
- NumiSeal end-to-end theorem scope digest
- recursive folding knowledge soundness
- typed carry producer/consumer
- NumiSealZK simulation/privacy
- exact rejection-sampled field mask distribution
- product cryptographic security dossier digest
- bounded-depth product security theorem
- product extractor loss accounting
- product QROM public-coin accounting
- product QROM transcript schedule
- product QROM sampler and encoding evidence
- product QROM collision/malleability structural evidence
- product QROM transform preconditions
- product QROM interactive reduction
- product total-loss budget
- product release distribution evidence
- signed revocation feed
- E2E proof metrics digest
- constant-time release evidence digest

## References

- `Docs/ProductionReadinessAuditPacket-2026-04-16.md`
- `Docs/ReleaseCandidateRunbook-2026-04-16.md`
- `Docs/SchemaCompatibility-2026-04-16.md`
- `Docs/Benchmarking.md`
