import SuperNeoFormal.PiRLCConcreteCollision

/-!
Finite-bad-seed PiRLC soundness.

This file keeps the finite bad-seed set constructive: bad seeds are the filtered
fold-failure seeds from `PiRLCBadSeedFinset`, and the CRT endpoint records the
component localization needed to count them without the older split-certificate
carrier.
-/

noncomputable section

set_option maxRecDepth 10000

namespace SuperNeoFormal

open Finset Polynomial

inductive PiRLCCRTComponentSide where
  | left
  | right
  deriving DecidableEq

def phi81CRTComponentDegree : Nat :=
  phi81Degree / 2

theorem phi81CRTComponentDegree_eq :
    phi81CRTComponentDegree = 27 := by
  native_decide

def PiRLCCRTComponentNonzero
    {count : Nat}
    (pivot : Fin count)
    (deltas : Fin count → Phi81) :
    PiRLCCRTComponentSide → Prop
  | .left => pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0
  | .right => pirlcCRTRightProjectedDeltas deltas pivot ≠ 0

theorem pirlcCRTComponentNonzero_exists_of_pivot_ne_zero
    {count : Nat}
    {pivot : Fin count}
    {deltas : Fin count → Phi81}
    (hPivot : deltas pivot ≠ 0) :
    ∃ side, PiRLCCRTComponentNonzero pivot deltas side := by
  rcases pirlcCRT_nonzero_pivot_has_nonzero_component hPivot with hLeft | hRight
  · exact ⟨PiRLCCRTComponentSide.left, hLeft⟩
  · exact ⟨PiRLCCRTComponentSide.right, hRight⟩

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

def phi81CRTLeftChallengeElementFinset [DecidableEq Phi81CRTLeft] :
    Finset Phi81CRTLeft :=
  univ.image fun seed : Phi81ChallengeSeed =>
    phi81CRTLeftProjection (phi81ChallengeElement seed)

def phi81CRTRightChallengeElementFinset [DecidableEq Phi81CRTRight] :
    Finset Phi81CRTRight :=
  univ.image fun seed : Phi81ChallengeSeed =>
    phi81CRTRightProjection (phi81ChallengeElement seed)

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

theorem rlcWeightedSum_eq_scalarRLCWithPivot
    {F : Type} [Field F]
    {count : Nat}
    (challenges : Fin count → F)
    (pivot : Fin count)
    (deltas : Fin count → F) :
    rlcWeightedSum challenges deltas =
      scalarRLCWithPivot challenges pivot deltas (challenges pivot) := by
  simpa [scalarRLCWithPivot, scalarRLCWithoutPivot,
    ringRLCWithPivot, ringRLCWithoutPivot] using
    rlcWeightedSum_eq_ringRLCWithPivot challenges pivot deltas

theorem scalarRLCWithPivot_eq_rlcWeightedSum_of_eq_off_pivot
    {F : Type} [Field F]
    {count : Nat}
    (fixed challenges : Fin count → F)
    (pivot : Fin count)
    (deltas : Fin count → F)
    (hOff : ∀ index, index ≠ pivot → fixed index = challenges index) :
    scalarRLCWithPivot fixed pivot deltas (challenges pivot) =
      rlcWeightedSum challenges deltas := by
  simpa [scalarRLCWithPivot, scalarRLCWithoutPivot,
    ringRLCWithPivot, ringRLCWithoutPivot] using
    ringRLCWithPivot_eq_rlcWeightedSum_of_eq_off_pivot
      fixed
      challenges
      pivot
      deltas
      hOff

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

abbrev PiRLCConstructiveBadSeeds
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)] :
    Finset (PiRLCChallengeSeed count) :=
  PiRLCBadSeedFinset
    (PiRLCConcreteAccepts point)
    foldedSound
    inputSound
    claims

theorem pirlc_constructiveBadSeeds_mem_iff
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (seed : PiRLCChallengeSeed count) :
    seed ∈ PiRLCConstructiveBadSeeds point foldedSound inputSound claims ↔
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        seed := by
  simp [PiRLCConstructiveBadSeeds, PiRLCBadSeedFinset]

def PiRLCFailureDeltaCollision
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (deltas : Fin count → Phi81) : Prop :=
  ∀ seed,
    PiRLCFoldFailure
      (PiRLCConcreteAccepts point)
      foldedSound
      inputSound
      claims
      seed →
        rlcWeightedSum (pirlcChallengeElements seed) deltas = 0

structure PiRLCLinearDefectSemantics
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars) where
  defect : EvaluationClaim Phi81 rows publicCount evalCount pointVars → Phi81
  accepted_fold_defect :
    ∀ seed folded,
      PiRLCConcreteAccepts point seed claims folded →
        defect folded =
          rlcWeightedSum
            (pirlcChallengeElements seed)
            (fun index => defect (claims index))
  foldedSound_defect_zero :
    ∀ folded,
      foldedSound folded →
        defect folded = 0
  inputSound_iff_defect_zero :
    ∀ claim,
      inputSound claim ↔ defect claim = 0

