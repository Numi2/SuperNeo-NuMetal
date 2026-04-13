# Binary-Addition Artifact Metadata Hardening, 2026-04-13

This pass tightens the checked-artifact boundary for the bundled
`binary-addition-v1` workload.

## Finding

- Binary-addition proof verification cryptographically binds the public input
  bits through the public statement digest and proof envelope.
- The redundant `workloadParameters.publicSum` field was only checked when it
  was present, so artifacts with missing or malformed public-sum metadata could
  still pass CLI self-consistency verification.
- This was not a verifier bypass, but it was weaker than the repository's
  stated artifact-canonicality posture: checked vectors should fail closed when
  redundant metadata is missing or inconsistent.

## Work Completed

- CLI verification now requires `workloadParameters.publicSum` for
  `binary-addition-v1` artifacts.
- The public sum must parse as a canonical unsigned decimal string and must
  match the little-endian binary sum bits in `publicInputs`. The CLI rejects
  non-canonical spellings such as leading-zero `042` instead of silently parsing
  them as `42`.
- `TestVectors/artifact.schema.json` now requires `publicSum` for
  binary-addition artifacts.
- `Scripts/validate-test-vectors.swift` now enforces the same public-sum rule
  and rejects unsupported binary-addition bit counts.
- `Scripts/production-gate.sh` now creates tampered binary-addition artifacts
  with `publicSum` removed and with non-canonical `publicSum: "042"`, then
  requires strict CLI verification to reject both.

## Verification

```sh
swift Scripts/validate-test-vectors.swift
Scripts/production-gate.sh
```

Result: passed.

## Residual Boundary

The public sum remains redundant metadata. The cryptographic statement is still
the normalized public input and its statement digest. Production callers must
continue pinning trusted public inputs, proof kind, shape digest, statement
digest, and verifier-key digest outside the artifact.
