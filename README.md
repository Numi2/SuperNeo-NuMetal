# SuperNeo NuMetal

SuperNeo NuMetal is a Swift/Metal research implementation of the SuperNeo
folding stack over the `Goldilocks/Phi81(d=54)` profile. It contains the Swift
prover/verifier, NumiSeal product paths, QRO-bound product verification,
checked evidence manifests, benchmark tooling, and a Lean 4 formal track under
`Formal/`.

## Current Architecture

- Product proving defaults to NumiSealZK.
- Product verification uses the explicit QRO public-coin path in
  `Docs/QROProductArchitecture-2026-04-25.md`.
- Product artifacts must be `NumiSealProductArtifact.artifactVersion == 2`.
- Old artifact-selected transcript seeds and self-described NumiSeal JSON are
  not product acceptance paths.
- Source-fold decomposition/opening uses the selected `pay-per-bit-v1` profile,
  not fixed 14-limb decomposition.
- Pay-per-bit artifacts bind the decomposition profile and must satisfy
  recomposition plus matching decomposition/output claim counts.
- Signed side-channel certificates remain optional for `correctness-only`
  trusted contexts; stricter trusted contexts can require a minimum certificate
  level.

## Claim Boundary

Repository-local claim: the checked bounded-depth evidence surface is internally
consistent for development and release-candidate use.

Not claimed: production post-quantum security, production QROM security,
whole-stack constant-time certification, hosted operations security, public
distribution assurance, or independent cryptographic and implementation review.

## Evidence To Keep In Sync

The current product/security gate is evidence-parametric. These records are the
main machine-readable anchors:

- `TestVectors/product-crypto-security-dossier-v1.json`
- `TestVectors/product-selected-depth-loss-accounting-v1.json`
- `TestVectors/product-extractor-loss-accounting-v1.json`
- `TestVectors/product-total-loss-budget-v1.json`
- `TestVectors/product-release-distribution-evidence-v1.json`
- `TestVectors/product-qrom-public-coin-accounting-v1.json`
- `TestVectors/product-qrom-transcript-schedule-v1.json`
- `TestVectors/product-qrom-sampler-encoding-evidence-v1.json`
- `TestVectors/product-qrom-collision-malleability-evidence-v1.json`
- `TestVectors/product-qrom-transform-preconditions-v1.json`
- `TestVectors/product-qrom-interactive-reduction-v1.json`
- `TestVectors/benchmark-coverage-v1.json`

Keep the extractor loss accounting, total-loss accounting, release distribution evidence,
QRO/QROM evidence, and benchmark coverage manifests aligned with any product
proof-path change.

## Fast Orientation

- `SuperNeo-NuMetal/`: Swift implementation, protocol paths, serialization, and
  product-facing code.
- `Formal/`: Lean 4 workspace and theorem stack.
- `Docs/`: current architecture, release, security, schema, and operations
  notes.
- `Scripts/`: validation, release, estimator, benchmark, and evidence tooling.
- `TestVectors/`: checked vector and evidence fixtures.
- `Evidence/`: release and constant-time evidence records.

## Useful Commands

Build the Swift package:

```sh
swift build --product superneo
```

Run the production gate when intentionally validating everything:

```sh
Scripts/production-gate.sh
```

Run the focused documentation/evidence checks after doc or evidence edits:

```sh
python3 Scripts/validate-doc-links.py
python3 Scripts/validate-release-readiness-policy.py
python3 Scripts/validate-product-ops-surface.py
python3 Scripts/validate-benchmark-coverage.py
python3 Scripts/validate-product-extractor-loss-accounting.py
python3 Scripts/validate-product-release-distribution-evidence.py
```

Build the formal import wall:

```sh
cd Formal
lake build SuperNeoFormal
```

## Current Human Docs

- `Docs/QROProductArchitecture-2026-04-25.md`: selected QRO product path.
- `Docs/CryptographicSecurityDossier-2026-04-16.md`: evidence-parametric
  security dossier.
- `Docs/WhatThisProves.md`: public claim boundaries.
- `Docs/ProofEnvelope.md`: proof-envelope binding and parser rules.
- `Docs/CLI.md`: active CLI surface.
- `Docs/Benchmarking.md`: benchmark commands and coverage gate.
- `math-audit.md`: formal audit notes.
- `notes-math-ai.md`: theorem-package direction.

## Do Not Reintroduce

- Fixed-14 source-fold decomposition as the default product path.
- Product acceptance through artifact-selected Fiat-Shamir transcript seeds.
- Self-described legacy NumiSeal JSON verification.
- Production-security wording that is not backed by the checked evidence set.
