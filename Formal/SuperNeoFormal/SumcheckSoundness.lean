import SuperNeoFormal.Sumcheck

/-!
Deterministic sum-check soundness core.

This module gives the verifier skeleton from `Sumcheck.lean` a concrete
hypercube-sum semantics.  It does not mechanize the probabilistic
Schwartz-Zippel/low-degree argument.  Instead, it proves the exact-oracle
theorem needed underneath that argument: if each verifier round polynomial is
the true partial Boolean-hypercube sum of the target oracle, then the accepted
trace's final claim is exactly the oracle evaluated at the verifier challenge
point.
-/

noncomputable section

namespace SuperNeoFormal

variable {F : Type} [Semiring F]

def sumcheckSetAt (point : Nat → F) (index : Nat) (value : F) : Nat → F :=
  fun query => if query = index then value else point query

def sumcheckPrefixPoint (challenge : Nat → F) (round : Nat) : Nat → F :=
  fun index => if index < round then challenge index else 0

/--
Recursive Boolean-hypercube sum over `remaining` variables starting at
`offset`.  The ambient oracle is `Nat → F` to avoid dependent casts in the
protocol trace; only indices `[offset, offset + remaining)` are overwritten by
Boolean values during this sum.
-/
def sumcheckHypercubeSumFrom
    (oracle : (Nat → F) → F) : Nat → Nat → (Nat → F) → F
  | 0, _offset, point => oracle point
  | remaining + 1, offset, point =>
      sumcheckHypercubeSumFrom oracle remaining (offset + 1) (sumcheckSetAt point offset 0) +
        sumcheckHypercubeSumFrom oracle remaining (offset + 1) (sumcheckSetAt point offset 1)

def sumcheckPartialHypercubeSum
    (oracle : (Nat → F) → F)
    (rounds round : Nat)
    (point : Nat → F) : F :=
  sumcheckHypercubeSumFrom oracle (rounds - round) round point

def sumcheckBooleanHypercubeSum
    (oracle : (Nat → F) → F)
    (rounds : Nat) : F :=
  sumcheckPartialHypercubeSum oracle rounds 0 (fun _ => 0)

def sumcheckExactRoundPolynomial
    (oracle : (Nat → F) → F)
    (rounds round : Nat)
    (point : Nat → F)
    (value : F) : F :=
  sumcheckPartialHypercubeSum oracle rounds (round + 1)
    (sumcheckSetAt point round value)

theorem sumcheckPrefixPoint_zero (challenge : Nat → F) :
    sumcheckPrefixPoint challenge 0 = fun _ => 0 := by
  funext index
  simp [sumcheckPrefixPoint]

theorem sumcheckPartialHypercubeSum_recurrence
    (oracle : (Nat → F) → F)
    {rounds round : Nat}
    (hRound : round < rounds)
    (point : Nat → F) :
    sumcheckPartialHypercubeSum oracle rounds round point =
      sumcheckPartialHypercubeSum oracle rounds (round + 1) (sumcheckSetAt point round 0) +
        sumcheckPartialHypercubeSum oracle rounds (round + 1) (sumcheckSetAt point round 1) := by
  have hLength : rounds - round = (rounds - (round + 1)) + 1 := by omega
  rw [sumcheckPartialHypercubeSum]
  rw [hLength]
  simp [sumcheckHypercubeSumFrom, sumcheckPartialHypercubeSum]

theorem sumcheckExactRoundPolynomial_zero_add_one
    (oracle : (Nat → F) → F)
    {rounds round : Nat}
    (hRound : round < rounds)
    (point : Nat → F) :
    sumcheckExactRoundPolynomial oracle rounds round point 0 +
        sumcheckExactRoundPolynomial oracle rounds round point 1 =
      sumcheckPartialHypercubeSum oracle rounds round point := by
  rw [sumcheckPartialHypercubeSum_recurrence oracle hRound point]
  rfl

