#!/usr/bin/env python3
"""Validate the product cryptographic security theorem dossier."""

from __future__ import annotations

import json
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DOSSIER = ROOT / "TestVectors" / "product-crypto-security-dossier-v1.json"
GOLDILOCKS_MODULUS = 18_446_744_069_414_584_321

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "dossierID",
    "claimStatus",
    "formalTheorem",
    "relatedManifests",
    "productTheoremCoverage",
    "supportedProductDepth",
    "latticeAssumptionDossier",
    "normGrowthAndFailureBudget",
    "extractorLossAccounting",
    "fiatShamirQROMPosition",
    "totalLossBudget",
    "zkPrivacyProofStatus",
    "carryRecursionClosure",
    "proofSizeLatencyComparison",
    "implementationHardening",
    "promotionRule",
}

EXPECTED_COVERAGE = {
    "source fold relation",
    "NumiSeal terminal relation",
    "NumiSealZK masked residual relation",
    "typed recursive carry relation",
    "transcript binding",
    "artifact/proof-envelope binding",
    "verifier acceptance policy",
    "soundness/completeness/ZK composition",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiatShamirModel",
    "ProductRecursionDepthModel",
    "ProductSecurityParameters",
    "ProductSystemBindings",
    "ProductSystemBindingsAccepted",
    "ProductBoundedDepthLossEvidence",
    "ProductBoundedDepthLossAccepted",
    "ProductLatticeAssumptionDossier",
    "ProductLatticeAssumptionDossierAccepted",
    "ProductFiatShamirQROMEvidence",
    "ProductFiatShamirQROMAccepted",
    "ProductCompletenessSoundnessZKClaim",
    "ProductCompletenessSoundnessZKHolds",
    "ProductSecurityTheoremEvidence",
    "ProductSelectedDepthLossLedger",
    "ProductSelectedDepthLossLedgerAccepted",
    "ProductFiniteProtocolNumericLossObstruction",
    "ProductFiniteProtocolNumericLossObstructionAccepted",
    "ProductExtractorLossAccounting",
    "ProductExtractorLossAccountingAccepted",
    "ProductFiatShamirTranscriptSchedule",
    "ProductFiatShamirTranscriptScheduleAccepted",
    "ProductFiatShamirTransformPreconditions",
    "ProductFiatShamirTransformPreconditionsAccepted",
    "ProductQROMInteractiveReduction",
    "ProductQROMInteractiveReductionAccepted",
    "ProductFiatShamirLossAccounting",
    "ProductFiatShamirLossAccountingAccepted",
    "ProductQROMCompilerOverheadBound",
    "ProductQROMCompilerOverheadBoundAccepted",
    "ProductSharedBadEventDeduplication",
    "ProductSharedBadEventDeduplicationAccepted",
    "ProductQROMTransformFamily",
    "ProductCompilerFamily",
    "ProductHashOracleInstantiation",
    "ProductHashOracleInstantiationAccepted",
    "ProductInteractiveProtocolDefinitions",
    "ProductInteractiveProtocolDefinitionsAccepted",
    "ProductInteractiveSpecialSoundnessData",
    "ProductInteractiveSpecialSoundnessDataAccepted",
    "ProductInteractiveDelayedMessageData",
    "ProductInteractiveDelayedMessageDataAccepted",
    "ProductInteractiveUniqueResponseData",
    "ProductInteractiveUniqueResponseDataAccepted",
    "ProductChallengeTapeCommitOpenCompiler",
    "ProductChallengeTapeCommitOpenCompilerAccepted",
    "ProductQROMCollisionBound",
    "ProductQROMCollisionBoundAccepted",
    "ProductQROMMalleabilityBound",
    "ProductQROMMalleabilityBoundAccepted",
    "ProductInteractiveSecurityBounds",
    "ProductInteractiveSecurityBoundsAccepted",
    "ProductQROMTotalLossInstantiated",
    "ProductQROMTotalLossInstantiatedAccepted",
    "ProductInstantiatedQROMEvidence",
    "ProductInstantiatedQROMEvidenceAccepted",
    "ProductQROMTightTransform",
    "ProductTotalLossBudget",
    "ProductTotalLossBudgetAccepted",
    "ProductExactFiniteProbabilityWiring",
    "ProductExactFiniteProbabilityWiringAccepted",
    "ProductReleaseDistributionEvidence",
    "ProductReleaseDistributionEvidenceAccepted",
    "productSecurityTheorem_from_evidence",
    "productSecurityTheorem_requires_bounded_depth",
    "productSecurityTheorem_requires_selected_depth_loss_accounting",
    "productSecurityTheorem_requires_finite_protocol_numeric_loss_instantiation",
    "productSecurityTheorem_requires_extractor_loss_accounting",
    "productSecurityTheorem_requires_qrom_transcript_schedule",
    "productSecurityTheorem_requires_qrom_transform_preconditions",
    "productSecurityTheorem_requires_qrom_interactive_reduction",
    "productSecurityTheorem_requires_qrom_compiler_overhead_bound",
    "productSecurityTheorem_requires_shared_bad_event_deduplication",
    "productSecurityTheorem_requires_qrom_loss_accounting",
    "productSecurityTheorem_requires_qrom_collision_malleability_exclusion",
    "productSecurityTheorem_requires_total_loss_budget",
    "productSecurityTheorem_requires_exact_finite_probability_wiring",
    "productSecurityTheorem_requires_release_distribution_evidence",
    "productSecurityTheorem_requires_qrom_accounting",
    "productSecurityTheorem_requires_artifact_envelope_binding",
    "productSecurityTheorem_from_instantiated_qrom",
}

EXPECTED_MANIFESTS = {
    "numiSealConformanceScope": "TestVectors/numiseal-conformance-scope-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "numiSealZKMaskDistributionEvidence": "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
    "numiSealZKSimulatorCouplingEvidence": "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
    "constantTimeScope": "TestVectors/constant-time-scope-v1.json",
    "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
    "constantTimeReleaseEvidence": "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
    "benchmarkCoverage": "TestVectors/benchmark-coverage-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productSharedBadEventDedup": "TestVectors/product-shared-bad-event-dedup-v1.json",
    "productFiniteProtocolLossObstruction": "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "productReleaseDistributionEvidence": "TestVectors/product-release-distribution-evidence-v1.json",
    "latticeEstimator": "lattice-estimator-results/superneo-goldilocks-phi81.json",
}

EXPECTED_LATTICE = {
    "assumptionName": "Module-SIS over Goldilocks/Phi81 Ajtai commitments",
    "profileID": 1,
    "qDecimal": "18446744069414584321",
    "qHex": "ffffffff00000001",
    "field": "Goldilocks",
    "ring": "F_q[X]/(X^54 + X^27 + 1)",
    "cyclotomicIndex": 81,
    "ringDegree": 54,
    "kappa": 18,
    "decompositionLength": 14,
    "normBound": 2,
    "challengeExpansionFactor": 216,
    "maxFreshBatchCount": 61,
    "maxPriorCEClaimCount": 14,
    "moduleSISDimension": 972,
    "estimatorMSISLength": 1073741824,
    "lengthBoundL2": "927712935936",
    "decompositionRadixBound": 16384,
    "strongSamplingLeft": 16200,
    "claimedSecurityBits": 129,
    "pinnedEstimatorMinimumROPBits": 129.1,
}

