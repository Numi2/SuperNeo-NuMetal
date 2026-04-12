# Lead Audit, 2026-04-12

Scope: production Swift and Metal backend code, benchmark code, and regression
coverage. This note records the findings addressed in the implementation pass;
it is not an independent cryptographic security certification.

## Findings Addressed

1. Production CE-opening entropy needed an explicit Apple platform boundary.
   `CEOpeningRelation.proveLocalBatch` now gets its production seed from
   `SecRandomCopyBytes(kSecRandomDefault, ...)` and propagates failure instead
   of silently continuing. The seed is then length-framed, domain-separated, and
   bound to the terminal CE statement before deterministic Stern-round expansion.

2. PiRLC claim batching accepted mixed witness availability. The protocol
   oracle now requires RLC claim batches to be either all witnessed or all
   public, closing an ambiguous prover input class.

3. Metal workspace construction accepted transformed matrices with mismatched
   column counts. `SuperNeoMetalWorkspace` now rejects matrices whose transformed
   column count does not match the active Ajtai key column count.

4. CE verifier target preparation was CPU-only even when a Metal workspace was
   supplied. The verifier now groups openings by evaluation point and uses the
   workspace combined commitment-plus-transformed-evaluation path for public
   target preparation when Metal is available, while retaining the CPU path as
   the deterministic fallback.

5. CE evaluation-vector subtraction used `zip`, which would truncate on a
   length mismatch. The helper now checks equal lengths and throws before any
   verifier instance is derived.

6. The `kernel/multilinearEvaluation/*` benchmark included CSR matrix
   rehydration in the timed body. The benchmark now prepares that matrix once
   during setup, so the timing row measures multilinear evaluation rather than
   benchmark fixture conversion.

7. `SparseMatrixCSR.multiplied(by:)` rehydrated a `SparseFieldMatrix` before
   multiplying. CSR matrices now multiply directly from row offsets, column
   indices, and values, preserving the same dimension error and oracle behavior
   without per-call entry-list reconstruction.

8. `MultilinearEvaluation.evaluate` allocated a fresh layer for every
   challenge. It now folds layers in place, preserving the same vector-length
   checks and evaluation formula while reducing allocation pressure in CPU
   kernel and sum-check paths.

9. `MultilinearEvaluation.checkedBasis` copied the full partial basis before
   each expansion round. Basis generation now expands in place, preserving the
   same low/high hypercube ordering and dimension guard while reducing setup
   allocation in transformed-evaluation paths.

10. CPU transformed evaluation scaled zero coefficients in every row. The
    public CPU backend now preserves its coefficient-first accumulation order
    but skips zero row coefficients before extension-field scaling. This keeps
    the sparse transformed-evaluation path aligned with canonical CSR sparsity
    without changing output ordering or verifier semantics.

## Validation

Commands run locally on 2026-04-12:

```sh
swift test --disable-swift-testing
swift build -c release
swift Scripts/validate-test-vectors.swift
cd Benchmarks && \
  SUPERNEO_BENCHMARK_PROFILE=quick \
  SUPERNEO_BENCHMARK_CASE_FILTER=m64-K1-k0-binary \
  swift package --disable-sandbox --allow-writing-to-package-directory benchmark \
    --target SuperNeoBenchmarks \
    run \
    --benchmark-build-configuration release \
    --metric wallClock \
    --format jsonSmallerIsBetter \
    --path /tmp/superneo-benchmark-csr-direct \
    --no-progress
cd Benchmarks && \
  SUPERNEO_BENCHMARK_PROFILE=quick \
  swift package --disable-sandbox --allow-writing-to-package-directory benchmark \
    --target SuperNeoBenchmarks \
    run \
    --benchmark-build-configuration release \
    --metric wallClock \
    --format jsonSmallerIsBetter \
    --path /tmp/superneo-benchmark-quick-direct \
    --no-progress
cd Benchmarks && \
  SUPERNEO_BENCHMARK_PROFILE=quick \
  swift package --disable-sandbox --allow-writing-to-package-directory benchmark \
    --target SuperNeoBenchmarks \
    run \
    --benchmark-build-configuration release \
    --metric wallClock \
    --format jsonSmallerIsBetter \
    --path /tmp/superneo-benchmark-quick-basis \
    --no-progress
cd Benchmarks && \
  SUPERNEO_BENCHMARK_PROFILE=quick \
  swift package --disable-sandbox --allow-writing-to-package-directory benchmark \
    --target SuperNeoBenchmarks \
    run \
    --benchmark-build-configuration release \
    --metric wallClock \
    --format jsonSmallerIsBetter \
    --path /tmp/superneo-benchmark-quick-cpu-zero-skip \
    --no-progress
```

