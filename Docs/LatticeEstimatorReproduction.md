# Lattice Estimator Reproduction

The implemented `Goldilocks/Phi81(d=54)` profile inherits the paper's
Module-SIS estimate. This repository now includes a pinned harness for
reproducing the exact estimator input tuple and, when SageMath is installed,
running the upstream lattice-estimator.

## Commands

Record the exact parameters without running the estimator:

```sh
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
```

Run the estimator through Sage:

```sh
Scripts/reproduce-lattice-estimator.sh lattice-estimator-results/superneo-goldilocks-phi81.json
```

Validate an artifact's pinned source, profile constants, derived SIS tuple, and
status:

```sh
Scripts/validate-lattice-estimator-artifact.py --expect-status not_run lattice-estimator-results/superneo-goldilocks-phi81.json
```

The full command clones or reuses
`https://github.com/malb/lattice-estimator.git` at pinned commit
`8d38f52c0bcc46f23d697c9c592bad50df0b124b`.

## Implemented GL Profile Parameters

| Quantity | Value |
| --- | ---: |
| `q` | `2^64 - 2^32 + 1` |
| `kappa` | `18` |
| `d` | `54` |
| `b` | `2` |
| `k` | `14` |
| `K` | `61` |
| `T` | `216` |
| `n_sis = kappa * d` | `972` |
| `m_sis = (2^30 / d) * d` | `1073741824` |
| `length_bound_l2 = sqrt(m_sis) * (8 * T * b^k)` | `927712935936` |

The strong-sampling inequality from Appendix D.8 is also recorded:

```text
(K + k) * T * (b - 1) = 16200 < b^k = 16384
```

## Interpretation

A dry-run artifact is a parameter lock and formula check. It must not be cited
as an estimator run. A full artifact may be cited for estimator reproduction only
when its JSON contains `"estimator": { "status": "ran", ... }`.
For full artifacts used to support the 129-bit claim, run the validator with
`--expect-status ran --require-claimed-security`.

The output is still an implementation reproducibility artifact. It does not turn
the parameter set into an audited production cryptographic certification.
