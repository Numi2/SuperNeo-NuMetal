# Formal Completion Research Plan, 2026-04-14

Formal status: corrected finite-model core with open theorem-critical integrations.

This document is now a historical planning record, not the active source of
truth. Earlier versions of this note described gaps in Swift byte equivalence,
finite probability composition, transcript canonicality, typed digest width,
certificate-first PiCCS soundness, and certificate-first terminal CE soundness.
Some lower-layer items have since been corrected, but the upper theorem path is
still tracked by the narrower status in `README.md`.

## Corrected Lower-Layer Path

The corrected formal path now includes:

- Swift/Lean `GoldilocksField` and `GoldilocksExt2` serialization equivalence
  surfaces.
- Swift/Lean CE proof-byte grammar and branch-selection equivalence surfaces.
- Well-formed length-counted transcript states with byte-injectivity theorems.
- 384-bit theorem-critical proof-envelope binding encodings.
- Width-parameterized typed digest wires and explicit digest domain families.
- Constructive PiCCS finite bad-challenge sets derived from the sum-check
  low-degree and prefix soundness files.
- Constructive terminal CE finite bad-seed accounting over the concrete
  extraction-failure bad-seed set.
- Exact finite-uniform probability modules over the finite Fiat-Shamir seed
  product.
- Selected-depth numerator arithmetic in the error ledger.
- Explicit theorem-obligation status records for upper evidence-parametric
  theorem surfaces.

## Current Source Of Truth

Use these files for the current formal solution:

- `Formal/SuperNeoFormal/WellFormedTranscript.lean`
- `Formal/SuperNeoFormal/Digest384Serialization.lean`
- `Formal/SuperNeoFormal/TypedDigestSemantics.lean`
- `Formal/SuperNeoFormal/PiCCSConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/TerminalCEConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/FiniteUniformProbability.lean`
- `Formal/SuperNeoFormal/ErrorLedger.lean`
- `Formal/SuperNeoFormal/ProductSecurityTheorem.lean`
- `Formal/SuperNeoFormal/TerminalCEVerifierSemantics.lean`
- `Formal/SuperNeoFormal/PiRLCFiniteSoundness.lean`

## What Is No Longer Active

Do not carry forward these older blocker statements:

- “Transcript bytes are not canonical for theorem use.”
  The theorem path now uses `WellFormedTranscript`.
- “The theorem-critical digest layer is fixed to 256 bits.”
  The theorem path now has `Digest384Serialization` and 384-bit typed digest
  bindings.
- “PiCCS finite soundness is only certificate-style.”
  The constructive PiCCS bad set is now built directly from the sum-check prefix
  theorem.
- “Terminal CE finite soundness has only a tautological budget certificate.”
  The constructive CE endpoint now derives `roundCount * 3` from bad-seed
  localization.
- “Transcript probability is disconnected from the error ledger.”
  The finite-uniform bridge and selected-depth numerator theorem are now in
  `ErrorLedger.lean`.

## Remaining Integration Work

The remaining work includes theorem-critical integrations and product/security
evidence:

- wire the 384-bit typed-digest layer through the upper theorem boundary;
- instantiate constructive terminal CE localization evidence;
- complete CRT-based PiRLC finite soundness;
- keep exact finite probability wired through the selected-depth ledger and
  product theorem;
- instantiate the split-oracle CTCO or Merkle-straightline QROM compiler
  evidence records;
- provide release-grade Swift trace/extractor equivalence evidence;
- finish hosted product operations evidence for context, provenance, replay,
  authorization, audit retention, and signed distribution;
- record independent cryptographic, implementation, and side-channel review.

## Verification

Run:

```sh
cd Formal
lake build SuperNeoFormal
```

The current top-level build succeeds, but build success is not the same as a
closed instantiated theorem.
