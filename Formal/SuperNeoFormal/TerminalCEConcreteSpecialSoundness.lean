import SuperNeoFormal.TerminalCEVerifierSemantics

/-!
Concrete terminal CE special-soundness scaffolding.

This file separates the constructive objects from the older finite certificate
surface.  It defines an explicit three-branch round predicate, a round extractor
semantics, and the exact finite bad-seed set induced by a seed-indexed
extraction predicate.
-/

noncomputable section

namespace SuperNeoFormal

open Finset

def CEOpeningRoundAllBranchesAccept
    {Commitment Response Witness : Type}
    (round : CEOpeningRoundSemantics Commitment Response Witness) : Prop :=
  round.verifierChecks CEOpeningVerifierChallenge.mask ∧
    round.verifierChecks CEOpeningVerifierChallenge.maskedWitness ∧
      round.verifierChecks CEOpeningVerifierChallenge.permutedWitness

structure CEOpeningConcreteRoundExtractor
    {Commitment Response Witness : Type}
    (round : CEOpeningRoundSemantics Commitment Response Witness)
    (opens : Witness → Prop) where
  extract :
    CEOpeningRoundAllBranchesAccept round →
      { witness : Witness // opens witness }

theorem ceOpeningConcreteRound_extract_of_all_branches
    {Commitment Response Witness : Type}
    {round : CEOpeningRoundSemantics Commitment Response Witness}
    {opens : Witness → Prop}
    (extractor : CEOpeningConcreteRoundExtractor round opens)
    (hBranches : CEOpeningRoundAllBranchesAccept round) :
    ∃ witness, opens witness := by
  exact ⟨(extractor.extract hBranches).1, (extractor.extract hBranches).2⟩

structure TerminalCEConcreteExtractorSemantics
    {Claim Commitment Response Witness Seed : Type}
    {count roundCount : Nat}
    (trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount)
    (statement : TerminalCEStatement Claim count)
    (opens : Claim → Witness → Prop) where
  roundForOutput : Fin count → Fin roundCount
  branchAccepts :
    ∀ index,
      CEOpeningRoundAllBranchesAccept (trace.rounds (roundForOutput index))
  roundExtractor :
    ∀ index,
      CEOpeningConcreteRoundExtractor
        (trace.rounds (roundForOutput index))
        (fun witness => opens (statement.outputClaim index) witness)

theorem terminalCEConcrete_extract_batch
    {Claim Commitment Response Witness Seed : Type}
    {count roundCount : Nat}
    {trace : TerminalCEVerifierTrace Commitment Response Witness Seed roundCount}
    {statement : TerminalCEStatement Claim count}
    {opens : Claim → Witness → Prop}
    (semantics :
      TerminalCEConcreteExtractorSemantics trace statement opens) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens := by
  refine ⟨fun index =>
    ((semantics.roundExtractor index).extract (semantics.branchAccepts index)).1, ?_⟩
  intro index
  exact ((semantics.roundExtractor index).extract (semantics.branchAccepts index)).2

def TerminalCESeedExtracts
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

def TerminalCEConcreteBadSeeds
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] :
    Finset Seed :=
  univ.filter fun seed =>
    ¬ TerminalCESeedExtracts verifyProof opens proofSeed seed

theorem TerminalCEConcreteBadSeeds_mem_iff
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    (seed : Seed) :
    seed ∈ TerminalCEConcreteBadSeeds verifyProof opens proofSeed ↔
      ¬ TerminalCESeedExtracts verifyProof opens proofSeed seed := by
  simp [TerminalCEConcreteBadSeeds]

theorem terminalCEConcrete_extract_of_seed_not_bad
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)]
    {statement : TerminalCEStatement Claim count}
    {proof : Proof}
    (hVerify : verifyProof statement proof)
    (hSeed :
      proofSeed proof ∉
        TerminalCEConcreteBadSeeds verifyProof opens proofSeed) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens := by
  have hExtracts :
      TerminalCESeedExtracts verifyProof opens proofSeed (proofSeed proof) := by
    by_contra hNoExtracts
    exact hSeed (by
      rw [TerminalCEConcreteBadSeeds_mem_iff]
      exact hNoExtracts)
  exact hExtracts statement proof hVerify rfl

theorem TerminalCEConcreteBadSeeds_card_le_univ
    {Claim Proof Witness Seed : Type}
    [Fintype Seed] [DecidableEq Seed]
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop)
    (proofSeed : Proof → Seed)
    [DecidablePred (TerminalCESeedExtracts verifyProof opens proofSeed)] :
    (TerminalCEConcreteBadSeeds verifyProof opens proofSeed).card ≤
      Fintype.card Seed := by
  simpa using
    (card_le_univ (TerminalCEConcreteBadSeeds verifyProof opens proofSeed))

end SuperNeoFormal
