# CLI High-Assurance Execution Policy, 2026-04-13

This pass makes the CLI proof-generation execution policy explicit.

## Finding

- The CLI uses the CPU backend, so it already avoided prover-side Metal work.
- It constructed the prover through `SuperNeoCPUBackend.makeProver(key:)`,
  which used the default optimized secret-arithmetic policy.
- That was deterministic and correct, but weaker than the repository's
  high-assurance posture for generated demo and vector artifacts because the
  CLI did not explicitly request the constant-work CPU prover paths.

## Work Completed

- `SuperNeoCPUBackend.makeProver` and `makeVerifier` now accept an explicit
  `SuperNeoExecutionPolicy` while preserving `.default` as the source-compatible
  default.
- CLI proof generation now constructs its prover with `.highAssurance`.
- Added unit coverage that the CPU backend factories preserve the requested
  execution policy.

## Verification

```sh
swift test --disable-swift-testing --filter UsabilitySurfaceTests/testCPUBackendFactoriesExposeExecutionPolicy
Scripts/production-gate.sh
```

Result: passed.

## Residual Boundary

`.highAssurance` selects the repository's constant-work CPU paths for covered
secret-bearing prover work. It is still not a formal constant-time proof for
Swift, LLVM, the operating system, allocator behavior, or hardware side
channels.
