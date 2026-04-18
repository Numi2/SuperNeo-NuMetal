import SuperNeoFormal.NumiSealProductTheorem
import SuperNeoFormal.ProductBadEventLedger
import SuperNeoFormal.CTCORepeatedTapeSoundness

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

inductive ProductQROMTransformFamily where
  | dfm20
  | commitOpenTight
  | openAndSign
  | ctco
  | merkleStraightline
  deriving DecidableEq, Repr

abbrev ProductCompilerFamily := ProductQROMTransformFamily

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

structure ProductSelectedDepthLossLedger where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  sourceFoldLossInstantiated : Prop
  terminalSealLossInstantiated : Prop
  recursiveCarryLossInstantiated : Prop
  zkSimulatorLossInstantiated : Prop
  fiatShamirQROMLossInstantiated : Prop
  extractorLossInstantiated : Prop
  productOperationsReplayLossInstantiated : Prop
  constantTimeSideChannelEvidenceClosed : Prop
  releaseSigningEvidenceClosed : Prop
  totalLossWithinBudget : Prop

def ProductSelectedDepthLossLedgerAccepted
    (ledger : ProductSelectedDepthLossLedger) : Prop :=
  (0 < ledger.selectedDepth)
    ∧ ledger.sourceFoldLossInstantiated
    ∧ ledger.terminalSealLossInstantiated
    ∧ ledger.recursiveCarryLossInstantiated
    ∧ ledger.zkSimulatorLossInstantiated
    ∧ ledger.fiatShamirQROMLossInstantiated
    ∧ ledger.extractorLossInstantiated
    ∧ ledger.productOperationsReplayLossInstantiated
    ∧ ledger.constantTimeSideChannelEvidenceClosed
    ∧ ledger.releaseSigningEvidenceClosed
    ∧ ledger.totalLossWithinBudget

structure ProductFiniteProtocolNumericLossObstruction where
  selectedDepth : Nat
  selectedSecurityBudgetBits : Nat
  pirlcCRTCertificateBoundExceedsSelectedBudget : Prop
  pirlcFullRingUnitPivotBoundStillExceedsSelectedBudget : Prop
  pirlcOneShotEqualityCounterexamplePinned : Prop
  piccsExt2RoundBoundExceedsSelectedBudget : Prop
  piccsOneShotFirstChallengeCounterexamplePinned : Prop
  terminalCEFullTapeLiftNotBudgetUseful : Prop
  terminalCERepeatedChallengeBoundWithinSelectedBudget : Prop
  terminalCEPinnedAt226Rounds : Prop
  ctcoRepeatedTapeAmplificationAvailable : Prop
  fixedKindRepeatedTapeRouteRequired : Prop
  sourceFoldRepeatedTapeLossInstantiated : Prop
  terminalSealRepeatedTapeLossInstantiated : Prop
  selectedTotalLossRemainsUninstantiated : Prop

def ProductFiniteProtocolNumericLossObstructionAccepted
    (obstruction : ProductFiniteProtocolNumericLossObstruction) : Prop :=
  obstruction.selectedDepth = 1
    ∧ obstruction.selectedSecurityBudgetBits = 128
    ∧ obstruction.pirlcCRTCertificateBoundExceedsSelectedBudget
    ∧ obstruction.pirlcFullRingUnitPivotBoundStillExceedsSelectedBudget
    ∧ obstruction.pirlcOneShotEqualityCounterexamplePinned
    ∧ obstruction.piccsExt2RoundBoundExceedsSelectedBudget
    ∧ obstruction.piccsOneShotFirstChallengeCounterexamplePinned
    ∧ obstruction.terminalCEFullTapeLiftNotBudgetUseful
    ∧ obstruction.terminalCERepeatedChallengeBoundWithinSelectedBudget
    ∧ obstruction.terminalCEPinnedAt226Rounds
    ∧ obstruction.ctcoRepeatedTapeAmplificationAvailable
    ∧ obstruction.fixedKindRepeatedTapeRouteRequired
    ∧ obstruction.sourceFoldRepeatedTapeLossInstantiated
    ∧ obstruction.terminalSealRepeatedTapeLossInstantiated
    ∧ obstruction.selectedTotalLossRemainsUninstantiated

inductive ProductDepthOneExpectedProofKind where
  | fold
  | terminal
  | compressedTerminal
  | numiSealTerminal
  | numiSealZKProduct
  deriving DecidableEq, Repr

structure ProductFixedKindCTCORepeatedTapePlan where
  selectedDepth : Nat
  expectedKind : ProductDepthOneExpectedProofKind
  expectedKindBoundByHBind : Prop
  fixedContextChargesOnlyExpectedKindFiniteTerms : Prop
  dispatcherCorollaryRangesOverAcceptedKinds : Prop
  oneExternalSeedPerAcceptedProofKindPreserved : Prop
  repeatedInternalTapesExpandedByDomainSeparatedHChal : Prop
  pirlcOneShotLowerBoundPinned : Prop
  piccsOneShotLowerBoundPinned : Prop
  genericRepeatedTapeAmplificationProved : Prop
  piccsTwoTapeInstantiationWithinBudget : Prop
  pirlcThreeTapeCRTInstantiationWithinBudget : Prop
  pirlcTwoTapeUnitPivotOnlyAfterSemanticProof : Prop
  terminalCEPinned226WithSharedCoreSlack : Prop

def ProductFixedKindCTCORepeatedTapePlanAccepted
    (plan : ProductFixedKindCTCORepeatedTapePlan) : Prop :=
  plan.selectedDepth = 1
    ∧ plan.expectedKindBoundByHBind
    ∧ plan.fixedContextChargesOnlyExpectedKindFiniteTerms
    ∧ plan.dispatcherCorollaryRangesOverAcceptedKinds
    ∧ plan.oneExternalSeedPerAcceptedProofKindPreserved
    ∧ plan.repeatedInternalTapesExpandedByDomainSeparatedHChal
    ∧ plan.pirlcOneShotLowerBoundPinned
    ∧ plan.piccsOneShotLowerBoundPinned
    ∧ plan.genericRepeatedTapeAmplificationProved
    ∧ plan.piccsTwoTapeInstantiationWithinBudget
    ∧ plan.pirlcThreeTapeCRTInstantiationWithinBudget
    ∧ plan.pirlcTwoTapeUnitPivotOnlyAfterSemanticProof
    ∧ plan.terminalCEPinned226WithSharedCoreSlack

structure ProductDepthOneDispatcherCorollary where
  selectedDepth : Nat
  acceptedProofKindsAreExactlyPublicFive : Prop
  proofKindBinderSelectsFixedExpectedKindContext : Prop
  everyAcceptedKindHasFixedKindPlan :
    ProductDepthOneExpectedProofKind → Prop
  dispatcherChargesOnlySelectedKindPerRun : Prop

