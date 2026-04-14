# Roadmap Status

This document maps the best-in-class roadmap to concrete repository artifacts.
It is intentionally conservative: passing items are implementation claims, not
production security certifications.

Formal status: completed formal protocol theorem.

## First Priority: Legibility

Status: implemented.

Artifacts:

- `README.md` names the implemented profile as `Goldilocks/Phi81(d=54)`.
- `Docs/Parameters.md` maps Appendix B.2 constants to code.
- `Docs/ThreatModel.md` documents assumptions, assets, adversaries, boundaries,
  and non-goals.
- `Docs/ProofEnvelope.md` specifies the version-4 envelope header, context
  binding, digest inputs, and parser rejection rules.
- `Docs/WhatThisProves.md` states what fold reductions, terminal proofs, and
  compressed public envelopes prove and do not prove.
- `SuperNeo_NuMetal.docc/SuperNeo_NuMetal.md` now has a real DocC landing page
  and symbol topics.

Remaining boundary:

- Full Module-SIS estimator reproduction requires SageMath and the canonical
  pinned upstream lattice-estimator lane. Latest-upstream runs are drift
  monitoring only and must not replace pinned evidence.

## Second Priority: Usability

Status: implemented.

Artifacts:

- `SuperNeoR1CSBuilder` encodes R1CS relations as CCS through
  `A(z) * B(z) - C(z) = 0`.
- `SuperNeoCCSNormalizer` prepares arbitrary serializable CCS inputs for the
  paper-normalized SuperNeo shape.
- `SuperNeoOneHotVectorWorkload` provides a minimal private-vector workload.
- `SuperNeoBinaryAdditionWorkload` provides a second workload with public sum
  bits, private operands, and private carries.
- The `superneo` executable supports `prove`, `verify`, and `inspect`.
- `Scripts/production-gate.sh` proves and verifies both fold and terminal
  release CLI artifacts under trusted context.
- `TestVectors/one-hot-vector-fold-v1.json` and
  `TestVectors/binary-addition-u8-fold-v1.json` are checked-in fold vectors.
- `TestVectors/one-hot-vector-terminal-v1.json` and
  `TestVectors/binary-addition-u8-terminal-v1.json` are checked-in complete
  terminal proof vectors validated under `--require-terminal`.

Remaining boundary:

- The CLI is an integration surface, not a full application frontend or
  compiler from general programs to CCS.

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
- `Docs/BenchmarkMetadataComparison-2026-04-14.md` records the metadata-aware
  benchmark comparison pass for profile, case, environment, toolchain,
  hardware, Metal, and clean-source policy checks.
- `Docs/BenchmarkReports/apple-m4-quick-2026-04-12.md` is a pinned Apple M4
  quick-profile report.
- `Docs/LeadAudit-2026-04-12.md` records the latest code audit findings,
  protocol/backend hardening work, and validation commands.
- `Docs/ProductionReadiness-2026-04-13.md` records the latest production gate,
  CLI verifier, vector manifest, and Metal allocation hardening work.
- `ProtocolE2ETests` include malformed proof-envelope and tampering tests.
- `Docs/GPUDeterminism.md` documents the CPU oracle policy and Metal
  determinism boundary.
- `SuperNeoExecutionPolicy.highAssurance` selects constant-work CPU
  commitment/evaluation paths for covered secret-bearing normalization and
  prover work, including transformed sparse ring matrix-vector multiplication.
- `SuperNeoExecutionPolicy.cpuRedundantMetal` requires CPU equality for covered
  Metal commitment and transformed-evaluation outputs.
- `SuperNeoMetalWorkspace` direct methods accept execution policies for
  CPU-redundant or CPU-only behavior at the workspace boundary.
- `SuperNeoPreparedFoldContext` is available to the benchmarking SPI so repeated
  proof measurements can reuse the transformed sparse CCS shape and bound Metal
  workspace while rejecting profile, shape, key, execution-policy, and Metal
  context mismatches.
- `SuperNeoPreparedPiRLCTranscript` is available to the benchmarking SPI so
  PiRLC stage rows can prepare and validate the post-sum-check transcript in
  benchmark setup instead of charging sum-check proving work to PiRLC timing.
- `Docs/HighAssuranceHardening-2026-04-13.md` records the side-channel,
  malicious-GPU, and estimator-reproduction hardening pass.
- `Docs/AjtaiKeyHardening-2026-04-13.md` records the fail-closed seeded Ajtai
  key dimension-overflow hardening pass.
- `Docs/KeySeedDomainSeparation-2026-04-13.md` records parameter-aware default
  key-seed derivation for bundled generated workloads while preserving checked-in
  8-bit vector compatibility.
- `Docs/BinaryAdditionArtifactMetadataHardening-2026-04-13.md` records
  fail-closed binary-addition `publicSum` metadata validation in the CLI,
  vector schema, vector validator, and production gate.
- `Docs/BinaryAdditionTerminalVector-2026-04-14.md` records the checked-in
  binary-addition terminal proof vector and strict `--require-terminal`
  validation coverage.
