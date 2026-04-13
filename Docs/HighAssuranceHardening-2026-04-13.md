# High-Assurance Hardening Pass, 2026-04-13

This pass addresses three previously explicit boundaries: side-channel posture,
independent lattice-estimator reproduction, and untrusted Metal execution.

## Findings

- The optimized CPU commitment and transformed-evaluation paths used
  witness-dependent zero skipping. That is appropriate for benchmarking sparse
  witnesses, but it is not the right default for callers treating local witness
  values as secrets against a co-resident observer.
- Metal outputs were covered by differential tests and workspace digests, but
  callers had no explicit API mode that recomputed GPU-produced proof material
  on CPU before use.
- The parameter documentation inherited the paper's `129`-bit Module-SIS
  estimate. The repository did not have a pinned command that derives the exact
  `SIS.Parameters(...)` tuple for the implemented `Goldilocks/Phi81(d=54)`
  profile.

## Work Completed

- Added `SuperNeoExecutionPolicy`.
  - `.default` preserves existing optimized behavior.
  - `.cpuRedundantMetal` keeps Metal enabled and rejects Metal commitment or
    transformed-evaluation outputs that do not match the CPU oracle.
  - `.highAssurance` disables secret-bearing Metal work in the prover and uses
    constant-work CPU commitment/evaluation primitives for covered local
    witness paths.
- Added `AjtaiCommitter.commitConstantWorkReference(...)` for ring-message and
  field-witness commitments. It performs fixed row/column/coefficient loops
  instead of sparse witness-term iteration.
- Added a constant-work Phi81 ring product and routed prover-side folded
  witness random-linear-combination through it under `.highAssurance`.
- Added constant-work transformed sparse ring matrix-vector multiplication and
  transformed extension-row evaluation for CE and local opening paths selected
  by the execution policy.
- Threaded the execution policy through prover fold generation, terminal CE
  proof generation, public CE proof verification, terminal local verification,
  CCS normalization commitments, and CPU-redundant Metal target/private-linear
  preparation.
- Added policy-aware `SuperNeoMetalWorkspace` methods so direct workspace users
  can request CPU-only or CPU-redundant behavior instead of bypassing the
  protocol-level checks.
- Added tests for constant-work commitment equality, high-assurance CPU fold
  equality, and CPU-redundant Metal fold verification.
- Added `Scripts/reproduce-lattice-estimator.sh`,
  `Scripts/reproduce-lattice-estimator.py`, and
  `Scripts/validate-lattice-estimator-artifact.py`.
  - Dry-run mode records the exact derived Module-SIS parameters:
    `n_sis = 972`, `m_sis = 1073741824`, and
    `length_bound_l2 = 927712935936`.
  - Full mode pins `malb/lattice-estimator` at commit
    `8d38f52c0bcc46f23d697c9c592bad50df0b124b` and runs through Sage's
    Python runtime.

## Residual Boundaries

- The new CPU paths are constant-work with respect to the largest local
  witness-dependent branches in this repository. They are not a formal
  constant-time proof for Swift, LLVM, Apple CPUs, memory allocation, or power
  analysis.
- `.cpuRedundantMetal` catches incorrect Metal outputs for covered commitment
  and transformed-evaluation calls. It does not defend against a compromised
  host process that can alter both the Metal and CPU results, alter verifier
  inputs, or skip verification.
- The lattice-estimator harness is independent repository automation, not a new
  cryptographic proof. Dry-run artifacts do not reproduce the claimed
  `129`-bit estimate; only pinned non-dry-run artifacts with estimator status
  `ran` and `--require-claimed-security` validation should be cited for
  estimator execution. Latest-upstream runs are drift monitoring only.

## Commands

```sh
swift test --disable-swift-testing --filter CommitmentCoreTests/testTier0AjtaiConstantWorkReferenceMatchesOptimizedReference
swift test --disable-swift-testing --filter ProtocolSmokeTests/testHighAssuranceCPUFoldMatchesOptimizedProof
swift test --disable-swift-testing --filter MetalDifferentialTests/testTier0CPURedundantMetalPolicyVerifiesFoldOutputs
Scripts/reproduce-lattice-estimator.sh --dry-run /tmp/superneo-lattice-estimator.json
Scripts/validate-lattice-estimator-artifact.py --expect-status not_run --expect-latest-status absent /tmp/superneo-lattice-estimator.json
```
