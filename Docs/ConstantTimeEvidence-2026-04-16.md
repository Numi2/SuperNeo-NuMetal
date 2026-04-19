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

## Current Boundary

The evidence covers only the scoped local source/formal/lowering slices. It
does not claim complete CPU, Swift optimizer, LLVM, allocator, Metal AIR,
metallib, GPU timing, power, contention, failure-path, or hardware-counter
closure.

Repository-local production constant-time claims are enabled for the scoped
source/formal/lowering slices pinned by the release evidence. Broader hardware
lanes, power/contention, and expanded hardware-counter corpora remain outside
that repository-local claim.
