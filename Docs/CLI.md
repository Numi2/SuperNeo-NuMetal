# SuperNeo CLI

The `superneo` executable is a development and product-smoke frontend. It emits
versioned proof artifacts and verifies them through the same Swift library paths
used by tests.

Build it with:

```sh
swift build --product superneo
```

`swift link` is not a SwiftPM command in this repository.

## Current Defaults

- Source decomposition/opening profile: `pay-per-bit-v1`.
- Product proof mode: NumiSealZK, `zkMode = "masked-digit-tensor-v1"`.
- Product public-coin model: explicit QRO challenge.
- Local/dev only: raw `--qro-session-id`, `--qro-public-coin-hex`, and
  `--numiseal-zk-mode none`.

## Basic Fold Proof

```sh
swift run superneo prove \
  --workload one-hot \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-fold.json

swift run superneo verify /tmp/one-hot-fold.json
```

## Terminal Proof

```sh
swift run superneo prove \
  --workload one-hot \
  --kind compressed-terminal \
  --bits 0,0,1,0 \
  --output /tmp/one-hot-terminal.json

swift run superneo verify --require-terminal /tmp/one-hot-terminal.json
```

## Local NumiSealZK Smoke Proof

```sh
swift run superneo prove \
  --seal numiseal \
  --bits 0,1 \
  --qro-session-id local-product-session-v1 \
  --qro-public-coin-hex 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --max-obligations-per-aggregate 32 \
  --output /tmp/numiseal-zk-product.json

swift run superneo verify \
  --qro-session-id local-product-session-v1 \
  --qro-public-coin-hex 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f \
  /tmp/numiseal-zk-product.json
```

## Product-Control Verification

Product-control verification is stricter than local verification. It accepts
NumiSealZK product artifacts, requires signed context/provenance material,
requires a signed issued-QRO pack, and records replay/audit state. Side-channel
certificates are optional for default `correctness-only` contexts and validated
when supplied; stricter trusted contexts may require them.

For typed-required recursive carry, add:

```sh
--recursive-carry-parent parent-numiseal-product.json \
--recursive-carry-parent-provenance parent-provenance.json
```

## Issued QRO Flow

```sh
swift run superneo product-issue-qro \
  --context-id ctx-one-hot-v1 \
  --signing-key-file qro-ed25519-private.b64 \
  --valid-until 2026-12-31T00:00:00Z \
  --bits 0,0,1,0 \
  --qro-session-id issue-one-hot-v1 \
  --output issued-qro.json

swift run superneo prove \
  --seal numiseal \
  --bits 0,0,1,0 \
  --qro-challenge-pack issued-qro.json \
  --trusted-qro-issuer-key-digest 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef \
  --numiseal-execution-policy zk-high-assurance-cpu \
  --output /tmp/one-hot-numiseal-zk.json
```

`--qro-challenge-pack` cannot be combined with raw QRO flags. Signed-QRO product
proving requires the default ZK mode; `--numiseal-zk-mode none` is only for
local/dev non-product experiments.

## Product Ops

```sh
swift run superneo product-status \
  --operator-profile profile.json \
  --context-pack context.json \
  --revocation-feed revocations.json \
  --format json

swift run superneo product-export-audit \
  --operator-profile profile.json \
  --context-pack context.json \
  --revocation-feed revocations.json \
  --output audit-export.json
```

## Artifact Fields

NumiSeal product artifacts carry `artifactVersion = 2`, `proofKind =
"numiseal-zk"`, `sourceDecompositionProfile = "pay-per-bit-v1"`, source fold
envelope bytes, source fold output-claim digests, NumiSeal proof envelope bytes,
QRO metadata, CTCO/QROM evidence metadata, public statement roots, aggregate
digests, and execution-policy metadata. Verification rejects malformed or
mismatched profile, QRO, CTCO, envelope, and statement fields.
