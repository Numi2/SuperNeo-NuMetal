import SuperNeoFormal.NumiSealProductTheorem
import SuperNeoFormal.ProductBadEventLedger
import SuperNeoFormal.CTCORepeatedTapeSoundness
import SuperNeoFormal.ErrorLedger
import SuperNeoFormal.PiCCSFiniteSoundness
import SuperNeoFormal.CertifiedAjtai
import SuperNeoFormal.PrimitiveVerifierConstraints
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

structure ProductNumericLossTerm where
  value : ℚ
  budget : ℚ
  nonnegative : 0 ≤ value
  withinBudget : value ≤ budget

def ProductNumericLossTermAccepted
    (term : ProductNumericLossTerm) : Prop :=
  0 ≤ term.value ∧ term.value ≤ term.budget

theorem ProductNumericLossTerm.accepted
    (term : ProductNumericLossTerm) :
    ProductNumericLossTermAccepted term :=
  ⟨term.nonnegative, term.withinBudget⟩

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
  totalLossBound : ProductNumericLossTerm

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
    ∧ ProductNumericLossTermAccepted losses.totalLossBound

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
  selectedDepthTotalLoss : ProductNumericLossTerm

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
    ∧ ProductNumericLossTermAccepted ledger.selectedDepthTotalLoss

structure ProductSelectedDepthLossClosure where
  sourceFoldLossInstantiated : Prop
  terminalSealLossInstantiated : Prop
  recursiveCarryLossInstantiated : Prop
  zkSimulatorLossInstantiated : Prop
  productOperationsReplayLossInstantiated : Prop
  constantTimeSideChannelEvidenceClosed : Prop
  selectedDepthTotalLoss : ProductNumericLossTerm

def ProductSelectedDepthLossClosureAccepted
    (closure : ProductSelectedDepthLossClosure) : Prop :=
  closure.sourceFoldLossInstantiated
    ∧ closure.terminalSealLossInstantiated
    ∧ closure.recursiveCarryLossInstantiated
    ∧ closure.zkSimulatorLossInstantiated
    ∧ closure.productOperationsReplayLossInstantiated
    ∧ closure.constantTimeSideChannelEvidenceClosed
    ∧ ProductNumericLossTermAccepted closure.selectedDepthTotalLoss

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
  totalLossBound := ledger.selectedDepthTotalLoss

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

structure ProductLocalExtractorTheorem where
  Seed : Type
  acceptedInput : Prop
  challengeSeed : Seed
  badSet : Finset Seed
  badSetCardinalityBound : Nat
  extractionConclusion : Prop
  lossBoundConclusion : Prop
  acceptedInputHolds : acceptedInput
  outsideBadSetHolds : challengeSeed ∉ badSet
  badSetCardinality : badSet.card ≤ badSetCardinalityBound
  extractOutsideBad :
    acceptedInput → challengeSeed ∉ badSet → extractionConclusion
  lossBound : lossBoundConclusion

def ProductLocalExtractorTheoremAccepted
    (extractor : ProductLocalExtractorTheorem) : Prop :=
  extractor.acceptedInput
    ∧ extractor.challengeSeed ∉ extractor.badSet
    ∧ extractor.badSet.card ≤ extractor.badSetCardinalityBound
    ∧ extractor.extractionConclusion
    ∧ extractor.lossBoundConclusion

theorem ProductLocalExtractorTheorem.accepted
    (extractor : ProductLocalExtractorTheorem) :
    ProductLocalExtractorTheoremAccepted extractor := by
  exact
    ⟨extractor.acceptedInputHolds,
      extractor.outsideBadSetHolds,
      extractor.badSetCardinality,
      extractor.extractOutsideBad
        extractor.acceptedInputHolds
        extractor.outsideBadSetHolds,
      extractor.lossBound⟩

structure ProductAcceptedProofKindExtractor where
  localExtractor : ProductLocalExtractorTheorem
  ctcoTraceBlockDependencyBound : Prop
  parentChainDependencyBound : Prop
  carryChainRootRelationBound : Prop
  ctcoTraceBlockDependency : ctcoTraceBlockDependencyBound
  parentChainDependency : parentChainDependencyBound
  carryChainRootRelation : carryChainRootRelationBound

def ProductAcceptedProofKindExtractorAccepted
    (extractor : ProductAcceptedProofKindExtractor) : Prop :=
  ProductLocalExtractorTheoremAccepted extractor.localExtractor
    ∧ extractor.ctcoTraceBlockDependencyBound
    ∧ extractor.parentChainDependencyBound
    ∧ extractor.carryChainRootRelationBound

theorem productAcceptedProofKindExtractorAccepted
    (extractor : ProductAcceptedProofKindExtractor) :
    ProductAcceptedProofKindExtractorAccepted extractor := by
  exact
    ⟨ProductLocalExtractorTheorem.accepted extractor.localExtractor,
      extractor.ctcoTraceBlockDependency,
      extractor.parentChainDependency,
      extractor.carryChainRootRelation⟩

def ProductLocalExtractorTheorem.ofTerminalCEConstructiveCertificate
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
    (lossBoundConclusion : Prop)
    (hAcceptedInput : verifyProof statement proof)
    (hOutsideBadSet : proofSeed proof ∉ certificate.badSeeds)
    (hLossBound : lossBoundConclusion) :
    ProductLocalExtractorTheorem where
  Seed := Seed
  acceptedInput := verifyProof statement proof
  challengeSeed := proofSeed proof
  badSet := certificate.badSeeds
  badSetCardinalityBound := bound
  extractionConclusion :=
    ∃ witnesses : Fin count → Witness,
      TerminalLocalBatchRelation statement witnesses opens
  lossBoundConclusion := lossBoundConclusion
  acceptedInputHolds := hAcceptedInput
  outsideBadSetHolds := hOutsideBadSet
  badSetCardinality := certificate.card_le
  extractOutsideBad := fun hVerify hSeed =>
    terminalCEConstructive_certificate_extract_outside_bad
      certificate
      hVerify
      hSeed
  lossBound := hLossBound

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
    (ctcoTraceBlockDependencyBound : Prop)
    (extractorLossContributionBound : Prop)
    (parentChainDependencyBound : Prop)
    (carryChainRootRelationBound : Prop)
    (hAcceptedInput : verifyProof statement proof)
    (hOutsideBadSet : proofSeed proof ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencyBound)
    (hExtractorLoss : extractorLossContributionBound)
    (hParentChain : parentChainDependencyBound)
    (hCarryChain : carryChainRootRelationBound) :
    ProductAcceptedProofKindExtractor where
  localExtractor :=
    ProductLocalExtractorTheorem.ofTerminalCEConstructiveCertificate
      certificate
      statement
      proof
      extractorLossContributionBound
      hAcceptedInput
      hOutsideBadSet
      hExtractorLoss
  ctcoTraceBlockDependencyBound := ctcoTraceBlockDependencyBound
  parentChainDependencyBound := parentChainDependencyBound
  carryChainRootRelationBound := carryChainRootRelationBound
  ctcoTraceBlockDependency := hCTCO
  parentChainDependency := hParentChain
  carryChainRootRelation := hCarryChain

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
    {ctcoTraceBlockDependencyBound : Prop}
    {extractorLossContributionBound : Prop}
    {parentChainDependencyBound : Prop}
    {carryChainRootRelatesToExtractedState : Prop}
    (hVerify : verifyProof statement proof)
    (hSeed : proofSeed proof ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencyBound)
    (hExtractorLoss : extractorLossContributionBound)
    (hParentChain : parentChainDependencyBound)
    (hCarryChain : carryChainRootRelatesToExtractedState) :
    ProductAcceptedProofKindExtractorAccepted
      (ProductAcceptedProofKindExtractor.ofTerminalCEConstructiveCertificate
        certificate
        statement
        proof
        ctcoTraceBlockDependencyBound
        extractorLossContributionBound
        parentChainDependencyBound
        carryChainRootRelatesToExtractedState
        hVerify
        hSeed
        hCTCO
        hExtractorLoss
        hParentChain
        hCarryChain) := by
  exact productAcceptedProofKindExtractorAccepted _

def ProductLocalExtractorTheorem.ofPiRLCConstructiveCertificate
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
    (lossBoundConclusion : Prop)
    (hAcceptedInput :
      PiRLCConcreteAccepts point seed claims folded
        ∧ foldedSound folded)
    (hOutsideBadSet : seed ∉ certificate.badSeeds)
    (hLossBound : lossBoundConclusion) :
    ProductLocalExtractorTheorem where
  Seed := PiRLCChallengeSeed count
  acceptedInput :=
    PiRLCConcreteAccepts point seed claims folded
      ∧ foldedSound folded
  challengeSeed := seed
  badSet := certificate.badSeeds
  badSetCardinalityBound := bound
  extractionConclusion := AllClaimsSound inputSound claims
  lossBoundConclusion := lossBoundConclusion
  acceptedInputHolds := hAcceptedInput
  outsideBadSetHolds := hOutsideBadSet
  badSetCardinality := certificate.card_le
  extractOutsideBad := fun hInput hSeed =>
    certificate.allInputsSound_outside_bad
      seed
      folded
      hInput.1
      hInput.2
      hSeed
  lossBound := hLossBound

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
    (ctcoTraceBlockDependencyBound : Prop)
    (extractorLossContributionBound : Prop)
    (parentChainDependencyBound : Prop)
    (carryChainRootRelationBound : Prop)
    (hAcceptedInput :
      PiRLCConcreteAccepts point seed claims folded
        ∧ foldedSound folded)
    (hOutsideBadSet : seed ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencyBound)
    (hExtractorLoss : extractorLossContributionBound)
    (hParentChain : parentChainDependencyBound)
    (hCarryChain : carryChainRootRelationBound) :
    ProductAcceptedProofKindExtractor where
  localExtractor :=
    ProductLocalExtractorTheorem.ofPiRLCConstructiveCertificate
      certificate
      seed
      folded
      extractorLossContributionBound
      hAcceptedInput
      hOutsideBadSet
      hExtractorLoss
  ctcoTraceBlockDependencyBound := ctcoTraceBlockDependencyBound
  parentChainDependencyBound := parentChainDependencyBound
  carryChainRootRelationBound := carryChainRootRelationBound
  ctcoTraceBlockDependency := hCTCO
  parentChainDependency := hParentChain
  carryChainRootRelation := hCarryChain

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
    {ctcoTraceBlockDependencyBound : Prop}
    {extractorLossContributionBound : Prop}
    {parentChainDependencyBound : Prop}
    {carryChainRootRelatesToExtractedState : Prop}
    (hAccepts : PiRLCConcreteAccepts point seed claims folded)
    (hFoldedSound : foldedSound folded)
    (hSeed : seed ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencyBound)
    (hExtractorLoss : extractorLossContributionBound)
    (hParentChain : parentChainDependencyBound)
    (hCarryChain : carryChainRootRelatesToExtractedState) :
    ProductAcceptedProofKindExtractorAccepted
      (ProductAcceptedProofKindExtractor.ofPiRLCConstructiveCertificate
        certificate
        seed
        folded
        ctcoTraceBlockDependencyBound
        extractorLossContributionBound
        parentChainDependencyBound
        carryChainRootRelatesToExtractedState
        ⟨hAccepts, hFoldedSound⟩
        hSeed
        hCTCO
        hExtractorLoss
        hParentChain
        hCarryChain) := by
  exact productAcceptedProofKindExtractorAccepted _

