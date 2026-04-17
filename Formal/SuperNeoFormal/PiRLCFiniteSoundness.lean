import SuperNeoFormal.PiRLCConcreteCollision

/-!
Finite-bad-seed PiRLC soundness.

This is the completed-formal-status replacement for the old
`PiRLCConcreteCollisionBound` boundary group.  The certificate names the exact
finite challenge seeds that may hide a folded-claim collision.
-/

noncomputable section

set_option maxRecDepth 10000

namespace SuperNeoFormal

open Finset

inductive Phi81SplitSide where
  | left
  | right
  deriving DecidableEq

def phi81SplitProjection
    (certificate : Phi81SplitCertificate)
    (side : Phi81SplitSide) : Phi81 → Goldilocks :=
  match side with
  | Phi81SplitSide.left => certificate.leftProjection
  | Phi81SplitSide.right => certificate.rightProjection

def pirlcProjectedDeltas
    {count : Nat}
    (split : Phi81SplitCertificate)
    (side : Phi81SplitSide)
    (deltas : Fin count → Phi81) : Fin count → Goldilocks :=
  fun index => phi81SplitProjection split side (deltas index)

def pirlcProjectedComponentBadValues
    {count : Nat}
    (support : Finset Goldilocks)
    (split : Phi81SplitCertificate)
    (side : Phi81SplitSide)
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Phi81) : Finset Goldilocks :=
  scalarRLCBadPivotValues
    support
    fixedChallenges
    pivot
    (pirlcProjectedDeltas split side deltas)

