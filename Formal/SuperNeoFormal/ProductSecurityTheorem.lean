import SuperNeoFormal.NumiSealProductTheorem
import SuperNeoFormal.ProductBadEventLedger
import SuperNeoFormal.CTCORepeatedTapeSoundness
import SuperNeoFormal.PiCCSFiniteSoundness
import SuperNeoFormal.CertifiedAjtai
import SuperNeoFormal.WellFormedTranscript

/-!
Product cryptographic security theorem surface.

This module is the checked boundary for the paper-grade theorem program.  It
does not manufacture missing extractor, QROM, lattice-loss, or side-channel
evidence.  Instead it states the actual product theorem shape: accepted product
relations plus pinned transcript/artifact bindings, a bounded-depth loss
accounting record, a lattice-assumption dossier, and public-coin QRO/QROM
evidence.  The top theorem returns the deterministic reduction conclusion
derived from those components; it does not prove caller-chosen security claims.
-/

namespace SuperNeoFormal

inductive ProductPublicCoinModel where
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
  publicCoinModel : ProductPublicCoinModel

structure ProductSystemBindings where
  sourceFoldRelationBound : Prop
  terminalRelationBound : Prop
  zkMaskedResidualRelationBound : Prop
  typedRecursiveCarryRelationBound : Prop
  recursiveCarryChainRootRecurrenceBound : Prop
  transcriptDomainsBound : Prop
  artifactMetadataBound : Prop
  proofEnvelopeHeadersBound : Prop
  verifierPolicyBound : Prop

def ProductSystemBindingsAccepted (bindings : ProductSystemBindings) : Prop :=
  bindings.sourceFoldRelationBound
    ∧ bindings.terminalRelationBound
    ∧ bindings.zkMaskedResidualRelationBound
    ∧ bindings.typedRecursiveCarryRelationBound
    ∧ bindings.recursiveCarryChainRootRecurrenceBound
    ∧ bindings.transcriptDomainsBound
    ∧ bindings.artifactMetadataBound
    ∧ bindings.proofEnvelopeHeadersBound
    ∧ bindings.verifierPolicyBound

structure ProductSystemBindingClosure where
  recursiveCarryChainRootRecurrenceBound : Prop
  transcriptDomainsBound : Prop
  artifactMetadataBound : Prop
  proofEnvelopeHeadersBound : Prop

def ProductSystemBindingClosureAccepted
    (closure : ProductSystemBindingClosure) : Prop :=
  closure.recursiveCarryChainRootRecurrenceBound
    ∧ closure.transcriptDomainsBound
    ∧ closure.artifactMetadataBound
    ∧ closure.proofEnvelopeHeadersBound

def ProductSystemBindings.ofProductRelations
    {depth : Nat}
    {View Leakage : Type}
    (relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage)
    (closure : ProductSystemBindingClosure) :
    ProductSystemBindings where
  sourceFoldRelationBound :=
    relations.endToEndRelation.sourceFoldRelation
  terminalRelationBound :=
    relations.endToEndRelation.terminalSealRelation
  zkMaskedResidualRelationBound :=
    relations.endToEndRelation.zkMaskedResidualRelation
  typedRecursiveCarryRelationBound :=
    relations.endToEndRelation.typedCarryRelation
  recursiveCarryChainRootRecurrenceBound :=
    closure.recursiveCarryChainRootRecurrenceBound
  transcriptDomainsBound := closure.transcriptDomainsBound
  artifactMetadataBound := closure.artifactMetadataBound
  proofEnvelopeHeadersBound := closure.proofEnvelopeHeadersBound
  verifierPolicyBound := relations.endToEndRelation.productPolicyRelation

theorem productSystemBindingsAccepted_of_productRelations
    {depth : Nat}
    {View Leakage : Type}
    {relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage}
    {closure : ProductSystemBindingClosure}
    (hProduct :
      NumiSealProductKnowledgeCarryPrivacyHolds relations)
    (hClosure : ProductSystemBindingClosureAccepted closure) :
    ProductSystemBindingsAccepted
      (ProductSystemBindings.ofProductRelations relations closure) := by
  rcases hProduct with ⟨hEndToEnd, _, _, _⟩
  rcases hEndToEnd with
    ⟨hSourceFold,
      _,
      hTerminal,
      hTypedCarry,
      hZK,
      hPolicy⟩
  rcases hClosure with
    ⟨hChainRoot, hTranscriptDomains, hArtifact, hEnvelope⟩
  exact
    ⟨hSourceFold,
      hTerminal,
      hZK,
      hTypedCarry,
      hChainRoot,
      hTranscriptDomains,
      hArtifact,
      hEnvelope,
      hPolicy⟩

structure ProductBoundedDepthLossEvidence
    (parameters : ProductSecurityParameters) where
  supportedDepthPositive : 0 < parameters.maximumProductDepth
  allAcceptedLayersWithinDepth : Prop
  sourceFoldLossAccounted : Prop
  terminalSealLossAccounted : Prop
  recursiveCarryLossAccounted : Prop
  zkMaskingLossAccounted : Prop
  publicCoinLossAccounted : Prop
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
    ∧ losses.publicCoinLossAccounted
    ∧ losses.totalLossWithinBudget

structure ProductSelectedDepthLossLedger where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  selectedRecursiveCarryHops : Nat
  sourceFoldLossInstantiated : Prop
  terminalSealLossInstantiated : Prop
  recursiveCarryLossInstantiated : Prop
  zkSimulatorLossInstantiated : Prop
  publicCoinQROMLossInstantiated : Prop
  extractorLossInstantiated : Prop
  productOperationsReplayLossInstantiated : Prop
  loadedParentChainRequired : Prop
  recursiveCarryChainRootRecurrenceBound : Prop
  constantTimeSideChannelEvidenceClosed : Prop
  totalLossWithinBudget : Prop

def ProductSelectedDepthLossLedgerAccepted
    (ledger : ProductSelectedDepthLossLedger) : Prop :=
  ledger.selectedDepth = 3
    ∧ ledger.selectedRecursiveCarryHops = 2
    ∧ (0 < ledger.selectedDepth)
    ∧ ledger.sourceFoldLossInstantiated
    ∧ ledger.terminalSealLossInstantiated
    ∧ ledger.recursiveCarryLossInstantiated
    ∧ ledger.zkSimulatorLossInstantiated
    ∧ ledger.publicCoinQROMLossInstantiated
    ∧ ledger.extractorLossInstantiated
    ∧ ledger.productOperationsReplayLossInstantiated
    ∧ ledger.loadedParentChainRequired
    ∧ ledger.recursiveCarryChainRootRecurrenceBound
    ∧ ledger.constantTimeSideChannelEvidenceClosed
    ∧ ledger.totalLossWithinBudget

structure ProductSelectedDepthLossClosure where
  sourceFoldLossInstantiated : Prop
  terminalSealLossInstantiated : Prop
  recursiveCarryLossInstantiated : Prop
  zkSimulatorLossInstantiated : Prop
  productOperationsReplayLossInstantiated : Prop
  constantTimeSideChannelEvidenceClosed : Prop
  totalLossWithinBudget : Prop

def ProductSelectedDepthLossClosureAccepted
    (closure : ProductSelectedDepthLossClosure) : Prop :=
  closure.sourceFoldLossInstantiated
    ∧ closure.terminalSealLossInstantiated
    ∧ closure.recursiveCarryLossInstantiated
    ∧ closure.zkSimulatorLossInstantiated
    ∧ closure.productOperationsReplayLossInstantiated
    ∧ closure.constantTimeSideChannelEvidenceClosed
    ∧ closure.totalLossWithinBudget

def ProductBoundedDepthLossEvidence.ofSelectedDepthLedger
    (parameters : ProductSecurityParameters)
    (ledger : ProductSelectedDepthLossLedger)
    (hMaximumProductDepth : parameters.maximumProductDepth = 3) :
    ProductBoundedDepthLossEvidence parameters where
  supportedDepthPositive := by
    rw [hMaximumProductDepth]
    decide
  allAcceptedLayersWithinDepth :=
    ledger.selectedDepth ≤ parameters.maximumProductDepth
  sourceFoldLossAccounted := ledger.sourceFoldLossInstantiated
  terminalSealLossAccounted := ledger.terminalSealLossInstantiated
  recursiveCarryLossAccounted := ledger.recursiveCarryLossInstantiated
  zkMaskingLossAccounted := ledger.zkSimulatorLossInstantiated
  publicCoinLossAccounted := ledger.publicCoinQROMLossInstantiated
  totalLossWithinBudget := ledger.totalLossWithinBudget

theorem productBoundedDepthLossAccepted_of_selectedDepthLedger
    {parameters : ProductSecurityParameters}
    {ledger : ProductSelectedDepthLossLedger}
    {hMaximumProductDepth : parameters.maximumProductDepth = 3}
    (hLedger : ProductSelectedDepthLossLedgerAccepted ledger) :
    ProductBoundedDepthLossAccepted
      (ProductBoundedDepthLossEvidence.ofSelectedDepthLedger
        parameters
        ledger
        hMaximumProductDepth) := by
  rcases hLedger with
    ⟨hDepth,
      _,
      _,
      hSourceFold,
      hTerminalSeal,
      hRecursiveCarry,
      hZK,
      hPublicCoin,
      _,
      _,
      _,
      _,
      _,
      hTotal⟩
  exact
    ⟨by
        rw [hMaximumProductDepth]
        decide,
      by
        simp [ProductBoundedDepthLossEvidence.ofSelectedDepthLedger,
          hDepth,
          hMaximumProductDepth],
      hSourceFold,
      hTerminalSeal,
      hRecursiveCarry,
      hZK,
      hPublicCoin,
      hTotal⟩

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
  obstruction.selectedDepth = 3
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

structure ProductAcceptedProofKindExtractor where
  acceptedInputObjectSpecified : Prop
  verifierAcceptancePredicateSpecified : Prop
  extractedObjectSpecified : Prop
  failureEventsSpecified : Prop
  ctcoTraceBlockDependencySpecified : Prop
  extractorLossContributionSpecified : Prop
  parentChainDependencySpecified : Prop
  carryChainRootRelatesToExtractedState : Prop

def ProductAcceptedProofKindExtractorAccepted
    (extractor : ProductAcceptedProofKindExtractor) : Prop :=
  extractor.acceptedInputObjectSpecified
    ∧ extractor.verifierAcceptancePredicateSpecified
    ∧ extractor.extractedObjectSpecified
    ∧ extractor.failureEventsSpecified
    ∧ extractor.ctcoTraceBlockDependencySpecified
    ∧ extractor.extractorLossContributionSpecified
    ∧ extractor.parentChainDependencySpecified
    ∧ extractor.carryChainRootRelatesToExtractedState

def ProductAcceptedProofKindExtractor.ofTerminalCEConstructiveCertificate
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count bound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEConstructiveFiniteSoundnessCertificate
        verifyProof
        opens
        proofSeed
        bound)
    (statement : TerminalCEStatement Claim count)
    (proof : Proof)
    (ctcoTraceBlockDependencySpecified : Prop)
    (extractorLossContributionSpecified : Prop)
    (parentChainDependencySpecified : Prop)
    (carryChainRootRelatesToExtractedState : Prop) :
    ProductAcceptedProofKindExtractor where
  acceptedInputObjectSpecified := verifyProof statement proof
  verifierAcceptancePredicateSpecified := certificate.badSeeds.card ≤ bound
  extractedObjectSpecified :=
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens
  failureEventsSpecified := proofSeed proof ∉ certificate.badSeeds
  ctcoTraceBlockDependencySpecified := ctcoTraceBlockDependencySpecified
  extractorLossContributionSpecified := extractorLossContributionSpecified
  parentChainDependencySpecified := parentChainDependencySpecified
  carryChainRootRelatesToExtractedState := carryChainRootRelatesToExtractedState

theorem productTerminalExtractorAccepted_from_constructive_certificate
    {Claim Proof Witness Seed : Type}
    [DecidableEq Seed]
    {count bound : Nat}
    {verifyProof : TerminalCEStatement Claim count → Proof → Prop}
    {opens : Claim → Witness → Prop}
    {proofSeed : Proof → Seed}
    (certificate :
      TerminalCEConstructiveFiniteSoundnessCertificate
        verifyProof
        opens
        proofSeed
        bound)
    (statement : TerminalCEStatement Claim count)
    (proof : Proof)
    {ctcoTraceBlockDependencySpecified : Prop}
    {extractorLossContributionSpecified : Prop}
    {parentChainDependencySpecified : Prop}
    {carryChainRootRelatesToExtractedState : Prop}
    (hVerify : verifyProof statement proof)
    (hSeed : proofSeed proof ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencySpecified)
    (hExtractorLoss : extractorLossContributionSpecified)
    (hParentChain : parentChainDependencySpecified)
    (hCarryChain : carryChainRootRelatesToExtractedState) :
    ProductAcceptedProofKindExtractorAccepted
      (ProductAcceptedProofKindExtractor.ofTerminalCEConstructiveCertificate
        certificate
        statement
        proof
        ctcoTraceBlockDependencySpecified
        extractorLossContributionSpecified
        parentChainDependencySpecified
        carryChainRootRelatesToExtractedState) := by
  exact
    ⟨hVerify,
      certificate.card_le,
      terminalCEConstructive_certificate_extract_outside_bad
        certificate
        hVerify
        hSeed,
      hSeed,
      hCTCO,
      hExtractorLoss,
      hParentChain,
      hCarryChain⟩

