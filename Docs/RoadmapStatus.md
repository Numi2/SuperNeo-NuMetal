# Roadmap Status

Formal status: completed formal protocol theorem.

This file replaces the old long roadmap narrative. Use it as a short pointer to
current source-of-truth files.

## Active Architecture

- Primitive spec: `Docs/PrimitiveSpec.md`
- Threat model: `Docs/ThreatModel.md`
- Parameters: `Docs/Parameters.md`
- Product architecture: `Docs/QROProductArchitecture-2026-04-25.md`
- Paper development notes: `Docs/SuperNeoPaperDevelopmentNotes-2026-04-25.md`
- Paper implementation tracks: `Docs/SuperNeoPaperImplementationTracks-2026-04-25.md`
- Paper reproduction: `Docs/PaperReproduction.md`
- CLI surface: `Docs/CLI.md`
- Product integration: `Docs/ProductIntegrationLayer-2026-04-16.md`
- Proof envelopes: `Docs/ProofEnvelope.md`
- Public claim boundary: `Docs/WhatThisProves.md`

## Current Development Priorities

1. Define the primitive and statement binding clearly enough for external
   cryptographic review.
2. Keep `pay-per-bit-v1` as the source decomposition/opening profile until a
   better parameterized replacement is reviewed.
3. Expand verifier-negative tests before adding prover conveniences.
4. Keep malformed-artifact fuzzing and stable vector regeneration close to any
   serialization, transcript, or proof-envelope change.
5. Simplify prover/verifier paths when the simplification makes the accepted
   statement, transcript domain, or rejection behavior easier to audit.

## Evidence Pointers

- Parameter dossier: `Docs/ParameterSecurityDossier-2026-04-16.md`
- Paper parameters: `Docs/Parameters.md`
- Lattice estimator reproduction: `Docs/LatticeEstimatorReproduction.md`
- Threat model: `Docs/ThreatModel.md`
- GPU determinism and Metal policy: `Docs/GPUDeterminism.md`
- High-assurance hardening: `Docs/HighAssuranceHardening-2026-04-13.md`
- Benchmark coverage: `Docs/Benchmarking.md`
- Archived compliance material: `Docs/Archive/compliance/`

## Formal Track

The formal status files remain in the `Docs/Formal...` document set and
`Formal/`. Do not use this roadmap as a formal source of truth.
