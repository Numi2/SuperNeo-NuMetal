# Parameter Security Dossier, 2026-04-16

Scope: the implemented `Goldilocks/Phi81(d=54)` profile only.

Status: research parameter dossier. The profile has exact implementation
constants, a pinned default lattice-estimator reproduction at 129.1 bits, and
Lean-side finite bad-seed accounting. It does not yet support NIST security
category language, production post-quantum claims, or a QROM Fiat-Shamir theorem.

## Bottom Line

The implemented profile is internally specified and reproducible, but its public
security statement must be narrow:

> Binding is assumed from the stated Module-SIS/no-short-kernel problem for
> certified Ajtai keys over `R_q = F_q[X] / (X^54 + X^27 + 1)`, with the exact
> coefficient-expanded estimator tuple below. Non-interactive soundness is
> modeled in the ROM/finite-bad-seed ledger, not proved in the QROM.

The pinned estimator lane clears the repository's `129`-bit threshold only under
the default MATZOV reduction-cost model used by the reproduction artifact.
Common quantum or more conservative cost models give lower bit estimates for
the same block size. Therefore this profile should not be described as a NIST
category-1-equivalent or production PQ parameter set.

## External Baseline

NIST's current approved PQC FIPS set is FIPS 203 ML-KEM, FIPS 204 ML-DSA, and
FIPS 205 SLH-DSA. NIST's PQC project page says Falcon/FN-DSA is still the
FIPS 206 standardization path, not part of the first approved three-standard
set. The bar those documents set is precise algorithms, parameter sets,
failure conditions, and category claims. This repository is not at that bar.

## Exact Module-SIS Statement

Let:

- `q = 2^64 - 2^32 + 1 = 18446744069414584321`.
- `F_q` be the Goldilocks prime field.
- `R_q = F_q[X] / (X^54 + X^27 + 1)`.
- `d = 54`, `kappa = 18`, and `n_sis = kappa * d = 972`.
- `m_sis = 2^30 = 1073741824` coefficient-expanded columns.
- `B = b^k = 2^14 = 16384`.
- `L_2 = sqrt(m_sis) * (8 * T * B) = 927712935936`.

The concrete SIS estimator challenge is:

> Given a coefficient-expanded Ajtai matrix `A` corresponding to an
> `R_q`-linear map with `kappa = 18` ring rows and at most `m_sis`
> coefficient-expanded columns, find a nonzero integer coefficient vector
> `z` such that `A z = 0 mod q` and `||z||_2 <= 927712935936`.

The protocol-level assumption is the matching Module-SIS/no-short-kernel
assumption:

> For honestly generated, verifier-pinned, certified Ajtai keys, no efficient
> classical or quantum adversary can find a nonzero bounded-difference opening
> vector in the kernel of the `R_q`-linear commitment map, where the
> coefficient expansion of that vector is within the estimator target above.

The Lean model does not assert hardness for arbitrary matrices. It consumes a
`VerifiedAjtaiKernelCertificate`; the formal files explicitly reject the false
claim that arbitrary matrices have no short kernel. A real deployment theorem
would still need a distributional key-generation theorem that connects the
implemented key sampler to this Module-SIS assumption.

## Exact Implemented Parameters

| Quantity | Implemented value |
| --- | ---: |
| Profile | `Goldilocks/Phi81(d=54)` |
| Profile ID | `1` |
| Proof envelope version | `4` |
| Proof envelope header bytes | `141` |
| Transcript-binding context bytes | `137` (`bodyLength` excluded) |
| Field modulus | `18446744069414584321` |
| Extension field | degree 2, `u^2 = 7` |
| Ring | `F_q[X] / (X^54 + X^27 + 1)` |
| Ring degree | `54` |
| Ajtai rows | `kappa = 18` |
| Norm bound for decomposed CE claims | `b = 2` |
| Small digit set | `{-1, 0, 1}` |
| Decomposition length | `k = 14` |
| Folded bound | `B = 2^14 = 16384` |
| RLC challenge coefficients | `{-2, -1, 0, 1, 2}` |
| Phi81 challenge-seed support | `5^54` |
| Challenge expansion factor | `T = 216` |
| Maximum fresh CCS claims | `61` |
| Maximum prior CE claims | `14` |
| Maximum per-fold aggregate count | `75` |
| PiCCS challenge field | `F_q^2` |
| Terminal CE challenge symbols | `3` |
| Terminal CE rounds | `219` |
| NumiSeal default aggregate limit | `75` obligations |
| NumiSeal max digit-tensor columns | `4096` |

