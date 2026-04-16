import SuperNeoFormal.NumiSealProductTheorem

/-!
Product cryptographic security theorem surface.

This module is the checked boundary for the paper-grade theorem program.  It
does not manufacture missing extractor, QROM, lattice-loss, or side-channel
evidence.  Instead it states the actual product theorem shape: accepted product
relations plus pinned transcript/artifact bindings, a bounded-depth loss
accounting record, a lattice-assumption dossier, Fiat-Shamir/QROM evidence, and
explicit completeness/soundness/ZK obligations imply the product security
guarantee used by release policy.
-/

namespace SuperNeoFormal

inductive ProductFiatShamirModel where
  | rom
  | qrom
  deriving DecidableEq, Repr

inductive ProductRecursionDepthModel where
  | boundedDepth
  | polynomialDepth
  deriving DecidableEq, Repr

structure ProductSecurityParameters where
  maximumProductDepth : Nat
  claimedClassicalSecurityBits : Nat
  claimedQuantumSecurityBits : Nat
  soundnessLossBudgetBits : Nat
  recursionDepthModel : ProductRecursionDepthModel
  fiatShamirModel : ProductFiatShamirModel

structure ProductSystemBindings where
  sourceFoldRelationBound : Prop
  terminalRelationBound : Prop
  zkMaskedResidualRelationBound : Prop
  typedRecursiveCarryRelationBound : Prop
  transcriptDomainsBound : Prop
  artifactMetadataBound : Prop
  proofEnvelopeHeadersBound : Prop
  verifierPolicyBound : Prop

def ProductSystemBindingsAccepted (bindings : ProductSystemBindings) : Prop :=
  bindings.sourceFoldRelationBound
    ∧ bindings.terminalRelationBound
    ∧ bindings.zkMaskedResidualRelationBound
    ∧ bindings.typedRecursiveCarryRelationBound
    ∧ bindings.transcriptDomainsBound
    ∧ bindings.artifactMetadataBound
    ∧ bindings.proofEnvelopeHeadersBound
    ∧ bindings.verifierPolicyBound

structure ProductBoundedDepthLossEvidence
    (parameters : ProductSecurityParameters) where
  supportedDepthPositive : 0 < parameters.maximumProductDepth
  allAcceptedLayersWithinDepth : Prop
  sourceFoldLossAccounted : Prop
  terminalSealLossAccounted : Prop
  recursiveCarryLossAccounted : Prop
  zkMaskingLossAccounted : Prop
  fiatShamirLossAccounted : Prop
  totalLossWithinBudget : Prop

def ProductBoundedDepthLossAccepted
    {parameters : ProductSecurityParameters}
    (losses : ProductBoundedDepthLossEvidence parameters) : Prop :=
  (0 < parameters.maximumProductDepth)
    ∧ losses.allAcceptedLayersWithinDepth
    ∧ losses.sourceFoldLossAccounted
    ∧ losses.terminalSealLossAccounted
    ∧ losses.recursiveCarryLossAccounted
    ∧ losses.zkMaskingLossAccounted
    ∧ losses.fiatShamirLossAccounted
    ∧ losses.totalLossWithinBudget

structure ProductLatticeAssumptionDossier where
  moduleSISStatementPinned : Prop
  qRingDimensionAndNormPinned : Prop
  decompositionAndChallengeParametersPinned : Prop
  normGrowthAcrossFoldAndNumiSealPinned : Prop
  reductionLossAccounted : Prop
  classicalCostEstimatePinned : Prop
  quantumCostEstimatePinned : Prop
  parameterSensitivityRecorded : Prop
  failureProbabilityBudgetRecorded : Prop

def ProductLatticeAssumptionDossierAccepted
    (dossier : ProductLatticeAssumptionDossier) : Prop :=
  dossier.moduleSISStatementPinned
    ∧ dossier.qRingDimensionAndNormPinned
    ∧ dossier.decompositionAndChallengeParametersPinned
    ∧ dossier.normGrowthAcrossFoldAndNumiSealPinned
    ∧ dossier.reductionLossAccounted
    ∧ dossier.classicalCostEstimatePinned
    ∧ dossier.quantumCostEstimatePinned
    ∧ dossier.parameterSensitivityRecorded
    ∧ dossier.failureProbabilityBudgetRecorded

structure ProductFiatShamirQROMEvidence where
  interactivePublicCoinProtocolSpecified : Prop
  transformPreconditionsSatisfied : Prop
  quantumOracleQueryBoundAccounted : Prop
  transcriptDomainSeparatorsBound : Prop
  proofKindSeparationBound : Prop
  transcriptCollisionMalleabilityExcluded : Prop

