# Formal PiDEC Recomposition Pass, 2026-04-13

Formal status: completed formal protocol theorem.

This pass adds a Lean module for the algebraic recomposition boundary used by
the PiDEC verifier.

## Work Completed

`Formal/SuperNeoFormal/PiDEC.lean` models scalar-power recomposition over the
same abstract commutative ring used by the Ajtai formalization. It defines:

- `pidecScalarPower`,
- `pidecWeightedSum`,
- `pidecWeightedMessage`, and
- `pidecWeightedCommitment`.

The core theorem is `commit_pidecWeightedMessage`: committing the weighted sum
of limb messages equals the weighted sum of the limb commitments. This is the
commitment-side algebra behind the Swift verifier's PiDEC check, which
recombines decomposition limbs with powers of the norm-bound base and compares
the result to the folded claim.

The module also records `pidec_commitment_recomposition` and
`pidec_opening_recomposition`, giving named theorem surfaces for recomposed
commitments and openings.

## Manifest Update

`Docs/FormalStatus.json` now marks the `pidec-recomposition` theorem group
closed and points it at `SuperNeoFormal.PiDEC`.

## Trust Boundary

This is not a full PiDEC soundness theorem by itself and does not close an
unconditional full SuperNeo protocol theorem. It closes the commitment
recomposition algebra over the current abstract ring model. A later
2026-04-13 pass added assumption-scoped PiRLC, PiCCS, terminal CE, and verifier
composition theorem surfaces, and the 2026-04-17 formal cleanup superseded that
intermediate status with the completed finite formal protocol theorem label.
