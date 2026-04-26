# GPU Determinism And Metal Policy

Metal is an optional accelerator for repository workloads. It is not a separate
cryptographic assumption and it is not the default high-assurance product path.

## Modes

- CPU reference: default correctness and high-assurance baseline.
- Metal acceleration: optional performance lane with CPU/Metal differential
  tests and benchmark coverage.
- CPU-redundant Metal: hardened opt-in lane that treats CPU recomputation as the
  acceptance reference.

The runtime policy surface is implemented in
[SuperNeoExecutionPolicy.swift](../SuperNeo-NuMetal/SuperNeoExecutionPolicy.swift)
and the Metal backend under [MetalBackend](../SuperNeo-NuMetal/MetalBackend).

## Evidence

Relevant evidence and docs:

- [ConstantTimeEvidence-2026-04-16.md](ConstantTimeEvidence-2026-04-16.md)
- [CryptographicSideChannelAudit-2026-04-25.md](CryptographicSideChannelAudit-2026-04-25.md)
- [constant-time-scope-v1.json](../TestVectors/constant-time-scope-v1.json)
- [constant-time-lowering-evidence-v1.json](../TestVectors/constant-time-lowering-evidence-v1.json)
- [ConstantTime evidence manifest](../Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json)

## Claim Boundary

Passing Metal tests show deterministic agreement with the CPU implementation for
the covered workloads. They do not certify a malicious GPU, a constant-time GPU
microarchitecture, or whole-stack leakage resistance. Product deployments that
need side-channel evidence must require signed side-channel certificates through
the product-control path.
