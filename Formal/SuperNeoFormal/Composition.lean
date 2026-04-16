import SuperNeoFormal.PiCCS
import SuperNeoFormal.PiCCSFiniteSoundness
import SuperNeoFormal.PiRLC
import SuperNeoFormal.PiRLCFiniteSoundness
import SuperNeoFormal.PiDEC
import SuperNeoFormal.TerminalCE
import SuperNeoFormal.TerminalCEFiniteSoundness
import SuperNeoFormal.ProbabilityComposition
import SuperNeoFormal.TranscriptProbability
import SuperNeoFormal.ErrorLedger

/-!
Final verifier-acceptance composition model.

This is the deterministic top-level verifier shape implemented in Swift:
accepted terminal verification is accepted fold reduction plus matching terminal
CE output claims plus accepted terminal CE opening verification.
-/

namespace SuperNeoFormal

structure FoldReductionGates (Claim : Type) (outputCount : Nat) where
  outputClaims : Fin outputCount → Claim
  publicInputWellFormed : Prop
  piCCSAccepts : Prop
  piRLCAccepts : Prop
  piDECAccepts : Prop

def FoldReductionAccepted
    {Claim : Type}
    {outputCount : Nat}
    (gates : FoldReductionGates Claim outputCount) : Prop :=
  gates.publicInputWellFormed ∧
    gates.piCCSAccepts ∧
    gates.piRLCAccepts ∧
    gates.piDECAccepts

structure TerminalVerifierGates (Claim : Type) (outputCount : Nat) where
  statement : TerminalCEStatement Claim outputCount
  statementMatchesReduction : Prop
  terminalCEAccepts : Prop

structure TerminalProofVerifierGates
    (Claim Proof : Type)
    (outputCount : Nat) where
  statement : TerminalCEStatement Claim outputCount
  proof : Proof
  verifyProof : TerminalCEStatement Claim outputCount → Proof → Prop
  statementMatchesReduction : Prop

def SuperNeoVerifierAccepts
    {Claim : Type}
    {outputCount : Nat}
    (reduction : FoldReductionGates Claim outputCount)
    (terminal : TerminalVerifierGates Claim outputCount) : Prop :=
  FoldReductionAccepted reduction ∧
    terminal.statementMatchesReduction ∧
    terminal.terminalCEAccepts

def TerminalProofVerifierCEAccepts
    {Claim Proof : Type}
    {outputCount : Nat}
    (terminal : TerminalProofVerifierGates Claim Proof outputCount) : Prop :=
  TerminalCEAccepts terminal.statement terminal.proof terminal.verifyProof

def SuperNeoProofVerifierAccepts
    {Claim Proof : Type}
    {outputCount : Nat}
    (reduction : FoldReductionGates Claim outputCount)
    (terminal : TerminalProofVerifierGates Claim Proof outputCount) : Prop :=
  FoldReductionAccepted reduction ∧
    terminal.statementMatchesReduction ∧
    TerminalProofVerifierCEAccepts terminal

theorem fold_reduction_acceptance_from_stages
    {Claim : Type}
    {outputCount : Nat}
    {gates : FoldReductionGates Claim outputCount}
    (hPublicInput : gates.publicInputWellFormed)
    (hPiCCS : gates.piCCSAccepts)
    (hPiRLC : gates.piRLCAccepts)
    (hPiDEC : gates.piDECAccepts) :
    FoldReductionAccepted gates := by
  exact ⟨hPublicInput, hPiCCS, hPiRLC, hPiDEC⟩

theorem superneo_acceptance_composition
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hReduction : FoldReductionAccepted reduction)
    (hStatementMatches : terminal.statementMatchesReduction)
    (hTerminalCE : terminal.terminalCEAccepts) :
    SuperNeoVerifierAccepts reduction terminal :=
  ⟨hReduction, hStatementMatches, hTerminalCE⟩

theorem superneo_acceptance_requires_fold_reduction
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction :=
  hAccepts.1

theorem superneo_acceptance_requires_terminal_statement_match
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    terminal.statementMatchesReduction :=
  hAccepts.2.1

