# Formal Ajtai Binding Pass, 2026-04-13

Formal status: partial formalization.

This pass strengthens the Lean formalization for the abstract Ajtai commitment
layer without changing the repository's public formal status. The work is
deliberately scoped to the commitment binding boundary that is already listed as
closed under an explicit MSIS no-short-kernel assumption.

## Work Completed

`Formal/SuperNeoFormal/Ajtai.lean` now defines `BindingSecure` as the statement
that two bounded openings to the same commitment have the same message.

The Lean layer also adds named theorems for:

- extracting a nonzero short-kernel witness from two distinct bounded openings
  to the same commitment,
- deriving message equality from `NoShortKernel`,
- deriving `BindingSecure` from `NoShortKernel`,
- deriving `NoShortKernel` from `BindingSecure`, and
- the equivalence `NoShortKernel A bounded ↔ BindingSecure A bounded`.

This makes the Ajtai binding reduction explicit as a two-way algebraic boundary
inside the current abstract ring model.

## Manifest Updates

`Docs/FormalStatus.json` now tracks the new binding declarations under the
`ajtai-binding-reduction` theorem group. The profile theorem group also lists
the derived constants and strong-sampling inequality already present in
`Profile.lean`, including the Module-SIS dimension, estimator length,
decomposition radix bound, and `strongSampling_holds`.

## Trust Boundary

This remains a partial formalization. The abstract commitment model is over an
arbitrary commutative ring `RF`; it has not yet been refined to the concrete
quotient ring `F[X] / (X^54 + X^27 + 1)`. This pass does not close PiDEC,
PiRLC, PiCCS, terminal CE, or the full SuperNeo composition theorem.

Local validation can run the manifest and documentation gates. A Lean/Lake build
still requires an environment with `lake` available, so the formal CI workflow
remains the authoritative proof-build gate for the Lean sources.