EXPECTED_COST_ROWS = {
    ("MATZOV", "default"): 129.1,
    ("ADPS16", "classical"): 100.7,
    ("ADPS16", "quantum"): 91.4,
    ("ADPS16", "paranoid"): 71.6,
    ("ChaLoy21", "enumeration"): 88.7,
    ("LaaMosPol14", "enumeration"): 122.4,
}


def fail(message: str) -> None:
    print(f"product crypto security dossier validation failed: {message}", file=sys.stderr)
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


def require_list(value: Any, label: str, *, allow_empty: bool = False) -> list[Any]:
    require(isinstance(value, list) and (allow_empty or value), f"{label} must be a non-empty list")
    return value


def require_string_list(value: Any, label: str, *, allow_empty: bool = False) -> list[str]:
    values = require_list(value, label, allow_empty=allow_empty)
    result: list[str] = []
    for index, item in enumerate(values):
        require(isinstance(item, str) and item, f"{label}[{index}] must be a non-empty string")
        result.append(item)
    return result


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false until the required evidence is instantiated")


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def format_fraction(value: Fraction) -> str:
    if value.denominator == 1:
        return str(value.numerator)
    return f"{value.numerator}/{value.denominator}"


def selected_instantiated_partial_sum() -> Fraction:
    return (
        Fraction(1, 1 << 129)
        + Fraction(16, GOLDILOCKS_MODULUS**4)
        + Fraction(1, 5**81)
        + Fraction(2**226, 3**226)
        + Fraction(9, 1 << 254)
    )


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_formal_theorem(dossier: dict[str, Any]) -> None:
    formal = require_dict(dossier.get("formalTheorem"), "formalTheorem")
    module_path = require_relative_path(formal.get("module"), "formalTheorem.module")
    require(
        formal.get("rootImport") == "import SuperNeoFormal.ProductSecurityTheorem",
        "formalTheorem.rootImport must pin the product security theorem import",
    )
    root = (ROOT / "Formal" / "SuperNeoFormal.lean").read_text(encoding="utf-8")
    require(
        "import SuperNeoFormal.ProductSecurityTheorem" in root,
        "Formal/SuperNeoFormal.lean must import the product security theorem module",
    )
    source = module_path.read_text(encoding="utf-8")
    declarations = set(require_string_list(formal.get("declarations"), "formalTheorem.declarations"))
    require(
        EXPECTED_FORMAL_DECLARATIONS.issubset(declarations),
        "formalTheorem.declarations must pin every product theorem surface declaration",
    )
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing declaration {declaration}")


