# Apple M4 Quick Benchmark Report

Generated: 2026-04-12T12:04:52Z

Source commit: `b85102a`

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

## Profile

Command:

```sh
Scripts/run-benchmarks.sh quick
```

Cases:

- `m64-K1-k0-binary`
- `m256-K2-k1-binary`

The quick profile is a smoke baseline. Use the scaling and full profiles before
making architectural performance claims.

## Proof Sizes

| Case | Constraints | Proof bytes | Envelope bytes | Sum-check | PiCCS | PiRLC | PiDEC | Output claims |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `m64-K1-k0-binary` | 64 | 321128 | 321269 | 672 | 10920 | 11352 | 145280 | 152880 |
| `m256-K2-k1-binary` | 256 | 344616 | 344757 | 880 | 32856 | 12248 | 145280 | 153328 |

## Timings

| Benchmark | Time |
| --- | ---: |
| `fold/cpu/m64-K1-k0-binary` | 15 ms |
| `fold/metal/m64-K1-k0-binary` | 19.554 ms |
| `reduceFold/cpu/m64-K1-k0-binary` | 2.415 ms |
| `terminalVerify/cpu/m64-K1-k0-binary` | 17 ms |
| `proofEnvelope/roundTrip/m64-K1-k0-binary` | 18 ms |
| `fold/cpu/m256-K2-k1-binary` | 179 ms |
| `fold/metal/m256-K2-k1-binary` | 165 ms |
| `reduceFold/cpu/m256-K2-k1-binary` | 8.079 ms |
| `terminalVerify/cpu/m256-K2-k1-binary` | 49 ms |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 79 ms |

## Kernel Notes

Small `m64` kernels are dominated by Metal launch overhead. The quick profile is
therefore a correctness and smoke-performance gate, not evidence that Metal is
always faster. The larger scaling snapshot in `Docs/Benchmarking.md` is the
current source for Metal acceleration claims.

Relevant quick-profile kernel timings:

| Benchmark | Time |
| --- | ---: |
| `kernel/fieldMultiply/m64-K1-k0-binary` | 375 ns |
| `kernel/fieldMultiply/metal/m64-K1-k0-binary` | 1.642 ms |
| `kernel/ringMultiply/m64-K1-k0-binary` | 3.625 us |
| `kernel/ringMultiply/metal/m64-K1-k0-binary` | 2.848 ms |
| `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | 123 us |
| `kernel/ajtaiCommit/metal/m64-K1-k0-binary` | 2.487 ms |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 440 us |
| `kernel/transformedEvaluation/metalSparse/m64-K1-k0-binary` | 5.096 ms |
| `kernel/combinedCommitEval/batchWorkspace/metal/m64-K1-k0-binary` | 7.315 ms |

## Reproduction Notes

The source benchmark export lives under `benchmark-results/` in this workspace:

- `benchmark-results/metadata.json`
- `benchmark-results/report.md`
- `benchmark-results/results.json`

Regenerate this report after intentional performance changes. Do not compare
results across Apple Silicon generations without recording hardware, OS, Xcode,
Swift, Metal device, benchmark profile, and environment variables.
