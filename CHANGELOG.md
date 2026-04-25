# Changelog

Repository-level changes are summarized here. Detailed historical prose belongs
in commits and evidence manifests, not in long stale Markdown.

## Unreleased

### Production Readiness

- Selected the QRO public-coin product architecture for NumiSeal product proofs.
- Removed product acceptance through artifact-selected transcript seeds and
  legacy self-described NumiSeal JSON.
- Defaulted product proving to NumiSealZK.
- Added issued-QRO pack support, replay-ledger binding, CTCO root metadata, and
  QRO-derived source-fold and terminal transcript derivation.
- Selected `pay-per-bit-v1` as the source-fold decomposition/opening profile.
- Added verifier-hostile tests for product artifacts covering public-input,
  verifier-key, QRO pack, domain, proof-kind, replay, lane, aggregate, carry,
  malformed length, duplicate-key, and bit-flip mutations.
- Added checked NumiSeal end-to-end theorem scope evidence.
- Added recursive folding knowledge soundness evidence.
- Added typed carry producer/consumer evidence.
- Added NumiSealZK simulation/privacy evidence.
- Added exact rejection-sampled field mask distribution evidence.
- Added the product cryptographic security dossier for the bounded-depth
  product security theorem.
- Added selected-depth loss accounting, extractor loss accounting, total-loss
  budget, and release distribution evidence manifests.
- Added QROM public-coin accounting, QROM transcript schedule, QROM
  sampler/encoding evidence, QROM collision/malleability evidence, QROM
  transform preconditions, and QROM interactive-reduction evidence.
- Added constant-time release evidence and scoped Swift/LLVM/Metal lowering
  evidence.
- Added benchmark coverage, E2E proof metrics, product operations readiness,
  signed revocation feed support, and release-candidate evidence tooling.

Release validators track these exact evidence labels:

- NumiSeal end-to-end theorem scope
- recursive folding knowledge soundness
- typed carry producer/consumer
- NumiSealZK simulation/privacy
- exact rejection-sampled field mask distribution
- product cryptographic security dossier
- bounded-depth product security theorem
- selected-depth loss accounting
- extractor loss accounting
- QROM public-coin accounting
- QROM transcript schedule
- QROM sampler/encoding evidence
- QROM collision/malleability evidence
- QROM transform preconditions
- total-loss budget
- release distribution evidence
- constant-time release evidence

### Compatibility

- Public R1CS/vector artifacts remain at `artifactVersion = 1`.
- Product NumiSeal artifacts use `NumiSealProductArtifact.artifactVersion == 2`.
- Public manifests remain at `manifestVersion = 1`.
- Product evidence manifests start at `schemaVersion = 1`.
- Proof envelopes use `ProofEnvelopeHeader.version = 5`.
- Source-fold product artifacts bind `sourceDecompositionProfile =
  pay-per-bit-v1`; fixed-14 decomposition is no longer the selected product
  profile.

### Repository-Local Promotion Status

- Repository-local promotion is controlled by checked manifests, validators, and
  release evidence.
- Product claims are evidence-parametric and bounded by the selected
  product/QRO/QROM/loss-accounting manifests.
- Signed side-channel certificates remain optional for `correctness-only`
  trusted contexts and required only when a stricter trusted context minimum is
  configured.
- Hosted deployment, public distribution, hardware side-channel closure, and
  independent cryptographic implementation review remain outside the
  repository-local proof claim.
