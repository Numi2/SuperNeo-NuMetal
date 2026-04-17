import SuperNeoFormal.PiCCSFiniteSoundness
import SuperNeoFormal.SumcheckPrefixSoundness

/-!
Constructive finite PiCCS bad-challenge set.

This module names the concrete bad set obtained from the per-round low-degree
sum-check mismatch theorem.  Unlike `PiCCSFiniteSoundness.lean`, this file does
not take the bad set as a certificate field.
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
        PiCCSSumcheckBadChallengeBudget numVars maxDegreePerRound := by
  simpa [PiCCSSumcheckBadChallengeBudget] using
    PiCCSBadChallengeSetConstructed_card_le
      numVars
      maxDegreePerRound
      support
      prover
      exact
      hProverDegree
      hExactDegree

end SuperNeoFormal
