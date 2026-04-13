# Apple M4 Prepared-Context Quick Profile, 2026-04-13

This report records the first benchmark pass after adding an explicit prepared
fold context for repeated proofs. The prepared rows keep the existing
cryptographic checks in the proof call while moving transformed sparse CCS
compilation and Metal workspace construction into benchmark setup.

## Environment

- Command: `Scripts/run-benchmarks.sh quick`
- Generated: `2026-04-13T10:59:42Z`
- Hardware: MacBook Air, Apple M4, 10 CPU cores, 24 GB memory
- OS: Version 26.5 (Build 25F5042g)
- Xcode: 26.4 (17E192)
- Swift: 6.3
- Metal device: Apple M4
- Source: `36cc44a`, dirty worktree with the prepared-context benchmark changes
- Benchmark cases: `m64-K1-k0-binary`, `m256-K2-k1-binary`

## Fold Rows

| Case | Cold CPU | Prepared CPU | CPU change | Cold Metal | Prepared Metal | Metal change |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K1-k0-binary` | 4.48 ms | 4.22 ms | 1.06x faster | 19.0 ms | 14.4 ms | 1.32x faster |
| `m256-K2-k1-binary` | 38 ms | 38 ms | unchanged | 87 ms | 74 ms | 1.18x faster |

## Stage Rows

The prepared stage rows retain per-call context validation and run on the small
`m64` quick fixture, so these rows are primarily lifetime visibility checks
rather than stable optimization claims.

| Stage | Cold | Prepared | Change |
| --- | ---: | ---: | ---: |
| `sumcheck` | 268 us | 312 us | 0.86x |
| `piCCSClaims` | 264 us | 307 us | 0.86x |
| `piRLC` | 1.01 ms | 964 us | 1.05x faster |
| `piDEC` | 2.39 ms | 2.51 ms | 0.95x |

## Findings

- The prepared-context path is most visible on Metal full-fold rows, where
  avoiding per-iteration workspace construction improved the quick profile by
  1.18x to 1.32x while still comparing prepared Metal proofs to the CPU
  reference proof.
- CPU quick rows are dominated by protocol arithmetic after the previous sparse
  and exact-arithmetic passes. The small `m64` row benefits modestly; the
  `m256` row is unchanged at this profile's resolution.
- The benchmark suite now reports both cold API rows and prepared steady-state
  rows. This avoids a hidden global cache and makes compiled-shape/workspace
  lifetime explicit in benchmark setup.
- Prepared fold context reuse is guarded by profile ID, shape digest, exact
  compiled shape, verifier-key digest, execution policy, Metal workspace
  availability, Metal execution-context identity, workspace key, transformed
  matrix count, and transformed matrix digest.

## Validation

- `swift test --disable-swift-testing`: 80 tests, 0 failures.
- `Scripts/run-benchmarks.sh quick`: passed its XCTest preflight with 80 tests,
  then generated fresh `benchmark-results/results.json`,
  `benchmark-results/metadata.json`, and `benchmark-results/report.md`.
- New targeted coverage:
  `ProtocolSmokeTests.testPreparedFoldContextMatchesStandardFoldAndRejectsWrongKey`
  and
  `MetalDifferentialTests.testTier0PreparedMetalFoldContextMatchesCPUOracle`.

## Remaining Work

- Run the prepared rows on the `scaling` profile before making large-case
  conclusions. The quick profile is useful for correctness and artifact
  coverage, but large cases will separate setup lifetime from prover arithmetic
  more clearly.
- Keep the prepared context in the benchmarking SPI until there is enough
  external API evidence to promote a stable public interface.
