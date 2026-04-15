import Mathlib.Tactic
import SuperNeoFormal.SumcheckSoundness

/-!
Finite prefix bad-challenge aggregation for sum-check.

This module packages the bookkeeping layer between the per-round
low-degree/root-count facts in `SumcheckSoundness.lean` and the global
finite-bad-challenge PiCCS boundary.  It remains finite and deterministic: it
does not model challenge distributions or claim a probabilistic bound.
-/

noncomputable section

namespace SuperNeoFormal

section PrefixBadChallenges

variable {K : Type} [Field K] [DecidableEq K]

def sumcheckPrefixRoundBadChallenges
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    (round : Nat) : Finset K :=
  if prover round = exact round then
    ∅
  else
    sumcheckPolynomialAgreementInSupport support (prover round) (exact round)

theorem sumcheckPrefixRoundBadChallenges_mem_iff
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    (round : Nat)
    (challenge : K) :
    challenge ∈ sumcheckPrefixRoundBadChallenges support prover exact round ↔
      prover round ≠ exact round ∧
        challenge ∈ support ∧
          (prover round).eval challenge = (exact round).eval challenge := by
  by_cases hEq : prover round = exact round
  · simp [sumcheckPrefixRoundBadChallenges, hEq]
  · simp [
      sumcheckPrefixRoundBadChallenges,
      hEq,
      sumcheckPolynomialAgreementInSupport_mem_iff
    ]

theorem sumcheckPrefixRoundBadChallenges_card_le_degreeBound
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    {degreeBound round : Nat}
    (hProverDegree : (prover round).natDegree ≤ degreeBound)
    (hExactDegree : (exact round).natDegree ≤ degreeBound) :
    (sumcheckPrefixRoundBadChallenges support prover exact round).card ≤
      degreeBound := by
  by_cases hEq : prover round = exact round
  · simp [sumcheckPrefixRoundBadChallenges, hEq]
  · simpa [sumcheckPrefixRoundBadChallenges, hEq] using
      (sumcheckPolynomialAgreementInSupport_card_le_degreeBound
        support
        (prover := prover round)
        (exact := exact round)
        (degreeBound := degreeBound)
        hEq
        hProverDegree
        hExactDegree)

def sumcheckPrefixBadChallenges
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K) :
    Finset (Nat × K) :=
  (Finset.range rounds).biUnion fun round =>
    (sumcheckPrefixRoundBadChallenges support prover exact round).image
      (fun challenge => (round, challenge))

theorem sumcheckPrefixBadChallenges_mem_iff
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    (round : Nat)
    (challenge : K) :
    (round, challenge) ∈
        sumcheckPrefixBadChallenges rounds support prover exact ↔
      round < rounds ∧
        challenge ∈ sumcheckPrefixRoundBadChallenges support prover exact round := by
  constructor
  · intro hMember
    rw [sumcheckPrefixBadChallenges, Finset.mem_biUnion] at hMember
    rcases hMember with ⟨sourceRound, hSourceRound, hImage⟩
    rw [Finset.mem_image] at hImage
    rcases hImage with ⟨sourceChallenge, hChallenge, hPair⟩
    cases hPair
    exact ⟨Finset.mem_range.mp hSourceRound, hChallenge⟩
  · intro hMember
    rw [sumcheckPrefixBadChallenges, Finset.mem_biUnion]
    exact ⟨round, Finset.mem_range.mpr hMember.1,
      Finset.mem_image.mpr ⟨challenge, hMember.2, rfl⟩⟩

theorem sumcheckPrefixBadChallenges_member_agrees
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    {round : Nat}
    {challenge : K}
    (hMember :
      (round, challenge) ∈
        sumcheckPrefixBadChallenges rounds support prover exact) :
    round < rounds ∧
      prover round ≠ exact round ∧
        challenge ∈ support ∧
          (prover round).eval challenge = (exact round).eval challenge := by
  have hPrefix :=
    (sumcheckPrefixBadChallenges_mem_iff
      rounds
      support
      prover
      exact
      round
      challenge).mp hMember
  have hRound :=
    (sumcheckPrefixRoundBadChallenges_mem_iff
      support
      prover
      exact
      round
      challenge).mp hPrefix.2
  exact ⟨hPrefix.1, hRound.1, hRound.2.1, hRound.2.2⟩

theorem sumcheckPrefixBadChallenges_contains_round_agreement
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    {round : Nat}
    {challenge : K}
    (hRound : round < rounds)
    (hMismatch : prover round ≠ exact round)
    (hChallenge : challenge ∈ support)
    (hEval : (prover round).eval challenge = (exact round).eval challenge) :
    (round, challenge) ∈
      sumcheckPrefixBadChallenges rounds support prover exact := by
  rw [sumcheckPrefixBadChallenges_mem_iff]
  rw [sumcheckPrefixRoundBadChallenges_mem_iff]
  exact ⟨hRound, hMismatch, hChallenge, hEval⟩

theorem sumcheckPrefixBadChallenges_card_le_of_round_bounds
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    {degreeBound : Nat}
    (hRound :
      ∀ round, round < rounds →
        (sumcheckPrefixRoundBadChallenges support prover exact round).card ≤
          degreeBound) :
    (sumcheckPrefixBadChallenges rounds support prover exact).card ≤
      rounds * degreeBound := by
  calc
    (sumcheckPrefixBadChallenges rounds support prover exact).card ≤
        ∑ round ∈ Finset.range rounds,
          ((sumcheckPrefixRoundBadChallenges support prover exact round).image
            (fun challenge => (round, challenge))).card := by
      rw [sumcheckPrefixBadChallenges]
      exact Finset.card_biUnion_le
    _ ≤ ∑ _round ∈ Finset.range rounds, degreeBound := by
      apply Finset.sum_le_sum
      intro round hRoundMem
      exact le_trans
        Finset.card_image_le
        (hRound round (Finset.mem_range.mp hRoundMem))
    _ = rounds * degreeBound := by
      simp

theorem sumcheckPrefixBadChallenges_card_le_degreeBound
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    {degreeBound : Nat}
    (hProverDegree :
      ∀ round, round < rounds →
        (prover round).natDegree ≤ degreeBound)
    (hExactDegree :
      ∀ round, round < rounds →
        (exact round).natDegree ≤ degreeBound) :
    (sumcheckPrefixBadChallenges rounds support prover exact).card ≤
      rounds * degreeBound :=
  sumcheckPrefixBadChallenges_card_le_of_round_bounds
    rounds
    support
    prover
    exact
    (fun round hRound =>
      sumcheckPrefixRoundBadChallenges_card_le_degreeBound
        support
        prover
        exact
        (hProverDegree round hRound)
        (hExactDegree round hRound))

def sumcheckPrefixBadChallengeBudget
    (rounds degreeBound : Nat) : Nat :=
  rounds * degreeBound

theorem sumcheckPrefixBadChallengeBudget_card_le
    (rounds : Nat)
    (support : Finset K)
    (prover exact : Nat → Polynomial K)
    {degreeBound : Nat}
    (hProverDegree :
      ∀ round, round < rounds →
        (prover round).natDegree ≤ degreeBound)
    (hExactDegree :
      ∀ round, round < rounds →
        (exact round).natDegree ≤ degreeBound) :
    (sumcheckPrefixBadChallenges rounds support prover exact).card ≤
      sumcheckPrefixBadChallengeBudget rounds degreeBound := by
  exact sumcheckPrefixBadChallenges_card_le_degreeBound
    rounds
    support
    prover
    exact
    hProverDegree
    hExactDegree

end PrefixBadChallenges

end SuperNeoFormal
