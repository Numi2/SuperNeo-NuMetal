# Schema Compatibility Policy, 2026-04-16

This document defines compatibility rules for public SuperNeo artifact surfaces.
It covers JSON proof artifacts, vector manifests, NumiSeal artifacts, NumiSeal
manifests, and binary proof envelopes.

## Current Public Versions

| Surface | Current version |
| --- | --- |
| R1CS/vector JSON artifact | `artifactVersion = 1` |
| R1CS/vector JSON Schema | `test-vector-artifact-v1.json` |
| R1CS/vector manifest | `manifestVersion = 1` |
| NumiSeal JSON artifact | `artifactVersion = 1` |
| NumiSeal JSON Schema | `numiseal-test-vector-artifact-v1.json` |
| NumiSeal manifest | `manifestVersion = 1` |
| Proof envelope header | `ProofEnvelopeHeader.version = 4` |
| NumiSeal proof envelope kind | `4` |

## Compatibility Rules

- Public artifact parsers must reject unknown top-level JSON keys unless a new
  artifact version explicitly allows them.
- Public artifact parsers must reject duplicate JSON object keys before normal
  decoding.
- Public manifest validators must reject unknown manifest keys, duplicate vector
  entries, duplicate strict commands, missing checked coverage, and
  unmanifested checked vector files.
- Changing the meaning, requiredness, digest binding, or verification semantics
  of an existing field requires a new artifact version.
- Adding a new proof envelope kind does not require a new envelope version when
  the versioned header semantics are unchanged, but parsers must fail closed on
  unsupported kinds.
- Changing header layout, transcript binding, digest framing, or body-length
  semantics requires a new `ProofEnvelopeHeader.version`.
- Deterministic test-vector seeds must not be reused as production randomness
  policy.

## R1CS/Vector Artifact Policy

Version `1` is fixed to the checked one-hot and binary-addition workload
families. It accepts proof kinds:

- `fold`,
- `terminal`,
- `compressed-terminal`.

Production verifiers must pin trusted public inputs, verifier-key digest, shape
digest, statement digest, and proof-kind policy outside the artifact.

## NumiSeal Artifact Policy

Version `1` is fixed to the checked immediate-residual NumiSeal artifact family.
It accepts only:

- `proofKind = "numiseal-terminal"`,
- `residualMode = "immediate"`,
- `keyColumnCount = 2`,
- `publicInputCount = 54`,
- `privateWitnessCount = 10`.

Production verifiers must pin trusted key seed or verifier-key digest, shape
digest, statement digest, transcript-domain digest, public-statement digest,
obligation root, lane-summary root, aggregate digests, component digest root,
proof-transcript digest, and public inputs outside the artifact.

The shared `NumiSealArtifactVerifier` is the compatibility boundary for
metadata validation, public-obligation reconstruction, policy construction,
envelope checks, expected-context checks, and verifier dispatch.

## Version Bump Checklist

Before introducing a new public artifact or envelope version:

1. Update the relevant JSON Schema.
2. Update parser allowlists and duplicate-key coverage.
3. Add checked vectors or a migration fixture.
4. Add manifest entries with strict production verification commands.
5. Add schema validator coverage.
6. Add mutation tests for old/new compatibility boundaries.
7. Update `Docs/ProofEnvelope.md`, `Docs/CLI.md`, and
   `Docs/ProductionReadinessAuditPacket-2026-04-16.md`.
8. Run `Scripts/production-gate.sh` without `--skip-formal`.