theorem sumcheckExactRoundPolynomial_eval
    (oracle : (Nat → F) → F)
    (rounds round : Nat)
    (point : Nat → F)
    (value : F) :
    sumcheckExactRoundPolynomial oracle rounds round point value =
      sumcheckPartialHypercubeSum oracle rounds (round + 1)
        (sumcheckSetAt point round value) := by
  rfl

theorem sumcheckExactRoundConsistent
    (oracle : (Nat → F) → F)
    {rounds round : Nat}
    (hRound : round < rounds)
    (point : Nat → F)
    (challenge : F) :
    SumcheckRoundConsistent
      (sumcheckPartialHypercubeSum oracle rounds round point)
      (sumcheckPartialHypercubeSum oracle rounds (round + 1)
        (sumcheckSetAt point round challenge))
      (sumcheckExactRoundPolynomial oracle rounds round point)
      challenge := by
  constructor
  · exact sumcheckExactRoundPolynomial_zero_add_one oracle hRound point
  · rfl

theorem sumcheckPrefixPoint_set_next (challenge : Nat → F) (round : Nat) :
    sumcheckSetAt (sumcheckPrefixPoint challenge round) round (challenge round) =
      sumcheckPrefixPoint challenge (round + 1) := by
  funext index
  by_cases hEq : index = round
  · simp [sumcheckSetAt, sumcheckPrefixPoint, hEq]
  · have hNotEq : ¬ index = round := hEq
    simp [sumcheckSetAt, sumcheckPrefixPoint, hNotEq]
    by_cases hLt : index < round
    · have hLtNext : index < round + 1 := by omega
      simp [hLt, hLtNext]
    · have hNotLtNext : ¬ index < round + 1 := by omega
      simp [hLt, hNotLtNext]

theorem sumcheckPartialHypercubeSum_final
    (oracle : (Nat → F) → F)
    (rounds : Nat)
    (point : Nat → F) :
    sumcheckPartialHypercubeSum oracle rounds rounds point = oracle point := by
  rw [sumcheckPartialHypercubeSum, Nat.sub_self]
  rfl

def SumcheckTraceMatchesOracle
    (oracle : (Nat → F) → F)
    (trace : SumcheckVerifierTrace F) : Prop :=
  trace.claimAt 0 =
      sumcheckPartialHypercubeSum oracle trace.rounds 0
        (sumcheckPrefixPoint trace.challenge 0) ∧
    ∀ round, round < trace.rounds →
      trace.roundPolynomial round =
        sumcheckExactRoundPolynomial oracle trace.rounds round
          (sumcheckPrefixPoint trace.challenge round)

theorem sumcheck_trace_initial_claim_eq_boolean_sum
    {oracle : (Nat → F) → F}
    {trace : SumcheckVerifierTrace F}
    (hMatches : SumcheckTraceMatchesOracle oracle trace) :
    trace.claimAt 0 = sumcheckBooleanHypercubeSum oracle trace.rounds := by
  rw [sumcheckBooleanHypercubeSum]
  simpa [sumcheckPrefixPoint_zero] using hMatches.1

theorem sumcheck_claim_eq_partial_hypercube_sum
    {oracle : (Nat → F) → F}
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck)
    (hMatches : SumcheckTraceMatchesOracle oracle trace) :
    ∀ round, round ≤ trace.rounds →
      trace.claimAt round =
        sumcheckPartialHypercubeSum oracle trace.rounds round
          (sumcheckPrefixPoint trace.challenge round) := by
  intro round hRoundLe
  induction round with
  | zero => exact hMatches.1
  | succ previous _ih =>
      have hPreviousLt : previous < trace.rounds := Nat.lt_of_succ_le hRoundLe
      calc
        trace.claimAt (previous + 1)
            = trace.roundPolynomial previous (trace.challenge previous) :=
              sumcheck_accepts_next_claim hAccepts hPreviousLt
        _ = sumcheckExactRoundPolynomial oracle trace.rounds previous
              (sumcheckPrefixPoint trace.challenge previous)
              (trace.challenge previous) := by
              rw [hMatches.2 previous hPreviousLt]
        _ = sumcheckPartialHypercubeSum oracle trace.rounds (previous + 1)
              (sumcheckSetAt
                (sumcheckPrefixPoint trace.challenge previous)
                previous
                (trace.challenge previous)) := rfl
        _ = sumcheckPartialHypercubeSum oracle trace.rounds (previous + 1)
              (sumcheckPrefixPoint trace.challenge (previous + 1)) := by
              rw [sumcheckPrefixPoint_set_next]

