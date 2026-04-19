#!/usr/bin/env python3
"""Validate product QROM CTCO interactive-reduction evidence."""

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
    "interactiveSecurityBounds",
    "transcriptOracleEncodingProof",
    "delayedMessageData",
    "uniqueResponseData",
    "compilerOverheadInstantiation",
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
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "proofEnvelopePolicy": "Docs/ProofEnvelope.md",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductQROMInteractiveReduction",
    "ProductInteractiveProtocolDefinitions",
    "ProductInteractiveSpecialSoundnessData",
    "ProductInteractiveDelayedMessageData",
    "ProductInteractiveUniqueResponseData",
    "ProductInteractiveSecurityBounds",
    "ProductPerKindInteractiveSecurityEvidence",
    "ProductChallengeTapeCommitOpenCompiler",
    "ProductQROMCompilerOverheadBound",
    "productInteractiveSecurityBounds_from_perKindEvidence",
    "productSecurityTheorem_requires_qrom_interactive_reduction",
    "productSecurityTheorem_requires_qrom_compiler_overhead_bound",
}

EXPECTED_PROOF_KINDS = [
    ("fold", 1, 204),
    ("terminal", 2, 423),
    ("compressed-terminal", 3, 423),
    ("numiseal-terminal", 4, 4_376_925),
    ("numiseal-zk-product", 5, 4_377_150),
]
EXPECTED_REPEATED_TAPE_PROFILE = {
    "proofEnvelopeHeaderVersion": 5,
    "externalChallengeSeedBits": 256,
    "piccsTapeCount": 2,
    "pirlcBranchCount": 3,
    "terminalCERoundCount": 226,
    "pirlcSelectedRoute": "generic-crt-component-three-branch",
    "pirlcUnitPivotRouteSelected": False,
    "labelVersion": "selected-repeated-tape-v1",
    "piccsTapeLabels": [
        "selected-repeated-tape-v1/piccs-tape-0",
        "selected-repeated-tape-v1/piccs-tape-1",
    ],
    "pirlcBranchLabels": [
        "selected-repeated-tape-v1/pirlc-branch-0",
        "selected-repeated-tape-v1/pirlc-branch-1",
        "selected-repeated-tape-v1/pirlc-branch-2",
    ],
}


def fail(message: str) -> None:
    print(f"product QROM CTCO interactive reduction validation failed: {message}", file=sys.stderr)
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
    for key, expected in EXPECTED_REPEATED_TAPE_PROFILE.items():
        require(profile.get(key) == expected, f"{label}.{key} mismatch")
    expansion = require_string(profile.get("challengeExpansionMode"), f"{label}.challengeExpansionMode")
    require("H_chal" in expansion and "seed-bit slicing" in expansion and "not" in expansion.lower(), f"{label}.challengeExpansionMode must reject seed-bit slicing")
    source = (ROOT / "SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift").read_text(encoding="utf-8")
    for needle in [
        "public static let selectedPiCCSTapeCount = 2",
        "public static let selectedPiRLCBranchCount = 3",
        "repeatedTapeSeed(",
        "validatePiCCSTape(",
        "validatePiRLCBranch(",
    ]:
        require(needle in source, f"Swift repeated-tape implementation missing {needle}")


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


