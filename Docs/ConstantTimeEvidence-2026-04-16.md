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
- `Scripts/validate-constant-time-scope.py` checks the manifest, source
  markers, forbidden branch patterns, formal declarations, production-gate
  wiring, and release-policy wiring.

The production gate runs the validator before release-readiness validation, so
source drift in the checked regions fails closed.

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

## Remaining Work

- Check emitted SIL/LLVM for Swift Bool-to-mask lowering or replace the helper
  with a verified primitive.
- Record compiler lowering evidence for the selected Metal integer operations
  under pinned Xcode/Apple clang versions.
- Model or constrain allocator, ARC, array copy-on-write, cache, power, and
  scheduler observations.
- Check emitted code for the fixed-exponentiation select path and keep
  inversion's zero rejection outside the secret-bearing lane unless callers can
  prove nonzero inputs before entry.
- Decide whether sparse and small-coefficient optimized kernels are public-input
  kernels only, or rewrite them as fixed-work kernels for secret-bearing use.