def ProductAcceptedProofKindExtractor.ofPiRLCConstructiveCertificate
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims :
      Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCConstructiveFiniteSoundnessCertificate
        point
        foldedSound
        inputSound
        claims
        bound)
    (seed : PiRLCChallengeSeed count)
    (folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    (ctcoTraceBlockDependencySpecified : Prop)
    (extractorLossContributionSpecified : Prop)
    (parentChainDependencySpecified : Prop)
    (carryChainRootRelatesToExtractedState : Prop) :
    ProductAcceptedProofKindExtractor where
  acceptedInputObjectSpecified :=
    PiRLCConcreteAccepts point seed claims folded
  verifierAcceptancePredicateSpecified := certificate.badSeeds.card ≤ bound
  extractedObjectSpecified := AllClaimsSound inputSound claims
  failureEventsSpecified := seed ∉ certificate.badSeeds
  ctcoTraceBlockDependencySpecified := ctcoTraceBlockDependencySpecified
  extractorLossContributionSpecified := extractorLossContributionSpecified
  parentChainDependencySpecified := parentChainDependencySpecified
  carryChainRootRelatesToExtractedState := carryChainRootRelatesToExtractedState

theorem productPiRLCExtractorAccepted_from_constructive_certificate
    {count rows publicCount evalCount pointVars bound : Nat}
    {point : ProtocolVector Phi81 pointVars}
    {foldedSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {inputSound :
      EvaluationClaim Phi81 rows publicCount evalCount pointVars → Prop}
    {claims :
      Fin count → EvaluationClaim Phi81 rows publicCount evalCount pointVars}
    (certificate :
      PiRLCConstructiveFiniteSoundnessCertificate
        point
        foldedSound
        inputSound
        claims
        bound)
    (seed : PiRLCChallengeSeed count)
    (folded : EvaluationClaim Phi81 rows publicCount evalCount pointVars)
    {ctcoTraceBlockDependencySpecified : Prop}
    {extractorLossContributionSpecified : Prop}
    {parentChainDependencySpecified : Prop}
    {carryChainRootRelatesToExtractedState : Prop}
    (hAccepts : PiRLCConcreteAccepts point seed claims folded)
    (hFoldedSound : foldedSound folded)
    (hSeed : seed ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencySpecified)
    (hExtractorLoss : extractorLossContributionSpecified)
    (hParentChain : parentChainDependencySpecified)
    (hCarryChain : carryChainRootRelatesToExtractedState) :
    ProductAcceptedProofKindExtractorAccepted
      (ProductAcceptedProofKindExtractor.ofPiRLCConstructiveCertificate
        certificate
        seed
        folded
        ctcoTraceBlockDependencySpecified
        extractorLossContributionSpecified
        parentChainDependencySpecified
        carryChainRootRelatesToExtractedState) := by
  exact
    ⟨hAccepts,
      certificate.card_le,
      certificate.allInputsSound_outside_bad
        seed
        folded
        hAccepts
        hFoldedSound
        hSeed,
      hSeed,
      hCTCO,
      hExtractorLoss,
      hParentChain,
      hCarryChain⟩

def ProductAcceptedProofKindExtractor.ofPiCCSFiniteBadChallengeCertificate
    {F Seed : Type}
    [Semiring F]
    [DecidableEq Seed]
    {state : PiCCSPublicQState F}
    {traceSound : SumcheckVerifierTrace F → Prop}
    {traceSeed : SumcheckVerifierTrace F → Seed}
    {bound : Nat}
    (certificate :
      PiCCSFiniteBadChallengeCertificate
        state
        traceSound
        traceSeed
        bound)
    (trace : SumcheckVerifierTrace F)
    (ctcoTraceBlockDependencySpecified : Prop)
    (extractorLossContributionSpecified : Prop)
    (parentChainDependencySpecified : Prop)
    (carryChainRootRelatesToExtractedState : Prop) :
    ProductAcceptedProofKindExtractor where
  acceptedInputObjectSpecified := PiCCSAccepts state trace
  verifierAcceptancePredicateSpecified := certificate.badSeeds.card ≤ bound
  extractedObjectSpecified := traceSound trace
  failureEventsSpecified := traceSeed trace ∉ certificate.badSeeds
  ctcoTraceBlockDependencySpecified := ctcoTraceBlockDependencySpecified
  extractorLossContributionSpecified := extractorLossContributionSpecified
  parentChainDependencySpecified := parentChainDependencySpecified
  carryChainRootRelatesToExtractedState := carryChainRootRelatesToExtractedState

theorem productPiCCSExtractorAccepted_from_finite_bad_challenge_certificate
    {F Seed : Type}
    [Semiring F]
    [DecidableEq Seed]
    {state : PiCCSPublicQState F}
    {traceSound : SumcheckVerifierTrace F → Prop}
    {traceSeed : SumcheckVerifierTrace F → Seed}
    {bound : Nat}
    (certificate :
      PiCCSFiniteBadChallengeCertificate
        state
        traceSound
        traceSeed
        bound)
    (trace : SumcheckVerifierTrace F)
    {ctcoTraceBlockDependencySpecified : Prop}
    {extractorLossContributionSpecified : Prop}
    {parentChainDependencySpecified : Prop}
    {carryChainRootRelatesToExtractedState : Prop}
    (hAccepts : PiCCSAccepts state trace)
    (hSeed : traceSeed trace ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencySpecified)
    (hExtractorLoss : extractorLossContributionSpecified)
    (hParentChain : parentChainDependencySpecified)
    (hCarryChain : carryChainRootRelatesToExtractedState) :
    ProductAcceptedProofKindExtractorAccepted
      (ProductAcceptedProofKindExtractor.ofPiCCSFiniteBadChallengeCertificate
        certificate
        trace
        ctcoTraceBlockDependencySpecified
        extractorLossContributionSpecified
        parentChainDependencySpecified
        carryChainRootRelatesToExtractedState) := by
  exact
    ⟨hAccepts,
      certificate.card_le,
      piccs_traceSound_of_seed_not_bad
        certificate
        hAccepts
        hSeed,
      hSeed,
      hCTCO,
      hExtractorLoss,
      hParentChain,
      hCarryChain⟩

structure ProductPerKindExtractorTheorems where
  fold : ProductAcceptedProofKindExtractor
  terminal : ProductAcceptedProofKindExtractor
  compressedTerminal : ProductAcceptedProofKindExtractor
  numiSealTerminal : ProductAcceptedProofKindExtractor
  numiSealZKProduct : ProductAcceptedProofKindExtractor
  recursiveCarryDepthLeThree : ProductAcceptedProofKindExtractor

def ProductPerKindExtractorTheoremsAccepted
    (theorems : ProductPerKindExtractorTheorems) : Prop :=
  ProductAcceptedProofKindExtractorAccepted theorems.fold
    ∧ ProductAcceptedProofKindExtractorAccepted theorems.terminal
    ∧ ProductAcceptedProofKindExtractorAccepted theorems.compressedTerminal
    ∧ ProductAcceptedProofKindExtractorAccepted theorems.numiSealTerminal
    ∧ ProductAcceptedProofKindExtractorAccepted theorems.numiSealZKProduct
    ∧ ProductAcceptedProofKindExtractorAccepted theorems.recursiveCarryDepthLeThree

theorem productFoldExtractor_from_acceptedProof
    {theorems : ProductPerKindExtractorTheorems}
    (hTheorems : ProductPerKindExtractorTheoremsAccepted theorems) :
    ProductAcceptedProofKindExtractorAccepted theorems.fold := by
  exact hTheorems.left

theorem productTerminalExtractor_from_acceptedProof
    {theorems : ProductPerKindExtractorTheorems}
    (hTheorems : ProductPerKindExtractorTheoremsAccepted theorems) :
    ProductAcceptedProofKindExtractorAccepted theorems.terminal := by
  exact hTheorems.right.left

theorem productCompressedTerminalExtractor_from_acceptedProof
    {theorems : ProductPerKindExtractorTheorems}
    (hTheorems : ProductPerKindExtractorTheoremsAccepted theorems) :
    ProductAcceptedProofKindExtractorAccepted theorems.compressedTerminal := by
  exact hTheorems.right.right.left

theorem productNumiSealTerminalExtractor_from_acceptedProof
    {theorems : ProductPerKindExtractorTheorems}
    (hTheorems : ProductPerKindExtractorTheoremsAccepted theorems) :
    ProductAcceptedProofKindExtractorAccepted theorems.numiSealTerminal := by
  exact hTheorems.right.right.right.left

theorem productNumiSealZKProductExtractor_from_acceptedProof
    {theorems : ProductPerKindExtractorTheorems}
    (hTheorems : ProductPerKindExtractorTheoremsAccepted theorems) :
    ProductAcceptedProofKindExtractorAccepted theorems.numiSealZKProduct := by
  exact hTheorems.right.right.right.right.left

theorem productRecursiveCarryDepthLeThreeExtractor_from_acceptedProof
    {theorems : ProductPerKindExtractorTheorems}
    (hTheorems : ProductPerKindExtractorTheoremsAccepted theorems) :
    ProductAcceptedProofKindExtractorAccepted theorems.recursiveCarryDepthLeThree := by
  exact hTheorems.right.right.right.right.right

structure ProductTerminalVerifierArithmetization where
  relationTagPinned : Prop
  canonicalSourceEnvelopeDigestBound : Prop
  publicStatementDigestBound : Prop
  recursiveRelationDigestBound : Prop
  verifierKeyDigestBound : Prop
  terminalStatementDigestBound : Prop
  foldProofDigestBound : Prop
  ceOpeningProofDigestBound : Prop
  verifierRelationRerunsFoldReduction : Prop
  verifierRelationRerunsTerminalCEOpening : Prop
  verifierRelationRerunsPiCCS : Prop
  verifierRelationRerunsPiRLC : Prop
  verifierRelationRerunsPiDEC : Prop
  verifierRelationRerunsAjtaiOpening : Prop
  verifierRelationChecksModuleSISNorms : Prop
  fakeSourceDigestRejected : Prop
  sourceFreeSNARKStyleAcceptance : Prop
  sourceFreeSpartanFRIAcceptance : Prop
  spartanFRITraceBindsTerminalVerifierRelation : Prop
  malformedFRITraceRejected : Prop
  sourceFreeAcceptanceRequiresVerifierKey : Prop
  concreteVerifierConsumesCompressedProofBytes : Prop
  concreteVerifierRejectsExpandedVerifierWitness : Prop
  sourceProofBytesAbsentFromConcreteVerifier : Prop
  expandedVerifierTraceAbsentFromConcreteVerifier : Prop
  terminalVerifierTraceColumnsCommitted : Prop
  terminalVerifierBoundaryConstraintsCommitted : Prop
  terminalVerifierTransitionConstraintsCommitted : Prop
  terminalVerifierResidualPolynomialCommitted : Prop
  traceResidualPCSFRIQueriesVerified : Prop
  terminalVerifierExecutionIsProvedRelation : Prop
  terminalAcceptBitOneConstrained : Prop
  canonicalDecodingConstrainedAtAIRLevel : Prop
  hashDigestBindingsConstrainedAtAIRLevel : Prop
  piCCSVerifierConstrainedAtAIRLevel : Prop
  piRLCVerifierConstrainedAtAIRLevel : Prop
  piDECVerifierConstrainedAtAIRLevel : Prop
  terminalCEVerifierConstrainedAtAIRLevel : Prop
  friPCSVerifierConstrainedAtAIRLevel : Prop
  jointTraceResidualQueryScheduleBound : Prop
  traceResidualOpeningsPairedByQueryPoint : Prop
  residualEqualsAIRConstraintEvaluation : Prop
  acceptBitDerivedFromAIRConstraints : Prop
  terminalVerifierTypedAIRSubrelationsDeclared : Prop
  canonicalSourceRepresentationSubrelationConstrained : Prop
  publicBindingSubrelationConstrained : Prop
  piCCSVerifierSubrelationConstrained : Prop
  piRLCVerifierSubrelationConstrained : Prop
  piDECVerifierSubrelationConstrained : Prop
  terminalCEOpeningSubrelationConstrained : Prop
  innerCompressedProofVerifierSubrelationGatedBySourceKind : Prop
  outerFRIVerifierSeparatedFromTerminalAIR : Prop
  residualAggregationUsesTypedSubrelations : Prop
  residualPolynomialEncodesAggregateVerifierConstraints : Prop
  sharedSpecEmitsExecutableConstraintRows : Prop
  airResidualZeroIffSharedSpecAccepts : Prop
  normalTerminalVerifierAcceptanceEquivalentToZeroResidual : Prop

def ProductTerminalVerifierArithmetizationAccepted
    (arith : ProductTerminalVerifierArithmetization) : Prop :=
  arith.relationTagPinned
    ∧ arith.canonicalSourceEnvelopeDigestBound
    ∧ arith.publicStatementDigestBound
    ∧ arith.recursiveRelationDigestBound
    ∧ arith.verifierKeyDigestBound
    ∧ arith.terminalStatementDigestBound
    ∧ arith.foldProofDigestBound
    ∧ arith.ceOpeningProofDigestBound
    ∧ arith.verifierRelationRerunsFoldReduction
    ∧ arith.verifierRelationRerunsTerminalCEOpening
    ∧ arith.verifierRelationRerunsPiCCS
    ∧ arith.verifierRelationRerunsPiRLC
    ∧ arith.verifierRelationRerunsPiDEC
    ∧ arith.verifierRelationRerunsAjtaiOpening
    ∧ arith.verifierRelationChecksModuleSISNorms
    ∧ arith.fakeSourceDigestRejected
    ∧ arith.sourceFreeSNARKStyleAcceptance
    ∧ arith.sourceFreeSpartanFRIAcceptance
    ∧ arith.spartanFRITraceBindsTerminalVerifierRelation
    ∧ arith.malformedFRITraceRejected
    ∧ arith.sourceFreeAcceptanceRequiresVerifierKey
    ∧ arith.concreteVerifierConsumesCompressedProofBytes
    ∧ arith.concreteVerifierRejectsExpandedVerifierWitness
    ∧ arith.sourceProofBytesAbsentFromConcreteVerifier
    ∧ arith.expandedVerifierTraceAbsentFromConcreteVerifier
    ∧ arith.terminalVerifierTraceColumnsCommitted
    ∧ arith.terminalVerifierBoundaryConstraintsCommitted
    ∧ arith.terminalVerifierTransitionConstraintsCommitted
    ∧ arith.terminalVerifierResidualPolynomialCommitted
    ∧ arith.traceResidualPCSFRIQueriesVerified
    ∧ arith.terminalVerifierExecutionIsProvedRelation
    ∧ arith.terminalAcceptBitOneConstrained
    ∧ arith.canonicalDecodingConstrainedAtAIRLevel
    ∧ arith.hashDigestBindingsConstrainedAtAIRLevel
    ∧ arith.piCCSVerifierConstrainedAtAIRLevel
    ∧ arith.piRLCVerifierConstrainedAtAIRLevel
    ∧ arith.piDECVerifierConstrainedAtAIRLevel
    ∧ arith.terminalCEVerifierConstrainedAtAIRLevel
    ∧ arith.friPCSVerifierConstrainedAtAIRLevel
    ∧ arith.jointTraceResidualQueryScheduleBound
    ∧ arith.traceResidualOpeningsPairedByQueryPoint
    ∧ arith.residualEqualsAIRConstraintEvaluation
    ∧ arith.acceptBitDerivedFromAIRConstraints
    ∧ arith.terminalVerifierTypedAIRSubrelationsDeclared
    ∧ arith.canonicalSourceRepresentationSubrelationConstrained
    ∧ arith.publicBindingSubrelationConstrained
    ∧ arith.piCCSVerifierSubrelationConstrained
    ∧ arith.piRLCVerifierSubrelationConstrained
    ∧ arith.piDECVerifierSubrelationConstrained
    ∧ arith.terminalCEOpeningSubrelationConstrained
    ∧ arith.innerCompressedProofVerifierSubrelationGatedBySourceKind
    ∧ arith.outerFRIVerifierSeparatedFromTerminalAIR
    ∧ arith.residualAggregationUsesTypedSubrelations
    ∧ arith.residualPolynomialEncodesAggregateVerifierConstraints
    ∧ arith.sharedSpecEmitsExecutableConstraintRows
    ∧ arith.airResidualZeroIffSharedSpecAccepts
    ∧ arith.normalTerminalVerifierAcceptanceEquivalentToZeroResidual

theorem productCompressionSourceFree_from_terminalVerifierArithmetization
    {arith : ProductTerminalVerifierArithmetization}
    (hArith : ProductTerminalVerifierArithmetizationAccepted arith) :
    arith.sourceFreeSNARKStyleAcceptance
      ∧ arith.sourceFreeSpartanFRIAcceptance
      ∧ arith.concreteVerifierConsumesCompressedProofBytes
      ∧ arith.sourceProofBytesAbsentFromConcreteVerifier
      ∧ arith.concreteVerifierRejectsExpandedVerifierWitness
      ∧ arith.expandedVerifierTraceAbsentFromConcreteVerifier
      ∧ arith.canonicalSourceEnvelopeDigestBound
      ∧ arith.verifierRelationRerunsFoldReduction
      ∧ arith.verifierRelationRerunsPiCCS
      ∧ arith.verifierRelationRerunsPiRLC
      ∧ arith.verifierRelationRerunsPiDEC
      ∧ arith.verifierRelationRerunsAjtaiOpening
      ∧ arith.verifierRelationChecksModuleSISNorms
      ∧ arith.verifierRelationRerunsTerminalCEOpening
      ∧ arith.spartanFRITraceBindsTerminalVerifierRelation
      ∧ arith.terminalVerifierTraceColumnsCommitted
      ∧ arith.terminalVerifierBoundaryConstraintsCommitted
      ∧ arith.terminalVerifierTransitionConstraintsCommitted
      ∧ arith.terminalVerifierResidualPolynomialCommitted
      ∧ arith.traceResidualPCSFRIQueriesVerified
      ∧ arith.terminalVerifierExecutionIsProvedRelation
      ∧ arith.terminalAcceptBitOneConstrained := by
  rcases hArith with
    ⟨_,
      hSourceDigest,
      _,
      _,
      _,
      _,
      _,
      _,
      hFold,
      hCE,
      hPiCCS,
      hPiRLC,
      hPiDEC,
      hAjtai,
      hModuleSIS,
      _,
      hSNARK,
      hSpartan,
      hTrace,
      _,
      _,
      hBytes,
      hNoWitness,
      hNoSourceBytes,
      hNoTrace,
      hColumns,
      hBoundary,
      hTransition,
      hResidual,
      hQueries,
      hExecution,
      hAccept,
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
      _⟩
  exact ⟨hSNARK, hSpartan, hBytes, hNoSourceBytes, hNoWitness, hNoTrace,
    hSourceDigest, hFold, hPiCCS, hPiRLC, hPiDEC, hAjtai, hModuleSIS, hCE,
    hTrace, hColumns, hBoundary, hTransition, hResidual, hQueries, hExecution,
    hAccept⟩

structure ProductTerminalVerifierAIRSpec where
  sharedByNormalTerminalVerifierAndAIR : Prop
  canonicalSourceDecodingSpecified : Prop
  sourceDigestComputedFromCanonicalPrivateEncoding : Prop
  sourceByteCountBoundToCanonicalEncoding : Prop
  verifierKeyBindingSpecified : Prop
  publicStatementBindingSpecified : Prop
  recursiveRelationDigestPublicInput : Prop
  compressionPolicyBindingSpecified : Prop
  publicCoinDerivationVerifierBound : Prop
  piCCSVerifierEquationSpecified : Prop
  piRLCVerifierEquationSpecified : Prop
  piDECVerifierEquationSpecified : Prop
  terminalCEOpeningArithmeticSpecified : Prop
  ceAjtaiArithmeticConstrained : Prop
  moduleSISNormAndShapeChecksSpecified : Prop
  optionalInnerCompressedVerifierDomainSeparated : Prop
  concreteVerifierDoesNotAcceptExpandedWitness : Prop
  acceptBitDerivedFromSpecPredicates : Prop
  emitsNormalResultAndAIRConstraintRowsFromSameSteps : Prop
  noAssertedStageAcceptanceFlags : Prop
  digestAndCoinComputationsConstraintEmitted : Prop
  ceAjtaiArithmeticConstraintEmitted : Prop
  primitiveRowsHaveInspectableProvenance : Prop
  ceAjtaiLoweredToPrimitiveRows : Prop
  foldBoundariesLoweredToPrimitiveRows : Prop
  noVerifierBooleanWrappingRows : Prop
  noBoundaryReportAcceptanceRows : Prop
  digestRowsHashOrPublicBound : Prop
  compactBatchingCommitsFullPrimitiveRowSet : Prop
  compactBatchingChallengesAfterRowTranscriptCommitment : Prop
  compactBatchResidualAggregatesAllPrimitiveRows : Prop
  compactBatchSamplesAreAuditOnly : Prop
  compactBatchTranscriptBindsPublicContext : Prop
  zeroResidualIffSpecAccepts : Prop

def ProductTerminalVerifierAIRSpecAccepted
    (spec : ProductTerminalVerifierAIRSpec) : Prop :=
  spec.sharedByNormalTerminalVerifierAndAIR
    ∧ spec.canonicalSourceDecodingSpecified
    ∧ spec.sourceDigestComputedFromCanonicalPrivateEncoding
    ∧ spec.sourceByteCountBoundToCanonicalEncoding
    ∧ spec.verifierKeyBindingSpecified
    ∧ spec.publicStatementBindingSpecified
    ∧ spec.recursiveRelationDigestPublicInput
    ∧ spec.compressionPolicyBindingSpecified
    ∧ spec.publicCoinDerivationVerifierBound
    ∧ spec.piCCSVerifierEquationSpecified
    ∧ spec.piRLCVerifierEquationSpecified
    ∧ spec.piDECVerifierEquationSpecified
    ∧ spec.terminalCEOpeningArithmeticSpecified
    ∧ spec.ceAjtaiArithmeticConstrained
    ∧ spec.moduleSISNormAndShapeChecksSpecified
    ∧ spec.optionalInnerCompressedVerifierDomainSeparated
    ∧ spec.concreteVerifierDoesNotAcceptExpandedWitness
    ∧ spec.acceptBitDerivedFromSpecPredicates
    ∧ spec.emitsNormalResultAndAIRConstraintRowsFromSameSteps
    ∧ spec.noAssertedStageAcceptanceFlags
    ∧ spec.digestAndCoinComputationsConstraintEmitted
    ∧ spec.ceAjtaiArithmeticConstraintEmitted
    ∧ spec.primitiveRowsHaveInspectableProvenance
    ∧ spec.ceAjtaiLoweredToPrimitiveRows
    ∧ spec.foldBoundariesLoweredToPrimitiveRows
    ∧ spec.noVerifierBooleanWrappingRows
    ∧ spec.noBoundaryReportAcceptanceRows
    ∧ spec.digestRowsHashOrPublicBound
    ∧ spec.compactBatchingCommitsFullPrimitiveRowSet
    ∧ spec.compactBatchingChallengesAfterRowTranscriptCommitment
    ∧ spec.compactBatchResidualAggregatesAllPrimitiveRows
    ∧ spec.compactBatchSamplesAreAuditOnly
    ∧ spec.compactBatchTranscriptBindsPublicContext
    ∧ spec.zeroResidualIffSpecAccepts

structure ProductTerminalVerifierAIRSoundness where
  spec : ProductTerminalVerifierAIRSpec
  arithmetization : ProductTerminalVerifierArithmetization
  specAccepted : Prop
  arithmetizationAccepted : Prop
  zeroResidualImpliesSpecAcceptBit : Prop
  airAcceptBitImpliesNormalTerminalAccept : Prop
  sourceDigestComputationProvenInAIR : Prop
  publicCoinDerivationConstrainedInAIR : Prop
  ceAjtaiArithmeticNotDigestOnly : Prop
  recursiveRelationDigestPublicBoundInAIR : Prop
  witnessHeavySourceFreeVerifierPathAbsent : Prop
  constraintExactness : Prop
  compactPrimitiveBatchingSound : Prop
  residualCompleteness : Prop
  residualSoundness : Prop

def ProductTerminalVerifierAIRSoundnessAccepted
    (soundness : ProductTerminalVerifierAIRSoundness) : Prop :=
  soundness.specAccepted
    ∧ soundness.arithmetizationAccepted
    ∧ soundness.zeroResidualImpliesSpecAcceptBit
    ∧ soundness.airAcceptBitImpliesNormalTerminalAccept
    ∧ soundness.sourceDigestComputationProvenInAIR
    ∧ soundness.publicCoinDerivationConstrainedInAIR
    ∧ soundness.ceAjtaiArithmeticNotDigestOnly
    ∧ soundness.recursiveRelationDigestPublicBoundInAIR
    ∧ soundness.witnessHeavySourceFreeVerifierPathAbsent
    ∧ soundness.constraintExactness
    ∧ soundness.compactPrimitiveBatchingSound
    ∧ soundness.residualCompleteness
    ∧ soundness.residualSoundness

structure ProductTerminalVerifierAIRConstraintExactness where
  spec : ProductTerminalVerifierAIRSpec
  arithmetization : ProductTerminalVerifierArithmetization
  specAccepted : Prop
  arithmetizationAccepted : Prop
  sharedVerifierStepsEmitNormalResultAndAIRRows : Prop
  noAssertedStageShortcuts : Prop
  digestAndPublicCoinExactness : Prop
  ceAjtaiArithmeticExactness : Prop
  primitiveConstraintLoweringExactness : Prop
  noVerifierBooleanWrappingRows : Prop
  rowProvenanceTypedAndInspectable : Prop
  acceptBitDerivedFromResidualAggregate : Prop
  concreteVerifierNoWitnessEscapeHatch : Prop
  compactBatchingEquivalentToFullPrimitiveRows : Prop
  airResidualZeroIffSharedSpecAccepts : Prop

def ProductTerminalVerifierAIRConstraintExactnessAccepted
    (exactness : ProductTerminalVerifierAIRConstraintExactness) : Prop :=
  exactness.specAccepted
    ∧ exactness.arithmetizationAccepted
    ∧ ProductTerminalVerifierAIRSpecAccepted exactness.spec
    ∧ ProductTerminalVerifierArithmetizationAccepted exactness.arithmetization
    ∧ exactness.sharedVerifierStepsEmitNormalResultAndAIRRows
    ∧ exactness.noAssertedStageShortcuts
    ∧ exactness.digestAndPublicCoinExactness
    ∧ exactness.ceAjtaiArithmeticExactness
    ∧ exactness.primitiveConstraintLoweringExactness
    ∧ exactness.noVerifierBooleanWrappingRows
    ∧ exactness.rowProvenanceTypedAndInspectable
    ∧ exactness.acceptBitDerivedFromResidualAggregate
    ∧ exactness.concreteVerifierNoWitnessEscapeHatch
    ∧ exactness.compactBatchingEquivalentToFullPrimitiveRows
    ∧ exactness.airResidualZeroIffSharedSpecAccepts

structure ProductTerminalVerifierAIRResidualCompleteness where
  exactness : ProductTerminalVerifierAIRConstraintExactness
  sharedSpecAcceptsBoundSource : Prop
  airResidualZero : Prop
  residualCompleteness :
    sharedSpecAcceptsBoundSource → airResidualZero

def ProductTerminalVerifierAIRResidualCompletenessAccepted
    (completeness : ProductTerminalVerifierAIRResidualCompleteness) : Prop :=
  ProductTerminalVerifierAIRConstraintExactnessAccepted completeness.exactness
    ∧ (completeness.sharedSpecAcceptsBoundSource → completeness.airResidualZero)

structure ProductTerminalVerifierAIRResidualSoundness where
  exactness : ProductTerminalVerifierAIRConstraintExactness
  airResidualZero : Prop
  sharedSpecAcceptsBoundSource : Prop
  normalTerminalVerifierAcceptsBoundSource : Prop
  residualSoundness :
    airResidualZero →
      sharedSpecAcceptsBoundSource ∧ normalTerminalVerifierAcceptsBoundSource

def ProductTerminalVerifierAIRResidualSoundnessAccepted
    (soundness : ProductTerminalVerifierAIRResidualSoundness) : Prop :=
  ProductTerminalVerifierAIRConstraintExactnessAccepted soundness.exactness
    ∧ (soundness.airResidualZero →
        soundness.sharedSpecAcceptsBoundSource ∧ soundness.normalTerminalVerifierAcceptsBoundSource)

structure ProductTerminalVerifierAIRPrimitiveLowering where
  exactness : ProductTerminalVerifierAIRConstraintExactness
  ceAjtaiRowsEmitCanonicalCoefficientDecoding : Prop
  ceAjtaiRowsEmitDimensionChecks : Prop
  ceAjtaiRowsEmitMatrixVectorMultiplication : Prop
  ceAjtaiRowsEmitCommitmentEquality : Prop
  ceAjtaiRowsEmitNormAndShapeChecks : Prop
  piCCSRowsEmitProjectionSumcheckAndFinalClaimConstraints : Prop
  piRLCRowsEmitCoinLinearCombinationAndParentPointConstraints : Prop
  piDECRowsEmitDigitBoundsRecompositionAndLowNormConstraints : Prop
  digestRowsAreHashSubrelationsOrPublicBindings : Prop
  noRowsSourcedFromVerifierBooleansOrBoundaryReportAcceptance : Prop
  compactRowsEncodePrimitiveRowIndexResidualAndContext : Prop
  fullRowTranscriptCommittedBeforeBatchChallenges : Prop
  aggregateResidualCoversEveryCommittedPrimitiveRow : Prop
  sampledPrimitiveRowsNotUsedAsSoundnessSubstitute : Prop

def ProductTerminalVerifierAIRPrimitiveLoweringAccepted
    (lowering : ProductTerminalVerifierAIRPrimitiveLowering) : Prop :=
  ProductTerminalVerifierAIRConstraintExactnessAccepted lowering.exactness
    ∧ lowering.ceAjtaiRowsEmitCanonicalCoefficientDecoding
    ∧ lowering.ceAjtaiRowsEmitDimensionChecks
    ∧ lowering.ceAjtaiRowsEmitMatrixVectorMultiplication
    ∧ lowering.ceAjtaiRowsEmitCommitmentEquality
    ∧ lowering.ceAjtaiRowsEmitNormAndShapeChecks
    ∧ lowering.piCCSRowsEmitProjectionSumcheckAndFinalClaimConstraints
    ∧ lowering.piRLCRowsEmitCoinLinearCombinationAndParentPointConstraints
    ∧ lowering.piDECRowsEmitDigitBoundsRecompositionAndLowNormConstraints
    ∧ lowering.digestRowsAreHashSubrelationsOrPublicBindings
    ∧ lowering.noRowsSourcedFromVerifierBooleansOrBoundaryReportAcceptance
    ∧ lowering.compactRowsEncodePrimitiveRowIndexResidualAndContext
    ∧ lowering.fullRowTranscriptCommittedBeforeBatchChallenges
    ∧ lowering.aggregateResidualCoversEveryCommittedPrimitiveRow
    ∧ lowering.sampledPrimitiveRowsNotUsedAsSoundnessSubstitute

def ProductPrimitiveBatchLaneCountSelected (laneCount : Nat) : Prop :=
  laneCount = 4

structure ProductTerminalAIRPrimitiveBatchMultiLane where
  selectedPrimitiveBatchLaneCount : Nat
  batchResidualLaneCount : Nat
  selectedLaneCountPinned :
    ProductPrimitiveBatchLaneCountSelected selectedPrimitiveBatchLaneCount
  proofCarriesEveryLaneResidual : Prop
  verifierRequiresEveryLaneResidualZero : Prop
  noLaneIsAuditOnly : Prop
  rowTranscriptBindsBatchLaneCount : Prop
  challengeTranscriptBindsBatchLaneCount : Prop
  airTraceBindsAllLaneResiduals : Prop
  pcsFriBindsAllLaneResiduals : Prop

def ProductTerminalAIRPrimitiveBatchMultiLaneAccepted
    (multiLane : ProductTerminalAIRPrimitiveBatchMultiLane) : Prop :=
  ProductPrimitiveBatchLaneCountSelected multiLane.selectedPrimitiveBatchLaneCount
    ∧ multiLane.batchResidualLaneCount = multiLane.selectedPrimitiveBatchLaneCount
    ∧ multiLane.proofCarriesEveryLaneResidual
    ∧ multiLane.verifierRequiresEveryLaneResidualZero
    ∧ multiLane.noLaneIsAuditOnly
    ∧ multiLane.rowTranscriptBindsBatchLaneCount
    ∧ multiLane.challengeTranscriptBindsBatchLaneCount
    ∧ multiLane.airTraceBindsAllLaneResiduals
    ∧ multiLane.pcsFriBindsAllLaneResiduals

structure ProductPrimitiveBatchCancellationBound where
  goldilocksModulus : Nat
  batchContextCount : Nat
  selectedPrimitiveBatchLaneCount : Nat
  numerator : Nat
  denominator : Nat
  laneCountSelected :
    ProductPrimitiveBatchLaneCountSelected selectedPrimitiveBatchLaneCount
  numeratorIsBatchContextCount : numerator = batchContextCount
  denominatorIsGoldilocksQPowSelectedLaneCount :
    denominator = goldilocksModulus ^ selectedPrimitiveBatchLaneCount
  cancellationEventBoundedByBatchContextCountOverQPowFour : Prop

def ProductPrimitiveBatchCancellationBoundAccepted
    (bound : ProductPrimitiveBatchCancellationBound) : Prop :=
  bound.goldilocksModulus = 18446744069414584321
    ∧ 0 < bound.batchContextCount
    ∧ ProductPrimitiveBatchLaneCountSelected bound.selectedPrimitiveBatchLaneCount
    ∧ bound.numerator = bound.batchContextCount
    ∧ bound.denominator = bound.goldilocksModulus ^ bound.selectedPrimitiveBatchLaneCount
    ∧ bound.denominator = bound.goldilocksModulus ^ 4
    ∧ bound.cancellationEventBoundedByBatchContextCountOverQPowFour

structure ProductTerminalVerifierAIRPrimitiveBatching where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  multiLane : ProductTerminalAIRPrimitiveBatchMultiLane
  cancellationBound : ProductPrimitiveBatchCancellationBound
  everyPrimitiveRowCanonicallyEncoded : Prop
  fullPrimitiveRowTranscriptCommitted : Prop
  noOmittedRowsOrDuplicateRowIndices : Prop
  batchingChallengesDerivedAfterTranscriptCommitment : Prop
  batchingCoefficientsRejectionSampledGoldilocksFieldElements : Prop
  batchingBadEventBoundChargedOverGoldilocksFieldSize : Prop
  batchingBadEventBoundChargedOverQFourthPower : Prop
  aggregateResidualCoversAllPrimitiveRows : Prop
  aggregateResidualCoversAllPrimitiveRowsAndAllBatchLanes : Prop
  sampledRowsAreAuditOnly : Prop
  aggregateResidualBoundIntoPCSFRI : Prop
  allLaneResidualsBoundIntoPCSFRI : Prop
  rowTranscriptBindsTerminalVerifierRelationDigest : Prop
  rowTranscriptBindsRecursiveRelationDigest : Prop
  rowTranscriptBindsSourceDigestAndByteCount : Prop
  rowTranscriptBindsPrimitiveBatchLaneCount : Prop
  proofBytesBindPrimitiveBatchLaneCount : Prop

def ProductTerminalVerifierAIRPrimitiveBatchingAccepted
    (batching : ProductTerminalVerifierAIRPrimitiveBatching) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted batching.lowering
    ∧ ProductTerminalAIRPrimitiveBatchMultiLaneAccepted batching.multiLane
    ∧ ProductPrimitiveBatchCancellationBoundAccepted batching.cancellationBound
    ∧ batching.everyPrimitiveRowCanonicallyEncoded
    ∧ batching.fullPrimitiveRowTranscriptCommitted
    ∧ batching.noOmittedRowsOrDuplicateRowIndices
    ∧ batching.batchingChallengesDerivedAfterTranscriptCommitment
    ∧ batching.batchingCoefficientsRejectionSampledGoldilocksFieldElements
    ∧ batching.batchingBadEventBoundChargedOverGoldilocksFieldSize
    ∧ batching.batchingBadEventBoundChargedOverQFourthPower
    ∧ batching.aggregateResidualCoversAllPrimitiveRows
    ∧ batching.aggregateResidualCoversAllPrimitiveRowsAndAllBatchLanes
    ∧ batching.sampledRowsAreAuditOnly
    ∧ batching.aggregateResidualBoundIntoPCSFRI
    ∧ batching.allLaneResidualsBoundIntoPCSFRI
    ∧ batching.rowTranscriptBindsTerminalVerifierRelationDigest
    ∧ batching.rowTranscriptBindsRecursiveRelationDigest
    ∧ batching.rowTranscriptBindsSourceDigestAndByteCount
    ∧ batching.rowTranscriptBindsPrimitiveBatchLaneCount
    ∧ batching.proofBytesBindPrimitiveBatchLaneCount

structure ProductAIRRowsNoVerifierBooleanWrapping where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  verifierBooleanRowsRejectedByValidator : Prop
  boundaryReportAcceptanceRowsRejectedByValidator : Prop
  stageAcceptedFlagsRejectedByValidator : Prop
  digestMatchBooleansRejectedWithoutHashOrPublicBinding : Prop

def ProductAIRRowsNoVerifierBooleanWrappingAccepted
    (rows : ProductAIRRowsNoVerifierBooleanWrapping) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted rows.lowering
    ∧ rows.verifierBooleanRowsRejectedByValidator
    ∧ rows.boundaryReportAcceptanceRowsRejectedByValidator
    ∧ rows.stageAcceptedFlagsRejectedByValidator
    ∧ rows.digestMatchBooleansRejectedWithoutHashOrPublicBinding

structure ProductCEAjtaiPrimitiveConstraintSoundness where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  canonicalCoefficientDecodingSound : Prop
  moduleRingDimensionChecksSound : Prop
  ajtaiMatrixVectorMultiplicationSound : Prop
  commitmentEqualitySound : Prop
  normAndShapeChecksSound : Prop
  malformedAlternativeOpeningsRejected : Prop

def ProductCEAjtaiPrimitiveConstraintSoundnessAccepted
    (soundness : ProductCEAjtaiPrimitiveConstraintSoundness) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted soundness.lowering
    ∧ soundness.canonicalCoefficientDecodingSound
    ∧ soundness.moduleRingDimensionChecksSound
    ∧ soundness.ajtaiMatrixVectorMultiplicationSound
    ∧ soundness.commitmentEqualitySound
    ∧ soundness.normAndShapeChecksSound
    ∧ soundness.malformedAlternativeOpeningsRejected

structure ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundness where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  piCCSProjectionAndSumcheckSound : Prop
  piRLCPublicCoinAndLinearCombinationSound : Prop
  piRLCPerParentEvaluationPointSound : Prop
  piDECDecompositionAndRecompositionSound : Prop
  piDECLowNormAndPublicInputSplitSound : Prop

def ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundnessAccepted
    (soundness : ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundness) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted soundness.lowering
    ∧ soundness.piCCSProjectionAndSumcheckSound
    ∧ soundness.piRLCPublicCoinAndLinearCombinationSound
    ∧ soundness.piRLCPerParentEvaluationPointSound
    ∧ soundness.piDECDecompositionAndRecompositionSound
    ∧ soundness.piDECLowNormAndPublicInputSplitSound

structure ProductSourceFreeCompressionImpliesTerminalAcceptance where
  soundness : ProductTerminalVerifierAIRSoundness
  sourceFreeCompressedVerifyAccepts : Prop
  normalTerminalVerifierAcceptsBoundSource : Prop
  sameVerifierKey : Prop
  samePublicStatement : Prop
  sameRecursiveRelationDigest : Prop
  samePolicy : Prop
  sameSourceDigest : Prop
  sameSourceByteCount : Prop

def ProductSourceFreeCompressionImpliesTerminalAcceptanceAccepted
    (impl : ProductSourceFreeCompressionImpliesTerminalAcceptance) : Prop :=
  ProductTerminalVerifierAIRSoundnessAccepted impl.soundness
    ∧ impl.sameVerifierKey
    ∧ impl.samePublicStatement
    ∧ impl.sameRecursiveRelationDigest
    ∧ impl.samePolicy
    ∧ impl.sameSourceDigest
    ∧ impl.sameSourceByteCount
    ∧ (impl.sourceFreeCompressedVerifyAccepts →
        impl.normalTerminalVerifierAcceptsBoundSource)

theorem productSourceFreeCompression_sound_for_bound_source
    {impl : ProductSourceFreeCompressionImpliesTerminalAcceptance}
    (hImpl : ProductSourceFreeCompressionImpliesTerminalAcceptanceAccepted impl)
    (hAccept : impl.sourceFreeCompressedVerifyAccepts) :
    impl.normalTerminalVerifierAcceptsBoundSource := by
  rcases hImpl with ⟨_, _, _, _, _, _, _, hImp⟩
  exact hImp hAccept

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
  plan.selectedDepth = 3
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
  corollary.selectedDepth = 3
    ∧ corollary.acceptedProofKindsAreExactlyPublicFive
    ∧ corollary.proofKindBinderSelectsFixedExpectedKindContext
    ∧ (∀ kind, corollary.everyAcceptedKindHasFixedKindPlan kind)
    ∧ corollary.dispatcherChargesOnlySelectedKindPerRun

structure ProductCarryChainRoot where
  marker : Nat
  deriving DecidableEq, Repr

structure ProductSelectedDepthIndexing where
  baseAcceptedLayerDepth : Nat
  recursiveChildDepths : List Nat
  selectedMaximumDepth : Nat
  selectedRecursiveCarryHops : Nat
  depthZeroArtifactAccepted : Bool

def ProductSelectedDepthIndexingAccepted
    (indexing : ProductSelectedDepthIndexing) : Prop :=
  indexing.baseAcceptedLayerDepth = 1
    ∧ indexing.recursiveChildDepths = [2, 3]
    ∧ indexing.selectedMaximumDepth = 3
    ∧ indexing.selectedRecursiveCarryHops = 2
    ∧ indexing.depthZeroArtifactAccepted = false

structure ProductCarryChainRootByteLayout where
  baseDomainTagPinned : Prop
  stepDomainTagPinned : Prop
  versionPinned : Prop
  profileIDFieldPinned : Prop
  selectedDepthPolicyDigestFieldPinned : Prop
  depthIndexFieldPinned : Prop
  parentChainRootFieldPinned : Prop
  artifactDigestFieldPinned : Prop
  sourceFoldEnvelopeDigestFieldPinned : Prop
  productProofEnvelopeDigestFieldPinned : Prop
  producerEnvelopeDigestFieldPinned : Prop
  publicStatementDigestFieldPinned : Prop
  consumerSessionDigestFieldPinned : Prop
  contextRootFieldPinned : Prop
  replayRootFieldPinned : Prop
  typedCarryStatementDigestFieldPinned : Prop
  recursiveRelationDigestFieldPinned : Prop
  orderedPCDParentTupleRootFieldPinned : Prop
  fieldOrderPinned : Prop

def ProductCarryChainRootByteLayoutAccepted
    (layout : ProductCarryChainRootByteLayout) : Prop :=
  layout.baseDomainTagPinned
    ∧ layout.stepDomainTagPinned
    ∧ layout.versionPinned
    ∧ layout.profileIDFieldPinned
    ∧ layout.selectedDepthPolicyDigestFieldPinned
    ∧ layout.depthIndexFieldPinned
    ∧ layout.parentChainRootFieldPinned
    ∧ layout.artifactDigestFieldPinned
    ∧ layout.sourceFoldEnvelopeDigestFieldPinned
    ∧ layout.productProofEnvelopeDigestFieldPinned
    ∧ layout.producerEnvelopeDigestFieldPinned
    ∧ layout.publicStatementDigestFieldPinned
    ∧ layout.consumerSessionDigestFieldPinned
    ∧ layout.contextRootFieldPinned
    ∧ layout.replayRootFieldPinned
    ∧ layout.typedCarryStatementDigestFieldPinned
    ∧ layout.recursiveRelationDigestFieldPinned
    ∧ layout.orderedPCDParentTupleRootFieldPinned
    ∧ layout.fieldOrderPinned

structure ProductPCDParentTupleBinding where
  parentPositionBound : Prop
  parentNodeIndexBound : Prop
  parentDepthBound : Prop
  parentStateDigestBound : Prop
  parentAccumulatorDigestBound : Prop
  parentPublicStatementDigestBound : Prop
  parentOutputAccumulatorClaimBound : Prop
  parentEvaluationPointBound : Prop
  parentClaimValueBound : Prop
  parentRecursiveRelationDigestBound : Prop
  parentCarryChainRootBound : Prop

def ProductPCDParentTupleBindingAccepted
    (tuple : ProductPCDParentTupleBinding) : Prop :=
  tuple.parentPositionBound
    ∧ tuple.parentNodeIndexBound
    ∧ tuple.parentDepthBound
    ∧ tuple.parentStateDigestBound
    ∧ tuple.parentAccumulatorDigestBound
    ∧ tuple.parentPublicStatementDigestBound
    ∧ tuple.parentOutputAccumulatorClaimBound
    ∧ tuple.parentEvaluationPointBound
    ∧ tuple.parentClaimValueBound
    ∧ tuple.parentRecursiveRelationDigestBound
    ∧ tuple.parentCarryChainRootBound

structure OrderedPCDParentTupleRoot where
  domainTagPinned : Prop
  fanInBound : Prop
  orderedTuplesBound : Prop
  rootConsumedByFoldedRelation : Prop
  parentRemovalRejected : Prop
  parentReorderingRejected : Prop
  evaluationPointSwapRejected : Prop
  claimValueSwapRejected : Prop
  duplicateParentReplayRejected : Prop

def OrderedPCDParentTupleRootAccepted
    (root : OrderedPCDParentTupleRoot) : Prop :=
  root.domainTagPinned
    ∧ root.fanInBound
    ∧ root.orderedTuplesBound
    ∧ root.rootConsumedByFoldedRelation
    ∧ root.parentRemovalRejected
    ∧ root.parentReorderingRejected
    ∧ root.evaluationPointSwapRejected
    ∧ root.claimValueSwapRejected
    ∧ root.duplicateParentReplayRejected

structure ProductRecursiveCarryChainRootRecurrence where
  selectedDepth : Nat
  selectedRecursiveCarryHops : Nat
  depthIndexing : ProductSelectedDepthIndexing
  byteLayout : ProductCarryChainRootByteLayout
  orderedParentTupleRoot : OrderedPCDParentTupleRoot
  baseRoot : ProductCarryChainRoot
  rootAtDepth : Nat → ProductCarryChainRoot
  stepRoot : Nat → ProductCarryChainRoot → ProductCarryChainRoot
  baseRootComputedFromActualLoadedBaseArtifact :
    rootAtDepth 1 = baseRoot
  stepRootComputedFromLoadedParentChainRoot :
    ∀ depth, 1 ≤ depth → depth < selectedDepth →
      rootAtDepth (depth + 1) = stepRoot depth (rootAtDepth depth)
  verifierLoadsParentChainBeforeAcceptingRecursiveArtifact : Prop
  verifierRejectsClaimedMetadataOnlyRecursiveRoot : Prop
  stepBindsParentArtifactDigest : Prop
  stepBindsParentSourceFoldEnvelopeDigest : Prop
  stepBindsParentProductProofEnvelopeDigest : Prop
  stepBindsAcceptedProducerEnvelopeDigest : Prop
  stepBindsParentPublicStatementDigest : Prop
  stepBindsConsumerSessionDigest : Prop
  stepBindsRecomputedContextRoot : Prop
  stepBindsRecomputedReplayRoot : Prop
  stepBindsTypedCarryStatements : Prop
  stepBindsRecursiveRelationDigest : Prop
  stepBindsOrderedPCDParentTupleRoot : Prop
  extractorUsesVerifierComputedChainRoot : Prop
  ctcoTraceBindsRecursiveChainRoot : Prop

def ProductRecursiveCarryChainRootRecurrenceAccepted
    (recurrence : ProductRecursiveCarryChainRootRecurrence) : Prop :=
  recurrence.selectedDepth = 3
    ∧ recurrence.selectedRecursiveCarryHops = 2
    ∧ ProductSelectedDepthIndexingAccepted recurrence.depthIndexing
    ∧ ProductCarryChainRootByteLayoutAccepted recurrence.byteLayout
    ∧ OrderedPCDParentTupleRootAccepted recurrence.orderedParentTupleRoot
    ∧ recurrence.verifierLoadsParentChainBeforeAcceptingRecursiveArtifact
    ∧ recurrence.verifierRejectsClaimedMetadataOnlyRecursiveRoot
    ∧ recurrence.stepBindsParentArtifactDigest
    ∧ recurrence.stepBindsParentSourceFoldEnvelopeDigest
    ∧ recurrence.stepBindsParentProductProofEnvelopeDigest
    ∧ recurrence.stepBindsAcceptedProducerEnvelopeDigest
    ∧ recurrence.stepBindsParentPublicStatementDigest
    ∧ recurrence.stepBindsConsumerSessionDigest
    ∧ recurrence.stepBindsRecomputedContextRoot
    ∧ recurrence.stepBindsRecomputedReplayRoot
    ∧ recurrence.stepBindsTypedCarryStatements
    ∧ recurrence.stepBindsRecursiveRelationDigest
    ∧ recurrence.stepBindsOrderedPCDParentTupleRoot
    ∧ recurrence.extractorUsesVerifierComputedChainRoot
    ∧ recurrence.ctcoTraceBindsRecursiveChainRoot

structure ProductExtractorLossAccounting where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  acceptedLayerBounded : Prop
  sourceFoldExtractorSpecified : Prop
  terminalSealExtractorSpecified : Prop
  productEnvelopeExtractorSpecified : Prop
  recursiveCarryExtractorSpecified : Prop
  perKindExtractorTheorems : ProductPerKindExtractorTheorems
  recursiveCarryChainRootRecurrence :
    ProductRecursiveCarryChainRootRecurrence
  rewindScheduleBoundToTranscript : Prop
  extractorFailureLossAccounted : Prop
  extractorLossWithinBudget : Prop

def ProductExtractorLossAccountingAccepted
    (accounting : ProductExtractorLossAccounting) : Prop :=
  accounting.selectedDepth = 3
    ∧ (0 < accounting.selectedDepth)
    ∧ accounting.acceptedLayerBounded
    ∧ accounting.sourceFoldExtractorSpecified
    ∧ accounting.terminalSealExtractorSpecified
    ∧ accounting.productEnvelopeExtractorSpecified
    ∧ accounting.recursiveCarryExtractorSpecified
    ∧ ProductPerKindExtractorTheoremsAccepted accounting.perKindExtractorTheorems
    ∧ ProductRecursiveCarryChainRootRecurrenceAccepted
      accounting.recursiveCarryChainRootRecurrence
    ∧ accounting.rewindScheduleBoundToTranscript
    ∧ accounting.extractorFailureLossAccounted
    ∧ accounting.extractorLossWithinBudget

structure ProductExtractorLossClosure where
  acceptedLayerBounded : Prop
  rewindScheduleBoundToTranscript : Prop
  extractorFailureLossAccounted : Prop
  extractorLossWithinBudget : Prop

def ProductExtractorLossClosureAccepted
    (closure : ProductExtractorLossClosure) : Prop :=
  closure.acceptedLayerBounded
    ∧ closure.rewindScheduleBoundToTranscript
    ∧ closure.extractorFailureLossAccounted
    ∧ closure.extractorLossWithinBudget

def ProductExtractorLossAccounting.ofAcceptedComponents
    (perKindExtractorTheorems : ProductPerKindExtractorTheorems)
    (recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence)
    (closure : ProductExtractorLossClosure) :
    ProductExtractorLossAccounting where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  acceptedLayerBounded := closure.acceptedLayerBounded
  sourceFoldExtractorSpecified :=
    ProductAcceptedProofKindExtractorAccepted
      perKindExtractorTheorems.fold
  terminalSealExtractorSpecified :=
    ProductAcceptedProofKindExtractorAccepted
      perKindExtractorTheorems.terminal
  productEnvelopeExtractorSpecified :=
    ProductPerKindExtractorTheoremsAccepted perKindExtractorTheorems
  recursiveCarryExtractorSpecified :=
    ProductAcceptedProofKindExtractorAccepted
      perKindExtractorTheorems.recursiveCarryDepthLeThree
  perKindExtractorTheorems := perKindExtractorTheorems
  recursiveCarryChainRootRecurrence := recursiveCarryChainRootRecurrence
  rewindScheduleBoundToTranscript :=
    closure.rewindScheduleBoundToTranscript
  extractorFailureLossAccounted := closure.extractorFailureLossAccounted
  extractorLossWithinBudget := closure.extractorLossWithinBudget

theorem productExtractorLossAccountingAccepted_of_components
    {perKindExtractorTheorems : ProductPerKindExtractorTheorems}
    {recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence}
    {closure : ProductExtractorLossClosure}
    (hPerKind :
      ProductPerKindExtractorTheoremsAccepted perKindExtractorTheorems)
    (hRecurrence :
      ProductRecursiveCarryChainRootRecurrenceAccepted
        recursiveCarryChainRootRecurrence)
    (hClosure : ProductExtractorLossClosureAccepted closure) :
    ProductExtractorLossAccountingAccepted
      (ProductExtractorLossAccounting.ofAcceptedComponents
        perKindExtractorTheorems
        recursiveCarryChainRootRecurrence
        closure) := by
  rcases hPerKind with
    ⟨hFold,
      hTerminal,
      hCompressedTerminal,
      hNumiSealTerminal,
      hNumiSealZKProduct,
      hRecursiveCarry⟩
  rcases hClosure with
    ⟨hLayerBounded, hRewind, hExtractorLoss, hBudget⟩
  exact
    ⟨rfl,
      show 0 < 3 by decide,
      hLayerBounded,
      hFold,
      hTerminal,
      ⟨hFold,
        hTerminal,
        hCompressedTerminal,
        hNumiSealTerminal,
        hNumiSealZKProduct,
        hRecursiveCarry⟩,
      hRecursiveCarry,
      ⟨hFold,
        hTerminal,
        hCompressedTerminal,
        hNumiSealTerminal,
        hNumiSealZKProduct,
        hRecursiveCarry⟩,
      hRecurrence,
      hRewind,
      hExtractorLoss,
      hBudget⟩

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
  concreteHashRecommendationPinned : Prop
  hashQROInstantiationAssumptionPinned : Prop
  hashQROInstantiationProofProvided : Prop

def ProductHashOracleInstantiationAccepted
    (hashes : ProductHashOracleInstantiation) : Prop :=
  hashes.challengeOracleBits = 256
    ∧ hashes.bindingOracleBits = 384
    ∧ hashes.bindingTargetEventCount = 11
    ∧ hashes.splitOraclesPinned
    ∧ hashes.theoremCriticalBindingsUseHBind
    ∧ hashes.framedEncodingInjective
    ∧ hashes.proofKindBytesInjective
    ∧ hashes.challengeDomainsSeparated
    ∧ hashes.bindingDomainsSeparated
    ∧ hashes.concreteHashRecommendationPinned
    ∧ hashes.hashQROInstantiationAssumptionPinned
    ∧ hashes.hashQROInstantiationProofProvided

def ProductFramedEncodingInjective : Prop :=
  Function.Injective proofEnvelopeTranscriptBinding384Encode
    ∧ Function.Injective
      (fun transcript : WellFormedTranscript =>
        transcriptBytes transcript.state)

theorem productFramedEncodingInjective :
    ProductFramedEncodingInjective :=
  ⟨proofEnvelopeTranscriptBinding384Encode_injective,
    wellFormedTranscript_bytes_injective⟩

def ProductProofKindBytesInjective : Prop :=
  Function.Injective proofEnvelopeKindEncode

theorem productProofKindBytesInjective :
    ProductProofKindBytesInjective :=
  proofEnvelopeKindEncode_injective

def ProductChallengeDomainSeparation : Prop :=
  domainSeparatorTag ≠ transcriptPayloadTag
    ∧ ∀ domain payload domainRest payloadRest,
      transcriptEncode (domainFrame domain :: domainRest) ≠
        transcriptEncode
          (payloadFrame transcriptPayloadTag payload :: payloadRest)

theorem productChallengeDomainSeparation :
    ProductChallengeDomainSeparation :=
  ⟨domainSeparatorTag_ne_transcriptPayloadTag,
    domainSeparatedTranscript_ne_payloadTranscript⟩

def ProductBindingDomainSeparation : Prop :=
  domainSeparatorTag ≠ proofEnvelopeHeaderTag
    ∧ ∀ domain payload domainRest payloadRest,
      transcriptEncode (domainFrame domain :: domainRest) ≠
        transcriptEncode
          (payloadFrame proofEnvelopeHeaderTag payload :: payloadRest)

theorem productBindingDomainSeparation :
    ProductBindingDomainSeparation := by
  refine ⟨domainSeparatorTag_ne_proofEnvelopeHeaderTag, ?_⟩
  intro domain payload domainRest payloadRest
  exact transcriptEncode_cons_ne_of_tag_ne
    domainSeparatorTag_ne_proofEnvelopeHeaderTag

def ProductHashOracleInstantiation.ofSerializationFacts
    (splitOraclesPinned : Prop)
    (theoremCriticalBindingsUseHBind : Prop)
    (concreteHashRecommendationPinned : Prop)
    (hashQROInstantiationAssumptionPinned : Prop)
    (hashQROInstantiationProofProvided : Prop) :
    ProductHashOracleInstantiation where
  challengeOracleBits := 256
  bindingOracleBits := 384
  bindingTargetEventCount := 11
  splitOraclesPinned := splitOraclesPinned
  theoremCriticalBindingsUseHBind := theoremCriticalBindingsUseHBind
  framedEncodingInjective := ProductFramedEncodingInjective
  proofKindBytesInjective := ProductProofKindBytesInjective
  challengeDomainsSeparated := ProductChallengeDomainSeparation
  bindingDomainsSeparated := ProductBindingDomainSeparation
  concreteHashRecommendationPinned := concreteHashRecommendationPinned
  hashQROInstantiationAssumptionPinned := hashQROInstantiationAssumptionPinned
  hashQROInstantiationProofProvided := hashQROInstantiationProofProvided

theorem productHashOracleInstantiationAccepted_of_serializationFacts
    {splitOraclesPinned : Prop}
    {theoremCriticalBindingsUseHBind : Prop}
    {concreteHashRecommendationPinned : Prop}
    {hashQROInstantiationAssumptionPinned : Prop}
    {hashQROInstantiationProofProvided : Prop}
    (hSplitOracles : splitOraclesPinned)
    (hHBind : theoremCriticalBindingsUseHBind)
    (hHashRecommendation : concreteHashRecommendationPinned)
    (hQROAssumption : hashQROInstantiationAssumptionPinned)
    (hQROProof : hashQROInstantiationProofProvided) :
    ProductHashOracleInstantiationAccepted
      (ProductHashOracleInstantiation.ofSerializationFacts
        splitOraclesPinned
        theoremCriticalBindingsUseHBind
        concreteHashRecommendationPinned
        hashQROInstantiationAssumptionPinned
        hashQROInstantiationProofProvided) :=
  ⟨rfl,
    rfl,
    rfl,
    hSplitOracles,
    hHBind,
    productFramedEncodingInjective,
    productProofKindBytesInjective,
    productChallengeDomainSeparation,
    productBindingDomainSeparation,
    hHashRecommendation,
    hQROAssumption,
    hQROProof⟩

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
  concreteProtocolImplementationComplete : Prop

def ProductInteractiveProtocolDefinitionsAccepted
    (protocols : ProductInteractiveProtocolDefinitions) : Prop :=
  protocols.selectedDepth = 3
    ∧ (0 < protocols.selectedDepth)
    ∧ protocols.acceptedProofKindsPinned
    ∧ protocols.allKindsThreeMovePublicCoin
    ∧ protocols.oneChallengeSeedPerKind
    ∧ protocols.moveOneRootCommitmentSpecified
    ∧ protocols.challengeTapeExpansionSpecified
    ∧ protocols.verifierChecksRootOpenings
    ∧ protocols.compressedTerminalCanonicalDecompression
    ∧ protocols.typedCarryBinderSpecified
    ∧ protocols.concreteProtocolImplementationComplete

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
    ∧ compiler.firstMessageBindsAllChallengeIndependentMaterial
    ∧ compiler.singleSeedChallengeTapePinned
    ∧ compiler.lateMessageBindingPinned
    ∧ compiler.tightQROMTransformBounded
    ∧ compiler.legacyDFM20InterfaceDeprecated

def ProductChallengeTapeCommitOpenCompiler.ofHashOracleInstantiation
    (hashes : ProductHashOracleInstantiation)
    (compilerFamily : ProductCompilerFamily)
    (firstMessageBindsAllChallengeIndependentMaterial : Prop)
    (singleSeedChallengeTapePinned : Prop)
    (lateMessageBindingPinned : Prop)
    (tightQROMTransformBounded : Prop)
    (legacyDFM20InterfaceDeprecated : Prop) :
    ProductChallengeTapeCommitOpenCompiler where
  compilerFamily := compilerFamily
  challengeSeedBits := hashes.challengeOracleBits
  bindingDigestBits := hashes.bindingOracleBits
  merkleNodeDigestBits := hashes.bindingOracleBits
  firstMessageBindsAllChallengeIndependentMaterial :=
    firstMessageBindsAllChallengeIndependentMaterial
  singleSeedChallengeTapePinned := singleSeedChallengeTapePinned
  lateMessageBindingPinned := lateMessageBindingPinned
  tightQROMTransformBounded := tightQROMTransformBounded
  legacyDFM20InterfaceDeprecated := legacyDFM20InterfaceDeprecated

theorem productChallengeTapeCommitOpenCompilerAccepted_of_hashOracleInstantiation
    {hashes : ProductHashOracleInstantiation}
    (hHashes : ProductHashOracleInstantiationAccepted hashes)
    {compilerFamily : ProductCompilerFamily}
    (hFamily :
      compilerFamily = ProductQROMTransformFamily.ctco
        ∨ compilerFamily = ProductQROMTransformFamily.merkleStraightline)
    {firstMessageBindsAllChallengeIndependentMaterial : Prop}
    {singleSeedChallengeTapePinned : Prop}
    {lateMessageBindingPinned : Prop}
    {tightQROMTransformBounded : Prop}
    {legacyDFM20InterfaceDeprecated : Prop}
    (hFirstMessage : firstMessageBindsAllChallengeIndependentMaterial)
    (hSingleSeed : singleSeedChallengeTapePinned)
    (hLateBinding : lateMessageBindingPinned)
    (hTightTransform : tightQROMTransformBounded)
    (hNoLegacyDFM20 : legacyDFM20InterfaceDeprecated) :
    ProductChallengeTapeCommitOpenCompilerAccepted
      (ProductChallengeTapeCommitOpenCompiler.ofHashOracleInstantiation
        hashes
        compilerFamily
        firstMessageBindsAllChallengeIndependentMaterial
        singleSeedChallengeTapePinned
        lateMessageBindingPinned
        tightQROMTransformBounded
        legacyDFM20InterfaceDeprecated) := by
  rcases hHashes with
    ⟨hChallengeBits,
      hBindingBits,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _⟩
  exact
    ⟨hFamily,
      hChallengeBits,
      hBindingBits,
      hBindingBits,
      hFirstMessage,
      hSingleSeed,
      hLateBinding,
      hTightTransform,
      hNoLegacyDFM20⟩

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
  effectiveHashOutputBits : Nat
  bindingDigestBits : Nat
  bindingTargetEventCount : Nat
  orderedCollisionPairCount : Nat
  targetEnumerationPinned : Prop
  collisionFormulaPinned : Prop
  collisionBoundInstantiated : Prop
  collisionBoundWithinBudget : Prop

def ProductQROMCollisionBoundAccepted
    (bound : ProductQROMCollisionBound) : Prop :=
  bound.queryBoundQHLog2 = 64
    ∧ bound.effectiveHashOutputBits = 256
    ∧ bound.bindingDigestBits = 384
    ∧ bound.bindingTargetEventCount = 11
    ∧ bound.orderedCollisionPairCount = 44
    ∧ bound.orderedCollisionPairCount = bound.bindingTargetEventCount * 4
    ∧ bound.targetEnumerationPinned
    ∧ bound.collisionFormulaPinned
    ∧ bound.collisionBoundInstantiated
    ∧ bound.collisionBoundWithinBudget

def ProductQROMCollisionBound.ofHashOracleInstantiation
    (hashes : ProductHashOracleInstantiation)
    (targetEnumerationPinned : Prop)
    (collisionFormulaPinned : Prop)
    (collisionBoundInstantiated : Prop)
    (collisionBoundWithinBudget : Prop) :
    ProductQROMCollisionBound where
  queryBoundQHLog2 := 64
  effectiveHashOutputBits := hashes.challengeOracleBits
  bindingDigestBits := hashes.bindingOracleBits
  bindingTargetEventCount := hashes.bindingTargetEventCount
  orderedCollisionPairCount := hashes.bindingTargetEventCount * 4
  targetEnumerationPinned := targetEnumerationPinned
  collisionFormulaPinned := collisionFormulaPinned
  collisionBoundInstantiated := collisionBoundInstantiated
  collisionBoundWithinBudget := collisionBoundWithinBudget

theorem productQROMCollisionBoundAccepted_of_hashOracleInstantiation
    {hashes : ProductHashOracleInstantiation}
    (hHashes : ProductHashOracleInstantiationAccepted hashes)
    {targetEnumerationPinned : Prop}
    {collisionFormulaPinned : Prop}
    {collisionBoundInstantiated : Prop}
    {collisionBoundWithinBudget : Prop}
    (hTargetEnumeration : targetEnumerationPinned)
    (hFormula : collisionFormulaPinned)
    (hCollisionBound : collisionBoundInstantiated)
    (hWithinBudget : collisionBoundWithinBudget) :
    ProductQROMCollisionBoundAccepted
      (ProductQROMCollisionBound.ofHashOracleInstantiation
        hashes
        targetEnumerationPinned
        collisionFormulaPinned
        collisionBoundInstantiated
        collisionBoundWithinBudget) := by
  rcases hHashes with
    ⟨hChallengeBits,
      hBindingBits,
      hTargetCount,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _⟩
  exact
    ⟨rfl,
      hChallengeBits,
      hBindingBits,
      hTargetCount,
      by
        simp [ProductQROMCollisionBound.ofHashOracleInstantiation,
          hTargetCount],
      by
        simp [ProductQROMCollisionBound.ofHashOracleInstantiation],
      hTargetEnumeration,
      hFormula,
      hCollisionBound,
      hWithinBudget⟩

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
  auxiliaryLedgerTermsAccounted : Prop

def ProductQROMTotalLossInstantiatedAccepted
    (loss : ProductQROMTotalLossInstantiated) : Prop :=
  loss.hashModelGapZeroInIdealSplitQRO
    ∧ loss.compilerOverheadWithinBudget
    ∧ loss.qromExtraLossOnly
    ∧ loss.collisionLedgerIntegrated
    ∧ loss.cryptographicSliceWithinBudget
    ∧ loss.auxiliaryLedgerTermsAccounted

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
    ∧ bound.selectedDepth = 3
    ∧ 0 < bound.selectedDepth
    ∧ bound.idealSplitQROModelPinned
    ∧ bound.onlineExtractabilityAssumptionPinned
    ∧ bound.compilerAddsNoLegacyRoundFactor
    ∧ bound.compilerOverheadExactZeroInIdealModel
    ∧ bound.hashModelGapSeparated
    ∧ bound.totalLossLedgerReceivesQROMTerm

def ProductQROMCompilerOverheadBound.ofCompiler
    (compiler : ProductChallengeTapeCommitOpenCompiler)
    (idealSplitQROModelPinned : Prop)
    (onlineExtractabilityAssumptionPinned : Prop)
    (compilerOverheadExactZeroInIdealModel : Prop)
    (hashModelGapSeparated : Prop)
    (totalLossLedgerReceivesQROMTerm : Prop) :
    ProductQROMCompilerOverheadBound where
  selectedFamily := compiler.compilerFamily
  selectedDepth := 3
  idealSplitQROModelPinned := idealSplitQROModelPinned
  onlineExtractabilityAssumptionPinned :=
    onlineExtractabilityAssumptionPinned
  compilerAddsNoLegacyRoundFactor :=
    compiler.legacyDFM20InterfaceDeprecated
  compilerOverheadExactZeroInIdealModel :=
    compilerOverheadExactZeroInIdealModel
  hashModelGapSeparated := hashModelGapSeparated
  totalLossLedgerReceivesQROMTerm := totalLossLedgerReceivesQROMTerm

theorem productQROMCompilerOverheadBoundAccepted_of_compiler
    {compiler : ProductChallengeTapeCommitOpenCompiler}
    (hCompiler : ProductChallengeTapeCommitOpenCompilerAccepted compiler)
    {idealSplitQROModelPinned : Prop}
    {onlineExtractabilityAssumptionPinned : Prop}
    {compilerOverheadExactZeroInIdealModel : Prop}
    {hashModelGapSeparated : Prop}
    {totalLossLedgerReceivesQROMTerm : Prop}
    (hIdealSplitQRO : idealSplitQROModelPinned)
    (hOnlineExtractability : onlineExtractabilityAssumptionPinned)
    (hOverheadZero : compilerOverheadExactZeroInIdealModel)
    (hHashGap : hashModelGapSeparated)
    (hLedgerReceivesQROM : totalLossLedgerReceivesQROMTerm) :
    ProductQROMCompilerOverheadBoundAccepted
      (ProductQROMCompilerOverheadBound.ofCompiler
        compiler
        idealSplitQROModelPinned
        onlineExtractabilityAssumptionPinned
        compilerOverheadExactZeroInIdealModel
        hashModelGapSeparated
        totalLossLedgerReceivesQROMTerm) := by
  rcases hCompiler with
    ⟨hFamily,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      hNoLegacyFactor⟩
  exact
    ⟨hFamily,
      rfl,
      show 0 < 3 by decide,
      hIdealSplitQRO,
      hOnlineExtractability,
      hNoLegacyFactor,
      hOverheadZero,
      hHashGap,
      hLedgerReceivesQROM⟩

structure ProductSharedBadEventDeduplication where
  moduleSISSharedTagPinned : Prop
  commitmentSharedTagPinned : Prop
  sourceFoldUsesResidualNonCoreTerm : Prop
  terminalUsesResidualNonCoreTerm : Prop
  extractorUsesResidualNonCoreTerm : Prop
  qromCollisionSeparatedFromCore : Prop
  selectedDepthLedgerUsesSharedCoreTerm : Prop
  totalLossBudgetChargesSharedCoreOnce : Prop

def ProductFormalAggregateUnionBound : Prop :=
  ∀ {Tag : Type} [DecidableEq Tag] (ledger : ProductBadEventLedger Tag),
    ledger.aggregate.card ≤ ledger.flatCharge

theorem productFormalAggregateUnionBound :
    ProductFormalAggregateUnionBound := by
  intro _Tag _hDecidable ledger
  exact ProductBadEventLedger.aggregate_card_le_flatCharge ledger

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
  primitiveBatchCancellationExpressionExact : Prop
  hbindCollisionExpressionExact : Prop
  selectedDepthBudgetComparisonUsesExactRationals : Prop

def ProductExactFiniteProbabilityWiringAccepted
    (wiring : ProductExactFiniteProbabilityWiring) : Prop :=
  wiring.selectedDepth = 3
    ∧ 0 < wiring.selectedDepth
    ∧ wiring.dyadicRationalArithmeticPinned
    ∧ wiring.nonDyadicFiniteProtocolRationalsPinned
    ∧ wiring.zeroLossTermsRepresentedExactly
    ∧ wiring.instantiatedTermPartialSumComputed
    ∧ wiring.missingRequiredTermsKeepTotalUninstantiated
    ∧ wiring.qromTermSeparatedFromCollisionLedger
    ∧ wiring.sourceFoldRepeatedTapeExpressionExact
    ∧ wiring.terminalCE226ExpressionExact
    ∧ wiring.primitiveBatchCancellationExpressionExact
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

def ProductInstantiatedQROMEvidence.ofSerializationBackedHashAndCollision
    (splitOraclesPinned : Prop)
    (theoremCriticalBindingsUseHBind : Prop)
    (concreteHashRecommendationPinned : Prop)
    (hashQROInstantiationAssumptionPinned : Prop)
    (hashQROInstantiationProofProvided : Prop)
    (protocolDefinitions : ProductInteractiveProtocolDefinitions)
    (specialSoundnessData : ProductInteractiveSpecialSoundnessData)
    (delayedMessageData : ProductInteractiveDelayedMessageData)
    (uniqueResponseData : ProductInteractiveUniqueResponseData)
    (compiler : ProductChallengeTapeCommitOpenCompiler)
    (targetEnumerationPinned : Prop)
    (collisionFormulaPinned : Prop)
    (collisionBoundInstantiated : Prop)
    (collisionBoundWithinBudget : Prop)
    (malleabilityBound : ProductQROMMalleabilityBound)
    (interactiveBounds : ProductInteractiveSecurityBounds)
    (compilerOverheadBound : ProductQROMCompilerOverheadBound)
    (exactFiniteProbabilityWiring : ProductExactFiniteProbabilityWiring)
    (totalLoss : ProductQROMTotalLossInstantiated) :
    ProductInstantiatedQROMEvidence where
  hashInstantiation :=
    ProductHashOracleInstantiation.ofSerializationFacts
      splitOraclesPinned
      theoremCriticalBindingsUseHBind
      concreteHashRecommendationPinned
      hashQROInstantiationAssumptionPinned
      hashQROInstantiationProofProvided
  protocolDefinitions := protocolDefinitions
  specialSoundnessData := specialSoundnessData
  delayedMessageData := delayedMessageData
  uniqueResponseData := uniqueResponseData
  compiler := compiler
  collisionBound :=
    ProductQROMCollisionBound.ofHashOracleInstantiation
      (ProductHashOracleInstantiation.ofSerializationFacts
        splitOraclesPinned
        theoremCriticalBindingsUseHBind
        concreteHashRecommendationPinned
        hashQROInstantiationAssumptionPinned
        hashQROInstantiationProofProvided)
      targetEnumerationPinned
      collisionFormulaPinned
      collisionBoundInstantiated
      collisionBoundWithinBudget
  malleabilityBound := malleabilityBound
  interactiveBounds := interactiveBounds
  compilerOverheadBound := compilerOverheadBound
  exactFiniteProbabilityWiring := exactFiniteProbabilityWiring
  totalLoss := totalLoss

theorem productInstantiatedQROMEvidenceAccepted_of_serializationBackedHashAndCollision
    {splitOraclesPinned : Prop}
    {theoremCriticalBindingsUseHBind : Prop}
    {concreteHashRecommendationPinned : Prop}
    {hashQROInstantiationAssumptionPinned : Prop}
    {hashQROInstantiationProofProvided : Prop}
    {protocolDefinitions : ProductInteractiveProtocolDefinitions}
    {specialSoundnessData : ProductInteractiveSpecialSoundnessData}
    {delayedMessageData : ProductInteractiveDelayedMessageData}
    {uniqueResponseData : ProductInteractiveUniqueResponseData}
    {compiler : ProductChallengeTapeCommitOpenCompiler}
    {targetEnumerationPinned : Prop}
    {collisionFormulaPinned : Prop}
    {collisionBoundInstantiated : Prop}
    {collisionBoundWithinBudget : Prop}
    {malleabilityBound : ProductQROMMalleabilityBound}
    {interactiveBounds : ProductInteractiveSecurityBounds}
    {compilerOverheadBound : ProductQROMCompilerOverheadBound}
    {exactFiniteProbabilityWiring : ProductExactFiniteProbabilityWiring}
    {totalLoss : ProductQROMTotalLossInstantiated}
    (hSplitOracles : splitOraclesPinned)
    (hHBind : theoremCriticalBindingsUseHBind)
    (hHashRecommendation : concreteHashRecommendationPinned)
    (hQROAssumption : hashQROInstantiationAssumptionPinned)
    (hQROProof : hashQROInstantiationProofProvided)
    (hProtocols :
      ProductInteractiveProtocolDefinitionsAccepted protocolDefinitions)
    (hSpecialSoundness :
      ProductInteractiveSpecialSoundnessDataAccepted specialSoundnessData)
    (hDelayedMessages :
      ProductInteractiveDelayedMessageDataAccepted delayedMessageData)
    (hUniqueResponses :
      ProductInteractiveUniqueResponseDataAccepted uniqueResponseData)
    (hCompiler : ProductChallengeTapeCommitOpenCompilerAccepted compiler)
    (hTargetEnumeration : targetEnumerationPinned)
    (hFormula : collisionFormulaPinned)
    (hCollisionBound : collisionBoundInstantiated)
    (hWithinBudget : collisionBoundWithinBudget)
    (hMalleability : ProductQROMMalleabilityBoundAccepted malleabilityBound)
    (hInteractiveBounds :
      ProductInteractiveSecurityBoundsAccepted interactiveBounds)
    (hCompilerOverhead :
      ProductQROMCompilerOverheadBoundAccepted compilerOverheadBound)
    (hExactWiring :
      ProductExactFiniteProbabilityWiringAccepted exactFiniteProbabilityWiring)
    (hTotalLoss : ProductQROMTotalLossInstantiatedAccepted totalLoss) :
    ProductInstantiatedQROMEvidenceAccepted
      (ProductInstantiatedQROMEvidence.ofSerializationBackedHashAndCollision
        splitOraclesPinned
        theoremCriticalBindingsUseHBind
        concreteHashRecommendationPinned
        hashQROInstantiationAssumptionPinned
        hashQROInstantiationProofProvided
        protocolDefinitions
        specialSoundnessData
        delayedMessageData
        uniqueResponseData
        compiler
        targetEnumerationPinned
        collisionFormulaPinned
        collisionBoundInstantiated
        collisionBoundWithinBudget
        malleabilityBound
        interactiveBounds
        compilerOverheadBound
        exactFiniteProbabilityWiring
        totalLoss) := by
  have hHash :
      ProductHashOracleInstantiationAccepted
        (ProductHashOracleInstantiation.ofSerializationFacts
          splitOraclesPinned
          theoremCriticalBindingsUseHBind
          concreteHashRecommendationPinned
          hashQROInstantiationAssumptionPinned
          hashQROInstantiationProofProvided) :=
    productHashOracleInstantiationAccepted_of_serializationFacts
      hSplitOracles
      hHBind
      hHashRecommendation
      hQROAssumption
      hQROProof
  have hCollision :
      ProductQROMCollisionBoundAccepted
        (ProductQROMCollisionBound.ofHashOracleInstantiation
          (ProductHashOracleInstantiation.ofSerializationFacts
            splitOraclesPinned
            theoremCriticalBindingsUseHBind
            concreteHashRecommendationPinned
            hashQROInstantiationAssumptionPinned
            hashQROInstantiationProofProvided)
          targetEnumerationPinned
          collisionFormulaPinned
          collisionBoundInstantiated
          collisionBoundWithinBudget) :=
    productQROMCollisionBoundAccepted_of_hashOracleInstantiation
      hHash
      hTargetEnumeration
      hFormula
      hCollisionBound
      hWithinBudget
  exact
    ⟨hHash,
      hProtocols,
      hSpecialSoundness,
      hDelayedMessages,
      hUniqueResponses,
      hCompiler,
      hCollision,
      hMalleability,
      hInteractiveBounds,
      hCompilerOverhead,
      hExactWiring,
      hTotalLoss⟩

def ProductSelectedDepthLossLedger.ofAcceptedComponents
    (perKindExtractorTheorems : ProductPerKindExtractorTheorems)
    (recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence)
    (extractorLossClosure : ProductExtractorLossClosure)
    (qrom : ProductInstantiatedQROMEvidence)
    (closure : ProductSelectedDepthLossClosure) :
    ProductSelectedDepthLossLedger where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  selectedRecursiveCarryHops := 2
  sourceFoldLossInstantiated := closure.sourceFoldLossInstantiated
  terminalSealLossInstantiated := closure.terminalSealLossInstantiated
  recursiveCarryLossInstantiated := closure.recursiveCarryLossInstantiated
  zkSimulatorLossInstantiated := closure.zkSimulatorLossInstantiated
  publicCoinQROMLossInstantiated :=
    ProductInstantiatedQROMEvidenceAccepted qrom
  extractorLossInstantiated :=
    ProductExtractorLossAccountingAccepted
      (ProductExtractorLossAccounting.ofAcceptedComponents
        perKindExtractorTheorems
        recursiveCarryChainRootRecurrence
        extractorLossClosure)
  productOperationsReplayLossInstantiated :=
    closure.productOperationsReplayLossInstantiated
  loadedParentChainRequired :=
    recursiveCarryChainRootRecurrence.verifierLoadsParentChainBeforeAcceptingRecursiveArtifact
  recursiveCarryChainRootRecurrenceBound :=
    ProductRecursiveCarryChainRootRecurrenceAccepted
      recursiveCarryChainRootRecurrence
  constantTimeSideChannelEvidenceClosed :=
    closure.constantTimeSideChannelEvidenceClosed
  totalLossWithinBudget := closure.totalLossWithinBudget

theorem productSelectedDepthLossLedgerAccepted_of_components
    {perKindExtractorTheorems : ProductPerKindExtractorTheorems}
    {recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence}
    {extractorLossClosure : ProductExtractorLossClosure}
    {qrom : ProductInstantiatedQROMEvidence}
    {closure : ProductSelectedDepthLossClosure}
    (hPerKind :
      ProductPerKindExtractorTheoremsAccepted perKindExtractorTheorems)
    (hRecurrence :
      ProductRecursiveCarryChainRootRecurrenceAccepted
        recursiveCarryChainRootRecurrence)
    (hExtractorClosure :
      ProductExtractorLossClosureAccepted extractorLossClosure)
    (hQROM : ProductInstantiatedQROMEvidenceAccepted qrom)
    (hClosure : ProductSelectedDepthLossClosureAccepted closure) :
    ProductSelectedDepthLossLedgerAccepted
      (ProductSelectedDepthLossLedger.ofAcceptedComponents
        perKindExtractorTheorems
        recursiveCarryChainRootRecurrence
        extractorLossClosure
        qrom
        closure) := by
  have hRecurrenceAccepted :
      ProductRecursiveCarryChainRootRecurrenceAccepted
        recursiveCarryChainRootRecurrence :=
    hRecurrence
  have hExtractorAccounting :
      ProductExtractorLossAccountingAccepted
        (ProductExtractorLossAccounting.ofAcceptedComponents
          perKindExtractorTheorems
          recursiveCarryChainRootRecurrence
          extractorLossClosure) :=
    productExtractorLossAccountingAccepted_of_components
      hPerKind
      hRecurrence
      hExtractorClosure
  rcases hRecurrence with
    ⟨_,
      _,
      _,
      _,
      _,
      hLoadedParent,
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
      _,
      _,
      _⟩
  rcases hClosure with
    ⟨hSourceFold,
      hTerminalSeal,
      hRecursiveCarry,
      hZK,
      hProductReplay,
      hConstantTime,
      hTotal⟩
  exact
    ⟨rfl,
      rfl,
      show 0 < 3 by decide,
      hSourceFold,
      hTerminalSeal,
      hRecursiveCarry,
      hZK,
      hQROM,
      hExtractorAccounting,
      hProductReplay,
      hLoadedParent,
      hRecurrenceAccepted,
      hConstantTime,
      hTotal⟩

structure ProductPublicCoinTranscriptSchedule where
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
  transcriptScheduleTheoremApplies : Prop

def ProductWellFormedTranscriptScheduleTheorem : Prop :=
  Function.Injective
    (fun transcript : WellFormedTranscript =>
      transcriptBytes transcript.state)

def ProductPublicCoinTranscriptScheduleAccepted
    (schedule : ProductPublicCoinTranscriptSchedule) : Prop :=
  schedule.selectedDepth = 3
    ∧ (0 < schedule.selectedDepth)
    ∧ schedule.acceptedProofKindsPinned
    ∧ schedule.interactiveRoundSchedulePinned
    ∧ schedule.publicCoinChallengeLabelsPinned
    ∧ schedule.oracleQueryFamiliesPinned
    ∧ schedule.transcriptStateTransitionsPinned
    ∧ schedule.witnessIndependentOracleLabelsPinned
    ∧ schedule.domainSeparationBindingPinned
    ∧ schedule.proofKindSeparationBindingPinned
    ∧ schedule.numericQuantumQueryBoundsInstantiated
    ∧ schedule.transcriptScheduleTheoremApplies

def ProductPublicCoinTranscriptSchedule.ofInstantiatedQROM
    (evidence : ProductInstantiatedQROMEvidence)
    (publicCoinChallengeLabelsPinned : Prop)
    (oracleQueryFamiliesPinned : Prop)
    (transcriptStateTransitionsPinned : Prop)
    (witnessIndependentOracleLabelsPinned : Prop) :
    ProductPublicCoinTranscriptSchedule where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  acceptedProofKindsPinned :=
    evidence.protocolDefinitions.acceptedProofKindsPinned
  interactiveRoundSchedulePinned :=
    evidence.protocolDefinitions.allKindsThreeMovePublicCoin
  publicCoinChallengeLabelsPinned := publicCoinChallengeLabelsPinned
  oracleQueryFamiliesPinned := oracleQueryFamiliesPinned
  transcriptStateTransitionsPinned := transcriptStateTransitionsPinned
  witnessIndependentOracleLabelsPinned :=
    witnessIndependentOracleLabelsPinned
  domainSeparationBindingPinned :=
    evidence.hashInstantiation.challengeDomainsSeparated
      ∧ evidence.hashInstantiation.bindingDomainsSeparated
  proofKindSeparationBindingPinned :=
    evidence.hashInstantiation.proofKindBytesInjective
  numericQuantumQueryBoundsInstantiated :=
    ProductQROMCollisionBoundAccepted evidence.collisionBound
  transcriptScheduleTheoremApplies :=
    ProductWellFormedTranscriptScheduleTheorem

theorem productPublicCoinTranscriptScheduleAccepted_of_instantiatedQROM
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence)
    {publicCoinChallengeLabelsPinned : Prop}
    {oracleQueryFamiliesPinned : Prop}
    {transcriptStateTransitionsPinned : Prop}
    {witnessIndependentOracleLabelsPinned : Prop}
    (hChallengeLabels : publicCoinChallengeLabelsPinned)
    (hOracleFamilies : oracleQueryFamiliesPinned)
    (hTranscriptTransitions : transcriptStateTransitionsPinned)
    (hWitnessIndependent : witnessIndependentOracleLabelsPinned) :
    ProductPublicCoinTranscriptScheduleAccepted
      (ProductPublicCoinTranscriptSchedule.ofInstantiatedQROM
        evidence
        publicCoinChallengeLabelsPinned
        oracleQueryFamiliesPinned
        transcriptStateTransitionsPinned
        witnessIndependentOracleLabelsPinned) := by
  rcases hEvidence with
    ⟨hHash,
      hProtocols,
      _,
      _,
      _,
      _,
      hCollision,
      _,
      _,
      _,
      _,
      _⟩
  rcases hHash with
    ⟨_,
      _,
      _,
      _,
      _,
      _,
      hProofKindBytes,
      hChallengeDomains,
      hBindingDomains,
      _,
      _,
      _⟩
  rcases hProtocols with
    ⟨_,
      _,
      hAcceptedKinds,
      hThreeMove,
      _,
      _,
      _,
      _,
      _,
      _⟩
  exact
    ⟨rfl,
      show 0 < 3 by decide,
      hAcceptedKinds,
      hThreeMove,
      hChallengeLabels,
      hOracleFamilies,
      hTranscriptTransitions,
      hWitnessIndependent,
      ⟨hChallengeDomains, hBindingDomains⟩,
      hProofKindBytes,
      hCollision,
      wellFormedTranscript_bytes_injective⟩

structure ProductPublicCoinTransformPreconditions where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  theoremFamilyPinned : Prop
  acceptedProofKindOrderPinned : Prop
  publicCoinInteractiveProtocolSpecified : Prop
  constantRoundOddMessageScheduleSpecified : Prop
  challengeSpaceAndUniformityPinned : Prop
  transcriptOracleEncodingInjective : Prop
  transcriptScheduleAccepted : Prop
  underlyingInteractiveSecurityBoundInstantiated : Prop
  quantumOracleQueryBoundInstantiated : Prop
  qromReductionLossInstantiated : Prop
  transformSoundnessTheoremApplies : Prop

def ProductPublicCoinTransformPreconditionsAccepted
    (preconditions : ProductPublicCoinTransformPreconditions) : Prop :=
  preconditions.selectedDepth = 3
    ∧ (0 < preconditions.selectedDepth)
    ∧ preconditions.theoremFamilyPinned
    ∧ preconditions.acceptedProofKindOrderPinned
    ∧ preconditions.publicCoinInteractiveProtocolSpecified
    ∧ preconditions.constantRoundOddMessageScheduleSpecified
    ∧ preconditions.challengeSpaceAndUniformityPinned
    ∧ preconditions.transcriptOracleEncodingInjective
    ∧ preconditions.transcriptScheduleAccepted
    ∧ preconditions.underlyingInteractiveSecurityBoundInstantiated
    ∧ preconditions.quantumOracleQueryBoundInstantiated
    ∧ preconditions.qromReductionLossInstantiated
    ∧ preconditions.transformSoundnessTheoremApplies

def ProductPublicCoinTransformPreconditions.ofInstantiatedQROM
    (evidence : ProductInstantiatedQROMEvidence)
    (schedule : ProductPublicCoinTranscriptSchedule)
    (theoremFamilyPinned : Prop)
    (challengeSpaceAndUniformityPinned : Prop)
    (qromReductionLossInstantiated : Prop)
    (transformSoundnessTheoremApplies : Prop) :
    ProductPublicCoinTransformPreconditions where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  theoremFamilyPinned := theoremFamilyPinned
  acceptedProofKindOrderPinned := schedule.acceptedProofKindsPinned
  publicCoinInteractiveProtocolSpecified :=
    ProductInteractiveProtocolDefinitionsAccepted evidence.protocolDefinitions
  constantRoundOddMessageScheduleSpecified :=
    evidence.protocolDefinitions.allKindsThreeMovePublicCoin
  challengeSpaceAndUniformityPinned := challengeSpaceAndUniformityPinned
  transcriptOracleEncodingInjective :=
    evidence.hashInstantiation.framedEncodingInjective
      ∧ evidence.hashInstantiation.proofKindBytesInjective
  transcriptScheduleAccepted :=
    ProductPublicCoinTranscriptScheduleAccepted schedule
  underlyingInteractiveSecurityBoundInstantiated :=
    ProductInteractiveSecurityBoundsAccepted evidence.interactiveBounds
  quantumOracleQueryBoundInstantiated :=
    ProductQROMCollisionBoundAccepted evidence.collisionBound
  qromReductionLossInstantiated := qromReductionLossInstantiated
  transformSoundnessTheoremApplies := transformSoundnessTheoremApplies

theorem productPublicCoinTransformPreconditionsAccepted_of_instantiatedQROM
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence)
    {schedule : ProductPublicCoinTranscriptSchedule}
    (hSchedule : ProductPublicCoinTranscriptScheduleAccepted schedule)
    {theoremFamilyPinned : Prop}
    {challengeSpaceAndUniformityPinned : Prop}
    {qromReductionLossInstantiated : Prop}
    {transformSoundnessTheoremApplies : Prop}
    (hFamily : theoremFamilyPinned)
    (hUniformity : challengeSpaceAndUniformityPinned)
    (hReductionLoss : qromReductionLossInstantiated)
    (hTransformTheorem : transformSoundnessTheoremApplies) :
    ProductPublicCoinTransformPreconditionsAccepted
      (ProductPublicCoinTransformPreconditions.ofInstantiatedQROM
        evidence
        schedule
        theoremFamilyPinned
        challengeSpaceAndUniformityPinned
        qromReductionLossInstantiated
        transformSoundnessTheoremApplies) := by
  rcases hEvidence with
    ⟨hHash,
      hProtocols,
      _,
      _,
      _,
      _,
      hCollision,
      _,
      hInteractive,
      _,
      _,
      _⟩
  have hScheduleAccepted :
      ProductPublicCoinTranscriptScheduleAccepted schedule :=
    hSchedule
  rcases hSchedule with
    ⟨_,
      _,
      hAcceptedProofKinds,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _,
      _⟩
  have hProtocolsAccepted :
      ProductInteractiveProtocolDefinitionsAccepted
        evidence.protocolDefinitions :=
    hProtocols
  rcases hProtocols with
    ⟨_,
      _,
      _,
      hThreeMove,
      _,
      _,
      _,
      _,
      _,
      _,
      _⟩
  rcases hHash with
    ⟨_,
      _,
      _,
      _,
      _,
      hFramed,
      hProofKind,
      _,
      _,
      _,
      _,
      _⟩
  exact
    ⟨rfl,
      show 0 < 3 by decide,
      hFamily,
      hAcceptedProofKinds,
      hProtocolsAccepted,
      hThreeMove,
      hUniformity,
      ⟨hFramed, hProofKind⟩,
      hScheduleAccepted,
      hInteractive,
      hCollision,
      hReductionLoss,
      hTransformTheorem⟩

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
  qromReductionTheoremApplies : Prop

