import SuperNeoFormal.PiDEC

/-!
Abstract PiRLC weighted-claim layer.

Swift's PiRLC verifier derives one ring challenge per PiCCS final claim and
checks that the folded claim is the public weighted sum of commitments, public
inputs, and matrix evaluations. This module proves the commitment-opening side
of that recomposition over the existing abstract Ajtai ring model, and records
the explicit soundness-assumption shape for the random-linear-combination step.
-/

namespace SuperNeoFormal

open Finset

variable {RF : Type} [CommRing RF]

abbrev ProtocolVector (RF : Type) (n : Nat) := Fin n → RF

structure EvaluationClaim (RF : Type) (rows publicCount evalCount pointVars : Nat) where
  commitment : Commitment RF rows
  publicInput : ProtocolVector RF publicCount
  point : ProtocolVector RF pointVars
  evaluations : ProtocolVector RF evalCount

def rlcWeightedSum {count : Nat}
    (challenges : Fin count → RF)
    (parts : Fin count → RF) : RF :=
  ∑ index : Fin count, challenges index * parts index

def rlcWeightedVector {count width : Nat}
    (challenges : Fin count → RF)
    (parts : Fin count → ProtocolVector RF width) : ProtocolVector RF width :=
  fun coordinate => rlcWeightedSum challenges (fun index => parts index coordinate)

def rlcWeightedMessage {count columns : Nat}
    (challenges : Fin count → RF)
    (messages : Fin count → Message RF columns) : Message RF columns :=
  rlcWeightedVector challenges messages

def rlcWeightedCommitment {count rows : Nat}
    (challenges : Fin count → RF)
    (commitments : Fin count → Commitment RF rows) : Commitment RF rows :=
  rlcWeightedVector challenges commitments

def rlcWeightedClaim {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector RF pointVars)
    (challenges : Fin count → RF)
    (claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars) :
    EvaluationClaim RF rows publicCount evalCount pointVars where
  commitment := rlcWeightedCommitment challenges (fun index => (claims index).commitment)
  publicInput := rlcWeightedVector challenges (fun index => (claims index).publicInput)
  point := point
  evaluations := rlcWeightedVector challenges (fun index => (claims index).evaluations)

structure RLCClaimLinearObservation
    (RF : Type) [CommRing RF]
    (rows publicCount evalCount pointVars : Nat) where
  observe : EvaluationClaim RF rows publicCount evalCount pointVars → RF
  observe_rlcWeightedClaim :
    ∀ {count : Nat}
      (point : ProtocolVector RF pointVars)
      (challenges : Fin count → RF)
      (claims : Fin count →
        EvaluationClaim RF rows publicCount evalCount pointVars),
      observe (rlcWeightedClaim point challenges claims) =
        rlcWeightedSum challenges (fun index => observe (claims index))

def rlcCommitmentCoordinateObservation
    {rows publicCount evalCount pointVars : Nat}
    (row : Fin rows) :
    RLCClaimLinearObservation RF rows publicCount evalCount pointVars where
  observe := fun claim => claim.commitment row
  observe_rlcWeightedClaim := by
    intro count point challenges claims
    rfl

def rlcPublicInputCoordinateObservation
    {rows publicCount evalCount pointVars : Nat}
    (coordinate : Fin publicCount) :
    RLCClaimLinearObservation RF rows publicCount evalCount pointVars where
  observe := fun claim => claim.publicInput coordinate
  observe_rlcWeightedClaim := by
    intro count point challenges claims
    rfl

def rlcEvaluationCoordinateObservation
    {rows publicCount evalCount pointVars : Nat}
    (coordinate : Fin evalCount) :
    RLCClaimLinearObservation RF rows publicCount evalCount pointVars where
  observe := fun claim => claim.evaluations coordinate
  observe_rlcWeightedClaim := by
    intro count point challenges claims
    rfl

abbrev RLCClaimPublicFieldIndex
    (rows publicCount evalCount : Nat) :=
  (Fin rows ⊕ Fin publicCount) ⊕ Fin evalCount

theorem rlcPublicFieldObservationIndex_card
    (rows publicCount evalCount : Nat) :
    Fintype.card (RLCClaimPublicFieldIndex rows publicCount evalCount) =
      rows + publicCount + evalCount := by
  simp [RLCClaimPublicFieldIndex, Nat.add_assoc]

