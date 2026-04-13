# Production Readiness Pass, 2026-04-13

This pass addressed the review findings from the 2026-04-13 production-readiness
audit. The goal was to turn demo-oriented behavior into explicit production
guardrails without weakening transcript, shape, verifier-key, or GPU/CPU trust
boundaries.

## Findings Addressed

### CLI verifier context

The `superneo verify` short form remains available for local demos, but it is
documented as a self-consistency check. Production callers can now pass trusted
context explicitly:

- `--key-seed`
- `--expected-verifier-key-digest`
- `--expected-shape-digest`
- `--expected-statement-digest`
- `--expected-public-inputs`
- `--require-terminal`

The verifier rejects artifacts whose regenerated key, reconstructed shape,
statement, public inputs, or proof kind do not match those pinned values.

Checked-in vector validation now treats `TestVectors/manifest.json` as the
trusted expected context. The manifest records expected public inputs, key seed,
shape digest, statement digest, verifier-key digest, and strict verification
commands. `Scripts/validate-test-vectors.swift` verifies the artifact against
those manifest values and then invokes the CLI with strict arguments.

### Metal allocation and dispatch sizing

Metal buffer byte lengths now use checked multiplication before allocation.
Backend batch, output, row-block, and dispatch counts are computed through
checked integer helpers so oversized dimensions return `SuperNeoError` rather
than trapping on `Int` overflow.

`SparseRingMatrixCSR` also checks `rows + 1` with overflow reporting before
validating row-offset count. The regression test covers the `Int.max` row-count
case.

### Production gate release coverage

`Scripts/production-gate.sh` now runs:

- `swift build -c release`
- `swift test --disable-swift-testing`
- `swift test -c release --disable-swift-testing`
- `swift Scripts/validate-test-vectors.swift`
- release binary CLI prove/verify smoke for one-hot and binary-addition
- negative strict-verifier checks for public-input mismatch and terminal-proof
  requirement mismatch

`.github/workflows/production-gate.yml` runs the same gate on pull requests,
`main`, and manual dispatch.

## Verification

Final local command:

```sh
Scripts/production-gate.sh --with-benchmarks
```

Result: passed.

The command covered release build, debug XCTest, release XCTest, strict vector
validation, release CLI smoke tests, negative strict-verifier checks, and the
quick benchmark profile.

## Residual Boundaries

- Fold reductions still are not terminal application proofs. Callers that need
  the complete terminal relation must require `--require-terminal` and verify a
  terminal proof artifact.
- The CLI remains an integration surface, not a wallet, server, or policy
  engine. Production embedding code should own expected context, persistence,
  replay policy, and user-facing error handling outside the proof artifact.
- Metal remains an acceleration path. Trust continues to come from CPU
  verification, transcript binding, and differential coverage rather than GPU
  execution alone.
- Hardware-class performance claims remain limited to the currently documented
  Apple M4 reports until additional hardware reports are pinned.
