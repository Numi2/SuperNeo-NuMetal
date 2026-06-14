# Lattice Estimator Reproduction

This note records how the paper's Module-SIS parameter claim is reproduced in
the repository.

## Modes

- `--dry-run` records the exact estimator inputs derived from the implemented
  Goldilocks/Phi81 profile. It does not execute the Sage estimator and therefore
  does not reproduce the 129-bit claim.
- `--full --pinned` executes the canonical pinned Sage/lattice-estimator lane
  and is the only lane that may set
  `claimed_security_reproduced_under_pinned_toolchain = true`.
- `--full --pinned --latest` is monitoring for upstream drift. It is not the
  paper claim source.

## Commands

```bash
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
```

```bash
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
```

## Maintained Inputs

The current input derivation is documented in [Parameters.md](Parameters.md) and
[ParameterSecurityDossier-2026-04-16.md](ParameterSecurityDossier-2026-04-16.md).
The generated artifact code is
[Scripts/reproduce-lattice-estimator.py](../Scripts/reproduce-lattice-estimator.py).

## Sensitivity Policy

Any change to `q`, the Phi81 relation, `kappa`, decomposition length, challenge
support, expansion factor, selected fresh/prior bounds, or norm bound requires:

- regenerating the estimator artifact,
- rerunning the profile-shape test,
- updating [ParameterSecurityDossier-2026-04-16.md](ParameterSecurityDossier-2026-04-16.md),
- updating [Parameters.md](Parameters.md),
- and keeping production PQ wording out of scope until the parameter change has
  independent cryptographic review.
