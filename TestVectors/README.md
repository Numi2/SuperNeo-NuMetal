# SuperNeo Test Vectors

This directory contains checked-in public artifacts for cross-version and
cross-implementation verification.

Machine-readable files:

- `manifest.json`: vector list, byte counts, SHA-256 hashes, expected verifier
  context, and strict verification commands.
- `artifact.schema.json`: JSON Schema for artifact version 1.
- `numiseal-manifest.json`: NumiSeal vector list, byte count, SHA-256 hash,
  expected NumiSeal digests, and strict validation command.
- `numiseal-artifact.schema.json`: JSON Schema for NumiSeal artifact version 1.
- `numiseal-conformance-scope-v1.json`: checked NumiSeal product/carry/ZK
  theorem and conformance-vector promotion scope.
- `numiseal-end-to-end-theorem-scope-v1.json`: checked NumiSeal end-to-end
  theorem scope for the current evidence-parametric product/carry/ZK relation,
  including recursive folding knowledge soundness, typed carry
  producer/consumer composition, and NumiSealZK simulation/privacy under the
  declared public-leakage model.
- `numiseal-zk-mask-distribution-evidence-v1.json`: checked exact
  rejection-sampled field mask distribution evidence for the NumiSealZK mask
  sampler. It pins the v2 expansion domain, 64-bit candidate space, Goldilocks
  acceptance set, rejection count, zero statistical distance after rejection,
  leakage-model binding, and production-promotion boundary.
- `numiseal-typed-carry-conformance-v1.json`: typed carry positive/negative
  conformance descriptor.
- `numiseal-zk-masked-residual-conformance-v1.json`: masked residual ZK
  positive/negative conformance descriptor.
- `constant-time-scope-v1.json`: checked constant-time source/formal scope for
  the first Swift Goldilocks and NumiSealZK Metal regions.
- `constant-time-lowering-evidence-v1.json`: checked Swift/LLVM/Metal
  lowering evidence contract for the constant-time source/formal scope. It
  links to `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json`, which
  pins local Swift SIL/LLVM/assembly, Metal AIR/metallib, runtime
  allocation-review, CPU/GPU observation evidence, and compiler/hardware
  observation lane reports outside the test-vector directory.
- `e2e-proof-metrics-v1.json`: checked proof-envelope byte counts, artifact
  byte counts, generated product-smoke budgets, and benchmark-evidence policy.

Validate the checked-in vectors with:

