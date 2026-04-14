# Compressed Terminal Vector - 2026-04-14

## Finding

After `compressed-terminal` became a public CLI artifact kind, the repository
still had no checked-in compressed public terminal proof vector. That left the
compressed envelope path covered by protocol tests and release smoke checks, but
not by the cross-version manifest and public artifact corpus.

## Work

- Generated `TestVectors/one-hot-vector-compressed-terminal-v1.json` with:
  - workload `one-hot-vector-v1`,
  - proof kind `compressed-terminal`,
  - envelope kind raw byte `3`,
  - key seed `SuperNeoCLI.one-hot-vector.v1`,
  - public input `[1]`,
  - shape digest
    `84d903373ff54785a9b7d99bd048e1527deedd1173309c272992a8a87b61a765`,
  - statement digest
    `786532c3daee5d41f54b619bde8b6bcc432f7ae1f40017e14953cc8ce38992e0`,
  - verifier-key digest
    `7e6c4fc3ec5bee0e1872cde17322830a37fc0a2d17ed79a208f6113fd0186a86`.
- Added the vector to `TestVectors/manifest.json` with byte count `4513526`
  and SHA-256
  `775aa6047717d54d3cb848a79660622fae801b52837e209937cdf99b77edf82f`.
- Added golden XCTest coverage that verifies the vector through
  `verifyCompressedTerminalFoldEnvelope`.
- Hardened the vector validator to reject duplicate manifest entries,
  duplicate raw manifest JSON keys, duplicate strict verification commands,
  unknown manifest keys, unmanifested checked vector files, duplicate nested
  artifact JSON keys, and removal of the required one-hot compressed-terminal
  coverage row.
- Added `Scripts/test-vector-manifest-validation.py` to mutation-test those
  fail-closed manifest rules without running CLI verification for each mutated
  case.
- Extended the production gate to mutate a generated compressed-terminal
  artifact's JSON `proofKind` to `terminal` and `fold`, requiring both variants
  to fail under trusted `--require-terminal` verification because the envelope
  header still carries kind `compressedPublic`.
- Updated the paper-reproduction harness so quick/scaling/full artifacts verify
  and inspect the compressed-terminal vector.

## Boundary

This is a compatibility and regression artifact. It does not add a new proof
claim beyond the existing compressed public terminal envelope semantics: the
verifier still must supply trusted context and use `--require-terminal` when
terminal acceptance is required.

## Validation

- `.build/release/superneo prove --kind compressed-terminal ...`
- `.build/release/superneo inspect TestVectors/one-hot-vector-compressed-terminal-v1.json`
- `.build/release/superneo verify --require-terminal ... TestVectors/one-hot-vector-compressed-terminal-v1.json`
- `python3 -m json.tool TestVectors/one-hot-vector-compressed-terminal-v1.json`
- `Scripts/test-vector-manifest-validation.py`
- `Scripts/production-gate.sh --skip-formal`

The generated artifact contains 3,343,691 envelope bytes and verified under
trusted one-hot context in 0.441 s with the release CLI.
