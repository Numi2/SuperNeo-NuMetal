# SuperNeo / NumiSeal Formal Audit

Date: 2026-04-18

This note supersedes the earlier audit addenda that asked for a well-formed
transcript object, 384-bit theorem-critical bindings, constructive terminal CE
finite soundness, constructive PiCCS finite soundness, and a finite-uniform
probability bridge. Those items are now implemented in the Lean formal stack.
The current formal status is still the corrected finite-model core with open
theorem-critical integrations; it is not promoted to a completed protocol
theorem while terminal CE and PiRLC semantic-localization evidence remains open.

Verified command:

```sh
cd Formal
lake build SuperNeoFormal
```

Result: build completed successfully.

A source scan of `Formal/SuperNeoFormal` found no `axiom`, `sorry`, or `admit`.

## Current Decision

The formal stack is now organized around concrete lower-layer mathematics plus
evidence-parametric theorem surfaces:

- transcript byte injectivity is theorem-facing only for well-formed,
  length-counted transcript states;
- theorem-critical binding encodings use the new 384-bit companion layer;
- typed digests are width-parameterized and domain-family typed;
- PiCCS finite soundness consumes the constructive sum-check prefix bad-set
  proofs directly;
- terminal CE finite soundness has a constructive replacement surface over the
  concrete extraction-failure bad-seed set, including a slot-seed certificate
  endpoint, a Swift-round certificate endpoint, and a checked lift from slot
  bad seeds to full ternary challenge-tape bad seeds with the exact
  `3^(roundCount - 1)` fiber factor. The Swift response-tag trace now supplies
  the full ternary challenge tape and verifier-branch match;
- PiRLC finite soundness has a constructive bad-seed surface, a strong
  full-ring unit-pivot endpoint, and CRT-component certificate constructors
  from delta collision plus the concrete upper-half challenge-coefficient fiber.
  The checked linear-defect semantics route is the final Lean input shape for
  the conservative PiRLC path, and concrete folded-claim observations cover
  commitment, public-input, and evaluation coordinates with a finite
  observation-family union-bound lift. The full public-field family is
  instantiated with the concrete `(rows + publicCount + evalCount)` multiplier;
- transcript finite probability is connected to the finite-uniform error ledger
  and selected-depth numerator arithmetic.

The upper product theorem files remain evidence-parametric by design. They
should be read as theorem surfaces that require explicit accepted evidence
records, not as standalone cryptographic proofs.

## Implemented Modules

### `WellFormedTranscript.lean`

This is the canonical theorem-facing transcript object.

It defines:

- `WellFormedTranscriptFrame`
- `WellFormedTranscriptFrames`
- `WellFormedTranscriptState`
- `WellFormedTranscript`
- `wellFormedTranscriptInit`
- `wellFormedTranscriptAbsorb`

It proves:

- `transcriptFramesBytes_injective_of_wellFormed`
- `transcriptBytes_injective_of_wellFormed`
- `wellFormedTranscript_bytes_injective`
- domain-byte separation for well-formed transcript initializers
- 384-bit proof-envelope kind separation for well-formed transcript bytes

Decision: QROM/compiler theorem paths must quantify over this well-formed
transcript layer, not arbitrary `TranscriptState` values.

### `Digest384Serialization.lean`

This is the theorem-critical digest-width companion to the existing
serialization layer.

It defines:

- `DigestWire width`
- `Digest384Wire`
- `digest384Encode`
- `digest384Decode?`
- `ProofEnvelopeContext384Wire`
- `proofEnvelopeTranscriptBinding384Encode`
- `proofEnvelopeTranscriptBinding384Decode?`

It proves 384-bit digest encode/decode round trips, fixed lengths, and binding
encoding injectivity.

Decision: raw 256-bit digest wires remain useful for compatibility and
non-theorem-critical metadata, but acceptance-critical theorem bindings should
go through the 384-bit binding layer.

### `TypedDigestSemantics.lean`

This file is no longer fixed to a 256-bit digest wrapper.

It now defines:

- `TypedDigestDomainFamily`
- theorem-critical domain families for artifact, provenance, replay,
  component-root, randomness-session, leakage, and carry;
- `TypedDigestWire width`
- `TypedDigest384Wire`
- `TypedDigestBinding width`
- `TypedDigest384Binding`

It proves domain-family encoding injectivity, typed digest encoding injectivity,
typed frame encoding injectivity, and typed digest domain separation.

