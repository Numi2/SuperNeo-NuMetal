# Formal Remaining Boundaries, 2026-04-14

Formal status: completed formal protocol theorem.

This note records the boundary-closure pass after the earlier assumption-surface
deepening work. The previous eight `*-boundary` groups have been replaced in the
manifest by certified-key or finite bad-challenge/bad-seed theorem groups.

## Closed During This Pass

- Ajtai binding now has a certified-key surface. `CertifiedAjtaiKey` and
  `VerifiedAjtaiKernelCertificate` carry the exact `ModuleSISNoShortKernel`
  fact for the verifier key matrix, and binding/CE uniqueness theorems consume
  that certificate instead of claiming arbitrary matrices are binding.
- `arbitraryNoShortKernelTheorem_false` records the guardrail: an arbitrary
  zero matrix over any nontrivial commutative ring does not satisfy
  `NoShortKernel`.
- Phi81 now records the concrete Goldilocks factorization
  `X^54 + X^27 + 1 = (X^27 - (2^32 - 1)) * (X^27 + 2^32)` and exposes an
  explicit split-certificate surface for componentwise collision arguments.
- PiRLC now has `PiRLCFiniteBadSeedCertificate`: accepted folded claims imply all
  inputs are sound outside the finite certified bad-seed set.
- PiCCS/sum-check now has a GoldilocksExt2 wire model and
  `PiCCSFiniteBadChallengeCertificate`, replacing deterministic
  `accepts -> sound` with soundness outside a finite bad-challenge set.
- Terminal CE proof soundness now has `TerminalCEFiniteBadSeedCertificate` and
  Stern-round special-soundness surfaces, replacing deterministic proof
  soundness with extraction outside a finite bad-seed set.
- SuperNeo composition now has `superneo_end_to_end_outside_ce_badSeeds`, which
  composes terminal verifier acceptance with the finite CE bad-seed certificate.
- Sum-check now has a closed finite-field low-degree root-count core:
  a nonzero polynomial has at most `natDegree` roots in any finite challenge
  support, and a support larger than the degree bound contains a non-root.
- Pure acceptance/opening predicate shape has been moved out of assumption
  buckets. `concrete-ajtai-opening-core`,
  `pirlc-concrete-acceptance-core`, and
  `terminal-ce-proof-acceptance-core` now track deterministic predicate
  equivalences, while the boundary groups keep only assumption-consuming
  declarations.
- The Ajtai reduction core now has the exact contrapositive kernel-witness
  surface: `short_kernel_yields_binding_failure`,
  `binding_failure_yields_short_kernel`, and
  `not_bindingSecure_iff_exists_short_kernel`.
- PiRLC now has `ringRLCBadPivotValues_card_le_one_of_unit` and
  `phi81RLCBadPivotValues_card_le_one_of_unit`, which prove the one-bad-value
  bound only under a unit pivot in a commutative ring. This is the strongest
  currently mechanized quotient-ring-safe collision fact.
- Sum-check now tracks polynomial agreement sets for prover/exact round
  mismatches. If two low-degree polynomials differ, the challenge values where
  they agree are degree-bounded, and a large enough support contains a
  disagreeing challenge.
- CE local and terminal-batch algebra now prove that two distinct witnesses for
  the same statement yield an explicit nonzero bounded-difference kernel
  vector.

## Boundary Replacement Map

- `module-sis-no-short-kernel-boundary` -> `module-sis-certified-kernel`
- `concrete-ajtai-binding-boundary` -> `concrete-ajtai-certified-binding`
- `ajtai-binding-boundary` -> `ajtai-certified-binding`
- `ce-opening-binding-boundary` -> `ce-opening-certified-binding`
- `pirlc-collision-bound-boundary` -> `phi81-split-semantics` and
  `pirlc-finite-bad-seed-soundness`
- `piccs-sumcheck-boundary` -> `goldilocks-ext2-wire-model` and
  `piccs-finite-bad-challenge-soundness`
- `terminal-ce-proof-soundness-boundary` ->
  `terminal-ce-finite-bad-seed-soundness`
- `superneo-ce-opening-composition-boundary` ->
  `superneo-finite-bad-seed-composition`

## Current Manifest Shape

The current manifest uses closed replacement groups for the completed dependency
path. The active label is `completed formal protocol theorem`, whose accepted
status set is exactly `closed`.
