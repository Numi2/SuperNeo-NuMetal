# Release Candidate Runbook, 2026-04-16

This is the short release-candidate checklist. Keep release evidence in JSON
manifests; do not duplicate it here.

## Required Steps

1. Run:

```sh
Scripts/production-gate.sh
Scripts/generate-release-candidate-evidence.py --expect-production-gate-result passed
Scripts/validate-release-candidate-evidence.py
```

2. Keep distribution wording at repository-local unsigned distribution unless
release signing and publication controls are separately documented.

3. Record these version and digest fields:

- NumiSeal product/carry/ZK conformance-scope version and digest
- NumiSeal end-to-end theorem-scope version and digest
- NumiSealZK mask-distribution evidence version and digest
- product cryptographic security dossier version and digest
- selected-depth loss-accounting version and digest
- product extractor loss-accounting version and digest
- product QROM public-coin accounting version and digest
- product QROM transcript schedule version and digest
- product QROM sampler/encoding evidence version and digest
- product QROM collision/malleability evidence version and digest
- product QROM transform preconditions version and digest
- product total-loss budget version and digest
- product release distribution evidence version and digest
- constant-time source/formal scope version and digest
- constant-time lowering evidence version and digest
- constant-time release evidence version and digest
- E2E proof metrics version and digest
- product operations readiness status
- signed revocation feed

4. Check linked docs:

- `Docs/ProductOperationsReadiness-2026-04-16.md`
- `Docs/ProductionReadinessAuditPacket-2026-04-16.md`
- `Docs/SchemaCompatibility-2026-04-16.md`
- `Docs/Benchmarking.md`

## Publication Protection

Publication Protection remains outside the repository-local release-candidate
claim unless explicit release signing, distribution, and publication controls
are added.