theorem superneo_acceptance_requires_terminal_ce
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    terminal.terminalCEAccepts :=
  hAccepts.2.2

theorem superneo_acceptance_deterministic_facts
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
        terminal.terminalCEAccepts :=
  ⟨
    superneo_acceptance_requires_fold_reduction hAccepts,
    superneo_acceptance_requires_terminal_statement_match hAccepts,
    superneo_acceptance_requires_terminal_ce hAccepts
  ⟩

theorem superneo_proof_acceptance_requires_fold_reduction
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction :=
  hAccepts.1

theorem superneo_proof_acceptance_requires_terminal_statement_match
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    terminal.statementMatchesReduction :=
  hAccepts.2.1

theorem superneo_proof_acceptance_requires_terminal_ce
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    TerminalProofVerifierCEAccepts terminal :=
  hAccepts.2.2

theorem superneo_proof_acceptance_deterministic_facts
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
        TerminalProofVerifierCEAccepts terminal :=
  ⟨
    superneo_proof_acceptance_requires_fold_reduction hAccepts,
    superneo_proof_acceptance_requires_terminal_statement_match hAccepts,
    superneo_proof_acceptance_requires_terminal_ce hAccepts
  ⟩

theorem superneo_terminal_soundness_from_ce_soundness
    {Claim Proof Witness : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {verifyProof : TerminalCEStatement Claim outputCount → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proof : Proof}
    (hProof : terminal.proof = proof)
    (hVerifyProof : terminal.verifyProof = verifyProof)
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (hCESoundness : TerminalCEProofSoundnessAssumption verifyProof opens) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens := by
  have hTerminalAccepts :
      TerminalCEAccepts terminal.statement proof verifyProof := by
    subst proof
    subst verifyProof
    exact superneo_proof_acceptance_requires_terminal_ce hAccepts
  exact ⟨
    superneo_proof_acceptance_requires_fold_reduction hAccepts,
    superneo_proof_acceptance_requires_terminal_statement_match hAccepts,
    terminal_ce_relation_from_verified_proof hCESoundness hTerminalAccepts
  ⟩

theorem superneo_end_to_end_from_ce_soundness
    {Claim Proof Witness : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {opens : Claim → Witness → Prop}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (hCESoundness : TerminalCEProofSoundnessAssumption terminal.verifyProof opens) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens :=
  superneo_terminal_soundness_from_ce_soundness
    (proof := terminal.proof)
    rfl
    rfl
    hAccepts
    hCESoundness

theorem superneo_end_to_end_outside_ce_badSeeds
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {outputCount bound : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (certificate :
      TerminalCEFiniteBadSeedCertificate
        terminal.verifyProof
        opens
        proofSeed
        bound)
    (hSeed : proofSeed terminal.proof ∉ certificate.badSeeds) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens := by
  exact ⟨
    superneo_proof_acceptance_requires_fold_reduction hAccepts,
    superneo_proof_acceptance_requires_terminal_statement_match hAccepts,
    terminal_ce_relation_from_verified_proof_outside_badSeeds
      certificate
      (superneo_proof_acceptance_requires_terminal_ce hAccepts)
      hSeed
  ⟩

theorem superneo_full_outside_bad_events_sound
    {Claim Proof Witness Seed PiRLCSeed PiCCSSeed TranscriptSeed : Type}
    [DecidableEq Seed] [DecidableEq PiRLCSeed] [DecidableEq PiCCSSeed]
    [DecidableEq TranscriptSeed]
    {outputCount bound : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (certificate :
      TerminalCEFiniteBadSeedCertificate
        terminal.verifyProof
        opens
        proofSeed
        bound)
    (pirlcBadSeeds : Finset PiRLCSeed)
    (piccsBadSeeds : Finset PiCCSSeed)
    (transcriptBadSeeds : Finset TranscriptSeed)
    (seeds : SuperNeoStageSeeds PiRLCSeed PiCCSSeed Seed TranscriptSeed)
    (targets : SuperNeoStageSoundnessTargets)
    (hOutside :
      superneoOutsideAggregate
        pirlcBadSeeds
        piccsBadSeeds
        certificate.badSeeds
        transcriptBadSeeds
        seeds)
    (hTerminalSeed : proofSeed terminal.proof = seeds.terminalCESeed)
    (hPiRLC :
      seeds.pirlcSeed ∉ pirlcBadSeeds →
        targets.pirlcSound)
    (hPiCCS :
      seeds.piccsSeed ∉ piccsBadSeeds →
        targets.piccsSound)
    (hTerminalCE :
      seeds.terminalCESeed ∉ certificate.badSeeds →
        targets.terminalCESound)
    (hTranscript :
      seeds.transcriptSeed ∉ transcriptBadSeeds →
        targets.transcriptSound) :
    superNeoStageSoundnessTargetsAll targets ∧
      FoldReductionAccepted reduction ∧
        terminal.statementMatchesReduction ∧
          ∃ witnesses : Fin outputCount → Witness,
            TerminalLocalBatchRelation terminal.statement witnesses opens := by
  have hStage :
      superNeoStageSoundnessTargetsAll targets :=
    superneo_stage_soundness_from_outsideAggregate
      pirlcBadSeeds
      piccsBadSeeds
      certificate.badSeeds
      transcriptBadSeeds
      seeds
      targets
      hOutside
      hPiRLC
      hPiCCS
      hTerminalCE
      hTranscript
  have hNotBad :=
    superneo_outsideAggregate_stage_not_bad
      pirlcBadSeeds
      piccsBadSeeds
      certificate.badSeeds
      transcriptBadSeeds
      seeds
      hOutside
  have hProofSeed : proofSeed terminal.proof ∉ certificate.badSeeds := by
    rw [hTerminalSeed]
    exact hNotBad.2.2.1
  exact ⟨
    hStage,
    superneo_end_to_end_outside_ce_badSeeds
      hAccepts
      certificate
      hProofSeed
  ⟩

theorem superneo_full_bad_event_cardinality_bound
    {PiRLCSeed PiCCSSeed TerminalCESeed TranscriptSeed : Type}
    [DecidableEq PiRLCSeed] [DecidableEq PiCCSSeed]
    [DecidableEq TerminalCESeed] [DecidableEq TranscriptSeed]
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
          transcriptBadSeeds.card :=
  superneo_aggregateBadEvents_card_le
    pirlcBadSeeds
    piccsBadSeeds
    terminalCEBadSeeds
    transcriptBadSeeds

theorem superneo_full_probability_denominator_profile
    (pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat) :
    superNeoFiatShamirProbabilityDenominator
      pirlcCount
      piccsRoundCount
      terminalCERoundCount
      transcriptByteLength =
        (((5 ^ phi81Degree) ^ pirlcCount *
            (goldilocksModulus ^ 2) ^ piccsRoundCount) *
          3 ^ terminalCERoundCount) *
            256 ^ transcriptByteLength :=
  superNeoFiatShamirProbabilityDenominator_profile_factors
    pirlcCount
    piccsRoundCount
    terminalCERoundCount
    transcriptByteLength

theorem superneo_full_probability_numerator_bound
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
        transcriptBadSeeds :=
  superNeoFiatShamirProbabilityNumerator_le_budget
    pirlcBadSeeds
    piccsBadSeeds
    terminalCEBadSeeds
    transcriptBadSeeds
    budget
    hPiRLC
    hPiCCS
    hTerminalCE
    hTranscript

theorem superneo_full_probability_composition
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
    superNeoFiatShamirProbability
      (superNeoFiatShamirBadTranscriptSeeds
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds) ≤
      (superNeoFiatShamirProbabilityBudgetNumerator
        budget
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds : ℚ) /
        (superNeoFiatShamirProbabilityDenominator
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength : ℚ) := by
  unfold superNeoFiatShamirProbability
  apply div_le_div_of_nonneg_right
  · exact_mod_cast
      superneo_full_probability_numerator_bound
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds
        budget
        hPiRLC
        hPiCCS
        hTerminalCE
        hTranscript
  · exact_mod_cast
      Nat.zero_le
        (superNeoFiatShamirProbabilityDenominator
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength)

end SuperNeoFormal
