# Ajtai Key Dimension Hardening, 2026-04-13

This pass closes a remaining fail-closed gap in seeded Ajtai key generation.
The implementation already checked matrix dimensions when constructing a
`RingMatrix`, but `AjtaiCommitmentKey(parameters:columns:seed:)` multiplied
`kappa * columns` before allocation and RNG expansion. An adversarially large
column count could therefore trap on `Int` overflow instead of returning a
typed `SuperNeoError`.

## Finding

- Seeded Ajtai key generation accepted any positive `columns` value and used a
  direct `parameters.kappa * columns` product for `reserveCapacity` and loop
  bounds.
- The matrix constructor would have rejected inconsistent dimensions later, but
  the unchecked product happened before that constructor was reached.

## Work Completed

- Added an explicit checked multiplication step before seeded key material is
  generated.
- Invalid dimensions now fail closed with
  `SuperNeoError.invalidParameter("Ajtai key dimensions overflow")`.
- Added a regression test that exercises the overflow boundary without
  allocating key material:
  `CommitmentCoreTests/testTier0AjtaiSeededKeyRejectsDimensionOverflowBeforeAllocation`.

## Verification

```sh
swift test --disable-swift-testing --filter CommitmentCoreTests/testTier0AjtaiSeededKeyRejectsDimensionOverflowBeforeAllocation
```

Result: passed.

## Residual Boundary

This guard prevents integer-overflow traps during seeded key generation. It is
not a general resource quota for intentionally huge but representable keys;
embedding applications should still enforce workload-specific key-size policy
before accepting untrusted dimensions.