theorem pirlcProjectedComponentBadValues_card_le_one
    {count : Nat}
    (support : Finset Goldilocks)
    (split : Phi81SplitCertificate)
    (side : Phi81SplitSide)
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivot :
      phi81SplitProjection split side (deltas pivot) ≠ 0) :
    (pirlcProjectedComponentBadValues
      support
      split
      side
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    support
    fixedChallenges
    pivot
    (pirlcProjectedDeltas split side deltas)
    hPivot

abbrev PiRLCRemainingChallengeSeed
    (count : Nat)
    (pivot : Fin count) :=
  { index : Fin count // index ≠ pivot } → Phi81ChallengeSeed

def pirlcRemainingSeed
    {count : Nat}
    (pivot : Fin count)
    (seed : PiRLCChallengeSeed count) :
    PiRLCRemainingChallengeSeed count pivot :=
  fun index => seed index.1

def phi81ChallengeElementFinset [DecidableEq Phi81] : Finset Phi81 :=
  univ.image phi81ChallengeElement

theorem phi81ChallengeElementFinset_card [DecidableEq Phi81] :
    phi81ChallengeElementFinset.card = 5 ^ phi81Degree := by
  rw [phi81ChallengeElementFinset]
  rw [Finset.card_image_of_injective]
  exact phi81ChallengeSeed_card
  exact phi81ChallengeElement_injective

theorem pirlcRemainingChallengeSeed_card
    {count : Nat}
    (pivot : Fin count) :
    Fintype.card (PiRLCRemainingChallengeSeed count pivot) =
      (5 ^ phi81Degree) ^ (count - 1) := by
  simp [PiRLCRemainingChallengeSeed, Phi81ChallengeSeed,
    ChallengeCoefficientChoice]

theorem rlcWeightedSum_eq_ringRLCWithPivot
    {R : Type} [CommRing R]
    {count : Nat}
    (challenges : Fin count → R)
    (pivot : Fin count)
    (deltas : Fin count → R) :
    rlcWeightedSum challenges deltas =
      ringRLCWithPivot challenges pivot deltas (challenges pivot) := by
  rw [rlcWeightedSum, ringRLCWithPivot, ringRLCWithoutPivot]
  have hnot : pivot ∉ ((univ : Finset (Fin count)).erase pivot) := by
    simp
  have huniv :
      insert pivot ((univ : Finset (Fin count)).erase pivot) = univ := by
    ext index
    by_cases hIndex : index = pivot <;> simp [hIndex]
  calc
    (∑ index : Fin count, challenges index * deltas index)
        = ∑ index ∈ insert pivot ((univ : Finset (Fin count)).erase pivot),
            challenges index * deltas index := by
          rw [huniv]
    _ = challenges pivot * deltas pivot +
          ∑ index ∈ (univ : Finset (Fin count)).erase pivot,
            challenges index * deltas index := by
          rw [Finset.sum_insert hnot]

theorem ringRLCWithPivot_eq_rlcWeightedSum_of_eq_off_pivot
    {R : Type} [CommRing R]
    {count : Nat}
    (fixed challenges : Fin count → R)
    (pivot : Fin count)
    (deltas : Fin count → R)
    (hOff : ∀ index, index ≠ pivot → fixed index = challenges index) :
    ringRLCWithPivot fixed pivot deltas (challenges pivot) =
      rlcWeightedSum challenges deltas := by
  rw [rlcWeightedSum_eq_ringRLCWithPivot challenges pivot deltas]
  unfold ringRLCWithPivot ringRLCWithoutPivot
  congr 1
  apply Finset.sum_congr rfl
  intro index hIndex
  have hNe : index ≠ pivot :=
    ne_of_mem_erase hIndex
  rw [hOff index hNe]

def PiRLCUnitPivotCollisionBadSeeds
    {count : Nat} [DecidableEq Phi81]
    (_pivot : Fin count)
    (deltas : Fin count → Phi81) :
    Finset (PiRLCChallengeSeed count) :=
  univ.filter fun seed =>
    rlcWeightedSum (pirlcChallengeElements seed) deltas = 0

theorem pirlc_unitPivotCollisionBadSeeds_mem_iff
    {count : Nat} [DecidableEq Phi81]
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (seed : PiRLCChallengeSeed count) :
    seed ∈ PiRLCUnitPivotCollisionBadSeeds pivot deltas ↔
      rlcWeightedSum (pirlcChallengeElements seed) deltas = 0 := by
  simp [PiRLCUnitPivotCollisionBadSeeds]

theorem pirlc_unitPivotCollisionBadSeeds_remainingSeed_injective
    {count : Nat} [DecidableEq Phi81]
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivotUnit : IsUnit (deltas pivot)) :
    Function.Injective
      (fun seed :
          { seed // seed ∈ PiRLCUnitPivotCollisionBadSeeds pivot deltas } =>
        pirlcRemainingSeed pivot seed.1) := by
  intro lhs rhs hRemaining
  apply Subtype.ext
  funext index
  by_cases hIndex : index = pivot
  · subst index
    apply phi81ChallengeElement_injective
    have hLeftZero :
        rlcWeightedSum (pirlcChallengeElements lhs.1) deltas = 0 :=
      (mem_filter.mp lhs.2).2
    have hRightZero :
        rlcWeightedSum (pirlcChallengeElements rhs.1) deltas = 0 :=
      (mem_filter.mp rhs.2).2
    have hLeftMem :
        pirlcChallengeElements lhs.1 pivot ∈
          ringRLCBadPivotValues
            phi81ChallengeElementFinset
            (pirlcChallengeElements lhs.1)
            pivot
            deltas := by
      rw [ringRLCBadPivotValues]
      refine mem_filter.mpr ?_
      constructor
      · exact mem_image.mpr ⟨lhs.1 pivot, mem_univ _, rfl⟩
      · rw [← rlcWeightedSum_eq_ringRLCWithPivot]
        exact hLeftZero
    have hRightMem :
        pirlcChallengeElements rhs.1 pivot ∈
          ringRLCBadPivotValues
            phi81ChallengeElementFinset
            (pirlcChallengeElements lhs.1)
            pivot
            deltas := by
      rw [ringRLCBadPivotValues]
      refine mem_filter.mpr ?_
      constructor
      · exact mem_image.mpr ⟨rhs.1 pivot, mem_univ _, rfl⟩
      · rw [ringRLCWithPivot_eq_rlcWeightedSum_of_eq_off_pivot]
        · exact hRightZero
        · intro index hNe
          unfold pirlcChallengeElements
          have hAt := congrFun hRemaining ⟨index, hNe⟩
          exact congrArg phi81ChallengeElement hAt
    have hBadCard :
        (ringRLCBadPivotValues
            phi81ChallengeElementFinset
            (pirlcChallengeElements lhs.1)
            pivot
            deltas).card ≤ 1 :=
      ringRLCBadPivotValues_card_le_one_of_unit
        phi81ChallengeElementFinset
        (pirlcChallengeElements lhs.1)
        pivot
        deltas
        hPivotUnit
    exact (Finset.card_le_one.mp hBadCard)
      (pirlcChallengeElements lhs.1 pivot)
      hLeftMem
      (pirlcChallengeElements rhs.1 pivot)
      hRightMem
  · have hAt := congrFun hRemaining ⟨index, hIndex⟩
    exact hAt

theorem PiRLCUnitPivotCollisionBadSeeds_card_le_remaining
    {count : Nat} [DecidableEq Phi81]
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivotUnit : IsUnit (deltas pivot)) :
    (PiRLCUnitPivotCollisionBadSeeds pivot deltas).card ≤
      Fintype.card (PiRLCRemainingChallengeSeed count pivot) := by
  have hCard :=
    Fintype.card_le_of_injective
      (fun seed :
          { seed // seed ∈ PiRLCUnitPivotCollisionBadSeeds pivot deltas } =>
        pirlcRemainingSeed pivot seed.1)
      (pirlc_unitPivotCollisionBadSeeds_remainingSeed_injective
        pivot
        deltas
        hPivotUnit)
  simpa using hCard

theorem PiRLCUnitPivotCollisionBadSeeds_card_le_actualCoefficientSupport
    {count : Nat} [DecidableEq Phi81]
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivotUnit : IsUnit (deltas pivot)) :
    (PiRLCUnitPivotCollisionBadSeeds pivot deltas).card ≤
      (5 ^ phi81Degree) ^ (count - 1) := by
  simpa [pirlcRemainingChallengeSeed_card pivot] using
    PiRLCUnitPivotCollisionBadSeeds_card_le_remaining
      pivot
      deltas
      hPivotUnit

structure PiRLCFiniteBadSeedCertificate
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) where
  split : Phi81SplitCertificate
  badSeeds : Finset (PiRLCChallengeSeed count)
  card_le : badSeeds.card ≤ bound
  covers_failure :
    ∀ seed,
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        seed →
          seed ∈ badSeeds

