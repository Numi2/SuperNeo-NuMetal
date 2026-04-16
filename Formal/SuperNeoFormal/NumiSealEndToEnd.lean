import SuperNeoFormal.Composition
import SuperNeoFormal.NumiSealSumcheckTranscript

/-!
NumiSeal product/carry/ZK end-to-end theorem scope.

This module is the checked composition boundary for the current NumiSeal
product surface.  It does not assert a standalone extractor, simulator, or
hardware side-channel theorem.  Instead it states the exact product theorem that
the implementation can safely use today: if the product verifier gates accept
and the release supplies the named cryptographic evidence obligations, then the
accepted artifact satisfies the end-to-end NumiSeal relation composed from
source fold, reconstructed obligations, terminal seal, typed carry, ZK masking,
and product policy.
-/

namespace SuperNeoFormal

inductive NumiSealProofMode where
  | terminal
  | zk
  deriving DecidableEq, Repr

inductive NumiSealCarryMode where
  | none
  | typedOptional
  | typedRequired
  deriving DecidableEq, Repr

structure NumiSealProductPolicyGates where
  expectedContextBound : Prop
  provenanceAccepted : Prop
  replayIdentityFresh : Prop
  productByteLimitEnforced : Prop
  proofKindPolicyAccepted : Prop

def NumiSealProductPolicyAccepted (policy : NumiSealProductPolicyGates) : Prop :=
  policy.expectedContextBound
    ∧ policy.provenanceAccepted
    ∧ policy.replayIdentityFresh
    ∧ policy.productByteLimitEnforced
    ∧ policy.proofKindPolicyAccepted

structure NumiSealTerminalSealGates where
  sourceFoldAccepted : Prop
  artifactMetadataAccepted : Prop
  obligationsReconstructed : Prop
  terminalEnvelopeAccepted : Prop
  terminalTranscriptBound : Prop
  componentRootBound : Prop

def NumiSealTerminalSealAccepted (terminal : NumiSealTerminalSealGates) : Prop :=
  terminal.sourceFoldAccepted
    ∧ terminal.artifactMetadataAccepted
    ∧ terminal.obligationsReconstructed
    ∧ terminal.terminalEnvelopeAccepted
    ∧ terminal.terminalTranscriptBound
    ∧ terminal.componentRootBound

structure NumiSealTypedCarryGates where
  carryModeAccepted : Prop
  typedCarryGrammarAccepted : Prop
  carryDigestBound : Prop
  carryContextBound : Prop
  carryReplayIdentityFresh : Prop

def NumiSealTypedCarryAccepted (carry : NumiSealTypedCarryGates) : Prop :=
  carry.carryModeAccepted
    ∧ carry.typedCarryGrammarAccepted
    ∧ carry.carryDigestBound
    ∧ carry.carryContextBound
    ∧ carry.carryReplayIdentityFresh

structure NumiSealZKGates where
  zkModeAccepted : Prop
  randomnessSessionFresh : Prop
  leakageDigestBound : Prop
  maskStatementsBound : Prop
  maskedResidualsBound : Prop
  embeddedTerminalProofAccepted : Prop
  simulatorEvidenceSupplied : Prop

def NumiSealZKAccepted (zk : NumiSealZKGates) : Prop :=
  zk.zkModeAccepted
    ∧ zk.randomnessSessionFresh
    ∧ zk.leakageDigestBound
    ∧ zk.maskStatementsBound
    ∧ zk.maskedResidualsBound
    ∧ zk.embeddedTerminalProofAccepted
    ∧ zk.simulatorEvidenceSupplied

structure NumiSealProductVerifierGates where
  proofMode : NumiSealProofMode
  carryMode : NumiSealCarryMode
  terminal : NumiSealTerminalSealGates
  carry : NumiSealTypedCarryGates
  zk : NumiSealZKGates
  policy : NumiSealProductPolicyGates

def NumiSealProductVerifierAccepts (gates : NumiSealProductVerifierGates) : Prop :=
  NumiSealTerminalSealAccepted gates.terminal
    ∧ NumiSealTypedCarryAccepted gates.carry
    ∧ NumiSealZKAccepted gates.zk
    ∧ NumiSealProductPolicyAccepted gates.policy

def NumiSealTerminalProductVerifierAccepts (gates : NumiSealProductVerifierGates) : Prop :=
  NumiSealProductVerifierAccepts gates ∧ gates.proofMode = .terminal

def NumiSealZKProductVerifierAccepts (gates : NumiSealProductVerifierGates) : Prop :=
  NumiSealProductVerifierAccepts gates ∧ gates.proofMode = .zk

