# Apple M4 Quick Benchmark Report - Scalar, Transcript, and Sumcheck CPU Pass

Generated locally on 2026-04-13 after a protocol-preserving benchmark pass
focused on removing avoidable allocation and repeated arithmetic from CPU hot
paths. The final benchmark metadata file was generated at
`2026-04-12T22:27:30Z`.

## Environment

| Field | Value |
| --- | --- |
| Machine | MacBook Air |
| Chip | Apple M4 |
| CPU cores | 10 |
| Memory | 24 GB |
| OS | Version 26.3 (Build 25D5087f) |
| Xcode | Xcode 26.4 Build version 17E192 |
| Swift | Apple Swift 6.3, target `arm64-apple-macosx26.0` |
| Metal device | Apple M4 |
| Benchmark profile | `quick` |
| Benchmark cases | `m64-K1-k0-binary`, `m256-K2-k1-binary` |
| Source head | `afc1d6d7c2f4aeee7159456f5ddee812a906c5bc` with this pass dirty |

The comparison baseline was captured at the start of this pass from the same
source head before these edits, using the root quick benchmark runner. The final
export was refreshed after the final `swift test --disable-swift-testing` gate
with the same benchmark definitions and a benchmark-only invocation, then
rendered through `Scripts/render-benchmark-report.swift`.

## Scope

- Factored the sum-check equality term into fixed-prefix and Boolean-suffix
  products, avoiding full point construction and repeated `eq(point, alpha)`
  work for every suffix.
- Cached sum-check round sample points once per `CCSQOracle` instead of
  allocating them on every round.
- Expanded multilinear basis weights in place.
- Switched PiDEC verifier recomposition from constant-ring powers to
  `GoldilocksField` scalar powers and direct ring/extension scaling.
- Added a base-field scalar path for `AjtaiCommitment.scaled(by:)` when the
  ring scalar is a constant polynomial.
- Kept random-linear-combination witness accumulation pre-sized and nonoptional.
- Reworked deterministic RNG word extraction to assemble little-endian `UInt64`
  values directly from the SHA-256 counter stream.
- Reworked transcript absorb framing to reserve once and append frames without
  intermediate array concatenation.
- Removed temporary prefix arrays from evaluation-witness public-input checks.
- Skipped zero coefficients, and direct-added one coefficients, in the protocol
  extension-row evaluator.

## Trust Boundaries

This pass did not change cryptographic parameters, challenge coefficient sets,
transcript domain separators, Fiat-Shamir framing, proof serialization, verifier
acceptance criteria, Ajtai key material, shape/statement digest binding, or
CPU/Metal equality requirements.

The deterministic RNG optimization is byte-stream preserving. A new reference
test checks SHA-256 over `seed || littleEndian(counter)`, `nextUInt64`,
`nextChallengeRing`, and transcript domain/seed/payload framing against an
independent implementation that intentionally keeps the old byte-buffer style.

The sum-check changes are algebraic rewrites of the same multilinear equality
polynomial:

- arbitrary fixed-prefix coordinates use
  `1 - x_i - y_i + 2 x_i y_i`;
- Boolean suffix coordinates reduce to `1 - y_i` for bit `0` and `y_i` for
  bit `1`.

## Validation

| Command | Result |
| --- | --- |
| `swift test --disable-swift-testing` | 74 XCTest cases, 0 failures |
| `swift Scripts/validate-test-vectors.swift` | `one-hot-vector-fold-v1.json` and `binary-addition-u8-fold-v1.json` validated |
| `git diff --check` | clean |
| benchmark quick export | wrote `benchmark-results/results.json`, `benchmark-results/metadata.json`, and `benchmark-results/report.md` |

Benchmark correctness gates still executed inside the benchmark bodies: protocol
rows verified reductions or terminal envelopes, and Metal rows compared against
CPU reference output where registered.

## Timing

Rows compare the local clean baseline from the start of this pass with the final
quick export. The table uses the benchmark runner's wall-clock value; p95 notes
are included where the quick profile showed visible outliers.

| Benchmark | Baseline | Final | Change | Note |
| --- | ---: | ---: | ---: | --- |
| `stage/sumcheck/m64-K1-k0-binary` | 834 us | 258 us | 3.23x faster | p95 376 us -> 256 us |
| `stage/piDEC/m64-K1-k0-binary` | 2375 us | 2145 us | 1.11x faster | p95 2324 us -> 2126 us |
| `stage/piRLC/m64-K1-k0-binary` | 976 us | 932 us | 1.05x faster | p95 928 us -> 878 us |
| `stage/piCCSClaims/m64-K1-k0-binary` | 246 us | 275 us | 0.89x | p95 236 us -> 245 us; wall-clock outlier, p95 within 4% |
| `fold/cpu/m64-K1-k0-binary` | 4316 us | 4347 us | 0.99x | p95 4239 us -> 4243 us |
| `fold/cpu/m256-K2-k1-binary` | 43 ms | 38 ms | 1.13x faster | complete fold path |
| `terminalVerify/cpu/m64-K1-k0-binary` | 3305 us | 3047 us | 1.08x faster | terminal verifier path |
| `terminalVerify/cpu/m256-K2-k1-binary` | 13 ms | 13 ms | flat | quick profile reports whole ms |
| `proofEnvelope/roundTrip/m64-K1-k0-binary` | 6716 us | 7334 us | 0.92x | p95 6672 us -> 7062 us; below full-protocol failure threshold |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 17 ms | 16 ms | 1.06x faster | envelope path |
| `kernel/ringScalarMultiply/cpu/m64-K1-k0-binary` | 458 ns | 250 ns | 1.83x faster | scalar ring kernel |
| `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | 99 us | 65 us | 1.52x faster | single commitment |
| `kernel/ajtaiCommit/batch/cpu/m64-K1-k0-binary` | 1565 us | 925 us | 1.69x faster | batch commitment |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 31 us | 29 us | 1.07x faster | sparse transformed evaluation |

## Caveats

The quick profile is a smoke-performance gate. During this pass, repeated local
runs showed scheduler and thermal variance on unrelated rows, especially after
the full XCTest gate. Treat the stable signal as:

- strong CPU sum-check improvement;
- direct scalar and Ajtai kernel improvements;
- PiDEC and terminal verifier improvements in the final quick export;
- no cryptographic or serialization relaxation.

Do not promote this single quick run into a release-wide performance claim
without a fresh full or scaling profile on an idle pinned machine.
