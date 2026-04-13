# Workload Key-Seed Domain Separation, 2026-04-13

This pass makes CLI default Ajtai key seeds parameter-aware for bundled
workloads while preserving the checked-in 8-bit vector compatibility boundary.

## Finding

- The binary-addition CLI default key seed was
  `SuperNeoCLI.binary-addition.u8.v1` for every `--operand-bits` value.
- The verifier still bound artifacts to the regenerated verifier-key digest, so
  this was not a proof-verification bypass. The issue was a domain-separation
  and auditability weakness: generated non-8-bit artifacts could carry a seed
  label that described the wrong operand width.

## Work Completed

- Added `SuperNeoWorkloadKeySeed` as the shared seed-policy surface.
- Kept existing 8-bit seeds stable:
  - `SuperNeoCLI.one-hot-vector.v1`
  - `SuperNeoCLI.binary-addition.u8.v1`
- Added parameter-separated defaults for other generated workloads, such as:
  - `SuperNeoCLI.one-hot-vector.u4.v1`
  - `SuperNeoCLI.binary-addition.u16.v1`
- Routed CLI proof generation through the shared helper instead of a
  CLI-private switch.
- Added unit coverage for vector-compatible 8-bit seeds, non-8-bit separation,
  and invalid binary-addition widths.

## Verification

```sh
swift test --disable-swift-testing --filter UsabilitySurfaceTests/testWorkloadDefaultKeySeedsAreParameterSeparatedAndVectorCompatible
```

Result: passed.

## Residual Boundary

This helper defines deterministic demo and test-vector seed labels. Production
embedding code should still own key lifecycle, provenance, rotation, and
trusted verifier-key digest distribution rather than treating a seed string as a
security policy.
