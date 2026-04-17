# SuperNeo NuMetal

SuperNeo NuMetal is a research-grade Swift/Metal implementation of the SuperNeo
folding protocol over the `Goldilocks/Phi81(d=54)` profile. The repo includes
versioned proof envelopes, checked NumiSeal artifact paths, validation scripts,
benchmark/release evidence, and a Lean 4 formal track under `Formal/`.

Current safe claim:

> SuperNeo NuMetal now has a corrected Lean formal finite-model core with
> well-formed transcript injectivity, 384-bit proof-envelope context
> serialization, Phi81 CRT decomposition, constructive PiCCS bad-challenge
> accounting, and exact finite-support probability modules. The product/QROM
> theorem surface has been upgraded to the split-oracle/CTCO design, and
> acceptance-critical Swift paths now compare theorem-critical public metadata
> through 384-bit H_bind binders. Product proof-envelope paths now have
> Merkle-style CTCO root coverage and a source H_chal challenge-tape expansion
> primitive. Some theorem-critical integrations remain open: wiring the
> algebraic verifier subprotocols to consume the CTCO tape, instantiating
> constructive terminal CE localization evidence, completing CRT-based PiRLC
> finite soundness, and full wiring of exact finite probability into the
> top-level product theorem.

This is not a production-security claim. The repo does not claim production
post-quantum security, production QROM security, whole-stack constant-time
certification, or independent cryptographic audit completion.

## Current Status

As of 2026-04-18, the formal layer has made real lower-level progress, but the
full-theorem blocker list remains open at the integration level. The current
formal solution is built around:

- well-formed, length-counted transcripts with byte injectivity;
- 384-bit theorem-critical proof-envelope binding encodings;
- width-parameterized typed digest domains;
- constructive PiCCS finite bad-challenge sets built from the sum-check
  soundness layer;
- constructive terminal CE finite bad-seed accounting over concrete
  extraction-failure semantics;
- exact finite-uniform Fiat-Shamir seed probability modules and a selected-depth
  ledger interface.

The remaining Lean integration gaps are theorem-critical and must not be folded
into product/security evidence status:

- wire the theorem-critical typed-digest binding path through the upper theorem
  boundary on the 384-bit instantiation;
- instantiate constructive terminal CE localization evidence beyond the current
  constructive composition endpoint;
- complete CRT-based PiRLC finite soundness on top of `Phi81CRT.lean` and
  `PiRLCConcreteCollision.lean`;
- keep exact finite-uniform probability wired through the selected-depth error
  ledger and top-level product theorem.

The remaining product/security evidence gaps are separate:

- instantiate numeric extractor, QROM compiler-overhead, ZK-simulator,
  operations, side-channel, and release-distribution loss terms in the selected
  total-loss budget;
- complete release-grade Swift trace/extractor equivalence review for the
  pinned executable trace evidence;
- extend recursive carry from checked local chain replay into the selected
  hosted production-depth policy;
- record release-hardware ZK simulator-coupling benchmarks and side-channel
  review before default promotion;
- close hosted product operations evidence for context, provenance, replay,
  authorization, audit retention, and signed distribution;
- finish independent cryptographic, implementation, and side-channel review.

## Formal Source Of Truth

Use these Lean files for theorem-facing references:

- `Formal/SuperNeoFormal/WellFormedTranscript.lean`
- `Formal/SuperNeoFormal/Digest384Serialization.lean`
- `Formal/SuperNeoFormal/TypedDigestSemantics.lean`
- `Formal/SuperNeoFormal/Phi81CRT.lean`
- `Formal/SuperNeoFormal/PiRLCConcreteCollision.lean`
- `Formal/SuperNeoFormal/PiRLCFiniteSoundness.lean`
- `Formal/SuperNeoFormal/PiCCSConstructiveFiniteSoundness.lean`
- `Formal/SuperNeoFormal/TerminalCEVerifierSemantics.lean`
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
- `Formal/SuperNeoFormal/Phi81Split.lean`: factorization support used below the
  CRT endpoint.
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
- 256-bit challenge seeds with deterministic H_chal challenge-tape expansion;
- 384-bit theorem-critical binding digests;
- depth-1 product policy over fold, terminal, compressed-terminal,
  NumiSeal-terminal, and NumiSealZK product proof kinds;
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
