import SuperNeoFormal.Composition

/-!
Recursive folding knowledge-soundness surface.

This module records the checked composition theorem for recursive folding
knowledge soundness.  It is deliberately parametric in the extractor evidence:
the theorem proves that accepted recursive folding gates imply the recursive
knowledge relation once every accepted layer supplies the named local extractor
obligations and the chain-level digest/final-accumulator obligations.
-/

namespace SuperNeoFormal

structure RecursiveFoldingKnowledgeStepGates where
  foldReductionAccepted : Prop
  terminalWitnessesExtracted : Prop
  transcriptOutsideBadEvents : Prop
  publicAccumulatorBound : Prop
  priorCarryConsumed : Prop

def RecursiveFoldingKnowledgeStepAccepted
    (gates : RecursiveFoldingKnowledgeStepGates) : Prop :=
  gates.foldReductionAccepted
    ∧ gates.terminalWitnessesExtracted
    ∧ gates.transcriptOutsideBadEvents
    ∧ gates.publicAccumulatorBound
    ∧ gates.priorCarryConsumed

structure RecursiveFoldingKnowledgeStepRelation where
  extractedWitnessExists : Prop
  foldedRelationSatisfied : Prop
  accumulatorConsistent : Prop
  priorCarryConsistent : Prop
  transcriptConsistent : Prop

def RecursiveFoldingKnowledgeStepRelationHolds
    (relation : RecursiveFoldingKnowledgeStepRelation) : Prop :=
  relation.extractedWitnessExists
    ∧ relation.foldedRelationSatisfied
    ∧ relation.accumulatorConsistent
    ∧ relation.priorCarryConsistent
    ∧ relation.transcriptConsistent

structure RecursiveFoldingKnowledgeStepEvidence
    (gates : RecursiveFoldingKnowledgeStepGates)
    (relation : RecursiveFoldingKnowledgeStepRelation) where
  witnessExtractionSound :
    gates.foldReductionAccepted →
      gates.terminalWitnessesExtracted →
        relation.extractedWitnessExists
  foldedRelationSound :
    gates.foldReductionAccepted →
      gates.publicAccumulatorBound →
        relation.foldedRelationSatisfied
  accumulatorSound :
    gates.publicAccumulatorBound →
      relation.accumulatorConsistent
  priorCarrySound :
    gates.priorCarryConsumed →
      relation.priorCarryConsistent
  transcriptSound :
    gates.transcriptOutsideBadEvents →
      relation.transcriptConsistent

theorem recursiveFoldingKnowledgeStepSoundness_from_evidence
    {gates : RecursiveFoldingKnowledgeStepGates}
    {relation : RecursiveFoldingKnowledgeStepRelation}
    (hAccepted : RecursiveFoldingKnowledgeStepAccepted gates)
    (evidence : RecursiveFoldingKnowledgeStepEvidence gates relation) :
    RecursiveFoldingKnowledgeStepRelationHolds relation := by
  rcases hAccepted with
    ⟨hFold, hTerminalWitnesses, hTranscript, hAccumulator, hPriorCarry⟩
  exact ⟨
    evidence.witnessExtractionSound hFold hTerminalWitnesses,
    evidence.foldedRelationSound hFold hAccumulator,
    evidence.accumulatorSound hAccumulator,
    evidence.priorCarrySound hPriorCarry,
    evidence.transcriptSound hTranscript
  ⟩

structure RecursiveFoldingKnowledgeChainGates (depth : Nat) where
  steps : Fin depth → RecursiveFoldingKnowledgeStepGates
  chainDigestBound : Prop
  finalAccumulatorBound : Prop

def RecursiveFoldingKnowledgeChainAccepted
    {depth : Nat}
    (chain : RecursiveFoldingKnowledgeChainGates depth) : Prop :=
  (∀ step, RecursiveFoldingKnowledgeStepAccepted (chain.steps step))
    ∧ chain.chainDigestBound
    ∧ chain.finalAccumulatorBound

structure RecursiveFoldingKnowledgeChainRelation (depth : Nat) where
  stepRelations : Fin depth → RecursiveFoldingKnowledgeStepRelation
  chainDigestRelation : Prop
  finalKnowledgeRelation : Prop

def RecursiveFoldingKnowledgeChainHolds
    {depth : Nat}
    (relation : RecursiveFoldingKnowledgeChainRelation depth) : Prop :=
  (∀ step,
      RecursiveFoldingKnowledgeStepRelationHolds
        (relation.stepRelations step))
    ∧ relation.chainDigestRelation
    ∧ relation.finalKnowledgeRelation

structure RecursiveFoldingKnowledgeChainEvidence
    {depth : Nat}
    (chain : RecursiveFoldingKnowledgeChainGates depth)
    (relation : RecursiveFoldingKnowledgeChainRelation depth) where
  stepEvidence :
    ∀ step,
      RecursiveFoldingKnowledgeStepEvidence
        (chain.steps step)
        (relation.stepRelations step)
  chainDigestSound :
    chain.chainDigestBound →
      relation.chainDigestRelation
  finalAccumulatorSound :
    chain.finalAccumulatorBound →
      relation.finalKnowledgeRelation

theorem recursiveFoldingKnowledgeSoundness_from_chainEvidence
    {depth : Nat}
    {chain : RecursiveFoldingKnowledgeChainGates depth}
    {relation : RecursiveFoldingKnowledgeChainRelation depth}
    (hAccepted : RecursiveFoldingKnowledgeChainAccepted chain)
    (evidence : RecursiveFoldingKnowledgeChainEvidence chain relation) :
    RecursiveFoldingKnowledgeChainHolds relation := by
  rcases hAccepted with ⟨hSteps, hChainDigest, hFinalAccumulator⟩
  exact ⟨
    fun step =>
      recursiveFoldingKnowledgeStepSoundness_from_evidence
        (hSteps step)
        (evidence.stepEvidence step),
    evidence.chainDigestSound hChainDigest,
    evidence.finalAccumulatorSound hFinalAccumulator
  ⟩

theorem recursiveFoldingKnowledge_terminalCE_witnesses_from_badSeed_certificate
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {outputCount bound : Nat}
    {reduction : FoldReductionGates Claim outputCount}
    {terminal : TerminalProofVerifierGates Claim Proof outputCount}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (hAccepts : SuperNeoProofVerifierAccepts reduction terminal)
    (certificate :
      TerminalCEFiniteBadSeedCertificate
        terminal.verifyProof
        opens
        proofSeed
        bound)
    (hSeed : proofSeed terminal.proof ∉ certificate.badSeeds) :
    FoldReductionAccepted reduction ∧
      terminal.statementMatchesReduction ∧
      ∃ witnesses : Fin outputCount → Witness,
        TerminalLocalBatchRelation terminal.statement witnesses opens :=
  superneo_end_to_end_outside_ce_badSeeds
    hAccepts
    certificate
    hSeed

end SuperNeoFormal
