# GPU Determinism

Metal is an accelerator for prover-side and local verification work. It is not a
separate proof system and it is not trusted for proof acceptance semantics.

## Determinism Claim

For a fixed executable, parameter profile, Ajtai verifier key, CCS shape,
normalized witness, public input, transcript seed, and Metal tuning environment,
the Metal path is intended to produce the same field and ring outputs as the CPU
reference path.

This claim covers:

- Goldilocks field arithmetic kernels,
- Phi81 ring arithmetic kernels,
- Ajtai commitment kernels,
- transformed sparse-evaluation kernels, and
- fused commitment plus transformed-evaluation kernels.

It does not claim constant-time execution, driver-independent timing, identical
wall-clock performance, or reproducible GPU scheduling traces.

## Why Kernel Results Are Deterministic

The Metal kernels operate over integer field elements with explicit modular
arithmetic. They do not use floating-point arithmetic, transcendental functions,
or approximate reductions.

The dispatch layer submits a fixed sequence of one-dimensional compute commands
and waits for completion before reading results. When multiple commands are
encoded into one command buffer and a later command depends on an earlier write,
the command sequence requests a buffer memory barrier.

The sparse-matrix workspaces are precomputed from the compiled CCS shape and
bound to a digest. CE opening paths reject workspaces whose verifier key,
shape digest, transformed matrix count, or transformed matrix digest does not
match the public statement being verified.

## CPU Oracle Policy

CPU code is the reference implementation. Metal changes must preserve CPU/Metal
differential checks before they are treated as valid optimization work.

Callers can now make this runtime-enforced:

- `SuperNeoExecutionPolicy.cpuRedundantMetal` keeps Metal acceleration enabled
  and rejects covered Metal commitment or transformed-evaluation outputs that
  differ from CPU recomputation.
- `SuperNeoExecutionPolicy.highAssurance` disables secret-bearing Metal work in
  the prover and uses CPU-redundant checks for any covered Metal work that
  remains in verification.
- `SuperNeoMetalWorkspace` exposes policy-aware direct methods for callers that
  use the workspace API outside the fold/CE protocol wrappers.

Required gates:

- `MetalDifferentialTests` for kernel-level CPU/Metal equality.
- Benchmark correctness gates, which compare CPU and Metal outputs when both are
  available.
- Full protocol verification after benchmark execution: fold reduction,
  terminal verification, and proof-envelope round trips must still pass.

The verifier API does not accept a proof merely because a GPU computation
completed. Proof acceptance still goes through the same public transcript,
statement digest, verifier-key digest, proof-envelope, and relation checks. With
`cpuRedundantMetal`, covered GPU outputs must also match CPU results before the
verification path uses them.

## Environment Variables

`SUPERNEO_METAL_EVAL_ROW_BLOCK_SIZE` changes the row-block size used by fused
transformed evaluation. It is a performance knob, not a transcript input.
Changing it must not change proof bytes or verifier results. When benchmarking,
record the value in the report notes so performance results are attributable.

`SUPERNEO_METAL_EVAL_ROW_PARTIAL_THRESHOLD` enables the experimental row-partial
transformed-evaluation schedule for batch row counts at or above the configured
threshold. The default leaves the schedule disabled because the local m64
correctness run was slower than the blocked baseline even though it produced the
same values.

`SUPERNEO_METAL_EVAL_ROW_PARTIAL_MAX_WORDS` caps temporary partial-buffer
allocation for the row-partial schedule. If the required partial buffer is larger
than this cap, the backend falls back to the blocked/fused schedule.

Benchmark metadata records all three Metal tuning variables. Baseline
comparisons treat them as comparable metadata, so runs with different tuning
values are not silently compared as equivalent evidence.

## Non-Goals

The current implementation does not try to protect against:

- malicious GPU drivers that can also tamper with CPU execution or process
  control flow,
- malicious kernel binaries outside this repository,
- hardware faults or memory corruption,
- side-channel leakage through GPU timing, cache behavior, or power, or
- cross-vendor reproducibility outside Apple Metal devices.

Use the CPU path for independent reference checks. Use Metal for performance
only after the CPU/Metal differential suite and proof-envelope verification pass.
