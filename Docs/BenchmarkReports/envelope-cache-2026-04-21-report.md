

## Timing Summary

| Benchmark | Time | GPU | Encode | Commit | Wait | p95 | Derived | Allocations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `fold/cpu/m256-K2-k1-binary` | 59 ms |  |  |  |  | 59 | 16.95 folds/s, 4339 constraints/s | 0 # |
| `fold/cpu/m64-K1-k0-binary` | 14 ms |  |  |  |  |  | 71.43 folds/s, 4571 constraints/s | 0 # |
| `fold/metal/m256-K2-k1-binary` | 152 ms | 17 ns | 41 ns | 11.8 μs | 18 ns | 144 | 6.58 folds/s, 1684 constraints/s | 0 # |
| `fold/metal/m64-K1-k0-binary` | 36 ms | 5.5 μs | 13.5 μs | 5.88 μs | 6.49 μs | 35 | 27.78 folds/s, 1778 constraints/s | 0 # |
| `fold/prepared/cpu/m256-K2-k1-binary` | 58 ms |  |  |  |  |  | 17.24 folds/s, 4414 constraints/s | 0 # |
| `fold/prepared/cpu/m64-K1-k0-binary` | 14 ms |  |  |  |  |  | 71.43 folds/s, 4571 constraints/s | 0 # |
| `fold/prepared/metal/m256-K2-k1-binary` | 144 ms | 17 ns | 40 ns | 5.12 μs | 18 ns | 143 | 6.94 folds/s, 1778 constraints/s | 0 # |
| `fold/prepared/metal/m64-K1-k0-binary` | 39 ms | 5.46 μs | 66 ns | 37.7 μs | 6.39 μs |  | 25.64 folds/s, 1641 constraints/s | 0 # |
| `kernel/ajtaiCommit/batch/cpu/m64-K1-k0-binary` | 865 μs |  |  |  |  | 710 | 1156.07 commitments/s | 0 # |
| `kernel/ajtaiCommit/batch/metal/m64-K1-k0-binary` | 2.26e+03 μs | 985 ns | 9.75 μs | 4.5 μs | 2.13 μs | 1316 | 442.28 commitments/s | 0 # |
| `kernel/ajtaiCommit/batchWorkspace/metal/m64-K1-k0-binary` | 3.47e+03 μs | 1.26 μs | 9.17 μs | 4.25 μs | 3.37 μs | 1637 | 288.18 commitments/s | 0 # |
| `kernel/ajtaiCommit/cpu/m64-K1-k0-binary` | 47 μs |  |  |  |  |  | 21276.60 commitments/s | 0 # |
| `kernel/ajtaiCommit/metal/m64-K1-k0-binary` | 2.25e+03 μs | 522 ns | 11.9 μs | 3.75 μs | 2.22 μs | 1768 | 443.66 commitments/s | 0 # |
| `kernel/ajtaiCommit/workProfile/m64-K1-k0-binary` | 2.21e+03 ns |  |  |  |  | 1584 | 452898.55 commitments/s | 0 # |
| `kernel/combinedCommitEval/batchWorkspace/metal/m64-K1-k0-binary` | 5.05e+03 μs | 4.41 μs | 35 μs | 9.38 μs | 4.94 μs | 4809 |  | 0 # |
| `kernel/fieldMultiply/m64-K1-k0-binary` | 500 ns |  |  |  |  | 208 |  | 0 # |
| `kernel/fieldMultiply/metal/m64-K1-k0-binary` | 1.44e+03 μs | 254 ns | 7.92 μs | 3.42 μs | 1.41 μs | 689 |  | 0 # |
| `kernel/ringMultiply/m64-K1-k0-binary` | 2.54e+03 ns |  |  |  |  | 2042 |  | 0 # |
| `kernel/ringMultiply/metal/m64-K1-k0-binary` | 1.72e+03 μs | 427 ns | 15.2 μs | 13.9 μs | 1.68 μs | 1177 |  | 0 # |
| `kernel/ringScalarMultiply/cpu/m64-K1-k0-binary` | 375 ns |  |  |  |  | 125 |  | 0 # |
| `kernel/ringScalarMultiply/metal/m64-K1-k0-binary` | 2.5e+03 μs | 1.09 μs | 12.8 μs | 14.9 μs | 2.45 μs | 1614 |  | 0 # |
| `kernel/transformedEvaluation/cpu/m64-K1-k0-binary` | 27 μs |  |  |  |  | 25 |  | 0 # |
| `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary` | 17 μs |  |  |  |  |  |  | 0 # |
| `kernel/transformedEvaluation/metalDense/m64-K1-k0-binary` | 5.23e+03 μs | 608 ns | 12.9 μs | 4.75 μs | 2.54 μs | 4049 |  | 0 # |
| `kernel/transformedEvaluation/metalSparse/m64-K1-k0-binary` | 4.02e+03 μs | 969 ns | 7.62 μs | 18.4 μs | 2.16 μs | 3785 |  | 0 # |
| `kernel/transformedEvaluation/metalSparseBatch/m64-K1-k0-binary` | 6.45e+03 μs | 5.93 μs | 11.1 μs | 5.46 μs | 6.33 μs | 5812 |  | 0 # |
| `kernel/transformedEvaluation/metalSparseBatchWorkspace/m64-K1-k0-binary` | 6.91e+03 μs | 5.75 μs | 11.8 μs | 4.46 μs | 6.86 μs | 6210 |  | 0 # |
| `numisealProduct/prove/cpu/one-hot-u2-terminal` | 425 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/prove/cpu/one-hot-u2-zk` | 424 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/recursiveCarry/prove/cpu/one-hot-u2-child` | 524 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/recursiveCarry/verify/cpu/one-hot-u2-child` | 161 ms |  |  |  |  |  |  | 0 # |
| `numisealProduct/verify/cpu/one-hot-u2-terminal` | 160 ms |  |  |  |  | 160 |  | 0 # |
| `numisealProduct/verify/cpu/one-hot-u2-zk` | 159 ms |  |  |  |  |  |  | 0 # |
| `productControls/auditEventEncode/cpu/recursive-carry` | 1.39e+04 ns |  |  |  |  | 13127 |  | 0 # |
| `productControls/replayIdentity/cpu/recursive-carry` | 42 μs |  |  |  |  | 40 |  | 0 # |
| `proofEnvelope/roundTrip/m256-K2-k1-binary` | 18 ms |  |  |  |  |  |  | 0 # |
| `proofEnvelope/roundTrip/m64-K1-k0-binary` | 8.62e+03 μs |  |  |  |  | 8561 |  | 0 # |
| `reduceFold/cpu/m256-K2-k1-binary` | 14 ms |  |  |  |  |  |  | 0 # |
| `reduceFold/cpu/m64-K1-k0-binary` | 5.13e+03 μs |  |  |  |  | 5046 |  | 0 # |
| `stage/piCCSClaims/m64-K1-k0-binary` | 233 μs |  |  |  |  | 226 |  | 0 # |
| `stage/piDEC/m64-K1-k0-binary` | 1.59e+03 μs |  |  |  |  | 1322 |  | 0 # |
| `stage/piRLC/m64-K1-k0-binary` | 1.84e+03 μs |  |  |  |  | 1805 |  | 0 # |
| `stage/prepared/piCCSClaims/m64-K1-k0-binary` | 242 μs |  |  |  |  | 241 |  | 0 # |
| `stage/prepared/piDEC/m64-K1-k0-binary` | 1.45e+03 μs |  |  |  |  | 1445 |  | 0 # |
| `stage/prepared/piRLC/m64-K1-k0-binary` | 381 μs |  |  |  |  | 376 |  | 0 # |
| `stage/prepared/sumcheck/m64-K1-k0-binary` | 825 μs |  |  |  |  | 618 |  | 0 # |
| `stage/sumcheck/m64-K1-k0-binary` | 595 μs |  |  |  |  | 585 |  | 0 # |
| `terminalVerify/cpu/m256-K2-k1-binary` | 16 ms |  |  |  |  |  |  | 0 # |
| `terminalVerify/cpu/m64-K1-k0-binary` | 6.41e+03 μs |  |  |  |  | 6304 |  | 0 # |
