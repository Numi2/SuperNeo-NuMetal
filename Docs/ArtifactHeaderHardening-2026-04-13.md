# Artifact Header Hardening Pass, 2026-04-13

This pass tightened the boundary between trusted verifier context and
demo-artifact JSON metadata. The binary proof envelope is the canonical carrier
for profile, proof kind, shape digest, statement digest, verifier-key digest,
transcript domain, and body length; JSON wrappers are only transport metadata.

## Findings

- The protocol verifier already checked envelope headers against the supplied
  trusted context before accepting a proof.
- The CLI and test-vector validator still decoded artifact JSON first and only
  reached strict header rejection later through protocol verification.
- `superneo inspect` carried a small local header parser instead of using the
  library's canonical envelope parser.

## Work Completed

- Added `ProofEnvelopeHeader.parsePrefix(from:)` to parse and validate the
  canonical envelope header from public bytes.
- Added `ProofEnvelopeHeader.validateEnvelopeLength(totalByteCount:)` so CLI and
  artifact tooling can reject body-length mismatches before protocol parsing.
- Routed `superneo inspect` through the shared header parser.
- Routed `superneo verify` through early header validation and explicit
  cross-checks against artifact JSON for proof kind, shape digest, statement
  digest, verifier-key digest, and profile ID before constructing workload
  context.
- Extended `Scripts/validate-test-vectors.swift` to validate checked-in
  artifact envelope magic, version, kind, profile ID, body length, and digest
  agreement with both manifest and JSON metadata.
- Added regression coverage for the public header parser, short headers, wrong
  magic, and body-length mismatch detection.

## Residual Boundaries

- This does not make artifact JSON trusted. Production verifiers should still
  pass pinned context with `--key-seed`, expected digest flags,
  `--expected-public-inputs`, and `--require-terminal` where applicable.
- This does not change proof semantics. Fold reductions remain reductions; only
  terminal envelopes prove the terminal local CE relation.
- The CLI remains an integration/demo surface. Applications embedding this code
  should own artifact storage, replay policy, and trusted-context distribution.

## Commands

```sh
swift test --disable-swift-testing --filter ProtocolE2ETests/testProofEnvelopeRejectsHeaderTamperingAndLengthMismatch
swift Scripts/validate-test-vectors.swift
swift run superneo verify --key-seed SuperNeoCLI.one-hot-vector.v1 --expected-verifier-key-digest 7e6c4fc3ec5bee0e1872cde17322830a37fc0a2d17ed79a208f6113fd0186a86 --expected-shape-digest 84d903373ff54785a9b7d99bd048e1527deedd1173309c272992a8a87b61a765 --expected-statement-digest 786532c3daee5d41f54b619bde8b6bcc432f7ae1f40017e14953cc8ce38992e0 --expected-public-inputs 1 TestVectors/one-hot-vector-fold-v1.json
```
