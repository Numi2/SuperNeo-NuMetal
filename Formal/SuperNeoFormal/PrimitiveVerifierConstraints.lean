import SuperNeoFormal.PiCCS
import SuperNeoFormal.PiRLCSoundness
import SuperNeoFormal.PiDEC
import SuperNeoFormal.CEOpeningRelation
import SuperNeoFormal.Serialization

/-!
Executable primitive verifier constraints.

This file connects the abstract verifier-step predicates to smaller primitive
constraint predicates that can later be lowered into AIR rows.  The residual
surface is deliberately row-indexed: a zero vector/function of residuals can
soundly imply every primitive constraint, while a single scalar batch residual
requires a separate no-cancellation batching theorem.
-/

namespace SuperNeoFormal

open Finset

variable {F : Type} [Semiring F]
variable {RF : Type} [CommRing RF]

abbrev AIRResidual (Row F : Type) :=
  Row → F

def AIRResidualZero {Row F : Type} [Zero F] (residual : AIRResidual Row F) : Prop :=
  ∀ row, residual row = 0

structure PrimitiveVerifierConstraintSystem (Row F : Type) [Zero F] where
  residual : AIRResidual Row F
  primitiveConstraint : Row → Prop
  residual_zero_sound :
    ∀ row, residual row = 0 → primitiveConstraint row

def PrimitiveVerifierConstraintsHold
    {Row F : Type} [Zero F]
    (system : PrimitiveVerifierConstraintSystem Row F) : Prop :=
  ∀ row, system.primitiveConstraint row

theorem airResidual_zero_implies_primitiveVerifierConstraintsHold
    {Row F : Type} [Zero F]
    {system : PrimitiveVerifierConstraintSystem Row F}
    (hResidualZero : AIRResidualZero system.residual) :
    PrimitiveVerifierConstraintsHold system := by
  intro row
  exact system.residual_zero_sound row (hResidualZero row)

structure SharedTerminalVerifierBridge (Row F : Type) [Zero F] where
  system : PrimitiveVerifierConstraintSystem Row F
  sharedTerminalVerifierAccepts : Prop
  constraints_imply_accepts :
    PrimitiveVerifierConstraintsHold system → sharedTerminalVerifierAccepts

theorem primitiveVerifierConstraintsHold_implies_sharedTerminalVerifierAccepts
    {Row F : Type} [Zero F]
    {bridge : SharedTerminalVerifierBridge Row F}
    (hConstraints : PrimitiveVerifierConstraintsHold bridge.system) :
    bridge.sharedTerminalVerifierAccepts :=
  bridge.constraints_imply_accepts hConstraints

theorem airResidual_zero_implies_sharedTerminalVerifierAccepts
    {Row F : Type} [Zero F]
    {bridge : SharedTerminalVerifierBridge Row F}
    (hResidualZero : AIRResidualZero bridge.system.residual) :
    bridge.sharedTerminalVerifierAccepts :=
  bridge.constraints_imply_accepts
    (airResidual_zero_implies_primitiveVerifierConstraintsHold hResidualZero)

structure SourceFreePCSResidualVerifier (Query Row F : Type) where
  queryRow : Query → Row
  openedResidual : Query → F
  airResidual : AIRResidual Row F
  sourceFreePCSVerifierAccepts : Prop
  accepted_openings_match :
    sourceFreePCSVerifierAccepts →
      ∀ query, openedResidual query = airResidual (queryRow query)

def SourceFreePCSQueriedResidualsMatchAIRResidual
    {Query Row F : Type}
    (verifier : SourceFreePCSResidualVerifier Query Row F) : Prop :=
  ∀ query, verifier.openedResidual query = verifier.airResidual (verifier.queryRow query)

theorem sourceFreePCSVerifier_accepts_implies_queriedResiduals_match_AIRResidual
    {Query Row F : Type}
    {verifier : SourceFreePCSResidualVerifier Query Row F}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    SourceFreePCSQueriedResidualsMatchAIRResidual verifier :=
  verifier.accepted_openings_match hAccepts

def PiCCSPrimitiveConstraints
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F) : Prop :=
  trace.rounds = state.numVars ∧
    trace.claimedSum = state.claimedSum ∧
    trace.claimAt 0 = trace.claimedSum ∧
    (∀ round, round < trace.rounds →
      SumcheckRoundConsistent
        (trace.claimAt round)
        (trace.claimAt (round + 1))
        (trace.roundPolynomial round)
        (trace.challenge round)) ∧
    state.finalEvaluation trace.challenge = trace.claimAt trace.rounds ∧
    state.finalClaimsConsistent trace.challenge

theorem piccsPrimitiveConstraints_iff_accepts
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F) :
    PiCCSPrimitiveConstraints state trace ↔ PiCCSAccepts state trace := by
  constructor
  · intro hConstraints
    rcases hConstraints with
      ⟨hRounds, hClaimedSum, hInitial, hRoundsConsistent, hFinalValue,
        hFinalClaims⟩
    exact
      ⟨hRounds, hClaimedSum,
        hInitial, hRoundsConsistent, hFinalValue, hFinalClaims⟩
  · intro hAccepts
    exact
      ⟨piccs_accepts_round_count hAccepts,
        piccs_accepts_claimed_sum hAccepts,
        sumcheck_accepts_initial_claim (piccs_accepts_sumcheck hAccepts),
        fun round hRound =>
          sumcheck_accepts_round_consistency
            (piccs_accepts_sumcheck hAccepts)
            hRound,
        piccs_accepts_final_q_value hAccepts,
        piccs_accepts_final_claim_consistency hAccepts⟩

theorem piccs_accepts_iff_primitiveConstraints
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F) :
    PiCCSAccepts state trace ↔ PiCCSPrimitiveConstraints state trace :=
  (piccsPrimitiveConstraints_iff_accepts state trace).symm

def PiCCSVerifierStep
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F) : Prop :=
  PiCCSAccepts state trace

theorem piccsPrimitiveConstraints_iff_verifierStep
    (state : PiCCSPublicQState F)
    (trace : SumcheckVerifierTrace F) :
    PiCCSPrimitiveConstraints state trace ↔ PiCCSVerifierStep state trace :=
  piccsPrimitiveConstraints_iff_accepts state trace

section PiCCSConcrete

variable {K : Type} [CommRing K]

structure PiCCSAIRResidualValue (K : Type) where
  field : K
  guard : Nat

instance [Zero K] : Zero (PiCCSAIRResidualValue K) :=
  ⟨{ field := 0, guard := 0 }⟩

def PiCCSFieldResidual [Sub K]
    (lhs rhs : K) : PiCCSAIRResidualValue K :=
  { field := lhs - rhs, guard := 0 }

def PiCCSGuardResidual [Zero K]
    (condition : Prop) [Decidable condition] : PiCCSAIRResidualValue K :=
  { field := 0, guard := if condition then 0 else 1 }

theorem piccsFieldResidual_zero_iff
    {lhs rhs : K} :
    PiCCSFieldResidual lhs rhs = 0 ↔ lhs = rhs := by
  constructor
  · intro hZero
    have hField : lhs - rhs = 0 := by
      simpa [PiCCSFieldResidual] using
        congrArg PiCCSAIRResidualValue.field hZero
    exact sub_eq_zero.mp hField
  · intro hEq
    rw [hEq]
    change
      ({ field := rhs - rhs, guard := 0 } : PiCCSAIRResidualValue K) =
        { field := 0, guard := 0 }
    simp

omit [CommRing K] in
theorem piccsGuardResidual_zero_iff [Zero K]
    {condition : Prop} [Decidable condition] :
    PiCCSGuardResidual (K := K) condition = 0 ↔ condition := by
  by_cases hCondition : condition
  · constructor
    · intro _hZero
      exact hCondition
    · intro _hCondition
      unfold PiCCSGuardResidual
      rw [if_pos hCondition]
      change
        ({ field := 0, guard := 0 } : PiCCSAIRResidualValue K) =
          { field := 0, guard := 0 }
      rfl
  · constructor
    · intro hZero
      have hGuard : (1 : Nat) = 0 := by
        simpa [PiCCSGuardResidual, hCondition] using
          congrArg PiCCSAIRResidualValue.guard hZero
      exact False.elim ((Nat.succ_ne_zero 0) hGuard)
    · intro h
      exact False.elim (hCondition h)

structure PiCCSNatEqualityRow where
  observed : Nat
  expected : Nat

def PiCCSNatEqualityRowHolds (row : PiCCSNatEqualityRow) : Prop :=
  row.observed = row.expected

def PiCCSNatEqualityRowResidual [Zero K]
    (row : PiCCSNatEqualityRow) : PiCCSAIRResidualValue K :=
  PiCCSGuardResidual (K := K)
    (condition := row.observed = row.expected)

omit [CommRing K] in
theorem piccsNatEqualityRowResidual_zero_iff [Zero K]
    (row : PiCCSNatEqualityRow) :
    PiCCSNatEqualityRowResidual (K := K) row = 0 ↔
      PiCCSNatEqualityRowHolds row :=
  piccsGuardResidual_zero_iff

structure PiCCSFieldEqualityRow (K : Type) where
  observed : K
  expected : K

def PiCCSFieldEqualityRowHolds
    (row : PiCCSFieldEqualityRow K) : Prop :=
  row.observed = row.expected

def PiCCSFieldEqualityRowResidual
    (row : PiCCSFieldEqualityRow K) : PiCCSAIRResidualValue K :=
  PiCCSFieldResidual row.observed row.expected

theorem piccsFieldEqualityRowResidual_zero_iff
    (row : PiCCSFieldEqualityRow K) :
    PiCCSFieldEqualityRowResidual row = 0 ↔
      PiCCSFieldEqualityRowHolds row :=
  piccsFieldResidual_zero_iff

structure PiCCSGuardRow where
  condition : Prop
  decidableCondition : Decidable condition

def PiCCSGuardRowHolds (row : PiCCSGuardRow) : Prop :=
  row.condition

def PiCCSGuardRowResidual [Zero K]
    (row : PiCCSGuardRow) : PiCCSAIRResidualValue K :=
  letI := row.decidableCondition
  PiCCSGuardResidual (K := K) row.condition

omit [CommRing K] in
theorem piccsGuardRowResidual_zero_iff [Zero K]
    (row : PiCCSGuardRow) :
    PiCCSGuardRowResidual (K := K) row = 0 ↔
      PiCCSGuardRowHolds row := by
  letI := row.decidableCondition
  exact piccsGuardResidual_zero_iff

structure PiCCSConcreteAIRRows (K : Type) [CommRing K] (rounds : Nat) where
  state : PiCCSPublicQState K
  trace : SumcheckVerifierTrace K
  finalClaimsConsistentDecidable :
    Decidable (state.finalClaimsConsistent trace.challenge)

inductive PiCCSConcreteAIRRowIndex (rounds : Nat) where
  | scheduleRoundCount : PiCCSConcreteAIRRowIndex rounds
  | stateRoundCount : PiCCSConcreteAIRRowIndex rounds
  | claimedSum : PiCCSConcreteAIRRowIndex rounds
  | initialClaim : PiCCSConcreteAIRRowIndex rounds
  | roundZeroOneSum : Fin rounds → PiCCSConcreteAIRRowIndex rounds
  | roundNextClaim : Fin rounds → PiCCSConcreteAIRRowIndex rounds
  | finalEvaluation : PiCCSConcreteAIRRowIndex rounds
  | finalClaimConsistency : PiCCSConcreteAIRRowIndex rounds

def PiCCSConcreteAIRRows.scheduleRoundCountRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : PiCCSNatEqualityRow where
  observed := rounds
  expected := air.trace.rounds

def PiCCSConcreteAIRRows.stateRoundCountRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : PiCCSNatEqualityRow where
  observed := air.trace.rounds
  expected := air.state.numVars

def PiCCSConcreteAIRRows.claimedSumRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : PiCCSFieldEqualityRow K where
  observed := air.trace.claimedSum
  expected := air.state.claimedSum

def PiCCSConcreteAIRRows.initialClaimRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : PiCCSFieldEqualityRow K where
  observed := air.trace.claimAt 0
  expected := air.trace.claimedSum

def PiCCSConcreteAIRRows.roundZeroOneSumRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (round : Fin rounds) : PiCCSFieldEqualityRow K where
  observed := air.trace.roundPolynomial round.val 0 +
    air.trace.roundPolynomial round.val 1
  expected := air.trace.claimAt round.val

def PiCCSConcreteAIRRows.roundNextClaimRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (round : Fin rounds) : PiCCSFieldEqualityRow K where
  observed := air.trace.claimAt (round.val + 1)
  expected := air.trace.roundPolynomial round.val
    (air.trace.challenge round.val)

def PiCCSConcreteAIRRows.finalEvaluationRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : PiCCSFieldEqualityRow K where
  observed := air.state.finalEvaluation air.trace.challenge
  expected := air.trace.claimAt air.trace.rounds

def PiCCSConcreteAIRRows.finalClaimConsistencyRow
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : PiCCSGuardRow where
  condition := air.state.finalClaimsConsistent air.trace.challenge
  decidableCondition := air.finalClaimsConsistentDecidable

def PiCCSConcreteAIRRowResidual
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (index : PiCCSConcreteAIRRowIndex rounds) :
    PiCCSAIRResidualValue K :=
  match index with
  | .scheduleRoundCount =>
      PiCCSNatEqualityRowResidual (K := K) air.scheduleRoundCountRow
  | .stateRoundCount =>
      PiCCSNatEqualityRowResidual (K := K) air.stateRoundCountRow
  | .claimedSum =>
      PiCCSFieldEqualityRowResidual air.claimedSumRow
  | .initialClaim =>
      PiCCSFieldEqualityRowResidual air.initialClaimRow
  | .roundZeroOneSum round =>
      PiCCSFieldEqualityRowResidual (air.roundZeroOneSumRow round)
  | .roundNextClaim round =>
      PiCCSFieldEqualityRowResidual (air.roundNextClaimRow round)
  | .finalEvaluation =>
      PiCCSFieldEqualityRowResidual air.finalEvaluationRow
  | .finalClaimConsistency =>
      PiCCSGuardRowResidual (K := K) air.finalClaimConsistencyRow

def PiCCSConcreteAIRRowHolds
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (index : PiCCSConcreteAIRRowIndex rounds) : Prop :=
  match index with
  | .scheduleRoundCount =>
      PiCCSNatEqualityRowHolds air.scheduleRoundCountRow
  | .stateRoundCount =>
      PiCCSNatEqualityRowHolds air.stateRoundCountRow
  | .claimedSum =>
      PiCCSFieldEqualityRowHolds air.claimedSumRow
  | .initialClaim =>
      PiCCSFieldEqualityRowHolds air.initialClaimRow
  | .roundZeroOneSum round =>
      PiCCSFieldEqualityRowHolds (air.roundZeroOneSumRow round)
  | .roundNextClaim round =>
      PiCCSFieldEqualityRowHolds (air.roundNextClaimRow round)
  | .finalEvaluation =>
      PiCCSFieldEqualityRowHolds air.finalEvaluationRow
  | .finalClaimConsistency =>
      PiCCSGuardRowHolds air.finalClaimConsistencyRow

theorem piccsConcreteAIRRowResidual_zero_iff_holds
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (index : PiCCSConcreteAIRRowIndex rounds) :
    PiCCSConcreteAIRRowResidual air index = 0 ↔
      PiCCSConcreteAIRRowHolds air index := by
  cases index with
  | scheduleRoundCount =>
      exact piccsNatEqualityRowResidual_zero_iff (K := K)
        air.scheduleRoundCountRow
  | stateRoundCount =>
      exact piccsNatEqualityRowResidual_zero_iff (K := K)
        air.stateRoundCountRow
  | claimedSum =>
      exact piccsFieldEqualityRowResidual_zero_iff air.claimedSumRow
  | initialClaim =>
      exact piccsFieldEqualityRowResidual_zero_iff air.initialClaimRow
  | roundZeroOneSum round =>
      exact piccsFieldEqualityRowResidual_zero_iff
        (air.roundZeroOneSumRow round)
  | roundNextClaim round =>
      exact piccsFieldEqualityRowResidual_zero_iff
        (air.roundNextClaimRow round)
  | finalEvaluation =>
      exact piccsFieldEqualityRowResidual_zero_iff air.finalEvaluationRow
  | finalClaimConsistency =>
      exact piccsGuardRowResidual_zero_iff (K := K)
        air.finalClaimConsistencyRow

def PiCCSConcreteAIRAllRowsZero
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : Prop :=
  ∀ index, PiCCSConcreteAIRRowResidual air index = 0

def PiCCSConcreteAIRAllRowsHold
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : Prop :=
  ∀ index, PiCCSConcreteAIRRowHolds air index

theorem piccsConcreteAIR_allRowsZero_iff_allRowsHold
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) :
    PiCCSConcreteAIRAllRowsZero air ↔ PiCCSConcreteAIRAllRowsHold air := by
  constructor
  · intro hZero index
    exact (piccsConcreteAIRRowResidual_zero_iff_holds air index).mp
      (hZero index)
  · intro hHold index
    exact (piccsConcreteAIRRowResidual_zero_iff_holds air index).mpr
      (hHold index)

def PiCCSConcreteVerifierStep
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) : Prop :=
  PiCCSVerifierStep air.state air.trace ∧ rounds = air.trace.rounds

theorem piccsConcreteAIR_allRowsZero_iff_verifierStep
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds) :
    PiCCSConcreteAIRAllRowsZero air ↔
      PiCCSConcreteVerifierStep air := by
  constructor
  · intro hZero
    have hHold : PiCCSConcreteAIRAllRowsHold air :=
      (piccsConcreteAIR_allRowsZero_iff_allRowsHold air).mp hZero
    have hScheduleRounds : rounds = air.trace.rounds :=
      hHold .scheduleRoundCount
    have hStateRounds : air.trace.rounds = air.state.numVars :=
      hHold .stateRoundCount
    have hClaimedSum : air.trace.claimedSum = air.state.claimedSum :=
      hHold .claimedSum
    have hInitial : air.trace.claimAt 0 = air.trace.claimedSum :=
      hHold .initialClaim
    have hRounds :
        ∀ round, round < air.trace.rounds →
          SumcheckRoundConsistent
            (air.trace.claimAt round)
            (air.trace.claimAt (round + 1))
            (air.trace.roundPolynomial round)
            (air.trace.challenge round) := by
      intro round hRound
      have hScheduledRound : round < rounds := by
        rw [hScheduleRounds]
        exact hRound
      let scheduledRound : Fin rounds := ⟨round, hScheduledRound⟩
      exact
        ⟨hHold (.roundZeroOneSum scheduledRound),
          hHold (.roundNextClaim scheduledRound)⟩
    have hFinalEvaluation :
        air.state.finalEvaluation air.trace.challenge =
          air.trace.claimAt air.trace.rounds :=
      hHold .finalEvaluation
    have hFinalConsistency :
        air.state.finalClaimsConsistent air.trace.challenge :=
      hHold .finalClaimConsistency
    exact
      ⟨⟨hStateRounds, hClaimedSum,
          hInitial, hRounds, hFinalEvaluation, hFinalConsistency⟩,
        hScheduleRounds⟩
  · intro hVerifier
    rcases hVerifier with ⟨hAccepts, hScheduleRounds⟩
    refine (piccsConcreteAIR_allRowsZero_iff_allRowsHold air).mpr ?_
    intro index
    cases index with
    | scheduleRoundCount =>
        exact hScheduleRounds
    | stateRoundCount =>
        exact piccs_accepts_round_count hAccepts
    | claimedSum =>
        exact piccs_accepts_claimed_sum hAccepts
    | initialClaim =>
        exact sumcheck_accepts_initial_claim
          (piccs_accepts_sumcheck hAccepts)
    | roundZeroOneSum round =>
        have hRoundTrace : round.val < air.trace.rounds := by
          rw [← hScheduleRounds]
          exact round.isLt
        exact sumcheck_accepts_round_zero_one_sum
          (piccs_accepts_sumcheck hAccepts) hRoundTrace
    | roundNextClaim round =>
        have hRoundTrace : round.val < air.trace.rounds := by
          rw [← hScheduleRounds]
          exact round.isLt
        exact sumcheck_accepts_next_claim
          (piccs_accepts_sumcheck hAccepts) hRoundTrace
    | finalEvaluation =>
        exact piccs_accepts_final_q_value hAccepts
    | finalClaimConsistency =>
        exact piccs_accepts_final_claim_consistency hAccepts

theorem piccsConcreteAIR_allRowsZero_implies_primitiveConstraints
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (hZero : PiCCSConcreteAIRAllRowsZero air) :
    PiCCSPrimitiveConstraints air.state air.trace := by
  have hVerifier :
      PiCCSConcreteVerifierStep air :=
    (piccsConcreteAIR_allRowsZero_iff_verifierStep air).mp hZero
  exact
    (piccsPrimitiveConstraints_iff_verifierStep
      air.state air.trace).mpr hVerifier.1

end PiCCSConcrete

def PiRLCPrimitiveConstraints
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector RF pointVars)
    (challenges : Fin count → RF)
    (claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars)
    (folded : EvaluationClaim RF rows publicCount evalCount pointVars) : Prop :=
  folded.commitment =
      rlcWeightedCommitment challenges (fun index => (claims index).commitment) ∧
    folded.publicInput =
      rlcWeightedVector challenges (fun index => (claims index).publicInput) ∧
    folded.point = point ∧
    folded.evaluations =
      rlcWeightedVector challenges (fun index => (claims index).evaluations) ∧
    ∀ index, (claims index).point = point

omit [CommRing RF] in
theorem pirlcEvaluationClaim_ext
    {rows publicCount evalCount pointVars : Nat}
    {lhs rhs : EvaluationClaim RF rows publicCount evalCount pointVars}
    (hCommitment : lhs.commitment = rhs.commitment)
    (hPublicInput : lhs.publicInput = rhs.publicInput)
    (hPoint : lhs.point = rhs.point)
    (hEvaluations : lhs.evaluations = rhs.evaluations) :
    lhs = rhs := by
  cases lhs
  cases rhs
  simp at hCommitment hPublicInput hPoint hEvaluations ⊢
  exact ⟨hCommitment, hPublicInput, hPoint, hEvaluations⟩

theorem pirlcPrimitiveConstraints_iff_publiclyConsistent
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector RF pointVars)
    (challenges : Fin count → RF)
    (claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars)
    (folded : EvaluationClaim RF rows publicCount evalCount pointVars) :
    PiRLCPrimitiveConstraints point challenges claims folded ↔
      RLCClaimPubliclyConsistent point challenges claims folded := by
  constructor
  · intro hConstraints
    rcases hConstraints with
      ⟨hCommitment, hPublicInput, hPoint, hEvaluations, hParentPoints⟩
    constructor
    · cases folded
      simp only at hCommitment hPublicInput hPoint hEvaluations
      rw [hCommitment, hPublicInput, hPoint, hEvaluations]
      rfl
    · exact hParentPoints
  · intro hConsistent
    rcases hConsistent with ⟨hFolded, hParentPoints⟩
    subst folded
    exact ⟨rfl, rfl, rfl, rfl, hParentPoints⟩

def PiRLCVerifierStep
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector RF pointVars)
    (challenges : Fin count → RF)
    (claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars)
    (folded : EvaluationClaim RF rows publicCount evalCount pointVars) : Prop :=
  RLCClaimPubliclyConsistent point challenges claims folded

theorem pirlcPrimitiveConstraints_iff_verifierStep
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector RF pointVars)
    (challenges : Fin count → RF)
    (claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars)
    (folded : EvaluationClaim RF rows publicCount evalCount pointVars) :
    PiRLCPrimitiveConstraints point challenges claims folded ↔
      PiRLCVerifierStep point challenges claims folded :=
  pirlcPrimitiveConstraints_iff_publiclyConsistent point challenges claims folded

theorem pirlcConcreteAccepts_iff_primitiveConstraints
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (seed : PiRLCChallengeSeed count)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars) :
    PiRLCConcreteAccepts point seed claims folded ↔
      PiRLCPrimitiveConstraints point (pirlcChallengeElements seed) claims folded := by
  rw [pirlcConcreteAccepts_iff_publiclyConsistent,
    pirlcPrimitiveConstraints_iff_publiclyConsistent]

structure PiRLCAIRResidualValue (RF : Type) where
  field : RF
  guard : Nat

instance [Zero RF] : Zero (PiRLCAIRResidualValue RF) :=
  ⟨{ field := 0, guard := 0 }⟩

def PiRLCFieldResidual [Sub RF]
    (lhs rhs : RF) : PiRLCAIRResidualValue RF :=
  { field := lhs - rhs, guard := 0 }

def PiRLCGuardResidual [Zero RF]
    (condition : Prop) [Decidable condition] : PiRLCAIRResidualValue RF :=
  { field := 0, guard := if condition then 0 else 1 }

omit [CommRing RF] in
theorem pirlcFieldResidual_zero_iff [CommRing RF]
    {lhs rhs : RF} :
    PiRLCFieldResidual lhs rhs = 0 ↔ lhs = rhs := by
  constructor
  · intro hZero
    have hField : lhs - rhs = 0 := by
      simpa [PiRLCFieldResidual] using
        congrArg PiRLCAIRResidualValue.field hZero
    exact sub_eq_zero.mp hField
  · intro hEq
    rw [hEq]
    change ({ field := rhs - rhs, guard := 0 } : PiRLCAIRResidualValue RF) =
      { field := 0, guard := 0 }
    simp

omit [CommRing RF] in
theorem pirlcGuardResidual_zero_iff [Zero RF]
    {condition : Prop} [Decidable condition] :
    PiRLCGuardResidual (RF := RF) condition = 0 ↔ condition := by
  by_cases hCondition : condition
  · constructor
    · intro _hZero
      exact hCondition
    · intro _hCondition
      unfold PiRLCGuardResidual
      rw [if_pos hCondition]
      change
        ({ field := 0, guard := 0 } : PiRLCAIRResidualValue RF) =
          { field := 0, guard := 0 }
      rfl
  · constructor
    · intro hZero
      have hGuard : (1 : Nat) = 0 := by
        simpa [PiRLCGuardResidual, hCondition] using
          congrArg PiRLCAIRResidualValue.guard hZero
      exact False.elim ((Nat.succ_ne_zero 0) hGuard)
    · intro h
      exact False.elim (hCondition h)

structure PiRLCChallengeBindingRow (RF : Type) where
  derivedChallenge : RF
  boundChallenge : RF
  index : Nat
  publicCoinContext : Digest256Wire

def PiRLCChallengeBindingRowHolds
    (row : PiRLCChallengeBindingRow RF) : Prop :=
  row.derivedChallenge = row.boundChallenge

def PiRLCChallengeBindingRowResidual [CommRing RF]
    (row : PiRLCChallengeBindingRow RF) : PiRLCAIRResidualValue RF :=
  PiRLCFieldResidual row.derivedChallenge row.boundChallenge

omit [CommRing RF] in
theorem pirlcChallengeBindingRowResidual_zero_iff [CommRing RF]
    (row : PiRLCChallengeBindingRow RF) :
    PiRLCChallengeBindingRowResidual row = 0 ↔
      PiRLCChallengeBindingRowHolds row :=
  pirlcFieldResidual_zero_iff

structure PiRLCChallengeBindingSoundnessRow (RF : Type) where
  derivedChallenge : RF
  boundChallenge : RF
  usedChallenge : RF
  observedIndex : Nat
  expectedIndex : Nat
  publicCoinContext : Digest256Wire
  expectedPublicCoinContext : Digest256Wire
  soundnessConditionDecidable :
    Decidable
      (derivedChallenge = usedChallenge ∧
        boundChallenge = usedChallenge ∧
        observedIndex = expectedIndex ∧
        publicCoinContext = expectedPublicCoinContext)

def PiRLCChallengeBindingSoundnessRowCondition
    (row : PiRLCChallengeBindingSoundnessRow RF) : Prop :=
  row.derivedChallenge = row.usedChallenge ∧
    row.boundChallenge = row.usedChallenge ∧
    row.observedIndex = row.expectedIndex ∧
    row.publicCoinContext = row.expectedPublicCoinContext

def PiRLCChallengeBindingSoundnessRowHolds
    (row : PiRLCChallengeBindingSoundnessRow RF) : Prop :=
  row.derivedChallenge = row.boundChallenge ∧
    PiRLCChallengeBindingSoundnessRowCondition row

def PiRLCChallengeBindingSoundnessRowResidual [CommRing RF]
    (row : PiRLCChallengeBindingSoundnessRow RF) :
    PiRLCAIRResidualValue RF :=
  let condition :=
    row.derivedChallenge = row.usedChallenge ∧
      row.boundChallenge = row.usedChallenge ∧
      row.observedIndex = row.expectedIndex ∧
      row.publicCoinContext = row.expectedPublicCoinContext
  letI := row.soundnessConditionDecidable
  { field := row.derivedChallenge - row.boundChallenge,
    guard := if condition then 0 else 1 }

omit [CommRing RF] in
theorem pirlcChallengeBindingSoundnessRowResidual_zero_iff [CommRing RF]
    (row : PiRLCChallengeBindingSoundnessRow RF) :
    PiRLCChallengeBindingSoundnessRowResidual row = 0 ↔
      PiRLCChallengeBindingSoundnessRowHolds row := by
  let condition :=
    row.derivedChallenge = row.usedChallenge ∧
      row.boundChallenge = row.usedChallenge ∧
      row.observedIndex = row.expectedIndex ∧
      row.publicCoinContext = row.expectedPublicCoinContext
  letI := row.soundnessConditionDecidable
  constructor
  · intro hZero
    have hField : row.derivedChallenge - row.boundChallenge = 0 := by
      simpa [PiRLCChallengeBindingSoundnessRowResidual, condition] using
        congrArg PiRLCAIRResidualValue.field hZero
    have hDerivedBound :
        row.derivedChallenge = row.boundChallenge := sub_eq_zero.mp hField
    have hGuard :
        (if condition then 0 else 1) = 0 := by
      have hGuardRaw := congrArg PiRLCAIRResidualValue.guard hZero
      change (if condition then 0 else 1) = 0 at hGuardRaw
      exact hGuardRaw
    have hCondition : condition := by
      by_cases hCondition : condition
      · exact hCondition
      · have hImpossible : (1 : Nat) = 0 := by
          simp [hCondition] at hGuard
        exact False.elim ((Nat.succ_ne_zero 0) hImpossible)
    exact ⟨hDerivedBound, hCondition⟩
  · intro hHolds
    rcases hHolds with ⟨hDerivedBound, hCondition⟩
    have hConditionExpanded : condition := by
      simpa [condition, PiRLCChallengeBindingSoundnessRowCondition] using
        hCondition
    simp [PiRLCChallengeBindingSoundnessRowResidual, condition,
      hConditionExpanded]
    rfl

omit [CommRing RF] in
theorem pirlcChallengeBindingSoundness_rejects_unrelated_self_consistent_row
    {used derived : RF}
    {observedIndex expectedIndex : Nat}
    {publicCoinContext expectedPublicCoinContext : Digest256Wire}
    (hMismatch : derived ≠ used) :
    ¬ PiRLCChallengeBindingSoundnessRowHolds
      ({
        derivedChallenge := derived,
        boundChallenge := derived,
        usedChallenge := used,
        observedIndex := observedIndex,
        expectedIndex := expectedIndex,
        publicCoinContext := publicCoinContext,
        expectedPublicCoinContext := expectedPublicCoinContext,
        soundnessConditionDecidable := by classical exact inferInstance
      } : PiRLCChallengeBindingSoundnessRow RF) := by
  intro hHolds
  exact hMismatch hHolds.2.1

structure PiRLCPointEqualityRow (RF : Type) where
  observedPoint : RF
  expectedPoint : RF

def PiRLCPointEqualityRowHolds
    (row : PiRLCPointEqualityRow RF) : Prop :=
  row.observedPoint = row.expectedPoint

def PiRLCPointEqualityRowResidual [CommRing RF]
    (row : PiRLCPointEqualityRow RF) : PiRLCAIRResidualValue RF :=
  PiRLCFieldResidual row.observedPoint row.expectedPoint

omit [CommRing RF] in
theorem pirlcPointEqualityRowResidual_zero_iff [CommRing RF]
    (row : PiRLCPointEqualityRow RF) :
    PiRLCPointEqualityRowResidual row = 0 ↔
      PiRLCPointEqualityRowHolds row :=
  pirlcFieldResidual_zero_iff

structure PiRLCLinearCombinationRow (RF : Type) (count : Nat) where
  target : RF
  challenges : Fin count → RF
  parts : Fin count → RF

