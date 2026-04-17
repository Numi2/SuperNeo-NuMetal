#!/usr/bin/env python3
"""Validate product QROM interactive-reduction accounting evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
REDUCTION = ROOT / "TestVectors" / "product-qrom-interactive-reduction-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "reductionID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "researchBasis",
    "selectedTheoremFamily",
    "productProtocolModel",
    "proofKindProtocols",
    "transcriptOracleEncodingProof",
    "qromQueryAndLossInstantiation",
    "ledgerIntegration",
    "hardClaimBlockers",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "proofEnvelopePolicy": "Docs/ProofEnvelope.md",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductQROMInteractiveReduction",
    "ProductQROMInteractiveReductionAccepted",
    "productSecurityTheorem_requires_qrom_interactive_reduction",
}

EXPECTED_PROOF_KINDS = [
    ("fold", 1, 204, "n_fold"),
    ("terminal", 2, 423, "n_terminal"),
    ("compressed-terminal", 3, 423, "n_compressed_terminal"),
    ("numiseal-terminal", 4, 4_376_925, "n_numiseal_terminal"),
    ("numiseal-zk-product", 5, 4_377_150, "n_numiseal_zk_product"),
]

EXPECTED_BLOCKERS = [
    "DFM20 numeric reduction terms exceed the selected 2^-128 total-loss budget under Q_H = 2^64 and 256-bit challenge accounting",
    "uniformity proof for Ext2, Phi81 ring, ternary CE, and masked-residual field challenge samplers",
    "underlying interactive knowledge-soundness or soundness bounds for every accepted proof kind against quantum dishonest provers",
    "numeric epsilon_interactive_kind bounds for every accepted proof kind",
    "final epsilon_fs_transform boundLog2 integration into epsilon_qrom and the selected total-loss budget",
]

EXPECTED_PRODUCT_THEOREM_LIMITS = {
    "theoremID": "numiseal-product-qrom-selected-depth-1-v1",
    "maximumLaneCount": 1,
    "maximumSourceFoldOutputClaimCount": 75,
    "maximumObligationsPerAggregate": 75,
    "maximumAggregatesPerLane": 75,
    "maximumPublicInputCount": 1024,
    "maximumMatrixEvaluationCount": 1024,
    "maximumDigitTensorColumnCount": 4096,
    "maximumSumcheckVariableCount": 18,
    "scalarizationCommitmentWeightCount": 972,
    "scalarizationDecompositionCommitmentWeightCount": 972,
    "maximumMatrixEvaluationWeightCount": 55296,
    "maximumChallengesPerAggregate": 58359,
    "maximumNumiSealTerminalChallengeCount": 4_376_925,
    "maximumNumiSealZKProductChallengeCount": 4_377_150,
}


def fail(message: str) -> None:
    print(f"product QROM interactive reduction validation failed: {message}", file=sys.stderr)
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


def require_int(value: Any, label: str) -> int:
    require(type(value) is int, f"{label} must be an integer")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a non-empty list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must remain false until production QROM evidence is complete")


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(reduction: dict[str, Any]) -> None:
    related = require_dict(reduction.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the interactive-reduction evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, nested_key in [
        ("productCryptoSecurityDossier", "productQROMInteractiveReduction"),
        ("selectedDepthLossAccounting", "productQROMInteractiveReduction"),
        ("productQROMTranscriptSchedule", "productQROMInteractiveReduction"),
        ("productQROMTransformPreconditions", "productQROMInteractiveReduction"),
        ("productQROMFiatShamirAccounting", "productQROMInteractiveReduction"),
        ("productTotalLossBudget", "productQROMInteractiveReduction"),
    ]:
        manifest = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        manifest_related = require_dict(manifest.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            manifest_related.get(nested_key) == "TestVectors/product-qrom-interactive-reduction-v1.json",
            f"{manifest_key} must link product-qrom-interactive-reduction-v1.json",
        )

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    qrom_position = require_dict(dossier.get("fiatShamirQROMPosition"), "productCryptoSecurityDossier.fiatShamirQROMPosition")
    require(
        qrom_position.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "dossier Fiat-Shamir/QROM position must link the interactive reduction manifest",
    )

    accounting = read_json(ROOT / EXPECTED_MANIFESTS["productQROMFiatShamirAccounting"])
    model = require_dict(accounting.get("fiatShamirModel"), "productQROMFiatShamirAccounting.fiatShamirModel")
    require(
        model.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM accounting model must link the interactive reduction manifest",
    )


def validate_formal_surface(reduction: dict[str, Any]) -> None:
    formal = require_dict(reduction.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_research_basis(reduction: dict[str, Any]) -> None:
    rows = reduction.get("researchBasis")
    require(isinstance(rows, list) and len(rows) == 3, "researchBasis must pin three primary references")
    ids = [require_string(require_dict(row, f"researchBasis[{index}]").get("id"), f"researchBasis[{index}].id")
           for index, row in enumerate(rows)]
    require(ids == ["DFM20", "DFMS19", "Unruh17"], "researchBasis order mismatch")
    combined = json.dumps(rows, sort_keys=True).lower()
    for needle in ["2n + 1", "loss shape", "proof-of-knowledge", "post-quantum"]:
        require(needle in combined, f"researchBasis must mention {needle}")
    for row in rows:
        url = require_string(require_dict(row, "researchBasis row").get("url"), "researchBasis.url")
        require(url.startswith("https://eprint.iacr.org/"), "researchBasis URLs must use primary ePrint sources")


def validate_selected_theorem(reduction: dict[str, Any]) -> None:
    theorem = require_dict(reduction.get("selectedTheoremFamily"), "selectedTheoremFamily")
    require(theorem.get("model") == "qrom", "selectedTheoremFamily.model must be qrom")
    require("DFM20" in require_string(theorem.get("selectedFamily"), "selectedTheoremFamily.selectedFamily"), "selected theorem must be DFM20")
    require(theorem.get("moveShape") == "2n + 1", "moveShape must be 2n + 1")
    require(theorem.get("verifierChallengeCountSymbol") == "n", "verifier challenge symbol must be n")
    require(theorem.get("adversaryQuantumOracleQuerySymbol") == "Q_H", "QROM query symbol must be Q_H")
    multiplier = require_string(theorem.get("lossMultiplier"), "selectedTheoremFamily.lossMultiplier")
    for token in ["2*Q_H", "n + 1", "2*n", "n!"]:
        require(token in multiplier, f"lossMultiplier must contain {token}")
    require(theorem.get("additiveOrderingTerm") == "n! / 2^lambda_challenge", "additiveOrderingTerm mismatch")
    require(theorem.get("selectedChallengeRangeBits") == 256, "selectedChallengeRangeBits must be 256")
    require(theorem.get("selectedQHBound") == "2^64", "selectedQHBound must be 2^64")
    require(theorem.get("selectedQHLog2") == 64, "selectedQHLog2 must be 64")
    require_true(theorem.get("exactTheoremConstantPinned"), "exactTheoremConstantPinned")
    require_false(theorem.get("numericSelectedLossInstantiated"), "numericSelectedLossInstantiated")
    require_false(theorem.get("productionQROMTheoremClaimAllowed"), "productionQROMTheoremClaimAllowed")


def validate_protocol_model(reduction: dict[str, Any]) -> None:
    model = require_dict(reduction.get("productProtocolModel"), "productProtocolModel")
    require(model.get("selectedDepth") == 1, "productProtocolModel.selectedDepth must be 1")
    require(model.get("acceptedProofKinds") == [kind for kind, _, _, _ in EXPECTED_PROOF_KINDS], "acceptedProofKinds order mismatch")
    for key in ["acceptedProofKindOrderPinned", "protocolMessageAlgorithmsPinned", "exactChallengeCountFormulasPinned"]:
        require_true(model.get(key), f"productProtocolModel.{key}")
    require_true(model.get("allNumericChallengeCountsInstantiated"), "productProtocolModel.allNumericChallengeCountsInstantiated")
    limits = require_dict(model.get("selectedProductTheoremLimits"), "productProtocolModel.selectedProductTheoremLimits")
    code_surface = require_relative_path(limits.get("codeSurface"), "selectedProductTheoremLimits.codeSurface")
    source = code_surface.read_text(encoding="utf-8")
    for name, expected in EXPECTED_PRODUCT_THEOREM_LIMITS.items():
        if isinstance(expected, str):
            require(limits.get(name) == expected, f"selectedProductTheoremLimits.{name} mismatch")
        else:
            require(require_int(limits.get(name), f"selectedProductTheoremLimits.{name}") == expected, f"selectedProductTheoremLimits.{name} mismatch")
            require(str(expected) in json.dumps(limits), f"selectedProductTheoremLimits must encode {expected}")
    for symbol in [
        "NumiSealProductTheoremLimits",
        "maximumNumiSealTerminalChallengeCount",
        "maximumNumiSealZKProductChallengeCount",
        "validate(request:",
        "validate(artifact:",
    ]:
        require(symbol in source, f"theorem limit source missing {symbol}")
    require(
        limits.get("maximumChallengesPerAggregate")
        == limits.get("maximumObligationsPerAggregate")
        + limits.get("scalarizationCommitmentWeightCount")
        + limits.get("scalarizationDecompositionCommitmentWeightCount")
        + limits.get("maximumPublicInputCount")
        + limits.get("maximumMatrixEvaluationWeightCount")
        + 2
        + limits.get("maximumSumcheckVariableCount"),
        "maximumChallengesPerAggregate formula mismatch",
    )
    require(
        limits.get("maximumNumiSealTerminalChallengeCount")
        == limits.get("maximumLaneCount") * limits.get("maximumAggregatesPerLane") * limits.get("maximumChallengesPerAggregate"),
        "maximumNumiSealTerminalChallengeCount formula mismatch",
    )
    require(
        limits.get("maximumNumiSealZKProductChallengeCount")
        == limits.get("maximumNumiSealTerminalChallengeCount") + (3 * limits.get("maximumLaneCount") * limits.get("maximumAggregatesPerLane")),
        "maximumNumiSealZKProductChallengeCount formula mismatch",
    )
    enforced_by = require_string_list(limits.get("enforcedBy"), "selectedProductTheoremLimits.enforcedBy")
    require(len(enforced_by) >= 4, "selectedProductTheoremLimits.enforcedBy must include prover and verifier enforcement points")
    for key in [
        "allInteractiveSecurityBoundsInstantiated",
        "allUniformityProofsInstantiated",
        "productionProtocolClaimAllowed",
    ]:
        require_false(model.get(key), f"productProtocolModel.{key}")


def validate_proof_kind_protocols(reduction: dict[str, Any]) -> None:
    rows = reduction.get("proofKindProtocols")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_PROOF_KINDS), "proofKindProtocols length mismatch")
    for index, (expected_kind, envelope_kind, expected_n, symbol) in enumerate(EXPECTED_PROOF_KINDS):
        row = require_dict(rows[index], f"proofKindProtocols[{index}]")
        require(row.get("proofKind") == expected_kind, f"{expected_kind}.proofKind mismatch")
        require(row.get("envelopeKind") == envelope_kind, f"{expected_kind}.envelopeKind mismatch")
        sources = require_string_list(row.get("sourceReferences"), f"{expected_kind}.sourceReferences")
        require(len(sources) >= 2, f"{expected_kind}.sourceReferences must include code surfaces")
        protocol = require_string_list(row.get("interactiveProtocol"), f"{expected_kind}.interactiveProtocol")
        require(len(protocol) >= 3, f"{expected_kind}.interactiveProtocol must pin message schedule")
        challenge_formula = require_string(row.get("challengeCountFormula"), f"{expected_kind}.challengeCountFormula")
        require(symbol in challenge_formula, f"{expected_kind}.challengeCountFormula must contain {symbol}")
        move_formula = require_string(row.get("moveCountFormula"), f"{expected_kind}.moveCountFormula")
        require("2*" in move_formula and "+ 1" in move_formula, f"{expected_kind}.moveCountFormula must be odd public-coin shape")
        require(row.get("instantiatedUpperBoundN") == expected_n, f"{expected_kind}.instantiatedUpperBoundN mismatch")
        require(row.get("queryBoundQH") == "2^64", f"{expected_kind}.queryBoundQH must be 2^64")
        loss_expression = require_string(row.get("numericLossExpression"), f"{expected_kind}.numericLossExpression")
        for token in ["epsilon_fs", "2^64", "2^256", "epsilon_interactive", "epsilon_precondition"]:
            require(token in loss_expression, f"{expected_kind}.numericLossExpression must contain {token}")
        require(str(expected_n) in loss_expression, f"{expected_kind}.numericLossExpression must contain {expected_n}")
        require_false(row.get("numericLossInstantiated"), f"{expected_kind}.numericLossInstantiated")
        require_false(row.get("productionQROMClaimAllowed"), f"{expected_kind}.productionQROMClaimAllowed")
        open_inputs = require_string_list(row.get("openInputs"), f"{expected_kind}.openInputs")
        require("epsilon_interactive" in json.dumps(open_inputs), f"{expected_kind}.openInputs must mention epsilon_interactive")
        require("numeric upper bound" not in json.dumps(open_inputs).lower(), f"{expected_kind}.openInputs must not keep closed numeric-bound blocker")


def validate_encoding_and_loss(reduction: dict[str, Any]) -> None:
    encoding = require_dict(reduction.get("transcriptOracleEncodingProof"), "transcriptOracleEncodingProof")
    require("length-delimited" in require_string(encoding.get("encoding"), "transcriptOracleEncodingProof.encoding"), "encoding must be length-delimited")
    require_true(encoding.get("witnessIndependentLabelsPinned"), "witnessIndependentLabelsPinned")
    require_true(encoding.get("failurePathScheduleIndependent"), "failurePathScheduleIndependent")
    require_false(encoding.get("productionEncodingClaimAllowed"), "productionEncodingClaimAllowed")

    loss = require_dict(reduction.get("qromQueryAndLossInstantiation"), "qromQueryAndLossInstantiation")
    require(loss.get("queryBoundQH") == "2^64", "queryBoundQH mismatch")
    require(loss.get("queryBoundLog2") == 64, "queryBoundLog2 mismatch")
    require_true(loss.get("queryBoundInstantiated"), "queryBoundInstantiated")
    schedule_budget = require_dict(loss.get("scheduleDerivedQueryBudget"), "qromQueryAndLossInstantiation.scheduleDerivedQueryBudget")
    expected_budget = {kind: n for kind, _, n, _ in EXPECTED_PROOF_KINDS}
    for proof_kind, expected in expected_budget.items():
        require(schedule_budget.get(proof_kind) == expected, f"scheduleDerivedQueryBudget.{proof_kind} mismatch")
    require(schedule_budget.get("selectedDepthProtocolChallengeDerivations") == sum(expected_budget.values()), "scheduleDerivedQueryBudget.selectedDepthProtocolChallengeDerivations mismatch")
    require(
        schedule_budget.get("scheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "scheduleDerivedQueryBudget.scheduleManifest mismatch",
    )
    require(loss.get("challengeRangeBits") == 256, "challengeRangeBits mismatch")
    selected = require_string(loss.get("dfm20SelectedDepthExpression"), "dfm20SelectedDepthExpression")
    for token in ["max_kind", "2*Q_H", "n_kind!", "epsilon_interactive_kind", "epsilon_precondition_kind"]:
        require(token in selected, f"dfm20SelectedDepthExpression must contain {token}")
    require_true(loss.get("foldTerminalCompressedNumericNInstantiated"), "foldTerminalCompressedNumericNInstantiated")
    require_true(loss.get("numiSealNumericNInstantiated"), "numiSealNumericNInstantiated")
    finding = require_dict(loss.get("numericBudgetFinding"), "qromQueryAndLossInstantiation.numericBudgetFinding")
    require(finding.get("status") == "instantiated-outside-selected-budget", "numericBudgetFinding.status mismatch")
    require(finding.get("selectedSecurityBudgetBits") == 128, "numericBudgetFinding.selectedSecurityBudgetBits mismatch")
    require(finding.get("decisiveTerm") == "n_kind! / 2^256", "numericBudgetFinding.decisiveTerm mismatch")
    require(finding.get("smallestAcceptedProofKind") == "fold", "numericBudgetFinding.smallestAcceptedProofKind mismatch")
    require(finding.get("smallestAcceptedChallengeCountN") == 204, "numericBudgetFinding.smallestAcceptedChallengeCountN mismatch")
    conclusion = require_string(finding.get("smallestAcceptedOrderingTermConclusion"), "numericBudgetFinding.smallestAcceptedOrderingTermConclusion")
    require("greater than 1" in conclusion and "2^-128" in conclusion, "numericBudgetFinding must fail closed on the ordering term")
    for key in [
        "allInteractiveSecurityBoundsInstantiated",
        "allNumericLossTermsInstantiated",
        "qromLossWithinBudget",
        "productionQROMClaimAllowed",
    ]:
        require_false(loss.get(key), f"qromQueryAndLossInstantiation.{key}")


def validate_ledger_and_promotion(reduction: dict[str, Any]) -> None:
    ledger = require_dict(reduction.get("ledgerIntegration"), "ledgerIntegration")
    for key, expected in [
        ("qromAccountingManifest", "TestVectors/product-qrom-fiat-shamir-accounting-v1.json"),
        ("transformPreconditionManifest", "TestVectors/product-qrom-transform-preconditions-v1.json"),
        ("transcriptScheduleManifest", "TestVectors/product-qrom-transcript-schedule-v1.json"),
        ("totalLossBudgetManifest", "TestVectors/product-total-loss-budget-v1.json"),
    ]:
        require(ledger.get(key) == expected, f"ledgerIntegration.{key} mismatch")
    require(ledger.get("ledgerSymbol") == "epsilon_qrom", "ledgerSymbol mismatch")
    require(
        require_string_list(ledger.get("sourceSymbols"), "ledgerIntegration.sourceSymbols")
        == ["epsilon_fs_transform", "epsilon_qro_queries", "epsilon_proof_kind_malleability"],
        "ledgerIntegration.sourceSymbols mismatch",
    )
    require_false(ledger.get("qromLossWithinBudget"), "ledgerIntegration.qromLossWithinBudget")
    require_true(ledger.get("totalLossBudgetUpdated"), "ledgerIntegration.totalLossBudgetUpdated")

    blockers = require_string_list(reduction.get("hardClaimBlockers"), "hardClaimBlockers")
    require(blockers == EXPECTED_BLOCKERS, "hardClaimBlockers mismatch")
    promotion = require_dict(reduction.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    require(promotion.get("requiresNumericNumiSealChallengeBounds") is False, "promotionRule.requiresNumericNumiSealChallengeBounds must be false after code-enforced numeric bounds")
    for key in [
        "requiresChallengeUniformityProofs",
        "requiresInteractiveSecurityBounds",
        "requiresQROMLossWithinBudget",
        "requiresTotalLossBudgetUpdate",
    ]:
        require_true(promotion.get(key), f"promotionRule.{key}")


def validate_reduction(path: Path) -> None:
    reduction = read_json(path)
    require(set(reduction) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(reduction.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(reduction.get("reductionID") == "superneo-product-qrom-interactive-reduction-v1", "reductionID mismatch")
    require(
        reduction.get("claimStatus") == "qrom-interactive-reduction-ledger-not-production-claim",
        "claimStatus mismatch",
    )
    validate_related_manifests(reduction)
    validate_formal_surface(reduction)
    validate_research_basis(reduction)
    validate_selected_theorem(reduction)
    validate_protocol_model(reduction)
    validate_proof_kind_protocols(reduction)
    validate_encoding_and_loss(reduction)
    validate_ledger_and_promotion(reduction)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else REDUCTION
    if not path.is_absolute():
        path = ROOT / path
    validate_reduction(path)
    print("product QROM interactive reduction validation passed")


if __name__ == "__main__":
    main()
