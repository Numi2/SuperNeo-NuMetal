# NumiSeal v10 for SuperNeo-NuMetal

## Status

NumiSeal v10 is the planned native terminal-seal layer for this repository. It
is not a replacement for SuperNeo folding, Ajtai commitments, or the existing
terminal CE opening relation. It is a compression and aggregation layer that
turns many terminal CE obligations into a small number of lane-local terminal
checks while staying inside the repo's active profile:

- Goldilocks base field.
- GoldilocksExt2 transcript and sum-check arithmetic.
- `Phi_81(d=54)` ring arithmetic.
- Ajtai commitments with `kappa = 18`, norm bound `2`, and decomposition length
  `14`.
- CCS as the internal arithmetization IR.
- Terminal acceptance through `ProofEnvelopeHeader` plus trusted verifier policy.

The current repository already has:

- hand-authored R1CS -> CCS preparation through `SuperNeoR1CSBuilder`,
  `SuperNeoR1CSProgram`, and `SuperNeoR1CSProvingStack`;
- shape normalization through `SuperNeoCCSNormalizer`;
- a commitment backend boundary through `CommitmentScheme` and
  `AjtaiSuperNeoCommitment`;
- SuperNeo fold, terminal, and compressed-terminal envelopes;
- public terminal acceptance policy that rejects fold reductions before
  verification;
- CE opening proofs used as the terminal base relation;
- high-assurance CPU and CPU-redundant Metal execution policies.

NumiSeal v10 starts from that shipped stack. Phase 0 type and canonicalization
scaffolding is now present under `Protocols/NumiSeal/`; the full prover,
verifier, decomposition, scalarization, sum-check, residual opening, and
envelope kind are still implementation targets.

## Product Split

The repo should keep two tracks explicit.

### Prover Track

Purpose: prove hand-authored CCS/R1CS statements and verify them locally or in
CLI/test-vector contexts.

Shipped path:

```text
R1CS assignment -> CCS -> Ajtai commitments -> SuperNeo fold
-> terminal CE opening -> terminal/compressed envelope -> verifier policy
```

This track remains the correctness and integration baseline. Fold reductions are
useful for debugging and benchmarks but are never application acceptance.

### SNARK Product Track

Purpose: move toward smaller terminal proof objects, recursive/aggregate
sealing, and eventually zero-knowledge.

Planned path:

```text
frontend -> robust witness generation -> CCS -> Ajtai commitments
-> SuperNeo folding -> NumiSeal terminal seal
-> verifier/API -> security story -> optional ZK layer
```

NumiSeal belongs here. It is the native terminal seal for aggregation and
recursion. It is not the zero-knowledge layer by itself.

## Design Goals

NumiSeal v10 must:

- bind profile, shape, statement, verifier key, transcript domain, proof kind,
  and lane summaries;
- canonicalize every terminal CE obligation before sampling challenges;
- batch only obligations that share an identical lane key;
- use the repo's small challenge discipline for lane-local RLC;
- restore bounded language through a single digit-tensor commitment per lane
  aggregate;
- reduce public terminal equalities to one extension-field linear residual;
- combine residual, digit-language, and padding checks into one degree-4
  sum-check per lane aggregate;
- close each lane with the existing CE opening relation as the residual base
  case;
- expose carry claims for recursive sealing without forcing recursion into the
  base verifier.

NumiSeal v10 must not:

- import a second polynomial commitment stack;
- change the active Goldilocks/Phi81/Ajtai profile;
- batch across evaluation points or verifier keys;
- claim zero knowledge;
- treat a fold reduction as a terminal proof;
- use zero digests for absent components.

## Public API Target

```swift
public struct NumiSealAcceptancePolicy {
    public let profileID: UInt16
    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let verifierKeyDigest: Digest256
    public let transcriptDomain: Digest256
    public let acceptedLaneIDs: Set<NumiSealLaneID>
    public let maximumProofByteCount: Int?
}

public final class NumiSealProver {
    public func prove(
        obligations: [NumiSealObligation],
        witnesses: [CEOpeningWitness],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        policy: NumiSealAcceptancePolicy,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> NumiSealProofEnvelope
}

public final class NumiSealVerifier {
    public func verify(
        envelope: NumiSealProofEnvelope,
        obligations: [NumiSealObligation],
        shape: CCSShape,
        key: AjtaiCommitmentKey,
        policy: NumiSealAcceptancePolicy,
        executionPolicy: SuperNeoExecutionPolicy
    ) throws -> VerificationResult
}
```

New envelope kind:

```swift
case numiSealTerminal = 4
```

