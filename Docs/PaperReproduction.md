# Paper Reproduction Harness

This repository includes a reproduction harness for the bundled
`superneopaper.md`. The harness maps paper claims to concrete repository
commands, benchmark selectors, logs, test vectors, and generated reports.

It is an implementation artifact. It does not re-prove the paper's theorems, and
it does not independently rerun the lattice-estimator scripts referenced by
Appendix D.8.

## Command

Generate a claim map without running expensive tests or benchmarks:

```sh
Scripts/reproduce-superneo-paper.sh plan
```

Render the current `benchmark-results/` directory into a paper-reproduction
artifact:

```sh
Scripts/reproduce-superneo-paper.sh snapshot
```

Run the quick profile and render a new artifact:

```sh
Scripts/reproduce-superneo-paper.sh quick
```

Run scaling or full profiles on pinned Apple Silicon hardware:

```sh
Scripts/reproduce-superneo-paper.sh scaling
Scripts/reproduce-superneo-paper.sh full
```

Generated artifacts are written under `paper-reproduction/<timestamp>-<mode>/`.
That directory is ignored by git because it contains local machine logs and
benchmark exports.

## Output Layout

| Path | Meaning |
| --- | --- |
| `claim-map.json` | Machine-readable mapping from paper claim to repository evidence, commands, benchmark selectors, and generated artifacts. |
| `commands.sh` | Pinned command list for the artifact. |
| `report.md` | Human-readable claim map plus benchmark timing summary when `results.json` is present. |
| `environment.txt` | Git, Swift, macOS, and hardware metadata. |
| `logs/` | Command output captured by the harness. |
| `benchmark-results/` | Copied benchmark `results.json`, `metadata.json`, and `report.md`. |
| `test-vectors/` | Copied public test vectors used by the reproduction checks. |

## Claim Families

The harness currently tracks these paper-to-repository claims:

- `D1-parameters-module-sis-profile`: Appendix B.2 constants and the claimed
  129-bit Module-SIS profile.
- `D2-pay-per-bit-commitment-cost-model`: norm-preserving embedding and
  small-coefficient Ajtai work profile.
- `D3-field-native-folding-stages`: PiCCS, PiRLC, PiDEC, fold, and reduction
  verifier execution.
- `D4-general-ccs-not-simd-only`: R1CS builder, CCS normalizer, one-hot workload,
  binary-addition workload, and golden vector verification.
- `D5-small-field-goldilocks-native`: Goldilocks, extension-field, and Phi81 ring
  arithmetic gates.
- `D6-low-recursion-overhead-proxy`: bounded decomposition outputs and the
  explicit reduction-versus-terminal verification split.
- `apple-silicon-metal-acceleration`: CPU/Metal differential correctness and
  Metal benchmark selectors.

## Required Interpretation

A passing artifact means the implementation matches the checked paper-derived
profile constants, runs the relevant protocol stages, verifies the public proof
envelope and golden vector, and records benchmark rows for the selected profile.

It does not mean:

- production cryptographic certification,
- independent Module-SIS hardness estimation,
- side-channel resistance,
- malicious-driver resistance,
- correctness of third-party integrations, or
- that a fold-reduction vector is a complete terminal proof.

Fold-reduction artifacts must continue to report that terminal CE relation
verification is required.
