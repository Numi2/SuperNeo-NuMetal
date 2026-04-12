# Apple M4 Quick Benchmark Report - CSR Transform and CE Batch Verification

Generated locally on 2026-04-12 after a protocol-preserving benchmark pass focused on removing avoidable CPU allocation and repeated work. The benchmark metadata file was generated at `2026-04-12T17:05:31Z`.

## Environment

| Field | Value |
| --- | --- |
| Source base | `e39ef2e` plus the working-tree changes described in this report |
| Swift | Apple Swift version 6.3 (`swiftlang-6.3.0.123.5 clang-2100.0.123.102`) |
| Xcode | Xcode 26.4, build 17E192 |
| OS | macOS 26.3, build 25D5087f |
| Model | MacBook Air |
| Chip | Apple M4 |
| CPU cores | 10 |
| Memory | 24 GB |
| Metal device | Apple M4 |
| Benchmark profile | `quick` |
| Benchmark cases | `m64-K1-k0-binary`, `m256-K2-k1-binary` |

## Scope

- Added direct CSR-to-SuperNeo transforms for dense and sparse ring matrices. This bypasses `SparseFieldMatrix` expansion, per-entry unit-vector allocation, dictionary row grouping, and per-row sorting in the transform hot path.
- Routed `CompiledCCSShape` through the CSR transforms so benchmark fixture setup and local verification use the canonical serialized matrix representation directly.
- Exposed the cyclotomic inner-product dual basis internally and accumulated transformed unit contributions directly into caller-owned coefficient buffers.
- Reused packed witnesses and multilinear evaluation bases across local CE opening batches, while preserving each claim's existing checks.
- Replaced the multilinear equality factor `a*b + (1-a)*(1-b)` with the algebraically identical `1 - a - b + 2*a*b`, saving one extension-field multiply per variable.
- Packed padded field vectors directly into ring elements instead of first materializing a padded field vector.

I intentionally did not keep a global compiled-shape cache. A cache can be useful later with explicit ownership, invalidation, and benchmark accounting, but keeping it here would risk hiding setup work rather than improving the measured protocol path.

## Trust Boundaries Not Changed

- No changes to the Goldilocks modulus, extension-field definition, cyclotomic relation, Ajtai parameters, norm bound, decomposition length, challenge set, challenge expansion, profile id, or claimed security bits.
- No changes to transcript domain separation, Fiat-Shamir challenge derivation, shape digests, statement digests, verifier-key digests, proof envelope bytes, or serialization formats.
- No changes to verifier acceptance criteria: commitments, public-input prefixes, witness length, norm checks, evaluation point length, matrix-evaluation count, and transformed matrix count are still checked.
- No changes to Ajtai key material or commitment semantics. The local verifier now commits the already packed witness with the same reference commitment function instead of packing it twice through adjacent call paths.
- No weakening of CPU/Metal differential gates or benchmark correctness gates.

## Validation

| Command | Result |
| --- | --- |
| `swift test --disable-swift-testing` | 71 XCTest cases passed, 0 failures |
| `swift Scripts/validate-test-vectors.swift` | Validated `one-hot-vector-fold-v1.json` and `binary-addition-u8-fold-v1.json` |
| `Scripts/run-benchmarks.sh quick` | Ran the 71-test gate, then exported `benchmark-results/results.json` and `benchmark-results/report.md` |

Additional regression coverage added in this pass:

- `testTier0MultilinearEqMatchesOriginalProductFormula` checks the optimized equality polynomial against the original product expression over seeded extension-field points.
- `testSuperNeoCSRTransformMatchesIndependentUnitVectorOracle` checks the direct CSR dense and sparse transforms against an independent unit-vector transform oracle, including multiple ring columns, duplicate field entries, and out-of-order sparse-field input.

## Timing Summary

Baseline is the first local quick run in this session before this optimization pass. Final is the last quick run on the final working tree.

| Case | Baseline | Final | Speedup | Change |
| --- | ---: | ---: | ---: | ---: |
| `fold/cpu/m64` | 5.465 ms | 4.349 ms | 1.26x | -20.4% |
| `fold/cpu/m256` | 42 ms | 38 ms | 1.11x | -9.5% |
| `fold/metal/m64` | 19 ms | 14.29 ms | 1.33x | -24.8% |
| `fold/metal/m256` | 69 ms | 63 ms | 1.10x | -8.7% |
| `stage/sumcheck/m64` | 1.848 ms | 0.302 ms | 6.12x | -83.7% |
| `stage/piCCSClaims/m64` | 1.509 ms | 0.337 ms | 4.48x | -77.7% |
| `stage/piRLC/m64` | 2.086 ms | 1.016 ms | 2.05x | -51.3% |
| `stage/piDEC/m64` | 3.686 ms | 2.302 ms | 1.60x | -37.5% |
| `terminalVerify/cpu/m64` | 5.434 ms | 3.299 ms | 1.65x | -39.3% |
| `terminalVerify/cpu/m256` | 20 ms | 13 ms | 1.54x | -35.0% |
| `proofEnvelope/roundTrip/m64` | 9.135 ms | 6.744 ms | 1.35x | -26.2% |
| `proofEnvelope/roundTrip/m256` | 25 ms | 17 ms | 1.47x | -32.0% |

## Notes

- The largest stable gains are in protocol stages that repeatedly transform or verify CCS evaluations: sum-check setup, PiCCS, PiRLC, PiDEC, terminal verification, and proof-envelope round trips.
- Metal end-to-end rows improved in this run, but they remain more sensitive to device scheduling and benchmark variance than the CPU protocol-stage rows. Treat the stage rows as the primary signal for this pass.
- The direct CSR sparse transform relies on the existing CSR invariant that field columns are strictly increasing within each row. The constructor enforces that invariant, and the new regression test covers the canonicalization path from unsorted sparse-field input.
- Future work should focus on explicit compiled-shape lifetime management and Metal workspace reuse that is visible in benchmark setup, rather than global hidden caches.
