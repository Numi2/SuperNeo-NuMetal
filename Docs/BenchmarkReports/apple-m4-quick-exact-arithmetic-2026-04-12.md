# Apple M4 Exact-Arithmetic Quick Benchmark Report

Generated: 2026-04-12T16:15:18Z

Source state: local working tree after Goldilocks and cyclotomic-ring arithmetic
changes. Commit at measurement time: `9137a21`.

## Hardware And Toolchain

| Field | Value |
| --- | --- |
| Model | MacBook Air |
| Chip | Apple M4 |
| CPU cores | 10 |
| Memory | 24 GB |
| Metal device | Apple M4 |
| Metal support | available |
| OS | macOS 26.3, build 25D5087f |
| Swift | Apple Swift 6.3, target arm64-apple-macosx26.0 |
| Xcode | Xcode 26.4, build 17E192 |

## Scope

This pass optimizes exact arithmetic only:

- Goldilocks field reduction now folds the 128-bit product high word using
  `2^64 == 2^32 - 1 mod p`.
- Field add/sub/mul operators return canonical raw values directly when the
  implementation has already proven canonicality.
- Goldilocks extension-field multiplication uses the three-multiply Karatsuba
  identity, and row-evaluation hot paths scale extension values by base-field
  coefficients directly instead of promoting each scalar into a full extension
  element.
- `CyclotomicRing54` multiplication and base-ring-by-extension-ring
  multiplication accumulate directly into reduced degree-54 output coefficients
  using `X^54 = -X^27 - 1`; the extension-ring path scales components
  directly when the left operand comes from the base ring.
- Fixed-degree ring add/sub/scale paths use direct loops and unchecked
  fixed-length construction after coefficient-wise operations have already
  produced canonical coefficients.

No proof-system parameters, verifier checks, transcript domain, proof-envelope
binding, serialization format, Ajtai key material, Metal trust boundary, or
CPU/Metal equality gate changed.

## Validation

Correctness and trust gates run for this pass:

- `swift test`: 69 XCTest cases, 0 failures.
- `Scripts/run-benchmarks.sh quick`: 69 XCTest cases, 0 failures, then quick
  benchmark export under `benchmark-results/`.
- `swift Scripts/validate-test-vectors.swift`: both bundled proof vectors
  validated.
- Additional local equivalence checks: two million seeded Goldilocks products
  against the previous reducer; five million seeded additions against the
  previous add path; two million seeded extension-field products against the
  previous four-multiply formula; explicit boundary-value fixtures now
  committed in the XCTest suite.
- Benchmark correctness gates retained CPU/Metal output comparisons where both
  paths exist.

## Profile

Benchmark command:

```sh
Scripts/run-benchmarks.sh quick
```

Cases:

- `m64-K1-k0-binary`
- `m256-K2-k1-binary`

The quick profile remains a smoke-performance gate. Use the scaling and full
profiles before updating architectural acceleration claims.

## Proof Sizes

| Case | Constraints | Proof bytes | Envelope bytes | Sum-check | PiCCS | PiRLC | PiDEC | Output claims |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K1-k0-binary` | 64 | 321128 | 321269 | 672 | 10920 | 11352 | 145280 | 152880 |
| `m256-K2-k1-binary` | 256 | 344616 | 344757 | 880 | 32856 | 12248 | 145280 | 153328 |

## Timings

| Benchmark | Previous local quick | Exact-arithmetic quick | Change |
| --- | ---: | ---: | ---: |
| `fold/cpu/m64-K1-k0-binary` | 47 ms | 5.27 ms | 8.91x faster |
| `fold/metal/m64-K1-k0-binary` | 26 ms | 12.5 ms | 2.08x faster |
| `reduceFold/cpu/m64-K1-k0-binary` | 5.55 ms | 1.01 ms | 5.50x faster |
| `terminalVerify/cpu/m64-K1-k0-binary` | 47 ms | 5.19 ms | 9.06x faster |
| `proofEnvelope/roundTrip/m64-K1-k0-binary` | 64 ms | 8.94 ms | 7.16x faster |
| `fold/cpu/m256-K2-k1-binary` | 366 ms | 41 ms | 8.93x faster |
| `fold/metal/m256-K2-k1-binary` | 245 ms | 60 ms | 4.08x faster |
| `reduceFold/cpu/m256-K2-k1-binary` | 11 ms | 3.00 ms | 3.67x faster |
| `terminalVerify/cpu/m256-K2-k1-binary` | 205 ms | 20 ms | 10.25x faster |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 179 ms | 24 ms | 7.46x faster |

## Protocol Stage Notes

| Benchmark | Previous local quick | Exact-arithmetic quick | Change |
| --- | ---: | ---: | ---: |
| `stage/piCCSClaims/m64-K1-k0-binary` | 5.08 ms | 1.34 ms | 3.79x faster |
| `stage/piDEC/m64-K1-k0-binary` | 36 ms | 3.35 ms | 10.75x faster |

## Kernel Notes

| Benchmark | Previous local quick | Exact-arithmetic quick | Change |
| --- | ---: | ---: | ---: |
| `kernel/fieldMultiply/m64-K1-k0-binary` | 375 ns | 375 ns | unchanged |
| `kernel/ringMultiply/m64-K1-k0-binary` | 14 us | 4.00 us | 3.50x faster |
| `kernel/ringScalarMultiply/cpu/m64-K1-k0-binary` | 625 ns | 417 ns | 1.50x faster |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 583 us | 40 us | 14.58x faster |
| `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | 88 us | 63 us | 1.40x faster |

The broad protocol wins come from exact field reduction, Karatsuba extension
multiplication, direct base-scalar extension scaling, and direct reduced ring
accumulation. The quick-profile nanosecond field-multiply row is noisy enough
to report as unchanged in this canonical run; the end-to-end fold, reduction,
terminal verification, proof-envelope, PiDEC, Ajtai CPU, ring-scalar, and
transformed-evaluation rows improved while the verification and vector gates
stayed intact.

## Reproduction Notes

The source benchmark export for this run was rendered under:

- `benchmark-results/metadata.json`
- `benchmark-results/report.md`
- `benchmark-results/results.json`

Do not compare this run across Apple Silicon generations without recording
hardware, OS, Xcode, Swift, Metal device, benchmark profile, source state, and
environment variables. This report intentionally keeps the previous quick rows
as local before/after context; it does not replace scaling-profile baselines.
