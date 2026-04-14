import SuperNeoFormal.PiCCSSoundness
import SuperNeoFormal.GoldilocksExt2

/-!
Finite-bad-challenge PiCCS/sum-check soundness.

The old PiCCS boundary was deterministic (`accepts → traceSound`) even though
sum-check is probabilistic.  This replacement states the soundness surface used
by the completed model: every accepted unsound trace maps to a finite bad
challenge seed set.
-/

noncomputable section

namespace SuperNeoFormal

structure PiCCSRoundPolynomialSemantics
    (F : Type) [Semiring F]
    (trace : SumcheckVerifierTrace F) where
  degreeBound : Nat
  roundDegree :
    ∀ round, round < trace.rounds →
      ∃ polynomial : Polynomial F,
        polynomial.natDegree ≤ degreeBound ∧
          ∀ value, polynomial.eval value = trace.roundPolynomial round value

structure PiCCSPublicQOracleSemantics
    (F : Type) [Semiring F]
    (state : PiCCSPublicQState F) where
  oracle : (Nat → F) → F
  stateMatches : PiCCSStateMatchesOracle state oracle

structure PiCCSFiniteBadChallengeCertificate
    {F Seed : Type} [Semiring F] [DecidableEq Seed]
    (state : PiCCSPublicQState F)
    (traceSound : SumcheckVerifierTrace F → Prop)
    (traceSeed : SumcheckVerifierTrace F → Seed)
    (bound : Nat) where
  badSeeds : Finset Seed
  card_le : badSeeds.card ≤ bound
  covers_unsound :
    ∀ trace,
      PiCCSAccepts state trace →
        ¬ traceSound trace →
          traceSeed trace ∈ badSeeds

theorem piccs_badChallengeCount_le_of_certificate
    {F Seed : Type} [Semiring F] [DecidableEq Seed]
    {state : PiCCSPublicQState F}
    {traceSound : SumcheckVerifierTrace F → Prop}
    {traceSeed : SumcheckVerifierTrace F → Seed}
    {bound : Nat}
    (certificate :
      PiCCSFiniteBadChallengeCertificate state traceSound traceSeed bound) :
    certificate.badSeeds.card ≤ bound :=
  certificate.card_le

theorem piccs_traceSound_of_seed_not_bad
    {F Seed : Type} [Semiring F] [DecidableEq Seed]
    {state : PiCCSPublicQState F}
    {traceSound : SumcheckVerifierTrace F → Prop}
    {traceSeed : SumcheckVerifierTrace F → Seed}
    {bound : Nat}
    {trace : SumcheckVerifierTrace F}
    (certificate :
      PiCCSFiniteBadChallengeCertificate state traceSound traceSeed bound)
    (hAccepts : PiCCSAccepts state trace)
    (hSeed : traceSeed trace ∉ certificate.badSeeds) :
    traceSound trace := by
  by_contra hUnsound
  exact hSeed (certificate.covers_unsound trace hAccepts hUnsound)

def PiCCSSumcheckBadChallengeBudget
    (numVars maxDegreePerRound : Nat) : Nat :=
  numVars * maxDegreePerRound

theorem piccs_sumcheck_badChallengeBudget_profile
    {F Seed : Type} [Semiring F] [DecidableEq Seed]
    {state : PiCCSPublicQState F}
    {traceSound : SumcheckVerifierTrace F → Prop}
    {traceSeed : SumcheckVerifierTrace F → Seed}
    {maxDegreePerRound : Nat}
    (certificate :
      PiCCSFiniteBadChallengeCertificate
        state
        traceSound
        traceSeed
        (PiCCSSumcheckBadChallengeBudget state.numVars maxDegreePerRound)) :
    certificate.badSeeds.card ≤
      PiCCSSumcheckBadChallengeBudget state.numVars maxDegreePerRound :=
  certificate.card_le

end SuperNeoFormal
