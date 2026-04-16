# Changelog

All notable repository-level changes are recorded here. This project currently
uses research/integration release wording only; production-security release
claims remain blocked by the audit packet no-go items.

## Unreleased

### Production Readiness

- Added an audit/blocker-narrowing packet covering side-channel posture,
  product integration requirements, formal blocker status, and the local Sage
  estimator blocker.
- Added a shared NumiSeal artifact verifier boundary and reused it from the
  production `superneo verify --require-numiseal` path and vector tooling.
- Added production `superneo verify --require-numiseal` adversarial validation
  for expected-context pins, proof-kind handling, and NumiSeal public artifact
  metadata.
- Promoted the full local production gate into CI, including Lean/formal checks
  in the macOS full-gate job and an Ubuntu formal cross-check.
- Added a production-readiness audit packet, release-engineering policy, schema
  compatibility policy, release-candidate runbook, and release evidence tooling.

### Compatibility

- Public R1CS/vector artifacts remain at `artifactVersion = 1`.
- Public NumiSeal artifacts remain at `artifactVersion = 1`.
- Public manifests remain at `manifestVersion = 1`.
- Proof envelopes remain at `ProofEnvelopeHeader.version = 4`.

### Remaining Production-Security Blockers

- Independent cryptographic and implementation security audit.
- Side-channel review and constant-time certification scope.
- Product integration for provenance, replay protection, trusted context, access
  control, persistence, logging, and user-facing policy.
- Formal-claim promotion or explicit narrowing for remaining blocker groups.
- Full Sage-backed lattice-estimator execution for release evidence.
- Signed artifacts and repository branch-protection enforcement.