theorem pirlc_failureDeltaCollision_of_linearDefectSemantics
    {count rows publicCount evalCount pointVars : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (semantics :
      PiRLCLinearDefectSemantics point foldedSound inputSound claims) :
    PiRLCFailureDeltaCollision
      point
      foldedSound
      inputSound
      claims
      (fun index => semantics.defect (claims index)) := by
  intro seed hFailure
  rcases hFailure with ⟨folded, hAccepts, hFoldedSound, _hUnsound⟩
  rw [← semantics.accepted_fold_defect seed folded hAccepts]
  exact semantics.foldedSound_defect_zero folded hFoldedSound

theorem pirlc_linearDefectSemantics_exists_nonzero_pivot
    {count rows publicCount evalCount pointVars : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (semantics :
      PiRLCLinearDefectSemantics point foldedSound inputSound claims)
    (hUnsound : ¬ AllClaimsSound inputSound claims) :
    ∃ pivot,
      (fun index => semantics.defect (claims index)) pivot ≠ 0 := by
  rw [AllClaimsSound] at hUnsound
  push_neg at hUnsound
  rcases hUnsound with ⟨pivot, hNotSound⟩
  refine ⟨pivot, ?_⟩
  intro hZero
  exact hNotSound
    ((semantics.inputSound_iff_defect_zero (claims pivot)).mpr hZero)

def PiRLCObservationSound
    {rows publicCount evalCount pointVars : Nat}
    (observation :
      RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars)
    (claim : EvaluationClaim Phi81 rows publicCount evalCount pointVars) : Prop :=
  observation.observe claim = 0

def PiRLCObservationFamilySound
    {rows publicCount evalCount pointVars : Nat}
    {ObservationIndex : Type}
    (observations :
      ObservationIndex →
        RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars)
    (claim : EvaluationClaim Phi81 rows publicCount evalCount pointVars) : Prop :=
  ∀ observationIndex,
    PiRLCObservationSound (observations observationIndex) claim

def PiRLCPublicFieldObservationSound
    {rows publicCount evalCount pointVars : Nat}
    (claim : EvaluationClaim Phi81 rows publicCount evalCount pointVars) : Prop :=
  PiRLCObservationFamilySound
    (fun index : RLCClaimPublicFieldIndex rows publicCount evalCount =>
      rlcPublicFieldObservation (RF := Phi81) (pointVars := pointVars) index)
    claim

theorem pirlc_publicFieldObservationSound_iff_fields_zero
    {rows publicCount evalCount pointVars : Nat}
    (claim : EvaluationClaim Phi81 rows publicCount evalCount pointVars) :
    PiRLCPublicFieldObservationSound claim ↔
      RLCClaimPublicFieldsZero claim := by
  simpa [
    PiRLCPublicFieldObservationSound,
    PiRLCObservationFamilySound,
    PiRLCObservationSound,
    RLCClaimPublicFieldObservationSound
  ] using
    rlcPublicFieldObservationSound_iff_fields_zero
      (RF := Phi81)
      (claim := claim)

def pirlc_linearObservationDefectSemantics
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (observation :
      RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars) :
    PiRLCLinearDefectSemantics
      point
      (PiRLCObservationSound observation)
      (PiRLCObservationSound observation)
      claims where
  defect := observation.observe
  accepted_fold_defect := by
    intro seed folded hAccepts
    rcases hAccepts with ⟨hFolded, _hPoints⟩
    rw [hFolded]
    exact observation.observe_rlcWeightedClaim
      point
      (pirlcChallengeElements seed)
      claims
  foldedSound_defect_zero := by
    intro folded hSound
    exact hSound
  inputSound_iff_defect_zero := by
    intro claim
    rfl

theorem pirlc_constructive_badSeeds_subset_unitPivotCollisionBadSeeds
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    PiRLCConstructiveBadSeeds point foldedSound inputSound claims ⊆
      PiRLCUnitPivotCollisionBadSeeds pivot deltas := by
  intro seed hSeed
  rw [pirlc_unitPivotCollisionBadSeeds_mem_iff]
  exact hCollision seed
    ((pirlc_constructiveBadSeeds_mem_iff
      point
      foldedSound
      inputSound
      claims
      seed).mp hSeed)

theorem pirlc_constructive_badSeedCount_le_of_unitPivotDeltaCollision
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivotUnit : IsUnit (deltas pivot))
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    (PiRLCConstructiveBadSeeds point foldedSound inputSound claims).card ≤
      (5 ^ phi81Degree) ^ (count - 1) := by
  have hSubset :
      PiRLCConstructiveBadSeeds point foldedSound inputSound claims ⊆
        PiRLCUnitPivotCollisionBadSeeds pivot deltas :=
    pirlc_constructive_badSeeds_subset_unitPivotCollisionBadSeeds
      pivot
      hCollision
  exact le_trans
    (Finset.card_le_card hSubset)
    (PiRLCUnitPivotCollisionBadSeeds_card_le_actualCoefficientSupport
      pivot
      deltas
      hPivotUnit)

structure PiRLCConstructiveFiniteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) where
  badSeeds : Finset (PiRLCChallengeSeed count)
  card_le : badSeeds.card ≤ bound
  allInputsSound_outside_bad :
    ∀ seed folded,
      PiRLCConcreteAccepts point seed claims folded →
        foldedSound folded →
          seed ∉ badSeeds →
            AllClaimsSound inputSound claims

def pirlc_constructive_finiteSoundnessCertificate
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
    (hCard :
      (PiRLCConstructiveBadSeeds point foldedSound inputSound claims).card ≤
        bound) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      bound where
  badSeeds := PiRLCConstructiveBadSeeds point foldedSound inputSound claims
  card_le := hCard
  allInputsSound_outside_bad := by
    intro seed folded hAccepts hFoldedSound hSeed
    by_contra hUnsound
    exact hSeed
      (by
        rw [pirlc_constructiveBadSeeds_mem_iff]
        exact ⟨folded, hAccepts, hFoldedSound, hUnsound⟩)

def pirlc_constructive_finiteSoundnessCertificate_of_allInputsSound
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (hAll : AllClaimsSound inputSound claims) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      bound where
  badSeeds := ∅
  card_le := by simp
  allInputsSound_outside_bad := by
    intro _seed _folded _hAccepts _hFoldedSound _hSeed
    exact hAll

def pirlc_unitPivotDeltaCollision_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivotUnit : IsUnit (deltas pivot))
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      ((5 ^ phi81Degree) ^ (count - 1)) :=
  pirlc_constructive_finiteSoundnessCertificate
    (pirlc_constructive_badSeedCount_le_of_unitPivotDeltaCollision
      pivot
      hPivotUnit
      hCollision)

structure PiRLCUnitPivotDeltaCollisionEvidence
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)] where
  deltas : Fin count → Phi81
  pivot : Fin count
  pivot_unit : IsUnit (deltas pivot)
  failure_delta_collision :
    PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas

def pirlc_unitPivotDeltaCollisionEvidence_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81]
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
    (evidence :
      PiRLCUnitPivotDeltaCollisionEvidence
        point
        foldedSound
        inputSound
        claims) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      ((5 ^ phi81Degree) ^ (count - 1)) :=
  pirlc_unitPivotDeltaCollision_finiteSoundnessCertificate
    evidence.pivot
    evidence.pivot_unit
    evidence.failure_delta_collision

structure PiRLCCRTConstructiveFailureLocalization
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (deltas : Fin count → Phi81)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)] where
  pivot : Fin count
  component : PiRLCCRTComponentSide
  component_nonzero : PiRLCCRTComponentNonzero pivot deltas component
  remainingSeed_injective :
    Function.Injective
      (fun seed :
          { seed // seed ∈
            PiRLCConstructiveBadSeeds point foldedSound inputSound claims } =>
        pirlcRemainingSeed pivot seed.1)

def PiRLCCRTComponentBadSeedBudget
    (count : Nat) : Nat :=
  (5 ^ phi81Degree) ^ (count - 1) * 5 ^ phi81CRTComponentDegree

abbrev PiRLCCRTComponentPivotFiber :=
  Fin phi81CRTComponentDegree → ChallengeCoefficientChoice

/--
The conservative CRT component count indexes each projection fiber by the upper
27 sampled challenge coefficients. If two full degree-54 seeds have the same
component projection and the same upper half, their polynomial difference has
degree below the monic degree-27 CRT factor, so the seeds are equal.
-/
def phi81ChallengeSeedHighIndex
    (index : Fin phi81CRTComponentDegree) :
    Fin phi81Degree :=
  ⟨index.val + phi81CRTComponentDegree, by
    have hIndex : index.val < phi81CRTComponentDegree := index.isLt
    have hComponentDegree : phi81CRTComponentDegree = 27 :=
      phi81CRTComponentDegree_eq
    have hPhiDegree : phi81Degree = 54 :=
      phi81Degree_eq
    omega⟩