def ProductLocalExtractorTheorem.ofPiCCSFiniteBadChallengeCertificate
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
    (lossBoundConclusion : Prop)
    (hAcceptedInput : PiCCSAccepts state trace)
    (hOutsideBadSet : traceSeed trace ∉ certificate.badSeeds)
    (hLossBound : lossBoundConclusion) :
    ProductLocalExtractorTheorem where
  Seed := Seed
  acceptedInput := PiCCSAccepts state trace
  challengeSeed := traceSeed trace
  badSet := certificate.badSeeds
  badSetCardinalityBound := bound
  extractionConclusion := traceSound trace
  lossBoundConclusion := lossBoundConclusion
  acceptedInputHolds := hAcceptedInput
  outsideBadSetHolds := hOutsideBadSet
  badSetCardinality := certificate.card_le
  extractOutsideBad := fun hAccepts hSeed =>
    piccs_traceSound_of_seed_not_bad
      certificate
      hAccepts
      hSeed
  lossBound := hLossBound

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
    (ctcoTraceBlockDependencyBound : Prop)
    (extractorLossContributionBound : Prop)
    (parentChainDependencyBound : Prop)
    (carryChainRootRelationBound : Prop)
    (hAcceptedInput : PiCCSAccepts state trace)
    (hOutsideBadSet : traceSeed trace ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencyBound)
    (hExtractorLoss : extractorLossContributionBound)
    (hParentChain : parentChainDependencyBound)
    (hCarryChain : carryChainRootRelationBound) :
    ProductAcceptedProofKindExtractor where
  localExtractor :=
    ProductLocalExtractorTheorem.ofPiCCSFiniteBadChallengeCertificate
      certificate
      trace
      extractorLossContributionBound
      hAcceptedInput
      hOutsideBadSet
      hExtractorLoss
  ctcoTraceBlockDependencyBound := ctcoTraceBlockDependencyBound
  parentChainDependencyBound := parentChainDependencyBound
  carryChainRootRelationBound := carryChainRootRelationBound
  ctcoTraceBlockDependency := hCTCO
  parentChainDependency := hParentChain
  carryChainRootRelation := hCarryChain

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
    {ctcoTraceBlockDependencyBound : Prop}
    {extractorLossContributionBound : Prop}
    {parentChainDependencyBound : Prop}
    {carryChainRootRelatesToExtractedState : Prop}
    (hAccepts : PiCCSAccepts state trace)
    (hSeed : traceSeed trace ∉ certificate.badSeeds)
    (hCTCO : ctcoTraceBlockDependencyBound)
    (hExtractorLoss : extractorLossContributionBound)
    (hParentChain : parentChainDependencyBound)
    (hCarryChain : carryChainRootRelatesToExtractedState) :
    ProductAcceptedProofKindExtractorAccepted
      (ProductAcceptedProofKindExtractor.ofPiCCSFiniteBadChallengeCertificate
        certificate
        trace
        ctcoTraceBlockDependencyBound
        extractorLossContributionBound
        parentChainDependencyBound
        carryChainRootRelatesToExtractedState
        hAccepts
        hSeed
        hCTCO
        hExtractorLoss
        hParentChain
        hCarryChain) := by
  exact productAcceptedProofKindExtractorAccepted _

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

structure ProductVerifierAIRPredicateImplication where
  sourcePredicate : Prop
  targetPredicate : Prop
  implication : sourcePredicate → targetPredicate

def ProductVerifierAIRPredicateImplicationAccepted
    (obligation : ProductVerifierAIRPredicateImplication) : Prop :=
  obligation.sourcePredicate → obligation.targetPredicate

theorem productVerifierAIRPredicateImplicationAccepted
    (obligation : ProductVerifierAIRPredicateImplication) :
    ProductVerifierAIRPredicateImplicationAccepted obligation :=
  obligation.implication

structure ProductVerifierAIRPredicateEquivalence where
  leftPredicate : Prop
  rightPredicate : Prop
  equivalence : leftPredicate ↔ rightPredicate

def ProductVerifierAIRPredicateEquivalenceAccepted
    (obligation : ProductVerifierAIRPredicateEquivalence) : Prop :=
  obligation.leftPredicate ↔ obligation.rightPredicate

theorem productVerifierAIRPredicateEquivalenceAccepted
    (obligation : ProductVerifierAIRPredicateEquivalence) :
    ProductVerifierAIRPredicateEquivalenceAccepted obligation :=
  obligation.equivalence

def ProductPiCCSPiRLCPiDECPrimitiveLoweringTheorem : Prop :=
  ∀ {F RF : Type} [Semiring F] [CommRing RF]
    {pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount : Nat}
    (bundle :
      PiCCSPiRLCPiDECPrimitiveBundle F RF
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
        pidecRows pidecColumns pidecCount),
      PiCCSPiRLCPiDECPrimitiveConstraints bundle ↔
        PiCCSPiRLCPiDECVerifierSteps bundle

theorem productPiCCSPiRLCPiDECPrimitiveLoweringTheorem :
    ProductPiCCSPiRLCPiDECPrimitiveLoweringTheorem := by
  intro F RF _hF _hRF pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
    pirlcPointVars pidecRows pidecColumns pidecCount bundle
  exact piCCS_piRLC_piDEC_primitiveConstraints_iff_verifierSteps bundle

def ProductTerminalAIRPrimitiveFamilyScheduleTheorem : Prop :=
  ∀ {K RF : Type} [CommRing K] [CommRing RF]
    {piccsRounds
      pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount pirlcPointVars
      pidecRows pidecColumns pidecCount pidecSignedDigitCount
      pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
      ceRows ceColumns cePublicCount ceEvalCount cePointVars : Nat}
    (rows :
      TerminalAIRPrimitiveFamilyScheduledRows K RF
        piccsRounds
        pirlcCount pirlcRows pirlcPublicCount pirlcEvalCount
        pirlcPointVars
        pidecRows pidecColumns pidecCount pidecSignedDigitCount
        pidecDecompositionCount pidecPublicSplitCount pidecLowNormCount
        ceRows ceColumns cePublicCount ceEvalCount cePointVars),
      TerminalAIRPrimitiveFamilyAllScheduledRowsZero rows ↔
        PiCCSConcreteVerifierStep rows.piccsAir ∧
        PiRLCConcreteVerifierStep rows.pirlcAir ∧
        PiDECConcreteVerifierStep rows.pidecAir ∧
        CEAjtaiConcreteVerifierStep rows.ceAjtaiAir

theorem productTerminalAIRPrimitiveFamilyScheduleTheorem :
    ProductTerminalAIRPrimitiveFamilyScheduleTheorem := by
  intro K RF _hK _hRF piccsRounds pirlcCount pirlcRows pirlcPublicCount
    pirlcEvalCount pirlcPointVars pidecRows pidecColumns pidecCount
    pidecSignedDigitCount pidecDecompositionCount pidecPublicSplitCount
    pidecLowNormCount ceRows ceColumns cePublicCount ceEvalCount cePointVars
    rows
  exact terminalAIRPrimitiveFamily_allScheduledRowsZero_iff_verifierSteps rows

structure ProductTerminalVerifierArithmetization where
  relationTagPinned : Prop
  canonicalSourceEnvelopeDigestBound : Prop
  publicStatementDigestBound : Prop
  recursiveRelationDigestBound : Prop
  verifierKeyDigestBound : Prop
  terminalStatementDigestBound : Prop
  foldProofDigestBound : Prop
  ceOpeningProofDigestBound : Prop
  verifierRelationRerunsFoldReduction :
    ProductVerifierAIRPredicateImplication
  verifierRelationRerunsTerminalCEOpening :
    ProductVerifierAIRPredicateImplication
  verifierRelationRerunsPiCCS : ProductVerifierAIRPredicateImplication
  verifierRelationRerunsPiRLC : ProductVerifierAIRPredicateImplication
  verifierRelationRerunsPiDEC : ProductVerifierAIRPredicateImplication
  verifierRelationRerunsAjtaiOpening :
    ProductVerifierAIRPredicateImplication
  verifierRelationChecksModuleSISNorms :
    ProductVerifierAIRPredicateImplication
  fakeSourceDigestRejected : ProductVerifierAIRPredicateImplication
  sourceFreeSNARKStyleAcceptance : ProductVerifierAIRPredicateImplication
  sourceFreeSpartanFRIAcceptance : ProductVerifierAIRPredicateImplication
  spartanFRITraceBindsTerminalVerifierRelation :
    ProductVerifierAIRPredicateImplication
  malformedFRITraceRejected : ProductVerifierAIRPredicateImplication
  sourceFreeAcceptanceRequiresVerifierKey :
    ProductVerifierAIRPredicateImplication
  concreteVerifierConsumesCompressedProofBytes :
    ProductVerifierAIRPredicateImplication
  concreteVerifierRejectsExpandedVerifierWitness :
    ProductVerifierAIRPredicateImplication
  sourceProofBytesAbsentFromConcreteVerifier :
    ProductVerifierAIRPredicateImplication
  expandedVerifierTraceAbsentFromConcreteVerifier :
    ProductVerifierAIRPredicateImplication
  terminalVerifierTraceColumnsCommitted :
    ProductVerifierAIRPredicateImplication
  terminalVerifierBoundaryConstraintsCommitted :
    ProductVerifierAIRPredicateImplication
  terminalVerifierTransitionConstraintsCommitted :
    ProductVerifierAIRPredicateImplication
  terminalVerifierResidualPolynomialCommitted :
    ProductVerifierAIRPredicateImplication
  traceResidualPCSFRIQueriesVerified :
    ProductVerifierAIRPredicateImplication
  terminalVerifierExecutionIsProvedRelation :
    ProductVerifierAIRPredicateImplication
  terminalAcceptBitOneConstrained :
    ProductVerifierAIRPredicateImplication
  canonicalDecodingConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  hashDigestBindingsConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  piCCSVerifierConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  piRLCVerifierConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  piDECVerifierConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  terminalCEVerifierConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  friPCSVerifierConstrainedAtAIRLevel :
    ProductVerifierAIRPredicateImplication
  jointTraceResidualQueryScheduleBound :
    ProductVerifierAIRPredicateImplication
  traceResidualOpeningsPairedByQueryPoint :
    ProductVerifierAIRPredicateImplication
  residualEqualsAIRConstraintEvaluation :
    ProductVerifierAIRPredicateEquivalence
  acceptBitDerivedFromAIRConstraints :
    ProductVerifierAIRPredicateImplication
  terminalVerifierTypedAIRSubrelationsDeclared :
    ProductVerifierAIRPredicateImplication
  canonicalSourceRepresentationSubrelationConstrained :
    ProductVerifierAIRPredicateImplication
  publicBindingSubrelationConstrained :
    ProductVerifierAIRPredicateImplication
  piCCSVerifierSubrelationConstrained :
    ProductVerifierAIRPredicateImplication
  piRLCVerifierSubrelationConstrained :
    ProductVerifierAIRPredicateImplication
  piDECVerifierSubrelationConstrained :
    ProductVerifierAIRPredicateImplication
  terminalCEOpeningSubrelationConstrained :
    ProductVerifierAIRPredicateImplication
  innerCompressedProofVerifierSubrelationGatedBySourceKind :
    ProductVerifierAIRPredicateImplication
  outerFRIVerifierSeparatedFromTerminalAIR :
    ProductVerifierAIRPredicateImplication
  residualAggregationUsesTypedSubrelations :
    ProductVerifierAIRPredicateImplication
  residualPolynomialEncodesAggregateVerifierConstraints :
    ProductVerifierAIRPredicateImplication
  sharedSpecEmitsExecutableConstraintRows :
    ProductVerifierAIRPredicateImplication
  airResidualZeroIffSharedSpecAccepts :
    ProductVerifierAIRPredicateEquivalence
  normalTerminalVerifierAcceptanceEquivalentToZeroResidual :
    ProductVerifierAIRPredicateEquivalence

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
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationRerunsFoldReduction
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationRerunsTerminalCEOpening
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationRerunsPiCCS
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationRerunsPiRLC
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationRerunsPiDEC
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationRerunsAjtaiOpening
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.verifierRelationChecksModuleSISNorms
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.fakeSourceDigestRejected
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.sourceFreeSNARKStyleAcceptance
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.sourceFreeSpartanFRIAcceptance
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.spartanFRITraceBindsTerminalVerifierRelation
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.malformedFRITraceRejected
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.sourceFreeAcceptanceRequiresVerifierKey
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.concreteVerifierConsumesCompressedProofBytes
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.concreteVerifierRejectsExpandedVerifierWitness
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.sourceProofBytesAbsentFromConcreteVerifier
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.expandedVerifierTraceAbsentFromConcreteVerifier
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalVerifierTraceColumnsCommitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalVerifierBoundaryConstraintsCommitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalVerifierTransitionConstraintsCommitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalVerifierResidualPolynomialCommitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.traceResidualPCSFRIQueriesVerified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalVerifierExecutionIsProvedRelation
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalAcceptBitOneConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.canonicalDecodingConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.hashDigestBindingsConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.piCCSVerifierConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.piRLCVerifierConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.piDECVerifierConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalCEVerifierConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.friPCSVerifierConstrainedAtAIRLevel
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.jointTraceResidualQueryScheduleBound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.traceResidualOpeningsPairedByQueryPoint
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      arith.residualEqualsAIRConstraintEvaluation
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.acceptBitDerivedFromAIRConstraints
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalVerifierTypedAIRSubrelationsDeclared
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.canonicalSourceRepresentationSubrelationConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.publicBindingSubrelationConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.piCCSVerifierSubrelationConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.piRLCVerifierSubrelationConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.piDECVerifierSubrelationConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.terminalCEOpeningSubrelationConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.innerCompressedProofVerifierSubrelationGatedBySourceKind
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.outerFRIVerifierSeparatedFromTerminalAIR
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.residualAggregationUsesTypedSubrelations
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.residualPolynomialEncodesAggregateVerifierConstraints
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      arith.sharedSpecEmitsExecutableConstraintRows
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      arith.airResidualZeroIffSharedSpecAccepts
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      arith.normalTerminalVerifierAcceptanceEquivalentToZeroResidual

