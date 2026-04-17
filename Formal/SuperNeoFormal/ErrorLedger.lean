import Mathlib.Data.Rat.Lemmas
import Mathlib.Tactic
import SuperNeoFormal.FiniteUniformProbability
import SuperNeoFormal.ProbabilityComposition

/-!
Error ledger for SuperNeo probability composition.

This module packages the part of the probability argument that is safe to state
today: if a probability model supplies union bounds and every component event is
bounded by its budget, then the aggregate event is bounded by the sum of the
component budgets.  The compatibility `AbstractProbabilityModel` remains below,
but the module now also provides the concrete finite-uniform count-to-rational
probability ledger used by the finite bad-set theorems.
-/

namespace SuperNeoFormal

structure AbstractProbabilityModel where
  prob : Prop → ℚ
  nonnegative : ∀ event, 0 ≤ prob event
  monotone : ∀ {lhs rhs : Prop}, (lhs → rhs) → prob lhs ≤ prob rhs
  union_bound : ∀ lhs rhs : Prop, prob (lhs ∨ rhs) ≤ prob lhs + prob rhs

structure SuperNeoErrorEvents where
  pirlc : Prop
  piccs : Prop
  terminalCE : Prop
  transcript : Prop

def SuperNeoErrorEvents.any (events : SuperNeoErrorEvents) : Prop :=
  events.pirlc ∨ events.piccs ∨ events.terminalCE ∨ events.transcript

def superNeoErrorEventsAny (events : SuperNeoErrorEvents) : Prop :=
  events.any

structure SuperNeoErrorBudget where
  pirlc : ℚ
  piccs : ℚ
  terminalCE : ℚ
  transcript : ℚ

def SuperNeoErrorBudget.total (budget : SuperNeoErrorBudget) : ℚ :=
  budget.pirlc + budget.piccs + budget.terminalCE + budget.transcript

def SuperNeoErrorBudget.Nonnegative (budget : SuperNeoErrorBudget) : Prop :=
  0 ≤ budget.pirlc ∧
    0 ≤ budget.piccs ∧
    0 ≤ budget.terminalCE ∧
    0 ≤ budget.transcript

def superNeoErrorBudgetTotal (budget : SuperNeoErrorBudget) : ℚ :=
  budget.total

def superNeoErrorBudgetNonnegative (budget : SuperNeoErrorBudget) : Prop :=
  budget.Nonnegative

structure SuperNeoComponentErrorBounds
    (model : AbstractProbabilityModel)
    (events : SuperNeoErrorEvents)
    (budget : SuperNeoErrorBudget) : Prop where
  pirlc : model.prob events.pirlc ≤ budget.pirlc
  piccs : model.prob events.piccs ≤ budget.piccs
  terminalCE : model.prob events.terminalCE ≤ budget.terminalCE
  transcript : model.prob events.transcript ≤ budget.transcript

theorem superneo_errorBudget_union_bound
    (model : AbstractProbabilityModel)
    (events : SuperNeoErrorEvents)
    (budget : SuperNeoErrorBudget)
    (bounds : SuperNeoComponentErrorBounds model events budget) :
    model.prob events.any ≤ budget.total := by
  have hTerminalTranscript :
      model.prob (events.terminalCE ∨ events.transcript) ≤
        budget.terminalCE + budget.transcript := by
    calc
      model.prob (events.terminalCE ∨ events.transcript) ≤
          model.prob events.terminalCE + model.prob events.transcript :=
        model.union_bound events.terminalCE events.transcript
      _ ≤ budget.terminalCE + budget.transcript := by
        linarith [bounds.terminalCE, bounds.transcript]
  have hPiccsRest :
      model.prob (events.piccs ∨ events.terminalCE ∨ events.transcript) ≤
        budget.piccs + budget.terminalCE + budget.transcript := by
    calc
      model.prob (events.piccs ∨ events.terminalCE ∨ events.transcript) ≤
          model.prob events.piccs +
            model.prob (events.terminalCE ∨ events.transcript) :=
        model.union_bound events.piccs (events.terminalCE ∨ events.transcript)
      _ ≤ budget.piccs + budget.terminalCE + budget.transcript := by
        linarith [bounds.piccs, hTerminalTranscript]
  calc
    model.prob events.any ≤
        model.prob events.pirlc +
          model.prob (events.piccs ∨ events.terminalCE ∨ events.transcript) :=
      model.union_bound events.pirlc
        (events.piccs ∨ events.terminalCE ∨ events.transcript)
    _ ≤ budget.total := by
      rw [SuperNeoErrorBudget.total]
      linarith [bounds.pirlc, hPiccsRest]

