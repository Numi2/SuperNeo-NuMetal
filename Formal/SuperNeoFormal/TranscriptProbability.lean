import Mathlib.Data.Rat.Lemmas
import Mathlib.Tactic
import SuperNeoFormal.PiRLCFiniteSoundness
import SuperNeoFormal.ProbabilityComposition
import SuperNeoFormal.Serialization
import SuperNeoFormal.TerminalCEFiniteSoundness

/-!
Finite transcript-seed accounting for later Fiat-Shamir probability work.

This module is still below the full probability theorem.  It gives the concrete
finite seed product that later Fiat-Shamir models must instantiate, exposes the
stage projection maps, and proves finite preimage/fiber bookkeeping together
with rational numerator/denominator definitions.  It deliberately does not
model SHA-256, random-oracle programming, or connect these budgets to the error
ledger.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

abbrev TranscriptSeedDomain (byteLength : Nat) :=
  Fin byteLength → Byte

def transcriptSeedDomainSupport (byteLength : Nat) :
    Finset (TranscriptSeedDomain byteLength) :=
  univ

theorem transcriptSeedDomainSupport_card (byteLength : Nat) :
    (transcriptSeedDomainSupport byteLength).card = 256 ^ byteLength := by
  simp [transcriptSeedDomainSupport, TranscriptSeedDomain]

def transcriptSeedDomainZero (byteLength : Nat) :
    TranscriptSeedDomain byteLength :=
  fun _ => zeroByte

def goldilocksExt2EquivBaseProduct :
    GoldilocksExt2 ≃ Goldilocks × Goldilocks where
  toFun value := (value.c0, value.c1)
  invFun value := { c0 := value.1, c1 := value.2 }
  left_inv value := by
    cases value
    rfl
  right_inv value := by
    cases value
    rfl

theorem goldilocksExt2_fintype_card :
    Fintype.card GoldilocksExt2 = goldilocksModulus ^ 2 := by
  rw [Fintype.card_congr goldilocksExt2EquivBaseProduct]
  rw [Fintype.card_prod]
  rw [ZMod.card]
  ring

structure SuperNeoFiatShamirSeed
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat)
    where
  pirlc : PiRLCChallengeSeed pirlcCount
  piccs : Fin piccsRoundCount → GoldilocksExt2
  terminalCE : Fin terminalCERoundCount → CEOpeningChallengeSymbol
  transcript : TranscriptSeedDomain transcriptByteLength
  deriving DecidableEq, Fintype

def superNeoFiatShamirSeedZero
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    SuperNeoFiatShamirSeed
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength where
  pirlc := fun _ _ => ⟨0, by native_decide⟩
  piccs := fun _ => goldilocksExt2Zero
  terminalCE := fun _ => ⟨0, by native_decide⟩
  transcript := transcriptSeedDomainZero transcriptByteLength