Any change to the modulus, ring, `kappa`, challenge support, challenge expansion
factor, decomposition length, norm bound, maximum fold counts, envelope
transcript domains, or terminal CE round count is a new parameter profile and
must receive a new profile ID or a new proof-kind/domain policy.

## Norm-Growth Accounting

Fresh CE openings use coefficients with signed magnitude `< b`, so for the
current `b = 2` profile the small coefficient set is `{-1, 0, 1}`.

For one fold with `s = freshCount + priorCount`, the implemented strong-sampling
check is:

```text
s * T * (b - 1) < b^k
```

The worst allowed fold has:

```text
s = 61 + 14 = 75
75 * 216 * (2 - 1) = 16200 < 16384 = 2^14
```

The remaining slack is only `184`. This is intentional but tight.

The decomposition path then uses 14 signed base-2 limbs. Each limb is checked to
have signed magnitude `< 2`, and recomposition is checked for commitments,
public-input encodings, and evaluation claims. The proof obligation is not just
"small after decomposition"; it is "14 small CE claims recompose to the folded
claim."

NumiSeal lane aggregation follows the same bound if each aggregate contains at
most 75 obligations and uses the same Phi81 challenge support. The implementation
sets `NumiSealAggregationLimits.defaultLimits()` to `61 + 14 = 75` and derives
one ring challenge per obligation under
`SuperNeo-NuMetal.numiseal.rlc.v1`. For adversarial review, the dossier treats
`maximumObligationsPerAggregate <= 75` as a security condition, not a tuning
knob. A custom NumiSeal policy with a larger aggregate limit would violate this
norm-growth proof unless it also changes decomposition parameters and estimator
inputs.

NumiSeal's terminal artifact verifies immediate residual CE openings. It is not
yet a recursive NumiSeal product theorem, and the current formal status should
not be read as a complete product/ZK aggregation proof.

## Reduction-Loss Accounting

The binding reduction has the usual lossless algebraic shape:

1. Two accepting openings for the same commitment and public context define a
   nonzero difference vector.
2. Commitment linearity maps that difference vector to `0`.
3. The boundedness checks put the difference vector within the short-kernel
   target.
4. A binding adversary therefore yields a Module-SIS/no-short-kernel witness.

The loss is not in the algebraic extraction; it is in the assumptions around it:

- the Ajtai key must be honestly generated or otherwise certified;
- the verifier must pin the verifier-key digest used by the proof envelope;
- the coefficient-expanded SIS estimate is a heuristic attack-cost estimate, not
  a formal proof of Module-SIS hardness for the split Phi81 quotient ring; and
- PiRLC soundness over Phi81 cannot use a field-pivot argument for every nonzero
  ring element, because `X^54 + X^27 + 1` splits over Goldilocks.

The formal soundness ledger then adds finite bad-seed sets for PiRLC, PiCCS,
terminal CE, and transcript-stage events. The final ROM-style accounting is a
finite seed-space numerator over this denominator:

```text
(((5^54)^pirlcCount * (q^2)^piccsRoundCount) *
  3^terminalCERoundCount) *
  256^transcriptByteLength
```

For the proof-envelope fold transcript, the structured context seed is 137
bytes. The formal denominator is still an abstract seed-space accounting device;
it deliberately does not prove SHA-256 random-oracle programmability.

Component budgets currently exposed by Lean include:

- PiCCS/sum-check bad challenge budget:
  `numVars * maxDegreePerRound`.
- For R1CS-like degree-2 CCS with the current norm polynomial,
  `maxDegreePerRound = max(shape.relationDegree, 3) + 1 = 4`.
- Terminal CE finite bad-seed budget:
  `219 * 3 = 657` over the modeled seed type.
