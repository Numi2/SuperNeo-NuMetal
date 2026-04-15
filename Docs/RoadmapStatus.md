# Roadmap Status

This document maps the repository roadmap to concrete artifacts and remaining
boundaries. It is intentionally conservative: passing items are implementation
claims, not production security certifications.

Formal status: conditional protocol formalization.

## First Priority: Legibility

Status: implemented for the current prover track.

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

Status: implemented for hand-authored CCS/R1CS statements.

Artifacts:

- `SuperNeoR1CSBuilder` encodes R1CS relations as CCS through
  `A(z) * B(z) - C(z) = 0`.
- `SuperNeoR1CSAssignment`, `SuperNeoR1CSWitnessGenerator`,
  `SuperNeoR1CSProgram`, and `SuperNeoR1CSProvingStack` provide a public
  hand-authored R1CS frontend path from generated witness assignment to
  fold/terminal/compressed proof envelope and terminal verifier policy.
- `Docs/R1CSFrontendAPI-2026-04-15.md` records the frontend API boundary,
  validation path, and non-claims.
- `SuperNeoCCSNormalizer` prepares arbitrary serializable CCS inputs for the
  paper-normalized SuperNeo shape.
- `SuperNeoOneHotVectorWorkload` provides a minimal private-vector workload.
- `SuperNeoBinaryAdditionWorkload` provides a second workload with public sum
  bits, private operands, and private carries.
- The `superneo` executable supports `prove`, `verify`, and `inspect`.
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
- The CLI is still a demo/integration surface, not a production verifier
  service.

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
- `CommitmentScheme` and `AjtaiSuperNeoCommitment` expose a concrete commitment
  backend boundary with seeded/system-random setup, local opening verification,
  batch commits, verifier-key digesting, shape-bound fail-closed checks, and
  profile-tagged key serialization.
- `Docs/AjtaiCommitmentBackend-2026-04-15.md` records the implemented backend
  boundary, non-claims, and targeted validation.
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
- `Formal/` provides a Lean 4/Lake workspace for the conditional formal
  protocol track. The current dependency path uses certified Ajtai keys and
  finite bad-challenge/bad-seed certificates for PiRLC, PiCCS/sum-check, and
  terminal CE proof soundness, alongside the closed deterministic cores for
  profile constants, concrete Goldilocks/Phi81 algebra, GoldilocksExt2 wire
  operations, Phi81 splitting, field-to-ring packing, concrete Ajtai
  instantiation, PiDEC recomposition, PiRLC weighted-claim recomposition,
  transcript-bound challenge scheduling, public-Q reduction, low-degree
  root-counting, sum-check prefix bad-challenge aggregation, terminal CE local
  algebra, finite error-ledger bookkeeping, and verifier composition.
- `Docs/FormalStatus.json` and `Scripts/validate-formal-status.py` gate
  documentation labels against named theorem groups and verify that closed
  groups reference declarations present in the claimed Lean module without
  duplicate declaration assignment across groups. The gate also prevents
  boundary/assumption declarations from being marked closed and keeps the full
  theorem label dependent on every current conditional theorem group plus the
  explicit planned blocker groups.
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
- The current formal status is conditional for the corrected model: certified
  verifier keys and finite excluded challenge/seed sets. It is not a proof that
  arbitrary Ajtai matrices are binding, that probabilistic protocol bounds have
  been fully composed, that Swift Ext2 serialization has been proved equivalent
  for every caller, or that the Swift CE verifier has been proved byte-for-byte
  equivalent.

## Fifth Priority: NumiSeal Terminal Seal

Status: design refreshed; Phase 0 public statement wiring, Phase 1 lane
aggregation, Phase 2 proof-body policy separation, Phase 3 decomposition
handoff, Phase 4 public scalarization, the bounded Phase 5 sum-check handoff,
and the first typed Phase 6 residual-opening handoff are present.

NumiSeal is the planned native terminal-seal layer for the SNARK product track.
It should compress many terminal CE obligations into lane-local aggregates while
staying inside the active Goldilocks/Phi81/Ajtai profile and using the existing
CE opening relation as the residual base case.

Artifacts:

- `SuperNeo-NuMetal/NumiSeal-v10-design.md` is now a repository-grounded v10
  implementation plan. It removes stale external-drafting context, removes
  non-actionable citation artifacts, and defines the current target in terms of
  shipped repository APIs.
