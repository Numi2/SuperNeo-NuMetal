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
parameter analysis. This repository does not independently run or reproduce the
lattice-estimator scripts in Appendix D.8, and it does not convert the research
analysis into a production cryptographic certification.

Treat the implemented profile as:

- a faithful code-level profile for research and benchmarking,
- plausibly post-quantum under the paper's Module-SIS analysis, and
- not yet an audited production parameter set.

Any change to `kappa`, ring degree, challenge set, decomposition length,
norm bound, field modulus, or transcript domains creates a different profile and
must be documented as a new profile ID.
