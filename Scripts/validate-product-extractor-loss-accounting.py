#!/usr/bin/env python3
"""Validate product extractor loss accounting evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ACCOUNTING = ROOT / "TestVectors" / "product-extractor-loss-accounting-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "accountingID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedDepth",
    "chainRootRecurrence",
    "extractorInterface",
    "componentLosses",
    "lossRule",
    "hardClaimBlockers",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
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
    "ProductRecursiveCarryChainRootRecurrence",
    "ProductRecursiveCarryChainRootRecurrenceAccepted",
    "ProductExtractorLossAccounting",
    "ProductExtractorLossAccountingAccepted",
    "productFoldExtractor_from_acceptedProof",
    "productTerminalExtractor_from_acceptedProof",
    "productCompressedTerminalExtractor_from_acceptedProof",
    "productNumiSealTerminalExtractor_from_acceptedProof",
    "productNumiSealZKProductExtractor_from_acceptedProof",
    "productRecursiveCarryDepthLeThreeExtractor_from_acceptedProof",
    "productRecursiveCarryChainRoot_recurrence_unfolds_depth_le_three",
    "productRecursiveCarryChainRoot_verifier_extractor_path_depth_le_three",
    "productSecurityTheorem_requires_extractor_loss_accounting",
}

EXPECTED_COMPONENT_IDS = [
    "source-fold-extractor",
    "terminal-seal-extractor",
    "product-envelope-composition-extractor",
    "recursive-carry-extractor",
]

EXPECTED_BLOCKERS = [
    "recursive carry extractor for promoted depth beyond selected depth 3",
]

EXPECTED_CLAIM_STATUS = "selected-depth-concrete-extractor-loss-instantiated-repository-local-production-claim"
EXPECTED_DEPTH_INDEXING = {
    "baseAcceptedLayerDepth": 1,
    "recursiveChildDepths": [2, 3],
    "selectedMaximumDepth": 3,
    "selectedRecursiveCarryHops": 2,
    "depthZeroArtifactAccepted": False,
}
EXPECTED_CARRY_ROOT_FIELD_ORDER = [
    "domainTag",
    "version",
    "profileID",
    "selectedDepthPolicyDigest",
    "depthIndex",
    "parentChainRoot",
    "artifactDigest",
    "sourceFoldEnvelopeDigest",
    "productProofEnvelopeDigest",
    "producerEnvelopeDigest",
    "publicStatementDigest",
    "consumerSessionDigest",
    "contextRoot",
    "replayRoot",
    "typedCarryStatementDigest",
    "recursiveRelationDigest",
    "orderedPCDParentTupleRoot",
]
EXPECTED_PCD_PARENT_TUPLE_FIELDS = [
    "parentPosition",
    "parentNodeIndex",
    "parentDepth",
    "parentStateDigest",
    "parentAccumulatorDigest",
    "parentPublicStatementDigest",
    "parentOutputAccumulatorClaim",
    "parentEvaluationPoint",
    "parentClaimValue",
    "parentRecursiveRelationDigest",
    "parentCarryChainRoot",
]
EXPECTED_EXTRACTOR_THEOREMS = {
    "fold": "productFoldExtractor_from_acceptedProof",
    "terminal": "productTerminalExtractor_from_acceptedProof",
    "compressed-terminal": "productCompressedTerminalExtractor_from_acceptedProof",
    "numiseal-terminal": "productNumiSealTerminalExtractor_from_acceptedProof",
    "numiseal-zk-product": "productNumiSealZKProductExtractor_from_acceptedProof",
    "recursive-carry-depth-le-three": "productRecursiveCarryDepthLeThreeExtractor_from_acceptedProof",
}


def fail(message: str) -> None:
    print(f"product extractor loss accounting validation failed: {message}", file=sys.stderr)
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
    require(value is False, f"{label} must be false until extractor evidence is instantiated")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(accounting: dict[str, Any]) -> None:
    related = require_dict(accounting.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the extractor evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "product crypto security dossier must link extractor loss accounting",
    )
    extractor = require_dict(dossier.get("extractorLossAccounting"), "productCryptoSecurityDossier.extractorLossAccounting")
    require(
        extractor.get("accountingManifest") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "dossier extractorLossAccounting must point at the extractor manifest",
    )

    ledger = read_json(ROOT / EXPECTED_MANIFESTS["selectedDepthLossAccounting"])
    ledger_related = require_dict(ledger.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        ledger_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "selected-depth ledger must link extractor loss accounting",
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
    require(depth.get("selectedMaximumDepth") == 3, "selectedDepth.selectedMaximumDepth must be 3")
    require(depth.get("acceptedProductLayers") == 3, "selectedDepth.acceptedProductLayers must be 3")
    require(depth.get("selectedRecursiveCarryHops") == 2, "selectedDepth.selectedRecursiveCarryHops must be 2")
    require(depth.get("loadedParentChainRequired") is True, "selectedDepth.loadedParentChainRequired must be true")
    require(depth.get("extractorPromotionAllowed") is True, "selectedDepth.extractorPromotionAllowed must be true for selected-depth extractor promotion")
    indexing = require_dict(depth.get("depthIndexing"), "selectedDepth.depthIndexing")
    require(indexing == EXPECTED_DEPTH_INDEXING, "selectedDepth.depthIndexing mismatch")


def validate_chain_root_recurrence(accounting: dict[str, Any]) -> None:
    recurrence = require_dict(accounting.get("chainRootRecurrence"), "chainRootRecurrence")
    require(recurrence.get("selectedDepth") == 3, "chainRootRecurrence.selectedDepth must be 3")
    require(recurrence.get("selectedRecursiveCarryHops") == 2, "chainRootRecurrence.selectedRecursiveCarryHops must be 2")
    require_relative_path(recurrence.get("canonicalVector"), "chainRootRecurrence.canonicalVector")
    byte_layout = require_dict(recurrence.get("byteExactLayouts"), "chainRootRecurrence.byteExactLayouts")
    require(byte_layout.get("baseDomainTag") == "SUPERNEO/PRODUCT/CARRY_CHAIN/BASE/v1", "base carry root domain tag mismatch")
    require(byte_layout.get("stepDomainTag") == "SUPERNEO/PRODUCT/CARRY_CHAIN/STEP/v1", "step carry root domain tag mismatch")
    require(byte_layout.get("version") == 1, "carry root layout version must be 1")
    require(byte_layout.get("fieldOrder") == EXPECTED_CARRY_ROOT_FIELD_ORDER, "carry root byte field order mismatch")
    tuple_root = require_dict(recurrence.get("orderedPCDParentTupleRoot"), "chainRootRecurrence.orderedPCDParentTupleRoot")
    require(tuple_root.get("domainTag") == "SUPERNEO/PCD/PARENT_TUPLES/v1", "PCD parent tuple root domain mismatch")
    require(tuple_root.get("tupleFields") == EXPECTED_PCD_PARENT_TUPLE_FIELDS, "PCD parent tuple fields mismatch")
    require(tuple_root.get("consumedByFoldedRelation") is True, "PCD parent tuple root must be consumed by folded relation")
    base = require_string(recurrence.get("baseCase"), "chainRootRecurrence.baseCase").lower()
    step = require_string(recurrence.get("stepCase"), "chainRootRecurrence.stepCase").lower()
    for needle in [
        "rootatdepth(1) = baseroot",
        "actual accepted base artifact",
        "actual source fold envelope",
        "actual numiseal proof envelope",
        "actual public statement",
    ]:
        require(needle in base, f"chainRootRecurrence.baseCase must mention {needle}")
    for needle in [
        "1 <= d < 3",
        "rootatdepth(d + 1) = steproot(d, rootatdepth(d)",
        "parent artifact digest",
        "parent source fold envelope digest",
        "parent product proof envelope digest",
        "accepted producer envelope digest",
        "recomputed context root",
        "recomputed replay root",
        "typed carry statements",
        "recursiverelationdigest",
        "ordered pcd parent tuple root",
    ]:
        require(needle in step, f"chainRootRecurrence.stepCase must mention {needle}")
    unrolling = require_string_list(recurrence.get("depthThreeUnrolling"), "chainRootRecurrence.depthThreeUnrolling")
    require(
        unrolling == [
            "rootAtDepth(1) = baseRoot",
            "rootAtDepth(2) = stepRoot(1, baseRoot)",
            "rootAtDepth(3) = stepRoot(2, stepRoot(1, baseRoot))",
        ],
        "chainRootRecurrence.depthThreeUnrolling mismatch",
    )
    verifier = require_string(recurrence.get("verifierProcedure"), "chainRootRecurrence.verifierProcedure").lower()
    extractor = require_string(recurrence.get("extractorProcedure"), "chainRootRecurrence.extractorProcedure").lower()
    for needle in ["verify", "loaded verified parent chain root", "actual loaded parent", "before accepting"]:
        require(needle in verifier, f"chainRootRecurrence.verifierProcedure must mention {needle}")
    for needle in ["productcarrychainroot", "does not accept", "artifact metadata"]:
        require(needle in extractor, f"chainRootRecurrence.extractorProcedure must mention {needle}")
    require(
        recurrence.get("metadataOnlyRecursiveParentRejected") is True,
        "chainRootRecurrence.metadataOnlyRecursiveParentRejected must be true",
    )
    require(
        recurrence.get("ctcoTraceBlock") == "recursive-carry-chain-root",
        "chainRootRecurrence.ctcoTraceBlock mismatch",
    )
    require(
        recurrence.get("formalAcceptance") == "ProductRecursiveCarryChainRootRecurrenceAccepted",
        "chainRootRecurrence.formalAcceptance mismatch",
    )


def validate_extractor_interface(accounting: dict[str, Any]) -> None:
    interface = require_dict(accounting.get("extractorInterface"), "extractorInterface")
    text = json.dumps(interface, sort_keys=True).lower()
    for needle in [
        "proof envelopes",
        "post-acceptance verifier replay",
        "ctco trace blocks",
        "per-kind extractor theorems",
        "swift",
        "proof envelope header bytes",
        "source fold envelope bytes",
        "numiseal product proof envelope bytes",
        "recursive carry context root",
    ]:
        require(needle in text, f"extractorInterface must mention {needle}")
    require(interface.get("concreteExtractorImplemented") is True, "concreteExtractorImplemented must be true")
    require(
        interface.get("concreteExtractorSurface") == "NumiSealProductConcreteExtractor.extract",
        "extractorInterface.concreteExtractorSurface mismatch",
    )
    require(
        interface.get("concreteExtractorEvidenceDigestMetadataKey") == "swiftConcreteExtractorEvidenceDigest",
        "extractorInterface must pin swiftConcreteExtractorEvidenceDigest metadata",
    )
    require(
        interface.get("selectedDepthLossBound") == "epsilon_extract(depth=3) = 0",
        "extractorInterface.selectedDepthLossBound mismatch",
    )
    require(interface.get("extractorSchedulePinned") is True, "extractorSchedulePinned must be true")
    require(
        require_dict(interface.get("perKindExtractorTheorems"), "extractorInterface.perKindExtractorTheorems") == EXPECTED_EXTRACTOR_THEOREMS,
        "per-kind extractor theorem mapping mismatch",
    )
    obligations = set(require_string_list(interface.get("perKindProofObligationFields"), "extractorInterface.perKindProofObligationFields"))
    for obligation in [
        "acceptedInputObjectSpecified",
        "verifierAcceptancePredicateSpecified",
        "extractedObjectSpecified",
        "failureEventsSpecified",
        "ctcoTraceBlockDependencySpecified",
        "extractorLossContributionSpecified",
        "parentChainDependencySpecified",
        "carryChainRootRelatesToExtractedState",
    ]:
        require(obligation in obligations, f"extractorInterface.perKindProofObligationFields missing {obligation}")
    bindings = require_string_list(interface.get("acceptedInputBindings"), "extractorInterface.acceptedInputBindings")
    require(len(bindings) >= 10, "extractorInterface must pin the accepted input binding set")


def validate_component_losses(accounting: dict[str, Any]) -> None:
    components = accounting.get("componentLosses")
    require(isinstance(components, list), "componentLosses must be a list")
    require(len(components) == len(EXPECTED_COMPONENT_IDS), "componentLosses length mismatch")
    seen_ids: list[str] = []
    for index, item in enumerate(components):
        component = require_dict(item, f"componentLosses[{index}]")
        component_id = require_string(component.get("id"), f"componentLosses[{index}].id")
        seen_ids.append(component_id)
        require_string(component.get("lossSymbol"), f"{component_id}.lossSymbol")
        require(component.get("appliesPerAcceptedLayer") in {True, False}, f"{component_id}.appliesPerAcceptedLayer must be boolean")
        multiplicity = component.get("currentMultiplicityAtSelectedDepth")
        require(isinstance(multiplicity, int) and multiplicity >= 0, f"{component_id}.currentMultiplicityAtSelectedDepth must be non-negative")
        require_string(component.get("status"), f"{component_id}.status")
        require_string(component.get("accountingRule"), f"{component_id}.accountingRule")
        require_string(component.get("requiredEvidence"), f"{component_id}.requiredEvidence")
        require(component.get("lossInstantiated") is True, f"{component_id}.lossInstantiated must be true")
        require(component.get("exactUpperBound") == "0", f"{component_id}.exactUpperBound must be 0")
        require("instantiated" in require_string(component.get("status"), f"{component_id}.status"), f"{component_id}.status must record instantiation")
        if component_id == "recursive-carry-extractor":
            require(multiplicity == 2, "recursive-carry-extractor must have two selected-depth carry hops")
            evidence = require_string(component.get("requiredEvidence"), "recursive-carry-extractor.requiredEvidence")
            for needle in ["productCarryChainRoot", "metadata-only", "recursive-carry-chain-root"]:
                require(needle in evidence, f"recursive-carry-extractor evidence must mention {needle}")
    require(seen_ids == EXPECTED_COMPONENT_IDS, "componentLosses must stay in the pinned extractor order")


def validate_loss_rule(accounting: dict[str, Any]) -> None:
    rule = require_dict(accounting.get("lossRule"), "lossRule")
    selected = require_string(rule.get("selectedDepthExpression"), "lossRule.selectedDepthExpression")
    recursive = require_string(rule.get("recursivePromotionExpression"), "lossRule.recursivePromotionExpression")
    require("epsilon_extract(depth=3) = 0" in selected, "selected-depth extractor expression must be exact zero at depth 3")
    require("epsilon_extract_carry" in recursive and "max(d - 1, 0)" in recursive, "recursive extractor expression must include carry-hop loss")
    require(rule.get("allExtractorTermsInstantiated") is True, "lossRule.allExtractorTermsInstantiated must be true")
    require(rule.get("extractorLossWithinBudget") is True, "lossRule.extractorLossWithinBudget must be true")
    require(rule.get("productionExtractorClaimAllowed") is True, "lossRule.productionExtractorClaimAllowed must be true")
    require(rule.get("exactSelectedDepthUpperBound") == "0", "lossRule.exactSelectedDepthUpperBound must be 0")


def validate_promotion_and_blockers(accounting: dict[str, Any]) -> None:
    blockers = accounting.get("hardClaimBlockers")
    require(isinstance(blockers, list), "hardClaimBlockers must be a list")
    require(blockers == [], "hardClaimBlockers must be empty after repository-local source-level promotion")
    promotion = require_dict(accounting.get("promotionRule"), "promotionRule")
    require(
        promotion.get("productionProductSecurityClaimAllowed") is True,
        "promotionRule.productionProductSecurityClaimAllowed must be true",
    )
    require(
        promotion.get("productionExtractorClaimAllowed") is True,
        "promotionRule.productionExtractorClaimAllowed must be true",
    )
    for key in [
        "requiresConcreteExtractorImplementation",
        "requiresExtractorLossWithinBudget",
        "requiresSelectedDepthLedgerUpdate",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")
    require(
        promotion.get("selectedDepthExtractorClaimAllowed") is True,
        "promotionRule.selectedDepthExtractorClaimAllowed must be true",
    )
    require(
        promotion.get("recursiveDepthPromotionRequiresCarryExtractor") is True,
        "promotionRule.recursiveDepthPromotionRequiresCarryExtractor must be true",
    )


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-extractor-loss-accounting-v1.json",
            "extractor loss accounting",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-extractor-loss-accounting-v1.json",
            "Extractor Loss Accounting",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "Scripts/validate-product-extractor-loss-accounting.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "product extractor loss accounting",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product extractor loss accounting manifest",
        ],
        "TestVectors/README.md": [
            "product-extractor-loss-accounting-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-extractor-loss-accounting.py" in gate,
        "production gate must run extractor loss-accounting validator",
    )
    require(
        "run_step Scripts/test-product-extractor-loss-accounting-validation.py" in gate,
        "production gate must run extractor loss-accounting regression tests",
    )


def validate_accounting(path: Path) -> None:
    accounting = read_json(path)
    text = json.dumps(accounting, sort_keys=True).lower()
    require("external" + " audit" not in text, "accounting must not encode outsourced review as a product gate")
    require("per-kind theorem assumption" not in text, "accounting must not leave accepted proof kinds as unresolved theorem assumptions")
    require(set(accounting) == EXPECTED_TOP_LEVEL_KEYS, "top-level accounting keys must match the v1 contract exactly")
    require(accounting.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(accounting.get("accountingID") == "superneo-product-extractor-loss-accounting-v1", "accountingID mismatch")
    require(
        accounting.get("claimStatus") == EXPECTED_CLAIM_STATUS,
        "claimStatus must record selected-depth concrete extractor instantiation",
    )
    validate_related_manifests(accounting)
    validate_formal_surface(accounting)
    validate_selected_depth(accounting)
    validate_chain_root_recurrence(accounting)
    validate_extractor_interface(accounting)
    validate_component_losses(accounting)
    validate_loss_rule(accounting)
    validate_promotion_and_blockers(accounting)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ACCOUNTING
    if not path.is_absolute():
        path = ROOT / path
    validate_accounting(path)
    print("product extractor loss accounting validation passed")


if __name__ == "__main__":
    main()