- `Docs/CompressedTerminalCLI-2026-04-14.md` records the CLI, schema,
  validator, and production-gate exposure for compressed public terminal
  envelopes.
- `Docs/CompressedTerminalVector-2026-04-14.md` records the checked-in one-hot
  compressed-terminal proof vector and manifest/reproduction coverage.
- `Docs/VectorManifestDuplicateKeyHardening-2026-04-14.md` records
  fail-closed duplicate-key scanning for the vector manifest and checked-in
  artifact corpus.
- `Docs/BenchmarkPiRLCIsolation-2026-04-14.md` records the PiRLC benchmark
  boundary correction and validation plan.
- `Docs/BenchmarkOpeningBatchThreshold-2026-04-14.md` records the m256 CPU
  opening-batch parallel threshold pass and validation plan.
- `Docs/BenchmarkRelationEvaluationPlan-2026-04-14.md` records the sum-check
  public relation/source evaluation-plan pass and validation plan.
- `Docs/BenchmarkSumcheckPriorBatch-2026-04-14.md` records the sum-check
  prior-claim coefficient batching pass and validation plan.
- `Docs/BenchmarkSumcheckPublicPrecompute-2026-04-14.md` records the sum-check
  public-precompute cleanup and its no-material-speedup benchmark finding.
- `Docs/BenchmarkNormPolynomialSpecialization-2026-04-14.md` records the
  default public norm-root polynomial specialization and its no-material
  aggregate benchmark finding.
- `Docs/BenchmarkTransformedEvaluationFusion-2026-04-14.md` records the CPU
  transformed-evaluation fusion pass and validation plan.
- `Docs/CLIHighAssurancePolicy-2026-04-13.md` records the CLI proof-generation
  switch to explicit `.highAssurance` execution policy.
- `Docs/ArtifactUnknownFieldHardening-2026-04-13.md` records fail-closed
  rejection of unsupported top-level proof artifact fields in the CLI, vector
  validator, and production gate.
- `Docs/WorkloadParameterCanonicality-2026-04-13.md` records exact
  workload-parameter validation for one-hot and binary-addition artifacts across
  the CLI, vector schema, vector validator, and production gate.
- `.github/workflows/production-gate.yml` runs the release build, debug and
  release XCTest suites, vector validation, and strict release CLI smoke tests
  on pull requests and `main`.
- `Scripts/production-gate.sh` provides the same local release-readiness gate,
  including positive terminal and compressed-terminal proof smoke checks and an
  opt-in quick benchmark pass.
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
- `Docs/ArtifactHeaderHardening-2026-04-13.md` records the CLI/vector
  envelope-header hardening pass.
- `Docs/ArtifactDuplicateKeyHardening-2026-04-13.md` records fail-closed CLI
  and vector-corpus rejection of duplicate JSON object keys before artifact
  decoding.

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
- `Formal/` provides a Lean 4/Lake workspace for the completed formal protocol
  theorem track. The completed dependency path uses certified Ajtai keys and
  finite bad-challenge/bad-seed certificates for PiRLC, PiCCS/sum-check, and
  terminal CE proof soundness, alongside the closed deterministic cores for
  profile constants, concrete Goldilocks/Phi81 algebra, GoldilocksExt2 wire
  operations, Phi81 splitting, field-to-ring packing, concrete Ajtai
  instantiation, PiDEC recomposition, PiRLC weighted-claim recomposition,
  transcript-bound challenge scheduling, public-Q reduction, low-degree
  root-counting, terminal CE local algebra, and verifier composition.
- `Docs/FormalStatus.json` and `Scripts/validate-formal-status.py` gate
  documentation labels against named theorem groups and verify that closed
  groups reference declarations present in the claimed Lean module without
  duplicate declaration assignment across groups. The gate also prevents
  boundary/assumption declarations from being marked closed and keeps the
  completed label dependent on every current conditional theorem group.
- `Scripts/test-formal-status-validation.py` regression-tests the formal-status
  gate by mutating temporary manifests and requiring fail-closed behavior.
- `Docs/FormalStatusPromotion-2026-04-13.md` records the partial-formalization
  promotion, validation commands, and remaining formal boundaries.
- `Docs/FormalAjtaiBinding-2026-04-13.md` records the Ajtai binding-equivalence
  formalization pass and remaining quotient-ring/protocol boundaries.
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
  continuity while keeping the active manifest on closed replacement groups.
- `Docs/PaperReproduction.md` documents the harness and interpretation rules.
- `Docs/LatticeEstimatorReproduction.md` documents the estimator command,
  pinned upstream source, and exact derived parameters.

Remaining boundary:

- The harness reproduces implementation claims against the bundled paper text.
  It does not produce a formal proof of the paper's theorems or a production
  cryptographic certification.
- The completed formal status is for the corrected model: certified verifier
  keys and finite excluded challenge/seed sets. It is not a proof that arbitrary
  Ajtai matrices are binding or that probabilistic protocols have zero bad
  transcripts.