def ProductQROMInteractiveReductionAccepted
    (reduction : ProductQROMInteractiveReduction) : Prop :=
  reduction.selectedDepth = 3
    ∧ (0 < reduction.selectedDepth)
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
    ∧ reduction.qromReductionTheoremApplies

def ProductQROMInteractiveReduction.ofTransformPreconditions
    (preconditions : ProductPublicCoinTransformPreconditions)
    (challengeCountFormulasPinned : Prop)
    (dfm20LossFormulaPinned : Prop)
    (numericSelectedLossInstantiated : Prop)
    (totalLossBudgetInterfacePinned : Prop)
    (qromReductionTheoremApplies : Prop) :
    ProductQROMInteractiveReduction where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  acceptedProofKindOrderPinned :=
    preconditions.acceptedProofKindOrderPinned
  protocolMessageAlgorithmsPinned :=
    preconditions.publicCoinInteractiveProtocolSpecified
  exactMoveCountsPinned :=
    preconditions.constantRoundOddMessageScheduleSpecified
  challengeCountFormulasPinned := challengeCountFormulasPinned
  transcriptOracleEncodingProofPinned :=
    preconditions.transcriptOracleEncodingInjective
  challengeUniformityProofPinned :=
    preconditions.challengeSpaceAndUniformityPinned
  quantumQueryPolicyBoundPinned :=
    preconditions.quantumOracleQueryBoundInstantiated
  dfm20LossFormulaPinned := dfm20LossFormulaPinned
  numericSelectedLossInstantiated := numericSelectedLossInstantiated
  underlyingInteractiveSecurityInstantiated :=
    preconditions.underlyingInteractiveSecurityBoundInstantiated
  totalLossBudgetInterfacePinned := totalLossBudgetInterfacePinned
  qromReductionTheoremApplies := qromReductionTheoremApplies