Decision: theorem-critical digest equality is a typed 384-bit binding equality,
not an untyped raw digest comparison.

### `PiCCSConstructiveFiniteSoundness.lean`

This file no longer depends on the certificate-first PiCCS wrapper. It imports
the sum-check soundness core and prefix bad-challenge layer directly.

It defines:

- `PiCCSBadChallengeSetConstructed`
- `PiCCSConstructiveSumcheckBadChallengeBudget`
- `PiCCSTraceChallengeFailureCovered`

It proves:

- bad-set membership iff round mismatch plus support agreement;
- cardinality bounded by `numVars * maxDegreePerRound`;
- trace challenge failures land in the constructed finite bad set.

Decision: PiCCS finite soundness should cite the constructive file, not the
legacy certificate wrapper, whenever the actual bad set is needed.

### `TerminalCEConstructiveFiniteSoundness.lean`

This file is the replacement theorem surface for the older certificate-budget
profile theorem.

It defines:

- `TerminalCEConstructiveBadSeeds`
- `TerminalCEConstructiveVerifierSemantics`
- `TerminalCEConstructiveFailureLocalization`

It proves:

- extraction outside the concrete bad-seed set;
- `TerminalCEConstructiveBadSeeds.card <= roundCount * 3` from an injective
  bad-seed-to-`(round, challenge)` localization;
- the corresponding `TerminalCEProofBadSeedBudget roundCount` bound.

Decision: `TerminalCEFiniteSoundness.lean` remains a compatibility layer.
Constructive CE finite soundness should cite
`TerminalCEConstructiveFiniteSoundness.lean`.

### `ErrorLedger.lean` and `FiniteUniformProbability.lean`

The probability layer is no longer only an abstract probability shell.

It now has:

- exact finite-uniform probability over finite supports;
- `Pr[event] = |event ∩ support| / |support|`;
- cardinality-to-rational probability bounds;
- a bridge equating the Fiat-Shamir finite-uniform ledger event with
  `superNeoFiatShamirProbability`;
- selected-depth numerator arithmetic via `selectedDepthLossNumerator`;
- a selected-depth probability cap theorem.

Decision: classical finite seed probability accounting is connected. QROM
oracle-game semantics remain a separate cryptographic theorem/evidence boundary.

## Legacy Or Compatibility Surfaces

The following files are still useful, but should be cited precisely:

- `Transcript.lean`: low-level deterministic transcript operations and
  length-counted constructors; not the theorem-facing injective transcript
  object by itself.
- `TerminalCEFiniteSoundness.lean`: compatibility and older certificate
  wrappers; use the constructive CE file for derived finite bad-seed budgets.
- `PiCCSFiniteSoundness.lean`: legacy certificate interface; use
  `PiCCSConstructiveFiniteSoundness.lean` for constructed bad challenge sets.
- `VectorChecks.lean`: executable conformance harness; not theorem-critical
  security evidence.
- `ProductSecurityTheorem.lean`: evidence-parametric theorem surface for split
  oracles, CTCO / Merkle-straightline compiler families, selected-depth loss
  accounting, and explicit obligation status.

## Remaining Boundaries

The old broad Lean implementation list is closed, but two theorem-critical
formal integrations remain open and are intentionally tracked as planned groups:

- connect accepted Swift/trace terminal CE failure seeds to concrete bad rounds,
  instantiating the checked terminal CE evidence package;
- instantiate the checked PiRLC linear-defect semantics for the selected
  concrete Swift/trace folded relation's product-level defect predicate, or
  prove the stronger full-ring unit-pivot evidence package for that selected
  path. The full public-field observation family can now be discharged through
  the checked finite-family bad-seed certificate once that defect predicate is
  proved;
- connect deployed Swift verifier/prover behavior to the formal trace
  semantics at release-grade assurance, beyond grammar/vector conformance;
- close product operations evidence for hosted context/provenance/replay,
  authorization, audit retention, and signed distribution;
- provide independent cryptographic/implementation/side-channel review records
  before production-security wording.

## Safe Claim

Safe:

> The corrected finite formal model has checked Lean endpoints for well-formed
> transcript injectivity, 384-bit theorem-critical bindings, constructive PiCCS
> and terminal CE finite bad-set theorems, PiRLC finite-soundness certificates
> under explicit localization hypotheses, and exact finite-uniform probability
> accounting.

Not safe:

> The repository has a completed formal protocol theorem, production QROM
> security, or production side-channel certification.
