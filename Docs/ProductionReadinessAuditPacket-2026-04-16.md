# Production Readiness Audit Packet, 2026-04-16

Formal status: completed formal protocol theorem.

This packet is the current reviewer entry point for production-readiness
assessment. It records what the repository can substantiate today, what the
local release gate has covered, and what still blocks a production-security
claim.

## Current Qualification Result

Local command:

```sh
Scripts/production-gate.sh
```

Result: passed.

Coverage included:

- release build,
- debug XCTest suite,
- release XCTest suite,
- R1CS artifact schema contract validation and schema mutation tests,
- NumiSeal artifact schema contract validation and schema mutation tests,
- NumiSeal conformance and end-to-end theorem-scope validation,
- constant-time source/formal scope validation,
- constant-time Swift/LLVM/Metal lowering and pinned release evidence
  validation,
- E2E proof-size metrics and generated product smoke budget validation,
- local product-ops readiness surface validation,
- release policy, schema compatibility, and CI gate drift validation,
- checked vector validation,
- NumiSeal vector validation,
- production `superneo verify --require-numiseal` adversarial matrix,
- terminal and compressed-terminal CLI smoke tests,
- lattice-estimator dry-run artifact validation,
- Lean `lake build`,
- Lean vector-check target,
- Lean executable proof-import wall and Swift/Lean vector checks,
- formal status, profile-constant, Ext2 serialization, and CE byte
  serialization validation,
- Swift/Lean Ext2 vector comparison,
- Swift/Lean CE vector comparison.

This is a strong release gate for the implemented repository scope. It is not
a side-channel certification or product deployment approval.

Additional local estimator command:

```sh
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
```

Result: passed under SageMath 10.8. The pinned lane records
`minimum_extracted_rop_bits = 129.1` against the 129-bit threshold. The
generated JSON is local scratch output under `lattice-estimator-results/`; the
tracked audit disposition is in `Docs/AuditBlockerNarrowing-2026-04-16.md`.

## CI Policy

`.github/workflows/production-gate.yml` runs the full macOS production gate on
pull requests, `main`, and manual dispatch. That job installs the pinned Lean
toolchain through `elan` and runs `Scripts/production-gate.sh` without
`--skip-formal`, so the Swift/Lean vector bridges are checked in the same job as
the release Swift CLI and XCTest gates.

The workflow also keeps an Ubuntu Lean cross-check for the formal workspace,
formal executable gates, status manifest, profile constants, Ext2 serialization
surface, and CE byte-serialization surface. That second job is not a replacement
for the full macOS production gate; it is an additional platform check for the
formal side of the repository.

## Evidence Map

Core implementation and verifier boundaries:

