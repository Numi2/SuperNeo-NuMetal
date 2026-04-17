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
- `Docs/E2EProofMetrics-2026-04-16.md` reflects any proof-size or product
  smoke budget changes.
- `Docs/Benchmarking.md` and `TestVectors/benchmark-coverage-v1.json` reflect
  any benchmark row coverage changes.
- `Docs/ConstantTimeEvidence-2026-04-16.md` reflects any constant-time
  source/formal or Swift/LLVM/Metal lowering evidence changes.
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json` has been
  regenerated with `Scripts/generate-constant-time-release-evidence.py` when
  scoped source, Metal kernels, the release toolchain, or observation tooling
  changed.
- `Docs/ProductOperationsReadiness-2026-04-16.md` reflects any product
  operations readiness status or signed revocation feed changes.
- `Docs/CryptographicSecurityDossier-2026-04-16.md` and
  `TestVectors/product-crypto-security-dossier-v1.json` reflect any product
  theorem, Fiat-Shamir/QROM, Module-SIS parameter, proof-size, or hardening
  boundary changes.
- `TestVectors/product-selected-depth-loss-accounting-v1.json` reflects any
  selected-depth loss-accounting changes for extractor, QROM, transcript
  collision, ZK simulator, product-ops replay, CT, or release-distribution
  terms.
- `TestVectors/product-extractor-loss-accounting-v1.json` reflects any
  extractor input, rewind schedule, source-fold extractor, terminal-seal
  extractor, product-envelope composition, or recursive carry extractor changes.
- `TestVectors/product-qrom-fiat-shamir-accounting-v1.json` reflects any
  QROM Fiat-Shamir accounting changes for proof-kind transcript interfaces,
  challenge families, domain separation, quantum random-oracle queries, or
  transcript collision/malleability terms.
- `TestVectors/product-qrom-transcript-schedule-v1.json` reflects any product
  QROM transcript schedule changes for proof-kind order, public challenge
  labels, symbolic `Q_H` query families, or schedule-to-ledger binding.
- `TestVectors/product-qrom-transform-preconditions-v1.json` reflects any
  product QROM transform precondition changes for theorem-family fit,
  public-coin protocol obligations, round schedule, challenge uniformity,
  transcript encoding, `Q_H` query bounds, or reduction-loss accounting.
- `TestVectors/product-qrom-interactive-reduction-v1.json` reflects any
  product QROM interactive reduction changes for public-coin protocol formulas,
  selected `Q_H` policy, DFM20 loss multiplier, challenge-count maxima, or
  per-kind interactive-security obligations.
- `TestVectors/product-total-loss-budget-v1.json` reflects any selected-depth
  total-loss budget, exact rational summation, required component bounds, or
  `2^-128` threshold changes.
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

The benchmark coverage manifest is mandatory release evidence, but it is only
the coverage contract for row registration, report rendering, comparison, and
gate wiring. A fresh `--with-benchmarks` run is still required before release
notes quote latency, throughput, or competitor-comparison numbers.

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
- NumiSeal product/carry/ZK conformance-scope version and digest,
- NumiSeal end-to-end theorem-scope version and digest,
- recursive folding knowledge, typed carry producer/consumer, and NumiSealZK
  simulation/privacy theorem-surface digests inside the theorem-scope manifest,
- NumiSealZK mask-distribution evidence version and digest,
- exact rejection-sampled field mask distribution evidence status,
- product cryptographic security dossier version and digest,
- bounded-depth product security theorem status,
- selected-depth loss-accounting version and digest,
- product extractor loss-accounting version and digest,
- product QROM Fiat-Shamir accounting version and digest,
- product QROM transcript schedule version and digest,
- product QROM transform preconditions version and digest,
- product QROM interactive reduction version and digest,
- product total-loss budget version and digest,
- constant-time source/formal scope version and digest,
- constant-time lowering evidence version and digest,
- constant-time release evidence version and digest,
- constant-time compiler and hardware observation lane versions and digests,
- E2E proof metrics version and digest,
- benchmark coverage version, digest, and required-surface count,
- product operations readiness status version,
- signed revocation feed policy,
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