theorem productCompressionSourceFree_from_terminalVerifierArithmetization
    {arith : ProductTerminalVerifierArithmetization}
    (hArith : ProductTerminalVerifierArithmetizationAccepted arith) :
    ProductVerifierAIRPredicateImplicationAccepted
        arith.sourceFreeSNARKStyleAcceptance
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.sourceFreeSpartanFRIAcceptance
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.concreteVerifierConsumesCompressedProofBytes
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.sourceProofBytesAbsentFromConcreteVerifier
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.concreteVerifierRejectsExpandedVerifierWitness
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.expandedVerifierTraceAbsentFromConcreteVerifier
      ∧ arith.canonicalSourceEnvelopeDigestBound
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationRerunsFoldReduction
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationRerunsPiCCS
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationRerunsPiRLC
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationRerunsPiDEC
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationRerunsAjtaiOpening
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationChecksModuleSISNorms
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.verifierRelationRerunsTerminalCEOpening
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.spartanFRITraceBindsTerminalVerifierRelation
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.terminalVerifierTraceColumnsCommitted
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.terminalVerifierBoundaryConstraintsCommitted
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.terminalVerifierTransitionConstraintsCommitted
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.terminalVerifierResidualPolynomialCommitted
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.traceResidualPCSFRIQueriesVerified
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.terminalVerifierExecutionIsProvedRelation
      ∧ ProductVerifierAIRPredicateImplicationAccepted
        arith.terminalAcceptBitOneConstrained := by
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
  sharedByNormalTerminalVerifierAndAIR :
    ProductVerifierAIRPredicateEquivalence
  canonicalSourceDecodingSpecified :
    ProductVerifierAIRPredicateImplication
  sourceDigestComputedFromCanonicalPrivateEncoding :
    ProductVerifierAIRPredicateImplication
  sourceByteCountBoundToCanonicalEncoding :
    ProductVerifierAIRPredicateImplication
  verifierKeyBindingSpecified : ProductVerifierAIRPredicateImplication
  publicStatementBindingSpecified :
    ProductVerifierAIRPredicateImplication
  recursiveRelationDigestPublicInput :
    ProductVerifierAIRPredicateImplication
  compressionPolicyBindingSpecified :
    ProductVerifierAIRPredicateImplication
  publicCoinDerivationVerifierBound :
    ProductVerifierAIRPredicateImplication
  piCCSVerifierEquationSpecified :
    ProductVerifierAIRPredicateImplication
  piRLCVerifierEquationSpecified :
    ProductVerifierAIRPredicateImplication
  piDECVerifierEquationSpecified :
    ProductVerifierAIRPredicateImplication
  terminalCEOpeningArithmeticSpecified :
    ProductVerifierAIRPredicateImplication
  ceAjtaiArithmeticConstrained :
    ProductVerifierAIRPredicateImplication
  moduleSISNormAndShapeChecksSpecified :
    ProductVerifierAIRPredicateImplication
  optionalInnerCompressedVerifierDomainSeparated :
    ProductVerifierAIRPredicateImplication
  concreteVerifierDoesNotAcceptExpandedWitness :
    ProductVerifierAIRPredicateImplication
  acceptBitDerivedFromSpecPredicates :
    ProductVerifierAIRPredicateImplication
  emitsNormalResultAndAIRConstraintRowsFromSameSteps :
    ProductVerifierAIRPredicateImplication
  noAssertedStageAcceptanceFlags :
    ProductVerifierAIRPredicateImplication
  digestAndCoinComputationsConstraintEmitted :
    ProductVerifierAIRPredicateImplication
  ceAjtaiArithmeticConstraintEmitted :
    ProductVerifierAIRPredicateImplication
  primitiveRowsHaveInspectableProvenance :
    ProductVerifierAIRPredicateImplication
  ceAjtaiLoweredToPrimitiveRows :
    ProductVerifierAIRPredicateImplication
  foldBoundariesLoweredToPrimitiveRows :
    ProductVerifierAIRPredicateImplication
  noVerifierBooleanWrappingRows :
    ProductVerifierAIRPredicateImplication
  noBoundaryReportAcceptanceRows :
    ProductVerifierAIRPredicateImplication
  digestRowsHashOrPublicBound :
    ProductVerifierAIRPredicateImplication
  compactBatchingCommitsFullPrimitiveRowSet :
    ProductVerifierAIRPredicateImplication
  compactBatchingChallengesAfterRowTranscriptCommitment :
    ProductVerifierAIRPredicateImplication
  compactBatchResidualAggregatesAllPrimitiveRows :
    ProductVerifierAIRPredicateImplication
  compactBatchSamplesAreAuditOnly :
    ProductVerifierAIRPredicateImplication
  compactBatchTranscriptBindsPublicContext :
    ProductVerifierAIRPredicateImplication
  zeroResidualIffSpecAccepts : ProductVerifierAIRPredicateEquivalence

def ProductTerminalVerifierAIRSpecAccepted
    (spec : ProductTerminalVerifierAIRSpec) : Prop :=
  ProductVerifierAIRPredicateEquivalenceAccepted
      spec.sharedByNormalTerminalVerifierAndAIR
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.canonicalSourceDecodingSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.sourceDigestComputedFromCanonicalPrivateEncoding
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.sourceByteCountBoundToCanonicalEncoding
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.verifierKeyBindingSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.publicStatementBindingSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.recursiveRelationDigestPublicInput
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.compressionPolicyBindingSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.publicCoinDerivationVerifierBound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.piCCSVerifierEquationSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.piRLCVerifierEquationSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.piDECVerifierEquationSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.terminalCEOpeningArithmeticSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.ceAjtaiArithmeticConstrained
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.moduleSISNormAndShapeChecksSpecified
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.optionalInnerCompressedVerifierDomainSeparated
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.concreteVerifierDoesNotAcceptExpandedWitness
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.acceptBitDerivedFromSpecPredicates
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.emitsNormalResultAndAIRConstraintRowsFromSameSteps
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.noAssertedStageAcceptanceFlags
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.digestAndCoinComputationsConstraintEmitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.ceAjtaiArithmeticConstraintEmitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.primitiveRowsHaveInspectableProvenance
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.ceAjtaiLoweredToPrimitiveRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.foldBoundariesLoweredToPrimitiveRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.noVerifierBooleanWrappingRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.noBoundaryReportAcceptanceRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.digestRowsHashOrPublicBound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.compactBatchingCommitsFullPrimitiveRowSet
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.compactBatchingChallengesAfterRowTranscriptCommitment
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.compactBatchResidualAggregatesAllPrimitiveRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.compactBatchSamplesAreAuditOnly
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      spec.compactBatchTranscriptBindsPublicContext
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      spec.zeroResidualIffSpecAccepts

structure ProductTerminalVerifierAIRConstraintExactness where
  spec : ProductTerminalVerifierAIRSpec
  arithmetization : ProductTerminalVerifierArithmetization
  sharedVerifierStepsEmitNormalResultAndAIRRows :
    ProductVerifierAIRPredicateEquivalence
  noAssertedStageShortcuts : ProductVerifierAIRPredicateImplication
  digestAndPublicCoinExactness : ProductVerifierAIRPredicateEquivalence
  ceAjtaiArithmeticExactness : ProductVerifierAIRPredicateEquivalence
  primitiveConstraintLoweringExactness :
    ProductVerifierAIRPredicateEquivalence
  rowProvenanceTypedAndInspectable :
    ProductVerifierAIRPredicateImplication
  acceptBitDerivedFromResidualAggregate :
    ProductVerifierAIRPredicateImplication
  compactBatchingEquivalentToFullPrimitiveRows :
    ProductVerifierAIRPredicateEquivalence
  airResidualZeroIffSharedSpecAccepts :
    ProductVerifierAIRPredicateEquivalence

