import Mathlib.Data.Finset.Card
import Mathlib.Tactic

/-!
Conservative finite bad-event composition.

This module deliberately stops before a probability claim. It only tags the
finite bad sets contributed by the PiRLC, PiCCS/sum-check, terminal CE, and
transcript layers, and proves the finite union-cardinality bound needed before
any later distribution or Fiat-Shamir fiber argument can be stated honestly.
-/

namespace SuperNeoFormal

inductive SuperNeoBadEvent
    (PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type) where
  | pirlc : PiRLCSeed → SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed
  | piccs : PiCCSSeed → SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed
  | terminalCE :
      TerminalCESeed → SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed
  | transcript :
      TranscriptSeed → SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed
  deriving DecidableEq

variable {PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type}
variable [DecidableEq PiRLCSeed] [DecidableEq PiCCSSeed]
variable [DecidableEq TerminalCESeed] [DecidableEq TranscriptSeed]

def superNeoBadEventsPirlc
    (badSeeds : Finset PiRLCSeed) :
    Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
  badSeeds.image SuperNeoBadEvent.pirlc

def superNeoBadEventsPiccs
    (badSeeds : Finset PiCCSSeed) :
    Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
  badSeeds.image SuperNeoBadEvent.piccs

def superNeoBadEventsTerminalCE
    (badSeeds : Finset TerminalCESeed) :
    Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
  badSeeds.image SuperNeoBadEvent.terminalCE

def superNeoBadEventsTranscript
    (badSeeds : Finset TranscriptSeed) :
    Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
  badSeeds.image SuperNeoBadEvent.transcript

def superNeoBadEventsAggregate
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed) :
    Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
  ((superNeoBadEventsPirlc pirlcBadSeeds ∪
      superNeoBadEventsPiccs piccsBadSeeds) ∪
    superNeoBadEventsTerminalCE terminalCEBadSeeds) ∪
      superNeoBadEventsTranscript transcriptBadSeeds

theorem superNeoBadEventsPirlc_card
    (badSeeds : Finset PiRLCSeed) :
    (superNeoBadEventsPirlc
      (PiCCSSeed := PiCCSSeed)
      (TerminalCESeed := TerminalCESeed)
      (TranscriptSeed := TranscriptSeed)
      badSeeds).card = badSeeds.card := by
  rw [superNeoBadEventsPirlc]
  exact Finset.card_image_of_injective badSeeds (by
    intro lhs rhs h
    cases h
    rfl)

theorem superNeoBadEventsPiccs_card
    (badSeeds : Finset PiCCSSeed) :
    (superNeoBadEventsPiccs
      (PiRLCSeed := PiRLCSeed)
      (TerminalCESeed := TerminalCESeed)
      (TranscriptSeed := TranscriptSeed)
      badSeeds).card = badSeeds.card := by
  rw [superNeoBadEventsPiccs]
  exact Finset.card_image_of_injective badSeeds (by
    intro lhs rhs h
    cases h
    rfl)

theorem superNeoBadEventsTerminalCE_card
    (badSeeds : Finset TerminalCESeed) :
    (superNeoBadEventsTerminalCE
      (PiRLCSeed := PiRLCSeed)
      (PiCCSSeed := PiCCSSeed)
      (TranscriptSeed := TranscriptSeed)
      badSeeds).card = badSeeds.card := by
  rw [superNeoBadEventsTerminalCE]
  exact Finset.card_image_of_injective badSeeds (by
    intro lhs rhs h
    cases h
    rfl)

theorem superNeoBadEventsTranscript_card
    (badSeeds : Finset TranscriptSeed) :
    (superNeoBadEventsTranscript
      (PiRLCSeed := PiRLCSeed)
      (PiCCSSeed := PiCCSSeed)
      (TerminalCESeed := TerminalCESeed)
      badSeeds).card = badSeeds.card := by
  rw [superNeoBadEventsTranscript]
  exact Finset.card_image_of_injective badSeeds (by
    intro lhs rhs h
    cases h
    rfl)

