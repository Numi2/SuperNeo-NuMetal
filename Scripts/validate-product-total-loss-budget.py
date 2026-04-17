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
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "numiSealZKMaskDistributionEvidence": "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
    "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
    "constantTimeReleaseEvidence": "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
    "benchmarkCoverage": "TestVectors/benchmark-coverage-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductTotalLossBudget",
    "ProductTotalLossBudgetAccepted",
    "productSecurityTheorem_requires_total_loss_budget",
}

EXPECTED_COMPONENT_IDS = [
    "source-fold-knowledge",
    "terminal-numiseal-seal",
    "typed-recursive-carry",
    "zk-simulator-composition",
    "fiat-shamir-qrom",
    "extractor-instantiation",
    "transcript-collision-domain-separation",
    "product-ops-replay",
    "constant-time-side-channel",
    "release-signing-notarization",
]

EXPECTED_REQUIRED_IDS = [
    "source-fold-knowledge",
    "terminal-numiseal-seal",
    "zk-simulator-composition",
    "fiat-shamir-qrom",
    "extractor-instantiation",
    "transcript-collision-domain-separation",
    "product-ops-replay",
    "constant-time-side-channel",
    "release-signing-notarization",
]

EXPECTED_FALSE_PROMOTION_FLAGS = [
    "productionProductSecurityClaimAllowed",
    "productionPostQuantumClaimAllowed",
    "productionQROMClaimAllowed",
    "productionZKPrivacyClaimAllowed",
    "productionConstantTimeClaimAllowed",
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
    require(collision_sources == ["epsilon_transcript_collision"], "epsilon_collision must map exactly from epsilon_transcript_collision")

    schedule = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTranscriptSchedule"])
    ledger_binding = require_dict(schedule.get("ledgerBinding"), "productQROMTranscriptSchedule.ledgerBinding")
    require(
        ledger_binding.get("totalLossBudgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "QROM transcript schedule must link total-loss budget",
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
    require_false(depth.get("productionBudgetPromotionAllowed"), "selectedDepth.productionBudgetPromotionAllowed")


def validate_budget_model(budget: dict[str, Any]) -> int:
    model = require_dict(budget.get("budgetModel"), "budgetModel")
    require(model.get("lossBoundFormat") == "negative-log2-upper-bound-bits", "budgetModel.lossBoundFormat mismatch")
    require(
        model.get("exactArithmetic") == "sum exact rational terms multiplicity * 2^-boundLog2",
        "budgetModel.exactArithmetic mismatch",
    )
    bits = require_int(model.get("selectedSecurityBudgetBits"), "budgetModel.selectedSecurityBudgetBits")
    require(bits == 128, "selectedSecurityBudgetBits must be 128 for the current contract")
    require(model.get("maximumAllowedTotalLoss") == "2^-128", "maximumAllowedTotalLoss mismatch")
    require(model.get("requiresEveryRequiredTermInstantiated") is True, "requiresEveryRequiredTermInstantiated must be true")
    require(model.get("zeroMultiplicityTermsExcludedFromSelectedSum") is True, "zeroMultiplicityTermsExcludedFromSelectedSum must be true")
    policy = require_string(model.get("doubleCountingPolicy"), "budgetModel.doubleCountingPolicy")
    require("epsilon_collision" in policy and "not included inside epsilon_qrom" in policy, "doubleCountingPolicy must pin collision mapping")
    return bits


def validate_component_bounds(budget: dict[str, Any]) -> tuple[int, int, list[str], Fraction | None]:
    components = budget.get("componentBounds")
    require(isinstance(components, list), "componentBounds must be a list")
    require(len(components) == len(EXPECTED_COMPONENT_IDS), "componentBounds length mismatch")
    seen_ids: list[str] = []
    required_ids: list[str] = []
    missing_ids: list[str] = []
    instantiated_required = 0
    total = Fraction(0, 1)

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
        if instantiated:
            require(type(bound_log2) is int and bound_log2 > 0, f"{component_id}.boundLog2 must be a positive integer when instantiated")
        else:
            require(bound_log2 is None, f"{component_id}.boundLog2 must be null until the term is instantiated")
        require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")

        if required:
            required_ids.append(component_id)
            if instantiated:
                instantiated_required += 1
                total += Fraction(multiplicity, 1 << int(bound_log2))
            else:
                missing_ids.append(component_id)
        else:
            require(multiplicity == 0, f"{component_id} must have zero multiplicity when not required at selected depth")

    require(seen_ids == EXPECTED_COMPONENT_IDS, "componentBounds must stay in the pinned budget order")
    require(required_ids == EXPECTED_REQUIRED_IDS, "required selected-depth budget terms mismatch")
    exact_total = total if not missing_ids else None
    return len(required_ids), instantiated_required, missing_ids, exact_total


def validate_computed_budget(
    budget: dict[str, Any],
    security_bits: int,
    required_count: int,
    instantiated_count: int,
    missing_ids: list[str],
    exact_total: Fraction | None,
) -> None:
    computed = require_dict(budget.get("computedBudget"), "computedBudget")
    require(computed.get("requiredTermCount") == required_count, "computedBudget.requiredTermCount mismatch")
    require(
        computed.get("instantiatedRequiredTermCount") == instantiated_count,
        "computedBudget.instantiatedRequiredTermCount mismatch",
    )
    require(computed.get("missingRequiredTermIDs") == missing_ids, "computedBudget.missingRequiredTermIDs mismatch")
    all_required = not missing_ids
    within_budget = exact_total is not None and exact_total <= Fraction(1, 1 << security_bits)
    expected_bound = format_fraction(exact_total) if exact_total is not None else None
    require(
        computed.get("exactSelectedDepthLossUpperBound") == expected_bound,
        "computedBudget.exactSelectedDepthLossUpperBound mismatch",
    )
    require(computed.get("allRequiredTermsInstantiated") is all_required, "computedBudget.allRequiredTermsInstantiated mismatch")
    require(computed.get("selectedDepthLossWithinBudget") is within_budget, "computedBudget.selectedDepthLossWithinBudget mismatch")
    require_false(computed.get("productionTotalLossClaimAllowed"), "computedBudget.productionTotalLossClaimAllowed")
    if not all_required:
        require_false(computed.get("selectedDepthLossWithinBudget"), "computedBudget.selectedDepthLossWithinBudget")


def validate_promotion_rule(budget: dict[str, Any]) -> None:
    promotion = require_dict(budget.get("promotionRule"), "promotionRule")
    for key in EXPECTED_FALSE_PROMOTION_FLAGS:
        require_false(promotion.get(key), f"promotionRule.{key}")
    for key in [
        "requiresAllRequiredTermsInstantiated",
        "requiresSelectedDepthLossWithinBudget",
        "requiresSelectedDepthLedgerUpdate",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-total-loss-budget-v1.json",
            "total-loss budget",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-total-loss-budget-v1.json",
            "Total Loss Budget",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "Scripts/validate-product-total-loss-budget.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "product total-loss budget",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product total-loss budget manifest",
        ],
        "TestVectors/README.md": [
            "product-total-loss-budget-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-total-loss-budget.py" in gate,
        "production gate must run total-loss budget validator",
    )
    require(
        "run_step Scripts/test-product-total-loss-budget-validation.py" in gate,
        "production gate must run total-loss budget regression tests",
    )


def validate_budget(path: Path) -> None:
    budget = read_json(path)
    text = json.dumps(budget, sort_keys=True).lower()
    require("external" + " audit" not in text, "budget must not encode outsourced review as a product gate")
    require(set(budget) == EXPECTED_TOP_LEVEL_KEYS, "top-level budget keys must match the v1 contract exactly")
    require(budget.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(budget.get("budgetID") == "superneo-product-total-loss-budget-v1", "budgetID mismatch")
    require(
        budget.get("claimStatus") == "total-loss-budget-contract-not-production-claim",
        "claimStatus must stay non-production",
    )
    validate_related_manifests(budget)
    validate_formal_surface(budget)
    validate_selected_depth(budget)
    security_bits = validate_budget_model(budget)
    required_count, instantiated_count, missing_ids, exact_total = validate_component_bounds(budget)
    validate_computed_budget(budget, security_bits, required_count, instantiated_count, missing_ids, exact_total)
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