theorem productQROMInteractiveReductionAccepted_of_transformPreconditions
    {preconditions : ProductPublicCoinTransformPreconditions}
    (hPreconditions :
      ProductPublicCoinTransformPreconditionsAccepted preconditions)
    {challengeCountFormulasPinned : Prop}
    {dfm20LossFormulaPinned : Prop}
    {numericSelectedLossInstantiated : Prop}
    {totalLossBudgetInterfacePinned : Prop}
    {qromReductionTheoremApplies : Prop}
    (hChallengeCounts : challengeCountFormulasPinned)
    (hDFM20Formula : dfm20LossFormulaPinned)
    (hNumericLoss : numericSelectedLossInstantiated)
    (hBudgetInterface : totalLossBudgetInterfacePinned)
    (hQROMTheorem : qromReductionTheoremApplies) :
    ProductQROMInteractiveReductionAccepted
      (ProductQROMInteractiveReduction.ofTransformPreconditions
        preconditions
        challengeCountFormulasPinned
        dfm20LossFormulaPinned
        numericSelectedLossInstantiated
        totalLossBudgetInterfacePinned
        qromReductionTheoremApplies) := by
  rcases hPreconditions with
    ⟨_,
      _,
      _,
      hAcceptedOrder,
      hProtocol,
      hMoveCounts,
      hUniformity,
      hEncoding,
      _,
      hInteractive,
      hQueries,
      _,
      _⟩
  exact
    ⟨rfl,
      show 0 < 3 by decide,
      hAcceptedOrder,
      hProtocol,
      hMoveCounts,
      hChallengeCounts,
      hEncoding,
      hUniformity,
      hQueries,
      hDFM20Formula,
      hNumericLoss,
      hInteractive,
      hBudgetInterface,
      hQROMTheorem⟩

