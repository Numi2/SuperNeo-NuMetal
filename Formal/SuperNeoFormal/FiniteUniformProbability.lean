import Mathlib.Data.Rat.Lemmas
import Mathlib.Tactic
import SuperNeoFormal.TranscriptProbability

/-!
Finite uniform probability.

This module closes the deterministic count-to-probability step for finite
uniform supports.  It deliberately stays finite and exact: a probability is the
cardinality of the event inside the support divided by the cardinality of the
support.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

variable {Ω : Type}

def finiteUniformEventSupport
    [DecidableEq Ω]
    (support event : Finset Ω) : Finset Ω :=
  support.filter fun sample => sample ∈ event

def finiteUniformProbability
    [DecidableEq Ω]
    (support event : Finset Ω) : ℚ :=
  ((finiteUniformEventSupport support event).card : ℚ) /
    (support.card : ℚ)

theorem finiteUniformProbability_eq_card_div
    [DecidableEq Ω]
    (support event : Finset Ω) :
    finiteUniformProbability support event =
      ((finiteUniformEventSupport support event).card : ℚ) /
        (support.card : ℚ) :=
  rfl

theorem finiteUniformEventSupport_mem_iff
    [DecidableEq Ω]
    (support event : Finset Ω)
    (sample : Ω) :
    sample ∈ finiteUniformEventSupport support event ↔
      sample ∈ support ∧ sample ∈ event := by
  simp [finiteUniformEventSupport]

theorem finiteUniformEventSupport_subset_support
    [DecidableEq Ω]
    (support event : Finset Ω) :
    finiteUniformEventSupport support event ⊆ support := by
  intro sample hSample
  exact (finiteUniformEventSupport_mem_iff support event sample).mp hSample |>.1

theorem finiteUniformEventSupport_card_le_support
    [DecidableEq Ω]
    (support event : Finset Ω) :
    (finiteUniformEventSupport support event).card ≤ support.card :=
  card_le_card (finiteUniformEventSupport_subset_support support event)

theorem finiteUniformProbability_nonnegative
    [DecidableEq Ω]
    (support event : Finset Ω) :
    0 ≤ finiteUniformProbability support event := by
  rw [finiteUniformProbability]
  positivity

theorem finiteUniformProbability_le_one
    [DecidableEq Ω]
    (support event : Finset Ω) :
    finiteUniformProbability support event ≤ 1 := by
  by_cases hSupport : support.card = 0
  · simp [finiteUniformProbability, hSupport]
  · have hCard :
        ((finiteUniformEventSupport support event).card : ℚ) ≤
          (support.card : ℚ) := by
      exact_mod_cast finiteUniformEventSupport_card_le_support support event
    have hPos : (0 : ℚ) < support.card := by
      exact_mod_cast Nat.pos_of_ne_zero hSupport
    calc
      finiteUniformProbability support event =
          ((finiteUniformEventSupport support event).card : ℚ) /
            (support.card : ℚ) := rfl
      _ ≤ (support.card : ℚ) / (support.card : ℚ) := by
            exact div_le_div_of_nonneg_right hCard (le_of_lt hPos)
      _ = 1 := by
            exact div_self (ne_of_gt hPos)

theorem finiteUniformProbability_le_of_event_card_le
    [DecidableEq Ω]
    (support event : Finset Ω)
    {bound : Nat}
    (hCard : (finiteUniformEventSupport support event).card ≤ bound) :
    finiteUniformProbability support event ≤
      (bound : ℚ) / (support.card : ℚ) := by
  have hCast :
      ((finiteUniformEventSupport support event).card : ℚ) ≤ (bound : ℚ) := by
    exact_mod_cast hCard
  rw [finiteUniformProbability]
  exact div_le_div_of_nonneg_right hCast (by positivity)

theorem finiteUniformProbability_le_of_subset_card_le
    [DecidableEq Ω]
    (support event badSet : Finset Ω)
    {bound : Nat}
    (hSubset : finiteUniformEventSupport support event ⊆ badSet)
    (hCard : badSet.card ≤ bound) :
    finiteUniformProbability support event ≤
      (bound : ℚ) / (support.card : ℚ) := by
  exact finiteUniformProbability_le_of_event_card_le
    support
    event
    (le_trans (card_le_card hSubset) hCard)

