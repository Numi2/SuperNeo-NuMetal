#!/usr/bin/env python3
"""Validate product QROM CTCO transform precondition evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PRECONDITIONS = ROOT / "TestVectors" / "product-qrom-transform-preconditions-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "preconditionID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "researchBasis",
    "selectedTransformProfile",
    "preconditions",
    "proofKindFit",
    "lossInterface",
    "hardClaimBlockers",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "proofEnvelopePolicy": "Docs/ProofEnvelope.md",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiatShamirTransformPreconditions",
    "ProductQROMTransformFamily",
    "ProductCompilerFamily",
    "ProductChallengeTapeCommitOpenCompiler",
    "ProductChallengeTapeExpansion",
    "ProductChallengeTapeExpansionAccepted",
    "ProductInteractiveProtocolDefinitions",
    "ProductInteractiveSpecialSoundnessData",
    "ProductInteractiveDelayedMessageData",
    "ProductInteractiveUniqueResponseData",
    "productSecurityTheorem_requires_challenge_tape_expansion",
    "productSecurityTheorem_requires_qrom_transform_preconditions",
}

EXPECTED_PRECONDITION_IDS = [
    "ctco-public-coin-protocol",
    "single-seed-challenge-tape",
    "hbind-384-acceptance-bindings",
    "challenge-space-uniformity",
    "transcript-oracle-input-encoding",
    "delayed-message-binding",
    "unique-response-data",
    "underlying-interactive-security",
    "zero-knowledge-or-simulator-preconditions",
    "quantum-query-bound",
    "qrom-compiler-overhead-instantiation",
    "collision-and-malleability-exclusion",
]

EXPECTED_PROOF_KINDS = [
    ("fold", 1, 204),
    ("terminal", 2, 423),
    ("compressed-terminal", 3, 423),
    ("numiseal-terminal", 4, 4_376_925),
    ("numiseal-zk-product", 5, 4_377_150),
]


def fail(message: str) -> None:
    print(f"product QROM CTCO transform precondition validation failed: {message}", file=sys.stderr)
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


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false")


def validate_related_manifests(preconditions: dict[str, Any]) -> None:
    related = require_dict(preconditions.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the transform-precondition evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, nested_key in [
        ("productQROMFiatShamirAccounting", "productQROMTransformPreconditions"),
        ("productQROMTranscriptSchedule", "productQROMTransformPreconditions"),
        ("productCryptoSecurityDossier", "productQROMTransformPreconditions"),
        ("selectedDepthLossAccounting", "productQROMTransformPreconditions"),
        ("productTotalLossBudget", "productQROMTransformPreconditions"),
        ("productQROMInteractiveReduction", "productQROMTransformPreconditions"),
    ]:
        manifest = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        manifest_related = require_dict(manifest.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            manifest_related.get(nested_key) == "TestVectors/product-qrom-transform-preconditions-v1.json",
            f"{manifest_key} must link product-qrom-transform-preconditions-v1.json",
        )


def validate_formal_surface(preconditions: dict[str, Any]) -> None:
    formal = require_dict(preconditions.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(EXPECTED_FORMAL_DECLARATIONS.issubset(declarations), "formalSurface.declarations missing CTCO declarations")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_research_basis(preconditions: dict[str, Any]) -> None:
    rows = preconditions.get("researchBasis")
    require(isinstance(rows, list) and len(rows) >= 4, "researchBasis must include CTCO, fallback, sponge, and legacy sources")
    ids = [require_string(require_dict(row, f"researchBasis[{index}]").get("id"), f"researchBasis[{index}].id") for index, row in enumerate(rows)]
    for expected in ["DFMS22", "RotemTessaro", "SpongeQRO", "DFM20-legacy"]:
        require(expected in ids, f"researchBasis missing {expected}")
    joined = json.dumps(rows, sort_keys=True).lower()
    for needle in ["commit-and-open", "straight-line", "shake256", "dfm20"]:
        require(needle in joined, f"researchBasis must mention {needle}")


def validate_selected_transform_profile(preconditions: dict[str, Any]) -> None:
    profile = require_dict(preconditions.get("selectedTransformProfile"), "selectedTransformProfile")
    require(profile.get("model") == "ideal-split-qro", "selectedTransformProfile.model mismatch")
    require(profile.get("compilerFamily") == "ctco", "compilerFamily must be ctco")
    require(profile.get("fallbackFamily") == "merkle-straightline", "fallbackFamily mismatch")
    require(profile.get("currentSelectedFamily") == "ctco", "currentSelectedFamily mismatch")
    require(profile.get("exactMoveCountInstantiated") is True, "exactMoveCountInstantiated must be true")
    require(profile.get("challengeCountSymbol") == "one-seed", "challengeCountSymbol mismatch")
    require(profile.get("challengeOracleBits") == 256, "challengeOracleBits mismatch")
    require(profile.get("bindingOracleBits") == 384, "bindingOracleBits mismatch")
    require(profile.get("merkleNodeBits") == 384, "merkleNodeBits mismatch")
    loss_shape = require_string(profile.get("selectedLossShape"), "selectedLossShape")
    require("epsilon_compiler_overhead" in loss_shape and "factorial" in loss_shape, "selectedLossShape must pin new loss and reject factorial term")
    require_true(profile.get("interactiveLossChargedOutsideQROM"), "interactiveLossChargedOutsideQROM")
    require_true(profile.get("legacyDFM20InterfaceDeprecated"), "legacyDFM20InterfaceDeprecated")
    require_false(profile.get("productionTransformClaimAllowed"), "productionTransformClaimAllowed")


def validate_precondition_rows(preconditions: dict[str, Any]) -> None:
    rows = preconditions.get("preconditions")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_PRECONDITION_IDS), "preconditions length mismatch")
    seen: list[str] = []
    satisfied = set()
    unsatisfied = set()
    for index, item in enumerate(rows):
        row = require_dict(item, f"preconditions[{index}]")
        row_id = require_string(row.get("id"), f"preconditions[{index}].id")
        seen.append(row_id)
        require(row.get("required") is True, f"{row_id}.required must be true")
        require_string(row.get("status"), f"{row_id}.status")
        require_string(row.get("evidence"), f"{row_id}.evidence")
        require_string_list(row.get("sourceBasis"), f"{row_id}.sourceBasis")
        if row.get("satisfied") is True:
            satisfied.add(row_id)
        elif row.get("satisfied") is False:
            unsatisfied.add(row_id)
        else:
            fail(f"{row_id}.satisfied must be boolean")
    require(seen == EXPECTED_PRECONDITION_IDS, "preconditions order mismatch")
    require({"ctco-public-coin-protocol", "hbind-384-acceptance-bindings", "challenge-space-uniformity", "transcript-oracle-input-encoding", "quantum-query-bound", "collision-and-malleability-exclusion"}.issubset(satisfied), "closed structural preconditions mismatch")
    require({"single-seed-challenge-tape", "delayed-message-binding", "unique-response-data", "underlying-interactive-security", "zero-knowledge-or-simulator-preconditions", "qrom-compiler-overhead-instantiation"}.issubset(unsatisfied), "open CTCO implementation/security preconditions mismatch")


def validate_proof_kind_fit(preconditions: dict[str, Any]) -> None:
    rows = preconditions.get("proofKindFit")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_PROOF_KINDS), "proofKindFit length mismatch")
    seen: list[tuple[str, int]] = []
    for index, (expected_kind, envelope_kind, legacy_count) in enumerate(EXPECTED_PROOF_KINDS):
        row = require_dict(rows[index], f"proofKindFit[{index}]")
        proof_kind = require_string(row.get("proofKind"), f"proofKindFit[{index}].proofKind")
        seen.append((proof_kind, row.get("envelopeKind")))
        require(proof_kind == expected_kind, f"{expected_kind}.proofKind mismatch")
        require(row.get("envelopeKind") == envelope_kind, f"{expected_kind}.envelopeKind mismatch")
        require(row.get("candidateFamily", "").startswith("ctco"), f"{expected_kind}.candidateFamily must be ctco")
        require(row.get("exactInteractiveProtocolSpecified") is True, f"{expected_kind}.exactInteractiveProtocolSpecified must be true")
        require(row.get("challengeCountN") == 1, f"{expected_kind}.challengeCountN must be 1")
        require(row.get("legacyMaximumProtocolChallengeDerivations") == legacy_count, f"{expected_kind}.legacyMaximumProtocolChallengeDerivations mismatch")
        require(row.get("queryBoundQH") == "2^64", f"{expected_kind}.queryBoundQH mismatch")
        require(row.get("queryBoundLog2") == 64, f"{expected_kind}.queryBoundLog2 mismatch")
        require_false(row.get("transformPreconditionsSatisfied"), f"{expected_kind}.transformPreconditionsSatisfied")
        require_false(row.get("productionQROMClaimAllowed"), f"{expected_kind}.productionQROMClaimAllowed")
    require(seen == [(kind, envelope) for kind, envelope, _ in EXPECTED_PROOF_KINDS], "proofKindFit order mismatch")


def validate_loss_interface(preconditions: dict[str, Any]) -> None:
    interface = require_dict(preconditions.get("lossInterface"), "lossInterface")
    for key in [
        "qromAccountingManifest",
        "interactiveReductionManifest",
        "transcriptScheduleManifest",
        "collisionMalleabilityEvidenceManifest",
        "totalLossBudgetManifest",
    ]:
        require_relative_path(interface.get(key), f"lossInterface.{key}")
    require(interface.get("qromLossSymbol") == "epsilon_qrom", "qromLossSymbol mismatch")
    require(interface.get("compilerOverheadSymbol") == "epsilon_compiler_overhead", "compilerOverheadSymbol mismatch")
    require(interface.get("hashModelGapSymbol") == "epsilon_hash_model_gap", "hashModelGapSymbol mismatch")
    selected = require_string(interface.get("selectedDepthExpression"), "selectedDepthExpression")
    require("epsilon_compiler_overhead" in selected and "epsilon_hash_model_gap" in selected, "selectedDepthExpression mismatch")
    require_false(interface.get("numericLossInstantiated"), "lossInterface.numericLossInstantiated")
    require_false(interface.get("qromLossWithinBudget"), "lossInterface.qromLossWithinBudget")


def validate_promotion_and_blockers(preconditions: dict[str, Any]) -> None:
    blockers = " ".join(require_string_list(preconditions.get("hardClaimBlockers"), "hardClaimBlockers")).lower()
    for needle in ["special-soundness", "delayed-message", "unique-response", "compiler_overhead"]:
        require(needle in blockers, f"hardClaimBlockers must mention {needle}")
    promotion = require_dict(preconditions.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    for key in [
        "requiresInteractiveProtocolImplementation",
        "requiresUnderlyingInteractiveSecurity",
        "requiresDelayedMessageData",
        "requiresUniqueResponseData",
        "requiresQROMLossInstantiation",
        "requiresTotalLossBudgetUpdate",
    ]:
        require_true(promotion.get(key), f"promotionRule.{key}")
    require_false(promotion.get("requiresHBind384Implementation"), "promotionRule.requiresHBind384Implementation")
    for key in [
        "requiresChallengeUniformity",
        "requiresTranscriptEncodingProof",
        "requiresStructuralCollisionMalleabilityEvidence",
        "requiresQuantumOracleQueryBound",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")


def validate_preconditions(path: Path) -> None:
    preconditions = read_json(path)
    text = json.dumps(preconditions, sort_keys=True).lower()
    require("external" + " audit" not in text, "preconditions must not encode outsourced review as a product gate")
    require(set(preconditions) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(preconditions.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(preconditions.get("preconditionID") == "superneo-product-qrom-transform-preconditions-v1", "preconditionID mismatch")
    require(preconditions.get("claimStatus") == "qrom-ctco-transform-precondition-contract-not-production-claim", "claimStatus mismatch")
    validate_related_manifests(preconditions)
    validate_formal_surface(preconditions)
    validate_research_basis(preconditions)
    validate_selected_transform_profile(preconditions)
    validate_precondition_rows(preconditions)
    validate_proof_kind_fit(preconditions)
    validate_loss_interface(preconditions)
    validate_promotion_and_blockers(preconditions)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else PRECONDITIONS
    if not path.is_absolute():
        path = ROOT / path
    validate_preconditions(path)
    print("product QROM CTCO transform precondition validation passed")


if __name__ == "__main__":
    main()
