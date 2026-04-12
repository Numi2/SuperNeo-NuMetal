# Roadmap Status

This document maps the best-in-class roadmap to concrete repository artifacts.
It is intentionally conservative: passing items are implementation claims, not
production security certifications.

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

- The repository does not claim independent verification of the paper's
  Module-SIS estimator scripts.

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
- `TestVectors/one-hot-vector-fold-v1.json` and
  `TestVectors/binary-addition-u8-fold-v1.json` are checked-in fold vectors.

Remaining boundary:

- The CLI is an integration surface, not a full application frontend or
  compiler from general programs to CCS.

## Third Priority: Credibility

Status: implemented for the current repository scope.

Artifacts:

- `Docs/Benchmarking.md` documents benchmark profiles, correctness gates, and
  baseline policy.
- `Docs/BenchmarkReports/apple-m4-quick-2026-04-12.md` is a pinned Apple M4
  quick-profile report.
- `ProtocolE2ETests` include malformed proof-envelope and tampering tests.
- `Docs/GPUDeterminism.md` documents the CPU oracle policy and Metal
  determinism boundary.
- `TestVectors/manifest.json` gives file hashes, byte counts, workloads, and
  verification commands.
- `TestVectors/artifact.schema.json` defines the public artifact schema.
- `Scripts/validate-test-vectors.swift` checks vector hashes, basic schema
  invariants, workload-specific public input rules, and CLI verification.

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
- `Docs/PaperReproduction.md` documents the harness and interpretation rules.

Remaining boundary:

- The harness reproduces implementation claims against the bundled paper text.
  It does not independently re-run Appendix D.8 lattice-estimator scripts or
  produce a formal proof of the paper's theorems.