theorem sumcheck_exact_oracle_final_claim
    {oracle : (Nat → F) → F}
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck)
    (hMatches : SumcheckTraceMatchesOracle oracle trace) :
    trace.claimAt trace.rounds =
      oracle (sumcheckPrefixPoint trace.challenge trace.rounds) := by
  calc
    trace.claimAt trace.rounds =
        sumcheckPartialHypercubeSum oracle trace.rounds trace.rounds
          (sumcheckPrefixPoint trace.challenge trace.rounds) :=
      sumcheck_claim_eq_partial_hypercube_sum hAccepts hMatches trace.rounds le_rfl
    _ = oracle (sumcheckPrefixPoint trace.challenge trace.rounds) := by
      rw [sumcheckPartialHypercubeSum_final]

theorem sumcheck_exact_oracle_final_check
    {oracle : (Nat → F) → F}
    {trace : SumcheckVerifierTrace F}
    {finalCheck : (Nat → F) → F → Prop}
    (hAccepts : SumcheckVerifierAccepts trace finalCheck)
    (hMatches : SumcheckTraceMatchesOracle oracle trace) :
    finalCheck trace.challenge
      (oracle (sumcheckPrefixPoint trace.challenge trace.rounds)) := by
  have hFinal := sumcheck_accepts_final_check hAccepts
  rwa [sumcheck_exact_oracle_final_claim hAccepts hMatches] at hFinal

section LowDegreeRootCounting

variable {K : Type} [Field K] [DecidableEq K]

def sumcheckPolynomialRootsInSupport
    (support : Finset K)
    (polynomial : Polynomial K) : Finset K :=
  support.filter (fun value => polynomial.eval value = 0)

def sumcheckPolynomialAgreementInSupport
    (support : Finset K)
    (prover exact : Polynomial K) : Finset K :=
  sumcheckPolynomialRootsInSupport support (prover - exact)

theorem sumcheckPolynomialAgreementInSupport_mem_iff
    (support : Finset K)
    (prover exact : Polynomial K)
    (value : K) :
    value ∈ sumcheckPolynomialAgreementInSupport support prover exact ↔
      value ∈ support ∧ prover.eval value = exact.eval value := by
  simp [sumcheckPolynomialAgreementInSupport, sumcheckPolynomialRootsInSupport,
    Polynomial.eval_sub, sub_eq_zero]

theorem sumcheckPolynomialRootsInSupport_card_le_natDegree
    (support : Finset K)
    {polynomial : Polynomial K}
    (hNonzero : polynomial ≠ 0) :
    (sumcheckPolynomialRootsInSupport support polynomial).card ≤
      polynomial.natDegree := by
  apply Polynomial.card_le_degree_of_subset_roots
  intro value hValue
  have hRoot : polynomial.eval value = 0 := (Finset.mem_filter.mp hValue).2
  exact (Polynomial.mem_roots hNonzero).mpr hRoot

theorem sumcheckPolynomialRootsInSupport_card_le_degreeBound
    (support : Finset K)
    {polynomial : Polynomial K}
    {degreeBound : Nat}
    (hNonzero : polynomial ≠ 0)
    (hDegree : polynomial.natDegree ≤ degreeBound) :
    (sumcheckPolynomialRootsInSupport support polynomial).card ≤ degreeBound :=
  le_trans
    (sumcheckPolynomialRootsInSupport_card_le_natDegree support hNonzero)
    hDegree

