# Roadmap Status

This document maps the repository roadmap to concrete artifacts and remaining
boundaries. It is intentionally conservative: passing items are implementation
claims, not production security certifications.

Formal status: completed formal protocol theorem.

## First Priority: Legibility

Status: implemented for the current prover track.

Artifacts:

- `README.md` names the implemented profile as `Goldilocks/Phi81(d=54)`.
- `Docs/ParameterSecurityDossier-2026-04-16.md` maps the active parameter
  profile, estimator boundary, and assumption-scoped parameter claims.
- `Docs/WhatThisProves.md` and
  `Docs/AuditBlockerNarrowing-2026-04-16.md` document assumptions, assets,
  adversaries, proof semantics, boundaries, and non-goals.
- `Docs/ProofEnvelope.md` specifies the version-5 envelope header, context
  binding, digest inputs, and parser rejection rules.
- `SuperNeo-NuMetal/SuperNeo_NuMetal.docc/SuperNeo_NuMetal.md` now has a real
  DocC landing page and symbol topics.

Estimator boundary:

- Full Module-SIS estimator reproduction requires SageMath and the canonical
  pinned upstream lattice-estimator lane. The 2026-04-16 audit pass ran that
  pinned lane under SageMath 10.8 and recorded the disposition in
  `Docs/AuditBlockerNarrowing-2026-04-16.md`. Latest-upstream runs are drift
  monitoring only and must not replace pinned evidence.

## Second Priority: Usability

Status: implemented for hand-authored CCS/R1CS statements.

Artifacts:

- `SuperNeoR1CSBuilder` encodes R1CS relations as CCS through
  `A(z) * B(z) - C(z) = 0`.
- `SuperNeoR1CSAssignment`, `SuperNeoR1CSWitnessGenerator`,
  `SuperNeoR1CSProgram`, and `SuperNeoR1CSProvingStack` provide a public
  hand-authored R1CS frontend path from generated witness assignment to
  fold/terminal/compressed proof envelope, terminal verifier policy, and
  NumiSeal product artifacts through `NumiSealProductAPI`.
- `Docs/R1CSFrontendAPI-2026-04-15.md` records the frontend API boundary,
  validation path, and non-claims.
- `SuperNeoCCSNormalizer` prepares arbitrary serializable CCS inputs for the
  paper-normalized SuperNeo shape.
- `SuperNeoOneHotVectorWorkload` provides a minimal private-vector workload.
- `SuperNeoBinaryAdditionWorkload` provides a second workload with public sum
  bits, private operands, and private carries.
- The `superneo` executable supports `prove`, `verify`, and `inspect`.
- `superneo prove --seal numiseal` routes through the supported public
  NumiSeal product API and emits trusted-context, trace/extractor, CTCO, QROM,
  and optional proof-level ZK simulator-coupling metadata.
- `SuperNeoTerminalProofAcceptancePolicy` gives application code a reusable
  terminal-only envelope acceptance surface for terminal and compressed-terminal
  proof bytes, rejecting fold reductions before terminal verification. It also
  supports direct trusted-public-input construction, strict terminal/compressed
  proof-kind policy, and optional proof byte limits.
- `Scripts/production-gate.sh` proves and verifies both fold and terminal
  release CLI artifacts under trusted context.
- `TestVectors/one-hot-vector-fold-v1.json` and
  `TestVectors/binary-addition-u8-fold-v1.json` are checked-in fold vectors.
- `TestVectors/one-hot-vector-terminal-v1.json` and
  `TestVectors/binary-addition-u8-terminal-v1.json` are checked-in complete
  terminal proof vectors validated under `--require-terminal`.

Remaining boundary:

- `SuperNeoR1CSProgram` is a hand-authored R1CS frontend and witness-generation
  boundary. It is not a compiler from general programs to CCS, a persistence
  layer, a replay-protection system, or an application identity/key-distribution
  system.
- The CLI is still a local integration surface, not a hosted verifier service,
  wallet, durable replay-protection layer, or application policy engine.
  NumiSeal acceptance is exposed through the default strict verifier path for
  checked immediate-residual artifacts, the public
  `NumiSealProductAPI` generation path, and the protocol-based
  `SuperNeoNumiSealProductVerifier` facade for product integration experiments.