def ProductTerminalVerifierAIRConstraintExactnessAccepted
    (exactness : ProductTerminalVerifierAIRConstraintExactness) : Prop :=
  ProductTerminalVerifierAIRSpecAccepted exactness.spec
    ∧ ProductTerminalVerifierArithmetizationAccepted exactness.arithmetization
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      exactness.sharedVerifierStepsEmitNormalResultAndAIRRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      exactness.noAssertedStageShortcuts
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      exactness.digestAndPublicCoinExactness
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      exactness.ceAjtaiArithmeticExactness
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      exactness.primitiveConstraintLoweringExactness
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      exactness.rowProvenanceTypedAndInspectable
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      exactness.acceptBitDerivedFromResidualAggregate
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      exactness.compactBatchingEquivalentToFullPrimitiveRows
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      exactness.airResidualZeroIffSharedSpecAccepts

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
  primitiveConstraintsIffVerifierSteps :
    ProductPiCCSPiRLCPiDECPrimitiveLoweringTheorem
  scheduledRowsZeroIffVerifierSteps :
    ProductTerminalAIRPrimitiveFamilyScheduleTheorem
  ceAjtaiRowsEmitCanonicalCoefficientDecoding :
    ProductVerifierAIRPredicateImplication
  ceAjtaiRowsEmitDimensionChecks : ProductVerifierAIRPredicateImplication
  ceAjtaiRowsEmitMatrixVectorMultiplication :
    ProductVerifierAIRPredicateImplication
  ceAjtaiRowsEmitCommitmentEquality :
    ProductVerifierAIRPredicateImplication
  ceAjtaiRowsEmitNormAndShapeChecks :
    ProductVerifierAIRPredicateImplication
  piCCSRowsEmitProjectionSumcheckAndFinalClaimConstraints :
    ProductVerifierAIRPredicateImplication
  piRLCRowsEmitCoinLinearCombinationAndParentPointConstraints :
    ProductVerifierAIRPredicateImplication
  piDECRowsEmitDigitBoundsRecompositionAndLowNormConstraints :
    ProductVerifierAIRPredicateImplication
  digestRowsAreHashSubrelationsOrPublicBindings :
    ProductVerifierAIRPredicateImplication
  noRowsSourcedFromVerifierBooleansOrBoundaryReportAcceptance :
    ProductVerifierAIRPredicateImplication
  compactRowsEncodePrimitiveRowIndexResidualAndContext :
    ProductVerifierAIRPredicateImplication
  fullRowTranscriptCommittedBeforeBatchChallenges :
    ProductVerifierAIRPredicateImplication
  aggregateResidualCoversEveryCommittedPrimitiveRow :
    ProductVerifierAIRPredicateImplication
  sampledPrimitiveRowsNotUsedAsSoundnessSubstitute :
    ProductVerifierAIRPredicateImplication

def ProductTerminalVerifierAIRPrimitiveLoweringAccepted
    (lowering : ProductTerminalVerifierAIRPrimitiveLowering) : Prop :=
  ProductTerminalVerifierAIRConstraintExactnessAccepted lowering.exactness
    ∧ ProductPiCCSPiRLCPiDECPrimitiveLoweringTheorem
    ∧ ProductTerminalAIRPrimitiveFamilyScheduleTheorem
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.ceAjtaiRowsEmitCanonicalCoefficientDecoding
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.ceAjtaiRowsEmitDimensionChecks
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.ceAjtaiRowsEmitMatrixVectorMultiplication
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.ceAjtaiRowsEmitCommitmentEquality
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.ceAjtaiRowsEmitNormAndShapeChecks
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.piCCSRowsEmitProjectionSumcheckAndFinalClaimConstraints
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.piRLCRowsEmitCoinLinearCombinationAndParentPointConstraints
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.piDECRowsEmitDigitBoundsRecompositionAndLowNormConstraints
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.digestRowsAreHashSubrelationsOrPublicBindings
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.noRowsSourcedFromVerifierBooleansOrBoundaryReportAcceptance
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.compactRowsEncodePrimitiveRowIndexResidualAndContext
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.fullRowTranscriptCommittedBeforeBatchChallenges
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.aggregateResidualCoversEveryCommittedPrimitiveRow
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      lowering.sampledPrimitiveRowsNotUsedAsSoundnessSubstitute

def ProductPrimitiveBatchLaneCountSelected (laneCount : Nat) : Prop :=
  laneCount = 4

structure ProductTerminalAIRPrimitiveBatchMultiLane where
  selectedPrimitiveBatchLaneCount : Nat
  batchResidualLaneCount : Nat
  selectedLaneCountPinned :
    ProductPrimitiveBatchLaneCountSelected selectedPrimitiveBatchLaneCount
  proofCarriesEveryLaneResidual : ProductVerifierAIRPredicateImplication
  verifierRequiresEveryLaneResidualZero :
    ProductVerifierAIRPredicateImplication
  noLaneIsAuditOnly : ProductVerifierAIRPredicateImplication
  rowTranscriptBindsBatchLaneCount :
    ProductVerifierAIRPredicateImplication
  challengeTranscriptBindsBatchLaneCount :
    ProductVerifierAIRPredicateImplication
  airTraceBindsAllLaneResiduals : ProductVerifierAIRPredicateImplication
  pcsFriBindsAllLaneResiduals : ProductVerifierAIRPredicateImplication

def ProductTerminalAIRPrimitiveBatchMultiLaneAccepted
    (multiLane : ProductTerminalAIRPrimitiveBatchMultiLane) : Prop :=
  ProductPrimitiveBatchLaneCountSelected multiLane.selectedPrimitiveBatchLaneCount
    ∧ multiLane.batchResidualLaneCount = multiLane.selectedPrimitiveBatchLaneCount
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      multiLane.proofCarriesEveryLaneResidual
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      multiLane.verifierRequiresEveryLaneResidualZero
    ∧ ProductVerifierAIRPredicateImplicationAccepted multiLane.noLaneIsAuditOnly
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      multiLane.rowTranscriptBindsBatchLaneCount
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      multiLane.challengeTranscriptBindsBatchLaneCount
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      multiLane.airTraceBindsAllLaneResiduals
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      multiLane.pcsFriBindsAllLaneResiduals

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
  cancellationEventBoundedByBatchContextCountOverQPowFour :
    ProductVerifierAIRPredicateImplication

def ProductPrimitiveBatchCancellationBoundAccepted
    (bound : ProductPrimitiveBatchCancellationBound) : Prop :=
  bound.goldilocksModulus = 18446744069414584321
    ∧ 0 < bound.batchContextCount
    ∧ ProductPrimitiveBatchLaneCountSelected bound.selectedPrimitiveBatchLaneCount
    ∧ bound.numerator = bound.batchContextCount
    ∧ bound.denominator = bound.goldilocksModulus ^ bound.selectedPrimitiveBatchLaneCount
    ∧ bound.denominator = bound.goldilocksModulus ^ 4
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      bound.cancellationEventBoundedByBatchContextCountOverQPowFour

structure ProductTerminalVerifierAIRPrimitiveBatching where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  multiLane : ProductTerminalAIRPrimitiveBatchMultiLane
  cancellationBound : ProductPrimitiveBatchCancellationBound
  everyPrimitiveRowCanonicallyEncoded :
    ProductVerifierAIRPredicateImplication
  fullPrimitiveRowTranscriptCommitted :
    ProductVerifierAIRPredicateImplication
  noOmittedRowsOrDuplicateRowIndices :
    ProductVerifierAIRPredicateImplication
  batchingChallengesDerivedAfterTranscriptCommitment :
    ProductVerifierAIRPredicateImplication
  batchingCoefficientsRejectionSampledGoldilocksFieldElements :
    ProductVerifierAIRPredicateImplication
  batchingBadEventBoundChargedOverGoldilocksFieldSize :
    ProductVerifierAIRPredicateImplication
  batchingBadEventBoundChargedOverQFourthPower :
    ProductVerifierAIRPredicateImplication
  aggregateResidualCoversAllPrimitiveRows :
    ProductVerifierAIRPredicateImplication
  aggregateResidualCoversAllPrimitiveRowsAndAllBatchLanes :
    ProductVerifierAIRPredicateImplication
  sampledRowsAreAuditOnly : ProductVerifierAIRPredicateImplication
  aggregateResidualBoundIntoPCSFRI :
    ProductVerifierAIRPredicateImplication
  allLaneResidualsBoundIntoPCSFRI :
    ProductVerifierAIRPredicateImplication
  rowTranscriptBindsTerminalVerifierRelationDigest :
    ProductVerifierAIRPredicateImplication
  rowTranscriptBindsRecursiveRelationDigest :
    ProductVerifierAIRPredicateImplication
  rowTranscriptBindsSourceDigestAndByteCount :
    ProductVerifierAIRPredicateImplication
  rowTranscriptBindsPrimitiveBatchLaneCount :
    ProductVerifierAIRPredicateImplication
  proofBytesBindPrimitiveBatchLaneCount :
    ProductVerifierAIRPredicateImplication

def ProductTerminalVerifierAIRPrimitiveBatchingAccepted
    (batching : ProductTerminalVerifierAIRPrimitiveBatching) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted batching.lowering
    ∧ ProductTerminalAIRPrimitiveBatchMultiLaneAccepted batching.multiLane
    ∧ ProductPrimitiveBatchCancellationBoundAccepted batching.cancellationBound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.everyPrimitiveRowCanonicallyEncoded
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.fullPrimitiveRowTranscriptCommitted
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.noOmittedRowsOrDuplicateRowIndices
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.batchingChallengesDerivedAfterTranscriptCommitment
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.batchingCoefficientsRejectionSampledGoldilocksFieldElements
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.batchingBadEventBoundChargedOverGoldilocksFieldSize
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.batchingBadEventBoundChargedOverQFourthPower
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.aggregateResidualCoversAllPrimitiveRows
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.aggregateResidualCoversAllPrimitiveRowsAndAllBatchLanes
    ∧ ProductVerifierAIRPredicateImplicationAccepted batching.sampledRowsAreAuditOnly
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.aggregateResidualBoundIntoPCSFRI
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.allLaneResidualsBoundIntoPCSFRI
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.rowTranscriptBindsTerminalVerifierRelationDigest
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.rowTranscriptBindsRecursiveRelationDigest
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.rowTranscriptBindsSourceDigestAndByteCount
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.rowTranscriptBindsPrimitiveBatchLaneCount
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      batching.proofBytesBindPrimitiveBatchLaneCount

structure ProductAIRRowsNoVerifierBooleanWrapping where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  verifierBooleanRowsRejectedByValidator :
    ProductVerifierAIRPredicateImplication
  boundaryReportAcceptanceRowsRejectedByValidator :
    ProductVerifierAIRPredicateImplication
  stageAcceptedFlagsRejectedByValidator :
    ProductVerifierAIRPredicateImplication
  digestMatchBooleansRejectedWithoutHashOrPublicBinding :
    ProductVerifierAIRPredicateImplication

def ProductAIRRowsNoVerifierBooleanWrappingAccepted
    (rows : ProductAIRRowsNoVerifierBooleanWrapping) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted rows.lowering
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      rows.verifierBooleanRowsRejectedByValidator
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      rows.boundaryReportAcceptanceRowsRejectedByValidator
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      rows.stageAcceptedFlagsRejectedByValidator
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      rows.digestMatchBooleansRejectedWithoutHashOrPublicBinding

structure ProductCEAjtaiPrimitiveConstraintSoundness where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  canonicalCoefficientDecodingSound :
    ProductVerifierAIRPredicateImplication
  moduleRingDimensionChecksSound : ProductVerifierAIRPredicateImplication
  ajtaiMatrixVectorMultiplicationSound :
    ProductVerifierAIRPredicateImplication
  commitmentEqualitySound : ProductVerifierAIRPredicateImplication
  normAndShapeChecksSound : ProductVerifierAIRPredicateImplication
  malformedAlternativeOpeningsRejected :
    ProductVerifierAIRPredicateImplication