def phi81ChallengeSeedHighHalf
    (seed : Phi81ChallengeSeed) :
    PiRLCCRTComponentPivotFiber :=
  fun index => seed (phi81ChallengeSeedHighIndex index)

theorem phi81ChallengeSeedHighHalf_eq_at
    {lhs rhs : Phi81ChallengeSeed}
    (hHigh :
      phi81ChallengeSeedHighHalf lhs = phi81ChallengeSeedHighHalf rhs)
    {index : Fin phi81Degree}
    (hIndex : phi81CRTComponentDegree ≤ index.val) :
    lhs index = rhs index := by
  have hUpper :
      index.val - phi81CRTComponentDegree < phi81CRTComponentDegree := by
    have hLt : index.val < phi81Degree := index.isLt
    have hComponentDegree : phi81CRTComponentDegree = 27 :=
      phi81CRTComponentDegree_eq
    have hPhiDegree : phi81Degree = 54 :=
      phi81Degree_eq
    omega
  let highIndex : Fin phi81CRTComponentDegree :=
    ⟨index.val - phi81CRTComponentDegree, hUpper⟩
  have hAt := congrFun hHigh highIndex
  have hFin : phi81ChallengeSeedHighIndex highIndex = index := by
    apply Fin.ext
    have hLowerNat : 27 ≤ index.val := by
      simpa [phi81CRTComponentDegree] using hIndex
    have hValue :
        (index.val - phi81CRTComponentDegree) +
          phi81CRTComponentDegree = index.val := by
      omega
    simpa [phi81ChallengeSeedHighIndex, highIndex] using hValue
  simpa [phi81ChallengeSeedHighHalf, hFin] using hAt

theorem phi81ChallengePolynomial_sub_natDegree_lt_component
    {lhs rhs : Phi81ChallengeSeed}
    (hHigh :
      phi81ChallengeSeedHighHalf lhs = phi81ChallengeSeedHighHalf rhs) :
    (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
      phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)).natDegree <
      phi81CRTComponentDegree := by
  have hLe :
      (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
        phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)).natDegree ≤
        phi81CRTComponentDegree - 1 := by
    rw [Polynomial.natDegree_le_iff_coeff_eq_zero]
    intro exponent hExponent
    by_cases hInside : exponent < phi81Degree
    · let coeffIndex : Fin phi81Degree := ⟨exponent, hInside⟩
      have hComponent : phi81CRTComponentDegree ≤ coeffIndex.val := by
        have hExponentNat : 26 < exponent := by
          have hComponentDegree : phi81CRTComponentDegree = 27 :=
            phi81CRTComponentDegree_eq
          omega
        have hBound : 27 ≤ exponent := by
          omega
        simpa [phi81CRTComponentDegree, coeffIndex] using hBound
      have hSeed :
          lhs coeffIndex = rhs coeffIndex :=
        phi81ChallengeSeedHighHalf_eq_at hHigh hComponent
      have hCoeff :
          phi81ChallengeCoefficients lhs coeffIndex =
            phi81ChallengeCoefficients rhs coeffIndex := by
        simpa [phi81ChallengeCoefficients] using
          congrArg challengeCoefficientGoldilocks hSeed
      have hLeftCoeff :
          (phi81CoeffsToPolynomial
            (phi81ChallengeCoefficients lhs)).coeff exponent =
            phi81ChallengeCoefficients lhs coeffIndex := by
        simpa [coeffIndex] using
          phi81CoeffsToPolynomial_coeff
            (phi81ChallengeCoefficients lhs)
            coeffIndex
      have hRightCoeff :
          (phi81CoeffsToPolynomial
            (phi81ChallengeCoefficients rhs)).coeff exponent =
            phi81ChallengeCoefficients rhs coeffIndex := by
        simpa [coeffIndex] using
          phi81CoeffsToPolynomial_coeff
            (phi81ChallengeCoefficients rhs)
            coeffIndex
      rw [Polynomial.coeff_sub, hLeftCoeff, hRightCoeff, hCoeff, sub_self]
    · have hLeftZero :
          (phi81CoeffsToPolynomial
            (phi81ChallengeCoefficients lhs)).coeff exponent = 0 := by
        exact coeff_eq_zero_of_natDegree_lt
          (lt_of_lt_of_le
            (phi81CoeffsToPolynomial_natDegree_lt
              (phi81ChallengeCoefficients lhs))
            (le_of_not_gt hInside))
      have hRightZero :
          (phi81CoeffsToPolynomial
            (phi81ChallengeCoefficients rhs)).coeff exponent = 0 := by
        exact coeff_eq_zero_of_natDegree_lt
          (lt_of_lt_of_le
            (phi81CoeffsToPolynomial_natDegree_lt
              (phi81ChallengeCoefficients rhs))
            (le_of_not_gt hInside))
      simp [Polynomial.coeff_sub, hLeftZero, hRightZero]
  have hComponentPositive : 0 < phi81CRTComponentDegree := by
    rw [phi81CRTComponentDegree_eq]
    norm_num
  exact lt_of_le_of_lt hLe
    (Nat.sub_one_lt (Nat.ne_of_gt hComponentPositive))

theorem phi81CRTLeftProjection_eq_and_highHalf_eq_imp_seed_eq
    {lhs rhs : Phi81ChallengeSeed}
    (hProjection :
      phi81CRTLeftProjection (phi81ChallengeElement lhs) =
        phi81CRTLeftProjection (phi81ChallengeElement rhs))
    (hHigh :
      phi81ChallengeSeedHighHalf lhs = phi81ChallengeSeedHighHalf rhs) :
    lhs = rhs := by
  apply phi81ChallengeCoefficients_injective
  apply phi81CoeffsToPolynomial_injective
  apply sub_eq_zero.mp
  by_contra hDiff
  have hMk :
      (Ideal.Quotient.mk phi81CRTLeftIdeal
        (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
          phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)) :
          Phi81CRTLeft) = 0 := by
    simpa [phi81ChallengeElement, phi81CoeffsToQuotient, map_sub] using
      (sub_eq_zero.mpr hProjection :
        phi81CRTLeftProjection (phi81ChallengeElement lhs) -
          phi81CRTLeftProjection (phi81ChallengeElement rhs) = 0)
  have hDvd :
      phi81CRTLeftPolynomial ∣
        phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
          phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs) := by
    change
      AdjoinRoot.mk phi81CRTLeftPolynomial
          (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
            phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)) = 0 at hMk
    exact AdjoinRoot.mk_eq_zero.mp hMk
  have hDegree :
      (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
        phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)).natDegree <
        phi81CRTLeftPolynomial.natDegree := by
    rw [phi81CRTLeftPolynomial_natDegree]
    simpa [phi81CRTComponentDegree_eq] using
      phi81ChallengePolynomial_sub_natDegree_lt_component hHigh
  exact
    (phi81CRTLeftPolynomial_monic.not_dvd_of_natDegree_lt hDiff hDegree)
      hDvd

