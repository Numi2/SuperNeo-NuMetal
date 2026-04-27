import SuperNeoFormal.PiCCS
import SuperNeoFormal.PiRLCSoundness
import SuperNeoFormal.PiDEC

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
