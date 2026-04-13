import SuperNeoFormal.Sumcheck
import SuperNeoFormal.PiRLC

/-!
Abstract PiCCS/sum-check model.

The concrete Swift `PublicQVerifierState` reconstructs the public Q final
evaluation from public instances, prior CE claims, PiCCS final claims, the
sum-check point, and transcript challenges. This file keeps that Q evaluator as
an explicit parameter and proves the verifier-facing facts that follow from
acceptance of the sum-check trace.
-/

namespace SuperNeoFormal

variable {F : Type} [Semiring F]

structure PiCCSPublicQState (F : Type) where
  numVars : Nat
  claimedSum : F
  finalEvaluation : (Nat → F) → F
  finalClaimsConsistent : (Nat → F) → Prop

def PiCCSFinalCheck
    (state : PiCCSPublicQState F)
    (point : Nat → F)
    (value : F) : Prop :=
  state.finalEvaluation point = value ∧
    state.finalClaimsConsistent point

def PiCCSAccepts
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F) : Prop :=
  trace.rounds = state.numVars ∧
    trace.claimedSum = state.claimedSum ∧
    SumcheckVerifierAccepts trace (PiCCSFinalCheck state)

theorem piccs_accepts_sumcheck
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    (hAccepts : PiCCSAccepts state trace) :
    SumcheckVerifierAccepts trace (PiCCSFinalCheck state) :=
  hAccepts.2.2

theorem piccs_accepts_round_count
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    (hAccepts : PiCCSAccepts state trace) :
    trace.rounds = state.numVars :=
  hAccepts.1

theorem piccs_accepts_claimed_sum
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    (hAccepts : PiCCSAccepts state trace) :
    trace.claimedSum = state.claimedSum :=
  hAccepts.2.1

theorem piccs_accepts_final_q_value
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    (hAccepts : PiCCSAccepts state trace) :
    state.finalEvaluation trace.challenge = trace.claimAt trace.rounds :=
  (sumcheck_accepts_final_check (piccs_accepts_sumcheck hAccepts)).1

theorem piccs_accepts_final_claim_consistency
    {state : PiCCSPublicQState F}
    {trace : SumcheckVerifierTrace F}
    (hAccepts : PiCCSAccepts state trace) :
    state.finalClaimsConsistent trace.challenge :=
  (sumcheck_accepts_final_check (piccs_accepts_sumcheck hAccepts)).2

def PiCCSSumcheckSoundnessAssumption
    (state : PiCCSPublicQState F)
    (traceSound : SumcheckVerifierTrace F → Prop) : Prop :=
  ∀ trace,
    PiCCSAccepts state trace →
      traceSound trace

theorem piccs_soundness_from_sumcheck_assumption
    {state : PiCCSPublicQState F}
    {traceSound : SumcheckVerifierTrace F → Prop}
    (hSoundness : PiCCSSumcheckSoundnessAssumption state traceSound)
    {trace : SumcheckVerifierTrace F}
    (hAccepts : PiCCSAccepts state trace) :
    traceSound trace :=
  hSoundness trace hAccepts

end SuperNeoFormal