structure ProductPublicCoinLossAccounting where
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

def ProductPublicCoinLossAccountingAccepted
    (accounting : ProductPublicCoinLossAccounting) : Prop :=
  accounting.selectedDepth = 3
    ∧ (0 < accounting.selectedDepth)
    ∧ accounting.interactiveProtocolSpecified
    ∧ accounting.publicCoinChallengeScheduleSpecified
    ∧ accounting.qromTransformPreconditionsSatisfied
    ∧ accounting.quantumOracleQueryBoundAccounted
    ∧ accounting.transcriptDomainSeparatorsBound
    ∧ accounting.proofKindSeparationBound
    ∧ accounting.transcriptCollisionMalleabilityExcluded
    ∧ accounting.qromLossWithinBudget

def ProductPublicCoinLossAccounting.ofInstantiatedQROM
    (evidence : ProductInstantiatedQROMEvidence) :
    ProductPublicCoinLossAccounting where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  interactiveProtocolSpecified :=
    ProductInteractiveProtocolDefinitionsAccepted evidence.protocolDefinitions
  publicCoinChallengeScheduleSpecified :=
    ProductChallengeTapeCommitOpenCompilerAccepted evidence.compiler
  qromTransformPreconditionsSatisfied :=
    ProductQROMCompilerOverheadBoundAccepted evidence.compilerOverheadBound
  quantumOracleQueryBoundAccounted :=
    ProductQROMCollisionBoundAccepted evidence.collisionBound
  transcriptDomainSeparatorsBound :=
    evidence.hashInstantiation.challengeDomainsSeparated
      ∧ evidence.hashInstantiation.bindingDomainsSeparated
  proofKindSeparationBound :=
    evidence.hashInstantiation.proofKindBytesInjective
  transcriptCollisionMalleabilityExcluded :=
    ProductQROMMalleabilityBoundAccepted evidence.malleabilityBound
  qromLossWithinBudget :=
    ProductQROMTotalLossInstantiatedAccepted evidence.totalLoss

