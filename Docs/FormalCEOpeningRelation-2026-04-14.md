# CE Opening Local Relation Formal Slice

Formal status: completed formal protocol theorem.

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
- Proved `ceLocalOpening_distinct_witnesses_yield_short_kernel`: two distinct
  local witnesses for the same CE statement produce an explicit nonzero
  bounded-difference kernel vector.
- Connected terminal CE statements to batches of local openings through
  `CETerminalLocalBatchRelation`.
- Proved terminal-batch projections for shape compatibility, context equality,
  public-input boundedness, commitment equality, and evaluation-relation
  satisfaction at each output index.
- Proved `ceTerminalLocalBatch_distinct_witnesses_yield_short_kernel`, the
  terminal-batch version of the same distinct-witness reduction.
- Added concrete profile shape helpers with rows fixed to `kappa`.

## Completed Replacement

This is the local algebraic relation, not a proof of Stern transcript soundness.
The terminal local batch declarations are now tracked as the closed
`terminal-ce-local-batch` group, with the base terminal statement relation
tracked separately as `terminal-ce-statement-core`. The public CE proof verifier
is now represented on the conditional dependency path by
`TerminalCEFiniteBadSeedCertificate`, which extracts local batch witnesses
outside the explicit finite bad-seed set.

Local and terminal-batch witness uniqueness from certified no-short-kernel is
tracked under `ce-opening-certified-binding`. The distinct-witness lemmas remain
the contrapositive diagnostic surface: if uniqueness fails, a concrete
short-kernel witness exists.

## Verification

The module builds as part of `lake build`, and its declaration group is tracked
by `Docs/FormalStatus.json`.