## Third Priority: Credibility

Status: implemented for the current repository scope.

Artifacts:

- `Docs/Benchmarking.md` documents benchmark profiles, correctness gates, and
  baseline policy.
- `Scripts/compare-benchmark-results.swift` turns the benchmark baseline policy
  into a machine-checkable gate with 5% kernel and 10% protocol thresholds by
  default; `Scripts/run-benchmarks.sh` can invoke it automatically when
  `SUPERNEO_BENCHMARK_BASELINE` is set.
- `Scripts/test-benchmark-tooling-validation.py` mutation-tests benchmark
  comparator and report-rendering failure modes before benchmark evidence is
  trusted by the production gate.
- `TestVectors/benchmark-coverage-v1.json` records the checked benchmark
  surface contract, and `Scripts/validate-benchmark-coverage.py` gates it.
- `Docs/BenchmarkReports/README.md` is the checked-in benchmark-report index;
  fresh hardware timing reports are generated artifacts and are not bundled as
  audit evidence in this checkout.
- `Docs/ProductionReadinessAuditPacket-2026-04-16.md` records the current full
  release-gate evidence map, passed full local gate, and remaining no-go items
  before production-security language is appropriate.
- `Docs/AuditBlockerNarrowing-2026-04-16.md` records the latest side-channel,
  product-integration, formal-blocker, and Sage-estimator audit disposition.
- `Docs/ProductIntegrationLayer-2026-04-16.md` records the first executable
  NumiSeal product-verification facade for trusted context lookup,
  authorization, provenance verification, replay checking, product byte limits,
  and audit events.
- `ProtocolE2ETests` include malformed proof-envelope and tampering tests.
- `Docs/ConstantTimeEvidence-2026-04-16.md` documents the CPU oracle policy,
  constant-work source scope, and Metal determinism boundary.
- `SuperNeoExecutionPolicy.highAssurance` selects constant-work CPU
  commitment/evaluation paths for covered secret-bearing normalization and
  prover work, including transformed sparse ring matrix-vector multiplication.
- `SuperNeoExecutionPolicy.cpuRedundantMetal` requires CPU equality for covered
  Metal commitment and transformed-evaluation outputs.
- `SuperNeoMetalWorkspace` direct methods accept execution policies for
  CPU-redundant or CPU-only behavior at the workspace boundary.
- `CommitmentScheme` and `AjtaiSuperNeoCommitment` expose a concrete commitment
  backend boundary with seeded/system-random setup, local opening verification,
  batch commits, verifier-key digesting, shape-bound fail-closed checks, and
  profile-tagged key serialization.
- `Docs/CryptographicSecurityDossier-2026-04-16.md` records the implemented
  backend boundary, non-claims, and targeted validation.
- `SuperNeoPreparedFoldContext` is available to the benchmarking SPI so repeated
  proof measurements can reuse the transformed sparse CCS shape and bound Metal
  workspace while rejecting profile, shape, key, execution-policy, and Metal
  context mismatches.
- `SuperNeoPreparedPiRLCTranscript` is available to the benchmarking SPI so
  PiRLC stage rows can prepare and validate the post-sum-check transcript in
  benchmark setup instead of charging sum-check proving work to PiRLC timing.
- `Docs/CLI.md`, `Docs/SchemaCompatibility-2026-04-16.md`, and
  `Docs/NumiSealCLIExposure-2026-04-16.md` record the current fail-closed CLI,
  artifact-schema, duplicate-key, terminal-envelope, and workload-parameter
  validation boundaries.
- `Docs/ProductIntegrationLayer-2026-04-16.md` and
  `Docs/ProductOperationsReadiness-2026-04-16.md` record the current product
  integration, local controls, replay, revocation, provenance, and audit-event
  surfaces.
- `.github/workflows/production-gate.yml` runs a short XCTest smoke job on
  pull requests, while the full release build, debug and release XCTest suites,
  vector validation, and strict release CLI smoke tests run on `main` and
  manual dispatch.