theorem productPublicCoinLossAccountingAccepted_of_instantiatedQROM
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence) :
    ProductPublicCoinLossAccountingAccepted
      (ProductPublicCoinLossAccounting.ofInstantiatedQROM evidence) := by
  rcases hEvidence with
    ⟨hHash,
      hProtocols,
      _,
      _,
      _,
      hCompiler,
      hCollision,
      hMalleability,
      _,
      hCompilerOverhead,
      _,
      hLoss⟩
  rcases hHash with
    ⟨_,
      _,
      _,
      _,
      _,
      _,
      hProofKindBytes,
      hChallengeDomains,
      hBindingDomains,
      _,
      _,
      _⟩
  exact
    ⟨rfl,
      show 0 < 3 by decide,
      hProtocols,
      hCompiler,
      hCompilerOverhead,
      hCollision,
      ⟨hChallengeDomains, hBindingDomains⟩,
      hProofKindBytes,
      hMalleability,
      hLoss⟩

structure ProductTotalLossBudget where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  exactArithmeticPinned : Prop
  qromLedgerTermMappingPinned : Prop
  extractorLedgerTermMappingPinned : Prop
  primitiveBatchCancellationTermIncluded : Prop
  allRequiredTermsInstantiated : Prop
  missingRequiredTermSetEmpty : Prop
  selectedDepthLossWithinBudget : Prop
  totalLossBoundInstantiated : Prop

structure ProductTotalLossClosure where
  missingRequiredTermSetEmpty : Prop
  totalLossBoundInstantiated : Prop