theorem phi81CRTRightProjection_eq_and_highHalf_eq_imp_seed_eq
    {lhs rhs : Phi81ChallengeSeed}
    (hProjection :
      phi81CRTRightProjection (phi81ChallengeElement lhs) =
        phi81CRTRightProjection (phi81ChallengeElement rhs))
    (hHigh :
      phi81ChallengeSeedHighHalf lhs = phi81ChallengeSeedHighHalf rhs) :
    lhs = rhs := by
  apply phi81ChallengeCoefficients_injective
  apply phi81CoeffsToPolynomial_injective
  apply sub_eq_zero.mp
  by_contra hDiff
  have hMk :
      (Ideal.Quotient.mk phi81CRTRightIdeal
        (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
          phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)) :
          Phi81CRTRight) = 0 := by
    simpa [phi81ChallengeElement, phi81CoeffsToQuotient, map_sub] using
      (sub_eq_zero.mpr hProjection :
        phi81CRTRightProjection (phi81ChallengeElement lhs) -
          phi81CRTRightProjection (phi81ChallengeElement rhs) = 0)
  have hDvd :
      phi81CRTRightPolynomial ∣
        phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
          phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs) := by
    change
      AdjoinRoot.mk phi81CRTRightPolynomial
          (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
            phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)) = 0 at hMk
    exact AdjoinRoot.mk_eq_zero.mp hMk
  have hDegree :
      (phi81CoeffsToPolynomial (phi81ChallengeCoefficients lhs) -
        phi81CoeffsToPolynomial (phi81ChallengeCoefficients rhs)).natDegree <
        phi81CRTRightPolynomial.natDegree := by
    rw [phi81CRTRightPolynomial_natDegree]
    simpa [phi81CRTComponentDegree_eq] using
      phi81ChallengePolynomial_sub_natDegree_lt_component hHigh
  exact
    (phi81CRTRightPolynomial_monic.not_dvd_of_natDegree_lt hDiff hDegree)
      hDvd

structure PiRLCCRTComponentFailureLocalization
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (deltas : Fin count → Phi81)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)] where
  pivot : Fin count
  component : PiRLCCRTComponentSide
  component_nonzero : PiRLCCRTComponentNonzero pivot deltas component
  failureTarget :
    { seed // seed ∈
      PiRLCConstructiveBadSeeds point foldedSound inputSound claims } →
      PiRLCRemainingChallengeSeed count pivot × PiRLCCRTComponentPivotFiber
  failureTarget_injective : Function.Injective failureTarget

structure PiRLCCRTLeftPivotFiberIndex where
  fiberIndex : Phi81ChallengeSeed → PiRLCCRTComponentPivotFiber
  fiberIndex_injective :
    ∀ {lhs rhs : Phi81ChallengeSeed},
      phi81CRTLeftProjection (phi81ChallengeElement lhs) =
          phi81CRTLeftProjection (phi81ChallengeElement rhs) →
        fiberIndex lhs = fiberIndex rhs →
          lhs = rhs

structure PiRLCCRTRightPivotFiberIndex where
  fiberIndex : Phi81ChallengeSeed → PiRLCCRTComponentPivotFiber
  fiberIndex_injective :
    ∀ {lhs rhs : Phi81ChallengeSeed},
      phi81CRTRightProjection (phi81ChallengeElement lhs) =
          phi81CRTRightProjection (phi81ChallengeElement rhs) →
        fiberIndex lhs = fiberIndex rhs →
          lhs = rhs

def pirlcCRTLeftHighHalfPivotFiberIndex :
    PiRLCCRTLeftPivotFiberIndex where
  fiberIndex := phi81ChallengeSeedHighHalf
  fiberIndex_injective := by
    intro lhs rhs hProjection hFiber
    exact
      phi81CRTLeftProjection_eq_and_highHalf_eq_imp_seed_eq
        hProjection
        hFiber

def pirlcCRTRightHighHalfPivotFiberIndex :
    PiRLCCRTRightPivotFiberIndex where
  fiberIndex := phi81ChallengeSeedHighHalf
  fiberIndex_injective := by
    intro lhs rhs hProjection hFiber
    exact
      phi81CRTRightProjection_eq_and_highHalf_eq_imp_seed_eq
        hProjection
        hFiber

theorem pirlcCRTLeft_badSeeds_same_remaining_have_same_pivot_projection
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
    {lhs rhs :
      { seed // seed ∈
        PiRLCConstructiveBadSeeds point foldedSound inputSound claims }}
    (hRemaining : pirlcRemainingSeed pivot lhs.1 = pirlcRemainingSeed pivot rhs.1) :
    phi81CRTLeftProjection (phi81ChallengeElement (lhs.1 pivot)) =
      phi81CRTLeftProjection (phi81ChallengeElement (rhs.1 pivot)) := by
  let fixedChallenges :=
    pirlcCRTLeftProjectedChallenges (pirlcChallengeElements lhs.1)
  let rhsChallenges :=
    pirlcCRTLeftProjectedChallenges (pirlcChallengeElements rhs.1)
  let projectedDeltas :=
    pirlcCRTLeftProjectedDeltas deltas
  have hLeftFailure :
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        lhs.1 :=
    (pirlc_constructiveBadSeeds_mem_iff
      point
      foldedSound
      inputSound
      claims
      lhs.1).mp lhs.2
  have hRightFailure :
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        rhs.1 :=
    (pirlc_constructiveBadSeeds_mem_iff
      point
      foldedSound
      inputSound
      claims
      rhs.1).mp rhs.2
  have hLeftZero :
      rlcWeightedSum fixedChallenges projectedDeltas = 0 := by
    have hFull := hCollision lhs.1 hLeftFailure
    simpa [fixedChallenges, projectedDeltas,
      phi81CRTLeftProjection_rlcWeightedSum] using
      congrArg phi81CRTLeftProjection hFull
  have hRightZero :
      rlcWeightedSum rhsChallenges projectedDeltas = 0 := by
    have hFull := hCollision rhs.1 hRightFailure
    simpa [rhsChallenges, projectedDeltas,
      phi81CRTLeftProjection_rlcWeightedSum] using
      congrArg phi81CRTLeftProjection hFull
  have hOff :
      ∀ index, index ≠ pivot → fixedChallenges index = rhsChallenges index := by
    intro index hNe
    have hSeed := congrFun hRemaining ⟨index, hNe⟩
    exact congrArg
      (fun seed => phi81CRTLeftProjection (phi81ChallengeElement seed))
      hSeed
  have hLeftMem :
      phi81CRTLeftProjection (phi81ChallengeElement (lhs.1 pivot)) ∈
        pirlcCRTLeftBadPivotValues
          phi81CRTLeftChallengeElementFinset
          (pirlcChallengeElements lhs.1)
          pivot
          deltas := by
    rw [pirlcCRTLeftBadPivotValues, scalarRLCBadPivotValues]
    refine mem_filter.mpr ?_
    constructor
    · exact mem_image.mpr ⟨lhs.1 pivot, mem_univ _, rfl⟩
    · change
        scalarRLCWithPivot fixedChallenges pivot projectedDeltas
          (fixedChallenges pivot) = 0
      rw [← rlcWeightedSum_eq_scalarRLCWithPivot]
      exact hLeftZero
  have hRightMem :
      phi81CRTLeftProjection (phi81ChallengeElement (rhs.1 pivot)) ∈
        pirlcCRTLeftBadPivotValues
          phi81CRTLeftChallengeElementFinset
          (pirlcChallengeElements lhs.1)
          pivot
          deltas := by
    rw [pirlcCRTLeftBadPivotValues, scalarRLCBadPivotValues]
    refine mem_filter.mpr ?_
    constructor
    · exact mem_image.mpr ⟨rhs.1 pivot, mem_univ _, rfl⟩
    · change
        scalarRLCWithPivot fixedChallenges pivot projectedDeltas
          (rhsChallenges pivot) = 0
      calc
        scalarRLCWithPivot fixedChallenges pivot projectedDeltas
            (rhsChallenges pivot)
            = rlcWeightedSum rhsChallenges projectedDeltas :=
              scalarRLCWithPivot_eq_rlcWeightedSum_of_eq_off_pivot
                fixedChallenges
                rhsChallenges
                pivot
                projectedDeltas
                hOff
        _ = 0 := hRightZero
  have hBadCard :
      (pirlcCRTLeftBadPivotValues
        phi81CRTLeftChallengeElementFinset
        (pirlcChallengeElements lhs.1)
        pivot
        deltas).card ≤ 1 :=
    pirlcCRTLeftBadPivotValues_card_le_one
      phi81CRTLeftChallengeElementFinset
      (pirlcChallengeElements lhs.1)
      pivot
      deltas
      hPivot
  exact (Finset.card_le_one.mp hBadCard)
    (phi81CRTLeftProjection (phi81ChallengeElement (lhs.1 pivot)))
    hLeftMem
    (phi81CRTLeftProjection (phi81ChallengeElement (rhs.1 pivot)))
    hRightMem

