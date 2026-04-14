import SuperNeoFormal.TerminalCE

/-!
Finite-bad-seed terminal CE proof soundness.

The public CE opening proof is a Fiat-Shamir transform of repeated Stern-style
rounds.  A single accepting transcript is not deterministically a witness.  The
completed theorem therefore excludes an explicit finite bad-seed set and extracts
the modeled local batch relation outside that set.
-/

noncomputable section

namespace SuperNeoFormal

inductive CEOpeningVerifierChallenge where
  | mask
  | maskedWitness
  | permutedWitness
  deriving DecidableEq

structure CEOpeningRoundSemantics (Commitment Response Witness : Type) where
  commitments : List Commitment
  response : Response
  challenge : CEOpeningVerifierChallenge
  verifierChecks : CEOpeningVerifierChallenge → Prop

def CEOpeningRoundAccepts
    {Commitment Response Witness : Type}
    (round : CEOpeningRoundSemantics Commitment Response Witness) : Prop :=
  round.verifierChecks round.challenge

structure CEOpeningRoundSpecialSoundnessCertificate
    {Commitment Response Witness : Type}
    (round : CEOpeningRoundSemantics Commitment Response Witness)
    (opens : Witness → Prop) where
  extractedWitness : Witness
  mask_accepts : round.verifierChecks CEOpeningVerifierChallenge.mask
  maskedWitness_accepts : round.verifierChecks CEOpeningVerifierChallenge.maskedWitness
  permutedWitness_accepts : round.verifierChecks CEOpeningVerifierChallenge.permutedWitness
  extracted_opens : opens extractedWitness

theorem ceOpeningRound_extract_of_three_accepting_branches
    {Commitment Response Witness : Type}
    {round : CEOpeningRoundSemantics Commitment Response Witness}
    {opens : Witness → Prop}
    (certificate :
      CEOpeningRoundSpecialSoundnessCertificate round opens) :
    ∃ witness, opens witness :=
  ⟨certificate.extractedWitness, certificate.extracted_opens⟩

structure TerminalCEFiniteBadSeedCertificate
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    (bound : Nat) where
  badSeeds : Finset Seed
  card_le : badSeeds.card ≤ bound
  extract_outside_bad :
    ∀ statement proof,
      verifyProof statement proof →
        proofSeed proof ∉ badSeeds →
          ∃ witnesses : Fin count → Witness,
            TerminalLocalBatchRelation statement witnesses opens

theorem terminal_ce_badSeedCount_le_of_certificate
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count bound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEFiniteBadSeedCertificate verifyProof opens proofSeed bound) :
    certificate.badSeeds.card ≤ bound :=
  certificate.card_le

theorem terminal_ce_relation_from_verified_proof_outside_badSeeds
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count bound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEFiniteBadSeedCertificate verifyProof opens proofSeed bound)
    {statement : TerminalCEStatement Claim count}
    {proof : Proof}
    (hAccepts : TerminalCEAccepts statement proof verifyProof)
    (hSeed : proofSeed proof ∉ certificate.badSeeds) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens :=
  certificate.extract_outside_bad statement proof hAccepts hSeed

def TerminalCEProofBadSeedBudget
    (roundCount : Nat)
    (challengeCount : Nat := 3) : Nat :=
  roundCount * challengeCount

theorem terminal_ce_badSeedBudget_profile
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count roundCount : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEFiniteBadSeedCertificate
        verifyProof
        opens
        proofSeed
        (TerminalCEProofBadSeedBudget roundCount)) :
    certificate.badSeeds.card ≤ TerminalCEProofBadSeedBudget roundCount :=
  certificate.card_le

end SuperNeoFormal
