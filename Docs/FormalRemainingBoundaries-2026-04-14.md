# Formal Remaining Boundaries, 2026-04-14

Formal status: conditional protocol formalization.

This note records the boundary-closure pass after the earlier assumption-surface
deepening work. The previous eight `*-boundary` groups have been replaced in the
manifest by certified-key or finite bad-challenge/bad-seed theorem groups.

## Closed During This Pass

- Ajtai binding now has a certified-key surface. `CertifiedAjtaiKey` and
  `AjtaiKernelCertificate` carry the exact `ModuleSISNoShortKernel` fact for a
  certified matrix; `checkAjtaiKernelCertificate` ties that payload to the
  verifier key metadata before binding/CE uniqueness theorems consume it.
- `arbitraryNoShortKernelTheorem_false` records the guardrail: an arbitrary
  zero matrix over any nontrivial commutative ring does not satisfy
  `NoShortKernel`.
- Phi81 now records the concrete Goldilocks factorization
  `X^54 + X^27 + 1 = (X^27 - (2^32 - 1)) * (X^27 + 2^32)` and exposes an
  explicit split-certificate surface for componentwise collision arguments.
- PiRLC now has `PiRLCFiniteBadSeedCertificate`: accepted folded claims imply all
  inputs are sound outside the finite certified bad-seed set. The certificate
  carries the Phi81 split, and the file records projected component deltas and a
  one-bad-value theorem for nonzero projected pivots.
- PiCCS/sum-check now has a GoldilocksExt2 wire model and
  `PiCCSFiniteBadChallengeCertificate`, replacing deterministic
  `accepts -> sound` with soundness outside a finite bad-challenge set. The
  certificate also carries public-Q oracle semantics and max-degree-bounded
  round-polynomial witnesses.
- Terminal CE proof soundness now has `TerminalCEFiniteBadSeedCertificate` and
  Stern-round special-soundness surfaces, replacing deterministic proof
  soundness with extraction outside a finite bad-seed set. The file also models
  the three-symbol verifier challenge domain, parsed verifier-round traces, and
  branch-derived local batch extraction.
- SuperNeo composition now has `superneo_end_to_end_outside_ce_badSeeds`, which
  composes terminal verifier acceptance with the finite CE bad-seed certificate.
- Probability composition now has a conservative tagged finite-event layer:
  `SuperNeoFormal.ProbabilityComposition` tags PiRLC, PiCCS/sum-check, terminal
  CE, and transcript bad-event sets, proves the aggregate finite-cardinality
  bound, and proves that being outside the aggregate implies being outside each
  stage set.
- Ext2 caller byte surfaces now have `SuperNeoFormal.Ext2CallerSerialization`,
  which models counted Ext2 vectors, counted `CyclotomicExt2Ring54` vectors,
  sum-check Ext2 rounds/proofs, and CCS/CE point-evaluation surfaces after
  their opaque non-Ext2 prefixes.
- Sum-check now has a closed finite-field low-degree root-count core:
  a nonzero polynomial has at most `natDegree` roots in any finite challenge
  support, and a support larger than the degree bound contains a non-root.
- Pure acceptance/opening predicate shape has been moved out of assumption
  buckets. `concrete-ajtai-opening-core`,
  `pirlc-concrete-acceptance-core`, and
  `terminal-ce-proof-acceptance-core` now track deterministic predicate
  equivalences; the old boundary IDs are retained only in this historical
  replacement map, not as active manifest groups.
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
- Sum-check now also has a prefix bad-challenge aggregation layer: per-round
  agreement sets are tagged by round and composed into a finite
  `(round, challenge)` event set with a `rounds * degreeBound` cardinality
  budget.
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

The current manifest uses closed replacement groups for the conditional
dependency path. The active label is `conditional protocol formalization`.

The full theorem label still requires three planned groups:

- `superneo-full-probability-composition`: full composition of the PiRLC,
  PiCCS/sum-check, terminal CE, transcript, and CE bad-seed/bad-challenge
  probability budgets.
- `swift-goldilocks-ext2-serialization-equivalence`: complete Swift
  serialization equivalence for `GoldilocksExt2` and all callers that depend on
  it.
- `swift-ce-verifier-byte-equivalence`: a byte-for-byte equivalence proof for
  the Swift CE verifier proof parser and verifier path.

The CE byte grammar itself has moved forward: `SuperNeoFormal.CEByteSerialization`
now models the counted CE proof bytes, response tags, commitments, responses,
rounds, and complete proof object, with round-trip theorems, a Swift drift
validator, and an exact Swift/Lean complete-proof vector comparator in the
production gate. This does not discharge the blocker because the executable
Swift verifier branches are not yet proved equivalent to
`TerminalCEVerifierTraceAccepts`.

The Ext2 caller byte surface itself has moved forward:
`swift-ext2-caller-byte-surfaces` is closed as a supporting grammar for counted
Ext2 vectors, counted Ext2 ring vectors, sum-check Ext2 proof fragments, and
CCS/CE point-evaluation caller bytes. The production gate also runs an exact
Swift/Lean Ext2 vector comparator. This does not discharge
`swift-goldilocks-ext2-serialization-equivalence` because executable Swift
behavior equivalence is still not mechanized.

The tagged bad-event composition itself has moved forward:
`superneo-tagged-bad-event-composition` is closed as finite bookkeeping for the
PiRLC, PiCCS/sum-check, terminal CE, and transcript event sets. This does not
discharge `superneo-full-probability-composition` because no transcript-seed
distribution, Fiat-Shamir projection map, fiber bound, or rational probability
denominator is mechanized yet.

The Lean `goldilocks-ext2-field-instance` group is now closed by transferring
mathlib's root-free quadratic-algebra field instance onto the existing
`GoldilocksExt2` `c0/c1` structure after proving that `7` is nonsquare in the
Goldilocks base field.

The closure plan for the three remaining blockers is recorded in
[Formal Completion Research Plan, 2026-04-14](FormalCompletionResearchPlan-2026-04-14.md).
It keeps the groups planned, identifies the concrete Swift and Lean surfaces
that must be connected, and defines the validation gates needed before the
completed theorem label can be used.