def validate_formal_surface(reduction: dict[str, Any]) -> None:
    formal = require_dict(reduction.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(EXPECTED_FORMAL_DECLARATIONS.issubset(declarations), "formalSurface.declarations missing CTCO declarations")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_research_basis(reduction: dict[str, Any]) -> None:
    rows = reduction.get("researchBasis")
    require(isinstance(rows, list) and len(rows) >= 3, "researchBasis must pin CTCO, fallback, and legacy references")
    ids = [require_string(require_dict(row, f"researchBasis[{index}]").get("id"), f"researchBasis[{index}].id") for index, row in enumerate(rows)]
    for expected in ["DFMS22", "RotemTessaro", "DFM20-legacy"]:
        require(expected in ids, f"researchBasis missing {expected}")
    joined = json.dumps(rows, sort_keys=True).lower()
    for needle in ["commit-and-open", "straight-line", "legacy", "dfm20"]:
        require(needle in joined, f"researchBasis must mention {needle}")


def validate_selected_theorem(reduction: dict[str, Any]) -> None:
    theorem = require_dict(reduction.get("selectedTheoremFamily"), "selectedTheoremFamily")
    require(theorem.get("model") == "ideal-split-qro", "selected theorem model must be ideal-split-qro")
    require(theorem.get("selectedFamily") == "challenge-tape-commit-open", "selected family must be CTCO")
    require(theorem.get("compilerFamily") == "ctco", "compiler family must be ctco")
    require(theorem.get("fallbackFamily") == "merkle-straightline", "fallback family mismatch")
    require(theorem.get("moveShape") == "3", "move shape must be 3")
    require(theorem.get("selectedChallengeSeedBits") == 256, "challenge seed bits must be 256")
    require(theorem.get("selectedBindingBits") == 384, "binding bits must be 384")
    require(theorem.get("selectedMerkleNodeBits") == 384, "Merkle node bits must be 384")
    require(theorem.get("selectedQHBound") == "2^64", "selectedQHBound must be 2^64")
    require(theorem.get("selectedQHLog2") == 64, "selectedQHLog2 must be 64")
    require_true(theorem.get("legacyDFM20InterfaceDeprecated"), "selectedTheoremFamily.legacyDFM20InterfaceDeprecated")
    require_true(theorem.get("numericSelectedLossInstantiated"), "selectedTheoremFamily.numericSelectedLossInstantiated")
    require_true(theorem.get("productionQROMTheoremClaimAllowed"), "selectedTheoremFamily.productionQROMTheoremClaimAllowed")


def validate_protocol_model(reduction: dict[str, Any]) -> None:
    model = require_dict(reduction.get("productProtocolModel"), "productProtocolModel")
    require(model.get("selectedDepth") == 1, "selectedDepth must be 1")
    require(model.get("acceptedProofKinds") == [kind for kind, _, _ in EXPECTED_PROOF_KINDS], "acceptedProofKinds order mismatch")
    for key in [
        "acceptedProofKindOrderPinned",
        "protocolMessageAlgorithmsPinned",
        "ctcoProtocolDefinitionsPinned",
        "allKindsThreeMovePublicCoin",
        "oneSeedChallengePerKind",
        "ctcoRootCommitmentsImplemented",
    ]:
        require_true(model.get(key), f"productProtocolModel.{key}")
    validate_repeated_tape_profile(
        model.get("runtimeSelectedRepeatedTapeProfile"),
        "productProtocolModel.runtimeSelectedRepeatedTapeProfile",
    )
    limits = require_dict(model.get("selectedProductTheoremLimits"), "selectedProductTheoremLimits")
    require_relative_path(limits.get("codeSurface"), "selectedProductTheoremLimits.codeSurface")
    require(limits.get("maximumNumiSealTerminalChallengeCount") == 4_376_925, "legacy terminal challenge metric mismatch")
    require(limits.get("maximumNumiSealZKProductChallengeCount") == 4_377_150, "legacy ZK challenge metric mismatch")
    require_true(model.get("allInteractiveSecurityBoundsInstantiated"), "productProtocolModel.allInteractiveSecurityBoundsInstantiated")
    require_true(model.get("allUniformityProofsInstantiated"), "productProtocolModel.allUniformityProofsInstantiated")
    require_true(model.get("productionProtocolClaimAllowed"), "productProtocolModel.productionProtocolClaimAllowed")


def validate_proof_kind_protocols(reduction: dict[str, Any]) -> None:
    rows = reduction.get("proofKindProtocols")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_PROOF_KINDS), "proofKindProtocols length mismatch")
    for index, (expected_kind, envelope_kind, legacy_count) in enumerate(EXPECTED_PROOF_KINDS):
        row = require_dict(rows[index], f"proofKindProtocols[{index}]")
        require(row.get("proofKind") == expected_kind, f"{expected_kind}.proofKind mismatch")
        require(row.get("envelopeKind") == envelope_kind, f"{expected_kind}.envelopeKind mismatch")
        require(row.get("ctcoChallengeCount") == 1, f"{expected_kind}.ctcoChallengeCount must be 1")
        require(row.get("legacyScheduleChallengeDerivations") == legacy_count, f"{expected_kind}.legacy schedule metric mismatch")
        require(row.get("challengeCountFormula") == f"n_{expected_kind.replace('-', '_')}_ctco = 1", f"{expected_kind}.challengeCountFormula mismatch")
        require(row.get("moveCountFormula") == f"moves_{expected_kind.replace('-', '_')}_ctco = 3", f"{expected_kind}.moveCountFormula mismatch")
        protocol = " ".join(require_string_list(row.get("ctcoInteractiveProtocol"), f"{expected_kind}.ctcoInteractiveProtocol")).lower()
        require("p1" in protocol and "rho" in protocol and "p2" in protocol, f"{expected_kind} must have P1/rho/P2 CTCO schedule")
        require_string(row.get("extractorTarget"), f"{expected_kind}.extractorTarget")
        require("independent of legacy" in require_string(row.get("numericLossExpression"), f"{expected_kind}.numericLossExpression"), f"{expected_kind}.numericLossExpression must reject legacy n dependence")
        require_true(row.get("numericLossInstantiated"), f"{expected_kind}.numericLossInstantiated")
        if expected_kind == "fold":
            validate_repeated_tape_profile(
                row.get("runtimeSelectedRepeatedTapeProfile"),
                f"{expected_kind}.runtimeSelectedRepeatedTapeProfile",
            )
            fixed_kind = require_string(row.get("fixedKindFiniteLossExpression"), f"{expected_kind}.fixedKindFiniteLossExpression")
            for needle in ["16/q^4", "1/5^81", "two PiCCS", "three PiRLC"]:
                require(needle in fixed_kind, f"{expected_kind}.fixedKindFiniteLossExpression must mention {needle}")
        else:
            inherited = require_string(row.get("sourceFoldRepeatedTapeProfile"), f"{expected_kind}.sourceFoldRepeatedTapeProfile")
            require("selected-repeated-tape-v1" in inherited and "2 PiCCS" in inherited and "3 PiRLC" in inherited, f"{expected_kind} must inherit the selected source-fold repeated profile")
        bound = require_dict(row.get("interactiveSecurityBound"), f"{expected_kind}.interactiveSecurityBound")
        require("instantiated" in require_string(bound.get("status"), f"{expected_kind}.interactiveSecurityBound.status"), f"{expected_kind}.interactiveSecurityBound.status must be instantiated")
        require("charged outside epsilon_qrom" in require_string(bound.get("qromAccountingRule"), f"{expected_kind}.interactiveSecurityBound.qromAccountingRule"), f"{expected_kind}.interactiveSecurityBound must export loss outside epsilon_qrom")
        require_string_list(bound.get("formalEvidence"), f"{expected_kind}.interactiveSecurityBound.formalEvidence")
        require_string_list(bound.get("lossExport"), f"{expected_kind}.interactiveSecurityBound.lossExport")
        open_inputs = row.get("openInputs")
        require(isinstance(open_inputs, list), f"{expected_kind}.openInputs must be a list")
        require(open_inputs == [], f"{expected_kind}.openInputs must be closed")
        require_true(row.get("productionQROMClaimAllowed"), f"{expected_kind}.productionQROMClaimAllowed")


