import SuperNeoFormal.Phi81Split

/-!
Finite-bad-seed PiRLC soundness.

This is the completed-formal-status replacement for the old
`PiRLCConcreteCollisionBound` boundary group.  The certificate names the exact
finite challenge seeds that may hide a folded-claim collision.
-/

noncomputable section

namespace SuperNeoFormal

structure PiRLCFiniteBadSeedCertificate
    {count rows publicCount evalCount pointVars : Nat}
    (point : ProtocolVector Phi81 pointVars)
    (foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop)
    (claims : Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (bound : Nat) where
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
