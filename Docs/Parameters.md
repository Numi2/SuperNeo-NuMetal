# SuperNeo Parameters

This note is the paper-facing parameter entry point for the implemented
Goldilocks/Phi81 profile. It is a pointer to implementation constants,
estimator reproduction, and focused tests, not a separate security proof.

## Implemented Profile

| Item | Value |
| --- | --- |
| Base field | Goldilocks, `q = 18446744069414584321` |
| Ring | `F_q[X] / (X^54 + X^27 + 1)` |
| Cyclotomic index | `81` |
| Ring degree | `54` |
| Ajtai rows | `kappa = 18` |
| Source norm bound | `2` |
| Decomposition length | `14` |
| Challenge coefficients | `[-2, -1, 0, 1, 2]` |
| Strong-sampling expansion | `216` |
| Selected fresh batch bound | `61` |
| Selected prior CE bound | `14` |
| Estimator threshold | `129` ROP bits in the pinned paper lane |

The source of truth for these values is the Swift profile plus the parameter
notes:

- `SuperNeoParameterProfile.goldilocksPhi81`
- [ParameterSecurityDossier-2026-04-16.md](ParameterSecurityDossier-2026-04-16.md)

## Validation

Run the shape/profile guard:

```bash
swift test --disable-swift-testing --filter ProtocolShapeTests/testGoldilocksParameterProfileMatchesPaperProfile
```

Run the estimator parameter reproduction in dry-run mode:

```bash
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
```

Run the pinned Sage-backed estimator lane only when the Sage/lattice-estimator
toolchain is present:

```bash
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
```

## Claim Boundary

The repository may claim implementation consistency for the selected profile
when the focused tests and estimator reproduction match the documented values.
It must not claim general production post-quantum security, QROM deployment
security, whole-stack side-channel security, or estimator robustness beyond the
pinned lane.