def ProductDepthOneDispatcherCorollaryAccepted
    (corollary : ProductDepthOneDispatcherCorollary) : Prop :=
  corollary.selectedDepth = 1
    ∧ corollary.acceptedProofKindsAreExactlyPublicFive
    ∧ corollary.proofKindBinderSelectsFixedExpectedKindContext
    ∧ (∀ kind, corollary.everyAcceptedKindHasFixedKindPlan kind)
    ∧ corollary.dispatcherChargesOnlySelectedKindPerRun

structure ProductExtractorLossAccounting where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  acceptedLayerBounded : Prop
  sourceFoldExtractorSpecified : Prop
  terminalSealExtractorSpecified : Prop
  productEnvelopeExtractorSpecified : Prop
  recursiveCarryExtractorSpecified : Prop
  rewindScheduleBoundToTranscript : Prop
  extractorFailureLossAccounted : Prop
  extractorLossWithinBudget : Prop

def ProductExtractorLossAccountingAccepted
    (accounting : ProductExtractorLossAccounting) : Prop :=
  (0 < accounting.selectedDepth)
    ∧ accounting.acceptedLayerBounded
    ∧ accounting.sourceFoldExtractorSpecified
    ∧ accounting.terminalSealExtractorSpecified
    ∧ accounting.productEnvelopeExtractorSpecified
    ∧ accounting.recursiveCarryExtractorSpecified
    ∧ accounting.rewindScheduleBoundToTranscript
    ∧ accounting.extractorFailureLossAccounted
    ∧ accounting.extractorLossWithinBudget

structure ProductHashOracleInstantiation where
  challengeOracleBits : Nat
  bindingOracleBits : Nat
  bindingTargetEventCount : Nat
  splitOraclesPinned : Prop
  theoremCriticalBindingsUseHBind : Prop
  framedEncodingInjective : Prop
  proofKindBytesInjective : Prop
  challengeDomainsSeparated : Prop
  bindingDomainsSeparated : Prop
  bindingTargetEventCountPinned : Prop
  concreteHashRecommendationPinned : Prop
  hashQROInstantiationAssumptionPinned : Prop
  hashQROInstantiationProofProvided : Prop

def ProductHashOracleInstantiationAccepted
    (hashes : ProductHashOracleInstantiation) : Prop :=
  hashes.challengeOracleBits = 256
    ∧ hashes.bindingOracleBits = 384
    ∧ hashes.bindingTargetEventCount = 9
    ∧ hashes.splitOraclesPinned
    ∧ hashes.theoremCriticalBindingsUseHBind
    ∧ hashes.framedEncodingInjective
    ∧ hashes.proofKindBytesInjective
    ∧ hashes.challengeDomainsSeparated
    ∧ hashes.bindingDomainsSeparated
    ∧ hashes.bindingTargetEventCountPinned
    ∧ hashes.concreteHashRecommendationPinned
    ∧ hashes.hashQROInstantiationAssumptionPinned

structure ProductInteractiveProtocolDefinitions where
  selectedDepth : Nat
  acceptedProofKindsPinned : Prop
  allKindsThreeMovePublicCoin : Prop
  oneChallengeSeedPerKind : Prop
  moveOneRootCommitmentSpecified : Prop
  challengeTapeExpansionSpecified : Prop
  verifierChecksRootOpenings : Prop
  compressedTerminalCanonicalDecompression : Prop
  typedCarryBinderSpecified : Prop
  productionProtocolImplementationComplete : Prop

def ProductInteractiveProtocolDefinitionsAccepted
    (protocols : ProductInteractiveProtocolDefinitions) : Prop :=
  (0 < protocols.selectedDepth)
    ∧ protocols.acceptedProofKindsPinned
    ∧ protocols.allKindsThreeMovePublicCoin
    ∧ protocols.oneChallengeSeedPerKind
    ∧ protocols.moveOneRootCommitmentSpecified
    ∧ protocols.challengeTapeExpansionSpecified
    ∧ protocols.verifierChecksRootOpenings
    ∧ protocols.compressedTerminalCanonicalDecompression
    ∧ protocols.typedCarryBinderSpecified
    ∧ protocols.productionProtocolImplementationComplete

structure ProductInteractiveSpecialSoundnessData where
  foldExtractorTargetSpecified : Prop
  terminalExtractorTargetSpecified : Prop
  compressedTerminalExtractorTargetSpecified : Prop
  numiSealTerminalExtractorTargetSpecified : Prop
  numiSealZKProductExtractorTargetSpecified : Prop
  quantumDishonestProverBoundInstantiated : Prop

def ProductInteractiveSpecialSoundnessDataAccepted
    (data : ProductInteractiveSpecialSoundnessData) : Prop :=
  data.foldExtractorTargetSpecified
    ∧ data.terminalExtractorTargetSpecified
    ∧ data.compressedTerminalExtractorTargetSpecified
    ∧ data.numiSealTerminalExtractorTargetSpecified
    ∧ data.numiSealZKProductExtractorTargetSpecified
    ∧ data.quantumDishonestProverBoundInstantiated

structure ProductInteractiveDelayedMessageData where
  artifactBindingDelayedMessageSound : Prop
  provenanceBindingDelayedMessageSound : Prop
  replayBindingDelayedMessageSound : Prop
  componentRootDelayedMessageSound : Prop
  randomnessSessionDelayedMessageSound : Prop
  leakageDelayedMessageSound : Prop
  carryDelayedMessageSound : Prop

def ProductInteractiveDelayedMessageDataAccepted
    (data : ProductInteractiveDelayedMessageData) : Prop :=
  data.artifactBindingDelayedMessageSound
    ∧ data.provenanceBindingDelayedMessageSound
    ∧ data.replayBindingDelayedMessageSound
    ∧ data.componentRootDelayedMessageSound
    ∧ data.randomnessSessionDelayedMessageSound
    ∧ data.leakageDelayedMessageSound
    ∧ data.carryDelayedMessageSound

structure ProductInteractiveUniqueResponseData where
  foldUniqueResponseSpecified : Prop
  terminalUniqueResponseSpecified : Prop
  compressedTerminalUniqueResponseSpecified : Prop
  numiSealTerminalUniqueResponseSpecified : Prop
  numiSealZKProductUniqueResponseSpecified : Prop

def ProductInteractiveUniqueResponseDataAccepted
    (data : ProductInteractiveUniqueResponseData) : Prop :=
  data.foldUniqueResponseSpecified
    ∧ data.terminalUniqueResponseSpecified
    ∧ data.compressedTerminalUniqueResponseSpecified
    ∧ data.numiSealTerminalUniqueResponseSpecified
    ∧ data.numiSealZKProductUniqueResponseSpecified

