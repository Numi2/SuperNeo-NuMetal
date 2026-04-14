import SuperNeoFormal.ChallengeSampling
import SuperNeoFormal.PiRLC

/-!
Finite-distribution PiRLC soundness surface.

The older PiRLC theorem records random-linear-combination soundness as one
global implication.  This module exposes the finite probability space used by
the concrete profile and states soundness as an exact bad-seed counting theorem.
It also proves the standard one-root collision lemma for scalar folds over a
field; the Phi81 ring challenge theorem is deliberately phrased through an
explicit collision-set bound because the profile ring is a quotient ring rather
than assumed to be a field here.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

variable {RF : Type} [CommRing RF]

abbrev PiRLCChallengeSeed (count : Nat) :=
  Fin count → Phi81ChallengeSeed

def pirlcChallengeElements {count : Nat}
    (seed : PiRLCChallengeSeed count) : Fin count → Phi81 :=
  fun index => phi81ChallengeElement (seed index)

def PiRLCChallengeSupport (count : Nat) : Set (Fin count → Phi81) :=
  Set.range (pirlcChallengeElements (count := count))

theorem pirlcChallengeSeed_card (count : Nat) :
    Fintype.card (PiRLCChallengeSeed count) =
      (5 ^ phi81Degree) ^ count := by
  simp [PiRLCChallengeSeed, Phi81ChallengeSeed, ChallengeCoefficientChoice]

theorem pirlcChallengeElements_mem_support {count : Nat}
    (seed : PiRLCChallengeSeed count) :
    pirlcChallengeElements seed ∈ PiRLCChallengeSupport count := by
  exact Set.mem_range_self seed

def AllClaimsSound {Claim : Type} {count : Nat}
    (inputSound : Claim → Prop)
    (claims : Fin count → Claim) : Prop :=
  ∀ index, inputSound (claims index)

def PiRLCFoldFailure {Seed Claim Folded : Type} {count : Nat}
    (acceptsFold : Seed → (Fin count → Claim) → Folded → Prop)
    (foldedSound : Folded → Prop)
    (inputSound : Claim → Prop)
    (claims : Fin count → Claim)
    (seed : Seed) : Prop :=
  ∃ folded,
    acceptsFold seed claims folded ∧
      foldedSound folded ∧
        ¬ AllClaimsSound inputSound claims

def PiRLCBadSeedFinset {Seed Claim Folded : Type} [Fintype Seed]
    {count : Nat}
    (acceptsFold : Seed → (Fin count → Claim) → Folded → Prop)
    (foldedSound : Folded → Prop)
    (inputSound : Claim → Prop)
    (claims : Fin count → Claim)
    [DecidablePred
      (PiRLCFoldFailure acceptsFold foldedSound inputSound claims)] :
    Finset Seed :=
  univ.filter (PiRLCFoldFailure acceptsFold foldedSound inputSound claims)

theorem pirlc_badSeedCount_le_of_collisionSet
    {Seed Claim Folded : Type} [Fintype Seed]
    {count bound : Nat}
    {acceptsFold : Seed → (Fin count → Claim) → Folded → Prop}
    {foldedSound : Folded → Prop}
    {inputSound : Claim → Prop}
    {claims : Fin count → Claim}
    [DecidablePred
      (PiRLCFoldFailure acceptsFold foldedSound inputSound claims)]
    {collisionSet : Finset Seed}
    (hSubset :
      ∀ seed,
        PiRLCFoldFailure acceptsFold foldedSound inputSound claims seed →
          seed ∈ collisionSet)
    (hBound : collisionSet.card ≤ bound) :
    (PiRLCBadSeedFinset acceptsFold foldedSound inputSound claims).card ≤ bound := by
  refine le_trans ?_ hBound
  apply Finset.card_le_card
  intro seed hSeed
  exact hSubset seed (mem_filter.mp hSeed).2