def validate_interactive_security_bounds(reduction: dict[str, Any]) -> None:
    bounds = require_dict(reduction.get("interactiveSecurityBounds"), "interactiveSecurityBounds")
    require(
        bounds.get("status") == "instantiated-for-selected-depth-finite-formal-model",
        "interactiveSecurityBounds.status mismatch",
    )
    formal = require_dict(bounds.get("formalEvidence"), "interactiveSecurityBounds.formalEvidence")
    require(formal.get("formalStatusManifest") == "Docs/FormalStatus.json", "interactiveSecurityBounds formal status manifest mismatch")
    formal_status = read_json(ROOT / "Docs" / "FormalStatus.json")
    require(
        formal_status.get("current_label") == "completed formal protocol theorem",
        "interactiveSecurityBounds requires completed formal protocol theorem",
    )
    require(
        formal.get("leanBridge") == "productInteractiveSecurityBounds_from_perKindEvidence",
        "interactiveSecurityBounds leanBridge mismatch",
    )
    require(
        formal.get("perKindEvidenceStructure") == "ProductPerKindInteractiveSecurityEvidence",
        "interactiveSecurityBounds evidence structure mismatch",
    )
    rule = require_string(bounds.get("accountingRule"), "interactiveSecurityBounds.accountingRule")
    for needle in [
        "epsilon_fold",
        "epsilon_terminal",
        "epsilon_replay",
        "epsilon_collision",
        "proof-level simulator coupling",
        "epsilon_zk_sim = 0",
        "epsilon_qrom",
    ]:
        require(needle in rule, f"interactiveSecurityBounds accountingRule must mention {needle}")
    require_true(bounds.get("allAcceptedProofKindsCovered"), "interactiveSecurityBounds.allAcceptedProofKindsCovered")
    require_true(bounds.get("allInteractiveSecurityBoundsInstantiated"), "interactiveSecurityBounds.allInteractiveSecurityBoundsInstantiated")
    require_false(bounds.get("numericTotalLossInstantiated"), "interactiveSecurityBounds.numericTotalLossInstantiated")
    require_true(bounds.get("productionQROMClaimAllowed"), "interactiveSecurityBounds.productionQROMClaimAllowed")


