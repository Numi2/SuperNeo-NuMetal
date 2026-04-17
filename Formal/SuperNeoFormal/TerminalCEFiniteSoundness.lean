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

abbrev CEOpeningChallengeSymbol :=
  Fin 3

def ceOpeningChallengeFromSymbol
    (symbol : CEOpeningChallengeSymbol) : CEOpeningVerifierChallenge :=
  match symbol.val with
  | 0 => CEOpeningVerifierChallenge.mask
  | 1 => CEOpeningVerifierChallenge.maskedWitness
  | _ => CEOpeningVerifierChallenge.permutedWitness

def CEOpeningChallengeDomain : Finset CEOpeningVerifierChallenge :=
  { CEOpeningVerifierChallenge.mask,
    CEOpeningVerifierChallenge.maskedWitness,
    CEOpeningVerifierChallenge.permutedWitness }

theorem ceOpeningChallengeDomain_card :
    CEOpeningChallengeDomain.card = 3 := by
  native_decide

theorem ceOpeningChallengeFromSymbol_mem_domain
    (symbol : CEOpeningChallengeSymbol) :
    ceOpeningChallengeFromSymbol symbol ∈ CEOpeningChallengeDomain := by
  fin_cases symbol <;> native_decide

theorem ceOpeningVerifierChallenge_mem_domain
    (challenge : CEOpeningVerifierChallenge) :
    challenge ∈ CEOpeningChallengeDomain := by
  cases challenge <;> native_decide

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

structure TerminalCEVerifierTrace
    (Commitment Response Witness Seed : Type)
    (roundCount : Nat) where
  seed : Seed
  rounds : Fin roundCount → CEOpeningRoundSemantics Commitment Response Witness
  challengeSymbols : Fin roundCount → CEOpeningChallengeSymbol
  challenges_match :
    ∀ round,
      (rounds round).challenge =
        ceOpeningChallengeFromSymbol (challengeSymbols round)

def TerminalCEVerifierTraceAccepts
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount) :
    Prop :=
  ∀ round, CEOpeningRoundAccepts (trace.rounds round)

theorem terminalCEVerifierTrace_roundCount
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (_trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount) :
    Fintype.card (Fin roundCount) = roundCount := by
  simp

theorem terminalCEVerifierTrace_challenge_mem_domain
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    (trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount)
    (round : Fin roundCount) :
    (trace.rounds round).challenge ∈ CEOpeningChallengeDomain := by
  rw [trace.challenges_match round]
  exact ceOpeningChallengeFromSymbol_mem_domain (trace.challengeSymbols round)

theorem terminalCEVerifierTrace_accepts_derived_branch
    {Commitment Response Witness Seed : Type}
    {roundCount : Nat}
    {trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount}
    (hAccepts : TerminalCEVerifierTraceAccepts trace)
    (round : Fin roundCount) :
    (trace.rounds round).verifierChecks
      (ceOpeningChallengeFromSymbol (trace.challengeSymbols round)) := by
  have hRound := hAccepts round
  rw [← trace.challenges_match round]
  exact hRound

structure TerminalCEVerifierExtractionCertificate
    {Claim Commitment Response Witness Seed : Type}
    {count roundCount : Nat}
    (trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount)
    (statement : TerminalCEStatement Claim count)
    (opens : Claim → Witness → Prop) where
  roundForOutput : Fin count → Fin roundCount
  branchCertificates :
    ∀ index,
      CEOpeningRoundSpecialSoundnessCertificate
        (trace.rounds (roundForOutput index))
        (fun witness => opens (statement.outputClaim index) witness)

theorem terminalCEVerifierTrace_extract_batch_from_round_certificates
    {Claim Commitment Response Witness Seed : Type}
    {count roundCount : Nat}
    {trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount}
    {statement : TerminalCEStatement Claim count}
    {opens : Claim → Witness → Prop}
    (certificate :
      TerminalCEVerifierExtractionCertificate trace statement opens) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens := by
  refine ⟨fun index => (certificate.branchCertificates index).extractedWitness, ?_⟩
  intro index
  exact (certificate.branchCertificates index).extracted_opens

def TerminalCEConstructedSeedExtracts
    {Claim Proof Witness Seed : Type}
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    (seed : Seed) : Prop :=
  ∀ statement proof,
    verifyProof statement proof →
      proofSeed proof = seed →
        ∃ witnesses : Fin count → Witness,
          TerminalLocalBatchRelation statement witnesses opens

def TerminalCEConstructedBadSeeds
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred
      (TerminalCEConstructedSeedExtracts verifyProof opens proofSeed)] :
    Finset Seed :=
  Finset.univ.filter fun seed =>
    ¬ TerminalCEConstructedSeedExtracts verifyProof opens proofSeed seed

theorem TerminalCEConstructedBadSeeds_mem_iff
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred
      (TerminalCEConstructedSeedExtracts verifyProof opens proofSeed)]
    (seed : Seed) :
    seed ∈ TerminalCEConstructedBadSeeds verifyProof opens proofSeed ↔
      ¬ TerminalCEConstructedSeedExtracts verifyProof opens proofSeed seed := by
  simp [TerminalCEConstructedBadSeeds]

theorem terminalCEConstructed_extract_of_seed_not_bad
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred
      (TerminalCEConstructedSeedExtracts verifyProof opens proofSeed)]
    {statement : TerminalCEStatement Claim count}
    {proof : Proof}
    (hVerify : verifyProof statement proof)
    (hSeed :
      proofSeed proof ∉
        TerminalCEConstructedBadSeeds verifyProof opens proofSeed) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens := by
  have hExtracts :
      TerminalCEConstructedSeedExtracts
        verifyProof
        opens
        proofSeed
        (proofSeed proof) := by
    by_contra hNoExtracts
    exact hSeed (by
      rw [TerminalCEConstructedBadSeeds_mem_iff]
      exact hNoExtracts)
  exact hExtracts statement proof hVerify rfl

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