The verifier API should mirror `verifyTerminalProofEnvelope`: it must reject
wrong kind, wrong profile, wrong shape, wrong statement, wrong key, wrong
transcript domain, and over-large proof bytes before expensive verification.

## Public Statement Objects

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

The lane key is:

```text
(
  profileID,
  shapeDigest,
  verifierKeyDigest,
  evalPointDigest,
  laneID
)
```

`evalPointDigest` is:

```text
H("numiseal.eval-point.v1" || length(evalPoint) || canonical(evalPoint))
```

Never batch across different lane keys. Different evaluation points are
different lanes even when every other digest matches.

## Canonicalization

For each verification call:

1. Reject empty obligation lists.
2. Reject obligations whose profile, shape, statement, or verifier-key digest
   disagrees with policy.
3. Reject obligations whose `laneID` is not accepted by policy.
4. Compute `evalPointDigest`.
5. Compute the lane key.
6. Sort obligations lexicographically by:
   - lane key bytes,
   - commitment digest,
   - public input digest,
   - matrix evaluation digest,
   - source fold digest.
7. Group adjacent obligations by lane key.

The obligation leaf is:

```text
H(
  "numiseal.obligation.v1" ||
  canonicalEncode(obligation)
)
```

The lane summary leaf is:

```text
H(
  "numiseal.lane-summary.v1" ||
  laneKey ||
  obligationCount ||
  laneObligationRoot
)
```

Roots use deterministic length-framed digest lists:

```text
root(label, leaves) =
  H(label || count(leaves) || leaf_0 || ... || leaf_n)
```

This is not a Merkle authentication tree. It is a compact transcript-binding
root. If later proof streaming needs inclusion proofs, add a separate Merkle
root with a new label.

Absent components use:

```text
H("numiseal.absent-component.v1" || componentLabel || laneKey)
```

Zero digests are invalid.

## Transcript Schedule

All challenge derivation must follow one public schedule:

1. envelope version and kind,
2. policy transcript domain,
3. profile ID and profile parameter digest,
4. shape digest,
5. statement digest,
6. verifier-key digest,
7. canonical obligation root,
8. lane summary root,
9. per-lane component digests as they become fixed.

The transcript schedule is part of the proof kind. Any change requires a new
NumiSeal proof version.

## Lane-Local RLC

For each lane with obligations `O_0 ... O_{m-1}`, sample small challenges:

```text
rho_i in {-2, -1, 0, 1, 2}
```

using the same profile challenge set as PiRLC.

Aggregate public objects:

```text
C* = sum_i rho_i C_i
Y* = sum_i rho_i Y_i
x* = sum_i rho_i x_i
```

Aggregate private witnesses on the prover side:

```text
z* = sum_i rho_i z_i
```

Limits:

- obligation count per lane aggregate must not exceed
  `SuperNeoParameters.maxFreshBatchCount`;
- carry/prior-like obligations must not exceed
  `SuperNeoParameters.maxPriorClaimCount`;
- when a lane exceeds a limit, split into deterministic lane aggregate chunks
  and prove each chunk independently in the same envelope.

## Bound-Restoring Decomposition

The v10 representation is one digit witness tensor per lane aggregate:

```text
d : [0 .. paddedWitnessLength - 1] x [0 .. 15] -> Goldilocks
```

Active digits are `0 .. 13`; digit slots `14` and `15` are padding.

Reconstruction:

```text
z*(t) = sum_{k=0}^{13} 2^k d(t, k)
```

The active digit language for v10 is ternary:

```text
d(t,k) in {-1, 0, 1}
```

with language polynomial:

```text
N(u) = u(u - 1)(u + 1)
```

### Decomposition Key

Derive one Ajtai decomposition key per lane aggregate:

```text
A_dec = AjtaiCommitmentKey(
  columns: ceil((paddedWitnessLength * 16) / 54),
  seed: H(
    "numiseal.decomposition-key.v1" ||
    verifierKeyDigest ||
    laneKey ||
    aggregateIndex ||
    requiredColumnCount
  )
)
```

This is public deterministic key derivation. Both prover and verifier can
rebuild `A_dec` from public data.

Commit once:

```text
D_lane = A_dec * pack(d_flat)
```

Do not send 14 limb commitments. Fourteen limb commitments are correct but fail
the v10 size target and should be kept out of the primary design.

## Public Residual Scalarization

Each lane aggregate must prove:

1. Ajtai commitment consistency:

   ```text
   A_orig * z* = C*
   ```

2. CCS matrix evaluation consistency:

   ```text
   MLE_r(M_j z*) = Y*_j
   ```

