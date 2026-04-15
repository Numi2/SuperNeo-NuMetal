# NumiSeal v10 for SuperNeo-NuMetal

## Status

This document is an implementation-grade protocol design for a **native terminal seal** for the SuperNeo-NuMetal stack described in the request. I could not patch the repository directly in this environment because the repository itself is not mounted here, so the output below is a protocol and integration spec rather than an applied source-tree modification.

The design is intentionally **not** a generic PCS retrofit. It is a terminal proof system specialized to the exact objects already emitted by the repo:

- Goldilocks base field and GoldilocksExt2 transcript arithmetic.
- `Phi_81` ring arithmetic at degree 54.
- Ajtai commitments under the repo’s verifier key.
- transcript-bound SuperNeo folding outputs.
- PiRLC / PiDEC style bounded batching.
- existing terminal CE opening verifier as the residual/base opening relation.

The result is a new terminal layer that reduces many CE obligations to:

1. one **lane-local accumulated claim** per compatible lane,
2. one **decomposition witness commitment** per lane aggregate,
3. one **degree-4 index-domain sum-check** per lane aggregate,
4. a **constant number of residual CE openings** per lane aggregate.

That is the architecture that gives realistic proof-size and verifier-cost wins while staying inside the repo’s mathematics.

---

## 1. Design decision summary

### 1.1 What NumiSeal is

NumiSeal is a **native CE-obligation proof system** for the terminal boundary of SuperNeo.

It proves that the public terminal CE obligations emitted by the fold engine are all simultaneously valid with respect to:

- the pinned CCS shape,
- the pinned Ajtai verifier key,
- the pinned statement digest,
- the exact lane/evaluation-point separation already required by Neo/SuperNeo,
- bounded witness language constraints.

### 1.2 What NumiSeal is not

NumiSeal is **not**:

- a replacement of the internal SuperNeo folding commitment machinery,
- a second polynomial-commitment stack living beside Ajtai,
- a new field/ring profile,
- a default zero-knowledge layer.

### 1.3 Main idea

The core move is:

- batch compatible obligations only **within the same lane**,
- rebuild a single bounded **digit witness tensor** for the lane-local aggregate,
- commit once to that digit tensor using an **Ajtai-derived decomposition commitment**,
- scalarize all remaining public terminal equalities into one extension-field linear identity,
- combine that linear identity with the bounded-language check into one degree-4 polynomial over the witness index hypercube,
- prove that identity by sum-check,
- discharge the final oracle query using the repo’s own **CE opening relation** as the residual/base case.

This makes the terminal seal “native”: the final object is still an Ajtai/CE statement in GoldilocksExt2 / `Phi_81`, just much smaller and easier to recurse over.

---

## 2. Why not Hachi as the terminal seal

Hachi is attractive because it is a lattice-based multilinear PCS over extension fields, and recent public materials around it position it as the first lattice PCS with extension-field evaluation support and asymptotically improved verification relative to Greyhound. Greyhound itself gets compact proofs by combining a polynomial-evaluation protocol with LaBRADOR-style recursion, and public summaries report around 53 KB evaluation proofs at large degree. The publicly visible Hachi prototype is also very early-stage: the GitHub repo currently shows only a few commits and a benchmark-style prototype README. This is useful research input, but it is not enough to justify importing Hachi as the repo’s production terminal boundary. citeturn600580search0turn600580search11turn489332search1turn489332search4turn225342view0

For this repo specifically, a Hachi-style outer PCS would also have to bridge from SuperNeo’s exact Ajtai/CCS/CE obligations into a different outer polynomial-commitment statement. Public Hachi materials emphasize power-of-two cyclotomic rings, while your active repo profile is explicitly `Phi_81(d=54)` and the Goldilocks modulus `2^64 - 2^32 + 1`. That mismatch is enough to make “drop in Hachi” the wrong direction for v10. citeturn256258search1turn194436search0

NumiSeal avoids that detour. It keeps the terminal object inside the same field/ring/key/transcript family and uses the already-implemented CE opening relation as the last residual step rather than replacing it with an external PCS.

---

## 3. Public API