def ProductCEAjtaiPrimitiveConstraintSoundnessAccepted
    (soundness : ProductCEAjtaiPrimitiveConstraintSoundness) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted soundness.lowering
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.canonicalCoefficientDecodingSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.moduleRingDimensionChecksSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.ajtaiMatrixVectorMultiplicationSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.commitmentEqualitySound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.normAndShapeChecksSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.malformedAlternativeOpeningsRejected

structure ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundness where
  lowering : ProductTerminalVerifierAIRPrimitiveLowering
  piCCSProjectionAndSumcheckSound :
    ProductVerifierAIRPredicateImplication
  piRLCPublicCoinAndLinearCombinationSound :
    ProductVerifierAIRPredicateImplication
  piRLCPerParentEvaluationPointSound :
    ProductVerifierAIRPredicateImplication
  piDECDecompositionAndRecompositionSound :
    ProductVerifierAIRPredicateImplication
  piDECLowNormAndPublicInputSplitSound :
    ProductVerifierAIRPredicateImplication

def ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundnessAccepted
    (soundness : ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundness) : Prop :=
  ProductTerminalVerifierAIRPrimitiveLoweringAccepted soundness.lowering
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.piCCSProjectionAndSumcheckSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.piRLCPublicCoinAndLinearCombinationSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.piRLCPerParentEvaluationPointSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.piDECDecompositionAndRecompositionSound
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.piDECLowNormAndPublicInputSplitSound

structure ProductTerminalVerifierAIRNoWitnessEscape where
  spec : ProductTerminalVerifierAIRSpec
  arithmetization : ProductTerminalVerifierArithmetization
  specRejectsExpandedWitness :
    ProductVerifierAIRPredicateImplication
  arithRejectsExpandedWitness :
    ProductVerifierAIRPredicateImplication
  sourceProofBytesAbsent : ProductVerifierAIRPredicateImplication
  expandedTraceAbsent : ProductVerifierAIRPredicateImplication
  sourceFreeAcceptImpliesCompressedProofPath :
    ProductVerifierAIRPredicateImplication
  specRejectsExpandedWitnessMatches :
    specRejectsExpandedWitness =
      spec.concreteVerifierDoesNotAcceptExpandedWitness
  arithRejectsExpandedWitnessMatches :
    arithRejectsExpandedWitness =
      arithmetization.concreteVerifierRejectsExpandedVerifierWitness
  sourceProofBytesAbsentMatches :
    sourceProofBytesAbsent =
      arithmetization.sourceProofBytesAbsentFromConcreteVerifier
  expandedTraceAbsentMatches :
    expandedTraceAbsent =
      arithmetization.expandedVerifierTraceAbsentFromConcreteVerifier
  compressedProofPathMatches :
    sourceFreeAcceptImpliesCompressedProofPath =
      arithmetization.concreteVerifierConsumesCompressedProofBytes

def ProductTerminalVerifierAIRNoWitnessEscapeAccepted
    (escape : ProductTerminalVerifierAIRNoWitnessEscape) : Prop :=
  ProductTerminalVerifierAIRSpecAccepted escape.spec
    ∧ ProductTerminalVerifierArithmetizationAccepted escape.arithmetization
    ∧ escape.specRejectsExpandedWitness =
      escape.spec.concreteVerifierDoesNotAcceptExpandedWitness
    ∧ escape.arithRejectsExpandedWitness =
      escape.arithmetization.concreteVerifierRejectsExpandedVerifierWitness
    ∧ escape.sourceProofBytesAbsent =
      escape.arithmetization.sourceProofBytesAbsentFromConcreteVerifier
    ∧ escape.expandedTraceAbsent =
      escape.arithmetization.expandedVerifierTraceAbsentFromConcreteVerifier
    ∧ escape.sourceFreeAcceptImpliesCompressedProofPath =
      escape.arithmetization.concreteVerifierConsumesCompressedProofBytes
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      escape.specRejectsExpandedWitness
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      escape.arithRejectsExpandedWitness
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      escape.sourceProofBytesAbsent
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      escape.expandedTraceAbsent
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      escape.sourceFreeAcceptImpliesCompressedProofPath

structure ProductTerminalVerifierAIRSoundness where
  spec : ProductTerminalVerifierAIRSpec
  arithmetization : ProductTerminalVerifierArithmetization
  exactness : ProductTerminalVerifierAIRConstraintExactness
  residualCompleteness : ProductTerminalVerifierAIRResidualCompleteness
  residualSoundness : ProductTerminalVerifierAIRResidualSoundness
  primitiveLowering : ProductTerminalVerifierAIRPrimitiveLowering
  primitiveBatching : ProductTerminalVerifierAIRPrimitiveBatching
  noWitnessEscape : ProductTerminalVerifierAIRNoWitnessEscape
  zeroResidualImpliesSpecAcceptBit :
    ProductVerifierAIRPredicateImplication
  airAcceptBitImpliesNormalTerminalAccept :
    ProductVerifierAIRPredicateImplication
  sourceDigestComputationProvenInAIR :
    ProductVerifierAIRPredicateImplication
  publicCoinDerivationConstrainedInAIR :
    ProductVerifierAIRPredicateImplication
  ceAjtaiArithmeticNotDigestOnly :
    ProductVerifierAIRPredicateImplication
  recursiveRelationDigestPublicBoundInAIR :
    ProductVerifierAIRPredicateImplication
  exactnessSpecMatches : exactness.spec = spec
  exactnessArithmetizationMatches :
    exactness.arithmetization = arithmetization
  residualCompletenessExactnessMatches :
    residualCompleteness.exactness = exactness
  residualSoundnessExactnessMatches :
    residualSoundness.exactness = exactness
  primitiveLoweringExactnessMatches :
    primitiveLowering.exactness = exactness
  primitiveBatchingLoweringMatches :
    primitiveBatching.lowering = primitiveLowering
  noWitnessEscapeSpecMatches : noWitnessEscape.spec = spec
  noWitnessEscapeArithmetizationMatches :
    noWitnessEscape.arithmetization = arithmetization

def ProductTerminalVerifierAIRSoundnessAccepted
    (soundness : ProductTerminalVerifierAIRSoundness) : Prop :=
  ProductTerminalVerifierAIRSpecAccepted soundness.spec
    ∧ ProductTerminalVerifierArithmetizationAccepted soundness.arithmetization
    ∧ ProductTerminalVerifierAIRConstraintExactnessAccepted soundness.exactness
    ∧ ProductTerminalVerifierAIRResidualCompletenessAccepted
      soundness.residualCompleteness
    ∧ ProductTerminalVerifierAIRResidualSoundnessAccepted
      soundness.residualSoundness
    ∧ ProductTerminalVerifierAIRPrimitiveLoweringAccepted
      soundness.primitiveLowering
    ∧ ProductTerminalVerifierAIRPrimitiveBatchingAccepted
      soundness.primitiveBatching
    ∧ ProductTerminalVerifierAIRNoWitnessEscapeAccepted
      soundness.noWitnessEscape
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.zeroResidualImpliesSpecAcceptBit
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.airAcceptBitImpliesNormalTerminalAccept
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.sourceDigestComputationProvenInAIR
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.publicCoinDerivationConstrainedInAIR
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.ceAjtaiArithmeticNotDigestOnly
    ∧ ProductVerifierAIRPredicateImplicationAccepted
      soundness.recursiveRelationDigestPublicBoundInAIR
    ∧ soundness.exactness.spec = soundness.spec
    ∧ soundness.exactness.arithmetization = soundness.arithmetization
    ∧ soundness.residualCompleteness.exactness = soundness.exactness
    ∧ soundness.residualSoundness.exactness = soundness.exactness
    ∧ soundness.primitiveLowering.exactness = soundness.exactness
    ∧ soundness.primitiveBatching.lowering = soundness.primitiveLowering
    ∧ soundness.noWitnessEscape.spec = soundness.spec
    ∧ soundness.noWitnessEscape.arithmetization = soundness.arithmetization

structure ProductSourceFreeCompressionImpliesTerminalAcceptance where
  soundness : ProductTerminalVerifierAIRSoundness
  sourceFreeCompressedVerifyAccepts : Prop
  normalTerminalVerifierAcceptsBoundSource : Prop
  sameVerifierKey : ProductVerifierAIRPredicateEquivalence
  samePublicStatement : ProductVerifierAIRPredicateEquivalence
  sameRecursiveRelationDigest : ProductVerifierAIRPredicateEquivalence
  samePolicy : ProductVerifierAIRPredicateEquivalence
  sameSourceDigest : ProductVerifierAIRPredicateEquivalence
  sameSourceByteCount : ProductVerifierAIRPredicateEquivalence

def ProductSourceFreeCompressionImpliesTerminalAcceptanceAccepted
    (impl : ProductSourceFreeCompressionImpliesTerminalAcceptance) : Prop :=
  ProductTerminalVerifierAIRSoundnessAccepted impl.soundness
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted impl.sameVerifierKey
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted impl.samePublicStatement
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted
      impl.sameRecursiveRelationDigest
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted impl.samePolicy
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted impl.sameSourceDigest
    ∧ ProductVerifierAIRPredicateEquivalenceAccepted impl.sameSourceByteCount
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
  sourceFoldExtractorAccepted : Prop
  terminalSealExtractorAccepted : Prop
  productEnvelopeExtractorClosed : Prop
  recursiveCarryExtractorAccepted : Prop
  perKindExtractorTheorems : ProductPerKindExtractorTheorems
  recursiveCarryChainRootRecurrence :
    ProductRecursiveCarryChainRootRecurrence
  rewindScheduleBoundToTranscript : Prop
  extractorFailureLossAccounted : Prop
  extractorLossBound : ProductNumericLossTerm

def ProductExtractorLossAccountingAccepted
    (accounting : ProductExtractorLossAccounting) : Prop :=
  accounting.selectedDepth = 3
    ∧ (0 < accounting.selectedDepth)
    ∧ accounting.acceptedLayerBounded
    ∧ accounting.sourceFoldExtractorAccepted
    ∧ accounting.terminalSealExtractorAccepted
    ∧ accounting.productEnvelopeExtractorClosed
    ∧ accounting.recursiveCarryExtractorAccepted
    ∧ ProductPerKindExtractorTheoremsAccepted accounting.perKindExtractorTheorems
    ∧ ProductRecursiveCarryChainRootRecurrenceAccepted
      accounting.recursiveCarryChainRootRecurrence
    ∧ accounting.rewindScheduleBoundToTranscript
    ∧ accounting.extractorFailureLossAccounted
    ∧ ProductNumericLossTermAccepted accounting.extractorLossBound

structure ProductExtractorLossClosure where
  acceptedLayerBounded : Prop
  rewindScheduleBoundToTranscript : Prop
  extractorFailureLossAccounted : Prop
  extractorLossBound : ProductNumericLossTerm

def ProductExtractorLossClosureAccepted
    (closure : ProductExtractorLossClosure) : Prop :=
  closure.acceptedLayerBounded
    ∧ closure.rewindScheduleBoundToTranscript
    ∧ closure.extractorFailureLossAccounted
    ∧ ProductNumericLossTermAccepted closure.extractorLossBound

