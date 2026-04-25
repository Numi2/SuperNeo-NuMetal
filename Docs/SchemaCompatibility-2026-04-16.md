# Schema Compatibility, 2026-04-16

This page is the short schema and manifest compatibility ledger.

## Active Versions

- `artifactVersion = 1`
- `manifestVersion = 1`
- `ProofEnvelopeHeader.version = 5`
- `numiseal-product-artifact-v2.schema.json`
- `test-vector-artifact-v1.json`

## Checked Manifests

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

## Human Labels Required By Validators

- Product extractor loss accounting manifest
- Product QROM public-coin accounting manifest
- Product QROM transcript schedule manifest
- Product QROM sampler/encoding evidence manifest
- Product QROM collision/malleability evidence manifest
- Product QROM transform preconditions manifest
- Product QROM interactive reduction manifest
- Product total-loss budget manifest
- Product release distribution evidence manifest

## Version Bump Checklist

1. Add the new schema or manifest.
2. Add validator and mutation tests.
3. Update production-gate wiring.
4. Update checked vector metadata.
5. Update release candidate evidence generation.
6. Preserve old readers only when compatibility is deliberately supported.
7. Update `Docs/ProofEnvelope.md`, `Docs/CLI.md`, and
   `Docs/ProductionReadinessAuditPacket-2026-04-16.md`.
