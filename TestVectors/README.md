# SuperNeo Test Vectors

`TestVectors/` contains checked public proof fixtures for cross-version and
cross-implementation verification. Treat the proof artifacts and JSON schemas as
machine contracts. Archived product, conformance, benchmark, and release
evidence manifests live under `TestVectors/Archive/compliance/` for reference
only.

## Core Files

- `manifest.json`: vector list, byte counts, SHA-256 hashes, verifier context,
  and strict verification commands.
- `artifact.schema.json`: version-1 R1CS workload artifact schema.
- `numiseal-product-artifact-v2.schema.json`: QRO-bound NumiSeal product
  artifact schema.
- `product-carry-chain-root-v1.json`: canonical byte-layout vector for product
  recursive carry-chain roots.
- `one-hot-vector-*.json`: fold, terminal, and compressed-terminal one-hot
  proof artifacts.
- `binary-addition-u8-*.json`: fold and terminal binary-addition proof
  artifacts.
- `Archive/compliance/`: old evidence manifests retained outside the active
  proof-vector set.

## Active Verification Rules

- Reject duplicate JSON object keys before semantic decoding.
- Reject unknown manifest fields before Swift decoding can ignore them.
- Rebuild trusted shapes, statements, verifier keys, and public inputs instead
  of trusting artifact metadata alone.
- Product NumiSeal artifacts verify through
  `NumiSealProductVerifier.verify(..., qroChallenge:)`.
- Product verification requires caller-supplied `SuperNeoQROChallenge` public
  coins.
- Source-fold vectors now use adaptive `pay-per-bit-v1` decomposition/output
  accounting. Do not assume a fixed 14 output CE claim count.
- Fold artifacts are reductions, not terminal acceptance proofs.
- Terminal and compressed-terminal artifacts must be verified under terminal
  acceptance policy.

## Workload Vectors

`one-hot-vector-v1` proves knowledge of a committed private vector of 8 field
elements where every element is binary and exactly one element is selected.

`binary-addition-v1` proves knowledge of two committed private 8-bit integers
whose public little-endian sum bits encode `42`. The checked witness used to
generate the vector is `13 + 29 = 42`, but the artifact does not reveal the
private operands.

For fold vectors, the verifier returns the artifact-recorded adaptive CE
obligations for terminal verification. For terminal vectors, a strict verifier
must require terminal acceptance and reject fold-only artifacts in their place.

## Active Validation

Regenerate the active proof vectors into a temporary directory and verify them:

```sh
Scripts/regenerate-test-vectors.sh
```

Compare regenerated proof-vector bytes against the checked fixtures when
investigating serialization or transcript drift:

```sh
Scripts/regenerate-test-vectors.sh --check
swift Scripts/parse-test-vectors.swift
Scripts/fuzz-malformed-artifacts.sh
```

If any digest changes, treat it as a serialization, transcript, normalization,
or parameter compatibility event and document the cause before updating the
vector.
