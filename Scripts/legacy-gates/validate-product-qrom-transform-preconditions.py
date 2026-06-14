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
    "productQROMPublicCoinAccounting": "TestVectors/product-qrom-public-coin-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "numiSealZKSimulatorCouplingEvidence": "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "proofEnvelopePolicy": "Docs/ProofEnvelope.md",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductPublicCoinTransformPreconditions",
    "ProductQROMTransformFamily",
    "ProductCompilerFamily",
    "ProductChallengeTapeCommitOpenCompiler",
    "ProductChallengeTapeExpansion",
    "ProductChallengeTapeExpansionAccepted",
    "ProductInteractiveProtocolDefinitions",
    "ProductInteractiveSpecialSoundnessData",
    "ProductInteractiveDelayedMessageData",
    "ProductInteractiveUniqueResponseData",
    "ProductInteractiveSecurityBounds",
    "ProductPerKindInteractiveSecurityEvidence",
    "ProductQROMCompilerOverheadBound",
    "ProductQROMCompilerOverheadBoundAccepted",
    "productInteractiveSecurityBounds_from_perKindEvidence",
    "productSecurityTheorem_requires_challenge_tape_expansion",
    "productSecurityTheorem_requires_qrom_compiler_overhead_bound",
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
EXPECTED_REPEATED_TAPE_LABELS = [
    "selected-repeated-tape-v1/piccs-tape-0",
    "selected-repeated-tape-v1/piccs-tape-1",
    "selected-repeated-tape-v1/pirlc-branch-0",
    "selected-repeated-tape-v1/pirlc-branch-1",
    "selected-repeated-tape-v1/pirlc-branch-2",
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


def validate_repeated_tape_profile(value: Any, label: str) -> None:
    profile = require_dict(value, label)
    require(profile.get("proofEnvelopeHeaderVersion") == 5, f"{label}.proofEnvelopeHeaderVersion mismatch")
    require(profile.get("externalChallengeSeedBits") == 256, f"{label}.externalChallengeSeedBits mismatch")
    require(profile.get("piccsTapeCount") == 2, f"{label}.piccsTapeCount mismatch")
    require(profile.get("pirlcBranchCount") == 3, f"{label}.pirlcBranchCount mismatch")
    require(profile.get("terminalCERoundCount") == 226, f"{label}.terminalCERoundCount mismatch")
    require(profile.get("pirlcSelectedRoute") == "generic-crt-component-three-branch", f"{label}.pirlcSelectedRoute mismatch")
    require(profile.get("pirlcUnitPivotRouteSelected") is False, f"{label}.pirlcUnitPivotRouteSelected must be false")
    require(profile.get("labelVersion") == "selected-repeated-tape-v1", f"{label}.labelVersion mismatch")
    require(profile.get("labels") == EXPECTED_REPEATED_TAPE_LABELS, f"{label}.labels mismatch")
    expansion = require_string(profile.get("challengeExpansionMode"), f"{label}.challengeExpansionMode")
    require("H_chal" in expansion and "not seed-bit slicing" in expansion, f"{label}.challengeExpansionMode mismatch")


def validate_related_manifests(preconditions: dict[str, Any]) -> None:
    related = require_dict(preconditions.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the transform-precondition evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, nested_key in [
        ("productQROMPublicCoinAccounting", "productQROMTransformPreconditions"),
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
    validate_repeated_tape_profile(profile.get("selectedRepeatedTapeProfile"), "selectedTransformProfile.selectedRepeatedTapeProfile")
    loss_shape = require_string(profile.get("selectedLossShape"), "selectedLossShape")
    require("epsilon_compiler_overhead" in loss_shape and "factorial" in loss_shape, "selectedLossShape must pin new loss and reject factorial term")
    require_true(profile.get("interactiveLossChargedOutsideQROM"), "interactiveLossChargedOutsideQROM")
    require_true(profile.get("legacyDFM20InterfaceDeprecated"), "legacyDFM20InterfaceDeprecated")
    require_true(profile.get("productionTransformClaimAllowed"), "productionTransformClaimAllowed")


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
    require({
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
    }.issubset(satisfied), "closed CTCO/QROM preconditions mismatch")
    require(
        unsatisfied == set(),
        "open CTCO implementation/security preconditions mismatch",
    )


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
        if expected_kind == "fold":
            validate_repeated_tape_profile(row.get("selectedRepeatedTapeProfile"), f"{expected_kind}.selectedRepeatedTapeProfile")
        else:
            inherited = require_string(row.get("sourceFoldRepeatedTapeProfile"), f"{expected_kind}.sourceFoldRepeatedTapeProfile")
            require("selected-repeated-tape-v1" in inherited and "2 PiCCS" in inherited and "3 PiRLC" in inherited, f"{expected_kind} must inherit source-fold repeated profile")
        require(row.get("legacyMaximumProtocolChallengeDerivations") == legacy_count, f"{expected_kind}.legacyMaximumProtocolChallengeDerivations mismatch")
        require(row.get("queryBoundQH") == "2^64", f"{expected_kind}.queryBoundQH mismatch")
        require(row.get("queryBoundLog2") == 64, f"{expected_kind}.queryBoundLog2 mismatch")
        require_true(row.get("interactiveSecurityBoundInstantiated"), f"{expected_kind}.interactiveSecurityBoundInstantiated")
        require_true(row.get("transformPreconditionsSatisfied"), f"{expected_kind}.transformPreconditionsSatisfied")
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
    require(
        interface.get("compilerOverheadExpression") == "epsilon_compiler_overhead = 0 in the ideal split-QRO CTCO theorem model",
        "lossInterface.compilerOverheadExpression mismatch",
    )
    require("ideal split-QRO" in require_string(interface.get("hashModelGapExpression"), "lossInterface.hashModelGapExpression"), "hash model gap expression mismatch")
    require_true(interface.get("numericLossInstantiated"), "lossInterface.numericLossInstantiated")
    require_true(interface.get("qromLossWithinBudget"), "lossInterface.qromLossWithinBudget")


def validate_promotion_and_blockers(preconditions: dict[str, Any]) -> None:
    blockers = preconditions.get("hardClaimBlockers")
    require(isinstance(blockers, list), "hardClaimBlockers must be a list")
    blocker_text = " ".join(str(blocker) for blocker in blockers).lower()
    require("shake256-to-split-qro" in blocker_text, "hardClaimBlockers must keep concrete SHAKE256 promotion open")
    require("zero-knowledge" not in blocker_text, "zero-knowledge simulator composition must not remain a transform blocker")
    require("special-soundness" not in blocker_text, "interactive special-soundness must not remain a transform blocker")
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
        "requiresHBind384Implementation",
        "requiresDelayedMessageData",
        "requiresUniqueResponseData",
        "requiresQROMLossInstantiation",
        "requiresTotalLossBudgetUpdate",
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
    require(preconditions.get("claimStatus") == "qrom-ctco-transform-precondition-contract-repository-local-production-claim", "claimStatus mismatch")
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
