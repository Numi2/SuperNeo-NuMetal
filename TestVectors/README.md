# SuperNeo Test Vectors

This directory contains checked-in public artifacts for cross-version and
cross-implementation verification.

Machine-readable files:

- `manifest.json`: vector list, byte counts, SHA-256 hashes, expected verifier
  context, and strict verification commands.
- `artifact.schema.json`: JSON Schema for artifact version 1.

Validate the checked-in vectors with:

```sh
swift Scripts/validate-test-vectors.swift
```

## Vectors

### `one-hot-vector-fold-v1.json`

Workload: `one-hot-vector-v1`

Statement:

- the prover knows a committed private vector of 8 field elements,
- each private element is binary, and
- exactly one private element is selected.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `fold`

The artifact is a fold-reduction vector, not a terminal proof. A verifier should
accept the fold reduction and return 14 output CE claims requiring terminal CE
verification.

### `binary-addition-u8-fold-v1.json`

Workload: `binary-addition-v1`

Statement:

- the prover knows two committed private 8-bit integers,
- every operand bit is binary,
- every carry bit is binary,
- the public little-endian sum bits encode `42`, and
- the private operands satisfy `left + right = 42`.

The checked-in witness used to generate the vector is `13 + 29 = 42`, but the
artifact does not reveal the private operands. The public input is the constant
one followed by 9 little-endian sum bits.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `fold`

The artifact is a fold-reduction vector, not a terminal proof. A verifier should
accept the fold reduction and return 14 output CE claims requiring terminal CE
verification.

## Artifact Schema

All byte arrays are base64 strings. All digests are lowercase hexadecimal
SHA-256 strings. `artifact.schema.json` is the normative machine-readable schema
for artifact version 1.

| Field | Meaning |
| --- | --- |
| `artifactVersion` | Test-vector schema version. Current value: `1`. |
| `workload` | Workload identifier. Current values: `one-hot-vector-v1` and `binary-addition-v1`. |
| `profile` | Parameter profile name. |
| `proofKind` | `fold` or `terminal`. |
| `bitCount` | Number of private bit variables in the workload. |
| `expectedSelectedCount` | Public selected-count constraint. Current value: `1`. |
| `keySeedUTF8` | UTF-8 seed used to regenerate the public Ajtai verifier key. |
| `workloadParameters` | Workload metadata such as public sum. These values are redundant with public inputs and must be checked when present. |
| `publicInputs` | Original public input field elements before normalization. |
| `commitmentBase64` | Public Ajtai commitment for the normalized witness. |
| `proofEnvelopeBase64` | Versioned proof envelope bytes. |
| `shapeDigestHex` | Digest of the normalized CCS shape. |
| `statementDigestHex` | Digest of the normalized public statement. |
| `verifierKeyDigestHex` | Digest of the Ajtai verifier key. |

For checked-in vectors, treat `manifest.json` as the trusted expected context.
The artifact still stores its own seed, public inputs, and digests so it is
self-describing, but production verification must compare those fields against
the manifest or another trusted caller-owned source.

External implementations should:

1. Read `workload`.
2. Rebuild the corresponding R1CS workload.
3. Normalize it to the SuperNeo paper-normalized CCS shape.
4. Check `shapeDigestHex` against the trusted expected shape digest.
5. Decode `commitmentBase64` as an Ajtai commitment.
6. Rebuild the public statement and check `statementDigestHex` against the
   trusted expected statement digest.
7. Regenerate the Ajtai key from the trusted expected `keySeedUTF8` and check
   `verifierKeyDigestHex` against the trusted expected verifier-key digest.
8. Decode and verify `proofEnvelopeBase64` according to `Docs/ProofEnvelope.md`.

For `binary-addition-v1`, `publicInputs` must be the constant one followed by
`bitCount + 1` binary sum bits. If `workloadParameters.publicSum` is present,
it must equal those little-endian public bits.

The workload-specific reconstruction rules are:

- `one-hot-vector-v1`: construct private bit variables `b_i`, enforce
  `b_i * (b_i - 1) = 0`, and enforce `sum(b_i) = 1`.
- `binary-addition-v1`: construct public sum bits, private left/right bits, and
  private carry bits; enforce booleanity and the bitwise carry equations listed
  in `Docs/CLI.md`.

If any digest changes, treat it as a serialization, transcript, normalization, or
parameter compatibility event and document the cause before updating the vector.
