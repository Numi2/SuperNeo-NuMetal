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

def SuperNeoVerifierAccepts
    {Claim : Type}
    {outputCount : Nat}
    (reduction : FoldReductionGates Claim outputCount)
    (terminal : TerminalVerifierGates Claim outputCount) : Prop :=
  FoldReductionAccepted reduction ∧
    terminal.statementMatchesReduction ∧
    terminal.terminalCEAccepts

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

theorem superneo_terminal_soundness_from_ce_soundness
    {Claim Proof Witness : Type}
    {outputCount : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalVerifierGates Claim outputCount}
    {verifyProof : TerminalCEStatement Claim outputCount → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proof : Proof}
    (hAccepts : SuperNeoVerifierAccepts reduction terminal)
    (hTerminalAccepts : TerminalCEAccepts terminal.statement proof verifyProof)
    (hCESoundness : TerminalCEProofSoundnessAssumption verifyProof opens) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens := by
  exact ⟨
    superneo_acceptance_requires_fold_reduction hAccepts,
    superneo_acceptance_requires_terminal_statement_match hAccepts,
    terminal_ce_relation_from_verified_proof hCESoundness hTerminalAccepts
  ⟩

end SuperNeoFormal