def superNeoFiatShamirSeedDomain
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    Finset
      (SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :=
  univ

def superNeoFiatShamirSeedEquivProduct
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength ≃
      (((PiRLCChallengeSeed pirlcCount) × (Fin piccsRoundCount → GoldilocksExt2)) ×
        (Fin terminalCERoundCount → CEOpeningChallengeSymbol)) ×
          TranscriptSeedDomain transcriptByteLength where
  toFun seed := (((seed.pirlc, seed.piccs), seed.terminalCE), seed.transcript)
  invFun data := {
    pirlc := data.1.1.1
    piccs := data.1.1.2
    terminalCE := data.1.2
    transcript := data.2
  }
  left_inv seed := by
    cases seed
    rfl
  right_inv data := by
    cases data with
    | mk left transcript =>
        cases left with
        | mk left terminalCE =>
            cases left
            rfl

def superNeoFiatShamirPirlcSeed
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat)
    (seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :
    PiRLCChallengeSeed pirlcCount :=
  seed.pirlc

def superNeoFiatShamirPiccsSeed
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat)
    (seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :
    Fin piccsRoundCount → GoldilocksExt2 :=
  seed.piccs

def superNeoFiatShamirTerminalCESeed
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat)
    (seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :
    Fin terminalCERoundCount → CEOpeningChallengeSymbol :=
  seed.terminalCE

def superNeoFiatShamirTranscriptSeed
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat)
    (seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :
    TranscriptSeedDomain transcriptByteLength :=
  seed.transcript

def superNeoFiatShamirStageSeeds
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :
    SuperNeoStageSeeds
      (PiRLCChallengeSeed pirlcCount)
      (Fin piccsRoundCount → GoldilocksExt2)
      (Fin terminalCERoundCount → CEOpeningChallengeSymbol)
      (TranscriptSeedDomain transcriptByteLength) where
  pirlcSeed :=
    superNeoFiatShamirPirlcSeed
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength
      seed
  piccsSeed :=
    superNeoFiatShamirPiccsSeed
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength
      seed
  terminalCESeed :=
    superNeoFiatShamirTerminalCESeed
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength
      seed
  transcriptSeed :=
    superNeoFiatShamirTranscriptSeed
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength
      seed

def fiatShamirProjectionSupport
    {Source Target : Type}
    [Fintype Source] [DecidableEq Target]
    (project : Source → Target) : Finset Target :=
  univ.image project

theorem fiatShamirProjection_mem_support
    {Source Target : Type}
    [Fintype Source] [DecidableEq Target]
    (project : Source → Target)
    (source : Source) :
    project source ∈ fiatShamirProjectionSupport project := by
  exact mem_image.mpr ⟨source, mem_univ source, rfl⟩

def fiatShamirProjectionFiber
    {Source Target : Type}
    [Fintype Source] [DecidableEq Source] [DecidableEq Target]
    (project : Source → Target)
    (target : Target) : Finset Source :=
  univ.filter fun source => project source = target

theorem fiatShamirProjectionFiber_mem_iff
    {Source Target : Type}
    [Fintype Source] [DecidableEq Source] [DecidableEq Target]
    (project : Source → Target)
    (target : Target)
    (source : Source) :
    source ∈ fiatShamirProjectionFiber project target ↔
      project source = target := by
  simp [fiatShamirProjectionFiber]

def fiatShamirProjectionPreimage
    {Source Target : Type}
    [Fintype Source] [DecidableEq Source] [DecidableEq Target]
    (project : Source → Target)
    (badTargets : Finset Target) : Finset Source :=
  univ.filter fun source => project source ∈ badTargets

theorem fiatShamirProjectionPreimage_mem_iff
    {Source Target : Type}
    [Fintype Source] [DecidableEq Source] [DecidableEq Target]
    (project : Source → Target)
    (badTargets : Finset Target)
    (source : Source) :
    source ∈ fiatShamirProjectionPreimage project badTargets ↔
      project source ∈ badTargets := by
  simp [fiatShamirProjectionPreimage]

theorem fiatShamirProjectionPreimage_card_le_of_fiber_bound
    {Source Target : Type}
    [Fintype Source] [DecidableEq Source] [DecidableEq Target]
    (project : Source → Target)
    (badTargets : Finset Target)
    (fiberBound : Nat)
    (hFiber :
      ∀ target, target ∈ badTargets →
        (fiatShamirProjectionFiber project target).card ≤ fiberBound) :
    (fiatShamirProjectionPreimage project badTargets).card ≤
      badTargets.card * fiberBound := by
  let fibers : Finset Source :=
    badTargets.biUnion fun target => fiatShamirProjectionFiber project target
  have hSubset :
      fiatShamirProjectionPreimage project badTargets ⊆ fibers := by
    intro source hSource
    have hBad :
        project source ∈ badTargets :=
      (fiatShamirProjectionPreimage_mem_iff project badTargets source).mp hSource
    change source ∈
      (badTargets.biUnion fun target => fiatShamirProjectionFiber project target)
    rw [mem_biUnion]
    exact ⟨project source, hBad,
      (fiatShamirProjectionFiber_mem_iff project (project source) source).mpr rfl⟩
  calc
    (fiatShamirProjectionPreimage project badTargets).card ≤ fibers.card :=
      card_le_card hSubset
    _ ≤ ∑ target ∈ badTargets, (fiatShamirProjectionFiber project target).card := by
      change
        (badTargets.biUnion fun target => fiatShamirProjectionFiber project target).card ≤
          ∑ target ∈ badTargets, (fiatShamirProjectionFiber project target).card
      exact card_biUnion_le
    _ ≤ ∑ _target ∈ badTargets, fiberBound := by
      apply sum_le_sum
      intro target hTarget
      exact hFiber target hTarget
    _ = badTargets.card * fiberBound := by
      simp

structure SuperNeoFiatShamirFiberBudget where
  pirlc : Nat
  piccs : Nat
  terminalCE : Nat
  transcript : Nat

def SuperNeoFiatShamirFiberBudget.total
    {PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type}
    (budget : SuperNeoFiatShamirFiberBudget)
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed) : Nat :=
  pirlcBadSeeds.card * budget.pirlc +
    piccsBadSeeds.card * budget.piccs +
      terminalCEBadSeeds.card * budget.terminalCE +
        transcriptBadSeeds.card * budget.transcript