def finiteUniformPredicateSupport
    [DecidableEq Ω]
    (support : Finset Ω)
    (event : Ω → Prop)
    [DecidablePred event] : Finset Ω :=
  support.filter event

def finiteUniformPredicateProbability
    [DecidableEq Ω]
    (support : Finset Ω)
    (event : Ω → Prop)
    [DecidablePred event] : ℚ :=
  ((finiteUniformPredicateSupport support event).card : ℚ) /
    (support.card : ℚ)

theorem finiteUniformPredicateProbability_eq_card_div
    [DecidableEq Ω]
    (support : Finset Ω)
    (event : Ω → Prop)
    [DecidablePred event] :
    finiteUniformPredicateProbability support event =
      ((finiteUniformPredicateSupport support event).card : ℚ) /
        (support.card : ℚ) :=
  rfl

theorem finiteUniformPredicateSupport_mem_iff
    [DecidableEq Ω]
    (support : Finset Ω)
    (event : Ω → Prop)
    [DecidablePred event]
    (sample : Ω) :
    sample ∈ finiteUniformPredicateSupport support event ↔
      sample ∈ support ∧ event sample := by
  simp [finiteUniformPredicateSupport]

def finiteUniformUnivProbability
    [Fintype Ω] [DecidableEq Ω]
    (event : Finset Ω) : ℚ :=
  finiteUniformProbability univ event

theorem finiteUniformEventSupport_univ
    [Fintype Ω] [DecidableEq Ω]
    (event : Finset Ω) :
    finiteUniformEventSupport (univ : Finset Ω) event = event := by
  ext sample
  simp [finiteUniformEventSupport]

theorem finiteUniformUnivProbability_eq_card_div
    [Fintype Ω] [DecidableEq Ω]
    (event : Finset Ω) :
    finiteUniformUnivProbability event =
      (event.card : ℚ) / (Fintype.card Ω : ℚ) := by
  simp [finiteUniformUnivProbability, finiteUniformProbability,
    finiteUniformEventSupport_univ]

theorem finiteUniformUnivProbability_le_of_card_le
    [Fintype Ω] [DecidableEq Ω]
    (event : Finset Ω)
    {bound : Nat}
    (hCard : event.card ≤ bound) :
    finiteUniformUnivProbability event ≤
      (bound : ℚ) / (Fintype.card Ω : ℚ) := by
  rw [finiteUniformUnivProbability_eq_card_div]
  have hCast : (event.card : ℚ) ≤ (bound : ℚ) := by
    exact_mod_cast hCard
  exact div_le_div_of_nonneg_right hCast (by positivity)

theorem superNeoFiatShamirProbability_eq_finiteUniformProbability
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (badSeeds :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength)) :
    superNeoFiatShamirProbability badSeeds =
      finiteUniformProbability
        (superNeoFiatShamirSeedDomain
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength)
        badSeeds := by
  simp [superNeoFiatShamirProbability, superNeoFiatShamirProbabilityNumerator,
    superNeoFiatShamirProbabilityDenominator, finiteUniformProbability,
    finiteUniformEventSupport, superNeoFiatShamirSeedDomain]

theorem superNeoFiatShamirProbability_le_of_card_le
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (badSeeds :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength))
    {bound : Nat}
    (hCard : badSeeds.card ≤ bound) :
    superNeoFiatShamirProbability badSeeds ≤
      (bound : ℚ) /
        (superNeoFiatShamirProbabilityDenominator
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength : ℚ) := by
  rw [superNeoFiatShamirProbability_eq_finiteUniformProbability]
  simpa [superNeoFiatShamirProbabilityDenominator, superNeoFiatShamirSeedDomain]
    using
      (finiteUniformUnivProbability_le_of_card_le
        (Ω :=
          SuperNeoFiatShamirSeed
            pirlcCount
            piccsRoundCount
            terminalCERoundCount
            transcriptByteLength)
        badSeeds
        hCard)

end SuperNeoFormal