- The theorem-facing PiCCS and terminal CE paths are now constructive:
  `PiCCSConstructiveFiniteSoundness.lean` consumes the sum-check bad-set proofs
  directly, and `TerminalCEConstructiveFiniteSoundness.lean` derives the
  `roundCount * 3` budget from concrete extraction-failure localization.
- PiRLC finite bad-seed soundness requires the explicit split/finite bad-seed
  certificate; this dossier does not replace that certificate with a one-line
  field Schwartz-Zippel claim.

## Estimator Results

Pinned command:

```sh
Scripts/reproduce-lattice-estimator.sh --full --pinned lattice-estimator-results/superneo-goldilocks-phi81.json
Scripts/validate-lattice-estimator-artifact.py --expect-status ran --expect-latest-status absent --require-claimed-security lattice-estimator-results/superneo-goldilocks-phi81.json
```

Pinned artifact:

- upstream repository: `https://github.com/malb/lattice-estimator.git`
- commit: `8d38f52c0bcc46f23d697c9c592bad50df0b124b`
- Sage: `10.8`
- canonical row: `rop ~= 2^129.1`, `beta = 345`, `d = 3129`,
  `delta = 1.004408`.

Manual audit rows from the same estimator checkout and same `SIS.Parameters`:

| Cost model | Estimated rop bits | beta | d | Interpretation |
| --- | ---: | ---: | ---: | --- |
| default MATZOV | `129.1` | `345` | `3129` | canonical pinned lane |
| ADPS16 classical | `100.7` | `345` | `3129` | alternate classical costing |
| ADPS16 quantum | `91.4` | `345` | `3129` | alternate quantum costing |
| ADPS16 paranoid | `71.6` | `345` | `3129` | conservative costing |
| ChaLoy21 | `88.7` | `345` | `3129` | alternate costing |
| LaaMosPol14 | `122.4` | `345` | `3129` | alternate costing |

This is the main adversarial-reading point: the repository's release gate
reproduces the paper/default estimator threshold, while broader quantum/cautious
cost models do not support a 128-bit quantum claim for `kappa = 18`.

## Sensitivity Analysis

Same estimator checkout, same `q`, `d = 54`, `m = 2^30`, and `norm = 2`.
`strong` means `(K + k) * T * (b - 1) < b^k` with `K = 61` unless stated.

| Variant | kappa | k | T | K | strong | MATZOV bits | ADPS16 quantum bits |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| baseline | `18` | `14` | `216` | `61` | yes | `129.1` | `91.4` |
| kappa-17 | `17` | `14` | `216` | `61` | yes | `121.2` | `84.0` |
| kappa-19 | `19` | `14` | `216` | `61` | yes | `136.9` | `98.8` |
| kappa-20 | `20` | `14` | `216` | `61` | yes | `145.0` | `106.5` |
| k-13 | `18` | `13` | `216` | `61` | no | `136.6` | `98.6` |
| k-15 | `18` | `15` | `216` | `61` | yes | `122.1` | `84.8` |
| T-192 | `18` | `14` | `192` | `61` | yes | `130.2` | `92.5` |
| T-240 | `18` | `14` | `240` | `61` | no | `128.0` | `90.4` |
| K-62 only | `18` | `14` | `216` | `62` | no | `129.1` | `91.4` |
| kappa-23 | `23` | `14` | `216` | `61` | yes | `170.0` | `130.1` |

Observations:

- `k = 14` is the minimum viable decomposition length for the implemented
  `K = 61`, prior count `14`, and `T = 216` budget.
- Increasing `k` creates norm headroom but weakens the SIS estimate because the
  short-vector bound grows.
- Reducing `T` helps security and norm headroom, but `T` is a proof parameter and
  cannot be changed independently of the challenge-expansion argument.
- Raising `K` from 61 to 62 breaks strong sampling even though it does not change
  the estimator tuple.
- A `kappa` near 23 is needed to clear 128 bits under the sampled ADPS16 quantum
  model, before accounting for proof size, runtime, and a new profile ID.

## Failure Probability And Soundness Budget

