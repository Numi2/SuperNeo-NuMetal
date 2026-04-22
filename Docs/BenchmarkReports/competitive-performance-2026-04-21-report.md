

## Timing Summary

| Benchmark | Time | GPU | Encode | Commit | Wait | p95 | Derived | Allocations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `fold/cpu/m256-K2-k1-binary` | 56 ms |  |  |  |  |  | 17.86 folds/s, 4571 constraints/s | 0 # |
| `fold/cpu/m64-K1-k0-binary` | 14 ms |  |  |  |  |  | 71.43 folds/s, 4571 constraints/s | 0 # |
| `fold/metal/m256-K2-k1-binary` | 88 ms | 8.36 μs | 8.12 μs | 9.62 μs | 9.01 μs | 87 | 11.36 folds/s, 2909 constraints/s | 0 # |
| `fold/metal/m64-K1-k0-binary` | 17 ms | 2.24 μs | 4.17 μs | 5.38 μs | 2.57 μs |  | 58.82 folds/s, 3765 constraints/s | 0 # |
| `fold/prepared/cpu/m256-K2-k1-binary` | 56 ms |  |  |  |  |  | 17.86 folds/s, 4571 constraints/s | 0 # |
| `fold/prepared/cpu/m64-K1-k0-binary` | 13 ms |  |  |  |  |  | 76.92 folds/s, 4923 constraints/s | 0 # |
| `fold/prepared/metal/m256-K2-k1-binary` | 89 ms | 7.95 μs | 10.4 μs | 6.96 μs | 8.79 μs |  | 11.24 folds/s, 2876 constraints/s | 0 # |
| `fold/prepared/metal/m64-K1-k0-binary` | 16 ms | 2.19 μs | 3.29 μs | 4.79 μs | 2.6 μs |  | 62.50 folds/s, 4000 constraints/s | 0 # |
| `kernel/ajtaiCommit/batch/cpu/m64-K1-k0-binary` | 670 μs |  |  |  |  | 669 | 1492.54 commitments/s | 0 # |
| `kernel/ajtaiCommit/batch/metal/m64-K1-k0-binary` | 1.68e+03 μs | 1.36 μs | 5.38 μs | 15.4 μs | 1.6 μs | 1223 | 596.66 commitments/s | 0 # |
| `kernel/ajtaiCommit/batchWorkspace/metal/m64-K1-k0-binary` | 1.08e+03 μs | 399 ns | 11.8 μs | 3.79 μs | 971 ns | 1075 | 925.93 commitments/s | 0 # |
| `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | 47 μs |  |  |  |  |  | 21276.60 commitments/s | 0 # |
| `kernel/ajtaiCommit/metal/m64-K1-k0-binary` | 875 μs | 140 ns | 6.04 μs | 7.38 μs | 824 ns | 782 | 1142.86 commitments/s | 0 # |
| `kernel/ajtaiCommit/workProfile/m64-K1-k0-binary` | 2.08e+03 ns |  |  |  |  | 1459 | 480076.81 commitments/s | 0 # |
| `kernel/combinedCommitEval/batchWorkspace/metal/m64-K1-k0-binary` | 7.81e+03 μs | 7.23 μs | 8.46 μs | 4.58 μs | 7.71 μs | 6603 |  | 0 # |
| `kernel/fieldMultiply/m64-K1-k0-binary` | 375 ns |  |  |  |  | 208 |  | 0 # |
| `kernel/fieldMultiply/metal/m64-K1-k0-binary` | 1.71e+03 μs | 1.21 μs | 8.08 μs | 4.62 μs | 1.66 μs | 824 |  | 0 # |
| `kernel/ringMultiply/m64-K1-k0-binary` | 2.62e+03 ns |  |  |  |  | 2125 |  | 0 # |
| `kernel/ringMultiply/metal/m64-K1-k0-binary` | 1.65e+03 μs | 1.16 μs | 20.7 μs | 4.58 μs | 1.59 μs | 1073 |  | 0 # |
| `kernel/ringScalarMultiply/cpu/m64-K1-k0-binary` | 416 ns |  |  |  |  | 125 |  | 0 # |
| `kernel/ringScalarMultiply/metal/m64-K1-k0-binary` | 1.68e+03 μs | 1.14 μs | 17 μs | 3.75 μs | 1.63 μs | 1054 |  | 0 # |
| `kernel/transformedEvaluation/cpu/m64-K1-k0-binary` | 24 μs |  |  |  |  | 24 |  | 0 # |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 20 μs |  |  |  |  | 19 |  | 0 # |
| `kernel/transformedEvaluation/metalDense/m64-K1-k0-binary` | 3.46e+03 μs | 321 ns | 9.96 μs | 2.92 μs | 773 ns | 3410 |  | 0 # |
| `kernel/transformedEvaluation/metalSparse/m64-K1-k0-binary` | 3.32e+03 μs | 130 ns | 3.29 μs | 7.25 μs | 801 ns | 3295 |  | 0 # |
| `kernel/transformedEvaluation/metalSparseBatch/m64-K1-k0-binary` | 8.07e+03 μs | 7.44 μs | 5.54 μs | 5.62 μs | 7.97 μs | 6181 |  | 0 # |
| `kernel/transformedEvaluation/metalSparseBatchWorkspace/m64-K1-k0-binary` | 6.28e+03 μs | 5.59 μs | 9.21 μs | 7.08 μs | 6.2 μs | 2910 |  | 0 # |
| `numisealProduct/prove/cpu/one-hot-u2-terminal` | 420 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/prove/cpu/one-hot-u2-zk` | 419 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/recursiveCarry/prove/cpu/one-hot-u2-child` | 485 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/recursiveCarry/verify/cpu/one-hot-u2-child` | 156 ms |  |  |  |  | 156 |  | 0 # |
| `numisealProduct/verify/cpu/one-hot-u2-terminal` | 165 ms |  |  |  |  | 163 |  | 0 # |
| `numisealProduct/verify/cpu/one-hot-u2-zk` | 156 ms |  |  |  |  |  |  | 0 # |
| `productControls/auditEventEncode/cpu/recursive-carry` | 1.2e+04 ns |  |  |  |  | 10087 |  | 0 # |
| `productControls/replayIdentity/cpu/recursive-carry` | 52 μs |  |  |  |  | 48 |  | 0 # |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 28 ms |  |  |  |  |  |  | 0 # |
| `proofEnvelope/roundTrip/m64-K1-k0-binary` | 17 ms |  |  |  |  |  |  | 0 # |
| `reduceFold/cpu/m256-K2-k1-binary` | 13 ms |  |  |  |  |  |  | 0 # |
| `reduceFold/cpu/m64-K1-k0-binary` | 4.7e+03 μs |  |  |  |  | 4674 |  | 0 # |
| `stage/piCCSClaims/m64-K1-k0-binary` | 221 μs |  |  |  |  | 213 |  | 0 # |
| `stage/piDEC/m64-K1-k0-binary` | 1.29e+03 μs |  |  |  |  | 1261 |  | 0 # |
| `stage/piRLC/m64-K1-k0-binary` | 1.69e+03 μs |  |  |  |  | 1683 |  | 0 # |
| `stage/prepared/piCCSClaims/m64-K1-k0-binary` | 247 μs |  |  |  |  | 243 |  | 0 # |
| `stage/prepared/piDEC/m64-K1-k0-binary` | 1.38e+03 μs |  |  |  |  | 1368 |  | 0 # |
| `stage/prepared/piRLC/m64-K1-k0-binary` | 286 μs |  |  |  |  | 262 |  | 0 # |
| `stage/prepared/sumcheck/m64-K1-k0-binary` | 598 μs |  |  |  |  | 596 |  | 0 # |
| `stage/sumcheck/m64-K1-k0-binary` | 597 μs |  |  |  |  | 585 |  | 0 # |
| `terminalVerify/cpu/m256-K2-k1-binary` | 15 ms |  |  |  |  |  |  | 0 # |
| `terminalVerify/cpu/m64-K1-k0-binary` | 6.11e+03 μs |  |  |  |  | 6058 |  | 0 # |
