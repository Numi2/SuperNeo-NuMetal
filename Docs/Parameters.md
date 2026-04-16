# SuperNeo Parameters

This repository implements one public parameter profile: `Goldilocks/Phi81(d=54)`.
The code-level entry point is `SuperNeoParameterProfile.goldilocksPhi81`; the
older `goldilocksPhi54` spelling is deprecated because the cyclotomic polynomial
is `Phi_81(X) = X^54 + X^27 + 1`, whose degree is 54.

## Paper Mapping

The bundled `superneopaper.md` describes SuperNeo as a lattice-based folding
scheme for CCS with:

- plausible post-quantum security under Module-SIS for Ajtai commitments,
- pay-per-bit commitment costs from norm-preserving embeddings,
- field-native sum-check and norm checks over a small field extension,
- support for general non-SIMD CCS,
- native Goldilocks support, and
- low recursion overhead relative to ring-sum-check lattice approaches.

This is a paper-claim mapping, not the repository's production-security claim.
The current parameter-security position is narrower and is recorded in
`Docs/ParameterSecurityDossier-2026-04-16.md`.

The implemented protocol follows the paper's SuperNeo stack:

- `PiCCS`: a sum-check reduction from CCS and prior CE claims to CE claims.
- `PiRLC`: a random linear combination of CE claims using ring challenges from a strong sampling set.
- `PiDEC`: decomposition of the larger-norm folded claim back into small-norm CE claims.

The implementation names these stages in `FoldProof` as `piCCS`, `piRLC`, and
`piDEC`. A fold reduction is accepted only after these stages verify; terminal
acceptance requires the CE opening relation to verify for the reduction outputs.

## Profile Constants

| Quantity | Implemented value | Code source |
| --- | ---: | --- |
| Profile name | `Goldilocks/Phi81(d=54)` | `SuperNeoParameterProfile.goldilocksPhi81` |
| Profile ID | `1` | `SuperNeoParameters.profileID` |
| Base field | `q = 2^64 - 2^32 + 1` (`0xFFFF_FFFF_0000_0001`) | `GoldilocksField.modulus` |
| Extension field | degree 2 over Goldilocks, `u^2 = 7` | `GoldilocksExt2.nonResidue` |
| Cyclotomic index | `81` | `SuperNeoParameterProfile.cyclotomicIndex` |
| Ring polynomial | `X^54 + X^27 + 1` | `CyclotomicRing54.reduce` and profile relation |
| Ring degree | `54` | `CyclotomicRing54.degree` |
| Ajtai rows | `kappa = 18` | `SuperNeoParameters.kappa` |
| Norm bound | `b = 2` | `SuperNeoParameters.normBound` |
| Norm roots | `[-1, 0, 1]` | `SuperNeoParameters.normRoots` |
| Decomposition length | `14` | `SuperNeoParameters.decompositionLength` |
| RLC challenge coefficients | `[-2, -1, 0, 1, 2]` | `SuperNeoParameters.challengeCoefficients` |
| Challenge expansion factor | `216` | `SuperNeoParameters.challengeExpansionFactor` |
| Maximum fresh batch count | `61` | `SuperNeoParameters.maxFreshBatchCount` |
| Maximum prior CE count | `14` | `SuperNeoParameters.maxPriorClaimCount` |
| Claimed profile security | `129` bits | `SuperNeoParameters.claimedSecurityBits` |

These constants match Appendix B.2 of the bundled paper text: Goldilocks,
`eta = 81`, `Phi = X^54 + X^27 + 1`, `d = 54`, `kappa = 18`, `b = 2`,
`k = 14`, fresh-batch count `K in [61]`, `B = 2^14`,
challenge coefficient set `[-2, -1, 0, 1, 2]`, `T = 216`,
extension challenge field `F_q^2`, and an estimated
`MSIS` hardness of about 129 bits.

## Embedding And Work Model

SuperNeo embeds a field vector by splitting it into chunks of 54 field elements
and storing each chunk as the coefficient vector of one ring element in
`F[X] / (X^54 + X^27 + 1)`. This is the code path exposed by
`SuperNeoEmbedding.pack` and `packPadded`.

The paper's key property for this profile is norm preservation: small field
coefficients remain small ring coefficients. The commitment cost is therefore
driven by the number and magnitude of active witness coefficients rather than by
full-width field-element multiplication in every slot. The implementation tracks
this through `AjtaiCommitmentWorkProfile` and uses sparse/small-coefficient
paths in the CPU and Metal commit kernels.

## Security Estimate Scope

The `129`-bit value is a profile claim inherited from the paper's concrete
parameter analysis. The repository now includes a pinned reproduction harness
for Appendix D.8:

```sh
Scripts/reproduce-lattice-estimator.sh --dry-run lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status not_run --expect-latest-status absent lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
```

Dry-run mode records the exact `SIS.Parameters` inputs for this profile. Full
mode requires SageMath and the upstream `malb/lattice-estimator` checkout pinned
in the script. Treat the estimate as independently reproduced only when the
pinned lane reports estimator status `ran` and validation requires the 129-bit
threshold. Latest-upstream runs are available for drift monitoring, not for
replacing the pinned evidence lane.

The estimator input is a coefficient-expanded SIS encoding of the protocol's
Module-SIS/ring commitment claim: `n = kappa * d`, `m = 2^30`,
`length_bound = sqrt(m) * (8 * T * b^k)`, `q` is the Goldilocks modulus, and
`norm = 2`. This translation is documented in
`Docs/LatticeEstimatorReproduction.md`.

This harness does not convert the research analysis into a production
cryptographic certification.

The full assumption and Fiat-Shamir position is recorded in
`Docs/ParameterSecurityDossier-2026-04-16.md`. That dossier is the controlling
security-position document for the implemented profile. In particular, it records
that the pinned default estimator lane clears 129 bits, while sampled quantum and
more conservative reduction-cost models for the same `SIS.Parameters` tuple do
not support a 128-bit quantum claim.

Treat the implemented profile as:

- a faithful code-level profile for research and benchmarking,
- backed by a reproduced 129-bit default estimator lane under the paper's
  stated Module-SIS analysis, and
- not yet an audited production parameter set.

Any change to `kappa`, ring degree, challenge set, decomposition length,
norm bound, field modulus, or transcript domains creates a different profile and
must be documented as a new profile ID.
