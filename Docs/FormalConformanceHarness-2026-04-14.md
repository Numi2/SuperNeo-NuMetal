# Formal Conformance Harness Progress, 2026-04-14

Formal status: conditional protocol formalization

This pass adds a drift check between the implemented Swift profile and the Lean
formal constants.

## Added scripts

- `Scripts/validate-formal-profile-constants.py`
  - Compares the Lean Goldilocks modulus against `GoldilocksField.modulus`.
  - Compares Lean `phi81Degree` against `CyclotomicRing54.degree` and Swift
    `ringDegree`.
  - Compares Lean `phi81Index`, `kappa`, `normBound`,
    `decompositionLength`, `challengeExpansionFactor`, `freshBatchCount`, and
    `paperClaimThresholdBits` against the Swift profile.
  - Checks Swift `maxPriorClaimCount` stays tied to Lean
    `decompositionLength`.
  - Compares the Lean challenge coefficient set against Swift
    `challengeCoefficients`.
  - Compares Lean proof-envelope magic, version, proof-kind tags, and
    transcript-binding byte length against `ProofEnvelopeHeader` and
    `ProofEnvelopeKind`.

- `Scripts/test-formal-profile-constants-validation.py`
  - Runs the validator against the repository.
  - Mutates a temporary Lean `kappa` constant and requires validation failure.
  - Mutates a temporary Lean challenge coefficient set and requires validation
    failure.
  - Mutates temporary Lean proof-envelope magic, transcript-binding length, and
    proof-kind tags and requires validation failure.

## Gate integration

`Scripts/production-gate.sh` now runs both the profile-constant validator and
its mutation tests after the Lean build and formal-status validation.

## What remains open

The validator catches profile constant drift, but it is still a comparison
harness rather than a single-source generator. A later pass can move both Swift
and Lean constants to a generated source derived from one checked JSON profile.
