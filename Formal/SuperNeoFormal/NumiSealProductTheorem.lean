import SuperNeoFormal.NumiSealEndToEnd
import SuperNeoFormal.NumiSealTypedCarryTheorem
import SuperNeoFormal.NumiSealZKPrivacy
import SuperNeoFormal.RecursiveFoldingKnowledge

/-!
NumiSeal product theorem composition.

This module ties the product end-to-end relation to the three theorem surfaces
that were previously only residual obligations: recursive folding knowledge
soundness, typed carry producer/consumer composition, and NumiSealZK
simulation/privacy under an explicit leakage model.
-/

namespace SuperNeoFormal

structure NumiSealProductKnowledgeCarryPrivacyRelations
    (depth : Nat)
    (View Leakage : Type) where
  endToEndRelation : NumiSealEndToEndRelation
  recursiveKnowledgeRelation : RecursiveFoldingKnowledgeChainRelation depth
  typedCarryRelation : NumiSealTypedCarryProducerConsumerRelation
  zkPrivacyClaim : NumiSealZKSimulationPrivacyClaim View Leakage

def NumiSealProductKnowledgeCarryPrivacyHolds
    {depth : Nat}
    {View Leakage : Type}
    (relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage) :
    Prop :=
  NumiSealEndToEndRelationHolds relations.endToEndRelation
    ∧ RecursiveFoldingKnowledgeChainHolds relations.recursiveKnowledgeRelation
    ∧ NumiSealTypedCarryProducerConsumerRelationHolds relations.typedCarryRelation
    ∧ NumiSealZKSimulationPrivacyHolds relations.zkPrivacyClaim

structure NumiSealProductTheoremObligationStatus where
  endToEnd : NumiSealEndToEndObligationStatus
  recursiveKnowledge : RecursiveFoldingKnowledgeObligationStatus
  typedCarry : NumiSealTypedCarryObligationStatus
  zkPrivacy : NumiSealZKPrivacyObligationStatus

def NumiSealProductTheoremObligationStatus.FullyInstantiated
    (status : NumiSealProductTheoremObligationStatus) : Prop :=
  status.endToEnd.FullyInstantiated
    ∧ status.recursiveKnowledge.FullyInstantiated
    ∧ status.typedCarry.FullyInstantiated
    ∧ status.zkPrivacy.FullyInstantiated

theorem numiSealProductKnowledgeCarryPrivacy_composition
    {depth : Nat}
    {View Leakage : Type}
    {relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage}
    (hEndToEnd : NumiSealEndToEndRelationHolds relations.endToEndRelation)
    (hKnowledge :
      RecursiveFoldingKnowledgeChainHolds
        relations.recursiveKnowledgeRelation)
    (hCarry :
      NumiSealTypedCarryProducerConsumerRelationHolds
        relations.typedCarryRelation)
    (hPrivacy :
      NumiSealZKSimulationPrivacyHolds
        relations.zkPrivacyClaim) :
    NumiSealProductKnowledgeCarryPrivacyHolds relations :=
  ⟨hEndToEnd, hKnowledge, hCarry, hPrivacy⟩

theorem numiSealProductKnowledgeCarryPrivacy_from_evidence
    {depth : Nat}
    {View Leakage : Type}
    {productGates : NumiSealProductVerifierGates}
    {endToEndRelation : NumiSealEndToEndRelation}
    {recursiveGates : RecursiveFoldingKnowledgeChainGates depth}
    {recursiveRelation : RecursiveFoldingKnowledgeChainRelation depth}
    {carryProducer : NumiSealTypedCarryProducerGates}
    {carryConsumer : NumiSealTypedCarryConsumerGates}
    {carryRelation : NumiSealTypedCarryProducerConsumerRelation}
    {leakageModel : NumiSealZKLeakageModel}
    {zkPrivacyClaim : NumiSealZKSimulationPrivacyClaim View Leakage}
    (hProduct : NumiSealZKProductVerifierAccepts productGates)
    (hRecursive :
      RecursiveFoldingKnowledgeChainAccepted recursiveGates)
    (hCarryProducer :
      NumiSealTypedCarryProducerAccepted carryProducer)
    (hCarryConsumer :
      NumiSealTypedCarryConsumerAccepted carryConsumer)
    (hLeakageModel :
      NumiSealZKLeakageModelAccepted leakageModel)
    (endToEndEvidence :
      NumiSealEndToEndEvidence productGates endToEndRelation)
    (recursiveEvidence :
      RecursiveFoldingKnowledgeChainEvidence
        recursiveGates
        recursiveRelation)
    (carryEvidence :
      NumiSealTypedCarryProducerConsumerEvidence
        carryProducer
        carryConsumer
        carryRelation)
    (zkEvidence :
      NumiSealZKSimulationEvidence
        productGates.zk
        leakageModel
        zkPrivacyClaim) :
    NumiSealProductKnowledgeCarryPrivacyHolds
      {
        endToEndRelation := endToEndRelation
        recursiveKnowledgeRelation := recursiveRelation
        typedCarryRelation := carryRelation
        zkPrivacyClaim := zkPrivacyClaim
      } :=
  numiSealProductKnowledgeCarryPrivacy_composition
    (numiSealProduct_endToEnd_from_evidence
      hProduct.1
      endToEndEvidence)
    (recursiveFoldingKnowledgeSoundness_from_chainEvidence
      hRecursive
      recursiveEvidence)
    (numiSealTypedCarryProducerConsumer_from_evidence
      hCarryProducer
      hCarryConsumer
      carryEvidence)
    (numiSealZKProduct_privacy_from_product_acceptance
      hProduct
      hLeakageModel
      zkEvidence)

end SuperNeoFormal
