#!/usr/bin/env python3
"""Validate product QROM Fiat-Shamir transform precondition evidence."""

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
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "proofEnvelopePolicy": "Docs/ProofEnvelope.md",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiatShamirTransformPreconditions",
    "ProductFiatShamirTransformPreconditionsAccepted",
    "productSecurityTheorem_requires_qrom_transform_preconditions",
}

EXPECTED_RESEARCH_IDS = ["DFMS19", "DFM20", "Unruh17", "DFMS22"]

EXPECTED_PRECONDITION_IDS = [
    "public-coin-interactive-protocol",
    "constant-round-odd-message-schedule",
    "challenge-space-uniformity",
    "transcript-oracle-input-encoding",
    "witness-independent-oracle-labels",
    "underlying-interactive-security",
    "zero-knowledge-or-simulator-preconditions",
    "quantum-query-bound",
    "qrom-reduction-loss-instantiation",
    "collision-and-malleability-exclusion",
]

EXPECTED_PROOF_KINDS = [
    ("fold", 1),
    ("terminal", 2),
    ("compressed-terminal", 3),
    ("numiseal-terminal", 4),
    ("numiseal-zk-product", 5),
]

EXPECTED_BLOCKERS = [
    "exact public-coin interactive protocol for every accepted product proof kind",
    "exact constant-round odd-message schedule and challenge count n",
    "challenge-space uniformity and transcript-oracle encoding proof",
    "underlying interactive knowledge-soundness or soundness bound against quantum dishonest provers",
    "numeric Q_H query bound and C_n * Q_H^(2n) reduction-loss instantiation",
    "integration of epsilon_fs_transform and epsilon_precondition into QROM accounting and the selected total-loss budget",
]


def fail(message: str) -> None:
    print(f"product QROM transform precondition validation failed: {message}", file=sys.stderr)
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
    require(value is False, f"{label} must be false until QROM transform evidence is instantiated")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(preconditions: dict[str, Any]) -> None:
    related = require_dict(preconditions.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the transform-precondition evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    qrom = read_json(ROOT / EXPECTED_MANIFESTS["productQROMFiatShamirAccounting"])
    qrom_related = require_dict(qrom.get("relatedManifests"), "productQROMFiatShamirAccounting.relatedManifests")
    require(
        qrom_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM accounting must link the transform precondition dossier",
    )
    qrom_model = require_dict(qrom.get("fiatShamirModel"), "productQROMFiatShamirAccounting.fiatShamirModel")
    require(
        qrom_model.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM accounting model must point at the transform precondition dossier",
    )

    schedule = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTranscriptSchedule"])
    schedule_related = require_dict(schedule.get("relatedManifests"), "productQROMTranscriptSchedule.relatedManifests")
    require(
        schedule_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM transcript schedule must link the transform precondition dossier",
    )

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "product crypto security dossier must link the transform precondition dossier",
    )
    qrom_position = require_dict(dossier.get("fiatShamirQROMPosition"), "productCryptoSecurityDossier.fiatShamirQROMPosition")
    require(
        qrom_position.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "dossier Fiat-Shamir/QROM position must point at the transform precondition dossier",
    )

    ledger = read_json(ROOT / EXPECTED_MANIFESTS["selectedDepthLossAccounting"])
    ledger_related = require_dict(ledger.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        ledger_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "selected-depth ledger must link the transform precondition dossier",
    )

    budget = read_json(ROOT / EXPECTED_MANIFESTS["productTotalLossBudget"])
    budget_related = require_dict(budget.get("relatedManifests"), "productTotalLossBudget.relatedManifests")
    require(
        budget_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "total-loss budget must link the transform precondition dossier",
    )