def PiRLCConcreteAccepts {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (seed : PiRLCChallengeSeed count)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars) : Prop :=
  RLCClaimPubliclyConsistent point (pirlcChallengeElements seed) claims folded

theorem pirlcConcreteAccepts_iff_publiclyConsistent
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (seed : PiRLCChallengeSeed count)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars) :
    PiRLCConcreteAccepts point seed claims folded ↔
      RLCClaimPubliclyConsistent point (pirlcChallengeElements seed) claims folded :=
  Iff.rfl

def PiRLCConcreteCollisionBound
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) : Prop :=
  ∃ collisionSet : Finset (PiRLCChallengeSeed count),
    collisionSet.card ≤ bound ∧
      ∀ seed,
        PiRLCFoldFailure
          (PiRLCConcreteAccepts point)
          foldedSound
          inputSound
          claims
          seed →
            seed ∈ collisionSet

theorem pirlc_concrete_badSeedCount_le_of_collisionBound
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
    (hCollision :
      PiRLCConcreteCollisionBound point foldedSound inputSound claims bound) :
    (PiRLCBadSeedFinset
      (PiRLCConcreteAccepts point)
      foldedSound
      inputSound
      claims).card ≤ bound := by
  rcases hCollision with ⟨collisionSet, hBound, hSubset⟩
  exact pirlc_badSeedCount_le_of_collisionSet
    (collisionSet := collisionSet) hSubset hBound

def PiRLCFiniteCollisionSoundnessBoundary
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) : Prop :=
  PiRLCConcreteCollisionBound point foldedSound inputSound claims bound

theorem pirlc_concrete_badSeedCount_le_of_finiteCollisionBoundary
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
    (hCollision :
      PiRLCFiniteCollisionSoundnessBoundary point foldedSound inputSound claims bound) :
    (PiRLCBadSeedFinset
      (PiRLCConcreteAccepts point)
      foldedSound
      inputSound
      claims).card ≤ bound :=
  pirlc_concrete_badSeedCount_le_of_collisionBound hCollision

section UnitPivotCollision

variable {R : Type} [CommRing R] [DecidableEq R]

def ringRLCWithoutPivot {count : Nat}
    (fixedChallenges : Fin count → R)
    (pivot : Fin count)
    (deltas : Fin count → R) : R :=
  (univ.erase pivot).sum (fun index => fixedChallenges index * deltas index)

def ringRLCWithPivot {count : Nat}
    (fixedChallenges : Fin count → R)
    (pivot : Fin count)
    (deltas : Fin count → R)
    (pivotValue : R) : R :=
  pivotValue * deltas pivot +
    ringRLCWithoutPivot fixedChallenges pivot deltas

def ringRLCBadPivotValues {count : Nat}
    (support : Finset R)
    (fixedChallenges : Fin count → R)
    (pivot : Fin count)
    (deltas : Fin count → R) : Finset R :=
  support.filter
    (fun value => ringRLCWithPivot fixedChallenges pivot deltas value = 0)

theorem ringRLCBadPivotValues_card_le_one_of_unit {count : Nat}
    (support : Finset R)
    (fixedChallenges : Fin count → R)
    (pivot : Fin count)
    (deltas : Fin count → R)
    (hPivotUnit : IsUnit (deltas pivot)) :
    (ringRLCBadPivotValues support fixedChallenges pivot deltas).card ≤ 1 := by
  rw [Finset.card_le_one]
  intro lhs hLhs rhs hRhs
  have hLhsZero :
      ringRLCWithPivot fixedChallenges pivot deltas lhs = 0 :=
    (mem_filter.mp hLhs).2
  have hRhsZero :
      ringRLCWithPivot fixedChallenges pivot deltas rhs = 0 :=
    (mem_filter.mp hRhs).2
  have hMul :
      (lhs - rhs) * deltas pivot = 0 := by
    calc
      (lhs - rhs) * deltas pivot
          = ringRLCWithPivot fixedChallenges pivot deltas lhs -
              ringRLCWithPivot fixedChallenges pivot deltas rhs := by
            simp [ringRLCWithPivot, ringRLCWithoutPivot]
            ring
      _ = 0 := by
            rw [hLhsZero, hRhsZero]
            ring
  have hDiff : lhs - rhs = 0 := by
    have hMulComm : deltas pivot * (lhs - rhs) = 0 := by
      simpa [mul_comm] using hMul
    exact (hPivotUnit.mul_right_eq_zero).mp hMulComm
  exact sub_eq_zero.mp hDiff

