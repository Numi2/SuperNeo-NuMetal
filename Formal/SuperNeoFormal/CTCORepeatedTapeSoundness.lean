import Mathlib.Tactic
import SuperNeoFormal.PiRLCFiniteSoundness
import SuperNeoFormal.PiCCSConstructiveFiniteSoundness
import SuperNeoFormal.TerminalCEVerifierSemantics

/-!
CTCO repeated-tape soundness accounting.

This module records the theorem route used by the product QROM proof package
after the selected depth-1 one-shot PiRLC/PiCCS profile was shown insufficient
for a `2^-128` total-loss theorem.  The external CTCO verifier still samples one
256-bit seed.  Internally, `H_chal` expands that seed into independent,
domain-separated tapes, and the verifier accepts only if every tape accepts.

The core reusable theorem below is deliberately finite and first-message
centric: once the first message binds all challenge-independent material, a
one-tape bad set of size `B` amplifies to a multi-tape bad set of size at most
`B^m` in the product tape domain.
-/

noncomputable section

set_option maxRecDepth 10000

namespace SuperNeoFormal

open Finset

structure CTCORepeatedTapeBindingEvidence where
  moveOneBindsChallengeIndependentMaterial : Prop
  repeatedTapesExpandedByDomainSeparatedHChal : Prop
  acceptRequiresEveryTape : Prop

def CTCORepeatedTapeBindingEvidenceAccepted
    (evidence : CTCORepeatedTapeBindingEvidence) : Prop :=
  evidence.moveOneBindsChallengeIndependentMaterial
    ∧ evidence.repeatedTapesExpandedByDomainSeparatedHChal
    ∧ evidence.acceptRequiresEveryTape

def CTCORepeatedTapeBadSet
    {Tape : Type} [Fintype Tape] [DecidableEq Tape]
    (oneTapeBadSet : Finset Tape)
    (repeatCount : Nat) :
    Finset (Fin repeatCount → Tape) :=
  univ.filter fun tape => ∀ index, tape index ∈ oneTapeBadSet

theorem ctcoRepeatedTapeBadSet_mem_iff
    {Tape : Type} [Fintype Tape] [DecidableEq Tape]
    (oneTapeBadSet : Finset Tape)
    (repeatCount : Nat)
    (tape : Fin repeatCount → Tape) :
    tape ∈ CTCORepeatedTapeBadSet oneTapeBadSet repeatCount ↔
      ∀ index, tape index ∈ oneTapeBadSet := by
  simp [CTCORepeatedTapeBadSet]