structure SuperNeoFiniteUniformErrorEvents
    (Ω : Type) [DecidableEq Ω] where
  support : Finset Ω
  pirlc : Finset Ω
  piccs : Finset Ω
  terminalCE : Finset Ω
  transcript : Finset Ω

def SuperNeoFiniteUniformErrorEvents.any
    {Ω : Type} [DecidableEq Ω]
    (events : SuperNeoFiniteUniformErrorEvents Ω) : Finset Ω :=
  ((events.pirlc ∪ events.piccs) ∪ events.terminalCE) ∪ events.transcript

def SuperNeoFiniteUniformErrorEvents.componentSupportAggregate
    {Ω : Type} [DecidableEq Ω]
    (events : SuperNeoFiniteUniformErrorEvents Ω) : Finset Ω :=
  ((finiteUniformEventSupport events.support events.pirlc ∪
      finiteUniformEventSupport events.support events.piccs) ∪
    finiteUniformEventSupport events.support events.terminalCE) ∪
      finiteUniformEventSupport events.support events.transcript

structure SuperNeoFiniteUniformComponentCardBounds
    {Ω : Type} [DecidableEq Ω]
    (events : SuperNeoFiniteUniformErrorEvents Ω) where
  pirlcBound : Nat
  piccsBound : Nat
  terminalCEBound : Nat
  transcriptBound : Nat
  pirlc : (finiteUniformEventSupport events.support events.pirlc).card ≤ pirlcBound
  piccs : (finiteUniformEventSupport events.support events.piccs).card ≤ piccsBound
  terminalCE :
    (finiteUniformEventSupport events.support events.terminalCE).card ≤ terminalCEBound
  transcript :
    (finiteUniformEventSupport events.support events.transcript).card ≤ transcriptBound

def SuperNeoFiniteUniformComponentCardBounds.total
    {Ω : Type} [DecidableEq Ω]
    {events : SuperNeoFiniteUniformErrorEvents Ω}
    (bounds : SuperNeoFiniteUniformComponentCardBounds events) : Nat :=
  bounds.pirlcBound + bounds.piccsBound +
    bounds.terminalCEBound + bounds.transcriptBound

theorem superneoFiniteUniform_any_subset_componentAggregate
    {Ω : Type} [DecidableEq Ω]
    (events : SuperNeoFiniteUniformErrorEvents Ω) :
    finiteUniformEventSupport events.support events.any ⊆
      events.componentSupportAggregate := by
  intro sample hSample
  simp [SuperNeoFiniteUniformErrorEvents.any,
    SuperNeoFiniteUniformErrorEvents.componentSupportAggregate,
    finiteUniformEventSupport] at hSample ⊢
  tauto

theorem superneoFiniteUniform_componentAggregate_card_le
    {Ω : Type} [DecidableEq Ω]
    (events : SuperNeoFiniteUniformErrorEvents Ω)
    (bounds : SuperNeoFiniteUniformComponentCardBounds events) :
    events.componentSupportAggregate.card ≤ bounds.total := by
  let A := finiteUniformEventSupport events.support events.pirlc
  let B := finiteUniformEventSupport events.support events.piccs
  let C := finiteUniformEventSupport events.support events.terminalCE
  let D := finiteUniformEventSupport events.support events.transcript
  have hA : A.card ≤ bounds.pirlcBound := by
    simpa [A] using bounds.pirlc
  have hB : B.card ≤ bounds.piccsBound := by
    simpa [B] using bounds.piccs
  have hC : C.card ≤ bounds.terminalCEBound := by
    simpa [C] using bounds.terminalCE
  have hD : D.card ≤ bounds.transcriptBound := by
    simpa [D] using bounds.transcript
  have hAB : (A ∪ B).card ≤ A.card + B.card :=
    Finset.card_union_le A B
  have hABC :
      ((A ∪ B) ∪ C).card ≤ (A.card + B.card) + C.card := by
    calc
      ((A ∪ B) ∪ C).card ≤ (A ∪ B).card + C.card :=
        Finset.card_union_le _ _
      _ ≤ (A.card + B.card) + C.card := by
        omega
  have hABCD :
      (((A ∪ B) ∪ C) ∪ D).card ≤
        ((A.card + B.card) + C.card) + D.card := by
    calc
      (((A ∪ B) ∪ C) ∪ D).card ≤ ((A ∪ B) ∪ C).card + D.card :=
        Finset.card_union_le _ _
      _ ≤ ((A.card + B.card) + C.card) + D.card := by
        omega
  unfold SuperNeoFiniteUniformErrorEvents.componentSupportAggregate
  unfold SuperNeoFiniteUniformComponentCardBounds.total
  change (((A ∪ B) ∪ C) ∪ D).card ≤
    bounds.pirlcBound + bounds.piccsBound +
      bounds.terminalCEBound + bounds.transcriptBound
  omega

