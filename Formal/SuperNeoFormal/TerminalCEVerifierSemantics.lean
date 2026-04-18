import SuperNeoFormal.TerminalCE

/-!
Certificate-free terminal CE verifier semantics.

This module contains the shared challenge, trace, and budget vocabulary used by
both constructive and compatibility terminal CE soundness modules.  It does not
define finite bad-seed certificates.
-/

noncomputable section

namespace SuperNeoFormal

inductive CEOpeningVerifierChallenge where
  | mask
  | maskedWitness
  | permutedWitness
  deriving DecidableEq

abbrev CEOpeningChallengeSymbol :=
  Fin 3

def ceOpeningChallengeFromSymbol
    (symbol : CEOpeningChallengeSymbol) : CEOpeningVerifierChallenge :=
  match symbol.val with
  | 0 => CEOpeningVerifierChallenge.mask
  | 1 => CEOpeningVerifierChallenge.maskedWitness
  | _ => CEOpeningVerifierChallenge.permutedWitness

def CEOpeningChallengeDomain : Finset CEOpeningVerifierChallenge :=
  { CEOpeningVerifierChallenge.mask,
    CEOpeningVerifierChallenge.maskedWitness,
    CEOpeningVerifierChallenge.permutedWitness }

theorem ceOpeningChallengeDomain_card :
    CEOpeningChallengeDomain.card = 3 := by
  native_decide

theorem ceOpeningChallengeFromSymbol_mem_domain
    (symbol : CEOpeningChallengeSymbol) :
    ceOpeningChallengeFromSymbol symbol ∈ CEOpeningChallengeDomain := by
  fin_cases symbol <;> native_decide

theorem ceOpeningVerifierChallenge_mem_domain
    (challenge : CEOpeningVerifierChallenge) :
    challenge ∈ CEOpeningChallengeDomain := by
  cases challenge <;> native_decide

structure CEOpeningRoundSemantics (Commitment Response Witness : Type) where
  commitments : List Commitment
  response : Response
  challenge : CEOpeningVerifierChallenge
  verifierChecks : CEOpeningVerifierChallenge → Prop

def CEOpeningRoundAccepts
    {Commitment Response Witness : Type}
    (round : CEOpeningRoundSemantics Commitment Response Witness) : Prop :=
  round.verifierChecks round.challenge

structure TerminalCEVerifierTrace
    (Commitment Response Witness Seed : Type)
    (roundCount : Nat) where
  seed : Seed
  rounds : Fin roundCount → CEOpeningRoundSemantics Commitment Response Witness
  challengeSymbols : Fin roundCount → CEOpeningChallengeSymbol
  challenges_match :
    ∀ round,
      (rounds round).challenge =
        ceOpeningChallengeFromSymbol (challengeSymbols round)

def TerminalCEVerifierTraceAccepts
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount) :
    Prop :=
  ∀ round, CEOpeningRoundAccepts (trace.rounds round)

theorem terminalCEVerifierTrace_roundCount
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (_trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount) :
    Fintype.card (Fin roundCount) = roundCount := by
  simp

theorem terminalCEVerifierTrace_challenge_mem_domain
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount)
    (round : Fin roundCount) :
    (trace.rounds round).challenge ∈ CEOpeningChallengeDomain := by
  rw [trace.challenges_match round]
  exact ceOpeningChallengeFromSymbol_mem_domain (trace.challengeSymbols round)

theorem terminalCEVerifierTrace_accepts_derived_branch
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    {trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount}
    (hAccepts : TerminalCEVerifierTraceAccepts trace)
    (round : Fin roundCount) :
    (trace.rounds round).verifierChecks
      (ceOpeningChallengeFromSymbol (trace.challengeSymbols round)) := by
  have hRound := hAccepts round
  rw [← trace.challenges_match round]
  exact hRound

def TerminalCEProofBadSeedBudget
    (roundCount : Nat)
    (challengeCount : Nat := 3) : Nat :=
  roundCount * challengeCount

def terminalCESwiftRoundCount : Nat :=
  226

def terminalCESwiftProofBadSeedBudget : Nat :=
  TerminalCEProofBadSeedBudget terminalCESwiftRoundCount

theorem terminalCESwiftRoundCount_positive :
    0 < terminalCESwiftRoundCount := by
  native_decide

theorem terminalCESwiftProofBadSeedBudget_eq :
    terminalCESwiftProofBadSeedBudget = 678 := by
  native_decide

abbrev TerminalCESwiftVerifierTrace
    (Commitment Response Witness Seed : Type) :=
  TerminalCEVerifierTrace
    Commitment
    Response
    Witness
    Seed
    terminalCESwiftRoundCount

end SuperNeoFormal
