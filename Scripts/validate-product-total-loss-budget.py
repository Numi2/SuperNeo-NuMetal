#!/usr/bin/env python3
"""Validate product total-loss budget accounting evidence."""

from __future__ import annotations

import json
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
BUDGET = ROOT / "TestVectors" / "product-total-loss-budget-v1.json"
GOLDILOCKS_MODULUS = 18_446_744_069_414_584_321
PIRLC_CRT_COMPONENT_DEGREE = 27
PIRLC_REPEATED_BRANCH_COUNT = 3
TERMINAL_CE_ROUNDS = 226

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "budgetID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedDepth",
    "budgetModel",
    "componentBounds",
    "computedBudget",
    "exactFiniteProbabilityWiring",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
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
    "numiSealZKMaskDistributionEvidence": "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
    "numiSealZKSimulatorCouplingEvidence": "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
    "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
    "constantTimeReleaseEvidence": "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
    "benchmarkCoverage": "TestVectors/benchmark-coverage-v1.json",
    "productReleaseDistributionEvidence": "TestVectors/product-release-distribution-evidence-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductTotalLossBudget",
    "ProductTotalLossBudgetAccepted",
    "ProductSharedBadEventDeduplication",
    "ProductSharedBadEventDeduplicationAccepted",
    "ProductExactFiniteProbabilityWiring",
    "ProductExactFiniteProbabilityWiringAccepted",
    "productSecurityTheorem_requires_total_loss_budget",
    "productSecurityTheorem_requires_shared_bad_event_deduplication",
    "productSecurityTheorem_requires_exact_finite_probability_wiring",
}

EXPECTED_COMPONENT_IDS = [
    "shared-cryptographic-core",
    "source-fold-knowledge",
    "terminal-numiseal-seal",
    "typed-recursive-carry",
    "zk-simulator-composition",
    "fiat-shamir-qrom",
    "extractor-instantiation",
    "transcript-collision-domain-separation",
    "product-ops-replay",
    "constant-time-side-channel",
    "release-distribution",
]

EXPECTED_REQUIRED_IDS = [
    "shared-cryptographic-core",
    "source-fold-knowledge",
    "terminal-numiseal-seal",
    "zk-simulator-composition",
    "fiat-shamir-qrom",
    "extractor-instantiation",
    "transcript-collision-domain-separation",
]

EXPECTED_TRUE_PROMOTION_FLAGS = [
    "productionProductSecurityClaimAllowed",
    "productionPostQuantumClaimAllowed",
    "productionQROMClaimAllowed",
    "productionZKPrivacyClaimAllowed",
]


def fail(message: str) -> None:
    print(f"product total-loss budget validation failed: {message}", file=sys.stderr)
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


def require_int(value: Any, label: str) -> int:
    require(type(value) is int, f"{label} must be an integer")
    return value


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false until total-loss evidence is instantiated")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def format_fraction(value: Fraction) -> str:
    if value.denominator == 1:
        return str(value.numerator)
    return f"{value.numerator}/{value.denominator}"


def format_dyadic_fraction(value: Fraction) -> str:
    if value == 0:
        return "0"
    denominator = value.denominator
    if denominator > 0 and denominator & (denominator - 1) == 0:
        return f"{value.numerator}/2^{denominator.bit_length() - 1}"
    return format_fraction(value)


def source_fold_repeated_tape_bound() -> Fraction:
    return Fraction(16, GOLDILOCKS_MODULUS**4) + Fraction(
        1,
        5 ** (PIRLC_CRT_COMPONENT_DEGREE * PIRLC_REPEATED_BRANCH_COUNT),
    )


def terminal_ce_226_bound() -> Fraction:
    return Fraction(2**TERMINAL_CE_ROUNDS, 3**TERMINAL_CE_ROUNDS)


