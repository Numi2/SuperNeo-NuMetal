# Cryptographic Side-Channel Audit - 2026-04-25

This audit covers the Swift and Metal cryptographic implementation surfaces that affect
constant-work and side-channel claims. It is a source and repository-evidence review, not
full side-channel certification. The scoped compiler/lowering review is now pinned in
`compiler-lowering-audit-v1`; whole-stack constant-time behavior still requires hardware
observation coverage before it can be claimed.

## Scope Reviewed

- Swift finite-field and ring arithmetic:
  `SuperNeo-NuMetal/Fields/GoldilocksField.swift`,
  `SuperNeo-NuMetal/Rings/CyclotomicRing54.swift`
- Ajtai commitment and matrix/vector paths:
  `SuperNeo-NuMetal/Commitments/AjtaiCommitment.swift`
- NumiSeal product/ZK proving and trusted product controls:
  `SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealProductProver.swift`,
  `SuperNeo-NuMetal/ProductIntegration/NumiSealZKSideChannelCertification.swift`,
  `SuperNeo-NuMetal/ProductIntegration/LocalProductControls.swift`
- Metal kernels and constant-time evidence manifests:
  `SuperNeo-NuMetal/MetalBackend/SuperNeoKernels.metal`,
  `TestVectors/constant-time-lowering-evidence-v1.json`,
  `Evidence/ConstantTime/swift-llvm-metal-v1/`

## Findings

### F-01: Side-channel certificate minimum was not enforced

Severity: High. Status: Fixed in this audit.

`SuperNeoTrustedNumiSealZKContext` exposed `minimumSideChannelCertificationLevel`,
but product validation allowed `certificate == nil` to return successfully before comparing
against that minimum. A trusted context configured to require
`production-side-channel-cleared` could therefore accept a masked NumiSealZK artifact
without any side-channel certificate.

Fix: `NumiSealZKSideChannelCertification.swift:419` now requires a certificate whenever
the minimum is stricter than `correctness-only`, and `NumiSealZKSideChannelCertification.swift:484`
rejects certificates below the configured minimum. Certificate validity windows now also
require `issuedAt < validUntil`.

### F-02: Machine-readable evidence claimed production constant-time too early

Severity: High. Status: Fixed in this audit.

The constant-time evidence files pinned useful local artifacts, but their promotion flags
allowed production constant-time claims even though the same evidence records described
open compiler/lowering and hardware-observation work. That was not a defensible whole-stack
constant-time claim.

Fix: `TestVectors/constant-time-lowering-evidence-v1.json`, the compiler/hardware lane
reports, the release evidence manifest, and the product loss/dossier manifests now keep
`productionConstantTimeClaimAllowed` false. Validators were updated to enforce that
non-certifying state while hardware coverage remains open; the scoped compiler/lowering
input is now pinned by `compiler-lowering-audit-v1`.

### F-03: High-assurance defaults are useful, but optimized paths remain data-dependent

Severity: Medium. Status: Accepted boundary.

The default and `zkHighAssuranceCPU` product policies resolve to `highAssurance`, and
`SuperNeoExecutionPolicy.swift:80` prevents Metal acceleration when the constant-work CPU
policy is active. This is the right default posture.

The optimized CPU and Metal paths still contain data-dependent branches and sparse skips:
`CyclotomicRing54.swift:63`, `CyclotomicRing54.swift:81`, `AjtaiCommitment.swift:448`,
`AjtaiCommitment.swift:507`, and `SuperNeoKernels.metal:81`. These are acceptable only as
explicit performance paths, not as certified secret-bearing constant-time paths.

### F-04: Goldilocks source shape is mostly constant-work; lowering review is pinned

Severity: Medium. Status: Fixed for scoped compiler/lowering; open for hardware certification.

`GoldilocksField.swift:23` through `GoldilocksField.swift:93` uses mask-style selection and
fixed-width exponentiation at source level. `compiler-lowering-audit-v1` now pins the
optimized SIL, LLVM IR, ARM64 assembly, Metal AIR/metallib objdump, and scoped review
findings for the marked regions. That closes the repository-local compiler/lowering input
for this toolchain, but does not certify CPU or GPU hardware behavior.

`GoldilocksField.swift:95` also keeps an explicit zero check for inversion. That is fine when
the zero/nonzero condition is public or already validated outside a secret observation model;
it is not a constant-time secret inversion API.

## Current Certification Boundary

The repository can currently claim:

- source-level constant-work hardening for selected arithmetic and high-assurance paths;
- default product proving that avoids secret-bearing Metal acceleration;
- pinned local compiler artifacts and local CPU/GPU smoke observations;
- pinned scoped compiler/lowering review for the current Swift/LLVM/Metal toolchain;
- enforced side-channel certificate minimums for trusted NumiSealZK contexts.

The repository should not claim:

- full side-channel certification;
- whole-stack Swift/LLVM/Metal constant-time behavior;
- GPU-family independent constant-time behavior;
- power/contention/scheduler closure.

## Required Before Whole-Stack Constant-Time Claim

1. CPU hardware-counter or dudect-style coverage for accepted CPU classes.
2. GPU timing/counter coverage for each accepted Apple GPU family.
3. Explicit power, contention, scheduler, and co-residency observation model.
4. Runtime allocation, ARC, copy-on-write, error-path, artifact-size, and retry-path closure
   under the accepted deployment threat model.