```swift
public struct NumiSealAcceptancePolicy {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let acceptedLaneIDs: Set<NumiSealLaneID>
    public let maximumProofByteCount: Int
    public let transcriptDomain: Digest256
}

public final class NumiSealProver {
    public func prove(
        obligations: [NumiSealObligation],
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> NumiSealProofEnvelope
}

public final class NumiSealVerifier {
    public func verify(
        envelope: NumiSealProofEnvelope,
        obligations: [NumiSealObligation],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        policy: NumiSealAcceptancePolicy
    ) throws -> VerificationResult
}
```

New envelope kind:

```swift
ProofEnvelopeKind.numiSealTerminal = 4
```

---

## 4. Public statement object

```text
NumiSealObligation {
  laneID
  profileID
  shapeDigest
  statementDigest
  verifierKeyDigest
  commitment
  publicInputEncoding
  evalPoint
  matrixEvaluations
  sourceFoldDigest
}
```

A **lane** is exactly:

```text
(profileID, shapeDigest, verifierKeyDigest, evalPointDigest, laneID)
```

Never batch across distinct lane tuples.

This matches the Neo/SuperNeo “two-lane” warning from Nightstream: obligations at different evaluation points cannot be merged into the same single-point terminal check. citeturn164464search0

---

## 5. Canonicalization and transcript binding

### 5.1 Canonical order

For a fixed verification call:

1. reject any obligation whose profile/shape/key/statement digest disagrees with policy,
2. compute `evalPointDigest = H("numiseal.eval-point.v1" || canonical(evalPoint))`,
3. compute lane tuple,
4. sort lexicographically by:
   - lane tuple,
   - commitment digest,
   - public-input digest,
   - matrix-evaluation digest,
   - sourceFoldDigest.

### 5.2 Obligation leaf

```text
obligationLeaf_i = H(
  "numiseal.obligations.v1" ||
  canonicalEncode(obligation_i)
)
```

### 5.3 Lane summary

For each lane:

```text
laneSummaryLeaf = H(
  "numiseal.lane-summary.v1" ||
  laneID ||
  profileID ||
  shapeDigest ||
  verifierKeyDigest ||
  evalPointDigest ||
  obligationCount ||
  laneObligationRoot
)
```

### 5.4 Transcript schedule

Transcript absorb order:

1. envelope kind/version,
2. `policy.transcriptDomain`,
3. profile parameters hash,
4. `shapeDigest`, `statementDigest`, `verifierKeyDigest`,
5. lane summary leaves in canonical order,
6. obligation leaves in canonical order,
7. component digests as they are fixed.

All absorbs use the repo’s existing length-framed transcript discipline.

No empty components get zero digests. Use:

```text
absentComponentDigest(label, context) =
  H("numiseal.absent-component.v1" || label || context)
```

---

## 6. Lane-local RLC accumulation

For each lane with obligations `O_1, ..., O_m`, sample transcript challenges

```text
ρ_i ∈ {-2, -1, 0, 1, 2}
```

using the same challenge discipline as PiRLC.

Then define lane-local aggregates:

```text
C*   = Σ_i ρ_i C_i
Y*   = Σ_i ρ_i Y_i
x*   = Σ_i ρ_i x_i
z*   = Σ_i ρ_i z_i
```

where `Y_i` is the vector of claimed matrix evaluations and `x_i` is the public-input encoding.

### 6.1 Why reuse the PiRLC challenge set

Ajtai commitments are only binding for low-norm witnesses, so uncontrolled linear batching is unsafe. Public discussions of lattice folding highlight that norm growth is the central difficulty when using Ajtai commitments, and that folding must be engineered to stay inside the binding range. NumiSeal inherits the repo’s existing solution strategy: small batching coefficients followed by decomposition. citeturn293242search0turn293242search2turn293242search3

### 6.2 Batch limits

NumiSeal should enforce the same profile-safe limits the repo already advertises:

- max fresh batch count = 61,
- max prior CE claim count = 14,
- decomposition length = 14.

If a lane exceeds safe batch limits, split it into multiple lane aggregates and prove each aggregate independently inside the same envelope.

---

## 7. Bound-restoring decomposition