3. public-slot consistency:

   ```text
   z*[0 .. publicInputCount) = x*
   ```

All three are linear in `z*`, hence linear in the digit tensor after applying
the reconstruction map.

Sample transcript weights for commitment rows/ring coefficients, matrix
indices/ring coefficients, and public slots. Collapse the checks into:

```text
R_lin(d) = sum_{t,k} lambda_lin(t) * 2^k * d(t,k) - c_lin
```

where `lambda_lin` and `c_lin` are fully public after transcript challenge
sampling.

## Sum-Check Polynomial

View `d` as a multilinear extension:

```text
D(X, K)
```

over:

```text
ell = log2(paddedWitnessLength) + 4
```

The extra four variables index the 16 digit slots.

Public tables:

```text
pow2(K)    = [1, 2, ..., 2^13, 0, 0]
active(K)  = [1 x 14, 0, 0]
padding(K) = 1 - active(K)
lambda(X)  = lambda_lin(X)
```

Sample `tau_lang` and `tau_pad` and define equality-weight tables:

```text
eta_lang(X,K) = eq(tau_lang, (X,K))
eta_pad(X,K)  = eq(tau_pad,  (X,K))
```

Define:

```text
G_lin(X,K)  = lambda(X) * pow2(K) * D(X,K)
G_lang(X,K) = eta_lang(X,K) * active(K)  * N(D(X,K))
G_pad(X,K)  = eta_pad(X,K)  * padding(K) * D(X,K)
```

After sampling `beta_lin`, `beta_lang`, and `beta_pad`:

```text
G = beta_lin * G_lin + beta_lang * G_lang + beta_pad * G_pad
```

Claimed sum:

```text
sum_{Boolean cube} G = beta_lin * c_lin
```

Degree per variable:

- `G_lin`: at most 2;
- `G_pad`: at most 2;
- `G_lang`: at most 4 because `N` is cubic and `eta_lang` is multilinear.

The verifier uses the existing sum-check verifier with expected degree `4`.

## Residual Opening

After sum-check, the verifier has one digit-witness evaluation claim:

```text
D(r_sc) = v_sc
```

Do not add a new PCS. Encode this as a CE opening over a fixed internal
identity/selection CCS shape for the flattened digit witness:

```text
MLE_{r_sc}(I * d_flat) = v_sc
```

The residual proof object:

```text
NumiSealResidualOpening {
  laneKey
  decompositionKeyDigest
  decompositionCommitmentDigest
  evalPointDigest
  claimedValue
  ceOpeningProof
}
```

This is the terminal base case. A NumiSeal verifier accepts only if every lane
aggregate has a valid residual CE opening.

## Recursive Carry

A recursive prover may export a carry claim instead of exposing the full
residual witness:

```text
NumiSealCarryClaim {
  carryKind = digitWitnessMLE
  laneKey
  parentStatementDigest
  decompositionKeyDigest
  commitment = D_lane
  evalPoint = r_sc
  matrixEvaluations = [v_sc]
}
```

Application verification should verify residual openings immediately.
Recursive/aggregate proving may carry them into the next NumiSeal instance.

## Proof Object

```text
NumiSealProof {
  version
  profileID
  obligationRoot
  laneSummaryRoot
  componentDigestRoot
  transcriptDigest
  laneProofs
}

NumiSealLaneProof {
  laneKey
  aggregateIndex
  obligationDigests
  rlcChallenges
  aggregateDigest
  decompositionKeyDigest
  decompositionCommitment
  scalarizationDigest
  sumcheckProof
  residualOpening
  optionalCarryClaim
}
```

Typed component labels:

```text
numiseal.obligation.v1
numiseal.lane-summary.v1
numiseal.public-statement.v1
numiseal.lane-aggregate.v1
numiseal.decomposition.v1
numiseal.scalarization.v1
numiseal.sumcheck.v1
numiseal.residual-opening.v1
numiseal.carry.v1
numiseal.absent-component.v1
```

`componentDigestRoot` is a deterministic digest-list root of all present or
absent component leaves in lane-major order.

## Verifier Algorithm

1. Parse the envelope header.
2. Reject unless `kind == .numiSealTerminal`.
3. Apply `NumiSealAcceptancePolicy`.
4. Recompute canonical obligation order.
5. Recompute obligation and lane roots.
6. Rebuild the transcript schedule.
7. For every lane aggregate:
   - recompute RLC challenges;
   - recompute public aggregates;
   - derive `A_dec`;
   - recompute decomposition key digest;
   - recompute scalarization coefficients and `c_lin`;
   - verify the degree-4 sum-check;
   - verify the residual CE opening.
