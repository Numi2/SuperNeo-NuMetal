#!/usr/bin/env python3
"""Validate release-readiness policy, schema-version, and CI gate drift."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"release readiness policy validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read_text(relative_path: str) -> str:
    path = ROOT / relative_path
    require(path.exists(), f"missing required file: {relative_path}")
    return path.read_text(encoding="utf-8")


def read_json(relative_path: str) -> object:
    try:
        return json.loads(read_text(relative_path))
    except json.JSONDecodeError as error:
        fail(f"{relative_path} is not valid JSON: {error}")


def require_contains(relative_path: str, needles: list[str]) -> None:
    text = read_text(relative_path)
    for needle in needles:
        require(needle in text, f"{relative_path} missing required text: {needle}")


def validate_workflow() -> None:
    workflow = read_text(".github/workflows/production-gate.yml")
    require("name: Full production gate" in workflow, "macOS CI job is not named as the full production gate")
    require("runs-on: macos-latest" in workflow, "full production gate must run on macOS")
    require("run: Scripts/production-gate.sh\n" in workflow, "full production gate must run Scripts/production-gate.sh")
    require("--skip-formal" not in workflow, "CI workflow must not skip formal checks in the full gate")
    for command in [
        "Scripts/validate-formal-ext2-serialization.py",
        "Scripts/test-formal-ext2-serialization-validation.py",
        "Scripts/validate-formal-ce-byte-serialization.py",
        "Scripts/test-formal-ce-byte-serialization-validation.py",
    ]:
        require(command in workflow, f"formal Linux cross-check missing {command}")


def validate_docs() -> None:
    require_contains(
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md",
        [
            "Scripts/production-gate.sh",
            "Result: passed.",
            "Not Yet Production-Ready For",
            "Remaining No-Go Items",
            "self-owned production-hardening record",
            "Docs/ReleaseEngineering-2026-04-16.md",
            "Docs/SchemaCompatibility-2026-04-16.md",
            "Docs/ReleaseCandidateRunbook-2026-04-16.md",
            "Docs/ConstantTimeEvidence-2026-04-16.md",
            "Docs/E2EProofMetrics-2026-04-16.md",
            "Docs/ProductOperationsReadiness-2026-04-16.md",
            "Docs/CryptographicSecurityDossier-2026-04-16.md",
            "TestVectors/numiseal-conformance-scope-v1.json",
            "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
            "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
            "TestVectors/product-crypto-security-dossier-v1.json",
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "TestVectors/product-extractor-loss-accounting-v1.json",
            "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-total-loss-budget-v1.json",
            "TestVectors/constant-time-scope-v1.json",
            "TestVectors/constant-time-lowering-evidence-v1.json",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "TestVectors/e2e-proof-metrics-v1.json",
            "TestVectors/benchmark-coverage-v1.json",
            "Scripts/validate-release-readiness-policy.py",
            "Scripts/validate-numiseal-conformance-scope.py",
            "Scripts/test-numiseal-conformance-scope-validation.py",
            "Scripts/validate-constant-time-scope.py",
            "Scripts/test-constant-time-scope-validation.py",
            "Scripts/validate-constant-time-lowering-evidence.py",
            "Scripts/test-constant-time-lowering-evidence-validation.py",
            "Scripts/generate-constant-time-release-evidence.py",
            "Scripts/validate-product-crypto-security-dossier.py",
            "Scripts/test-product-crypto-security-dossier-validation.py",
            "Scripts/validate-product-selected-depth-loss-accounting.py",
            "Scripts/test-product-selected-depth-loss-accounting-validation.py",
            "Scripts/validate-product-extractor-loss-accounting.py",
            "Scripts/test-product-extractor-loss-accounting-validation.py",
            "Scripts/validate-product-qrom-fiat-shamir-accounting.py",
            "Scripts/test-product-qrom-fiat-shamir-accounting-validation.py",
            "Scripts/validate-product-qrom-transcript-schedule.py",
            "Scripts/test-product-qrom-transcript-schedule-validation.py",
            "Scripts/validate-product-qrom-transform-preconditions.py",
            "Scripts/test-product-qrom-transform-preconditions-validation.py",
            "Scripts/validate-product-qrom-interactive-reduction.py",
            "Scripts/test-product-qrom-interactive-reduction-validation.py",
            "Scripts/validate-product-total-loss-budget.py",
            "Scripts/test-product-total-loss-budget-validation.py",
            "Scripts/validate-e2e-proof-metrics.py",
            "Scripts/test-e2e-proof-metrics-validation.py",
            "Scripts/validate-benchmark-coverage.py",
            "Scripts/test-benchmark-coverage-validation.py",
            "Scripts/validate-product-ops-surface.py",
            "Scripts/test-product-ops-surface-validation.py",
            "Scripts/generate-release-candidate-evidence.py",
            "Scripts/validate-release-candidate-evidence.py",
            "local product-ops readiness",
            "NumiSeal end-to-end theorem scope",
            "recursive folding knowledge soundness",
            "typed carry producer/consumer",
            "NumiSealZK simulation/privacy",
            "exact rejection-sampled field mask distribution",
            "bounded-depth product security theorem",
            "selected-depth loss accounting",
            "extractor loss-accounting validation",
            "QROM Fiat-Shamir accounting validation",
            "QROM transcript schedule validation",
            "QROM interactive reduction validation",
            "QROM transform precondition validation",
            "total-loss budget validation",
            "ProductSecurityTheorem",
            "Fiat-Shamir/QROM",
            "Module-SIS",
            "signed revocation feed",
        ],
    )
    require_contains(
        "Docs/ReleaseEngineering-2026-04-16.md",
        [
            "Research or Integration Release",
            "Production-Security Release",
            "Scripts/production-gate.sh",
            "without `--skip-formal`",
            "self-owned cryptographic and implementation review",
            "signed artifacts",
            "branch protection requiring the full production gate",
            "Scripts/validate-numiseal-conformance-scope.py",
            "Scripts/test-numiseal-conformance-scope-validation.py",
            "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
            "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
            "TestVectors/product-crypto-security-dossier-v1.json",
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "TestVectors/product-extractor-loss-accounting-v1.json",
            "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-total-loss-budget-v1.json",
            "Docs/CryptographicSecurityDossier-2026-04-16.md",
            "Scripts/validate-constant-time-scope.py",
            "Scripts/validate-constant-time-lowering-evidence.py",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "Scripts/validate-e2e-proof-metrics.py",
            "Scripts/validate-product-ops-surface.py",
            "product operations readiness",
            "NumiSeal end-to-end theorem scope digest",
            "recursive folding knowledge soundness",
            "typed carry producer/consumer",
            "NumiSealZK simulation/privacy",
            "exact rejection-sampled field mask distribution",
            "product cryptographic security dossier digest",
            "bounded-depth product security theorem",
            "product extractor loss accounting",
            "product QROM Fiat-Shamir accounting",
            "product QROM transcript schedule",
            "product QROM transform preconditions",
            "product QROM interactive reduction",
            "product total-loss budget",
            "signed revocation feed",
            "E2E proof metrics digest",
            "constant-time release evidence digest",
            "Scripts/generate-release-candidate-evidence.py",
        ],
    )
    require_contains(
        "Docs/SchemaCompatibility-2026-04-16.md",
        [
            "`artifactVersion = 1`",
            "`manifestVersion = 1`",
            "`ProofEnvelopeHeader.version = 4`",
            "`numiseal-test-vector-artifact-v1.json`",
            "`test-vector-artifact-v1.json`",
            "TestVectors/numiseal-conformance-scope-v1.json",
            "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
            "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
            "TestVectors/product-crypto-security-dossier-v1.json",
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "TestVectors/product-extractor-loss-accounting-v1.json",
            "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-total-loss-budget-v1.json",
            "TestVectors/constant-time-scope-v1.json",
            "TestVectors/constant-time-lowering-evidence-v1.json",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "TestVectors/e2e-proof-metrics-v1.json",
            "TestVectors/benchmark-coverage-v1.json",
            "Product extractor loss accounting manifest",
            "Product QROM Fiat-Shamir accounting manifest",
            "Product QROM transcript schedule manifest",
            "Product QROM transform preconditions manifest",
            "Product QROM interactive reduction manifest",
            "Product total-loss budget manifest",
            "Version Bump Checklist",
        ],
    )
    require_contains(
        "Docs/ReleaseCandidateRunbook-2026-04-16.md",
        [
            "Scripts/production-gate.sh",
            "Scripts/generate-release-candidate-evidence.py",
            "Scripts/validate-release-candidate-evidence.py",
            "--expect-production-gate-result passed",
            "unsigned research artifacts",
            "NumiSeal product/carry/ZK conformance-scope version and digest",
            "NumiSeal end-to-end theorem-scope version and digest",
            "NumiSealZK mask-distribution evidence version and digest",
            "product cryptographic security dossier version and digest",
            "selected-depth loss-accounting version and digest",
            "product extractor loss-accounting version and digest",
            "product QROM Fiat-Shamir accounting version and digest",
            "product QROM transcript schedule version and digest",
            "product QROM transform preconditions version and digest",
            "product total-loss budget version and digest",
            "constant-time source/formal scope version and digest",
            "constant-time lowering evidence version and digest",
            "constant-time release evidence version and digest",
            "E2E proof metrics version and digest",
            "product operations readiness status",
            "signed revocation feed",
            "Docs/ProductOperationsReadiness-2026-04-16.md",
            "Branch Protection",
        ],
    )
    require_contains(
        "CHANGELOG.md",
        [
            "## Unreleased",
            "Production Readiness",
            "Compatibility",
            "Remaining Production-Security Blockers",
            "NumiSeal end-to-end theorem scope",
            "recursive folding knowledge soundness",
            "typed carry producer/consumer",
            "NumiSealZK simulation/privacy",
            "exact rejection-sampled field mask distribution",
            "product cryptographic security dossier",
            "bounded-depth product security theorem",
            "selected-depth loss accounting",
            "extractor loss accounting",
            "QROM Fiat-Shamir accounting",
            "QROM transcript schedule",
            "QROM transform preconditions",
            "total-loss budget",
            "constant-time release evidence",
        ],
    )


def require_schema_version(relative_path: str, expected_id_suffix: str) -> None:
    schema = read_json(relative_path)
    require(isinstance(schema, dict), f"{relative_path} root must be a JSON object")
    schema_id = schema.get("$id")
    require(isinstance(schema_id, str), f"{relative_path} must publish a string $id")
    require(schema_id.endswith(expected_id_suffix), f"{relative_path} $id must end with {expected_id_suffix}")
    properties = schema.get("properties")
    require(isinstance(properties, dict), f"{relative_path} must contain object properties")
    artifact_version = properties.get("artifactVersion")
    require(isinstance(artifact_version, dict), f"{relative_path} must constrain artifactVersion")
    require(artifact_version.get("const") == 1, f"{relative_path} artifactVersion const must be 1")


def require_manifest_version(relative_path: str) -> None:
    manifest = read_json(relative_path)
    require(isinstance(manifest, dict), f"{relative_path} root must be a JSON object")
    require(manifest.get("manifestVersion") == 1, f"{relative_path} manifestVersion must be 1")


def validate_schema_versions() -> None:
    require_schema_version("TestVectors/artifact.schema.json", "/test-vector-artifact-v1.json")
    require_schema_version("TestVectors/numiseal-artifact.schema.json", "/numiseal-test-vector-artifact-v1.json")
    require_manifest_version("TestVectors/manifest.json")
    require_manifest_version("TestVectors/numiseal-manifest.json")
    conformance_scope = read_json("TestVectors/numiseal-conformance-scope-v1.json")
    require(isinstance(conformance_scope, dict), "NumiSeal conformance scope root must be an object")
    require(conformance_scope.get("schemaVersion") == 1, "NumiSeal conformance scope schemaVersion must be 1")
    require(
        conformance_scope.get("theoremScopeManifest") == "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
        "NumiSeal conformance scope must link the end-to-end theorem scope",
    )
    require(
        conformance_scope.get("zkMaskDistributionEvidence") == "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
        "NumiSeal conformance scope must link the mask-distribution evidence",
    )
    legacy_review_flag = "external" + "AuditRequired"
    require(legacy_review_flag not in conformance_scope, "NumiSeal conformance scope must not carry review-gate flags")
    theorem_scope = read_json("TestVectors/numiseal-end-to-end-theorem-scope-v1.json")
    require(isinstance(theorem_scope, dict), "NumiSeal end-to-end theorem scope root must be an object")
    require(theorem_scope.get("schemaVersion") == 1, "NumiSeal end-to-end theorem scope schemaVersion must be 1")
    require(
        theorem_scope.get("claimStatus") == "evidence-parametric-end-to-end-composition-theorem",
        "NumiSeal end-to-end theorem scope claimStatus must stay precise",
    )
    require(
        theorem_scope.get("zkMaskDistributionEvidence") == "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
        "NumiSeal theorem scope must link the mask-distribution evidence",
    )
    formal_model = theorem_scope.get("formalModel")
    require(isinstance(formal_model, dict), "NumiSeal end-to-end theorem formalModel must be an object")
    auxiliary_modules = formal_model.get("auxiliaryModules")
    require(isinstance(auxiliary_modules, list), "NumiSeal theorem auxiliaryModules must be a list")
    auxiliary_paths = {module.get("module") for module in auxiliary_modules if isinstance(module, dict)}
    require(
        {
            "Formal/SuperNeoFormal/RecursiveFoldingKnowledge.lean",
            "Formal/SuperNeoFormal/NumiSealTypedCarryTheorem.lean",
            "Formal/SuperNeoFormal/NumiSealZKPrivacy.lean",
            "Formal/SuperNeoFormal/NumiSealProductTheorem.lean",
        }.issubset(auxiliary_paths),
        "NumiSeal theorem scope must pin recursive knowledge, typed carry, ZK privacy, and product theorem modules",
    )
    theorem_surfaces = theorem_scope.get("theoremSurfaces")
    require(isinstance(theorem_surfaces, list), "NumiSeal theoremSurfaces must be a list")
    theorem_surface_ids = {surface.get("id") for surface in theorem_surfaces if isinstance(surface, dict)}
    require(
        {
            "recursive-folding-knowledge-soundness",
            "typed-carry-producer-consumer",
            "zk-leakage-simulation-privacy",
        }.issubset(theorem_surface_ids),
        "NumiSeal theorem scope must pin recursive knowledge, typed carry producer/consumer, and ZK privacy surfaces",
    )
    theorem_promotion = theorem_scope.get("promotionRule")
    require(isinstance(theorem_promotion, dict), "NumiSeal end-to-end theorem promotionRule must be an object")
    require(
        theorem_promotion.get("productionNumiSealTheoremClaimAllowed") is False,
        "NumiSeal end-to-end theorem scope must not prematurely allow production theorem claims",
    )
    mask_evidence = read_json("TestVectors/numiseal-zk-mask-distribution-evidence-v1.json")
    require(isinstance(mask_evidence, dict), "NumiSealZK mask-distribution evidence root must be an object")
    require(mask_evidence.get("schemaVersion") == 1, "NumiSealZK mask-distribution evidence schemaVersion must be 1")
    require(
        mask_evidence.get("claimStatus") == "exact-rejection-sampled-field-mask-evidence",
        "NumiSealZK mask-distribution evidence claimStatus must stay precise",
    )
    sampler = mask_evidence.get("sampler")
    require(isinstance(sampler, dict), "NumiSealZK mask evidence sampler must be an object")
    require(
        sampler.get("statisticalDistanceFromUniformAcceptedFieldElement") == "0",
        "NumiSealZK mask evidence must record zero statistical distance after rejection",
    )
    mask_promotion = mask_evidence.get("promotionRule")
    require(isinstance(mask_promotion, dict), "NumiSealZK mask evidence promotionRule must be an object")
    require(
        mask_promotion.get("productionZKPrivacyClaimAllowed") is False,
        "NumiSealZK mask evidence must not prematurely allow production privacy claims",
    )
    product_dossier = read_json("TestVectors/product-crypto-security-dossier-v1.json")
    require(isinstance(product_dossier, dict), "product crypto security dossier root must be an object")
    require(product_dossier.get("schemaVersion") == 1, "product crypto security dossier schemaVersion must be 1")
    require(
        product_dossier.get("claimStatus") == "evidence-parametric-product-security-theorem-dossier",
        "product crypto security dossier claimStatus must stay precise",
    )
    dossier_related = product_dossier.get("relatedManifests")
    require(isinstance(dossier_related, dict), "product crypto security dossier relatedManifests must be an object")
    require(
        dossier_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "product crypto security dossier must link extractor accounting",
    )
    require(
        dossier_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "product crypto security dossier must link QROM Fiat-Shamir accounting",
    )
    require(
        dossier_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "product crypto security dossier must link QROM transcript schedule",
    )
    require(
        dossier_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "product crypto security dossier must link QROM transform preconditions",
    )
    require(
        dossier_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "product crypto security dossier must link QROM interactive reduction",
    )
    require(
        dossier_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "product crypto security dossier must link total-loss budget",
    )
    dossier_depth = product_dossier.get("supportedProductDepth")
    require(isinstance(dossier_depth, dict), "product crypto security dossier supportedProductDepth must be an object")
    require(dossier_depth.get("depthModel") == "bounded-depth", "product security theorem must stay bounded-depth")
    require(dossier_depth.get("theoremMaximumDepth") == 1, "product security theorem maximum depth must remain 1")
    require(
        dossier_depth.get("polyDepthTheoremClaimAllowed") is False,
        "product security theorem must not prematurely claim poly-depth knowledge soundness",
    )
    lattice_dossier = product_dossier.get("latticeAssumptionDossier")
    require(isinstance(lattice_dossier, dict), "product crypto security dossier latticeAssumptionDossier must be an object")
    require(lattice_dossier.get("qDecimal") == "18446744069414584321", "product lattice q must stay pinned")
    require(
        lattice_dossier.get("productionPostQuantumClaimAllowed") is False,
        "product crypto security dossier must not prematurely allow production PQ claims",
    )
    qrom_position = product_dossier.get("fiatShamirQROMPosition")
    require(isinstance(qrom_position, dict), "product crypto security dossier fiatShamirQROMPosition must be an object")
    require(qrom_position.get("model") == "qrom", "product crypto security dossier must state the QROM target")
    require(
        qrom_position.get("transcriptScheduleManifest") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "product crypto security dossier must link the QROM transcript schedule in the QROM position",
    )
    require(
        qrom_position.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "product crypto security dossier must link QROM transform preconditions in the QROM position",
    )
    require(
        qrom_position.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "product crypto security dossier must link QROM interactive reduction in the QROM position",
    )
    require(
        qrom_position.get("productionQROMClaimAllowed") is False,
        "product crypto security dossier must not prematurely allow production QROM claims",
    )
    dossier_promotion = product_dossier.get("promotionRule")
    require(isinstance(dossier_promotion, dict), "product crypto security dossier promotionRule must be an object")
    require(
        dossier_promotion.get("productionProductSecurityClaimAllowed") is False,
        "product crypto security dossier must not prematurely allow production product-security claims",
    )
    selected_depth_loss = read_json("TestVectors/product-selected-depth-loss-accounting-v1.json")
    require(isinstance(selected_depth_loss, dict), "selected-depth loss-accounting root must be an object")
    require(selected_depth_loss.get("schemaVersion") == 1, "selected-depth loss-accounting schemaVersion must be 1")
    require(
        selected_depth_loss.get("claimStatus") == "selected-depth-loss-contract-not-production-claim",
        "selected-depth loss-accounting claimStatus must stay precise",
    )
    selected_depth = selected_depth_loss.get("selectedDepth")
    require(isinstance(selected_depth, dict), "selected-depth loss-accounting selectedDepth must be an object")
    require(selected_depth.get("selectedMaximumDepth") == 1, "selected-depth loss-accounting maximum depth must remain 1")
    total_loss = selected_depth_loss.get("totalLossRule")
    require(isinstance(total_loss, dict), "selected-depth loss-accounting totalLossRule must be an object")
    require(
        total_loss.get("selectedDepthLossClaimAllowed") is False,
        "selected-depth loss-accounting must not prematurely allow product-security loss claims",
    )
    blockers = selected_depth_loss.get("hardClaimBlockers")
    require(isinstance(blockers, list) and len(blockers) == 8, "selected-depth loss-accounting must pin eight hard blockers")
    selected_related = selected_depth_loss.get("relatedManifests")
    require(isinstance(selected_related, dict), "selected-depth loss-accounting relatedManifests must be an object")
    require(
        selected_related.get("productExtractorLossAccounting") == "TestVectors/product-extractor-loss-accounting-v1.json",
        "selected-depth loss-accounting must link extractor accounting",
    )
    require(
        selected_related.get("productQROMFiatShamirAccounting") == "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
        "selected-depth loss-accounting must link QROM Fiat-Shamir accounting",
    )
    require(
        selected_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "selected-depth loss-accounting must link QROM transcript schedule",
    )
    require(
        selected_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "selected-depth loss-accounting must link QROM transform preconditions",
    )
    require(
        selected_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "selected-depth loss-accounting must link QROM interactive reduction",
    )
    require(
        selected_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "selected-depth loss-accounting must link total-loss budget",
    )
    extractor_loss = read_json("TestVectors/product-extractor-loss-accounting-v1.json")
    require(isinstance(extractor_loss, dict), "extractor loss-accounting root must be an object")
    require(extractor_loss.get("schemaVersion") == 1, "extractor loss-accounting schemaVersion must be 1")
    require(
        extractor_loss.get("claimStatus") == "extractor-loss-contract-not-production-claim",
        "extractor loss-accounting claimStatus must stay precise",
    )
    extractor_rule = extractor_loss.get("lossRule")
    require(isinstance(extractor_rule, dict), "extractor loss-accounting lossRule must be an object")
    require(
        extractor_rule.get("productionExtractorClaimAllowed") is False,
        "extractor loss-accounting must not prematurely allow extractor claims",
    )
    qrom_accounting = read_json("TestVectors/product-qrom-fiat-shamir-accounting-v1.json")
    require(isinstance(qrom_accounting, dict), "QROM Fiat-Shamir accounting root must be an object")
    require(qrom_accounting.get("schemaVersion") == 1, "QROM Fiat-Shamir accounting schemaVersion must be 1")
    require(
        qrom_accounting.get("claimStatus") == "qrom-fiat-shamir-loss-contract-not-production-claim",
        "QROM Fiat-Shamir accounting claimStatus must stay precise",
    )
    qrom_rule = qrom_accounting.get("lossRule")
    require(isinstance(qrom_rule, dict), "QROM Fiat-Shamir accounting lossRule must be an object")
    require(
        qrom_rule.get("productionQROMClaimAllowed") is False,
        "QROM Fiat-Shamir accounting must not prematurely allow QROM claims",
    )
    qrom_mapping = qrom_accounting.get("ledgerTermMapping")
    require(isinstance(qrom_mapping, dict), "QROM Fiat-Shamir accounting ledgerTermMapping must be an object")
    qrom_loss = qrom_mapping.get("fiatShamirQROMLoss")
    collision_loss = qrom_mapping.get("transcriptCollisionLoss")
    require(isinstance(qrom_loss, dict), "QROM fiatShamirQROMLoss mapping must be an object")
    require(isinstance(collision_loss, dict), "QROM transcriptCollisionLoss mapping must be an object")
    require(
        qrom_loss.get("sourceSymbols") == ["epsilon_fs_transform", "epsilon_qro_queries", "epsilon_proof_kind_malleability"],
        "QROM Fiat-Shamir accounting must not double-count transcript collision inside epsilon_qrom",
    )
    require(
        collision_loss.get("sourceSymbols") == ["epsilon_transcript_collision"],
        "QROM Fiat-Shamir accounting must map epsilon_transcript_collision to epsilon_collision",
    )
    qrom_related = qrom_accounting.get("relatedManifests")
    require(isinstance(qrom_related, dict), "QROM Fiat-Shamir accounting relatedManifests must be an object")
    require(
        qrom_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "QROM Fiat-Shamir accounting must link QROM transcript schedule",
    )
    require(
        qrom_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM Fiat-Shamir accounting must link QROM transform preconditions",
    )
    require(
        qrom_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM Fiat-Shamir accounting must link QROM interactive reduction",
    )
    qrom_model = qrom_accounting.get("fiatShamirModel")
    require(isinstance(qrom_model, dict), "QROM Fiat-Shamir accounting fiatShamirModel must be an object")
    require(
        qrom_model.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM Fiat-Shamir accounting must link transform preconditions in the model",
    )
    require(
        qrom_model.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM Fiat-Shamir accounting must link interactive reduction in the model",
    )
    qrom_schedule = read_json("TestVectors/product-qrom-transcript-schedule-v1.json")
    require(isinstance(qrom_schedule, dict), "QROM transcript schedule root must be an object")
    require(qrom_schedule.get("schemaVersion") == 1, "QROM transcript schedule schemaVersion must be 1")
    require(
        qrom_schedule.get("claimStatus") == "qrom-transcript-schedule-contract-not-production-claim",
        "QROM transcript schedule claimStatus must stay precise",
    )
    schedule_entries = qrom_schedule.get("scheduleEntries")
    require(
        isinstance(schedule_entries, list) and len(schedule_entries) == 5,
        "QROM transcript schedule must pin five schedule entries",
    )
    schedule_related = qrom_schedule.get("relatedManifests")
    require(isinstance(schedule_related, dict), "QROM transcript schedule relatedManifests must be an object")
    require(
        schedule_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM transcript schedule must link QROM transform preconditions",
    )
    require(
        schedule_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM transcript schedule must link QROM interactive reduction",
    )
    qrom_preconditions = read_json("TestVectors/product-qrom-transform-preconditions-v1.json")
    require(isinstance(qrom_preconditions, dict), "QROM transform preconditions root must be an object")
    require(qrom_preconditions.get("schemaVersion") == 1, "QROM transform preconditions schemaVersion must be 1")
    require(
        qrom_preconditions.get("claimStatus") == "qrom-transform-precondition-dossier-not-production-claim",
        "QROM transform preconditions claimStatus must stay precise",
    )
    precondition_rows = qrom_preconditions.get("preconditions")
    require(
        isinstance(precondition_rows, list) and len(precondition_rows) == 10,
        "QROM transform preconditions must pin ten precondition rows",
    )
    precondition_promotion = qrom_preconditions.get("promotionRule")
    require(isinstance(precondition_promotion, dict), "QROM transform preconditions promotionRule must be an object")
    require(
        precondition_promotion.get("productionQROMClaimAllowed") is False,
        "QROM transform preconditions must not prematurely allow QROM claims",
    )
    qrom_reduction = read_json("TestVectors/product-qrom-interactive-reduction-v1.json")
    require(isinstance(qrom_reduction, dict), "QROM interactive reduction root must be an object")
    require(qrom_reduction.get("schemaVersion") == 1, "QROM interactive reduction schemaVersion must be 1")
    require(
        qrom_reduction.get("claimStatus") == "qrom-interactive-reduction-ledger-not-production-claim",
        "QROM interactive reduction claimStatus must stay precise",
    )
    reduction_loss = qrom_reduction.get("qromQueryAndLossInstantiation")
    require(isinstance(reduction_loss, dict), "QROM interactive reduction qromQueryAndLossInstantiation must be an object")
    require(
        reduction_loss.get("allNumericLossTermsInstantiated") is False,
        "QROM interactive reduction must not prematurely instantiate all numeric loss terms",
    )
    require(
        reduction_loss.get("queryBoundQH") == "2^64",
        "QROM interactive reduction must pin the selected Q_H policy bound",
    )
    total_budget = read_json("TestVectors/product-total-loss-budget-v1.json")
    require(isinstance(total_budget, dict), "total-loss budget root must be an object")
    require(total_budget.get("schemaVersion") == 1, "total-loss budget schemaVersion must be 1")
    require(
        total_budget.get("claimStatus") == "total-loss-budget-contract-not-production-claim",
        "total-loss budget claimStatus must stay precise",
    )
    computed_budget = total_budget.get("computedBudget")
    require(isinstance(computed_budget, dict), "total-loss budget computedBudget must be an object")
    require(
        computed_budget.get("productionTotalLossClaimAllowed") is False,
        "total-loss budget must not prematurely allow product-security loss claims",
    )
    require(
        computed_budget.get("selectedDepthLossWithinBudget") is False,
        "total-loss budget must not prematurely claim the selected-depth loss is within budget",
    )
    total_related = total_budget.get("relatedManifests")
    require(isinstance(total_related, dict), "total-loss budget relatedManifests must be an object")
    require(
        total_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "total-loss budget must link QROM transcript schedule",
    )
    require(
        total_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "total-loss budget must link QROM transform preconditions",
    )
    require(
        total_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "total-loss budget must link QROM interactive reduction",
    )
    constant_time_scope = read_json("TestVectors/constant-time-scope-v1.json")
    require(isinstance(constant_time_scope, dict), "constant-time scope root must be an object")
    require(constant_time_scope.get("schemaVersion") == 1, "constant-time scope schemaVersion must be 1")
    require(
        constant_time_scope.get("claimStatus") == "conditional-source-and-formal-trace-model",
        "constant-time scope claimStatus must stay precise",
    )
    require(
        constant_time_scope.get("loweringEvidenceManifest") == "TestVectors/constant-time-lowering-evidence-v1.json",
        "constant-time scope must link the lowering evidence manifest",
    )
    lowering_evidence = read_json("TestVectors/constant-time-lowering-evidence-v1.json")
    require(isinstance(lowering_evidence, dict), "constant-time lowering evidence root must be an object")
    require(lowering_evidence.get("schemaVersion") == 1, "constant-time lowering evidence schemaVersion must be 1")
    require(
        lowering_evidence.get("claimStatus") == "conditional-lowering-and-tcb-proof-contract",
        "constant-time lowering evidence claimStatus must stay precise",
    )
    require(
        lowering_evidence.get("releaseEvidenceManifest") == "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
        "constant-time lowering evidence must link the pinned release evidence manifest",
    )
    observation_lane_reports = lowering_evidence.get("observationLaneReports")
    require(isinstance(observation_lane_reports, dict), "constant-time lowering evidence observationLaneReports must be an object")
    require(
        observation_lane_reports.get("compiler") == "Evidence/ConstantTime/swift-llvm-metal-v1/compiler/compiler-observation-lanes-v1.json",
        "constant-time lowering evidence must link the compiler observation lane report",
    )
    require(
        observation_lane_reports.get("hardware") == "Evidence/ConstantTime/swift-llvm-metal-v1/hardware/hardware-observation-lanes-v1.json",
        "constant-time lowering evidence must link the hardware observation lane report",
    )
    promotion_rule = lowering_evidence.get("promotionRule")
    require(isinstance(promotion_rule, dict), "constant-time lowering evidence promotionRule must be an object")
    require(
        promotion_rule.get("productionConstantTimeClaimAllowed") is False,
        "constant-time lowering evidence must not prematurely allow production CT claims",
    )
    release_evidence = read_json("Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json")
    require(isinstance(release_evidence, dict), "constant-time release evidence root must be an object")
    require(release_evidence.get("schemaVersion") == 1, "constant-time release evidence schemaVersion must be 1")
    require(
        release_evidence.get("claimStatus") == "local-release-evidence-pinned",
        "constant-time release evidence claimStatus must stay precise",
    )
    release_promotion = release_evidence.get("promotionDecision")
    require(isinstance(release_promotion, dict), "constant-time release evidence promotionDecision must be an object")
    require(
        release_promotion.get("productionConstantTimeClaimAllowed") is False,
        "constant-time release evidence must not prematurely allow production CT claims",
    )
    artifact_entries = release_evidence.get("artifactEntries")
    require(
        isinstance(artifact_entries, list) and len(artifact_entries) == 12,
        "constant-time release evidence must pin twelve artifacts",
    )
    artifact_ids = {
        str(entry.get("id"))
        for entry in artifact_entries
        if isinstance(entry, dict)
    }
    require(
        {
            "swift-optimized-sil",
            "swift-optimized-llvm-ir",
            "swift-target-assembly",
            "swift-compiler-artifact-report",
            "compiler-observation-lanes",
            "hardware-observation-lanes",
        }.issubset(artifact_ids),
        "constant-time release evidence must pin Swift compiler artifacts and compiler/hardware observation lane reports",
    )
    e2e_metrics = read_json("TestVectors/e2e-proof-metrics-v1.json")
    require(isinstance(e2e_metrics, dict), "E2E proof metrics root must be an object")
    require(e2e_metrics.get("schemaVersion") == 1, "E2E proof metrics schemaVersion must be 1")
    require(
        e2e_metrics.get("claimStatus") == "checked-vector-and-product-smoke-size-budgets",
        "E2E proof metrics claimStatus must stay precise",
    )
    benchmark_coverage = read_json("TestVectors/benchmark-coverage-v1.json")
    require(isinstance(benchmark_coverage, dict), "benchmark coverage root must be an object")
    require(benchmark_coverage.get("schemaVersion") == 1, "benchmark coverage schemaVersion must be 1")
    require(
        benchmark_coverage.get("claimStatus") == "coverage-contract-not-hardware-performance-claim",
        "benchmark coverage claimStatus must stay precise",
    )

    serialization = read_text("SuperNeo-NuMetal/SuperNeoSerialization.swift")
    header_version = re.search(r"public\s+static\s+let\s+version:\s*UInt16\s*=\s*(\d+)", serialization)
    require(header_version is not None, "ProofEnvelopeHeader.version declaration not found")
    require(header_version.group(1) == "4", "ProofEnvelopeHeader.version must remain 4 until compatibility docs are updated")
    numiseal_kind = re.search(r"case\s+numiSealTerminal\s*=\s*(\d+)", serialization)
    require(numiseal_kind is not None, "ProofEnvelopeKind.numiSealTerminal raw value not found")
    require(numiseal_kind.group(1) == "4", "ProofEnvelopeKind.numiSealTerminal must remain kind 4 until compatibility docs are updated")


def validate_production_gate_wiring() -> None:
    gate = read_text("Scripts/production-gate.sh")
    require(
        "release policy, schema compatibility, and CI gate drift validation" in gate,
        "production gate usage text must mention release policy validation",
    )
    require(
        "run_step Scripts/validate-release-readiness-policy.py" in gate,
        "production gate must run validate-release-readiness-policy.py",
    )
    require(
        "run_step Scripts/test-release-candidate-evidence-validation.py" in gate,
        "production gate must run release-candidate evidence regression tests",
    )
    require(
        "run_step Scripts/validate-numiseal-conformance-scope.py" in gate,
        "production gate must run validate-numiseal-conformance-scope.py",
    )
    require(
        "run_step Scripts/test-numiseal-conformance-scope-validation.py" in gate,
        "production gate must run NumiSeal conformance scope regression tests",
    )
    require(
        "run_step Scripts/validate-numiseal-zk-mask-distribution-evidence.py" in gate,
        "production gate must run NumiSealZK mask-distribution evidence validation",
    )
    require(
        "run_step Scripts/test-numiseal-zk-mask-distribution-evidence-validation.py" in gate,
        "production gate must run NumiSealZK mask-distribution evidence regression tests",
    )
    require(
        "run_step Scripts/validate-numiseal-product-artifact-schema.py" in gate,
        "production gate must run NumiSeal product artifact schema validation",
    )
    require(
        "run_step Scripts/test-numiseal-product-artifact-schema-validation.py" in gate,
        "production gate must run NumiSeal product artifact schema regression tests",
    )
    require(
        "run_step Scripts/validate-product-crypto-security-dossier.py" in gate,
        "production gate must run validate-product-crypto-security-dossier.py",
    )
    require(
        "run_step Scripts/test-product-crypto-security-dossier-validation.py" in gate,
        "production gate must run product crypto security dossier regression tests",
    )
    require(
        "run_step Scripts/validate-product-selected-depth-loss-accounting.py" in gate,
        "production gate must run validate-product-selected-depth-loss-accounting.py",
    )
    require(
        "run_step Scripts/test-product-selected-depth-loss-accounting-validation.py" in gate,
        "production gate must run selected-depth loss-accounting regression tests",
    )
    require(
        "run_step Scripts/validate-product-extractor-loss-accounting.py" in gate,
        "production gate must run validate-product-extractor-loss-accounting.py",
    )
    require(
        "run_step Scripts/test-product-extractor-loss-accounting-validation.py" in gate,
        "production gate must run extractor loss-accounting regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-fiat-shamir-accounting.py" in gate,
        "production gate must run validate-product-qrom-fiat-shamir-accounting.py",
    )
    require(
        "run_step Scripts/test-product-qrom-fiat-shamir-accounting-validation.py" in gate,
        "production gate must run QROM Fiat-Shamir accounting regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-transcript-schedule.py" in gate,
        "production gate must run validate-product-qrom-transcript-schedule.py",
    )
    require(
        "run_step Scripts/test-product-qrom-transcript-schedule-validation.py" in gate,
        "production gate must run QROM transcript schedule regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-transform-preconditions.py" in gate,
        "production gate must run validate-product-qrom-transform-preconditions.py",
    )
    require(
        "run_step Scripts/test-product-qrom-transform-preconditions-validation.py" in gate,
        "production gate must run QROM transform precondition regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-interactive-reduction.py" in gate,
        "production gate must run validate-product-qrom-interactive-reduction.py",
    )
    require(
        "run_step Scripts/test-product-qrom-interactive-reduction-validation.py" in gate,
        "production gate must run QROM interactive reduction regression tests",
    )
    require(
        "run_step Scripts/validate-product-total-loss-budget.py" in gate,
        "production gate must run validate-product-total-loss-budget.py",
    )
    require(
        "run_step Scripts/test-product-total-loss-budget-validation.py" in gate,
        "production gate must run total-loss budget regression tests",
    )
    require(
        "run_step Scripts/validate-constant-time-scope.py" in gate,
        "production gate must run validate-constant-time-scope.py",
    )
    require(
        "run_step Scripts/test-constant-time-scope-validation.py" in gate,
        "production gate must run constant-time validator regression tests",
    )
    require(
        "run_step Scripts/validate-constant-time-lowering-evidence.py" in gate,
        "production gate must run validate-constant-time-lowering-evidence.py",
    )
    require(
        "run_step Scripts/test-constant-time-lowering-evidence-validation.py" in gate,
        "production gate must run constant-time lowering evidence regression tests",
    )
    require(
        "run_step Scripts/validate-e2e-proof-metrics.py" in gate,
        "production gate must run validate-e2e-proof-metrics.py",
    )
    require(
        "run_step Scripts/test-e2e-proof-metrics-validation.py" in gate,
        "production gate must run E2E proof metrics validator regression tests",
    )
    require(
        "run_step Scripts/validate-product-ops-surface.py" in gate,
        "production gate must run validate-product-ops-surface.py",
    )
    require(
        "run_step Scripts/test-product-ops-surface-validation.py" in gate,
        "production gate must run product ops surface validator regression tests",
    )
    require(
        "--generated-product-artifact \"numiseal-product-smoke:${numiseal_product_path}\"" in gate,
        "production gate must budget the generated NumiSeal product smoke artifact",
    )
    require(
        "--generated-product-artifact \"numiseal-zk-product-smoke:${numiseal_zk_product_path}\"" in gate,
        "production gate must budget the generated NumiSealZK product smoke artifact",
    )


def main() -> None:
    validate_workflow()
    validate_docs()
    validate_schema_versions()
    validate_production_gate_wiring()
    print("release readiness policy validation passed")


if __name__ == "__main__":
    main()
