# Constant-Time Evidence

This note records the current constant-time evidence surface for release
candidate packets. It is a research evidence index, not a production
constant-time certification.

## Checked Inputs

- `TestVectors/constant-time-scope-v1.json` pins the first theorem-facing
  secret-bearing source/formal scope and the corresponding Lean trace model.
- `TestVectors/constant-time-lowering-evidence-v1.json` pins the Swift, LLVM,
  and Metal lowering evidence contract and points to the local release evidence
  manifest.
- `Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json` records the current
  local emitted-artifact review packet.
- `Evidence/ConstantTime/swift-llvm-metal-v1/compiler/compiler-lowering-audit-v1.json`
  records the scoped Swift SIL/LLVM/ARM64 and Metal AIR/metallib lowering
  audit, including pinned `metal-objdump` output for the release metallib.

## Current Boundary

The evidence covers only the scoped local source/formal/lowering slices plus
the pinned compiler/lowering audit for the current toolchain. It does not claim
complete CPU cache, allocator, Metal GPU-family timing, power, contention,
failure-path, or hardware-counter closure.

Repository-local constant-time evidence is pinned for the scoped
source/formal/lowering slices, but production whole-stack constant-time claims
are not enabled. Broader hardware lanes, power/contention coverage, and
expanded hardware-counter corpora are still required before claiming full
side-channel certification.
