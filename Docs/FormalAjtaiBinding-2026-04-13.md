# Formal Ajtai Binding Pass, 2026-04-13

Formal status: conditional protocol formalization.

This pass strengthens the Lean formalization for the abstract Ajtai commitment
layer without changing the repository's public formal status. The deterministic
parts of the binding reduction are now separated from the theorems that consume
an explicit MSIS no-short-kernel premise.

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
closed `ajtai-binding-reduction-core` group and the
`closed_under_msis_assumption` `ajtai-binding-boundary` group. The profile
theorem group also lists the derived constants and strong-sampling inequality already present in
`Profile.lean`, including the Module-SIS dimension, estimator length,
decomposition radix bound, and `strongSampling_holds`.

## Trust Boundary

This remains assumption-scoped formalization. The generic commitment model is
over an arbitrary commutative ring `RF`, while later concrete-Ajtai groups tie
the implemented commitment shape to Phi81. The no-short-kernel premise is still
the MSIS boundary; these theorems do not prove that the sampled concrete key has
that property unconditionally.

Local validation can run the manifest and documentation gates. A Lean/Lake build
still requires an environment with `lake` available, so the formal CI workflow
remains the authoritative proof-build gate for the Lean sources.
