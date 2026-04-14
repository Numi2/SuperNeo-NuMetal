# Formal Remaining Boundaries, 2026-04-14

Formal status: conditional protocol formalization.

This note records the remaining formal blockers after the assumption-surface
deepening pass. It is intentionally conservative: a boundary remains a boundary
until the Lean theorem that removes it is present and tracked as `closed` in
`Docs/FormalStatus.json`.

## Closed During This Pass

- Stage-assumption composition is no longer a standalone blocker. The
  proof-carrying SuperNeo composition theorem now depends directly on
  `TerminalCEProofSoundnessAssumption`, so top-level terminal soundness is
  CE-opening scoped.
- Sum-check now has a closed finite-field low-degree root-count core:
  a nonzero polynomial has at most `natDegree` roots in any finite challenge
  support, and a support larger than the degree bound contains a non-root.
- Pure acceptance/opening predicate shape has been moved out of assumption
  buckets. `concrete-ajtai-opening-core`,
  `pirlc-concrete-acceptance-core`, and
  `terminal-ce-proof-acceptance-core` now track deterministic predicate
  equivalences, while the boundary groups keep only assumption-consuming
  declarations.

## Boundaries Still Open

- MSIS/no-short-kernel:
  `module-sis-no-short-kernel-boundary`, `concrete-ajtai-binding-boundary`,
  `ajtai-binding-boundary`, and `ce-opening-binding-boundary` still depend on a
  no-short-kernel premise. Closing them requires a mechanized theorem that the
  concrete key distribution satisfies the needed Module-SIS/no-short-kernel
  property under stated parameters, not just an estimator artifact.
- Phi81 folded-claim collision:
  `pirlc-collision-bound-boundary` still requires a concrete collision-set
  certificate for the quotient-ring folded-claim relation. Scalar Goldilocks
  one-root facts are closed, but the Phi81 quotient-ring case is not silently
  treated as a field.
- Sum-check soundness:
  `piccs-sumcheck-boundary` still covers the remaining low-degree/probabilistic
  sum-check argument tying arbitrary accepted traces to the exact oracle model.
  The root-count lemma is closed, but the full protocol-level mismatch
  polynomial construction is not.
- CE proof soundness:
  `terminal-ce-proof-soundness-boundary` and
  `superneo-ce-opening-composition-boundary` remain scoped to public CE opening
  verifier soundness. The local algebraic CE relation is closed; soundness of
  the external proof verifier is not.

## Current Manifest Shape

The current manifest has 40 theorem groups: 32 closed deterministic groups and
8 explicit boundary groups. `completed formal protocol theorem` remains blocked
because it accepts only `closed` groups.