### 7.1 Preferred v10 representation

This is the critical design choice.

Do **not** send 14 separate decomposition commitments unless the current key code absolutely forces it.

Preferred v10 path:

- represent the aggregate witness `z*` as a **digit witness tensor**

```text
d : [0..n-1] × [0..15] -> F_q
```

where only digits `0..13` are active, digits `14,15` are padding, and

```text
z*(t) = Σ_{k=0}^{13} 2^k · d(t, k)
```

with each active digit in the bounded language.

### 7.2 One decomposition commitment per lane aggregate

Commit **once** to the flattened digit tensor using a key derived from the pinned Ajtai key:

```text
A_dec(lane) = DeriveAjtaiKey(
  baseKey = A,
  domain = "numiseal.decomposition-key.v1",
  laneID,
  requiredColumnCount
)
```

and

```text
D_lane = A_dec(lane) · pack(d_flat)
```

This keeps proof size on target. Fourteen full Ajtai commitments would usually miss the 10–30 KB goal.

### 7.3 Fallback only if key derivation is impossible

If the existing `AjtaiCommitmentKey` cannot deterministically derive a widened key from the pinned verifier-key seed, the fallback is 14 limb commitments. That fallback is correct but it is **not** the preferred v10 design and likely fails the stated proof-size target.

### 7.4 Language polynomial

For the current ternary digit language:

```text
N(t) = t(t - 1)(t + 1)
```

For future decomposition alphabets, define a profile-level `LanguagePolynomial` that vanishes exactly on the allowed alphabet.

---

## 8. Scalarizing the public terminal equalities

Each lane aggregate needs to prove three classes of equalities:

1. original Ajtai commitment consistency,
2. original matrix-evaluation consistency,
3. public-slot consistency.

These are all **linear** in the witness.

### 8.1 Commitment residual

Expand the ring/vector commitment equation

```text
A_orig · reconstruct(d) = C*
```

into base coefficients and sample transcript weights

```text
ψ_{row, coeff} ∈ F_q^2
```

Then obtain one extension-field scalar residual:

```text
R_commit(d) = Σ_t λ_commit(t) · z*(t) - c_commit
```

where `λ_commit` and `c_commit` are public and derived from:

- `A_orig`,
- the packing map,
- the random weights `ψ`,
- the public aggregate commitment `C*`.

### 8.2 Evaluation residual

For each claimed matrix evaluation equality

```text
MLE_r(M_j z*) = y*_j
```

choose transcript weights over matrix index and ring coefficients, and collapse all of them into:

```text
R_eval(d) = Σ_t λ_eval(t) · z*(t) - c_eval
```

The coefficient vector `λ_eval` is public and computed from the sparse CCS matrices and the lane evaluation point.

### 8.3 Public-slot residual

Similarly encode public-input slot matching as:

```text
R_pub(d) = Σ_t λ_pub(t) · z*(t) - c_pub
```

### 8.4 Combined linear residual

After sampling `α_commit, α_eval, α_pub ∈ F_q^2`, define

```text
R_lin(d) = Σ_t λ_lin(t) · z*(t) - c_lin
```

where

```text
λ_lin = α_commit λ_commit + α_eval λ_eval + α_pub λ_pub
c_lin = α_commit c_commit + α_eval c_eval + α_pub c_pub
```

Because

```text
z*(t) = Σ_k 2^k d(t, k)
```

this becomes

```text
R_lin(d) = Σ_{t,k} λ_lin(t) 2^k d(t, k) - c_lin
```

Everything is now a linear identity in the digit witness tensor.

---

## 9. The NumiSeal sum-check polynomial

Let the digit tensor be viewed as a multilinear extension

```text
D(X, K)
```

over a Boolean cube of dimension

```text
ℓ = log2(paddedWitnessLength) + 4
```

where `X` indexes witness position and `K` indexes the 16 digit slots.

Define public tables / multilinear extensions:

