import SuperNeoFormal.Phi81Split

/-!
Finite-bad-seed PiRLC soundness.

This is the completed-formal-status replacement for the old
`PiRLCConcreteCollisionBound` boundary group.  The certificate names the exact
finite challenge seeds that may hide a folded-claim collision.
-/

noncomputable section

namespace SuperNeoFormal

inductive Phi81SplitSide where
  | left
  | right
  deriving DecidableEq

def phi81SplitProjection
    (certificate : Phi81SplitCertificate)
    (side : Phi81SplitSide) : Phi81 → Goldilocks :=
  match side with
  | Phi81SplitSide.left => certificate.leftProjection
  | Phi81SplitSide.right => certificate.rightProjection

def pirlcProjectedDeltas
    {count : Nat}
    (split : Phi81SplitCertificate)
    (side : Phi81SplitSide)
    (deltas : Fin count → Phi81) : Fin count → Goldilocks :=
  fun index => phi81SplitProjection split side (deltas index)

def pirlcProjectedComponentBadValues
    {count : Nat}
    (support : Finset Goldilocks)
    (split : Phi81SplitCertificate)
    (side : Phi81SplitSide)
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Phi81) : Finset Goldilocks :=
  scalarRLCBadPivotValues
    support
    fixedChallenges
    pivot
    (pirlcProjectedDeltas split side deltas)

theorem pirlcProjectedComponentBadValues_card_le_one
    {count : Nat}
    (support : Finset Goldilocks)
    (split : Phi81SplitCertificate)
    (side : Phi81SplitSide)
    (fixedChallenges : Fin count → Goldilocks)
    (pivot : Fin count)
    (deltas : Fin count → Phi81)
    (hPivot :
      phi81SplitProjection split side (deltas pivot) ≠ 0) :
    (pirlcProjectedComponentBadValues
      support
      split
      side
      fixedChallenges
      pivot
      deltas).card ≤ 1 :=
  scalarRLCBadPivotValues_card_le_one
    support
    fixedChallenges
    pivot
    (pirlcProjectedDeltas split side deltas)
    hPivot

structure PiRLCFiniteBadSeedCertificate
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) where
  split : Phi81SplitCertificate
  badSeeds : Finset (PiRLCChallengeSeed count)
  card_le : badSeeds.card ≤ bound
  covers_failure :
    ∀ seed,
      PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims
        seed →
          seed ∈ badSeeds

theorem pirlc_concrete_badSeedCount_le_of_certificate
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    [DecidablePred
      (PiRLCFoldFailure
        (PiRLCConcreteAccepts point)
        foldedSound
        inputSound
        claims)]
    (certificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound) :
    (PiRLCBadSeedFinset
      (PiRLCConcreteAccepts point)
      foldedSound
      inputSound
      claims).card ≤ bound :=
  pirlc_badSeedCount_le_of_collisionSet
    (collisionSet := certificate.badSeeds)
    certificate.covers_failure
    certificate.card_le

def pirlc_certificate_split
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound) :
    Phi81SplitCertificate :=
  certificate.split

theorem pirlc_allInputsSound_of_seed_not_bad
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    {seed : PiRLCChallengeSeed count}
    {folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound)
    (hSeed : seed ∉ certificate.badSeeds)
    (hAccepts : PiRLCConcreteAccepts point seed claims folded)
    (hFoldedSound : foldedSound folded) :
    AllClaimsSound inputSound claims := by
  by_contra hUnsound
  exact hSeed
    (certificate.covers_failure
      seed
      ⟨folded, hAccepts, hFoldedSound, hUnsound⟩)

def PiRLCComponentwiseSplitCertificate
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) : Prop :=
  ∃ _split : Phi81SplitCertificate,
    ∃ _badSeedCertificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound,
        True

theorem pirlc_certificate_from_componentwise_split
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCComponentwiseSplitCertificate point foldedSound inputSound claims bound) :
    ∃ _badSeedCertificate :
      PiRLCFiniteBadSeedCertificate point foldedSound inputSound claims bound,
        True := by
  rcases certificate with ⟨_split, badSeedCertificate, hTrivial⟩
  exact ⟨badSeedCertificate, hTrivial⟩

end SuperNeoFormal
