# Formal Remaining Boundaries, 2026-04-14

Formal status: corrected finite-model core with open theorem-critical integrations.

This note records the boundary-closure pass after the earlier assumption-surface
deepening work. It has been updated for the 2026-04-17 formal cleanup: the old
transcript, 384-bit binding, constructive PiCCS, constructive terminal CE, and
finite probability-ledger gaps are no longer phrased as broad roadmap blockers,
but their upper theorem-critical integration points remain tracked explicitly.

## Closed During This Pass

- Ajtai binding now has a certified-key surface. `CertifiedAjtaiKey` and
  `AjtaiKernelCertificate` carry the exact `ModuleSISNoShortKernel` fact for a
  certified matrix; `checkAjtaiKernelCertificate` ties that payload to the
  verifier key metadata before binding/CE uniqueness theorems consume it.
- `arbitraryNoShortKernelTheorem_false` records the guardrail: an arbitrary
  zero matrix over any nontrivial commutative ring does not satisfy
  `NoShortKernel`.
- Phi81 now records the concrete Goldilocks factorization
  `X^54 + X^27 + 1 = (X^27 - (2^32 - 1)) * (X^27 + 2^32)` as support for the
  concrete CRT endpoint in `Phi81CRT.lean`.
- PiRLC now has a constructive finite bad-seed endpoint:
  `PiRLCConstructiveBadSeeds` is the filtered fold-failure set, and
  `PiRLCCRTConstructiveFailureLocalization` records the full-ring unit-pivot
  localization needed for the remaining-seed count. The CRT component endpoint
  uses a conservative component budget with the `5^27` fiber factor. The
  checked component-certificate constructors now derive that endpoint from a
  delta-collision proof, a nonzero CRT component pivot, and the concrete
  upper-half challenge-coefficient fiber. The checked
  `PiRLCLinearDefectSemantics` route now derives that certificate from an
  accepted-fold defect functional, including the nonzero pivot when inputs are
  not all sound. `RLCClaimLinearObservation` instantiates the field-coordinate
  linearity for commitment, public-input, and evaluation coordinates of the
  folded claim. The concrete Swift/trace folded relation still must select and
  supply the product-level defect predicate.
- PiCCS/sum-check now has a GoldilocksExt2 wire model and a constructive finite
  bad-challenge path. `PiCCSConstructiveFiniteSoundness.lean` constructs the
  bad set directly from `SumcheckSoundness.lean` and
  `SumcheckPrefixSoundness.lean`, proving the `numVars * maxDegreePerRound`
  cardinality budget without relying on a certificate-first endpoint.
- Terminal CE proof soundness now has concrete Stern-round special-soundness
  surfaces and a constructive finite bad-seed endpoint.
  `TerminalCEConstructiveFiniteSoundness.lean` uses the concrete
  extraction-failure bad-seed set and derives the `roundCount * 3` budget from
  an injective bad-seed localization. The checked slot-seed endpoint is not yet
  a proof that every Swift/Fiat-Shamir challenge tape failure localizes to a
  unique slot. The checked `TerminalCESlotSeedLocalizationEvidence` and
  `terminalCESwiftSlotSeedFiniteSoundnessCertificate` declarations are the
  final formal input shape for that localization evidence. The checked
  `swiftCETraceChallengeTape_matches_verifier_branch` declaration derives the
  full ternary tape from Swift response tags, and
  `terminalCEFullTapeCertificate_of_slotCertificate` lifts any slot certificate
  to the full challenge-tape seed model with the exact per-slot fiber factor
  `3^(roundCount - 1)`.
  `TerminalCEFiniteSoundness.lean` remains as a compatibility wrapper.
- SuperNeo composition now has
  `superneo_end_to_end_outside_constructive_ce_badSeeds`, which composes
  terminal verifier acceptance with constructive terminal CE bad-seed semantics.
- Transcript binding now has a theorem-facing well-formed layer:
  `WellFormedTranscript.lean` proves byte injectivity for length-counted
  transcript states and provides 384-bit proof-envelope transcript separation.
- Theorem-critical digest binding now has a 384-bit companion:
  `Digest384Serialization.lean` and `TypedDigestSemantics.lean` provide
  parameterized digest wires, 384-bit proof-envelope binding records, and typed
  digest-domain separation.
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

The current manifest uses closed corrected-core groups plus explicit planned
integration groups. The active label is `corrected finite-model core with open theorem-critical integrations`.

The remaining theorem-critical integration groups are:

- `terminal-ce-localization-instantiation`, which instantiates constructive
  terminal CE localization evidence beyond the checked slot and full-tape
  certificate endpoints by proving the accepted Swift/trace parser supplies the
  concrete bad-round selector. The full ternary challenge tape and the
  proof-level full-tape certificate constructor are already checked from the
  Swift response-tag trace.
- `pirlc-crt-finite-soundness-completion`, which completes the CRT-based PiRLC
  finite-soundness count on top of `Phi81CRT.lean` and
  `PiRLCConcreteCollision.lean`. The checked surface includes a conservative
  component bad-seed budget with the `5^27` CRT fiber factor and certificate
  constructors from delta collision plus the checked upper-half coefficient
  fiber. The checked `PiRLCLinearDefectSemantics` certificate route is now the
  exact formal target, with checked linear observations for the folded claim
  fields and a finite observation-family lift that unions bad seeds across the
  selected coordinate family with the explicit family-cardinality multiplier.
  The full public-field family is now instantiated with a concrete
  `(rows + publicCount + evalCount)` multiplier; completion still requires the
  selected concrete Swift/trace folded relation to instantiate the selected
  defect predicate. The stronger
  remaining-seed count is exposed only under an explicit full-ring unit-pivot
  collision evidence package.

The existing CE byte grammar remains the supporting parser model for counted CE
proof bytes, response tags, commitments, responses, rounds, and complete proof
objects. The Ext2 caller byte surface remains the supporting grammar for counted
Ext2 vectors, counted Ext2 ring vectors, sum-check Ext2 proof fragments, and
CCS/CE point-evaluation caller bytes. The tagged bad-event, error-ledger, and
Fiat-Shamir finite-seed accounting groups are connected to an exact
finite-uniform probability bridge and selected-depth numerator arithmetic; the
remaining open groups are the terminal CE and PiRLC semantic-localization
integrations listed above.

The Lean `goldilocks-ext2-field-instance` group is now closed by transferring
mathlib's root-free quadratic-algebra field instance onto the existing
`GoldilocksExt2` `c0/c1` structure after proving that `7` is nonsquare in the
Goldilocks base field.

The historical closure plan for the three blockers is recorded in
[Formal Completion Research Plan, 2026-04-14](FormalCompletionResearchPlan-2026-04-14.md).
It now serves only as an audit trail. The current solution is summarized in the
root [`math-audit.md`](../math-audit.md).