def ProductExtractorLossAccounting.ofAcceptedComponents
    (perKindExtractorTheorems : ProductPerKindExtractorTheorems)
    (recursiveCarryChainRootRecurrence :
      ProductRecursiveCarryChainRootRecurrence)
    (closure : ProductExtractorLossClosure) :
    ProductExtractorLossAccounting where
  selectedDepth := 3
  selectedDepthPositive := show 0 < 3 by decide
  acceptedLayerBounded := closure.acceptedLayerBounded
  sourceFoldExtractorAccepted :=
    ProductAcceptedProofKindExtractorAccepted
      perKindExtractorTheorems.fold
  terminalSealExtractorAccepted :=
    ProductAcceptedProofKindExtractorAccepted
      perKindExtractorTheorems.terminal
  productEnvelopeExtractorClosed :=
    ProductPerKindExtractorTheoremsAccepted perKindExtractorTheorems
  recursiveCarryExtractorAccepted :=
    ProductAcceptedProofKindExtractorAccepted
      perKindExtractorTheorems.recursiveCarryDepthLeThree
  perKindExtractorTheorems := perKindExtractorTheorems
  recursiveCarryChainRootRecurrence := recursiveCarryChainRootRecurrence
  rewindScheduleBoundToTranscript :=
    closure.rewindScheduleBoundToTranscript
  extractorFailureLossAccounted := closure.extractorFailureLossAccounted
  extractorLossBound := closure.extractorLossBound

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

structure ProductQROMOracleModelAssumptions where
  splitOracleModelPinned : Prop
  hashQROInstantiationAssumptionPinned : Prop
  idealSplitQROModelPinned : Prop
  onlineExtractabilityAssumptionPinned : Prop
  hashModelGapSeparated : Prop
  hashModelGapZeroInIdealSplitQRO : Prop

def ProductQROMOracleModelAssumptionsAccepted
    (assumptions : ProductQROMOracleModelAssumptions) : Prop :=
  assumptions.splitOracleModelPinned
    ∧ assumptions.hashQROInstantiationAssumptionPinned
    ∧ assumptions.idealSplitQROModelPinned
    ∧ assumptions.onlineExtractabilityAssumptionPinned
    ∧ assumptions.hashModelGapSeparated
    ∧ assumptions.hashModelGapZeroInIdealSplitQRO

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
  oracleModelAssumptions : ProductQROMOracleModelAssumptions

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
    ∧ ProductQROMOracleModelAssumptionsAccepted
      hashes.oracleModelAssumptions

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
    (oracleModelAssumptions : ProductQROMOracleModelAssumptions) :
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
  oracleModelAssumptions := oracleModelAssumptions

theorem productHashOracleInstantiationAccepted_of_serializationFacts
    {splitOraclesPinned : Prop}
    {theoremCriticalBindingsUseHBind : Prop}
    {concreteHashRecommendationPinned : Prop}
    {oracleModelAssumptions : ProductQROMOracleModelAssumptions}
    (hSplitOracles : splitOraclesPinned)
    (hHBind : theoremCriticalBindingsUseHBind)
    (hHashRecommendation : concreteHashRecommendationPinned)
    (hOracleModel :
      ProductQROMOracleModelAssumptionsAccepted oracleModelAssumptions) :
    ProductHashOracleInstantiationAccepted
      (ProductHashOracleInstantiation.ofSerializationFacts
        splitOraclesPinned
        theoremCriticalBindingsUseHBind
        concreteHashRecommendationPinned
        oracleModelAssumptions) :=
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
    hOracleModel⟩

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
  qromLossBound : ProductNumericLossTerm
  hashModelGapZeroInIdealSplitQRO : Prop
  compilerOverheadWithinBudget : Prop
  qromExtraLossOnly : Prop
  collisionLedgerIntegrated : Prop
  cryptographicSliceWithinBudget : Prop
  auxiliaryLedgerTermsAccounted : Prop

def ProductQROMTotalLossInstantiatedAccepted
    (loss : ProductQROMTotalLossInstantiated) : Prop :=
  ProductNumericLossTermAccepted loss.qromLossBound
    ∧ loss.hashModelGapZeroInIdealSplitQRO
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
    (oracleModelAssumptions : ProductQROMOracleModelAssumptions)
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
      oracleModelAssumptions
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
        oracleModelAssumptions)
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
    {oracleModelAssumptions : ProductQROMOracleModelAssumptions}
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
    (hOracleModel :
      ProductQROMOracleModelAssumptionsAccepted oracleModelAssumptions)
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
        oracleModelAssumptions
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
          oracleModelAssumptions) :=
    productHashOracleInstantiationAccepted_of_serializationFacts
      hSplitOracles
      hHBind
      hHashRecommendation
      hOracleModel
  have hCollision :
      ProductQROMCollisionBoundAccepted
        (ProductQROMCollisionBound.ofHashOracleInstantiation
          (ProductHashOracleInstantiation.ofSerializationFacts
            splitOraclesPinned
            theoremCriticalBindingsUseHBind
            concreteHashRecommendationPinned
            oracleModelAssumptions)
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
  selectedDepthTotalLoss := closure.selectedDepthTotalLoss

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

def ProductPublicCoinTransformPreconditions.ofInstantiatedQROM
    (evidence : ProductInstantiatedQROMEvidence)
    (schedule : ProductPublicCoinTranscriptSchedule)
    (theoremFamilyPinned : Prop)
    (challengeSpaceAndUniformityPinned : Prop)
    (qromReductionLossInstantiated : Prop) :
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

theorem productPublicCoinTransformPreconditionsAccepted_of_instantiatedQROM
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence)
    {schedule : ProductPublicCoinTranscriptSchedule}
    (hSchedule : ProductPublicCoinTranscriptScheduleAccepted schedule)
    {theoremFamilyPinned : Prop}
    {challengeSpaceAndUniformityPinned : Prop}
    {qromReductionLossInstantiated : Prop}
    (hFamily : theoremFamilyPinned)
    (hUniformity : challengeSpaceAndUniformityPinned)
    (hReductionLoss : qromReductionLossInstantiated) :
    ProductPublicCoinTransformPreconditionsAccepted
      (ProductPublicCoinTransformPreconditions.ofInstantiatedQROM
        evidence
        schedule
        theoremFamilyPinned
        challengeSpaceAndUniformityPinned
        qromReductionLossInstantiated) := by
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
      hReductionLoss⟩

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

def ProductQROMInteractiveReduction.ofTransformPreconditions
    (preconditions : ProductPublicCoinTransformPreconditions)
    (challengeCountFormulasPinned : Prop)
    (dfm20LossFormulaPinned : Prop)
    (numericSelectedLossInstantiated : Prop)
    (totalLossBudgetInterfacePinned : Prop) :
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

theorem productQROMInteractiveReductionAccepted_of_transformPreconditions
    {preconditions : ProductPublicCoinTransformPreconditions}
    (hPreconditions :
      ProductPublicCoinTransformPreconditionsAccepted preconditions)
    {challengeCountFormulasPinned : Prop}
    {dfm20LossFormulaPinned : Prop}
    {numericSelectedLossInstantiated : Prop}
    {totalLossBudgetInterfacePinned : Prop}
    (hChallengeCounts : challengeCountFormulasPinned)
    (hDFM20Formula : dfm20LossFormulaPinned)
    (hNumericLoss : numericSelectedLossInstantiated)
    (hBudgetInterface : totalLossBudgetInterfacePinned) :
    ProductQROMInteractiveReductionAccepted
      (ProductQROMInteractiveReduction.ofTransformPreconditions
        preconditions
        challengeCountFormulasPinned
        dfm20LossFormulaPinned
        numericSelectedLossInstantiated
        totalLossBudgetInterfacePinned) := by
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
      hBudgetInterface⟩

structure ProductQROMReductionTheorem where
  transcriptSchedule : ProductPublicCoinTranscriptSchedule
  transformPreconditions : ProductPublicCoinTransformPreconditions
  interactiveBounds : ProductInteractiveSecurityBounds
  exactFiniteProbabilityWiring : ProductExactFiniteProbabilityWiring
  oracleModelAssumptions : ProductQROMOracleModelAssumptions
  interactiveReduction : ProductQROMInteractiveReduction
  reductionLossBound : ProductNumericLossTerm
  transcriptScheduleAccepted :
    ProductPublicCoinTranscriptScheduleAccepted transcriptSchedule
  transformPreconditionsAccepted :
    ProductPublicCoinTransformPreconditionsAccepted transformPreconditions
  interactiveBoundsAccepted :
    ProductInteractiveSecurityBoundsAccepted interactiveBounds
  exactFiniteProbabilityWiringAccepted :
    ProductExactFiniteProbabilityWiringAccepted exactFiniteProbabilityWiring
  oracleModelAssumptionsAccepted :
    ProductQROMOracleModelAssumptionsAccepted oracleModelAssumptions
  interactiveReductionAccepted :
    ProductQROMInteractiveReductionAccepted interactiveReduction
  reductionLossBoundAccepted :
    ProductNumericLossTermAccepted reductionLossBound

def ProductQROMReductionTheoremAccepted
    (theoremRecord : ProductQROMReductionTheorem) : Prop :=
  ProductPublicCoinTranscriptScheduleAccepted
      theoremRecord.transcriptSchedule
    ∧ ProductPublicCoinTransformPreconditionsAccepted
      theoremRecord.transformPreconditions
    ∧ ProductInteractiveSecurityBoundsAccepted theoremRecord.interactiveBounds
    ∧ ProductExactFiniteProbabilityWiringAccepted
      theoremRecord.exactFiniteProbabilityWiring
    ∧ ProductQROMOracleModelAssumptionsAccepted
      theoremRecord.oracleModelAssumptions
    ∧ ProductQROMInteractiveReductionAccepted
      theoremRecord.interactiveReduction
    ∧ ProductNumericLossTermAccepted theoremRecord.reductionLossBound

theorem ProductQROMReductionTheorem.accepted
    (theoremRecord : ProductQROMReductionTheorem) :
    ProductQROMReductionTheoremAccepted theoremRecord :=
  ⟨theoremRecord.transcriptScheduleAccepted,
    theoremRecord.transformPreconditionsAccepted,
    theoremRecord.interactiveBoundsAccepted,
    theoremRecord.exactFiniteProbabilityWiringAccepted,
    theoremRecord.oracleModelAssumptionsAccepted,
    theoremRecord.interactiveReductionAccepted,
    theoremRecord.reductionLossBoundAccepted⟩

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
  qromLossBound : ProductNumericLossTerm

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
    ∧ ProductNumericLossTermAccepted accounting.qromLossBound

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
  qromLossBound := evidence.totalLoss.qromLossBound

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
      hLoss.1⟩

inductive ProductTotalLossTermKind where
  | selectedDepth
  | publicCoinQROM
  | extractor
  | recursiveCarry
  | zkSimulator
  | productOperationsReplay
  | primitiveBatchCancellation
  | qromCompilerOverhead
  | hashCollision
  | auxiliary
  deriving DecidableEq, Fintype, Repr

def ProductTotalLossRequiredTerms : Finset ProductTotalLossTermKind :=
  Finset.univ