def ProductFiatShamirQROMAccepted
    (evidence : ProductFiatShamirQROMEvidence) : Prop :=
  evidence.interactivePublicCoinProtocolSpecified
    ∧ evidence.transformPreconditionsSatisfied
    ∧ evidence.quantumOracleQueryBoundAccounted
    ∧ evidence.transcriptDomainSeparatorsBound
    ∧ evidence.proofKindSeparationBound
    ∧ evidence.transcriptCollisionMalleabilityExcluded

structure ProductCompletenessSoundnessZKClaim where
  completeness : Prop
  knowledgeSoundness : Prop
  zeroKnowledge : Prop
  composition : Prop

def ProductCompletenessSoundnessZKHolds
    (claim : ProductCompletenessSoundnessZKClaim) : Prop :=
  claim.completeness
    ∧ claim.knowledgeSoundness
    ∧ claim.zeroKnowledge
    ∧ claim.composition

structure ProductSecurityTheoremEvidence
    {depth : Nat}
    {View Leakage : Type}
    (parameters : ProductSecurityParameters)
    (bindings : ProductSystemBindings)
    (relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage)
    (losses : ProductBoundedDepthLossEvidence parameters)
    (assumptions : ProductLatticeAssumptionDossier)
    (fiatShamir : ProductFiatShamirQROMEvidence)
    (claim : ProductCompletenessSoundnessZKClaim) where
  productRelationsHold :
    NumiSealProductKnowledgeCarryPrivacyHolds relations
  completenessSound :
    ProductSystemBindingsAccepted bindings →
      NumiSealProductKnowledgeCarryPrivacyHolds relations →
        claim.completeness
  knowledgeSoundnessSound :
    ProductBoundedDepthLossAccepted losses →
      ProductLatticeAssumptionDossierAccepted assumptions →
      ProductFiatShamirQROMAccepted fiatShamir →
      NumiSealProductKnowledgeCarryPrivacyHolds relations →
        claim.knowledgeSoundness
  zeroKnowledgeSound :
    ProductSystemBindingsAccepted bindings →
      ProductFiatShamirQROMAccepted fiatShamir →
      NumiSealProductKnowledgeCarryPrivacyHolds relations →
        claim.zeroKnowledge
  compositionSound :
    ProductSystemBindingsAccepted bindings →
      ProductBoundedDepthLossAccepted losses →
      ProductLatticeAssumptionDossierAccepted assumptions →
      ProductFiatShamirQROMAccepted fiatShamir →
        claim.composition

theorem productSecurityTheorem_from_evidence
    {depth : Nat}
    {View Leakage : Type}
    {parameters : ProductSecurityParameters}
    {bindings : ProductSystemBindings}
    {relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage}
    {losses : ProductBoundedDepthLossEvidence parameters}
    {assumptions : ProductLatticeAssumptionDossier}
    {fiatShamir : ProductFiatShamirQROMEvidence}
    {claim : ProductCompletenessSoundnessZKClaim}
    (hBindings : ProductSystemBindingsAccepted bindings)
    (hLosses : ProductBoundedDepthLossAccepted losses)
    (hAssumptions : ProductLatticeAssumptionDossierAccepted assumptions)
    (hFiatShamir : ProductFiatShamirQROMAccepted fiatShamir)
    (evidence :
      ProductSecurityTheoremEvidence
        parameters
        bindings
        relations
        losses
        assumptions
        fiatShamir
        claim) :
    ProductCompletenessSoundnessZKHolds claim :=
  ⟨
    evidence.completenessSound hBindings evidence.productRelationsHold,
    evidence.knowledgeSoundnessSound
      hLosses
      hAssumptions
      hFiatShamir
      evidence.productRelationsHold,
    evidence.zeroKnowledgeSound
      hBindings
      hFiatShamir
      evidence.productRelationsHold,
    evidence.compositionSound hBindings hLosses hAssumptions hFiatShamir
  ⟩

theorem productSecurityTheorem_requires_bounded_depth
    {parameters : ProductSecurityParameters}
    {losses : ProductBoundedDepthLossEvidence parameters}
    (hLosses : ProductBoundedDepthLossAccepted losses) :
    0 < parameters.maximumProductDepth :=
  hLosses.1

theorem productSecurityTheorem_requires_qrom_accounting
    {fiatShamir : ProductFiatShamirQROMEvidence}
    (hFiatShamir : ProductFiatShamirQROMAccepted fiatShamir) :
    fiatShamir.quantumOracleQueryBoundAccounted :=
  hFiatShamir.2.2.1

theorem productSecurityTheorem_requires_artifact_envelope_binding
    {bindings : ProductSystemBindings}
    (hBindings : ProductSystemBindingsAccepted bindings) :
    bindings.artifactMetadataBound ∧ bindings.proofEnvelopeHeadersBound :=
  ⟨hBindings.2.2.2.2.2.1, hBindings.2.2.2.2.2.2.1⟩

end SuperNeoFormal