structure NumiSealEndToEndRelation where
  sourceFoldRelation : Prop
  obligationReconstructionRelation : Prop
  terminalSealRelation : Prop
  typedCarryRelation : Prop
  zkMaskedResidualRelation : Prop
  productPolicyRelation : Prop

def NumiSealEndToEndRelationHolds (relation : NumiSealEndToEndRelation) : Prop :=
  relation.sourceFoldRelation
    ∧ relation.obligationReconstructionRelation
    ∧ relation.terminalSealRelation
    ∧ relation.typedCarryRelation
    ∧ relation.zkMaskedResidualRelation
    ∧ relation.productPolicyRelation

structure NumiSealEndToEndEvidence
    (gates : NumiSealProductVerifierGates)
    (relation : NumiSealEndToEndRelation) where
  sourceFoldSound :
    gates.terminal.sourceFoldAccepted → relation.sourceFoldRelation
  obligationReconstructionSound :
    gates.terminal.artifactMetadataAccepted →
      gates.terminal.obligationsReconstructed →
        relation.obligationReconstructionRelation
  terminalSealSound :
    gates.terminal.terminalEnvelopeAccepted →
      gates.terminal.terminalTranscriptBound →
        gates.terminal.componentRootBound →
          relation.terminalSealRelation
  typedCarrySound :
    NumiSealTypedCarryAccepted gates.carry → relation.typedCarryRelation
  zkSound :
    NumiSealZKAccepted gates.zk → relation.zkMaskedResidualRelation
  productPolicySound :
    NumiSealProductPolicyAccepted gates.policy → relation.productPolicyRelation

theorem numiSealProduct_acceptance_requires_source_fold
    {gates : NumiSealProductVerifierGates}
    (hAccepts : NumiSealProductVerifierAccepts gates) :
    gates.terminal.sourceFoldAccepted :=
  hAccepts.1.1

theorem numiSealProduct_acceptance_requires_terminal_seal
    {gates : NumiSealProductVerifierGates}
    (hAccepts : NumiSealProductVerifierAccepts gates) :
    gates.terminal.terminalEnvelopeAccepted :=
  hAccepts.1.2.2.2.1

theorem numiSealProduct_acceptance_requires_typed_carry
    {gates : NumiSealProductVerifierGates}
    (hAccepts : NumiSealProductVerifierAccepts gates) :
    NumiSealTypedCarryAccepted gates.carry :=
  hAccepts.2.1

theorem numiSealProduct_acceptance_requires_zk_layer
    {gates : NumiSealProductVerifierGates}
    (hAccepts : NumiSealProductVerifierAccepts gates) :
    NumiSealZKAccepted gates.zk :=
  hAccepts.2.2.1

theorem numiSealProduct_endToEnd_from_evidence
    {gates : NumiSealProductVerifierGates}
    {relation : NumiSealEndToEndRelation}
    (hAccepts : NumiSealProductVerifierAccepts gates)
    (evidence : NumiSealEndToEndEvidence gates relation) :
    NumiSealEndToEndRelationHolds relation := by
  rcases hAccepts with ⟨hTerminal, hCarry, hZK, hPolicy⟩
  rcases hTerminal with
    ⟨hSourceFold, hMetadata, hObligations, hEnvelope, hTranscript, hComponentRoot⟩
  exact ⟨
    evidence.sourceFoldSound hSourceFold,
    evidence.obligationReconstructionSound hMetadata hObligations,
    evidence.terminalSealSound hEnvelope hTranscript hComponentRoot,
    evidence.typedCarrySound hCarry,
    evidence.zkSound hZK,
    evidence.productPolicySound hPolicy
  ⟩

theorem numiSealTerminalProduct_endToEnd_from_evidence
    {gates : NumiSealProductVerifierGates}
    {relation : NumiSealEndToEndRelation}
    (hAccepts : NumiSealTerminalProductVerifierAccepts gates)
    (evidence : NumiSealEndToEndEvidence gates relation) :
    NumiSealEndToEndRelationHolds relation :=
  numiSealProduct_endToEnd_from_evidence hAccepts.1 evidence

theorem numiSealZKProduct_endToEnd_from_evidence
    {gates : NumiSealProductVerifierGates}
    {relation : NumiSealEndToEndRelation}
    (hAccepts : NumiSealZKProductVerifierAccepts gates)
    (evidence : NumiSealEndToEndEvidence gates relation) :
    NumiSealEndToEndRelationHolds relation :=
  numiSealProduct_endToEnd_from_evidence hAccepts.1 evidence

end SuperNeoFormal
