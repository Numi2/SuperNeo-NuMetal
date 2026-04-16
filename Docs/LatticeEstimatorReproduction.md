# Lattice Estimator Reproduction

The implemented `Goldilocks/Phi81(d=54)` profile inherits the paper's
Module-SIS estimate. This repository has two separate estimator lanes:

- **Pinned reproduction:** canonical, docs-facing evidence from a reviewed
  `malb/lattice-estimator` commit.
- **Latest-upstream monitoring:** drift evidence only. It records the current
  upstream HEAD and whether that run still clears the paper threshold, but it
  does not replace the pinned baseline.

## Commands

Record the exact translated estimator parameters without Sage:

```sh
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status not_run --expect-latest-status absent lattice-estimator-results/superneo-goldilocks-phi81.json
```

Run the canonical pinned estimator lane through Sage:

```sh
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
```

Run pinned reproduction plus latest-upstream monitoring:

```sh
Scripts/reproduce-lattice-estimator.sh --full --pinned --latest lattice-estimator-results/superneo-goldilocks-phi81-latest-monitoring.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status ran --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81-latest-monitoring.json
```

The pinned lane uses
`https://github.com/malb/lattice-estimator.git` at commit
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

## Module-SIS Translation

The estimator run encodes the protocol's ring/module commitment instance as a
coefficient-expanded SIS problem:

| `SIS.Parameters` field | Value | Translation |
| --- | ---: | --- |
| `n` | `972` | `kappa * d`, with `kappa = 18` and Phi81 degree `d = 54` |
| `q` | `18446744069414584321` | Goldilocks modulus `2^64 - 2^32 + 1` |
| `m` | `1073741824` | Appendix D.8 coefficient-expanded length `2^30` |
| `length_bound` | `927712935936` | `sqrt(m_sis) * (8 * T * b^k)` |
| `norm` | `2` | lattice-estimator norm selector used by the paper script |

This translation is a way to feed the paper's Module-SIS parameter claim into a
SIS estimator that supports the relevant attacks. It is not a native formal
statement about the quotient ring and it is not a production cryptographic
certification.

## Artifact Semantics

Artifacts use schema `superneo.lattice-estimator.v2`.

- `pinned_reproduction` contains the canonical lane. The top-level
  `claimed_security_reproduced_under_pinned_toolchain` field is true only when
  this lane ran and cleared the 129-bit threshold.
- `latest_monitoring` contains the optional HEAD-tracking lane. The top-level
  `latest_upstream_still_clears_threshold` field is null unless that lane ran.
- `paper_claim_threshold_bits` is fixed to `129`.

Latest-upstream output is useful for maintenance. It must be cited as drift
monitoring, not as the canonical reproduction claim.

## Interpretation

A dry-run artifact is a parameter lock and formula check. It must not be cited
as an estimator run. A pinned full artifact may be cited for estimator
reproduction only when validation passes with:

```sh
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security <artifact>
```

The output is still an implementation reproducibility artifact. It does not turn
the parameter set into an audited production cryptographic certification.

## Alternate Cost-Model Audit

The canonical artifact records the default estimator lane. A security dossier
must also account for the sensitivity of the same `SIS.Parameters` tuple under
alternate reduction-cost models. The 2026-04-16 manual audit using the same
pinned estimator checkout produced:

| Cost model | Estimated rop bits | beta | d |
| --- | ---: | ---: | ---: |
| default MATZOV | `129.1` | `345` | `3129` |
| ADPS16 classical | `100.7` | `345` | `3129` |
| ADPS16 quantum | `91.4` | `345` | `3129` |
| ADPS16 paranoid | `71.6` | `345` | `3129` |
| ChaLoy21 | `88.7` | `345` | `3129` |
| LaaMosPol14 | `122.4` | `345` | `3129` |

These alternate rows are not currently release-gated by
`Scripts/reproduce-lattice-estimator.sh`. They are included here to prevent
overstating the profile: the implemented `kappa = 18` profile clears the paper's
default lane, not a broad 128-bit quantum-security target across common costing
models. See `Docs/ParameterSecurityDossier-2026-04-16.md` for the full
parameter-security position.
