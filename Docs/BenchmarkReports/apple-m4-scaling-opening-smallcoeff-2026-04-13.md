# Apple M4 Scaling Benchmark Report - Parallel Openings and Small-Coefficient Ring Arithmetic

Generated locally on 2026-04-13 after a protocol-preserving benchmark pass
focused on the `m4096` and `m16384` scaling cases.

## Environment

| Field | Value |
| --- | --- |
| Machine | MacBook Air |
| Chip | Apple M4 |
| CPU cores | 10 (4 performance, 6 efficiency) |
| Memory | 24 GB |
| OS | macOS 26.3, build 25D5087f |
| Xcode | Xcode 26.4, build 17E192 |
| Swift | Apple Swift 6.3, target `arm64-apple-macosx26.0` |
| Metal device | Apple M4, Metal 4 |
| Benchmark profile | `scaling` with `SUPERNEO_BENCHMARK_CASE_FILTER=m4096,m16384` for final end-to-end slice |
| Source head | `8a56de5824abc6ed795bc1cfdda9cb8cfe04ab9e` with this pass dirty |

## Scope

- Parallelized independent CPU evaluation-opening work for large batches. This
  applies to PiDEC limb commitment/evaluation construction and terminal CE
  opening verification when `count >= 4` and `m >= 1024`.
- Preserved output ordering with an ordered parallel map. Each opening still
  runs the same commitment recomputation, public-input prefix check, norm check,
  transformed-evaluation recomputation, and equality check.
- Added a small-coefficient ring multiplication path for rings whose
  coefficients are all in `{0, +/-1, +/-2}`. This matches the implemented
  Fiat-Shamir challenge-ring coefficient set and uses exact add/sub/double
  operations instead of full Goldilocks multiplication for those coefficient
  products.
- Kept generic ring products on the original full-width multiplication loop
  after a one-time per-ring small-coefficient scan.
- Added an independent reduction-oracle test for small-coefficient base-ring
  and extension-ring products.

## Rejected Work

I tested parallelizing PiRLC witness folding across ring columns. It preserved
correctness but regressed `m16384 stage/piRLC` to about `165 ms`, likely from
thread scheduling and cache contention around many medium-sized ring products.
That change was reverted. The accepted implementation does not parallelize
PiRLC.

I also retested the existing Metal row-block knob at `m16384` with
`SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE=256`. It did not improve the measured
Metal fold or transformed-evaluation rows, so the default remains unchanged.

## Trust Boundaries

This pass did not change cryptographic parameters, the Goldilocks modulus,
extension-field definition, cyclotomic relation, Ajtai dimensions, norm bound,
decomposition length, challenge coefficient set, challenge expansion factor,
profile id, claimed security bits, transcript domains, Fiat-Shamir framing,
shape/statement/verifier-key digests, proof serialization, proof-envelope
binding, verifier acceptance criteria, or CPU/Metal equality requirements.

The parallel opening code only changes scheduling for independent local CPU
work. The small-coefficient arithmetic path is an exact algebraic
specialization for coefficients already sampled by the existing profile.

## Validation

| Command | Result |
| --- | --- |
| `swift test --disable-swift-testing` | 75 XCTest cases, 0 failures |
| `swift Scripts/validate-test-vectors.swift` | `one-hot-vector-fold-v1.json` and `binary-addition-u8-fold-v1.json` validated |
| `git diff --check` | clean |

Benchmark correctness gates also ran inside the targeted benchmark rows:
protocol rows verified reductions or terminal envelopes, and Metal rows compared
against CPU reference output where registered.

## Timing

The baseline rows below were captured at the start of this pass on the same
machine and source head before these edits. The final rows use the final
targeted scaling benchmark slice. Timing is wall clock from package-benchmark.

| Benchmark | Baseline | Final | Change |
| --- | ---: | ---: | ---: |
| `fold/cpu/m4096-K2-k0-binary` | 202 ms | 174 ms | 1.16x faster |
| `terminalVerify/cpu/m4096-K2-k0-binary` | 144 ms | 113 ms | 1.27x faster |
| `proofEnvelope/roundTrip/m4096-K2-k0-binary` | 157 ms | 119 ms | 1.32x faster |
| `stage/piDEC/m4096-K2-k0-binary` | 137 ms | 106 ms | 1.29x faster |
| `stage/piRLC/m4096-K2-k0-binary` | 24 ms | 24 ms | flat |
| `fold/cpu/m16384-K2-k0-binary` | 796 ms | 686 ms | 1.16x faster |
| `terminalVerify/cpu/m16384-K2-k0-binary` | 572 ms | 428 ms | 1.34x faster |
| `proofEnvelope/roundTrip/m16384-K2-k0-binary` | 765 ms | 431 ms | 1.78x faster |
| `stage/piDEC/m16384-K2-k0-binary` | 589 ms | 411 ms | 1.43x faster |
| `stage/piRLC/m16384-K2-k0-binary` | 104 ms | 115 ms | within observed stage-run variance |

Metal fold rows were not the focus of this pass. The final slice measured
`fold/metal/m4096` at `106 ms` versus a `105 ms` starting row, and
`fold/metal/m16384` at `365 ms` versus a `355 ms` starting row. Those rows are
within the local variance observed during row-block tuning and should not be
treated as a Metal regression claim without a longer isolated Metal run.

## Notes

- The strongest stable signal is in CPU terminal verification and proof-envelope
  round trips, where terminal opening checks previously ran serially across the
  decomposition limbs.
- PiDEC improved because large CPU limb commitments and transformed evaluations
  now run as independent ordered work.
- The small-coefficient ring path is kept because it restores PiRLC after the
  failed parallel attempt while preserving or improving the final end-to-end CPU
  rows. The independent oracle test covers this path directly.
- Stage rows unrelated to the edited code showed visible run-to-run variance in
  the targeted benchmark invocations. Use the final end-to-end rows as the main
  acceptance signal for this pass.