def ctcoRepeatedTapeBadSetEncode
    {Tape : Type} [Fintype Tape] [DecidableEq Tape]
    {repeatCount : Nat}
    (oneTapeBadSet : Finset Tape)
    (tape :
      { tape // tape ∈ CTCORepeatedTapeBadSet oneTapeBadSet repeatCount }) :
    Fin repeatCount → { value // value ∈ oneTapeBadSet } :=
  fun index =>
    ⟨tape.1 index,
      (ctcoRepeatedTapeBadSet_mem_iff oneTapeBadSet repeatCount tape.1).mp
        tape.2
        index⟩

theorem ctcoRepeatedTapeBadSetEncode_injective
    {Tape : Type} [Fintype Tape] [DecidableEq Tape]
    {repeatCount : Nat}
    (oneTapeBadSet : Finset Tape) :
    Function.Injective
      (ctcoRepeatedTapeBadSetEncode
        (repeatCount := repeatCount)
        oneTapeBadSet) := by
  intro lhs rhs hEncode
  apply Subtype.ext
  funext index
  have hIndex := congrFun hEncode index
  exact congrArg Subtype.val hIndex

theorem ctcoRepeatedTapeBadSet_card_le_bad_pow
    {Tape : Type} [Fintype Tape] [DecidableEq Tape]
    (oneTapeBadSet : Finset Tape)
    (repeatCount : Nat) :
    (CTCORepeatedTapeBadSet oneTapeBadSet repeatCount).card ≤
      oneTapeBadSet.card ^ repeatCount := by
  have hCard :
      Fintype.card
          { tape // tape ∈ CTCORepeatedTapeBadSet oneTapeBadSet repeatCount } ≤
        Fintype.card (Fin repeatCount → { value // value ∈ oneTapeBadSet }) :=
    Fintype.card_le_of_injective
      (ctcoRepeatedTapeBadSetEncode
        (repeatCount := repeatCount)
        oneTapeBadSet)
      (ctcoRepeatedTapeBadSetEncode_injective
        (repeatCount := repeatCount)
        oneTapeBadSet)
  simpa [Fintype.card_coe, Fintype.card_fun] using hCard

theorem ctcoRepeatedTapeBadSet_card_le_budget_pow
    {Tape : Type} [Fintype Tape] [DecidableEq Tape]
    (oneTapeBadSet : Finset Tape)
    (repeatCount oneTapeBudget : Nat)
    (hOneTape : oneTapeBadSet.card ≤ oneTapeBudget) :
    (CTCORepeatedTapeBadSet oneTapeBadSet repeatCount).card ≤
      oneTapeBudget ^ repeatCount := by
  exact le_trans
    (ctcoRepeatedTapeBadSet_card_le_bad_pow oneTapeBadSet repeatCount)
    (Nat.pow_le_pow_left hOneTape repeatCount)

theorem ctcoRepeatedTapeDomain_card
    (Tape : Type) [Fintype Tape]
    (repeatCount : Nat) :
    Fintype.card (Fin repeatCount → Tape) =
      Fintype.card Tape ^ repeatCount := by
  simp

theorem ctcoRepeatedTapeBadSet_uniformProbability_le_budgetRatio
    {Tape : Type} [Fintype Tape] [DecidableEq Tape] [Inhabited Tape]
    (oneTapeBadSet : Finset Tape)
    (repeatCount oneTapeBudget : Nat)
    (hOneTape : oneTapeBadSet.card ≤ oneTapeBudget) :
    ((CTCORepeatedTapeBadSet oneTapeBadSet repeatCount).card : ℚ) /
        (Fintype.card (Fin repeatCount → Tape) : ℚ) ≤
      (oneTapeBudget ^ repeatCount : ℚ) /
        (Fintype.card Tape ^ repeatCount : ℚ) := by
  have hCardNat :=
    ctcoRepeatedTapeBadSet_card_le_budget_pow
      oneTapeBadSet
      repeatCount
      oneTapeBudget
      hOneTape
  have hCardRat :
      ((CTCORepeatedTapeBadSet oneTapeBadSet repeatCount).card : ℚ) ≤
        (oneTapeBudget ^ repeatCount : ℚ) := by
    exact_mod_cast hCardNat
  have hDomain :
      (Fintype.card (Fin repeatCount → Tape) : ℚ) =
        (Fintype.card Tape ^ repeatCount : ℚ) := by
    exact_mod_cast ctcoRepeatedTapeDomain_card Tape repeatCount
  have hDomainPos :
      (0 : ℚ) < (Fintype.card (Fin repeatCount → Tape) : ℚ) := by
    exact_mod_cast Fintype.card_pos_iff.mpr ⟨fun _ => default⟩
  calc
    ((CTCORepeatedTapeBadSet oneTapeBadSet repeatCount).card : ℚ) /
        (Fintype.card (Fin repeatCount → Tape) : ℚ)
        ≤ (oneTapeBudget ^ repeatCount : ℚ) /
            (Fintype.card (Fin repeatCount → Tape) : ℚ) := by
          gcongr
    _ = (oneTapeBudget ^ repeatCount : ℚ) /
          (Fintype.card Tape ^ repeatCount : ℚ) := by
          rw [hDomain]

def ctcoFinTwoLeft : Fin 2 :=
  ⟨0, by decide⟩

def ctcoFinTwoRight : Fin 2 :=
  ⟨1, by decide⟩

def ctcoFinTwoDiagonalEquiv (α : Type) :
    { values : Fin 2 → α //
        values ctcoFinTwoLeft = values ctcoFinTwoRight } ≃ α where
  toFun values := values.1 ctcoFinTwoLeft
  invFun value := ⟨fun _ => value, rfl⟩
  left_inv values := by
    apply Subtype.ext
    funext index
    fin_cases index
    · rfl
    · exact values.2
  right_inv value := rfl

def pirlcConstantTwoSeed
    (seed : Phi81ChallengeSeed) :
    PiRLCChallengeSeed 2 :=
  fun _ => seed

theorem pirlcConstantTwoSeed_injective :
    Function.Injective pirlcConstantTwoSeed := by
  intro lhs rhs hSeed
  exact congrFun hSeed ctcoFinTwoLeft

def PiRLCOneShotEqualityCounterexampleBadSeeds :
    Finset (PiRLCChallengeSeed 2) :=
  univ.image pirlcConstantTwoSeed

theorem pirlcOneShotEqualityCounterexampleBadSeeds_mem_iff
    (seed : PiRLCChallengeSeed 2) :
    seed ∈ PiRLCOneShotEqualityCounterexampleBadSeeds ↔
      seed ctcoFinTwoLeft = seed ctcoFinTwoRight := by
  constructor
  · intro hMember
    rcases mem_image.mp hMember with ⟨value, _, hSeed⟩
    rw [← hSeed]
    rfl
  · intro hEquality
    apply mem_image.mpr
    refine ⟨seed ctcoFinTwoLeft, mem_univ _, ?_⟩
    funext index
    fin_cases index
    · rfl
    · exact hEquality

theorem pirlcOneShotEqualityCounterexampleBadSeeds_card_eq :
    PiRLCOneShotEqualityCounterexampleBadSeeds.card = 5 ^ phi81Degree := by
  rw [PiRLCOneShotEqualityCounterexampleBadSeeds]
  rw [card_image_of_injective]
  · exact phi81ChallengeSeed_card
  · exact pirlcConstantTwoSeed_injective

theorem pirlcOneShotEqualityCounterexampleDomain_card :
    Fintype.card (PiRLCChallengeSeed 2) =
      (5 ^ phi81Degree) ^ 2 :=
  pirlcChallengeSeed_card 2

theorem pirlcOneShotEqualityCounterexampleLowerBound_exceeds_selected128 :
    5 ^ phi81Degree < 2 ^ 128 :=
  pirlcFullRingUnitPivotSingleObservationBound_exceeds_selected128

def PiCCSOneShotFirstChallengeZeroBadSet : Finset GoldilocksExt2 :=
  {0}

theorem piccsOneShotFirstChallengeZeroBadSet_card_eq :
    PiCCSOneShotFirstChallengeZeroBadSet.card = 1 := by
  simp [PiCCSOneShotFirstChallengeZeroBadSet]

def ctcoGoldilocksExt2EquivBaseProduct :
    GoldilocksExt2 ≃ Goldilocks × Goldilocks where
  toFun value := (value.c0, value.c1)
  invFun value := { c0 := value.1, c1 := value.2 }
  left_inv value := by
    cases value
    rfl
  right_inv value := by
    cases value
    rfl

theorem ctcoGoldilocksExt2_fintype_card :
    Fintype.card GoldilocksExt2 = goldilocksModulus ^ 2 := by
  rw [Fintype.card_congr ctcoGoldilocksExt2EquivBaseProduct]
  rw [Fintype.card_prod]
  rw [ZMod.card]
  ring

theorem piccsOneShotFirstChallengeZeroDomain_card :
    Fintype.card GoldilocksExt2 = goldilocksModulus ^ 2 :=
  ctcoGoldilocksExt2_fintype_card

theorem piccsOneShotFirstChallengeZeroCounterexampleLowerBound_exceeds_selected128 :
    goldilocksModulus ^ 2 < 2 ^ 128 :=
  piccsGoldilocksExt2ChallengeSupport_below_selected128

def piccsTwoTapeLooseRepeatedBadBudget : Nat :=
  (18 * 4) ^ 2

def piccsTwoTapeFirstMismatchRepeatedBadBudget : Nat :=
  4 ^ 2

theorem piccsTwoTapeLooseRepeatedBound_lt_selected128 :
    piccsTwoTapeLooseRepeatedBadBudget * 2 ^ 128 <
      (goldilocksModulus ^ 2) ^ 2 := by
  native_decide

theorem piccsTwoTapeFirstMismatchRepeatedBound_lt_selected128 :
    piccsTwoTapeFirstMismatchRepeatedBadBudget * 2 ^ 128 <
      (goldilocksModulus ^ 2) ^ 2 := by
  native_decide

theorem pirlcThreeTapeCRTComponentRepeatedBound_lt_selected128 :
    2 ^ 128 < (5 ^ phi81CRTComponentDegree) ^ 3 := by
  native_decide

theorem pirlcTwoTapeUnitPivotRepeatedBound_lt_selected128 :
    2 ^ 128 < (5 ^ phi81Degree) ^ 2 := by
  native_decide

theorem sourceFoldRepeatedTapeFiniteBound_lt_selected128 :
    piccsTwoTapeFirstMismatchRepeatedBadBudget *
        (5 ^ (phi81CRTComponentDegree * 3)) * 2 ^ 128
      + (goldilocksModulus ^ 4) * 2 ^ 128 <
        (goldilocksModulus ^ 4) *
          (5 ^ (phi81CRTComponentDegree * 3)) := by
  native_decide

def terminalCEPinnedRoundCount226 : Nat :=
  226

theorem terminalCE226RepeatedChallengeWithSharedCoreBudget_lt_selected128 :
    2 ^ terminalCEPinnedRoundCount226 * 2 ^ 129 <
      3 ^ terminalCEPinnedRoundCount226 := by
  native_decide

theorem terminalCESwift226RepeatedChallengeWithSharedCoreBudget_lt_selected128 :
    2 ^ terminalCESwiftRoundCount * 2 ^ 129 <
      3 ^ terminalCESwiftRoundCount := by
  native_decide

end SuperNeoFormal
