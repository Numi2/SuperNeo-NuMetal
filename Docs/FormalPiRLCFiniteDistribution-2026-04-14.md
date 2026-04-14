# PiRLC Finite Distribution Formal Slice

Formal status: conditional protocol formalization

This note records the April 14, 2026 PiRLC soundness progress in
`Formal/SuperNeoFormal/PiRLCSoundness.lean`.

## What closed

- The PiRLC challenge source is now a finite Lean type:
  `PiRLCChallengeSeed count = Fin count -> Phi81ChallengeSeed`.
- The concrete seed count is proved as `(5 ^ 54) ^ count`, reusing the
  coefficient-wise `{ -2, -1, 0, 1, 2 }` Phi81 challenge source.
- Bad verifier seeds are represented by an explicit finite set, not an informal
  probability phrase.
- The theorem `pirlc_badSeedCount_le_of_collisionSet` proves that any collision
  set covering all bad seeds gives an exact cardinality bound on verifier
  failure.
- The scalar field lemma `scalarRLCBadPivotValues_card_le_one` proves the usual
  one-root random-linear-combination collision bound for a pivot coefficient
  with nonzero delta.
- `goldilocksScalarRLCBadPivotValues_card_le_one` instantiates that one-root
  lemma for the concrete Goldilocks scalar challenge support.

These declarations are now split into closed `pirlc-finite-support-core` and
`pirlc-scalar-collision-core` theorem groups.

The concrete Phi81 public acceptance predicate
`PiRLCConcreteAccepts` is also tracked separately in the closed
`pirlc-concrete-acceptance-core` group. The random-linear-combination boundary
now contains only the concrete collision-bound predicate and the theorems that
consume that predicate.

## Boundary kept explicit

The concrete Phi81 challenge ring is not silently treated as a field.  The
finite-distribution theorem therefore requires a concrete collision-set bound
for the Phi81 folded-claim relation.  That is the remaining PiRLC cryptographic
boundary, while the weighted-claim recomposition core is now tracked separately
as closed deterministic algebra.

`PiRLCFiniteCollisionSoundnessBoundary` names the remaining finite collision-set
premise directly, and
`pirlc_concrete_badSeedCount_le_of_finiteCollisionBoundary` records how that
premise implies the concrete bad-seed count bound. Those declarations remain in
`pirlc-collision-bound-boundary`.

## Verification

The module builds as part of `lake build`.  The formal status manifest now tracks
the new declarations, so documentation cannot promote beyond the current
conditional label while this random-linear-combination boundary remains open.
