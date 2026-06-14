# SuperNeo Test Vectors

`TestVectors/` contains checked public fixtures for cross-version and
cross-implementation verification. Treat the proof artifacts and JSON schemas as
machine contracts; archived product evidence manifests are retained for
reference, not as development blockers.

## Core Files

- `manifest.json`: vector list, byte counts, SHA-256 hashes, verifier context,
  and strict verification commands.
- `artifact.schema.json`: version-1 R1CS workload artifact schema.
- `numiseal-product-artifact-v2.schema.json`: QRO-bound NumiSeal product
  artifact schema.
- `numiseal-conformance-scope-v1.json`: product/carry/ZK conformance scope.
- `numiseal-end-to-end-theorem-scope-v1.json`: NumiSeal end-to-end theorem
  scope, including recursive folding knowledge soundness, typed carry
  producer/consumer composition, and NumiSealZK simulation/privacy.
- `numiseal-zk-mask-distribution-evidence-v1.json`: exact rejection-sampled
  field mask distribution evidence.
- `product-crypto-security-dossier-v1.json`: bounded-depth product security
  dossier.
- `product-selected-depth-loss-accounting-v1.json`: selected-depth product
  loss ledger.
- `product-extractor-loss-accounting-v1.json`: extractor loss accounting.
- `product-total-loss-budget-v1.json`: exact total-loss budget contract.
- `product-release-distribution-evidence-v1.json`: release distribution
  evidence.
- `product-qrom-public-coin-accounting-v1.json`: QROM public-coin accounting.
- `product-qrom-transcript-schedule-v1.json`: QROM transcript schedule.
- `product-qrom-sampler-encoding-evidence-v1.json`: QROM sampler/encoding
  evidence.
- `product-qrom-collision-malleability-evidence-v1.json`: QROM
  collision/malleability evidence.
- `product-qrom-transform-preconditions-v1.json`: QROM transform
  preconditions.
- `product-qrom-interactive-reduction-v1.json`: QROM interactive-reduction
  ledger.
- `constant-time-scope-v1.json`: Swift/formal constant-time source scope.
- `constant-time-lowering-evidence-v1.json`: Swift/LLVM/Metal lowering
  evidence pointer.
- `e2e-proof-metrics-v1.json`: proof-envelope and product artifact byte counts.
- `benchmark-coverage-v1.json`: whole-stack benchmark coverage contract.

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