theorem pirlcCRTRight_badSeeds_same_remaining_have_same_pivot_projection
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTRight]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
    {lhs rhs :
      { seed // seed ∈
        PiRLCConstructiveBadSeeds point foldedSound inputSound claims }}
    (hRemaining : pirlcRemainingSeed pivot lhs.1 = pirlcRemainingSeed pivot rhs.1) :
    phi81CRTRightProjection (phi81ChallengeElement (lhs.1 pivot)) =
      phi81CRTRightProjection (phi81ChallengeElement (rhs.1 pivot)) := by
  let fixedChallenges :=
    pirlcCRTRightProjectedChallenges (pirlcChallengeElements lhs.1)
  let rhsChallenges :=
    pirlcCRTRightProjectedChallenges (pirlcChallengeElements rhs.1)
  let projectedDeltas :=
    pirlcCRTRightProjectedDeltas deltas
  have hLeftFailure :
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        lhs.1 :=
    (pirlc_constructiveBadSeeds_mem_iff
      point
      foldedSound
      inputSound
      claims
      lhs.1).mp lhs.2
  have hRightFailure :
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        rhs.1 :=
    (pirlc_constructiveBadSeeds_mem_iff
      point
      foldedSound
      inputSound
      claims
      rhs.1).mp rhs.2
  have hLeftZero :
      rlcWeightedSum fixedChallenges projectedDeltas = 0 := by
    have hFull := hCollision lhs.1 hLeftFailure
    simpa [fixedChallenges, projectedDeltas,
      phi81CRTRightProjection_rlcWeightedSum] using
      congrArg phi81CRTRightProjection hFull
  have hRightZero :
      rlcWeightedSum rhsChallenges projectedDeltas = 0 := by
    have hFull := hCollision rhs.1 hRightFailure
    simpa [rhsChallenges, projectedDeltas,
      phi81CRTRightProjection_rlcWeightedSum] using
      congrArg phi81CRTRightProjection hFull
  have hOff :
      ∀ index, index ≠ pivot → fixedChallenges index = rhsChallenges index := by
    intro index hNe
    have hSeed := congrFun hRemaining ⟨index, hNe⟩
    exact congrArg
      (fun seed => phi81CRTRightProjection (phi81ChallengeElement seed))
      hSeed
  have hLeftMem :
      phi81CRTRightProjection (phi81ChallengeElement (lhs.1 pivot)) ∈
        pirlcCRTRightBadPivotValues
          phi81CRTRightChallengeElementFinset
          (pirlcChallengeElements lhs.1)
          pivot
          deltas := by
    rw [pirlcCRTRightBadPivotValues, scalarRLCBadPivotValues]
    refine mem_filter.mpr ?_
    constructor
    · exact mem_image.mpr ⟨lhs.1 pivot, mem_univ _, rfl⟩
    · change
        scalarRLCWithPivot fixedChallenges pivot projectedDeltas
          (fixedChallenges pivot) = 0
      rw [← rlcWeightedSum_eq_scalarRLCWithPivot]
      exact hLeftZero
  have hRightMem :
      phi81CRTRightProjection (phi81ChallengeElement (rhs.1 pivot)) ∈
        pirlcCRTRightBadPivotValues
          phi81CRTRightChallengeElementFinset
          (pirlcChallengeElements lhs.1)
          pivot
          deltas := by
    rw [pirlcCRTRightBadPivotValues, scalarRLCBadPivotValues]
    refine mem_filter.mpr ?_
    constructor
    · exact mem_image.mpr ⟨rhs.1 pivot, mem_univ _, rfl⟩
    · change
        scalarRLCWithPivot fixedChallenges pivot projectedDeltas
          (rhsChallenges pivot) = 0
      calc
        scalarRLCWithPivot fixedChallenges pivot projectedDeltas
            (rhsChallenges pivot)
            = rlcWeightedSum rhsChallenges projectedDeltas :=
              scalarRLCWithPivot_eq_rlcWeightedSum_of_eq_off_pivot
                fixedChallenges
                rhsChallenges
                pivot
                projectedDeltas
                hOff
        _ = 0 := hRightZero
  have hBadCard :
      (pirlcCRTRightBadPivotValues
        phi81CRTRightChallengeElementFinset
        (pirlcChallengeElements lhs.1)
        pivot
        deltas).card ≤ 1 :=
    pirlcCRTRightBadPivotValues_card_le_one
      phi81CRTRightChallengeElementFinset
      (pirlcChallengeElements lhs.1)
      pivot
      deltas
      hPivot
  exact (Finset.card_le_one.mp hBadCard)
    (phi81CRTRightProjection (phi81ChallengeElement (lhs.1 pivot)))
    hLeftMem
    (phi81CRTRightProjection (phi81ChallengeElement (rhs.1 pivot)))
    hRightMem