theorem superneo_aggregateBadEvents_card_le
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed) :
    (superNeoBadEventsAggregate
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds).card ≤
        pirlcBadSeeds.card +
          piccsBadSeeds.card +
          terminalCEBadSeeds.card +
          transcriptBadSeeds.card := by
  let pirlcEvents :
      Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
    superNeoBadEventsPirlc pirlcBadSeeds
  let piccsEvents :
      Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
    superNeoBadEventsPiccs piccsBadSeeds
  let terminalEvents :
      Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
    superNeoBadEventsTerminalCE terminalCEBadSeeds
  let transcriptEvents :
      Finset (SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :=
    superNeoBadEventsTranscript transcriptBadSeeds
  have hAB := Finset.card_union_le pirlcEvents piccsEvents
  have hABC := Finset.card_union_le (pirlcEvents ∪ piccsEvents) terminalEvents
  have hABCD :=
    Finset.card_union_le ((pirlcEvents ∪ piccsEvents) ∪ terminalEvents) transcriptEvents
  have hBound :
      (((pirlcEvents ∪ piccsEvents) ∪ terminalEvents) ∪ transcriptEvents).card ≤
        pirlcEvents.card + piccsEvents.card + terminalEvents.card + transcriptEvents.card := by
    omega
  have hCards :
      pirlcEvents.card + piccsEvents.card + terminalEvents.card + transcriptEvents.card =
        pirlcBadSeeds.card +
          piccsBadSeeds.card +
          terminalCEBadSeeds.card +
          transcriptBadSeeds.card := by
    simp [
      pirlcEvents,
      piccsEvents,
      terminalEvents,
      transcriptEvents,
      superNeoBadEventsPirlc_card,
      superNeoBadEventsPiccs_card,
      superNeoBadEventsTerminalCE_card,
      superNeoBadEventsTranscript_card
    ]
  rw [superNeoBadEventsAggregate]
  change
    (((pirlcEvents ∪ piccsEvents) ∪ terminalEvents) ∪ transcriptEvents).card ≤
      pirlcBadSeeds.card +
        piccsBadSeeds.card +
        terminalCEBadSeeds.card +
        transcriptBadSeeds.card
  rw [← hCards]
  exact hBound

structure SuperNeoStageSeeds
    (PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type) where
  pirlcSeed : PiRLCSeed
  piccsSeed : PiCCSSeed
  terminalCESeed : TerminalCESeed
  transcriptSeed : TranscriptSeed

def superneoOutsideAggregate
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed)
    (seeds : SuperNeoStageSeeds PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) :
    Prop :=
  (SuperNeoBadEvent.pirlc seeds.pirlcSeed :
      SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) ∉
    superNeoBadEventsAggregate
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds ∧
  (SuperNeoBadEvent.piccs seeds.piccsSeed :
      SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) ∉
    superNeoBadEventsAggregate
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds ∧
  (SuperNeoBadEvent.terminalCE seeds.terminalCESeed :
      SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) ∉
    superNeoBadEventsAggregate
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds ∧
  (SuperNeoBadEvent.transcript seeds.transcriptSeed :
      SuperNeoBadEvent PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed) ∉
    superNeoBadEventsAggregate
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds

theorem superneo_outsideAggregate_stage_not_bad
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
    seeds.pirlcSeed ∉ pirlcBadSeeds ∧
      seeds.piccsSeed ∉ piccsBadSeeds ∧
      seeds.terminalCESeed ∉ terminalCEBadSeeds ∧
      seeds.transcriptSeed ∉ transcriptBadSeeds := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro hSeed
    exact hOutside.1 (by
      simp [superNeoBadEventsAggregate, superNeoBadEventsPirlc, hSeed])
  · intro hSeed
    exact hOutside.2.1 (by
      simp [superNeoBadEventsAggregate, superNeoBadEventsPiccs, hSeed])
  · intro hSeed
    exact hOutside.2.2.1 (by
      simp [superNeoBadEventsAggregate, superNeoBadEventsTerminalCE, hSeed])
  · intro hSeed
    exact hOutside.2.2.2 (by
      simp [superNeoBadEventsAggregate, superNeoBadEventsTranscript, hSeed])

end SuperNeoFormal
