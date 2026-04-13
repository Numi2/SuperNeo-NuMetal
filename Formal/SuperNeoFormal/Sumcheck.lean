import Mathlib

/-!
Abstract sum-check verifier model.

The Swift verifier checks each round polynomial with `g_i(0) + g_i(1) =
claim_i`, derives a challenge, updates the running claim to `g_i(r_i)`, and
finally delegates the last point/value pair to a protocol-specific public
oracle check. This module captures that verifier skeleton without modeling a
particular Fiat-Shamir hash or a concrete polynomial representation.
-/

namespace SuperNeoFormal

variable {F : Type} [Semiring F]

def SumcheckRoundConsistent
    (claim nextClaim : F)
    (roundPolynomial : F → F)
    (challenge : F) : Prop :=
  roundPolynomial 0 + roundPolynomial 1 = claim ∧
    nextClaim = roundPolynomial challenge

structure SumcheckVerifierTrace (F : Type) where
  rounds : Nat
  claimedSum : F
  claimAt : Nat → F
  roundPolynomial : Nat → F → F
  challenge : Nat → F

def SumcheckVerifierAccepts
    (trace : SumcheckVerifierTrace F)
    (finalCheck : (Nat → F) → F → Prop) : Prop :=
  trace.claimAt 0 = trace.claimedSum ∧
    (∀ round, round < trace.rounds →
      SumcheckRoundConsistent
        (trace.claimAt round)
        (trace.claimAt (round + 1))
        (trace.roundPolynomial round)
        (trace.challenge round)) ∧
    finalCheck trace.challenge (trace.claimAt trace.rounds)

theorem sumcheck_accepts_initial_claim
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck) :
    trace.claimAt 0 = trace.claimedSum :=
  hAccepts.1

theorem sumcheck_accepts_round_consistency
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck)
    {round : Nat}
    (hRound : round < trace.rounds) :
    SumcheckRoundConsistent
      (trace.claimAt round)
      (trace.claimAt (round + 1))
      (trace.roundPolynomial round)
      (trace.challenge round) :=
  hAccepts.2.1 round hRound

theorem sumcheck_accepts_round_zero_one_sum
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck)
    {round : Nat}
    (hRound : round < trace.rounds) :
    trace.roundPolynomial round 0 + trace.roundPolynomial round 1 =
      trace.claimAt round :=
  (sumcheck_accepts_round_consistency hAccepts hRound).1

theorem sumcheck_accepts_next_claim
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck)
    {round : Nat}
    (hRound : round < trace.rounds) :
    trace.claimAt (round + 1) =
      trace.roundPolynomial round (trace.challenge round) :=
  (sumcheck_accepts_round_consistency hAccepts hRound).2

theorem sumcheck_accepts_final_check
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck) :
    finalCheck trace.challenge (trace.claimAt trace.rounds) :=
  hAccepts.2.2

end SuperNeoFormal
