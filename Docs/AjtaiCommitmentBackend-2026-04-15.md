# Ajtai Commitment Backend Boundary - 2026-04-15

This pass turns the existing Ajtai commitment implementation into an explicit
backend boundary for the proving stack.

## Implemented

- `CommitmentScheme` defines setup, commit, opening verification, batch commit,
  and verifier-key digest operations.
- `AjtaiSuperNeoCommitment` implements that interface for the current
  Goldilocks/Phi81 profile.
- Seeded setup derives reproducible prover/verifier keys from caller-provided
  bytes.
- System-random setup derives a high-entropy seed and binds it to the profile ID
  and CCS shape digest before using the deterministic key generator.
- Shape-bound commit, verify, and batch-commit helpers reject key/shape profile
  and column mismatches before touching witness material.
- `AjtaiCommitmentKey` has a profile-tagged binary encoding with magic, version,
  profile ID, parameter descriptor, matrix dimensions, and canonical ring
  elements.
- The wrapper exposes optimized CPU, constant-work CPU, optional Metal
  acceleration, and CPU-redundant Metal checking through `SuperNeoExecutionPolicy`.

## Non-Claims

- `verifyOpening` is a local recomputation check against an explicitly supplied
  message. It is not a zero-knowledge opening protocol.
- The prover and verifier keys are currently the same public Ajtai matrix. The
  `CommitmentKeyPair` split is an API boundary for later backend evolution.
- Only the current profile ID is accepted by the key parser. New parameter
  profiles must use a new profile ID and wire-compatible validation path.

## Validation

Targeted validation:

```sh
swift test --filter CommitmentCoreTests
```

The tests cover seeded setup, digest access, good and bad opening checks,
fail-closed key/shape mismatches, batch/single parity, and key-wire
round-tripping plus profile mutation rejection.