def pirlc_leftCRTComponentFailureLocalization_of_deltaCollision
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
    (fiber : PiRLCCRTLeftPivotFiberIndex) :
    PiRLCCRTComponentFailureLocalization
      point
      foldedSound
      inputSound
      claims
      deltas where
  pivot := pivot
  component := PiRLCCRTComponentSide.left
  component_nonzero := hPivot
  failureTarget := fun seed =>
    (pirlcRemainingSeed pivot seed.1, fiber.fiberIndex (seed.1 pivot))
  failureTarget_injective := by
    intro lhs rhs hTarget
    apply Subtype.ext
    funext index
    have hRemaining := congrArg Prod.fst hTarget
    have hFiber := congrArg Prod.snd hTarget
    by_cases hIndex : index = pivot
    · subst index
      exact fiber.fiberIndex_injective
        (pirlcCRTLeft_badSeeds_same_remaining_have_same_pivot_projection
          pivot
          hPivot
          hCollision
          hRemaining)
        hFiber
    · exact congrFun hRemaining ⟨index, hIndex⟩

def pirlc_rightCRTComponentFailureLocalization_of_deltaCollision
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTRight]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
    (fiber : PiRLCCRTRightPivotFiberIndex) :
    PiRLCCRTComponentFailureLocalization
      point
      foldedSound
      inputSound
      claims
      deltas where
  pivot := pivot
  component := PiRLCCRTComponentSide.right
  component_nonzero := hPivot
  failureTarget := fun seed =>
    (pirlcRemainingSeed pivot seed.1, fiber.fiberIndex (seed.1 pivot))
  failureTarget_injective := by
    intro lhs rhs hTarget
    apply Subtype.ext
    funext index
    have hRemaining := congrArg Prod.fst hTarget
    have hFiber := congrArg Prod.snd hTarget
    by_cases hIndex : index = pivot
    · subst index
      exact fiber.fiberIndex_injective
        (pirlcCRTRight_badSeeds_same_remaining_have_same_pivot_projection
          pivot
          hPivot
          hCollision
          hRemaining)
        hFiber
    · exact congrFun hRemaining ⟨index, hIndex⟩

theorem pirlcCRTComponentFailureTarget_card
    {count : Nat}
    (pivot : Fin count) :
    Fintype.card
      (PiRLCRemainingChallengeSeed count pivot × PiRLCCRTComponentPivotFiber) =
        PiRLCCRTComponentBadSeedBudget count := by
  simp [PiRLCCRTComponentBadSeedBudget, PiRLCCRTComponentPivotFiber,
    phi81CRTComponentDegree]

theorem pirlc_constructive_badSeedCount_le_of_crtComponentLocalization
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (localization :
      PiRLCCRTComponentFailureLocalization
        point
        foldedSound
        inputSound
        claims
        deltas)
    (hBudget : PiRLCCRTComponentBadSeedBudget count ≤ bound) :
    (PiRLCConstructiveBadSeeds point foldedSound inputSound claims).card ≤ bound := by
  have hCard :
      Fintype.card
        (PiRLCConstructiveBadSeeds point foldedSound inputSound claims) ≤
          Fintype.card
            (PiRLCRemainingChallengeSeed count localization.pivot ×
              PiRLCCRTComponentPivotFiber) :=
    Fintype.card_le_of_injective
      localization.failureTarget
      localization.failureTarget_injective
  have hConstructive :
      (PiRLCConstructiveBadSeeds point foldedSound inputSound claims).card ≤
        PiRLCCRTComponentBadSeedBudget count := by
    simpa [Fintype.card_coe,
      pirlcCRTComponentFailureTarget_card localization.pivot] using hCard
  exact le_trans hConstructive hBudget

def pirlc_crtComponentLocalization_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (localization :
      PiRLCCRTComponentFailureLocalization
        point
        foldedSound
        inputSound
        claims
        deltas) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  pirlc_constructive_finiteSoundnessCertificate
    (pirlc_constructive_badSeedCount_le_of_crtComponentLocalization
      localization
      (Nat.le_refl _))

def pirlc_leftCRTComponentDeltaCollision_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
    (fiber : PiRLCCRTLeftPivotFiberIndex) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  pirlc_crtComponentLocalization_finiteSoundnessCertificate
    (pirlc_leftCRTComponentFailureLocalization_of_deltaCollision
      pivot
      hPivot
      hCollision
      fiber)

def pirlc_rightCRTComponentDeltaCollision_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTRight]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
    (fiber : PiRLCCRTRightPivotFiberIndex) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  pirlc_crtComponentLocalization_finiteSoundnessCertificate
    (pirlc_rightCRTComponentFailureLocalization_of_deltaCollision
      pivot
      hPivot
      hCollision
      fiber)

def pirlc_leftCRTComponentHighHalfFailureLocalization_of_deltaCollision
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    PiRLCCRTComponentFailureLocalization
      point
      foldedSound
      inputSound
      claims
      deltas :=
  pirlc_leftCRTComponentFailureLocalization_of_deltaCollision
    pivot
    hPivot
    hCollision
    pirlcCRTLeftHighHalfPivotFiberIndex

def pirlc_rightCRTComponentHighHalfFailureLocalization_of_deltaCollision
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTRight]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    PiRLCCRTComponentFailureLocalization
      point
      foldedSound
      inputSound
      claims
      deltas :=
  pirlc_rightCRTComponentFailureLocalization_of_deltaCollision
    pivot
    hPivot
    hCollision
    pirlcCRTRightHighHalfPivotFiberIndex

def pirlc_leftCRTComponentDeltaCollision_highHalfFiniteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  pirlc_leftCRTComponentDeltaCollision_finiteSoundnessCertificate
    pivot
    hPivot
    hCollision
    pirlcCRTLeftHighHalfPivotFiberIndex