def PiRLCLinearCombinationRowHolds [CommRing RF]
    {count : Nat}
    (row : PiRLCLinearCombinationRow RF count) : Prop :=
  row.target = rlcWeightedSum row.challenges row.parts

def PiRLCLinearCombinationRowResidual [CommRing RF]
    {count : Nat}
    (row : PiRLCLinearCombinationRow RF count) : PiRLCAIRResidualValue RF :=
  PiRLCFieldResidual row.target (rlcWeightedSum row.challenges row.parts)

omit [CommRing RF] in
theorem pirlcLinearCombinationRowResidual_zero_iff [CommRing RF]
    {count : Nat}
    (row : PiRLCLinearCombinationRow RF count) :
    PiRLCLinearCombinationRowResidual row = 0 ↔
      PiRLCLinearCombinationRowHolds row :=
  pirlcFieldResidual_zero_iff

structure PiRLCConcreteAIRRows
    (RF : Type) [CommRing RF]
    (count rows publicCount evalCount pointVars : Nat) where
  point : ProtocolVector RF pointVars
  challenges : Fin count → RF
  claims : Fin count → EvaluationClaim RF rows publicCount evalCount pointVars
  folded : EvaluationClaim RF rows publicCount evalCount pointVars
  publicCoinContext : Digest256Wire
  challengeBindingRow : Fin count → PiRLCChallengeBindingRow RF
  challengeBindingSoundnessDecidable :
    ∀ index : Fin count,
      Decidable
        ((challengeBindingRow index).derivedChallenge = challenges index ∧
          (challengeBindingRow index).boundChallenge = challenges index ∧
          (challengeBindingRow index).index = index.val ∧
          (challengeBindingRow index).publicCoinContext = publicCoinContext)

inductive PiRLCConcreteAIRRowIndex
    (count rows publicCount evalCount pointVars : Nat) where
  | challengeBinding :
      Fin count →
        PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars
  | foldedPoint :
      Fin pointVars →
        PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars
  | parentPoint :
      Fin count →
        Fin pointVars →
          PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars
  | commitmentCombination :
      Fin rows →
        PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars
  | publicInputCombination :
      Fin publicCount →
        PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars
  | evaluationCombination :
      Fin evalCount →
        PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars

def PiRLCConcreteAIRRows.foldedPointRow
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (coordinate : Fin pointVars) : PiRLCPointEqualityRow RF where
  observedPoint := air.folded.point coordinate
  expectedPoint := air.point coordinate

def PiRLCConcreteAIRRows.parentPointRow
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (claimIndex : Fin count)
    (coordinate : Fin pointVars) : PiRLCPointEqualityRow RF where
  observedPoint := (air.claims claimIndex).point coordinate
  expectedPoint := air.point coordinate

def PiRLCConcreteAIRRows.commitmentCombinationRow
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (row : Fin rows) : PiRLCLinearCombinationRow RF count where
  target := air.folded.commitment row
  challenges := air.challenges
  parts := fun index => (air.claims index).commitment row

def PiRLCConcreteAIRRows.publicInputCombinationRow
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (coordinate : Fin publicCount) : PiRLCLinearCombinationRow RF count where
  target := air.folded.publicInput coordinate
  challenges := air.challenges
  parts := fun index => (air.claims index).publicInput coordinate

def PiRLCConcreteAIRRows.evaluationCombinationRow
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (coordinate : Fin evalCount) : PiRLCLinearCombinationRow RF count where
  target := air.folded.evaluations coordinate
  challenges := air.challenges
  parts := fun index => (air.claims index).evaluations coordinate

def PiRLCConcreteAIRRows.challengeBindingSoundnessRow
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index : Fin count) : PiRLCChallengeBindingSoundnessRow RF where
  derivedChallenge := (air.challengeBindingRow index).derivedChallenge
  boundChallenge := (air.challengeBindingRow index).boundChallenge
  usedChallenge := air.challenges index
  observedIndex := (air.challengeBindingRow index).index
  expectedIndex := index.val
  publicCoinContext := (air.challengeBindingRow index).publicCoinContext
  expectedPublicCoinContext := air.publicCoinContext
  soundnessConditionDecidable := air.challengeBindingSoundnessDecidable index

def PiRLCConcreteAIRRowResidual
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    PiRLCAIRResidualValue RF :=
  match index with
  | .challengeBinding row =>
      PiRLCChallengeBindingSoundnessRowResidual
        (air.challengeBindingSoundnessRow row)
  | .foldedPoint coordinate =>
      PiRLCPointEqualityRowResidual (air.foldedPointRow coordinate)
  | .parentPoint claimIndex coordinate =>
      PiRLCPointEqualityRowResidual
        (air.parentPointRow claimIndex coordinate)
  | .commitmentCombination row =>
      PiRLCLinearCombinationRowResidual
        (air.commitmentCombinationRow row)
  | .publicInputCombination coordinate =>
      PiRLCLinearCombinationRowResidual
        (air.publicInputCombinationRow coordinate)
  | .evaluationCombination coordinate =>
      PiRLCLinearCombinationRowResidual
        (air.evaluationCombinationRow coordinate)

def PiRLCConcreteAIRRowHolds
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    Prop :=
  match index with
  | .challengeBinding row =>
      PiRLCChallengeBindingSoundnessRowHolds
        (air.challengeBindingSoundnessRow row)
  | .foldedPoint coordinate =>
      PiRLCPointEqualityRowHolds (air.foldedPointRow coordinate)
  | .parentPoint claimIndex coordinate =>
      PiRLCPointEqualityRowHolds
        (air.parentPointRow claimIndex coordinate)
  | .commitmentCombination row =>
      PiRLCLinearCombinationRowHolds
        (air.commitmentCombinationRow row)
  | .publicInputCombination coordinate =>
      PiRLCLinearCombinationRowHolds
        (air.publicInputCombinationRow coordinate)
  | .evaluationCombination coordinate =>
      PiRLCLinearCombinationRowHolds
        (air.evaluationCombinationRow coordinate)

theorem pirlcConcreteAIRRowResidual_zero_iff_holds
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    PiRLCConcreteAIRRowResidual air index = 0 ↔
      PiRLCConcreteAIRRowHolds air index := by
  cases index with
  | challengeBinding row =>
      exact pirlcChallengeBindingSoundnessRowResidual_zero_iff
        (air.challengeBindingSoundnessRow row)
  | foldedPoint coordinate =>
      exact pirlcPointEqualityRowResidual_zero_iff
        (air.foldedPointRow coordinate)
  | parentPoint claimIndex coordinate =>
      exact pirlcPointEqualityRowResidual_zero_iff
        (air.parentPointRow claimIndex coordinate)
  | commitmentCombination row =>
      exact pirlcLinearCombinationRowResidual_zero_iff
        (air.commitmentCombinationRow row)
  | publicInputCombination coordinate =>
      exact pirlcLinearCombinationRowResidual_zero_iff
        (air.publicInputCombinationRow coordinate)
  | evaluationCombination coordinate =>
      exact pirlcLinearCombinationRowResidual_zero_iff
        (air.evaluationCombinationRow coordinate)

def PiRLCConcreteAIRAllRowsZero
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) : Prop :=
  ∀ index, PiRLCConcreteAIRRowResidual air index = 0

def PiRLCConcreteAIRAllRowsHold
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) : Prop :=
  ∀ index, PiRLCConcreteAIRRowHolds air index

theorem pirlcConcreteAIR_allRowsZero_iff_allRowsHold
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) :
    PiRLCConcreteAIRAllRowsZero air ↔ PiRLCConcreteAIRAllRowsHold air := by
  constructor
  · intro hZero index
    exact (pirlcConcreteAIRRowResidual_zero_iff_holds air index).mp
      (hZero index)
  · intro hHold index
    exact (pirlcConcreteAIRRowResidual_zero_iff_holds air index).mpr
      (hHold index)

def PiRLCConcreteSideRowsHold
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) : Prop :=
  ∀ index, PiRLCChallengeBindingSoundnessRowHolds
    (air.challengeBindingSoundnessRow index)

def PiRLCChallengeBindingRowsMatchUsedChallenges
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) : Prop :=
  ∀ index, PiRLCChallengeBindingSoundnessRowHolds
    (air.challengeBindingSoundnessRow index)

def PiRLCConcreteAIRRowsChallengeBindingSound
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) : Prop :=
  PiRLCChallengeBindingRowsMatchUsedChallenges air

def PiRLCConcreteVerifierStep
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) : Prop :=
  PiRLCVerifierStep air.point air.challenges air.claims air.folded ∧
    PiRLCConcreteSideRowsHold air

theorem pirlcConcreteAIR_allRowsZero_iff_verifierStep
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars) :
    PiRLCConcreteAIRAllRowsZero air ↔
      PiRLCConcreteVerifierStep air := by
  constructor
  · intro hZero
    have hHold : PiRLCConcreteAIRAllRowsHold air :=
      (pirlcConcreteAIR_allRowsZero_iff_allRowsHold air).mp hZero
    have hCommitment :
        air.folded.commitment =
          rlcWeightedCommitment air.challenges
            (fun index => (air.claims index).commitment) := by
      funext row
      exact hHold (.commitmentCombination row)
    have hPublicInput :
        air.folded.publicInput =
          rlcWeightedVector air.challenges
            (fun index => (air.claims index).publicInput) := by
      funext coordinate
      exact hHold (.publicInputCombination coordinate)
    have hFoldedPoint : air.folded.point = air.point := by
      funext coordinate
      exact hHold (.foldedPoint coordinate)
    have hEvaluations :
        air.folded.evaluations =
          rlcWeightedVector air.challenges
            (fun index => (air.claims index).evaluations) := by
      funext coordinate
      exact hHold (.evaluationCombination coordinate)
    have hFolded :
        air.folded = rlcWeightedClaim air.point air.challenges air.claims := by
      exact pirlcEvaluationClaim_ext
        hCommitment
        hPublicInput
        hFoldedPoint
        hEvaluations
    have hParentPoints : ∀ index, (air.claims index).point = air.point := by
      intro claimIndex
      funext coordinate
      exact hHold (.parentPoint claimIndex coordinate)
    exact ⟨⟨hFolded, hParentPoints⟩,
      fun index => hHold (.challengeBinding index)⟩
  · intro hVerifier
    rcases hVerifier with ⟨hStep, hChallengeBindings⟩
    have hPrimitive :
        PiRLCPrimitiveConstraints
          air.point air.challenges air.claims air.folded :=
      (pirlcPrimitiveConstraints_iff_verifierStep
        air.point air.challenges air.claims air.folded).mpr hStep
    rcases hPrimitive with
      ⟨hCommitment, hPublicInput, hFoldedPoint, hEvaluations, hParentPoints⟩
    refine (pirlcConcreteAIR_allRowsZero_iff_allRowsHold air).mpr ?_
    intro index
    cases index with
    | challengeBinding row =>
        exact hChallengeBindings row
    | foldedPoint coordinate =>
        exact congrFun hFoldedPoint coordinate
    | parentPoint claimIndex coordinate =>
        exact congrFun (hParentPoints claimIndex) coordinate
    | commitmentCombination row =>
        exact congrFun hCommitment row
    | publicInputCombination coordinate =>
        exact congrFun hPublicInput coordinate
    | evaluationCombination coordinate =>
        exact congrFun hEvaluations coordinate

theorem pirlcConcreteAIR_allRowsZero_implies_primitiveConstraints
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (hZero : PiRLCConcreteAIRAllRowsZero air) :
    PiRLCPrimitiveConstraints
      air.point air.challenges air.claims air.folded := by
  have hVerifier :
      PiRLCConcreteVerifierStep air :=
    (pirlcConcreteAIR_allRowsZero_iff_verifierStep air).mp hZero
  exact
    (pirlcPrimitiveConstraints_iff_verifierStep
      air.point air.challenges air.claims air.folded).mpr hVerifier.1

def PiDECVerifierStep
    {rows columns count : Nat}
    (A : AjtaiMatrix RF rows columns)
    (base : RF)
    (limbs : Fin count → Message RF columns)
    (folded : Message RF columns)
    (foldedCommitment : Commitment RF rows) : Prop :=
  folded = pidecWeightedMessage base limbs ∧
    foldedCommitment =
      pidecWeightedCommitment base (fun index => commit A (limbs index))

def PiDECPrimitiveConstraints
    {rows columns count : Nat}
    (A : AjtaiMatrix RF rows columns)
    (base : RF)
    (limbs : Fin count → Message RF columns)
    (folded : Message RF columns)
    (foldedCommitment : Commitment RF rows) : Prop :=
  folded = pidecWeightedMessage base limbs ∧
    foldedCommitment = commit A folded ∧
    foldedCommitment =
      pidecWeightedCommitment base (fun index => commit A (limbs index))

theorem pidecPrimitiveConstraints_iff_verifierStep
    {rows columns count : Nat}
    (A : AjtaiMatrix RF rows columns)
    (base : RF)
    (limbs : Fin count → Message RF columns)
    (folded : Message RF columns)
    (foldedCommitment : Commitment RF rows) :
    PiDECPrimitiveConstraints A base limbs folded foldedCommitment ↔
      PiDECVerifierStep A base limbs folded foldedCommitment := by
  constructor
  · intro hConstraints
    exact ⟨hConstraints.1, hConstraints.2.2⟩
  · intro hStep
    rcases hStep with ⟨hFolded, hCommitment⟩
    refine ⟨hFolded, ?_, hCommitment⟩
    rw [hCommitment, hFolded]
    exact (commit_pidecWeightedMessage A base limbs).symm

theorem pidecVerifierStep_iff_primitiveConstraints
    {rows columns count : Nat}
    (A : AjtaiMatrix RF rows columns)
    (base : RF)
    (limbs : Fin count → Message RF columns)
    (folded : Message RF columns)
    (foldedCommitment : Commitment RF rows) :
    PiDECVerifierStep A base limbs folded foldedCommitment ↔
      PiDECPrimitiveConstraints A base limbs folded foldedCommitment :=
  (pidecPrimitiveConstraints_iff_verifierStep
    A base limbs folded foldedCommitment).symm

structure PiDECAIRResidualValue (RF : Type) where
  field : RF
  guard : Nat

instance [Zero RF] : Zero (PiDECAIRResidualValue RF) :=
  ⟨{ field := 0, guard := 0 }⟩

def PiDECFieldResidual [Sub RF]
    (lhs rhs : RF) : PiDECAIRResidualValue RF :=
  { field := lhs - rhs, guard := 0 }

def PiDECGuardResidual [Zero RF]
    (condition : Prop) [Decidable condition] : PiDECAIRResidualValue RF :=
  { field := 0, guard := if condition then 0 else 1 }

omit [CommRing RF] in
theorem pidecFieldResidual_zero_iff [CommRing RF]
    {lhs rhs : RF} :
    PiDECFieldResidual lhs rhs = 0 ↔ lhs = rhs := by
  constructor
  · intro hZero
    have hField : lhs - rhs = 0 := by
      simpa [PiDECFieldResidual] using
        congrArg PiDECAIRResidualValue.field hZero
    exact sub_eq_zero.mp hField
  · intro hEq
    rw [hEq]
    change
      ({ field := rhs - rhs, guard := 0 } : PiDECAIRResidualValue RF) =
        { field := 0, guard := 0 }
    simp

omit [CommRing RF] in
theorem pidecGuardResidual_zero_iff [Zero RF]
    {condition : Prop} [Decidable condition] :
    PiDECGuardResidual (RF := RF) condition = 0 ↔ condition := by
  by_cases hCondition : condition
  · constructor
    · intro _hZero
      exact hCondition
    · intro _hCondition
      unfold PiDECGuardResidual
      rw [if_pos hCondition]
      change
        ({ field := 0, guard := 0 } : PiDECAIRResidualValue RF) =
          { field := 0, guard := 0 }
      rfl
  · constructor
    · intro hZero
      have hGuard : (1 : Nat) = 0 := by
        simpa [PiDECGuardResidual, hCondition] using
          congrArg PiDECAIRResidualValue.guard hZero
      exact False.elim ((Nat.succ_ne_zero 0) hGuard)
    · intro h
      exact False.elim (hCondition h)

structure PiDECSignedDigitBoundRow where
  digit : Int
  bound : Nat

def PiDECSignedDigitBoundRowHolds
    (row : PiDECSignedDigitBoundRow) : Prop :=
  row.digit.natAbs ≤ row.bound

def PiDECSignedDigitBoundRowResidual [Zero RF]
    (row : PiDECSignedDigitBoundRow) : PiDECAIRResidualValue RF :=
  PiDECGuardResidual (RF := RF)
    (condition := row.digit.natAbs ≤ row.bound)

omit [CommRing RF] in
theorem pidecSignedDigitBoundRowResidual_zero_iff [Zero RF]
    (row : PiDECSignedDigitBoundRow) :
    PiDECSignedDigitBoundRowResidual (RF := RF) row = 0 ↔
      PiDECSignedDigitBoundRowHolds row :=
  pidecGuardResidual_zero_iff

structure PiDECBaseBDecompositionRow (RF : Type) (count : Nat) where
  value : RF
  base : RF
  digits : Fin count → RF

def PiDECBaseBDecompositionRowHolds [CommRing RF]
    {count : Nat}
    (row : PiDECBaseBDecompositionRow RF count) : Prop :=
  row.value = pidecWeightedSum row.base row.digits

def PiDECBaseBDecompositionRowResidual [CommRing RF]
    {count : Nat}
    (row : PiDECBaseBDecompositionRow RF count) : PiDECAIRResidualValue RF :=
  PiDECFieldResidual row.value (pidecWeightedSum row.base row.digits)

omit [CommRing RF] in
theorem pidecBaseBDecompositionRowResidual_zero_iff [CommRing RF]
    {count : Nat}
    (row : PiDECBaseBDecompositionRow RF count) :
    PiDECBaseBDecompositionRowResidual row = 0 ↔
      PiDECBaseBDecompositionRowHolds row :=
  pidecFieldResidual_zero_iff

structure PiDECRecompositionRow (RF : Type) (count : Nat) where
  target : RF
  base : RF
  parts : Fin count → RF

def PiDECRecompositionRowHolds [CommRing RF]
    {count : Nat}
    (row : PiDECRecompositionRow RF count) : Prop :=
  row.target = pidecWeightedSum row.base row.parts

def PiDECRecompositionRowResidual [CommRing RF]
    {count : Nat}
    (row : PiDECRecompositionRow RF count) : PiDECAIRResidualValue RF :=
  PiDECFieldResidual row.target (pidecWeightedSum row.base row.parts)

omit [CommRing RF] in
theorem pidecRecompositionRowResidual_zero_iff [CommRing RF]
    {count : Nat}
    (row : PiDECRecompositionRow RF count) :
    PiDECRecompositionRowResidual row = 0 ↔
      PiDECRecompositionRowHolds row :=
  pidecFieldResidual_zero_iff

structure PiDECCommitmentEvaluationRow (RF : Type) (columns : Nat) where
  target : RF
  matrixRow : Fin columns → RF
  witness : Message RF columns

def PiDECCommitmentEvaluationRowHolds [CommRing RF]
    {columns : Nat}
    (row : PiDECCommitmentEvaluationRow RF columns) : Prop :=
  row.target = ∑ column : Fin columns, row.matrixRow column * row.witness column

def PiDECCommitmentEvaluationRowResidual [CommRing RF]
    {columns : Nat}
    (row : PiDECCommitmentEvaluationRow RF columns) :
    PiDECAIRResidualValue RF :=
  PiDECFieldResidual row.target
    (∑ column : Fin columns, row.matrixRow column * row.witness column)

omit [CommRing RF] in
theorem pidecCommitmentEvaluationRowResidual_zero_iff [CommRing RF]
    {columns : Nat}
    (row : PiDECCommitmentEvaluationRow RF columns) :
    PiDECCommitmentEvaluationRowResidual row = 0 ↔
      PiDECCommitmentEvaluationRowHolds row :=
  pidecFieldResidual_zero_iff

structure PiDECPublicInputSplitRow (RF : Type) where
  combined : RF
  left : RF
  right : RF

def PiDECPublicInputSplitRowHolds [Add RF]
    (row : PiDECPublicInputSplitRow RF) : Prop :=
  row.combined = row.left + row.right

def PiDECPublicInputSplitRowResidual [CommRing RF]
    (row : PiDECPublicInputSplitRow RF) : PiDECAIRResidualValue RF :=
  PiDECFieldResidual row.combined (row.left + row.right)

omit [CommRing RF] in
theorem pidecPublicInputSplitRowResidual_zero_iff [CommRing RF]
    (row : PiDECPublicInputSplitRow RF) :
    PiDECPublicInputSplitRowResidual row = 0 ↔
      PiDECPublicInputSplitRowHolds row :=
  pidecFieldResidual_zero_iff

structure PiDECLowNormRow where
  norm : Nat
  bound : Nat

def PiDECLowNormRowHolds (row : PiDECLowNormRow) : Prop :=
  row.norm ≤ row.bound

def PiDECLowNormRowResidual [Zero RF]
    (row : PiDECLowNormRow) : PiDECAIRResidualValue RF :=
  PiDECGuardResidual (RF := RF)
    (condition := row.norm ≤ row.bound)

omit [CommRing RF] in
theorem pidecLowNormRowResidual_zero_iff [Zero RF]
    (row : PiDECLowNormRow) :
    PiDECLowNormRowResidual (RF := RF) row = 0 ↔
      PiDECLowNormRowHolds row :=
  pidecGuardResidual_zero_iff

structure PiDECConcreteAIRRows
    (RF : Type) [CommRing RF]
    (rows columns count : Nat)
    (SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type) where
  matrix : AjtaiMatrix RF rows columns
  base : RF
  limbs : Fin count → Message RF columns
  folded : Message RF columns
  foldedCommitment : Commitment RF rows
  signedDigitBoundRow : SignedDigitIndex → PiDECSignedDigitBoundRow
  baseBDecompositionRow :
    DecompositionIndex → PiDECBaseBDecompositionRow RF count
  publicInputSplitRow :
    PublicSplitIndex → PiDECPublicInputSplitRow RF
  lowNormRow : LowNormIndex → PiDECLowNormRow

inductive PiDECConcreteAIRRowIndex
    (rows columns : Nat)
    (SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type) where
  | signedDigitBound :
      SignedDigitIndex →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex
  | baseBDecomposition :
      DecompositionIndex →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex
  | messageRecomposition :
      Fin columns →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex
  | commitmentEvaluation :
      Fin rows →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex
  | commitmentRecomposition :
      Fin rows →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex
  | publicInputSplit :
      PublicSplitIndex →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex
  | lowNorm :
      LowNormIndex →
        PiDECConcreteAIRRowIndex rows columns
          SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex

def PiDECConcreteAIRRows.messageRecompositionRow
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (coordinate : Fin columns) : PiDECRecompositionRow RF count where
  target := air.folded coordinate
  base := air.base
  parts := fun index => air.limbs index coordinate

def PiDECConcreteAIRRows.commitmentEvaluationRow
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (row : Fin rows) : PiDECCommitmentEvaluationRow RF columns where
  target := air.foldedCommitment row
  matrixRow := air.matrix row
  witness := air.folded

def PiDECConcreteAIRRows.commitmentRecompositionRow
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (row : Fin rows) : PiDECRecompositionRow RF count where
  target := air.foldedCommitment row
  base := air.base
  parts := fun index => commit air.matrix (air.limbs index) row

def PiDECConcreteAIRRowResidual
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (index :
      PiDECConcreteAIRRowIndex rows columns
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) :
    PiDECAIRResidualValue RF :=
  match index with
  | .signedDigitBound row =>
      PiDECSignedDigitBoundRowResidual (RF := RF)
        (air.signedDigitBoundRow row)
  | .baseBDecomposition row =>
      PiDECBaseBDecompositionRowResidual
        (air.baseBDecompositionRow row)
  | .messageRecomposition coordinate =>
      PiDECRecompositionRowResidual
        (air.messageRecompositionRow coordinate)
  | .commitmentEvaluation row =>
      PiDECCommitmentEvaluationRowResidual
        (air.commitmentEvaluationRow row)
  | .commitmentRecomposition row =>
      PiDECRecompositionRowResidual
        (air.commitmentRecompositionRow row)
  | .publicInputSplit row =>
      PiDECPublicInputSplitRowResidual
        (air.publicInputSplitRow row)
  | .lowNorm row =>
      PiDECLowNormRowResidual (RF := RF)
        (air.lowNormRow row)

def PiDECConcreteAIRRowHolds
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (index :
      PiDECConcreteAIRRowIndex rows columns
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) :
    Prop :=
  match index with
  | .signedDigitBound row =>
      PiDECSignedDigitBoundRowHolds (air.signedDigitBoundRow row)
  | .baseBDecomposition row =>
      PiDECBaseBDecompositionRowHolds (air.baseBDecompositionRow row)
  | .messageRecomposition coordinate =>
      PiDECRecompositionRowHolds (air.messageRecompositionRow coordinate)
  | .commitmentEvaluation row =>
      PiDECCommitmentEvaluationRowHolds (air.commitmentEvaluationRow row)
  | .commitmentRecomposition row =>
      PiDECRecompositionRowHolds (air.commitmentRecompositionRow row)
  | .publicInputSplit row =>
      PiDECPublicInputSplitRowHolds (air.publicInputSplitRow row)
  | .lowNorm row =>
      PiDECLowNormRowHolds (air.lowNormRow row)

theorem pidecConcreteAIRRowResidual_zero_iff_holds
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (index :
      PiDECConcreteAIRRowIndex rows columns
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) :
    PiDECConcreteAIRRowResidual air index = 0 ↔
      PiDECConcreteAIRRowHolds air index := by
  cases index with
  | signedDigitBound row =>
      exact pidecSignedDigitBoundRowResidual_zero_iff (RF := RF)
        (air.signedDigitBoundRow row)
  | baseBDecomposition row =>
      exact pidecBaseBDecompositionRowResidual_zero_iff
        (air.baseBDecompositionRow row)
  | messageRecomposition coordinate =>
      exact pidecRecompositionRowResidual_zero_iff
        (air.messageRecompositionRow coordinate)
  | commitmentEvaluation row =>
      exact pidecCommitmentEvaluationRowResidual_zero_iff
        (air.commitmentEvaluationRow row)
  | commitmentRecomposition row =>
      exact pidecRecompositionRowResidual_zero_iff
        (air.commitmentRecompositionRow row)
  | publicInputSplit row =>
      exact pidecPublicInputSplitRowResidual_zero_iff
        (air.publicInputSplitRow row)
  | lowNorm row =>
      exact pidecLowNormRowResidual_zero_iff (RF := RF)
        (air.lowNormRow row)

def PiDECConcreteAIRAllRowsZero
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) : Prop :=
  ∀ index, PiDECConcreteAIRRowResidual air index = 0

def PiDECConcreteAIRAllRowsHold
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) : Prop :=
  ∀ index, PiDECConcreteAIRRowHolds air index

theorem pidecConcreteAIR_allRowsZero_iff_allRowsHold
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) :
    PiDECConcreteAIRAllRowsZero air ↔ PiDECConcreteAIRAllRowsHold air := by
  constructor
  · intro hZero index
    exact (pidecConcreteAIRRowResidual_zero_iff_holds air index).mp
      (hZero index)
  · intro hHold index
    exact (pidecConcreteAIRRowResidual_zero_iff_holds air index).mpr
      (hHold index)

def PiDECConcreteSideRowsHold
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) : Prop :=
  (∀ row, PiDECSignedDigitBoundRowHolds (air.signedDigitBoundRow row)) ∧
    (∀ row, PiDECBaseBDecompositionRowHolds (air.baseBDecompositionRow row)) ∧
    (∀ row, PiDECPublicInputSplitRowHolds (air.publicInputSplitRow row)) ∧
    (∀ row, PiDECLowNormRowHolds (air.lowNormRow row))

def PiDECConcreteVerifierStep
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) : Prop :=
  PiDECVerifierStep
      air.matrix
      air.base
      air.limbs
      air.folded
      air.foldedCommitment ∧
    PiDECConcreteSideRowsHold air

theorem pidecConcreteAIR_allRowsZero_iff_verifierStep
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) :
    PiDECConcreteAIRAllRowsZero air ↔
      PiDECConcreteVerifierStep air := by
  constructor
  · intro hZero
    have hHold : PiDECConcreteAIRAllRowsHold air :=
      (pidecConcreteAIR_allRowsZero_iff_allRowsHold air).mp hZero
    have hFolded : air.folded = pidecWeightedMessage air.base air.limbs := by
      funext coordinate
      exact hHold (.messageRecomposition coordinate)
    have hCommitment :
        air.foldedCommitment =
          pidecWeightedCommitment air.base
            (fun index => commit air.matrix (air.limbs index)) := by
      funext row
      exact hHold (.commitmentRecomposition row)
    refine ⟨⟨hFolded, hCommitment⟩, ?_⟩
    exact
      ⟨fun row => hHold (.signedDigitBound row),
        fun row => hHold (.baseBDecomposition row),
        fun row => hHold (.publicInputSplit row),
        fun row => hHold (.lowNorm row)⟩
  · intro hVerifier
    rcases hVerifier with
      ⟨⟨hFolded, hCommitment⟩,
        hSignedDigits, hDecomposition, hPublicSplit, hLowNorm⟩
    have hCommitmentEvaluation :
        air.foldedCommitment = commit air.matrix air.folded := by
      rw [hCommitment, hFolded]
      exact (commit_pidecWeightedMessage air.matrix air.base air.limbs).symm
    refine (pidecConcreteAIR_allRowsZero_iff_allRowsHold air).mpr ?_
    intro index
    cases index with
    | signedDigitBound row =>
        exact hSignedDigits row
    | baseBDecomposition row =>
        exact hDecomposition row
    | messageRecomposition coordinate =>
        exact congrFun hFolded coordinate
    | commitmentEvaluation row =>
        exact congrFun hCommitmentEvaluation row
    | commitmentRecomposition row =>
        exact congrFun hCommitment row
    | publicInputSplit row =>
        exact hPublicSplit row
    | lowNorm row =>
        exact hLowNorm row

theorem pidecConcreteAIR_allRowsZero_implies_primitiveConstraints
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (hZero : PiDECConcreteAIRAllRowsZero air) :
    PiDECPrimitiveConstraints
      air.matrix
      air.base
      air.limbs
      air.folded
      air.foldedCommitment := by
  have hVerifier :
      PiDECConcreteVerifierStep air :=
    (pidecConcreteAIR_allRowsZero_iff_verifierStep air).mp hZero
  exact
    (pidecVerifierStep_iff_primitiveConstraints
      air.matrix
      air.base
      air.limbs
      air.folded
      air.foldedCommitment).mp hVerifier.1

inductive TerminalAIRRowProvenance where
  | primitiveArithmetic
  | canonicalDecoding
  | publicInputBinding
  | hashSubrelation
  | publicCoinBinding
  | friPCSVerifier
  deriving DecidableEq

def TerminalAIRRowProvenance.productionCode :
    TerminalAIRRowProvenance → Nat
  | .primitiveArithmetic => 1
  | .canonicalDecoding => 2
  | .publicInputBinding => 3
  | .hashSubrelation => 4
  | .publicCoinBinding => 5
  | .friPCSVerifier => 6

inductive TerminalAIRSubrelationKind where
  | canonicalSourceRepresentation
  | publicBinding
  | piCCSVerifier
  | piRLCVerifier
  | piDECVerifier
  | terminalCEOpening
  | innerCompressedProofVerifier
  | acceptAggregation
  deriving DecidableEq

def TerminalAIRSubrelationKind.productionCode :
    TerminalAIRSubrelationKind → Nat
  | .canonicalSourceRepresentation => 1
  | .publicBinding => 2
  | .piCCSVerifier => 3
  | .piRLCVerifier => 4
  | .piDECVerifier => 5
  | .terminalCEOpening => 6
  | .innerCompressedProofVerifier => 7
  | .acceptAggregation => 8

inductive PiCCSPrimitiveRowKind where
  | scheduleRoundCount
  | stateRoundCount
  | claimedSum
  | initialClaim
  | roundZeroOneSum
  | roundNextClaim
  | finalEvaluation
  | finalClaimConsistency
  deriving DecidableEq

inductive PiDECPrimitiveRowKind where
  | signedDigitBound
  | baseBDecomposition
  | messageRecomposition
  | commitmentEvaluation
  | commitmentRecomposition
  | publicInputSplit
  | lowNorm
  deriving DecidableEq

inductive PiRLCPrimitiveRowKind where
  | challengeBinding
  | foldedPoint
  | parentPoint
  | commitmentCombination
  | publicInputCombination
  | evaluationCombination
  deriving DecidableEq

