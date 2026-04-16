# NumiSealZK Design

`NumiSealZK` is the ZK product track for NumiSeal. It is not a marketing flag on
kind `4`; non-ZK immediate-residual NumiSeal remains kind `4` body version `11`.
The initial ZK mode is `masked-digit-tensor-v1` and uses proof-envelope kind
`5` with body version `13`.

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

This document does not by itself certify GPU side-channel privacy. It separates
correctness of Metal output from privacy of Metal execution, and the product
control layer now has a signed certificate gate for promoting reviewed
side-channel evidence into trusted contexts.

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

No production wording may claim side-channel privacy unless a trusted context
pins the declared leakage digest and, for secret-bearing Metal modes, a signed
NumiSealZK side-channel certificate covering memory access, command scheduling,
cache behavior, timing, error paths, kernel/stage review, and benchmark evidence.

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
existing Ajtai batch commitment and transformed-evaluation kernels. The first
implemented ZK kernels are:

- `numiseal_apply_mask_kernel`,
- `numiseal_dense_fold_kernel`,
- `numiseal_eq_weight_kernel`,
- `numiseal_sumcheck_accumulate_kernel`,
- `numiseal_mask_accumulate_kernel`.

`NumiSealMetalProvingWorkspace` exposes these as mask application, dense layer
folding, equality-weight evaluation, and sum-check polynomial accumulation. In
`.zkRedundantMetal`, each output is checked against a CPU oracle before the
caller can use it. Fiat-Shamir transcript hashing remains CPU-side until a typed
GPU hash path exists and is cross-checked.

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

## Current Implementation Status

Implemented:

- kind `5` `NumiSealZKProofEnvelope` and body version `13`,
- `NumiSealZKProof` with `zkMode`, randomness-session digest,
  declared-leakage digest, embedded base `NumiSealProof`, mask statements,
  masked residual statements, component root, and transcript digest,
- CPU-expanded mask material and fail-closed randomness-session reuse guard,
- Metal-backed mask application through `NumiSealMetalProvingWorkspace` with
  CPU oracle checks in `.zkRedundantMetal`,
- transcript-derived masked residual accumulation challenges bound to each base
  lane proof, mask statement, and three accumulation weights,
- verifier-side recomputation of the public equality-weight digest,
- Metal kernels for dense folding, equality weights, sum-check accumulation, and
  fused mask-plus-accumulation,
- public product proving through explicit
  `--numiseal-zk-mode masked-digit-tensor-v1` / `NumiSealProvingRequest.zkMode`,
- focused tests for ZK body round-trip, randomness reuse rejection, fresh mask
  divergence, masked residual binding, product ZK artifact verification, and
  CPU/Metal oracle equality,
- fixed-randomness CPU and Metal proof-byte equality for the masked
  `NumiSealZKProofEnvelope`,
- signed `NumiSealZK` side-channel certificate payloads with context, release,
  proof-policy, leakage, Metal workspace, reviewed kernel/stage, evidence, and
  expiry bindings,
- product-control fail-closed validation for `numiseal-zk` trusted contexts
  that omit ZK policy, require a missing certificate, pin a different
  certificate digest, or present a certificate whose bindings differ from the
  artifact.

Still not certified as production privacy:

- the simulator proof for the full masked residual language,
- benchmark-report promotion of proof-byte equivalence across product-sized
  hardware profiles,
- generating and signing side-channel certificate evidence for each production
  hardware/profile lane,
- public product artifact defaulting to `zkMode = "masked-digit-tensor-v1"`.

Until those gates land, product artifacts continue to default to
`zkMode = "none"`. Explicit masked product artifacts are correctness-checked and
verifiable. Secret-bearing Metal privacy claims require a trusted context with
NumiSealZK policy and a matching signed side-channel certificate.
