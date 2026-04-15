import Mathlib.Data.Rat.Lemmas
import Mathlib.Tactic
import SuperNeoFormal.ProbabilityComposition

/-!
Abstract error ledger for SuperNeo probability composition.

This module packages the part of the probability argument that is safe to state
today: if a probability model supplies union bounds and every component event is
bounded by its budget, then the aggregate event is bounded by the sum of the
component budgets.  It intentionally does not construct the Fiat-Shamir
transcript distribution or turn finite bad sets into probabilities.
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