8. Recompute component root and final transcript digest.
9. Accept only if every lane aggregate accepts.

## Security Claims

NumiSeal v10 may claim:

- completeness for valid terminal CE obligations and correct witnesses;
- binding to profile, shape, statement, verifier key, transcript domain, proof
  kind, lane summaries, and component roots;
- lane-local accumulation soundness under the same small-challenge and
  bounded-decomposition discipline used by PiRLC/PiDEC;
- terminal relation soundness conditioned on Ajtai binding in the stated norm
  regime, soundness of sum-check, and soundness of the residual CE opening
  relation;
- recursive carry soundness conditioned on correct carry encoding and soundness
  of the next verifier layer.

NumiSeal v10 may not claim:

- zero knowledge;
- QROM soundness;
- arbitrary-Ajtai-matrix binding beyond the repo's stated conditional model;
- security for cross-lane batching;
- production certification.

## Zero-Knowledge Track

Default NumiSeal is a correctness/knowledge terminal seal.

`NumiSealZK` is a later layer and needs its own design:

- digit-tensor masking;
- simulator strategy;
- transcript-safe randomness derivation;
- proof that masking composes with residual CE opening;
- randomness-reuse protection across recursive levels;
- side-channel analysis for witness-dependent branches and memory access.

Do not treat the current CE opening masking as a blanket ZK layer.

## Execution Policies

### `.highAssurance`

- CPU-only for secret-bearing work.
- Constant-work CPU paths where already implemented.
- Deterministic loop order and transcript schedule.
- No Metal acceleration for witness-bearing stages.

### `.default`

- Optimized CPU.
- Deterministic serialization.
- Existing automatic Metal routing only where the policy permits it.

### `.cpuRedundantMetal`

- Metal may accelerate array-heavy work.
- Every Metal result used in a soundness-critical path must be checked against
  the CPU oracle before use.

Verifier logic should remain CPU-first until benchmarks show a real verifier
benefit and CPU-redundant checks exist.

## Implementation Plan

### Phase 0: Types And Canonicalization

Files:

```text
SuperNeo-NuMetal/Protocols/NumiSeal/
  NumiSealTypes.swift
  NumiSealCanonicalization.swift
  NumiSealWire.swift
  NumiSealPublicStatement.swift
  NumiSealLaneAggregation.swift
```

Current status:

- `NumiSealTypes.swift` defines lane IDs, lane keys, acceptance policy,
  obligations, canonical obligations, lane summaries, and digest-list roots.
- `NumiSealCanonicalization.swift` validates policy bindings, derives
  evaluation-point digests, sorts obligations deterministically, groups them by
  lane key, and produces obligation/lane summary roots.
- `NumiSealWire.swift` adds bounded readers for lane IDs, lane keys, summaries,
  commitments, public-input encodings, evaluation points, and matrix
  evaluations.
- `NumiSealPublicStatement.swift` defines a versioned, parseable public
  statement that binds profile, shape, statement, verifier key, transcript
  domain, obligation root, lane summary root, and sorted lane summaries.
- `NumiSealLaneAggregation.swift` starts Phase 1 by chunking each lane under
  profile limits, deriving deterministic lane-local RLC challenges, computing
  public aggregates, and giving each aggregate a parse-checked digest.
- Phase 6 still owns the final `ProofEnvelopeKind.numiSealTerminal` body and
  verifier API.

Acceptance:

- deterministic obligation sorting;
- lane-key derivation;
- policy rejection tests;
- digest root fixtures;
- public-statement byte round trips;
- aggregate byte round trips;
- no zero digest placeholders.

### Phase 1: Lane Accumulation

Files:

```text
NumiSealLaneAggregation.swift
```

Acceptance:

- small challenge sampling is bound to the NumiSeal public-statement digest,
  lane key, aggregate index, and canonical obligation digests;
- lane-local public aggregates match direct recomputation;
- cross-lane batching is impossible by construction because chunks are cut only
  inside sorted lane-summary spans;
- lane chunking respects profile limits;
- aggregate bytes reject digest tampering.

### Phase 2: Decomposition Commitment

Files:

```text
NumiSealDecomposition.swift
```

Acceptance:

- deterministic `A_dec` derivation from verifier-key digest and lane key;
- one commitment per lane aggregate;
- digit reconstruction test vectors;
- bad digit and nonzero padding rejection;
- CPU and accelerated commitment outputs match when acceleration is enabled.

### Phase 3: Scalarization

Files:

```text
NumiSealScalarization.swift
```

