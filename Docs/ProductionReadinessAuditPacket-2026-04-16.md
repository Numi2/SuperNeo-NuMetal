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
- product cryptographic security dossier validation,
- selected-depth product loss-accounting validation,
- product extractor loss-accounting validation,
- product QROM transcript schedule validation,
- product QROM sampler/encoding evidence validation,
- product QROM collision/malleability structural evidence validation,
- product QROM transform precondition validation,
- product QROM interactive reduction validation,
- product QROM Fiat-Shamir accounting validation,
- product total-loss budget validation,
- product release distribution evidence validation,
- constant-time source/formal scope validation,
- constant-time Swift/LLVM/Metal lowering and pinned release evidence
  validation,
- E2E proof-size metrics and generated product smoke budget validation,
- whole-stack benchmark coverage validation,
- local product-ops readiness surface validation,
- release policy, schema compatibility, and CI gate drift validation,
- checked vector validation,
- NumiSeal vector validation,
- production strict NumiSeal `superneo verify` adversarial matrix,
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

`.github/workflows/production-gate.yml` runs a short macOS XCTest smoke job on
pull requests that touch Swift, scripts, tools, or checked vectors. The full
macOS production gate now runs on `main` and manual dispatch, installs the
pinned Lean toolchain through `elan`, and runs `Scripts/production-gate.sh`
without `--skip-formal`, so the Swift/Lean vector bridges remain part of the
release gate.

`.github/workflows/formal-status.yml` owns the path-filtered Ubuntu Lean lane
for pull requests and `main`: formal workspace build, executable gates, status
manifest, profile constants, Ext2 serialization surface, CE byte-serialization
surface, and the vector-bridge regression harnesses.

## Evidence Map

Core implementation and verifier boundaries:

- `SuperNeo-NuMetal/`
- `SuperNeoCLI/main.swift`
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealArtifactVerifier.swift`
- `Tools/NumiSealVectorCLI/main.swift`

Threat model and proof semantics:

- `Docs/WhatThisProves.md`
- `Docs/ProofEnvelope.md`
- `Docs/CLI.md`
- `Docs/AuditBlockerNarrowing-2026-04-16.md`
- `Docs/ProductIntegrationLayer-2026-04-16.md`
- `Docs/ConstantTimeEvidence-2026-04-16.md`
- `Docs/E2EProofMetrics-2026-04-16.md`
- `Docs/ProductOperationsReadiness-2026-04-16.md`
- `Docs/CryptographicSecurityDossier-2026-04-16.md`

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
- `TestVectors/product-crypto-security-dossier-v1.json`
- `TestVectors/product-selected-depth-loss-accounting-v1.json`
- `TestVectors/product-extractor-loss-accounting-v1.json`
- `TestVectors/product-qrom-fiat-shamir-accounting-v1.json`
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
- `CHANGELOG.md`
- `Scripts/validate-doc-links.py`
- `Scripts/validate-release-readiness-policy.py`
- `Scripts/validate-numiseal-conformance-scope.py`
- `Scripts/test-numiseal-conformance-scope-validation.py`
- `Scripts/validate-numiseal-zk-mask-distribution-evidence.py`
- `Scripts/test-numiseal-zk-mask-distribution-evidence-validation.py`
- `Scripts/validate-product-crypto-security-dossier.py`
- `Scripts/test-product-crypto-security-dossier-validation.py`
- `Scripts/validate-product-selected-depth-loss-accounting.py`
- `Scripts/test-product-selected-depth-loss-accounting-validation.py`
- `Scripts/validate-product-extractor-loss-accounting.py`
- `Scripts/test-product-extractor-loss-accounting-validation.py`
- `Scripts/validate-product-qrom-fiat-shamir-accounting.py`
- `Scripts/test-product-qrom-fiat-shamir-accounting-validation.py`
- `Scripts/validate-product-qrom-transcript-schedule.py`
- `Scripts/test-product-qrom-transcript-schedule-validation.py`
- `Scripts/validate-product-qrom-sampler-encoding-evidence.py`
- `Scripts/test-product-qrom-sampler-encoding-evidence-validation.py`
- `Scripts/validate-product-qrom-collision-malleability-evidence.py`
- `Scripts/test-product-qrom-collision-malleability-evidence-validation.py`
- `Scripts/validate-product-qrom-transform-preconditions.py`
- `Scripts/test-product-qrom-transform-preconditions-validation.py`
- `Scripts/validate-product-qrom-interactive-reduction.py`
- `Scripts/test-product-qrom-interactive-reduction-validation.py`
- `Scripts/validate-product-total-loss-budget.py`
- `Scripts/test-product-total-loss-budget-validation.py`
- `Scripts/validate-product-release-distribution-evidence.py`
- `Scripts/test-product-release-distribution-evidence-validation.py`
- `Scripts/validate-constant-time-scope.py`
- `Scripts/test-constant-time-scope-validation.py`
- `Scripts/validate-constant-time-lowering-evidence.py`
- `Scripts/test-constant-time-lowering-evidence-validation.py`
- `Scripts/generate-constant-time-release-evidence.py`
- `Scripts/validate-e2e-proof-metrics.py`
- `Scripts/test-e2e-proof-metrics-validation.py`
- `Scripts/validate-benchmark-coverage.py`
- `Scripts/test-benchmark-coverage-validation.py`
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
- `TestVectors/benchmark-coverage-v1.json`
- `Scripts/reproduce-lattice-estimator.sh`
- `Scripts/validate-lattice-estimator-artifact.py`
- `Docs/AuditBlockerNarrowing-2026-04-16.md`

## Production-Ready For

Within the repository's stated scope, the code is ready for:

- local and CI release-gate validation,
- implementation research,
- reproducibility review,
- verifier integration experiments with caller-owned trusted context,
- local NumiSeal product artifact generation through `NumiSealProductAPI` and
  `superneo prove --seal numiseal`,
- checked terminal, compressed-terminal, and NumiSeal artifact verification
  using explicit policy gates,
- NumiSeal product-integration experiments using protocol hooks for trusted
  context lookup, authorization, provenance verification, replay detection, and
  audit recording,
- local product-ops readiness inspection and audit export with machine-readable
  `SuperNeoProductOperationsStatus`,
- signed local revocation-feed verification and audit binding for product
  controls.

For NumiSeal, the production-facing local surface is artifact generation,
verification, and inspection of the checked immediate-residual artifact family.
`NumiSealProductAPI` is the supported proving boundary for prepared R1CS and
current frontend helpers. The shared `NumiSealArtifactVerifier` is the library
boundary for metadata validation, public obligation reconstruction, policy
construction, envelope checks, caller trust-pin checks, and final verifier
dispatch.

## Claim Boundaries

The repository-local production-security promotion does not authorize broader
claims that are outside the checked manifests, validators, and release evidence.
Do not present this repository by itself as:

- a production-secure post-quantum SNARK,
- a general zero-knowledge system for arbitrary application statements,
- a hosted verifier service, wallet, replay-protection service, or policy
  engine,
- a formally constant-time implementation,
- a Swift/LLVM/Metal hardware constant-time certificate,
- a general program-to-CCS compiler,
- a hosted NumiSeal production proving product,
- a production product-security theorem beyond the checked bounded-depth
  product security theorem surface,
- a self-owned production-hardening record for all NumiSeal product, carry,
  ZK, side-channel, and release-operation lanes.

## External Assurance Boundaries

These activities are outside the repository-local promotion gate. They may be
needed for a downstream hosted product, signed distribution, hardware
certificate, or third-party assurance program, but they do not disable the
current repository-local production-security promotion status:

1. Self-owned cryptographic and implementation review record.
2. Side-channel review for Swift, LLVM, Metal AIR/object-code lowering, CPU/GPU
   microarchitecture, allocation, power, contention, and timing behavior. The
   repository now has a checked Swift/LLVM/Metal lowering proof contract in
   `TestVectors/constant-time-lowering-evidence-v1.json` and pinned local
   release evidence in `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`
   for Swift SIL/LLVM/assembly generation, Metal AIR/metallib generation,
   runtime allocation/COW static review, CPU/GPU smoke corpora, and
   compiler/hardware observation lane reports. Scoped Swift emitted-code review,
   hardware counters, power/contention, and broader device lanes are external
   assurance expansion for stronger hardware/certificate language.
3. Deployed product implementations for trusted key distribution,
   expected-context storage, artifact provenance, replay protection,
   persistence, access control, hosted logging, and hosted revocation
   distribution. The local NumiSeal integration protocol facade, local
   product-ops readiness status, and signed revocation feed now exist, but
   durable product implementations remain outside the repository.
4. NumiSeal product/carry/ZK theorem scope is checked repository-local release
   discipline:
   `TestVectors/numiseal-conformance-scope-v1.json` tracks the current
   surfaces and conformance vectors, and
   `TestVectors/numiseal-end-to-end-theorem-scope-v1.json` pins the checked
   NumiSeal end-to-end theorem scope. That scope now includes checked Lean
   surfaces for recursive folding knowledge soundness, typed carry producer/consumer
   composition, and NumiSealZK simulation/privacy under the declared
   public-leakage model. The scope now also pins exact rejection-sampled field mask distribution
   evidence, product Swift
   trace/extractor evidence, NumiSealZK simulator-coupling evidence, and CTCO
   instantiation evidence. The current theorem is still evidence-parametric:
   accepted product gates plus named source-fold, terminal-seal,
   recursive-knowledge, typed-carry, masked-residual ZK, simulation/privacy, and
   product-policy obligations imply the composed relation. Product extractor
   loss accounting, QROM transcript schedule, QROM sampler/encoding evidence,
   QROM transform preconditions, QROM interactive reduction, QROM Fiat-Shamir
   accounting, and the total-loss budget are now checked in
   `TestVectors/product-swift-trace-extractor-evidence-v1.json`,
   `TestVectors/product-extractor-loss-accounting-v1.json`,
   `TestVectors/product-qrom-fiat-shamir-accounting-v1.json`,
   `TestVectors/product-qrom-transcript-schedule-v1.json`,
   `TestVectors/product-qrom-sampler-encoding-evidence-v1.json`,
   `TestVectors/product-qrom-collision-malleability-evidence-v1.json`,
   `TestVectors/product-qrom-ctco-instantiation-v1.json`,
   `TestVectors/product-qrom-transform-preconditions-v1.json`,
   `TestVectors/product-qrom-interactive-reduction-v1.json`, and
   `TestVectors/product-total-loss-budget-v1.json`. Product release
   distribution evidence is now checked in
   `TestVectors/product-release-distribution-evidence-v1.json`, and
   simulator-coupling evidence is checked in
   `TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json`. The
   repository-local bounded NumiSeal theorem language is allowed by these
   checked manifests and the promotion collector; hosted release review,
   release-hardware benchmark refreshes, and additional hardware side-channel
   evidence remain downstream deployment-operation choices, not repository-local
   no-go items.
   `TestVectors/product-crypto-security-dossier-v1.json` and
   `Docs/CryptographicSecurityDossier-2026-04-16.md` now pin the bounded-depth product security theorem,
   `ProductSecurityTheorem`, Fiat-Shamir/QROM
   position, Module-SIS parameter dossier, proof-size/latency boundary, and
   implementation-hardening boundary.
   `TestVectors/product-selected-depth-loss-accounting-v1.json` now pins the
   selected-depth loss accounting contract for the product theorem boundary,
   including source fold, terminal seal, carry, proof-level ZK simulator loss,
   QROM, extractor, transcript collision, product-ops replay, constant-time, and
   release-distribution loss terms. The checked dossier, ledger, extractor
   accounting, QROM accounting, QROM transform preconditions, and total-loss
   budget now enable repository-local production claims for the selected
   bounded-depth profile.
5. Broader hardware benchmark reports before making cross-generation
   competitor-performance claims. The E2E proof metrics manifest now gates checked-vector
   proof size and product-smoke size budgets, and
   `TestVectors/benchmark-coverage-v1.json` gates whole-stack benchmark row
   coverage for source fold, kernels, Metal, NumiSeal product, recursive carry,
   and product controls. Repository-local performance claims are enabled for
   those checked budgets and registered benchmark surfaces.
6. Release engineering execution: artifact digest provenance, release evidence
   digest binding, full production-gate evidence, and numeric `epsilon_release`
   budget instantiation. The changelog, reproducible release instructions,
   release evidence tooling, product release distribution evidence contract,
   and schema compatibility policies now exist and are
   checked by `Scripts/validate-release-readiness-policy.py`.

## Next Engineering Slice

The next high-leverage implementation slice is hosted product operations and
typed recursive carry promotion. The local product verifier now has trusted
context, provenance, replay, audit hooks, product-ops readiness classification,
signed revocation feed verification, audit export retention policy, and retry
policy. Production work should add durable context storage, key distribution and
rotation rollout, hosted revocation feed distribution, tenant authorization, and
hosted audit retention.

Recursive carry promotion should keep using `NumiSealCarryStatement` rather
than raw carry slots. Product producer/consumer context vectors are now pinned,
and recursive child artifacts now use `typed-required` when a verified parent is
supplied. Local product controls can now verify one parent edge with
`--recursive-carry-parent` and `--recursive-carry-parent-provenance`, require
prior parent replay acceptance, and bind the child carry context/replay roots
into SQLite replay and JSONL audit with single-use carry replay-binding
enforcement. The remaining work is hosted replay policy plus depth/loss
accounting for the selected production recursion bound.