def rlcPublicFieldObservation
    {rows publicCount evalCount pointVars : Nat}
    (index : RLCClaimPublicFieldIndex rows publicCount evalCount) :
    RLCClaimLinearObservation RF rows publicCount evalCount pointVars :=
  match index with
  | Sum.inl (Sum.inl row) => rlcCommitmentCoordinateObservation row
  | Sum.inl (Sum.inr coordinate) => rlcPublicInputCoordinateObservation coordinate
  | Sum.inr coordinate => rlcEvaluationCoordinateObservation coordinate

def RLCClaimPublicFieldsZero
    {rows publicCount evalCount pointVars : Nat}
    (claim : EvaluationClaim RF rows publicCount evalCount pointVars) : Prop :=
  (∀ row, claim.commitment row = 0) ∧
    (∀ coordinate, claim.publicInput coordinate = 0) ∧
      (∀ coordinate, claim.evaluations coordinate = 0)

def RLCClaimPublicFieldObservationSound
    {rows publicCount evalCount pointVars : Nat}
    (claim : EvaluationClaim RF rows publicCount evalCount pointVars) : Prop :=
  ∀ index : RLCClaimPublicFieldIndex rows publicCount evalCount,
    (rlcPublicFieldObservation (RF := RF) (pointVars := pointVars) index).observe claim = 0

theorem rlcPublicFieldObservationSound_iff_fields_zero
    {rows publicCount evalCount pointVars : Nat}
    (claim : EvaluationClaim RF rows publicCount evalCount pointVars) :
    RLCClaimPublicFieldObservationSound claim ↔
      RLCClaimPublicFieldsZero claim := by
  constructor
  · intro hSound
    refine ⟨?_, ?_, ?_⟩
    · intro row
      simpa [RLCClaimPublicFieldObservationSound, rlcPublicFieldObservation]
        using hSound (Sum.inl (Sum.inl row))
    · intro coordinate
      simpa [RLCClaimPublicFieldObservationSound, rlcPublicFieldObservation]
        using hSound (Sum.inl (Sum.inr coordinate))
    · intro coordinate
      simpa [RLCClaimPublicFieldObservationSound, rlcPublicFieldObservation]
        using hSound (Sum.inr coordinate)
  · intro hZero index
    rcases hZero with ⟨hCommitment, hPublicInput, hEvaluations⟩
    rcases index with (index | coordinate)
    · rcases index with (row | coordinate)
      · simpa [RLCClaimPublicFieldObservationSound, rlcPublicFieldObservation]
          using hCommitment row
      · simpa [RLCClaimPublicFieldObservationSound, rlcPublicFieldObservation]
          using hPublicInput coordinate
    · simpa [RLCClaimPublicFieldObservationSound, rlcPublicFieldObservation]
        using hEvaluations coordinate

def RLCClaimPubliclyConsistent {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector RF pointVars)
    (challenges : Fin count → RF)
    (claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars)
    (folded : EvaluationClaim RF rows publicCount evalCount pointVars) : Prop :=
  folded = rlcWeightedClaim point challenges claims ∧
    ∀ index, (claims index).point = point

def ClaimOpening {rows columns publicCount evalCount pointVars : Nat}
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop)
    (evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop)
    (claim : EvaluationClaim RF rows publicCount evalCount pointVars)
    (witness : Message RF columns) : Prop :=
  bounded witness ∧
    commit A witness = claim.commitment ∧
    evaluationRelation witness claim.point claim.evaluations

def LinearEvaluationRelation {columns evalCount pointVars : Nat}
    (evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop) : Prop :=
  ∀ {count : Nat}
    (challenges : Fin count → RF)
    (witnesses : Fin count → Message RF columns)
    (point : ProtocolVector RF pointVars)
    (evaluations : Fin count → ProtocolVector RF evalCount),
    (∀ index, evaluationRelation (witnesses index) point (evaluations index)) →
      evaluationRelation
        (rlcWeightedMessage challenges witnesses)
        point
        (rlcWeightedVector challenges evaluations)

theorem rlcWeightedSum_eq_sum {count : Nat}
    (challenges : Fin count → RF)
    (parts : Fin count → RF) :
    rlcWeightedSum challenges parts =
      ∑ index : Fin count, challenges index * parts index := by
  rfl