structure ProductChallengeTapeCommitOpenCompiler where
  compilerFamily : ProductCompilerFamily
  challengeSeedBits : Nat
  bindingDigestBits : Nat
  merkleNodeDigestBits : Nat
  compilerFamilyPinned : Prop
  firstMessageBindsAllChallengeIndependentMaterial : Prop
  singleSeedChallengeTapePinned : Prop
  lateMessageBindingPinned : Prop
  tightQROMTransformBounded : Prop
  legacyDFM20InterfaceDeprecated : Prop

def ProductChallengeTapeCommitOpenCompilerAccepted
    (compiler : ProductChallengeTapeCommitOpenCompiler) : Prop :=
  (compiler.compilerFamily = ProductQROMTransformFamily.ctco
      ∨ compiler.compilerFamily = ProductQROMTransformFamily.merkleStraightline)
    ∧ compiler.challengeSeedBits = 256
    ∧ compiler.bindingDigestBits = 384
    ∧ compiler.merkleNodeDigestBits = 384
    ∧ compiler.compilerFamilyPinned
    ∧ compiler.firstMessageBindsAllChallengeIndependentMaterial
    ∧ compiler.singleSeedChallengeTapePinned
    ∧ compiler.lateMessageBindingPinned
    ∧ compiler.tightQROMTransformBounded
    ∧ compiler.legacyDFM20InterfaceDeprecated

structure ProductChallengeTapeExpansion where
  challengeSeedBits : Nat
  challengeOraclePinned : Prop
  proofKindLabelSeparated : Prop
  deterministicExpansionPinned : Prop
  fieldSamplerPinned : Prop
  extensionFieldSamplerPinned : Prop
  ringSamplerPinned : Prop

def ProductChallengeTapeExpansionAccepted
    (expansion : ProductChallengeTapeExpansion) : Prop :=
  expansion.challengeSeedBits = 256
    ∧ expansion.challengeOraclePinned
    ∧ expansion.proofKindLabelSeparated
    ∧ expansion.deterministicExpansionPinned
    ∧ expansion.fieldSamplerPinned
    ∧ expansion.extensionFieldSamplerPinned
    ∧ expansion.ringSamplerPinned

structure ProductQROMCollisionBound where
  queryBoundQHLog2 : Nat
  bindingDigestBits : Nat
  bindingTargetEventCount : Nat
  collisionFormulaPinned : Prop
  collisionBoundInstantiated : Prop
  collisionBoundWithinBudget : Prop

def ProductQROMCollisionBoundAccepted
    (bound : ProductQROMCollisionBound) : Prop :=
  bound.queryBoundQHLog2 = 64
    ∧ bound.bindingDigestBits = 384
    ∧ bound.bindingTargetEventCount = 9
    ∧ bound.collisionFormulaPinned
    ∧ bound.collisionBoundInstantiated
    ∧ bound.collisionBoundWithinBudget

structure ProductQROMMalleabilityBound where
  proofKindMalleabilityChargedToCollisionLedger : Prop
  proofKindMalleabilityFormulaZero : Prop
  crossKindSwapsRequireBindingTargetEvent : Prop
  crossDomainSwapsRequireBindingTargetEvent : Prop
  crossSessionSwapsRequireBindingTargetEvent : Prop
  crossCarrySwapsRequireBindingTargetEvent : Prop

def ProductQROMMalleabilityBoundAccepted
    (bound : ProductQROMMalleabilityBound) : Prop :=
  bound.proofKindMalleabilityChargedToCollisionLedger
    ∧ bound.proofKindMalleabilityFormulaZero
    ∧ bound.crossKindSwapsRequireBindingTargetEvent
    ∧ bound.crossDomainSwapsRequireBindingTargetEvent
    ∧ bound.crossSessionSwapsRequireBindingTargetEvent
    ∧ bound.crossCarrySwapsRequireBindingTargetEvent

structure ProductInteractiveSecurityBounds where
  interactiveLossChargedOutsideQROM : Prop
  sharedBadEventTagsPinned : Prop
  moduleSISSharedEventDeduplicated : Prop
  foldInteractiveBoundInstantiated : Prop
  terminalInteractiveBoundInstantiated : Prop
  compressedTerminalInteractiveBoundInstantiated : Prop
  numiSealTerminalInteractiveBoundInstantiated : Prop
  numiSealZKProductInteractiveBoundInstantiated : Prop

def ProductInteractiveSecurityBoundsAccepted
    (bounds : ProductInteractiveSecurityBounds) : Prop :=
  bounds.interactiveLossChargedOutsideQROM
    ∧ bounds.sharedBadEventTagsPinned
    ∧ bounds.moduleSISSharedEventDeduplicated
    ∧ bounds.foldInteractiveBoundInstantiated
    ∧ bounds.terminalInteractiveBoundInstantiated
    ∧ bounds.compressedTerminalInteractiveBoundInstantiated
    ∧ bounds.numiSealTerminalInteractiveBoundInstantiated
    ∧ bounds.numiSealZKProductInteractiveBoundInstantiated

structure ProductPerKindInteractiveSecurityEvidence where
  interactiveLossChargedOutsideQROM : Prop
  sharedBadEventTagsPinned : Prop
  moduleSISSharedEventDeduplicated : Prop
  foldFiniteProtocolBound : Prop
  terminalFiniteProtocolBound : Prop
  compressedTerminalCanonicalReduction : Prop
  numiSealTerminalSourceAndTerminalComposition : Prop
  numiSealZKProductSoundnessComposition : Prop

def ProductInteractiveSecurityBounds.ofPerKindEvidence
    (evidence : ProductPerKindInteractiveSecurityEvidence) :
    ProductInteractiveSecurityBounds where
  interactiveLossChargedOutsideQROM :=
    evidence.interactiveLossChargedOutsideQROM
  sharedBadEventTagsPinned := evidence.sharedBadEventTagsPinned
  moduleSISSharedEventDeduplicated := evidence.moduleSISSharedEventDeduplicated
  foldInteractiveBoundInstantiated := evidence.foldFiniteProtocolBound
  terminalInteractiveBoundInstantiated := evidence.terminalFiniteProtocolBound
  compressedTerminalInteractiveBoundInstantiated :=
    evidence.compressedTerminalCanonicalReduction
  numiSealTerminalInteractiveBoundInstantiated :=
    evidence.numiSealTerminalSourceAndTerminalComposition
  numiSealZKProductInteractiveBoundInstantiated :=
    evidence.numiSealZKProductSoundnessComposition