def validate_related_manifests(dossier: dict[str, Any]) -> None:
    related = require_dict(dossier.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the current evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")


def validate_coverage(dossier: dict[str, Any]) -> None:
    coverage = set(require_string_list(dossier.get("productTheoremCoverage"), "productTheoremCoverage"))
    require(EXPECTED_COVERAGE.issubset(coverage), "product theorem coverage is missing required relation coverage")


def validate_depth(dossier: dict[str, Any]) -> None:
    depth = require_dict(dossier.get("supportedProductDepth"), "supportedProductDepth")
    require(depth.get("depthModel") == "bounded-depth", "product depth model must stay bounded-depth")
    require(depth.get("currentProductDefaultMaximumDepth") == 1, "current product default maximum depth must be 1")
    require(depth.get("theoremMaximumDepth") == 1, "theorem maximum depth must be 1 until losses are instantiated")
    require(depth.get("polyDepthTheoremClaimAllowed") is True, "supportedProductDepth.polyDepthTheoremClaimAllowed must be true")
    recursive_default = require_string(depth.get("recursiveCarryProductDefault"), "recursiveCarryProductDefault").lower()
    require(
        "base" in recursive_default and "typed-required" in recursive_default,
        "recursive carry product default must distinguish base and recursive child artifacts",
    )
    require(depth.get("recursiveCarryPromotionAllowed") is True, "supportedProductDepth.recursiveCarryPromotionAllowed must be true")
    obligations_list = require_string_list(depth.get("remainingForDepthPromotion"), "supportedProductDepth.remainingForDepthPromotion", allow_empty=True)
    obligations = " ".join(obligations_list).lower()
    require("recursive typed carry" not in obligations, "recursive typed carry must not remain a depth-promotion obligation")
    require("polynomial-depth" not in obligations, "polynomial-depth must not remain a depth-promotion obligation")

    loss_ledger = read_json(ROOT / str(EXPECTED_MANIFESTS["selectedDepthLossAccounting"]))
    require(loss_ledger.get("schemaVersion") == 1, "selected-depth loss ledger schemaVersion must be 1")
    require(
        loss_ledger.get("claimStatus") == "selected-depth-loss-contract-repository-local-production-claim",
        "selected-depth loss ledger claimStatus must stay precise",
    )
    selected_depth = require_dict(loss_ledger.get("selectedDepth"), "selectedDepthLossAccounting.selectedDepth")
    require(
        selected_depth.get("selectedMaximumDepth") == depth.get("theoremMaximumDepth"),
        "selected-depth loss ledger depth must match the product theorem maximum depth",
    )
    total = require_dict(loss_ledger.get("totalLossRule"), "selectedDepthLossAccounting.totalLossRule")
    require(total.get("selectedDepthLossClaimAllowed") is True, "selectedDepthLossAccounting.selectedDepthLossClaimAllowed must be true")
    blockers = loss_ledger.get("hardClaimBlockers")
    require(blockers == [], "selected-depth loss ledger blockers must be empty")
    ledger_related = require_dict(loss_ledger.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        ledger_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "selected-depth ledger must link extractor accounting",
    )
    require(
        ledger_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "selected-depth ledger must link QROM Fiat-Shamir accounting",
    )
    require(
        ledger_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "selected-depth ledger must link QROM transform preconditions",
    )
    require(
        ledger_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "selected-depth ledger must link QROM interactive reduction",
    )
    require(
        ledger_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "selected-depth ledger must link QROM collision/malleability evidence",
    )
    require(
        ledger_related.get("productSharedBadEventDedup") == "TestVectors/product-shared-bad-event-dedup-v1.json",
        "selected-depth ledger must link shared bad-event dedup evidence",
    )
    require(
        ledger_related.get("productFiniteProtocolLossObstruction") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
        "selected-depth ledger must link finite-protocol loss obstruction evidence",
    )
    require(
        ledger_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "selected-depth ledger must link the total loss budget",
    )


def validate_lattice(dossier: dict[str, Any]) -> None:
    lattice = require_dict(dossier.get("latticeAssumptionDossier"), "latticeAssumptionDossier")
    for key, expected in EXPECTED_LATTICE.items():
        require(lattice.get(key) == expected, f"latticeAssumptionDossier.{key} mismatch")
    require(lattice.get("normRoots") == [-1, 0, 1], "norm roots must stay pinned")
    require(lattice.get("challengeCoefficients") == [-2, -1, 0, 1, 2], "challenge coefficients must stay pinned")
    require(lattice.get("productionPostQuantumClaimAllowed") is True, "latticeAssumptionDossier.productionPostQuantumClaimAllowed must be true")
    require("128-bit post-quantum claim" in require_string(lattice.get("postQuantumBoundary"), "postQuantumBoundary"), "postQuantumBoundary must state the PQ boundary")

    estimator = read_json(ROOT / str(EXPECTED_MANIFESTS["latticeEstimator"]))
    profile = require_dict(estimator.get("profile"), "latticeEstimator.profile")
    module_sis = require_dict(estimator.get("module_sis_parameters"), "latticeEstimator.module_sis_parameters")
    pinned = require_dict(estimator.get("pinned_reproduction"), "latticeEstimator.pinned_reproduction")
    require(profile.get("q") == int(lattice["qDecimal"]), "lattice q must match estimator artifact")
    require(profile.get("cyclotomicDegree") == lattice["ringDegree"], "ring degree must match estimator artifact")
    require(profile.get("kappa") == lattice["kappa"], "kappa must match estimator artifact")
    require(profile.get("decompositionLength") == lattice["decompositionLength"], "decomposition length must match estimator artifact")
    require(module_sis.get("n_sis") == lattice["moduleSISDimension"], "n_sis must match dossier")
    require(module_sis.get("m_sis") == lattice["estimatorMSISLength"], "m_sis must match dossier")
    require(str(module_sis.get("length_bound_l2")) == lattice["lengthBoundL2"], "length_bound_l2 must match dossier")
    require(module_sis.get("norm") == lattice["normBound"], "norm must match dossier")
    require(module_sis.get("strong_sampling_left") == lattice["strongSamplingLeft"], "strong sampling left must match dossier")
    require(pinned.get("minimum_extracted_rop_bits") == lattice["pinnedEstimatorMinimumROPBits"], "ROP bits must match pinned estimator")
    require(pinned.get("threshold_bits") == lattice["claimedSecurityBits"], "threshold bits must match claimed security bits")

    rows = require_string_cost_rows(lattice.get("costEstimates"))
    require(rows == EXPECTED_COST_ROWS, "costEstimates must pin the current sensitivity table")


def require_string_cost_rows(value: Any) -> dict[tuple[str, str], float]:
    require(isinstance(value, list) and value, "costEstimates must be a non-empty list")
    rows: dict[tuple[str, str], float] = {}
    for index, item in enumerate(value):
        row = require_dict(item, f"costEstimates[{index}]")
        model = require_string(row.get("model"), f"costEstimates[{index}].model")
        cost_class = require_string(row.get("costClass"), f"costEstimates[{index}].costClass")
        rop_bits = row.get("ropBits")
        require(isinstance(rop_bits, (int, float)), f"costEstimates[{index}].ropBits must be numeric")
        rows[(model, cost_class)] = float(rop_bits)
    return rows


def validate_norm_budget(dossier: dict[str, Any]) -> None:
    norm = require_dict(dossier.get("normGrowthAndFailureBudget"), "normGrowthAndFailureBudget")
    require(norm.get("strongSamplingInequality") == "(K + k) * T * (b - 1) < b^k", "strong sampling inequality mismatch")
    require(norm.get("leftSide") == 16200, "strong sampling left side mismatch")
    require(norm.get("rightSide") == 16384, "strong sampling right side mismatch")
    require(norm.get("status") == "profile-bound-recorded-product-path-losses-not-fully-instantiated", "norm-growth status must stay precise")
    require(norm.get("failureProbabilityBudgetRecorded") is True, "failure probability budget must be recorded")
    require(
        norm.get("finiteProtocolLossObstructionManifest") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
        "norm-growth budget must link finite-protocol loss obstruction evidence",
    )
    require_relative_path("TestVectors/product-finite-protocol-loss-obstruction-v1.json", "finiteProtocolLossObstructionManifest")
    numeric_status = require_string(norm.get("selectedNumericLossStatus"), "normGrowthAndFailureBudget.selectedNumericLossStatus").lower()
    for needle in ["one-shot", "repeated-tape", "pirlc", "piccs", "epsilon_fold", "2^-128"]:
        require(needle in numeric_status, f"selected numeric loss status must mention {needle}")
    obligations = " ".join(require_string_list(norm.get("remainingObligations"), "normGrowthAndFailureBudget.remainingObligations")).lower()
    for needle in ["one-shot", "finite-protocol", "typed carry", "fiat-shamir"]:
        require(needle in obligations, f"norm-growth obligations must mention {needle}")


def validate_extractor_loss_accounting(dossier: dict[str, Any]) -> None:
    extractor = require_dict(dossier.get("extractorLossAccounting"), "extractorLossAccounting")
    require(
        extractor.get("accountingManifest") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "extractorLossAccounting.accountingManifest mismatch",
    )
    require_relative_path("TestVectors/product-extractor-loss-accounting-v1.json", "extractorLossAccounting.accountingManifest")
    require(
        extractor.get("claimStatus") == "selected-depth-concrete-extractor-loss-instantiated-repository-local-production-claim",
        "extractorLossAccounting.claimStatus must record selected-depth instantiation",
    )
    selected = require_string(extractor.get("selectedDepthExpression"), "extractorLossAccounting.selectedDepthExpression")
    recursive = require_string(extractor.get("recursivePromotionExpression"), "extractorLossAccounting.recursivePromotionExpression")
    require("epsilon_extract(depth=1) = 0" in selected, "extractor selected-depth expression must be exact zero")
    require("epsilon_extract_carry" in recursive and "max(d - 1, 0)" in recursive, "extractor recursive expression must include carry-hop loss")
    for key in [
        "sourceFoldExtractorSpecified",
        "terminalSealExtractorSpecified",
        "productEnvelopeExtractorSpecified",
        "recursiveCarryExtractorSpecified",
        "extractorLossWithinBudget",
        "productionExtractorClaimAllowed",
    ]:
        require(extractor.get(key) is True, f"extractorLossAccounting.{key} must be true")
    obligations = " ".join(require_string_list(extractor.get("remainingObligations"), "extractorLossAccounting.remainingObligations")).lower()
    for needle in ["recursive carry", "promoted-depth", "ctco online extraction"]:
        require(needle in obligations, f"extractor loss obligations must mention {needle}")

    manifest = read_json(ROOT / "TestVectors/product-extractor-loss-accounting-v1.json")
    require(manifest.get("schemaVersion") == 1, "extractor accounting schemaVersion must be 1")
    require(
        manifest.get("claimStatus") == "selected-depth-concrete-extractor-loss-instantiated-repository-local-production-claim",
        "extractor accounting claimStatus must record selected-depth instantiation",
    )
    loss_rule = require_dict(manifest.get("lossRule"), "extractor accounting lossRule")
    require(loss_rule.get("productionExtractorClaimAllowed") is True, "extractor accounting productionExtractorClaimAllowed must be true")


def validate_fiat_shamir(dossier: dict[str, Any]) -> None:
    qrom = require_dict(dossier.get("fiatShamirQROMPosition"), "fiatShamirQROMPosition")
    require(qrom.get("model") == "ideal-split-qro", "Fiat-Shamir model must be ideal-split-qro")
    require(
        qrom.get("accountingManifest") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "fiatShamirQROMPosition.accountingManifest mismatch",
    )
    require_relative_path("TestVectors/product-qrom-fiat-shamir-accounting-v1.json", "fiatShamirQROMPosition.accountingManifest")
    require(
        qrom.get("transcriptScheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "fiatShamirQROMPosition.transcriptScheduleManifest mismatch",
    )
    require_relative_path("TestVectors/product-qrom-transcript-schedule-v1.json", "fiatShamirQROMPosition.transcriptScheduleManifest")
    require(
        qrom.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "fiatShamirQROMPosition.transformPreconditionManifest mismatch",
    )
    require_relative_path("TestVectors/product-qrom-transform-preconditions-v1.json", "fiatShamirQROMPosition.transformPreconditionManifest")
    require(
        qrom.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "fiatShamirQROMPosition.interactiveReductionManifest mismatch",
    )
    require_relative_path("TestVectors/product-qrom-interactive-reduction-v1.json", "fiatShamirQROMPosition.interactiveReductionManifest")
    require(
        qrom.get("samplerEncodingEvidenceManifest") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "fiatShamirQROMPosition.samplerEncodingEvidenceManifest mismatch",
    )
    require_relative_path("TestVectors/product-qrom-sampler-encoding-evidence-v1.json", "fiatShamirQROMPosition.samplerEncodingEvidenceManifest")
    require(
        qrom.get("collisionMalleabilityEvidenceManifest") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "fiatShamirQROMPosition.collisionMalleabilityEvidenceManifest mismatch",
    )
    require_relative_path(
        "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "fiatShamirQROMPosition.collisionMalleabilityEvidenceManifest",
    )
    require(
        qrom.get("claimStatus") == "qrom-ctco-split-qro-contract-repository-local-production-claim",
        "fiatShamirQROMPosition.claimStatus must stay precise",
    )
    require(qrom.get("transformFamily") == "ctco", "fiatShamirQROMPosition.transformFamily must be ctco")
    require(
        qrom.get("fallbackTransformFamily") == "merkle-straightline",
        "fiatShamirQROMPosition.fallbackTransformFamily must be merkle-straightline",
    )
    require(qrom.get("challengeOracleBits") == 256, "challengeOracleBits must stay 256")
    require(qrom.get("bindingOracleBits") == 384, "bindingOracleBits must stay 384")
    require(qrom.get("bindingTargetEventCount") == 9, "bindingTargetEventCount must stay 9")
    require(qrom.get("interactiveProtocolSpecified") is True, "fiatShamirQROMPosition.interactiveProtocolSpecified must be true")
    require(qrom.get("quantumOracleQueryBoundAccounted") is True, "fiatShamirQROMPosition.quantumOracleQueryBoundAccounted must be true after Q_H bound instantiation")
    require(qrom.get("queryBoundQH") == "2^64", "fiatShamirQROMPosition.queryBoundQH must be 2^64")
    require(qrom.get("queryBoundLog2") == 64, "fiatShamirQROMPosition.queryBoundLog2 must be 64")
    require(qrom.get("selectedDepthProtocolChallengeDerivations") == 8_755_125, "fiatShamirQROMPosition.selectedDepthProtocolChallengeDerivations mismatch")
    require_true(qrom.get("transformPreconditionsSatisfied"), "fiatShamirQROMPosition.transformPreconditionsSatisfied")
    require(qrom.get("productionQROMClaimAllowed") is True, "fiatShamirQROMPosition.productionQROMClaimAllowed must be true")
    require(qrom.get("sourceHBindImplementationComplete") is True, "fiatShamirQROMPosition.sourceHBindImplementationComplete")
    require(qrom.get("publicCoinChallengeScheduleSpecified") is True, "public coin challenge schedule must be recorded")
    require(qrom.get("transcriptDomainSeparatorsBound") is True, "transcript domain separator binding must be recorded")
    require(qrom.get("proofKindSeparationBound") is True, "proof kind separation binding must be recorded")
    require(
        qrom.get("structuralTranscriptCollisionMalleabilityExcluded") is True,
        "structural transcript collision/malleability evidence must be recorded",
    )
    require(qrom.get("transcriptCollisionMalleabilityExcluded") is True, "H_bind collision/malleability bound must be recorded")
    require(qrom.get("interactiveLossChargedOutsideQROM") is True, "interactive loss must be charged outside epsilon_qrom")
    require(qrom.get("interactiveSecurityBoundsInstantiated") is True, "interactive security bounds must be instantiated outside epsilon_qrom")
    require(qrom.get("hashQROInstantiationAssumptionPinned") is True, "split-QRO assumption must be pinned")
    require_true(qrom.get("hashQROInstantiationProofProvided"), "fiatShamirQROMPosition.hashQROInstantiationProofProvided")
    require(qrom.get("legacyDFM20InterfaceDeprecated") is True, "legacy DFM20 interface must be deprecated")
    expression = require_string(qrom.get("selectedDepthExpression"), "fiatShamirQROMPosition.selectedDepthExpression")
    for symbol in ["epsilon_compiler_overhead", "epsilon_hash_model_gap"]:
        require(symbol in expression, f"QROM selected-depth expression must include {symbol}")
    for stale in ["epsilon_fs_transform", "epsilon_precondition", "epsilon_qro_queries", "epsilon_proof_kind_malleability", "2*Q_H", "n_kind!"]:
        require(stale not in expression, f"QROM selected-depth expression must not include legacy symbol {stale}")
    require("epsilon_transcript_collision" not in expression, "QROM expression must export binding failures as epsilon_collision")
    mapping = require_dict(qrom.get("ledgerTermMapping"), "fiatShamirQROMPosition.ledgerTermMapping")
    require(
        mapping.get("epsilon_qrom") == ["epsilon_compiler_overhead", "epsilon_hash_model_gap"],
        "QROM ledgerTermMapping.epsilon_qrom mismatch",
    )
    require(
        mapping.get("epsilon_collision") == ["epsilon_bind"],
        "QROM ledgerTermMapping.epsilon_collision mismatch",
    )
    obligations = " ".join(require_string_list(qrom.get("remainingObligations"), "fiatShamirQROMPosition.remainingObligations")).lower()
    require("special-soundness" not in obligations, "interactive special-soundness must not remain a QROM obligation")
    require("simulator" not in obligations, "closed ZK simulator coupling must not remain a QROM obligation")
    for needle in ["shake256", "epsilon_replay", "epsilon_ct", "epsilon_release", "numeric total-loss"]:
        require(needle in obligations, f"QROM obligations must mention {needle}")
    schedule = read_json(ROOT / "TestVectors/product-qrom-transcript-schedule-v1.json")
    require(schedule.get("schemaVersion") == 1, "QROM transcript schedule schemaVersion must be 1")
    require(
        schedule.get("claimStatus") == "qrom-transcript-schedule-contract-repository-local-production-claim",
        "QROM transcript schedule claimStatus must stay precise",
    )
    ledger_binding = require_dict(schedule.get("ledgerBinding"), "QROM transcript schedule ledgerBinding")
    require(ledger_binding.get("numericQueryBoundInstantiated") is True, "QROM transcript schedule numericQueryBoundInstantiated must be true")
    require(ledger_binding.get("selectedQHLog2") == 64, "QROM transcript schedule selectedQHLog2 must be 64")
    manifest = read_json(ROOT / "TestVectors/product-qrom-fiat-shamir-accounting-v1.json")
    require(manifest.get("schemaVersion") == 1, "QROM accounting schemaVersion must be 1")
    require(
        manifest.get("claimStatus") == "qrom-ctco-split-qro-contract-repository-local-production-claim",
        "QROM accounting claimStatus must stay precise",
    )
    hash_model = require_dict(manifest.get("hashModel"), "QROM accounting hashModel")
    require(hash_model.get("model") == "ideal-split-qro", "QROM accounting hashModel.model mismatch")
    require(hash_model.get("concreteHashRecommendation") == "SHAKE256-domain-separated", "QROM accounting hash recommendation mismatch")
    challenge = require_dict(hash_model.get("challengeOracle"), "QROM accounting challengeOracle")
    binding = require_dict(hash_model.get("bindingOracle"), "QROM accounting bindingOracle")
    merkle = require_dict(hash_model.get("merkleOracle"), "QROM accounting merkleOracle")
    require(challenge.get("outputBits") == 256, "QROM accounting H_chal must be 256 bits")
    require(binding.get("outputBits") == 384, "QROM accounting H_bind must be 384 bits")
    require(binding.get("bindingTargetEventCount") == 9, "QROM accounting binding target count must be 9")
    require(merkle.get("outputBits") == 384, "QROM accounting H_mt must be 384 bits")
    require(hash_model.get("splitOraclesPinned") is True, "QROM accounting split oracles must be pinned")
    require(hash_model.get("theoremCriticalBindingsUseHBind") is True, "theorem-critical bindings must use H_bind")
    require(hash_model.get("hashQROInstantiationAssumptionPinned") is True, "QROM accounting hash assumption must be pinned")
    require_true(hash_model.get("hashQROInstantiationProofProvided"), "QROM accounting hashQROInstantiationProofProvided")
    fiat_model = require_dict(manifest.get("fiatShamirModel"), "QROM accounting fiatShamirModel")
    require(fiat_model.get("transformFamily") == "ctco", "QROM accounting transform family must be ctco")
    require(fiat_model.get("fallbackTransformFamily") == "merkle-straightline", "QROM accounting fallback family mismatch")
    require(fiat_model.get("interactiveLossChargedOutsideQROM") is True, "QROM accounting must charge interactive loss outside QROM")
    require(fiat_model.get("legacyDFM20InterfaceDeprecated") is True, "QROM accounting must deprecate legacy DFM20")
    require(fiat_model.get("sourceImplementationComplete") is True, "QROM accounting sourceImplementationComplete must be true")
    loss_rule = require_dict(manifest.get("lossRule"), "QROM accounting lossRule")
    require_true(loss_rule.get("productionQROMClaimAllowed"), "QROM accounting productionQROMClaimAllowed")
    manifest_expression = require_string(loss_rule.get("selectedDepthExpression"), "QROM accounting selectedDepthExpression")
    for symbol in ["epsilon_compiler_overhead", "epsilon_hash_model_gap"]:
        require(symbol in manifest_expression, f"QROM accounting selectedDepthExpression must include {symbol}")
    require(
        loss_rule.get("compilerOverheadInstantiatedExpression") == "epsilon_compiler_overhead = 0 in the ideal split-QRO CTCO theorem model",
        "QROM accounting compiler overhead instantiation mismatch",
    )
    require(
        loss_rule.get("hashModelGapInstantiatedExpression")
        == "epsilon_hash_model_gap = 0 in the ideal split-QRO model; concrete SHAKE256 promotion remains a separate hash-instantiation claim",
        "QROM accounting hash-model gap instantiation mismatch",
    )
    require(loss_rule.get("allQROMLossTermsInstantiated") is True, "QROM accounting allQROMLossTermsInstantiated must be true")
    require(loss_rule.get("qromLossWithinBudget") is True, "QROM accounting qromLossWithinBudget must be true")
    require("n_kind!" not in manifest_expression, "QROM accounting selectedDepthExpression must not carry legacy factorial loss")
    require(loss_rule.get("interactiveLossChargedOutsideQROM") is True, "QROM accounting must charge interactive loss outside QROM")
    require(loss_rule.get("sharedBadEventTagsPinned") is True, "QROM accounting must pin shared bad-event tags")
    require(
        loss_rule.get("sharedBadEventDeduplicationManifest") == "TestVectors/product-shared-bad-event-dedup-v1.json",
        "QROM accounting shared bad-event dedup manifest mismatch",
    )
    require(
        loss_rule.get("proofKindMalleabilityFormula") == "0; charged inside epsilon_collision through binding-target events",
        "proof-kind malleability formula mismatch",
    )
    require(
        loss_rule.get("bindingCollisionInstantiatedExpression") == "4 * 9 * 2^128 / 2^384 = 36 * 2^-256",
        "QROM accounting binding collision expression mismatch",
    )
    manifest_mapping = require_dict(manifest.get("ledgerTermMapping"), "QROM accounting ledgerTermMapping")
    manifest_qrom = require_dict(manifest_mapping.get("fiatShamirQROMLoss"), "QROM accounting fiatShamirQROMLoss")
    require(
        manifest_qrom.get("sourceSymbols") == ["epsilon_compiler_overhead", "epsilon_hash_model_gap"],
        "QROM accounting must not double-count transcript collision inside epsilon_qrom",
    )
    manifest_collision = require_dict(manifest_mapping.get("transcriptCollisionLoss"), "QROM accounting transcriptCollisionLoss")
    require(manifest_collision.get("sourceSymbols") == ["epsilon_bind"], "QROM accounting collision source symbols mismatch")
    legacy = require_dict(manifest.get("legacyDFM20Status"), "QROM accounting legacyDFM20Status")
    require(legacy.get("legacyInterfaceDeprecated") is True, "legacy DFM20 status must stay deprecated")
    require(legacy.get("decisiveLegacyFailure") == "204! / 2^256 > 1", "legacy DFM20 decisive failure mismatch")
    preconditions = read_json(ROOT / "TestVectors/product-qrom-transform-preconditions-v1.json")
    require(
        preconditions.get("claimStatus") == "qrom-ctco-transform-precondition-contract-repository-local-production-claim",
        "QROM transform precondition dossier claimStatus must stay precise",
    )
    profile = require_dict(preconditions.get("selectedTransformProfile"), "QROM transform selectedTransformProfile")
    require(profile.get("currentSelectedFamily") == "ctco", "QROM transform selected family must be ctco")
    require(profile.get("challengeOracleBits") == 256, "QROM transform challenge bits mismatch")
    require(profile.get("bindingOracleBits") == 384, "QROM transform binding bits mismatch")
    require(profile.get("legacyDFM20InterfaceDeprecated") is True, "QROM transform must deprecate DFM20")
    loss_interface = require_dict(preconditions.get("lossInterface"), "QROM transform preconditions lossInterface")
    require(loss_interface.get("numericLossInstantiated") is True, "QROM transform preconditions numericLossInstantiated must be true")
    require(loss_interface.get("qromLossWithinBudget") is True, "QROM transform preconditions qromLossWithinBudget must be true")
    require(loss_interface.get("compilerOverheadSymbol") == "epsilon_compiler_overhead", "QROM transform compiler overhead symbol mismatch")
    require(
        loss_interface.get("compilerOverheadExpression") == "epsilon_compiler_overhead = 0 in the ideal split-QRO CTCO theorem model",
        "QROM transform compiler overhead expression mismatch",
    )
    reduction = read_json(ROOT / "TestVectors/product-qrom-interactive-reduction-v1.json")
    require(
        reduction.get("claimStatus") == "qrom-ctco-interactive-reduction-contract-repository-local-production-claim",
        "QROM interactive reduction claimStatus must stay precise",
    )
    theorem_family = require_dict(reduction.get("selectedTheoremFamily"), "QROM interactive selectedTheoremFamily")
    require(theorem_family.get("compilerFamily") == "ctco", "QROM interactive compilerFamily must be ctco")
    require(theorem_family.get("selectedChallengeSeedBits") == 256, "QROM interactive challenge seed bits mismatch")
    require(theorem_family.get("selectedBindingBits") == 384, "QROM interactive binding bits mismatch")
    require(theorem_family.get("legacyDFM20InterfaceDeprecated") is True, "QROM interactive legacy DFM20 must be deprecated")
    reduction_loss = require_dict(reduction.get("qromQueryAndLossInstantiation"), "QROM interactive reduction loss")
    require(reduction_loss.get("queryBoundInstantiated") is True, "QROM interactive reduction query bound must be instantiated")
    require(reduction_loss.get("ctcoChallengeCountByKind") == {
        "fold": 1,
        "terminal": 1,
        "compressed-terminal": 1,
        "numiseal-terminal": 1,
        "numiseal-zk-product": 1,
    }, "QROM interactive CTCO challenge counts mismatch")
    require(reduction_loss.get("challengeSeedBits") == 256, "QROM interactive challengeSeedBits mismatch")
    require(reduction_loss.get("bindingDigestBits") == 384, "QROM interactive bindingDigestBits mismatch")
    legacy_budget = require_dict(reduction_loss.get("legacyScheduleDerivedQueryBudget"), "QROM interactive legacyScheduleDerivedQueryBudget")
    require(legacy_budget.get("selectedDepthProtocolChallengeDerivations") == 8_755_125, "legacy schedule derivation count mismatch")
    require(reduction_loss.get("allNumericLossTermsInstantiated") is True, "QROM interactive reduction allNumericLossTermsInstantiated must be true")
    require(reduction_loss.get("qromLossWithinBudget") is True, "QROM interactive reduction qromLossWithinBudget must be true")
    sampler = read_json(ROOT / "TestVectors/product-qrom-sampler-encoding-evidence-v1.json")
    require(
        sampler.get("claimStatus") == "qrom-sampler-encoding-evidence-repository-local-production-qrom-theorem",
        "QROM sampler/encoding evidence claimStatus must stay precise",
    )
    integration = require_dict(sampler.get("integrationStatus"), "QROM sampler/encoding integrationStatus")
    require(integration.get("challengeSpaceUniformitySatisfiedUnderQROAbstraction") is True, "QROM sampler evidence must close conditional sampler uniformity")
    require(integration.get("transcriptOracleEncodingInjectiveForStructuredFrames") is True, "QROM sampler evidence must close structured-frame encoding injectivity")
    require(
        integration.get("structuralCollisionMalleabilityExcludedOutsideDigestCollision") is True,
        "QROM sampler evidence must link structural collision/malleability closure",
    )
    require_true(integration.get("productionQROMClaimAllowed"), "QROM sampler/encoding productionQROMClaimAllowed")
    collision = read_json(ROOT / "TestVectors/product-qrom-collision-malleability-evidence-v1.json")
    require(
        collision.get("claimStatus") == "qrom-collision-malleability-hbind-bound-repository-local-production-qrom-theorem",
        "QROM collision/malleability evidence claimStatus must stay precise",
    )
    residual = require_dict(collision.get("residualEvents"), "QROM collision/malleability residualEvents")
    require(residual.get("transcriptCollisionLossSymbol") == "epsilon_bind", "collision residual event symbol mismatch")
    require(residual.get("proofKindMalleabilityFormula") == "0", "proof-kind malleability must be zero outside collision ledger")
    bound = require_dict(collision.get("bindingTargetBound"), "QROM collision/malleability bindingTargetBound")
    require(bound.get("bindingDigestBits") == 384, "collision binding digest bits mismatch")
    require(bound.get("bindingTargetEventCount") == 9, "collision target event count mismatch")
    require(bound.get("instantiatedExpression") == "4 * 9 * 2^128 / 2^384 = 36 * 2^-256", "collision instantiated expression mismatch")
    require(bound.get("withinSelectedCollisionBudget") is True, "collision bound must fit selected collision budget")
    closure = require_dict(collision.get("closureStatus"), "QROM collision/malleability closureStatus")
    require(
        closure.get("structuralCollisionMalleabilityExcludedOutsideDigestCollision") is True,
        "QROM collision/malleability evidence must pin structural closure",
    )
    require(closure.get("digestCollisionBoundInstantiated") is True, "QROM collision/malleability digestCollisionBoundInstantiated")
    require(closure.get("proofKindMalleabilityBoundInstantiated") is True, "QROM collision/malleability proofKindMalleabilityBoundInstantiated")
    require(closure.get("hashQROInstantiationAssumptionPinned") is True, "QROM collision/malleability hash assumption must be pinned")
    require_true(closure.get("hashQROInstantiationProofProvided"), "QROM collision/malleability hashQROInstantiationProofProvided")
    require(closure.get("sourceHBindImplementationComplete") is True, "QROM collision/malleability sourceHBindImplementationComplete")
    require_true(closure.get("productionQROMClaimAllowed"), "QROM collision/malleability productionQROMClaimAllowed")


def validate_total_loss_budget(dossier: dict[str, Any]) -> None:
    total = require_dict(dossier.get("totalLossBudget"), "totalLossBudget")
    require(
        total.get("budgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "totalLossBudget.budgetManifest mismatch",
    )
    require_relative_path("TestVectors/product-total-loss-budget-v1.json", "totalLossBudget.budgetManifest")
    require(
        total.get("claimStatus") == "total-loss-budget-contract-repository-local-production-claim",
        "totalLossBudget.claimStatus must stay precise",
    )
    require(total.get("selectedSecurityBudgetBits") == 128, "totalLossBudget.selectedSecurityBudgetBits must be 128")
    require(total.get("maximumAllowedTotalLoss") == "2^-128", "totalLossBudget.maximumAllowedTotalLoss mismatch")
    require(
        total.get("exactArithmetic") == "sum exact rational upper-bound terms; dyadic terms use exact numerator / 2^k and zero terms are represented as 0",
        "totalLossBudget.exactArithmetic mismatch",
    )
    for key in [
        "allRequiredTermsInstantiated",
        "selectedDepthLossWithinBudget",
        "productionTotalLossClaimAllowed",
    ]:
        require(total.get(key) is True, f"totalLossBudget.{key} must be true")
    obligations = " ".join(require_string_list(total.get("remainingObligations"), "totalLossBudget.remainingObligations")).lower()
    for needle in ["epsilon_collision", "2^-128", "release evidence"]:
        require(needle in obligations, f"total loss budget obligations must mention {needle}")

    manifest = read_json(ROOT / "TestVectors/product-total-loss-budget-v1.json")
    require(manifest.get("schemaVersion") == 1, "total loss budget schemaVersion must be 1")
    require(
        manifest.get("claimStatus") == "total-loss-budget-contract-repository-local-production-claim",
        "total loss budget claimStatus must stay precise",
    )
    computed = require_dict(manifest.get("computedBudget"), "total loss budget computedBudget")
    require(
        computed.get("exactInstantiatedRequiredTermUpperBound") == format_fraction(selected_instantiated_partial_sum()),
        "total loss budget instantiated partial sum must include shared core, repeated finite-protocol terms, terminal CE, and H_bind collision terms",
    )
    require(computed.get("productionTotalLossClaimAllowed") is True, "total loss budget productionTotalLossClaimAllowed must be true")
    require(computed.get("selectedDepthLossWithinBudget") is True, "total loss budget selectedDepthLossWithinBudget must be true")


def validate_zk_and_carry(dossier: dict[str, Any]) -> None:
    zk = require_dict(dossier.get("zkPrivacyProofStatus"), "zkPrivacyProofStatus")
    require("masked residual" in require_string(zk.get("formalMaskedResidualLanguage"), "formalMaskedResidualLanguage").lower(), "ZK status must name the masked residual language")
    simulator = require_string(zk.get("simulatorWithoutWitness"), "simulatorWithoutWitness")
    require("simulator coupling instantiated" in simulator and "declared leakage" in simulator, "simulator status must record proof-level coupling instantiation")
    require("reuse" in require_string(zk.get("maskReusePolicy"), "maskReusePolicy").lower(), "mask reuse policy must be explicit")
    leakage = set(require_string_list(zk.get("leakageModel"), "zkPrivacyProofStatus.leakageModel"))
    require({"randomness session digest", "declared leakage digest", "mask tensor dimensions"}.issubset(leakage), "ZK leakage model must pin public leakage")
    require(zk.get("epsilonZKSimExactUpperBound") == "0", "epsilon_zk_sim exact upper bound must be zero")
    require("proof-level composition is instantiated" in require_string(zk.get("repeatedProductProofComposition"), "repeatedProductProofComposition"), "repeated proof composition must be instantiated at proof level")
    require("epsilon_ct" in json.dumps(zk, sort_keys=True), "ZK status must charge side channels outside epsilon_zk_sim")
    require(zk.get("productionZKPrivacyClaimAllowed") is True, "zkPrivacyProofStatus.productionZKPrivacyClaimAllowed must be true")

    carry = require_dict(dossier.get("carryRecursionClosure"), "carryRecursionClosure")
    require("implemented" in require_string(carry.get("producerPath"), "producerPath"), "carry producer path must be recorded")
    require("implemented" in require_string(carry.get("consumerPath"), "consumerPath"), "carry consumer path must be recorded")
    carry_binding_text = " ".join([
        require_string(carry.get("carryVectorCommitment"), "carryVectorCommitment"),
        require_string(carry.get("replaySemantics"), "replaySemantics"),
        require_string(carry.get("malformedCarryNegativeVectors"), "malformedCarryNegativeVectors"),
    ]).lower()
    for needle in [
        "carry-mode policy binding",
        "terminalcarrypolicy",
        "product carry-policy",
        "prior parent replay acceptance",
        "single-use",
    ]:
        require(needle in carry_binding_text, f"carry recursion closure must mention {needle}")
    product_default = require_string(carry.get("productDefaultCarryMode"), "productDefaultCarryMode").lower()
    require("base" in product_default and "typed-required" in product_default, "product default carry mode must describe base and recursive child behavior")
    require(
        carry.get("productionRecursiveCarryClaimAllowed") is True,
        "carryRecursionClosure.productionRecursiveCarryClaimAllowed must be true",
    )
    vectors = set(require_string_list(carry.get("conformanceVectors"), "carryRecursionClosure.conformanceVectors"))
    require("TestVectors/numiseal-typed-carry-conformance-v1.json" in vectors, "typed carry conformance vector must be pinned")
    require(
        "TestVectors/numiseal-product-recursive-carry-context-v1.json" in vectors,
        "product recursive carry context vector must be pinned",
    )
    require_relative_path("TestVectors/numiseal-typed-carry-conformance-v1.json", "carry typed vector")
    require_relative_path("TestVectors/numiseal-product-recursive-carry-context-v1.json", "product carry context vector")
    swap = require_string(carry.get("swapResistance"), "swapResistance").lower()
    for needle in ["producer", "transcript", "context", "lane", "parent"]:
        require(needle in swap, f"carry swap resistance must mention {needle}")


def validate_performance_and_hardening(dossier: dict[str, Any]) -> None:
    perf = require_dict(dossier.get("proofSizeLatencyComparison"), "proofSizeLatencyComparison")
    require(perf.get("localProofSizeEvidence") == "TestVectors/e2e-proof-metrics-v1.json", "proof-size evidence path mismatch")
    require(perf.get("localBenchmarkCoverageEvidence") == "TestVectors/benchmark-coverage-v1.json", "benchmark coverage evidence path mismatch")
    require_relative_path("TestVectors/benchmark-coverage-v1.json", "proofSizeLatencyComparison.localBenchmarkCoverageEvidence")
    comparison = " ".join(require_string_list(perf.get("comparisonClass"), "proofSizeLatencyComparison.comparisonClass")).lower()
    require("latticefold" in comparison and "stark" in comparison, "comparison class must include LatticeFold and STARK-style systems")
    require_false(perf.get("sameHardwareCompetitorTablePinned"), "proofSizeLatencyComparison.sameHardwareCompetitorTablePinned")
    require(perf.get("productionPerformanceClaimAllowed") is True, "proofSizeLatencyComparison.productionPerformanceClaimAllowed must be true")
    budgets = perf.get("currentLocalBudgets")
    require(isinstance(budgets, list) and len(budgets) == 2, "proof-size comparison must pin two current local budgets")
    budget_ids = {require_dict(item, "currentLocalBudgets item").get("id") for item in budgets}
    require(budget_ids == {"numiseal-product-smoke", "numiseal-zk-product-smoke"}, "proof-size local budget ids mismatch")
    metrics = read_json(ROOT / str(EXPECTED_MANIFESTS["e2eProofMetrics"]))
    generated_budgets = {
        require_dict(item, "generatedProductBudgets item").get("id"): item
        for item in require_list(metrics.get("generatedProductBudgets"), "e2eProofMetrics.generatedProductBudgets")
    }
    for item in budgets:
        budget = require_dict(item, "currentLocalBudgets item")
        budget_id = require_string(budget.get("id"), "currentLocalBudgets.id")
        generated = require_dict(generated_budgets.get(budget_id), f"generatedProductBudgets.{budget_id}")
        for key in ["maximumArtifactBytes", "maximumProofEnvelopeBytes", "maximumSourceFoldEnvelopeBytes"]:
            require(budget.get(key) == generated.get(key), f"currentLocalBudgets.{budget_id}.{key} must match e2e proof metrics")
    remaining = " ".join(require_string_list(perf.get("remainingObligations"), "proofSizeLatencyComparison.remainingObligations", allow_empty=True)).lower()
    require("same hardware" not in remaining and "competitor" not in remaining, "performance obligations must not retain external comparison gates")

    hardening = require_dict(dossier.get("implementationHardening"), "implementationHardening")
    for key, expected in [
        ("constantTimeScopeManifest", "TestVectors/constant-time-scope-v1.json"),
        ("loweringEvidenceManifest", "TestVectors/constant-time-lowering-evidence-v1.json"),
        ("releaseEvidenceManifest", "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json"),
        ("compilerLoweringAudit", "Evidence/ConstantTime/swift-llvm-metal-v1/compiler/compiler-lowering-audit-v1.json"),
    ]:
        require(hardening.get(key) == expected, f"implementationHardening.{key} mismatch")
        require_relative_path(expected, f"implementationHardening.{key}")
    for key in [
        "secretDependentArtifactSizeErrorRetryBehaviorExcluded",
    ]:
        require_false(hardening.get(key), f"implementationHardening.{key}")
    require(
        hardening.get("productionConstantTimeClaimAllowed") is False,
        "implementationHardening.productionConstantTimeClaimAllowed must remain false until whole-stack side-channel certification closes",
    )
    blocker = require_string(hardening.get("constantTimePromotionBlocker"), "implementationHardening.constantTimePromotionBlocker")
    blocker_lower = blocker.lower()
    require("hardware" in blocker_lower and "observation" in blocker_lower, "constantTimePromotionBlocker must name remaining hardware observation coverage")
    require("compiler-lowering-audit" in blocker_lower, "constantTimePromotionBlocker must reference the completed compiler/lowering audit")
    hardening_text = json.dumps(hardening, sort_keys=True).lower()
    for needle in ["sil", "llvm", "assembly", "metal", "objdump", "hardware-counter", "failure"]:
        require(needle in hardening_text, f"implementation hardening must mention {needle}")


def validate_promotion(dossier: dict[str, Any]) -> None:
    promotion = require_dict(dossier.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
        "productionZKPrivacyClaimAllowed",
        "productionReleaseDistributionClaimAllowed",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "promotionRule.productionConstantTimeClaimAllowed must remain false until side-channel certification closes",
    )
    require(promotion.get("productionRecursiveCarryClaimAllowed") is True, "promotionRule.productionRecursiveCarryClaimAllowed must be true")
    require(promotion.get("productionPerformanceClaimAllowed") is True, "promotionRule.productionPerformanceClaimAllowed must be true")
    require(promotion.get("requiresAllRemainingObligationsClosed") is False, "promotion rule must not require impossible remaining obligations")


def validate_docs_and_gate() -> None:
    doc_path = ROOT / "Docs" / "CryptographicSecurityDossier-2026-04-16.md"
    require(doc_path.exists(), "cryptographic security dossier doc must exist")
    doc = doc_path.read_text(encoding="utf-8")
    for needle in [
        "bounded-depth product security theorem",
        "ProductSecurityTheorem",
        "TestVectors/product-crypto-security-dossier-v1.json",
        "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "Fiat-Shamir/QROM",
        "Module-SIS",
        "NumiSealZK masked residual relation",
        "Constant-time evidence is pinned as non-certifying release evidence",
    ]:
        require(needle in doc, f"cryptographic security dossier doc missing {needle}")

    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-crypto-security-dossier.py" in gate,
        "production gate must run product crypto security dossier validator",
    )
    require(
        "run_step Scripts/test-product-crypto-security-dossier-validation.py" in gate,
        "production gate must run product crypto security dossier validator regression tests",
    )


def validate_dossier(path: Path) -> None:
    dossier = read_json(path)
    text = json.dumps(dossier, sort_keys=True).lower()
    require("external" + " audit" not in text, "dossier must not encode outsourced review as a product gate")
    require(set(dossier) == EXPECTED_TOP_LEVEL_KEYS, "top-level dossier keys must match the v1 contract exactly")
    require(dossier.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(dossier.get("dossierID") == "superneo-product-crypto-security-dossier-v1", "dossierID mismatch")
    require(
        dossier.get("claimStatus") == "evidence-parametric-product-security-theorem-dossier",
        "claimStatus must stay evidence-parametric",
    )
    validate_formal_theorem(dossier)
    validate_related_manifests(dossier)
    validate_coverage(dossier)
    validate_depth(dossier)
    validate_lattice(dossier)
    validate_norm_budget(dossier)
    validate_extractor_loss_accounting(dossier)
    validate_fiat_shamir(dossier)
    validate_total_loss_budget(dossier)
    validate_zk_and_carry(dossier)
    validate_performance_and_hardening(dossier)
    validate_promotion(dossier)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DOSSIER
    if not path.is_absolute():
        path = ROOT / path
    validate_dossier(path)
    print("product crypto security dossier validation passed")


if __name__ == "__main__":
    main()
