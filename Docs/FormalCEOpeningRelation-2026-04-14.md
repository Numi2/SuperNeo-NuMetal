# CE Opening Local Relation Formal Slice

Formal status: conditional protocol formalization

This note records the April 14, 2026 local CE opening relation work in
`Formal/SuperNeoFormal/CEOpeningRelation.lean`.

## What closed

- Added a formal public context for the profile ID, shape digest, and verifier
  key digest that Swift binds in `CEOpeningStatement`.
- Added a formal CE opening shape and a compatibility predicate for rows,
  Ajtai columns, public inputs, matrix evaluations, and evaluation-point arity.
- Defined `CELocalOpeningRelation`, which combines:
  - shape compatibility,
  - public context equality,
  - public-input boundedness,
  - Ajtai commitment opening,
  - matrix-evaluation relation satisfaction.
- Proved projections from a verified local opening to its commitment equation
  and evaluation relation.
- Proved local witness uniqueness under `NoShortKernel`, matching the existing
  Ajtai binding assumption boundary.
- Connected terminal CE statements to batches of local openings through
  `CETerminalLocalBatchRelation`.
- Added concrete profile shape helpers with rows fixed to `kappa`.

## Boundary kept explicit

This is the local algebraic relation, not a proof of Stern transcript soundness.
The public CE proof verifier remains represented by
`TerminalCEProofSoundnessAssumption`, so the global terminal CE theorem group
stays under `closed_under_ce_opening_assumption`.

## Verification

The module builds as part of `lake build`, and its declaration group is tracked
by `Docs/FormalStatus.json`.
