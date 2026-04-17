#!/usr/bin/env python3
"""Validate selected-depth product loss accounting evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "TestVectors" / "product-selected-depth-loss-accounting-v1.json"

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
    "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
    "constantTimeReleaseEvidence": "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
    "benchmarkCoverage": "TestVectors/benchmark-coverage-v1.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductSelectedDepthLossLedger",
    "ProductSelectedDepthLossLedgerAccepted",
    "ProductExtractorLossAccounting",
    "ProductExtractorLossAccountingAccepted",
    "ProductFiatShamirTranscriptSchedule",
    "ProductFiatShamirTranscriptScheduleAccepted",
    "ProductFiatShamirLossAccounting",
    "ProductFiatShamirLossAccountingAccepted",
    "ProductTotalLossBudget",
    "ProductTotalLossBudgetAccepted",
    "productSecurityTheorem_requires_selected_depth_loss_accounting",
    "productSecurityTheorem_requires_extractor_loss_accounting",
    "productSecurityTheorem_requires_qrom_transcript_schedule",
    "productSecurityTheorem_requires_qrom_loss_accounting",
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

EXPECTED_BLOCKERS = [
    "selected-depth extractor instantiation",
    "QROM transcript schedule and Fiat-Shamir loss accounting",
    "transcript collision and proof-kind malleability exclusion",
    "selected total-loss budget instantiation",
    "full ZK simulator composition",
    "hosted product operations replay and revocation freshness",
    "release signing and notarization",
    "complete CPU/Swift/LLVM/Metal constant-time evidence closure",
]

EXPECTED_PROMOTION_FALSE_FLAGS = [
    "productionProductSecurityClaimAllowed",
    "productionPostQuantumClaimAllowed",
    "productionQROMClaimAllowed",
    "productionZKPrivacyClaimAllowed",
    "productionRecursiveCarryClaimAllowed",
    "productionConstantTimeClaimAllowed",
    "productionReleaseDistributionClaimAllowed",
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
    require(depth.get("theoremMaximumDepth") == 1, "product crypto security dossier maximum theorem depth must stay 1")
    require(
        dossier_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "product crypto security dossier must link extractor loss accounting",
    )
    require(
        dossier_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "product crypto security dossier must link QROM Fiat-Shamir accounting",
    )
    require(
        dossier_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "product crypto security dossier must link QROM transcript schedule",
    )
    require(
        dossier_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "product crypto security dossier must link the total loss budget",
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


def validate_formal_surface(ledger: dict[str, Any]) -> None:
    formal = require_dict(ledger.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_selected_depth(ledger: dict[str, Any]) -> None:
    depth = require_dict(ledger.get("selectedDepth"), "selectedDepth")
    require(depth.get("depthModel") == "bounded-depth", "selectedDepth.depthModel must be bounded-depth")
    require(depth.get("selectedMaximumDepth") == 1, "selectedDepth.selectedMaximumDepth must be 1")
    require(depth.get("selectedRecursiveCarryHops") == 0, "selectedDepth.selectedRecursiveCarryHops must be 0")
    require(depth.get("currentProductDefaultMaximumDepth") == 1, "selectedDepth.currentProductDefaultMaximumDepth must be 1")
    require_false(depth.get("polyDepthClaimAllowed"), "selectedDepth.polyDepthClaimAllowed")
    require_false(depth.get("productionSelectedDepthClaimAllowed"), "selectedDepth.productionSelectedDepthClaimAllowed")


def validate_loss_notation(ledger: dict[str, Any]) -> None:
    notation = require_dict(ledger.get("lossNotation"), "lossNotation")
    required_symbols = {
        "securityParameter",
        "adversarySuccess",
        "sourceFoldLoss",
        "terminalSealLoss",
        "recursiveCarryLoss",
        "zkSimulatorLoss",
        "fiatShamirQROMLoss",
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
        require_false(component.get("productionClaimAllowed"), f"{component_id}.productionClaimAllowed")
        if component_id == "extractor-instantiation":
            require(
                component.get("accountingManifest") == "TestVectors/product-extractor-loss-accounting-v1.json",
                "extractor-instantiation must link product extractor loss accounting",
            )
            require_relative_path(component.get("accountingManifest"), "extractor-instantiation.accountingManifest")
        if component_id == "fiat-shamir-qrom":
            require(
                component.get("accountingManifest") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
                "fiat-shamir-qrom must link product QROM Fiat-Shamir accounting",
            )
            require_relative_path(component.get("accountingManifest"), "fiat-shamir-qrom.accountingManifest")
        if component_id == "transcript-collision-domain-separation":
            require(
                component.get("accountingManifest") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
                "transcript-collision-domain-separation must link product QROM Fiat-Shamir accounting",
            )
            require_relative_path(component.get("accountingManifest"), "transcript-collision-domain-separation.accountingManifest")
        component_text.append(json.dumps(component, sort_keys=True).lower())
    require(seen_ids == EXPECTED_COMPONENT_IDS, "componentLosses must stay in the pinned accounting order")
    joined = " ".join(component_text)
    for needle in ["extractor", "qrom", "collision", "simulator", "hosted", "notarization", "swift", "llvm", "metal"]:
        require(needle in joined, f"component losses must mention {needle}")


def validate_total_loss_rule(ledger: dict[str, Any]) -> None:
    total = require_dict(ledger.get("totalLossRule"), "totalLossRule")
    selected = require_string(total.get("selectedDepthExpression"), "totalLossRule.selectedDepthExpression")
    recursive = require_string(total.get("recursivePromotionExpression"), "totalLossRule.recursivePromotionExpression")
    for symbol in [
        "epsilon_fold",
        "epsilon_terminal",
        "epsilon_zk_sim",
        "epsilon_qrom",
        "epsilon_extract",
        "epsilon_collision",
        "epsilon_replay",
        "epsilon_ct",
        "epsilon_release",
    ]:
        require(symbol in selected, f"selected-depth expression must include {symbol}")
    require("epsilon_carry" in recursive and "max(d - 1, 0)" in recursive, "recursive promotion expression must include carry-hop accounting")
    require_false(total.get("allComponentLossesInstantiated"), "totalLossRule.allComponentLossesInstantiated")
    require_false(total.get("totalLossWithinBudget"), "totalLossRule.totalLossWithinBudget")
    require_false(total.get("selectedDepthLossClaimAllowed"), "totalLossRule.selectedDepthLossClaimAllowed")


def validate_promotion_and_blockers(ledger: dict[str, Any]) -> None:
    blockers = require_string_list(ledger.get("hardClaimBlockers"), "hardClaimBlockers")
    require(blockers == EXPECTED_BLOCKERS, "hardClaimBlockers must list the pinned production blockers")
    promotion = require_dict(ledger.get("promotionRule"), "promotionRule")
    for key in EXPECTED_PROMOTION_FALSE_FLAGS:
        require_false(promotion.get(key), f"promotionRule.{key}")
    require(promotion.get("requiresAllComponentLossesInstantiated") is True, "promotionRule.requiresAllComponentLossesInstantiated must be true")
    require(promotion.get("requiresTotalLossWithinBudget") is True, "promotionRule.requiresTotalLossWithinBudget must be true")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "selected-depth loss accounting",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "selected-depth loss accounting",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "Scripts/validate-product-selected-depth-loss-accounting.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "selected-depth loss accounting",
        ],
        "Docs/ReleaseCandidateRunbook-2026-04-16.md": [
            "selected-depth loss-accounting version and digest",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
        ],
        "TestVectors/README.md": [
            "product-selected-depth-loss-accounting-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-selected-depth-loss-accounting.py" in gate,
        "production gate must run selected-depth loss-accounting validator",
    )
    require(
        "run_step Scripts/test-product-selected-depth-loss-accounting-validation.py" in gate,
        "production gate must run selected-depth loss-accounting regression tests",
    )


def validate_ledger(path: Path) -> None:
    ledger = read_json(path)
    text = json.dumps(ledger, sort_keys=True).lower()
    require("external" + " audit" not in text, "ledger must not encode outsourced review as a product gate")
    require(set(ledger) == EXPECTED_TOP_LEVEL_KEYS, "top-level ledger keys must match the v1 contract exactly")
    require(ledger.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(ledger.get("ledgerID") == "superneo-product-selected-depth-loss-accounting-v1", "ledgerID mismatch")
    require(
        ledger.get("claimStatus") == "selected-depth-loss-contract-not-production-claim",
        "claimStatus must stay non-production",
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