- `Scripts/production-gate.sh` provides the same local release-readiness gate,
  including positive terminal and compressed-terminal proof smoke checks and an
  opt-in quick benchmark pass.
- `Docs/ReleaseEngineering-2026-04-16.md` defines the current research release
  bar and the separate blockers for production-security release language.
- `Docs/SchemaCompatibility-2026-04-16.md` records the public artifact,
  manifest, and proof-envelope compatibility rules.
- `Scripts/validate-release-readiness-policy.py` checks release policy, schema
  compatibility, and CI full-gate drift.
- `Docs/ReleaseCandidateRunbook-2026-04-16.md`, `CHANGELOG.md`, and the
  release-candidate evidence scripts define a reproducible research/integration
  release path.
- `TestVectors/manifest.json` gives file hashes, byte counts, workloads,
  trusted expected verifier context, proof-kind requirements, and strict
  verification commands.
- `TestVectors/artifact.schema.json` defines the public artifact schema.
- `ProofEnvelopeHeader.parsePrefix(from:)` gives CLI and artifact tooling the
  same strict envelope-header parser used by proof-envelope decoding.
- `Scripts/validate-test-vectors.swift` checks vector hashes, duplicate JSON
  keys before decoding, exact manifest key allowlists, schema invariants,
  workload-specific public input rules, strict envelope header agreement, and
  CLI verification.
- `Scripts/test-vector-manifest-validation.py` mutation-tests vector manifest
  uniqueness, raw duplicate-key rejection, unknown manifest-key rejection,
  required proof-kind coverage, and checked-file coverage.
- `Scripts/validate-artifact-schema.py` checks that the published artifact
  schema preserves exact root and workload-parameter rejection rules.
- `Scripts/test-artifact-schema-validation.py` regression-tests the artifact
  schema checker against temporary loosened schemas and requires fail-closed
  behavior.
- `Scripts/validate-doc-links.py` rejects broken local Markdown evidence links
  before the release gate can report audit docs as current.

Remaining boundary:

- Hardware-class reports are currently present for Apple M4. Add M1, M2, M3,
  M4 Pro/Max/Ultra, and future generations before making cross-generation
  performance claims.

## Fourth Priority: Influence

Status: implemented as a reproducibility harness; research-artifact expansion
continues.

Artifacts:

- `Scripts/reproduce-superneo-paper.sh` produces a paper-claim reproduction
  artifact in `plan`, `snapshot`, `quick`, `scaling`, or `full` mode.
- `Scripts/render-paper-reproduction.swift` maps SuperNeo paper claims to
  repository evidence, commands, benchmark selectors, vectors, and reports.
- `Scripts/reproduce-lattice-estimator.sh` derives the implemented GL
  Module-SIS estimator tuple and can run the pinned upstream estimator under
  SageMath, with an optional latest-upstream monitoring lane.
- `Scripts/validate-lattice-estimator-artifact.py` validates the pinned source,
  profile constants, derived SIS tuple, normalized estimator rows, threshold
  semantics, and lane separation.
- `Formal/` provides a Lean 4/Lake workspace for the completed finite formal
  protocol theorem. The current dependency path uses certified Ajtai keys and
  finite bad-challenge/bad-seed evidence for PiRLC, constructive PiCCS
  sum-check soundness, and constructive terminal CE proof soundness, alongside
  the closed deterministic cores for
  profile constants, concrete Goldilocks/Phi81 algebra, GoldilocksExt2 wire
  operations, Phi81 splitting, field-to-ring packing, concrete Ajtai
  instantiation, PiDEC recomposition, PiRLC weighted-claim recomposition,
  well-formed transcript-bound challenge scheduling, 384-bit theorem-critical
  binding, public-Q reduction, low-degree root-counting, sum-check prefix
  bad-challenge aggregation, terminal CE local algebra, finite-uniform
  error-ledger bookkeeping, and verifier composition.
- `Docs/FormalStatus.json` and `Scripts/validate-formal-status.py` gate
  documentation labels against named theorem groups and verify that closed
  groups reference declarations present in the claimed Lean module without
  duplicate declaration assignment across groups. The gate also prevents
  boundary/assumption declarations from appearing in completed-theorem groups
  and requires the former theorem-critical integration gates to be closed before
  the completed label is active.
