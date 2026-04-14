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
- `Scripts/test-vector-manifest-validation.py`
- release binary CLI fold prove/verify smoke for one-hot and binary-addition
- release binary CLI terminal prove/verify smoke for one-hot and
  binary-addition with `--require-terminal`
- negative strict-verifier checks for public-input mismatch and terminal-proof
  requirement mismatch
- negative artifact-ingestion checks for unknown fields, duplicate JSON keys,
  missing workload parameters, non-canonical workload parameters, and workload
  parameter/public-input mismatches
- vector-corpus mutation checks for duplicate manifest entries, duplicate raw
  manifest and artifact JSON keys, unknown manifest keys, duplicate strict
  verify commands, missing proof-kind coverage, and unmanifested checked vector
  files
- benchmark tooling mutation checks for comparator thresholds, missing and
  duplicate timing rows, unsupported units, malformed result JSON, and Markdown
  report rendering
- lattice-estimator dry-run parameter derivation and artifact validation for
  the implemented `Goldilocks/Phi81(d=54)` Module-SIS tuple

`.github/workflows/production-gate.yml` runs the same gate on pull requests,
`main`, and manual dispatch.

### High-assurance execution policy

The public API now exposes explicit execution policies:

- `.highAssurance` uses constant-work CPU commitment/evaluation primitives for
  covered secret-bearing normalization and prover paths, including transformed
  sparse ring matrix-vector multiplication, and avoids prover-side Metal work.
- `.cpuRedundantMetal` keeps Metal enabled but requires CPU equality for covered
  Metal commitment and transformed-evaluation outputs before use.

This does not claim formal constant-time behavior or malicious-host resistance.
It gives callers a concrete opt-in mode instead of relying on documentation-only
guidance.

### Lattice-estimator reproduction

`Scripts/reproduce-lattice-estimator.sh` derives the exact Appendix D.8 GL
Module-SIS inputs and can run the pinned upstream lattice-estimator through
SageMath. It also has a latest-upstream monitoring lane for drift reporting, but
that lane is not canonical docs-facing evidence. `Scripts/validate-lattice-estimator-artifact.py`
checks the pinned source, exact profile constants, derived SIS tuple,
strong-sampling inequality, normalized estimator rows, lane-specific threshold
semantics, and estimator status. Dry-run generation and validation are part of
the production gate; full estimator execution is intentionally separate because
it requires Sage.

## Verification

Final local command:

```sh
Scripts/production-gate.sh --with-benchmarks
```

Result: passed.

The command covered release build, debug XCTest, release XCTest, strict vector
validation including the compressed-terminal vector, release CLI fold,
terminal, and compressed-terminal smoke tests, negative strict-verifier checks,
compressed-terminal proof-kind mismatch checks, vector manifest mutation tests,
and the quick benchmark profile.

## Residual Boundaries

- Fold reductions still are not terminal application proofs. The production
  gate now includes positive terminal proof smoke checks for both bundled
  workloads and a compressed-terminal smoke check for one-hot; callers that need
  the complete terminal relation must still require `--require-terminal` and
  verify a terminal or compressed-terminal proof artifact.
- The CLI remains an integration surface, not a wallet, server, or policy
  engine. Production embedding code should own expected context, persistence,
  replay policy, and user-facing error handling outside the proof artifact.
- Metal remains an acceleration path. Use `.cpuRedundantMetal` or
  `.highAssurance` when GPU output must be treated as untrusted.
- Hardware-class performance claims remain limited to the currently documented
  Apple M4 reports until additional hardware reports are pinned.
