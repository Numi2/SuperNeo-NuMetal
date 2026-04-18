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

Production constant-time claims remain disabled until the selected release
hardware lanes are reviewed, the missing emitted-code and runtime observations
are archived, and the selected-depth loss budget receives an instantiated
`epsilon_ct` term.