Acceptance:

- commitment residual fixtures;
- evaluation residual fixtures over sparse CCS matrices;
- public-slot residual fixtures;
- tampering any public terminal equality changes `R_lin`.

### Phase 4: Degree-4 Sum-Check

Files:

```text
NumiSealSumCheck.swift
```

Acceptance:

- expected degree fixed at 4;
- honest proof verifies;
- invalid digit, invalid padding, and wrong `c_lin` reject;
- transcript-domain replay rejects.

### Phase 5: Residual CE Opening

Files:

```text
NumiSealResidualOpening.swift
```

Acceptance:

- fixed internal residual shape has a stable digest;
- residual CE opening verifies through existing CE relation;
- malformed residual opening rejects;
- carry claim encoding is deterministic.

### Phase 6: Envelope And Verifier API

Files:

```text
NumiSealProver.swift
NumiSealVerifier.swift
```

Acceptance:

- `ProofEnvelopeKind.numiSealTerminal = 4`;
- terminal policy rejects fold, terminal-local, and compressed-public envelopes
  when a NumiSeal proof is required;
- NumiSeal policy rejects wrong profile, shape, statement, key, domain, lane,
  byte limit, and component root;
- full one-lane and two-lane vectors verify.

## Test Matrix

Deterministic vectors:

- obligation encoding;
- eval-point digest;
- lane key;
- canonical sorting;
- obligation root;
- lane summary root;
- RLC challenges;
- aggregate commitment/evaluation/public input digests;
- decomposition key digest;
- decomposition commitment;
- scalarization coefficients;
- degree-4 sum-check transcript;
- residual opening statement;
- final envelope digest.

Adversarial tests:

- different evaluation points with same lane ID reject;
- different verifier key digest rejects;
- proof with noncanonical obligation order rejects;
- invalid digit rejects;
- nonzero padding digit rejects;
- wrong scalarization constant rejects;
- wrong decomposition key digest rejects;
- missing component with zero digest rejects;
- residual opening tamper rejects;
- transcript-domain replay rejects;
- proof-kind confusion rejects.

Performance tests:

- one lane;
- two lanes;
- maximum allowed lane aggregate;
- split aggregate over batch limit;
- default CPU;
- high-assurance CPU;
- CPU-redundant Metal for decomposition commitment.

## Formalization Plan

Lean-side definitions:

- `LaneKey`;
- `CanonicalObligationOrder`;
- `DigitTensor`;
- `Reconstruct`;
- `LanguagePolynomial`;
- `ScalarizedLinearResidual`;
- `NumiSealPolynomial`;
- `ResidualCEClaim`;
- `CarryClaim`.

First theorem targets:

1. canonicalization is deterministic;
2. lane grouping never mixes distinct lane keys;
3. digit reconstruction is linear;
4. ternary language polynomial vanishes exactly on allowed digits;
5. scalarization preserves terminal equality except at bad challenges;
6. degree-4 NumiSeal polynomial has the claimed bound;
7. sum-check acceptance plus residual opening implies lane aggregate validity;
8. all lane aggregates valid implies all accepted obligations are valid under
   the lane-local RLC soundness lemma.

Trusted boundaries:

- random-oracle transcript model;
- certified Ajtai binding assumptions already tracked by the repo;
- residual CE opening soundness;
- Swift/Lean serialization equivalence for new NumiSeal wire objects.

## World-Class Acceptance Bar

NumiSeal is not ready until all of the following are true:

- every public byte in the proof is covered by a typed digest leaf;
- every absent optional component is covered by an absent-component digest;
- every challenge has a single documented transcript predecessor;
- no verifier path accepts a fold reduction as terminal proof;
- every profile parameter change requires a new profile ID or a new proof
  version;
- every performance claim has a checked benchmark report;
- every security claim has a named assumption ledger entry or formal theorem
  target;
- every test vector is reproducible from scripts.

## Bottom Line

Ship NumiSeal v10 as a native terminal seal:

1. canonicalize obligations by lane;
2. perform lane-local RLC with small challenges;
3. restore bounds with one committed ternary digit tensor per lane aggregate;
4. scalarize all public terminal equalities into one extension-field residual;
5. combine residual, digit-language, and padding checks into one degree-4
   sum-check;
6. discharge the final digit-witness evaluation through the existing CE opening
   relation;
7. bind the result in a typed proof envelope with explicit recursive carry
   claims.

That path is smaller and cleaner than the current heavy terminal layer, stays
inside the repository's implemented mathematics, respects lane separation, and
creates a precise boundary for future recursion and zero knowledge.
