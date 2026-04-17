#!/usr/bin/env python3
"""Validate product QROM Fiat-Shamir transcript schedule evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCHEDULE = ROOT / "TestVectors" / "product-qrom-transcript-schedule-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "scheduleID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedDepth",
    "oracleModel",
    "transcriptState",
    "scheduleEntries",
    "ledgerBinding",
    "hardClaimBlockers",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "proofEnvelopePolicy": "Docs/ProofEnvelope.md",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiatShamirTranscriptSchedule",
    "ProductFiatShamirTranscriptScheduleAccepted",
    "productSecurityTheorem_requires_qrom_transcript_schedule",
}

EXPECTED_PROOF_KINDS = [
    ("fold", 1),
    ("terminal", 2),
    ("compressed-terminal", 3),
    ("numiseal-terminal", 4),
    ("numiseal-zk-product", 5),
]

EXPECTED_CHALLENGE_DERIVATIONS = {
    "fold": 204,
    "terminal": 423,
    "compressed-terminal": 423,
    "numiseal-terminal": 4_376_925,
    "numiseal-zk-product": 4_377_150,
}

EXPECTED_QUERY_FAMILY_PREFIXES = [
    "Q_H_fold_",
    "Q_H_terminal_",
    "Q_H_compressed_terminal_",
    "Q_H_numiseal_terminal_",
    "Q_H_numiseal_zk_product_",
]

EXPECTED_BLOCKERS = [
    "Fiat-Shamir transform precondition proof for the pinned transcript schedule",
    "domain-separation collision and proof-kind malleability exclusion proof",
    "integration of the instantiated Q_H bound into a repaired QROM loss model that fits the selected total-loss budget",
]


def fail(message: str) -> None:
    print(f"product QROM transcript schedule validation failed: {message}", file=sys.stderr)
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
    require(value is False, f"{label} must be false until QROM schedule evidence is instantiated")


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def require_int(value: Any, label: str) -> int:
    require(type(value) is int, f"{label} must be an integer")
    return value


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(schedule: dict[str, Any]) -> None:
    related = require_dict(schedule.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the transcript-schedule evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    qrom = read_json(ROOT / EXPECTED_MANIFESTS["productQROMFiatShamirAccounting"])
    qrom_related = require_dict(qrom.get("relatedManifests"), "productQROMFiatShamirAccounting.relatedManifests")
    require(
        qrom_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "QROM accounting must link the transcript schedule",
    )
    require(
        qrom_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM accounting must link transform preconditions",
    )
    require(
        qrom_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM accounting must link interactive reduction",
    )
    require(
        qrom_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM accounting must link sampler/encoding evidence",
    )
    qrom_model = require_dict(qrom.get("fiatShamirModel"), "productQROMFiatShamirAccounting.fiatShamirModel")
    require(
        qrom_model.get("transcriptScheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "QROM accounting Fiat-Shamir model must point at the transcript schedule",
    )
    require(
        qrom_model.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM accounting Fiat-Shamir model must point at transform preconditions",
    )
    require(
        qrom_model.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM accounting Fiat-Shamir model must point at interactive reduction",
    )

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "product crypto security dossier must link the transcript schedule",
    )
    require(
        dossier_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "product crypto security dossier must link transform preconditions",
    )
    require(
        dossier_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "product crypto security dossier must link interactive reduction",
    )
    require(
        dossier_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "product crypto security dossier must link sampler/encoding evidence",
    )
    qrom_position = require_dict(dossier.get("fiatShamirQROMPosition"), "productCryptoSecurityDossier.fiatShamirQROMPosition")
    require(
        qrom_position.get("transcriptScheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "dossier Fiat-Shamir/QROM position must point at the transcript schedule",
    )
    require(
        qrom_position.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "dossier Fiat-Shamir/QROM position must point at transform preconditions",
    )
    require(
        qrom_position.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "dossier Fiat-Shamir/QROM position must point at interactive reduction",
    )

    ledger = read_json(ROOT / EXPECTED_MANIFESTS["selectedDepthLossAccounting"])
    ledger_related = require_dict(ledger.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        ledger_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "selected-depth ledger must link the transcript schedule",
    )
    require(
        ledger_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "selected-depth ledger must link transform preconditions",
    )
    require(
        ledger_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "selected-depth ledger must link interactive reduction",
    )
    require(
        ledger_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "selected-depth ledger must link sampler/encoding evidence",
    )

    budget = read_json(ROOT / EXPECTED_MANIFESTS["productTotalLossBudget"])
    budget_related = require_dict(budget.get("relatedManifests"), "productTotalLossBudget.relatedManifests")
    require(
        budget_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "total-loss budget must link the transcript schedule",
    )
    require(
        budget_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "total-loss budget must link transform preconditions",
    )
    require(
        budget_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "total-loss budget must link interactive reduction",
    )
    require(
        budget_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "total-loss budget must link sampler/encoding evidence",
    )

    preconditions = read_json(ROOT / EXPECTED_MANIFESTS["productQROMTransformPreconditions"])
    precondition_related = require_dict(preconditions.get("relatedManifests"), "productQROMTransformPreconditions.relatedManifests")
    require(
        precondition_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "transform preconditions must link this transcript schedule",
    )
    require(
        precondition_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "transform preconditions must link interactive reduction",
    )
    require(
        precondition_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "transform preconditions must link sampler/encoding evidence",
    )

    reduction = read_json(ROOT / EXPECTED_MANIFESTS["productQROMInteractiveReduction"])
    reduction_related = require_dict(reduction.get("relatedManifests"), "productQROMInteractiveReduction.relatedManifests")
    require(
        reduction_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "interactive reduction must link this transcript schedule",
    )
    require(
        reduction_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "interactive reduction must link sampler/encoding evidence",
    )


def validate_formal_surface(schedule: dict[str, Any]) -> None:
    formal = require_dict(schedule.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_selected_depth(schedule: dict[str, Any]) -> None:
    depth = require_dict(schedule.get("selectedDepth"), "selectedDepth")
    require(depth.get("depthModel") == "bounded-depth", "selectedDepth.depthModel must be bounded-depth")
    require(depth.get("selectedMaximumDepth") == 1, "selectedDepth.selectedMaximumDepth must be 1")
    require(depth.get("acceptedProductLayers") == 1, "selectedDepth.acceptedProductLayers must be 1")
    require(depth.get("selectedRecursiveCarryHops") == 0, "selectedDepth.selectedRecursiveCarryHops must be 0")
    require_false(depth.get("schedulePromotionAllowed"), "selectedDepth.schedulePromotionAllowed")


def validate_oracle_model(schedule: dict[str, Any]) -> None:
    model = require_dict(schedule.get("oracleModel"), "oracleModel")
    require(model.get("model") == "qrom", "oracleModel.model must be qrom")
    require("quantum random-oracle" in require_string(model.get("randomOracleAbstraction"), "oracleModel.randomOracleAbstraction"), "oracle abstraction must state the quantum random-oracle boundary")
    require(
        model.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "oracleModel.interactiveReductionManifest mismatch",
    )
    require_relative_path(model.get("interactiveReductionManifest"), "oracleModel.interactiveReductionManifest")
    require(
        model.get("samplerEncodingEvidenceManifest") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "oracleModel.samplerEncodingEvidenceManifest mismatch",
    )
    require_relative_path(model.get("samplerEncodingEvidenceManifest"), "oracleModel.samplerEncodingEvidenceManifest")
    require(model.get("interactiveProtocolFullySpecified") is True, "oracleModel.interactiveProtocolFullySpecified must be true")
    require_true(model.get("quantumOracleQueryBoundInstantiated"), "oracleModel.quantumOracleQueryBoundInstantiated")
    for key in [
        "hashInstantiationProofProvided",
        "transformPreconditionsSatisfied",
        "productionQROMClaimAllowed",
    ]:
        require_false(model.get(key), f"oracleModel.{key}")


def validate_transcript_state(schedule: dict[str, Any]) -> None:
    state = require_dict(schedule.get("transcriptState"), "transcriptState")
    combined = json.dumps(state, sort_keys=True).lower()
    for key in [
        "initialBinding",
        "stateTransitionPolicy",
        "witnessIndependencePolicy",
        "domainSeparatorPolicy",
        "failurePathPolicy",
    ]:
        require_string(state.get(key), f"transcriptState.{key}")
    for needle in [
        "proofenvelopeheader.version",
        "proof kind",
        "length-delimited",
        "witness independent",
        "schedule",
        "failure",
    ]:
        require(needle in combined, f"transcriptState must mention {needle}")


def validate_schedule_entries(schedule: dict[str, Any]) -> None:
    entries = schedule.get("scheduleEntries")
    require(isinstance(entries, list), "scheduleEntries must be a list")
    require(len(entries) == len(EXPECTED_PROOF_KINDS), "scheduleEntries length mismatch")

    qrom = read_json(ROOT / EXPECTED_MANIFESTS["productQROMFiatShamirAccounting"])
    interfaces = qrom.get("transcriptInterfaces")
    require(isinstance(interfaces, list), "QROM accounting transcriptInterfaces must be a list")
    interface_pairs = [
        (require_dict(item, f"transcriptInterfaces[{index}]").get("proofKind"), item.get("envelopeKind"))
        for index, item in enumerate(interfaces)
    ]

    seen: list[tuple[str, int]] = []
    labels: list[str] = []
    combined_text: list[str] = []
    for index, item in enumerate(entries):
        entry = require_dict(item, f"scheduleEntries[{index}]")
        proof_kind = require_string(entry.get("proofKind"), f"scheduleEntries[{index}].proofKind")
        envelope_kind = entry.get("envelopeKind")
        require(isinstance(envelope_kind, int), f"{proof_kind}.envelopeKind must be an integer")
        seen.append((proof_kind, envelope_kind))
        require_string(entry.get("interactiveRoundSchedule"), f"{proof_kind}.interactiveRoundSchedule")
        bindings = require_string_list(entry.get("transcriptBindings"), f"{proof_kind}.transcriptBindings")
        challenge_labels = require_string_list(entry.get("challengeLabels"), f"{proof_kind}.challengeLabels")
        oracle_families = require_string_list(entry.get("oracleQueryFamilies"), f"{proof_kind}.oracleQueryFamilies")
        require(len(bindings) >= 3, f"{proof_kind} must pin at least three transcript bindings")
        require(len(challenge_labels) >= 2, f"{proof_kind} must pin multiple challenge labels")
        require(len(oracle_families) >= 2, f"{proof_kind} must pin multiple oracle query families")
        for label in challenge_labels:
            require(label.startswith("superneo."), f"{proof_kind} challenge label must use the superneo namespace: {label}")
        prefix = EXPECTED_QUERY_FAMILY_PREFIXES[index]
        for family in oracle_families:
            require(family.startswith(prefix), f"{proof_kind} oracle query family must start with {prefix}: {family}")
        expected_derivations = EXPECTED_CHALLENGE_DERIVATIONS[proof_kind]
        require(
            require_int(entry.get("maximumProtocolChallengeDerivations"), f"{proof_kind}.maximumProtocolChallengeDerivations")
            == expected_derivations,
            f"{proof_kind}.maximumProtocolChallengeDerivations mismatch",
        )
        require(entry.get("maximumQuantumOracleQueries") == "2^64", f"{proof_kind}.maximumQuantumOracleQueries must be 2^64")
        require(entry.get("maximumQuantumOracleQueriesLog2") == 64, f"{proof_kind}.maximumQuantumOracleQueriesLog2 must be 64")
        source = require_string(entry.get("queryBoundSource"), f"{proof_kind}.queryBoundSource")
        require("conditional adversary" in source and "schedule-derived" in source, f"{proof_kind}.queryBoundSource must identify the conditional and schedule-derived bounds")
        require_true(entry.get("queryBoundInstantiated"), f"{proof_kind}.queryBoundInstantiated")
        require_false(entry.get("transformPreconditionsSatisfied"), f"{proof_kind}.transformPreconditionsSatisfied")
        require_false(entry.get("productionScheduleClaimAllowed"), f"{proof_kind}.productionScheduleClaimAllowed")
        labels.extend(challenge_labels)
        combined_text.append(json.dumps(entry, sort_keys=True).lower())

    require(seen == EXPECTED_PROOF_KINDS, "scheduleEntries must stay in the pinned proof-kind order")
    require(interface_pairs == EXPECTED_PROOF_KINDS, "QROM accounting transcriptInterfaces must match the schedule proof-kind order")
    require(len(labels) == len(set(labels)), "challenge labels must be globally unique")

    joined = " ".join(combined_text)
    for needle in [
        "source fold",
        "compressed terminal",
        "numiseal",
        "randomness session",
        "declared leakage",
        "component digest root",
    ]:
        require(needle in joined, f"scheduleEntries must mention {needle}")


def validate_ledger_binding(schedule: dict[str, Any]) -> None:
    binding = require_dict(schedule.get("ledgerBinding"), "ledgerBinding")
    require(
        binding.get("qromAccountingManifest") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "ledgerBinding.qromAccountingManifest mismatch",
    )
    require(
        binding.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "ledgerBinding.interactiveReductionManifest mismatch",
    )
    require(
        binding.get("totalLossBudgetManifest") == "TestVectors/product-total-loss-budget-v1.json",
        "ledgerBinding.totalLossBudgetManifest mismatch",
    )
    require_relative_path(binding.get("qromAccountingManifest"), "ledgerBinding.qromAccountingManifest")
    require_relative_path(binding.get("interactiveReductionManifest"), "ledgerBinding.interactiveReductionManifest")
    require_relative_path(binding.get("totalLossBudgetManifest"), "ledgerBinding.totalLossBudgetManifest")
    require(binding.get("qromLossSymbol") == "epsilon_qrom", "ledgerBinding.qromLossSymbol mismatch")
    require(binding.get("transcriptCollisionLossSymbol") == "epsilon_collision", "ledgerBinding.transcriptCollisionLossSymbol mismatch")
    require(binding.get("quantumOracleQuerySymbol") == "Q_H", "ledgerBinding.quantumOracleQuerySymbol mismatch")
    expression = require_string(binding.get("selectedDepthQueryExpression"), "ledgerBinding.selectedDepthQueryExpression")
    for symbol in [
        "Q_H_fold",
        "Q_H_terminal",
        "Q_H_compressed_terminal",
        "Q_H_numiseal_terminal",
        "Q_H_numiseal_zk_product",
    ]:
        require(symbol in expression, f"selectedDepthQueryExpression must include {symbol}")
    require(binding.get("selectedDepthProtocolChallengeDerivations") == sum(EXPECTED_CHALLENGE_DERIVATIONS.values()), "ledgerBinding.selectedDepthProtocolChallengeDerivations mismatch")
    require(binding.get("selectedQHBound") == "2^64", "ledgerBinding.selectedQHBound must be 2^64")
    require(binding.get("selectedQHLog2") == 64, "ledgerBinding.selectedQHLog2 must be 64")
    require_true(binding.get("numericQueryBoundInstantiated"), "ledgerBinding.numericQueryBoundInstantiated")
    require_false(binding.get("qromLossWithinBudget"), "ledgerBinding.qromLossWithinBudget")


def validate_promotion_and_blockers(schedule: dict[str, Any]) -> None:
    blockers = require_string_list(schedule.get("hardClaimBlockers"), "hardClaimBlockers")
    require(blockers == EXPECTED_BLOCKERS, "hardClaimBlockers mismatch")
    promotion = require_dict(schedule.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    require(promotion.get("requiresInteractiveProtocol") is False, "promotionRule.requiresInteractiveProtocol must be false after interactive reduction manifest closure")
    for key in [
        "requiresTransformPreconditions",
        "requiresQROMAccountingUpdate",
        "requiresTotalLossBudgetUpdate",
    ]:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")
    require(promotion.get("requiresQuantumOracleQueryBound") is False, "promotionRule.requiresQuantumOracleQueryBound must be false after Q_H bound instantiation")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            "QROM transcript schedule",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            "QROM Transcript Schedule",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "Scripts/validate-product-qrom-transcript-schedule.py",
            "Scripts/validate-product-qrom-transform-preconditions.py",
            "Scripts/validate-product-qrom-interactive-reduction.py",
            "Scripts/validate-product-qrom-sampler-encoding-evidence.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "product QROM transcript schedule",
            "product QROM transform preconditions",
            "product QROM interactive reduction",
            "product QROM sampler and encoding evidence",
        ],
        "Docs/ReleaseCandidateRunbook-2026-04-16.md": [
            "product QROM transcript schedule version and digest",
            "product QROM transform preconditions version and digest",
            "product QROM interactive reduction version and digest",
            "product QROM sampler/encoding evidence version and digest",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product QROM transcript schedule manifest",
            "Product QROM transform preconditions manifest",
            "Product QROM interactive reduction manifest",
            "Product QROM sampler/encoding evidence manifest",
        ],
        "TestVectors/README.md": [
            "product-qrom-transcript-schedule-v1.json",
            "product-qrom-transform-preconditions-v1.json",
            "product-qrom-interactive-reduction-v1.json",
            "product-qrom-sampler-encoding-evidence-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-qrom-transcript-schedule.py" in gate,
        "production gate must run QROM transcript schedule validator",
    )
    require(
        "run_step Scripts/test-product-qrom-transcript-schedule-validation.py" in gate,
        "production gate must run QROM transcript schedule regression tests",
    )


def validate_schedule(path: Path) -> None:
    schedule = read_json(path)
    text = json.dumps(schedule, sort_keys=True).lower()
    require("external" + " audit" not in text, "schedule must not encode outsourced review as a product gate")
    require(set(schedule) == EXPECTED_TOP_LEVEL_KEYS, "top-level schedule keys must match the v1 contract exactly")
    require(schedule.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(schedule.get("scheduleID") == "superneo-product-qrom-transcript-schedule-v1", "scheduleID mismatch")
    require(
        schedule.get("claimStatus") == "qrom-transcript-schedule-contract-not-production-claim",
        "claimStatus must stay non-production",
    )
    validate_related_manifests(schedule)
    validate_formal_surface(schedule)
    validate_selected_depth(schedule)
    validate_oracle_model(schedule)
    validate_transcript_state(schedule)
    validate_schedule_entries(schedule)
    validate_ledger_binding(schedule)
    validate_promotion_and_blockers(schedule)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else SCHEDULE
    if not path.is_absolute():
        path = ROOT / path
    validate_schedule(path)
    print("product QROM transcript schedule validation passed")


if __name__ == "__main__":
    main()
