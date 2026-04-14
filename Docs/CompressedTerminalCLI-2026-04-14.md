# Compressed Terminal CLI Exposure - 2026-04-14

## Finding

The protocol layer already had first-class compressed public terminal envelopes:
`SuperNeoProver.compressedTerminalFoldEnvelope` emits
`ProofEnvelopeKind.compressedPublic`, and
`SuperNeoVerifier.verifyCompressedTerminalFoldEnvelope` checks the compressed
statement context, public-input digest, verifier-key digest, terminal statement
digest, and reconstructed terminal CE proof. The CLI artifact surface still only
accepted `fold` and `terminal`, so users could not produce or strictly verify
the compressed terminal path from the public demo tool even though the docs and
benchmarks described it.

## Work

- Added canonical CLI proof kind `compressed-terminal`.
- Mapped `compressed-terminal` artifacts to envelope kind `compressedPublic`
  (`3`) and the existing compressed terminal prover/verifier APIs.
- Treated `compressed-terminal` as satisfying `--require-terminal`; fold
  reductions continue to fail that policy gate.
- Updated the public artifact schema and vector validator so future compressed
  test vectors can be validated without ad hoc tooling.
- Added a release production-gate smoke for one-hot compressed-terminal
  prove/verify under trusted expected verifier context.

## Boundary

This change exposes an already implemented proof system path. It does not
change the compressed terminal wire format, transcript domains, public-input
digest construction, or CE opening verification logic.

This slice originally closed the public CLI exposure gap and hardened
schema/tooling support. A follow-up on 2026-04-14 added
`TestVectors/one-hot-vector-compressed-terminal-v1.json`; see
`Docs/CompressedTerminalVector-2026-04-14.md`.

## Validation

Validation run for this slice:

- `swift build`
- `swift build -c release`
- `Scripts/validate-artifact-schema.py`
- `Scripts/test-artifact-schema-validation.py`
- `swift Scripts/validate-test-vectors.swift`
- release CLI one-hot `--kind compressed-terminal` prove/verify with
  `--require-terminal`
- `git diff --check`
- `Scripts/production-gate.sh --skip-formal`

The release CLI smoke produced a one-hot compressed-terminal envelope of
3,343,691 bytes in 1.143 s and verified it under trusted context in 0.459 s.
The skip-formal production gate also passed with its compressed-terminal smoke
enabled.
