# Roadmap Status

This document maps the best-in-class roadmap to concrete repository artifacts.
It is intentionally conservative: passing items are implementation claims, not
production security certifications.

Formal status: bounded formalization.

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
- `TestVectors/one-hot-vector-terminal-v1.json` is a checked-in complete
  terminal proof vector validated under `--require-terminal`.

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
- `Docs/HighAssuranceHardening-2026-04-13.md` records the side-channel,
  malicious-GPU, and estimator-reproduction hardening pass.
- `.github/workflows/production-gate.yml` runs the release build, debug and
  release XCTest suites, vector validation, and strict release CLI smoke tests
  on pull requests and `main`.
- `Scripts/production-gate.sh` provides the same local release-readiness gate,
  including a positive terminal proof smoke check and an opt-in quick benchmark
  pass.
- `TestVectors/manifest.json` gives file hashes, byte counts, workloads,
  trusted expected verifier context, proof-kind requirements, and strict
  verification commands.
- `TestVectors/artifact.schema.json` defines the public artifact schema.
- `ProofEnvelopeHeader.parsePrefix(from:)` gives CLI and artifact tooling the
  same strict envelope-header parser used by proof-envelope decoding.
- `Scripts/validate-test-vectors.swift` checks vector hashes, schema invariants,
  workload-specific public input rules, strict envelope header agreement, and
  CLI verification.
- `Docs/ArtifactHeaderHardening-2026-04-13.md` records the CLI/vector
  envelope-header hardening pass.

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
- `Formal/` provides a Lean 4/Lake workspace for the bounded formalization
  track, starting with the concrete Ajtai commitment map and binding reduction
  under an explicit MSIS no-short-kernel assumption.
- `Docs/FormalStatus.json` and `Scripts/validate-formal-status.py` gate
  documentation labels against named theorem groups and verify that closed
  groups reference declarations present in the claimed Lean module.
- `Scripts/test-formal-status-validation.py` regression-tests the formal-status
  gate by mutating temporary manifests and requiring fail-closed behavior.
- `Docs/PaperReproduction.md` documents the harness and interpretation rules.
- `Docs/LatticeEstimatorReproduction.md` documents the estimator command,
  pinned upstream source, and exact derived parameters.

Remaining boundary:

- The harness reproduces implementation claims against the bundled paper text.
  It does not produce a formal proof of the paper's theorems or a production
  cryptographic certification.
- Documentation remains at `bounded formalization` until the formal status
  manifest closes the full protocol composition theorem group.
