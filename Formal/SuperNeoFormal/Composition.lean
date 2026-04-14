import SuperNeoFormal.PiCCS
import SuperNeoFormal.PiRLC
import SuperNeoFormal.PiDEC
import SuperNeoFormal.TerminalCE

/-!
Final verifier-acceptance composition model.

This is the deterministic top-level verifier shape implemented in Swift:
accepted terminal verification is accepted fold reduction plus matching terminal
CE output claims plus accepted terminal CE opening verification.
-/

namespace SuperNeoFormal

structure FoldReductionGates (Claim : Type) (outputCount : Nat) where
  outputClaims : Fin outputCount → Claim
  publicInputWellFormed : Prop
  piCCSAccepts : Prop
  piRLCAccepts : Prop
  piDECAccepts : Prop

def FoldReductionAccepted
    {Claim : Type}
    {outputCount : Nat}
    (gates : FoldReductionGates Claim outputCount) : Prop :=
  gates.publicInputWellFormed ∧
    gates.piCCSAccepts ∧
    gates.piRLCAccepts ∧
    gates.piDECAccepts

structure TerminalVerifierGates (Claim : Type) (outputCount : Nat) where
  statement : TerminalCEStatement Claim outputCount
  statementMatchesReduction : Prop
  terminalCEAccepts : Prop

structure TerminalProofVerifierGates
    (Claim Proof : Type)
    (outputCount : Nat) where
  statement : TerminalCEStatement Claim outputCount
  proof : Proof
  verifyProof : TerminalCEStatement Claim outputCount → Proof → Prop
  statementMatchesReduction : Prop

def SuperNeoVerifierAccepts
    {Claim : Type}
    {outputCount : Nat}
    (reduction : FoldReductionGates Claim outputCount)
    (terminal : TerminalVerifierGates Claim outputCount) : Prop :=
  FoldReductionAccepted reduction ∧
    terminal.statementMatchesReduction ∧
    terminal.terminalCEAccepts

def TerminalProofVerifierCEAccepts
    {Claim Proof : Type}
    {outputCount : Nat}
    (terminal : TerminalProofVerifierGates Claim Proof outputCount) : Prop :=
  TerminalCEAccepts terminal.statement terminal.proof terminal.verifyProof

def SuperNeoProofVerifierAccepts
    {Claim Proof : Type}
    {outputCount : Nat}
    (reduction : FoldReductionGates Claim outputCount)
    (terminal : TerminalProofVerifierGates Claim Proof outputCount) : Prop :=
  FoldReductionAccepted reduction ∧
    terminal.statementMatchesReduction ∧
    TerminalProofVerifierCEAccepts terminal

theorem fold_reduction_acceptance_from_stages
    {Claim : Type}
    {outputCount : Nat}
    {gates : FoldReductionGates Claim outputCount}
    (hPublicInput : gates.publicInputWellFormed)
    (hPiCCS : gates.piCCSAccepts)
    (hPiRLC : gates.piRLCAccepts)
    (hPiDEC : gates.piDECAccepts) :
    FoldReductionAccepted gates := by
  exact ⟨hPublicInput, hPiCCS, hPiRLC, hPiDEC⟩

theorem superneo_acceptance_composition
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hReduction : FoldReductionAccepted reduction)
    (hStatementMatches : terminal.statementMatchesReduction)
    (hTerminalCE : terminal.terminalCEAccepts) :
    SuperNeoVerifierAccepts reduction terminal :=
  ⟨hReduction, hStatementMatches, hTerminalCE⟩

theorem superneo_acceptance_requires_fold_reduction
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction :=
  hAccepts.1

theorem superneo_acceptance_requires_terminal_statement_match
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    terminal.statementMatchesReduction :=
  hAccepts.2.1

theorem superneo_acceptance_requires_terminal_ce
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    terminal.terminalCEAccepts :=
  hAccepts.2.2

theorem superneo_acceptance_deterministic_facts
    {Claim : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
        terminal.terminalCEAccepts :=
  ⟨
    superneo_acceptance_requires_fold_reduction hAccepts,
    superneo_acceptance_requires_terminal_statement_match hAccepts,
    superneo_acceptance_requires_terminal_ce hAccepts
  ⟩

theorem superneo_proof_acceptance_requires_fold_reduction
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction :=
  hAccepts.1

theorem superneo_proof_acceptance_requires_terminal_statement_match
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    terminal.statementMatchesReduction :=
  hAccepts.2.1

theorem superneo_proof_acceptance_requires_terminal_ce
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    TerminalProofVerifierCEAccepts terminal :=
  hAccepts.2.2

theorem superneo_proof_acceptance_deterministic_facts
    {Claim Proof : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
        TerminalProofVerifierCEAccepts terminal :=
  ⟨
    superneo_proof_acceptance_requires_fold_reduction hAccepts,
    superneo_proof_acceptance_requires_terminal_statement_match hAccepts,
    superneo_proof_acceptance_requires_terminal_ce hAccepts
  ⟩

theorem superneo_terminal_soundness_from_ce_soundness
    {Claim Proof Witness : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {verifyProof : TerminalCEStatement Claim outputCount → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proof : Proof}
    (hProof : terminal.proof = proof)
    (hVerifyProof : terminal.verifyProof = verifyProof)
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (hCESoundness : TerminalCEProofSoundnessAssumption verifyProof opens) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens := by
  have hTerminalAccepts :
      TerminalCEAccepts terminal.statement proof verifyProof := by
    subst proof
    subst verifyProof
    exact superneo_proof_acceptance_requires_terminal_ce hAccepts
  exact ⟨
    superneo_proof_acceptance_requires_fold_reduction hAccepts,
    superneo_proof_acceptance_requires_terminal_statement_match hAccepts,
    terminal_ce_relation_from_verified_proof hCESoundness hTerminalAccepts
  ⟩

theorem superneo_end_to_end_from_ce_soundness
    {Claim Proof Witness : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {opens : Claim → Witness → Prop}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (hCESoundness : TerminalCEProofSoundnessAssumption terminal.verifyProof opens) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens :=
  superneo_terminal_soundness_from_ce_soundness
    (proof := terminal.proof)
    rfl
    rfl
    hAccepts
    hCESoundness

end SuperNeoFormal
