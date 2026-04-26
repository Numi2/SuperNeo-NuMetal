# Paper Reproduction

The paper-reproduction harness maps claims in
[superneopaper.md](../SuperNeo-NuMetal/SuperNeo_NuMetal.docc/superneopaper.md)
to repository commands, evidence files, benchmark selectors, and generated
artifacts.

## Commands

Generate the claim map and report skeleton:

```bash
Scripts/reproduce-superneo-paper.sh plan
```

Render from existing benchmark outputs:

```bash
Scripts/reproduce-superneo-paper.sh snapshot
```

Run benchmark-backed reproduction artifacts:

```bash
Scripts/reproduce-superneo-paper.sh quick
Scripts/reproduce-superneo-paper.sh scaling
Scripts/reproduce-superneo-paper.sh full
```

Run the pinned Sage-backed estimator lane when available:

```bash
Scripts/reproduce-superneo-paper.sh quick --with-full-estimator
```

## Outputs

The default output directory is `paper-reproduction/<timestamp>-<mode>/`.
Each artifact contains:

- `claim-map.json`,
- `commands.sh`,
- `report.md`,
- `environment.txt`,
- `logs/`,
- `benchmark-results/`,
- `payperbit-profile/`,
- `test-vectors/`,
- and `lattice-estimator/`.

## Interpretation

A passing artifact supports the listed implementation-reproduction claims. It
does not re-prove the paper, certify production deployment security, or turn
ideal QRO/QROM theorem assumptions into concrete-hash deployment claims. Those
boundaries remain governed by [WhatThisProves.md](WhatThisProves.md),
[QROProductArchitecture-2026-04-25.md](QROProductArchitecture-2026-04-25.md),
and [HighAssuranceHardening-2026-04-13.md](HighAssuranceHardening-2026-04-13.md).