- `pow2(K)` = `[1, 2, 4, ..., 2^13, 0, 0]`,
- `active(K)` = `[1 x 14, 0, 0]`,
- `inactive(K) = 1 - active(K)`,
- `λ_lin(X)` = combined public linear coefficient table,
- `η_lang(X, K) = eq(τ_lang, (X,K))` for a transcript-random point `τ_lang`,
- `η_pad(X, K) = eq(τ_pad, (X,K))` for a transcript-random point `τ_pad`.

Then define

```text
G_lin(X, K)  = λ_lin(X) · pow2(K) · D(X, K)
G_lang(X, K) = η_lang(X, K) · active(K) · N(D(X, K))
G_pad(X, K)  = η_pad(X, K) · inactive(K) · D(X, K)
```

and after sampling `β_lin, β_lang, β_pad ∈ F_q^2` define

```text
G(X, K) =
    β_lin  · G_lin(X, K)
  + β_lang · G_lang(X, K)
  + β_pad  · G_pad(X, K)
```

Claimed total:

```text
T = β_lin · c_lin
```

because the language and padding sums should be zero.

### 9.1 Degree bound

- `G_lin` is degree 2 per variable,
- `G_pad` is degree 2 per variable,
- `G_lang` is degree 4 per variable because `N` is cubic and `η_lang` is multilinear.

So the whole combined polynomial has degree at most 4 in each variable.

This fits the standard sum-check setting used by Spartan/HyperNova-style CCS reductions. HyperNova’s preliminaries explicitly rely on sum-check over low-degree polynomials on the Boolean hypercube and define CCS as sparse multilinear relations over that cube. citeturn325281view3

### 9.2 Why the language check works

`N(D(X,K))` is zero on every Boolean-cube point for an honest ternary digit table. If it is non-zero anywhere, then its multilinear extension is a non-zero low-degree polynomial, so evaluating the `eq(τ_lang, ·)` weighted sum at a random transcript point catches the violation with standard Schwartz–Zippel / sum-check soundness.

---

## 10. Residual opening: native base case

After the sum-check, the verifier is left with a single evaluation claim of the form

```text
D(r_sc) = v_sc
```

for a transcript-derived extension-field point `r_sc`.

This is the **only** oracle value that the verifier needs from the witness for the combined lane check.

### 10.1 Do not invent a second opening primitive

The residual opening should be handled by the repo’s existing CE opening relation, not by a new PCS.

Encode the claim as an internal CE statement for the digit witness commitment `D_lane` using a fixed identity/selection shape:

```text
MLE_{r_sc}(I · d_flat) = v_sc
```

where `I` is a canonical sparse identity selector over the flattened digit witness.

This satisfies the requirement:

- exact Ajtai linear relation,
- exact transformed sparse-matrix evaluation relation,
- no generic PCS.

### 10.2 Residual proof object

```text
NumiSealResidualOpening {
  laneID
  decompositionKeyDigest
  decompositionCommitmentDigest
  evalPointDigest
  claimedValue
  ceOpeningProof
}
```

### 10.3 Recursive carry

The residual claim can also be exported as a new NumiSeal carry obligation:

```text
NumiSealCarryClaim {
  carryKind = digitWitnessMLE
  laneID
  profileID
  parentShapeDigest
  parentStatementDigest
  parentVerifierKeyDigest
  decompositionKeyDigest
  commitment = D_lane
  evalPoint = r_sc
  matrixEvaluations = [v_sc]
}
```

This is how recursive sealing / checkpointing works. The number of such carry claims is constant per lane aggregate.

---

## 11. Full proof object

```text
NumiSealProof {
  version
  profileID
  laneSummaries
  obligationRoot
  componentDigestRoot
  accumulatorTranscriptDigest
  decompositionCommitments
  sumcheckProofs
  terminalResidualOpenings
  recursionCarryClaims
}
```

Typed component leaves:

```text
numiseal.obligations.v1
numiseal.lane-summary.v1
numiseal.accumulator.v1
numiseal.decomposition.v1
numiseal.sumcheck.v1
numiseal.residual-opening.v1
numiseal.absent-component.v1
```

Recommended component leaf commitments:

```text
accumulatorLeaf = H(
  "numiseal.accumulator.v1" ||
  laneID ||
  aggregateCommitmentDigest ||
  aggregateEvaluationDigest ||
  aggregatePublicInputDigest ||
  aggregateSourceFoldDigest
)

compositionLeaf = H(
  "numiseal.decomposition.v1" ||
  laneID ||
  decompositionKeyDigest ||
  decompositionCommitmentDigest
)

sumcheckLeaf = H(
  "numiseal.sumcheck.v1" ||
  laneID ||
  claimedTotal ||
  roundDigestRoot ||
  finalPointDigest ||
  finalClaimedValue
)

residualOpeningLeaf = H(
  "numiseal.residual-opening.v1" ||
  laneID ||
  residualOpeningDigest
)
```

`componentDigestRoot` is the Merkle root of all present or absent component leaves in a fixed lane-major order.

---

## 12. Prover algorithm

For each verification call:

### Step A. Canonicalize

- canonicalize obligations,
- group by lane,
- absorb into transcript.

### Step B. Lane accumulation

For each lane:

- sample `ρ_i`,
- compute public aggregates `C*`, `Y*`, `x*`,
- compute private aggregate witness `z*`.

### Step C. Digit decomposition

- form ternary digit tensor `d`,
- derive `A_dec(lane)`,
- commit once to `d_flat` obtaining `D_lane`.

### Step D. Public coefficient generation

- sample residual-combination challenges,
- compute `λ_commit`, `λ_eval`, `λ_pub`,
- combine into `λ_lin`,
- compute `c_lin`.

### Step E. Sum-check

- define `G(X,K)` as above,
- run non-interactive sum-check over `GoldilocksExt2`,
- obtain final point `r_sc` and claimed value `v_sc = D(r_sc)`.

### Step F. Residual CE opening

- generate CE opening proof for `D_lane` at `r_sc` with claimed value `v_sc`.

### Step G. Envelope binding

- compute all component leaves,
- compute `componentDigestRoot`,
- finalize transcript digest,
- serialize proof body and envelope.

---

## 13. Verifier algorithm

### Step 1. Policy checks

Reject unless:

- envelope kind is `numiSealTerminal`,
- proof bytes are within policy bound,
- profile/shape/statement/key digests match,
- all lane IDs are policy-accepted.

### Step 2. Re-canonicalize obligations

- rebuild canonical order,
- rebuild obligation root,
- rebuild lane summaries.

### Step 3. Transcript reconstruction

- absorb the same public objects in the same order,
- re-derive all Fiat–Shamir challenges.

### Step 4. Per-lane public recomputation

For each lane:

- recompute `ρ_i` and public aggregates,
- verify the decomposition commitment digest entry,
- derive the same decomposition key digest,
- recompute `λ_lin` and `c_lin`,
- verify sum-check rounds,
- recover final `r_sc` and claimed `v_sc`,
- verify residual CE opening on `D_lane` at `r_sc`.

### Step 5. Component root and final digest

- recompute `componentDigestRoot`,
- recompute `accumulatorTranscriptDigest`,
- verify envelope binding.

Return `accepted` only if all lanes accept.

---

## 14. Security claims and proof story

NumiSeal v10 should claim the following and no more.

### 14.1 Completeness

If all supplied obligations are valid and the prover supplies the correct witnesses, the verifier accepts.

Reason:

- lane-local RLC is exact linear aggregation,
- ternary digit decomposition reconstructs the aggregate witness exactly,
- linear residual scalarization preserves equality,
- sum-check is complete,
- residual CE opening verifier is complete.

### 14.2 Binding to exact shape / statement / verifier key

The envelope and transcript bind:

- `shapeDigest`,
- `statementDigest`,
- `verifierKeyDigest`,
- lane summaries,
- obligation root,
- component digest root.

An accepted proof is therefore statement-specific and key-specific.

### 14.3 Lane-local accumulation soundness

This is inherited from the same bounded small-challenge accumulation discipline already used by PiRLC/PiDEC, provided NumiSeal enforces the same safe profile limits.

### 14.4 Bounded-witness knowledge soundness

Conditioned on:

1. binding of the Ajtai commitment for the claimed norm range,
2. correctness of the decomposition reconstruction identity,
3. soundness of the residual CE opening relation,

