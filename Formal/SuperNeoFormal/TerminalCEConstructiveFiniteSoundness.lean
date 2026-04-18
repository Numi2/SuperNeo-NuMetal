import SuperNeoFormal.CEByteSerialization
import SuperNeoFormal.TerminalCEConcreteSpecialSoundness
import SuperNeoFormal.TranscriptChallenge
import SuperNeoFormal.TranscriptProbability
import SuperNeoFormal.WellFormedTranscript

/-!
Constructive finite-bad-seed terminal CE soundness.

This is the replacement theorem surface for the older certificate-budget file.
The bad set is the concrete extraction-failure set from
`TerminalCEConcreteSpecialSoundness`; the round budget is derived from an
injective localization of each bad seed to a concrete `(round, challenge)` slot.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

abbrev TerminalCEConstructiveBadSeeds
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] :
    Finset Seed :=
  TerminalCEConcreteBadSeeds verifyProof opens proofSeed

structure TerminalCEConstructiveVerifierSemantics
    {Claim Proof Witness Seed Commitment Response : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count roundCount : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] where
  parseTrace :
    ∀ statement proof,
      verifyProof statement proof →
        TerminalCEVerifierTrace Commitment Response Witness Seed roundCount
  trace_seed :
    ∀ statement proof hVerify,
      (parseTrace statement proof hVerify).seed = proofSeed proof
  trace_accepts :
    ∀ statement proof hVerify,
      TerminalCEVerifierTraceAccepts (parseTrace statement proof hVerify)
  extractionSemantics :
    ∀ statement proof hVerify,
      proofSeed proof ∉ TerminalCEConstructiveBadSeeds verifyProof opens proofSeed →
        TerminalCEConcreteExtractorSemantics
          (parseTrace statement proof hVerify)
          statement
          opens

theorem terminalCEConstructive_extract_outside_bad
    {Claim Proof Witness Seed Commitment Response : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (semantics :
      TerminalCEConstructiveVerifierSemantics
        (Commitment := Commitment)
        (Response := Response)
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed)
    {statement : TerminalCEStatement Claim count}
    {proof : Proof}
    (hVerify : verifyProof statement proof)
    (hSeed :
      proofSeed proof ∉ TerminalCEConstructiveBadSeeds verifyProof opens proofSeed) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens :=
  terminalCEConcrete_extract_batch
    (semantics.extractionSemantics statement proof hVerify hSeed)

structure TerminalCEConstructiveFailureLocalization
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count roundCount : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] where
  failureSlot :
    TerminalCEConstructiveBadSeeds verifyProof opens proofSeed →
      Fin roundCount × CEOpeningChallengeSymbol
  failureSlot_injective :
    Function.Injective failureSlot

abbrev TerminalCEFailureSlotSeed
    (roundCount : Nat) :=
  Fin roundCount × CEOpeningChallengeSymbol

abbrev TerminalCEChallengeTape
    (roundCount : Nat) :=
  Fin roundCount → CEOpeningChallengeSymbol