theorem pirlc_concrete_badSeedCount_le_of_certificate
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (certificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound) :
    (PiRLCBadSeedFinset
      (PiRLCConcreteAccepts point)
      foldedSound
      inputSound
      claims).card ≤ bound :=
  pirlc_badSeedCount_le_of_collisionSet
    (collisionSet := certificate.badSeeds)
    certificate.covers_failure
    certificate.card_le

def pirlc_certificate_split
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound) :
    Phi81SplitCertificate :=
  certificate.split

theorem pirlc_allInputsSound_of_seed_not_bad
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {seed : PiRLCChallengeSeed count}
    {folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound)
    (hSeed : seed ∉ certificate.badSeeds)
    (hAccepts : PiRLCConcreteAccepts point seed claims folded)
    (hFoldedSound : foldedSound folded) :
    AllClaimsSound inputSound claims := by
  by_contra hUnsound
  exact hSeed
    (certificate.covers_failure
      seed
      ⟨folded, hAccepts, hFoldedSound, hUnsound⟩)

def PiRLCComponentwiseSplitCertificate
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) : Prop :=
  ∃ _split : Phi81SplitCertificate,
    ∃ _badSeedCertificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound,
        True

theorem pirlc_certificate_from_componentwise_split
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCComponentwiseSplitCertificate point foldedSound inputSound claims bound) :
    ∃ _badSeedCertificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound,
        True := by
  rcases certificate with ⟨_split, badSeedCertificate, hTrivial⟩
  exact ⟨badSeedCertificate, hTrivial⟩

end SuperNeoFormal