an accepting proof implies knowledge of a digit witness tensor whose reconstruction satisfies the aggregated linear obligations.

### 14.5 Terminal CE relation soundness

The sum-check plus residual opening implies the lane aggregate satisfies the exact scalarized terminal equalities derived from:

- the Ajtai commitment relation,
- the sparse-matrix evaluation relation,
- the public-slot relation.

By random scalarization over ring coefficients / matrix indices, failure of any constituent equality survives into the scalarized relation except with negligible probability.

### 14.6 Fiat–Shamir model

For v10, the conservative claim should be:

- **Fiat–Shamir soundness in the classical random-oracle model**.

Do **not** claim a QROM proof unless one is written specifically for this transcript schedule and residual-opening composition.

### 14.7 Recursive composition soundness

Recursive soundness reduces to:

1. correctness of carry-claim encoding,
2. soundness of the higher-level NumiSeal instance on those carry claims,
3. collision resistance / binding of the component digests.

### 14.8 Zero knowledge

Do **not** claim zero knowledge by default.

Default NumiSeal is a **knowledge / correctness** terminal seal only.

A future `NumiSealZK` must add:

- masking of the digit witness tensor,
- a simulator argument,
- transcript-safe randomness derivation,
- randomness-reuse prevention across recursive levels.

---

## 15. Performance expectations

### 15.1 Proof size

For one lane aggregate:

- one decomposition commitment dominates,
- one degree-4 sum-check contributes `O(log n)` extension-field elements,
- one residual CE opening contributes a constant-size object.

With raw Ajtai commitments of roughly `κ * 54` base-field coefficients, one decomposition commitment is on the order of single-digit KB, so one or two lanes plus logarithmic sum-check overhead is consistent with the 10–30 KB target for common cases.

### 15.2 Verifier time

The verifier does **not** touch the full witness.

It performs:

- canonicalization and digesting over public obligations,
- sparse public coefficient generation,
- `O(log n)` sum-check verification,
- constant-number residual CE openings.

That is sublinear in witness length, assuming the existing CE opening verifier is already sublinear in the opened witness length.

### 15.3 Prover time

Near-linear in witness length for each lane aggregate:

- digit decomposition is linear,
- decomposition commitment is linear and already has CPU/Metal paths,
- each sum-check round is a streaming reduction over the digit tensor,
- residual CE opening count is constant per lane aggregate.

---

## 16. Execution policy mapping

### `highAssurance`

- CPU only.
- fixed-order reductions,
- no nondeterministic parallel sums,
- no Metal,
- deterministic challenge expansion.

### `cpu`

- multithreaded scalar/vectorized implementation,
- cache sparse coefficient tables per shape + eval point digest,
- deterministic serialization.

### `metal`

Accelerate only the heavy array work:

1. lane-local witness accumulation,
2. digit decomposition packing,
3. decomposition commitment computation,
4. round-wise sum-check reductions.

Verifier stays CPU.

---

## 17. Concrete source-tree plan

Suggested new files:

```text
SuperNeo-NuMetal/
  Protocols/
    NumiSeal/
      NumiSealTypes.swift
      NumiSealCanonicalization.swift
      NumiSealLaneAccumulator.swift
      NumiSealDecomposition.swift
      NumiSealScalarization.swift
      NumiSealSumCheck.swift
      NumiSealResidualOpening.swift
      NumiSealProver.swift
      NumiSealVerifier.swift
      NumiSealSerialization.swift
  Docs/
    NumiSeal-v10.md
    NumiSeal-Security.md
    NumiSeal-Recursion.md
  Tests/
    NumiSealTests/
      NumiSealCanonicalizationTests.swift
      NumiSealLaneBatchingTests.swift
      NumiSealDecompositionTests.swift
      NumiSealSumCheckTests.swift
      NumiSealResidualOpeningTests.swift
      NumiSealEndToEndTests.swift
      NumiSealAdversarialTests.swift
```

### 17.1 Serialization changes

Extend `ProofEnvelopeKind` with:

```swift
case numiSealTerminal = 4
```

Add versioned serialization labels for every new component. Reuse the repo’s digest framing and “trusted context” acceptance rules.