There is no decryption-style failure probability. Honest prover failure is
deterministic and should be zero for well-formed inputs that satisfy the profile
limits. Rejections come from parser errors, domain/context mismatches,
strong-sampling violations, decomposition non-recomposition, invalid terminal CE
branches, or malformed NumiSeal policy/artifact data.

Soundness must be stated as:

```text
epsilon_total <= epsilon_MSIS
              + epsilon_keygen_or_certificate
              + epsilon_ROM_FS
              + epsilon_hash_collision_or_domain_failure
```

The repository currently instantiates `epsilon_ROM_FS` as finite bad-seed
accounting, not as a QROM reduction. For concrete audit packets, record:

- `pirlcCount <= 75` for a maximum fold aggregate;
- `piccsRoundCount = log2(shape.m)` for the sum-check instance;
- `terminalCERoundCount = 219`;
- `transcriptByteLength = 137` for the envelope-context seed when that seed is
  used; and
- all proof-kind and transcript labels listed below.

The deterministic transcript work now proves byte injectivity only for
well-formed length-counted transcript states, and the theorem-critical binding
surface uses 384-bit typed binding digests. This does not prove SHA-256
collision resistance, indifferentiability, or random-oracle programmability.

## Fiat-Shamir / QROM Position

The interactive protocol before Fiat-Shamir is:

1. PiCCS public-Q and sum-check: verifier sends `alpha`, `gamma`, and one
   `F_q^2` challenge per sum-check round; prover sends the claimed sum and
   univariate round polynomials.
2. PiRLC: verifier sends one Phi81 ring challenge per CE claim after the PiCCS
   output claims are fixed.
3. PiDEC: deterministic checked decomposition and recomposition; no verifier
   randomness beyond the folded claim already produced.
4. Terminal CE opening: repeated Stern-style public-coin protocol with one of
   three verifier challenge symbols per round for 219 rounds.
5. NumiSeal: lane RLC, scalarization, sum-check, residual-opening, and optional
   ZK component transcripts use separate labels and digest roots.

The implementation applies Fiat-Shamir with SHA-256-derived deterministic
transcripts. The safe model statement today is ROM/heuristic FS plus the finite
bad-seed ledger over well-formed transcripts. It is not QROM.

To claim QROM security, the active theorem route must instantiate the split-QRO
product surface:

- use 256-bit challenge seeds and a separate 384-bit binding oracle;
- fit the accepted proof kinds to CTCO or Merkle-straightline compiler evidence;
- prove the conditions required by the selected QROM compiler theorem, including
  special soundness/extractability and the additional natural properties required
  by that result;
- include a quantum random-oracle query parameter `Q_H` in the reduction loss;
- bind every proof kind, transcript label, shape digest, statement digest,
  verifier-key digest, policy digest, and 384-bit theorem-critical binding
  digest in the theorem statement; and
- prove that cross-kind transcript replay is impossible except through a
  collision in the named digest/hash surface.

Don, Fehr, Majenz, and Schaffner give a QROM Fiat-Shamir reduction for
sigma-protocols and explicitly handle adversaries making quantum random-oracle
queries. That is relevant literature, not a drop-in proof for this protocol
stack as implemented. The old DFM20 multi-round accounting remains a
fail-closed diagnostic, not the active production theorem route.

## Transcript Labels And Cross-Kind Separation

Proof envelope kinds:

| Kind | Value | Meaning |
| --- | ---: | --- |
| `foldReduction` | `1` | fold reduction body |
| `terminalLocal` | `2` | local terminal fold proof |
| `compressedPublic` | `3` | compressed public terminal proof |
| `numiSealTerminal` | `4` | NumiSeal terminal artifact |
| `numiSealZK` | `5` | NumiSeal ZK artifact |

Envelope context binds:

```text
magic || version || profileID || kind ||
shapeDigest || statementDigest || verifierKeyDigest || transcriptDomain
```

`bodyLength` is part of the serialized 141-byte header and is enforced by the
parser, but it is not part of the 137-byte transcript-binding seed. The theorem
statement should therefore separate parser binding from transcript binding.

Primary labels and domains:

