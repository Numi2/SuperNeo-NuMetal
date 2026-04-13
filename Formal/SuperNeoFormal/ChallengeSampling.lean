import SuperNeoFormal.Embedding

/-!
Concrete small-coefficient challenge sampling.

Swift samples PiRLC ring challenges coefficient-wise from
`[-2, -1, 0, 1, 2]` and expands them into Phi81 ring elements.  This module
formalizes that finite source, proves coefficient bounds, and connects the
profile's strong-sampling capacity inequality to the Lean constants.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

abbrev ChallengeCoefficientChoice :=
  Fin 5

def challengeCoefficientValue (choice : ChallengeCoefficientChoice) : Int :=
  match choice.val with
  | 0 => -2
  | 1 => -1
  | 2 => 0
  | 3 => 1
  | _ => 2

def challengeCoefficientSet : Finset Int :=
  {-2, -1, 0, 1, 2}

theorem challengeCoefficientSet_card :
    challengeCoefficientSet.card = 5 := by
  native_decide

theorem challengeCoefficientValue_mem (choice : ChallengeCoefficientChoice) :
    challengeCoefficientValue choice ∈ challengeCoefficientSet := by
  fin_cases choice <;> native_decide

theorem challengeCoefficientValue_abs_le_normBound (choice : ChallengeCoefficientChoice) :
    |challengeCoefficientValue choice| ≤ (normBound : Int) := by
  fin_cases choice <;> native_decide

theorem challengeCoefficient_goldilocks_normBound (choice : ChallengeCoefficientChoice) :
    goldilocksCenteredNorm ((challengeCoefficientValue choice : Goldilocks)) ≤ normBound := by
  fin_cases choice <;> native_decide

def challengeCoefficientGoldilocks (choice : ChallengeCoefficientChoice) : Goldilocks :=
  (challengeCoefficientValue choice : Goldilocks)

abbrev Phi81ChallengeSeed :=
  Fin phi81Degree → ChallengeCoefficientChoice

def phi81ChallengeCoefficients (seed : Phi81ChallengeSeed) : Phi81Coefficients :=
  fun coeff => challengeCoefficientGoldilocks (seed coeff)

def phi81ChallengeElement (seed : Phi81ChallengeSeed) : Phi81 :=
  phi81CoeffsToQuotient (phi81ChallengeCoefficients seed)

def Phi81CoefficientsBounded
    (bound : Nat)
    (coefficients : Phi81Coefficients) : Prop :=
  ∀ coeff, goldilocksCenteredNorm (coefficients coeff) ≤ bound

theorem phi81ChallengeCoefficients_bounded (seed : Phi81ChallengeSeed) :
    Phi81CoefficientsBounded normBound (phi81ChallengeCoefficients seed) := by
  intro coeff
  unfold phi81ChallengeCoefficients challengeCoefficientGoldilocks
  exact challengeCoefficient_goldilocks_normBound (seed coeff)

theorem phi81ChallengeSeed_card :
    Fintype.card Phi81ChallengeSeed = 5 ^ phi81Degree := by
  simp [Phi81ChallengeSeed, ChallengeCoefficientChoice]

def Phi81ChallengeSupport : Set Phi81 :=
  Set.range phi81ChallengeElement

theorem phi81ChallengeElement_mem_support (seed : Phi81ChallengeSeed) :
    phi81ChallengeElement seed ∈ Phi81ChallengeSupport := by
  exact Set.mem_range_self seed

abbrev Phi81ExpandedChallengeSeed :=
  Fin challengeExpansionFactor → Phi81ChallengeSeed

def phi81ExpandedChallengeElements
    (seed : Phi81ExpandedChallengeSeed) : Fin challengeExpansionFactor → Phi81 :=
  fun index => phi81ChallengeElement (seed index)

theorem phi81ExpandedChallengeSeed_card :
    Fintype.card Phi81ExpandedChallengeSeed =
      (5 ^ phi81Degree) ^ challengeExpansionFactor := by
  simp [Phi81ExpandedChallengeSeed, Phi81ChallengeSeed, ChallengeCoefficientChoice]

def strongSamplingFoldBudget (freshCount priorCount : Nat) : Nat :=
  (freshCount + priorCount) * challengeExpansionFactor * (normBound - 1)

def StrongSamplingCapacity (freshCount priorCount : Nat) : Prop :=
  strongSamplingFoldBudget freshCount priorCount < decompositionRadixBound

theorem strongSamplingFoldBudget_profileMax :
    strongSamplingFoldBudget freshBatchCount decompositionLength = strongSamplingLeft := by
  rfl

theorem strongSamplingCapacity_profileMax :
    StrongSamplingCapacity freshBatchCount decompositionLength := by
  unfold StrongSamplingCapacity strongSamplingFoldBudget
  native_decide

theorem strongSamplingCapacity_uses_profile_theorem :
    StrongSamplingCapacity freshBatchCount decompositionLength := by
  simpa [StrongSamplingCapacity, strongSamplingFoldBudget, strongSamplingFoldBudget_profileMax]
    using strongSampling_holds

theorem strongSamplingCapacity_of_profile_bounds {freshCount priorCount : Nat}
    (hFresh : freshCount ≤ freshBatchCount)
    (hPrior : priorCount ≤ decompositionLength) :
    StrongSamplingCapacity freshCount priorCount := by
  unfold StrongSamplingCapacity strongSamplingFoldBudget
  have hBudget :
      (freshCount + priorCount) * challengeExpansionFactor * (normBound - 1) ≤
        (freshBatchCount + decompositionLength) * challengeExpansionFactor *
          (normBound - 1) := by
    gcongr
  have hProfile :
      (freshBatchCount + decompositionLength) * challengeExpansionFactor *
          (normBound - 1) <
        decompositionRadixBound := by
    native_decide
  exact lt_of_le_of_lt hBudget hProfile

end SuperNeoFormal
