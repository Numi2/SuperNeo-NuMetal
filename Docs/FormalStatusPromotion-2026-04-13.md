# Formal Status Promotion, 2026-04-13

Historical note, 2026-04-17: this document is retained as the audit record for
the original partial-formalization promotion. It is superseded by the completed
formal protocol theorem status described in `Docs/FormalVerification.md` and
root `math-audit.md`.

This pass promotes the repository's formal track from `bounded formalization` to
`partial formalization`.

The promotion is intentionally narrow. It recognizes the theorem groups that are
already closed in the Lean workspace: profile constants, the abstract Ajtai
commitment map, Ajtai opening linearity, and Ajtai binding reduction under an
explicit MSIS no-short-kernel assumption. It does not claim a completed protocol
theorem.

## Findings

- `Docs/FormalStatus.json` already defined `partial formalization` as the label
  reached by the profile and Ajtai theorem groups.
- The required theorem groups for that label were marked closed or
  closed-under-assumption and had named declarations in the Lean modules.
- The status validator now resolves declared Lean modules to source files and
  checks that closed groups reference present declarations, so documentation
  labels are no longer detached from source-level theorem names.
- The GitHub `Formal Status` workflow ran the Lean build and positive manifest
  validator, but did not run the mutation-based fail-closed regression harness.
- The paper-reproduction harness also ran the positive formal-status validator
  but did not record the mutation-regression check in generated artifacts.

## Work Completed

- Set the manifest current label and tracked documentation claims to
  `partial formalization`.
- Updated status-bearing documentation to use the partial label and state the
  theorem groups that were open at the time of promotion. Later 2026-04-13
  passes closed abstract PiDEC recomposition and added assumption-scoped PiRLC,
  PiCCS, terminal CE, and verifier-composition theorem surfaces.
- Added the formal-status mutation regression harness to the GitHub formal
  workflow.
- Added the same regression harness to the paper-reproduction command list and
  execution flow.
- Extended the regression harness to prove that any future completed-protocol
  label is blocked by non-`closed` theorem groups and that documentation
  overclaims are rejected.

## Residual Boundaries

- This is not a production cryptographic certification.
- This is not an unconditional concrete proof of the full SuperNeo protocol,
  terminal CE proof system, PiRLC probability bound, PiCCS sum-check soundness
  probability, or side-channel resistance. Abstract PiDEC commitment
  recomposition is tracked separately in
  `Docs/FormalPiDECRecomposition-2026-04-13.md`; the assumption-scoped protocol
  composition pass is tracked in
  `Docs/FormalProtocolComposition-2026-04-13.md`.
- The Ajtai binding statement remains conditional on the explicit MSIS
  no-short-kernel assumption represented in the Lean model.
- Local validation in this workspace now runs `lake build` through elan. The
  GitHub formal workflow remains the authoritative shared proof-build gate for
  formal changes.

## Validation

Commands run locally on 2026-04-13:

```sh
(cd Formal && lake build)
Scripts/validate-formal-status.py
Scripts/test-formal-status-validation.py
swift test --disable-swift-testing --filter ProtocolShapeTests/testGoldilocksParameterProfileMatchesPaperProfile
Scripts/production-gate.sh
```

Results:

- Lean build: passed where `lake` is available through elan.
- Formal manifest validation: passed.
- Formal-status mutation regression tests: passed.
- Goldilocks/Phi81 profile test: passed.
- Production gate: passed, including release build, debug and release XCTest
  suites, checked-in vector validation, lattice-estimator dry-run validation,
  formal-status validation, formal-status regression tests, and strict release
  CLI proof/verify smoke checks.