inductive CEAjtaiPrimitiveRowKind where
  | shapeRows
  | shapeColumns
  | shapePublicCount
  | shapeEvalCount
  | shapePointVars
  | contextProfileID
  | contextShapeDigest
  | contextVerifierKeyDigest
  | publicInputBound
  | witnessBound
  | commitmentRecomposition
  | evaluationRelation
  deriving DecidableEq

def PiCCSPrimitiveRowKind.localCode : PiCCSPrimitiveRowKind → Nat
  | .scheduleRoundCount => 1
  | .stateRoundCount => 2
  | .claimedSum => 3
  | .initialClaim => 4
  | .roundZeroOneSum => 5
  | .roundNextClaim => 6
  | .finalEvaluation => 7
  | .finalClaimConsistency => 8

def PiDECPrimitiveRowKind.localCode : PiDECPrimitiveRowKind → Nat
  | .signedDigitBound => 1
  | .baseBDecomposition => 2
  | .messageRecomposition => 3
  | .commitmentEvaluation => 4
  | .commitmentRecomposition => 5
  | .publicInputSplit => 6
  | .lowNorm => 7

def PiRLCPrimitiveRowKind.localCode : PiRLCPrimitiveRowKind → Nat
  | .challengeBinding => 1
  | .foldedPoint => 2
  | .parentPoint => 3
  | .commitmentCombination => 4
  | .publicInputCombination => 5
  | .evaluationCombination => 6

def CEAjtaiPrimitiveRowKind.localCode : CEAjtaiPrimitiveRowKind → Nat
  | .shapeRows => 1
  | .shapeColumns => 2
  | .shapePublicCount => 3
  | .shapeEvalCount => 4
  | .shapePointVars => 5
  | .contextProfileID => 6
  | .contextShapeDigest => 7
  | .contextVerifierKeyDigest => 8
  | .publicInputBound => 9
  | .witnessBound => 10
  | .commitmentRecomposition => 11
  | .evaluationRelation => 12

structure TerminalAIRPublicBindingContext where
  profileID : Nat
  shapeDigest : Digest256Wire
  statementDigest : Digest256Wire
  verifierKeyDigest : Digest256Wire
  transcriptDomain : Digest256Wire
  publicInputDigest : Digest256Wire
  compressionPolicyDigest : Digest256Wire
  terminalStatementDigest : Digest256Wire
  foldProofDigest : Digest256Wire
  ceOpeningProofDigest : Digest256Wire

structure TerminalAIRRowTranscriptContext where
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

structure TerminalAIRScheduledRowRef where
  provenance : TerminalAIRRowProvenance
  subrelationKind : TerminalAIRSubrelationKind
  rowKindCode : Nat
  globalRowIndex : Nat
  localRowIndex : Nat
  coordinateIndex? : Option Nat
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

def TerminalAIRScheduledRowRef.provenanceCode
    (row : TerminalAIRScheduledRowRef) : Nat :=
  row.provenance.productionCode

def TerminalAIRScheduledRowRef.subrelationCode
    (row : TerminalAIRScheduledRowRef) : Nat :=
  row.subrelationKind.productionCode

structure TerminalAIRProductionPrimitiveRowBindingFields
    (Observed Expected ResidualValue : Type) where
  domain : String
  subrelationKindRawValue : Nat
  globalRowIndex : Nat
  productionRowKindRawValue : Nat
  localRowKindCode : Nat
  provenanceRawValue : Nat
  labelDigest : Digest256Wire
  observed : Observed
  expected : Expected
  residual : ResidualValue
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

def TerminalAIRProductionPrimitiveRowBindingFields.ofScheduledRowRef
    {Observed Expected ResidualValue : Type}
    (domain : String)
    (row : TerminalAIRScheduledRowRef)
    (labelDigest : Digest256Wire)
    (observed : Observed)
    (expected : Expected)
    (residual : ResidualValue) :
    TerminalAIRProductionPrimitiveRowBindingFields
      Observed Expected ResidualValue where
  domain := domain
  subrelationKindRawValue := row.subrelationCode
  globalRowIndex := row.globalRowIndex
  productionRowKindRawValue := row.subrelationCode
  localRowKindCode := row.rowKindCode
  provenanceRawValue := row.provenanceCode
  labelDigest := labelDigest
  observed := observed
  expected := expected
  residual := residual
  publicBindingContext := row.publicBindingContext
  terminalVerifierRelationDigest := row.terminalVerifierRelationDigest
  recursiveRelationDigest := row.recursiveRelationDigest
  sourceDigest := row.sourceDigest
  sourceByteCount := row.sourceByteCount

def TerminalAIRProductionPrimitiveRowBindingFields.MatchesScheduledRowRef
    {Observed Expected ResidualValue : Type}
    (residualOf : Observed → Expected → ResidualValue)
    (fields :
      TerminalAIRProductionPrimitiveRowBindingFields
        Observed Expected ResidualValue)
    (row : TerminalAIRScheduledRowRef) : Prop :=
  fields.subrelationKindRawValue = row.subrelationCode ∧
  fields.globalRowIndex = row.globalRowIndex ∧
  fields.productionRowKindRawValue = row.subrelationCode ∧
  fields.localRowKindCode = row.rowKindCode ∧
  fields.provenanceRawValue = row.provenanceCode ∧
  fields.residual = residualOf fields.observed fields.expected ∧
  fields.publicBindingContext = row.publicBindingContext ∧
  fields.terminalVerifierRelationDigest =
    row.terminalVerifierRelationDigest ∧
  fields.recursiveRelationDigest = row.recursiveRelationDigest ∧
  fields.sourceDigest = row.sourceDigest ∧
  fields.sourceByteCount = row.sourceByteCount

theorem terminalAIRProductionPrimitiveRowBindingFields_ofScheduledRowRef_matches
    {Observed Expected ResidualValue : Type}
    (residualOf : Observed → Expected → ResidualValue)
    (domain : String)
    (row : TerminalAIRScheduledRowRef)
    (labelDigest : Digest256Wire)
    (observed : Observed)
    (expected : Expected) :
    TerminalAIRProductionPrimitiveRowBindingFields.MatchesScheduledRowRef
      residualOf
      (TerminalAIRProductionPrimitiveRowBindingFields.ofScheduledRowRef
        domain row labelDigest observed expected
        (residualOf observed expected))
      row := by
  simp [TerminalAIRProductionPrimitiveRowBindingFields.MatchesScheduledRowRef,
    TerminalAIRProductionPrimitiveRowBindingFields.ofScheduledRowRef]

theorem terminalAIRProductionPrimitiveRowBindingFields_matches_implies_context_bound
    {Observed Expected ResidualValue : Type}
    {residualOf : Observed → Expected → ResidualValue}
    {fields :
      TerminalAIRProductionPrimitiveRowBindingFields
        Observed Expected ResidualValue}
    {row : TerminalAIRScheduledRowRef}
    (hMatches :
      TerminalAIRProductionPrimitiveRowBindingFields.MatchesScheduledRowRef
        residualOf fields row) :
    fields.publicBindingContext = row.publicBindingContext ∧
      fields.terminalVerifierRelationDigest =
        row.terminalVerifierRelationDigest ∧
      fields.recursiveRelationDigest = row.recursiveRelationDigest ∧
      fields.sourceDigest = row.sourceDigest ∧
      fields.sourceByteCount = row.sourceByteCount := by
  rcases hMatches with
    ⟨_hSubrelation, _hGlobalIndex, _hProductionRowKind,
      _hLocalRowKind, _hProvenance, _hResidual, hPublicContext,
      hTerminalDigest, hRecursiveDigest, hSourceDigest, hSourceByteCount⟩
  exact
    ⟨hPublicContext, hTerminalDigest, hRecursiveDigest, hSourceDigest,
      hSourceByteCount⟩

theorem terminalAIRProductionPrimitiveRowBindingFields_matches_implies_raw_tags
    {Observed Expected ResidualValue : Type}
    {residualOf : Observed → Expected → ResidualValue}
    {fields :
      TerminalAIRProductionPrimitiveRowBindingFields
        Observed Expected ResidualValue}
    {row : TerminalAIRScheduledRowRef}
    (hMatches :
      TerminalAIRProductionPrimitiveRowBindingFields.MatchesScheduledRowRef
        residualOf fields row) :
    fields.subrelationKindRawValue = row.subrelationCode ∧
      fields.productionRowKindRawValue = row.subrelationCode ∧
      fields.localRowKindCode = row.rowKindCode ∧
      fields.provenanceRawValue = row.provenanceCode := by
  rcases hMatches with
    ⟨hSubrelation, _hGlobalIndex, hProductionRowKind, hLocalRowKind,
      hProvenance, _hResidual, _hPublicContext, _hTerminalDigest,
      _hRecursiveDigest, _hSourceDigest, _hSourceByteCount⟩
  exact ⟨hSubrelation, hProductionRowKind, hLocalRowKind, hProvenance⟩

structure TerminalAIRQueryOpening
    (TraceOpening ResidualValue : Type) where
  scheduledRow : TerminalAIRScheduledRowRef
  traceOpening : TraceOpening
  residualOpening : ResidualValue

structure TerminalAIRPackedConstraintRowLayout where
  subrelationKind : TerminalAIRSubrelationKind
  subrelationStartIndex : Nat
  primitiveRowsStartIndex : Nat
  contextDigestFieldCount : Nat
  labelDigestFieldCount : Nat

def TerminalAIRPackedConstraintRowLayout.rowBlockWidth
    (layout : TerminalAIRPackedConstraintRowLayout) : Nat :=
  4 + layout.contextDigestFieldCount + layout.labelDigestFieldCount

def TerminalAIRPackedConstraintRowLayout.observedResidualOffset
    (layout : TerminalAIRPackedConstraintRowLayout) : Nat :=
  3 + layout.contextDigestFieldCount + layout.labelDigestFieldCount

def TerminalAIRPackedConstraintRowLayout.rowBaseIndex
    (layout : TerminalAIRPackedConstraintRowLayout)
    (row : TerminalAIRScheduledRowRef) : Nat :=
  layout.subrelationStartIndex +
    layout.primitiveRowsStartIndex +
      row.globalRowIndex * layout.rowBlockWidth

def TerminalAIRPackedConstraintRowLayout.observedResidualIndex
    (layout : TerminalAIRPackedConstraintRowLayout)
    (row : TerminalAIRScheduledRowRef) : Nat :=
  layout.rowBaseIndex row + layout.observedResidualOffset

theorem terminalAIRPackedConstraintRowLayout_observedResidualOffset_lt_rowBlockWidth
    (layout : TerminalAIRPackedConstraintRowLayout) :
    layout.observedResidualOffset < layout.rowBlockWidth := by
  simp [TerminalAIRPackedConstraintRowLayout.observedResidualOffset,
    TerminalAIRPackedConstraintRowLayout.rowBlockWidth,
    Nat.add_comm, Nat.add_left_comm]

def terminalAIRProductionConstraintRowLayout
    (subrelationKind : TerminalAIRSubrelationKind)
    (subrelationStartIndex primitiveRowsStartIndex digestFieldCount : Nat) :
    TerminalAIRPackedConstraintRowLayout where
  subrelationKind := subrelationKind
  subrelationStartIndex := subrelationStartIndex
  primitiveRowsStartIndex := primitiveRowsStartIndex
  contextDigestFieldCount := digestFieldCount
  labelDigestFieldCount := digestFieldCount

theorem terminalAIRProductionConstraintRowLayout_rowBlockWidth
    (subrelationKind : TerminalAIRSubrelationKind)
    (subrelationStartIndex primitiveRowsStartIndex digestFieldCount : Nat) :
    (terminalAIRProductionConstraintRowLayout
      subrelationKind subrelationStartIndex primitiveRowsStartIndex
      digestFieldCount).rowBlockWidth =
        4 + digestFieldCount + digestFieldCount :=
  rfl

theorem terminalAIRProductionConstraintRowLayout_observedResidualOffset
    (subrelationKind : TerminalAIRSubrelationKind)
    (subrelationStartIndex primitiveRowsStartIndex digestFieldCount : Nat) :
    (terminalAIRProductionConstraintRowLayout
      subrelationKind subrelationStartIndex primitiveRowsStartIndex
      digestFieldCount).observedResidualOffset =
        3 + digestFieldCount + digestFieldCount :=
  rfl

def terminalAIRPiCCSPrimitiveRowsStartIndex
    (digestFieldCount : Nat) : Nat :=
  4 * digestFieldCount + 2

def terminalAIRPiRLCPrimitiveRowsStartIndex
    (digestFieldCount : Nat) : Nat :=
  5 * digestFieldCount + 1

def terminalAIRPiDECPrimitiveRowsStartIndex
    (digestFieldCount : Nat) : Nat :=
  3 * digestFieldCount + 1

def terminalAIRCEAjtaiPrimitiveRowsStartIndex
    (digestFieldCount : Nat) : Nat :=
  4 * digestFieldCount + 1

def terminalAIRPiCCSProductionPackedLayout
    (subrelationStartIndex digestFieldCount : Nat) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRProductionConstraintRowLayout
    .piCCSVerifier
    subrelationStartIndex
    (terminalAIRPiCCSPrimitiveRowsStartIndex digestFieldCount)
    digestFieldCount

def terminalAIRPiRLCProductionPackedLayout
    (subrelationStartIndex digestFieldCount : Nat) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRProductionConstraintRowLayout
    .piRLCVerifier
    subrelationStartIndex
    (terminalAIRPiRLCPrimitiveRowsStartIndex digestFieldCount)
    digestFieldCount

def terminalAIRPiDECProductionPackedLayout
    (subrelationStartIndex digestFieldCount : Nat) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRProductionConstraintRowLayout
    .piDECVerifier
    subrelationStartIndex
    (terminalAIRPiDECPrimitiveRowsStartIndex digestFieldCount)
    digestFieldCount

def terminalAIRCEAjtaiProductionPackedLayout
    (subrelationStartIndex digestFieldCount : Nat) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRProductionConstraintRowLayout
    .terminalCEOpening
    subrelationStartIndex
    (terminalAIRCEAjtaiPrimitiveRowsStartIndex digestFieldCount)
    digestFieldCount

theorem finPairRowMajor_eq_of_eq
    {outer inner : Nat}
    {lhsOuter rhsOuter : Fin outer}
    {lhsInner rhsInner : Fin inner}
    (hEq :
      lhsOuter.val * inner + lhsInner.val =
        rhsOuter.val * inner + rhsInner.val) :
    lhsOuter = rhsOuter ∧ lhsInner = rhsInner := by
  have hInnerPos : 0 < inner :=
    Nat.lt_of_le_of_lt (Nat.zero_le lhsInner.val) lhsInner.isLt
  have hLeftDiv :
      (lhsOuter.val * inner + lhsInner.val) / inner = lhsOuter.val := by
    rw [Nat.mul_comm lhsOuter.val inner]
    rw [Nat.mul_add_div hInnerPos]
    rw [Nat.div_eq_of_lt lhsInner.isLt]
    omega
  have hRightDiv :
      (rhsOuter.val * inner + rhsInner.val) / inner = rhsOuter.val := by
    rw [Nat.mul_comm rhsOuter.val inner]
    rw [Nat.mul_add_div hInnerPos]
    rw [Nat.div_eq_of_lt rhsInner.isLt]
    omega
  have hOuterValue : lhsOuter.val = rhsOuter.val := by
    calc
      lhsOuter.val =
          (lhsOuter.val * inner + lhsInner.val) / inner :=
        hLeftDiv.symm
      _ = (rhsOuter.val * inner + rhsInner.val) / inner := by
        rw [hEq]
      _ = rhsOuter.val := hRightDiv
  have hInnerValue : lhsInner.val = rhsInner.val := by
    have hEq' := hEq
    rw [hOuterValue] at hEq'
    exact Nat.add_left_cancel hEq'
  exact ⟨Fin.ext hOuterValue, Fin.ext hInnerValue⟩

theorem finPairRowMajor_lt_product
    {outer inner : Nat}
    (outerIndex : Fin outer)
    (innerIndex : Fin inner) :
    outerIndex.val * inner + innerIndex.val < outer * inner := by
  have hBlockBound :
      (outerIndex.val + 1) * inner <= outer * inner := by
    exact Nat.mul_le_mul_right inner outerIndex.isLt
  have hWithinBlock :
      outerIndex.val * inner + innerIndex.val <
        (outerIndex.val + 1) * inner := by
    nlinarith [innerIndex.isLt]
  exact lt_of_lt_of_le hWithinBlock hBlockBound

section PiCCSSchedule

variable {K : Type} [CommRing K]

inductive PiCCSScheduleIndex (rounds : Nat) where
  | scheduleRoundCount : PiCCSScheduleIndex rounds
  | stateRoundCount : PiCCSScheduleIndex rounds
  | claimedSum : PiCCSScheduleIndex rounds
  | initialClaim : PiCCSScheduleIndex rounds
  | roundZeroOneSum : Fin rounds → PiCCSScheduleIndex rounds
  | roundNextClaim : Fin rounds → PiCCSScheduleIndex rounds
  | finalEvaluation : PiCCSScheduleIndex rounds
  | finalClaimConsistency : PiCCSScheduleIndex rounds
  deriving DecidableEq

def PiCCSScheduleIndex.toConcreteIndex
    {rounds : Nat} :
    PiCCSScheduleIndex rounds → PiCCSConcreteAIRRowIndex rounds
  | .scheduleRoundCount => .scheduleRoundCount
  | .stateRoundCount => .stateRoundCount
  | .claimedSum => .claimedSum
  | .initialClaim => .initialClaim
  | .roundZeroOneSum round => .roundZeroOneSum round
  | .roundNextClaim round => .roundNextClaim round
  | .finalEvaluation => .finalEvaluation
  | .finalClaimConsistency => .finalClaimConsistency

def PiCCSScheduleIndex.fromConcreteIndex
    {rounds : Nat} :
    PiCCSConcreteAIRRowIndex rounds → PiCCSScheduleIndex rounds
  | .scheduleRoundCount => .scheduleRoundCount
  | .stateRoundCount => .stateRoundCount
  | .claimedSum => .claimedSum
  | .initialClaim => .initialClaim
  | .roundZeroOneSum round => .roundZeroOneSum round
  | .roundNextClaim round => .roundNextClaim round
  | .finalEvaluation => .finalEvaluation
  | .finalClaimConsistency => .finalClaimConsistency

theorem piccsSchedule_toConcrete_fromConcrete
    {rounds : Nat}
    (index : PiCCSConcreteAIRRowIndex rounds) :
    PiCCSScheduleIndex.toConcreteIndex
        (PiCCSScheduleIndex.fromConcreteIndex index) = index := by
  cases index <;> rfl

theorem piccsSchedule_fromConcrete_toConcrete
    {rounds : Nat}
    (index : PiCCSScheduleIndex rounds) :
    PiCCSScheduleIndex.fromConcreteIndex
        (PiCCSScheduleIndex.toConcreteIndex index) = index := by
  cases index <;> rfl

theorem piccsSchedule_no_missing_required_row
    {rounds : Nat}
    (index : PiCCSConcreteAIRRowIndex rounds) :
    ∃ scheduled : PiCCSScheduleIndex rounds,
      PiCCSScheduleIndex.toConcreteIndex scheduled = index :=
  ⟨PiCCSScheduleIndex.fromConcreteIndex index,
    piccsSchedule_toConcrete_fromConcrete index⟩

theorem piccsSchedule_no_duplicate_row_index
    {rounds : Nat} :
    Function.Injective
      (PiCCSScheduleIndex.toConcreteIndex (rounds := rounds)) := by
  intro lhs rhs hConcrete
  rw [← piccsSchedule_fromConcrete_toConcrete lhs]
  rw [← piccsSchedule_fromConcrete_toConcrete rhs]
  rw [hConcrete]

def PiCCSScheduleIndex.rowKind
    {rounds : Nat}
    (index : PiCCSScheduleIndex rounds) : PiCCSPrimitiveRowKind :=
  match index with
  | .scheduleRoundCount => .scheduleRoundCount
  | .stateRoundCount => .stateRoundCount
  | .claimedSum => .claimedSum
  | .initialClaim => .initialClaim
  | .roundZeroOneSum _ => .roundZeroOneSum
  | .roundNextClaim _ => .roundNextClaim
  | .finalEvaluation => .finalEvaluation
  | .finalClaimConsistency => .finalClaimConsistency

def PiCCSScheduleIndex.localIndex
    {rounds : Nat}
    (index : PiCCSScheduleIndex rounds) : Nat :=
  match index with
  | .scheduleRoundCount => 0
  | .stateRoundCount => 0
  | .claimedSum => 0
  | .initialClaim => 0
  | .roundZeroOneSum round => round.val
  | .roundNextClaim round => round.val
  | .finalEvaluation => 0
  | .finalClaimConsistency => 0

def PiCCSScheduleIndex.coordinateIndex?
    {rounds : Nat}
    (index : PiCCSScheduleIndex rounds) : Option Nat :=
  match index with
  | .roundZeroOneSum round => some round.val
  | .roundNextClaim round => some round.val
  | _ => none

def PiCCSScheduleIndex.provenance
    {rounds : Nat}
    (_index : PiCCSScheduleIndex rounds) : TerminalAIRRowProvenance :=
  .primitiveArithmetic

def PiCCSScheduleIndex.subrelationKind
    {rounds : Nat}
    (_index : PiCCSScheduleIndex rounds) : TerminalAIRSubrelationKind :=
  .piCCSVerifier

def PiCCSScheduleIndex.globalRowIndex
    {rounds : Nat}
    (index : PiCCSScheduleIndex rounds) : Nat :=
  match index with
  | .scheduleRoundCount => 0
  | .stateRoundCount => 1
  | .claimedSum => 2
  | .initialClaim => 3
  | .roundZeroOneSum round => 4 + round.val
  | .roundNextClaim round => 4 + rounds + round.val
  | .finalEvaluation => 4 + rounds + rounds
  | .finalClaimConsistency => 5 + rounds + rounds

theorem piccsSchedule_globalRowIndex_injective
    {rounds : Nat} :
    Function.Injective
      (PiCCSScheduleIndex.globalRowIndex (rounds := rounds)) := by
  intro lhs rhs hIndex
  cases lhs <;> cases rhs <;>
    simp [PiCCSScheduleIndex.globalRowIndex] at hIndex ⊢ <;>
    omega