- `Docs/NumiSealFullStackRoadmap-2026-04-15.md` maps the remaining execution
  path from proof body grammar, envelope policy, decomposition, scalarization,
  degree-4 sum-check, residual opening, prover/verifier assembly, and vectors
  through recursion, zero knowledge, frontend expansion, verifier/API product
  surface, and research-governance work.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealTypes.swift` defines lane IDs,
  lane keys, acceptance policy, terminal obligations, canonical obligations,
  lane summaries, and digest-list roots.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealCanonicalization.swift` validates
  policy bindings, derives evaluation-point digests, sorts obligations
  deterministically, groups by lane key, and emits obligation/lane summary
  roots.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealWire.swift` provides bounded
  readers for the NumiSeal wire objects introduced so far.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealPublicStatement.swift` defines a
  versioned, parseable public statement that binds policy context, obligation
  root, lane summary root, and sorted lane summaries before later proof-body
  work.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealLaneAggregation.swift` chunks
  canonical lane spans under profile limits, derives deterministic lane-local
  RLC challenges from the public-statement digest, computes public aggregate CE
  instances, and gives every aggregate a parse-checked digest.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealAggregateEvaluation.swift`
  rebuilds witnessed aggregate claims from canonical RLC challenges and checks
  aggregate commitments plus sparse transformed CCS evaluations against the
  existing shape/key machinery.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealProof.swift` defines the
  versioned NumiSeal proof-body grammar, lane-proof parser, typed component
  digest leaves, absent carry leaf, `numiSealTerminal` envelope, and
  NumiSeal-only terminal preflight policy.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealDecomposition.swift` defines
  deterministic decomposition-key derivation, a bounded ternary digit-tensor
  grammar, zero-padding enforcement, CPU reference decomposition commitments,
  and opening checks for the next NumiSeal algebraic phase.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealScalarization.swift` defines
  scalarization statements, transcript-derived public weights, parse-checked
  linear residuals, and stale-statement rejection before the degree-4
  sum-check phase.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealSumcheck.swift` defines the
  bounded reference sum-check handoff over the scalar residual and digit-tensor
  ternary/padding language, using the existing sum-check prover/verifier.
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealProof.swift` also defines the
  typed immediate residual-opening body, binding lane scope, scalarization
  digest, sum-check proof digest, canonical terminal CE statement bytes,
  canonical CE opening proof bytes, and a recomputed residual-opening digest.
  Its full-verification path now accepts public shape/key material and calls
  `CEOpeningRelation.verify` for supplied immediate residual CE openings after
  the cheap preflight bindings pass.
- `NumiSealCanonicalizationTests` cover deterministic sorting independent of
  input order, lane separation by evaluation point, fail-closed policy mismatch
  rejection, public-statement serialization, deterministic aggregate chunking,
  lane-scoped aggregate indexing, aggregate byte tamper rejection,
  incompatible public-input rejection,
  proof-body mutation rejection, lane-proof ordering, absent carry digest
  binding, envelope-kind separation, decomposition-key public binding,
  digit-tensor mutation/padding rejection, CPU decomposition commitment opening,
  witnessed aggregate sparse CCS reconstruction, scalarization residual
  mutation/stale-statement rejection, sum-check residual/digit-tensor binding,
  residual-opening digest/scope/count binding, residual CE opening proof
  verification, complete lane-summary coverage, contiguous aggregate-index
  coverage, and NumiSeal policy preflight rejection.
- The design explicitly separates the shipped prover track from the planned
  SNARK product track.
- The design requires lane-key canonicalization, typed digest roots,
  no zero-digest placeholders, one decomposition commitment per lane aggregate,
  degree-4 sum-checks, residual CE opening, recursive carry encoding, and
  terminal-only verifier policy.
- The design states non-claims: no default zero knowledge, no external PCS
  import, no QROM proof claim, no cross-lane batching, and no production
  certification.

Implementation gates:

- Phase 0: NumiSeal public types, canonicalization, lane-key derivation, policy
  rejection, digest-root fixtures, public-statement serialization, and aggregate
  serialization. Lane-local RLC and deterministic lane chunking under profile
  limits are present for public aggregates.
- Phase 1: proof-body grammar, bounded parsers, typed component leaves, absent
  carry binding, lane-proof ordering, lane-summary coverage checks, transcript
  digest recomputation, and parser/mutation tests are present.
- Phase 2: `ProofEnvelopeKind.numiSealTerminal = 4`, NumiSeal proof envelopes,
  and NumiSeal-only terminal preflight policy are present.
- Phase 3: deterministic decomposition-key derivation, bounded digit-tensor
  grammar, one CPU reference Ajtai digit-tensor commitment per lane aggregate,
  and parser/mutation tests are present. Full aggregate witness decomposition
  and verifier handoff remain.
- Phase 4: public scalarization statements, transcript-derived weights, linear
  residual digests, witnessed aggregate sparse CCS reconstruction, and
  mutation/stale-statement tests are present. Multi-lane/prior-claim vectors
  remain.
- Phase 5: degree-4 sum-check prover/verifier with invalid digit, padding, and
  scalarization tamper tests. A bounded reference sum-check handoff is present;
  the optimized large-tensor prover/verifier remains.
- Phase 6: typed immediate residual-opening parsing, preflight digest/scope
  binding, and full verification of supplied immediate residual CE opening
  proofs through the existing CE relation are present. The stable internal
  residual shape digest and residual witness builder remain.
- Phase 7: NumiSeal prover/verifier API, full algebraic verification, vectors,
  and production-gate coverage remain.

Remaining boundary:

- NumiSeal is not a complete terminal proof mode yet. The current complete
  terminal proof remains `terminalLocal` or `compressedPublic`; NumiSeal must
  not be advertised as an available verifier mode until Phase 6 passes.
- The zero-knowledge product track still needs a separate `NumiSealZK` design
  and proof story.