- `SuperNeo-NuMetal/`
- `SuperNeoCLI/main.swift`
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealArtifactVerifier.swift`
- `Tools/NumiSealVectorCLI/main.swift`

Threat model and proof semantics:

- `Docs/ThreatModel.md`
- `Docs/WhatThisProves.md`
- `Docs/ProofEnvelope.md`
- `Docs/CLI.md`
- `Docs/AuditBlockerNarrowing-2026-04-16.md`
- `Docs/ProductIntegrationLayer-2026-04-16.md`
- `Docs/ConstantTimeEvidence-2026-04-16.md`
- `Docs/E2EProofMetrics-2026-04-16.md`
- `Docs/ProductOperationsReadiness-2026-04-16.md`

Formal status:

- `Docs/FormalStatus.json`
- `Docs/FormalAssumptionLedger-2026-04-14.md`
- `Docs/FormalRemainingBoundaries-2026-04-14.md`
- `Formal/`

Release and validation gates:

- `Scripts/production-gate.sh`
- `.github/workflows/production-gate.yml`
- `Docs/ReleaseEngineering-2026-04-16.md`
- `Docs/SchemaCompatibility-2026-04-16.md`
- `Docs/ProductIntegrationLayer-2026-04-16.md`
- `Docs/ReleaseCandidateRunbook-2026-04-16.md`
- `TestVectors/numiseal-conformance-scope-v1.json`
- `TestVectors/numiseal-end-to-end-theorem-scope-v1.json`
- `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`
- `TestVectors/constant-time-scope-v1.json`
- `TestVectors/constant-time-lowering-evidence-v1.json`
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
- `TestVectors/e2e-proof-metrics-v1.json`
- `CHANGELOG.md`
- `Scripts/validate-release-readiness-policy.py`
- `Scripts/validate-numiseal-conformance-scope.py`
- `Scripts/test-numiseal-conformance-scope-validation.py`
- `Scripts/validate-numiseal-zk-mask-distribution-evidence.py`
- `Scripts/test-numiseal-zk-mask-distribution-evidence-validation.py`
- `Scripts/validate-constant-time-scope.py`
- `Scripts/test-constant-time-scope-validation.py`
- `Scripts/validate-constant-time-lowering-evidence.py`
- `Scripts/test-constant-time-lowering-evidence-validation.py`
- `Scripts/generate-constant-time-release-evidence.py`
- `Scripts/validate-e2e-proof-metrics.py`
- `Scripts/test-e2e-proof-metrics-validation.py`
- `Scripts/validate-product-ops-surface.py`
- `Scripts/test-product-ops-surface-validation.py`
- `Scripts/generate-release-candidate-evidence.py`
- `Scripts/validate-release-candidate-evidence.py`
- `Scripts/test-release-candidate-evidence-validation.py`
- `Scripts/validate-test-vectors.swift`
- `Scripts/test-vector-manifest-validation.py`
- `Scripts/validate-artifact-schema.py`
- `Scripts/test-artifact-schema-validation.py`
- `Scripts/validate-numiseal-artifact-schema.py`
- `Scripts/test-numiseal-artifact-schema-validation.py`
- `Scripts/test-numiseal-vector-validation.py`
- `Scripts/test-numiseal-superneo-cli-validation.py`

Checked artifacts:

- `TestVectors/manifest.json`
- `TestVectors/artifact.schema.json`
- `TestVectors/numiseal-manifest.json`
- `TestVectors/numiseal-artifact.schema.json`

Benchmark and estimator evidence:

- `Docs/Benchmarking.md`
- `Docs/BenchmarkReports/`
- `Scripts/reproduce-lattice-estimator.sh`
- `Scripts/validate-lattice-estimator-artifact.py`
- `Docs/AuditBlockerNarrowing-2026-04-16.md`

## Production-Ready For

Within the repository's stated scope, the code is ready for:

- local and CI release-gate validation,
- implementation research,
- reproducibility review,
- verifier integration experiments with caller-owned trusted context,
- checked terminal, compressed-terminal, and NumiSeal artifact verification
  using explicit policy gates,
- NumiSeal product-integration experiments using protocol hooks for trusted
  context lookup, authorization, provenance verification, replay detection, and
  audit recording,
- local product-ops readiness inspection and audit export with machine-readable
  `SuperNeoProductOperationsStatus`,
- signed local revocation-feed verification and audit binding for product
  controls.

For NumiSeal, the production-facing surface is verification and inspection of
the checked immediate-residual artifact family. The shared
`NumiSealArtifactVerifier` is the library boundary for metadata validation,
public obligation reconstruction, policy construction, envelope checks, caller
trust-pin checks, and final verifier dispatch.

## Not Yet Production-Ready For

The repository must not yet be presented as:

- a production-secure post-quantum SNARK,
- a general zero-knowledge system for arbitrary application statements,
- a hosted verifier service, wallet, replay-protection service, or policy
  engine,
- a formally constant-time implementation,
- a Swift/LLVM/Metal hardware constant-time certificate,
- a general program-to-CCS compiler,
- a general NumiSeal production proving product.
- a self-owned production-hardening record for all NumiSeal product, carry,
  ZK, side-channel, and release-operation lanes.

## Remaining No-Go Items

These are the remaining blockers before using production-security language:

1. Self-owned cryptographic and implementation review record.
2. Side-channel review for Swift, LLVM, Metal AIR/object-code lowering, CPU/GPU
   microarchitecture, allocation, power, contention, and timing behavior. The
   repository now has a checked Swift/LLVM/Metal lowering proof contract in
   `TestVectors/constant-time-lowering-evidence-v1.json` and pinned local
   release evidence in `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
   for Swift SIL/LLVM/assembly generation, Metal AIR/metallib generation,
   runtime allocation/COW static review, CPU/GPU smoke corpora, and
   compiler/hardware observation lane reports. Scoped Swift emitted-code review,
   hardware counters, power/contention, and broader device lanes still have to
   be recorded before production constant-time language is allowed.
3. Deployed product implementations for trusted key distribution,
   expected-context storage, artifact provenance, replay protection,
   persistence, access control, hosted logging, and hosted revocation
   distribution. The local NumiSeal integration protocol facade, local
   product-ops readiness status, and signed revocation feed now exist, but
   durable product implementations remain outside the repository.
4. NumiSeal product/carry/ZK theorem scope remains release-discipline work:
   `TestVectors/numiseal-conformance-scope-v1.json` tracks the current
   surfaces and conformance vectors, and
   `TestVectors/numiseal-end-to-end-theorem-scope-v1.json` pins the checked
   NumiSeal end-to-end theorem scope. That scope now includes checked Lean
   surfaces for recursive folding knowledge soundness, typed carry producer/consumer
   composition, and NumiSealZK simulation/privacy under the
   declared public-leakage model. The scope now also pins the exact rejection-sampled field mask distribution evidence in
   `TestVectors/numiseal-zk-mask-distribution-evidence-v1.json`. The current
   theorem is still evidence-parametric: accepted product gates plus named source-fold,
   terminal-seal, recursive-knowledge, typed-carry, masked-residual ZK,
   simulation/privacy, and product-policy obligations imply the composed
   relation. Concrete Swift extractor evidence, product recursive typed carry
   vectors, simulator coupling evidence beyond the exact mask-distribution
   lemma, QROM Fiat-Shamir loss accounting, and side-channel evidence still
   have to be supplied before production-security NumiSeal theorem language is
   allowed.
5. Broader hardware benchmark reports before making cross-generation
   performance claims. The E2E proof metrics manifest now gates checked-vector
   proof size and product-smoke size budgets, but hardware latency claims still
   need fresh benchmark evidence.
6. Release engineering execution: signed artifacts and hosted branch-protection
   enforcement requiring the full production gate. The changelog, reproducible
   release instructions, release evidence tooling, and schema compatibility
   policies now exist and are checked by
   `Scripts/validate-release-readiness-policy.py`.

## Next Engineering Slice

The next high-leverage implementation slice is hosted product operations and
typed recursive carry promotion. The local product verifier now has trusted
context, provenance, replay, audit hooks, product-ops readiness classification,
signed revocation feed verification, audit export retention policy, and retry
policy. Production work should add durable context storage, key distribution and
rotation rollout, hosted revocation feed distribution, tenant authorization, and
hosted audit retention.

Recursive carry promotion should keep using `NumiSealCarryStatement` rather
than raw carry slots, add product producer/consumer vectors, and extend the
conformance-scope manifest before changing product defaults.