def PiCCSScheduleIndex.toScheduledRowRef
    {rounds : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    TerminalAIRScheduledRowRef where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKindCode := PiCCSPrimitiveRowKind.localCode index.rowKind
  globalRowIndex := index.globalRowIndex
  localRowIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

theorem piccsSchedule_scheduledRowRef_subrelation
    {rounds : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    (PiCCSScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .piCCSVerifier :=
  rfl

theorem piccsProductionPackedLayout_subrelation_matches_rowRef
    {rounds : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    (PiCCSScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        (terminalAIRPiCCSProductionPackedLayout
          subrelationStartIndex digestFieldCount).subrelationKind :=
  rfl

theorem piccsProductionPackedLayout_observedResidualIndex
    {rounds : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    (terminalAIRPiCCSProductionPackedLayout
      subrelationStartIndex digestFieldCount).observedResidualIndex
        (PiCCSScheduleIndex.toScheduledRowRef
          publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount index) =
      subrelationStartIndex +
        terminalAIRPiCCSPrimitiveRowsStartIndex digestFieldCount +
          index.globalRowIndex *
            (terminalAIRPiCCSProductionPackedLayout
              subrelationStartIndex digestFieldCount).rowBlockWidth +
              (terminalAIRPiCCSProductionPackedLayout
                subrelationStartIndex digestFieldCount).observedResidualOffset :=
  rfl

theorem piccsSchedule_no_ambiguous_row_kind
    {rounds : Nat}
    {lhs rhs : PiCCSScheduleIndex rounds}
    (hConcrete :
      PiCCSScheduleIndex.toConcreteIndex lhs =
        PiCCSScheduleIndex.toConcreteIndex rhs) :
    lhs = rhs ∧ lhs.rowKind = rhs.rowKind := by
  have hEq := piccsSchedule_no_duplicate_row_index hConcrete
  exact ⟨hEq, by rw [hEq]⟩

inductive PiCCSScheduledRowValue (K : Type) where
  | nat : Nat → PiCCSScheduledRowValue K
  | field : K → PiCCSScheduledRowValue K
  | guard : Nat → PiCCSScheduledRowValue K

def PiCCSConcreteAIRRowObservedValue
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (index : PiCCSConcreteAIRRowIndex rounds) :
    PiCCSScheduledRowValue K :=
  match index with
  | .scheduleRoundCount => .nat air.scheduleRoundCountRow.observed
  | .stateRoundCount => .nat air.stateRoundCountRow.observed
  | .claimedSum => .field air.claimedSumRow.observed
  | .initialClaim => .field air.initialClaimRow.observed
  | .roundZeroOneSum round => .field (air.roundZeroOneSumRow round).observed
  | .roundNextClaim round => .field (air.roundNextClaimRow round).observed
  | .finalEvaluation => .field air.finalEvaluationRow.observed
  | .finalClaimConsistency =>
      let row := air.finalClaimConsistencyRow
      letI := row.decidableCondition
      .guard (if row.condition then 0 else 1)

def PiCCSConcreteAIRRowExpectedValue
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (index : PiCCSConcreteAIRRowIndex rounds) :
    PiCCSScheduledRowValue K :=
  match index with
  | .scheduleRoundCount => .nat air.scheduleRoundCountRow.expected
  | .stateRoundCount => .nat air.stateRoundCountRow.expected
  | .claimedSum => .field air.claimedSumRow.expected
  | .initialClaim => .field air.initialClaimRow.expected
  | .roundZeroOneSum round => .field (air.roundZeroOneSumRow round).expected
  | .roundNextClaim round => .field (air.roundNextClaimRow round).expected
  | .finalEvaluation => .field air.finalEvaluationRow.expected
  | .finalClaimConsistency => .guard 0

structure PiCCSScheduledRowTranscript
    (K : Type) [CommRing K]
    (rounds : Nat) where
  provenance : TerminalAIRRowProvenance
  subrelationKind : TerminalAIRSubrelationKind
  rowKind : PiCCSPrimitiveRowKind
  rowIndex : PiCCSScheduleIndex rounds
  localIndex : Nat
  coordinateIndex? : Option Nat
  observedValue : PiCCSScheduledRowValue K
  expectedValue : PiCCSScheduledRowValue K
  residual : PiCCSAIRResidualValue K
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

def PiCCSScheduledRowTranscript.ofScheduleIndex
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    PiCCSScheduledRowTranscript K rounds where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKind := index.rowKind
  rowIndex := index
  localIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  observedValue :=
    PiCCSConcreteAIRRowObservedValue air index.toConcreteIndex
  expectedValue :=
    PiCCSConcreteAIRRowExpectedValue air index.toConcreteIndex
  residual :=
    PiCCSConcreteAIRRowResidual air index.toConcreteIndex
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

def PiCCSScheduledRowTranscript.toScheduledRowRef
    {rounds : Nat}
    (globalRowIndex : Nat)
    (row : PiCCSScheduledRowTranscript K rounds) :
    TerminalAIRScheduledRowRef where
  provenance := row.provenance
  subrelationKind := row.subrelationKind
  rowKindCode := PiCCSPrimitiveRowKind.localCode row.rowKind
  globalRowIndex := globalRowIndex
  localRowIndex := row.localIndex
  coordinateIndex? := row.coordinateIndex?
  publicBindingContext := row.publicBindingContext
  terminalVerifierRelationDigest := row.terminalVerifierRelationDigest
  recursiveRelationDigest := row.recursiveRelationDigest
  sourceDigest := row.sourceDigest
  sourceByteCount := row.sourceByteCount

theorem piccsScheduledRow_subrelation_piCCS
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    (PiCCSScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .piCCSVerifier :=
  rfl

theorem piccsScheduledRow_residual_eq_concrete
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index : PiCCSScheduleIndex rounds) :
    (PiCCSScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual =
        PiCCSConcreteAIRRowResidual air index.toConcreteIndex :=
  rfl

def PiCCSScheduledAIRAllRowsZero
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) : Prop :=
  ∀ index : PiCCSScheduleIndex rounds,
    (PiCCSScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual = 0

theorem piccsScheduledAIR_allRowsZero_iff_concreteAllRowsZero
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    PiCCSScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      PiCCSConcreteAIRAllRowsZero air := by
  constructor
  · intro hScheduled concreteIndex
    have hScheduledIndex :
        (PiCCSScheduledRowTranscript.ofScheduleIndex
          air publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount
          (PiCCSScheduleIndex.fromConcreteIndex concreteIndex)).residual = 0 :=
      hScheduled (PiCCSScheduleIndex.fromConcreteIndex concreteIndex)
    simpa [PiCCSScheduledRowTranscript.ofScheduleIndex,
      piccsSchedule_toConcrete_fromConcrete concreteIndex] using hScheduledIndex
  · intro hConcrete scheduledIndex
    simpa [PiCCSScheduledRowTranscript.ofScheduleIndex] using
      hConcrete scheduledIndex.toConcreteIndex

theorem piccsScheduledAIR_allRowsZero_iff_verifierStep
    {rounds : Nat}
    (air : PiCCSConcreteAIRRows K rounds)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    PiCCSScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      PiCCSConcreteVerifierStep air := by
  rw [piccsScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  exact piccsConcreteAIR_allRowsZero_iff_verifierStep air

end PiCCSSchedule

inductive PiRLCScheduleIndex
    (count rows publicCount evalCount pointVars : Nat) where
  | challengeBinding :
      Fin count →
        PiRLCScheduleIndex count rows publicCount evalCount pointVars
  | foldedPoint :
      Fin pointVars →
        PiRLCScheduleIndex count rows publicCount evalCount pointVars
  | parentPoint :
      Fin count →
        Fin pointVars →
          PiRLCScheduleIndex count rows publicCount evalCount pointVars
  | commitmentCombination :
      Fin rows →
        PiRLCScheduleIndex count rows publicCount evalCount pointVars
  | publicInputCombination :
      Fin publicCount →
        PiRLCScheduleIndex count rows publicCount evalCount pointVars
  | evaluationCombination :
      Fin evalCount →
        PiRLCScheduleIndex count rows publicCount evalCount pointVars
  deriving DecidableEq

def PiRLCScheduleIndex.toConcreteIndex
    {count rows publicCount evalCount pointVars : Nat} :
    PiRLCScheduleIndex count rows publicCount evalCount pointVars →
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars
  | .challengeBinding row => .challengeBinding row
  | .foldedPoint coordinate => .foldedPoint coordinate
  | .parentPoint claimIndex coordinate => .parentPoint claimIndex coordinate
  | .commitmentCombination row => .commitmentCombination row
  | .publicInputCombination coordinate => .publicInputCombination coordinate
  | .evaluationCombination coordinate => .evaluationCombination coordinate

def PiRLCScheduleIndex.fromConcreteIndex
    {count rows publicCount evalCount pointVars : Nat} :
    PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars →
      PiRLCScheduleIndex count rows publicCount evalCount pointVars
  | .challengeBinding row => .challengeBinding row
  | .foldedPoint coordinate => .foldedPoint coordinate
  | .parentPoint claimIndex coordinate => .parentPoint claimIndex coordinate
  | .commitmentCombination row => .commitmentCombination row
  | .publicInputCombination coordinate => .publicInputCombination coordinate
  | .evaluationCombination coordinate => .evaluationCombination coordinate

theorem pirlcSchedule_toConcrete_fromConcrete
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    PiRLCScheduleIndex.toConcreteIndex
        (PiRLCScheduleIndex.fromConcreteIndex index) = index := by
  cases index <;> rfl

theorem pirlcSchedule_fromConcrete_toConcrete
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    PiRLCScheduleIndex.fromConcreteIndex
        (PiRLCScheduleIndex.toConcreteIndex index) = index := by
  cases index <;> rfl

theorem pirlcSchedule_no_missing_required_row
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    ∃ scheduled : PiRLCScheduleIndex count rows publicCount evalCount pointVars,
      PiRLCScheduleIndex.toConcreteIndex scheduled = index :=
  ⟨PiRLCScheduleIndex.fromConcreteIndex index,
    pirlcSchedule_toConcrete_fromConcrete index⟩

theorem pirlcSchedule_no_duplicate_row_index
    {count rows publicCount evalCount pointVars : Nat} :
    Function.Injective
      (PiRLCScheduleIndex.toConcreteIndex
        (count := count)
        (rows := rows)
        (publicCount := publicCount)
        (evalCount := evalCount)
        (pointVars := pointVars)) := by
  intro lhs rhs hConcrete
  rw [← pirlcSchedule_fromConcrete_toConcrete lhs]
  rw [← pirlcSchedule_fromConcrete_toConcrete rhs]
  rw [hConcrete]

def PiRLCScheduleIndex.rowKind
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    PiRLCPrimitiveRowKind :=
  match index with
  | .challengeBinding _ => .challengeBinding
  | .foldedPoint _ => .foldedPoint
  | .parentPoint _ _ => .parentPoint
  | .commitmentCombination _ => .commitmentCombination
  | .publicInputCombination _ => .publicInputCombination
  | .evaluationCombination _ => .evaluationCombination

def PiRLCScheduleIndex.localIndex
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) : Nat :=
  match index with
  | .challengeBinding row => row.val
  | .foldedPoint coordinate => coordinate.val
  | .parentPoint claimIndex _ => claimIndex.val
  | .commitmentCombination row => row.val
  | .publicInputCombination coordinate => coordinate.val
  | .evaluationCombination coordinate => coordinate.val

def PiRLCScheduleIndex.coordinateIndex?
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    Option Nat :=
  match index with
  | .foldedPoint coordinate => some coordinate.val
  | .parentPoint _ coordinate => some coordinate.val
  | .commitmentCombination row => some row.val
  | .publicInputCombination coordinate => some coordinate.val
  | .evaluationCombination coordinate => some coordinate.val
  | .challengeBinding _ => none

def PiRLCScheduleIndex.provenance
    {count rows publicCount evalCount pointVars : Nat}
    (_index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    TerminalAIRRowProvenance :=
  .primitiveArithmetic

def PiRLCScheduleIndex.subrelationKind
    {count rows publicCount evalCount pointVars : Nat}
    (_index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    TerminalAIRSubrelationKind :=
  .piRLCVerifier

def PiRLCScheduleIndex.globalRowIndex
    {count rows publicCount evalCount pointVars : Nat}
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) : Nat :=
  match index with
  | .challengeBinding row => row.val
  | .foldedPoint coordinate => count + coordinate.val
  | .parentPoint claimIndex coordinate =>
      count + pointVars + claimIndex.val * pointVars + coordinate.val
  | .commitmentCombination row =>
      count + pointVars + count * pointVars + row.val
  | .publicInputCombination coordinate =>
      count + pointVars + count * pointVars + rows + coordinate.val
  | .evaluationCombination coordinate =>
      count + pointVars + count * pointVars + rows + publicCount +
        coordinate.val

theorem pirlcSchedule_globalRowIndex_injective
    {count rows publicCount evalCount pointVars : Nat} :
    Function.Injective
      (PiRLCScheduleIndex.globalRowIndex
        (count := count)
        (rows := rows)
        (publicCount := publicCount)
        (evalCount := evalCount)
        (pointVars := pointVars)) := by
  intro lhs rhs hIndex
  cases lhs <;> cases rhs <;>
    simp [PiRLCScheduleIndex.globalRowIndex] at hIndex ⊢ <;>
    try omega
  case parentPoint.parentPoint claimL coordL claimR coordR =>
      have hPair :
          claimL.val * pointVars + coordL.val =
            claimR.val * pointVars + coordR.val := by
        omega
      exact finPairRowMajor_eq_of_eq hPair
  case parentPoint.commitmentCombination claim coord row =>
      have hParentBound :
          claim.val * pointVars + coord.val < count * pointVars :=
        finPairRowMajor_lt_product claim coord
      omega
  case parentPoint.publicInputCombination claim coord publicCoord =>
      have hParentBound :
          claim.val * pointVars + coord.val < count * pointVars :=
        finPairRowMajor_lt_product claim coord
      omega
  case parentPoint.evaluationCombination claim coord evalCoord =>
      have hParentBound :
          claim.val * pointVars + coord.val < count * pointVars :=
        finPairRowMajor_lt_product claim coord
      omega
  case commitmentCombination.parentPoint row claim coord =>
      have hParentBound :
          claim.val * pointVars + coord.val < count * pointVars :=
        finPairRowMajor_lt_product claim coord
      omega
  case publicInputCombination.parentPoint publicCoord claim coord =>
      have hParentBound :
          claim.val * pointVars + coord.val < count * pointVars :=
        finPairRowMajor_lt_product claim coord
      omega
  case evaluationCombination.parentPoint evalCoord claim coord =>
      have hParentBound :
          claim.val * pointVars + coord.val < count * pointVars :=
        finPairRowMajor_lt_product claim coord
      omega

def PiRLCScheduleIndex.toScheduledRowRef
    {count rows publicCount evalCount pointVars : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    TerminalAIRScheduledRowRef where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKindCode := PiRLCPrimitiveRowKind.localCode index.rowKind
  globalRowIndex := index.globalRowIndex
  localRowIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

theorem pirlcSchedule_scheduledRowRef_subrelation
    {count rows publicCount evalCount pointVars : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    (PiRLCScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .piRLCVerifier :=
  rfl

theorem pirlcProductionPackedLayout_subrelation_matches_rowRef
    {count rows publicCount evalCount pointVars : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    (PiRLCScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        (terminalAIRPiRLCProductionPackedLayout
          subrelationStartIndex digestFieldCount).subrelationKind :=
  rfl

theorem pirlcProductionPackedLayout_observedResidualIndex
    {count rows publicCount evalCount pointVars : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    (terminalAIRPiRLCProductionPackedLayout
      subrelationStartIndex digestFieldCount).observedResidualIndex
        (PiRLCScheduleIndex.toScheduledRowRef
          publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount index) =
      subrelationStartIndex +
        terminalAIRPiRLCPrimitiveRowsStartIndex digestFieldCount +
          index.globalRowIndex *
            (terminalAIRPiRLCProductionPackedLayout
              subrelationStartIndex digestFieldCount).rowBlockWidth +
              (terminalAIRPiRLCProductionPackedLayout
                subrelationStartIndex digestFieldCount).observedResidualOffset :=
  rfl

theorem pirlcSchedule_no_ambiguous_row_kind
    {count rows publicCount evalCount pointVars : Nat}
    {lhs rhs :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars}
    (hConcrete :
      PiRLCScheduleIndex.toConcreteIndex lhs =
        PiRLCScheduleIndex.toConcreteIndex rhs) :
    lhs = rhs ∧ lhs.rowKind = rhs.rowKind := by
  have hEq := pirlcSchedule_no_duplicate_row_index hConcrete
  exact ⟨hEq, by rw [hEq]⟩

def PiRLCConcreteAIRRowObservedValue
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    RF :=
  match index with
  | .challengeBinding row => (air.challengeBindingRow row).derivedChallenge
  | .foldedPoint coordinate => (air.foldedPointRow coordinate).observedPoint
  | .parentPoint claimIndex coordinate =>
      (air.parentPointRow claimIndex coordinate).observedPoint
  | .commitmentCombination row => (air.commitmentCombinationRow row).target
  | .publicInputCombination coordinate =>
      (air.publicInputCombinationRow coordinate).target
  | .evaluationCombination coordinate =>
      (air.evaluationCombinationRow coordinate).target

def PiRLCConcreteAIRRowExpectedValue
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index :
      PiRLCConcreteAIRRowIndex count rows publicCount evalCount pointVars) :
    RF :=
  match index with
  | .challengeBinding row => (air.challengeBindingRow row).boundChallenge
  | .foldedPoint coordinate => (air.foldedPointRow coordinate).expectedPoint
  | .parentPoint claimIndex coordinate =>
      (air.parentPointRow claimIndex coordinate).expectedPoint
  | .commitmentCombination row =>
      rlcWeightedSum
        (air.commitmentCombinationRow row).challenges
        (air.commitmentCombinationRow row).parts
  | .publicInputCombination coordinate =>
      rlcWeightedSum
        (air.publicInputCombinationRow coordinate).challenges
        (air.publicInputCombinationRow coordinate).parts
  | .evaluationCombination coordinate =>
      rlcWeightedSum
        (air.evaluationCombinationRow coordinate).challenges
        (air.evaluationCombinationRow coordinate).parts

structure PiRLCScheduledRowTranscript
    (RF : Type) [CommRing RF]
    (count rows publicCount evalCount pointVars : Nat) where
  provenance : TerminalAIRRowProvenance
  subrelationKind : TerminalAIRSubrelationKind
  rowKind : PiRLCPrimitiveRowKind
  rowIndex : PiRLCScheduleIndex count rows publicCount evalCount pointVars
  localIndex : Nat
  coordinateIndex? : Option Nat
  observedValue : RF
  expectedValue : RF
  residual : PiRLCAIRResidualValue RF
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

def PiRLCScheduledRowTranscript.ofScheduleIndex
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    PiRLCScheduledRowTranscript RF count rows publicCount evalCount pointVars where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKind := index.rowKind
  rowIndex := index
  localIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  observedValue :=
    PiRLCConcreteAIRRowObservedValue air index.toConcreteIndex
  expectedValue :=
    PiRLCConcreteAIRRowExpectedValue air index.toConcreteIndex
  residual :=
    PiRLCConcreteAIRRowResidual air index.toConcreteIndex
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

def PiRLCScheduledRowTranscript.toScheduledRowRef
    {count rows publicCount evalCount pointVars : Nat}
    (globalRowIndex : Nat)
    (row :
      PiRLCScheduledRowTranscript
        RF count rows publicCount evalCount pointVars) :
    TerminalAIRScheduledRowRef where
  provenance := row.provenance
  subrelationKind := row.subrelationKind
  rowKindCode := PiRLCPrimitiveRowKind.localCode row.rowKind
  globalRowIndex := globalRowIndex
  localRowIndex := row.localIndex
  coordinateIndex? := row.coordinateIndex?
  publicBindingContext := row.publicBindingContext
  terminalVerifierRelationDigest := row.terminalVerifierRelationDigest
  recursiveRelationDigest := row.recursiveRelationDigest
  sourceDigest := row.sourceDigest
  sourceByteCount := row.sourceByteCount

theorem pirlcScheduledRow_subrelation_piRLC
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    (PiRLCScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .piRLCVerifier :=
  rfl

theorem pirlcScheduledRow_residual_eq_concrete
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    (PiRLCScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual =
        PiRLCConcreteAIRRowResidual air index.toConcreteIndex :=
  rfl

def PiRLCScheduledAIRAllRowsZero
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) : Prop :=
  ∀ index : PiRLCScheduleIndex count rows publicCount evalCount pointVars,
    (PiRLCScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual = 0

theorem pirlcScheduledAIR_allRowsZero_iff_concreteAllRowsZero
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    PiRLCScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      PiRLCConcreteAIRAllRowsZero air := by
  constructor
  · intro hScheduled concreteIndex
    have hScheduledIndex :
        (PiRLCScheduledRowTranscript.ofScheduleIndex
          air publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount
          (PiRLCScheduleIndex.fromConcreteIndex concreteIndex)).residual = 0 :=
      hScheduled (PiRLCScheduleIndex.fromConcreteIndex concreteIndex)
    simpa [PiRLCScheduledRowTranscript.ofScheduleIndex,
      pirlcSchedule_toConcrete_fromConcrete concreteIndex] using hScheduledIndex
  · intro hConcrete scheduledIndex
    simpa [PiRLCScheduledRowTranscript.ofScheduleIndex] using
      hConcrete scheduledIndex.toConcreteIndex

theorem pirlcScheduledAIR_allRowsZero_iff_verifierStep
    {count rows publicCount evalCount pointVars : Nat}
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    PiRLCScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      PiRLCConcreteVerifierStep air := by
  rw [pirlcScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  exact pirlcConcreteAIR_allRowsZero_iff_verifierStep air

inductive PiDECScheduleIndex
    (rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat) where
  | signedDigitBound :
      Fin signedDigitCount →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  | baseBDecomposition :
      Fin decompositionCount →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  | messageRecomposition :
      Fin columns →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  | commitmentEvaluation :
      Fin rows →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  | commitmentRecomposition :
      Fin rows →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  | publicInputSplit :
      Fin publicSplitCount →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  | lowNorm :
      Fin lowNormCount →
        PiDECScheduleIndex rows columns signedDigitCount decompositionCount
          publicSplitCount lowNormCount
  deriving DecidableEq

def PiDECScheduleIndex.toConcreteIndex
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat} :
    PiDECScheduleIndex rows columns signedDigitCount decompositionCount
      publicSplitCount lowNormCount →
      PiDECConcreteAIRRowIndex rows columns
        (Fin signedDigitCount) (Fin decompositionCount) (Fin publicSplitCount)
        (Fin lowNormCount)
  | .signedDigitBound row => .signedDigitBound row
  | .baseBDecomposition row => .baseBDecomposition row
  | .messageRecomposition coordinate => .messageRecomposition coordinate
  | .commitmentEvaluation row => .commitmentEvaluation row
  | .commitmentRecomposition row => .commitmentRecomposition row
  | .publicInputSplit row => .publicInputSplit row
  | .lowNorm row => .lowNorm row

def PiDECScheduleIndex.fromConcreteIndex
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat} :
    PiDECConcreteAIRRowIndex rows columns
        (Fin signedDigitCount) (Fin decompositionCount) (Fin publicSplitCount)
        (Fin lowNormCount) →
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount
  | .signedDigitBound row => .signedDigitBound row
  | .baseBDecomposition row => .baseBDecomposition row
  | .messageRecomposition coordinate => .messageRecomposition coordinate
  | .commitmentEvaluation row => .commitmentEvaluation row
  | .commitmentRecomposition row => .commitmentRecomposition row
  | .publicInputSplit row => .publicInputSplit row
  | .lowNorm row => .lowNorm row

theorem pidecSchedule_toConcrete_fromConcrete
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECConcreteAIRRowIndex rows columns
        (Fin signedDigitCount) (Fin decompositionCount) (Fin publicSplitCount)
        (Fin lowNormCount)) :
    PiDECScheduleIndex.toConcreteIndex
        (PiDECScheduleIndex.fromConcreteIndex index) = index := by
  cases index <;> rfl

theorem pidecSchedule_fromConcrete_toConcrete
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    PiDECScheduleIndex.fromConcreteIndex
        (PiDECScheduleIndex.toConcreteIndex index) = index := by
  cases index <;> rfl

theorem pidecSchedule_no_missing_required_row
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECConcreteAIRRowIndex rows columns
        (Fin signedDigitCount) (Fin decompositionCount) (Fin publicSplitCount)
        (Fin lowNormCount)) :
    ∃ scheduled :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount,
      PiDECScheduleIndex.toConcreteIndex scheduled = index :=
  ⟨PiDECScheduleIndex.fromConcreteIndex index,
    pidecSchedule_toConcrete_fromConcrete index⟩

theorem pidecSchedule_no_duplicate_row_index
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat} :
    Function.Injective
      (PiDECScheduleIndex.toConcreteIndex
        (rows := rows)
        (columns := columns)
        (signedDigitCount := signedDigitCount)
        (decompositionCount := decompositionCount)
        (publicSplitCount := publicSplitCount)
        (lowNormCount := lowNormCount)) := by
  intro lhs rhs hConcrete
  rw [← pidecSchedule_fromConcrete_toConcrete lhs]
  rw [← pidecSchedule_fromConcrete_toConcrete rhs]
  rw [hConcrete]

def PiDECScheduleIndex.rowKind
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) : PiDECPrimitiveRowKind :=
  match index with
  | .signedDigitBound _ => .signedDigitBound
  | .baseBDecomposition _ => .baseBDecomposition
  | .messageRecomposition _ => .messageRecomposition
  | .commitmentEvaluation _ => .commitmentEvaluation
  | .commitmentRecomposition _ => .commitmentRecomposition
  | .publicInputSplit _ => .publicInputSplit
  | .lowNorm _ => .lowNorm

def PiDECScheduleIndex.localIndex
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) : Nat :=
  match index with
  | .signedDigitBound row => row.val
  | .baseBDecomposition row => row.val
  | .messageRecomposition coordinate => coordinate.val
  | .commitmentEvaluation row => row.val
  | .commitmentRecomposition row => row.val
  | .publicInputSplit row => row.val
  | .lowNorm row => row.val

def PiDECScheduleIndex.coordinateIndex?
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) : Option Nat :=
  match index with
  | .messageRecomposition coordinate => some coordinate.val
  | .commitmentEvaluation row => some row.val
  | .commitmentRecomposition row => some row.val
  | _ => none

def PiDECScheduleIndex.provenance
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (_index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) : TerminalAIRRowProvenance :=
  .primitiveArithmetic

def PiDECScheduleIndex.subrelationKind
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (_index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) : TerminalAIRSubrelationKind :=
  .piDECVerifier

def PiDECScheduleIndex.globalRowIndex
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) : Nat :=
  match index with
  | .signedDigitBound row => row.val
  | .baseBDecomposition row => signedDigitCount + row.val
  | .messageRecomposition coordinate =>
      signedDigitCount + decompositionCount + coordinate.val
  | .commitmentEvaluation row =>
      signedDigitCount + decompositionCount + columns + row.val
  | .commitmentRecomposition row =>
      signedDigitCount + decompositionCount + columns + rows + row.val
  | .publicInputSplit row =>
      signedDigitCount + decompositionCount + columns + rows + rows + row.val
  | .lowNorm row =>
      signedDigitCount + decompositionCount + columns + rows + rows +
        publicSplitCount + row.val

theorem pidecSchedule_globalRowIndex_injective
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat} :
    Function.Injective
      (PiDECScheduleIndex.globalRowIndex
        (rows := rows)
        (columns := columns)
        (signedDigitCount := signedDigitCount)
        (decompositionCount := decompositionCount)
        (publicSplitCount := publicSplitCount)
        (lowNormCount := lowNormCount)) := by
  intro lhs rhs hIndex
  cases lhs <;> cases rhs <;>
    simp [PiDECScheduleIndex.globalRowIndex] at hIndex ⊢ <;>
    omega

def PiDECScheduleIndex.toScheduledRowRef
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    TerminalAIRScheduledRowRef where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKindCode := PiDECPrimitiveRowKind.localCode index.rowKind
  globalRowIndex := index.globalRowIndex
  localRowIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

theorem pidecSchedule_scheduledRowRef_subrelation
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    (PiDECScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .piDECVerifier :=
  rfl

theorem pidecProductionPackedLayout_subrelation_matches_rowRef
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    (PiDECScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        (terminalAIRPiDECProductionPackedLayout
          subrelationStartIndex digestFieldCount).subrelationKind :=
  rfl

theorem pidecProductionPackedLayout_observedResidualIndex
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    (terminalAIRPiDECProductionPackedLayout
      subrelationStartIndex digestFieldCount).observedResidualIndex
        (PiDECScheduleIndex.toScheduledRowRef
          publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount index) =
      subrelationStartIndex +
        terminalAIRPiDECPrimitiveRowsStartIndex digestFieldCount +
          index.globalRowIndex *
            (terminalAIRPiDECProductionPackedLayout
              subrelationStartIndex digestFieldCount).rowBlockWidth +
              (terminalAIRPiDECProductionPackedLayout
                subrelationStartIndex digestFieldCount).observedResidualOffset :=
  rfl

theorem pidecSchedule_no_ambiguous_row_kind
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    {lhs rhs :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount}
    (hConcrete :
      PiDECScheduleIndex.toConcreteIndex lhs =
        PiDECScheduleIndex.toConcreteIndex rhs) :
    lhs = rhs ∧ lhs.rowKind = rhs.rowKind := by
  have hEq := pidecSchedule_no_duplicate_row_index hConcrete
  exact ⟨hEq, by rw [hEq]⟩

abbrev PiDECScheduledAIRRows
    (RF : Type) [CommRing RF]
    (rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat) :=
  PiDECConcreteAIRRows RF rows columns count
    (Fin signedDigitCount) (Fin decompositionCount) (Fin publicSplitCount)
    (Fin lowNormCount)

def PiDECConcreteAIRRowObservedValue
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (index :
      PiDECConcreteAIRRowIndex rows columns
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) : RF :=
  match index with
  | .signedDigitBound _ => 0
  | .baseBDecomposition row => (air.baseBDecompositionRow row).value
  | .messageRecomposition coordinate =>
      (air.messageRecompositionRow coordinate).target
  | .commitmentEvaluation row =>
      (air.commitmentEvaluationRow row).target
  | .commitmentRecomposition row =>
      (air.commitmentRecompositionRow row).target
  | .publicInputSplit row => (air.publicInputSplitRow row).combined
  | .lowNorm _ => 0

def PiDECConcreteAIRRowExpectedValue
    {rows columns count : Nat}
    {SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex : Type}
    (air :
      PiDECConcreteAIRRows RF rows columns count
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex)
    (index :
      PiDECConcreteAIRRowIndex rows columns
        SignedDigitIndex DecompositionIndex PublicSplitIndex LowNormIndex) : RF :=
  match index with
  | .signedDigitBound _ => 0
  | .baseBDecomposition row =>
      pidecWeightedSum
        (air.baseBDecompositionRow row).base
        (air.baseBDecompositionRow row).digits
  | .messageRecomposition coordinate =>
      pidecWeightedSum
        (air.messageRecompositionRow coordinate).base
        (air.messageRecompositionRow coordinate).parts
  | .commitmentEvaluation row =>
      ∑ column : Fin columns,
        (air.commitmentEvaluationRow row).matrixRow column *
          (air.commitmentEvaluationRow row).witness column
  | .commitmentRecomposition row =>
      pidecWeightedSum
        (air.commitmentRecompositionRow row).base
        (air.commitmentRecompositionRow row).parts
  | .publicInputSplit row =>
      (air.publicInputSplitRow row).left + (air.publicInputSplitRow row).right
  | .lowNorm _ => 0

structure PiDECScheduledRowTranscript
    (RF : Type) [CommRing RF]
    (rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat) where
  provenance : TerminalAIRRowProvenance
  subrelationKind : TerminalAIRSubrelationKind
  rowKind : PiDECPrimitiveRowKind
  rowIndex :
    PiDECScheduleIndex rows columns signedDigitCount decompositionCount
      publicSplitCount lowNormCount
  localIndex : Nat
  coordinateIndex? : Option Nat
  observedValue : RF
  expectedValue : RF
  residual : PiDECAIRResidualValue RF
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

def PiDECScheduledRowTranscript.ofScheduleIndex
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    PiDECScheduledRowTranscript RF rows columns signedDigitCount
      decompositionCount publicSplitCount lowNormCount where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKind := index.rowKind
  rowIndex := index
  localIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  observedValue :=
    PiDECConcreteAIRRowObservedValue air index.toConcreteIndex
  expectedValue :=
    PiDECConcreteAIRRowExpectedValue air index.toConcreteIndex
  residual :=
    PiDECConcreteAIRRowResidual air index.toConcreteIndex
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

def PiDECScheduledRowTranscript.toScheduledRowRef
    {rows columns signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (globalRowIndex : Nat)
    (row :
      PiDECScheduledRowTranscript
        RF rows columns signedDigitCount decompositionCount publicSplitCount
        lowNormCount) :
    TerminalAIRScheduledRowRef where
  provenance := row.provenance
  subrelationKind := row.subrelationKind
  rowKindCode := PiDECPrimitiveRowKind.localCode row.rowKind
  globalRowIndex := globalRowIndex
  localRowIndex := row.localIndex
  coordinateIndex? := row.coordinateIndex?
  publicBindingContext := row.publicBindingContext
  terminalVerifierRelationDigest := row.terminalVerifierRelationDigest
  recursiveRelationDigest := row.recursiveRelationDigest
  sourceDigest := row.sourceDigest
  sourceByteCount := row.sourceByteCount

theorem pidecScheduledRow_subrelation_piDEC
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    (PiDECScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .piDECVerifier :=
  rfl

theorem pidecScheduledRow_residual_eq_concrete
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    (PiDECScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual =
        PiDECConcreteAIRRowResidual air index.toConcreteIndex :=
  rfl

def PiDECScheduledAIRAllRowsZero
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) : Prop :=
  ∀ index :
    PiDECScheduleIndex rows columns signedDigitCount decompositionCount
      publicSplitCount lowNormCount,
    (PiDECScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual = 0

theorem pidecScheduledAIR_allRowsZero_iff_concreteAllRowsZero
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    PiDECScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      PiDECConcreteAIRAllRowsZero air := by
  constructor
  · intro hScheduled concreteIndex
    have hScheduledIndex :
        (PiDECScheduledRowTranscript.ofScheduleIndex
          air publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount
          (PiDECScheduleIndex.fromConcreteIndex concreteIndex)).residual = 0 :=
      hScheduled (PiDECScheduleIndex.fromConcreteIndex concreteIndex)
    simpa [PiDECScheduledRowTranscript.ofScheduleIndex,
      pidecSchedule_toConcrete_fromConcrete concreteIndex] using hScheduledIndex
  · intro hConcrete scheduledIndex
    simpa [PiDECScheduledRowTranscript.ofScheduleIndex] using
      hConcrete scheduledIndex.toConcreteIndex

theorem pidecScheduledAIR_allRowsZero_iff_verifierStep
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    PiDECScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      PiDECConcreteVerifierStep air := by
  rw [pidecScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  exact pidecConcreteAIR_allRowsZero_iff_verifierStep air

def CEAjtaiPrimitiveConstraints
    {rows columns publicCount evalCount pointVars : Nat}
    (shape : CEOpeningShape)
    (context : CEOpeningPublicContext)
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop)
    (publicBound : RF → Prop)
    (evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop)
    (statement : CELocalStatement RF rows publicCount evalCount pointVars)
    (witness : Message RF columns) : Prop :=
  CEOpeningShapeCompatible shape rows columns publicCount evalCount pointVars ∧
    statement.context = context ∧
      CEPublicInputBounded publicBound statement ∧
        bounded witness ∧
          commit A witness = statement.claim.commitment ∧
            evaluationRelation witness statement.claim.point statement.claim.evaluations

theorem ceAjtaiPrimitiveConstraints_iff_localOpeningRelation
    {rows columns publicCount evalCount pointVars : Nat}
    (shape : CEOpeningShape)
    (context : CEOpeningPublicContext)
    (A : AjtaiMatrix RF rows columns)
    (bounded : Message RF columns → Prop)
    (publicBound : RF → Prop)
    (evaluationRelation :
      Message RF columns →
        ProtocolVector RF pointVars →
        ProtocolVector RF evalCount →
        Prop)
    (statement : CELocalStatement RF rows publicCount evalCount pointVars)
    (witness : Message RF columns) :
    CEAjtaiPrimitiveConstraints
      shape context A bounded publicBound evaluationRelation statement witness ↔
      CELocalOpeningRelation
        shape context A bounded publicBound evaluationRelation statement witness := by
  constructor
  · intro hConstraints
    rcases hConstraints with
      ⟨hShape, hContext, hPublic, hBounded, hCommitment, hEvaluation⟩
    exact ⟨hShape, hContext, hPublic, hBounded, hCommitment, hEvaluation⟩
  · intro hOpening
    rcases hOpening with
      ⟨hShape, hContext, hPublic, hBounded, hCommitment, hEvaluation⟩
    exact ⟨hShape, hContext, hPublic, hBounded, hCommitment, hEvaluation⟩

structure CEAjtaiAIRResidualValue (RF : Type) where
  field : RF
  guard : Nat

instance [Zero RF] : Zero (CEAjtaiAIRResidualValue RF) :=
  ⟨{ field := 0, guard := 0 }⟩

def CEAjtaiFieldResidual [Sub RF]
    (lhs rhs : RF) : CEAjtaiAIRResidualValue RF :=
  { field := lhs - rhs, guard := 0 }

def CEAjtaiGuardResidual [Zero RF]
    (condition : Prop) [Decidable condition] : CEAjtaiAIRResidualValue RF :=
  { field := 0, guard := if condition then 0 else 1 }

omit [CommRing RF] in
theorem ceAjtaiFieldResidual_zero_iff [CommRing RF]
    {lhs rhs : RF} :
    CEAjtaiFieldResidual lhs rhs = 0 ↔ lhs = rhs := by
  constructor
  · intro hZero
    have hField : lhs - rhs = 0 := by
      simpa [CEAjtaiFieldResidual] using
        congrArg CEAjtaiAIRResidualValue.field hZero
    exact sub_eq_zero.mp hField
  · intro hEq
    rw [hEq]
    change
      ({ field := rhs - rhs, guard := 0 } : CEAjtaiAIRResidualValue RF) =
        { field := 0, guard := 0 }
    simp

omit [CommRing RF] in
theorem ceAjtaiGuardResidual_zero_iff [Zero RF]
    {condition : Prop} [Decidable condition] :
    CEAjtaiGuardResidual (RF := RF) condition = 0 ↔ condition := by
  by_cases hCondition : condition
  · constructor
    · intro _hZero
      exact hCondition
    · intro _hCondition
      unfold CEAjtaiGuardResidual
      rw [if_pos hCondition]
      change
        ({ field := 0, guard := 0 } : CEAjtaiAIRResidualValue RF) =
          { field := 0, guard := 0 }
      rfl
  · constructor
    · intro hZero
      have hGuard : (1 : Nat) = 0 := by
        simpa [CEAjtaiGuardResidual, hCondition] using
          congrArg CEAjtaiAIRResidualValue.guard hZero
      exact False.elim ((Nat.succ_ne_zero 0) hGuard)
    · intro h
      exact False.elim (hCondition h)

structure CEAjtaiNatEqualityRow where
  observed : Nat
  expected : Nat

def CEAjtaiNatEqualityRowHolds (row : CEAjtaiNatEqualityRow) : Prop :=
  row.observed = row.expected

def CEAjtaiNatEqualityRowResidual [Zero RF]
    (row : CEAjtaiNatEqualityRow) : CEAjtaiAIRResidualValue RF :=
  CEAjtaiGuardResidual (RF := RF)
    (condition := row.observed = row.expected)

omit [CommRing RF] in
theorem ceAjtaiNatEqualityRowResidual_zero_iff [Zero RF]
    (row : CEAjtaiNatEqualityRow) :
    CEAjtaiNatEqualityRowResidual (RF := RF) row = 0 ↔
      CEAjtaiNatEqualityRowHolds row :=
  ceAjtaiGuardResidual_zero_iff

structure CEAjtaiFieldEqualityRow (RF : Type) where
  observed : RF
  expected : RF

def CEAjtaiFieldEqualityRowHolds
    (row : CEAjtaiFieldEqualityRow RF) : Prop :=
  row.observed = row.expected

def CEAjtaiFieldEqualityRowResidual
    (row : CEAjtaiFieldEqualityRow RF) : CEAjtaiAIRResidualValue RF :=
  CEAjtaiFieldResidual row.observed row.expected

theorem ceAjtaiFieldEqualityRowResidual_zero_iff
    (row : CEAjtaiFieldEqualityRow RF) :
    CEAjtaiFieldEqualityRowResidual row = 0 ↔
      CEAjtaiFieldEqualityRowHolds row :=
  ceAjtaiFieldResidual_zero_iff

structure CEAjtaiGuardRow where
  condition : Prop
  decidableCondition : Decidable condition

def CEAjtaiGuardRowHolds (row : CEAjtaiGuardRow) : Prop :=
  row.condition

def CEAjtaiGuardRowResidual [Zero RF]
    (row : CEAjtaiGuardRow) : CEAjtaiAIRResidualValue RF :=
  letI := row.decidableCondition
  CEAjtaiGuardResidual (RF := RF) row.condition

omit [CommRing RF] in
theorem ceAjtaiGuardRowResidual_zero_iff [Zero RF]
    (row : CEAjtaiGuardRow) :
    CEAjtaiGuardRowResidual (RF := RF) row = 0 ↔
      CEAjtaiGuardRowHolds row := by
  letI := row.decidableCondition
  exact ceAjtaiGuardResidual_zero_iff

structure CEAjtaiCommitmentRecompositionRow
    (RF : Type) [CommRing RF]
    (columns : Nat) where
  target : RF
  matrixRow : Fin columns → RF
  witness : Message RF columns

def CEAjtaiCommitmentRecompositionRowHolds
    {columns : Nat}
    (row : CEAjtaiCommitmentRecompositionRow RF columns) : Prop :=
  row.target = ∑ column : Fin columns, row.matrixRow column * row.witness column

def CEAjtaiCommitmentRecompositionRowResidual
    {columns : Nat}
    (row : CEAjtaiCommitmentRecompositionRow RF columns) :
    CEAjtaiAIRResidualValue RF :=
  CEAjtaiFieldResidual
    row.target
    (∑ column : Fin columns, row.matrixRow column * row.witness column)

theorem ceAjtaiCommitmentRecompositionRowResidual_zero_iff
    {columns : Nat}
    (row : CEAjtaiCommitmentRecompositionRow RF columns) :
    CEAjtaiCommitmentRecompositionRowResidual row = 0 ↔
      CEAjtaiCommitmentRecompositionRowHolds row :=
  ceAjtaiFieldResidual_zero_iff

structure CEAjtaiConcreteAIRRows
    (RF : Type) [CommRing RF]
    (rows columns publicCount evalCount pointVars : Nat) where
  shape : CEOpeningShape
  context : CEOpeningPublicContext
  A : AjtaiMatrix RF rows columns
  bounded : Message RF columns → Prop
  publicBound : RF → Prop
  evaluationRelation :
    Message RF columns →
      ProtocolVector RF pointVars →
      ProtocolVector RF evalCount →
      Prop
  statement : CELocalStatement RF rows publicCount evalCount pointVars
  witness : Message RF columns
  witnessBoundedDecidable : Decidable (bounded witness)
  publicBoundDecidable :
    (index : Fin publicCount) →
      Decidable (publicBound (statement.claim.publicInput index))
  evaluationRelationDecidable :
    Decidable
      (evaluationRelation witness statement.claim.point statement.claim.evaluations)

inductive CEAjtaiConcreteAIRRowIndex
    (rows columns publicCount evalCount pointVars : Nat) where
  | shapeRows :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | shapeColumns :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | shapePublicCount :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | shapeEvalCount :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | shapePointVars :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | contextProfileID :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | contextShapeDigest :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | contextVerifierKeyDigest :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | publicInputBound :
      Fin publicCount →
        CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | witnessBound :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | commitmentRecomposition :
      Fin rows →
        CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | evaluationRelation :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars

def CEAjtaiConcreteAIRRows.shapeRowsRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.shape.rows
  expected := rows

def CEAjtaiConcreteAIRRows.shapeColumnsRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.shape.columns
  expected := columns

def CEAjtaiConcreteAIRRows.shapePublicCountRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.shape.publicCount
  expected := publicCount

def CEAjtaiConcreteAIRRows.shapeEvalCountRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.shape.evalCount
  expected := evalCount

def CEAjtaiConcreteAIRRows.shapePointVarsRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.shape.pointVars
  expected := pointVars

def CEAjtaiConcreteAIRRows.contextProfileIDRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.statement.context.profileID
  expected := air.context.profileID

def CEAjtaiConcreteAIRRows.contextShapeDigestRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.statement.context.shapeDigest
  expected := air.context.shapeDigest

def CEAjtaiConcreteAIRRows.contextVerifierKeyDigestRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiNatEqualityRow where
  observed := air.statement.context.verifierKeyDigest
  expected := air.context.verifierKeyDigest

def CEAjtaiConcreteAIRRows.publicInputBoundRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index : Fin publicCount) : CEAjtaiGuardRow where
  condition := air.publicBound (air.statement.claim.publicInput index)
  decidableCondition := air.publicBoundDecidable index

def CEAjtaiConcreteAIRRows.witnessBoundRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiGuardRow where
  condition := air.bounded air.witness
  decidableCondition := air.witnessBoundedDecidable

def CEAjtaiConcreteAIRRows.commitmentRecompositionRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (row : Fin rows) : CEAjtaiCommitmentRecompositionRow RF columns where
  target := air.statement.claim.commitment row
  matrixRow := air.A row
  witness := air.witness

def CEAjtaiConcreteAIRRows.evaluationRelationRow
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiGuardRow where
  condition :=
    air.evaluationRelation air.witness
      air.statement.claim.point air.statement.claim.evaluations
  decidableCondition := air.evaluationRelationDecidable

def CEAjtaiConcreteAIRRowResidual
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiAIRResidualValue RF :=
  match index with
  | .shapeRows =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.shapeRowsRow
  | .shapeColumns =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.shapeColumnsRow
  | .shapePublicCount =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.shapePublicCountRow
  | .shapeEvalCount =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.shapeEvalCountRow
  | .shapePointVars =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.shapePointVarsRow
  | .contextProfileID =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.contextProfileIDRow
  | .contextShapeDigest =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.contextShapeDigestRow
  | .contextVerifierKeyDigest =>
      CEAjtaiNatEqualityRowResidual (RF := RF) air.contextVerifierKeyDigestRow
  | .publicInputBound index =>
      CEAjtaiGuardRowResidual (RF := RF) (air.publicInputBoundRow index)
  | .witnessBound =>
      CEAjtaiGuardRowResidual (RF := RF) air.witnessBoundRow
  | .commitmentRecomposition row =>
      CEAjtaiCommitmentRecompositionRowResidual
        (air.commitmentRecompositionRow row)
  | .evaluationRelation =>
      CEAjtaiGuardRowResidual (RF := RF) air.evaluationRelationRow

def CEAjtaiConcreteAIRRowHolds
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    Prop :=
  match index with
  | .shapeRows => CEAjtaiNatEqualityRowHolds air.shapeRowsRow
  | .shapeColumns => CEAjtaiNatEqualityRowHolds air.shapeColumnsRow
  | .shapePublicCount => CEAjtaiNatEqualityRowHolds air.shapePublicCountRow
  | .shapeEvalCount => CEAjtaiNatEqualityRowHolds air.shapeEvalCountRow
  | .shapePointVars => CEAjtaiNatEqualityRowHolds air.shapePointVarsRow
  | .contextProfileID => CEAjtaiNatEqualityRowHolds air.contextProfileIDRow
  | .contextShapeDigest => CEAjtaiNatEqualityRowHolds air.contextShapeDigestRow
  | .contextVerifierKeyDigest =>
      CEAjtaiNatEqualityRowHolds air.contextVerifierKeyDigestRow
  | .publicInputBound index => CEAjtaiGuardRowHolds (air.publicInputBoundRow index)
  | .witnessBound => CEAjtaiGuardRowHolds air.witnessBoundRow
  | .commitmentRecomposition row =>
      CEAjtaiCommitmentRecompositionRowHolds
        (air.commitmentRecompositionRow row)
  | .evaluationRelation => CEAjtaiGuardRowHolds air.evaluationRelationRow

theorem ceAjtaiConcreteAIRRowResidual_zero_iff_holds
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiConcreteAIRRowResidual air index = 0 ↔
      CEAjtaiConcreteAIRRowHolds air index := by
  cases index with
  | shapeRows =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.shapeRowsRow
  | shapeColumns =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.shapeColumnsRow
  | shapePublicCount =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.shapePublicCountRow
  | shapeEvalCount =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.shapeEvalCountRow
  | shapePointVars =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.shapePointVarsRow
  | contextProfileID =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.contextProfileIDRow
  | contextShapeDigest =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.contextShapeDigestRow
  | contextVerifierKeyDigest =>
      exact ceAjtaiNatEqualityRowResidual_zero_iff (RF := RF)
        air.contextVerifierKeyDigestRow
  | publicInputBound index =>
      exact ceAjtaiGuardRowResidual_zero_iff (RF := RF)
        (air.publicInputBoundRow index)
  | witnessBound =>
      exact ceAjtaiGuardRowResidual_zero_iff (RF := RF)
        air.witnessBoundRow
  | commitmentRecomposition row =>
      exact ceAjtaiCommitmentRecompositionRowResidual_zero_iff
        (air.commitmentRecompositionRow row)
  | evaluationRelation =>
      exact ceAjtaiGuardRowResidual_zero_iff (RF := RF)
        air.evaluationRelationRow

def CEAjtaiConcreteAIRAllRowsZero
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    Prop :=
  ∀ index, CEAjtaiConcreteAIRRowResidual air index = 0

def CEAjtaiConcreteAIRAllRowsHold
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    Prop :=
  ∀ index, CEAjtaiConcreteAIRRowHolds air index

theorem ceAjtaiConcreteAIR_allRowsZero_iff_allRowsHold
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiConcreteAIRAllRowsZero air ↔
      CEAjtaiConcreteAIRAllRowsHold air := by
  constructor
  · intro hZero index
    exact (ceAjtaiConcreteAIRRowResidual_zero_iff_holds air index).mp
      (hZero index)
  · intro hHold index
    exact (ceAjtaiConcreteAIRRowResidual_zero_iff_holds air index).mpr
      (hHold index)

def CEAjtaiConcreteVerifierStep
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    Prop :=
  CELocalOpeningRelation
    air.shape
    air.context
    air.A
    air.bounded
    air.publicBound
    air.evaluationRelation
    air.statement
    air.witness

theorem ceAjtaiConcreteAIR_allRowsZero_iff_verifierStep
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars) :
    CEAjtaiConcreteAIRAllRowsZero air ↔
      CEAjtaiConcreteVerifierStep air := by
  constructor
  · intro hZero
    have hHold : CEAjtaiConcreteAIRAllRowsHold air :=
      (ceAjtaiConcreteAIR_allRowsZero_iff_allRowsHold air).mp hZero
    have hShape :
        CEOpeningShapeCompatible
          air.shape rows columns publicCount evalCount pointVars :=
      ⟨hHold .shapeRows, hHold .shapeColumns,
        hHold .shapePublicCount, hHold .shapeEvalCount,
        hHold .shapePointVars⟩
    have hContext : air.statement.context = air.context := by
      have hContextProfileID :
          air.statement.context.profileID = air.context.profileID := by
        simpa [CEAjtaiConcreteAIRRowHolds,
          CEAjtaiConcreteAIRRows.contextProfileIDRow,
          CEAjtaiNatEqualityRowHolds] using hHold .contextProfileID
      have hContextShapeDigest :
          air.statement.context.shapeDigest = air.context.shapeDigest := by
        simpa [CEAjtaiConcreteAIRRowHolds,
          CEAjtaiConcreteAIRRows.contextShapeDigestRow,
          CEAjtaiNatEqualityRowHolds] using hHold .contextShapeDigest
      have hContextVerifierKeyDigest :
          air.statement.context.verifierKeyDigest =
            air.context.verifierKeyDigest := by
        simpa [CEAjtaiConcreteAIRRowHolds,
          CEAjtaiConcreteAIRRows.contextVerifierKeyDigestRow,
          CEAjtaiNatEqualityRowHolds] using hHold .contextVerifierKeyDigest
      rcases hStatementContext : air.statement.context with
        ⟨statementProfileID, statementShapeDigest, statementVerifierKeyDigest⟩
      rcases hContextValue : air.context with
        ⟨contextProfileID, contextShapeDigest, contextVerifierKeyDigest⟩
      rw [hStatementContext] at hContextProfileID hContextShapeDigest hContextVerifierKeyDigest
      rw [hContextValue] at hContextProfileID hContextShapeDigest hContextVerifierKeyDigest
      simpa using
        ⟨hContextProfileID, hContextShapeDigest,
          hContextVerifierKeyDigest⟩
    have hPublic : CEPublicInputBounded air.publicBound air.statement := by
      intro index
      exact hHold (.publicInputBound index)
    have hBounded : air.bounded air.witness :=
      hHold .witnessBound
    have hCommitment :
        commit air.A air.witness = air.statement.claim.commitment := by
      funext row
      have hRow :
          air.statement.claim.commitment row =
            ∑ column : Fin columns, air.A row column * air.witness column :=
        hHold (.commitmentRecomposition row)
      simpa [commit] using hRow.symm
    have hEvaluation :
        air.evaluationRelation
          air.witness air.statement.claim.point air.statement.claim.evaluations :=
      hHold .evaluationRelation
    exact
      (ceAjtaiPrimitiveConstraints_iff_localOpeningRelation
        air.shape air.context air.A air.bounded air.publicBound
        air.evaluationRelation air.statement air.witness).mp
        ⟨hShape, hContext, hPublic, hBounded, hCommitment, hEvaluation⟩
  · intro hVerifier
    have hPrimitive :
        CEAjtaiPrimitiveConstraints
          air.shape air.context air.A air.bounded air.publicBound
          air.evaluationRelation air.statement air.witness :=
      (ceAjtaiPrimitiveConstraints_iff_localOpeningRelation
        air.shape air.context air.A air.bounded air.publicBound
        air.evaluationRelation air.statement air.witness).mpr hVerifier
    rcases hPrimitive with
      ⟨hShape, hContext, hPublic, hBounded, hCommitment, hEvaluation⟩
    rcases hShape with
      ⟨hShapeRows, hShapeColumns, hShapePublicCount, hShapeEvalCount,
        hShapePointVars⟩
    refine (ceAjtaiConcreteAIR_allRowsZero_iff_allRowsHold air).mpr ?_
    intro index
    cases index with
    | shapeRows => exact hShapeRows
    | shapeColumns => exact hShapeColumns
    | shapePublicCount => exact hShapePublicCount
    | shapeEvalCount => exact hShapeEvalCount
    | shapePointVars => exact hShapePointVars
    | contextProfileID =>
        exact congrArg CEOpeningPublicContext.profileID hContext
    | contextShapeDigest =>
        exact congrArg CEOpeningPublicContext.shapeDigest hContext
    | contextVerifierKeyDigest =>
        exact congrArg CEOpeningPublicContext.verifierKeyDigest hContext
    | publicInputBound index =>
        exact hPublic index
    | witnessBound =>
        exact hBounded
    | commitmentRecomposition row =>
        have hRow :
            (∑ column : Fin columns,
              air.A row column * air.witness column) =
                air.statement.claim.commitment row := by
          simpa [commit] using congrFun hCommitment row
        exact hRow.symm
    | evaluationRelation =>
        exact hEvaluation

theorem ceAjtaiConcreteAIR_allRowsZero_implies_primitiveConstraints
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (hZero : CEAjtaiConcreteAIRAllRowsZero air) :
    CEAjtaiPrimitiveConstraints
      air.shape
      air.context
      air.A
      air.bounded
      air.publicBound
      air.evaluationRelation
      air.statement
      air.witness := by
  have hVerifier :
      CEAjtaiConcreteVerifierStep air :=
    (ceAjtaiConcreteAIR_allRowsZero_iff_verifierStep air).mp hZero
  exact
    (ceAjtaiPrimitiveConstraints_iff_localOpeningRelation
      air.shape air.context air.A air.bounded air.publicBound
      air.evaluationRelation air.statement air.witness).mpr hVerifier

inductive CEAjtaiScheduleIndex
    (rows columns publicCount evalCount pointVars : Nat) where
  | shapeRows :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | shapeColumns :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | shapePublicCount :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | shapeEvalCount :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | shapePointVars :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | contextProfileID :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | contextShapeDigest :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | contextVerifierKeyDigest :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | publicInputBound :
      Fin publicCount →
        CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | witnessBound :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | commitmentRecomposition :
      Fin rows →
        CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | evaluationRelation :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  deriving DecidableEq

def CEAjtaiScheduleIndex.toConcreteIndex
    {rows columns publicCount evalCount pointVars : Nat} :
    CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars →
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars
  | .shapeRows => .shapeRows
  | .shapeColumns => .shapeColumns
  | .shapePublicCount => .shapePublicCount
  | .shapeEvalCount => .shapeEvalCount
  | .shapePointVars => .shapePointVars
  | .contextProfileID => .contextProfileID
  | .contextShapeDigest => .contextShapeDigest
  | .contextVerifierKeyDigest => .contextVerifierKeyDigest
  | .publicInputBound index => .publicInputBound index
  | .witnessBound => .witnessBound
  | .commitmentRecomposition row => .commitmentRecomposition row
  | .evaluationRelation => .evaluationRelation

def CEAjtaiScheduleIndex.fromConcreteIndex
    {rows columns publicCount evalCount pointVars : Nat} :
    CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars →
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  | .shapeRows => .shapeRows
  | .shapeColumns => .shapeColumns
  | .shapePublicCount => .shapePublicCount
  | .shapeEvalCount => .shapeEvalCount
  | .shapePointVars => .shapePointVars
  | .contextProfileID => .contextProfileID
  | .contextShapeDigest => .contextShapeDigest
  | .contextVerifierKeyDigest => .contextVerifierKeyDigest
  | .publicInputBound index => .publicInputBound index
  | .witnessBound => .witnessBound
  | .commitmentRecomposition row => .commitmentRecomposition row
  | .evaluationRelation => .evaluationRelation

theorem ceAjtaiSchedule_toConcrete_fromConcrete
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiScheduleIndex.toConcreteIndex
        (CEAjtaiScheduleIndex.fromConcreteIndex index) = index := by
  cases index <;> rfl

theorem ceAjtaiSchedule_fromConcrete_toConcrete
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiScheduleIndex.fromConcreteIndex
        (CEAjtaiScheduleIndex.toConcreteIndex index) = index := by
  cases index <;> rfl

theorem ceAjtaiSchedule_no_missing_required_row
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    ∃ scheduled :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars,
      CEAjtaiScheduleIndex.toConcreteIndex scheduled = index :=
  ⟨CEAjtaiScheduleIndex.fromConcreteIndex index,
    ceAjtaiSchedule_toConcrete_fromConcrete index⟩

theorem ceAjtaiSchedule_no_duplicate_row_index
    {rows columns publicCount evalCount pointVars : Nat} :
    Function.Injective
      (CEAjtaiScheduleIndex.toConcreteIndex
        (rows := rows)
        (columns := columns)
        (publicCount := publicCount)
        (evalCount := evalCount)
        (pointVars := pointVars)) := by
  intro lhs rhs hConcrete
  rw [← ceAjtaiSchedule_fromConcrete_toConcrete lhs]
  rw [← ceAjtaiSchedule_fromConcrete_toConcrete rhs]
  rw [hConcrete]

def CEAjtaiScheduleIndex.rowKind
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiPrimitiveRowKind :=
  match index with
  | .shapeRows => .shapeRows
  | .shapeColumns => .shapeColumns
  | .shapePublicCount => .shapePublicCount
  | .shapeEvalCount => .shapeEvalCount
  | .shapePointVars => .shapePointVars
  | .contextProfileID => .contextProfileID
  | .contextShapeDigest => .contextShapeDigest
  | .contextVerifierKeyDigest => .contextVerifierKeyDigest
  | .publicInputBound _ => .publicInputBound
  | .witnessBound => .witnessBound
  | .commitmentRecomposition _ => .commitmentRecomposition
  | .evaluationRelation => .evaluationRelation

def CEAjtaiScheduleIndex.localIndex
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) : Nat :=
  match index with
  | .publicInputBound coordinate => coordinate.val
  | .commitmentRecomposition row => row.val
  | _ => 0

def CEAjtaiScheduleIndex.coordinateIndex?
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    Option Nat :=
  match index with
  | .publicInputBound coordinate => some coordinate.val
  | .commitmentRecomposition row => some row.val
  | _ => none

def CEAjtaiScheduleIndex.provenance
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    TerminalAIRRowProvenance :=
  match index with
  | .shapeRows => .canonicalDecoding
  | .shapeColumns => .canonicalDecoding
  | .shapePublicCount => .canonicalDecoding
  | .shapeEvalCount => .canonicalDecoding
  | .shapePointVars => .canonicalDecoding
  | .contextProfileID => .publicInputBinding
  | .contextShapeDigest => .publicInputBinding
  | .contextVerifierKeyDigest => .publicInputBinding
  | .publicInputBound _ => .primitiveArithmetic
  | .witnessBound => .primitiveArithmetic
  | .commitmentRecomposition _ => .primitiveArithmetic
  | .evaluationRelation => .primitiveArithmetic

def CEAjtaiScheduleIndex.subrelationKind
    {rows columns publicCount evalCount pointVars : Nat}
    (_index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    TerminalAIRSubrelationKind :=
  .terminalCEOpening

def CEAjtaiScheduleIndex.globalRowIndex
    {rows columns publicCount evalCount pointVars : Nat}
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    Nat :=
  match index with
  | .shapeRows => 0
  | .shapeColumns => 1
  | .shapePublicCount => 2
  | .shapeEvalCount => 3
  | .shapePointVars => 4
  | .contextProfileID => 5
  | .contextShapeDigest => 6
  | .contextVerifierKeyDigest => 7
  | .publicInputBound coordinate => 8 + coordinate.val
  | .witnessBound => 8 + publicCount
  | .commitmentRecomposition row => 9 + publicCount + row.val
  | .evaluationRelation => 9 + publicCount + rows

theorem ceAjtaiSchedule_globalRowIndex_injective
    {rows columns publicCount evalCount pointVars : Nat} :
    Function.Injective
      (CEAjtaiScheduleIndex.globalRowIndex
        (rows := rows)
        (columns := columns)
        (publicCount := publicCount)
        (evalCount := evalCount)
        (pointVars := pointVars)) := by
  intro lhs rhs hIndex
  cases lhs <;> cases rhs <;>
    simp [CEAjtaiScheduleIndex.globalRowIndex] at hIndex ⊢ <;>
    omega

def CEAjtaiScheduleIndex.toScheduledRowRef
    {rows columns publicCount evalCount pointVars : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    TerminalAIRScheduledRowRef where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKindCode := CEAjtaiPrimitiveRowKind.localCode index.rowKind
  globalRowIndex := index.globalRowIndex
  localRowIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

theorem ceAjtaiSchedule_scheduledRowRef_subrelation
    {rows columns publicCount evalCount pointVars : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    (CEAjtaiScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .terminalCEOpening :=
  rfl

theorem ceAjtaiProductionPackedLayout_subrelation_matches_rowRef
    {rows columns publicCount evalCount pointVars : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    (CEAjtaiScheduleIndex.toScheduledRowRef
      publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        (terminalAIRCEAjtaiProductionPackedLayout
          subrelationStartIndex digestFieldCount).subrelationKind :=
  rfl

theorem ceAjtaiProductionPackedLayout_observedResidualIndex
    {rows columns publicCount evalCount pointVars : Nat}
    (subrelationStartIndex digestFieldCount : Nat)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    (terminalAIRCEAjtaiProductionPackedLayout
      subrelationStartIndex digestFieldCount).observedResidualIndex
        (CEAjtaiScheduleIndex.toScheduledRowRef
          publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount index) =
      subrelationStartIndex +
        terminalAIRCEAjtaiPrimitiveRowsStartIndex digestFieldCount +
          index.globalRowIndex *
            (terminalAIRCEAjtaiProductionPackedLayout
              subrelationStartIndex digestFieldCount).rowBlockWidth +
              (terminalAIRCEAjtaiProductionPackedLayout
                subrelationStartIndex digestFieldCount).observedResidualOffset :=
  rfl

theorem ceAjtaiSchedule_no_ambiguous_row_kind
    {rows columns publicCount evalCount pointVars : Nat}
    {lhs rhs :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars}
    (hConcrete :
      CEAjtaiScheduleIndex.toConcreteIndex lhs =
        CEAjtaiScheduleIndex.toConcreteIndex rhs) :
    lhs = rhs ∧ lhs.rowKind = rhs.rowKind := by
  have hEq := ceAjtaiSchedule_no_duplicate_row_index hConcrete
  exact ⟨hEq, by rw [hEq]⟩

inductive CEAjtaiScheduledRowValue (RF : Type) where
  | nat : Nat → CEAjtaiScheduledRowValue RF
  | field : RF → CEAjtaiScheduledRowValue RF
  | guard : Nat → CEAjtaiScheduledRowValue RF

def CEAjtaiConcreteAIRRowObservedValue
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiScheduledRowValue RF :=
  match index with
  | .shapeRows => .nat air.shapeRowsRow.observed
  | .shapeColumns => .nat air.shapeColumnsRow.observed
  | .shapePublicCount => .nat air.shapePublicCountRow.observed
  | .shapeEvalCount => .nat air.shapeEvalCountRow.observed
  | .shapePointVars => .nat air.shapePointVarsRow.observed
  | .contextProfileID => .nat air.contextProfileIDRow.observed
  | .contextShapeDigest => .nat air.contextShapeDigestRow.observed
  | .contextVerifierKeyDigest => .nat air.contextVerifierKeyDigestRow.observed
  | .publicInputBound index =>
      let row := air.publicInputBoundRow index
      letI := row.decidableCondition
      .guard (if row.condition then 0 else 1)
  | .witnessBound =>
      let row := air.witnessBoundRow
      letI := row.decidableCondition
      .guard (if row.condition then 0 else 1)
  | .commitmentRecomposition row =>
      .field (air.commitmentRecompositionRow row).target
  | .evaluationRelation =>
      let row := air.evaluationRelationRow
      letI := row.decidableCondition
      .guard (if row.condition then 0 else 1)

def CEAjtaiConcreteAIRRowExpectedValue
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index :
      CEAjtaiConcreteAIRRowIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiScheduledRowValue RF :=
  match index with
  | .shapeRows => .nat air.shapeRowsRow.expected
  | .shapeColumns => .nat air.shapeColumnsRow.expected
  | .shapePublicCount => .nat air.shapePublicCountRow.expected
  | .shapeEvalCount => .nat air.shapeEvalCountRow.expected
  | .shapePointVars => .nat air.shapePointVarsRow.expected
  | .contextProfileID => .nat air.contextProfileIDRow.expected
  | .contextShapeDigest => .nat air.contextShapeDigestRow.expected
  | .contextVerifierKeyDigest => .nat air.contextVerifierKeyDigestRow.expected
  | .publicInputBound _ => .guard 0
  | .witnessBound => .guard 0
  | .commitmentRecomposition row =>
      .field
        (∑ column : Fin columns,
          (air.commitmentRecompositionRow row).matrixRow column *
            (air.commitmentRecompositionRow row).witness column)
  | .evaluationRelation => .guard 0

structure CEAjtaiScheduledRowTranscript
    (RF : Type) [CommRing RF]
    (rows columns publicCount evalCount pointVars : Nat) where
  provenance : TerminalAIRRowProvenance
  subrelationKind : TerminalAIRSubrelationKind
  rowKind : CEAjtaiPrimitiveRowKind
  rowIndex : CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  localIndex : Nat
  coordinateIndex? : Option Nat
  observedValue : CEAjtaiScheduledRowValue RF
  expectedValue : CEAjtaiScheduledRowValue RF
  residual : CEAjtaiAIRResidualValue RF
  publicBindingContext : TerminalAIRPublicBindingContext
  terminalVerifierRelationDigest : Digest256Wire
  recursiveRelationDigest : Option Digest256Wire
  sourceDigest : Digest256Wire
  sourceByteCount : Nat

def CEAjtaiScheduledRowTranscript.ofScheduleIndex
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount pointVars where
  provenance := index.provenance
  subrelationKind := index.subrelationKind
  rowKind := index.rowKind
  rowIndex := index
  localIndex := index.localIndex
  coordinateIndex? := index.coordinateIndex?
  observedValue :=
    CEAjtaiConcreteAIRRowObservedValue air index.toConcreteIndex
  expectedValue :=
    CEAjtaiConcreteAIRRowExpectedValue air index.toConcreteIndex
  residual :=
    CEAjtaiConcreteAIRRowResidual air index.toConcreteIndex
  publicBindingContext := publicBindingContext
  terminalVerifierRelationDigest := terminalVerifierRelationDigest
  recursiveRelationDigest := recursiveRelationDigest
  sourceDigest := sourceDigest
  sourceByteCount := sourceByteCount

def CEAjtaiScheduledRowTranscript.toScheduledRowRef
    {rows columns publicCount evalCount pointVars : Nat}
    (globalRowIndex : Nat)
    (row :
      CEAjtaiScheduledRowTranscript
        RF rows columns publicCount evalCount pointVars) :
    TerminalAIRScheduledRowRef where
  provenance := row.provenance
  subrelationKind := row.subrelationKind
  rowKindCode := CEAjtaiPrimitiveRowKind.localCode row.rowKind
  globalRowIndex := globalRowIndex
  localRowIndex := row.localIndex
  coordinateIndex? := row.coordinateIndex?
  publicBindingContext := row.publicBindingContext
  terminalVerifierRelationDigest := row.terminalVerifierRelationDigest
  recursiveRelationDigest := row.recursiveRelationDigest
  sourceDigest := row.sourceDigest
  sourceByteCount := row.sourceByteCount

theorem ceAjtaiScheduledRow_subrelation_terminalCEOpening
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    (CEAjtaiScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).subrelationKind =
        .terminalCEOpening :=
  rfl

theorem ceAjtaiScheduledRow_residual_eq_concrete
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    (CEAjtaiScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual =
        CEAjtaiConcreteAIRRowResidual air index.toConcreteIndex :=
  rfl

def CEAjtaiScheduledAIRAllRowsZero
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) : Prop :=
  ∀ index : CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars,
    (CEAjtaiScheduledRowTranscript.ofScheduleIndex
      air publicBindingContext terminalVerifierRelationDigest
      recursiveRelationDigest sourceDigest sourceByteCount index).residual = 0

theorem ceAjtaiScheduledAIR_allRowsZero_iff_concreteAllRowsZero
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    CEAjtaiScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      CEAjtaiConcreteAIRAllRowsZero air := by
  constructor
  · intro hScheduled concreteIndex
    have hScheduledIndex :
        (CEAjtaiScheduledRowTranscript.ofScheduleIndex
          air publicBindingContext terminalVerifierRelationDigest
          recursiveRelationDigest sourceDigest sourceByteCount
          (CEAjtaiScheduleIndex.fromConcreteIndex concreteIndex)).residual = 0 :=
      hScheduled (CEAjtaiScheduleIndex.fromConcreteIndex concreteIndex)
    simpa [CEAjtaiScheduledRowTranscript.ofScheduleIndex,
      ceAjtaiSchedule_toConcrete_fromConcrete concreteIndex] using hScheduledIndex
  · intro hConcrete scheduledIndex
    simpa [CEAjtaiScheduledRowTranscript.ofScheduleIndex] using
      hConcrete scheduledIndex.toConcreteIndex

theorem ceAjtaiScheduledAIR_allRowsZero_iff_verifierStep
    {rows columns publicCount evalCount pointVars : Nat}
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat) :
    CEAjtaiScheduledAIRAllRowsZero
        air publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount ↔
      CEAjtaiConcreteVerifierStep air := by
  rw [ceAjtaiScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  exact ceAjtaiConcreteAIR_allRowsZero_iff_verifierStep air

structure TerminalAIRQueryLocalPCSVerifier
    (Query TraceOpening ResidualValue : Type) [Zero ResidualValue] where
  scheduledRow : Query → TerminalAIRScheduledRowRef
  traceOpening : Query → TraceOpening
  residualOpening : Query → ResidualValue
  concreteAIRResidual :
    TerminalAIRScheduledRowRef → TraceOpening → ResidualValue
  queryOpeningAccepted : Query → Prop
  queryOpening_residual_eq_concrete :
    ∀ query, queryOpeningAccepted query →
      residualOpening query =
        concreteAIRResidual (scheduledRow query) (traceOpening query)
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query → residualOpening query = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

def TerminalAIRQueryLocalPCSVerifier.rowLookup
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    (verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue)
    (query : Query) : TerminalAIRScheduledRowRef :=
  verifier.scheduledRow query

def TerminalAIRQueryLocalPCSVerifier.queryOpening
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    (verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue)
    (query : Query) : TerminalAIRQueryOpening TraceOpening ResidualValue where
  scheduledRow := verifier.scheduledRow query
  traceOpening := verifier.traceOpening query
  residualOpening := verifier.residualOpening query

def TerminalAIRPCSQueriedResidualsMatchConcreteAIR
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    (verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue) :
    Prop :=
  ∀ query,
    verifier.residualOpening query =
      verifier.concreteAIRResidual
        (verifier.scheduledRow query)
        (verifier.traceOpening query)

def TerminalAIRPCSQueriedResidualsZero
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    (verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue) :
    Prop :=
  ∀ query, verifier.residualOpening query = 0

def TerminalAIRConcreteAIRResidualsZeroAtQueries
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    (verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue) :
    Prop :=
  ∀ query,
    verifier.concreteAIRResidual
      (verifier.scheduledRow query)
      (verifier.traceOpening query) = 0

theorem terminalAIRQueryOpening_accepts_implies_openedResidual_eq_concreteAIRResidual
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.residualOpening query =
      verifier.concreteAIRResidual
        (verifier.scheduledRow query)
        (verifier.traceOpening query) :=
  verifier.queryOpening_residual_eq_concrete query hAccepted

theorem terminalAIRQueryOpening_accepts_implies_openedResidual_zero
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.residualOpening query = 0 :=
  verifier.queryOpening_residual_zero query hAccepted

theorem terminalAIRQueryOpening_accepts_implies_concreteAIRResidual_zero
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.concreteAIRResidual
      (verifier.scheduledRow query)
      (verifier.traceOpening query) = 0 := by
  have hEq :
      verifier.residualOpening query =
        verifier.concreteAIRResidual
          (verifier.scheduledRow query)
          (verifier.traceOpening query) :=
    terminalAIRQueryOpening_accepts_implies_openedResidual_eq_concreteAIRResidual
      (verifier := verifier) hAccepted
  have hZero : verifier.residualOpening query = 0 :=
    terminalAIRQueryOpening_accepts_implies_openedResidual_zero
      (verifier := verifier) hAccepted
  rw [← hEq]
  exact hZero

theorem sourceFreePCS_accepts_implies_terminalAIR_queriedResiduals_match_concreteAIR
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    TerminalAIRPCSQueriedResidualsMatchConcreteAIR verifier := by
  intro query
  exact
    verifier.queryOpening_residual_eq_concrete query
      (verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

theorem sourceFreePCS_accepts_implies_terminalAIR_queriedResiduals_zero
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    TerminalAIRPCSQueriedResidualsZero verifier := by
  intro query
  exact
    verifier.queryOpening_residual_zero query
      (verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

theorem sourceFreePCS_accepts_implies_terminalAIR_concreteAIRResiduals_zero_at_queries
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    TerminalAIRConcreteAIRResidualsZeroAtQueries verifier := by
  intro query
  exact
    terminalAIRQueryOpening_accepts_implies_concreteAIRResidual_zero
      (verifier := verifier)
      (verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

structure TerminalAIRPackedTraceResidual
    (TraceOpening ResidualValue : Type) where
  traceAt : Nat → TraceOpening
  residualAt : Nat → ResidualValue

structure TerminalAIRPackedQueryLocalPCSVerifier
    (Query TraceOpening ResidualValue : Type) [Zero ResidualValue] where
  layout : TerminalAIRPackedConstraintRowLayout
  packedTraceResidual :
    TerminalAIRPackedTraceResidual TraceOpening ResidualValue
  queryIndex : Query → Nat
  scheduledRow : Query → TerminalAIRScheduledRowRef
  traceOpening : Query → TraceOpening
  residualOpening : Query → ResidualValue
  concreteAIRResidual :
    TerminalAIRScheduledRowRef → TraceOpening → ResidualValue
  queryOpeningAccepted : Query → Prop
  queryOpening_subrelation_matches_layout :
    ∀ query, queryOpeningAccepted query →
      (scheduledRow query).subrelationKind = layout.subrelationKind
  queryOpening_index_eq_observedResidualIndex :
    ∀ query, queryOpeningAccepted query →
      queryIndex query =
        layout.observedResidualIndex (scheduledRow query)
  queryOpening_trace_eq_packed :
    ∀ query, queryOpeningAccepted query →
      traceOpening query = packedTraceResidual.traceAt (queryIndex query)
  queryOpening_residual_eq_packed :
    ∀ query, queryOpeningAccepted query →
      residualOpening query =
        packedTraceResidual.residualAt (queryIndex query)
  packedResidual_eq_concreteAIRResidual :
    ∀ query, queryOpeningAccepted query →
      packedTraceResidual.residualAt
          (layout.observedResidualIndex (scheduledRow query)) =
        concreteAIRResidual (scheduledRow query) (traceOpening query)
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query → residualOpening query = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

def TerminalAIRPackedQueryLocalPCSVerifier.toQueryLocalVerifier
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    (verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue) :
    TerminalAIRQueryLocalPCSVerifier Query TraceOpening ResidualValue where
  scheduledRow := verifier.scheduledRow
  traceOpening := verifier.traceOpening
  residualOpening := verifier.residualOpening
  concreteAIRResidual := verifier.concreteAIRResidual
  queryOpeningAccepted := verifier.queryOpeningAccepted
  queryOpening_residual_eq_concrete := by
    intro query hAccepted
    calc
      verifier.residualOpening query =
          verifier.packedTraceResidual.residualAt (verifier.queryIndex query) :=
        verifier.queryOpening_residual_eq_packed query hAccepted
      _ =
          verifier.packedTraceResidual.residualAt
            (verifier.layout.observedResidualIndex
              (verifier.scheduledRow query)) := by
        rw [verifier.queryOpening_index_eq_observedResidualIndex
          query hAccepted]
      _ =
          verifier.concreteAIRResidual
            (verifier.scheduledRow query)
            (verifier.traceOpening query) :=
        verifier.packedResidual_eq_concreteAIRResidual query hAccepted
  queryOpening_residual_zero :=
    verifier.queryOpening_residual_zero
  sourceFreePCSVerifierAccepts := verifier.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_implies_queryOpeningAccepted :=
    verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted

theorem terminalAIRPackedQueryOpening_accepts_implies_subrelation_matches_layout
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    (verifier.scheduledRow query).subrelationKind =
      verifier.layout.subrelationKind :=
  verifier.queryOpening_subrelation_matches_layout query hAccepted

theorem terminalAIRPackedQueryOpening_accepts_implies_queryIndex_eq_observedResidualIndex
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.queryIndex query =
      verifier.layout.observedResidualIndex (verifier.scheduledRow query) :=
  verifier.queryOpening_index_eq_observedResidualIndex query hAccepted

theorem terminalAIRPackedQueryOpening_accepts_implies_openedResidual_eq_concreteAIRResidual
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.residualOpening query =
      verifier.concreteAIRResidual
        (verifier.scheduledRow query)
        (verifier.traceOpening query) :=
  terminalAIRQueryOpening_accepts_implies_openedResidual_eq_concreteAIRResidual
    (verifier := verifier.toQueryLocalVerifier)
    hAccepted

theorem terminalAIRPackedQueryOpening_accepts_implies_concreteAIRResidual_zero
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.concreteAIRResidual
      (verifier.scheduledRow query)
      (verifier.traceOpening query) = 0 :=
  terminalAIRQueryOpening_accepts_implies_concreteAIRResidual_zero
    (verifier := verifier.toQueryLocalVerifier)
    hAccepted

theorem sourceFreePCS_accepts_implies_terminalAIR_packedQueriedResiduals_match_concreteAIR
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    TerminalAIRPCSQueriedResidualsMatchConcreteAIR
      verifier.toQueryLocalVerifier :=
  sourceFreePCS_accepts_implies_terminalAIR_queriedResiduals_match_concreteAIR
    (verifier := verifier.toQueryLocalVerifier)
    hAccepts

theorem sourceFreePCS_accepts_implies_terminalAIR_packedConcreteAIRResiduals_zero_at_queries
    {Query TraceOpening ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRPackedQueryLocalPCSVerifier
        Query TraceOpening ResidualValue}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    TerminalAIRConcreteAIRResidualsZeroAtQueries
      verifier.toQueryLocalVerifier :=
  sourceFreePCS_accepts_implies_terminalAIR_concreteAIRResiduals_zero_at_queries
    (verifier := verifier.toQueryLocalVerifier)
    hAccepts

structure TerminalAIRProductionJointPCSQuerySchedule
    (Query : Type) where
  jointQueryIndex : Query → Nat
  traceQueryIndex : Query → Nat
  residualQueryIndex : Query → Nat
  traceQueryIndex_eq_joint :
    ∀ query, traceQueryIndex query = jointQueryIndex query
  residualQueryIndex_eq_joint :
    ∀ query, residualQueryIndex query = jointQueryIndex query

theorem terminalAIRProductionJointPCSQuerySchedule_trace_eq_residual
    {Query : Type}
    (schedule : TerminalAIRProductionJointPCSQuerySchedule Query)
    (query : Query) :
    schedule.traceQueryIndex query =
      schedule.residualQueryIndex query := by
  rw [schedule.traceQueryIndex_eq_joint query,
    schedule.residualQueryIndex_eq_joint query]

structure TerminalAIRProductionPCSQueryOpening
    (Point ResidualValue : Type) where
  queryIndex : Nat
  point : Point
  value : ResidualValue

structure TerminalAIRProductionPCSQueryVerifier
    (Query Point ResidualValue : Type) [Zero ResidualValue] where
  jointSchedule : TerminalAIRProductionJointPCSQuerySchedule Query
  residualOpening : Query → TerminalAIRProductionPCSQueryOpening Point ResidualValue
  residualPolynomialAt : Point → ResidualValue
  queryOpeningAccepted : Query → Prop
  queryOpening_index_eq_joint :
    ∀ query, queryOpeningAccepted query →
      (residualOpening query).queryIndex =
        jointSchedule.jointQueryIndex query
  queryOpening_residual_eq_polynomial :
    ∀ query, queryOpeningAccepted query →
      (residualOpening query).value =
        residualPolynomialAt (residualOpening query).point
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query →
      (residualOpening query).value = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

theorem terminalAIRProductionPCSQueryOpening_accepts_implies_residualPolynomial_zero
    {Query Point ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRProductionPCSQueryVerifier Query Point ResidualValue}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    verifier.residualPolynomialAt
        (verifier.residualOpening query).point = 0 := by
  have hEq :
      (verifier.residualOpening query).value =
        verifier.residualPolynomialAt
          (verifier.residualOpening query).point :=
    verifier.queryOpening_residual_eq_polynomial query hAccepted
  have hZero : (verifier.residualOpening query).value = 0 :=
    verifier.queryOpening_residual_zero query hAccepted
  rw [← hEq]
  exact hZero

theorem sourceFreePCS_accepts_implies_terminalAIRProductionPCS_residualPolynomial_zero_at_queries
    {Query Point ResidualValue : Type} [Zero ResidualValue]
    {verifier :
      TerminalAIRProductionPCSQueryVerifier Query Point ResidualValue}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    ∀ query,
      verifier.residualPolynomialAt
          (verifier.residualOpening query).point = 0 := by
  intro query
  exact
    terminalAIRProductionPCSQueryOpening_accepts_implies_residualPolynomial_zero
      (verifier := verifier)
      (verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

structure TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
    (Query TraceOpening ResidualValue Point : Type)
    [Zero ResidualValue] where
  productionPCS :
    TerminalAIRProductionPCSQueryVerifier Query Point ResidualValue
  packedVerifier :
    TerminalAIRPackedQueryLocalPCSVerifier
      Query TraceOpening ResidualValue
  packedQueryAccepted_of_productionAccepted :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packedVerifier.queryOpeningAccepted query
  packedQueryIndex_eq_joint :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packedVerifier.queryIndex query =
        productionPCS.jointSchedule.jointQueryIndex query
  residualPolynomial_eq_packedResidualAtObserved :
    ∀ query, productionPCS.queryOpeningAccepted query →
      productionPCS.residualPolynomialAt
          (productionPCS.residualOpening query).point =
        packedVerifier.packedTraceResidual.residualAt
          (packedVerifier.layout.observedResidualIndex
            (packedVerifier.scheduledRow query))

theorem terminalAIRProductionPCSInstantiatesPackedQueryVerifier_accepts_implies_packedQueryIndex_eq_residualQueryIndex
    {Query TraceOpening ResidualValue Point : Type}
    [Zero ResidualValue]
    {instantiation :
      TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
        Query TraceOpening ResidualValue Point}
    {query : Query}
    (hAccepted :
      instantiation.productionPCS.queryOpeningAccepted query) :
    instantiation.packedVerifier.queryIndex query =
      instantiation.productionPCS.jointSchedule.residualQueryIndex query := by
  rw [instantiation.packedQueryIndex_eq_joint query hAccepted]
  rw [instantiation.productionPCS.jointSchedule.residualQueryIndex_eq_joint]

theorem terminalAIRProductionPCSInstantiatesPackedQueryVerifier_accepts_implies_concreteAIRResidual_zero
    {Query TraceOpening ResidualValue Point : Type}
    [Zero ResidualValue]
    {instantiation :
      TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
        Query TraceOpening ResidualValue Point}
    {query : Query}
    (hAccepted :
      instantiation.productionPCS.queryOpeningAccepted query) :
    instantiation.packedVerifier.concreteAIRResidual
        (instantiation.packedVerifier.scheduledRow query)
        (instantiation.packedVerifier.traceOpening query) = 0 := by
  have hPackedAccepted :
      instantiation.packedVerifier.queryOpeningAccepted query :=
    instantiation.packedQueryAccepted_of_productionAccepted
      query hAccepted
  have hPolynomialZero :
      instantiation.productionPCS.residualPolynomialAt
          (instantiation.productionPCS.residualOpening query).point = 0 :=
    terminalAIRProductionPCSQueryOpening_accepts_implies_residualPolynomial_zero
      (verifier := instantiation.productionPCS) hAccepted
  have hPackedResidualZero :
      instantiation.packedVerifier.packedTraceResidual.residualAt
          (instantiation.packedVerifier.layout.observedResidualIndex
            (instantiation.packedVerifier.scheduledRow query)) = 0 := by
    rw [←
      instantiation.residualPolynomial_eq_packedResidualAtObserved
        query hAccepted]
    exact hPolynomialZero
  have hPackedResidualEqConcrete :
      instantiation.packedVerifier.packedTraceResidual.residualAt
          (instantiation.packedVerifier.layout.observedResidualIndex
            (instantiation.packedVerifier.scheduledRow query)) =
        instantiation.packedVerifier.concreteAIRResidual
          (instantiation.packedVerifier.scheduledRow query)
          (instantiation.packedVerifier.traceOpening query) :=
    instantiation.packedVerifier.packedResidual_eq_concreteAIRResidual
      query hPackedAccepted
  rw [hPackedResidualEqConcrete] at hPackedResidualZero
  exact hPackedResidualZero

theorem sourceFreePCS_accepts_implies_terminalAIRProductionPCSInstantiatesPackedQueryVerifier_concreteAIRResiduals_zero_at_queries
    {Query TraceOpening ResidualValue Point : Type}
    [Zero ResidualValue]
    {instantiation :
      TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
        Query TraceOpening ResidualValue Point}
    (hAccepts :
      instantiation.productionPCS.sourceFreePCSVerifierAccepts) :
    ∀ query,
      instantiation.packedVerifier.concreteAIRResidual
        (instantiation.packedVerifier.scheduledRow query)
        (instantiation.packedVerifier.traceOpening query) = 0 := by
  intro query
  exact
    terminalAIRProductionPCSInstantiatesPackedQueryVerifier_accepts_implies_concreteAIRResidual_zero
      (instantiation := instantiation)
      (instantiation.productionPCS.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

structure TerminalAIRProductionConcretePackedQueryResidualBridge
    (Query ScheduleIndex TraceOpening ResidualValue Point : Type)
    [Zero ResidualValue] where
  productionInstantiation :
    TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
      Query TraceOpening ResidualValue Point
  scheduledIndex : Query → ScheduleIndex
  concreteRowResidual : ScheduleIndex → ResidualValue
  concreteAIRResidual_eq_concreteRowResidual :
    ∀ query,
      productionInstantiation.packedVerifier.concreteAIRResidual
        (productionInstantiation.packedVerifier.scheduledRow query)
        (productionInstantiation.packedVerifier.traceOpening query) =
          concreteRowResidual (scheduledIndex query)

theorem terminalAIRProductionConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
    {Query ScheduleIndex TraceOpening ResidualValue Point : Type}
    [Zero ResidualValue]
    {bridge :
      TerminalAIRProductionConcretePackedQueryResidualBridge
        Query ScheduleIndex TraceOpening ResidualValue Point}
    {query : Query}
    (hAccepted :
      bridge.productionInstantiation.productionPCS.queryOpeningAccepted
        query) :
    bridge.concreteRowResidual (bridge.scheduledIndex query) = 0 := by
  have hConcreteAIRZero :
      bridge.productionInstantiation.packedVerifier.concreteAIRResidual
        (bridge.productionInstantiation.packedVerifier.scheduledRow query)
        (bridge.productionInstantiation.packedVerifier.traceOpening query) =
          0 :=
    terminalAIRProductionPCSInstantiatesPackedQueryVerifier_accepts_implies_concreteAIRResidual_zero
      (instantiation := bridge.productionInstantiation) hAccepted
  rw [bridge.concreteAIRResidual_eq_concreteRowResidual query] at hConcreteAIRZero
  exact hConcreteAIRZero

theorem sourceFreePCS_accepts_implies_terminalAIRProductionConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
    {Query ScheduleIndex TraceOpening ResidualValue Point : Type}
    [Zero ResidualValue]
    {bridge :
      TerminalAIRProductionConcretePackedQueryResidualBridge
        Query ScheduleIndex TraceOpening ResidualValue Point}
    (hAccepts :
      bridge.productionInstantiation.productionPCS.sourceFreePCSVerifierAccepts) :
    ∀ query,
      bridge.concreteRowResidual (bridge.scheduledIndex query) = 0 := by
  intro query
  exact
    terminalAIRProductionConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := bridge)
      (bridge.productionInstantiation.productionPCS.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

structure TerminalAIRConcretePackedQueryResidualBridge
    (Query ScheduleIndex TraceOpening ResidualValue : Type)
    [Zero ResidualValue] where
  packedVerifier :
    TerminalAIRPackedQueryLocalPCSVerifier
      Query TraceOpening ResidualValue
  scheduledIndex : Query → ScheduleIndex
  concreteRowResidual : ScheduleIndex → ResidualValue
  concreteAIRResidual_eq_concreteRowResidual :
    ∀ query,
      packedVerifier.concreteAIRResidual
        (packedVerifier.scheduledRow query)
        (packedVerifier.traceOpening query) =
          concreteRowResidual (scheduledIndex query)

theorem terminalAIRConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
    {Query ScheduleIndex TraceOpening ResidualValue : Type}
    [Zero ResidualValue]
    {bridge :
      TerminalAIRConcretePackedQueryResidualBridge
        Query ScheduleIndex TraceOpening ResidualValue}
    {query : Query}
    (hAccepted : bridge.packedVerifier.queryOpeningAccepted query) :
    bridge.concreteRowResidual (bridge.scheduledIndex query) = 0 := by
  have hConcreteAIRZero :
      bridge.packedVerifier.concreteAIRResidual
        (bridge.packedVerifier.scheduledRow query)
        (bridge.packedVerifier.traceOpening query) = 0 :=
    terminalAIRPackedQueryOpening_accepts_implies_concreteAIRResidual_zero
      (verifier := bridge.packedVerifier) hAccepted
  rw [← bridge.concreteAIRResidual_eq_concreteRowResidual query]
  exact hConcreteAIRZero

theorem sourceFreePCS_accepts_implies_terminalAIRConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
    {Query ScheduleIndex TraceOpening ResidualValue : Type}
    [Zero ResidualValue]
    {bridge :
      TerminalAIRConcretePackedQueryResidualBridge
        Query ScheduleIndex TraceOpening ResidualValue}
    (hAccepts : bridge.packedVerifier.sourceFreePCSVerifierAccepts) :
    ∀ query,
      bridge.concreteRowResidual (bridge.scheduledIndex query) = 0 := by
  intro query
  exact
    terminalAIRConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := bridge)
      (bridge.packedVerifier.sourceFreePCS_accepts_implies_queryOpeningAccepted
        hAccepts query)

structure PiDECPackedQueryLocalPCSVerifier
    (Query RF : Type) [CommRing RF]
    (rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat) where
  air :
    PiDECScheduledAIRRows RF rows columns count signedDigitCount
      decompositionCount publicSplitCount lowNormCount
  rowContext : TerminalAIRRowTranscriptContext
  subrelationStartIndex : Nat
  digestFieldCount : Nat
  packedTraceResidual :
    TerminalAIRPackedTraceResidual
      (PiDECScheduledRowTranscript RF rows columns signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
      (PiDECAIRResidualValue RF)
  queryIndex : Query → Nat
  scheduledIndex :
    Query →
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount
  residualOpening : Query → PiDECAIRResidualValue RF
  queryOpeningAccepted : Query → Prop
  queryOpening_index_eq_observedResidualIndex :
    ∀ query, queryOpeningAccepted query →
      queryIndex query =
        (terminalAIRPiDECProductionPackedLayout
          subrelationStartIndex digestFieldCount).observedResidualIndex
          (PiDECScheduleIndex.toScheduledRowRef
            rowContext.publicBindingContext
            rowContext.terminalVerifierRelationDigest
            rowContext.recursiveRelationDigest rowContext.sourceDigest
            rowContext.sourceByteCount
            (scheduledIndex query))
  queryOpening_trace_eq_packed :
    ∀ query, queryOpeningAccepted query →
      PiDECScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query) =
        packedTraceResidual.traceAt (queryIndex query)
  queryOpening_residual_eq_packed :
    ∀ query, queryOpeningAccepted query →
      residualOpening query =
        packedTraceResidual.residualAt (queryIndex query)
  packedResidual_eq_concreteAIRResidual :
    ∀ query, queryOpeningAccepted query →
      packedTraceResidual.residualAt
          ((terminalAIRPiDECProductionPackedLayout
            subrelationStartIndex digestFieldCount).observedResidualIndex
            (PiDECScheduleIndex.toScheduledRowRef
              rowContext.publicBindingContext
              rowContext.terminalVerifierRelationDigest
              rowContext.recursiveRelationDigest rowContext.sourceDigest
              rowContext.sourceByteCount
              (scheduledIndex query))) =
        (PiDECScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query)).residual
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query → residualOpening query = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

def PiDECPackedQueryLocalPCSVerifier.layout
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRPiDECProductionPackedLayout
    verifier.subrelationStartIndex verifier.digestFieldCount

def PiDECPackedQueryLocalPCSVerifier.scheduledRowRef
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount)
    (query : Query) : TerminalAIRScheduledRowRef :=
  PiDECScheduleIndex.toScheduledRowRef
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def PiDECPackedQueryLocalPCSVerifier.traceOpening
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount)
    (query : Query) :
    PiDECScheduledRowTranscript RF rows columns signedDigitCount
      decompositionCount publicSplitCount lowNormCount :=
  PiDECScheduledRowTranscript.ofScheduleIndex
    verifier.air
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def PiDECPackedQueryLocalPCSVerifier.toPackedVerifier
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount) :
    TerminalAIRPackedQueryLocalPCSVerifier
      Query
      (PiDECScheduledRowTranscript RF rows columns signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
      (PiDECAIRResidualValue RF) where
  layout := verifier.layout
  packedTraceResidual := verifier.packedTraceResidual
  queryIndex := verifier.queryIndex
  scheduledRow := verifier.scheduledRowRef
  traceOpening := verifier.traceOpening
  residualOpening := verifier.residualOpening
  concreteAIRResidual := fun _row trace => trace.residual
  queryOpeningAccepted := verifier.queryOpeningAccepted
  queryOpening_subrelation_matches_layout := by
    intro query _hAccepted
    exact
      pidecProductionPackedLayout_subrelation_matches_rowRef
        verifier.subrelationStartIndex
        verifier.digestFieldCount
        verifier.rowContext.publicBindingContext
        verifier.rowContext.terminalVerifierRelationDigest
        verifier.rowContext.recursiveRelationDigest
        verifier.rowContext.sourceDigest
        verifier.rowContext.sourceByteCount
        (verifier.scheduledIndex query)
  queryOpening_index_eq_observedResidualIndex :=
    verifier.queryOpening_index_eq_observedResidualIndex
  queryOpening_trace_eq_packed :=
    verifier.queryOpening_trace_eq_packed
  queryOpening_residual_eq_packed :=
    verifier.queryOpening_residual_eq_packed
  packedResidual_eq_concreteAIRResidual :=
    verifier.packedResidual_eq_concreteAIRResidual
  queryOpening_residual_zero :=
    verifier.queryOpening_residual_zero
  sourceFreePCSVerifierAccepts := verifier.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_implies_queryOpeningAccepted :=
    verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted

def PiDECPackedQueryLocalPCSVerifier.residualBridge
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount) :
    TerminalAIRConcretePackedQueryResidualBridge
      Query
      (PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount)
      (PiDECScheduledRowTranscript RF rows columns signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
      (PiDECAIRResidualValue RF) where
  packedVerifier := verifier.toPackedVerifier
  scheduledIndex := verifier.scheduledIndex
  concreteRowResidual := fun index =>
    PiDECConcreteAIRRowResidual verifier.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [PiDECPackedQueryLocalPCSVerifier.toPackedVerifier,
      PiDECPackedQueryLocalPCSVerifier.traceOpening,
      PiDECScheduledRowTranscript.ofScheduleIndex]

theorem pidecPackedQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    {verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    PiDECConcreteAIRRowResidual
      verifier.air
      (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiDECPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_pidecPackedConcreteAIRRowResiduals_zero_at_queries
    {Query RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    {verifier :
      PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
        signedDigitCount decompositionCount publicSplitCount lowNormCount}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    ∀ query,
      PiDECConcreteAIRRowResidual
        verifier.air
        (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiDECPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure PiDECProductionPackedQueryLocalPCSVerifier
    (Query RF Point : Type) [CommRing RF]
    (rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat) where
  packed :
    PiDECPackedQueryLocalPCSVerifier Query RF rows columns count
      signedDigitCount decompositionCount publicSplitCount lowNormCount
  productionPCS :
    TerminalAIRProductionPCSQueryVerifier
      Query Point (PiDECAIRResidualValue RF)
  packedQueryAccepted_of_productionAccepted :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryOpeningAccepted query
  packedQueryIndex_eq_joint :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryIndex query =
        productionPCS.jointSchedule.jointQueryIndex query
  residualPolynomial_eq_packedResidualAtObserved :
    ∀ query, productionPCS.queryOpeningAccepted query →
      productionPCS.residualPolynomialAt
          (productionPCS.residualOpening query).point =
        packed.packedTraceResidual.residualAt
          (packed.layout.observedResidualIndex
            (packed.scheduledRowRef query))

def PiDECProductionPackedQueryLocalPCSVerifier.toProductionInstantiation
    {Query RF Point : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        count signedDigitCount decompositionCount publicSplitCount
        lowNormCount) :
    TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
      Query
      (PiDECScheduledRowTranscript RF rows columns signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
      (PiDECAIRResidualValue RF)
      Point where
  productionPCS := verifier.productionPCS
  packedVerifier := verifier.packed.toPackedVerifier
  packedQueryAccepted_of_productionAccepted :=
    verifier.packedQueryAccepted_of_productionAccepted
  packedQueryIndex_eq_joint :=
    verifier.packedQueryIndex_eq_joint
  residualPolynomial_eq_packedResidualAtObserved :=
    verifier.residualPolynomial_eq_packedResidualAtObserved

def PiDECProductionPackedQueryLocalPCSVerifier.residualBridge
    {Query RF Point : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (verifier :
      PiDECProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        count signedDigitCount decompositionCount publicSplitCount
        lowNormCount) :
    TerminalAIRProductionConcretePackedQueryResidualBridge
      Query
      (PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount)
      (PiDECScheduledRowTranscript RF rows columns signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
      (PiDECAIRResidualValue RF)
      Point where
  productionInstantiation := verifier.toProductionInstantiation
  scheduledIndex := verifier.packed.scheduledIndex
  concreteRowResidual := fun index =>
    PiDECConcreteAIRRowResidual verifier.packed.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [PiDECProductionPackedQueryLocalPCSVerifier.toProductionInstantiation,
      PiDECPackedQueryLocalPCSVerifier.toPackedVerifier,
      PiDECPackedQueryLocalPCSVerifier.traceOpening,
      PiDECScheduledRowTranscript.ofScheduleIndex]

theorem pidecProductionPCSQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query RF Point : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    {verifier :
      PiDECProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        count signedDigitCount decompositionCount publicSplitCount
        lowNormCount}
    {query : Query}
    (hAccepted : verifier.productionPCS.queryOpeningAccepted query) :
    PiDECConcreteAIRRowResidual
      verifier.packed.air
      (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiDECProductionPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRProductionConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_pidecProductionPackedConcreteAIRRowResiduals_zero_at_queries
    {Query RF Point : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    {verifier :
      PiDECProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        count signedDigitCount decompositionCount publicSplitCount
        lowNormCount}
    (hAccepts : verifier.productionPCS.sourceFreePCSVerifierAccepts) :
    ∀ query,
      PiDECConcreteAIRRowResidual
        verifier.packed.air
        (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiDECProductionPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRProductionConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure PiRLCPackedQueryLocalPCSVerifier
    (Query RF : Type) [CommRing RF]
    (count rows publicCount evalCount pointVars : Nat) where
  air : PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars
  rowContext : TerminalAIRRowTranscriptContext
  subrelationStartIndex : Nat
  digestFieldCount : Nat
  packedTraceResidual :
    TerminalAIRPackedTraceResidual
      (PiRLCScheduledRowTranscript RF count rows publicCount evalCount
        pointVars)
      (PiRLCAIRResidualValue RF)
  queryIndex : Query → Nat
  scheduledIndex :
    Query →
      PiRLCScheduleIndex count rows publicCount evalCount pointVars
  residualOpening : Query → PiRLCAIRResidualValue RF
  queryOpeningAccepted : Query → Prop
  queryOpening_index_eq_observedResidualIndex :
    ∀ query, queryOpeningAccepted query →
      queryIndex query =
        (terminalAIRPiRLCProductionPackedLayout
          subrelationStartIndex digestFieldCount).observedResidualIndex
          (PiRLCScheduleIndex.toScheduledRowRef
            rowContext.publicBindingContext
            rowContext.terminalVerifierRelationDigest
            rowContext.recursiveRelationDigest rowContext.sourceDigest
            rowContext.sourceByteCount
            (scheduledIndex query))
  queryOpening_trace_eq_packed :
    ∀ query, queryOpeningAccepted query →
      PiRLCScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query) =
        packedTraceResidual.traceAt (queryIndex query)
  queryOpening_residual_eq_packed :
    ∀ query, queryOpeningAccepted query →
      residualOpening query =
        packedTraceResidual.residualAt (queryIndex query)
  packedResidual_eq_concreteAIRResidual :
    ∀ query, queryOpeningAccepted query →
      packedTraceResidual.residualAt
          ((terminalAIRPiRLCProductionPackedLayout
            subrelationStartIndex digestFieldCount).observedResidualIndex
            (PiRLCScheduleIndex.toScheduledRowRef
              rowContext.publicBindingContext
              rowContext.terminalVerifierRelationDigest
              rowContext.recursiveRelationDigest rowContext.sourceDigest
              rowContext.sourceByteCount
              (scheduledIndex query))) =
        (PiRLCScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query)).residual
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query → residualOpening query = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

def PiRLCPackedQueryLocalPCSVerifier.layout
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRPiRLCProductionPackedLayout
    verifier.subrelationStartIndex verifier.digestFieldCount

def PiRLCPackedQueryLocalPCSVerifier.scheduledRowRef
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars)
    (query : Query) : TerminalAIRScheduledRowRef :=
  PiRLCScheduleIndex.toScheduledRowRef
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def PiRLCPackedQueryLocalPCSVerifier.traceOpening
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars)
    (query : Query) :
    PiRLCScheduledRowTranscript RF count rows publicCount evalCount
      pointVars :=
  PiRLCScheduledRowTranscript.ofScheduleIndex
    verifier.air
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def PiRLCPackedQueryLocalPCSVerifier.toPackedVerifier
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars) :
    TerminalAIRPackedQueryLocalPCSVerifier
      Query
      (PiRLCScheduledRowTranscript RF count rows publicCount evalCount
        pointVars)
      (PiRLCAIRResidualValue RF) where
  layout := verifier.layout
  packedTraceResidual := verifier.packedTraceResidual
  queryIndex := verifier.queryIndex
  scheduledRow := verifier.scheduledRowRef
  traceOpening := verifier.traceOpening
  residualOpening := verifier.residualOpening
  concreteAIRResidual := fun _row trace => trace.residual
  queryOpeningAccepted := verifier.queryOpeningAccepted
  queryOpening_subrelation_matches_layout := by
    intro query _hAccepted
    exact
      pirlcProductionPackedLayout_subrelation_matches_rowRef
        verifier.subrelationStartIndex
        verifier.digestFieldCount
        verifier.rowContext.publicBindingContext
        verifier.rowContext.terminalVerifierRelationDigest
        verifier.rowContext.recursiveRelationDigest
        verifier.rowContext.sourceDigest
        verifier.rowContext.sourceByteCount
        (verifier.scheduledIndex query)
  queryOpening_index_eq_observedResidualIndex :=
    verifier.queryOpening_index_eq_observedResidualIndex
  queryOpening_trace_eq_packed :=
    verifier.queryOpening_trace_eq_packed
  queryOpening_residual_eq_packed :=
    verifier.queryOpening_residual_eq_packed
  packedResidual_eq_concreteAIRResidual :=
    verifier.packedResidual_eq_concreteAIRResidual
  queryOpening_residual_zero :=
    verifier.queryOpening_residual_zero
  sourceFreePCSVerifierAccepts := verifier.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_implies_queryOpeningAccepted :=
    verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted

def PiRLCPackedQueryLocalPCSVerifier.residualBridge
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars) :
    TerminalAIRConcretePackedQueryResidualBridge
      Query
      (PiRLCScheduleIndex count rows publicCount evalCount pointVars)
      (PiRLCScheduledRowTranscript RF count rows publicCount evalCount
        pointVars)
      (PiRLCAIRResidualValue RF) where
  packedVerifier := verifier.toPackedVerifier
  scheduledIndex := verifier.scheduledIndex
  concreteRowResidual := fun index =>
    PiRLCConcreteAIRRowResidual verifier.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [PiRLCPackedQueryLocalPCSVerifier.toPackedVerifier,
      PiRLCPackedQueryLocalPCSVerifier.traceOpening,
      PiRLCScheduledRowTranscript.ofScheduleIndex]

theorem pirlcPackedQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    {verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    PiRLCConcreteAIRRowResidual
      verifier.air
      (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiRLCPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_pirlcPackedConcreteAIRRowResiduals_zero_at_queries
    {Query RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    {verifier :
      PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
        evalCount pointVars}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    ∀ query,
      PiRLCConcreteAIRRowResidual
        verifier.air
        (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiRLCPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure PiRLCProductionPackedQueryLocalPCSVerifier
    (Query RF Point : Type) [CommRing RF]
    (count rows publicCount evalCount pointVars : Nat) where
  packed :
    PiRLCPackedQueryLocalPCSVerifier Query RF count rows publicCount
      evalCount pointVars
  productionPCS :
    TerminalAIRProductionPCSQueryVerifier
      Query Point (PiRLCAIRResidualValue RF)
  packedQueryAccepted_of_productionAccepted :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryOpeningAccepted query
  packedQueryIndex_eq_joint :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryIndex query =
        productionPCS.jointSchedule.jointQueryIndex query
  residualPolynomial_eq_packedResidualAtObserved :
    ∀ query, productionPCS.queryOpeningAccepted query →
      productionPCS.residualPolynomialAt
          (productionPCS.residualOpening query).point =
        packed.packedTraceResidual.residualAt
          (packed.layout.observedResidualIndex
            (packed.scheduledRowRef query))

def PiRLCProductionPackedQueryLocalPCSVerifier.toProductionInstantiation
    {Query RF Point : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCProductionPackedQueryLocalPCSVerifier Query RF Point count rows
        publicCount evalCount pointVars) :
    TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
      Query
      (PiRLCScheduledRowTranscript RF count rows publicCount evalCount
        pointVars)
      (PiRLCAIRResidualValue RF)
      Point where
  productionPCS := verifier.productionPCS
  packedVerifier := verifier.packed.toPackedVerifier
  packedQueryAccepted_of_productionAccepted :=
    verifier.packedQueryAccepted_of_productionAccepted
  packedQueryIndex_eq_joint :=
    verifier.packedQueryIndex_eq_joint
  residualPolynomial_eq_packedResidualAtObserved :=
    verifier.residualPolynomial_eq_packedResidualAtObserved

def PiRLCProductionPackedQueryLocalPCSVerifier.residualBridge
    {Query RF Point : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (verifier :
      PiRLCProductionPackedQueryLocalPCSVerifier Query RF Point count rows
        publicCount evalCount pointVars) :
    TerminalAIRProductionConcretePackedQueryResidualBridge
      Query
      (PiRLCScheduleIndex count rows publicCount evalCount pointVars)
      (PiRLCScheduledRowTranscript RF count rows publicCount evalCount
        pointVars)
      (PiRLCAIRResidualValue RF)
      Point where
  productionInstantiation := verifier.toProductionInstantiation
  scheduledIndex := verifier.packed.scheduledIndex
  concreteRowResidual := fun index =>
    PiRLCConcreteAIRRowResidual verifier.packed.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [PiRLCProductionPackedQueryLocalPCSVerifier.toProductionInstantiation,
      PiRLCPackedQueryLocalPCSVerifier.toPackedVerifier,
      PiRLCPackedQueryLocalPCSVerifier.traceOpening,
      PiRLCScheduledRowTranscript.ofScheduleIndex]

theorem pirlcProductionPCSQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query RF Point : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    {verifier :
      PiRLCProductionPackedQueryLocalPCSVerifier Query RF Point count rows
        publicCount evalCount pointVars}
    {query : Query}
    (hAccepted : verifier.productionPCS.queryOpeningAccepted query) :
    PiRLCConcreteAIRRowResidual
      verifier.packed.air
      (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiRLCProductionPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRProductionConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_pirlcProductionPackedConcreteAIRRowResiduals_zero_at_queries
    {Query RF Point : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    {verifier :
      PiRLCProductionPackedQueryLocalPCSVerifier Query RF Point count rows
        publicCount evalCount pointVars}
    (hAccepts : verifier.productionPCS.sourceFreePCSVerifierAccepts) :
    ∀ query,
      PiRLCConcreteAIRRowResidual
        verifier.packed.air
        (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiRLCProductionPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRProductionConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure PiCCSPackedQueryLocalPCSVerifier
    (Query K : Type) [CommRing K]
    (rounds : Nat) where
  air : PiCCSConcreteAIRRows K rounds
  rowContext : TerminalAIRRowTranscriptContext
  subrelationStartIndex : Nat
  digestFieldCount : Nat
  packedTraceResidual :
    TerminalAIRPackedTraceResidual
      (PiCCSScheduledRowTranscript K rounds)
      (PiCCSAIRResidualValue K)
  queryIndex : Query → Nat
  scheduledIndex : Query → PiCCSScheduleIndex rounds
  residualOpening : Query → PiCCSAIRResidualValue K
  queryOpeningAccepted : Query → Prop
  queryOpening_index_eq_observedResidualIndex :
    ∀ query, queryOpeningAccepted query →
      queryIndex query =
        (terminalAIRPiCCSProductionPackedLayout
          subrelationStartIndex digestFieldCount).observedResidualIndex
          (PiCCSScheduleIndex.toScheduledRowRef
            rowContext.publicBindingContext
            rowContext.terminalVerifierRelationDigest
            rowContext.recursiveRelationDigest rowContext.sourceDigest
            rowContext.sourceByteCount
            (scheduledIndex query))
  queryOpening_trace_eq_packed :
    ∀ query, queryOpeningAccepted query →
      PiCCSScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query) =
        packedTraceResidual.traceAt (queryIndex query)
  queryOpening_residual_eq_packed :
    ∀ query, queryOpeningAccepted query →
      residualOpening query =
        packedTraceResidual.residualAt (queryIndex query)
  packedResidual_eq_concreteAIRResidual :
    ∀ query, queryOpeningAccepted query →
      packedTraceResidual.residualAt
          ((terminalAIRPiCCSProductionPackedLayout
            subrelationStartIndex digestFieldCount).observedResidualIndex
            (PiCCSScheduleIndex.toScheduledRowRef
              rowContext.publicBindingContext
              rowContext.terminalVerifierRelationDigest
              rowContext.recursiveRelationDigest rowContext.sourceDigest
              rowContext.sourceByteCount
              (scheduledIndex query))) =
        (PiCCSScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query)).residual
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query → residualOpening query = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

def PiCCSPackedQueryLocalPCSVerifier.layout
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRPiCCSProductionPackedLayout
    verifier.subrelationStartIndex verifier.digestFieldCount

def PiCCSPackedQueryLocalPCSVerifier.scheduledRowRef
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds)
    (query : Query) : TerminalAIRScheduledRowRef :=
  PiCCSScheduleIndex.toScheduledRowRef
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def PiCCSPackedQueryLocalPCSVerifier.traceOpening
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds)
    (query : Query) : PiCCSScheduledRowTranscript K rounds :=
  PiCCSScheduledRowTranscript.ofScheduleIndex
    verifier.air
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def PiCCSPackedQueryLocalPCSVerifier.toPackedVerifier
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds) :
    TerminalAIRPackedQueryLocalPCSVerifier
      Query
      (PiCCSScheduledRowTranscript K rounds)
      (PiCCSAIRResidualValue K) where
  layout := verifier.layout
  packedTraceResidual := verifier.packedTraceResidual
  queryIndex := verifier.queryIndex
  scheduledRow := verifier.scheduledRowRef
  traceOpening := verifier.traceOpening
  residualOpening := verifier.residualOpening
  concreteAIRResidual := fun _row trace => trace.residual
  queryOpeningAccepted := verifier.queryOpeningAccepted
  queryOpening_subrelation_matches_layout := by
    intro query _hAccepted
    exact
      piccsProductionPackedLayout_subrelation_matches_rowRef
        verifier.subrelationStartIndex
        verifier.digestFieldCount
        verifier.rowContext.publicBindingContext
        verifier.rowContext.terminalVerifierRelationDigest
        verifier.rowContext.recursiveRelationDigest
        verifier.rowContext.sourceDigest
        verifier.rowContext.sourceByteCount
        (verifier.scheduledIndex query)
  queryOpening_index_eq_observedResidualIndex :=
    verifier.queryOpening_index_eq_observedResidualIndex
  queryOpening_trace_eq_packed :=
    verifier.queryOpening_trace_eq_packed
  queryOpening_residual_eq_packed :=
    verifier.queryOpening_residual_eq_packed
  packedResidual_eq_concreteAIRResidual :=
    verifier.packedResidual_eq_concreteAIRResidual
  queryOpening_residual_zero :=
    verifier.queryOpening_residual_zero
  sourceFreePCSVerifierAccepts := verifier.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_implies_queryOpeningAccepted :=
    verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted

def PiCCSPackedQueryLocalPCSVerifier.residualBridge
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds) :
    TerminalAIRConcretePackedQueryResidualBridge
      Query
      (PiCCSScheduleIndex rounds)
      (PiCCSScheduledRowTranscript K rounds)
      (PiCCSAIRResidualValue K) where
  packedVerifier := verifier.toPackedVerifier
  scheduledIndex := verifier.scheduledIndex
  concreteRowResidual := fun index =>
    PiCCSConcreteAIRRowResidual verifier.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [PiCCSPackedQueryLocalPCSVerifier.toPackedVerifier,
      PiCCSPackedQueryLocalPCSVerifier.traceOpening,
      PiCCSScheduledRowTranscript.ofScheduleIndex]

theorem piccsPackedQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    {verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    PiCCSConcreteAIRRowResidual
      verifier.air
      (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiCCSPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_piccsPackedConcreteAIRRowResiduals_zero_at_queries
    {Query K : Type} [CommRing K]
    {rounds : Nat}
    {verifier :
      PiCCSPackedQueryLocalPCSVerifier Query K rounds}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    ∀ query,
      PiCCSConcreteAIRRowResidual
        verifier.air
        (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiCCSPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure PiCCSProductionPackedQueryLocalPCSVerifier
    (Query K Point : Type) [CommRing K]
    (rounds : Nat) where
  packed : PiCCSPackedQueryLocalPCSVerifier Query K rounds
  productionPCS :
    TerminalAIRProductionPCSQueryVerifier
      Query Point (PiCCSAIRResidualValue K)
  packedQueryAccepted_of_productionAccepted :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryOpeningAccepted query
  packedQueryIndex_eq_joint :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryIndex query =
        productionPCS.jointSchedule.jointQueryIndex query
  residualPolynomial_eq_packedResidualAtObserved :
    ∀ query, productionPCS.queryOpeningAccepted query →
      productionPCS.residualPolynomialAt
          (productionPCS.residualOpening query).point =
        packed.packedTraceResidual.residualAt
          (packed.layout.observedResidualIndex
            (packed.scheduledRowRef query))

def PiCCSProductionPackedQueryLocalPCSVerifier.toProductionInstantiation
    {Query K Point : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSProductionPackedQueryLocalPCSVerifier Query K Point rounds) :
    TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
      Query
      (PiCCSScheduledRowTranscript K rounds)
      (PiCCSAIRResidualValue K)
      Point where
  productionPCS := verifier.productionPCS
  packedVerifier := verifier.packed.toPackedVerifier
  packedQueryAccepted_of_productionAccepted :=
    verifier.packedQueryAccepted_of_productionAccepted
  packedQueryIndex_eq_joint :=
    verifier.packedQueryIndex_eq_joint
  residualPolynomial_eq_packedResidualAtObserved :=
    verifier.residualPolynomial_eq_packedResidualAtObserved

def PiCCSProductionPackedQueryLocalPCSVerifier.residualBridge
    {Query K Point : Type} [CommRing K]
    {rounds : Nat}
    (verifier :
      PiCCSProductionPackedQueryLocalPCSVerifier Query K Point rounds) :
    TerminalAIRProductionConcretePackedQueryResidualBridge
      Query
      (PiCCSScheduleIndex rounds)
      (PiCCSScheduledRowTranscript K rounds)
      (PiCCSAIRResidualValue K)
      Point where
  productionInstantiation := verifier.toProductionInstantiation
  scheduledIndex := verifier.packed.scheduledIndex
  concreteRowResidual := fun index =>
    PiCCSConcreteAIRRowResidual verifier.packed.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [PiCCSProductionPackedQueryLocalPCSVerifier.toProductionInstantiation,
      PiCCSPackedQueryLocalPCSVerifier.toPackedVerifier,
      PiCCSPackedQueryLocalPCSVerifier.traceOpening,
      PiCCSScheduledRowTranscript.ofScheduleIndex]

theorem piccsProductionPCSQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query K Point : Type} [CommRing K]
    {rounds : Nat}
    {verifier :
      PiCCSProductionPackedQueryLocalPCSVerifier Query K Point rounds}
    {query : Query}
    (hAccepted : verifier.productionPCS.queryOpeningAccepted query) :
    PiCCSConcreteAIRRowResidual
      verifier.packed.air
      (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiCCSProductionPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRProductionConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_piccsProductionPackedConcreteAIRRowResiduals_zero_at_queries
    {Query K Point : Type} [CommRing K]
    {rounds : Nat}
    {verifier :
      PiCCSProductionPackedQueryLocalPCSVerifier Query K Point rounds}
    (hAccepts : verifier.productionPCS.sourceFreePCSVerifierAccepts) :
    ∀ query,
      PiCCSConcreteAIRRowResidual
        verifier.packed.air
        (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [PiCCSProductionPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRProductionConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure CEAjtaiPackedQueryLocalPCSVerifier
    (Query RF : Type) [CommRing RF]
    (rows columns publicCount evalCount pointVars : Nat) where
  air :
    CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars
  rowContext : TerminalAIRRowTranscriptContext
  subrelationStartIndex : Nat
  digestFieldCount : Nat
  packedTraceResidual :
    TerminalAIRPackedTraceResidual
      (CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
        pointVars)
      (CEAjtaiAIRResidualValue RF)
  queryIndex : Query → Nat
  scheduledIndex :
    Query →
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars
  residualOpening : Query → CEAjtaiAIRResidualValue RF
  queryOpeningAccepted : Query → Prop
  queryOpening_index_eq_observedResidualIndex :
    ∀ query, queryOpeningAccepted query →
      queryIndex query =
        (terminalAIRCEAjtaiProductionPackedLayout
          subrelationStartIndex digestFieldCount).observedResidualIndex
          (CEAjtaiScheduleIndex.toScheduledRowRef
            rowContext.publicBindingContext
            rowContext.terminalVerifierRelationDigest
            rowContext.recursiveRelationDigest rowContext.sourceDigest
            rowContext.sourceByteCount
            (scheduledIndex query))
  queryOpening_trace_eq_packed :
    ∀ query, queryOpeningAccepted query →
      CEAjtaiScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query) =
        packedTraceResidual.traceAt (queryIndex query)
  queryOpening_residual_eq_packed :
    ∀ query, queryOpeningAccepted query →
      residualOpening query =
        packedTraceResidual.residualAt (queryIndex query)
  packedResidual_eq_concreteAIRResidual :
    ∀ query, queryOpeningAccepted query →
      packedTraceResidual.residualAt
          ((terminalAIRCEAjtaiProductionPackedLayout
            subrelationStartIndex digestFieldCount).observedResidualIndex
            (CEAjtaiScheduleIndex.toScheduledRowRef
              rowContext.publicBindingContext
              rowContext.terminalVerifierRelationDigest
              rowContext.recursiveRelationDigest rowContext.sourceDigest
              rowContext.sourceByteCount
              (scheduledIndex query))) =
        (CEAjtaiScheduledRowTranscript.ofScheduleIndex
          air rowContext.publicBindingContext
          rowContext.terminalVerifierRelationDigest
          rowContext.recursiveRelationDigest rowContext.sourceDigest
          rowContext.sourceByteCount
          (scheduledIndex query)).residual
  queryOpening_residual_zero :
    ∀ query, queryOpeningAccepted query → residualOpening query = 0
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_implies_queryOpeningAccepted :
    sourceFreePCSVerifierAccepts →
      ∀ query, queryOpeningAccepted query

def CEAjtaiPackedQueryLocalPCSVerifier.layout
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars) :
    TerminalAIRPackedConstraintRowLayout :=
  terminalAIRCEAjtaiProductionPackedLayout
    verifier.subrelationStartIndex verifier.digestFieldCount

def CEAjtaiPackedQueryLocalPCSVerifier.scheduledRowRef
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars)
    (query : Query) : TerminalAIRScheduledRowRef :=
  CEAjtaiScheduleIndex.toScheduledRowRef
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def CEAjtaiPackedQueryLocalPCSVerifier.traceOpening
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars)
    (query : Query) :
    CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
      pointVars :=
  CEAjtaiScheduledRowTranscript.ofScheduleIndex
    verifier.air
    verifier.rowContext.publicBindingContext
    verifier.rowContext.terminalVerifierRelationDigest
    verifier.rowContext.recursiveRelationDigest
    verifier.rowContext.sourceDigest
    verifier.rowContext.sourceByteCount
    (verifier.scheduledIndex query)

def CEAjtaiPackedQueryLocalPCSVerifier.toPackedVerifier
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars) :
    TerminalAIRPackedQueryLocalPCSVerifier
      Query
      (CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
        pointVars)
      (CEAjtaiAIRResidualValue RF) where
  layout := verifier.layout
  packedTraceResidual := verifier.packedTraceResidual
  queryIndex := verifier.queryIndex
  scheduledRow := verifier.scheduledRowRef
  traceOpening := verifier.traceOpening
  residualOpening := verifier.residualOpening
  concreteAIRResidual := fun _row trace => trace.residual
  queryOpeningAccepted := verifier.queryOpeningAccepted
  queryOpening_subrelation_matches_layout := by
    intro query _hAccepted
    exact
      ceAjtaiProductionPackedLayout_subrelation_matches_rowRef
        verifier.subrelationStartIndex
        verifier.digestFieldCount
        verifier.rowContext.publicBindingContext
        verifier.rowContext.terminalVerifierRelationDigest
        verifier.rowContext.recursiveRelationDigest
        verifier.rowContext.sourceDigest
        verifier.rowContext.sourceByteCount
        (verifier.scheduledIndex query)
  queryOpening_index_eq_observedResidualIndex :=
    verifier.queryOpening_index_eq_observedResidualIndex
  queryOpening_trace_eq_packed :=
    verifier.queryOpening_trace_eq_packed
  queryOpening_residual_eq_packed :=
    verifier.queryOpening_residual_eq_packed
  packedResidual_eq_concreteAIRResidual :=
    verifier.packedResidual_eq_concreteAIRResidual
  queryOpening_residual_zero :=
    verifier.queryOpening_residual_zero
  sourceFreePCSVerifierAccepts := verifier.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_implies_queryOpeningAccepted :=
    verifier.sourceFreePCS_accepts_implies_queryOpeningAccepted

def CEAjtaiPackedQueryLocalPCSVerifier.residualBridge
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars) :
    TerminalAIRConcretePackedQueryResidualBridge
      Query
      (CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars)
      (CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
        pointVars)
      (CEAjtaiAIRResidualValue RF) where
  packedVerifier := verifier.toPackedVerifier
  scheduledIndex := verifier.scheduledIndex
  concreteRowResidual := fun index =>
    CEAjtaiConcreteAIRRowResidual verifier.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [CEAjtaiPackedQueryLocalPCSVerifier.toPackedVerifier,
      CEAjtaiPackedQueryLocalPCSVerifier.traceOpening,
      CEAjtaiScheduledRowTranscript.ofScheduleIndex]

theorem ceAjtaiPackedQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    {verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars}
    {query : Query}
    (hAccepted : verifier.queryOpeningAccepted query) :
    CEAjtaiConcreteAIRRowResidual
      verifier.air
      (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [CEAjtaiPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_ceAjtaiPackedConcreteAIRRowResiduals_zero_at_queries
    {Query RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    {verifier :
      CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
        evalCount pointVars}
    (hAccepts : verifier.sourceFreePCSVerifierAccepts) :
    ∀ query,
      CEAjtaiConcreteAIRRowResidual
        verifier.air
        (verifier.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [CEAjtaiPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

structure CEAjtaiProductionPackedQueryLocalPCSVerifier
    (Query RF Point : Type) [CommRing RF]
    (rows columns publicCount evalCount pointVars : Nat) where
  packed :
    CEAjtaiPackedQueryLocalPCSVerifier Query RF rows columns publicCount
      evalCount pointVars
  productionPCS :
    TerminalAIRProductionPCSQueryVerifier
      Query Point (CEAjtaiAIRResidualValue RF)
  packedQueryAccepted_of_productionAccepted :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryOpeningAccepted query
  packedQueryIndex_eq_joint :
    ∀ query, productionPCS.queryOpeningAccepted query →
      packed.queryIndex query =
        productionPCS.jointSchedule.jointQueryIndex query
  residualPolynomial_eq_packedResidualAtObserved :
    ∀ query, productionPCS.queryOpeningAccepted query →
      productionPCS.residualPolynomialAt
          (productionPCS.residualOpening query).point =
        packed.packedTraceResidual.residualAt
          (packed.layout.observedResidualIndex
            (packed.scheduledRowRef query))

def CEAjtaiProductionPackedQueryLocalPCSVerifier.toProductionInstantiation
    {Query RF Point : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        publicCount evalCount pointVars) :
    TerminalAIRProductionPCSInstantiatesPackedQueryVerifier
      Query
      (CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
        pointVars)
      (CEAjtaiAIRResidualValue RF)
      Point where
  productionPCS := verifier.productionPCS
  packedVerifier := verifier.packed.toPackedVerifier
  packedQueryAccepted_of_productionAccepted :=
    verifier.packedQueryAccepted_of_productionAccepted
  packedQueryIndex_eq_joint :=
    verifier.packedQueryIndex_eq_joint
  residualPolynomial_eq_packedResidualAtObserved :=
    verifier.residualPolynomial_eq_packedResidualAtObserved

def CEAjtaiProductionPackedQueryLocalPCSVerifier.residualBridge
    {Query RF Point : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (verifier :
      CEAjtaiProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        publicCount evalCount pointVars) :
    TerminalAIRProductionConcretePackedQueryResidualBridge
      Query
      (CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars)
      (CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
        pointVars)
      (CEAjtaiAIRResidualValue RF)
      Point where
  productionInstantiation := verifier.toProductionInstantiation
  scheduledIndex := verifier.packed.scheduledIndex
  concreteRowResidual := fun index =>
    CEAjtaiConcreteAIRRowResidual verifier.packed.air index.toConcreteIndex
  concreteAIRResidual_eq_concreteRowResidual := by
    intro query
    simp [CEAjtaiProductionPackedQueryLocalPCSVerifier.toProductionInstantiation,
      CEAjtaiPackedQueryLocalPCSVerifier.toPackedVerifier,
      CEAjtaiPackedQueryLocalPCSVerifier.traceOpening,
      CEAjtaiScheduledRowTranscript.ofScheduleIndex]

theorem ceAjtaiProductionPCSQueryOpening_accepts_implies_concreteAIRRowResidual_zero
    {Query RF Point : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    {verifier :
      CEAjtaiProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        publicCount evalCount pointVars}
    {query : Query}
    (hAccepted : verifier.productionPCS.queryOpeningAccepted query) :
    CEAjtaiConcreteAIRRowResidual
      verifier.packed.air
      (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [CEAjtaiProductionPackedQueryLocalPCSVerifier.residualBridge] using
    terminalAIRProductionConcretePackedQueryResidualBridge_accepts_implies_concreteRowResidual_zero
      (bridge := verifier.residualBridge) hAccepted

theorem sourceFreePCS_accepts_implies_ceAjtaiProductionPackedConcreteAIRRowResiduals_zero_at_queries
    {Query RF Point : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    {verifier :
      CEAjtaiProductionPackedQueryLocalPCSVerifier Query RF Point rows columns
        publicCount evalCount pointVars}
    (hAccepts : verifier.productionPCS.sourceFreePCSVerifierAccepts) :
    ∀ query,
      CEAjtaiConcreteAIRRowResidual
        verifier.packed.air
        (verifier.packed.scheduledIndex query).toConcreteIndex = 0 := by
  simpa [CEAjtaiProductionPackedQueryLocalPCSVerifier.residualBridge] using
    sourceFreePCS_accepts_implies_terminalAIRProductionConcretePackedQueryResidualBridge_concreteRowResiduals_zero_at_queries
      (bridge := verifier.residualBridge) hAccepts

inductive TerminalAIRPrimitiveFamilyQuery
    (PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery : Type) where
  | piCCS : PiCCSQuery →
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
  | piRLC : PiRLCQuery →
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
  | piDEC : PiDECQuery →
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
  | ceAjtai : CEAjtaiQuery →
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery

structure TerminalAIRProductionPackedFamilyPCSVerifiers
    (PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type)
    [CommRing K] [CommRing RF]
    (piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat) where
  piccs :
    PiCCSProductionPackedQueryLocalPCSVerifier
      PiCCSQuery K PiCCSPoint piccsRounds
  pirlc :
    PiRLCProductionPackedQueryLocalPCSVerifier
      PiRLCQuery RF PiRLCPoint pirlcCount pirlcRows
      pirlcPublicCount pirlcEvalCount pirlcPointVars
  pidec :
    PiDECProductionPackedQueryLocalPCSVerifier
      PiDECQuery RF PiDECPoint pidecRows pidecColumns pidecCount
      pidecSignedDigitCount pidecDecompositionCount pidecPublicSplitCount
      pidecLowNormCount
  ceAjtai :
    CEAjtaiProductionPackedQueryLocalPCSVerifier
      CEAjtaiQuery RF CEAjtaiPoint ceRows ceColumns cePublicCount
      ceEvalCount cePointVars
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_piccs :
    sourceFreePCSVerifierAccepts →
      piccs.productionPCS.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_pirlc :
    sourceFreePCSVerifierAccepts →
      pirlc.productionPCS.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_pidec :
    sourceFreePCSVerifierAccepts →
      pidec.productionPCS.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_ceAjtai :
    sourceFreePCSVerifierAccepts →
      ceAjtai.productionPCS.sourceFreePCSVerifierAccepts

def TerminalAIRProductionPackedFamilyConcreteResidualZeroAtQuery
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (verifiers :
      TerminalAIRProductionPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars)
    (query :
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery) : Prop :=
  match query with
  | .piCCS query =>
      PiCCSConcreteAIRRowResidual
        verifiers.piccs.packed.air
        (verifiers.piccs.packed.scheduledIndex query).toConcreteIndex = 0
  | .piRLC query =>
      PiRLCConcreteAIRRowResidual
        verifiers.pirlc.packed.air
        (verifiers.pirlc.packed.scheduledIndex query).toConcreteIndex = 0
  | .piDEC query =>
      PiDECConcreteAIRRowResidual
        verifiers.pidec.packed.air
        (verifiers.pidec.packed.scheduledIndex query).toConcreteIndex = 0
  | .ceAjtai query =>
      CEAjtaiConcreteAIRRowResidual
        verifiers.ceAjtai.packed.air
        (verifiers.ceAjtai.packed.scheduledIndex query).toConcreteIndex = 0

theorem sourceFreePCS_accepts_implies_terminalAIRProductionPackedFamily_concreteResidual_zero_at_query
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    {verifiers :
      TerminalAIRProductionPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars}
    (hAccepts : verifiers.sourceFreePCSVerifierAccepts)
    (query :
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery) :
    TerminalAIRProductionPackedFamilyConcreteResidualZeroAtQuery
      verifiers query := by
  cases query with
  | piCCS query =>
      exact
        sourceFreePCS_accepts_implies_piccsProductionPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.piccs)
          (verifiers.sourceFreePCS_accepts_piccs hAccepts)
          query
  | piRLC query =>
      exact
        sourceFreePCS_accepts_implies_pirlcProductionPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.pirlc)
          (verifiers.sourceFreePCS_accepts_pirlc hAccepts)
          query
  | piDEC query =>
      exact
        sourceFreePCS_accepts_implies_pidecProductionPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.pidec)
          (verifiers.sourceFreePCS_accepts_pidec hAccepts)
          query
  | ceAjtai query =>
      exact
        sourceFreePCS_accepts_implies_ceAjtaiProductionPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.ceAjtai)
          (verifiers.sourceFreePCS_accepts_ceAjtai hAccepts)
          query

theorem sourceFreePCS_accepts_implies_terminalAIRProductionPackedFamily_concreteResiduals_zero_at_queries
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    {verifiers :
      TerminalAIRProductionPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars}
    (hAccepts : verifiers.sourceFreePCSVerifierAccepts) :
    ∀ query :
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery,
      TerminalAIRProductionPackedFamilyConcreteResidualZeroAtQuery
        verifiers query := by
  intro query
  exact
    sourceFreePCS_accepts_implies_terminalAIRProductionPackedFamily_concreteResidual_zero_at_query
      (verifiers := verifiers) hAccepts query

structure TerminalAIRProductionPackedFamilyQueryCoversSchedule
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (verifiers :
      TerminalAIRProductionPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) where
  piccs :
    ∀ index : PiCCSScheduleIndex piccsRounds,
      ∃ query : PiCCSQuery,
        verifiers.piccs.packed.scheduledIndex query = index
  pirlc :
    ∀ index :
      PiRLCScheduleIndex pirlcCount pirlcRows pirlcPublicCount
        pirlcEvalCount pirlcPointVars,
      ∃ query : PiRLCQuery,
        verifiers.pirlc.packed.scheduledIndex query = index
  pidec :
    ∀ index :
      PiDECScheduleIndex pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount,
      ∃ query : PiDECQuery,
        verifiers.pidec.packed.scheduledIndex query = index
  ceAjtai :
    ∀ index :
      CEAjtaiScheduleIndex ceRows ceColumns cePublicCount ceEvalCount
        cePointVars,
      ∃ query : CEAjtaiQuery,
        verifiers.ceAjtai.packed.scheduledIndex query = index

theorem sourceFreePCS_accepts_implies_terminalAIRProductionPackedFamily_concreteAllRowsZero_of_scheduleCoverage
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    {verifiers :
      TerminalAIRProductionPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars}
    (coverage :
      TerminalAIRProductionPackedFamilyQueryCoversSchedule verifiers)
    (hAccepts : verifiers.sourceFreePCSVerifierAccepts) :
    PiCCSConcreteAIRAllRowsZero verifiers.piccs.packed.air ∧
      PiRLCConcreteAIRAllRowsZero verifiers.pirlc.packed.air ∧
      PiDECConcreteAIRAllRowsZero verifiers.pidec.packed.air ∧
      CEAjtaiConcreteAIRAllRowsZero verifiers.ceAjtai.packed.air := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro concreteIndex
    rcases coverage.piccs
        (PiCCSScheduleIndex.fromConcreteIndex concreteIndex) with
      ⟨query, hQuery⟩
    have hZero :=
      sourceFreePCS_accepts_implies_piccsProductionPackedConcreteAIRRowResiduals_zero_at_queries
        (verifier := verifiers.piccs)
        (verifiers.sourceFreePCS_accepts_piccs hAccepts)
        query
    rw [hQuery] at hZero
    simpa [piccsSchedule_toConcrete_fromConcrete concreteIndex] using hZero
  · intro concreteIndex
    rcases coverage.pirlc
        (PiRLCScheduleIndex.fromConcreteIndex concreteIndex) with
      ⟨query, hQuery⟩
    have hZero :=
      sourceFreePCS_accepts_implies_pirlcProductionPackedConcreteAIRRowResiduals_zero_at_queries
        (verifier := verifiers.pirlc)
        (verifiers.sourceFreePCS_accepts_pirlc hAccepts)
        query
    rw [hQuery] at hZero
    simpa [pirlcSchedule_toConcrete_fromConcrete concreteIndex] using hZero
  · intro concreteIndex
    rcases coverage.pidec
        (PiDECScheduleIndex.fromConcreteIndex concreteIndex) with
      ⟨query, hQuery⟩
    have hZero :=
      sourceFreePCS_accepts_implies_pidecProductionPackedConcreteAIRRowResiduals_zero_at_queries
        (verifier := verifiers.pidec)
        (verifiers.sourceFreePCS_accepts_pidec hAccepts)
        query
    rw [hQuery] at hZero
    simpa [pidecSchedule_toConcrete_fromConcrete concreteIndex] using hZero
  · intro concreteIndex
    rcases coverage.ceAjtai
        (CEAjtaiScheduleIndex.fromConcreteIndex concreteIndex) with
      ⟨query, hQuery⟩
    have hZero :=
      sourceFreePCS_accepts_implies_ceAjtaiProductionPackedConcreteAIRRowResiduals_zero_at_queries
        (verifier := verifiers.ceAjtai)
        (verifiers.sourceFreePCS_accepts_ceAjtai hAccepts)
        query
    rw [hQuery] at hZero
    simpa [ceAjtaiSchedule_toConcrete_fromConcrete concreteIndex] using hZero

theorem sourceFreePCS_accepts_implies_terminalAIRProductionPackedFamily_verifierSteps_of_scheduleCoverage
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery
      K RF PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    {verifiers :
      TerminalAIRProductionPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        PiCCSPoint PiRLCPoint PiDECPoint CEAjtaiPoint
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars}
    (coverage :
      TerminalAIRProductionPackedFamilyQueryCoversSchedule verifiers)
    (hAccepts : verifiers.sourceFreePCSVerifierAccepts) :
    PiCCSConcreteVerifierStep verifiers.piccs.packed.air ∧
      PiRLCConcreteVerifierStep verifiers.pirlc.packed.air ∧
      PiDECConcreteVerifierStep verifiers.pidec.packed.air ∧
      CEAjtaiConcreteVerifierStep verifiers.ceAjtai.packed.air := by
  have hRows :=
    sourceFreePCS_accepts_implies_terminalAIRProductionPackedFamily_concreteAllRowsZero_of_scheduleCoverage
      (verifiers := verifiers) coverage hAccepts
  rcases hRows with ⟨hPiCCS, hPiRLC, hPiDEC, hCEAjtai⟩
  exact
    ⟨(piccsConcreteAIR_allRowsZero_iff_verifierStep
        verifiers.piccs.packed.air).mp hPiCCS,
      (pirlcConcreteAIR_allRowsZero_iff_verifierStep
        verifiers.pirlc.packed.air).mp hPiRLC,
      (pidecConcreteAIR_allRowsZero_iff_verifierStep
        verifiers.pidec.packed.air).mp hPiDEC,
      (ceAjtaiConcreteAIR_allRowsZero_iff_verifierStep
        verifiers.ceAjtai.packed.air).mp hCEAjtai⟩

structure TerminalAIRPackedFamilyPCSVerifiers
    (PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF : Type)
    [CommRing K] [CommRing RF]
    (piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat) where
  piccs :
    PiCCSPackedQueryLocalPCSVerifier PiCCSQuery K piccsRounds
  pirlc :
    PiRLCPackedQueryLocalPCSVerifier PiRLCQuery RF pirlcCount pirlcRows
      pirlcPublicCount pirlcEvalCount pirlcPointVars
  pidec :
    PiDECPackedQueryLocalPCSVerifier PiDECQuery RF pidecRows pidecColumns
      pidecCount pidecSignedDigitCount pidecDecompositionCount
      pidecPublicSplitCount pidecLowNormCount
  ceAjtai :
    CEAjtaiPackedQueryLocalPCSVerifier CEAjtaiQuery RF ceRows ceColumns
      cePublicCount ceEvalCount cePointVars
  sourceFreePCSVerifierAccepts : Prop
  sourceFreePCS_accepts_piccs :
    sourceFreePCSVerifierAccepts → piccs.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_pirlc :
    sourceFreePCSVerifierAccepts → pirlc.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_pidec :
    sourceFreePCSVerifierAccepts → pidec.sourceFreePCSVerifierAccepts
  sourceFreePCS_accepts_ceAjtai :
    sourceFreePCSVerifierAccepts → ceAjtai.sourceFreePCSVerifierAccepts

def TerminalAIRPackedFamilyConcreteResidualZeroAtQuery
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (verifiers :
      TerminalAIRPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars)
    (query :
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery) : Prop :=
  match query with
  | .piCCS query =>
      PiCCSConcreteAIRRowResidual
        verifiers.piccs.air
        (verifiers.piccs.scheduledIndex query).toConcreteIndex = 0
  | .piRLC query =>
      PiRLCConcreteAIRRowResidual
        verifiers.pirlc.air
        (verifiers.pirlc.scheduledIndex query).toConcreteIndex = 0
  | .piDEC query =>
      PiDECConcreteAIRRowResidual
        verifiers.pidec.air
        (verifiers.pidec.scheduledIndex query).toConcreteIndex = 0
  | .ceAjtai query =>
      CEAjtaiConcreteAIRRowResidual
        verifiers.ceAjtai.air
        (verifiers.ceAjtai.scheduledIndex query).toConcreteIndex = 0

theorem sourceFreePCS_accepts_implies_terminalAIRPackedFamily_concreteResidual_zero_at_query
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    {verifiers :
      TerminalAIRPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars}
    (hAccepts : verifiers.sourceFreePCSVerifierAccepts)
    (query :
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery) :
    TerminalAIRPackedFamilyConcreteResidualZeroAtQuery
      verifiers query := by
  cases query with
  | piCCS query =>
      exact
        sourceFreePCS_accepts_implies_piccsPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.piccs)
          (verifiers.sourceFreePCS_accepts_piccs hAccepts)
          query
  | piRLC query =>
      exact
        sourceFreePCS_accepts_implies_pirlcPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.pirlc)
          (verifiers.sourceFreePCS_accepts_pirlc hAccepts)
          query
  | piDEC query =>
      exact
        sourceFreePCS_accepts_implies_pidecPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.pidec)
          (verifiers.sourceFreePCS_accepts_pidec hAccepts)
          query
  | ceAjtai query =>
      exact
        sourceFreePCS_accepts_implies_ceAjtaiPackedConcreteAIRRowResiduals_zero_at_queries
          (verifier := verifiers.ceAjtai)
          (verifiers.sourceFreePCS_accepts_ceAjtai hAccepts)
          query

theorem sourceFreePCS_accepts_implies_terminalAIRPackedFamily_concreteResiduals_zero_at_queries
    {PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF : Type}
    [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    {verifiers :
      TerminalAIRPackedFamilyPCSVerifiers
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars}
    (hAccepts : verifiers.sourceFreePCSVerifierAccepts) :
    ∀ query :
      TerminalAIRPrimitiveFamilyQuery
        PiCCSQuery PiRLCQuery PiDECQuery CEAjtaiQuery,
      TerminalAIRPackedFamilyConcreteResidualZeroAtQuery
        verifiers query := by
  intro query
  exact
    sourceFreePCS_accepts_implies_terminalAIRPackedFamily_concreteResidual_zero_at_query
      (verifiers := verifiers) hAccepts query

inductive TerminalAIRPrimitiveFamilyScheduleIndex
    (piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat) where
  | piCCS :
      PiCCSScheduleIndex piccsRounds →
        TerminalAIRPrimitiveFamilyScheduleIndex
          piccsRounds
          pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
          pirlcPointVars
          pidecRows pidecColumns pidecSignedDigitCount
          pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
          ceRows ceColumns cePublicCount ceEvalCount cePointVars
  | piRLC :
      PiRLCScheduleIndex pirlcCount pirlcRows pirlcPublicCount
        pirlcEvalCount pirlcPointVars →
        TerminalAIRPrimitiveFamilyScheduleIndex
          piccsRounds
          pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
          pirlcPointVars
          pidecRows pidecColumns pidecSignedDigitCount
          pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
          ceRows ceColumns cePublicCount ceEvalCount cePointVars
  | piDEC :
      PiDECScheduleIndex pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount →
        TerminalAIRPrimitiveFamilyScheduleIndex
          piccsRounds
          pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
          pirlcPointVars
          pidecRows pidecColumns pidecSignedDigitCount
          pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
          ceRows ceColumns cePublicCount ceEvalCount cePointVars
  | ceAjtai :
      CEAjtaiScheduleIndex ceRows ceColumns cePublicCount ceEvalCount
        cePointVars →
        TerminalAIRPrimitiveFamilyScheduleIndex
          piccsRounds
          pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
          pirlcPointVars
          pidecRows pidecColumns pidecSignedDigitCount
          pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
          ceRows ceColumns cePublicCount ceEvalCount cePointVars
  deriving DecidableEq

def TerminalAIRPrimitiveFamilyScheduleIndex.subrelationKind
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRSubrelationKind :=
  match index with
  | .piCCS index => index.subrelationKind
  | .piRLC index => index.subrelationKind
  | .piDEC index => index.subrelationKind
  | .ceAjtai index => index.subrelationKind

def TerminalAIRPrimitiveFamilyScheduleIndex.globalRowIndex
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) : Nat :=
  match index with
  | .piCCS index => index.globalRowIndex
  | .piRLC index => index.globalRowIndex
  | .piDEC index => index.globalRowIndex
  | .ceAjtai index => index.globalRowIndex

structure TerminalAIRPrimitiveFamilyScheduleKey where
  subrelationKind : TerminalAIRSubrelationKind
  globalRowIndex : Nat
  deriving DecidableEq

def TerminalAIRPrimitiveFamilyScheduleIndex.scheduleKey
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRPrimitiveFamilyScheduleKey where
  subrelationKind := index.subrelationKind
  globalRowIndex := index.globalRowIndex

def TerminalAIRPrimitiveFamilyScheduleIndex.toScheduledRowRef
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (publicBindingContext : TerminalAIRPublicBindingContext)
    (terminalVerifierRelationDigest : Digest256Wire)
    (recursiveRelationDigest : Option Digest256Wire)
    (sourceDigest : Digest256Wire)
    (sourceByteCount : Nat)
    (index :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRScheduledRowRef :=
  match index with
  | .piCCS index =>
      index.toScheduledRowRef
        publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount
  | .piRLC index =>
      index.toScheduledRowRef
        publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount
  | .piDEC index =>
      index.toScheduledRowRef
        publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount
  | .ceAjtai index =>
      index.toScheduledRowRef
        publicBindingContext terminalVerifierRelationDigest
        recursiveRelationDigest sourceDigest sourceByteCount

def TerminalAIRPrimitiveFamilyScheduleNoDuplicateKeys
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat} :
    Prop :=
  Function.Injective
    (TerminalAIRPrimitiveFamilyScheduleIndex.scheduleKey
      (piccsRounds := piccsRounds)
      (pirlcCount := pirlcCount)
      (pirlcRows := pirlcRows)
      (pirlcPublicCount := pirlcPublicCount)
      (pirlcEvalCount := pirlcEvalCount)
      (pirlcPointVars := pirlcPointVars)
      (pidecRows := pidecRows)
      (pidecColumns := pidecColumns)
      (pidecSignedDigitCount := pidecSignedDigitCount)
      (pidecDecompositionCount := pidecDecompositionCount)
      (pidecPublicSplitCount := pidecPublicSplitCount)
      (pidecLowNormCount := pidecLowNormCount)
      (ceRows := ceRows)
      (ceColumns := ceColumns)
      (cePublicCount := cePublicCount)
      (ceEvalCount := ceEvalCount)
      (cePointVars := cePointVars))

def TerminalAIRPrimitiveFamilySchedulePerFamilyGlobalIndicesInjective
    (piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat) :
    Prop :=
  Function.Injective
      (PiCCSScheduleIndex.globalRowIndex
        (rounds := piccsRounds)) ∧
    Function.Injective
      (PiRLCScheduleIndex.globalRowIndex
        (count := pirlcCount)
        (rows := pirlcRows)
        (publicCount := pirlcPublicCount)
        (evalCount := pirlcEvalCount)
        (pointVars := pirlcPointVars)) ∧
    Function.Injective
      (PiDECScheduleIndex.globalRowIndex
        (rows := pidecRows)
        (columns := pidecColumns)
        (signedDigitCount := pidecSignedDigitCount)
        (decompositionCount := pidecDecompositionCount)
        (publicSplitCount := pidecPublicSplitCount)
        (lowNormCount := pidecLowNormCount)) ∧
    Function.Injective
      (CEAjtaiScheduleIndex.globalRowIndex
        (rows := ceRows)
        (columns := ceColumns)
        (publicCount := cePublicCount)
        (evalCount := ceEvalCount)
        (pointVars := cePointVars))

theorem terminalAIRPrimitiveFamilySchedule_no_duplicate_keys_of_perFamily
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (hPerFamily :
      TerminalAIRPrimitiveFamilySchedulePerFamilyGlobalIndicesInjective
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRPrimitiveFamilyScheduleNoDuplicateKeys
      (piccsRounds := piccsRounds)
      (pirlcCount := pirlcCount)
      (pirlcRows := pirlcRows)
      (pirlcPublicCount := pirlcPublicCount)
      (pirlcEvalCount := pirlcEvalCount)
      (pirlcPointVars := pirlcPointVars)
      (pidecRows := pidecRows)
      (pidecColumns := pidecColumns)
      (pidecSignedDigitCount := pidecSignedDigitCount)
      (pidecDecompositionCount := pidecDecompositionCount)
      (pidecPublicSplitCount := pidecPublicSplitCount)
      (pidecLowNormCount := pidecLowNormCount)
      (ceRows := ceRows)
      (ceColumns := ceColumns)
      (cePublicCount := cePublicCount)
      (ceEvalCount := ceEvalCount)
      (cePointVars := cePointVars) := by
  rcases hPerFamily with
    ⟨hPiCCS, hPiRLC, hPiDEC, hCEAjtai⟩
  intro lhs rhs hKey
  cases lhs <;> cases rhs <;>
    simp [TerminalAIRPrimitiveFamilyScheduleIndex.scheduleKey,
      TerminalAIRPrimitiveFamilyScheduleIndex.subrelationKind,
      TerminalAIRPrimitiveFamilyScheduleIndex.globalRowIndex,
      PiCCSScheduleIndex.subrelationKind,
      PiRLCScheduleIndex.subrelationKind,
      PiDECScheduleIndex.subrelationKind,
      CEAjtaiScheduleIndex.subrelationKind] at hKey ⊢
  · exact hPiCCS hKey
  · exact hPiRLC hKey
  · exact hPiDEC hKey
  · exact hCEAjtai hKey

theorem terminalAIRPrimitiveFamilySchedule_perFamilyGlobalIndicesInjective
    (piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat) :
    TerminalAIRPrimitiveFamilySchedulePerFamilyGlobalIndicesInjective
      piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
      pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars :=
  ⟨piccsSchedule_globalRowIndex_injective,
    pirlcSchedule_globalRowIndex_injective,
    pidecSchedule_globalRowIndex_injective,
    ceAjtaiSchedule_globalRowIndex_injective⟩

theorem terminalAIRPrimitiveFamilySchedule_no_duplicate_keys
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat} :
    TerminalAIRPrimitiveFamilyScheduleNoDuplicateKeys
      (piccsRounds := piccsRounds)
      (pirlcCount := pirlcCount)
      (pirlcRows := pirlcRows)
      (pirlcPublicCount := pirlcPublicCount)
      (pirlcEvalCount := pirlcEvalCount)
      (pirlcPointVars := pirlcPointVars)
      (pidecRows := pidecRows)
      (pidecColumns := pidecColumns)
      (pidecSignedDigitCount := pidecSignedDigitCount)
      (pidecDecompositionCount := pidecDecompositionCount)
      (pidecPublicSplitCount := pidecPublicSplitCount)
      (pidecLowNormCount := pidecLowNormCount)
      (ceRows := ceRows)
      (ceColumns := ceColumns)
      (cePublicCount := cePublicCount)
      (ceEvalCount := ceEvalCount)
      (cePointVars := cePointVars) :=
  terminalAIRPrimitiveFamilySchedule_no_duplicate_keys_of_perFamily
    (terminalAIRPrimitiveFamilySchedule_perFamilyGlobalIndicesInjective
      piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
      pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars)

theorem terminalAIRPrimitiveFamilySchedule_no_missing_piccs_row
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index : PiCCSConcreteAIRRowIndex piccsRounds) :
    ∃ scheduled :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars,
      match scheduled with
      | .piCCS scheduledIndex =>
          scheduledIndex.toConcreteIndex = index
      | _ => False :=
  ⟨.piCCS (PiCCSScheduleIndex.fromConcreteIndex index),
    piccsSchedule_toConcrete_fromConcrete index⟩

theorem terminalAIRPrimitiveFamilySchedule_no_missing_pirlc_row
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index :
      PiRLCConcreteAIRRowIndex pirlcCount pirlcRows pirlcPublicCount
        pirlcEvalCount pirlcPointVars) :
    ∃ scheduled :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars,
      match scheduled with
      | .piRLC scheduledIndex =>
          scheduledIndex.toConcreteIndex = index
      | _ => False :=
  ⟨.piRLC (PiRLCScheduleIndex.fromConcreteIndex index),
    pirlcSchedule_toConcrete_fromConcrete index⟩

theorem terminalAIRPrimitiveFamilySchedule_no_missing_pidec_row
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index :
      PiDECConcreteAIRRowIndex pidecRows pidecColumns
        (Fin pidecSignedDigitCount) (Fin pidecDecompositionCount)
        (Fin pidecPublicSplitCount) (Fin pidecLowNormCount)) :
    ∃ scheduled :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars,
      match scheduled with
      | .piDEC scheduledIndex =>
          scheduledIndex.toConcreteIndex = index
      | _ => False :=
  ⟨.piDEC (PiDECScheduleIndex.fromConcreteIndex index),
    pidecSchedule_toConcrete_fromConcrete index⟩

theorem terminalAIRPrimitiveFamilySchedule_no_missing_ceAjtai_row
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (index :
      CEAjtaiConcreteAIRRowIndex ceRows ceColumns cePublicCount ceEvalCount
        cePointVars) :
    ∃ scheduled :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars,
      match scheduled with
      | .ceAjtai scheduledIndex =>
          scheduledIndex.toConcreteIndex = index
      | _ => False :=
  ⟨.ceAjtai (CEAjtaiScheduleIndex.fromConcreteIndex index),
    ceAjtaiSchedule_toConcrete_fromConcrete index⟩

def TerminalAIRRowTranscriptContext.piccsTranscript
    {K : Type} [CommRing K]
    {rounds : Nat}
    (context : TerminalAIRRowTranscriptContext)
    (air : PiCCSConcreteAIRRows K rounds)
    (index : PiCCSScheduleIndex rounds) :
    PiCCSScheduledRowTranscript K rounds :=
  PiCCSScheduledRowTranscript.ofScheduleIndex
    air context.publicBindingContext context.terminalVerifierRelationDigest
    context.recursiveRelationDigest context.sourceDigest context.sourceByteCount
    index

def TerminalAIRRowTranscriptContext.pirlcTranscript
    {RF : Type} [CommRing RF]
    {count rows publicCount evalCount pointVars : Nat}
    (context : TerminalAIRRowTranscriptContext)
    (air :
      PiRLCConcreteAIRRows RF count rows publicCount evalCount pointVars)
    (index :
      PiRLCScheduleIndex count rows publicCount evalCount pointVars) :
    PiRLCScheduledRowTranscript RF count rows publicCount evalCount pointVars :=
  PiRLCScheduledRowTranscript.ofScheduleIndex
    air context.publicBindingContext context.terminalVerifierRelationDigest
    context.recursiveRelationDigest context.sourceDigest context.sourceByteCount
    index

def TerminalAIRRowTranscriptContext.pidecTranscript
    {RF : Type} [CommRing RF]
    {rows columns count signedDigitCount decompositionCount publicSplitCount
      lowNormCount : Nat}
    (context : TerminalAIRRowTranscriptContext)
    (air :
      PiDECScheduledAIRRows RF rows columns count signedDigitCount
        decompositionCount publicSplitCount lowNormCount)
    (index :
      PiDECScheduleIndex rows columns signedDigitCount decompositionCount
        publicSplitCount lowNormCount) :
    PiDECScheduledRowTranscript RF rows columns signedDigitCount
      decompositionCount publicSplitCount lowNormCount :=
  PiDECScheduledRowTranscript.ofScheduleIndex
    air context.publicBindingContext context.terminalVerifierRelationDigest
    context.recursiveRelationDigest context.sourceDigest context.sourceByteCount
    index

def TerminalAIRRowTranscriptContext.ceAjtaiTranscript
    {RF : Type} [CommRing RF]
    {rows columns publicCount evalCount pointVars : Nat}
    (context : TerminalAIRRowTranscriptContext)
    (air :
      CEAjtaiConcreteAIRRows RF rows columns publicCount evalCount pointVars)
    (index :
      CEAjtaiScheduleIndex rows columns publicCount evalCount pointVars) :
    CEAjtaiScheduledRowTranscript RF rows columns publicCount evalCount
      pointVars :=
  CEAjtaiScheduledRowTranscript.ofScheduleIndex
    air context.publicBindingContext context.terminalVerifierRelationDigest
    context.recursiveRelationDigest context.sourceDigest context.sourceByteCount
    index

structure TerminalAIRPrimitiveFamilyScheduledRows
    (K RF : Type) [CommRing K] [CommRing RF]
    (piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat) where
  piccsAir : PiCCSConcreteAIRRows K piccsRounds
  pirlcAir :
    PiRLCConcreteAIRRows RF pirlcCount pirlcRows pirlcPublicCount
      pirlcEvalCount pirlcPointVars
  pidecAir :
    PiDECScheduledAIRRows RF pidecRows pidecColumns pidecCount
      pidecSignedDigitCount pidecDecompositionCount pidecPublicSplitCount
      pidecLowNormCount
  ceAjtaiAir :
    CEAjtaiConcreteAIRRows RF ceRows ceColumns cePublicCount ceEvalCount
      cePointVars
  rowContext : TerminalAIRRowTranscriptContext

def TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt
    {K RF : Type} [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (rows :
      TerminalAIRPrimitiveFamilyScheduledRows K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars)
    (index :
      TerminalAIRPrimitiveFamilyScheduleIndex
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) : Prop :=
  match index with
  | .piCCS index =>
      (rows.rowContext.piccsTranscript rows.piccsAir index).residual = 0
  | .piRLC index =>
      (rows.rowContext.pirlcTranscript rows.pirlcAir index).residual = 0
  | .piDEC index =>
      (rows.rowContext.pidecTranscript rows.pidecAir index).residual = 0
  | .ceAjtai index =>
      (rows.rowContext.ceAjtaiTranscript rows.ceAjtaiAir index).residual = 0

def TerminalAIRPrimitiveFamilyAllScheduledRowsZero
    {K RF : Type} [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (rows :
      TerminalAIRPrimitiveFamilyScheduledRows K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    Prop :=
  ∀ index, rows.residualZeroAt index

theorem terminalAIRPrimitiveFamily_allScheduledRowsZero_iff_familyScheduledRowsZero
    {K RF : Type} [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (rows :
      TerminalAIRPrimitiveFamilyScheduledRows K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRPrimitiveFamilyAllScheduledRowsZero rows ↔
      PiCCSScheduledAIRAllRowsZero
        rows.piccsAir rows.rowContext.publicBindingContext
        rows.rowContext.terminalVerifierRelationDigest
        rows.rowContext.recursiveRelationDigest
        rows.rowContext.sourceDigest rows.rowContext.sourceByteCount ∧
      PiRLCScheduledAIRAllRowsZero
        rows.pirlcAir rows.rowContext.publicBindingContext
        rows.rowContext.terminalVerifierRelationDigest
        rows.rowContext.recursiveRelationDigest
        rows.rowContext.sourceDigest rows.rowContext.sourceByteCount ∧
      PiDECScheduledAIRAllRowsZero
        rows.pidecAir rows.rowContext.publicBindingContext
        rows.rowContext.terminalVerifierRelationDigest
        rows.rowContext.recursiveRelationDigest
        rows.rowContext.sourceDigest rows.rowContext.sourceByteCount ∧
      CEAjtaiScheduledAIRAllRowsZero
        rows.ceAjtaiAir rows.rowContext.publicBindingContext
        rows.rowContext.terminalVerifierRelationDigest
        rows.rowContext.recursiveRelationDigest
        rows.rowContext.sourceDigest rows.rowContext.sourceByteCount := by
  constructor
  · intro hAll
    exact
      ⟨fun index => by
          simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
            TerminalAIRRowTranscriptContext.piccsTranscript] using
            hAll (.piCCS index),
        fun index => by
          simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
            TerminalAIRRowTranscriptContext.pirlcTranscript] using
            hAll (.piRLC index),
        fun index => by
          simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
            TerminalAIRRowTranscriptContext.pidecTranscript] using
            hAll (.piDEC index),
        fun index => by
          simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
            TerminalAIRRowTranscriptContext.ceAjtaiTranscript] using
            hAll (.ceAjtai index)⟩
  · intro hFamilies
    rcases hFamilies with ⟨hPiCCS, hPiRLC, hPiDEC, hCEAjtai⟩
    intro index
    cases index with
    | piCCS index =>
        simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
          TerminalAIRRowTranscriptContext.piccsTranscript] using hPiCCS index
    | piRLC index =>
        simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
          TerminalAIRRowTranscriptContext.pirlcTranscript] using hPiRLC index
    | piDEC index =>
        simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
          TerminalAIRRowTranscriptContext.pidecTranscript] using hPiDEC index
    | ceAjtai index =>
        simpa [TerminalAIRPrimitiveFamilyScheduledRows.residualZeroAt,
          TerminalAIRRowTranscriptContext.ceAjtaiTranscript] using
          hCEAjtai index

theorem terminalAIRPrimitiveFamily_allScheduledRowsZero_iff_concreteRowsZero
    {K RF : Type} [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (rows :
      TerminalAIRPrimitiveFamilyScheduledRows K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRPrimitiveFamilyAllScheduledRowsZero rows ↔
      PiCCSConcreteAIRAllRowsZero rows.piccsAir ∧
      PiRLCConcreteAIRAllRowsZero rows.pirlcAir ∧
      PiDECConcreteAIRAllRowsZero rows.pidecAir ∧
      CEAjtaiConcreteAIRAllRowsZero rows.ceAjtaiAir := by
  rw [terminalAIRPrimitiveFamily_allScheduledRowsZero_iff_familyScheduledRowsZero]
  rw [piccsScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  rw [pirlcScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  rw [pidecScheduledAIR_allRowsZero_iff_concreteAllRowsZero]
  rw [ceAjtaiScheduledAIR_allRowsZero_iff_concreteAllRowsZero]

theorem terminalAIRPrimitiveFamily_allScheduledRowsZero_iff_verifierSteps
    {K RF : Type} [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (rows :
      TerminalAIRPrimitiveFamilyScheduledRows K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars) :
    TerminalAIRPrimitiveFamilyAllScheduledRowsZero rows ↔
      PiCCSConcreteVerifierStep rows.piccsAir ∧
      PiRLCConcreteVerifierStep rows.pirlcAir ∧
      PiDECConcreteVerifierStep rows.pidecAir ∧
      CEAjtaiConcreteVerifierStep rows.ceAjtaiAir := by
  rw [terminalAIRPrimitiveFamily_allScheduledRowsZero_iff_familyScheduledRowsZero]
  rw [piccsScheduledAIR_allRowsZero_iff_verifierStep]
  rw [pirlcScheduledAIR_allRowsZero_iff_verifierStep]
  rw [pidecScheduledAIR_allRowsZero_iff_verifierStep]
  rw [ceAjtaiScheduledAIR_allRowsZero_iff_verifierStep]

structure PiCCSPiRLCPiDECPrimitiveBundle
    (F RF : Type) [Semiring F] [CommRing RF]
    (pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount : Nat) where
  piccsState : PiCCSPublicQState F
  piccsTrace : SumcheckVerifierTrace F
  pirlcPoint : ProtocolVector RF pirlcPointVars
  pirlcChallenges : Fin pirlcCount → RF
  pirlcClaims :
    Fin pirlcCount →
      EvaluationClaim RF pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
  pirlcFolded :
    EvaluationClaim RF pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
  pidecMatrix : AjtaiMatrix RF pidecRows pidecColumns
  pidecBase : RF
  pidecLimbs : Fin pidecCount → Message RF pidecColumns
  pidecFolded : Message RF pidecColumns
  pidecFoldedCommitment : Commitment RF pidecRows

def PiCCSPiRLCPiDECPrimitiveConstraints
    {pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount : Nat}
    (bundle :
      PiCCSPiRLCPiDECPrimitiveBundle F RF
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
        pidecRows pidecColumns pidecCount) : Prop :=
  PiCCSPrimitiveConstraints bundle.piccsState bundle.piccsTrace ∧
    PiRLCPrimitiveConstraints
      bundle.pirlcPoint
      bundle.pirlcChallenges
      bundle.pirlcClaims
      bundle.pirlcFolded ∧
    PiDECPrimitiveConstraints
      bundle.pidecMatrix
      bundle.pidecBase
      bundle.pidecLimbs
      bundle.pidecFolded
      bundle.pidecFoldedCommitment

def PiCCSPiRLCPiDECVerifierSteps
    {pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount : Nat}
    (bundle :
      PiCCSPiRLCPiDECPrimitiveBundle F RF
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
        pidecRows pidecColumns pidecCount) : Prop :=
  PiCCSVerifierStep bundle.piccsState bundle.piccsTrace ∧
    PiRLCVerifierStep
      bundle.pirlcPoint
      bundle.pirlcChallenges
      bundle.pirlcClaims
      bundle.pirlcFolded ∧
    PiDECVerifierStep
      bundle.pidecMatrix
      bundle.pidecBase
      bundle.pidecLimbs
      bundle.pidecFolded
      bundle.pidecFoldedCommitment

theorem piCCS_piRLC_piDEC_primitiveConstraints_iff_verifierSteps
    {pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount : Nat}
    (bundle :
      PiCCSPiRLCPiDECPrimitiveBundle F RF
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
        pidecRows pidecColumns pidecCount) :
    PiCCSPiRLCPiDECPrimitiveConstraints bundle ↔
      PiCCSPiRLCPiDECVerifierSteps bundle := by
  constructor
  · intro hConstraints
    rcases hConstraints with ⟨hPiCCS, hPiRLC, hPiDEC⟩
    exact
      ⟨(piccsPrimitiveConstraints_iff_verifierStep
          bundle.piccsState bundle.piccsTrace).mp hPiCCS,
        (pirlcPrimitiveConstraints_iff_verifierStep
          bundle.pirlcPoint
          bundle.pirlcChallenges
          bundle.pirlcClaims
          bundle.pirlcFolded).mp hPiRLC,
        (pidecPrimitiveConstraints_iff_verifierStep
          bundle.pidecMatrix
          bundle.pidecBase
          bundle.pidecLimbs
          bundle.pidecFolded
          bundle.pidecFoldedCommitment).mp hPiDEC⟩
  · intro hSteps
    rcases hSteps with ⟨hPiCCS, hPiRLC, hPiDEC⟩
    exact
      ⟨(piccsPrimitiveConstraints_iff_verifierStep
          bundle.piccsState bundle.piccsTrace).mpr hPiCCS,
        (pirlcPrimitiveConstraints_iff_verifierStep
          bundle.pirlcPoint
          bundle.pirlcChallenges
          bundle.pirlcClaims
          bundle.pirlcFolded).mpr hPiRLC,
        (pidecPrimitiveConstraints_iff_verifierStep
          bundle.pidecMatrix
          bundle.pidecBase
          bundle.pidecLimbs
          bundle.pidecFolded
          bundle.pidecFoldedCommitment).mpr hPiDEC⟩

theorem piCCS_piRLC_piDEC_verifierSteps_iff_primitiveConstraints
    {pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount : Nat}
    (bundle :
      PiCCSPiRLCPiDECPrimitiveBundle F RF
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
        pidecRows pidecColumns pidecCount) :
    PiCCSPiRLCPiDECVerifierSteps bundle ↔
      PiCCSPiRLCPiDECPrimitiveConstraints bundle :=
  (piCCS_piRLC_piDEC_primitiveConstraints_iff_verifierSteps bundle).symm

end SuperNeoFormal
