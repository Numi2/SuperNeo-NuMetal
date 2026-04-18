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
> primitive used by the algebraic transcript challenge paths. The CTCO
> delayed-message and unique-response data are pinned, the ideal split-QRO
> compiler-overhead term is instantiated as zero, and the exact finite
> probability wiring is recorded in the selected total-loss budget. The shared
> cryptographic core bad events are charged once through `epsilon_core_shared`.
> Some theorem-critical integrations remain open: underlying interactive
> security bounds, ZK simulator loss, concrete Swift/trace terminal CE
> localization evidence, concrete PiRLC fold-failure-to-delta-collision
> localization, and the remaining non-QROM selected total-loss terms.

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
  extraction-failure semantics, including slot-seed and Swift-round certificate
  endpoints plus checked Swift-trace challenge-tape matching and a
  slot-to-full-challenge-tape finite preimage bridge;
- PiRLC finite-soundness evidence packages for full-ring unit-pivot delta
  collision and conservative CRT-component delta collision with the `5^27`
  projection-fiber factor, now using the concrete upper-half challenge-coefficient
  fiber index, plus a checked linear-defect route from accepted folded claims to
  the concrete CRT component certificate. The linear-observation core covers
  commitment, public-input, and evaluation coordinates of the actual folded
  claim, and the finite observation-family lift unions the checked bad seeds
  across a selected family with the explicit family-cardinality multiplier. The
  full public-field family is instantiated with a concrete
  `(rows + publicCount + evalCount)` multiplier;
- exact finite-uniform Fiat-Shamir seed probability modules and a selected-depth
  ledger interface.
- checked proof-size and whole-stack benchmark coverage manifests, including
  `TestVectors/e2e-proof-metrics-v1.json` and
  `TestVectors/benchmark-coverage-v1.json`, used as evidence gates rather than
  latency claims.

The remaining Lean integration gaps are theorem-critical and must not be folded
into product/security evidence status:

- instantiate constructive terminal CE localization evidence beyond the checked
  slot and full-tape certificate endpoints, by proving the concrete Swift/trace
  parser supplies the required bad-round selector. The full ternary tape and
  proof-level full-tape certificate constructor are now checked directly from
  the Swift response-tag trace;
- complete CRT-based PiRLC finite soundness on top of `Phi81CRT.lean` and
  `PiRLCConcreteCollision.lean`. The formal surface now includes a conservative
  CRT component bad-seed budget with the necessary `5^27` fiber factor and
  constructs the component-localization certificate from a delta-collision
  proof plus the checked upper-half coefficient fiber used by the Swift
  challenge encoding. It also proves that any accepted fold with a sound folded
  output reaches that certificate from a linear defect functional, and provides
  concrete linear observations for the folded claim fields, including a finite
  observation-family soundness certificate for the full public field family.
  Closing the integration still requires concrete protocol evidence that the
  selected Swift/trace folded relation supplies the selected defect predicate. The
  stronger `1/5^54`-style count is exposed only under an explicit full-ring
  unit-pivot collision evidence package.

The remaining product/security evidence gaps are separate:

- instantiate numeric extractor, interactive-security, ZK-simulator,
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
The extractor loss accounting ledger is pinned at
`TestVectors/product-extractor-loss-accounting-v1.json`.
The release distribution evidence ledger is pinned at
`TestVectors/product-release-distribution-evidence-v1.json`.

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
