import SuperNeoFormal.NumiSealEndToEnd

/-!
NumiSeal typed-carry producer/consumer theorem.

The Swift surface has two distinct obligations: a producer must bind a typed
carry statement to an accepted parent proof and residual opening, and a consumer
must accept the same typed statement only for the expected parent/context and
fresh replay identity.  This module states and proves that those accepted gates,
plus the local digest/grammar evidence, imply the typed recursive carry
producer/consumer relation.
-/

namespace SuperNeoFormal

structure NumiSealTypedCarryProducerGates where
  parentProofAccepted : Prop
  producerEnvelopeDigestBound : Prop
  producerTranscriptDigestBound : Prop
  parentStatementDigestBound : Prop
  parentPublicStatementDigestBound : Prop
  residualOpeningDigestBound : Prop
  decompositionCommitmentBound : Prop
  finalPointBound : Prop
  consumerContextBound : Prop
  productContextDigestBound : Prop
  carryDigestBound : Prop
  recursionLevelAdvanced : Prop

def NumiSealTypedCarryProducerAccepted
    (producer : NumiSealTypedCarryProducerGates) : Prop :=
  producer.parentProofAccepted
    ∧ producer.producerEnvelopeDigestBound
    ∧ producer.producerTranscriptDigestBound
    ∧ producer.parentStatementDigestBound
    ∧ producer.parentPublicStatementDigestBound
    ∧ producer.residualOpeningDigestBound
    ∧ producer.decompositionCommitmentBound
    ∧ producer.finalPointBound
    ∧ producer.consumerContextBound
    ∧ producer.productContextDigestBound
    ∧ producer.carryDigestBound
    ∧ producer.recursionLevelAdvanced

structure NumiSealTypedCarryConsumerGates where
  typedGrammarAccepted : Prop
  parentProofAccepted : Prop
  producerEnvelopeDigestMatched : Prop
  producerTranscriptDigestMatched : Prop
  parentStatementDigestMatched : Prop
  parentPublicStatementDigestMatched : Prop
  consumerContextDigestMatched : Prop
  productContextDigestMatched : Prop
  carryDigestMatched : Prop
  recursionLevelMonotone : Prop
  replayIdentityFresh : Prop

def NumiSealTypedCarryConsumerAccepted
    (consumer : NumiSealTypedCarryConsumerGates) : Prop :=
  consumer.typedGrammarAccepted
    ∧ consumer.parentProofAccepted
    ∧ consumer.producerEnvelopeDigestMatched
    ∧ consumer.producerTranscriptDigestMatched
    ∧ consumer.parentStatementDigestMatched
    ∧ consumer.parentPublicStatementDigestMatched
    ∧ consumer.consumerContextDigestMatched
    ∧ consumer.productContextDigestMatched
    ∧ consumer.carryDigestMatched
    ∧ consumer.recursionLevelMonotone
    ∧ consumer.replayIdentityFresh

structure NumiSealTypedCarryProducerConsumerRelation where
  producedFromAcceptedParent : Prop
  consumedByExpectedChild : Prop
  producerConsumerDigestsAgree : Prop
  carriedResidualBoundToNextStatement : Prop
  productCarryContextBound : Prop
  recursionLevelMonotone : Prop
  replayIdentityFresh : Prop

def NumiSealTypedCarryProducerConsumerRelationHolds
    (relation : NumiSealTypedCarryProducerConsumerRelation) : Prop :=
  relation.producedFromAcceptedParent
    ∧ relation.consumedByExpectedChild
    ∧ relation.producerConsumerDigestsAgree
    ∧ relation.carriedResidualBoundToNextStatement
    ∧ relation.productCarryContextBound
    ∧ relation.recursionLevelMonotone
    ∧ relation.replayIdentityFresh

structure NumiSealTypedCarryObligationStatus where
  producerAcceptedParent : TheoremObligationStatus
  consumerExpectedChild : TheoremObligationStatus
  digestAgreement : TheoremObligationStatus
  residualCarryBinding : TheoremObligationStatus
  productCarryContext : TheoremObligationStatus
  recursionLevel : TheoremObligationStatus
  replayFreshness : TheoremObligationStatus

def NumiSealTypedCarryObligationStatus.FullyInstantiated
    (status : NumiSealTypedCarryObligationStatus) : Prop :=
  status.producerAcceptedParent.Accepted
    ∧ status.consumerExpectedChild.Accepted
    ∧ status.digestAgreement.Accepted
    ∧ status.residualCarryBinding.Accepted
    ∧ status.productCarryContext.Accepted
    ∧ status.recursionLevel.Accepted
    ∧ status.replayFreshness.Accepted