def pirlc_rightCRTComponentDeltaCollision_highHalfFiniteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTRight]
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (pivot : Fin count)
    (hPivot : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
    (hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  pirlc_rightCRTComponentDeltaCollision_finiteSoundnessCertificate
    pivot
    hPivot
    hCollision
    pirlcCRTRightHighHalfPivotFiberIndex

inductive PiRLCCRTComponentDeltaCollisionEvidence
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)] where
  | left
      (deltas : Fin count → Phi81)
      (pivot : Fin count)
      (component_nonzero : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
      (failure_delta_collision :
        PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
      (fiber : PiRLCCRTLeftPivotFiberIndex)
  | right
      (deltas : Fin count → Phi81)
      (pivot : Fin count)
      (component_nonzero : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
      (failure_delta_collision :
        PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
      (fiber : PiRLCCRTRightPivotFiberIndex)

def pirlc_crtComponentDeltaCollisionEvidence_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
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
    (evidence :
      PiRLCCRTComponentDeltaCollisionEvidence
        point
        foldedSound
        inputSound
        claims) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  match evidence with
  | .left deltas pivot component_nonzero failure_delta_collision fiber =>
      pirlc_leftCRTComponentDeltaCollision_finiteSoundnessCertificate
        (deltas := deltas)
        pivot
        component_nonzero
        failure_delta_collision
        fiber
  | .right deltas pivot component_nonzero failure_delta_collision fiber =>
      pirlc_rightCRTComponentDeltaCollision_finiteSoundnessCertificate
        (deltas := deltas)
        pivot
        component_nonzero
        failure_delta_collision
        fiber

inductive PiRLCCRTConcreteComponentDeltaCollisionEvidence
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)] where
  | left
      (deltas : Fin count → Phi81)
      (pivot : Fin count)
      (component_nonzero : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0)
      (failure_delta_collision :
        PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)
  | right
      (deltas : Fin count → Phi81)
      (pivot : Fin count)
      (component_nonzero : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0)
      (failure_delta_collision :
        PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas)

noncomputable def pirlc_crtConcreteComponentEvidence_of_linearDefectSemantics
    {count rows publicCount evalCount pointVars : Nat}
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
    (semantics :
      PiRLCLinearDefectSemantics point foldedSound inputSound claims)
    (hUnsound : ¬ AllClaimsSound inputSound claims) :
    PiRLCCRTConcreteComponentDeltaCollisionEvidence
      point
      foldedSound
      inputSound
      claims := by
  let deltas : Fin count → Phi81 :=
    fun index => semantics.defect (claims index)
  have hPivotExists :
      ∃ pivot, deltas pivot ≠ 0 := by
    simpa [deltas] using
      pirlc_linearDefectSemantics_exists_nonzero_pivot
        semantics
        hUnsound
  let pivot : Fin count := Classical.choose hPivotExists
  have hPivot : deltas pivot ≠ 0 :=
    Classical.choose_spec hPivotExists
  have hCollision :
      PiRLCFailureDeltaCollision point foldedSound inputSound claims deltas := by
    simpa [deltas] using
      pirlc_failureDeltaCollision_of_linearDefectSemantics
        semantics
  have hComponentExists :
      ∃ side, PiRLCCRTComponentNonzero pivot deltas side :=
    pirlcCRTComponentNonzero_exists_of_pivot_ne_zero hPivot
  let side := Classical.choose hComponentExists
  have hComponent : PiRLCCRTComponentNonzero pivot deltas side :=
    Classical.choose_spec hComponentExists
  cases hSide : side with
  | left =>
      have hLeft : pirlcCRTLeftProjectedDeltas deltas pivot ≠ 0 := by
        simpa [PiRLCCRTComponentNonzero, hSide] using hComponent
      exact
        PiRLCCRTConcreteComponentDeltaCollisionEvidence.left
          deltas
          pivot
          hLeft
          hCollision
  | right =>
      have hRight : pirlcCRTRightProjectedDeltas deltas pivot ≠ 0 := by
        simpa [PiRLCCRTComponentNonzero, hSide] using hComponent
      exact
        PiRLCCRTConcreteComponentDeltaCollisionEvidence.right
          deltas
          pivot
          hRight
          hCollision

def pirlc_crtConcreteComponentDeltaCollisionEvidence_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
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
    (evidence :
      PiRLCCRTConcreteComponentDeltaCollisionEvidence
        point
        foldedSound
        inputSound
        claims) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  match evidence with
  | .left deltas pivot component_nonzero failure_delta_collision =>
      pirlc_leftCRTComponentDeltaCollision_highHalfFiniteSoundnessCertificate
        (deltas := deltas)
        pivot
        component_nonzero
        failure_delta_collision
  | .right deltas pivot component_nonzero failure_delta_collision =>
      pirlc_rightCRTComponentDeltaCollision_highHalfFiniteSoundnessCertificate
        (deltas := deltas)
        pivot
        component_nonzero
        failure_delta_collision

noncomputable def pirlc_linearDefectSemantics_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
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
    (semantics :
      PiRLCLinearDefectSemantics point foldedSound inputSound claims) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      (PiRLCCRTComponentBadSeedBudget count) := by
  by_cases hAll : AllClaimsSound inputSound claims
  · exact pirlc_constructive_finiteSoundnessCertificate_of_allInputsSound hAll
  · exact
      pirlc_crtConcreteComponentDeltaCollisionEvidence_finiteSoundnessCertificate
        (pirlc_crtConcreteComponentEvidence_of_linearDefectSemantics
          semantics
          hAll)

noncomputable def pirlc_linearObservation_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
    (point : ProtocolVector Phi81 pointVars)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (observation :
      RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars)
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        (PiRLCObservationSound observation)
        (PiRLCObservationSound observation)
        claims)] :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      (PiRLCObservationSound observation)
      (PiRLCObservationSound observation)
      claims
      (PiRLCCRTComponentBadSeedBudget count) :=
  pirlc_linearDefectSemantics_finiteSoundnessCertificate
    (pirlc_linearObservationDefectSemantics point claims observation)

noncomputable def pirlc_linearObservationFamilyBadSeeds
    {ObservationIndex : Type}
    [Fintype ObservationIndex]
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq (PiRLCChallengeSeed count)]
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
    (point : ProtocolVector Phi81 pointVars)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (observations :
      ObservationIndex →
        RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars)
    (decidableObservationFailure :
      ∀ observationIndex,
        DecidablePred
          (PiRLCFoldFailure
            (PiRLCConcreteAccepts point)
            (PiRLCObservationSound (observations observationIndex))
            (PiRLCObservationSound (observations observationIndex))
            claims)) :
    Finset (PiRLCChallengeSeed count) :=
  univ.biUnion fun observationIndex =>
    letI := decidableObservationFailure observationIndex
    (pirlc_linearObservation_finiteSoundnessCertificate
      point
      claims
      (observations observationIndex)).badSeeds

theorem pirlc_linearObservationFamilyBadSeeds_card_le
    {ObservationIndex : Type}
    [Fintype ObservationIndex]
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq (PiRLCChallengeSeed count)]
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
    (point : ProtocolVector Phi81 pointVars)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (observations :
      ObservationIndex →
        RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars)
    (decidableObservationFailure :
      ∀ observationIndex,
        DecidablePred
          (PiRLCFoldFailure
            (PiRLCConcreteAccepts point)
            (PiRLCObservationSound (observations observationIndex))
            (PiRLCObservationSound (observations observationIndex))
            claims)) :
    (pirlc_linearObservationFamilyBadSeeds
      point
      claims
      observations
      decidableObservationFailure).card ≤
      Fintype.card ObservationIndex * PiRLCCRTComponentBadSeedBudget count := by
  calc
    (pirlc_linearObservationFamilyBadSeeds
      point
      claims
      observations
      decidableObservationFailure).card
        ≤ ∑ observationIndex : ObservationIndex,
            (letI := decidableObservationFailure observationIndex
             (pirlc_linearObservation_finiteSoundnessCertificate
              point
              claims
              (observations observationIndex)).badSeeds.card) := by
          rw [pirlc_linearObservationFamilyBadSeeds]
          exact card_biUnion_le
    _ ≤ ∑ _observationIndex : ObservationIndex,
          PiRLCCRTComponentBadSeedBudget count := by
          apply sum_le_sum
          intro observationIndex _hObservationIndex
          letI := decidableObservationFailure observationIndex
          exact
            (pirlc_linearObservation_finiteSoundnessCertificate
              point
              claims
              (observations observationIndex)).card_le
    _ = Fintype.card ObservationIndex *
          PiRLCCRTComponentBadSeedBudget count := by
          simp