theorem productInteractiveSecurityBounds_from_perKindEvidence
    {evidence : ProductPerKindInteractiveSecurityEvidence}
    (hEvidence :
      evidence.interactiveLossChargedOutsideQROM
        ∧ evidence.sharedBadEventTagsPinned
        ∧ evidence.moduleSISSharedEventDeduplicated
        ∧ evidence.foldFiniteProtocolBound
        ∧ evidence.terminalFiniteProtocolBound
        ∧ evidence.compressedTerminalCanonicalReduction
        ∧ evidence.numiSealTerminalSourceAndTerminalComposition
        ∧ evidence.numiSealZKProductSoundnessComposition) :
    ProductInteractiveSecurityBoundsAccepted
      (ProductInteractiveSecurityBounds.ofPerKindEvidence evidence) := by
  exact hEvidence

structure ProductQROMTotalLossInstantiated where
  hashModelGapZeroInIdealSplitQRO : Prop
  compilerOverheadWithinBudget : Prop
  qromExtraLossOnly : Prop
  collisionLedgerIntegrated : Prop
  cryptographicSliceWithinBudget : Prop
  repoWideNonMathTermsClosed : Prop

def ProductQROMTotalLossInstantiatedAccepted
    (loss : ProductQROMTotalLossInstantiated) : Prop :=
  loss.hashModelGapZeroInIdealSplitQRO
    ∧ loss.compilerOverheadWithinBudget
    ∧ loss.qromExtraLossOnly
    ∧ loss.collisionLedgerIntegrated
    ∧ loss.cryptographicSliceWithinBudget
    ∧ loss.repoWideNonMathTermsClosed

structure ProductQROMCompilerOverheadBound where
  selectedFamily : ProductCompilerFamily
  selectedDepth : Nat
  idealSplitQROModelPinned : Prop
  onlineExtractabilityAssumptionPinned : Prop
  compilerAddsNoLegacyRoundFactor : Prop
  compilerOverheadExactZeroInIdealModel : Prop
  hashModelGapSeparated : Prop
  totalLossLedgerReceivesQROMTerm : Prop

def ProductQROMCompilerOverheadBoundAccepted
    (bound : ProductQROMCompilerOverheadBound) : Prop :=
  (bound.selectedFamily = ProductQROMTransformFamily.ctco
      ∨ bound.selectedFamily = ProductQROMTransformFamily.merkleStraightline)
    ∧ 0 < bound.selectedDepth
    ∧ bound.idealSplitQROModelPinned
    ∧ bound.onlineExtractabilityAssumptionPinned
    ∧ bound.compilerAddsNoLegacyRoundFactor
    ∧ bound.compilerOverheadExactZeroInIdealModel
    ∧ bound.hashModelGapSeparated
    ∧ bound.totalLossLedgerReceivesQROMTerm

structure ProductSharedBadEventDeduplication where
  moduleSISSharedTagPinned : Prop
  commitmentSharedTagPinned : Prop
  sourceFoldUsesResidualNonCoreTerm : Prop
  terminalUsesResidualNonCoreTerm : Prop
  extractorUsesResidualNonCoreTerm : Prop
  qromCollisionSeparatedFromCore : Prop
  selectedDepthLedgerUsesSharedCoreTerm : Prop
  totalLossBudgetChargesSharedCoreOnce : Prop
  formalAggregateUnionBoundPinned : Prop

def ProductSharedBadEventDeduplicationAccepted
    (dedup : ProductSharedBadEventDeduplication) : Prop :=
  dedup.moduleSISSharedTagPinned
    ∧ dedup.commitmentSharedTagPinned
    ∧ dedup.sourceFoldUsesResidualNonCoreTerm
    ∧ dedup.terminalUsesResidualNonCoreTerm
    ∧ dedup.extractorUsesResidualNonCoreTerm
    ∧ dedup.qromCollisionSeparatedFromCore
    ∧ dedup.selectedDepthLedgerUsesSharedCoreTerm
    ∧ dedup.totalLossBudgetChargesSharedCoreOnce
    ∧ dedup.formalAggregateUnionBoundPinned

structure ProductExactFiniteProbabilityWiring where
  selectedDepth : Nat
  dyadicRationalArithmeticPinned : Prop
  nonDyadicFiniteProtocolRationalsPinned : Prop
  zeroLossTermsRepresentedExactly : Prop
  instantiatedTermPartialSumComputed : Prop
  missingRequiredTermsKeepTotalUninstantiated : Prop
  qromTermSeparatedFromCollisionLedger : Prop
  sourceFoldRepeatedTapeExpressionExact : Prop
  terminalCE226ExpressionExact : Prop
  hbindCollisionExpressionExact : Prop
  selectedDepthBudgetComparisonUsesExactRationals : Prop

def ProductExactFiniteProbabilityWiringAccepted
    (wiring : ProductExactFiniteProbabilityWiring) : Prop :=
  0 < wiring.selectedDepth
    ∧ wiring.dyadicRationalArithmeticPinned
    ∧ wiring.nonDyadicFiniteProtocolRationalsPinned
    ∧ wiring.zeroLossTermsRepresentedExactly
    ∧ wiring.instantiatedTermPartialSumComputed
    ∧ wiring.missingRequiredTermsKeepTotalUninstantiated
    ∧ wiring.qromTermSeparatedFromCollisionLedger
    ∧ wiring.sourceFoldRepeatedTapeExpressionExact
    ∧ wiring.terminalCE226ExpressionExact
    ∧ wiring.hbindCollisionExpressionExact
    ∧ wiring.selectedDepthBudgetComparisonUsesExactRationals

structure ProductInstantiatedQROMEvidence where
  hashInstantiation : ProductHashOracleInstantiation
  protocolDefinitions : ProductInteractiveProtocolDefinitions
  specialSoundnessData : ProductInteractiveSpecialSoundnessData
  delayedMessageData : ProductInteractiveDelayedMessageData
  uniqueResponseData : ProductInteractiveUniqueResponseData
  compiler : ProductChallengeTapeCommitOpenCompiler
  collisionBound : ProductQROMCollisionBound
  malleabilityBound : ProductQROMMalleabilityBound
  interactiveBounds : ProductInteractiveSecurityBounds
  compilerOverheadBound : ProductQROMCompilerOverheadBound
  exactFiniteProbabilityWiring : ProductExactFiniteProbabilityWiring
  totalLoss : ProductQROMTotalLossInstantiated

def ProductInstantiatedQROMEvidenceAccepted
    (evidence : ProductInstantiatedQROMEvidence) : Prop :=
  ProductHashOracleInstantiationAccepted evidence.hashInstantiation
    ∧ ProductInteractiveProtocolDefinitionsAccepted evidence.protocolDefinitions
    ∧ ProductInteractiveSpecialSoundnessDataAccepted evidence.specialSoundnessData
    ∧ ProductInteractiveDelayedMessageDataAccepted evidence.delayedMessageData
    ∧ ProductInteractiveUniqueResponseDataAccepted evidence.uniqueResponseData
    ∧ ProductChallengeTapeCommitOpenCompilerAccepted evidence.compiler
    ∧ ProductQROMCollisionBoundAccepted evidence.collisionBound
    ∧ ProductQROMMalleabilityBoundAccepted evidence.malleabilityBound
    ∧ ProductInteractiveSecurityBoundsAccepted evidence.interactiveBounds
    ∧ ProductQROMCompilerOverheadBoundAccepted evidence.compilerOverheadBound
    ∧ ProductExactFiniteProbabilityWiringAccepted evidence.exactFiniteProbabilityWiring
    ∧ ProductQROMTotalLossInstantiatedAccepted evidence.totalLoss