def superNeoFiatShamirFiberBudgetTotal
    {PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type}
    (budget : SuperNeoFiatShamirFiberBudget)
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed) : Nat :=
  budget.total
    pirlcBadSeeds
    piccsBadSeeds
    terminalCEBadSeeds
    transcriptBadSeeds

def superNeoFiatShamirBadTranscriptSeeds
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength)) :
    Finset
      (SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) :=
  ((fiatShamirProjectionPreimage
      (superNeoFiatShamirPirlcSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      pirlcBadSeeds ∪
      fiatShamirProjectionPreimage
        (superNeoFiatShamirPiccsSeed
          pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
        piccsBadSeeds) ∪
    fiatShamirProjectionPreimage
      (superNeoFiatShamirTerminalCESeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      terminalCEBadSeeds) ∪
      fiatShamirProjectionPreimage
        (superNeoFiatShamirTranscriptSeed
          pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
        transcriptBadSeeds

theorem superNeoFiatShamirStageSeeds_not_bad_of_not_badTranscriptSeed
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength))
    {seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength}
    (hSeed :
      seed ∉
        superNeoFiatShamirBadTranscriptSeeds
          pirlcBadSeeds
          piccsBadSeeds
          terminalCEBadSeeds
          transcriptBadSeeds) :
    superNeoFiatShamirPirlcSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength
        seed ∉
        pirlcBadSeeds ∧
      superNeoFiatShamirPiccsSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength
        seed ∉
        piccsBadSeeds ∧
      superNeoFiatShamirTerminalCESeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength
        seed ∉
        terminalCEBadSeeds ∧
      superNeoFiatShamirTranscriptSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength
        seed ∉
        transcriptBadSeeds := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro hBad
    exact hSeed (by
      simp [superNeoFiatShamirBadTranscriptSeeds, fiatShamirProjectionPreimage, hBad])
  · intro hBad
    exact hSeed (by
      simp [superNeoFiatShamirBadTranscriptSeeds, fiatShamirProjectionPreimage, hBad])
  · intro hBad
    exact hSeed (by
      simp [superNeoFiatShamirBadTranscriptSeeds, fiatShamirProjectionPreimage, hBad])
  · intro hBad
    exact hSeed (by
      simp [superNeoFiatShamirBadTranscriptSeeds, fiatShamirProjectionPreimage, hBad])

theorem superNeoFiatShamirOutsideAggregate_of_not_badTranscriptSeed
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength))
    {seed :
      SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength}
    (hSeed :
      seed ∉
        superNeoFiatShamirBadTranscriptSeeds
          pirlcBadSeeds
          piccsBadSeeds
          terminalCEBadSeeds
          transcriptBadSeeds) :
    superneoOutsideAggregate
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds
      (superNeoFiatShamirStageSeeds seed) := by
  have hNotBad :=
    superNeoFiatShamirStageSeeds_not_bad_of_not_badTranscriptSeed
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds
      hSeed
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro hEvent
    exact hNotBad.1 (by
      simpa [superNeoBadEventsAggregate, superNeoBadEventsPirlc,
        superNeoBadEventsPiccs, superNeoBadEventsTerminalCE,
        superNeoBadEventsTranscript, superNeoFiatShamirStageSeeds] using hEvent)
  · intro hEvent
    exact hNotBad.2.1 (by
      simpa [superNeoBadEventsAggregate, superNeoBadEventsPiccs,
        superNeoBadEventsPirlc, superNeoBadEventsTerminalCE,
        superNeoBadEventsTranscript, superNeoFiatShamirStageSeeds] using hEvent)
  · intro hEvent
    exact hNotBad.2.2.1 (by
      simpa [superNeoBadEventsAggregate, superNeoBadEventsTerminalCE,
        superNeoBadEventsPirlc, superNeoBadEventsPiccs,
        superNeoBadEventsTranscript, superNeoFiatShamirStageSeeds] using hEvent)
  · intro hEvent
    exact hNotBad.2.2.2 (by
      simpa [superNeoBadEventsAggregate, superNeoBadEventsTranscript,
        superNeoBadEventsPirlc, superNeoBadEventsPiccs,
        superNeoBadEventsTerminalCE, superNeoFiatShamirStageSeeds] using hEvent)

