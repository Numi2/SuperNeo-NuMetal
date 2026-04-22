# SuperNeo Benchmark Comparison

- Baseline: `/tmp/superneo-bench-direct.dDuhnF/Current_run.json`
- Candidate: `/tmp/superneo-bench-after.i8m9R0/Current_run.json`
- Baseline metadata: `/tmp/superneo-bench-direct.dDuhnF/metadata.json`
- Candidate metadata: `/tmp/superneo-bench-after.i8m9R0/metadata.json`
- Metadata comparison: PASS
- Clean metadata required: no
- Kernel threshold: 5.0%
- Protocol threshold: 10.0%
- Missing baseline rows: failure
- Mode: warn only
- Result: WARN

## Timing Rows

| Benchmark | Class | Baseline | Candidate | Change | Threshold | Status |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `fold/cpu/m256-K2-k1-binary` | protocol | 56 ms | 59 ms | 1.05x slower | 10.0% | within threshold |
| `fold/cpu/m64-K1-k0-binary` | protocol | 14 ms | 14 ms | unchanged | 10.0% | unchanged |
| `fold/metal/m256-K2-k1-binary` | protocol | 88 ms | 152 ms | 1.73x slower | 10.0% | FAIL |
| `fold/metal/m64-K1-k0-binary` | protocol | 17 ms | 36 ms | 2.12x slower | 10.0% | FAIL |
| `fold/prepared/cpu/m256-K2-k1-binary` | protocol | 56 ms | 58 ms | 1.04x slower | 10.0% | within threshold |
| `fold/prepared/cpu/m64-K1-k0-binary` | protocol | 13 ms | 14 ms | 1.08x slower | 10.0% | within threshold |
| `fold/prepared/metal/m256-K2-k1-binary` | protocol | 89 ms | 144 ms | 1.62x slower | 10.0% | FAIL |
| `fold/prepared/metal/m64-K1-k0-binary` | protocol | 16 ms | 39 ms | 2.44x slower | 10.0% | FAIL |
| `kernel/ajtaiCommit/batch/cpu/m64-K1-k0-binary` | kernel | 670 us | 865 us | 1.29x slower | 5.0% | FAIL |
| `kernel/ajtaiCommit/batch/metal/m64-K1-k0-binary` | kernel | 1.68 ms | 2.26 ms | 1.35x slower | 5.0% | FAIL |
| `kernel/ajtaiCommit/batchWorkspace/metal/m64-K1-k0-binary` | kernel | 1.08 ms | 3.47 ms | 3.21x slower | 5.0% | FAIL |
| `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | kernel | 47 us | 47 us | unchanged | 5.0% | unchanged |
| `kernel/ajtaiCommit/metal/m64-K1-k0-binary` | kernel | 875 us | 2.25 ms | 2.58x slower | 5.0% | FAIL |
| `kernel/ajtaiCommit/workProfile/m64-K1-k0-binary` | kernel | 2.08 us | 2.21 us | 1.06x slower | 5.0% | FAIL |
| `kernel/combinedCommitEval/batchWorkspace/metal/m64-K1-k0-binary` | kernel | 7.81 ms | 5.05 ms | 1.55x faster | 5.0% | faster |
| `kernel/fieldMultiply/m64-K1-k0-binary` | kernel | 375 ns | 500 ns | 1.33x slower | 5.0% | FAIL |
| `kernel/fieldMultiply/metal/m64-K1-k0-binary` | kernel | 1.71 ms | 1.44 ms | 1.19x faster | 5.0% | faster |
| `kernel/multilinearEvaluation/m64-K1-k0-binary` | kernel | 1.46 us | 1.71 us | 1.17x slower | 5.0% | FAIL |
| `kernel/ringMultiply/m64-K1-k0-binary` | kernel | 2.62 us | 2.54 us | 1.03x faster | 5.0% | faster |
| `kernel/ringMultiply/metal/m64-K1-k0-binary` | kernel | 1.65 ms | 1.72 ms | 1.04x slower | 5.0% | within threshold |
| `kernel/ringScalarMultiply/cpu/m64-K1-k0-binary` | kernel | 416 ns | 375 ns | 1.11x faster | 5.0% | faster |
| `kernel/ringScalarMultiply/metal/m64-K1-k0-binary` | kernel | 1.68 ms | 2.49 ms | 1.49x slower | 5.0% | FAIL |
| `kernel/transformedEvaluation/cpu/m64-K1-k0-binary` | kernel | 24 us | 27 us | 1.12x slower | 5.0% | FAIL |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | kernel | 20 us | 17 us | 1.18x faster | 5.0% | faster |
| `kernel/transformedEvaluation/metalDense/m64-K1-k0-binary` | kernel | 3.46 ms | 5.23 ms | 1.51x slower | 5.0% | FAIL |
| `kernel/transformedEvaluation/metalSparse/m64-K1-k0-binary` | kernel | 3.32 ms | 4.02 ms | 1.21x slower | 5.0% | FAIL |
| `kernel/transformedEvaluation/metalSparseBatch/m64-K1-k0-binary` | kernel | 8.07 ms | 6.45 ms | 1.25x faster | 5.0% | faster |
| `kernel/transformedEvaluation/metalSparseBatchWorkspace/m64-K1-k0-binary` | kernel | 6.28 ms | 6.91 ms | 1.10x slower | 5.0% | FAIL |
| `numisealProduct/prove/cpu/one-hot-u2-terminal` | protocol | 420 ms | 425 ms | 1.01x slower | 10.0% | within threshold |
| `numisealProduct/prove/cpu/one-hot-u2-zk` | protocol | 419 ms | 424 ms | 1.01x slower | 10.0% | within threshold |
| `numisealProduct/recursiveCarry/prove/cpu/one-hot-u2-child` | protocol | 485 ms | 524 ms | 1.08x slower | 10.0% | within threshold |
| `numisealProduct/recursiveCarry/verify/cpu/one-hot-u2-child` | protocol | 156 ms | 161 ms | 1.03x slower | 10.0% | within threshold |
| `numisealProduct/verify/cpu/one-hot-u2-terminal` | protocol | 165 ms | 160 ms | 1.03x faster | 10.0% | faster |
| `numisealProduct/verify/cpu/one-hot-u2-zk` | protocol | 156 ms | 159 ms | 1.02x slower | 10.0% | within threshold |
| `productControls/auditEventEncode/cpu/recursive-carry` | protocol | 12 us | 13.9 us | 1.15x slower | 10.0% | FAIL |
| `productControls/replayIdentity/cpu/recursive-carry` | protocol | 52 us | 42 us | 1.24x faster | 10.0% | faster |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | protocol | 28 ms | 18 ms | 1.56x faster | 10.0% | faster |
| `proofEnvelope/roundTrip/m64-K1-k0-binary` | protocol | 17 ms | 8.62 ms | 1.97x faster | 10.0% | faster |
| `reduceFold/cpu/m256-K2-k1-binary` | protocol | 13 ms | 14 ms | 1.08x slower | 10.0% | within threshold |
| `reduceFold/cpu/m64-K1-k0-binary` | protocol | 4.7 ms | 5.13 ms | 1.09x slower | 10.0% | within threshold |
| `stage/piCCSClaims/m64-K1-k0-binary` | protocol | 221 us | 233 us | 1.05x slower | 10.0% | within threshold |
| `stage/piDEC/m64-K1-k0-binary` | protocol | 1.29 ms | 1.59 ms | 1.23x slower | 10.0% | FAIL |
| `stage/piRLC/m64-K1-k0-binary` | protocol | 1.69 ms | 1.84 ms | 1.09x slower | 10.0% | within threshold |
| `stage/prepared/piCCSClaims/m64-K1-k0-binary` | protocol | 247 us | 242 us | 1.02x faster | 10.0% | faster |
| `stage/prepared/piDEC/m64-K1-k0-binary` | protocol | 1.38 ms | 1.45 ms | 1.05x slower | 10.0% | within threshold |
| `stage/prepared/piRLC/m64-K1-k0-binary` | protocol | 286 us | 381 us | 1.33x slower | 10.0% | FAIL |
| `stage/prepared/sumcheck/m64-K1-k0-binary` | protocol | 598 us | 825 us | 1.38x slower | 10.0% | FAIL |
| `stage/sumcheck/m64-K1-k0-binary` | protocol | 597 us | 595 us | 1.00x faster | 10.0% | faster |
| `terminalVerify/cpu/m256-K2-k1-binary` | protocol | 15 ms | 16 ms | 1.07x slower | 10.0% | within threshold |
| `terminalVerify/cpu/m64-K1-k0-binary` | protocol | 6.11 ms | 6.41 ms | 1.05x slower | 10.0% | within threshold |

## Metadata Checks

| Key | Baseline | Candidate | Status |
| --- | --- | --- | --- |
| `benchmarkProfile` | quick | quick | match |
| `benchmarkCases` | m64-K1-k0-binary,m256-K2-k1-binary | m64-K1-k0-binary,m256-K2-k1-binary | match |
| `swiftVersion` | Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)<br>Target: arm64-apple-macosx26.0 | Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)<br>Target: arm64-apple-macosx26.0 | match |
| `xcodeVersion` | Xcode 26.4 Build version 17E192 | Xcode 26.4 Build version 17E192 | match |
| `osVersion` | Version 26.5 (Build 25F5058e) | Version 26.5 (Build 25F5058e) | match |
| `modelName` | MacBook Air | MacBook Air | match |
| `chip` | Apple M4 | Apple M4 | match |
| `cpuCores` | 10 | 10 | match |
| `memory` | 24 GB | 24 GB | match |
| `metalDevice` | Apple M4 | Apple M4 | match |
| `metalSupport` | available | available | match |
| `env.SUPERNEO_BENCHMARK_PROFILE` | quick | quick | match |
| `env.SUPERNEO_BENCHMARK_CASE_FILTER` |  |  | match |
| `env.SUPERNEO_BENCHMARK_CE` |  |  | match |
| `env.SUPERNEO_BENCHMARK_SIGNPOSTS` |  |  | match |
| `env.SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE` |  |  | match |
| `env.SUPERNEO_METAL_EVAL_ROW_PARTIAL_THRESHOLD` |  |  | match |
| `env.SUPERNEO_METAL_EVAL_ROW_PARTIAL_MAX_WORDS` |  |  | match |
