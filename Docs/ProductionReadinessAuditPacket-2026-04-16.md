# Production Readiness Audit Packet, 2026-04-16

Formal status: conditional protocol formalization.

This packet is the current reviewer entry point for production-readiness
assessment. It records what the repository can substantiate today, what the
local release gate has covered, and what still blocks a production-security
claim.

## Current Qualification Result

Local command:

```sh
Scripts/production-gate.sh
```

Result: passed.

Coverage included:

- release build,
- debug XCTest suite,
- release XCTest suite,
- R1CS artifact schema contract validation and schema mutation tests,
- NumiSeal artifact schema contract validation and schema mutation tests,
- release policy, schema compatibility, and CI gate drift validation,
- checked vector validation,
- NumiSeal vector validation,
- production `superneo verify --require-numiseal` adversarial matrix,
- terminal and compressed-terminal CLI smoke tests,
- lattice-estimator dry-run artifact validation,
- Lean `lake build`,
- Lean vector-check target,
- Lean executable proof-import wall and Swift/Lean vector checks,
- formal status, profile-constant, Ext2 serialization, and CE byte
  serialization validation,
- Swift/Lean Ext2 vector comparison,
- Swift/Lean CE vector comparison.

This is a strong release gate for the implemented repository scope. It is not
an external cryptographic audit, side-channel certification, or product
deployment approval.

## CI Policy

`.github/workflows/production-gate.yml` runs the full macOS production gate on
pull requests, `main`, and manual dispatch. That job installs the pinned Lean
toolchain through `elan` and runs `Scripts/production-gate.sh` without
`--skip-formal`, so the Swift/Lean vector bridges are checked in the same job as
the release Swift CLI and XCTest gates.

The workflow also keeps an Ubuntu Lean cross-check for the formal workspace,
formal executable gates, status manifest, profile constants, Ext2 serialization
surface, and CE byte-serialization surface. That second job is not a replacement
for the full macOS production gate; it is an additional platform check for the
formal side of the repository.

## Evidence Map

Core implementation and verifier boundaries:

- `SuperNeo-NuMetal/`
- `SuperNeoCLI/main.swift`
- `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealArtifactVerifier.swift`
- `Tools/NumiSealVectorCLI/main.swift`

Threat model and proof semantics:

- `Docs/ThreatModel.md`
- `Docs/WhatThisProves.md`
- `Docs/ProofEnvelope.md`
- `Docs/CLI.md`
- `Docs/AuditBlockerNarrowing-2026-04-16.md`

Formal status:

- `Docs/FormalStatus.json`
- `Docs/FormalAssumptionLedger-2026-04-14.md`
- `Docs/FormalRemainingBoundaries-2026-04-14.md`
- `Formal/`

Release and validation gates:

- `Scripts/production-gate.sh`
- `.github/workflows/production-gate.yml`
- `Docs/ReleaseEngineering-2026-04-16.md`
- `Docs/SchemaCompatibility-2026-04-16.md`
- `Docs/ReleaseCandidateRunbook-2026-04-16.md`
- `CHANGELOG.md`
- `Scripts/validate-release-readiness-policy.py`
- `Scripts/generate-release-candidate-evidence.py`
- `Scripts/validate-release-candidate-evidence.py`
- `Scripts/test-release-candidate-evidence-validation.py`
- `Scripts/validate-test-vectors.swift`
- `Scripts/test-vector-manifest-validation.py`
- `Scripts/validate-artifact-schema.py`
- `Scripts/test-artifact-schema-validation.py`
- `Scripts/validate-numiseal-artifact-schema.py`
- `Scripts/test-numiseal-artifact-schema-validation.py`
- `Scripts/test-numiseal-vector-validation.py`
- `Scripts/test-numiseal-superneo-cli-validation.py`

Checked artifacts:

- `TestVectors/manifest.json`
- `TestVectors/artifact.schema.json`
- `TestVectors/numiseal-manifest.json`
- `TestVectors/numiseal-artifact.schema.json`

Benchmark and estimator evidence:

- `Docs/Benchmarking.md`
- `Docs/BenchmarkReports/`
- `Scripts/reproduce-lattice-estimator.sh`
- `Scripts/validate-lattice-estimator-artifact.py`

## Production-Ready For

Within the repository's stated scope, the code is ready for:

- local and CI release-gate validation,
- implementation research,
- reproducibility review,
- verifier integration experiments with caller-owned trusted context,
- checked terminal, compressed-terminal, and NumiSeal artifact verification
  using explicit policy gates.

For NumiSeal, the production-facing surface is verification and inspection of
the checked immediate-residual artifact family. The shared
`NumiSealArtifactVerifier` is the library boundary for metadata validation,
public obligation reconstruction, policy construction, envelope checks, caller
trust-pin checks, and final verifier dispatch.

## Not Yet Production-Ready For

The repository must not yet be presented as:

- an independently audited cryptographic library,
- a production-secure post-quantum SNARK,
- a general zero-knowledge system for arbitrary application statements,
- a hosted verifier service, wallet, replay-protection service, or policy
  engine,
- a formally constant-time implementation,
- a completed formal end-to-end protocol theorem,
- a general program-to-CCS compiler,
- a general NumiSeal production proving product.

## Remaining No-Go Items

These are the remaining blockers before using production-security language:

1. Independent cryptographic and implementation security audit.
2. Side-channel review for Swift, LLVM, CPU microarchitecture, allocation, and
   timing behavior.
3. Product integration layer for trusted key distribution, expected-context
   storage, artifact provenance, replay protection, persistence, access
   control, logging, and user-facing error policy.
4. Completion or explicit narrowing of formal claims around the remaining
   `Docs/FormalStatus.json` blocker groups:
   `superneo-full-probability-composition`,
   `swift-goldilocks-ext2-serialization-equivalence`, and
   `swift-ce-verifier-byte-equivalence`.
5. Full pinned lattice-estimator execution under SageMath for release evidence,
   not only dry-run derivation.
6. Broader hardware benchmark reports before making cross-generation
   performance claims.
7. Release engineering execution: signed artifacts and hosted branch-protection
   enforcement requiring the full production gate. The changelog, reproducible
   release instructions, release evidence tooling, and schema compatibility
   policies now exist and are checked by
   `Scripts/validate-release-readiness-policy.py`.

## Next Engineering Slice

The next high-leverage implementation slice is public NumiSeal artifact
generation:

```sh
superneo prove --seal numiseal ...
```

That work should reuse the shared `NumiSealArtifactVerifier` trust boundary and
keep deterministic vector generation separate from randomized production
proving. The slice should include prover-side schema policy, generated-artifact
negative tests, CLI docs, and production-gate coverage before being advertised
as a public proving surface.