abbrev TerminalCERemainingChallengeTape
    (roundCount : Nat)
    (slot : Fin roundCount) :=
  { round : Fin roundCount // round ≠ slot } → CEOpeningChallengeSymbol

def terminalCERemainingChallengeTape
    {roundCount : Nat}
    (slot : Fin roundCount)
    (tape : TerminalCEChallengeTape roundCount) :
    TerminalCERemainingChallengeTape roundCount slot :=
  fun round => tape round.1

def terminalCEChallengeTapeSlotFiber
    {roundCount : Nat}
    (slotSeed : TerminalCEFailureSlotSeed roundCount) :
    Finset (TerminalCEChallengeTape roundCount) :=
  univ.filter fun tape => tape slotSeed.1 = slotSeed.2

theorem terminalCEChallengeTapeSlotFiber_mem_iff
    {roundCount : Nat}
    (slotSeed : TerminalCEFailureSlotSeed roundCount)
    (tape : TerminalCEChallengeTape roundCount) :
    tape ∈ terminalCEChallengeTapeSlotFiber slotSeed ↔
      tape slotSeed.1 = slotSeed.2 := by
  simp [terminalCEChallengeTapeSlotFiber]

theorem terminalCERemainingChallengeTape_card
    {roundCount : Nat}
    (slot : Fin roundCount) :
    Fintype.card (TerminalCERemainingChallengeTape roundCount slot) =
      3 ^ (roundCount - 1) := by
  simp [TerminalCERemainingChallengeTape, CEOpeningChallengeSymbol]

theorem terminalCEChallengeTapeSlotFiber_remaining_injective
    {roundCount : Nat}
    (slotSeed : TerminalCEFailureSlotSeed roundCount) :
    Function.Injective
      (fun tape :
          { tape // tape ∈ terminalCEChallengeTapeSlotFiber slotSeed } =>
        terminalCERemainingChallengeTape slotSeed.1 tape.1) := by
  intro lhs rhs hRemaining
  apply Subtype.ext
  funext round
  by_cases hRound : round = slotSeed.1
  · subst round
    have hLhs :
        lhs.1 slotSeed.1 = slotSeed.2 :=
      (terminalCEChallengeTapeSlotFiber_mem_iff slotSeed lhs.1).mp lhs.2
    have hRhs :
        rhs.1 slotSeed.1 = slotSeed.2 :=
      (terminalCEChallengeTapeSlotFiber_mem_iff slotSeed rhs.1).mp rhs.2
    exact hLhs.trans hRhs.symm
  · exact congrFun hRemaining ⟨round, hRound⟩

theorem terminalCEChallengeTapeSlotFiber_card_le
    {roundCount : Nat}
    (slotSeed : TerminalCEFailureSlotSeed roundCount) :
    (terminalCEChallengeTapeSlotFiber slotSeed).card ≤
      3 ^ (roundCount - 1) := by
  have hCard :
      Fintype.card (terminalCEChallengeTapeSlotFiber slotSeed) ≤
        Fintype.card (TerminalCERemainingChallengeTape roundCount slotSeed.1) :=
    Fintype.card_le_of_injective
      (fun tape :
          { tape // tape ∈ terminalCEChallengeTapeSlotFiber slotSeed } =>
        terminalCERemainingChallengeTape slotSeed.1 tape.1)
      (terminalCEChallengeTapeSlotFiber_remaining_injective slotSeed)
  simpa [Fintype.card_coe, terminalCERemainingChallengeTape_card slotSeed.1] using hCard

def terminalCEChallengeTapeBadSeedsFromSlots
    {roundCount : Nat}
    (slotBadSeeds : Finset (TerminalCEFailureSlotSeed roundCount)) :
    Finset (TerminalCEChallengeTape roundCount) :=
  slotBadSeeds.biUnion terminalCEChallengeTapeSlotFiber

theorem terminalCEChallengeTapeBadSeedsFromSlots_mem_of_slot
    {roundCount : Nat}
    {slotBadSeeds : Finset (TerminalCEFailureSlotSeed roundCount)}
    {slotSeed : TerminalCEFailureSlotSeed roundCount}
    {tape : TerminalCEChallengeTape roundCount}
    (hSlot : slotSeed ∈ slotBadSeeds)
    (hTape : tape slotSeed.1 = slotSeed.2) :
    tape ∈ terminalCEChallengeTapeBadSeedsFromSlots slotBadSeeds := by
  rw [terminalCEChallengeTapeBadSeedsFromSlots]
  rw [mem_biUnion]
  exact ⟨slotSeed, hSlot,
    (terminalCEChallengeTapeSlotFiber_mem_iff slotSeed tape).mpr hTape⟩

theorem terminalCEChallengeTapeBadSeedsFromSlots_card_le
    {roundCount slotBound : Nat}
    {slotBadSeeds : Finset (TerminalCEFailureSlotSeed roundCount)}
    (hSlotBound : slotBadSeeds.card ≤ slotBound) :
    (terminalCEChallengeTapeBadSeedsFromSlots slotBadSeeds).card ≤
      slotBound * 3 ^ (roundCount - 1) := by
  calc
    (terminalCEChallengeTapeBadSeedsFromSlots slotBadSeeds).card
        ≤ ∑ slotSeed ∈ slotBadSeeds,
            (terminalCEChallengeTapeSlotFiber slotSeed).card := by
          rw [terminalCEChallengeTapeBadSeedsFromSlots]
          exact card_biUnion_le
    _ ≤ ∑ _slotSeed ∈ slotBadSeeds, 3 ^ (roundCount - 1) := by
          apply sum_le_sum
          intro slotSeed _hSlot
          exact terminalCEChallengeTapeSlotFiber_card_le slotSeed
    _ = slotBadSeeds.card * 3 ^ (roundCount - 1) := by
          simp
    _ ≤ slotBound * 3 ^ (roundCount - 1) := by
          exact Nat.mul_le_mul_right _ hSlotBound

def swiftCETraceChallengeTape
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount) :
    TerminalCEChallengeTape roundCount :=
  fun round => ceOpeningResponseTagSymbol (trace.responseTags round)

def swiftCETraceSlotSeed
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount)
    (round : Fin roundCount) :
    TerminalCEFailureSlotSeed roundCount :=
  (round, swiftCETraceChallengeTape trace round)

theorem swiftCETraceSlotSeed_matches_challengeTape
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount)
    (round : Fin roundCount) :
    swiftCETraceChallengeTape trace (swiftCETraceSlotSeed trace round).1 =
      (swiftCETraceSlotSeed trace round).2 := by
  rfl

