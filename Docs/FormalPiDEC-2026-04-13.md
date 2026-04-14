# Formal PiDEC Progress, 2026-04-13

Formal status: conditional protocol formalization.

This pass extends the PiDEC formal surface without claiming full PiDEC
soundness.  The added facts are unconditional recomposition and limb-bound
lemmas that the eventual PiDEC theorem can reuse.

## Added Lean module

- `SuperNeoFormal.PiDECSoundness`
  - Defines generic weighted vector recomposition.
  - Specializes weighted recomposition to public-input vectors.
  - Specializes weighted recomposition to matrix-evaluation vectors.
  - Proves coordinate-level recomposition for both public inputs and
    matrix-evaluation surfaces.
  - Defines signed base-2 scalar and vector recomposition over `Int`.
  - Defines signed limb bounds as `|limb| <= 1`.
  - Proves the concrete `decompositionLength = 14` bound:
    any signed base-2 decomposition with limbs bounded by `1` recomposes to
    absolute value at most `2^14 - 1`, hence strictly below
    `decompositionRadixBound = 16384`.

## What remains open

This does not yet prove the full PiDEC verifier theorem.  Remaining work is to
connect the signed integer limb model to concrete Goldilocks/Phi81 encodings,
prove small-norm limb bounds for the ring representation, and tie verified
decomposition outputs to valid bounded CE claims whose weighted recomposition
equals the folded claim.