def ProductTotalLossBudgetAccepted
    (budget : ProductTotalLossBudget) : Prop :=
  budget.selectedDepth = 3
    ∧ (0 < budget.selectedDepth)
    ∧ budget.exactArithmeticPinned
    ∧ budget.qromLedgerTermMappingPinned
    ∧ budget.extractorLedgerTermMappingPinned
    ∧ budget.primitiveBatchCancellationTermIncluded
    ∧ budget.allRequiredTermsInstantiated
    ∧ budget.missingRequiredTermSetEmpty
    ∧ budget.selectedDepthLossWithinBudget
    ∧ budget.totalLossBoundInstantiated

def ProductTotalLossBudget.ofAcceptedComponents
    (ledger : ProductSelectedDepthLossLedger)
    (extractorAccounting : ProductExtractorLossAccounting)
    (qrom : ProductInstantiatedQROMEvidence)
    (closure : ProductTotalLossClosure) :
    ProductTotalLossBudget where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  exactArithmeticPinned :=
    ProductExactFiniteProbabilityWiringAccepted qrom.exactFiniteProbabilityWiring
  qromLedgerTermMappingPinned :=
    ProductPublicCoinLossAccountingAccepted
      (ProductPublicCoinLossAccounting.ofInstantiatedQROM qrom)
  extractorLedgerTermMappingPinned :=
    ProductExtractorLossAccountingAccepted extractorAccounting
  primitiveBatchCancellationTermIncluded :=
    qrom.exactFiniteProbabilityWiring.primitiveBatchCancellationExpressionExact
  allRequiredTermsInstantiated :=
    ProductSelectedDepthLossLedgerAccepted ledger
      ∧ ProductExtractorLossAccountingAccepted extractorAccounting
      ∧ ProductInstantiatedQROMEvidenceAccepted qrom
  missingRequiredTermSetEmpty := closure.missingRequiredTermSetEmpty
  selectedDepthLossWithinBudget := ledger.totalLossWithinBudget
  totalLossBoundInstantiated := closure.totalLossBoundInstantiated

theorem productTotalLossBudgetAccepted_of_components
    {ledger : ProductSelectedDepthLossLedger}
    {extractorAccounting : ProductExtractorLossAccounting}
    {qrom : ProductInstantiatedQROMEvidence}
    {closure : ProductTotalLossClosure}
    (hLedger : ProductSelectedDepthLossLedgerAccepted ledger)
    (hExtractorAccounting :
      ProductExtractorLossAccountingAccepted extractorAccounting)
    (hQROM : ProductInstantiatedQROMEvidenceAccepted qrom)
    (hClosure :
      closure.missingRequiredTermSetEmpty
        ∧ closure.totalLossBoundInstantiated) :
    ProductTotalLossBudgetAccepted
      (ProductTotalLossBudget.ofAcceptedComponents
        ledger
        extractorAccounting
        qrom
        closure) := by
  have hQROMLedger :
      ProductPublicCoinLossAccountingAccepted
        (ProductPublicCoinLossAccounting.ofInstantiatedQROM qrom) :=
    productPublicCoinLossAccountingAccepted_of_instantiatedQROM hQROM
  have hAllRequired :
      ProductSelectedDepthLossLedgerAccepted ledger
        ∧ ProductExtractorLossAccountingAccepted extractorAccounting
        ∧ ProductInstantiatedQROMEvidenceAccepted qrom :=
    ⟨hLedger, hExtractorAccounting, hQROM⟩
  rcases hLedger with
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
      _,
      hSelectedDepthWithinBudget⟩
  rcases hQROM with
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
      hWiring,
      _⟩
  have hExactArithmetic :
      ProductExactFiniteProbabilityWiringAccepted
        qrom.exactFiniteProbabilityWiring :=
    hWiring
  rcases hWiring with
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
      hPrimitiveBatch,
      _,
      _⟩
  exact
    ⟨rfl,
      show 0 < 3 by decide,
      hExactArithmetic,
      hQROMLedger,
      hExtractorAccounting,
      hPrimitiveBatch,
      hAllRequired,
      hClosure.1,
      hSelectedDepthWithinBudget,
      hClosure.2⟩

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

structure ProductLatticeParameterClosure where
  qRingDimensionAndNormPinned : Prop
  decompositionAndChallengeParametersPinned : Prop
  normGrowthAcrossFoldAndNumiSealPinned : Prop
  reductionLossAccounted : Prop
  classicalCostEstimatePinned : Prop
  quantumCostEstimatePinned : Prop
  parameterSensitivityRecorded : Prop
  failureProbabilityBudgetRecorded : Prop

def ProductLatticeParameterClosureAccepted
    (closure : ProductLatticeParameterClosure) : Prop :=
  closure.qRingDimensionAndNormPinned
    ∧ closure.decompositionAndChallengeParametersPinned
    ∧ closure.normGrowthAcrossFoldAndNumiSealPinned
    ∧ closure.reductionLossAccounted
    ∧ closure.classicalCostEstimatePinned
    ∧ closure.quantumCostEstimatePinned
    ∧ closure.parameterSensitivityRecorded
    ∧ closure.failureProbabilityBudgetRecorded

def ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (qRingDimensionAndNormPinned : Prop)
    (decompositionAndChallengeParametersPinned : Prop)
    (normGrowthAcrossFoldAndNumiSealPinned : Prop)
    (reductionLossAccounted : Prop)
    (classicalCostEstimatePinned : Prop)
    (quantumCostEstimatePinned : Prop)
    (parameterSensitivityRecorded : Prop)
    (failureProbabilityBudgetRecorded : Prop) :
    ProductLatticeAssumptionDossier where
  moduleSISStatementPinned :=
    ModuleSISNoShortKernel key.matrix bounded
      ∧ checkAjtaiKernelCertificate key certificate.1
  qRingDimensionAndNormPinned := qRingDimensionAndNormPinned
  decompositionAndChallengeParametersPinned :=
    decompositionAndChallengeParametersPinned
  normGrowthAcrossFoldAndNumiSealPinned :=
    normGrowthAcrossFoldAndNumiSealPinned
  reductionLossAccounted := reductionLossAccounted
  classicalCostEstimatePinned := classicalCostEstimatePinned
  quantumCostEstimatePinned := quantumCostEstimatePinned
  parameterSensitivityRecorded := parameterSensitivityRecorded
  failureProbabilityBudgetRecorded := failureProbabilityBudgetRecorded

def ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificateAndClosure
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (closure : ProductLatticeParameterClosure) :
    ProductLatticeAssumptionDossier :=
  ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificate
    certificate
    closure.qRingDimensionAndNormPinned
    closure.decompositionAndChallengeParametersPinned
    closure.normGrowthAcrossFoldAndNumiSealPinned
    closure.reductionLossAccounted
    closure.classicalCostEstimatePinned
    closure.quantumCostEstimatePinned
    closure.parameterSensitivityRecorded
    closure.failureProbabilityBudgetRecorded

theorem productLatticeAssumptionDossierAccepted_of_verifiedAjtaiKernelCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    {qRingDimensionAndNormPinned : Prop}
    {decompositionAndChallengeParametersPinned : Prop}
    {normGrowthAcrossFoldAndNumiSealPinned : Prop}
    {reductionLossAccounted : Prop}
    {classicalCostEstimatePinned : Prop}
    {quantumCostEstimatePinned : Prop}
    {parameterSensitivityRecorded : Prop}
    {failureProbabilityBudgetRecorded : Prop}
    (hQRing : qRingDimensionAndNormPinned)
    (hDecomposition : decompositionAndChallengeParametersPinned)
    (hNormGrowth : normGrowthAcrossFoldAndNumiSealPinned)
    (hReductionLoss : reductionLossAccounted)
    (hClassicalCost : classicalCostEstimatePinned)
    (hQuantumCost : quantumCostEstimatePinned)
    (hSensitivity : parameterSensitivityRecorded)
    (hFailureBudget : failureProbabilityBudgetRecorded) :
    ProductLatticeAssumptionDossierAccepted
      (ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificate
        certificate
        qRingDimensionAndNormPinned
        decompositionAndChallengeParametersPinned
        normGrowthAcrossFoldAndNumiSealPinned
        reductionLossAccounted
        classicalCostEstimatePinned
        quantumCostEstimatePinned
        parameterSensitivityRecorded
        failureProbabilityBudgetRecorded) := by
  exact
    ⟨⟨verifiedCertificate_noShortKernel certificate, certificate.property⟩,
      hQRing,
      hDecomposition,
      hNormGrowth,
      hReductionLoss,
      hClassicalCost,
      hQuantumCost,
      hSensitivity,
      hFailureBudget⟩

theorem productLatticeAssumptionDossierAccepted_of_verifiedAjtaiKernelCertificateAndClosure
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    {closure : ProductLatticeParameterClosure}
    (hClosure : ProductLatticeParameterClosureAccepted closure) :
    ProductLatticeAssumptionDossierAccepted
      (ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificateAndClosure
        certificate
        closure) := by
  rcases hClosure with
    ⟨hQRing,
      hDecomposition,
      hNormGrowth,
      hReductionLoss,
      hClassicalCost,
      hQuantumCost,
      hSensitivity,
      hFailureBudget⟩
  exact
    productLatticeAssumptionDossierAccepted_of_verifiedAjtaiKernelCertificate
      certificate
      hQRing
      hDecomposition
      hNormGrowth
      hReductionLoss
      hClassicalCost
      hQuantumCost
      hSensitivity
      hFailureBudget

structure ProductPublicCoinQROMEvidence where
  interactivePublicCoinProtocolSpecified : Prop
  transformPreconditionsSatisfied : Prop
  quantumOracleQueryBoundAccounted : Prop
  transcriptDomainSeparatorsBound : Prop
  proofKindSeparationBound : Prop
  transcriptCollisionMalleabilityExcluded : Prop

def ProductPublicCoinQROMAccepted
    (evidence : ProductPublicCoinQROMEvidence) : Prop :=
  evidence.interactivePublicCoinProtocolSpecified
    ∧ evidence.transformPreconditionsSatisfied
    ∧ evidence.quantumOracleQueryBoundAccounted
    ∧ evidence.transcriptDomainSeparatorsBound
    ∧ evidence.proofKindSeparationBound
    ∧ evidence.transcriptCollisionMalleabilityExcluded

def ProductPublicCoinQROMEvidence.ofInstantiatedQROM
    (evidence : ProductInstantiatedQROMEvidence) :
    ProductPublicCoinQROMEvidence where
  interactivePublicCoinProtocolSpecified :=
    ProductInteractiveProtocolDefinitionsAccepted evidence.protocolDefinitions
  transformPreconditionsSatisfied :=
    ProductChallengeTapeCommitOpenCompilerAccepted evidence.compiler
  quantumOracleQueryBoundAccounted :=
    ProductQROMCollisionBoundAccepted evidence.collisionBound
  transcriptDomainSeparatorsBound :=
    evidence.hashInstantiation.challengeDomainsSeparated
      ∧ evidence.hashInstantiation.bindingDomainsSeparated
  proofKindSeparationBound :=
    evidence.hashInstantiation.proofKindBytesInjective
  transcriptCollisionMalleabilityExcluded :=
    ProductQROMMalleabilityBoundAccepted evidence.malleabilityBound

theorem productPublicCoinQROMAccepted_of_instantiatedQROM
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence) :
    ProductPublicCoinQROMAccepted
      (ProductPublicCoinQROMEvidence.ofInstantiatedQROM evidence) := by
  rcases hEvidence with
    ⟨hHash,
      hProtocols,
      _,
      _,
      _,
      hCompiler,
      hCollision,
      hMalleability,
      _,
      _,
      _,
      _⟩
  rcases hHash with
    ⟨_,
      _,
      _,
      _,
      _,
      _,
      hProofKindBytes,
      hChallengeDomains,
      hBindingDomains,
      _,
      _,
      _⟩
  exact
    ⟨hProtocols,
      hCompiler,
      hCollision,
      ⟨hChallengeDomains, hBindingDomains⟩,
      hProofKindBytes,
      hMalleability⟩

structure ProductSecurityTheoremObligationStatus where
  numiSealProduct : NumiSealProductTheoremObligationStatus
  systemBindingClosure : TheoremObligationStatus
  selectedDepthLossClosure : TheoremObligationStatus
  perKindExtractorTheorems : TheoremObligationStatus
  recursiveCarryChainRootRecurrence : TheoremObligationStatus
  extractorLossClosure : TheoremObligationStatus
  latticeParameterClosure : TheoremObligationStatus
  instantiatedQROM : TheoremObligationStatus
  totalLossBudget : TheoremObligationStatus

def ProductSecurityTheoremObligationStatus.FullyInstantiated
    (status : ProductSecurityTheoremObligationStatus) :
  Prop :=
  status.numiSealProduct.FullyInstantiated
    ∧ status.systemBindingClosure.Accepted
    ∧ status.selectedDepthLossClosure.Accepted
    ∧ status.perKindExtractorTheorems.Accepted
    ∧ status.recursiveCarryChainRootRecurrence.Accepted
    ∧ status.extractorLossClosure.Accepted
    ∧ status.latticeParameterClosure.Accepted
    ∧ status.instantiatedQROM.Accepted
    ∧ status.totalLossBudget.Accepted

structure ProductSecurityReductionConclusion
    {depth : Nat}
    {View Leakage : Type}
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (parameters : ProductSecurityParameters)
    (relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage)
    (systemBindingClosure : ProductSystemBindingClosure)
    (maximumProductDepthPinned : parameters.maximumProductDepth = 3)
    (selectedDepthLossClosure : ProductSelectedDepthLossClosure)
    (perKindExtractorTheorems : ProductPerKindExtractorTheorems)
    (recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence)
    (extractorLossClosure : ProductExtractorLossClosure)
    (latticeCertificate : VerifiedAjtaiKernelCertificate key bounded)
    (latticeParameterClosure : ProductLatticeParameterClosure)
    (instantiatedQROM : ProductInstantiatedQROMEvidence)
    (totalLossClosure : ProductTotalLossClosure) where
  productRelationsHold :
    NumiSealProductKnowledgeCarryPrivacyHolds relations
  endToEnd :
    NumiSealEndToEndRelationHolds relations.endToEndRelation
  recursiveKnowledge :
    RecursiveFoldingKnowledgeChainHolds
      relations.recursiveKnowledgeRelation
  typedCarry :
    NumiSealTypedCarryProducerConsumerRelationHolds
      relations.typedCarryRelation
  zkPrivacy :
    NumiSealZKSimulationPrivacyHolds relations.zkPrivacyClaim
  systemBindings :
    ProductSystemBindingsAccepted
      (ProductSystemBindings.ofProductRelations
        relations
        systemBindingClosure)
  selectedDepthLedger :
    ProductSelectedDepthLossLedgerAccepted
      (ProductSelectedDepthLossLedger.ofAcceptedComponents
        perKindExtractorTheorems
        recursiveCarryChainRootRecurrence
        extractorLossClosure
        instantiatedQROM
        selectedDepthLossClosure)
  boundedDepthLoss :
    ProductBoundedDepthLossAccepted
      (ProductBoundedDepthLossEvidence.ofSelectedDepthLedger
        parameters
        (ProductSelectedDepthLossLedger.ofAcceptedComponents
          perKindExtractorTheorems
          recursiveCarryChainRootRecurrence
          extractorLossClosure
          instantiatedQROM
          selectedDepthLossClosure)
        maximumProductDepthPinned)
  extractorAccounting :
    ProductExtractorLossAccountingAccepted
      (ProductExtractorLossAccounting.ofAcceptedComponents
        perKindExtractorTheorems
        recursiveCarryChainRootRecurrence
        extractorLossClosure)
  latticeDossier :
    ProductLatticeAssumptionDossierAccepted
      (ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificateAndClosure
        latticeCertificate
        latticeParameterClosure)
  instantiatedQROMAccepted :
    ProductInstantiatedQROMEvidenceAccepted instantiatedQROM
  publicCoinQROM :
    ProductPublicCoinQROMAccepted
      (ProductPublicCoinQROMEvidence.ofInstantiatedQROM instantiatedQROM)
  publicCoinLossAccounting :
    ProductPublicCoinLossAccountingAccepted
      (ProductPublicCoinLossAccounting.ofInstantiatedQROM instantiatedQROM)
  totalLossBudget :
    ProductTotalLossBudgetAccepted
      (ProductTotalLossBudget.ofAcceptedComponents
        (ProductSelectedDepthLossLedger.ofAcceptedComponents
          perKindExtractorTheorems
          recursiveCarryChainRootRecurrence
          extractorLossClosure
          instantiatedQROM
          selectedDepthLossClosure)
        (ProductExtractorLossAccounting.ofAcceptedComponents
          perKindExtractorTheorems
          recursiveCarryChainRootRecurrence
          extractorLossClosure)
        instantiatedQROM
        totalLossClosure)