| Surface | Label/domain |
| --- | --- |
| default envelope transcript domain digest | `SHA256("SuperNeo-NuMetal.fold.v1")` |
| fold transcript | `SuperNeo-NuMetal.fold` |
| terminal CE transcript | `SuperNeo-NuMetal.ce-opening.stern` |
| compressed public statement domain | `SHA256("SuperNeo-NuMetal.compressed-public.statement.v1")` |
| compressed public proof domain | `SHA256("SuperNeo-NuMetal.compressed-public.proof.v2")` |
| NumiSeal lane RLC | `SuperNeo-NuMetal.numiseal.rlc.v1` |
| NumiSeal scalarization transcript | `SuperNeo-NuMetal.numiseal.scalarization.v1` |
| NumiSeal sum-check transcript | `SuperNeo-NuMetal.numiseal.sumcheck.v1` |
| NumiSeal sum-check weights | `SuperNeo-NuMetal.numiseal.sumcheck-weights.v1` |
| NumiSeal decomposition key digest | `SHA256("SuperNeo-NuMetal.numiseal.decomposition-key.v1")` |
| NumiSeal digit tensor digest | `SHA256("SuperNeo-NuMetal.numiseal.digit-tensor.v1")` |
| NumiSeal residual opening digest | `SHA256("SuperNeo-NuMetal.numiseal.residual-opening.v1")` |
| NumiSeal linear residual digest | `SHA256("SuperNeo-NuMetal.numiseal.linear-residual.v1")` |
| NumiSeal proof transcript digest | `numiseal.proof-transcript.v1` |
| NumiSeal ZK proof transcript digest | `numiseal.zk.proof-transcript.v1` |

Cross-kind non-malleability currently rests on:

- proof kind in the envelope transcript-binding context;
- caller-supplied policy checks for expected kind/domain/digests;
- disjoint NumiSeal terminal and ZK proof kinds;
- well-formed length-framed transcript absorbs;
- 384-bit theorem-critical binding digests for acceptance-critical equality; and
- digest roots for compressed and NumiSeal component bodies.

This is a deterministic domain-separation argument plus ordinary hash-collision
assumptions. It is not yet a concrete-hash QROM transcript-collision theorem.

## Why These Parameters

The implemented parameters are the smallest coherent research profile matching
the bundled paper's Goldilocks/Phi81 target:

- `d = 54` gives the Phi81 ring over Goldilocks.
- `kappa = 18` clears the default pinned estimator's 129-bit threshold.
- `k = 14` is just large enough for the `75 * 216 < 2^14` strong-sampling
  budget.
- `K = 61` and prior count `14` give 75 total fold terms, leaving only 184 units
  of norm slack.
- challenge support `{-2,-1,0,1,2}` and `T = 216` match the implemented
  strong-sampling proof surface.
- terminal CE uses 219 three-symbol rounds to make the finite bad-seed budget
  negligible in the modeled seed space.

The adversarial reading is that these parameters are tight and model-sensitive.
They are appropriate for implementation research and benchmarking. They are not
appropriate for a production PQ claim without at least:

- a stronger parameter profile, likely increasing `kappa`;
- an estimator artifact that records classical and quantum cost lanes;
- a distributional key-generation-to-Module-SIS theorem;
- release-grade ROM/finite-seed evidence over the implemented transcript path;
  and
- instantiated split-oracle CTCO or Merkle-straightline QROM evidence, or an
  explicit decision not to claim QROM security.

## Sources

- NIST PQC standards page:
  <https://csrc.nist.gov/projects/post-quantum-cryptography/pqc-standards>
- NIST PQC project overview:
  <https://csrc.nist.gov/Projects/Post-Quantum-Cryptography>
- NIST FIPS 203:
  <https://csrc.nist.gov/pubs/fips/203/final>
- NIST FIPS 204:
  <https://csrc.nist.gov/pubs/fips/204/final>
- NIST FIPS 205:
  <https://csrc.nist.gov/pubs/fips/205/final>
- Don, Fehr, Majenz, Schaffner, "Security of the Fiat-Shamir Transformation in
  the Quantum Random-Oracle Model":
  <https://eprint.iacr.org/2019/190>
