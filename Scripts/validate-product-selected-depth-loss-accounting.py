#!/usr/bin/env python3
"""Validate selected-depth product loss accounting evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "TestVectors" / "product-selected-depth-loss-accounting-v1.json"
SELECTED_PRIMITIVE_BATCH_LANE_COUNT = 4

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "ledgerID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedDepth",
    "lossNotation",
    "componentLosses",
    "totalLossRule",
    "hardClaimBlockers",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "numiSealConformanceScope": "TestVectors/numiseal-conformance-scope-v1.json",
    "numiSealZKMaskDistributionEvidence": "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
    "numiSealZKSimulatorCouplingEvidence": "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
    "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
    "constantTimeReleaseEvidence": "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
    "benchmarkCoverage": "TestVectors/benchmark-coverage-v1.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMPublicCoinAccounting": "TestVectors/product-qrom-public-coin-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productSharedBadEventDedup": "TestVectors/product-shared-bad-event-dedup-v1.json",
    "productFiniteProtocolLossObstruction": "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "productReleaseDistributionEvidence": "TestVectors/product-release-distribution-evidence-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductSelectedDepthLossLedger",
    "ProductSelectedDepthLossLedgerAccepted",
    "ProductCarryChainRoot",
    "ProductSelectedDepthIndexing",
    "ProductSelectedDepthIndexingAccepted",
    "ProductCarryChainRootByteLayout",
    "ProductCarryChainRootByteLayoutAccepted",
    "ProductPCDParentTupleBinding",
    "ProductPCDParentTupleBindingAccepted",
    "OrderedPCDParentTupleRoot",
    "OrderedPCDParentTupleRootAccepted",
    "ProductAcceptedProofKindExtractor",
    "ProductAcceptedProofKindExtractorAccepted",
    "ProductPerKindExtractorTheorems",
    "ProductPerKindExtractorTheoremsAccepted",
    "ProductTerminalVerifierArithmetization",
    "ProductTerminalVerifierArithmetizationAccepted",
    "productCompressionSourceFree_from_terminalVerifierArithmetization",
    "ProductTerminalVerifierAIRSpec",
    "ProductTerminalVerifierAIRSpecAccepted",
    "ProductTerminalVerifierAIRSoundness",
    "ProductTerminalVerifierAIRSoundnessAccepted",
    "ProductTerminalVerifierAIRConstraintExactness",
    "ProductTerminalVerifierAIRConstraintExactnessAccepted",
    "ProductTerminalVerifierAIRPrimitiveLowering",
    "ProductTerminalVerifierAIRPrimitiveLoweringAccepted",
    "ProductTerminalVerifierAIRPrimitiveBatching",
    "ProductTerminalVerifierAIRPrimitiveBatchingAccepted",
    "ProductTerminalAIRPrimitiveBatchMultiLane",
    "ProductPrimitiveBatchCancellationBound",
    "ProductPrimitiveBatchCancellationBoundAccepted",
    "ProductPrimitiveBatchLaneCountSelected",
    "ProductAIRRowsNoVerifierBooleanWrapping",
    "ProductAIRRowsNoVerifierBooleanWrappingAccepted",
    "ProductCEAjtaiPrimitiveConstraintSoundness",
    "ProductCEAjtaiPrimitiveConstraintSoundnessAccepted",
    "ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundness",
    "ProductPiCCSPiRLCPiDECPrimitiveConstraintSoundnessAccepted",
    "ProductTerminalVerifierAIRResidualCompleteness",
    "ProductTerminalVerifierAIRResidualCompletenessAccepted",
    "ProductTerminalVerifierAIRResidualSoundness",
    "ProductTerminalVerifierAIRResidualSoundnessAccepted",
    "ProductSourceFreeCompressionImpliesTerminalAcceptance",
    "ProductSourceFreeCompressionImpliesTerminalAcceptanceAccepted",
    "productSourceFreeCompression_sound_for_bound_source",
    "ProductRecursiveCarryChainRootRecurrence",
    "ProductRecursiveCarryChainRootRecurrenceAccepted",
    "ProductExtractorLossAccounting",
    "ProductExtractorLossAccountingAccepted",
    "ProductPublicCoinTranscriptSchedule",
    "ProductPublicCoinTranscriptScheduleAccepted",
    "ProductPublicCoinTransformPreconditions",
    "ProductPublicCoinTransformPreconditionsAccepted",
    "ProductQROMInteractiveReduction",
    "ProductQROMInteractiveReductionAccepted",
    "ProductPublicCoinLossAccounting",
    "ProductPublicCoinLossAccountingAccepted",
    "ProductQROMCompilerOverheadBound",
    "ProductQROMCompilerOverheadBoundAccepted",
    "ProductSharedBadEventDeduplication",
    "ProductSharedBadEventDeduplicationAccepted",
    "ProductTotalLossBudget",
    "ProductTotalLossBudgetAccepted",
    "ProductExactFiniteProbabilityWiring",
    "ProductExactFiniteProbabilityWiringAccepted",
    "productFoldExtractor_from_acceptedProof",
    "productTerminalExtractor_from_acceptedProof",
    "productCompressedTerminalExtractor_from_acceptedProof",
    "productNumiSealTerminalExtractor_from_acceptedProof",
    "productNumiSealZKProductExtractor_from_acceptedProof",
    "productRecursiveCarryDepthLeThreeExtractor_from_acceptedProof",
    "productRecursiveCarryChainRoot_recurrence_unfolds_depth_le_three",
    "productRecursiveCarryChainRoot_verifier_extractor_path_depth_le_three",
    "productSecurityTheorem_requires_selected_depth_loss_accounting",
    "productSecurityTheorem_requires_extractor_loss_accounting",
    "productSecurityTheorem_requires_qrom_transcript_schedule",
    "productSecurityTheorem_requires_qrom_transform_preconditions",
    "productSecurityTheorem_requires_qrom_interactive_reduction",
    "productSecurityTheorem_requires_qrom_compiler_overhead_bound",
    "productSecurityTheorem_requires_shared_bad_event_deduplication",
    "productSecurityTheorem_requires_qrom_loss_accounting",
    "productSecurityTheorem_requires_total_loss_budget",
    "productSecurityTheorem_requires_exact_finite_probability_wiring",
}

EXPECTED_COMPONENT_IDS = [
    "shared-cryptographic-core",
    "source-fold-knowledge",
    "terminal-numiseal-seal",
    "typed-recursive-carry",
    "zk-simulator-composition",
    "public-coin-qrom",
    "extractor-instantiation",
    "transcript-collision-domain-separation",
    "product-ops-replay",
    "constant-time-side-channel",
    "release-distribution",
]

EXPECTED_BLOCKERS: list[str] = []

EXPECTED_PROMOTION_FALSE_FLAGS = [
    "productionProductSecurityClaimAllowed",
    "productionPostQuantumClaimAllowed",
    "productionQROMClaimAllowed",
    "productionZKPrivacyClaimAllowed",
    "productionReleaseDistributionClaimAllowed",
]

EXPECTED_DEPTH_INDEXING = {
    "baseAcceptedLayerDepth": 1,
    "recursiveChildDepths": [2, 3],
    "selectedMaximumDepth": 3,
    "selectedRecursiveCarryHops": 2,
    "depthZeroArtifactAccepted": False,
}

EXPECTED_TERMINAL_VERIFIER_ARITHMETIZATION_FIELDS = [
    "productionVerifierConsumesCompressedProofBytes",
    "productionVerifierRejectsExpandedVerifierWitness",
    "sourceProofBytesAbsentFromProductionVerifier",
    "expandedVerifierTraceAbsentFromProductionVerifier",
    "verifierRelationRerunsPiCCS",
    "verifierRelationRerunsPiRLC",
    "verifierRelationRerunsPiDEC",
    "verifierRelationRerunsAjtaiOpening",
    "verifierRelationChecksModuleSISNorms",
    "terminalVerifierTraceColumnsCommitted",
    "terminalVerifierBoundaryConstraintsCommitted",
    "terminalVerifierTransitionConstraintsCommitted",
    "terminalVerifierResidualPolynomialCommitted",
    "traceResidualPCSFRIQueriesVerified",
    "terminalVerifierExecutionIsProvedRelation",
    "terminalAcceptBitOneConstrained",
    "canonicalDecodingConstrainedAtAIRLevel",
    "hashDigestBindingsConstrainedAtAIRLevel",
    "piCCSVerifierConstrainedAtAIRLevel",
    "piRLCVerifierConstrainedAtAIRLevel",
    "piDECVerifierConstrainedAtAIRLevel",
    "terminalCEVerifierConstrainedAtAIRLevel",
    "friPCSVerifierConstrainedAtAIRLevel",
    "jointTraceResidualQueryScheduleBound",
    "traceResidualOpeningsPairedByQueryPoint",
    "residualEqualsAIRConstraintEvaluation",
    "acceptBitDerivedFromAIRConstraints",
    "terminalVerifierTypedAIRSubrelationsDeclared",
    "canonicalSourceRepresentationSubrelationConstrained",
    "publicBindingSubrelationConstrained",
    "piCCSVerifierSubrelationConstrained",
    "piRLCVerifierSubrelationConstrained",
    "piDECVerifierSubrelationConstrained",
    "terminalCEOpeningSubrelationConstrained",
    "innerCompressedProofVerifierSubrelationGatedBySourceKind",
    "outerFRIVerifierSeparatedFromTerminalAIR",
    "residualAggregationUsesTypedSubrelations",
    "residualPolynomialEncodesAggregateVerifierConstraints",
    "sharedByNormalTerminalVerifierAndAIR",
    "sourceDigestComputedFromCanonicalPrivateEncoding",
    "publicCoinDerivationVerifierBound",
    "ceAjtaiArithmeticConstrained",
    "recursiveRelationDigestPublicInput",
    "productionVerifierDoesNotAcceptExpandedWitness",
    "sourceDigestComputationProvenInAIR",
    "publicCoinDerivationConstrainedInAIR",
    "ceAjtaiArithmeticNotDigestOnly",
    "recursiveRelationDigestPublicBoundInAIR",
    "witnessHeavySourceFreeVerifierPathAbsent",
    "sharedSpecEmitsExecutableConstraintRows",
    "airResidualZeroIffSharedSpecAccepts",
    "normalTerminalVerifierAcceptanceEquivalentToZeroResidual",
    "emitsNormalResultAndAIRConstraintRowsFromSameSteps",
    "noAssertedStageAcceptanceFlags",
    "digestAndCoinComputationsConstraintEmitted",
    "ceAjtaiArithmeticConstraintEmitted",
    "primitiveRowsHaveInspectableProvenance",
    "ceAjtaiLoweredToPrimitiveRows",
    "foldBoundariesLoweredToPrimitiveRows",
    "noVerifierBooleanWrappingRows",
    "noBoundaryReportAcceptanceRows",
    "digestRowsHashOrPublicBound",
    "primitiveConstraintLoweringExactness",
    "rowProvenanceTypedAndInspectable",
    "ceAjtaiRowsEmitCanonicalCoefficientDecoding",
    "ceAjtaiRowsEmitMatrixVectorMultiplication",
    "piCCSRowsEmitProjectionSumcheckAndFinalClaimConstraints",
    "piRLCRowsEmitCoinLinearCombinationAndParentPointConstraints",
    "piDECRowsEmitDigitBoundsRecompositionAndLowNormConstraints",
    "noRowsSourcedFromVerifierBooleansOrBoundaryReportAcceptance",
    "zeroResidualIffSpecAccepts",
    "constraintExactness",
    "residualCompleteness",
    "residualSoundness",
]


def fail(message: str) -> None:
    print(f"product selected-depth loss accounting validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} root must be an object")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a non-empty list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false until the required evidence is instantiated")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(ledger: dict[str, Any]) -> None:
    related = require_dict(ledger.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the selected evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "product crypto security dossier must link the selected-depth loss ledger",
    )
    depth = require_dict(dossier.get("supportedProductDepth"), "productCryptoSecurityDossier.supportedProductDepth")
    require(depth.get("theoremMaximumDepth") == 3, "product crypto security dossier maximum theorem depth must be 3")
    require(
        dossier_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "product crypto security dossier must link extractor loss accounting",
    )
    require(
        dossier_related.get("productQROMPublicCoinAccounting") == "TestVectors/product-qrom-public-coin-accounting-v1.json",
        "product crypto security dossier must link QROM public-coin accounting",
    )
    require(
        dossier_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "product crypto security dossier must link QROM transcript schedule",
    )
    require(
        dossier_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "product crypto security dossier must link QROM transform preconditions",
    )
    require(
        dossier_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "product crypto security dossier must link QROM interactive reduction",
    )
    require(
        dossier_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "product crypto security dossier must link sampler/encoding evidence",
    )
    require(
        dossier_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "product crypto security dossier must link collision/malleability evidence",
    )
    require(
        dossier_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "product crypto security dossier must link the total loss budget",
    )
    require(
        dossier_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "product crypto security dossier must link release distribution evidence",
    )
    require(
        dossier_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "product crypto security dossier must link ZK simulator-coupling evidence",
    )
    total_budget = read_json(ROOT / EXPECTED_MANIFESTS["productTotalLossBudget"])
    total_related = require_dict(total_budget.get("relatedManifests"), "productTotalLossBudget.relatedManifests")
    require(
        total_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "total loss budget must link the selected-depth ledger",
    )
    require(
        total_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "total loss budget must link QROM transcript schedule",
    )
    require(
        total_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "total loss budget must link QROM transform preconditions",
    )
    require(
        total_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "total loss budget must link QROM interactive reduction",
    )
    require(
        total_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "total loss budget must link sampler/encoding evidence",
    )
    require(
        total_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "total loss budget must link ZK simulator-coupling evidence",
    )
    require(
        total_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "total loss budget must link collision/malleability evidence",
    )
    require(
        total_related.get("productFiniteProtocolLossObstruction") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
        "total loss budget must link finite-protocol loss obstruction evidence",
    )
    require(
        total_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "total loss budget must link release distribution evidence",
    )
    finite_loss = read_json(ROOT / EXPECTED_MANIFESTS["productFiniteProtocolLossObstruction"])
    finite_related = require_dict(finite_loss.get("relatedManifests"), "productFiniteProtocolLossObstruction.relatedManifests")
    require(
        finite_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "finite-protocol loss obstruction evidence must link selected-depth loss accounting",
    )
    release_distribution = read_json(ROOT / EXPECTED_MANIFESTS["productReleaseDistributionEvidence"])
    release_related = require_dict(release_distribution.get("relatedManifests"), "productReleaseDistributionEvidence.relatedManifests")
    require(
        release_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "release distribution evidence must link selected-depth loss accounting",
    )
    release_policy = require_dict(release_distribution.get("releaseClassPolicy"), "productReleaseDistributionEvidence.releaseClassPolicy")
    require(
        release_policy.get("releaseDistributionLossSymbol") == "epsilon_release",
        "release distribution evidence must bind epsilon_release",
    )

    preconditions = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTransformPreconditions"])
    precondition_related = require_dict(preconditions.get("relatedManifests"), "productQROMTransformPreconditions.relatedManifests")
    require(
        precondition_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "QROM transform preconditions must link selected-depth loss accounting",
    )
    require(
        precondition_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM transform preconditions must link interactive reduction",
    )
    require(
        precondition_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM transform preconditions must link sampler/encoding evidence",
    )
    require(
        precondition_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM transform preconditions must link collision/malleability evidence",
    )

    reduction = read_json(ROOT / EXPECTED_MANIFESTS["productQROMInteractiveReduction"])
    reduction_related = require_dict(reduction.get("relatedManifests"), "productQROMInteractiveReduction.relatedManifests")
    require(
        reduction_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "QROM interactive reduction must link selected-depth loss accounting",
    )
    require(
        reduction_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM interactive reduction must link sampler/encoding evidence",
    )
    require(
        reduction_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM interactive reduction must link collision/malleability evidence",
    )


def validate_formal_surface(ledger: dict[str, Any]) -> None:
    formal = require_dict(ledger.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")
    for needle in [
        "def ProductPrimitiveBatchLaneCountSelected (laneCount : Nat) : Prop :=",
        "laneCount = 4",
        "batchContextCount",
        "goldilocksModulus ^ 4",
        "cancellationEventBoundedByBatchContextCountOverQPowFour",
    ]:
        require(needle in source, f"formal primitive batch cancellation surface missing {needle}")
    for field in EXPECTED_TERMINAL_VERIFIER_ARITHMETIZATION_FIELDS:
        require(
            field in source,
            f"ProductTerminalVerifierArithmetization missing succinct PCS/FRI field {field}",
        )
    validate_air_primitive_lowering_source()


def validate_air_primitive_lowering_source() -> None:
    compression = (ROOT / "SuperNeo-NuMetal" / "ProofCompression" / "SuperNeoSpartanFRICompression.swift").read_text(encoding="utf-8")
    protocols = (ROOT / "SuperNeo-NuMetal" / "Protocols" / "SuperNeoProtocols.swift").read_text(encoding="utf-8")
    combined = compression + "\n" + protocols
    for needle in [
        "SuperNeoTerminalVerifierAIRRowProvenance",
        "case primitiveArithmetic",
        "case canonicalDecoding",
        "case publicInputBinding",
        "case hashSubrelation",
        "case publicCoinBinding",
        "case friPCSVerifier",
        "terminalVerifierAIRPrimitiveRows",
        "terminalVerifierAIRPiCCSPrimitiveRows",
        "terminalVerifierAIRPiRLCPrimitiveRows",
        "terminalVerifierAIRPiDECPrimitiveRows",
        "CEOpeningRelation.terminalVerifierAIRPrimitiveRows",
        "terminalPrimitiveAIRCompactRows",
        "TerminalVerifierAIRRowBindingContext",
        "primitive-row-context-binding",
        "full-primitive-row-transcript",
        "primitive-batch-challenge-after-row-transcript",
        "superneo/terminal-air/primitive-batch-coeff/v1",
        "static let selectedPrimitiveBatchLaneCount = 4",
        "validateSelectedBatchLaneCount",
        "batchResiduals",
        "coefficientsByLane",
        "aggregation.batchResiduals.count == batchLaneCount",
        "aggregation.coefficientsByLane.count == batchLaneCount",
        "summary.batchResiduals.count == SuperNeoTerminalVerifierAIRPrimitiveBatch.selectedPrimitiveBatchLaneCount",
        "laneIndex",
        "candidate < GoldilocksField.modulus",
        "primitive-row-index-chain",
        "primitive-batch-lane-count",
        "sourceFreePCSPolicy",
        "sourceFreeTinyPCSFixtureOnly",
        "sourceFreePCSParameters",
        "batched-primitive-residual-lane-\\(laneIndex)",
        "terminal-ce-ajtai",
    ]:
        require(needle in combined, f"terminal verifier AIR primitive lowering missing {needle}")
    require(
        "sourceFreeTinyPCSFixtureOnly" not in LEDGER.read_text(encoding="utf-8"),
        "selected-depth production ledger must not promote tiny PCS fixture policy",
    )
    forbidden = [
        "terminalVerifierAIRBoundaryRows",
        "boundary-\\(check.index)-accepted",
        "check.isAccepted",
        "terminalVerifierAIRTerminalCERows",
        "terminalVerifierAIRInnerCompressedRows",
        "terminalCEAccepted",
        "innerCompressedAccepted",
        "verify(...) == true",
    ]
    for needle in forbidden:
        require(needle not in combined, f"terminal verifier AIR must not source rows from {needle}")
    batch_coefficient_section = combined.split("superneo/terminal-air/primitive-batch-coeff/v1", 1)[1]
    require("firstDigestField" not in batch_coefficient_section, "primitive batch coefficients must not use firstDigestField")
    require("prefix(4)" not in batch_coefficient_section, "primitive batch coefficients must not use four-byte prefixes")
    require(
        "spartanFRIDigestFields(coinDigest)" not in batch_coefficient_section,
        "primitive batch coefficients must not truncate SHA-256 through digest fields",
    )
    require("% GoldilocksField.modulus" not in batch_coefficient_section, "primitive batch coefficients must not use modulo reduction")


def validate_selected_depth(ledger: dict[str, Any]) -> None:
    depth = require_dict(ledger.get("selectedDepth"), "selectedDepth")
    require(depth.get("depthModel") == "bounded-depth", "selectedDepth.depthModel must be bounded-depth")
    require(depth.get("selectedMaximumDepth") == 3, "selectedDepth.selectedMaximumDepth must be 3")
    require(depth.get("selectedRecursiveCarryHops") == 2, "selectedDepth.selectedRecursiveCarryHops must be 2")
    require(
        require_dict(depth.get("depthIndexing"), "selectedDepth.depthIndexing") == EXPECTED_DEPTH_INDEXING,
        "selectedDepth.depthIndexing mismatch",
    )
    require(depth.get("currentProductDefaultMaximumDepth") == 3, "selectedDepth.currentProductDefaultMaximumDepth must be 3")
    require(depth.get("loadedParentChainRequired") is True, "selectedDepth.loadedParentChainRequired must be true")
    require(
        depth.get("recursiveChainRootSource") == "NumiSealProductVerificationResult.productCarryChainRoot",
        "selectedDepth.recursiveChainRootSource mismatch",
    )
    require(depth.get("polyDepthClaimAllowed") is True, "selectedDepth.polyDepthClaimAllowed must be true")
    require(
        depth.get("repositoryLocalSelectedDepthClaimAllowed") is True,
        "selectedDepth.repositoryLocalSelectedDepthClaimAllowed must be true",
    )
    require(
        depth.get("productionSelectedDepthClaimAllowed") is False,
        "selectedDepth.productionSelectedDepthClaimAllowed must stay false until production gates close",
    )


def validate_loss_notation(ledger: dict[str, Any]) -> None:
    notation = require_dict(ledger.get("lossNotation"), "lossNotation")
    required_symbols = {
        "securityParameter",
        "adversarySuccess",
        "sharedCoreLoss",
        "sourceFoldLoss",
        "terminalSealLoss",
        "recursiveCarryLoss",
        "zkSimulatorLoss",
        "publicCoinQROMLoss",
        "extractorLoss",
        "transcriptCollisionLoss",
        "productOpsReplayLoss",
        "constantTimeLeakageLoss",
        "releaseDistributionLoss",
    }
    require(set(notation) == required_symbols, "lossNotation keys mismatch")
    for key in required_symbols:
        require_string(notation.get(key), f"lossNotation.{key}")


def validate_component_losses(ledger: dict[str, Any]) -> None:
    components = ledger.get("componentLosses")
    require(isinstance(components, list), "componentLosses must be a list")
    require(len(components) == len(EXPECTED_COMPONENT_IDS), "componentLosses length mismatch")
    seen_ids: list[str] = []
    component_text = []
    for index, item in enumerate(components):
        component = require_dict(item, f"componentLosses[{index}]")
        component_id = require_string(component.get("id"), f"componentLosses[{index}].id")
        seen_ids.append(component_id)
        require(component.get("appliesPerAcceptedLayer") in {True, False}, f"{component_id}.appliesPerAcceptedLayer must be boolean")
        require_string(component.get("status"), f"{component_id}.status")
        require_string(component.get("lossSymbol"), f"{component_id}.lossSymbol")
        require_string(component.get("accountingRule"), f"{component_id}.accountingRule")
        require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
        require(component.get("productionClaimAllowed") in {True, False}, f"{component_id}.productionClaimAllowed must be boolean")
        if component_id == "constant-time-side-channel":
            require(
                component.get("productionClaimAllowed") is False,
                "constant-time-side-channel.productionClaimAllowed must remain false until whole-stack side-channel certification closes",
            )
        if component_id == "shared-cryptographic-core":
            require(
                component.get("status") == "shared-core-bad-event-dedup-instantiated",
                "shared-cryptographic-core status mismatch",
            )
            require(
                component.get("accountingManifest") == "TestVectors/product-shared-bad-event-dedup-v1.json",
                "shared-cryptographic-core must link shared bad-event dedup evidence",
            )
            evidence = require_string(component.get("requiredEvidence"), "shared-cryptographic-core.requiredEvidence")
            for needle in ["product-shared-bad-event-dedup-v1.json", "2^-129", "Module-SIS"]:
                require(needle in evidence, f"shared-cryptographic-core requiredEvidence must mention {needle}")
        if component_id in {"source-fold-knowledge", "terminal-numiseal-seal"}:
            require(
                component.get("status") == "finite-protocol-repeated-tape-bound-instantiated",
                f"{component_id} status must record selected repeated-tape finite-protocol instantiation",
            )
            require(
                component.get("accountingManifest") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
                f"{component_id} must link finite-protocol loss obstruction evidence",
            )
            require_relative_path(component.get("accountingManifest"), f"{component_id}.accountingManifest")
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            for needle in ["product-finite-protocol-loss-obstruction-v1.json", "finite-protocol", "2^-128"]:
                require(needle in evidence, f"{component_id} requiredEvidence must mention {needle}")
            if component_id == "terminal-numiseal-seal":
                require(
                    "terminal CE is pinned at 226 repeated challenge rounds" in evidence
                    and "fixed-kind CTCO repeated-tape" in evidence
                    and "(2/3)^226" in evidence,
                    "terminal-numiseal-seal evidence must pin terminal CE repeated challenge closure",
                )
                require(
                    "full Goldilocks field elements" in evidence
                    and "q = 2^64 - 2^32 + 1" in evidence
                    and "selectedPrimitiveBatchLaneCount = 4" in evidence
                    and "primitiveBatchCancellation <= batchContextCount/q^4" in evidence
                    and "batchContextCount = 1" in evidence,
                    "terminal-numiseal-seal evidence must charge primitive batching as batchContextCount/q^4 with four selected lanes",
                )
                require("1/q" not in evidence, "terminal evidence must not claim primitive batching over 1/q")
                require("2^32 domain" not in evidence, "terminal evidence must not retain 32-bit batching language")
                require("UInt32" not in evidence, "terminal evidence must not retain UInt32 batching language")
            if component_id == "source-fold-knowledge":
                require(
                    "fixed-kind CTCO repeated-tape" in evidence
                    and "16/q^4 + 1/5^81" in evidence,
                    "source-fold evidence must pin the fixed-kind repeated-tape closure route",
                )
                require("PiRLC/PiCCS" in evidence, "source-fold evidence must name the PiRLC/PiCCS repeated route")
        if component_id == "extractor-instantiation":
            require(
                component.get("accountingManifest") == "TestVectors/product-extractor-loss-accounting-v1.json",
                "extractor-instantiation must link product extractor loss accounting",
            )
            require_relative_path(component.get("accountingManifest"), "extractor-instantiation.accountingManifest")
            require(
                component.get("status") == "selected-depth-concrete-extractor-zero-loss-instantiated",
                "extractor-instantiation status must record selected-depth zero-loss instantiation",
            )
            evidence = require_string(component.get("requiredEvidence"), "extractor-instantiation.requiredEvidence")
            for needle in ["NumiSealProductConcreteExtractor.extract", "swiftConcreteExtractorEvidenceDigest", "epsilon_extract = 0"]:
                require(needle in evidence, f"extractor-instantiation requiredEvidence must mention {needle}")
        if component_id == "typed-recursive-carry":
            require(
                component.get("status") == "loaded-parent-chain-root-recomputed-selected-depth-3-instantiated",
                "typed-recursive-carry status must record loaded-parent chain-root recomputation",
            )
            rule = require_string(component.get("accountingRule"), "typed-recursive-carry.accountingRule")
            evidence = require_string(component.get("requiredEvidence"), "typed-recursive-carry.requiredEvidence")
            for needle in ["two recursive carry hops", "epsilon_carry = 0", "loaded accepted parent chain root", "typed carry statements"]:
                require(needle in rule, f"typed-recursive-carry accountingRule must mention {needle}")
            for needle in [
                "NumiSealProductVerificationResult.productCarryChainRoot",
                "recursive-carry-chain-root CTCO trace block",
                "metadata-only recursive parents",
            ]:
                require(needle in evidence, f"typed-recursive-carry requiredEvidence must mention {needle}")
        if component_id == "public-coin-qrom":
            require(
                component.get("accountingManifest") == "TestVectors/product-qrom-public-coin-accounting-v1.json",
                "public-coin-qrom must link product QROM public-coin accounting",
            )
            require_relative_path(component.get("accountingManifest"), "public-coin-qrom.accountingManifest")
            evidence = require_string(component.get("requiredEvidence"), "public-coin-qrom.requiredEvidence")
            require(
                "TestVectors/product-qrom-transform-preconditions-v1.json" in evidence,
                "public-coin-qrom requiredEvidence must link QROM transform preconditions",
            )
            require(
                "TestVectors/product-qrom-interactive-reduction-v1.json" in evidence,
                "public-coin-qrom requiredEvidence must link QROM interactive reduction",
            )
            for needle in ["CTCO", "384-bit H_bind", "ProductPerKindInteractiveSecurityEvidence", "epsilon_compiler_overhead = 0", "exact finite-probability wiring"]:
                require(needle in evidence, f"public-coin-qrom requiredEvidence must mention {needle}")
        if component_id == "zk-simulator-composition":
            require(
                component.get("status") == "proof-level-simulator-coupling-instantiated-production-side-channel-gated",
                "zk-simulator-composition status mismatch",
            )
            evidence = require_string(component.get("requiredEvidence"), "zk-simulator-composition.requiredEvidence")
            for needle in [
                "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
                "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
                "declared leakage model",
            ]:
                require(needle in evidence, f"zk-simulator-composition requiredEvidence must mention {needle}")
            rule = require_string(component.get("accountingRule"), "zk-simulator-composition.accountingRule")
            for needle in ["epsilon_zk_sim = 0", "fresh randomness-session", "mask-reuse rejection", "epsilon_ct"]:
                require(needle in rule, f"zk-simulator-composition accountingRule must mention {needle}")
        if component_id == "transcript-collision-domain-separation":
            require(
                component.get("accountingManifest") == "TestVectors/product-qrom-public-coin-accounting-v1.json",
                "transcript-collision-domain-separation must link product QROM public-coin accounting",
            )
            require_relative_path(component.get("accountingManifest"), "transcript-collision-domain-separation.accountingManifest")
            require(
                component.get("status") == "hbind-collision-bound-instantiated-source-hbind-open",
                "transcript-collision-domain-separation status mismatch",
            )
            evidence = require_string(component.get("requiredEvidence"), "transcript-collision-domain-separation.requiredEvidence")
            require(
                "TestVectors/product-qrom-collision-malleability-evidence-v1.json" in evidence,
                "transcript-collision-domain-separation requiredEvidence must link collision/malleability evidence",
            )
            require(
                "44 * 2^-256" in evidence and "11 CTCO binding targets" in evidence and "source H_bind acceptance binding is implemented" in evidence,
                "transcript-collision-domain-separation requiredEvidence must pin H_bind bound and source implementation status",
            )
        if component_id == "release-distribution":
            evidence = require_string(component.get("requiredEvidence"), "release-distribution.requiredEvidence")
            require(
                "TestVectors/product-release-distribution-evidence-v1.json" in evidence,
                "release-distribution requiredEvidence must link release distribution evidence",
            )
        component_text.append(json.dumps(component, sort_keys=True).lower())
    require(seen_ids == EXPECTED_COMPONENT_IDS, "componentLosses must stay in the pinned accounting order")
    joined = " ".join(component_text)
    for needle in ["extractor", "qrom", "collision", "simulator", "release", "swift", "llvm", "metal"]:
        require(needle in joined, f"component losses must mention {needle}")


def validate_total_loss_rule(ledger: dict[str, Any]) -> None:
    total = require_dict(ledger.get("totalLossRule"), "totalLossRule")
    selected = require_string(total.get("selectedDepthExpression"), "totalLossRule.selectedDepthExpression")
    recursive = require_string(total.get("recursivePromotionExpression"), "totalLossRule.recursivePromotionExpression")
    for symbol in [
        "epsilon_fold",
        "epsilon_core_shared",
        "epsilon_terminal",
        "epsilon_zk_sim",
        "epsilon_qrom",
        "epsilon_extract",
        "epsilon_carry",
        "epsilon_collision",
    ]:
        require(symbol in selected, f"selected-depth expression must include {symbol}")
    require("depth=3" in selected and "3 *" in selected and "2 * epsilon_carry" in selected, "selected-depth expression must account depth 3 and two carry hops")
    require("epsilon_carry" in recursive and "max(d - 1, 0)" in recursive, "recursive promotion expression must include carry-hop accounting")
    require(total.get("allComponentLossesInstantiated") is True, "totalLossRule.allComponentLossesInstantiated must be true")
    require(total.get("totalLossWithinBudget") is True, "totalLossRule.totalLossWithinBudget must be true")
    require(total.get("selectedDepthLossClaimAllowed") is True, "totalLossRule.selectedDepthLossClaimAllowed must be true")


def validate_promotion_and_blockers(ledger: dict[str, Any]) -> None:
    blockers = ledger.get("hardClaimBlockers")
    require(isinstance(blockers, list), "hardClaimBlockers must be a list")
    for index, blocker in enumerate(blockers):
        require_string(blocker, f"hardClaimBlockers[{index}]")
    require(blockers == [], "hardClaimBlockers must be empty for repository-local selected-depth theorem use")
    promotion = require_dict(ledger.get("promotionRule"), "promotionRule")
    require(
        promotion.get("repositoryLocalProductTheoremClaimAllowed") is True,
        "promotionRule.repositoryLocalProductTheoremClaimAllowed must be true",
    )
    for key in EXPECTED_PROMOTION_FALSE_FLAGS:
        require(promotion.get(key) is False, f"promotionRule.{key} must stay false until production gates close")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "promotionRule.productionConstantTimeClaimAllowed must remain false until side-channel certification closes",
    )
    require(
        promotion.get("productionRecursiveCarryClaimAllowed") is False,
        "promotionRule.productionRecursiveCarryClaimAllowed must stay false until production gates close",
    )
    require(
        promotion.get("requiresAllProductionGatesSatisfied") is True,
        "promotionRule.requiresAllProductionGatesSatisfied must be true",
    )
    require(promotion.get("requiresAllComponentLossesInstantiated") is True, "promotionRule.requiresAllComponentLossesInstantiated must be true")
    require(promotion.get("requiresTotalLossWithinBudget") is True, "promotionRule.requiresTotalLossWithinBudget must be true")


def validate_docs_and_gate() -> None:
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-selected-depth-loss-accounting.py" in gate,
        "production gate must run selected-depth loss-accounting validator",
    )
    require(
        "run_step Scripts/test-product-selected-depth-loss-accounting-validation.py" in gate,
        "production gate must run selected-depth loss-accounting regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-collision-malleability-evidence.py" in gate,
        "production gate must run QROM collision/malleability evidence validator",
    )
    require(
        "run_step Scripts/validate-product-shared-bad-event-dedup.py" in gate,
        "production gate must run shared bad-event dedup validator",
    )
    require(
        "run_step Scripts/validate-product-finite-protocol-loss-obstruction.py" in gate,
        "production gate must run finite-protocol loss obstruction validator",
    )


def validate_ledger(path: Path) -> None:
    ledger = read_json(path)
    text = json.dumps(ledger, sort_keys=True).lower()
    require("external" + " audit" not in text, "ledger must not encode outsourced review as a product gate")
    require("per-kind theorem assumption" not in text, "ledger must not leave extractor claims as per-kind theorem assumptions")
    require(set(ledger) == EXPECTED_TOP_LEVEL_KEYS, "top-level ledger keys must match the v1 contract exactly")
    require(ledger.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(ledger.get("ledgerID") == "superneo-product-selected-depth-loss-accounting-v1", "ledgerID mismatch")
    require(
        ledger.get("claimStatus") == "selected-depth-loss-contract-repository-local-selected-depth-claim",
        "claimStatus must record the repository-local selected-depth claim boundary",
    )
    validate_related_manifests(ledger)
    validate_formal_surface(ledger)
    validate_selected_depth(ledger)
    validate_loss_notation(ledger)
    validate_component_losses(ledger)
    validate_total_loss_rule(ledger)
    validate_promotion_and_blockers(ledger)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else LEDGER
    if not path.is_absolute():
        path = ROOT / path
    validate_ledger(path)
    print("product selected-depth loss accounting validation passed")


if __name__ == "__main__":
    main()
