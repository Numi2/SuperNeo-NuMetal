# Workload Parameter Canonicality, 2026-04-13

Scope: CLI artifact verification, checked-in vector validation, public artifact
schema, and the local production gate.

## Finding

The proof envelope and statement digest already bind the cryptographic public
inputs. The JSON wrapper also carries workload-specific redundant metadata for
operator legibility:

- `one-hot-vector-v1`: `workloadParameters.selectedCount`
- `binary-addition-v1`: `workloadParameters.leftBitCount` and
  `workloadParameters.publicSum`

Before this pass, binary-addition `publicSum` was partially hardened, but the
workload parameter maps were still not exact. Missing one-hot `selectedCount`,
extra workload parameters, or mismatched binary-addition `leftBitCount` could be
silently ignored by the CLI while the proof remained self-consistent.

This was not a proof-system bypass. It was an artifact canonicality and
operational trust-boundary issue: all redundant metadata in checked artifacts
should be either verified exactly or rejected.

## Work Completed

- The CLI now requires exact workload-parameter key sets:
  - one-hot: `selectedCount`
  - binary-addition: `leftBitCount`, `publicSum`
- The CLI requires one-hot `selectedCount` to be canonical decimal `1`.
- The CLI requires binary-addition `leftBitCount` to be canonical decimal and
  equal to the artifact `bitCount`.
- `Scripts/validate-test-vectors.swift` applies the same workload-parameter
  checks to checked-in vectors.
- `TestVectors/artifact.schema.json` now requires workload-specific parameter
  maps and rejects extra workload-parameter keys.
- `Scripts/validate-artifact-schema.py` now gates the schema's root
  `additionalProperties: false` posture, exact root property set, and exact
  workload-parameter requirements without relying on an external JSON Schema
  package.
- `Scripts/test-artifact-schema-validation.py` mutates temporary schema copies
  and verifies that the schema checker fails closed on loosened root fields,
  extra root properties, missing workload-parameter requirements, and weakened
  canonical decimal patterns.
- `Scripts/production-gate.sh` now includes release negative checks for missing
  one-hot `selectedCount` and mismatched binary-addition `leftBitCount`.

## Validation

Commands run locally:

```sh
python3 -m json.tool TestVectors/artifact.schema.json >/tmp/superneo-artifact-schema.json
Scripts/validate-artifact-schema.py
Scripts/test-artifact-schema-validation.py
swift Scripts/validate-test-vectors.swift
swift test --disable-swift-testing --filter UsabilitySurfaceTests/testGoldenOneHotFoldVectorVerifies
swift test --disable-swift-testing --filter UsabilitySurfaceTests/testGoldenBinaryAdditionFoldVectorVerifies
Scripts/production-gate.sh
```

Result: passed.

## Residual Boundary

Workload parameters remain redundant wrapper metadata. Production acceptance
must continue to pin trusted public inputs, proof kind, shape digest, statement
digest, and verifier-key digest outside the artifact.