theorem swiftCETraceChallengeTape_matches_verifier_branch
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : SwiftCEVerifierTrace Commitment Response Witness Seed roundCount)
    (round : Fin roundCount) :
    (trace.terminalTrace.rounds round).challenge =
      ceOpeningChallengeFromSymbol (swiftCETraceChallengeTape trace round) := by
  simpa [swiftCETraceChallengeTape, ceOpeningResponseTagChallenge] using
    trace.responseTags_match round

def terminalCESwiftTraceProofTape
    {Proof Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (proofTrace : Proof → SwiftCEVerifierTrace Commitment Response Witness Seed roundCount)
    (proof : Proof) :
    TerminalCEChallengeTape roundCount :=
  swiftCETraceChallengeTape (proofTrace proof)

def terminalCESwiftTraceProofSlotSeed
    {Proof Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (proofTrace : Proof → SwiftCEVerifierTrace Commitment Response Witness Seed roundCount)
    (badRound : Proof → Fin roundCount)
    (proof : Proof) :
    TerminalCEFailureSlotSeed roundCount :=
  swiftCETraceSlotSeed (proofTrace proof) (badRound proof)

theorem terminalCESwiftTraceProofSlotSeed_matches_tape
    {Proof Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (proofTrace : Proof → SwiftCEVerifierTrace Commitment Response Witness Seed roundCount)
    (badRound : Proof → Fin roundCount)
    (proof : Proof) :
    terminalCESwiftTraceProofTape proofTrace proof
        (terminalCESwiftTraceProofSlotSeed proofTrace badRound proof).1 =
      (terminalCESwiftTraceProofSlotSeed proofTrace badRound proof).2 := by
  rfl

def terminalCEConstructive_slotFailureLocalization
    {Claim Proof Witness : Type}
    {count roundCount : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → TerminalCEFailureSlotSeed roundCount)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] :
    TerminalCEConstructiveFailureLocalization
      (Seed := TerminalCEFailureSlotSeed roundCount)
      (roundCount := roundCount)
      verifyProof
      opens
      proofSeed where
  failureSlot := fun seed => seed.1
  failureSlot_injective := by
    intro lhs rhs h
    exact Subtype.ext h

theorem terminalCEConstructive_badSeeds_card_le_roundCount_times_three
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (localization :
      TerminalCEConstructiveFailureLocalization
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed) :
    (TerminalCEConstructiveBadSeeds verifyProof opens proofSeed).card ≤
      roundCount * 3 := by
  have hCard :
      Fintype.card (TerminalCEConstructiveBadSeeds verifyProof opens proofSeed) ≤
        Fintype.card (Fin roundCount × CEOpeningChallengeSymbol) :=
    Fintype.card_le_of_injective
      localization.failureSlot
      localization.failureSlot_injective
  simpa [CEOpeningChallengeSymbol, Fintype.card_coe, Fintype.card_prod]
    using hCard

theorem terminalCEConstructive_badSeeds_probability_le
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (localization :
      TerminalCEConstructiveFailureLocalization
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed) :
    (TerminalCEConstructiveBadSeeds verifyProof opens proofSeed).card ≤
      TerminalCEProofBadSeedBudget roundCount := by
  simpa [TerminalCEProofBadSeedBudget] using
    terminalCEConstructive_badSeeds_card_le_roundCount_times_three
      localization

theorem terminalCEConstructive_slotBadSeeds_card_le_budget
    {Claim Proof Witness : Type}
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → TerminalCEFailureSlotSeed roundCount}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] :
    (TerminalCEConstructiveBadSeeds verifyProof opens proofSeed).card ≤
      TerminalCEProofBadSeedBudget roundCount := by
  exact terminalCEConstructive_badSeeds_probability_le
    (terminalCEConstructive_slotFailureLocalization
      verifyProof
      opens
      proofSeed)

