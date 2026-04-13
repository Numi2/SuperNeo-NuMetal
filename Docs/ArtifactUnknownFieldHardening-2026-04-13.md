# Artifact Unknown-Field Hardening, 2026-04-13

Scope: CLI proof-artifact parsing, checked-in test-vector validation, and the
local production gate.

## Finding

Swift `Codable` ignores unknown JSON object keys by default. That behavior is
reasonable for many application APIs, but it is the wrong default at a proof
artifact trust boundary: an artifact could carry extra top-level fields that are
not part of `TestVectors/artifact.schema.json`, while the CLI verifier and
vector validator would silently ignore them.

The ignored fields would not alter the proof envelope, shape digest, statement
digest, verifier-key digest, or transcript binding. The risk was instead
operational ambiguity: external tooling or reviewers could see unsupported
wrapper metadata that the verifier did not process.

## Change

- `superneo verify` and `superneo inspect` now reject proof artifacts whose JSON
  root is not an object or whose root object contains any unknown top-level
  field.
- `Scripts/validate-test-vectors.swift` applies the same top-level key allowlist
  before decoding vector artifacts.
- `Scripts/production-gate.sh` mutates a generated one-hot artifact by adding an
  unsupported `unexpectedTrustAnchor` field and requires strict verification to
  fail.

The allowlist matches the documented artifact schema surface:

- `artifactVersion`
- `workload`
- `profile`
- `proofKind`
- `bitCount`
- `expectedSelectedCount`
- `keySeedUTF8`
- `workloadParameters`
- `publicInputs`
- `commitmentBase64`
- `proofEnvelopeBase64`
- `shapeDigestHex`
- `statementDigestHex`
- `verifierKeyDigestHex`

## Validation

Commands run locally:

```sh
swift Scripts/validate-test-vectors.swift
swift test --disable-swift-testing --filter UsabilitySurfaceTests/testGoldenOneHotFoldVectorVerifies
Scripts/production-gate.sh
```

Result: passed. The production gate now includes the unknown-field negative
artifact check.

## Residual Boundary

This hardening is intentionally limited to top-level artifact fields. Workload
parameter maps remain workload-specific metadata surfaces; their security
meaning must continue to be validated explicitly per workload, as the
binary-addition `publicSum` check now does.
