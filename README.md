# SuperNeo NuMetal

SuperNeo NuMetal is a research-grade Swift/Metal implementation of the SuperNeo
folding protocol over the `Goldilocks/Phi81(d=54)` profile. The repo includes
versioned proof envelopes, checked NumiSeal artifact paths, validation scripts,
benchmark/release evidence, and a Lean 4 formal track under `Formal/`.

Current safe claim:

> SuperNeo NuMetal has a completed Lean formal protocol theorem for the
> corrected finite model, checked proof-envelope and NumiSeal artifact paths, and
> explicit remaining product/QROM/release evidence boundaries.

This is not a production-security claim. The repo does not claim production
post-quantum security, production QROM security, whole-stack constant-time
certification, or independent cryptographic audit completion.

## Current Status

As of 2026-04-17, the old formal blocker list has been retired. The current
formal solution is built around:

- well-formed, length-counted transcripts with byte injectivity;
- 384-bit theorem-critical proof-envelope binding encodings;
- width-parameterized typed digest domains;
- constructive PiCCS finite bad-challenge sets built from the sum-check
  soundness layer;
- constructive terminal CE finite bad-seed accounting over concrete
  extraction-failure semantics;
- exact finite-uniform Fiat-Shamir seed probability connected to the
  selected-depth error ledger.

The remaining gaps are product/security evidence gaps, not the old Lean
interface gaps:

- instantiate split-oracle CTCO or Merkle-straightline QROM compiler evidence;
- provide release-grade Swift trace/extractor equivalence evidence;
- close hosted product operations evidence for context, provenance, replay,
  authorization, audit retention, and signed distribution;
- finish independent cryptographic, implementation, and side-channel review.

## Formal Source Of Truth

Use these Lean files for theorem-facing references:

- `Formal/SuperNeoFormal/WellFormedTranscript.lean`
- `Formal/SuperNeoFormal/Digest384Serialization.lean`
- `Formal/SuperNeoFormal/TypedDigestSemantics.lean`
- `Formal/SuperNeoFormal/PiCCSConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/TerminalCEConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/FiniteUniformProbability.lean`
- `Formal/SuperNeoFormal/TranscriptProbability.lean`
- `Formal/SuperNeoFormal/ErrorLedger.lean`
- `Formal/SuperNeoFormal/ProductBadEventLedger.lean`
- `Formal/SuperNeoFormal/ProductSecurityTheorem.lean`

These files remain useful but are not the final theorem-critical endpoints:

- `Formal/SuperNeoFormal/Transcript.lean`: low-level transcript operations.
- `Formal/SuperNeoFormal/TerminalCEFiniteSoundness.lean`: compatibility wrapper.
- `Formal/SuperNeoFormal/PiCCSFiniteSoundness.lean`: legacy certificate
  interface.
- `Formal/SuperNeoFormal/VectorChecks.lean`: executable conformance harness.

## Verification

Build the full Lean import wall:

```sh
cd Formal
lake build SuperNeoFormal
```

Validate formal-status documentation:

```sh
Scripts/validate-formal-status.py
```

Scan the formal source tree for unfinished proof terms:

```sh
rg '\b(axiom|sorry|admit)\b' Formal/SuperNeoFormal Formal/SuperNeoFormal.lean
```

The current tree builds through `SuperNeoFormal`, the formal-status manifest
validates, and the unfinished-proof scan returns no matches.

## QROM Direction

The accepted direction is not the legacy DFM20 multi-round production route.
DFM20 records remain as fail-closed diagnostics only.

The active theorem target is:

- split ideal oracles for challenge and binding roles;
- 256-bit challenge seeds with deterministic expansion;
- 384-bit theorem-critical binding digests;
- CTCO as the preferred compiler family;
- Merkle-straightline as the fallback compiler family;
- interactive soundness charged outside the QROM transform term;
- shared bad events charged through the selected-depth ledger.

Production QROM language stays disabled until the explicit product/QROM evidence
records and total-loss bounds are instantiated.

## Important Docs

- `math-audit.md`: current formal audit and source-of-truth summary.
- `notes-math-ai.md`: theorem-package direction and QROM target.
- `Docs/FormalVerification.md`: formal-track overview.
- `Docs/WhatThisProves.md`: public claim boundaries.
- `Docs/CryptographicSecurityDossier-2026-04-16.md`: product/security dossier.
- `Docs/FormalCompletionResearchPlan-2026-04-14.md`: historical closure record,
  no longer an active blocker plan.

## Repository Areas

- `SuperNeo-NuMetal/`: Swift implementation, protocol paths, serialization, and
  product-facing code.
- `Formal/`: Lean 4 workspace and theorem stack.
- `Docs/`: formal status, product security, release, schema, and operations
  notes.
- `Scripts/`: validation, release, estimator, and evidence tooling.
- `TestVectors/`: checked vector and manifest fixtures.
- `Evidence/`: release and constant-time evidence records.

## Do Not Claim

Avoid these phrases unless new evidence explicitly closes the relevant boundary:

- “production-secure SNARK”
- “production QROM-secure”
- “constant-time implementation”
- “general program compiler to CCS”
- “independently audited cryptographic product”