theorem productSecurityTheorem_from_components
    {depth : Nat}
    {View Leakage : Type}
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    {parameters : ProductSecurityParameters}
    {relations :
      NumiSealProductKnowledgeCarryPrivacyRelations depth View Leakage}
    {systemBindingClosure : ProductSystemBindingClosure}
    {maximumProductDepthPinned : parameters.maximumProductDepth = 3}
    {selectedDepthLossClosure : ProductSelectedDepthLossClosure}
    {perKindExtractorTheorems : ProductPerKindExtractorTheorems}
    {recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence}
    {extractorLossClosure : ProductExtractorLossClosure}
    {latticeCertificate : VerifiedAjtaiKernelCertificate key bounded}
    {latticeParameterClosure : ProductLatticeParameterClosure}
    {instantiatedQROM : ProductInstantiatedQROMEvidence}
    {totalLossClosure : ProductTotalLossClosure}
    (hSystemBindingClosure :
      ProductSystemBindingClosureAccepted systemBindingClosure)
    (hSelectedDepthLossClosure :
      ProductSelectedDepthLossClosureAccepted selectedDepthLossClosure)
    (hPerKindExtractorTheorems :
      ProductPerKindExtractorTheoremsAccepted perKindExtractorTheorems)
    (hRecursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrenceAccepted
        recursiveCarryChainRootRecurrence)
    (hExtractorLossClosure :
      ProductExtractorLossClosureAccepted extractorLossClosure)
    (hLatticeParameterClosure :
      ProductLatticeParameterClosureAccepted latticeParameterClosure)
    (hInstantiatedQROM :
      ProductInstantiatedQROMEvidenceAccepted instantiatedQROM)
    (hTotalLossClosure :
      totalLossClosure.missingRequiredTermSetEmpty
        ∧ totalLossClosure.totalLossBoundInstantiated)
    (hProductRelations :
      NumiSealProductKnowledgeCarryPrivacyHolds relations) :
    ProductSecurityReductionConclusion
      parameters
      relations
      systemBindingClosure
      maximumProductDepthPinned
      selectedDepthLossClosure
      perKindExtractorTheorems
      recursiveCarryChainRootRecurrence
      extractorLossClosure
      latticeCertificate
      latticeParameterClosure
      instantiatedQROM
      totalLossClosure :=
  let selectedDepthLedger :=
    ProductSelectedDepthLossLedger.ofAcceptedComponents
      perKindExtractorTheorems
      recursiveCarryChainRootRecurrence
      extractorLossClosure
      instantiatedQROM
      selectedDepthLossClosure
  have hDerivedBindings :
      ProductSystemBindingsAccepted
        (ProductSystemBindings.ofProductRelations
          relations
          systemBindingClosure) :=
    productSystemBindingsAccepted_of_productRelations
      hProductRelations
      hSystemBindingClosure
  have hDerivedSelectedDepthLedger :
      ProductSelectedDepthLossLedgerAccepted selectedDepthLedger := by
    dsimp [selectedDepthLedger]
    exact productSelectedDepthLossLedgerAccepted_of_components
      hPerKindExtractorTheorems
      hRecursiveCarryChainRootRecurrence
      hExtractorLossClosure
      hInstantiatedQROM
      hSelectedDepthLossClosure
  have hDerivedBoundedDepthLosses :
      ProductBoundedDepthLossAccepted
        (ProductBoundedDepthLossEvidence.ofSelectedDepthLedger
          parameters
          selectedDepthLedger
          maximumProductDepthPinned) :=
    productBoundedDepthLossAccepted_of_selectedDepthLedger
      hDerivedSelectedDepthLedger
  have hDerivedExtractorAccounting :
      ProductExtractorLossAccountingAccepted
        (ProductExtractorLossAccounting.ofAcceptedComponents
          perKindExtractorTheorems
          recursiveCarryChainRootRecurrence
          extractorLossClosure) :=
    productExtractorLossAccountingAccepted_of_components
      hPerKindExtractorTheorems
      hRecursiveCarryChainRootRecurrence
      hExtractorLossClosure
  have hDerivedLatticeAssumptions :
      ProductLatticeAssumptionDossierAccepted
        (ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificateAndClosure
          latticeCertificate
          latticeParameterClosure) :=
    productLatticeAssumptionDossierAccepted_of_verifiedAjtaiKernelCertificateAndClosure
      latticeCertificate
      hLatticeParameterClosure
  have hDerivedPublicCoinAccounting :
      ProductPublicCoinLossAccountingAccepted
        (ProductPublicCoinLossAccounting.ofInstantiatedQROM instantiatedQROM) :=
    productPublicCoinLossAccountingAccepted_of_instantiatedQROM
      hInstantiatedQROM
  have hDerivedPublicCoinQROM :
      ProductPublicCoinQROMAccepted
        (ProductPublicCoinQROMEvidence.ofInstantiatedQROM instantiatedQROM) :=
    productPublicCoinQROMAccepted_of_instantiatedQROM
      hInstantiatedQROM
  have hDerivedTotalLossBudget :
      ProductTotalLossBudgetAccepted
        (ProductTotalLossBudget.ofAcceptedComponents
          selectedDepthLedger
          (ProductExtractorLossAccounting.ofAcceptedComponents
            perKindExtractorTheorems
            recursiveCarryChainRootRecurrence
            extractorLossClosure)
          instantiatedQROM
          totalLossClosure) :=
    productTotalLossBudgetAccepted_of_components
      hDerivedSelectedDepthLedger
      hDerivedExtractorAccounting
      hInstantiatedQROM
      hTotalLossClosure
  have hProductRelationsHold :
      NumiSealProductKnowledgeCarryPrivacyHolds relations :=
    hProductRelations
  show
      ProductSecurityReductionConclusion
        parameters
        relations
        systemBindingClosure
        maximumProductDepthPinned
        selectedDepthLossClosure
        perKindExtractorTheorems
        recursiveCarryChainRootRecurrence
        extractorLossClosure
        latticeCertificate
        latticeParameterClosure
        instantiatedQROM
        totalLossClosure
    from
      let hEndToEnd := hProductRelations.1
      let hRecursiveKnowledge := hProductRelations.2.1
      let hTypedCarry := hProductRelations.2.2.1
      let hZKPrivacy := hProductRelations.2.2.2
      { productRelationsHold := hProductRelationsHold
        endToEnd := hEndToEnd
        recursiveKnowledge := hRecursiveKnowledge
        typedCarry := hTypedCarry
        zkPrivacy := hZKPrivacy
        systemBindings := hDerivedBindings
        selectedDepthLedger := hDerivedSelectedDepthLedger
        boundedDepthLoss := hDerivedBoundedDepthLosses
        extractorAccounting := hDerivedExtractorAccounting
        latticeDossier := hDerivedLatticeAssumptions
        instantiatedQROMAccepted := hInstantiatedQROM
        publicCoinQROM := hDerivedPublicCoinQROM
        publicCoinLossAccounting := hDerivedPublicCoinAccounting
        totalLossBudget := hDerivedTotalLossBudget }

theorem productSecurityTheorem_requires_bounded_depth
    {parameters : ProductSecurityParameters}
    {losses : ProductBoundedDepthLossEvidence parameters}
    (hLosses : ProductBoundedDepthLossAccepted losses) :
    0 < parameters.maximumProductDepth :=
  hLosses.1

theorem productSecurityTheorem_derives_bounded_depth_loss
    {parameters : ProductSecurityParameters}
    {ledger : ProductSelectedDepthLossLedger}
    {maximumProductDepthPinned : parameters.maximumProductDepth = 3}
    (hLedger : ProductSelectedDepthLossLedgerAccepted ledger) :
    ProductBoundedDepthLossAccepted
      (ProductBoundedDepthLossEvidence.ofSelectedDepthLedger
        parameters
        ledger
        maximumProductDepthPinned) :=
  productBoundedDepthLossAccepted_of_selectedDepthLedger hLedger

theorem productSecurityTheorem_requires_selected_depth_loss_accounting
    {ledger : ProductSelectedDepthLossLedger}
    (hLedger : ProductSelectedDepthLossLedgerAccepted ledger) :
    ledger.selectedDepth = 3
      ∧ ledger.selectedRecursiveCarryHops = 2
      ∧ ledger.loadedParentChainRequired
      ∧ ledger.recursiveCarryChainRootRecurrenceBound
      ∧ ledger.extractorLossInstantiated
      ∧ ledger.publicCoinQROMLossInstantiated
      ∧ ledger.zkSimulatorLossInstantiated
      ∧ ledger.totalLossWithinBudget := by
  rcases hLedger with
    ⟨hDepth,
      hHops,
      _,
      _,
      _,
      _,
      hZKSimulator,
      hQROM,
      hExtractor,
      _,
      hLoadedParent,
      hRecurrence,
      _,
      hTotal⟩
  exact
    ⟨hDepth,
      hHops,
      hLoadedParent,
      hRecurrence,
      hExtractor,
      hQROM,
      hZKSimulator,
      hTotal⟩

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
      ∧ accounting.recursiveCarryExtractorSpecified
      ∧ ProductPerKindExtractorTheoremsAccepted
        accounting.perKindExtractorTheorems
      ∧ ProductRecursiveCarryChainRootRecurrenceAccepted
        accounting.recursiveCarryChainRootRecurrence
      ∧ accounting.extractorFailureLossAccounted
      ∧ accounting.extractorLossWithinBudget := by
  rcases hAccounting with
    ⟨_,
      _,
      _,
      hSourceFold,
      hTerminalSeal,
      hProductEnvelope,
      hRecursiveCarry,
      hPerKind,
      hRecurrence,
      _,
      hExtractorLoss,
      hBudget⟩
  exact
    ⟨hSourceFold,
      hTerminalSeal,
      hProductEnvelope,
      hRecursiveCarry,
      hPerKind,
      hRecurrence,
      hExtractorLoss,
      hBudget⟩

theorem productRecursiveCarryChainRoot_recurrence_unfolds_depth_le_three
    {recurrence : ProductRecursiveCarryChainRootRecurrence}
    (hRecurrence :
      ProductRecursiveCarryChainRootRecurrenceAccepted recurrence) :
    recurrence.rootAtDepth 1 = recurrence.baseRoot
      ∧ recurrence.rootAtDepth 2 = recurrence.stepRoot 1 recurrence.baseRoot
      ∧ recurrence.rootAtDepth 3 =
        recurrence.stepRoot 2 (recurrence.stepRoot 1 recurrence.baseRoot) := by
  rcases hRecurrence with
    ⟨hDepth, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _⟩
  have h12 :
      recurrence.rootAtDepth 2 =
        recurrence.stepRoot 1 recurrence.baseRoot := by
    have hStep :=
      recurrence.stepRootComputedFromLoadedParentChainRoot 1
        (by decide)
        (by rw [hDepth]; decide)
    rw [recurrence.baseRootComputedFromActualLoadedBaseArtifact] at hStep
    exact hStep
  have h23 :
      recurrence.rootAtDepth 3 =
        recurrence.stepRoot 2 (recurrence.stepRoot 1 recurrence.baseRoot) := by
    have hStep :=
      recurrence.stepRootComputedFromLoadedParentChainRoot 2
        (by decide)
        (by rw [hDepth]; decide)
    rw [h12] at hStep
    exact hStep
  exact
    ⟨recurrence.baseRootComputedFromActualLoadedBaseArtifact,
      h12,
      h23⟩

theorem productRecursiveCarryChainRoot_verifier_extractor_path_depth_le_three
    {recurrence : ProductRecursiveCarryChainRootRecurrence}
    (hRecurrence :
      ProductRecursiveCarryChainRootRecurrenceAccepted recurrence) :
    recurrence.selectedDepth = 3
      ∧ recurrence.selectedRecursiveCarryHops = 2
      ∧ ProductSelectedDepthIndexingAccepted recurrence.depthIndexing
      ∧ ProductCarryChainRootByteLayoutAccepted recurrence.byteLayout
      ∧ OrderedPCDParentTupleRootAccepted recurrence.orderedParentTupleRoot
      ∧ recurrence.verifierLoadsParentChainBeforeAcceptingRecursiveArtifact
      ∧ recurrence.verifierRejectsClaimedMetadataOnlyRecursiveRoot
      ∧ recurrence.stepBindsParentArtifactDigest
      ∧ recurrence.stepBindsParentSourceFoldEnvelopeDigest
      ∧ recurrence.stepBindsParentProductProofEnvelopeDigest
      ∧ recurrence.stepBindsAcceptedProducerEnvelopeDigest
      ∧ recurrence.stepBindsParentPublicStatementDigest
      ∧ recurrence.stepBindsConsumerSessionDigest
      ∧ recurrence.stepBindsRecomputedContextRoot
      ∧ recurrence.stepBindsRecomputedReplayRoot
      ∧ recurrence.stepBindsTypedCarryStatements
      ∧ recurrence.stepBindsRecursiveRelationDigest
      ∧ recurrence.stepBindsOrderedPCDParentTupleRoot
      ∧ recurrence.extractorUsesVerifierComputedChainRoot
      ∧ recurrence.ctcoTraceBindsRecursiveChainRoot := by
  exact hRecurrence

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
      hTight,
      _⟩
  rcases hCollision with
    ⟨_,
      _,
      _,
      _,
      _,
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
    ⟨_, _, _, _, _, _, hCompilerOverheadZero, _, _⟩
  rcases hWiring with
    ⟨_, _, _, _, _, hPartialSum, _, _, _, _, _, _⟩
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
    {accounting : ProductPublicCoinLossAccounting}
    (hAccounting : ProductPublicCoinLossAccountingAccepted accounting) :
    accounting.interactiveProtocolSpecified
      ∧ accounting.publicCoinChallengeScheduleSpecified
      ∧ accounting.qromTransformPreconditionsSatisfied
      ∧ accounting.quantumOracleQueryBoundAccounted
      ∧ accounting.transcriptCollisionMalleabilityExcluded
      ∧ accounting.qromLossWithinBudget := by
  rcases hAccounting with
    ⟨_,
      _,
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
    {accounting : ProductPublicCoinLossAccounting}
    (hAccounting : ProductPublicCoinLossAccountingAccepted accounting) :
    accounting.transcriptDomainSeparatorsBound
      ∧ accounting.proofKindSeparationBound
      ∧ accounting.transcriptCollisionMalleabilityExcluded := by
  rcases hAccounting with
    ⟨_,
      _,
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
      ∧ hashes.bindingTargetEventCount = 11
      ∧ hashes.theoremCriticalBindingsUseHBind
      ∧ hashes.bindingDomainsSeparated
      ∧ hashes.hashQROInstantiationAssumptionPinned
      ∧ hashes.hashQROInstantiationProofProvided := by
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
      _,
      hQROAssumption,
      hQROProof⟩
  exact
    ⟨hBindingBits,
      hTargetCount,
      hHBind,
      hBindingDomains,
      hQROAssumption,
      hQROProof⟩

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
    {schedule : ProductPublicCoinTranscriptSchedule}
    (hSchedule : ProductPublicCoinTranscriptScheduleAccepted schedule) :
    schedule.acceptedProofKindsPinned
      ∧ schedule.publicCoinChallengeLabelsPinned
      ∧ schedule.oracleQueryFamiliesPinned
      ∧ schedule.domainSeparationBindingPinned
      ∧ schedule.proofKindSeparationBindingPinned
      ∧ schedule.numericQuantumQueryBoundsInstantiated
      ∧ schedule.transcriptScheduleTheoremApplies := by
  rcases hSchedule with
    ⟨_,
      _,
      hProofKinds,
      _,
      hChallengeLabels,
      hOracleQueries,
      _,
      _,
      hDomain,
      hProofKindSeparation,
      hNumericQueries,
      hTheoremApplies⟩
  exact
    ⟨hProofKinds,
      hChallengeLabels,
      hOracleQueries,
      hDomain,
      hProofKindSeparation,
      hNumericQueries,
      hTheoremApplies⟩

theorem productSecurityTheorem_requires_qrom_transform_preconditions
    {preconditions : ProductPublicCoinTransformPreconditions}
    (hPreconditions :
      ProductPublicCoinTransformPreconditionsAccepted preconditions) :
    preconditions.theoremFamilyPinned
      ∧ preconditions.acceptedProofKindOrderPinned
      ∧ preconditions.publicCoinInteractiveProtocolSpecified
      ∧ preconditions.constantRoundOddMessageScheduleSpecified
      ∧ preconditions.challengeSpaceAndUniformityPinned
      ∧ preconditions.transcriptOracleEncodingInjective
      ∧ preconditions.transcriptScheduleAccepted
      ∧ preconditions.underlyingInteractiveSecurityBoundInstantiated
      ∧ preconditions.quantumOracleQueryBoundInstantiated
      ∧ preconditions.qromReductionLossInstantiated
      ∧ preconditions.transformSoundnessTheoremApplies := by
  rcases hPreconditions with
    ⟨_,
      _,
      hFamily,
      hAcceptedProofKinds,
      hInteractive,
      hRounds,
      hChallenge,
      hEncoding,
      hSchedule,
      hInteractiveSecurity,
      hQuantumQueries,
      hReductionLoss,
      hTheoremApplies⟩
  exact
    ⟨hFamily,
      hAcceptedProofKinds,
      hInteractive,
      hRounds,
      hChallenge,
      hEncoding,
      hSchedule,
      hInteractiveSecurity,
      hQuantumQueries,
      hReductionLoss,
      hTheoremApplies⟩

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
      ∧ reduction.qromReductionTheoremApplies := by
  rcases hReduction with
    ⟨_,
      _,
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
      hTheoremApplies⟩
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
      hTheoremApplies⟩

theorem productSecurityTheorem_requires_qrom_compiler_overhead_bound
    {bound : ProductQROMCompilerOverheadBound}
    (hBound : ProductQROMCompilerOverheadBoundAccepted bound) :
    (bound.selectedFamily = ProductQROMTransformFamily.ctco
        ∨ bound.selectedFamily = ProductQROMTransformFamily.merkleStraightline)
      ∧ bound.selectedDepth = 3
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
      ∧ ProductFormalAggregateUnionBound := by
  exact ⟨hDedup.1,
    hDedup.2.1,
    hDedup.2.2.1,
    hDedup.2.2.2.1,
    hDedup.2.2.2.2.1,
    hDedup.2.2.2.2.2.1,
    hDedup.2.2.2.2.2.2.1,
    hDedup.2.2.2.2.2.2.2,
    productFormalAggregateUnionBound⟩

theorem productSecurityTheorem_requires_total_loss_budget
    {budget : ProductTotalLossBudget}
    (hBudget : ProductTotalLossBudgetAccepted budget) :
    budget.selectedDepth = 3
      ∧ 0 < budget.selectedDepth
      ∧ budget.exactArithmeticPinned
      ∧ budget.qromLedgerTermMappingPinned
      ∧ budget.extractorLedgerTermMappingPinned
      ∧ budget.primitiveBatchCancellationTermIncluded
      ∧ budget.allRequiredTermsInstantiated
      ∧ budget.missingRequiredTermSetEmpty
      ∧ budget.selectedDepthLossWithinBudget
      ∧ budget.totalLossBoundInstantiated := by
  exact hBudget

theorem productSecurityTheorem_requires_exact_finite_probability_wiring
    {wiring : ProductExactFiniteProbabilityWiring}
    (hWiring : ProductExactFiniteProbabilityWiringAccepted wiring) :
    wiring.selectedDepth = 3
      ∧ 0 < wiring.selectedDepth
      ∧ wiring.dyadicRationalArithmeticPinned
      ∧ wiring.nonDyadicFiniteProtocolRationalsPinned
      ∧ wiring.zeroLossTermsRepresentedExactly
      ∧ wiring.instantiatedTermPartialSumComputed
      ∧ wiring.missingRequiredTermsKeepTotalUninstantiated
      ∧ wiring.qromTermSeparatedFromCollisionLedger
      ∧ wiring.sourceFoldRepeatedTapeExpressionExact
      ∧ wiring.terminalCE226ExpressionExact
      ∧ wiring.primitiveBatchCancellationExpressionExact
      ∧ wiring.hbindCollisionExpressionExact
      ∧ wiring.selectedDepthBudgetComparisonUsesExactRationals := by
  exact hWiring

theorem productSecurityTheorem_requires_qrom_accounting
    {publicCoin : ProductPublicCoinQROMEvidence}
    (hPublicCoin : ProductPublicCoinQROMAccepted publicCoin) :
    publicCoin.quantumOracleQueryBoundAccounted :=
  hPublicCoin.2.2.1

theorem productSecurityTheorem_requires_artifact_envelope_binding
    {bindings : ProductSystemBindings}
    (hBindings : ProductSystemBindingsAccepted bindings) :
    bindings.artifactMetadataBound ∧ bindings.proofEnvelopeHeadersBound :=
  by
    rcases hBindings with
      ⟨_, _, _, _, _, _, hArtifactMetadata, hProofEnvelopeHeaders, _⟩
    exact ⟨hArtifactMetadata, hProofEnvelopeHeaders⟩

theorem productSecurityTheorem_requires_recursive_carry_chain_root_binding
    {bindings : ProductSystemBindings}
    (hBindings : ProductSystemBindingsAccepted bindings) :
    bindings.typedRecursiveCarryRelationBound
      ∧ bindings.recursiveCarryChainRootRecurrenceBound := by
  rcases hBindings with
    ⟨_, _, _, hTypedCarry, hChainRootRecurrence, _, _, _, _⟩
  exact ⟨hTypedCarry, hChainRootRecurrence⟩

end SuperNeoFormal