structure NumiSealTypedCarryProducerConsumerEvidence
    (producer : NumiSealTypedCarryProducerGates)
    (consumer : NumiSealTypedCarryConsumerGates)
    (relation : NumiSealTypedCarryProducerConsumerRelation) where
  producerSound :
    NumiSealTypedCarryProducerAccepted producer →
      relation.producedFromAcceptedParent
  consumerSound :
    NumiSealTypedCarryConsumerAccepted consumer →
      relation.consumedByExpectedChild
  digestAgreementSound :
    producer.producerEnvelopeDigestBound →
      producer.producerTranscriptDigestBound →
      producer.parentStatementDigestBound →
      producer.parentPublicStatementDigestBound →
      producer.carryDigestBound →
      consumer.producerEnvelopeDigestMatched →
      consumer.producerTranscriptDigestMatched →
      consumer.parentStatementDigestMatched →
      consumer.parentPublicStatementDigestMatched →
      consumer.carryDigestMatched →
        relation.producerConsumerDigestsAgree
  residualCarrySound :
    producer.residualOpeningDigestBound →
      producer.decompositionCommitmentBound →
      producer.finalPointBound →
      producer.consumerContextBound →
      consumer.consumerContextDigestMatched →
        relation.carriedResidualBoundToNextStatement
  productContextSound :
    producer.productContextDigestBound →
      consumer.productContextDigestMatched →
        relation.productCarryContextBound
  recursionSound :
    producer.recursionLevelAdvanced →
      consumer.recursionLevelMonotone →
        relation.recursionLevelMonotone
  replaySound :
    consumer.replayIdentityFresh →
      relation.replayIdentityFresh

theorem numiSealTypedCarryProducerConsumer_from_evidence
    {producer : NumiSealTypedCarryProducerGates}
    {consumer : NumiSealTypedCarryConsumerGates}
    {relation : NumiSealTypedCarryProducerConsumerRelation}
    (hProducer : NumiSealTypedCarryProducerAccepted producer)
    (hConsumer : NumiSealTypedCarryConsumerAccepted consumer)
    (evidence :
      NumiSealTypedCarryProducerConsumerEvidence
        producer
        consumer
        relation) :
    NumiSealTypedCarryProducerConsumerRelationHolds relation := by
  rcases hProducer with
    ⟨hParentAccepted, hEnvelope, hTranscript, hParentStatement,
      hParentPublicStatement, hResidual, hDecomposition, hFinalPoint,
      hConsumerContext, hProductContext, hCarryDigest, hProducerRecursion⟩
  rcases hConsumer with
    ⟨hTypedGrammar, hConsumerParentAccepted, hEnvelopeMatched,
      hTranscriptMatched, hParentStatementMatched, hParentPublicStatementMatched,
      hConsumerContextMatched, hProductContextMatched, hCarryDigestMatched,
      hConsumerRecursion, hReplayFresh⟩
  have hProducerAccepted :
      NumiSealTypedCarryProducerAccepted producer := by
    exact ⟨
      hParentAccepted,
      hEnvelope,
      hTranscript,
      hParentStatement,
      hParentPublicStatement,
      hResidual,
      hDecomposition,
      hFinalPoint,
      hConsumerContext,
      hProductContext,
      hCarryDigest,
      hProducerRecursion
    ⟩
  have hConsumerAccepted :
      NumiSealTypedCarryConsumerAccepted consumer := by
    exact ⟨
      hTypedGrammar,
      hConsumerParentAccepted,
      hEnvelopeMatched,
      hTranscriptMatched,
      hParentStatementMatched,
      hParentPublicStatementMatched,
      hConsumerContextMatched,
      hProductContextMatched,
      hCarryDigestMatched,
      hConsumerRecursion,
      hReplayFresh
    ⟩
  exact ⟨
    evidence.producerSound hProducerAccepted,
    evidence.consumerSound hConsumerAccepted,
    evidence.digestAgreementSound
      hEnvelope
      hTranscript
      hParentStatement
      hParentPublicStatement
      hCarryDigest
      hEnvelopeMatched
      hTranscriptMatched
      hParentStatementMatched
      hParentPublicStatementMatched
      hCarryDigestMatched,
    evidence.residualCarrySound
      hResidual
      hDecomposition
      hFinalPoint
      hConsumerContext
      hConsumerContextMatched,
    evidence.productContextSound
      hProductContext
      hProductContextMatched,
    evidence.recursionSound hProducerRecursion hConsumerRecursion,
    evidence.replaySound hReplayFresh
  ⟩

theorem numiSealTypedCarry_from_product_carry_acceptance
    {carry : NumiSealTypedCarryGates}
    {producer : NumiSealTypedCarryProducerGates}
    {consumer : NumiSealTypedCarryConsumerGates}
    {relation : NumiSealTypedCarryProducerConsumerRelation}
    (hCarry : NumiSealTypedCarryAccepted carry)
    (hProducer : NumiSealTypedCarryProducerAccepted producer)
    (hConsumer : NumiSealTypedCarryConsumerAccepted consumer)
    (evidence :
      NumiSealTypedCarryProducerConsumerEvidence
        producer
        consumer
        relation)
    (hCarryModeSound :
      carry.carryModeAccepted →
        carry.typedCarryGrammarAccepted →
          relation.consumedByExpectedChild) :
    NumiSealTypedCarryProducerConsumerRelationHolds relation := by
  rcases hCarry with ⟨hCarryMode, hTypedGrammar, _, _, _⟩
  have hRelation :=
    numiSealTypedCarryProducerConsumer_from_evidence
      hProducer
      hConsumer
      evidence
  rcases hRelation with
    ⟨hProduced, _, hDigests, hResidual, hProductContext, hRecursion, hReplay⟩
  exact ⟨
    hProduced,
    hCarryModeSound hCarryMode hTypedGrammar,
    hDigests,
    hResidual,
    hProductContext,
    hRecursion,
    hReplay
  ⟩

end SuperNeoFormal
