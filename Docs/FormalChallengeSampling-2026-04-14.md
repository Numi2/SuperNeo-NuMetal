# Formal Challenge Sampling Progress, 2026-04-14

Formal status: conditional protocol formalization

This pass formalizes the concrete finite challenge source used for Phi81
small-coefficient ring challenges.  It does not yet prove the full PiRLC
collision probability theorem.

## Added Lean module

- `SuperNeoFormal.ChallengeSampling`
  - Defines the challenge coefficient choices as `Fin 5`.
  - Defines the concrete coefficient set `{-2, -1, 0, 1, 2}`.
  - Proves every sampled coefficient is in that set.
  - Proves the signed absolute-value bound by `normBound = 2`.
  - Proves the corresponding Goldilocks centered-norm bound.
  - Defines a Phi81 challenge seed as 54 independent coefficient choices.
  - Defines the induced Phi81 coefficient vector and quotient-ring element.
  - Proves every induced Phi81 challenge coefficient vector is bounded by
    `normBound`.
  - Proves the finite seed-space cardinality `5^54`.
  - Defines expanded challenge seeds for the profile expansion factor `216` and
    proves the expanded cardinality `(5^54)^216`.
  - Defines the strong-sampling fold budget and proves it satisfies the concrete
    profile capacity inequality, reusing `strongSampling_holds`.
  - Proves any fresh/prior claim counts bounded by the profile maxima also
    satisfy the strong-sampling capacity inequality.

## What remains open

The remaining PiRLC probability work is the actual random-linear-combination
collision theorem for folded claims under this finite challenge source.  The
current module supplies the finite source, coefficient bounds, and capacity
theorem that such a result should depend on.

The follow-up `SuperNeoFormal.TranscriptChallenge` module binds this finite
source to the ordered transcript model through an abstract challenge deriver.
That closes deterministic transcript equality/support facts for equal
proof-envelope context, seed, and ordered absorb sequences, but it still does
not model SHA-256 as a random oracle or prove challenge uniformity.
