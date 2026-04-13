# Paper Reproduction Harness

This repository includes a reproduction harness for the bundled
`superneopaper.md`. The harness maps paper claims to concrete repository
commands, benchmark selectors, logs, test vectors, lattice-estimator parameter
artifacts, and generated reports.

It is an implementation artifact. It does not re-prove the paper's theorems.
Appendix D.8 estimator execution is available through a separate Sage-backed
command and should only be cited when the generated JSON's pinned reproduction
lane reports estimator status `ran` and validation requires the 129-bit
threshold.

Formal status: bounded formalization.

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

Include the canonical pinned Sage/lattice-estimator lane when Sage is available:

```sh
Scripts/reproduce-superneo-paper.sh quick --with-full-estimator
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
| `lattice-estimator/` | Dry-run Module-SIS parameter artifact by default, or pinned full estimator output when `--with-full-estimator` is used. |

## Claim Families

The harness currently tracks these paper-to-repository claims:

- `D1-parameters-module-sis-profile`: Appendix B.2 constants and the claimed
  129-bit Module-SIS profile, plus exact derived and validated estimator
  inputs. Pinned full runs are the only docs-facing estimator reproduction lane;
  latest-upstream runs are drift monitoring only.
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
- independent Module-SIS hardness estimation unless the pinned non-dry-run
  lattice-estimator command completed successfully and validation required the
  129-bit threshold,
- latest-upstream estimator output as a replacement for the pinned reproduction
  baseline,
- formal side-channel resistance,
- malicious-host resistance,
- correctness of third-party integrations, or
- that a fold-reduction vector is a complete terminal proof.

Fold-reduction artifacts must continue to report that terminal CE relation
verification is required.