structure TerminalCEConstructiveFiniteSoundnessCertificate
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    (bound : Nat) where
  badSeeds : Finset Seed
  card_le : badSeeds.card ≤ bound
  extract_outside_bad :
    ∀ statement proof,
      verifyProof statement proof →
        proofSeed proof ∉ badSeeds →
          ∃ witnesses : Fin count → Witness,
            TerminalLocalBatchRelation statement witnesses opens

def terminalCEConstructive_finiteSoundnessCertificate
    {Claim Proof Witness Seed Commitment Response : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (semantics :
      TerminalCEConstructiveVerifierSemantics
        (Commitment := Commitment)
        (Response := Response)
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed)
    (localization :
      TerminalCEConstructiveFailureLocalization
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      proofSeed
      (TerminalCEProofBadSeedBudget roundCount) where
  badSeeds := TerminalCEConstructiveBadSeeds verifyProof opens proofSeed
  card_le := terminalCEConstructive_badSeeds_probability_le localization
  extract_outside_bad := by
    intro statement proof hVerify hSeed
    exact terminalCEConstructive_extract_outside_bad semantics hVerify hSeed

def terminalCEConstructive_slotSeedFiniteSoundnessCertificate
    {Claim Proof Witness Commitment Response : Type}
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → TerminalCEFailureSlotSeed roundCount}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (semantics :
      TerminalCEConstructiveVerifierSemantics
        (Seed := TerminalCEFailureSlotSeed roundCount)
        (Commitment := Commitment)
        (Response := Response)
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      proofSeed
      (TerminalCEProofBadSeedBudget roundCount) :=
  terminalCEConstructive_finiteSoundnessCertificate
    semantics
    (terminalCEConstructive_slotFailureLocalization
      verifyProof
      opens
      proofSeed)

structure TerminalCESlotSeedLocalizationEvidence
    {Claim Proof Witness Commitment Response : Type}
    {count roundCount : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → TerminalCEFailureSlotSeed roundCount)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] where
  semantics :
    TerminalCEConstructiveVerifierSemantics
      (Seed := TerminalCEFailureSlotSeed roundCount)
      (Commitment := Commitment)
      (Response := Response)
      (roundCount := roundCount)
      verifyProof
      opens
      proofSeed

def terminalCEConstructive_certificate_of_slotSeedLocalizationEvidence
    {Claim Proof Witness Commitment Response : Type}
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → TerminalCEFailureSlotSeed roundCount}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (evidence :
      TerminalCESlotSeedLocalizationEvidence
        (Commitment := Commitment)
        (Response := Response)
        verifyProof
        opens
        proofSeed) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      proofSeed
      (TerminalCEProofBadSeedBudget roundCount) :=
  terminalCEConstructive_slotSeedFiniteSoundnessCertificate
    evidence.semantics

def terminalCESwiftSlotSeedFiniteSoundnessCertificate
    {Claim Proof Witness Commitment Response : Type}
    {count : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → TerminalCEFailureSlotSeed terminalCESwiftRoundCount}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (evidence :
      TerminalCESlotSeedLocalizationEvidence
        (Commitment := Commitment)
        (Response := Response)
        verifyProof
        opens
        proofSeed) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      proofSeed
      terminalCESwiftProofBadSeedBudget := by
  simpa [terminalCESwiftProofBadSeedBudget] using
    terminalCEConstructive_certificate_of_slotSeedLocalizationEvidence
      evidence

theorem terminalCEConstructive_certificate_extract_outside_bad
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count bound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEConstructiveFiniteSoundnessCertificate
        verifyProof
        opens
        proofSeed
        bound)
    {statement : TerminalCEStatement Claim count}
    {proof : Proof}
    (hVerify : verifyProof statement proof)
    (hSeed : proofSeed proof ∉ certificate.badSeeds) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens :=
  certificate.extract_outside_bad statement proof hVerify hSeed