def validate_encoding_delayed_unique_and_loss(reduction: dict[str, Any]) -> None:
    encoding = require_dict(reduction.get("transcriptOracleEncodingProof"), "transcriptOracleEncodingProof")
    require("length-delimited" in require_string(encoding.get("encoding"), "encoding"), "encoding must be length-delimited")
    require("CtxBind" in require_string(encoding.get("domainSeparation"), "domainSeparation"), "domain separation must mention CtxBind")
    require(encoding.get("structuralCollisionMalleabilityStatus") == "structural-exclusion-pinned-binding-bound-instantiated-for-H_bind", "structural status mismatch")
    require_true(encoding.get("witnessIndependentLabelsPinned"), "witnessIndependentLabelsPinned")
    require_true(encoding.get("failurePathScheduleIndependent"), "failurePathScheduleIndependent")
    require_true(encoding.get("productionEncodingClaimAllowed"), "productionEncodingClaimAllowed")

    delayed = require_dict(reduction.get("delayedMessageData"), "delayedMessageData")
    require(delayed.get("status") == "pinned-for-ctco-extraction", "delayedMessageData.status mismatch")
    require_true(delayed.get("allBinderTargetsCovered"), "delayedMessageData.allBinderTargetsCovered")
    require(
        require_string_list(delayed.get("binderTargets"), "delayedMessageData.binderTargets")
        == ["artifact", "provenance", "replay", "component-root", "randomness-session", "leakage", "typed-carry"],
        "delayedMessageData.binderTargets mismatch",
    )
    acceptance = require_string(delayed.get("acceptanceRule"), "delayedMessageData.acceptanceRule")
    for needle in ["Move 1", "H_bind", "Root_k", "Move 3"]:
        require(needle in acceptance, f"delayedMessageData.acceptanceRule must mention {needle}")
    ambiguity = " ".join(require_string_list(delayed.get("ambiguityChargedTo"), "delayedMessageData.ambiguityChargedTo"))
    for needle in ["Root_k", "H_bind", "canonical decompression"]:
        require(needle in ambiguity, f"delayedMessageData.ambiguityChargedTo must mention {needle}")
    require_true(delayed.get("productionQROMClaimAllowed"), "delayedMessageData.productionQROMClaimAllowed")

    unique = require_dict(reduction.get("uniqueResponseData"), "uniqueResponseData")
    require(unique.get("status") == "pinned-for-ctco-extraction", "uniqueResponseData.status mismatch")
    require_true(unique.get("allAcceptedProofKindsCovered"), "uniqueResponseData.allAcceptedProofKindsCovered")
    response_rule = require_string(unique.get("responseRule"), "uniqueResponseData.responseRule")
    for needle in ["Root_k", "rho_k", "deterministic"]:
        require(needle in response_rule, f"uniqueResponseData.responseRule must mention {needle}")
    unique_rows = unique.get("proofKinds")
    require(isinstance(unique_rows, list) and len(unique_rows) == len(EXPECTED_PROOF_KINDS), "uniqueResponseData.proofKinds length mismatch")
    for index, (expected_kind, _, _) in enumerate(EXPECTED_PROOF_KINDS):
        row = require_dict(unique_rows[index], f"uniqueResponseData.proofKinds[{index}]")
        require(row.get("proofKind") == expected_kind, f"{expected_kind}.uniqueResponseData proofKind mismatch")
        require_string(row.get("responseUniqueness"), f"{expected_kind}.responseUniqueness")
    require_true(unique.get("productionQROMClaimAllowed"), "uniqueResponseData.productionQROMClaimAllowed")

    compiler = require_dict(reduction.get("compilerOverheadInstantiation"), "compilerOverheadInstantiation")
    require(compiler.get("status") == "ideal-split-qro-ctco-overhead-instantiated", "compilerOverheadInstantiation.status mismatch")
    require(compiler.get("compilerOverheadSymbol") == "epsilon_compiler_overhead", "compilerOverheadInstantiation symbol mismatch")
    require(compiler.get("exactExpression") == "epsilon_compiler_overhead = 0", "compilerOverheadInstantiation exact expression mismatch")
    require("ideal split-QRO" in require_string(compiler.get("modelScope"), "compilerOverheadInstantiation.modelScope"), "compiler model scope mismatch")
    require("charged outside" in require_string(compiler.get("lossSeparation"), "compilerOverheadInstantiation.lossSeparation"), "compiler loss separation mismatch")
    require_true(compiler.get("productionQROMClaimAllowed"), "compilerOverheadInstantiation.productionQROMClaimAllowed")

    loss = require_dict(reduction.get("qromQueryAndLossInstantiation"), "qromQueryAndLossInstantiation")
    require(loss.get("queryBoundQH") == "2^64", "queryBoundQH mismatch")
    require(loss.get("queryBoundLog2") == 64, "queryBoundLog2 mismatch")
    require_true(loss.get("queryBoundInstantiated"), "queryBoundInstantiated")
    legacy_budget = require_dict(loss.get("legacyScheduleDerivedQueryBudget"), "legacyScheduleDerivedQueryBudget")
    require(legacy_budget.get("selectedDepthProtocolChallengeDerivations") == 8_755_125, "legacy selected challenge derivations mismatch")
    ctco_counts = require_dict(loss.get("ctcoChallengeCountByKind"), "ctcoChallengeCountByKind")
    for proof_kind, _, _ in EXPECTED_PROOF_KINDS:
        require(ctco_counts.get(proof_kind) == 1, f"{proof_kind}.ctco count must be 1")
    require(loss.get("challengeSeedBits") == 256, "challengeSeedBits must be 256")
    require(loss.get("bindingDigestBits") == 384, "bindingDigestBits must be 384")
    internal = require_dict(loss.get("internalRepeatedTapeCounts"), "internalRepeatedTapeCounts")
    require(internal.get("piccsTapeCount") == 2, "internalRepeatedTapeCounts.piccsTapeCount mismatch")
    require(internal.get("pirlcBranchCount") == 3, "internalRepeatedTapeCounts.pirlcBranchCount mismatch")
    require(internal.get("terminalCERoundCount") == 226, "internalRepeatedTapeCounts.terminalCERoundCount mismatch")
    require(internal.get("externalCTCOSeedCountRemainsOne") is True, "internalRepeatedTapeCounts.externalCTCOSeedCountRemainsOne must be true")
    require("epsilon_compiler_overhead" in require_string(loss.get("ctcoSelectedDepthExpression"), "ctcoSelectedDepthExpression"), "CTCO loss expression mismatch")
    finding = require_dict(loss.get("legacyNumericBudgetFinding"), "legacyNumericBudgetFinding")
    require(finding.get("smallestAcceptedChallengeCountN") == 204, "legacy finding smallest n mismatch")
    require("deprecated" in require_string(finding.get("smallestAcceptedOrderingTermConclusion"), "legacy conclusion"), "legacy conclusion must deprecate DFM20")
    require_true(loss.get("allInteractiveSecurityBoundsInstantiated"), "qromQueryAndLossInstantiation.allInteractiveSecurityBoundsInstantiated")
    require_true(loss.get("allNumericLossTermsInstantiated"), "qromQueryAndLossInstantiation.allNumericLossTermsInstantiated")
    require_true(loss.get("qromLossWithinBudget"), "qromQueryAndLossInstantiation.qromLossWithinBudget")
    require_true(loss.get("productionQROMClaimAllowed"), "qromQueryAndLossInstantiation.productionQROMClaimAllowed")


