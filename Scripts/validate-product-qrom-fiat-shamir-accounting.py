#!/usr/bin/env python3
"""Validate product QROM Fiat-Shamir accounting evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ACCOUNTING = ROOT / "TestVectors" / "product-qrom-fiat-shamir-accounting-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "accountingID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedDepth",
    "fiatShamirModel",
    "transcriptInterfaces",
    "lossRule",
    "ledgerTermMapping",
    "hardClaimBlockers",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiatShamirLossAccounting",
    "ProductFiatShamirLossAccountingAccepted",
    "productSecurityTheorem_requires_qrom_loss_accounting",
}

EXPECTED_PROOF_KINDS = [
    ("fold", 1),
    ("terminal", 2),
    ("compressed-terminal", 3),
    ("numiseal-terminal", 4),
    ("numiseal-zk-product", 5),
]

EXPECTED_BLOCKERS = [
    "proof that the selected Fiat-Shamir transform preconditions hold",
    "DFM20 numeric reduction terms exceed the selected total-loss budget under the current challenge accounting",
    "challenge sampler uniformity and transcript-oracle encoding proof",
    "proof that proof-kind and transcript-domain separation exclude collision and malleability",
]


def fail(message: str) -> None:
    print(f"product QROM Fiat-Shamir accounting validation failed: {message}", file=sys.stderr)
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
    require(value is False, f"{label} must be false until QROM evidence is instantiated")


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(accounting: dict[str, Any]) -> None:
    related = require_dict(accounting.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the QROM evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "product crypto security dossier must link QROM Fiat-Shamir accounting",
    )
    require(
        dossier_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "product crypto security dossier must link QROM transform preconditions",
    )
    require(
        dossier_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "product crypto security dossier must link QROM interactive reduction",
    )
    qrom = require_dict(dossier.get("fiatShamirQROMPosition"), "productCryptoSecurityDossier.fiatShamirQROMPosition")
    require(
        qrom.get("accountingManifest") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "dossier fiatShamirQROMPosition must point at the QROM manifest",
    )
    require(
        qrom.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "dossier fiatShamirQROMPosition must point at the transform precondition dossier",
    )
    require(
        qrom.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "dossier fiatShamirQROMPosition must point at the interactive reduction manifest",
    )

    ledger = read_json(ROOT / EXPECTED_MANIFESTS["selectedDepthLossAccounting"])
    ledger_related = require_dict(ledger.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        ledger_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "selected-depth ledger must link QROM Fiat-Shamir accounting",
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

    schedule = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTranscriptSchedule"])
    schedule_related = require_dict(schedule.get("relatedManifests"), "productQROMTranscriptSchedule.relatedManifests")
    require(
        schedule_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "QROM transcript schedule must link this accounting manifest",
    )
    require(
        schedule_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM transcript schedule must link the transform precondition dossier",
    )
    require(
        schedule_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM transcript schedule must link the interactive reduction manifest",
    )

    preconditions = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTransformPreconditions"])
    require(
        preconditions.get("claimStatus") == "qrom-transform-precondition-dossier-not-production-claim",
        "QROM transform preconditions claimStatus must stay precise",
    )
    precondition_related = require_dict(preconditions.get("relatedManifests"), "productQROMTransformPreconditions.relatedManifests")
    require(
        precondition_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "QROM transform preconditions must link this accounting manifest",
    )
    require(
        precondition_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM transform preconditions must link the interactive reduction manifest",
    )

    reduction = read_json(ROOT / EXPECTED_MANIFESTS["productQROMInteractiveReduction"])
    reduction_related = require_dict(reduction.get("relatedManifests"), "productQROMInteractiveReduction.relatedManifests")
    require(
        reduction_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "QROM interactive reduction must link this accounting manifest",
    )


def validate_formal_surface(accounting: dict[str, Any]) -> None:
    formal = require_dict(accounting.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_selected_depth(accounting: dict[str, Any]) -> None:
    depth = require_dict(accounting.get("selectedDepth"), "selectedDepth")
    require(depth.get("depthModel") == "bounded-depth", "selectedDepth.depthModel must be bounded-depth")
    require(depth.get("selectedMaximumDepth") == 1, "selectedDepth.selectedMaximumDepth must be 1")
    require(depth.get("acceptedProductLayers") == 1, "selectedDepth.acceptedProductLayers must be 1")
    require(depth.get("selectedRecursiveCarryHops") == 0, "selectedDepth.selectedRecursiveCarryHops must be 0")
    require_false(depth.get("qromPromotionAllowed"), "selectedDepth.qromPromotionAllowed")


def validate_fiat_shamir_model(accounting: dict[str, Any]) -> None:
    model = require_dict(accounting.get("fiatShamirModel"), "fiatShamirModel")
    require(model.get("model") == "qrom", "fiatShamirModel.model must be qrom")
    require(
        model.get("transcriptScheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "fiatShamirModel.transcriptScheduleManifest mismatch",
    )
    require_relative_path(model.get("transcriptScheduleManifest"), "fiatShamirModel.transcriptScheduleManifest")
    require(
        model.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "fiatShamirModel.transformPreconditionManifest mismatch",
    )
    require_relative_path(model.get("transformPreconditionManifest"), "fiatShamirModel.transformPreconditionManifest")
    require(
        model.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "fiatShamirModel.interactiveReductionManifest mismatch",
    )
    require_relative_path(model.get("interactiveReductionManifest"), "fiatShamirModel.interactiveReductionManifest")
    require(model.get("interactiveProtocolSpecified") is True, "fiatShamirModel.interactiveProtocolSpecified must be true")
    require(model.get("publicCoinChallengeScheduleSpecified") is True, "publicCoinChallengeScheduleSpecified must be true")
    require_false(model.get("transformPreconditionsSatisfied"), "fiatShamirModel.transformPreconditionsSatisfied")
    require_true(model.get("quantumOracleQueryBoundAccounted"), "fiatShamirModel.quantumOracleQueryBoundAccounted")
    require(model.get("transcriptDomainSeparatorsBound") is True, "transcriptDomainSeparatorsBound must be true")
    require(model.get("proofKindSeparationBound") is True, "proofKindSeparationBound must be true")
    require_false(model.get("transcriptCollisionMalleabilityExcluded"), "fiatShamirModel.transcriptCollisionMalleabilityExcluded")
    require_false(model.get("productionQROMClaimAllowed"), "fiatShamirModel.productionQROMClaimAllowed")


def validate_transcript_interfaces(accounting: dict[str, Any]) -> None:
    interfaces = accounting.get("transcriptInterfaces")
    require(isinstance(interfaces, list), "transcriptInterfaces must be a list")
    require(len(interfaces) == len(EXPECTED_PROOF_KINDS), "transcriptInterfaces length mismatch")
    seen: list[tuple[str, int]] = []
    combined_text = []
    for index, item in enumerate(interfaces):
        interface = require_dict(item, f"transcriptInterfaces[{index}]")
        proof_kind = require_string(interface.get("proofKind"), f"transcriptInterfaces[{index}].proofKind")
        envelope_kind = interface.get("envelopeKind")
        require(isinstance(envelope_kind, int), f"{proof_kind}.envelopeKind must be an integer")
        seen.append((proof_kind, envelope_kind))
        require_string(interface.get("domainBinding"), f"{proof_kind}.domainBinding")
        challenges = require_string_list(interface.get("challengeFamilies"), f"{proof_kind}.challengeFamilies")
        require(len(challenges) >= 2, f"{proof_kind} must pin multiple challenge families")
        combined_text.append(json.dumps(interface, sort_keys=True).lower())
    require(seen == EXPECTED_PROOF_KINDS, "transcriptInterfaces must stay in the pinned proof-kind order")
    joined = " ".join(combined_text)
    for needle in [
        "source fold",
        "compressed terminal",
        "numiseal",
        "randomness session",
        "component digest root",
    ]:
        require(needle in joined, f"transcriptInterfaces must mention {needle}")


def validate_loss_rule(accounting: dict[str, Any]) -> None:
    rule = require_dict(accounting.get("lossRule"), "lossRule")
    selected = require_string(rule.get("selectedDepthExpression"), "lossRule.selectedDepthExpression")
    recursive = require_string(rule.get("recursivePromotionExpression"), "lossRule.recursivePromotionExpression")
    for symbol in [
        "epsilon_fs_transform",
        "epsilon_precondition",
        "epsilon_qro_queries",
        "epsilon_proof_kind_malleability",
        "2*Q_H",
        "n_kind!",
        "epsilon_interactive_kind",
    ]:
        require(symbol in selected, f"selected-depth QROM expression must include {symbol}")
    require("epsilon_transcript_collision" not in selected, "transcript collision must be exported as epsilon_collision, not double-counted inside epsilon_qrom")
    require("d *" in recursive and "epsilon_qro_queries" in recursive and "epsilon_precondition" in recursive, "recursive QROM expression must include per-depth query and precondition accounting")
    for key in [
        "quantumOracleQuerySymbol",
        "challengeForkingLossSymbol",
        "transcriptCollisionLossSymbol",
        "proofKindMalleabilityLossSymbol",
    ]:
        require_string(rule.get(key), f"lossRule.{key}")
    require(rule.get("queryBoundQH") == "2^64", "lossRule.queryBoundQH must be 2^64")
    require(rule.get("queryBoundLog2") == 64, "lossRule.queryBoundLog2 must be 64")
    require(rule.get("selectedDepthProtocolChallengeDerivations") == 8_755_125, "lossRule.selectedDepthProtocolChallengeDerivations mismatch")
    source = require_string(rule.get("queryBoundAccountingSource"), "lossRule.queryBoundAccountingSource")
    for manifest in [
        "TestVectors/product-qrom-transcript-schedule-v1.json",
        "TestVectors/product-qrom-interactive-reduction-v1.json",
    ]:
        require(manifest in source, f"lossRule.queryBoundAccountingSource must include {manifest}")
    require_false(rule.get("allQROMLossTermsInstantiated"), "lossRule.allQROMLossTermsInstantiated")
    require_false(rule.get("qromLossWithinBudget"), "lossRule.qromLossWithinBudget")
    require_false(rule.get("productionQROMClaimAllowed"), "lossRule.productionQROMClaimAllowed")


def validate_ledger_term_mapping(accounting: dict[str, Any]) -> None:
    mapping = require_dict(accounting.get("ledgerTermMapping"), "ledgerTermMapping")
    require(set(mapping) == {"fiatShamirQROMLoss", "transcriptCollisionLoss"}, "ledgerTermMapping keys mismatch")
    qrom = require_dict(mapping.get("fiatShamirQROMLoss"), "ledgerTermMapping.fiatShamirQROMLoss")
    require(qrom.get("ledgerSymbol") == "epsilon_qrom", "fiatShamirQROMLoss must map to epsilon_qrom")
    qrom_sources = require_string_list(qrom.get("sourceSymbols"), "ledgerTermMapping.fiatShamirQROMLoss.sourceSymbols")
    require(
        qrom_sources == ["epsilon_fs_transform", "epsilon_qro_queries", "epsilon_proof_kind_malleability"],
        "epsilon_qrom source symbols must exclude epsilon_transcript_collision",
    )
    require_string(qrom.get("selectedDepthContribution"), "ledgerTermMapping.fiatShamirQROMLoss.selectedDepthContribution")
    collision = require_dict(mapping.get("transcriptCollisionLoss"), "ledgerTermMapping.transcriptCollisionLoss")
    require(collision.get("ledgerSymbol") == "epsilon_collision", "transcriptCollisionLoss must map to epsilon_collision")
    collision_sources = require_string_list(collision.get("sourceSymbols"), "ledgerTermMapping.transcriptCollisionLoss.sourceSymbols")
    require(collision_sources == ["epsilon_transcript_collision"], "epsilon_collision must map exactly from epsilon_transcript_collision")
    require_string(collision.get("selectedDepthContribution"), "ledgerTermMapping.transcriptCollisionLoss.selectedDepthContribution")


def validate_promotion_and_blockers(accounting: dict[str, Any]) -> None:
    blockers = require_string_list(accounting.get("hardClaimBlockers"), "hardClaimBlockers")
    require(blockers == EXPECTED_BLOCKERS, "hardClaimBlockers mismatch")
    promotion = require_dict(accounting.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    require(promotion.get("requiresInteractiveProtocol") is False, "promotionRule.requiresInteractiveProtocol must be false after interactive reduction manifest closure")
    for key in [
        "requiresTransformPreconditions",
        "requiresQROMLossWithinBudget",
        "requiresSelectedDepthLedgerUpdate",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")
    require(promotion.get("requiresQuantumOracleQueryBound") is False, "promotionRule.requiresQuantumOracleQueryBound must be false after Q_H bound instantiation")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "QROM Fiat-Shamir accounting",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "QROM Fiat-Shamir Accounting",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "Scripts/validate-product-qrom-fiat-shamir-accounting.py",
            "Scripts/validate-product-qrom-transform-preconditions.py",
            "Scripts/validate-product-qrom-interactive-reduction.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "product QROM Fiat-Shamir accounting",
            "product QROM transcript schedule",
            "product QROM transform preconditions",
            "product QROM interactive reduction",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product QROM Fiat-Shamir accounting manifest",
            "Product QROM transcript schedule manifest",
            "Product QROM transform preconditions manifest",
            "Product QROM interactive reduction manifest",
        ],
        "TestVectors/README.md": [
            "product-qrom-fiat-shamir-accounting-v1.json",
            "product-qrom-transcript-schedule-v1.json",
            "product-qrom-transform-preconditions-v1.json",
            "product-qrom-interactive-reduction-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-qrom-fiat-shamir-accounting.py" in gate,
        "production gate must run QROM Fiat-Shamir accounting validator",
    )
    require(
        "run_step Scripts/validate-product-qrom-transcript-schedule.py" in gate,
        "production gate must run QROM transcript schedule validator",
    )
    require(
        "run_step Scripts/test-product-qrom-fiat-shamir-accounting-validation.py" in gate,
        "production gate must run QROM Fiat-Shamir accounting regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-transform-preconditions.py" in gate,
        "production gate must run QROM transform precondition validator",
    )
    require(
        "run_step Scripts/validate-product-qrom-interactive-reduction.py" in gate,
        "production gate must run QROM interactive reduction validator",
    )


def validate_accounting(path: Path) -> None:
    accounting = read_json(path)
    text = json.dumps(accounting, sort_keys=True).lower()
    require("external" + " audit" not in text, "accounting must not encode outsourced review as a product gate")
    require(set(accounting) == EXPECTED_TOP_LEVEL_KEYS, "top-level accounting keys must match the v1 contract exactly")
    require(accounting.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(accounting.get("accountingID") == "superneo-product-qrom-fiat-shamir-accounting-v1", "accountingID mismatch")
    require(
        accounting.get("claimStatus") == "qrom-fiat-shamir-loss-contract-not-production-claim",
        "claimStatus must stay non-production",
    )
    validate_related_manifests(accounting)
    validate_formal_surface(accounting)
    validate_selected_depth(accounting)
    validate_fiat_shamir_model(accounting)
    validate_transcript_interfaces(accounting)
    validate_loss_rule(accounting)
    validate_ledger_term_mapping(accounting)
    validate_promotion_and_blockers(accounting)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ACCOUNTING
    if not path.is_absolute():
        path = ROOT / path
    validate_accounting(path)
    print("product QROM Fiat-Shamir accounting validation passed")


if __name__ == "__main__":
    main()