def parse_exact_bound(value: Any, label: str) -> Fraction | None:
    if value is None:
        return None
    text = require_string(value, label)
    if text == "0":
        return Fraction(0, 1)
    if "/2^" in text:
        numerator_text, exponent_text = text.split("/2^", 1)
        try:
            numerator = int(numerator_text)
            exponent = int(exponent_text)
        except ValueError:
            fail(f"{label} must use numerator/2^exponent form")
        require(numerator >= 0 and exponent >= 0, f"{label} must be non-negative")
        return Fraction(numerator, 1 << exponent)
    if "/" in text:
        numerator_text, denominator_text = text.split("/", 1)
        try:
            numerator = int(numerator_text)
            denominator = int(denominator_text)
        except ValueError:
            fail(f"{label} must use numerator/denominator form")
        require(numerator >= 0 and denominator > 0, f"{label} must be a non-negative rational")
        return Fraction(numerator, denominator)
    try:
        integer = int(text)
    except ValueError:
        fail(f"{label} must be an exact rational string")
    require(integer >= 0, f"{label} must be non-negative")
    return Fraction(integer, 1)


def validate_related_manifests(budget: dict[str, Any]) -> None:
    related = require_dict(budget.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the total-loss evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "product crypto security dossier must link total loss budget",
    )
    require(
        dossier_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "product crypto security dossier must link ZK simulator-coupling evidence",
    )
    total = require_dict(dossier.get("totalLossBudget"), "productCryptoSecurityDossier.totalLossBudget")
    require(
        total.get("budgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "dossier totalLossBudget must point at the total-loss budget manifest",
    )

    ledger = read_json(ROOT / EXPECTED_MANIFESTS["selectedDepthLossAccounting"])
    ledger_related = require_dict(ledger.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        ledger_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "selected-depth ledger must link total loss budget",
    )
    require(
        ledger_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "selected-depth ledger must link QROM transcript schedule",
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
        ledger_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "selected-depth ledger must link sampler/encoding evidence",
    )
    require(
        ledger_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "selected-depth ledger must link collision/malleability evidence",
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
        ledger_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "selected-depth ledger must link release distribution evidence",
    )
    require(
        ledger_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "selected-depth ledger must link ZK simulator-coupling evidence",
    )
    component_ids = [
        require_string(row.get("id"), f"selectedDepthLossAccounting.componentLosses[{index}].id")
        for index, row in enumerate(ledger.get("componentLosses", []))
        if isinstance(row, dict)
    ]
    for required_id in EXPECTED_COMPONENT_IDS:
        require(required_id in component_ids, f"selected-depth ledger missing budget component {required_id}")

    qrom = read_json(ROOT / EXPECTED_MANIFESTS["productQROMFiatShamirAccounting"])
    mapping = require_dict(qrom.get("ledgerTermMapping"), "productQROMFiatShamirAccounting.ledgerTermMapping")
    qrom_loss = require_dict(mapping.get("fiatShamirQROMLoss"), "ledgerTermMapping.fiatShamirQROMLoss")
    collision_loss = require_dict(mapping.get("transcriptCollisionLoss"), "ledgerTermMapping.transcriptCollisionLoss")
    qrom_sources = require_string_list(qrom_loss.get("sourceSymbols"), "fiatShamirQROMLoss.sourceSymbols")
    collision_sources = require_string_list(collision_loss.get("sourceSymbols"), "transcriptCollisionLoss.sourceSymbols")
    require("epsilon_transcript_collision" not in qrom_sources, "epsilon_transcript_collision must not be double-counted inside epsilon_qrom")
    require(collision_sources == ["epsilon_bind"], "epsilon_collision must map exactly from epsilon_bind")

    schedule = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTranscriptSchedule"])
    ledger_binding = require_dict(schedule.get("ledgerBinding"), "productQROMTranscriptSchedule.ledgerBinding")
    require(
        ledger_binding.get("totalLossBudgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "QROM transcript schedule must link total-loss budget",
    )
    require(
        ledger_binding.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM transcript schedule must link interactive reduction",
    )
    require(
        require_dict(schedule.get("relatedManifests"), "productQROMTranscriptSchedule.relatedManifests").get("productQROMSamplerEncodingEvidence")
        == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM transcript schedule must link sampler/encoding evidence",
    )
    require(
        require_dict(schedule.get("relatedManifests"), "productQROMTranscriptSchedule.relatedManifests").get("productQROMCollisionMalleabilityEvidence")
        == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM transcript schedule must link collision/malleability evidence",
    )

    release_distribution = read_json(ROOT / EXPECTED_MANIFESTS["productReleaseDistributionEvidence"])
    release_related = require_dict(release_distribution.get("relatedManifests"), "productReleaseDistributionEvidence.relatedManifests")
    require(
        release_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "release distribution evidence must link total-loss budget",
    )
    release_policy = require_dict(release_distribution.get("releaseClassPolicy"), "productReleaseDistributionEvidence.releaseClassPolicy")
    require(
        release_policy.get("totalLossBudgetComponent") == "repository-local-release-evidence",
        "release distribution evidence must bind total-loss release component",
    )

    preconditions = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTransformPreconditions"])
    loss_interface = require_dict(preconditions.get("lossInterface"), "productQROMTransformPreconditions.lossInterface")
    require(
        loss_interface.get("totalLossBudgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "QROM transform preconditions must link total-loss budget",
    )
    require(
        loss_interface.get("numericLossInstantiated") is True,
        "QROM transform preconditions numericLossInstantiated must be true",
    )
    require(
        require_dict(preconditions.get("relatedManifests"), "productQROMTransformPreconditions.relatedManifests").get("productQROMSamplerEncodingEvidence")
        == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM transform preconditions must link sampler/encoding evidence",
    )
    require(
        require_dict(preconditions.get("relatedManifests"), "productQROMTransformPreconditions.relatedManifests").get("productQROMCollisionMalleabilityEvidence")
        == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM transform preconditions must link collision/malleability evidence",
    )

    shared_dedup = read_json(ROOT / EXPECTED_MANIFESTS["productSharedBadEventDedup"])
    shared_related = require_dict(shared_dedup.get("relatedManifests"), "productSharedBadEventDedup.relatedManifests")
    require(
        shared_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "shared bad-event dedup evidence must link total-loss budget",
    )
    finite_loss = read_json(ROOT / EXPECTED_MANIFESTS["productFiniteProtocolLossObstruction"])
    finite_related = require_dict(finite_loss.get("relatedManifests"), "productFiniteProtocolLossObstruction.relatedManifests")
    require(
        finite_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "finite-protocol loss obstruction evidence must link total-loss budget",
    )

    reduction = read_json(ROOT / EXPECTED_MANIFESTS["productQROMInteractiveReduction"])
    integration = require_dict(reduction.get("ledgerIntegration"), "productQROMInteractiveReduction.ledgerIntegration")
    require(
        integration.get("totalLossBudgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "QROM interactive reduction must link total-loss budget",
    )
    require(
        integration.get("qromLossWithinBudget") is True,
        "QROM interactive reduction qromLossWithinBudget must be true",
    )
    require(
        require_dict(reduction.get("relatedManifests"), "productQROMInteractiveReduction.relatedManifests").get("productQROMSamplerEncodingEvidence")
        == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM interactive reduction must link sampler/encoding evidence",
    )
    require(
        require_dict(reduction.get("relatedManifests"), "productQROMInteractiveReduction.relatedManifests").get("productQROMCollisionMalleabilityEvidence")
        == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM interactive reduction must link collision/malleability evidence",
    )


def validate_formal_surface(budget: dict[str, Any]) -> None:
    formal = require_dict(budget.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_selected_depth(budget: dict[str, Any]) -> None:
    depth = require_dict(budget.get("selectedDepth"), "selectedDepth")
    require(depth.get("depthModel") == "bounded-depth", "selectedDepth.depthModel must be bounded-depth")
    require(depth.get("selectedMaximumDepth") == 1, "selectedDepth.selectedMaximumDepth must be 1")
    require(depth.get("acceptedProductLayers") == 1, "selectedDepth.acceptedProductLayers must be 1")
    require(depth.get("selectedRecursiveCarryHops") == 0, "selectedDepth.selectedRecursiveCarryHops must be 0")
    require(depth.get("productionBudgetPromotionAllowed") is True, "selectedDepth.productionBudgetPromotionAllowed must be true")


def validate_budget_model(budget: dict[str, Any]) -> int:
    model = require_dict(budget.get("budgetModel"), "budgetModel")
    require(model.get("lossBoundFormat") == "negative-log2-upper-bound-bits", "budgetModel.lossBoundFormat mismatch")
    require(
        "exact rational upper-bound terms" in require_string(model.get("exactArithmetic"), "budgetModel.exactArithmetic"),
        "budgetModel.exactArithmetic mismatch",
    )
    bits = require_int(model.get("selectedSecurityBudgetBits"), "budgetModel.selectedSecurityBudgetBits")
    require(bits == 128, "selectedSecurityBudgetBits must be 128 for the current contract")
    require(model.get("maximumAllowedTotalLoss") == "2^-128", "maximumAllowedTotalLoss mismatch")
    require(model.get("requiresEveryRequiredTermInstantiated") is True, "requiresEveryRequiredTermInstantiated must be true")
    require(model.get("zeroMultiplicityTermsExcludedFromSelectedSum") is True, "zeroMultiplicityTermsExcludedFromSelectedSum must be true")
    policy = require_string(model.get("doubleCountingPolicy"), "budgetModel.doubleCountingPolicy")
    require(
        "epsilon_core_shared" in policy
        and "epsilon_bind" in policy
        and "not included inside epsilon_qrom" in policy
        and "epsilon_core_shared" in policy,
        "doubleCountingPolicy must pin shared core and collision mapping",
    )
    return bits


def validate_component_bounds(budget: dict[str, Any]) -> tuple[int, int, list[str], Fraction | None, Fraction]:
    components = budget.get("componentBounds")
    require(isinstance(components, list), "componentBounds must be a list")
    require(len(components) == len(EXPECTED_COMPONENT_IDS), "componentBounds length mismatch")
    seen_ids: list[str] = []
    required_ids: list[str] = []
    missing_ids: list[str] = []
    instantiated_required = 0
    instantiated_total = Fraction(0, 1)

    for index, item in enumerate(components):
        component = require_dict(item, f"componentBounds[{index}]")
        component_id = require_string(component.get("id"), f"componentBounds[{index}].id")
        seen_ids.append(component_id)
        require_string(component.get("ledgerSymbol"), f"{component_id}.ledgerSymbol")
        require_relative_path(component.get("sourceManifest"), f"{component_id}.sourceManifest")
        multiplicity = require_int(component.get("currentMultiplicityAtSelectedDepth"), f"{component_id}.currentMultiplicityAtSelectedDepth")
        require(multiplicity >= 0, f"{component_id}.currentMultiplicityAtSelectedDepth must be non-negative")
        required = component.get("requiredForSelectedDepth")
        require(isinstance(required, bool), f"{component_id}.requiredForSelectedDepth must be boolean")
        instantiated = component.get("lossInstantiated")
        require(isinstance(instantiated, bool), f"{component_id}.lossInstantiated must be boolean")
        bound_log2 = component.get("boundLog2")
        exact_bound = parse_exact_bound(component.get("exactUpperBound"), f"{component_id}.exactUpperBound")
        if instantiated:
            require(type(bound_log2) is int and bound_log2 > 0, f"{component_id}.boundLog2 must be a positive integer when instantiated")
            require(exact_bound is not None, f"{component_id}.exactUpperBound must be present when instantiated")
            require(
                component.get("exactUpperBound") == format_dyadic_fraction(exact_bound),
                f"{component_id}.exactUpperBound must use canonical exact dyadic form",
            )
        else:
            require(bound_log2 is None, f"{component_id}.boundLog2 must be null until the term is instantiated")
            require(exact_bound is None, f"{component_id}.exactUpperBound must be null until the term is instantiated")
        require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
        if component_id == "shared-cryptographic-core":
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            require(
                component.get("sourceManifest") == "TestVectors/product-shared-bad-event-dedup-v1.json",
                "shared-cryptographic-core sourceManifest must be shared bad-event dedup evidence",
            )
            for needle in ["product-shared-bad-event-dedup-v1.json", "2^-129", "Module-SIS"]:
                require(needle in evidence, f"shared-cryptographic-core requiredEvidence must mention {needle}")
            if instantiated:
                require(
                    exact_bound == Fraction(1, 1 << 129),
                    "shared-cryptographic-core exactUpperBound must be 1/2^129",
                )
        if component_id == "fiat-shamir-qrom":
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            require(
                "TestVectors/product-qrom-transform-preconditions-v1.json" in evidence,
                "fiat-shamir-qrom requiredEvidence must link QROM transform preconditions",
            )
            require(
                "TestVectors/product-qrom-interactive-reduction-v1.json" in evidence,
                "fiat-shamir-qrom requiredEvidence must link QROM interactive reduction",
            )
            for needle in ["CTCO", "384-bit H_bind", "epsilon_compiler_overhead = 0"]:
                require(needle in evidence, f"fiat-shamir-qrom requiredEvidence must mention {needle}")
            if instantiated:
                require(exact_bound == 0, "fiat-shamir-qrom exactUpperBound must be exactly 0")
        if component_id in {"source-fold-knowledge", "terminal-numiseal-seal"}:
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            require(
                component.get("sourceManifest") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
                f"{component_id} sourceManifest must be finite-protocol loss obstruction evidence",
            )
            for needle in ["product-finite-protocol-loss-obstruction-v1.json", "finite-protocol", "2^-128"]:
                require(needle in evidence, f"{component_id} requiredEvidence must mention {needle}")
            if component_id == "source-fold-knowledge":
                require(
                    "one-shot 5^54 < 2^128" in evidence
                    and "1/5^27" in evidence
                    and "16/q^4 + 1/5^81" in evidence
                    and "fixed-kind CTCO repeated-tape" in evidence,
                    "source fold evidence must pin PiRLC numeric gap and repeated-tape route",
                )
                if instantiated:
                    require(exact_bound == source_fold_repeated_tape_bound(), "source-fold-knowledge exactUpperBound mismatch")
            if component_id == "terminal-numiseal-seal":
                require(
                    "terminal CE is pinned at 226 repeated challenge rounds" in evidence
                    and "fixed-kind repeated-tape" in evidence,
                    "terminal evidence must pin terminal CE repeated challenge closure",
                )
                require("(2/3)^226" in evidence, "terminal evidence must pin exact CE expression")
                if instantiated:
                    require(exact_bound == terminal_ce_226_bound(), "terminal-numiseal-seal exactUpperBound mismatch")
        if component_id == "zk-simulator-composition":
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            require(
                component.get("sourceManifest") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
                "zk-simulator-composition sourceManifest must be simulator-coupling evidence",
            )
            for needle in [
                "numiseal-zk-simulator-coupling-evidence-v1.json",
                "epsilon_zk_sim = 0",
                "declared leakage",
                "mask-reuse rejection",
                "epsilon_ct",
            ]:
                require(needle in evidence, f"zk-simulator-composition requiredEvidence must mention {needle}")
            if instantiated:
                require(exact_bound == 0, "zk-simulator-composition exactUpperBound must be exactly 0")
        if component_id == "extractor-instantiation":
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            for needle in [
                "product-extractor-loss-accounting-v1.json",
                "NumiSealProductConcreteExtractor.extract",
                "swiftConcreteExtractorEvidenceDigest",
                "epsilon_extract(depth=1) = 0",
            ]:
                require(needle in evidence, f"extractor-instantiation requiredEvidence must mention {needle}")
            if instantiated:
                require(exact_bound == 0, "extractor-instantiation exactUpperBound must be exactly 0")
        if component_id == "transcript-collision-domain-separation":
            evidence = require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
            require(
                "TestVectors/product-qrom-collision-malleability-evidence-v1.json" in evidence,
                "transcript-collision-domain-separation requiredEvidence must link collision/malleability evidence",
            )
            require(
                "epsilon_bind = 36 * 2^-256 = 9/2^254" in evidence,
                "transcript-collision-domain-separation requiredEvidence must pin exact epsilon_bind bound",
            )
            if instantiated:
                require(
                    exact_bound == Fraction(9, 1 << 254),
                    "transcript-collision-domain-separation exactUpperBound must be 9/2^254",
                )
        if component_id in {"product-ops-replay", "constant-time-side-channel", "release-distribution"}:
            require(required is False, f"{component_id} must not be a selected-depth required loss term")
            require(multiplicity == 0, f"{component_id} must have zero selected-depth multiplicity")
            require(instantiated is False, f"{component_id} must stay outside instantiated selected-depth losses")

        if required:
            required_ids.append(component_id)
            if instantiated:
                instantiated_required += 1
                instantiated_total += multiplicity * exact_bound
            else:
                missing_ids.append(component_id)
        else:
            require(multiplicity == 0, f"{component_id} must have zero multiplicity when not required at selected depth")

    require(seen_ids == EXPECTED_COMPONENT_IDS, "componentBounds must stay in the pinned budget order")
    require(required_ids == EXPECTED_REQUIRED_IDS, "required selected-depth budget terms mismatch")
    exact_total = instantiated_total if not missing_ids else None
    return len(required_ids), instantiated_required, missing_ids, exact_total, instantiated_total


def validate_computed_budget(
    budget: dict[str, Any],
    security_bits: int,
    required_count: int,
    instantiated_count: int,
    missing_ids: list[str],
    exact_total: Fraction | None,
    instantiated_total: Fraction,
) -> None:
    computed = require_dict(budget.get("computedBudget"), "computedBudget")
    require(computed.get("requiredTermCount") == required_count, "computedBudget.requiredTermCount mismatch")
    require(
        computed.get("instantiatedRequiredTermCount") == instantiated_count,
        "computedBudget.instantiatedRequiredTermCount mismatch",
    )
    require(computed.get("missingRequiredTermIDs") == missing_ids, "computedBudget.missingRequiredTermIDs mismatch")
    require(
        computed.get("exactInstantiatedRequiredTermUpperBound") == format_dyadic_fraction(instantiated_total),
        "computedBudget.exactInstantiatedRequiredTermUpperBound mismatch",
    )
    all_required = not missing_ids
    within_budget = exact_total is not None and exact_total <= Fraction(1, 1 << security_bits)
    expected_bound = format_fraction(exact_total) if exact_total is not None else None
    require(
        computed.get("exactSelectedDepthLossUpperBound") == expected_bound,
        "computedBudget.exactSelectedDepthLossUpperBound mismatch",
    )
    require(computed.get("allRequiredTermsInstantiated") is all_required, "computedBudget.allRequiredTermsInstantiated mismatch")
    require(computed.get("selectedDepthLossWithinBudget") is within_budget, "computedBudget.selectedDepthLossWithinBudget mismatch")
    require(computed.get("productionTotalLossClaimAllowed") is True, "computedBudget.productionTotalLossClaimAllowed must be true")


def validate_exact_finite_probability_wiring(budget: dict[str, Any], instantiated_total: Fraction) -> None:
    wiring = require_dict(budget.get("exactFiniteProbabilityWiring"), "exactFiniteProbabilityWiring")
    require(wiring.get("selectedDepth") == 1, "exactFiniteProbabilityWiring.selectedDepth must be 1")
    for key in [
        "dyadicRationalArithmeticPinned",
        "nonDyadicFiniteProtocolRationalsPinned",
        "zeroLossTermsRepresentedExactly",
        "instantiatedTermPartialSumComputed",
        "qromTermSeparatedFromCollisionLedger",
        "selectedDepthBudgetComparisonUsesExactRationals",
    ]:
        require(wiring.get(key) is True, f"exactFiniteProbabilityWiring.{key} must be true")
    require(wiring.get("missingRequiredTermsKeepTotalUninstantiated") is False, "missingRequiredTermsKeepTotalUninstantiated must be false")
    require(
        wiring.get("hbindCollisionExpressionExact") == "epsilon_bind = 36 * 2^-256 = 9/2^254",
        "exactFiniteProbabilityWiring.hbindCollisionExpressionExact mismatch",
    )
    require(
        instantiated_total
        == Fraction(1, 1 << 129)
        + source_fold_repeated_tape_bound()
        + terminal_ce_226_bound()
        + Fraction(9, 1 << 254),
        "exactFiniteProbabilityWiring instantiated partial sum must include shared core, repeated finite-protocol, terminal CE, and H_bind collision terms",
    )
    require(
        wiring.get("sourceFoldRepeatedTapeExpressionExact") == "epsilon_fold <= 16/q^4 + 1/5^81",
        "exactFiniteProbabilityWiring.sourceFoldRepeatedTapeExpressionExact mismatch",
    )
    require(
        wiring.get("terminalCE226ExpressionExact") == "epsilon_terminal_ce <= (2/3)^226",
        "exactFiniteProbabilityWiring.terminalCE226ExpressionExact mismatch",
    )
    require(
        wiring.get("extractorExpressionExact") == "epsilon_extract(depth=1) = 0",
        "exactFiniteProbabilityWiring.extractorExpressionExact mismatch",
    )
    require(
        wiring.get("sharedCoreExpressionExact") == "epsilon_core_shared = 2^-129 = 1/2^129 and is charged once as a tagged union",
        "exactFiniteProbabilityWiring.sharedCoreExpressionExact mismatch",
    )
    require(wiring.get("productionTotalLossClaimAllowed") is True, "exactFiniteProbabilityWiring.productionTotalLossClaimAllowed must be true")


def validate_promotion_rule(budget: dict[str, Any]) -> None:
    promotion = require_dict(budget.get("promotionRule"), "promotionRule")
    for key in EXPECTED_TRUE_PROMOTION_FLAGS:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "promotionRule.productionConstantTimeClaimAllowed must remain false until side-channel certification closes",
    )
    for key in [
        "requiresAllRequiredTermsInstantiated",
        "requiresSelectedDepthLossWithinBudget",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")
    require(promotion.get("requiresSelectedDepthLedgerUpdate") is False, "promotionRule.requiresSelectedDepthLedgerUpdate must be false")


def validate_docs_and_gate() -> None:
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-total-loss-budget.py" in gate,
        "production gate must run total-loss budget validator",
    )
    require(
        "run_step Scripts/test-product-total-loss-budget-validation.py" in gate,
        "production gate must run total-loss budget regression tests",
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
    require(
        "run_step Scripts/test-product-shared-bad-event-dedup-validation.py" in gate,
        "production gate must run shared bad-event dedup regression tests",
    )


def validate_budget(path: Path) -> None:
    budget = read_json(path)
    text = json.dumps(budget, sort_keys=True).lower()
    require("external" + " audit" not in text, "budget must not encode outsourced review as a product gate")
    require(set(budget) == EXPECTED_TOP_LEVEL_KEYS, "top-level budget keys must match the v1 contract exactly")
    require(budget.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(budget.get("budgetID") == "superneo-product-total-loss-budget-v1", "budgetID mismatch")
    require(
        budget.get("claimStatus") == "total-loss-budget-contract-repository-local-production-claim",
        "claimStatus must record repository-local production",
    )
    validate_related_manifests(budget)
    validate_formal_surface(budget)
    validate_selected_depth(budget)
    security_bits = validate_budget_model(budget)
    required_count, instantiated_count, missing_ids, exact_total, instantiated_total = validate_component_bounds(budget)
    validate_computed_budget(
        budget,
        security_bits,
        required_count,
        instantiated_count,
        missing_ids,
        exact_total,
        instantiated_total,
    )
    validate_exact_finite_probability_wiring(budget, instantiated_total)
    validate_promotion_rule(budget)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else BUDGET
    if not path.is_absolute():
        path = ROOT / path
    validate_budget(path)
    print("product total-loss budget validation passed")


if __name__ == "__main__":
    main()
