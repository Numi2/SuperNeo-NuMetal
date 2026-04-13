import SuperNeoFormal.PiCCS
import SuperNeoFormal.SumcheckSoundness

/-!
PiCCS-facing bridge for the deterministic sum-check core.

This module connects `PiCCSPublicQState` to the exact public-Q oracle used by
`SumcheckSoundness.lean`.  It proves that accepted PiCCS traces whose
sum-check rounds match the exact public-Q partial sums reduce to the exact final
public-Q evaluation and the verifier's final-claim consistency predicate.
-/

noncomputable section

namespace SuperNeoFormal

variable {F : Type} [Semiring F]

def PiCCSStateMatchesOracle
    (state : PiCCSPublicQState F)
    (oracle : (Nat → F) → F) : Prop :=
  state.claimedSum = sumcheckBooleanHypercubeSum oracle state.numVars ∧
    ∀ point,
      state.finalEvaluation point =
        oracle (sumcheckPrefixPoint point state.numVars)

def PiCCSExactQReduction
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F)
    (oracle : (Nat → F) → F) : Prop :=
  state.claimedSum = sumcheckBooleanHypercubeSum oracle state.numVars ∧
    trace.claimAt trace.rounds =
      oracle (sumcheckPrefixPoint trace.challenge state.numVars) ∧
    state.finalEvaluation trace.challenge =
      oracle (sumcheckPrefixPoint trace.challenge state.numVars) ∧
    state.finalClaimsConsistent trace.challenge

theorem piccs_accepted_final_claim_equals_exact_oracle
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    {oracle : (Nat → F) → F}
    (hAccepts : PiCCSAccepts state trace)
    (hTraceMatches : SumcheckTraceMatchesOracle oracle trace) :
    trace.claimAt trace.rounds =
      oracle (sumcheckPrefixPoint trace.challenge state.numVars) := by
  have hRounds : trace.rounds = state.numVars := piccs_accepts_round_count hAccepts
  calc
    trace.claimAt trace.rounds =
        oracle (sumcheckPrefixPoint trace.challenge trace.rounds) :=
      sumcheck_exact_oracle_final_claim (piccs_accepts_sumcheck hAccepts) hTraceMatches
    _ = oracle (sumcheckPrefixPoint trace.challenge state.numVars) := by rw [hRounds]

theorem piccs_accepted_final_q_equals_exact_oracle
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    {oracle : (Nat → F) → F}
    (hAccepts : PiCCSAccepts state trace)
    (hTraceMatches : SumcheckTraceMatchesOracle oracle trace) :
    state.finalEvaluation trace.challenge =
      oracle (sumcheckPrefixPoint trace.challenge state.numVars) := by
  calc
    state.finalEvaluation trace.challenge = trace.claimAt trace.rounds :=
      piccs_accepts_final_q_value hAccepts
    _ = oracle (sumcheckPrefixPoint trace.challenge state.numVars) :=
      piccs_accepted_final_claim_equals_exact_oracle hAccepts hTraceMatches

theorem piccs_exact_q_reduction
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    {oracle : (Nat → F) → F}
    (hAccepts : PiCCSAccepts state trace)
    (hStateMatches : PiCCSStateMatchesOracle state oracle)
    (hTraceMatches : SumcheckTraceMatchesOracle oracle trace) :
    PiCCSExactQReduction state trace oracle := by
  constructor
  · exact hStateMatches.1
  constructor
  · exact piccs_accepted_final_claim_equals_exact_oracle hAccepts hTraceMatches
  constructor
  · exact hStateMatches.2 trace.challenge
  · exact piccs_accepts_final_claim_consistency hAccepts

end SuperNeoFormal