structure ProductTotalLossTermLedger where
  selectedDepth : ProductNumericLossTerm
  publicCoinQROM : ProductNumericLossTerm
  extractor : ProductNumericLossTerm
  recursiveCarry : ProductNumericLossTerm
  zkSimulator : ProductNumericLossTerm
  productOperationsReplay : ProductNumericLossTerm
  primitiveBatchCancellation : ProductNumericLossTerm
  qromCompilerOverhead : ProductNumericLossTerm
  hashCollision : ProductNumericLossTerm
  auxiliary : ProductNumericLossTerm

def ProductTotalLossTermLedger.valueTotal
    (terms : ProductTotalLossTermLedger) : ℚ :=
  terms.selectedDepth.value
    + terms.publicCoinQROM.value
    + terms.extractor.value
    + terms.recursiveCarry.value
    + terms.zkSimulator.value
    + terms.productOperationsReplay.value
    + terms.primitiveBatchCancellation.value
    + terms.qromCompilerOverhead.value
    + terms.hashCollision.value
    + terms.auxiliary.value

def ProductTotalLossTermLedger.budgetTotal
    (terms : ProductTotalLossTermLedger) : ℚ :=
  terms.selectedDepth.budget
    + terms.publicCoinQROM.budget
    + terms.extractor.budget
    + terms.recursiveCarry.budget
    + terms.zkSimulator.budget
    + terms.productOperationsReplay.budget
    + terms.primitiveBatchCancellation.budget
    + terms.qromCompilerOverhead.budget
    + terms.hashCollision.budget
    + terms.auxiliary.budget

def ProductTotalLossTermLedger.errorBudgetSliceTotal
    (terms : ProductTotalLossTermLedger) : ℚ :=
  terms.selectedDepth.budget
    + terms.publicCoinQROM.budget
    + terms.extractor.budget
    + terms.hashCollision.budget

def ProductTotalLossTermLedgerAccepted
    (terms : ProductTotalLossTermLedger) : Prop :=
  ProductNumericLossTermAccepted terms.selectedDepth
    ∧ ProductNumericLossTermAccepted terms.publicCoinQROM
    ∧ ProductNumericLossTermAccepted terms.extractor
    ∧ ProductNumericLossTermAccepted terms.recursiveCarry
    ∧ ProductNumericLossTermAccepted terms.zkSimulator
    ∧ ProductNumericLossTermAccepted terms.productOperationsReplay
    ∧ ProductNumericLossTermAccepted terms.primitiveBatchCancellation
    ∧ ProductNumericLossTermAccepted terms.qromCompilerOverhead
    ∧ ProductNumericLossTermAccepted terms.hashCollision
    ∧ ProductNumericLossTermAccepted terms.auxiliary

theorem ProductTotalLossTermLedger.accepted
    (terms : ProductTotalLossTermLedger) :
    ProductTotalLossTermLedgerAccepted terms := by
  exact
    ⟨terms.selectedDepth.accepted,
      terms.publicCoinQROM.accepted,
      terms.extractor.accepted,
      terms.recursiveCarry.accepted,
      terms.zkSimulator.accepted,
      terms.productOperationsReplay.accepted,
      terms.primitiveBatchCancellation.accepted,
      terms.qromCompilerOverhead.accepted,
      terms.hashCollision.accepted,
      terms.auxiliary.accepted⟩

theorem ProductTotalLossTermLedger.valueTotal_le_budgetTotal
    (terms : ProductTotalLossTermLedger) :
    terms.valueTotal ≤ terms.budgetTotal := by
  unfold ProductTotalLossTermLedger.valueTotal
  unfold ProductTotalLossTermLedger.budgetTotal
  linarith
    [terms.selectedDepth.withinBudget,
      terms.publicCoinQROM.withinBudget,
      terms.extractor.withinBudget,
      terms.recursiveCarry.withinBudget,
      terms.zkSimulator.withinBudget,
      terms.productOperationsReplay.withinBudget,
      terms.primitiveBatchCancellation.withinBudget,
      terms.qromCompilerOverhead.withinBudget,
      terms.hashCollision.withinBudget,
      terms.auxiliary.withinBudget]

structure ProductTotalLossCertificate where
  selectedDepth : Nat
  selectedDepthPinned : selectedDepth = 3
  selectedDepthPerLayerNumerator : Nat
  selectedDepthFixedNumerator : Nat
  selectedDepthNumerator : Nat
  selectedDepthDenominator : Nat
  selectedDepthDenominatorPositive : 0 < selectedDepthDenominator
  terms : ProductTotalLossTermLedger
  selectedDepthNumerator_eq :
    selectedDepthNumerator =
      selectedDepthLossNumerator
        selectedDepth
        selectedDepthPerLayerNumerator
        selectedDepthFixedNumerator
  selectedDepthTerm_eq :
    terms.selectedDepth.value =
      (selectedDepthNumerator : ℚ) / (selectedDepthDenominator : ℚ)
  errorBudget : SuperNeoErrorBudget
  errorBudgetTotal_eq :
    errorBudget.total = terms.errorBudgetSliceTotal
  totalValue : ℚ
  totalBudget : ℚ
  totalValue_eq : totalValue = terms.valueTotal
  totalBudget_eq : totalBudget = terms.budgetTotal
  coveredTerms : Finset ProductTotalLossTermKind
  requiredTermsCovered : ProductTotalLossRequiredTerms ⊆ coveredTerms
  missingRequiredTerms : Finset ProductTotalLossTermKind
  missingRequiredTerms_eq :
    missingRequiredTerms = ProductTotalLossRequiredTerms \ coveredTerms
  missingRequiredTerms_empty : missingRequiredTerms = ∅
  claimedBudget : ℚ
  totalBudgetWithinClaimedBudget : totalBudget ≤ claimedBudget

def ProductTotalLossCertificateAccepted
    (certificate : ProductTotalLossCertificate) : Prop :=
  certificate.selectedDepth = 3
    ∧ 0 < certificate.selectedDepth
    ∧ 0 < certificate.selectedDepthDenominator
    ∧ ProductTotalLossTermLedgerAccepted certificate.terms
    ∧ certificate.selectedDepthNumerator =
      selectedDepthLossNumerator
        certificate.selectedDepth
        certificate.selectedDepthPerLayerNumerator
        certificate.selectedDepthFixedNumerator
    ∧ certificate.terms.selectedDepth.value =
      (certificate.selectedDepthNumerator : ℚ) /
        (certificate.selectedDepthDenominator : ℚ)
    ∧ certificate.errorBudget.total =
      certificate.terms.errorBudgetSliceTotal
    ∧ certificate.totalValue = certificate.terms.valueTotal
    ∧ certificate.totalBudget = certificate.terms.budgetTotal
    ∧ ProductTotalLossRequiredTerms ⊆ certificate.coveredTerms
    ∧ certificate.missingRequiredTerms =
      ProductTotalLossRequiredTerms \ certificate.coveredTerms
    ∧ certificate.missingRequiredTerms = ∅
    ∧ certificate.totalBudget ≤ certificate.claimedBudget
    ∧ certificate.totalValue ≤ certificate.claimedBudget

theorem ProductTotalLossCertificate.accepted
    (certificate : ProductTotalLossCertificate) :
    ProductTotalLossCertificateAccepted certificate := by
  have hDepthPositive : 0 < certificate.selectedDepth := by
    rw [certificate.selectedDepthPinned]
    decide
  have hValueWithinBudget :
      certificate.totalValue ≤ certificate.totalBudget := by
    rw [certificate.totalValue_eq, certificate.totalBudget_eq]
    exact ProductTotalLossTermLedger.valueTotal_le_budgetTotal
      certificate.terms
  exact
    ⟨certificate.selectedDepthPinned,
      hDepthPositive,
      certificate.selectedDepthDenominatorPositive,
      ProductTotalLossTermLedger.accepted certificate.terms,
      certificate.selectedDepthNumerator_eq,
      certificate.selectedDepthTerm_eq,
      certificate.errorBudgetTotal_eq,
      certificate.totalValue_eq,
      certificate.totalBudget_eq,
      certificate.requiredTermsCovered,
      certificate.missingRequiredTerms_eq,
      certificate.missingRequiredTerms_empty,
      certificate.totalBudgetWithinClaimedBudget,
      le_trans hValueWithinBudget
        certificate.totalBudgetWithinClaimedBudget⟩

theorem ProductTotalLossCertificate.fiatShamirProbability_le_selectedDepthTerm
    {pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength : Nat}
    (certificate : ProductTotalLossCertificate)
    (pirlcBadSeeds : Finset (PiRLCChallengeSeed pirlcCount))
    (piccsBadSeeds : Finset (Fin piccsRoundCount → GoldilocksExt2))
    (terminalCEBadSeeds :
      Finset (Fin terminalCERoundCount → CEOpeningChallengeSymbol))
    (transcriptBadSeeds : Finset (TranscriptSeedDomain transcriptByteLength))
    (budget : SuperNeoFiatShamirFiberBudget)
    (hPiRLC :
      ∀ target, target ∈ pirlcBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirPirlcSeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.pirlc)
    (hPiCCS :
      ∀ target, target ∈ piccsBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirPiccsSeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.piccs)
    (hTerminalCE :
      ∀ target, target ∈ terminalCEBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirTerminalCESeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.terminalCE)
    (hTranscript :
      ∀ target, target ∈ transcriptBadSeeds →
        (fiatShamirProjectionFiber
          (superNeoFiatShamirTranscriptSeed
            pirlcCount piccsRoundCount terminalCERoundCount transcriptByteLength)
          target).card ≤
          budget.transcript)
    (hNumerator :
      superNeoFiatShamirProbabilityBudgetNumerator
        budget
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds ≤ certificate.selectedDepthNumerator)
    (hDenominator :
      certificate.selectedDepthDenominator =
        superNeoFiatShamirProbabilityDenominator
          pirlcCount
          piccsRoundCount
          terminalCERoundCount
          transcriptByteLength) :
    superNeoFiatShamirProbability
      (superNeoFiatShamirBadTranscriptSeeds
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds) ≤
      certificate.terms.selectedDepth.value := by
  have hSelectedNumerator :
      superNeoFiatShamirProbabilityBudgetNumerator
        budget
        pirlcBadSeeds
        piccsBadSeeds
        terminalCEBadSeeds
        transcriptBadSeeds ≤
        selectedDepthLossNumerator
          certificate.selectedDepth
          certificate.selectedDepthPerLayerNumerator
          certificate.selectedDepthFixedNumerator := by
    simpa [certificate.selectedDepthNumerator_eq] using hNumerator
  have hProbability :=
    superneo_fiatShamirProbability_le_selectedDepthLoss
      pirlcBadSeeds
      piccsBadSeeds
      terminalCEBadSeeds
      transcriptBadSeeds
      budget
      hPiRLC
      hPiCCS
      hTerminalCE
      hTranscript
      hSelectedNumerator
  calc
    superNeoFiatShamirProbability
        (superNeoFiatShamirBadTranscriptSeeds
          pirlcBadSeeds
          piccsBadSeeds
          terminalCEBadSeeds
          transcriptBadSeeds)
        ≤
        (selectedDepthLossNumerator
          certificate.selectedDepth
          certificate.selectedDepthPerLayerNumerator
          certificate.selectedDepthFixedNumerator : ℚ) /
          (superNeoFiatShamirProbabilityDenominator
            pirlcCount
            piccsRoundCount
            terminalCERoundCount
            transcriptByteLength : ℚ) := hProbability
    _ =
        (certificate.selectedDepthNumerator : ℚ) /
          (certificate.selectedDepthDenominator : ℚ) := by
          rw [← certificate.selectedDepthNumerator_eq, hDenominator]
    _ = certificate.terms.selectedDepth.value :=
      certificate.selectedDepthTerm_eq.symm