theorem superneo_finiteUniform_errorBudget_union_bound
    {Ω : Type} [DecidableEq Ω]
    (events : SuperNeoFiniteUniformErrorEvents Ω)
    (bounds : SuperNeoFiniteUniformComponentCardBounds events) :
    finiteUniformProbability events.support events.any ≤
      (bounds.total : ℚ) / (events.support.card : ℚ) :=
  finiteUniformProbability_le_of_subset_card_le
    events.support
    events.any
    events.componentSupportAggregate
    (superneoFiniteUniform_any_subset_componentAggregate events)
    (superneoFiniteUniform_componentAggregate_card_le events bounds)

def superNeoFiatShamirFiniteUniformEvents
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength)) :
    SuperNeoFiniteUniformErrorEvents
      (SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) where
  support :=
    superNeoFiatShamirSeedDomain
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength
  pirlc :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirPirlcSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength)
      pirlcBadSeeds
  piccs :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirPiccsSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength)
      piccsBadSeeds
  terminalCE :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirTerminalCESeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength)
      terminalCEBadSeeds
  transcript :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirTranscriptSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength)
      transcriptBadSeeds

theorem superNeoFiatShamirFiniteUniformEvents_any_eq_badTranscriptSeeds
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength)) :
    (superNeoFiatShamirFiniteUniformEvents
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds).any =
        superNeoFiatShamirBadTranscriptSeeds
          pirlcBadSeeds
          piccsBadSeeds
          terminalCEBadSeeds
          transcriptBadSeeds := by
  rfl

theorem superneo_fiatShamirFiniteUniform_errorLedger_eq_transcriptProbability
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength)) :
    finiteUniformProbability
      (superNeoFiatShamirSeedDomain
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength)
      (superNeoFiatShamirFiniteUniformEvents
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds).any =
        superNeoFiatShamirProbability
          (superNeoFiatShamirBadTranscriptSeeds
            pirlcBadSeeds
            piccsBadSeeds
            terminalCEBadSeeds
            transcriptBadSeeds) := by
  rw [superNeoFiatShamirFiniteUniformEvents_any_eq_badTranscriptSeeds]
  rw [superNeoFiatShamirProbability_eq_finiteUniformProbability]

def selectedDepthLossNumerator
    (selectedDepth perDepthLoss fixedLoss : Nat) : Nat :=
  selectedDepth * perDepthLoss + fixedLoss

theorem selectedDepthLossNumerator_mono_depth
    {lhsDepth rhsDepth perDepthLoss fixedLoss : Nat}
    (hDepth : lhsDepth ≤ rhsDepth) :
    selectedDepthLossNumerator lhsDepth perDepthLoss fixedLoss ≤
      selectedDepthLossNumerator rhsDepth perDepthLoss fixedLoss := by
  unfold selectedDepthLossNumerator
  exact Nat.add_le_add_right (Nat.mul_le_mul_right perDepthLoss hDepth) fixedLoss

