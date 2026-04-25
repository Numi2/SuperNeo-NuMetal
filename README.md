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
> probability wiring is recorded in the selected total-loss budget. The
> proof-level NumiSealZK simulator coupling is instantiated as
> `epsilon_zk_sim = 0` under the declared leakage model. The shared
> cryptographic core bad events are charged once through `epsilon_core_shared`.
> The terminal CE localization and PiRLC selected public-field finite-soundness
> integrations are now closed in Lean. Terminal CE repeated-challenge soundness
> is pinned by an exact `(2/3)^226 < 2^-128` finite-tape bound. The selected
> finite-protocol numeric obstruction is also explicit: the current one-shot
> PiRLC/PiCCS challenge supports cannot justify a selected 128-bit claim, so the
> selected product theorem uses the fixed-kind CTCO repeated-tape route instead.
> That route instantiates the source-fold finite term with two PiCCS tapes and
> three generic CRT PiRLC branches, and instantiates terminal CE at 226 rounds.
> The selected-depth Swift extractor term is now instantiated as deterministic
> post-acceptance replay with `epsilon_extract(depth=1) = 0`. The remaining
> non-production terms are separate evidence terms: hosted operations replay,
> side-channel, release-distribution loss terms, recursive carry extraction for
> promoted depths, and full production audit records.

This is not a production-security claim. The repo does not claim production
post-quantum security, production QROM security, whole-stack constant-time
certification, or independent cryptographic audit completion.

## Current Status

As of 2026-04-18, the Lean finite protocol theorem is completed for the
repository's formal model. Production-security wording remains disabled because
the selected product ledger still has separate extractor, operations,
side-channel, release, and audit evidence terms. The current formal
solution is built around:

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

The former hard Lean integration gaps are now closed by checked finite-model
endpoints and must still not be confused with product/security evidence status:

- terminal CE localization now has direct finite-soundness certificates from
  constructive localization, a slot-to-full-tape lift, Swift trace full-tape
  certificates, a pointwise two-branch repeated-challenge tape bound, the exact
  Swift profile inequality `(2/3)^226 < 2^-128`, and a checked first-round Swift
  trace selector;
- CRT-based PiRLC finite soundness now has a monotone certificate transport, a
  theorem extracting a nonzero public-field observation from failure of the
  selected public-fields-zero relation, and a direct finite-soundness
  certificate for that selected relation. The stronger `1/5^54`-style count
  remains exposed only under an explicit full-ring unit-pivot collision evidence
  package.

## Recent Benchmark Record

The latest optimization experiment targeted proof-envelope round trips by
caching parsed envelope body bytes instead of rebuilding the nested proof body
for every `superNeoBytes` request.

On the same Apple M4 quick benchmark profile captured on 2026-04-21, the saved
comparison in `Docs/BenchmarkReports/envelope-cache-2026-04-21-comparison.md`
records:

- `proofEnvelope/roundTrip/m64-K1-k0-binary`: `17 ms -> 8.62 ms` (`1.97x` faster)
- `proofEnvelope/roundTrip/m256-K2-k1-binary`: `28 ms -> 18 ms` (`1.56x` faster)

That record should be read as a targeted envelope-serialization improvement, not
as a claim that the whole quick benchmark suite moved by the same factor.

The remaining product/security evidence gaps are separate:

- instantiate operations, side-channel, and
  release-distribution loss terms in the selected total-loss budget; the
  one-shot source-fold profile remains mathematically non-128-bit
  (`5^54 < 2^128`, generic CRT PiRLC gives `1/5^27`, and the loose PiCCS
  certificate is `72/q^2`), while the selected fixed-kind CTCO repeated-tape
  route now supplies `epsilon_fold <= 16/q^4 + 1/5^81` and terminal CE is
  pinned at 226 repeated challenge rounds;
- keep release-grade Swift trace/extractor equivalence pinned to the concrete
  selected-depth replay surface;
- extend recursive carry from checked local chain replay into the selected
  hosted production-depth policy;
- keep NumiSealZK on by default for product proving and product APIs; signed
  side-channel certificates are optional only for `correctness-only` trusted
  contexts and are required when a stricter context minimum is configured;
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
- interactive soundness charged outside the QROM transform term, with per-kind
  finite-model bounds now pinned through the interactive-reduction evidence;
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
- `Docs/CompetitivePerformance-2026-04-21.md`: fresh same-hardware competitor table.
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
