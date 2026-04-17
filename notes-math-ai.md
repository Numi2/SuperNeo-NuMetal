# SuperNeo / NumiSeal Theorem Package Notes

Date: 2026-04-17

This note is the current theorem-package direction after the formal cleanup. It
replaces the older pasted QROM mandate text and removes instructions that are
already implemented in Lean.

## Current State

The formal package now has the lower theorem objects that the product/QROM
surface needs:

- well-formed transcript states with byte injectivity;
- 384-bit theorem-critical proof-envelope binding encodings;
- parameterized typed digest wires and explicit digest domain families;
- constructive PiCCS finite bad-challenge sets derived from the sum-check
  prefix soundness layer;
- constructive terminal CE finite bad-seed accounting derived from concrete
  extraction-failure semantics and a bad-seed localization;
- finite-uniform probability accounting connected to the Fiat-Shamir seed
  product and selected-depth numerator arithmetic.

The top-level product theorem remains intentionally evidence-parametric. That
is the right shape: the lower Lean math is now concrete where it should be, and
the product theorem explicitly records the cryptographic/release evidence still
needed for production wording.

## QROM Direction

The approved theorem direction remains:

- split ideal random oracles for challenge and binding roles;
- 256-bit challenge seeds and counter expansion;
- 384-bit theorem-critical binding digests;
- CTCO as the preferred compiler family;
- Merkle-straightline as the fallback compiler family;
- interactive soundness charged outside QROM transform loss;
- shared bad events charged through a tagged ledger rather than flat duplicated
  rows.

The old DFM20 multi-round production route is not the target. It remains a
legacy diagnostic/comparison path only.

## Implemented Lean Anchors

Use these files in future theorem notes:

- `Formal/SuperNeoFormal/WellFormedTranscript.lean`
- `Formal/SuperNeoFormal/Digest384Serialization.lean`
- `Formal/SuperNeoFormal/TypedDigestSemantics.lean`
- `Formal/SuperNeoFormal/PiCCSConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/TerminalCEConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/FiniteUniformProbability.lean`
- `Formal/SuperNeoFormal/ErrorLedger.lean`
- `Formal/SuperNeoFormal/ProductBadEventLedger.lean`
- `Formal/SuperNeoFormal/ProductSecurityTheorem.lean`

Avoid citing these as final theorem-critical endpoints:

- `TerminalCEFiniteSoundness.lean` for the final CE budget;
- `PiCCSFiniteSoundness.lean` for constructed PiCCS bad sets;
- raw 256-bit digest wires for acceptance-critical theorem binding;
- arbitrary `TranscriptState` byte strings for canonical transcript injection.

## Remaining Evidence

The remaining work is no longer “add well-formed transcripts” or “add 384-bit
digest serialization.” Those are done. The remaining work is:

- instantiate product/QROM evidence for the selected compiler family;
- prove or externally certify the release-grade Swift trace/extractor
  equivalences consumed by the theorem surfaces;
- close hosted product operations evidence for provenance, replay,
  authorization, audit retention, and signed release distribution;
- record independent cryptographic, implementation, and side-channel review.

## Safe Summary

The formal stack now supports the corrected finite theorem package. Production
QROM/security wording is still blocked until the explicit product/QROM and
release evidence records are instantiated.