Results:

- XCTest: 73 tests, 0 failures.
- Release build: passed.
- Test vectors: `one-hot-vector-fold-v1.json` and
  `binary-addition-u8-fold-v1.json` validated.
- Filtered direct-CSR benchmark smoke run: passed and wrote 29 wall-clock rows
  to `/tmp/superneo-benchmark-csr-direct/Current_run.json`, including
  `kernel/multilinearEvaluation/m64-K1-k0-binary = 1750 ns`.
- Direct CSR and in-place multilinear pass: full quick wall-clock profile passed
  and wrote 34 rows to `/tmp/superneo-benchmark-quick-direct/Current_run.json`.
  Local rows included `fold/cpu/m64-K1-k0-binary = 4475 us`,
  `fold/cpu/m256-K2-k1-binary = 37 ms`,
  `kernel/multilinearEvaluation/m64-K1-k0-binary = 1750 ns`, and
  `terminalVerify/cpu/m256-K2-k1-binary = 13 ms`. Treat these as local audit
  evidence, not a pinned hardware-class report.
- In-place basis pass: full quick wall-clock profile passed and wrote 34 rows
  to `/tmp/superneo-benchmark-quick-basis/Current_run.json`. Local rows included
  `fold/cpu/m64-K1-k0-binary = 4205 us`,
  `fold/cpu/m256-K2-k1-binary = 36 ms`,
  `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary = 32 us`,
  `terminalVerify/cpu/m64-K1-k0-binary = 3028 us`, and
  `proofEnvelope/roundTrip/m64-K1-k0-binary = 6448 us`. Treat these as local
  audit evidence, not a pinned hardware-class report.
- CPU transformed-evaluation zero-skip pass: full quick wall-clock profile
  passed and wrote 34 rows to
  `/tmp/superneo-benchmark-quick-cpu-zero-skip/Current_run.json`. Local rows
  included `fold/cpu/m64-K1-k0-binary = 4109 us`,
  `fold/cpu/m256-K2-k1-binary = 36 ms`,
  `kernel/transformedEvaluation/cpu/m64-K1-k0-binary = 38 us`,
  `kernel/transformedEvaluation/cpuSparse/m64-K1-k0-binary = 28 us`, and
  `stage/piDEC/m64-K1-k0-binary = 2150 us`. Treat these as local audit
  evidence, not a pinned hardware-class report.

## Platform Grounding

For production randomness on Apple platforms, the implementation now uses the
Security framework `SecRandomCopyBytes` API with `kSecRandomDefault`. The code
treats any non-success `OSStatus` as a hard proof-generation error because CE
opening randomness is part of the trust boundary.

Apple reference:
<https://developer.apple.com/documentation/security/secrandomcopybytes%28_%3A_%3A_%3A%29>

## Remaining Work

- Run and pin a full hardware-class benchmark report before updating public
  performance claims.
- Run the opt-in CE benchmark suite with `SUPERNEO_BENCHMARK_CE=1` after the
  next full quick run to quantify the Metal verifier target-preparation path.
- Use Instruments or Metal System Trace only after benchmark rows identify a
  stable hotspot; the correctness gate remains CPU/Metal equality plus the
  protocol tests.