- `Scripts/test-formal-status-validation.py` regression-tests the formal-status
  gate by mutating temporary manifests and requiring fail-closed behavior.
- `Docs/FormalStatusPromotion-2026-04-13.md` records the historical
  partial-formalization promotion, validation commands, and boundaries that were
  later superseded by the completed formal protocol theorem status.
- `Docs/FormalPiDECRecomposition-2026-04-13.md` records the abstract PiDEC
  recomposition formalization pass.
- `Docs/FormalProtocolComposition-2026-04-13.md` records the assumption-scoped
  PiRLC, PiCCS, terminal CE, and verifier-composition formalization pass.
- `Docs/FormalAssumptionLedger-2026-04-14.md` records the replacement of the
  old assumption-boundary dependency path with certified-key and finite
  bad-seed theorem groups.
- `Docs/FormalRemainingBoundaries-2026-04-14.md` records the historical boundary
  IDs and their closed replacement groups.
- The latest Lean pass keeps historical boundary IDs documented for audit
  continuity while keeping the active manifest on corrected-core groups plus
  closed theorem-critical integration gates.
- `Scripts/render-paper-reproduction.swift` documents and renders the
  paper-claim reproduction artifact format.
- `Scripts/reproduce-lattice-estimator.sh` and
  `Scripts/validate-lattice-estimator-artifact.py` document and validate the
  estimator command, pinned upstream source, and exact derived parameters.

Remaining boundary:

- The harness reproduces implementation claims against the bundled paper text.
  It does not produce a formal proof of the paper's theorems or a production
  cryptographic certification.
- The current formal status is a completed formal protocol theorem for the
  finite model: certified verifier keys, finite excluded challenge/seed sets,
  theorem-facing transcript and digest layers, closed terminal CE/PiRLC
  integration gates, and exact finite probability modules. It is not a proof
  that arbitrary Ajtai matrices are binding or that the implementation has
  completed side-channel or production operational certification.

## Fifth Priority: NumiSeal Terminal Seal

Keep detailed completed work out of this status file. Use
`Docs/NumiSealFullStackRoadmap-2026-04-15.md` for the active checklist and
`Docs/ProofEnvelope.md` for byte-format details.

Status:

- [x] Checked immediate-residual NumiSeal verifier/inspection surface exists.
- [x] Kind `4` envelope, NumiSeal proof body, terminal policy, lane aggregation,
  decomposition, scalarization, sum-check, immediate residual CE opening,
  checked vectors, CLI verification, and product verifier facade exist.
- [x] SuperNeo formal status is a corrected finite-model core with open
  theorem-critical integrations.
- [x] Public NumiSeal proving/product exposure exists through
  `NumiSealProductAPI` and `superneo prove --seal numiseal`.
- [x] Supported frontend-to-NumiSeal obligation path exists for prepared R1CS,
  one-hot, binary-addition, and hand-authored R1CS programs with trusted context
  packs.
- [x] Swift trace/extractor, ZK simulator-coupling, and CTCO/QROM instantiation
  evidence manifests are checked and production-gated.
- [x] Local recursive carry can continue through previously accepted recursive
  parents using signed provenance, replay-ledger acceptance, and carry replay
  roots.
- [ ] Complete NumiSeal production product.

Remaining checklist:

- [ ] Hosted selected-depth recursive carry policy and loss accounting.
- [x] Product-mode `NumiSealZK` is now the default for CLI and public product
  proving APIs. Signed side-channel certificates remain optional release
  metadata and are checked only when supplied.
- [ ] Deployed product operations: context storage, keys, provenance, replay,
  authz, hosted audit retention, hosted revocation feed distribution, release
  signing.
- [ ] NumiSeal-specific product/carry/ZK formalization tracked by
  `TestVectors/numiseal-conformance-scope-v1.json`.
- [ ] Self-owned cryptographic, implementation, and side-channel review record.

Safe wording:

> NumiSeal generates and verifies checked immediate-residual product artifacts
> through supported Swift and CLI surfaces. It is not yet a
> recursive-by-default or a deployed production product.
