import SuperNeoFormal.PiRLC

/-!
Terminal CE opening relation model.

The Swift terminal path accepts only after the fold reduction output claims match
the terminal statement and the CE opening proof verifies for those output claims.
This module models the batch relation and the assumption boundary for the public
CE opening proof verifier.
-/

namespace SuperNeoFormal

structure TerminalCEStatement (Claim : Type) (count : Nat) where
  outputClaim : Fin count → Claim

def TerminalLocalBatchRelation
    {Claim Witness : Type}
    {count : Nat}
    (statement : TerminalCEStatement Claim count)
    (witnesses : Fin count → Witness)
    (opens : Claim → Witness → Prop) : Prop :=
  ∀ index, opens (statement.outputClaim index) (witnesses index)

theorem terminalLocalBatchRelation_opening
    {Claim Witness : Type}
    {count : Nat}
    {statement : TerminalCEStatement Claim count}
    {witnesses : Fin count → Witness}
    {opens : Claim → Witness → Prop}
    (hBatch : TerminalLocalBatchRelation statement witnesses opens)
    (index : Fin count) :
    opens (statement.outputClaim index) (witnesses index) :=
  hBatch index

def TerminalCEProofSoundnessAssumption
    {Claim Proof Witness : Type}
    {count : Nat}
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop)
    (opens : Claim → Witness → Prop) : Prop :=
  ∀ statement proof,
    verifyProof statement proof →
      ∃ witnesses : Fin count → Witness,
        TerminalLocalBatchRelation statement witnesses opens

def TerminalCEAccepts
    {Claim Proof : Type}
    {count : Nat}
    (statement : TerminalCEStatement Claim count)
    (proof : Proof)
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop) : Prop :=
  verifyProof statement proof

theorem terminalCEAccepts_iff_verifyProof
    {Claim Proof : Type}
    {count : Nat}
    (statement : TerminalCEStatement Claim count)
    (proof : Proof)
    (verifyProof : TerminalCEStatement Claim count → Proof → Prop) :
    TerminalCEAccepts statement proof verifyProof ↔ verifyProof statement proof :=
  Iff.rfl

theorem terminal_ce_relation_from_verified_proof
    {Claim Proof Witness : Type}
    {count : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    (hSoundness : TerminalCEProofSoundnessAssumption verifyProof opens)
    {statement : TerminalCEStatement Claim count}
    {proof : Proof}
    (hAccepts : TerminalCEAccepts statement proof verifyProof) :
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens :=
  hSoundness statement proof hAccepts

theorem terminal_ce_statement_outputs_match
    {Claim : Type}
    {count : Nat}
    (statement : TerminalCEStatement Claim count) :
    statement.outputClaim = statement.outputClaim :=
  rfl

end SuperNeoFormal
