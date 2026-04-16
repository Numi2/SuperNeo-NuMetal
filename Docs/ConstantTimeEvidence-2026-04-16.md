# Constant-Time Evidence Track, 2026-04-16

Formal status: conditional source and formal trace model for the checked
constant-time scope.

This pass moves the side-channel track from prose into checked repository
evidence. It does not claim a complete Swift/LLVM/Metal/hardware
constant-time proof. It defines the proof object and validator path needed to
close that claim incrementally without relying on outsourced review.

## Checked Artifacts

- `Formal/SuperNeoFormal/ConstantTime.lean` defines trace independence for
  fixed operation schedules and proves it for the current Swift Goldilocks
  common-arithmetic model, Metal Goldilocks common-arithmetic model, and one
  NumiSealZK per-element mask-kernel schedule.
- `TestVectors/constant-time-scope-v1.json` records the audited source regions,
  secret/public inputs, forbidden source-level control-flow patterns, formal
  declaration names, and residual lowering boundaries.
- `TestVectors/constant-time-lowering-evidence-v1.json` records the
  Swift/LLVM/Metal lowering proof contract, runtime/hardware TCB obligations,
  required release artifacts, compiler/hardware observation lane reports, and
  the exact promotion rule that keeps production constant-time language disabled
  until those artifacts exist.
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json` pins the local
  release evidence generated for this slice: Metal AIR, linked metallib,
  Metal generation report, Swift runtime allocation/COW static review, CPU
  observation corpus, direct GPU kernel observation corpus, compiler
  observation lane report, and hardware observation lane report.
- `Evidence/ConstantTime/swift-llvm-metal-v1/compiler/compiler-observation-lanes-v1.json`
  records the Swift/LLVM and Metal compiler observation lanes, including which
  lanes only have local AIR/metallib or runtime review evidence and which
  emitted-code observations remain required.
- `Evidence/ConstantTime/swift-llvm-metal-v1/hardware/hardware-observation-lanes-v1.json`
  records CPU wall-clock, direct Metal GPU, and power/contention/scheduler
  observation lanes with explicit non-certifying status.
- `Scripts/generate-constant-time-release-evidence.py` regenerates that release
  evidence from the local toolchain and `superneo-ct-observe` captures the
  direct Metal NumiSeal kernel observations.
- `Scripts/validate-constant-time-scope.py` checks the manifest, source
  markers, forbidden branch patterns, formal declarations, production-gate
  wiring, and release-policy wiring.
- `Scripts/validate-constant-time-lowering-evidence.py` checks that every
  source region is covered by a Swift/LLVM, Metal AIR, or runtime/hardware
  boundary, that the Lean whole-stack evidence declarations exist, that pinned
  release artifacts match their SHA-256 digests and byte counts, that compiler
  and hardware observation lane reports cover the checked regions, and that the
  promotion rule cannot be flipped silently.

The production gate runs both validators before release-readiness validation, so
source drift or Swift/LLVM/Metal lowering-evidence drift in the checked regions
fails closed.

## Source Scope

Checked source regions:

- `swift-goldilocks-common-arithmetic`: `GoldilocksField` addition,
  subtraction, negation, multiplication reduction, and mask canonicalization
  helpers.
- `swift-goldilocks-fixed-exponentiation`: `GoldilocksField.pow(_:)` fixed
  64-round square-and-multiply schedule with mask selection for the public
  exponent bit.
- `metal-goldilocks-common-arithmetic`: Metal Goldilocks add/sub/mul reduction
  helpers used by secret-bearing NumiSealZK kernels.
- `metal-numiseal-zk-secret-bearing-kernels`: NumiSeal mask application, dense
  fold, equality weights, sum-check accumulation, and fused mask accumulation.

The source validator rejects secret-dependent `if`, `guard`, `switch`,
`continue`, and similar branching patterns in the checked Swift regions. The
fixed-exponentiation region allows only the public fixed-width loop. For the
Metal NumiSeal kernels, only the public thread-bound guard
`if (id >= count) { return; }` is allowed.

## Metal Hardening

The common Metal Goldilocks helpers now use `ct_mask`, `ct_select_ulong`, and
mask-based canonicalization instead of source-level branches for carry folding,
subtraction, and 128-bit reduction. The NumiSeal equality-weight kernel uses the
same select helper instead of a ternary branch for per-element selection.

Sparse and small-coefficient optimized kernels remain performance kernels. They
are intentionally outside the secret-bearing constant-time source scope until
their data-dependent skips are removed or their inputs are proven public under a
narrow deployment model.

## Formal Scope

The Lean module proves that fixed schedules have traces independent of secret
inputs and that independence composes. The source manifest binds checked source
regions to the schedule declarations:

- `swiftGoldilocksAdd_traceIndependent`
- `swiftGoldilocksSub_traceIndependent`
- `swiftGoldilocksMulReduction_traceIndependent`
- `swiftGoldilocksPow64_traceIndependent`
- `metalGoldilocksCommonArithmetic_traceIndependent`
- `numiSealZKMaskKernelElement_traceIndependent`
- `sourceRegion_constantTrace_from_evidence`

This is a conditional proof layer: once source branch freedom, public schedule
classification, and compiler lowering preservation are established for a
region, the Lean theorem yields the constant-trace statement for that region.

## Swift/LLVM/Metal Lowering Contract

The lowering evidence manifest is the repository-owned bridge from source-level
trace proofs to a whole-stack constant-time statement. It covers:

- Swift frontend through optimized LLVM IR for `GoldilocksField` arithmetic and
  fixed exponentiation,
- Apple Metal frontend through AIR/object code for Goldilocks helper arithmetic,
- Apple Metal frontend through AIR/object code for NumiSealZK secret-bearing
  kernels, and
- runtime and hardware TCB obligations for allocation, ARC, copy-on-write,
  cache/scheduler observation, GPU scheduling, and power/contention scope.

`Formal/SuperNeoFormal/ConstantTime.lean` now defines
`CompilerLoweringEvidence`, `RuntimeBoundaryEvidence`,
`HardwareObservationEvidence`, `SwiftLLVMMetalStackEvidence`, and the
`swiftLLVMMetalWholeStack_constantTrace_from_evidence` theorem. That theorem is
intentionally evidence-parametric: if the release supplies source branch
freedom, compiler lowering preservation, runtime constraints, and hardware
observation constraints, the formal model composes them into a whole-stack
constant-trace claim for the fixed schedule.

The current manifest is a proof contract, not a hardware certificate.
`productionConstantTimeClaimAllowed` is checked as `false` until the release
toolchain artifacts, CPU/GPU observation corpora, and compiler/hardware
observation lanes are sufficient for the accepted threat model. This keeps
constant-time evidence out of proof bytes while making the unblock criteria
owned, explicit, and machine-checked.

## Pinned Local Release Evidence

`Scripts/generate-constant-time-release-evidence.py --skip-build` generated
`Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json` on the local Apple M4
lane. The manifest has `claimStatus = "local-release-evidence-pinned"` and
`productionConstantTimeClaimAllowed = false`.

Pinned artifacts:

- `metal/SuperNeoKernels.air`: Metal AIR object generated by
  `xcrun -sdk macosx metal -c`.
- `metal/SuperNeoKernels.metallib`: linked Metal library generated by
  `xcrun -sdk macosx metallib`.
- `metal/metal-artifacts-v1.json`: Metal source digest, toolchain versions,
  compile/link commands, output digests, covered Metal regions, and residual
  GPU-family boundaries.
- `runtime/runtime-allocation-review-v1.json`: static source-scope review of
  the checked Swift Goldilocks regions. The current status is
  `no-scope-local-allocation-or-cow-tokens-detected`.
- `observations/cpu-observation-corpus-v1.json`: local same-public-shape
  NumiSealZK CPU observation corpus under `zk-high-assurance-cpu`.
- `observations/gpu-observation-corpus-v1.json`: direct Metal timing corpus for
  `numiseal_apply_mask_kernel`, `numiseal_dense_fold_kernel`,
  `numiseal_eq_weight_kernel`, `numiseal_sumcheck_accumulate_kernel`, and
  `numiseal_mask_accumulate_kernel`, with CPU reference equality checked for
  every observed operation.
- `compiler/compiler-observation-lanes-v1.json`: compiler-observation lane
  report separating Swift lowering gaps from local Metal AIR/metallib pinning.
- `hardware/hardware-observation-lanes-v1.json`: hardware-observation lane
  report separating local CPU/GPU smoke corpora from power, contention, scheduler,
  counter, and broader-device requirements.

These files are release evidence, not proof bytes. They are deliberately local
and non-certifying: wall-clock and Metal command-buffer observations do not
prove microarchitectural constant-time behavior, and the AIR/metallib artifacts
do not replace Swift optimized SIL, LLVM IR, target assembly review, hardware
counters, power/contention testing, or broader Apple GPU-family coverage.

## Compiler And Hardware Observation Lanes

The release evidence now separates raw pinned artifacts from observation lanes:

- `swift-llvm-goldilocks-arithmetic`: the Swift source/runtime review is pinned,
  but optimized SIL, LLVM IR, and target assembly observations are still required.
- `metal-air-goldilocks-arithmetic`: local AIR/metallib artifacts are pinned for
  the Metal Goldilocks helper region; target GPU-family disassembly or equivalent
  compiler reports remain required.
- `metal-air-numiseal-zk-kernels`: local AIR/metallib artifacts are pinned for
  the NumiSealZK secret-bearing kernels; target GPU-family disassembly and
  buffer-layout signoff remain required.
- `cpu-wall-clock-zk-high-assurance`: the CPU NumiSealZK wall-clock corpus is
  pinned as local smoke evidence only.
- `gpu-direct-metal-kernel-observation`: the direct Metal kernel corpus is
  pinned as local smoke evidence only.
- `power-contention-scheduler-boundary`: power, contention, and scheduler effects
  remain outside the current release claim and are required before production
  constant-time language.

The validator requires all lanes to remain present and non-certifying. Adding a
new accepted compiler or hardware lane must update the lane report, manifest
digest, validator expectations, and promotion rule together.

## Remaining Work

- Record emitted SIL/LLVM and target assembly for Swift Bool-to-mask and select
  lowering, or replace the helper with a verified primitive.
- Extend the pinned Metal evidence from local AIR/metallib generation to
  selected GPU-family disassembly or equivalent compiler reports.
- Expand the local runtime allocation/COW static review and CPU/GPU smoke
  corpora into hardware-counter, power, contention, scheduler, and
  broader-device observation evidence under the accepted observation model.
- Check emitted code for the fixed-exponentiation select path and keep
  inversion's zero rejection outside the secret-bearing lane unless callers can
  prove nonzero inputs before entry.
- Decide whether sparse and small-coefficient optimized kernels are public-input
  kernels only, or rewrite them as fixed-work kernels for secret-bearing use.