def validate_ledger_and_promotion(reduction: dict[str, Any]) -> None:
    ledger = require_dict(reduction.get("ledgerIntegration"), "ledgerIntegration")
    require(ledger.get("ledgerSymbol") == "epsilon_qrom", "ledger symbol mismatch")
    require(require_string_list(ledger.get("sourceSymbols"), "ledgerIntegration.sourceSymbols") == ["epsilon_compiler_overhead", "epsilon_hash_model_gap"], "ledger source symbols mismatch")
    require_true(ledger.get("qromLossWithinBudget"), "ledgerIntegration.qromLossWithinBudget")
    require_true(ledger.get("totalLossBudgetUpdated"), "ledgerIntegration.totalLossBudgetUpdated")
    blockers = reduction.get("hardClaimBlockers")
    require(isinstance(blockers, list), "hardClaimBlockers must be a list")
    require(blockers == [], "hardClaimBlockers must be empty after repository-local QROM promotion")
    blocker_text = " ".join(str(blocker) for blocker in blockers).lower()
    require("zk simulator" not in blocker_text, "ZK simulator composition must not remain a QROM interactive-reduction blocker")
    require("special-soundness" not in blocker_text, "interactive special-soundness must not remain a hard blocker")
    promotion = require_dict(reduction.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_true(promotion.get(key), f"promotionRule.{key}")
    require_false(promotion.get("requiresCTCORootCommitments"), "promotionRule.requiresCTCORootCommitments")
    require_false(promotion.get("requiresInteractiveSecurityBounds"), "promotionRule.requiresInteractiveSecurityBounds")
    for key in [
        "requiresHBind384SourceImplementation",
        "requiresDelayedMessageData",
        "requiresUniqueResponseData",
        "requiresQROMLossWithinBudget",
        "requiresTotalLossBudgetUpdate",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")


def validate_reduction(path: Path) -> None:
    reduction = read_json(path)
    text = json.dumps(reduction, sort_keys=True).lower()
    require("external" + " audit" not in text, "reduction must not encode outsourced review as a product gate")
    require(set(reduction) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(reduction.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(reduction.get("reductionID") == "superneo-product-qrom-interactive-reduction-v1", "reductionID mismatch")
    require(reduction.get("claimStatus") == "qrom-ctco-interactive-reduction-contract-repository-local-production-claim", "claimStatus mismatch")
    validate_related_manifests(reduction)
    validate_formal_surface(reduction)
    validate_research_basis(reduction)
    validate_selected_theorem(reduction)
    validate_protocol_model(reduction)
    validate_proof_kind_protocols(reduction)
    validate_interactive_security_bounds(reduction)
    validate_encoding_delayed_unique_and_loss(reduction)
    validate_ledger_and_promotion(reduction)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else REDUCTION
    if not path.is_absolute():
        path = ROOT / path
    validate_reduction(path)
    print("product QROM CTCO interactive reduction validation passed")


if __name__ == "__main__":
    main()