### 17.2 Reuse points in existing code

- `AjtaiCommitment.swift`
  - reuse commit / linear-combine paths,
  - add deterministic `deriveSubkey(...)` if current key material is seed-based.
- `SumCheckTranscript.swift`
  - add domain labels for NumiSeal challenge sampling.
- `SuperNeoProtocols.swift`
  - expose a residual CE-opening verification entrypoint usable by NumiSeal.
- `SuperNeoSerialization.swift`
  - add envelope kind, component leaves, absent-component digests.

---

## 18. Test plan

### 18.1 Deterministic test vectors

Need versioned golden vectors for:

1. canonical obligation sorting,
2. lane summary root,
3. RLC coefficient sampling,
4. digit decomposition,
5. decomposition commitment digest,
6. scalarization coefficients and `c_lin`,
7. one-lane sum-check transcript,
8. final residual CE opening claim,
9. full envelope digest.

### 18.2 Adversarial tests

Must include:

- same lane ID but different eval point → reject,
- same eval point but different verifier key digest → reject,
- valid obligations but wrong canonical ordering in proof → reject,
- invalid digit in decomposition tensor → reject,
- padding digit non-zero → reject,
- wrong `c_lin` scalarization constant → reject,
- malformed residual opening → reject,
- proof accepted under one transcript domain but replayed under another → reject,
- envelope missing a component but using zero digest placeholder → reject.

### 18.3 Performance tests

Benchmark by lane count, witness size, and execution policy:

- 1 main lane,
- main + value lane,
- worst-case allowed lane batch size,
- CPU vs highAssurance vs Metal.

---

## 19. Formalization scaffolding

Suggested theorem decomposition:

### Core definitions

- `LaneKey`
- `CanonicalObligationOrder`
- `DigitTensor`
- `Reconstruct`
- `LanguagePolynomial`
- `ScalarizedLinearResidual`
- `NumiSealPolynomial`

### Theorems to state first

1. `canonicalization_deterministic`
2. `reconstruct_correct`
3. `language_zero_on_allowed_digits`
4. `scalarization_preserves_truth`
5. `sumcheck_sound_for_numiseal_polynomial`
6. `residual_opening_implies_terminal_value`
7. `lane_acceptance_implies_aggregate_valid`
8. `all_lane_acceptance_implies_all_obligations_valid`

### Trusted-boundary statement

NumiSeal’s trusted reductions should be written explicitly as:

- hash / random oracle,
- Ajtai commitment binding in the stated norm regime,
- soundness of the existing CE residual opener,
- correctness of the sparse matrix / ring arithmetic implementation.

This makes it much easier to integrate into the existing formal track.

---

## 20. Open items that still need a code-level decision

These are the only three points I would still treat as implementation decisions rather than protocol uncertainty.

### A. How `AjtaiCommitmentKey` derives `A_dec`

Preferred:

- deterministic subkey expansion from the pinned verifier-key seed and lane ID.

Fallback:

- 14 limb commitments, knowing it will likely miss size targets.

### B. Exact internal CE residual shape

Preferred:

- a fixed identity/selection shape for flattened digit witnesses.

This should be domain-separated and serialized as an internal shape digest.

### C. Whether to verify carry claims immediately or export them

I recommend both modes:

- application verifier: full verification now,
- recursive prover: export carry claims to the next NumiSeal instance.

---

## 21. Bottom line

The protocol I recommend shipping as **NumiSeal v10** is:

1. canonicalize obligations by lane,
2. lane-local RLC with the repo’s existing small-challenge discipline,
3. decompose each lane aggregate into a **single committed ternary digit tensor**,
4. scalarize all public terminal equalities into one extension-field linear identity,
5. combine that identity with digit-language and padding checks into one degree-4 polynomial,
6. prove its cube-sum claim with sum-check,
7. discharge the final evaluation by the repo’s own CE opening relation,
8. package the result in a typed digest-bound proof envelope with recursive carry claims.

That is smaller than the current heavy terminal layer, fits the existing math, respects lane separation, reuses the repo’s Ajtai/CE machinery, and has a clean formal proof boundary.
