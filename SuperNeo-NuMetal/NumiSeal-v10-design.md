# NumiSeal Design Note

This packaged resource is intentionally compact. Historical design prose was
removed because it described obsolete non-QRO and non-product paths.

Current product path:

- product artifact version: `NumiSealProductArtifact.artifactVersion = 2`
- product proof kind: `numiseal-zk`
- ZK mode: `masked-digit-tensor-v1`
- source decomposition/opening profile: `pay-per-bit-v1`
- public coin: explicit `SuperNeoQROChallenge`
- product-control public coin: signed `SuperNeoSignedQROChallengePack`
- verifier-critical binding: CTCO/QROM metadata, 384-bit H_bind roots, and
  proof-envelope context binding

Local/dev diagnostics may still exercise non-ZK NumiSeal paths, but
product-control verification accepts only the QRO-bound NumiSealZK product
artifact path.
