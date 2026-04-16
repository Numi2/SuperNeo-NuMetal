# NumiSealZK Design

`NumiSealZK` is the ZK product track for NumiSeal. It is not a marketing flag on
kind `4`; non-ZK immediate-residual NumiSeal remains kind `4` body version `11`.
The target ZK mode is `masked-digit-tensor-v1`, with a new body mode or proof
kind once the masked language is fully implemented.

The recursive proof posture follows folding/IVC ideas from Nova, SuperNova,
HyperNova, and Protostar, while keeping the implementation native to
Goldilocks, Phi81, and Ajtai commitments. The accelerated proving API posture
uses ICICLE v2-style hardware-oriented polynomial APIs as a benchmark, but does
not import a foreign PCS stack.

## Privacy Claim

The intended claim is that a verifier learns the public source fold statement,
the public NumiSeal statement, aggregate structure, declared leakage, and proof
validity, but not the unmasked aggregate witness or raw digit tensor. The
simulator target is a verifier view generated from public roots, aggregate
metadata, transcript challenges, declared leakage, and sampled masks.

This document does not certify GPU side-channel privacy. It separates correctness
of Metal output from privacy of Metal execution.

## Declared Leakage

The first ZK artifact must snapshot and expose:

- profile, shape digest, verifier-key digest, and transcript domains,
- source fold envelope digest and source output-claim digests,
- lane IDs, lane keys, aggregate indices, and aggregate counts,
- digit tensor dimensions and active digit counts,
- mask commitment digests and randomness session IDs,
- public statement, obligation, lane-summary, aggregate, component, and
  transcript roots,
- execution policy and Metal mode,
- hardware/tuning metadata for accelerated proving runs.

No production wording may claim side-channel privacy until a GPU leakage review
covers memory access, command scheduling, cache behavior, timing, and error
paths.

## Masking Algebra

The target language proves:

- masked digit tensor validity,
- masked residual consistency,
- masked residual opening composition,
- binding between source fold output claims, NumiSeal obligations, masks, and
  final public roots.

Masks are generated on CPU from CSPRNG material using domain-separated expansion,
then moved to Metal as fixed buffers. Randomness session IDs are recorded and
must fail closed on reuse. Deterministic seeds are test-only and unavailable in
public product mode.

## Metal Path

GPU acceleration is part of the target design. The execution policies are:

- `.zkMetalAccelerated`: Metal is the primary prover path for secret-bearing ZK
  stages.
- `.zkRedundantMetal`: Metal is allowed, and covered kernel outputs are checked
  against CPU oracles.
- `.zkHighAssuranceCPU`: CPU-only reference and certification mode.
- `.defaultProduct`: CPU-redundant Metal when available, otherwise CPU.

`NumiSealMetalProvingWorkspace` sits above `SuperNeoMetalWorkspace`. It reuses
existing Ajtai batch commitment and transformed-evaluation kernels and defines
the boundary for digit-tensor derivation, mask application, dense layer folding,
equality-weight evaluation, and batched sum-check accumulation kernels. Fiat
Shamir transcript hashing remains CPU-side until a typed GPU hash path exists
and is cross-checked.

## Correctness Gates

ZK Metal correctness gates must include:

- CPU/Metal equality for decomposition commitment,
- CPU/Metal equality for scalarization accumulation,
- CPU/Metal equality for sum-check layer folding,
- CPU/Metal equality for masked tensor application,
- fixed-randomness CPU and Metal proof-byte equality, or a documented digest
  explanation for accepted divergence,
- `.zkRedundantMetal` fault injection rejection.

Benchmark gates must report one-lane NumiSeal, two-lane NumiSeal, max aggregate,
recursive carry aggregate, ZK masked aggregate, hardware identity, kernel
tuning, and proof-byte/digest equivalence status.

## Non-Goals For The Current Slice

The current implementation exposes public NumiSeal product proving, typed carry
wire format, carry consumer replay checks, and Metal/ZK execution-policy
surfaces. It does not yet implement the full masked ZK proof body. Non-ZK product
artifacts therefore use `zkMode = "none"` and keep side-channel claims out of
the user-facing product surface.