theorem commit_rlcWeightedMessage {rows columns count : Nat}
    (A : AjtaiMatrix RF rows columns)
    (challenges : Fin count → RF)
    (messages : Fin count → Message RF columns) :
    commit A (rlcWeightedMessage challenges messages) =
      rlcWeightedCommitment challenges (fun index => commit A (messages index)) := by
  funext row
  have hInner : ∀ index : Fin count,
      (∑ col : Fin columns,
        A row col * (challenges index * messages index col)) =
        challenges index * (∑ col : Fin columns, A row col * messages index col) := by
    intro index
    rw [Finset.mul_sum]
    apply Finset.sum_congr rfl
    intro col _
    ring
  calc
    commit A (rlcWeightedMessage challenges messages) row
        = ∑ col : Fin columns, ∑ index : Fin count,
            A row col * (challenges index * messages index col) := by
          simp [commit, rlcWeightedMessage, rlcWeightedVector, rlcWeightedSum, Finset.mul_sum]
    _ = ∑ index : Fin count, ∑ col : Fin columns,
            A row col * (challenges index * messages index col) := by
          rw [Finset.sum_comm]
    _ = rlcWeightedCommitment challenges (fun index => commit A (messages index)) row := by
          simp [commit, rlcWeightedCommitment, rlcWeightedVector, rlcWeightedSum, hInner]

theorem pirlc_commitment_recomposition {rows columns count : Nat}
    {A : AjtaiMatrix RF rows columns}
    {challenges : Fin count → RF}
    {witnesses : Fin count → Message RF columns}
    {folded : Message RF columns}
    (hFolded : folded = rlcWeightedMessage challenges witnesses) :
    commit A folded =
      rlcWeightedCommitment challenges (fun index => commit A (witnesses index)) := by
  subst folded
  exact commit_rlcWeightedMessage A challenges witnesses

theorem pirlc_folded_claim_opening
    {rows columns publicCount evalCount pointVars count : Nat}
    {A : AjtaiMatrix RF rows columns}
    {bounded : Message RF columns → Prop}
    {evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop}
    {challenges : Fin count → RF}
    {claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars}
    {witnesses : Fin count → Message RF columns}
    {point : ProtocolVector RF pointVars}
    (hLinearEvaluation : LinearEvaluationRelation evaluationRelation)
    (hPoint : ∀ index, (claims index).point = point)
    (hOpen : ∀ index, ClaimOpening A bounded evaluationRelation (claims index) (witnesses index))
    (hBoundedFolded : bounded (rlcWeightedMessage challenges witnesses)) :
    ClaimOpening
      A
      bounded
      evaluationRelation
      (rlcWeightedClaim point challenges claims)
      (rlcWeightedMessage challenges witnesses) := by
  constructor
  · exact hBoundedFolded
  constructor
  · rw [commit_rlcWeightedMessage]
    funext row
    simp [rlcWeightedClaim, rlcWeightedCommitment, rlcWeightedVector, rlcWeightedSum]
    apply Finset.sum_congr rfl
    intro index _
    rw [(hOpen index).2.1]
  · apply hLinearEvaluation
    intro index
    simpa [hPoint index] using (hOpen index).2.2

def PiRLCRandomChallengeSoundnessAssumption
    {Claim : Type}
    {count : Nat}
    (acceptsFold : (Fin count → Claim) → Claim → Prop)
    (foldedSound : Claim → Prop)
    (allInputsSound : (Fin count → Claim) → Prop) : Prop :=
  ∀ claims folded,
    acceptsFold claims folded →
      foldedSound folded →
        allInputsSound claims

theorem pirlc_soundness_from_assumption
    {Claim : Type}
    {count : Nat}
    {acceptsFold : (Fin count → Claim) → Claim → Prop}
    {foldedSound : Claim → Prop}
    {allInputsSound : (Fin count → Claim) → Prop}
    (hSoundness :
      PiRLCRandomChallengeSoundnessAssumption
        acceptsFold
        foldedSound
        allInputsSound)
    {claims : Fin count → Claim}
    {folded : Claim}
    (hAccepts : acceptsFold claims folded)
    (hFoldedSound : foldedSound folded) :
    allInputsSound claims :=
  hSoundness claims folded hAccepts hFoldedSound

end SuperNeoFormal
