# Roadmap Status

Formal status: completed formal protocol theorem.

This file replaces the old long roadmap narrative. Use it as a short pointer to
current source-of-truth files.

## Active Architecture

- Product architecture: `Docs/QROProductArchitecture-2026-04-25.md`
- Paper development notes: `Docs/SuperNeoPaperDevelopmentNotes-2026-04-25.md`
- Paper implementation tracks: `Docs/SuperNeoPaperImplementationTracks-2026-04-25.md`
- Paper reproduction: `Docs/PaperReproduction.md`
- CLI surface: `Docs/CLI.md`
- Product integration: `Docs/ProductIntegrationLayer-2026-04-16.md`
- Product operations: `Docs/ProductOperationsReadiness-2026-04-16.md`
- Proof envelopes: `Docs/ProofEnvelope.md`
- Public claim boundary: `Docs/WhatThisProves.md`

## Current Development Priorities

1. Keep NumiSealZK product artifacts as the product path.
2. Keep `pay-per-bit-v1` as the source decomposition/opening profile.
3. Expand verifier-negative tests before adding prover conveniences.
4. Keep product-control inputs signed: context, provenance, issued QRO, replay
   ledger, and audit log.
5. Keep side-channel certificates optional for default development contexts but
   validated when supplied.

## Evidence Pointers

- Product/security dossier: `Docs/CryptographicSecurityDossier-2026-04-16.md`
- Parameter dossier: `Docs/ParameterSecurityDossier-2026-04-16.md`
- Paper parameters: `Docs/Parameters.md`
- Lattice estimator reproduction: `Docs/LatticeEstimatorReproduction.md`
- Threat model: `Docs/ThreatModel.md`
- GPU determinism and Metal policy: `Docs/GPUDeterminism.md`
- High-assurance hardening: `Docs/HighAssuranceHardening-2026-04-13.md`
- Release gate: `Docs/ProductionReadinessAuditPacket-2026-04-16.md`
- Release policy: `Docs/ReleaseEngineering-2026-04-16.md`
- Schema ledger: `Docs/SchemaCompatibility-2026-04-16.md`
- Benchmark coverage: `Docs/Benchmarking.md`
- Audit blocker note: `Docs/AuditBlockerNarrowing-2026-04-16.md`

## Formal Track

The formal status files remain in the `Docs/Formal...` document set and
`Formal/`. Do not use this roadmap as a formal source of truth.