```sh
swift Scripts/validate-test-vectors.swift
swift run superneo-numiseal-vectors validate
Scripts/validate-numiseal-conformance-scope.py
Scripts/test-numiseal-conformance-scope-validation.py
Scripts/validate-numiseal-zk-mask-distribution-evidence.py
Scripts/test-numiseal-zk-mask-distribution-evidence-validation.py
Scripts/validate-constant-time-scope.py
Scripts/validate-constant-time-lowering-evidence.py
Scripts/generate-constant-time-release-evidence.py --skip-build
Scripts/validate-e2e-proof-metrics.py
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

### `one-hot-vector-terminal-v1.json`

Workload: `one-hot-vector-v1`

Statement:

- the prover knows a committed private vector of 8 field elements,
- each private element is binary, and
- exactly one private element is selected.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `terminal`

The artifact is a complete terminal proof for the same public one-hot statement
as `one-hot-vector-fold-v1.json`. A strict verifier must pass
`--require-terminal` and reject any fold-only artifact in its place.

### `one-hot-vector-compressed-terminal-v1.json`

Workload: `one-hot-vector-v1`

Statement:

- the prover knows a committed private vector of 8 field elements,
- each private element is binary, and
- exactly one private element is selected.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `compressed-terminal`

The artifact is a compressed public terminal proof for the same public one-hot
statement as `one-hot-vector-fold-v1.json`. A strict verifier must pass
`--require-terminal`; verification reconstructs terminal acceptance after
checking the compressed public-input digest, terminal statement digest, and
verifier-key binding.

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

### `binary-addition-u8-terminal-v1.json`

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

Proof kind: `terminal`

The artifact is a complete terminal proof for the binary-addition statement. A
strict verifier must pass `--require-terminal` and reject any fold-only artifact
in its place.

### `numiseal-terminal-single-aggregate-v1.json`

Workload: `numiseal-terminal-single-aggregate-v1`

Statement:

- the prover starts from one deterministic fold output claim,
- the claim is canonicalized as one NumiSeal obligation in lane
  `numiseal-vector-main`,
- the lane has one aggregate,
- the aggregate uses the direct digit-commitment immediate residual CE path, and
- the checked envelope is proof kind `numiseal-terminal`.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `numiseal-terminal`

This artifact is the baseline checked NumiSeal terminal vector. It is generated by
`superneo-numiseal-vectors generate`, which uses SPI-only deterministic CE
randomness for reproducibility. Production NumiSeal proving remains on the
public randomized prover path; the vector tool is not a production proving
interface. Validation regenerates the exact envelope bytes from the checked
parameters, parses the kind `4` envelope, and verifies it through
`NumiSealVerifier`.

### `numiseal-terminal-two-aggregate-v1.json`

Workload: `numiseal-terminal-two-aggregate-v1`

Statement:

- the prover starts from two deterministic fold output claims,
- both claims are canonicalized into lane `numiseal-vector-main`,
- the lane is split into two aggregates under a one-obligation aggregate limit,
- each aggregate uses the direct digit-commitment immediate residual CE path, and
- the checked envelope is proof kind `numiseal-terminal`.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `numiseal-terminal`

This vector exercises deterministic aggregate ordering, contiguous aggregate
indices within one lane, per-aggregate CE randomness, and component-root binding
for multiple lane proofs in one NumiSeal terminal envelope.

### `numiseal-terminal-two-lane-v1.json`

Workload: `numiseal-terminal-two-lane-v1`

Statement:

- the prover starts from two deterministic fold output claims,
- the claims are canonicalized into lanes `numiseal-vector-main` and
  `numiseal-vector-side`,
- each lane contributes one aggregate,
- each aggregate uses the direct digit-commitment immediate residual CE path, and
- the checked envelope is proof kind `numiseal-terminal`.

Profile: `Goldilocks/Phi81(d=54)`

Proof kind: `numiseal-terminal`

This vector exercises multi-lane policy acceptance, lane-summary-root binding,
deterministic lane ordering, and multi-aggregate verification across distinct
lane keys.

## Artifact Schema

All byte arrays are base64 strings. All digests are lowercase hexadecimal
SHA-256 strings. `artifact.schema.json` is the normative machine-readable schema
for artifact version 1. Artifact consumers should reject duplicate JSON object
member names before decoding, because duplicate keys make trust metadata
parser-dependent. The checked-in manifest validator applies this rule to both
`manifest.json` and every manifest-listed artifact before semantic decoding,
and rejects unknown manifest fields before Swift's decoder can ignore them.

| Field | Meaning |
| --- | --- |
| `artifactVersion` | Test-vector schema version. Current value: `1`. |
| `workload` | Workload identifier. Current values: `one-hot-vector-v1` and `binary-addition-v1`. |
| `profile` | Parameter profile name. |
| `proofKind` | `fold`, `terminal`, or `compressed-terminal`. |
| `bitCount` | Number of private bit variables in the workload. |
| `expectedSelectedCount` | Public selected-count constraint. Current value: `1`. |
| `keySeedUTF8` | UTF-8 seed used to regenerate the public Ajtai verifier key. |
| `workloadParameters` | Exact workload metadata. These values are redundant with public inputs and must be checked. |
| `publicInputs` | Original public input field elements before normalization. |
| `commitmentBase64` | Public Ajtai commitment for the normalized witness. |
| `proofEnvelopeBase64` | Versioned proof envelope bytes. |
| `shapeDigestHex` | Digest of the normalized CCS shape. |
| `statementDigestHex` | Digest of the normalized public statement. |
| `verifierKeyDigestHex` | Digest of the Ajtai verifier key. |

NumiSeal vectors use `numiseal-artifact.schema.json` instead of the R1CS
workload artifact schema. The NumiSeal manifest is the trusted expected context:
it records the expected shape, statement, verifier-key, transcript-domain,
public-statement, obligation-root, lane-summary-root, aggregate,
component-root, and proof-transcript digests. Its strict commands target
`superneo verify --require-numiseal` with those trust pins; the vector CLI
remains the deterministic generator/regenerator authority. Both CLIs use the
shared `NumiSealArtifactVerifier` core for public reconstruction, policy,
envelope digest checks, and final verification. `Scripts/validate-numiseal-artifact-schema.py`
keeps the JSON Schema aligned with the shared artifact core's public shape,
`Scripts/test-numiseal-vector-validation.py` mutation-tests manifest trust pins
and strict production commands, and
`Scripts/test-numiseal-superneo-cli-validation.py` covers the production CLI
negative matrix.

For checked-in NumiSeal vectors, treat `numiseal-manifest.json` as the trusted
expected context. The artifact still stores its own seed, public inputs, and
digests so it is self-describing, but production verification must compare those
fields against the manifest or another trusted caller-owned source.

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
`bitCount + 1` binary sum bits. `workloadParameters.publicSum` is required,
must be a canonical unsigned decimal string, and must equal those little-endian
public bits. `workloadParameters.leftBitCount` is required, must be canonical
unsigned decimal, and must equal `bitCount`.

For `one-hot-vector-v1`, `workloadParameters.selectedCount` is required and
must be the canonical string `1`.

The workload-specific reconstruction rules are:

- `one-hot-vector-v1`: construct private bit variables `b_i`, enforce
  `b_i * (b_i - 1) = 0`, and enforce `sum(b_i) = 1`.
- `binary-addition-v1`: construct public sum bits, private left/right bits, and
  private carry bits; enforce booleanity and the bitwise carry equations listed
  in `Docs/CLI.md`.

If any digest changes, treat it as a serialization, transcript, normalization, or
parameter compatibility event and document the cause before updating the vector.
