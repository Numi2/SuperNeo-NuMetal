# Release Candidate Runbook, 2026-04-16

This runbook defines the repeatable path for a research/integration release
candidate. It does not authorize production-security release claims.

## Preconditions

- The worktree is clean.
- `CHANGELOG.md` records user-facing changes and residual production-security
  blockers.
- `Docs/ProductionReadinessAuditPacket-2026-04-16.md` reflects the current gate
  result and no-go list.
- `Docs/SchemaCompatibility-2026-04-16.md` reflects any public artifact,
  manifest, or proof-envelope changes.
- `elan`, Swift, and the pinned Lean toolchain are available.

## Candidate Gate

Run the full gate without formal skipping:

```sh
Scripts/production-gate.sh
```

Optional benchmark and full estimator evidence can be attached when making
performance or security-estimate claims:

```sh
Scripts/production-gate.sh --with-benchmarks
Scripts/reproduce-lattice-estimator.sh release-evidence/lattice-estimator.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --require-claimed-security release-evidence/lattice-estimator.json
```

## Evidence Packet

After the full gate passes, generate release evidence from the clean worktree:

```sh
Scripts/generate-release-candidate-evidence.py \
  --release-name <tag-or-candidate-name> \
  --production-gate-result passed \
  --output release-evidence/<tag-or-candidate-name>.json
```

Validate the evidence:

```sh
Scripts/validate-release-candidate-evidence.py \
  --expect-production-gate-result passed \
  release-evidence/<tag-or-candidate-name>.json
```

The generated evidence records:

- commit, branch, remote, and dirty/clean state,
- Swift, Lean, and Lake toolchain versions,
- full production-gate command and result,
- public artifact, manifest, schema, and proof-envelope versions,
- release-policy documentation paths,
- formal status summary,
- explicit unsigned research-artifact signing status,
- residual production-security boundaries.

## Signing And Publication

Until a repository signing key and provenance format are selected, generated
artifacts must be published as unsigned research artifacts. Production-security
release language remains blocked until signed artifacts and verification
instructions are available.

For a research/integration tag:

1. Attach the release evidence JSON.
2. Attach any benchmark reports used by release notes.
3. Attach the Sage-backed lattice-estimator artifact only if it was actually
   run and validated.
4. State that the artifact is unsigned unless a signing command and public key
   are included.
5. State that production-security blockers remain as listed in the audit packet.

## Branch Protection

Protected release branches should require:

- `.github/workflows/production-gate.yml` macOS full production gate,
- `.github/workflows/production-gate.yml` Ubuntu Lean formal cross-check,
- review for changes under `SuperNeo-NuMetal/`, `SuperNeoCLI/`, `Tools/`,
  `Scripts/`, `Formal/`, `.github/workflows/`, `TestVectors/`, and `Docs/`.

Branch-protection configuration is repository-hosting state, so this runbook can
define the required policy but cannot prove the hosted setting is enabled.