theorem superneo_fiatShamirProbability_le_selectedDepthLoss
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength))
    (budget : SuperNeoFiatShamirFiberBudget)
    {selectedDepth perDepthLoss fixedLoss : Nat}
    (hPiRLC :
      ∀ target, target ∈ pirlcBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirPirlcSeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.pirlc)
    (hPiCCS :
      ∀ target, target ∈ piccsBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirPiccsSeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.piccs)
    (hTerminalCE :
      ∀ target, target ∈ terminalCEBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirTerminalCESeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.terminalCE)
    (hTranscript :
      ∀ target, target ∈ transcriptBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirTranscriptSeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.transcript)
    (hSelectedDepth :
      superNeoFiatShamirProbabilityBudgetNumerator
        budget
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds ≤
          selectedDepthLossNumerator selectedDepth perDepthLoss fixedLoss) :
    superNeoFiatShamirProbability
      (superNeoFiatShamirBadTranscriptSeeds
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds) ≤
      (selectedDepthLossNumerator selectedDepth perDepthLoss fixedLoss : ℚ) /
        (superNeoFiatShamirProbabilityDenominator
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength : ℚ) := by
  apply superNeoFiatShamirProbability_le_of_card_le
  exact le_trans
    (superNeoFiatShamirProbabilityNumerator_le_budget
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds
      budget
      hPiRLC
      hPiCCS
      hTerminalCE
      hTranscript)
    hSelectedDepth

abbrev SuperNeoErrorFunction :=
  Nat → ℚ

structure ErrorFunctionClass where
  negligible : SuperNeoErrorFunction → Prop
  zero : negligible (fun _ => 0)
  add :
    ∀ {lhs rhs : SuperNeoErrorFunction},
      negligible lhs →
        negligible rhs →
          negligible (fun securityParameter => lhs securityParameter + rhs securityParameter)

structure SuperNeoErrorFunctions where
  pirlc : SuperNeoErrorFunction
  piccs : SuperNeoErrorFunction
  terminalCE : SuperNeoErrorFunction
  transcript : SuperNeoErrorFunction

def SuperNeoErrorFunctions.total (errors : SuperNeoErrorFunctions) :
    SuperNeoErrorFunction :=
  fun securityParameter =>
    (errors.pirlc securityParameter + errors.piccs securityParameter) +
      (errors.terminalCE securityParameter + errors.transcript securityParameter)

def superNeoErrorFunctionsTotal (errors : SuperNeoErrorFunctions) :
    SuperNeoErrorFunction :=
  errors.total

theorem superneo_errorFunctions_total_negligible
    (cls : ErrorFunctionClass)
    (errors : SuperNeoErrorFunctions)
    (hPiRLC : cls.negligible errors.pirlc)
    (hPiCCS : cls.negligible errors.piccs)
    (hTerminalCE : cls.negligible errors.terminalCE)
    (hTranscript : cls.negligible errors.transcript) :
    cls.negligible errors.total := by
  have hFirst :
      cls.negligible
        (fun securityParameter =>
          errors.pirlc securityParameter + errors.piccs securityParameter) :=
    cls.add hPiRLC hPiCCS
  have hSecond :
      cls.negligible
        (fun securityParameter =>
          errors.terminalCE securityParameter + errors.transcript securityParameter) :=
    cls.add hTerminalCE hTranscript
  have hBoth :=
    cls.add hFirst hSecond
  exact hBoth

variable {PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type}
variable [DecidableEq PiRLCSeed] [DecidableEq PiCCSSeed]
variable [DecidableEq TerminalCESeed] [DecidableEq TranscriptSeed]

def superNeoStageErrorEvents
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed)
    (seeds : SuperNeoStageSeeds PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :
    SuperNeoErrorEvents where
  pirlc := seeds.pirlcSeed ∈ pirlcBadSeeds
  piccs := seeds.piccsSeed ∈ piccsBadSeeds
  terminalCE := seeds.terminalCESeed ∈ terminalCEBadSeeds
  transcript := seeds.transcriptSeed ∈ transcriptBadSeeds

theorem superneo_no_stageErrorEvent_of_outsideAggregate
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed)
    (seeds : SuperNeoStageSeeds PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed)
    (hOutside :
      superneoOutsideAggregate
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds
        seeds) :
    ¬ (superNeoStageErrorEvents
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds
        seeds).any := by
  intro hAny
  have hNotBad :=
    superneo_outsideAggregate_stage_not_bad
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds
      seeds
      hOutside
  rcases hAny with hPiRLC | hPiCCS | hTerminalCE | hTranscript
  · exact hNotBad.1 hPiRLC
  · exact hNotBad.2.1 hPiCCS
  · exact hNotBad.2.2.1 hTerminalCE
  · exact hNotBad.2.2.2 hTranscript

end SuperNeoFormal
