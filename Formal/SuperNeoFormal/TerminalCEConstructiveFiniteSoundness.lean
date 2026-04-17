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

end SuperNeoFormal