def terminalCEFiniteBadSeedCertificate_constructed
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred
      (TerminalCEConstructedSeedExtracts verifyProof opens proofSeed)] :
    TerminalCEFiniteBadSeedCertificate
      verifyProof
      opens
      proofSeed
      (Fintype.card Seed) where
  badSeeds := TerminalCEConstructedBadSeeds verifyProof opens proofSeed
  card_le := by
    simpa using
      (Finset.card_le_univ
        (TerminalCEConstructedBadSeeds verifyProof opens proofSeed))
  extract_outside_bad := by
    intro statement proof hVerify hSeed
    exact terminalCEConstructed_extract_of_seed_not_bad hVerify hSeed

theorem terminal_ce_constructed_badSeedCount_le_univ
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred
      (TerminalCEConstructedSeedExtracts verifyProof opens proofSeed)] :
    (TerminalCEConstructedBadSeeds verifyProof opens proofSeed).card ≤
      Fintype.card Seed := by
  exact (terminalCEFiniteBadSeedCertificate_constructed
    (verifyProof := verifyProof)
    (opens := opens)
    (proofSeed := proofSeed)).card_le

structure TerminalCEFiniteVerifierCertificate
    {Claim Proof Witness Seed Commitment Response : Type}
    [DecidableEq Seed]
    {count roundCount : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    (bound : Nat) where
  badSeeds : Finset Seed
  card_le : badSeeds.card ≤ bound
  parseTrace :
    ∀ statement proof,
      verifyProof statement proof →
        TerminalCEVerifierTrace Commitment Response Witness Seed roundCount
  trace_seed :
    ∀ statement proof hAccepts,
      (parseTrace statement proof hAccepts).seed = proofSeed proof
  trace_accepts :
    ∀ statement proof hAccepts,
      TerminalCEVerifierTraceAccepts (parseTrace statement proof hAccepts)
  extraction :
    ∀ statement proof hAccepts,
      proofSeed proof ∉ badSeeds →
        TerminalCEVerifierExtractionCertificate
          (parseTrace statement proof hAccepts)
          statement
          opens

def terminalCEFiniteBadSeedCertificate_from_verifierCertificate
    {Claim Proof Witness Seed Commitment Response : Type}
    [DecidableEq Seed]
    {count roundCount bound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEFiniteVerifierCertificate
        (Commitment := Commitment)
        (Response := Response)
        (roundCount := roundCount)
        verifyProof
        opens
        proofSeed
        bound) :
    TerminalCEFiniteBadSeedCertificate verifyProof opens proofSeed bound where
  badSeeds := certificate.badSeeds
  card_le := certificate.card_le
  extract_outside_bad := by
    intro statement proof hAccepts hSeed
    exact terminalCEVerifierTrace_extract_batch_from_round_certificates
      (certificate.extraction statement proof hAccepts hSeed)

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

def terminalCESwiftRoundCount : Nat :=
  219

def terminalCESwiftProofBadSeedBudget : Nat :=
  TerminalCEProofBadSeedBudget terminalCESwiftRoundCount

theorem terminalCESwiftRoundCount_positive :
    0 < terminalCESwiftRoundCount := by
  native_decide

theorem terminalCESwiftProofBadSeedBudget_eq :
    terminalCESwiftProofBadSeedBudget = 657 := by
  native_decide

abbrev TerminalCESwiftVerifierTrace
    (Commitment Response Witness Seed : Type) :=
  TerminalCEVerifierTrace
    Commitment
    Response
    Witness
    Seed
    terminalCESwiftRoundCount

structure TerminalCESwiftVerifierExtractionCertificate
    {Claim Commitment Response Witness Seed : Type}
    {count : Nat}
    (trace : TerminalCESwiftVerifierTrace Commitment Response Witness Seed)
    (statement : TerminalCEStatement Claim count)
    (opens : Claim → Witness → Prop) where
  roundForOutput : Fin count → Fin terminalCESwiftRoundCount
  branchCertificates :
    ∀ index,
      CEOpeningRoundSpecialSoundnessCertificate
        (trace.rounds (roundForOutput index))
        (fun witness => opens (statement.outputClaim index) witness)

def terminalCESwiftVerifierExtractionCertificate_to_generic
    {Claim Commitment Response Witness Seed : Type}
    {count : Nat}
    {trace : TerminalCESwiftVerifierTrace Commitment Response Witness Seed}
    {statement : TerminalCEStatement Claim count}
    {opens : Claim → Witness → Prop}
    (certificate :
      TerminalCESwiftVerifierExtractionCertificate trace statement opens) :
    TerminalCEVerifierExtractionCertificate trace statement opens where
  roundForOutput := certificate.roundForOutput
  branchCertificates := certificate.branchCertificates

theorem terminalCESwiftVerifierTrace_extract_batch_from_round_certificates
    {Claim Commitment Response Witness Seed : Type}
    {count : Nat}
    {trace : TerminalCESwiftVerifierTrace Commitment Response Witness Seed}
    {statement : TerminalCEStatement Claim count}
    {opens : Claim → Witness → Prop}
    (certificate :
      TerminalCESwiftVerifierExtractionCertificate trace statement opens) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens :=
  terminalCEVerifierTrace_extract_batch_from_round_certificates
    (terminalCESwiftVerifierExtractionCertificate_to_generic certificate)

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