theorem sumcheck_exists_nonroot_of_support_card_gt_degreeBound
    (support : Finset K)
    {polynomial : Polynomial K}
    {degreeBound : Nat}
    (hNonzero : polynomial ≠ 0)
    (hDegree : polynomial.natDegree ≤ degreeBound)
    (hSupport : degreeBound < support.card) :
    ∃ value ∈ support, polynomial.eval value ≠ 0 := by
  by_contra hNo
  have hAllRoots : ∀ value, value ∈ support → polynomial.eval value = 0 := by
    intro value hValue
    by_contra hEval
    exact hNo ⟨value, hValue, hEval⟩
  have hFilter :
      sumcheckPolynomialRootsInSupport support polynomial = support := by
    ext value
    constructor
    · intro hValue
      exact (Finset.mem_filter.mp hValue).1
    · intro hValue
      exact Finset.mem_filter.mpr ⟨hValue, hAllRoots value hValue⟩
  have hCard : support.card ≤ degreeBound := by
    rw [← hFilter]
    exact sumcheckPolynomialRootsInSupport_card_le_degreeBound
      support hNonzero hDegree
  exact (not_lt_of_ge hCard) hSupport

theorem sumcheckPolynomialAgreementInSupport_card_le_mismatchDegree
    (support : Finset K)
    {prover exact : Polynomial K}
    (hMismatch : prover ≠ exact) :
    (sumcheckPolynomialAgreementInSupport support prover exact).card ≤
      (prover - exact).natDegree := by
  apply sumcheckPolynomialRootsInSupport_card_le_natDegree
  intro hZero
  exact hMismatch (sub_eq_zero.mp hZero)

theorem sumcheckPolynomialAgreementInSupport_card_le_degreeBound
    (support : Finset K)
    {prover exact : Polynomial K}
    {degreeBound : Nat}
    (hMismatch : prover ≠ exact)
    (hProverDegree : prover.natDegree ≤ degreeBound)
    (hExactDegree : exact.natDegree ≤ degreeBound) :
    (sumcheckPolynomialAgreementInSupport support prover exact).card ≤
      degreeBound := by
  refine le_trans
    (sumcheckPolynomialAgreementInSupport_card_le_mismatchDegree
      support hMismatch) ?_
  simpa using
    (Polynomial.natDegree_sub_le_of_le
      (p := prover)
      (q := exact)
      hProverDegree
      hExactDegree)

theorem sumcheck_challenge_in_polynomial_agreement
    (support : Finset K)
    {prover exact : Polynomial K}
    {challenge : K}
    (hChallenge : challenge ∈ support)
    (hEval : prover.eval challenge = exact.eval challenge) :
    challenge ∈ sumcheckPolynomialAgreementInSupport support prover exact := by
  rw [sumcheckPolynomialAgreementInSupport_mem_iff]
  exact ⟨hChallenge, hEval⟩

theorem sumcheck_exists_disagreeing_challenge_of_support_card_gt_degreeBound
    (support : Finset K)
    {prover exact : Polynomial K}
    {degreeBound : Nat}
    (hMismatch : prover ≠ exact)
    (hProverDegree : prover.natDegree ≤ degreeBound)
    (hExactDegree : exact.natDegree ≤ degreeBound)
    (hSupport : degreeBound < support.card) :
    ∃ value ∈ support, prover.eval value ≠ exact.eval value := by
  have hNonzero : prover - exact ≠ 0 := by
    intro hZero
    exact hMismatch (sub_eq_zero.mp hZero)
  have hDegree : (prover - exact).natDegree ≤ degreeBound := by
    simpa using
      (Polynomial.natDegree_sub_le_of_le
        (p := prover)
        (q := exact)
        hProverDegree
        hExactDegree)
  rcases sumcheck_exists_nonroot_of_support_card_gt_degreeBound
      support hNonzero hDegree hSupport with
    ⟨value, hValue, hEval⟩
  refine ⟨value, hValue, ?_⟩
  intro hAgreement
  apply hEval
  simp [Polynomial.eval_sub, hAgreement]

end LowDegreeRootCounting

end SuperNeoFormal