noncomputable def pirlc_linearObservationFamily_finiteSoundnessCertificate
    {ObservationIndex : Type}
    [Fintype ObservationIndex]
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq (PiRLCChallengeSeed count)]
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
    (point : ProtocolVector Phi81 pointVars)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (observations :
      ObservationIndex →
        RLCClaimLinearObservation Phi81 rows publicCount evalCount pointVars)
    (decidableObservationFailure :
      ∀ observationIndex,
        DecidablePred
          (PiRLCFoldFailure
            (PiRLCConcreteAccepts point)
            (PiRLCObservationSound (observations observationIndex))
            (PiRLCObservationSound (observations observationIndex))
            claims)) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      (PiRLCObservationFamilySound observations)
      (PiRLCObservationFamilySound observations)
      claims
      (Fintype.card ObservationIndex * PiRLCCRTComponentBadSeedBudget count) where
  badSeeds :=
    pirlc_linearObservationFamilyBadSeeds
      point
      claims
      observations
      decidableObservationFailure
  card_le :=
    pirlc_linearObservationFamilyBadSeeds_card_le
      point
      claims
      observations
      decidableObservationFailure
  allInputsSound_outside_bad := by
    intro seed folded hAccepts hFoldedSound hSeedOutsideBad claimIndex observationIndex
    letI := decidableObservationFailure observationIndex
    let certificate :=
      pirlc_linearObservation_finiteSoundnessCertificate
        point
        claims
        (observations observationIndex)
    have hSeedOutsideObservation :
        seed ∉ certificate.badSeeds := by
      intro hSeedObservation
      exact hSeedOutsideBad
        (by
          rw [pirlc_linearObservationFamilyBadSeeds]
          exact mem_biUnion.mpr
            ⟨observationIndex, mem_univ _, hSeedObservation⟩)
    exact
      certificate.allInputsSound_outside_bad
        seed
        folded
        hAccepts
        (hFoldedSound observationIndex)
        hSeedOutsideObservation
        claimIndex

def PiRLCPublicFieldObservationBadSeedBudget
    (count rows publicCount evalCount : Nat) : Nat :=
  (rows + publicCount + evalCount) * PiRLCCRTComponentBadSeedBudget count

noncomputable def pirlc_publicFieldObservation_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    [DecidableEq (PiRLCChallengeSeed count)]
    [DecidableEq Phi81CRTLeft]
    [DecidableEq Phi81CRTRight]
    (point : ProtocolVector Phi81 pointVars)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (decidablePublicFieldFailure :
      ∀ observationIndex : RLCClaimPublicFieldIndex rows publicCount evalCount,
        DecidablePred
          (PiRLCFoldFailure
            (PiRLCConcreteAccepts point)
            (PiRLCObservationSound
              (rlcPublicFieldObservation
                (RF := Phi81)
                (pointVars := pointVars)
                observationIndex))
            (PiRLCObservationSound
              (rlcPublicFieldObservation
                (RF := Phi81)
                (pointVars := pointVars)
                observationIndex))
            claims)) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      PiRLCPublicFieldObservationSound
      PiRLCPublicFieldObservationSound
      claims
      (PiRLCPublicFieldObservationBadSeedBudget count rows publicCount evalCount) := by
  simpa [
    PiRLCPublicFieldObservationSound,
    PiRLCPublicFieldObservationBadSeedBudget,
    rlcPublicFieldObservationIndex_card,
    Nat.add_assoc
  ] using
    pirlc_linearObservationFamily_finiteSoundnessCertificate
      point
      claims
      (fun observationIndex : RLCClaimPublicFieldIndex rows publicCount evalCount =>
        rlcPublicFieldObservation (RF := Phi81) (pointVars := pointVars) observationIndex)
      decidablePublicFieldFailure

theorem pirlc_constructive_badSeedCount_le_of_crtLocalization
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (localization :
      PiRLCCRTConstructiveFailureLocalization
        point
        foldedSound
        inputSound
        claims
        deltas)
    (hRemaining :
      (5 ^ phi81Degree) ^ (count - 1) ≤ bound) :
    (PiRLCConstructiveBadSeeds point foldedSound inputSound claims).card ≤ bound := by
  have hCard :
      Fintype.card
        (PiRLCConstructiveBadSeeds point foldedSound inputSound claims) ≤
          Fintype.card (PiRLCRemainingChallengeSeed count localization.pivot) :=
    Fintype.card_le_of_injective
      (fun seed :
          { seed // seed ∈
            PiRLCConstructiveBadSeeds point foldedSound inputSound claims } =>
        pirlcRemainingSeed localization.pivot seed.1)
      localization.remainingSeed_injective
  have hConstructive :
      (PiRLCConstructiveBadSeeds point foldedSound inputSound claims).card ≤
        (5 ^ phi81Degree) ^ (count - 1) := by
    simpa [Fintype.card_coe,
      pirlcRemainingChallengeSeed_card localization.pivot] using hCard
  exact le_trans hConstructive hRemaining

def pirlc_crtLocalization_finiteSoundnessCertificate
    {count rows publicCount evalCount pointVars : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {deltas : Fin count → Phi81}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (localization :
      PiRLCCRTConstructiveFailureLocalization
        point
        foldedSound
        inputSound
        claims
        deltas) :
    PiRLCConstructiveFiniteSoundnessCertificate
      point
      foldedSound
      inputSound
      claims
      ((5 ^ phi81Degree) ^ (count - 1)) :=
  pirlc_constructive_finiteSoundnessCertificate
    (pirlc_constructive_badSeedCount_le_of_crtLocalization
      localization
      (Nat.le_refl _))

theorem pirlc_allInputsSound_of_seed_not_bad
    {count rows publicCount evalCount pointVars : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {seed : PiRLCChallengeSeed count}
    {folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (hSeed :
      seed ∉ PiRLCConstructiveBadSeeds point foldedSound inputSound claims)
    (hAccepts : PiRLCConcreteAccepts point seed claims folded)
    (hFoldedSound : foldedSound folded) :
    AllClaimsSound inputSound claims := by
  by_contra hUnsound
  exact hSeed
    (by
      rw [pirlc_constructiveBadSeeds_mem_iff]
      exact ⟨folded, hAccepts, hFoldedSound, hUnsound⟩)

theorem pirlc_certificate_allInputsSound_outside_bad
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCConstructiveFiniteSoundnessCertificate
        point
        foldedSound
        inputSound
        claims
        bound)
    {seed : PiRLCChallengeSeed count}
    {folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (hAccepts : PiRLCConcreteAccepts point seed claims folded)
    (hFoldedSound : foldedSound folded)
    (hSeed : seed ∉ certificate.badSeeds) :
    AllClaimsSound inputSound claims :=
  certificate.allInputsSound_outside_bad seed folded hAccepts hFoldedSound hSeed

end SuperNeoFormal
