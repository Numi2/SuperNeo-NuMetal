#!/usr/bin/env python3
"""Validate shared bad-event deduplication evidence for product loss accounting."""

from __future__ import annotations

import json
import sys
from fractions import Fraction
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-shared-bad-event-dedup-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "evidenceID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "deduplicationRule",
    "sharedCoreTags",
    "residualTermPolicy",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productQROMPublicCoinAccounting": "TestVectors/product-qrom-public-coin-accounting-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
}

EXPECTED_FORMAL_MODULES = [
    "Formal/SuperNeoFormal/ProductBadEventLedger.lean",
    "Formal/SuperNeoFormal/ProductSecurityTheorem.lean",
]

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductBadEventLedger",
    "aggregate",
    "aggregate_card_le_flatCharge",
    "shared_tag_charged_once",
    "ProductSharedBadEventDeduplication",
    "ProductSharedBadEventDeduplicationAccepted",
    "productSecurityTheorem_requires_shared_bad_event_deduplication",
}

EXPECTED_TAGS = [
    "core.module_sis.ajtai_binding",
    "core.commitment.opening_binding",
]


def fail(message: str) -> None:
    print(f"product shared bad-event dedup validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def reject_duplicate_object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_object_pairs)
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


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def parse_exact_dyadic(value: Any, label: str) -> Fraction:
    text = require_string(value, label)
    require("/2^" in text, f"{label} must use numerator/2^exponent form")
    numerator_text, exponent_text = text.split("/2^", 1)
    try:
        numerator = int(numerator_text)
        exponent = int(exponent_text)
    except ValueError:
        fail(f"{label} must use integer numerator and exponent")
    require(numerator >= 0 and exponent >= 0, f"{label} must be non-negative")
    return Fraction(numerator, 1 << exponent)


def validate_related_manifests(manifest: dict[str, Any]) -> None:
    related = require_dict(manifest.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the dedup evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key in [
        "productCryptoSecurityDossier",
        "selectedDepthLossAccounting",
        "productQROMPublicCoinAccounting",
        "productTotalLossBudget",
    ]:
        peer = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        peer_related = require_dict(peer.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            peer_related.get("productSharedBadEventDedup") == "TestVectors/product-shared-bad-event-dedup-v1.json",
            f"{manifest_key} must link product-shared-bad-event-dedup-v1.json",
        )


def validate_formal_surface(manifest: dict[str, Any]) -> None:
    formal = require_dict(manifest.get("formalSurface"), "formalSurface")
    modules = require_string_list(formal.get("modules"), "formalSurface.modules")
    require(modules == EXPECTED_FORMAL_MODULES, "formalSurface.modules mismatch")
    source = ""
    for index, module in enumerate(modules):
        module_path = require_relative_path(module, f"formalSurface.modules[{index}]")
        source += module_path.read_text(encoding="utf-8") + "\n"
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal source missing {declaration}")


def validate_deduplication_rule(manifest: dict[str, Any]) -> None:
    rule = require_dict(manifest.get("deduplicationRule"), "deduplicationRule")
    require(rule.get("selectedDepth") == 1, "deduplicationRule.selectedDepth must be 1")
    require(rule.get("sharedCoreLossSymbol") == "epsilon_core_shared", "shared core symbol mismatch")
    require(rule.get("sharedCoreBoundLog2") == 129, "shared core bound must be 129 bits")
    require(
        parse_exact_dyadic(rule.get("sharedCoreExactUpperBound"), "sharedCoreExactUpperBound") == Fraction(1, 1 << 129),
        "shared core exact bound must be 1/2^129",
    )
    require(
        rule.get("deduplicationOperator") == "finite tagged union of shared bad-event tags",
        "deduplication operator mismatch",
    )
    for key in [
        "flatSourceSumNotUsedForSharedCore",
        "qromCollisionSeparatedFromSharedCore",
        "sourceFoldTerminalExtractorTermsAreResidualAfterSharedCore",
        "totalLossBudgetChargesSharedCoreOnce",
    ]:
        require(rule.get(key) is True, f"deduplicationRule.{key} must be true")
    require(rule.get("productionTotalLossClaimAllowed") is True, "productionTotalLossClaimAllowed must be true")


def validate_shared_core_tags(manifest: dict[str, Any]) -> None:
    rows = manifest.get("sharedCoreTags")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_TAGS), "sharedCoreTags length mismatch")
    seen: list[str] = []
    all_sources: set[str] = set()
    for index, item in enumerate(rows):
        row = require_dict(item, f"sharedCoreTags[{index}]")
        tag = require_string(row.get("tag"), f"sharedCoreTags[{index}].tag")
        seen.append(tag)
        require_string(row.get("description"), f"{tag}.description")
        sources = require_string_list(row.get("sourceComponents"), f"{tag}.sourceComponents")
        all_sources.update(sources)
        require(row.get("chargedLedgerSymbol") == "epsilon_core_shared", f"{tag}.chargedLedgerSymbol mismatch")
    require(seen == EXPECTED_TAGS, "shared core tags must stay in pinned order")
    for component in [
        "source-fold-knowledge",
        "terminal-numiseal-seal",
        "extractor-instantiation",
        "transcript-collision-domain-separation",
    ]:
        require(component in all_sources, f"shared core tag sources must mention {component}")