structure ProductFiatShamirTranscriptSchedule where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  acceptedProofKindsPinned : Prop
  interactiveRoundSchedulePinned : Prop
  publicCoinChallengeLabelsPinned : Prop
  oracleQueryFamiliesPinned : Prop
  transcriptStateTransitionsPinned : Prop
  witnessIndependentOracleLabelsPinned : Prop
  domainSeparationBindingPinned : Prop
  proofKindSeparationBindingPinned : Prop
  numericQuantumQueryBoundsInstantiated : Prop
  productionTranscriptScheduleClaimAllowed : Prop

def ProductFiatShamirTranscriptScheduleAccepted
    (schedule : ProductFiatShamirTranscriptSchedule) : Prop :=
  (0 < schedule.selectedDepth)
    ∧ schedule.acceptedProofKindsPinned
    ∧ schedule.interactiveRoundSchedulePinned
    ∧ schedule.publicCoinChallengeLabelsPinned
    ∧ schedule.oracleQueryFamiliesPinned
    ∧ schedule.transcriptStateTransitionsPinned
    ∧ schedule.witnessIndependentOracleLabelsPinned
    ∧ schedule.domainSeparationBindingPinned
    ∧ schedule.proofKindSeparationBindingPinned
    ∧ schedule.numericQuantumQueryBoundsInstantiated
    ∧ schedule.productionTranscriptScheduleClaimAllowed

structure ProductFiatShamirTransformPreconditions where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  theoremFamilyPinned : Prop
  publicCoinInteractiveProtocolSpecified : Prop
  constantRoundOddMessageScheduleSpecified : Prop
  challengeSpaceAndUniformityPinned : Prop
  transcriptOracleEncodingInjective : Prop
  transcriptScheduleAccepted : Prop
  underlyingInteractiveSecurityBoundInstantiated : Prop
  quantumOracleQueryBoundInstantiated : Prop
  qromReductionLossInstantiated : Prop
  productionTransformClaimAllowed : Prop

def ProductFiatShamirTransformPreconditionsAccepted
    (preconditions : ProductFiatShamirTransformPreconditions) : Prop :=
  (0 < preconditions.selectedDepth)
    ∧ preconditions.theoremFamilyPinned
    ∧ preconditions.publicCoinInteractiveProtocolSpecified
    ∧ preconditions.constantRoundOddMessageScheduleSpecified
    ∧ preconditions.challengeSpaceAndUniformityPinned
    ∧ preconditions.transcriptOracleEncodingInjective
    ∧ preconditions.transcriptScheduleAccepted
    ∧ preconditions.underlyingInteractiveSecurityBoundInstantiated
    ∧ preconditions.quantumOracleQueryBoundInstantiated
    ∧ preconditions.qromReductionLossInstantiated
    ∧ preconditions.productionTransformClaimAllowed

structure ProductQROMInteractiveReduction where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  acceptedProofKindOrderPinned : Prop
  protocolMessageAlgorithmsPinned : Prop
  exactMoveCountsPinned : Prop
  challengeCountFormulasPinned : Prop
  transcriptOracleEncodingProofPinned : Prop
  challengeUniformityProofPinned : Prop
  quantumQueryPolicyBoundPinned : Prop
  dfm20LossFormulaPinned : Prop
  numericSelectedLossInstantiated : Prop
  underlyingInteractiveSecurityInstantiated : Prop
  totalLossBudgetInterfacePinned : Prop
  productionQROMTheoremClaimAllowed : Prop

def ProductQROMInteractiveReductionAccepted
    (reduction : ProductQROMInteractiveReduction) : Prop :=
  (0 < reduction.selectedDepth)
    ∧ reduction.acceptedProofKindOrderPinned
    ∧ reduction.protocolMessageAlgorithmsPinned
    ∧ reduction.exactMoveCountsPinned
    ∧ reduction.challengeCountFormulasPinned
    ∧ reduction.transcriptOracleEncodingProofPinned
    ∧ reduction.challengeUniformityProofPinned
    ∧ reduction.quantumQueryPolicyBoundPinned
    ∧ reduction.dfm20LossFormulaPinned
    ∧ reduction.numericSelectedLossInstantiated
    ∧ reduction.underlyingInteractiveSecurityInstantiated
    ∧ reduction.totalLossBudgetInterfacePinned
    ∧ reduction.productionQROMTheoremClaimAllowed

structure ProductFiatShamirLossAccounting where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  interactiveProtocolSpecified : Prop
  publicCoinChallengeScheduleSpecified : Prop
  qromTransformPreconditionsSatisfied : Prop
  quantumOracleQueryBoundAccounted : Prop
  transcriptDomainSeparatorsBound : Prop
  proofKindSeparationBound : Prop
  transcriptCollisionMalleabilityExcluded : Prop
  qromLossWithinBudget : Prop

def ProductFiatShamirLossAccountingAccepted
    (accounting : ProductFiatShamirLossAccounting) : Prop :=
  (0 < accounting.selectedDepth)
    ∧ accounting.interactiveProtocolSpecified
    ∧ accounting.publicCoinChallengeScheduleSpecified
    ∧ accounting.qromTransformPreconditionsSatisfied
    ∧ accounting.quantumOracleQueryBoundAccounted
    ∧ accounting.transcriptDomainSeparatorsBound
    ∧ accounting.proofKindSeparationBound
    ∧ accounting.transcriptCollisionMalleabilityExcluded
    ∧ accounting.qromLossWithinBudget

structure ProductTotalLossBudget where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  exactArithmeticPinned : Prop
  qromLedgerTermMappingPinned : Prop
  extractorLedgerTermMappingPinned : Prop
  allRequiredTermsInstantiated : Prop
  missingRequiredTermSetEmpty : Prop
  selectedDepthLossWithinBudget : Prop
  productionTotalLossClaimAllowed : Prop

def ProductTotalLossBudgetAccepted
    (budget : ProductTotalLossBudget) : Prop :=
  (0 < budget.selectedDepth)
    ∧ budget.exactArithmeticPinned
    ∧ budget.qromLedgerTermMappingPinned
    ∧ budget.extractorLedgerTermMappingPinned
    ∧ budget.allRequiredTermsInstantiated
    ∧ budget.missingRequiredTermSetEmpty
    ∧ budget.selectedDepthLossWithinBudget
    ∧ budget.productionTotalLossClaimAllowed

