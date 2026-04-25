# Formal Assumption Ledger Split, 2026-04-14

Formal status: completed formal protocol theorem.

This pass replaces the assumption-boundary dependency path with certified-key
and finite bad-challenge/bad-seed theorem groups. Historical `closed_under_*`
group IDs remain documented for audit continuity, while the manifest's
conditional path depends only on mechanized closed groups.

## What Changed

- Module-SIS profile constants and estimator tuple facts are now tracked as the
  closed `module-sis-parameters` group. The conditional dependency path uses
  `module-sis-certified-kernel`, where `AjtaiKernelCertificate` carries the
  concrete no-short-kernel proof and `VerifiedAjtaiKernelCertificate` is the
  checked key-metadata subtype consumed by verifier-key binding theorems.
- Concrete Ajtai shape, Phi81 quotient-ring wiring, packed-witness wiring, and
  concrete commitment linearity are tracked as `concrete-ajtai-instantiation`.
  Concrete opening and binding predicate shape is tracked separately as the
  closed `concrete-ajtai-opening-core`; binding from a certified key is tracked
  by `concrete-ajtai-certified-binding`.
- Generic Ajtai binding is split between the closed
  `ajtai-binding-reduction-core` group and the closed
  `ajtai-certified-binding` group.
  The closed reduction core now includes the exact contrapositive surface:
  a short-kernel witness gives a binding failure, a binding failure gives a
  short-kernel witness, and `¬ BindingSecure` is equivalent to existence of a
  nonzero bounded-difference kernel vector.
  `arbitraryNoShortKernelTheorem_false` records that arbitrary-key closure is
  false for degenerate matrices.
- Transcript-derived challenge scheduling is tracked by
  `transcript-challenge-binding`: equal structured transcripts, equal
  proof-envelope context/seed inputs, equal absorbed payloads, and equal ordered
  absorb sequences derive equal finite challenge seeds and elements.
- PiRLC weighted-claim recomposition, finite challenge support/counting, and
  the scalar Goldilocks one-root collision lemma are tracked as closed cores.
  The scalar collision core also includes a quotient-ring-safe unit-pivot
  version over any commutative ring and its Phi81 specialization under an
  explicit `IsUnit` pivot premise; it does not assert that every nonzero Phi81
  element is invertible. The April 15 invertibility audit found no
  `normBound`-style statement that promotes boundedness alone into
  invertibility; the mechanized PiRLC path still requires either a scalar
  nonzero pivot or an explicit quotient-ring unit pivot.
  Concrete acceptance predicate shape is tracked as the closed
  `pirlc-concrete-acceptance-core`.
  `phi81-split-semantics` records the concrete factorization of Phi81 over
  Goldilocks. The theorem-facing PiRLC endpoint now goes through
  `Phi81CRT.lean`, `PiRLCConcreteCollision.lean`, and
  `PiRLCCRTConstructiveFailureLocalization` rather than a split-carrying finite
  bad-seed certificate.
- PiCCS exact public-Q reduction is tracked as a closed deterministic bridge.
  PiCCS acceptance projections are tracked separately as a closed core.
  The finite-field low-degree root-count lemma is tracked as
  `sumcheck-low-degree-root-count-core`; that core now also tracks polynomial
  agreement sets for prover/exact round-polynomial mismatches and proves that
  low-degree mismatches can agree only on a degree-bounded support subset.
  `sumcheck-prefix-bad-challenge-composition` aggregates those per-round
  agreement sets into a finite set of `(round, challenge)` events and proves the
  `rounds * degreeBound` cardinality budget from the same low-degree premises.
  `PiCCSConstructiveFiniteSoundness.lean` now consumes this layer directly and
  constructs the theorem-facing PiCCS bad-challenge set; the older certificate
  wrapper is no longer the endpoint for constructed bad sets.
  `goldilocks-ext2-wire-model` tracks the extension-field wire operations and
  inverse-data correctness. The theorem-facing PiCCS accounting is the
  constructed bad-challenge set above.
- Swift wire support now includes `swift-ext2-caller-byte-surfaces`, a closed
  grammar layer for counted Ext2 vectors, counted Ext2 ring vectors,
  sum-check Ext2 proof fragments, and CCS/CE point-evaluation caller bytes.
  Later formal-status cleanup connects the theorem-facing Swift/Lean
  serialization equivalence surfaces through closed groups; this note keeps the
  grammar layer visible for auditability.
- Terminal CE statement and batch-projection facts are tracked as a closed core.
  Terminal CE local batch relations are tracked as closed local algebra.
  Public proof-acceptance predicate shape is tracked as the closed
  `terminal-ce-proof-acceptance-core`.
  The closed local CE groups now also prove that distinct local or terminal
  batch witnesses for the same CE statement produce an explicit nonzero
  bounded-difference kernel vector.
  Witness uniqueness from certified no-short-kernel is tracked separately as
  `ce-opening-certified-binding`.
  Public CE proof-verifier soundness is tracked by
  `terminal-ce-finite-bad-seed-soundness`, which now includes the three-symbol
  challenge domain, parsed verifier-round trace semantics, and extraction of
  local batch witnesses outside the explicit finite bad-seed set.
  `TerminalCEConstructiveFiniteSoundness.lean` is the current theorem-facing
  CE finite endpoint: it uses the concrete extraction-failure bad-seed set and
  derives the `roundCount * 3` budget from an injective bad-seed localization.
  The concrete Swift/Fiat-Shamir tape-to-slot localization remains an explicit
  integration obligation.
- SuperNeo acceptance decomposition is tracked as closed deterministic
  composition. `superneo-finite-bad-seed-composition` composes terminal
  verifier acceptance with the constructive finite CE bad-seed evidence.
  `superneo-tagged-bad-event-composition` tracks the finite tagged
  union/cardinality layer for PiRLC, PiCCS/sum-check, terminal CE, and
  transcript bad-event sets.
  `SuperNeoFormal.ErrorLedger` now has both the compatibility abstract
  probability/error-budget interface and a concrete finite-uniform ledger. The
  concrete path connects the Fiat-Shamir finite seed product to exact rational
  probability, proves the event equality with `superNeoFiatShamirProbability`,
  and exposes selected-depth numerator arithmetic.
- Transcript canonicality is tracked through `WellFormedTranscript.lean`.
  The theorem path no longer relies on arbitrary low-level `TranscriptState`
  values for byte injectivity.
- The theorem-critical digest-width boundary is tracked through
  `Digest384Serialization.lean` and `TypedDigestSemantics.lean`, which provide
  384-bit proof-envelope binding encodings and typed digest-domain separation.
- The formal-status validator now rejects duplicate declaration entries across
  theorem groups, preventing deterministic cores and assumption boundaries from
  double-counting the same Lean declaration.
- The validator also checks every label's theorem-group references and accepted
  status vocabulary, even when that label is not the active `current_label`, and
  rejects duplicate documentation claim paths.
- The validator rejects boundary groups or declarations named as assumptions or
  boundaries if they are marked `closed`. It also enforces that the completed
  label includes every conditional theorem group and accepts only `closed`.

## Historical Boundaries Kept Explicit

The old boundary IDs are replaced by closed groups on the conditional dependency
path. This preserves audit history while preventing a direct promotion of
`*-boundary` groups or declarations named `Assumption`/`Boundary`.

## Verification

Validation commands:

```sh
cd Formal && lake build
cd ..
Scripts/validate-formal-status.py
Scripts/test-formal-status-validation.py
```
