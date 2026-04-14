# PiRLC Finite Distribution Formal Slice

Formal status: completed formal protocol theorem

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
- `ringRLCBadPivotValues_card_le_one_of_unit` proves the same one-bad-value
  shape over an arbitrary commutative ring when the pivot delta is a unit.
- `phi81RLCBadPivotValues_card_le_one_of_unit` specializes that theorem to the
  Phi81 quotient ring under an explicit `IsUnit` pivot premise.

These declarations are now split into closed `pirlc-finite-support-core` and
`pirlc-scalar-collision-core` theorem groups.

The concrete Phi81 public acceptance predicate
`PiRLCConcreteAccepts` is also tracked separately in the closed
`pirlc-concrete-acceptance-core` group. The completed dependency path now uses
`phi81-split-semantics` and `pirlc-finite-bad-seed-soundness` instead of the
historical random-linear-combination boundary group.

## Completed Replacement

The concrete Phi81 challenge ring is not silently treated as a field.  The
finite-distribution theorem therefore uses a concrete finite bad-seed
certificate for the Phi81 folded-claim relation.  The weighted-claim
recomposition core is tracked separately as closed deterministic algebra.

The unit-pivot theorem is intentionally not enough to close the boundary: it
does not prove that every nonzero folded-claim pivot in Phi81 is a unit, nor
does it bound collisions caused by zero divisors or by non-unit deltas.

`phi81Polynomial_factor_goldilocks` records the concrete split of Phi81 over
Goldilocks, while `PiRLCFiniteBadSeedCertificate` names the finite bad-seed set
and `pirlc_allInputsSound_of_seed_not_bad` gives the outside-bad-seeds
soundness theorem.

## Verification

The modules build as part of `lake build`.  The formal status manifest tracks
the closed replacement declarations on the completed dependency path.