structure ProductReleaseDistributionEvidence where
  releaseSigningKeyPinned : Prop
  signedArtifactsProduced : Prop
  signedProvenanceFormatPinned : Prop
  notarizationOrPublicationProofPinned : Prop
  hostedBranchProtectionEvidencePinned : Prop
  archivedReleaseEvidencePinned : Prop
  releaseDistributionLossWithinBudget : Prop

def ProductReleaseDistributionEvidenceAccepted
    (evidence : ProductReleaseDistributionEvidence) : Prop :=
  evidence.releaseSigningKeyPinned
    ∧ evidence.signedArtifactsProduced
    ∧ evidence.signedProvenanceFormatPinned
    ∧ evidence.notarizationOrPublicationProofPinned
    ∧ evidence.hostedBranchProtectionEvidencePinned
    ∧ evidence.archivedReleaseEvidencePinned
    ∧ evidence.releaseDistributionLossWithinBudget

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

structure ProductSecurityTheoremObligationStatus where
  numiSealProduct : NumiSealProductTheoremObligationStatus
  systemBindings : TheoremObligationStatus
  boundedDepthLoss : TheoremObligationStatus
  selectedDepthLossLedger : TheoremObligationStatus
  extractorLossAccounting : TheoremObligationStatus
  latticeAssumptionDossier : TheoremObligationStatus
  fiatShamirQROM : TheoremObligationStatus
  totalLossBudget : TheoremObligationStatus
  releaseDistribution : TheoremObligationStatus
  completeness : TheoremObligationStatus
  knowledgeSoundness : TheoremObligationStatus
  zeroKnowledge : TheoremObligationStatus
  composition : TheoremObligationStatus

def ProductSecurityTheoremObligationStatus.FullyInstantiated
    (status : ProductSecurityTheoremObligationStatus) :
    Prop :=
  status.numiSealProduct.FullyInstantiated
    ∧ status.systemBindings.Accepted
    ∧ status.boundedDepthLoss.Accepted
    ∧ status.selectedDepthLossLedger.Accepted
    ∧ status.extractorLossAccounting.Accepted
    ∧ status.latticeAssumptionDossier.Accepted
    ∧ status.fiatShamirQROM.Accepted
    ∧ status.totalLossBudget.Accepted
    ∧ status.releaseDistribution.Accepted
    ∧ status.completeness.Accepted
    ∧ status.knowledgeSoundness.Accepted
    ∧ status.zeroKnowledge.Accepted
    ∧ status.composition.Accepted

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

theorem productSecurityTheorem_requires_selected_depth_loss_accounting
    {ledger : ProductSelectedDepthLossLedger}
    (hLedger : ProductSelectedDepthLossLedgerAccepted ledger) :
    ledger.extractorLossInstantiated
      ∧ ledger.fiatShamirQROMLossInstantiated
      ∧ ledger.zkSimulatorLossInstantiated
      ∧ ledger.totalLossWithinBudget := by
  rcases hLedger with
    ⟨_,
      _,
      _,
      _,
      hZKSimulator,
      hQROM,
      hExtractor,
      _,
      _,
      _,
      hTotal⟩
  exact ⟨hExtractor, hQROM, hZKSimulator, hTotal⟩

theorem productSecurityTheorem_requires_finite_protocol_numeric_loss_instantiation
    {obstruction : ProductFiniteProtocolNumericLossObstruction}
    (hObstruction :
      ProductFiniteProtocolNumericLossObstructionAccepted obstruction) :
    obstruction.sourceFoldRepeatedTapeLossInstantiated
      ∧ obstruction.terminalSealRepeatedTapeLossInstantiated
      ∧ obstruction.selectedTotalLossRemainsUninstantiated := by
  rcases hObstruction with
    ⟨_,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      hSourceFold,
      hTerminalSeal,
      hTotal⟩
  exact ⟨hSourceFold, hTerminalSeal, hTotal⟩

theorem productSecurityTheorem_requires_fixed_kind_repeated_tape_plan
    {plan : ProductFixedKindCTCORepeatedTapePlan}
    (hPlan : ProductFixedKindCTCORepeatedTapePlanAccepted plan) :
    plan.fixedContextChargesOnlyExpectedKindFiniteTerms
      ∧ plan.genericRepeatedTapeAmplificationProved
      ∧ plan.piccsTwoTapeInstantiationWithinBudget
      ∧ plan.pirlcThreeTapeCRTInstantiationWithinBudget
      ∧ plan.terminalCEPinned226WithSharedCoreSlack := by
  rcases hPlan with
    ⟨_,
      _,
      hFixedKind,
      _,
      _,
      _,
      _,
      _,
      hRepeated,
      hPiCCS,
      hPiRLC,
      _,
      hTerminal⟩
  exact ⟨hFixedKind, hRepeated, hPiCCS, hPiRLC, hTerminal⟩

theorem productSecurityTheorem_dispatcher_reduces_to_fixed_kind
    {corollary : ProductDepthOneDispatcherCorollary}
    (hCorollary : ProductDepthOneDispatcherCorollaryAccepted corollary) :
    corollary.proofKindBinderSelectsFixedExpectedKindContext
      ∧ (∀ kind, corollary.everyAcceptedKindHasFixedKindPlan kind)
      ∧ corollary.dispatcherChargesOnlySelectedKindPerRun := by
  rcases hCorollary with
    ⟨_,
      _,
      hBinder,
      hEveryKind,
      hSelectedKind⟩
  exact ⟨hBinder, hEveryKind, hSelectedKind⟩

theorem productSecurityTheorem_requires_extractor_loss_accounting
    {accounting : ProductExtractorLossAccounting}
    (hAccounting : ProductExtractorLossAccountingAccepted accounting) :
    accounting.sourceFoldExtractorSpecified
      ∧ accounting.terminalSealExtractorSpecified
      ∧ accounting.productEnvelopeExtractorSpecified
      ∧ accounting.extractorFailureLossAccounted
      ∧ accounting.extractorLossWithinBudget := by
  rcases hAccounting with
    ⟨_,
      _,
      hSourceFold,
      hTerminalSeal,
      hProductEnvelope,
      _,
      _,
      hExtractorLoss,
      hBudget⟩
  exact ⟨hSourceFold, hTerminalSeal, hProductEnvelope, hExtractorLoss, hBudget⟩