structure ProductTotalLossClosure where
  certificate : ProductTotalLossCertificate

def ProductTotalLossClosureAccepted
    (closure : ProductTotalLossClosure) : Prop :=
  ProductTotalLossCertificateAccepted closure.certificate

theorem ProductTotalLossClosure.accepted
    (closure : ProductTotalLossClosure) :
    ProductTotalLossClosureAccepted closure :=
  ProductTotalLossCertificate.accepted closure.certificate

structure ProductTotalLossBudget where
  selectedDepth : Nat
  selectedDepthPositive : 0 < selectedDepth
  exactArithmeticPinned : Prop
  qromLedgerTermMappingPinned : Prop
  extractorLedgerTermMappingPinned : Prop
  primitiveBatchCancellationTermIncluded : Prop
  allRequiredTermsInstantiated : Prop
  totalLossCertificate : ProductTotalLossCertificate

def ProductTotalLossBudgetAccepted
    (budget : ProductTotalLossBudget) : Prop :=
  budget.selectedDepth = 3
    ∧ (0 < budget.selectedDepth)
    ∧ budget.exactArithmeticPinned
    ∧ budget.qromLedgerTermMappingPinned
    ∧ budget.extractorLedgerTermMappingPinned
    ∧ budget.primitiveBatchCancellationTermIncluded
    ∧ budget.allRequiredTermsInstantiated
    ∧ ProductTotalLossCertificateAccepted budget.totalLossCertificate

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
  totalLossCertificate := closure.certificate

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
      ProductTotalLossClosureAccepted closure) :
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
      hClosure⟩

structure ProductLatticeParameterBounds where
  qRingDimensionAndNormBound : Prop
  decompositionAndChallengeParameterBounds : Prop
  normGrowthAcrossFoldAndNumiSealBound : Prop

def ProductLatticeParameterBoundsAccepted
    (bounds : ProductLatticeParameterBounds) : Prop :=
  bounds.qRingDimensionAndNormBound
    ∧ bounds.decompositionAndChallengeParameterBounds
    ∧ bounds.normGrowthAcrossFoldAndNumiSealBound

structure ProductLatticeReductionLossBounds where
  reductionLossBoundInstantiated : Prop
  reductionLossBoundIncludedInProductLedger : Prop

def ProductLatticeReductionLossBoundsAccepted
    (bounds : ProductLatticeReductionLossBounds) : Prop :=
  bounds.reductionLossBoundInstantiated
    ∧ bounds.reductionLossBoundIncludedInProductLedger

structure ProductLatticeConcreteCostBounds where
  classicalAttackCostBound : Prop
  quantumAttackCostBound : Prop
  parameterSensitivityBound : Prop
  failureProbabilityBudgetBound : Prop

def ProductLatticeConcreteCostBoundsAccepted
    (bounds : ProductLatticeConcreteCostBounds) : Prop :=
  bounds.classicalAttackCostBound
    ∧ bounds.quantumAttackCostBound
    ∧ bounds.parameterSensitivityBound
    ∧ bounds.failureProbabilityBudgetBound

structure ProductLatticeAssumptionDossier where
  moduleSISStatementPinned : Prop
  parameterBounds : ProductLatticeParameterBounds
  reductionLossBounds : ProductLatticeReductionLossBounds
  concreteCostBounds : ProductLatticeConcreteCostBounds

def ProductLatticeAssumptionDossierAccepted
    (dossier : ProductLatticeAssumptionDossier) : Prop :=
  dossier.moduleSISStatementPinned
    ∧ ProductLatticeParameterBoundsAccepted dossier.parameterBounds
    ∧ ProductLatticeReductionLossBoundsAccepted dossier.reductionLossBounds
    ∧ ProductLatticeConcreteCostBoundsAccepted dossier.concreteCostBounds

structure ProductLatticeParameterClosure where
  parameterBounds : ProductLatticeParameterBounds
  reductionLossBounds : ProductLatticeReductionLossBounds
  concreteCostBounds : ProductLatticeConcreteCostBounds

def ProductLatticeParameterClosureAccepted
    (closure : ProductLatticeParameterClosure) : Prop :=
  ProductLatticeParameterBoundsAccepted closure.parameterBounds
    ∧ ProductLatticeReductionLossBoundsAccepted closure.reductionLossBounds
    ∧ ProductLatticeConcreteCostBoundsAccepted closure.concreteCostBounds

def ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (parameterBounds : ProductLatticeParameterBounds)
    (reductionLossBounds : ProductLatticeReductionLossBounds)
    (concreteCostBounds : ProductLatticeConcreteCostBounds) :
    ProductLatticeAssumptionDossier where
  moduleSISStatementPinned :=
    ModuleSISNoShortKernel key.matrix bounded
      ∧ checkAjtaiKernelCertificate key certificate.1
  parameterBounds := parameterBounds
  reductionLossBounds := reductionLossBounds
  concreteCostBounds := concreteCostBounds

def ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificateAndClosure
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    (closure : ProductLatticeParameterClosure) :
    ProductLatticeAssumptionDossier :=
  ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificate
    certificate
    closure.parameterBounds
    closure.reductionLossBounds
    closure.concreteCostBounds

theorem productLatticeAssumptionDossierAccepted_of_verifiedAjtaiKernelCertificate
    {columns : Nat}
    {key : CertifiedAjtaiKey columns}
    {bounded : ConcreteAjtaiMessage columns → Prop}
    (certificate : VerifiedAjtaiKernelCertificate key bounded)
    {parameterBounds : ProductLatticeParameterBounds}
    {reductionLossBounds : ProductLatticeReductionLossBounds}
    {concreteCostBounds : ProductLatticeConcreteCostBounds}
    (hParameterBounds :
      ProductLatticeParameterBoundsAccepted parameterBounds)
    (hReductionLossBounds :
      ProductLatticeReductionLossBoundsAccepted reductionLossBounds)
    (hConcreteCostBounds :
      ProductLatticeConcreteCostBoundsAccepted concreteCostBounds) :
    ProductLatticeAssumptionDossierAccepted
      (ProductLatticeAssumptionDossier.ofVerifiedAjtaiKernelCertificate
        certificate
        parameterBounds
        reductionLossBounds
        concreteCostBounds) := by
  exact
    ⟨⟨verifiedCertificate_noShortKernel certificate, certificate.property⟩,
      hParameterBounds,
      hReductionLossBounds,
      hConcreteCostBounds⟩

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
    ⟨hParameterBounds, hReductionLossBounds, hConcreteCostBounds⟩
  exact
    productLatticeAssumptionDossierAccepted_of_verifiedAjtaiKernelCertificate
      certificate
      hParameterBounds
      hReductionLossBounds
      hConcreteCostBounds

structure ProductPublicCoinQROMEvidence where
  interactivePublicCoinProtocolSpecified : Prop
  transformPreconditionsSatisfied : Prop
  quantumOracleQueryBoundAccounted : Prop
  transcriptDomainSeparatorsBound : Prop
  proofKindSeparationBound : Prop
  transcriptCollisionMalleabilityExcluded : Prop
  qromReductionTheorem : ProductQROMReductionTheorem

def ProductPublicCoinQROMAccepted
    (evidence : ProductPublicCoinQROMEvidence) : Prop :=
  evidence.interactivePublicCoinProtocolSpecified
    ∧ evidence.transformPreconditionsSatisfied
    ∧ evidence.quantumOracleQueryBoundAccounted
    ∧ evidence.transcriptDomainSeparatorsBound
    ∧ evidence.proofKindSeparationBound
    ∧ evidence.transcriptCollisionMalleabilityExcluded
    ∧ ProductQROMReductionTheoremAccepted evidence.qromReductionTheorem

def ProductPublicCoinQROMEvidence.ofInstantiatedQROM
    (evidence : ProductInstantiatedQROMEvidence)
    (qromReductionTheorem : ProductQROMReductionTheorem) :
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
  qromReductionTheorem := qromReductionTheorem

theorem productPublicCoinQROMAccepted_of_instantiatedQROM
    {evidence : ProductInstantiatedQROMEvidence}
    (hEvidence : ProductInstantiatedQROMEvidenceAccepted evidence)
    {qromReductionTheorem : ProductQROMReductionTheorem}
    (hQROMReductionTheorem :
      ProductQROMReductionTheoremAccepted qromReductionTheorem) :
    ProductPublicCoinQROMAccepted
      (ProductPublicCoinQROMEvidence.ofInstantiatedQROM
        evidence
        qromReductionTheorem) := by
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
      hMalleability,
      hQROMReductionTheorem⟩

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
    (qromReductionTheorem : ProductQROMReductionTheorem)
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
      (ProductPublicCoinQROMEvidence.ofInstantiatedQROM
        instantiatedQROM
        qromReductionTheorem)
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
    {qromReductionTheorem : ProductQROMReductionTheorem}
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
    (hQROMReductionTheorem :
      ProductQROMReductionTheoremAccepted qromReductionTheorem)
    (hTotalLossClosure :
      ProductTotalLossClosureAccepted totalLossClosure)
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
      qromReductionTheorem
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
        (ProductPublicCoinQROMEvidence.ofInstantiatedQROM
          instantiatedQROM
          qromReductionTheorem) :=
    productPublicCoinQROMAccepted_of_instantiatedQROM
      hInstantiatedQROM
      hQROMReductionTheorem
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
          qromReductionTheorem
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
      ∧ ProductNumericLossTermAccepted ledger.selectedDepthTotalLoss := by
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
      hSelectedDepthTotalLoss⟩
  exact
    ⟨hDepth,
      hHops,
      hLoadedParent,
      hRecurrence,
      hExtractor,
      hQROM,
      hZKSimulator,
      hSelectedDepthTotalLoss⟩

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
    accounting.sourceFoldExtractorAccepted
      ∧ accounting.terminalSealExtractorAccepted
      ∧ accounting.productEnvelopeExtractorClosed
      ∧ accounting.recursiveCarryExtractorAccepted
      ∧ ProductPerKindExtractorTheoremsAccepted
        accounting.perKindExtractorTheorems
      ∧ ProductRecursiveCarryChainRootRecurrenceAccepted
        accounting.recursiveCarryChainRootRecurrence
      ∧ accounting.extractorFailureLossAccounted
      ∧ ProductNumericLossTermAccepted accounting.extractorLossBound := by
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
      ∧ ProductNumericLossTermAccepted accounting.qromLossBound := by
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
      ∧ ProductQROMOracleModelAssumptionsAccepted
        hashes.oracleModelAssumptions := by
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
      hOracleModel⟩
  exact
    ⟨hBindingBits,
      hTargetCount,
      hHBind,
      hBindingDomains,
      hOracleModel⟩

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
      ∧ preconditions.qromReductionLossInstantiated := by
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
      hReductionLoss⟩
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
      hReductionLoss⟩

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
      ∧ reduction.totalLossBudgetInterfacePinned := by
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
      hBudget⟩
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
      hBudget⟩

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
      ∧ ProductTotalLossCertificateAccepted
        budget.totalLossCertificate := by
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