structure TerminalCEFullTapeFromSlotCertificateEvidence
    {Claim Proof Witness : Type}
    {count roundCount slotBound : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (tapeSeed : Proof → TerminalCEChallengeTape roundCount) where
  slotSeed : Proof → TerminalCEFailureSlotSeed roundCount
  slotSeed_matches_tape :
    ∀ proof, tapeSeed proof (slotSeed proof).1 = (slotSeed proof).2
  slotCertificate :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      slotSeed
      slotBound

def terminalCEFullTapeCertificate_of_slotCertificate
    {Claim Proof Witness : Type}
    {count roundCount slotBound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {tapeSeed : Proof → TerminalCEChallengeTape roundCount}
    (evidence :
      TerminalCEFullTapeFromSlotCertificateEvidence
        verifyProof
        opens
        tapeSeed
        (slotBound := slotBound)) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      tapeSeed
      (slotBound * 3 ^ (roundCount - 1)) where
  badSeeds :=
    terminalCEChallengeTapeBadSeedsFromSlots
      evidence.slotCertificate.badSeeds
  card_le :=
    terminalCEChallengeTapeBadSeedsFromSlots_card_le
      evidence.slotCertificate.card_le
  extract_outside_bad := by
    intro statement proof hVerify hTapeSeed
    have hSlotSeed :
        evidence.slotSeed proof ∉ evidence.slotCertificate.badSeeds := by
      intro hBadSlot
      exact hTapeSeed
        (terminalCEChallengeTapeBadSeedsFromSlots_mem_of_slot
          hBadSlot
          (evidence.slotSeed_matches_tape proof))
    exact evidence.slotCertificate.extract_outside_bad
      statement
      proof
      hVerify
      hSlotSeed

def terminalCESwiftFullTapeCertificate_of_slotEvidence
    {Claim Proof Witness Commitment Response : Type}
    {count : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {slotSeed : Proof → TerminalCEFailureSlotSeed terminalCESwiftRoundCount}
    {tapeSeed : Proof → TerminalCEChallengeTape terminalCESwiftRoundCount}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens slotSeed)]
    (slotEvidence :
      TerminalCESlotSeedLocalizationEvidence
        (Commitment := Commitment)
        (Response := Response)
        verifyProof
        opens
        slotSeed)
    (hMatches : ∀ proof, tapeSeed proof (slotSeed proof).1 = (slotSeed proof).2) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      tapeSeed
      (terminalCESwiftProofBadSeedBudget * 3 ^ (terminalCESwiftRoundCount - 1)) :=
  terminalCEFullTapeCertificate_of_slotCertificate
    (slotBound := terminalCESwiftProofBadSeedBudget)
    {
      slotSeed := slotSeed
      slotSeed_matches_tape := hMatches
      slotCertificate :=
        terminalCESwiftSlotSeedFiniteSoundnessCertificate
          slotEvidence
    }

def terminalCESwiftTraceFullTapeCertificate_of_slotEvidence
    {Claim Proof Witness Commitment Response Seed : Type}
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofTrace : Proof → SwiftCEVerifierTrace Commitment Response Witness Seed roundCount}
    {badRound : Proof → Fin roundCount}
    [DecidablePred
      (TerminalCESeedExtracts
        verifyProof
        opens
        (terminalCESwiftTraceProofSlotSeed proofTrace badRound))]
    (slotEvidence :
      TerminalCESlotSeedLocalizationEvidence
        (Commitment := Commitment)
        (Response := Response)
        verifyProof
        opens
        (terminalCESwiftTraceProofSlotSeed proofTrace badRound)) :
    TerminalCEConstructiveFiniteSoundnessCertificate
      verifyProof
      opens
      (terminalCESwiftTraceProofTape proofTrace)
      (TerminalCEProofBadSeedBudget roundCount * 3 ^ (roundCount - 1)) :=
  terminalCEFullTapeCertificate_of_slotCertificate
    (slotBound := TerminalCEProofBadSeedBudget roundCount)
    {
      slotSeed := terminalCESwiftTraceProofSlotSeed proofTrace badRound
      slotSeed_matches_tape :=
        terminalCESwiftTraceProofSlotSeed_matches_tape proofTrace badRound
      slotCertificate :=
        terminalCEConstructive_certificate_of_slotSeedLocalizationEvidence
          slotEvidence
    }

end SuperNeoFormal
