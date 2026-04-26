#!/usr/bin/env python3
"""Validate the product QROM CTCO/split-oracle accounting contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
ACCOUNTING = ROOT / "TestVectors" / "product-qrom-public-coin-accounting-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "accountingID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "selectedDepth",
    "hashModel",
    "publicCoinQROModel",
    "transcriptInterfaces",
    "lossRule",
    "collisionAccounting",
    "ledgerTermMapping",
    "legacyDFM20Status",
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
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productSharedBadEventDedup": "TestVectors/product-shared-bad-event-dedup-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
}

EXPECTED_PROOF_KINDS = [
    ("fold", 1),
    ("terminal", 2),
    ("compressed-terminal", 3),
    ("numiseal-terminal", 4),
    ("numiseal-zk-product", 5),
]

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductPublicCoinLossAccounting",
    "ProductHashOracleInstantiation",
    "ProductQROMCollisionBound",
    "ProductQROMMalleabilityBound",
    "ProductInteractiveSecurityBounds",
    "ProductQROMTotalLossInstantiated",
    "ProductSharedBadEventDeduplication",
    "ProductQROMTightTransform",
    "productSecurityTheorem_from_instantiated_qrom",
    "productSecurityTheorem_requires_shared_bad_event_deduplication",
    "productSecurityTheorem_requires_qrom_loss_accounting",
}

EXPECTED_COLLISION_TARGETS = [
    "fold-context-binding",
    "terminal-context-binding",
    "compressed-terminal-context-binding",
    "numiseal-terminal-context-binding",
    "numiseal-zk-product-context-binding",
    "source-fold-envelope-binding",
    "product-proof-envelope-binding",
    "recursive-carry-replay-binding",
    "typed-carry-statement-binding",
    "component-root-binding",
    "qrom-evidence-binding",
]


def fail(message: str) -> None:
    print(f"product QROM CTCO accounting validation failed: {message}", file=sys.stderr)
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


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false")


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def validate_related_manifests(accounting: dict[str, Any]) -> None:
    related = require_dict(accounting.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the QROM evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, nested_key in [
        ("productCryptoSecurityDossier", "productQROMPublicCoinAccounting"),
        ("selectedDepthLossAccounting", "productQROMPublicCoinAccounting"),
        ("productQROMTranscriptSchedule", "productQROMPublicCoinAccounting"),
        ("productQROMTransformPreconditions", "productQROMPublicCoinAccounting"),
        ("productQROMInteractiveReduction", "productQROMPublicCoinAccounting"),
    ]:
        manifest = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        manifest_related = require_dict(manifest.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            manifest_related.get(nested_key) == "TestVectors/product-qrom-public-coin-accounting-v1.json",
            f"{manifest_key} must link product-qrom-public-coin-accounting-v1.json",
        )


def validate_formal_surface(accounting: dict[str, Any]) -> None:
    formal = require_dict(accounting.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(EXPECTED_FORMAL_DECLARATIONS.issubset(declarations), "formalSurface.declarations missing CTCO theorem declarations")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_selected_depth(accounting: dict[str, Any]) -> None:
    depth = require_dict(accounting.get("selectedDepth"), "selectedDepth")
    require(depth.get("depthModel") == "bounded-depth", "selectedDepth.depthModel must be bounded-depth")
    require(depth.get("selectedMaximumDepth") == 3, "selectedDepth.selectedMaximumDepth must be 3")
    require(depth.get("acceptedProductLayers") == 3, "selectedDepth.acceptedProductLayers must be 3")
    require(depth.get("selectedRecursiveCarryHops") == 2, "selectedDepth.selectedRecursiveCarryHops must be 2")
    require_true(depth.get("qromPromotionAllowed"), "selectedDepth.qromPromotionAllowed")


def validate_hash_model(accounting: dict[str, Any]) -> None:
    model = require_dict(accounting.get("hashModel"), "hashModel")
    require(model.get("model") == "ideal-split-qro", "hashModel.model must be ideal-split-qro")
    require(model.get("concreteHashRecommendation") == "SHAKE256-domain-separated", "concrete hash recommendation mismatch")
    challenge = require_dict(model.get("challengeOracle"), "hashModel.challengeOracle")
    binding = require_dict(model.get("bindingOracle"), "hashModel.bindingOracle")
    merkle = require_dict(model.get("merkleOracle"), "hashModel.merkleOracle")
    require(challenge.get("outputBits") == 256, "H_chal outputBits must be 256")
    require(binding.get("outputBits") == 384, "H_bind outputBits must be 384")
    require(binding.get("bindingTargetEventCount") == 11, "binding target event count must be 11")
    require(merkle.get("outputBits") == 384, "H_mt outputBits must be 384")
    for key in [
        "splitOraclesPinned",
        "theoremCriticalBindingsUseHBind",
        "framedEncodingInjective",
        "proofKindBytesInjective",
        "sourceSHAKE256PrimitiveAvailable",
        "sourceDigest384TypeAvailable",
        "sourceCTCOBinderHelpersAvailable",
        "hashQROInstantiationAssumptionPinned",
    ]:
        require_true(model.get(key), f"hashModel.{key}")
    require_true(model.get("sourceAcceptancePathsUseHBind"), "hashModel.sourceAcceptancePathsUseHBind")
    require_true(model.get("idealSplitQROTheoremInstantiated"), "hashModel.idealSplitQROTheoremInstantiated")
    require_false(
        model.get("genericOfflineTransformAcceptedForProduction"),
        "hashModel.genericOfflineTransformAcceptedForProduction",
    )
    require_false(
        model.get("concreteSHAKE256QROInstantiationProofProvided"),
        "hashModel.concreteSHAKE256QROInstantiationProofProvided",
    )
    require_false(model.get("hashQROInstantiationProofProvided"), "hashModel.hashQROInstantiationProofProvided")
    source = (ROOT / "SuperNeo-NuMetal" / "SuperNeoHashOracles.swift").read_text(encoding="utf-8")
    for needle in ["SuperNeoSHAKE256", "Digest384", "SuperNeoSplitQRO", "CTCOMoveOneCommitment"]:
        require(needle in source, f"SuperNeoHashOracles.swift missing {needle}")


def validate_public_coin_model(accounting: dict[str, Any]) -> None:
    model = require_dict(accounting.get("publicCoinQROModel"), "publicCoinQROModel")
    require(model.get("model") == "ideal-split-qro", "publicCoinQROModel.model must be ideal-split-qro")
    require(model.get("transformFamily") == "ctco", "transformFamily must be ctco")
    require(model.get("fallbackTransformFamily") == "merkle-straightline", "fallback transform mismatch")
    for key in [
        "transcriptScheduleManifest",
        "transformPreconditionManifest",
        "interactiveReductionManifest",
        "samplerEncodingEvidenceManifest",
        "collisionMalleabilityEvidenceManifest",
    ]:
        require_relative_path(model.get(key), f"publicCoinQROModel.{key}")
    for key in [
        "interactiveProtocolSpecified",
        "publicCoinChallengeScheduleSpecified",
        "transformPreconditionsSatisfied",
        "quantumOracleQueryBoundAccounted",
        "transcriptDomainSeparatorsBound",
        "proofKindSeparationBound",
        "structuralTranscriptCollisionMalleabilityExcluded",
        "transcriptCollisionMalleabilityExcluded",
        "interactiveLossChargedOutsideQROM",
        "interactiveSecurityBoundsInstantiated",
        "legacyDFM20InterfaceDeprecated",
        "sourceImplementationComplete",
    ]:
        require_true(model.get(key), f"publicCoinQROModel.{key}")
    require_true(model.get("repositoryLocalIdealQROMClaimAllowed"), "publicCoinQROModel.repositoryLocalIdealQROMClaimAllowed")
    require_false(model.get("productionQROMClaimAllowed"), "publicCoinQROModel.productionQROMClaimAllowed")


def validate_transcript_interfaces(accounting: dict[str, Any]) -> None:
    rows = accounting.get("transcriptInterfaces")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_PROOF_KINDS), "transcriptInterfaces length mismatch")
    seen: list[tuple[str, int]] = []
    joined_rows = []
    for index, item in enumerate(rows):
        row = require_dict(item, f"transcriptInterfaces[{index}]")
        proof_kind = require_string(row.get("proofKind"), f"transcriptInterfaces[{index}].proofKind")
        envelope_kind = row.get("envelopeKind")
        require(isinstance(envelope_kind, int), f"{proof_kind}.envelopeKind must be an integer")
        seen.append((proof_kind, envelope_kind))
        require(row.get("ctcoChallengeCount") == 1, f"{proof_kind}.ctcoChallengeCount must be 1")
        require("H_bind" in require_string(row.get("domainBinding"), f"{proof_kind}.domainBinding"), f"{proof_kind} must bind through H_bind")
        require("Root_" in require_string(row.get("rootCommitment"), f"{proof_kind}.rootCommitment"), f"{proof_kind} must name Root_k")
        challenges = " ".join(require_string_list(row.get("challengeFamilies"), f"{proof_kind}.challengeFamilies")).lower()
        require("one 256-bit seed" in challenges, f"{proof_kind} challenge family must use one seed")
        fixed_kind = require_string(row.get("fixedKindAccounting"), f"{proof_kind}.fixedKindAccounting")
        require("does not flat-sum unrelated proof-kind finite terms" in fixed_kind, f"{proof_kind}.fixedKindAccounting must reject flat sums")
        if proof_kind == "fold":
            require(
                "selected-repeated-tape-v1" in challenges
                and "2 PiCCS" in row.get("fixedKindAccounting", "")
                and "3 PiRLC" in row.get("fixedKindAccounting", ""),
                "fold transcript interface must pin selected repeated tape profile",
            )
        joined_rows.append(json.dumps(row, sort_keys=True).lower())
    require(seen == EXPECTED_PROOF_KINDS, "transcriptInterfaces must stay in proof-kind order")
    joined = " ".join(joined_rows)
    for needle in ["compressed", "randomness-session", "leakage", "component-root", "carry"]:
        require(needle in joined, f"transcriptInterfaces must mention {needle}")


def validate_loss_rule(accounting: dict[str, Any]) -> None:
    rule = require_dict(accounting.get("lossRule"), "lossRule")
    selected = require_string(rule.get("selectedDepthExpression"), "lossRule.selectedDepthExpression")
    require("epsilon_compiler_overhead" in selected and "epsilon_hash_model_gap" in selected, "epsilon_qrom must only charge compiler overhead and hash-model gap")
    for forbidden in ["n_kind!", "2*Q_H+n_kind", "epsilon_interactive_kind", "epsilon_precondition_kind"]:
        require(forbidden not in selected, f"selectedDepthExpression must not contain legacy DFM20 token {forbidden}")
    require(rule.get("queryBoundQH") == "2^64", "queryBoundQH must be 2^64")
    require(rule.get("queryBoundLog2") == 64, "queryBoundLog2 must be 64")
    require(rule.get("selectedDepthProtocolChallengeDerivations") == 26_265_375, "selected-depth implementation metric mismatch")
    challenge_counts = require_dict(rule.get("ctcoChallengeCountByKind"), "lossRule.ctcoChallengeCountByKind")
    require(set(challenge_counts) == {kind for kind, _ in EXPECTED_PROOF_KINDS}, "ctco challenge count keys mismatch")
    for proof_kind, count in challenge_counts.items():
        require(count == 1, f"{proof_kind} CTCO challenge count must be 1")
    require(rule.get("proofKindMalleabilityFormula") == "0; charged inside epsilon_collision through binding-target events", "proof-kind malleability formula mismatch")
    fixed_kind = require_string(rule.get("fixedKindAccountingRule"), "lossRule.fixedKindAccountingRule")
    require("H_bind" in fixed_kind and "fixed expected proof kind" in fixed_kind and "does not flat-sum unrelated proof-kind finite terms" in fixed_kind, "lossRule.fixedKindAccountingRule mismatch")
    require(rule.get("bindingCollisionFormula") == "4 * bindingTargetEventCount * Q_H^2 / 2^bindingOracle.outputBits", "binding collision formula mismatch")
    require("44 * 2^-256" in require_string(rule.get("bindingCollisionInstantiatedExpression"), "bindingCollisionInstantiatedExpression"), "binding collision instantiation mismatch")
    require(
        rule.get("compilerOverheadInstantiatedExpression") == "epsilon_compiler_overhead = 0 in the ideal split-QRO CTCO theorem model",
        "compiler overhead instantiation mismatch",
    )
    require("ideal split-QRO" in require_string(rule.get("hashModelGapInstantiatedExpression"), "hashModelGapInstantiatedExpression"), "hash-model gap instantiation mismatch")
    require_true(rule.get("interactiveLossChargedOutsideQROM"), "lossRule.interactiveLossChargedOutsideQROM")
    require_true(rule.get("interactiveSecurityBoundsInstantiated"), "lossRule.interactiveSecurityBoundsInstantiated")
    require_true(rule.get("sharedBadEventTagsPinned"), "lossRule.sharedBadEventTagsPinned")
    require(
        rule.get("sharedBadEventDeduplicationManifest") == "TestVectors/product-shared-bad-event-dedup-v1.json",
        "lossRule.sharedBadEventDeduplicationManifest mismatch",
    )
    require_true(rule.get("allQROMLossTermsInstantiated"), "lossRule.allQROMLossTermsInstantiated")
    require_true(rule.get("qromLossWithinBudget"), "lossRule.qromLossWithinBudget")
    require_true(rule.get("repositoryLocalIdealQROMClaimAllowed"), "lossRule.repositoryLocalIdealQROMClaimAllowed")
    require_false(rule.get("productionQROMClaimAllowed"), "lossRule.productionQROMClaimAllowed")


def validate_collision_accounting(accounting: dict[str, Any]) -> None:
    collision = require_dict(accounting.get("collisionAccounting"), "collisionAccounting")
    require(collision.get("hashOutputBits") == 256, "collisionAccounting.hashOutputBits must be the effective 256-bit exponent")
    require(collision.get("bindingOracleOutputBits") == 384, "collisionAccounting.bindingOracleOutputBits must be 384")
    require(collision.get("quantumQueryBoundLog2") == 64, "collisionAccounting.quantumQueryBoundLog2 must be 64")
    targets = collision.get("targets")
    require(isinstance(targets, list), "collisionAccounting.targets must be a list")
    names: list[str] = []
    domain_tags: list[str] = []
    for index, item in enumerate(targets):
        target = require_dict(item, f"collisionAccounting.targets[{index}]")
        names.append(require_string(target.get("name"), f"collisionAccounting.targets[{index}].name"))
        domain_tags.append(require_string(target.get("domainTag"), f"collisionAccounting.targets[{index}].domainTag"))
    require(names == EXPECTED_COLLISION_TARGETS, "collisionAccounting.targets must stay in the pinned target order")
    require(len(set(domain_tags)) == len(domain_tags), "collisionAccounting target domain tags must be unique")
    target_count = len(targets)
    require(collision.get("bindingTargets") == target_count, "collisionAccounting.bindingTargets must be derived from targets")
    ordered_pairs = 4 * target_count
    require(collision.get("orderedCollisionPairs") == ordered_pairs, "collisionAccounting.orderedCollisionPairs must equal 4 * targets")
    require(collision.get("bound") == f"{ordered_pairs} * 2^-256", "collisionAccounting.bound mismatch")
    require(collision.get("reducedBound") == "11 / 2^254", "collisionAccounting.reducedBound mismatch")
    derivation = require_string(collision.get("pairDerivation"), "collisionAccounting.pairDerivation")
    for needle in ["4 * bindingTargets", "Q_H = 2^64", "H_bind = 384", "44 * 2^-256", "11 / 2^254"]:
        require(needle in derivation, f"collisionAccounting.pairDerivation must mention {needle}")


def validate_ledger_term_mapping(accounting: dict[str, Any]) -> None:
    mapping = require_dict(accounting.get("ledgerTermMapping"), "ledgerTermMapping")
    qrom = require_dict(mapping.get("publicCoinQROMLoss"), "ledgerTermMapping.publicCoinQROMLoss")
    require(qrom.get("ledgerSymbol") == "epsilon_qrom", "publicCoinQROMLoss ledger symbol mismatch")
    require(require_string_list(qrom.get("sourceSymbols"), "publicCoinQROMLoss.sourceSymbols") == ["epsilon_compiler_overhead", "epsilon_hash_model_gap"], "epsilon_qrom source symbols mismatch")
    collision = require_dict(mapping.get("transcriptCollisionLoss"), "ledgerTermMapping.transcriptCollisionLoss")
    require(collision.get("ledgerSymbol") == "epsilon_collision", "collision ledger symbol mismatch")
    require(require_string_list(collision.get("sourceSymbols"), "transcriptCollisionLoss.sourceSymbols") == ["epsilon_bind"], "epsilon_collision must map from epsilon_bind")
    require("44 * 2^-256" in require_string(collision.get("selectedDepthContribution"), "collision.selectedDepthContribution"), "collision contribution must pin 384-bit bound")


def validate_legacy_status(accounting: dict[str, Any]) -> None:
    legacy = require_dict(accounting.get("legacyDFM20Status"), "legacyDFM20Status")
    require_true(legacy.get("legacyInterfaceDeprecated"), "legacyDFM20Status.legacyInterfaceDeprecated")
    require_false(legacy.get("legacyProductionTransformClaimAllowed"), "legacyDFM20Status.legacyProductionTransformClaimAllowed")
    require(legacy.get("smallestAcceptedChallengeCountN") == 204, "legacy smallest n mismatch")
    require("204!" in require_string(legacy.get("decisiveLegacyFailure"), "legacy decisive failure"), "legacy failure must mention 204!")


def validate_promotion_and_blockers(accounting: dict[str, Any]) -> None:
    blockers = accounting.get("hardClaimBlockers")
    require(isinstance(blockers, list), "hardClaimBlockers must be a list")
    require(blockers, "hardClaimBlockers must record concrete-hash and generic offline production blockers")
    blocker_text = " ".join(str(blocker) for blocker in blockers).lower()
    require("shake256-to-split-qro" in blocker_text, "hardClaimBlockers must keep concrete SHAKE256 promotion open")
    require("generic offline" in blocker_text, "hardClaimBlockers must reject generic offline production wording")
    require("zk simulator" not in blocker_text, "ZK simulator composition must not remain a QROM blocker")
    require("special-soundness" not in blocker_text, "interactive special-soundness must not remain a QROM blocker")
    require("deduplicate shared" not in blocker_text, "shared bad-event dedup must not remain a QROM blocker")
    promotion = require_dict(accounting.get("promotionRule"), "promotionRule")
    require_true(promotion.get("repositoryLocalIdealQROMClaimAllowed"), "promotionRule.repositoryLocalIdealQROMClaimAllowed")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    for key in [
        "requiresInteractiveSecurityBounds",
        "requiresCTCOProtocolImplementation",
        "requiresCompilerOverheadInstantiation",
        "requiresSharedBadEventDeduplication",
        "requiresSelectedDepthLedgerUpdate",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    require_false(promotion.get("requiresHBind384Implementation"), "promotionRule.requiresHBind384Implementation")
    require_true(
        promotion.get("requiresConcreteHashQROInstantiation"),
        "promotionRule.requiresConcreteHashQROInstantiation",
    )
    require_true(
        promotion.get("requiresInteractiveVerifierChallengeModeForHighestAssurance"),
        "promotionRule.requiresInteractiveVerifierChallengeModeForHighestAssurance",
    )


def validate_accounting(path: Path) -> None:
    accounting = read_json(path)
    text = json.dumps(accounting, sort_keys=True).lower()
    require("external" + " audit" not in text, "accounting must not encode outsourced review as a product gate")
    require(set(accounting) == EXPECTED_TOP_LEVEL_KEYS, "top-level accounting keys mismatch")
    require(accounting.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(accounting.get("accountingID") == "superneo-product-qrom-public-coin-accounting-v1", "accountingID mismatch")
    require(accounting.get("claimStatus") == "qrom-ctco-split-qro-contract-repository-local-production-claim", "claimStatus mismatch")
    validate_related_manifests(accounting)
    validate_formal_surface(accounting)
    validate_selected_depth(accounting)
    validate_hash_model(accounting)
    validate_public_coin_model(accounting)
    validate_transcript_interfaces(accounting)
    validate_loss_rule(accounting)
    validate_collision_accounting(accounting)
    validate_ledger_term_mapping(accounting)
    validate_legacy_status(accounting)
    validate_promotion_and_blockers(accounting)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ACCOUNTING
    if not path.is_absolute():
        path = ROOT / path
    validate_accounting(path)
    print("product QROM CTCO accounting validation passed")


if __name__ == "__main__":
    main()