theorem phi81RLCBadPivotValues_card_le_one_of_unit [DecidableEq Phi81] {count : Nat}
    (support : Finset Phi81)
    (fixedChallenges : Fin count → Phi81)
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivotUnit : IsUnit (deltas pivot)) :
    (ringRLCBadPivotValues support fixedChallenges pivot deltas).card ≤ 1 :=
  ringRLCBadPivotValues_card_le_one_of_unit
    support
    fixedChallenges
    pivot
    deltas
    hPivotUnit

end UnitPivotCollision

variable {F : Type} [Field F] [DecidableEq F]

def scalarRLCWithoutPivot {count : Nat}
    (fixedChallenges : Fin count → F)
    (pivot : Fin count)
    (deltas : Fin count → F) : F :=
  (univ.erase pivot).sum (fun index => fixedChallenges index * deltas index)

def scalarRLCWithPivot {count : Nat}
    (fixedChallenges : Fin count → F)
    (pivot : Fin count)
    (deltas : Fin count → F)
    (pivotValue : F) : F :=
  pivotValue * deltas pivot +
    scalarRLCWithoutPivot fixedChallenges pivot deltas

def scalarRLCBadPivotValues {count : Nat}
    (support : Finset F)
    (fixedChallenges : Fin count → F)
    (pivot : Fin count)
    (deltas : Fin count → F) : Finset F :=
  support.filter
    (fun value => scalarRLCWithPivot fixedChallenges pivot deltas value = 0)

theorem scalarRLCBadPivotValues_card_le_one {count : Nat}
    (support : Finset F)
    (fixedChallenges : Fin count → F)
    (pivot : Fin count)
    (deltas : Fin count → F)
    (hPivot : deltas pivot ≠ 0) :
    (scalarRLCBadPivotValues support fixedChallenges pivot deltas).card ≤ 1 := by
  rw [Finset.card_le_one]
  intro lhs hLhs rhs hRhs
  have hLhsZero :
      scalarRLCWithPivot fixedChallenges pivot deltas lhs = 0 :=
    (mem_filter.mp hLhs).2
  have hRhsZero :
      scalarRLCWithPivot fixedChallenges pivot deltas rhs = 0 :=
    (mem_filter.mp hRhs).2
  have hMul :
      (lhs - rhs) * deltas pivot = 0 := by
    calc
      (lhs - rhs) * deltas pivot
          = scalarRLCWithPivot fixedChallenges pivot deltas lhs -
              scalarRLCWithPivot fixedChallenges pivot deltas rhs := by
            simp [scalarRLCWithPivot, scalarRLCWithoutPivot]
            ring
      _ = 0 := by
            rw [hLhsZero, hRhsZero]
            ring
  have hDiff : lhs - rhs = 0 := by
    exact (mul_eq_zero.mp hMul).resolve_right hPivot
  exact sub_eq_zero.mp hDiff

def goldilocksScalarChallengeSupport : Finset Goldilocks :=
  univ.image challengeCoefficientGoldilocks

theorem goldilocksScalarRLCBadPivotValues_card_le_one {count : Nat}
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Goldilocks)
    (hPivot : deltas pivot ≠ 0) :
    (scalarRLCBadPivotValues
      goldilocksScalarChallengeSupport
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    goldilocksScalarChallengeSupport
    fixedChallenges
    pivot
    deltas
    hPivot

end SuperNeoFormal