def validate_formal_surface(preconditions: dict[str, Any]) -> None:
    formal = require_dict(preconditions.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_research_basis(preconditions: dict[str, Any]) -> None:
    rows = preconditions.get("researchBasis")
    require(isinstance(rows, list), "researchBasis must be a list")
    require(len(rows) == len(EXPECTED_RESEARCH_IDS), "researchBasis length mismatch")
    seen: list[str] = []
    combined = []
    for index, item in enumerate(rows):
        row = require_dict(item, f"researchBasis[{index}]")
        source_id = require_string(row.get("id"), f"researchBasis[{index}].id")
        seen.append(source_id)
        require_string(row.get("title"), f"{source_id}.title")
        require_string(row.get("authors"), f"{source_id}.authors")
        require_string(row.get("venue"), f"{source_id}.venue")
        url = require_string(row.get("url"), f"{source_id}.url")
        require(url.startswith("https://eprint.iacr.org/") or url.startswith("https://arxiv.org/"), f"{source_id}.url must be a primary paper source")
        used_for = require_string_list(row.get("usedFor"), f"{source_id}.usedFor")
        require(len(used_for) >= 2, f"{source_id}.usedFor must record multiple uses")
        combined.append(json.dumps(row, sort_keys=True).lower())
    require(seen == EXPECTED_RESEARCH_IDS, "researchBasis must stay in the pinned source order")
    joined = " ".join(combined)
    for needle in ["sigma", "multi-round", "o(q", "extractability", "zero-knowledge", "commit-and-open"]:
        require(needle in joined, f"researchBasis must mention {needle}")


def validate_selected_transform_profile(preconditions: dict[str, Any]) -> None:
    profile = require_dict(preconditions.get("selectedTransformProfile"), "selectedTransformProfile")
    require(profile.get("model") == "qrom", "selectedTransformProfile.model must be qrom")
    require("measure-and-reprogram" in require_string(profile.get("profile"), "selectedTransformProfile.profile"), "selected profile must name measure-and-reprogram")
    require(profile.get("selectedDepth") == 1, "selectedTransformProfile.selectedDepth must be 1")
    families = require_string_list(profile.get("acceptedTheoremFamilies"), "selectedTransformProfile.acceptedTheoremFamilies")
    family_text = " ".join(families).lower()
    for needle in ["sigma", "o(q_h^2)", "multi-round", "o(q_h^(2n))", "(2n + 1)"]:
        require(needle in family_text, f"accepted theorem families must mention {needle}")
    require(profile.get("currentSelectedFamily") == "multi-round-public-coin-fail-closed", "currentSelectedFamily mismatch")
    require_false(profile.get("exactMoveCountInstantiated"), "selectedTransformProfile.exactMoveCountInstantiated")
    require(profile.get("challengeCountSymbol") == "n", "challengeCountSymbol must be n")
    require(profile.get("quantumOracleQuerySymbol") == "Q_H", "quantumOracleQuerySymbol must be Q_H")
    loss_shape = require_string(profile.get("selectedLossShape"), "selectedTransformProfile.selectedLossShape")
    for symbol in ["C_n", "Q_H^(2n)", "epsilon_interactive", "epsilon_precondition"]:
        require(symbol in loss_shape, f"selectedLossShape must include {symbol}")
    require_false(profile.get("exactConstantInstantiated"), "selectedTransformProfile.exactConstantInstantiated")
    require_false(profile.get("productionTransformClaimAllowed"), "selectedTransformProfile.productionTransformClaimAllowed")


def validate_precondition_rows(preconditions: dict[str, Any]) -> None:
    rows = preconditions.get("preconditions")
    require(isinstance(rows, list), "preconditions must be a list")
    require(len(rows) == len(EXPECTED_PRECONDITION_IDS), "preconditions length mismatch")
    seen: list[str] = []
    combined = []
    source_ids = set(EXPECTED_RESEARCH_IDS)
    for index, item in enumerate(rows):
        row = require_dict(item, f"preconditions[{index}]")
        row_id = require_string(row.get("id"), f"preconditions[{index}].id")
        seen.append(row_id)
        require_string(row.get("status"), f"{row_id}.status")
        require(row.get("required") is True, f"{row_id}.required must be true")
        require_false(row.get("satisfied"), f"{row_id}.satisfied")
        require_string(row.get("evidence"), f"{row_id}.evidence")
        basis = require_string_list(row.get("sourceBasis"), f"{row_id}.sourceBasis")
        require(set(basis).issubset(source_ids), f"{row_id}.sourceBasis contains unknown source id")
        combined.append(json.dumps(row, sort_keys=True).lower())
    require(seen == EXPECTED_PRECONDITION_IDS, "preconditions must stay in the pinned order")
    joined = " ".join(combined)
    for needle in ["interactive", "2n + 1", "uniform", "encoding", "witness", "quantum", "q_h", "c_n", "collision"]:
        require(needle in joined, f"precondition rows must mention {needle}")


def validate_proof_kind_fit(preconditions: dict[str, Any]) -> None:
    rows = preconditions.get("proofKindFit")
    require(isinstance(rows, list), "proofKindFit must be a list")
    require(len(rows) == len(EXPECTED_PROOF_KINDS), "proofKindFit length mismatch")

    schedule = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTranscriptSchedule"])
    entries = schedule.get("scheduleEntries")
    require(isinstance(entries, list), "scheduleEntries must be a list")
    schedule_pairs = [
        (require_dict(item, f"scheduleEntries[{index}]").get("proofKind"), item.get("envelopeKind"))
        for index, item in enumerate(entries)
    ]

    seen: list[tuple[str, int]] = []
    for index, item in enumerate(rows):
        row = require_dict(item, f"proofKindFit[{index}]")
        proof_kind = require_string(row.get("proofKind"), f"proofKindFit[{index}].proofKind")
        envelope_kind = row.get("envelopeKind")
        require(isinstance(envelope_kind, int), f"{proof_kind}.envelopeKind must be an integer")
        seen.append((proof_kind, envelope_kind))
        require(row.get("scheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json", f"{proof_kind}.scheduleManifest mismatch")
        require_relative_path(row.get("scheduleManifest"), f"{proof_kind}.scheduleManifest")
        require("public-coin" in require_string(row.get("candidateFamily"), f"{proof_kind}.candidateFamily"), f"{proof_kind}.candidateFamily must name public-coin")
        require_false(row.get("exactInteractiveProtocolSpecified"), f"{proof_kind}.exactInteractiveProtocolSpecified")
        require(row.get("challengeCountN") is None, f"{proof_kind}.challengeCountN must stay null until instantiated")
        require(row.get("queryBoundQH") is None, f"{proof_kind}.queryBoundQH must stay null until instantiated")
        require_false(row.get("transformPreconditionsSatisfied"), f"{proof_kind}.transformPreconditionsSatisfied")
        require_false(row.get("productionQROMClaimAllowed"), f"{proof_kind}.productionQROMClaimAllowed")
    require(seen == EXPECTED_PROOF_KINDS, "proofKindFit must stay in the pinned proof-kind order")
    require(schedule_pairs == EXPECTED_PROOF_KINDS, "proofKindFit must match the transcript schedule proof-kind order")


def validate_loss_interface(preconditions: dict[str, Any]) -> None:
    interface = require_dict(preconditions.get("lossInterface"), "lossInterface")
    for key, expected in [
        ("qromAccountingManifest", "TestVectors/product-qrom-fiat-shamir-accounting-v1.json"),
        ("transcriptScheduleManifest", "TestVectors/product-qrom-transcript-schedule-v1.json"),
        ("totalLossBudgetManifest", "TestVectors/product-total-loss-budget-v1.json"),
    ]:
        require(interface.get(key) == expected, f"lossInterface.{key} mismatch")
        require_relative_path(interface.get(key), f"lossInterface.{key}")
    require(interface.get("qromLossSymbol") == "epsilon_qrom", "qromLossSymbol mismatch")
    require(interface.get("fiatShamirTransformLossSymbol") == "epsilon_fs_transform", "fiatShamirTransformLossSymbol mismatch")
    require(interface.get("quantumOracleQueryLossSymbol") == "epsilon_qro_queries", "quantumOracleQueryLossSymbol mismatch")
    require(interface.get("preconditionFailureSymbol") == "epsilon_precondition", "preconditionFailureSymbol mismatch")
    selected = require_string(interface.get("selectedDepthExpression"), "lossInterface.selectedDepthExpression")
    recursive = require_string(interface.get("recursivePromotionExpression"), "lossInterface.recursivePromotionExpression")
    for symbol in ["C_n", "Q_H^(2n)", "epsilon_interactive", "epsilon_precondition"]:
        require(symbol in selected, f"selectedDepthExpression must include {symbol}")
        require(symbol in recursive, f"recursivePromotionExpression must include {symbol}")
    require_false(interface.get("numericLossInstantiated"), "lossInterface.numericLossInstantiated")
    require_false(interface.get("qromLossWithinBudget"), "lossInterface.qromLossWithinBudget")


def validate_promotion_and_blockers(preconditions: dict[str, Any]) -> None:
    blockers = require_string_list(preconditions.get("hardClaimBlockers"), "hardClaimBlockers")
    require(blockers == EXPECTED_BLOCKERS, "hardClaimBlockers mismatch")
    promotion = require_dict(preconditions.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    for key in [
        "requiresInteractiveProtocol",
        "requiresRoundSchedule",
        "requiresChallengeUniformity",
        "requiresTranscriptEncodingProof",
        "requiresUnderlyingInteractiveSecurity",
        "requiresQuantumOracleQueryBound",
        "requiresQROMLossInstantiation",
        "requiresTotalLossBudgetUpdate",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "QROM transform preconditions",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "QROM Transform Preconditions",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "Scripts/validate-product-qrom-transform-preconditions.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "product QROM transform preconditions",
        ],
        "Docs/ReleaseCandidateRunbook-2026-04-16.md": [
            "product QROM transform preconditions version and digest",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product QROM transform preconditions manifest",
        ],
        "TestVectors/README.md": [
            "product-qrom-transform-preconditions-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-qrom-transform-preconditions.py" in gate,
        "production gate must run QROM transform precondition validator",
    )
    require(
        "run_step Scripts/test-product-qrom-transform-preconditions-validation.py" in gate,
        "production gate must run QROM transform precondition regression tests",
    )


def validate_preconditions(path: Path) -> None:
    preconditions = read_json(path)
    text = json.dumps(preconditions, sort_keys=True).lower()
    require("external" + " audit" not in text, "preconditions must not encode outsourced review as a product gate")
    require(set(preconditions) == EXPECTED_TOP_LEVEL_KEYS, "top-level precondition keys must match the v1 contract exactly")
    require(preconditions.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        preconditions.get("preconditionID") == "superneo-product-qrom-transform-preconditions-v1",
        "preconditionID mismatch",
    )
    require(
        preconditions.get("claimStatus") == "qrom-transform-precondition-dossier-not-production-claim",
        "claimStatus must stay non-production",
    )
    validate_related_manifests(preconditions)
    validate_formal_surface(preconditions)
    validate_research_basis(preconditions)
    validate_selected_transform_profile(preconditions)
    validate_precondition_rows(preconditions)
    validate_proof_kind_fit(preconditions)
    validate_loss_interface(preconditions)
    validate_promotion_and_blockers(preconditions)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else PRECONDITIONS
    if not path.is_absolute():
        path = ROOT / path
    validate_preconditions(path)
    print("product QROM transform precondition validation passed")


if __name__ == "__main__":
    main()