theorem superNeoFiatShamirBadTranscriptSeeds_card_le_of_fiberBudget
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength))
    (budget : SuperNeoFiatShamirFiberBudget)
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
          budget.transcript) :
    (superNeoFiatShamirBadTranscriptSeeds
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds).card ≤
        budget.total
          pirlcBadSeeds
          piccsBadSeeds
          terminalCEBadSeeds
          transcriptBadSeeds := by
  let pirlcPreimage :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength) :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirPirlcSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      pirlcBadSeeds
  let piccsPreimage :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength) :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirPiccsSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      piccsBadSeeds
  let terminalCEPreimage :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength) :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirTerminalCESeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      terminalCEBadSeeds
  let transcriptPreimage :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength) :=
    fiatShamirProjectionPreimage
      (superNeoFiatShamirTranscriptSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      transcriptBadSeeds
  have hPirlcBound :
      pirlcPreimage.card ≤ pirlcBadSeeds.card * budget.pirlc :=
    fiatShamirProjectionPreimage_card_le_of_fiber_bound
      (superNeoFiatShamirPirlcSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      pirlcBadSeeds
      budget.pirlc
      hPiRLC
  have hPiccsBound :
      piccsPreimage.card ≤ piccsBadSeeds.card * budget.piccs :=
    fiatShamirProjectionPreimage_card_le_of_fiber_bound
      (superNeoFiatShamirPiccsSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      piccsBadSeeds
      budget.piccs
      hPiCCS
  have hTerminalCEBound :
      terminalCEPreimage.card ≤ terminalCEBadSeeds.card * budget.terminalCE :=
    fiatShamirProjectionPreimage_card_le_of_fiber_bound
      (superNeoFiatShamirTerminalCESeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      terminalCEBadSeeds
      budget.terminalCE
      hTerminalCE
  have hTranscriptBound :
      transcriptPreimage.card ≤ transcriptBadSeeds.card * budget.transcript :=
    fiatShamirProjectionPreimage_card_le_of_fiber_bound
      (superNeoFiatShamirTranscriptSeed
        pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
      transcriptBadSeeds
      budget.transcript
      hTranscript
  have hAB := card_union_le pirlcPreimage piccsPreimage
  have hABC := card_union_le (pirlcPreimage ∪ piccsPreimage) terminalCEPreimage
  have hABCD :=
    card_union_le
      ((pirlcPreimage ∪ piccsPreimage) ∪ terminalCEPreimage)
      transcriptPreimage
  rw [superNeoFiatShamirBadTranscriptSeeds]
  change
    (((pirlcPreimage ∪ piccsPreimage) ∪ terminalCEPreimage) ∪
      transcriptPreimage).card ≤
        budget.total
          pirlcBadSeeds
          piccsBadSeeds
          terminalCEBadSeeds
          transcriptBadSeeds
  rw [SuperNeoFiatShamirFiberBudget.total]
  omega

def superNeoFiatShamirProbabilityDenominator
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    Nat :=
  (superNeoFiatShamirSeedDomain
    pirlcCount
    piccsRoundCount
    terminalCERoundCount
    transcriptByteLength).card

theorem superNeoFiatShamirSeedDomain_card
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    (superNeoFiatShamirSeedDomain
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength).card =
        superNeoFiatShamirProbabilityDenominator
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength :=
  rfl

theorem superNeoFiatShamirProbabilityDenominator_factors
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    superNeoFiatShamirProbabilityDenominator
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength =
        ((Fintype.card (PiRLCChallengeSeed pirlcCount) *
            Fintype.card (Fin piccsRoundCount → GoldilocksExt2)) *
          Fintype.card (Fin terminalCERoundCount → CEOpeningChallengeSymbol)) *
            256 ^ transcriptByteLength := by
  rw [superNeoFiatShamirProbabilityDenominator, superNeoFiatShamirSeedDomain]
  change
    Fintype.card
      (SuperNeoFiatShamirSeed
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength) = _
  rw [Fintype.card_congr
    (superNeoFiatShamirSeedEquivProduct
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength)]
  simp [TranscriptSeedDomain]

theorem superNeoFiatShamirProbabilityDenominator_profile_factors
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    superNeoFiatShamirProbabilityDenominator
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength =
        (((5 ^ phi81Degree) ^ pirlcCount *
            (goldilocksModulus ^ 2) ^ piccsRoundCount) *
          3 ^ terminalCERoundCount) *
            256 ^ transcriptByteLength := by
  rw [superNeoFiatShamirProbabilityDenominator_factors]
  rw [pirlcChallengeSeed_card]
  rw [Fintype.card_fun]
  rw [goldilocksExt2_fintype_card]
  simp [CEOpeningChallengeSymbol]

theorem superNeoFiatShamirProbabilityDenominator_pos
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    0 <
      superNeoFiatShamirProbabilityDenominator
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength := by
  rw [← superNeoFiatShamirSeedDomain_card]
  exact card_pos.mpr
    ⟨superNeoFiatShamirSeedZero
        pirlcCount
        piccsRoundCount
        terminalCERoundCount
        transcriptByteLength,
      by simp [superNeoFiatShamirSeedDomain]⟩

def superNeoFiatShamirProbabilityNumerator
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (badSeeds :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength)) : Nat :=
  badSeeds.card

def superNeoFiatShamirProbability
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (badSeeds :
      Finset
        (SuperNeoFiatShamirSeed
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength)) : ℚ :=
  (superNeoFiatShamirProbabilityNumerator badSeeds : ℚ) /
    (superNeoFiatShamirProbabilityDenominator
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength : ℚ)

def superNeoFiatShamirProbabilityBudgetNumerator
    {PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type}
    (budget : SuperNeoFiatShamirFiberBudget)
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (terminalCEBadSeeds : Finset TerminalCESeed)
    (transcriptBadSeeds : Finset TranscriptSeed) : Nat :=
  budget.total
    pirlcBadSeeds
    piccsBadSeeds
    terminalCEBadSeeds
    transcriptBadSeeds

theorem superNeoFiatShamirProbabilityNumerator_le_budget
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds : Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength))
    (budget : SuperNeoFiatShamirFiberBudget)
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
          budget.transcript) :
    superNeoFiatShamirProbabilityNumerator
      (superNeoFiatShamirBadTranscriptSeeds
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds) ≤
      superNeoFiatShamirProbabilityBudgetNumerator
        budget
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds := by
  exact
    superNeoFiatShamirBadTranscriptSeeds_card_le_of_fiberBudget
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds
      budget
      hPiRLC
      hPiCCS
      hTerminalCE
      hTranscript

end SuperNeoFormal