theorem ProductQROMTightTransform
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence) :
    evidence.compiler.tightQROMTransformBounded
      ∧ evidence.hashInstantiation.splitOraclesPinned
      ∧ evidence.hashInstantiation.theoremCriticalBindingsUseHBind
      ∧ evidence.interactiveBounds.interactiveLossChargedOutsideQROM
      ∧ evidence.malleabilityBound.proofKindMalleabilityChargedToCollisionLedger
      ∧ evidence.collisionBound.collisionBoundWithinBudget := by
  rcases hEvidence with
    ⟨hHash,
      _,
      _,
      _,
      _,
      hCompiler,
      hCollision,
      hMalleability,
      hInteractive,
      _⟩
  rcases hHash with
    ⟨_,
      _,
      _,
      hSplit,
      hHBind,
      _,
      _,
      _,
      _,
      _,
      _,
      _⟩
  rcases hCompiler with
    ⟨_,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      hTight,
      _⟩
  rcases hCollision with
    ⟨_,
      _,
      _,
      _,
      _,
      hCollisionBudget⟩
  rcases hMalleability with
    ⟨hMalleabilityCharged, _, _, _, _, _⟩
  rcases hInteractive with
    ⟨hInteractiveOutside, _, _, _, _, _, _, _⟩
  exact
    ⟨hTight,
      hSplit,
      hHBind,
      hInteractiveOutside,
      hMalleabilityCharged,
      hCollisionBudget⟩

theorem productSecurityTheorem_from_instantiated_qrom
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence) :
    evidence.totalLoss.cryptographicSliceWithinBudget
      ∧ evidence.totalLoss.collisionLedgerIntegrated
      ∧ evidence.interactiveBounds.sharedBadEventTagsPinned
      ∧ evidence.compilerOverheadBound.compilerOverheadExactZeroInIdealModel
      ∧ evidence.exactFiniteProbabilityWiring.instantiatedTermPartialSumComputed := by
  rcases hEvidence with
    ⟨_,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      hInteractive,
      hCompilerOverhead,
      hWiring,
      hLoss⟩
  rcases hInteractive with
    ⟨_, hSharedTags, _, _, _, _, _, _⟩
  rcases hCompilerOverhead with
    ⟨_, _, _, _, _, hCompilerOverheadZero, _, _⟩
  rcases hWiring with
    ⟨_, _, _, _, hPartialSum, _, _, _, _, _, _⟩
  rcases hLoss with
    ⟨_,
      _,
      _,
      hCollisionIntegrated,
      hCryptographicBudget,
      _⟩
  exact
    ⟨hCryptographicBudget,
      hCollisionIntegrated,
      hSharedTags,
      hCompilerOverheadZero,
      hPartialSum⟩

theorem productSecurityTheorem_requires_qrom_loss_accounting
    {accounting : ProductFiatShamirLossAccounting}
    (hAccounting : ProductFiatShamirLossAccountingAccepted accounting) :
    accounting.interactiveProtocolSpecified
      ∧ accounting.publicCoinChallengeScheduleSpecified
      ∧ accounting.qromTransformPreconditionsSatisfied
      ∧ accounting.quantumOracleQueryBoundAccounted
      ∧ accounting.transcriptCollisionMalleabilityExcluded
      ∧ accounting.qromLossWithinBudget := by
  rcases hAccounting with
    ⟨_,
      hInteractive,
      hChallengeSchedule,
      hPreconditions,
      hQuantumQueries,
      _,
      _,
      hCollision,
      hBudget⟩
  exact
    ⟨hInteractive,
      hChallengeSchedule,
      hPreconditions,
      hQuantumQueries,
      hCollision,
      hBudget⟩

theorem productSecurityTheorem_requires_qrom_collision_malleability_exclusion
    {accounting : ProductFiatShamirLossAccounting}
    (hAccounting : ProductFiatShamirLossAccountingAccepted accounting) :
    accounting.transcriptDomainSeparatorsBound
      ∧ accounting.proofKindSeparationBound
      ∧ accounting.transcriptCollisionMalleabilityExcluded := by
  rcases hAccounting with
    ⟨_,
      _,
      _,
      _,
      _,
      hTranscriptDomain,
      hProofKind,
      hCollision,
      _⟩
  exact ⟨hTranscriptDomain, hProofKind, hCollision⟩

theorem productSecurityTheorem_requires_theorem_critical_hbind
    {hashes : ProductHashOracleInstantiation}
    (hHashes : ProductHashOracleInstantiationAccepted hashes) :
    hashes.bindingOracleBits = 384
      ∧ hashes.bindingTargetEventCount = 9
      ∧ hashes.theoremCriticalBindingsUseHBind
      ∧ hashes.bindingDomainsSeparated
      ∧ hashes.bindingTargetEventCountPinned
      ∧ hashes.hashQROInstantiationAssumptionPinned := by
  rcases hHashes with
    ⟨_,
      hBindingBits,
      hTargetCount,
      _,
      hHBind,
      _,
      _,
      _,
      hBindingDomains,
      hTargetPinned,
      _,
      hQROAssumption⟩
  exact
    ⟨hBindingBits,
      hTargetCount,
      hHBind,
      hBindingDomains,
      hTargetPinned,
      hQROAssumption⟩

theorem productSecurityTheorem_requires_challenge_tape_expansion
    {expansion : ProductChallengeTapeExpansion}
    (hExpansion : ProductChallengeTapeExpansionAccepted expansion) :
    expansion.challengeSeedBits = 256
      ∧ expansion.challengeOraclePinned
      ∧ expansion.proofKindLabelSeparated
      ∧ expansion.deterministicExpansionPinned
      ∧ expansion.fieldSamplerPinned
      ∧ expansion.extensionFieldSamplerPinned
      ∧ expansion.ringSamplerPinned := by
  exact hExpansion

theorem productSecurityTheorem_requires_qrom_transcript_schedule
    {schedule : ProductFiatShamirTranscriptSchedule}
    (hSchedule : ProductFiatShamirTranscriptScheduleAccepted schedule) :
    schedule.acceptedProofKindsPinned
      ∧ schedule.publicCoinChallengeLabelsPinned
      ∧ schedule.oracleQueryFamiliesPinned
      ∧ schedule.domainSeparationBindingPinned
      ∧ schedule.proofKindSeparationBindingPinned
      ∧ schedule.numericQuantumQueryBoundsInstantiated
      ∧ schedule.productionTranscriptScheduleClaimAllowed := by
  rcases hSchedule with
    ⟨_,
      hProofKinds,
      _,
      hChallengeLabels,
      hOracleQueries,
      _,
      _,
      hDomain,
      hProofKindSeparation,
      hNumericQueries,
      hPromotion⟩
  exact
    ⟨hProofKinds,
      hChallengeLabels,
      hOracleQueries,
      hDomain,
      hProofKindSeparation,
      hNumericQueries,
      hPromotion⟩