def validate_residual_policy(manifest: dict[str, Any]) -> None:
    policy = require_dict(manifest.get("residualTermPolicy"), "residualTermPolicy")
    require(policy.get("sourceFoldResidualSymbol") == "epsilon_fold_residual", "source fold residual symbol mismatch")
    require(policy.get("terminalResidualSymbol") == "epsilon_terminal_residual", "terminal residual symbol mismatch")
    require(policy.get("extractorResidualSymbol") == "epsilon_extract_residual", "extractor residual symbol mismatch")
    for key in [
        "sourceFoldResidualExcludesSharedCore",
        "terminalResidualExcludesSharedCore",
        "extractorResidualExcludesSharedCore",
        "hbindCollisionRemainsEpsilonCollision",
    ]:
        require(policy.get(key) is True, f"residualTermPolicy.{key} must be true")


def validate_promotion_rule(manifest: dict[str, Any]) -> None:
    promotion = require_dict(manifest.get("promotionRule"), "promotionRule")
    require(promotion.get("repositoryLocalIdealQROMClaimAllowed") is True, "promotionRule.repositoryLocalIdealQROMClaimAllowed must be true")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require(promotion.get(key) is False, f"promotionRule.{key} must stay false until production gates close")
    for key in [
        "requiresSharedBadEventDeduplication",
        "requiresInteractiveSecurityBounds",
        "requiresZKSimulatorComposition",
    ]:
        require(promotion.get(key) is False, f"promotionRule.{key} must be false")
    for key in [
        "requiresRemainingTotalLossTerms",
    ]:
        require(promotion.get(key) is False, f"promotionRule.{key} must be false")


def validate_manifest(path: Path) -> None:
    manifest = read_json(path)
    text = json.dumps(manifest, sort_keys=True).lower()
    require("external" + " audit" not in text, "manifest must not encode outsourced review as a product gate")
    require(set(manifest) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(manifest.get("evidenceID") == "superneo-product-shared-bad-event-dedup-v1", "evidenceID mismatch")
    require(
        manifest.get("claimStatus") == "shared-bad-event-dedup-pinned-repository-local-production-total-loss-claim",
        "claimStatus mismatch",
    )
    validate_related_manifests(manifest)
    validate_formal_surface(manifest)
    validate_deduplication_rule(manifest)
    validate_shared_core_tags(manifest)
    validate_residual_policy(manifest)
    validate_promotion_rule(manifest)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not path.is_absolute():
        path = ROOT / path
    validate_manifest(path)
    print("product shared bad-event dedup validation passed")


if __name__ == "__main__":
    main()
