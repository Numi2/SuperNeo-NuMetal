# NumiSeal CLI Exposure, 2026-04-16

`superneo prove --seal numiseal` is the supported CLI path for QRO-bound
NumiSeal product artifacts. It uses `NumiSealProductAPI.provePreparedR1CS` and
emits `NumiSealProductArtifact.artifactVersion = 2`.

Current defaults:

- `proofKind = "numiseal-zk"`
- `zkMode = "masked-digit-tensor-v1"`
- `sourceDecompositionProfile = "pay-per-bit-v1"`

`--numiseal-zk-mode none` is reserved for local/dev non-product diagnostics and
is not accepted by product-control verification.

Product-control verification uses `--product`, signed context/provenance,
signed issued-QRO, replay/audit state, and optional side-channel certificate
validation. Raw QRO flags are local/dev only.
