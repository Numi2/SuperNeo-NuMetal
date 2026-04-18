import SuperNeoFormal.PiCCSSoundness
import SuperNeoFormal.SumcheckSoundness
import SuperNeoFormal.SumcheckPrefixSoundness
import SuperNeoFormal.GoldilocksExt2

/-!
Constructive finite PiCCS bad-challenge set.

This module names the concrete bad set obtained from the per-round low-degree
sum-check mismatch theorem.  Unlike `PiCCSFiniteSoundness.lean`, this file does
not take the bad set as a certificate field and does not import the certificate
layer.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

variable {F : Type} [Field F] [DecidableEq F]

def PiCCSBadChallengeSetConstructed
    (numVars : Nat)
    (support : Finset F)
    (prover exact : Nat → Polynomial F) :
    Finset (Nat × F) :=
  sumcheckPrefixBadChallenges numVars support prover exact

def PiCCSConstructiveSumcheckBadChallengeBudget
    (numVars maxDegreePerRound : Nat) : Nat :=
  sumcheckPrefixBadChallengeBudget numVars maxDegreePerRound

theorem piccsGoldilocksExt2ChallengeSupport_below_selected128 :
    goldilocksModulus ^ 2 < 2 ^ 128 := by
  native_decide

theorem piccsSelectedBadChallengeBudget_exceeds_selected128 :
    goldilocksModulus ^ 2 < (18 * 4) * 2 ^ 128 := by
  native_decide

theorem PiCCSBadChallengeSetConstructed_mem_iff
    (numVars : Nat)
    (support : Finset F)
    (prover exact : Nat → Polynomial F)
    (round : Nat)
    (challenge : F) :
    (round, challenge) ∈
        PiCCSBadChallengeSetConstructed numVars support prover exact ↔
      round < numVars ∧
        prover round ≠ exact round ∧
          challenge ∈ support ∧
            (prover round).eval challenge = (exact round).eval challenge := by
  rw [PiCCSBadChallengeSetConstructed]
  constructor
  · intro hMember
    exact sumcheckPrefixBadChallenges_member_agrees
      numVars
      support
      prover
      exact
      hMember
  · intro hData
    exact sumcheckPrefixBadChallenges_contains_round_agreement
      numVars
      support
      prover
      exact
      hData.1
      hData.2.1
      hData.2.2.1
      hData.2.2.2

theorem PiCCSBadChallengeSetConstructed_card_le
    (numVars maxDegreePerRound : Nat)
    (support : Finset F)
    (prover exact : Nat → Polynomial F)
    (hProverDegree :
      ∀ round, round < numVars →
        (prover round).natDegree ≤ maxDegreePerRound)
    (hExactDegree :
      ∀ round, round < numVars →
        (exact round).natDegree ≤ maxDegreePerRound) :
    (PiCCSBadChallengeSetConstructed
      numVars
      support
      prover
      exact).card ≤
        numVars * maxDegreePerRound := by
  exact sumcheckPrefixBadChallenges_card_le_degreeBound
    numVars
    support
    prover
    exact
    hProverDegree
    hExactDegree

theorem PiCCSBadChallengeSetConstructed_card_le_budget
    (numVars maxDegreePerRound : Nat)
    (support : Finset F)
    (prover exact : Nat → Polynomial F)
    (hProverDegree :
      ∀ round, round < numVars →
        (prover round).natDegree ≤ maxDegreePerRound)
    (hExactDegree :
      ∀ round, round < numVars →
        (exact round).natDegree ≤ maxDegreePerRound) :
    (PiCCSBadChallengeSetConstructed
      numVars
      support
      prover
      exact).card ≤
        PiCCSConstructiveSumcheckBadChallengeBudget
          numVars
          maxDegreePerRound := by
  simpa [PiCCSConstructiveSumcheckBadChallengeBudget,
    sumcheckPrefixBadChallengeBudget] using
    PiCCSBadChallengeSetConstructed_card_le
      numVars
      maxDegreePerRound
      support
      prover
      exact
      hProverDegree
      hExactDegree

theorem PiCCSBadChallengeSetConstructed_contains_trace_challenge
    (support : Finset F)
    (prover exact : Nat → Polynomial F)
    {trace : SumcheckVerifierTrace F}
    {round : Nat}
    (hRound : round < trace.rounds)
    (hMismatch : prover round ≠ exact round)
    (hChallenge : trace.challenge round ∈ support)
    (hEval :
      (prover round).eval (trace.challenge round) =
        (exact round).eval (trace.challenge round)) :
    (round, trace.challenge round) ∈
      PiCCSBadChallengeSetConstructed trace.rounds support prover exact := by
  exact
    sumcheckPrefixBadChallenges_contains_round_agreement
      trace.rounds
      support
      prover
      exact
      hRound
      hMismatch
      hChallenge
      hEval

def PiCCSTraceChallengeFailureCovered
    (support : Finset F)
    (prover exact : Nat → Polynomial F)
    (trace : SumcheckVerifierTrace F) : Prop :=
  ∃ round, round < trace.rounds ∧
    prover round ≠ exact round ∧
      trace.challenge round ∈ support ∧
        (prover round).eval (trace.challenge round) =
          (exact round).eval (trace.challenge round)

theorem PiCCSTraceChallengeFailureCovered_mem_constructed_bad_set
    (support : Finset F)
    (prover exact : Nat → Polynomial F)
    {trace : SumcheckVerifierTrace F}
    (hFailure :
      PiCCSTraceChallengeFailureCovered support prover exact trace) :
    ∃ badChallenge,
      badChallenge ∈
        PiCCSBadChallengeSetConstructed trace.rounds support prover exact := by
  rcases hFailure with
    ⟨round, hRound, hMismatch, hChallenge, hEval⟩
  exact
    ⟨(round, trace.challenge round),
      PiCCSBadChallengeSetConstructed_contains_trace_challenge
        support
        prover
        exact
        hRound
        hMismatch
        hChallenge
        hEval⟩

end SuperNeoFormal