theorem productSecurityTheorem_requires_qrom_transform_preconditions
    {preconditions : ProductFiatShamirTransformPreconditions}
    (hPreconditions :
      ProductFiatShamirTransformPreconditionsAccepted preconditions) :
    preconditions.theoremFamilyPinned
      ∧ preconditions.publicCoinInteractiveProtocolSpecified
      ∧ preconditions.constantRoundOddMessageScheduleSpecified
      ∧ preconditions.challengeSpaceAndUniformityPinned
      ∧ preconditions.transcriptOracleEncodingInjective
      ∧ preconditions.transcriptScheduleAccepted
      ∧ preconditions.underlyingInteractiveSecurityBoundInstantiated
      ∧ preconditions.quantumOracleQueryBoundInstantiated
      ∧ preconditions.qromReductionLossInstantiated
      ∧ preconditions.productionTransformClaimAllowed := by
  rcases hPreconditions with
    ⟨_,
      hFamily,
      hInteractive,
      hRounds,
      hChallenge,
      hEncoding,
      hSchedule,
      hInteractiveSecurity,
      hQuantumQueries,
      hReductionLoss,
      hPromotion⟩
  exact
    ⟨hFamily,
      hInteractive,
      hRounds,
      hChallenge,
      hEncoding,
      hSchedule,
      hInteractiveSecurity,
      hQuantumQueries,
      hReductionLoss,
      hPromotion⟩

theorem productSecurityTheorem_requires_qrom_interactive_reduction
    {reduction : ProductQROMInteractiveReduction}
    (hReduction : ProductQROMInteractiveReductionAccepted reduction) :
    reduction.acceptedProofKindOrderPinned
      ∧ reduction.protocolMessageAlgorithmsPinned
      ∧ reduction.exactMoveCountsPinned
      ∧ reduction.challengeCountFormulasPinned
      ∧ reduction.transcriptOracleEncodingProofPinned
      ∧ reduction.challengeUniformityProofPinned
      ∧ reduction.quantumQueryPolicyBoundPinned
      ∧ reduction.dfm20LossFormulaPinned
      ∧ reduction.numericSelectedLossInstantiated
      ∧ reduction.underlyingInteractiveSecurityInstantiated
      ∧ reduction.totalLossBudgetInterfacePinned
      ∧ reduction.productionQROMTheoremClaimAllowed := by
  rcases hReduction with
    ⟨_,
      hOrder,
      hProtocols,
      hMoves,
      hChallenges,
      hEncoding,
      hUniformity,
      hQueries,
      hFormula,
      hNumericLoss,
      hInteractiveSecurity,
      hBudget,
      hPromotion⟩
  exact
    ⟨hOrder,
      hProtocols,
      hMoves,
      hChallenges,
      hEncoding,
      hUniformity,
      hQueries,
      hFormula,
      hNumericLoss,
      hInteractiveSecurity,
      hBudget,
      hPromotion⟩

theorem productSecurityTheorem_requires_qrom_compiler_overhead_bound
    {bound : ProductQROMCompilerOverheadBound}
    (hBound : ProductQROMCompilerOverheadBoundAccepted bound) :
    (bound.selectedFamily = ProductQROMTransformFamily.ctco
        ∨ bound.selectedFamily = ProductQROMTransformFamily.merkleStraightline)
      ∧ 0 < bound.selectedDepth
      ∧ bound.idealSplitQROModelPinned
      ∧ bound.onlineExtractabilityAssumptionPinned
      ∧ bound.compilerAddsNoLegacyRoundFactor
      ∧ bound.compilerOverheadExactZeroInIdealModel
      ∧ bound.hashModelGapSeparated
      ∧ bound.totalLossLedgerReceivesQROMTerm := by
  exact hBound

theorem productSecurityTheorem_requires_shared_bad_event_deduplication
    {dedup : ProductSharedBadEventDeduplication}
    (hDedup : ProductSharedBadEventDeduplicationAccepted dedup) :
    dedup.moduleSISSharedTagPinned
      ∧ dedup.commitmentSharedTagPinned
      ∧ dedup.sourceFoldUsesResidualNonCoreTerm
      ∧ dedup.terminalUsesResidualNonCoreTerm
      ∧ dedup.extractorUsesResidualNonCoreTerm
      ∧ dedup.qromCollisionSeparatedFromCore
      ∧ dedup.selectedDepthLedgerUsesSharedCoreTerm
      ∧ dedup.totalLossBudgetChargesSharedCoreOnce
      ∧ dedup.formalAggregateUnionBoundPinned := by
  exact hDedup

theorem productSecurityTheorem_requires_total_loss_budget
    {budget : ProductTotalLossBudget}
    (hBudget : ProductTotalLossBudgetAccepted budget) :
    budget.exactArithmeticPinned
      ∧ budget.qromLedgerTermMappingPinned
      ∧ budget.extractorLedgerTermMappingPinned
      ∧ budget.allRequiredTermsInstantiated
      ∧ budget.missingRequiredTermSetEmpty
      ∧ budget.selectedDepthLossWithinBudget
      ∧ budget.productionTotalLossClaimAllowed := by
  rcases hBudget with
    ⟨_,
      hArithmetic,
      hQROM,
      hExtractor,
      hAll,
      hMissing,
      hWithin,
      hPromotion⟩
  exact ⟨hArithmetic, hQROM, hExtractor, hAll, hMissing, hWithin, hPromotion⟩

theorem productSecurityTheorem_requires_exact_finite_probability_wiring
    {wiring : ProductExactFiniteProbabilityWiring}
    (hWiring : ProductExactFiniteProbabilityWiringAccepted wiring) :
    0 < wiring.selectedDepth
      ∧ wiring.dyadicRationalArithmeticPinned
      ∧ wiring.nonDyadicFiniteProtocolRationalsPinned
      ∧ wiring.zeroLossTermsRepresentedExactly
      ∧ wiring.instantiatedTermPartialSumComputed
      ∧ wiring.missingRequiredTermsKeepTotalUninstantiated
      ∧ wiring.qromTermSeparatedFromCollisionLedger
      ∧ wiring.sourceFoldRepeatedTapeExpressionExact
      ∧ wiring.terminalCE226ExpressionExact
      ∧ wiring.hbindCollisionExpressionExact
      ∧ wiring.selectedDepthBudgetComparisonUsesExactRationals := by
  exact hWiring

theorem productSecurityTheorem_requires_release_distribution_evidence
    {evidence : ProductReleaseDistributionEvidence}
    (hEvidence : ProductReleaseDistributionEvidenceAccepted evidence) :
    evidence.releaseSigningKeyPinned
      ∧ evidence.signedArtifactsProduced
      ∧ evidence.signedProvenanceFormatPinned
      ∧ evidence.notarizationOrPublicationProofPinned
      ∧ evidence.hostedBranchProtectionEvidencePinned
      ∧ evidence.archivedReleaseEvidencePinned
      ∧ evidence.releaseDistributionLossWithinBudget := by
  exact hEvidence

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
