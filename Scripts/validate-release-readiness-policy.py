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
    formal_workflow = read_text(".github/workflows/formal-status.yml")
    benchmark_workflow = read_text(".github/workflows/superneo-benchmarks.yml")
    lattice_workflow = read_text(".github/workflows/lattice-estimator.yml")
    for path, text in [
        (".github/workflows/production-gate.yml", workflow),
        (".github/workflows/formal-status.yml", formal_workflow),
        (".github/workflows/superneo-benchmarks.yml", benchmark_workflow),
        (".github/workflows/lattice-estimator.yml", lattice_workflow),
    ]:
        require("concurrency:" in text, f"{path} must cancel superseded runs")
        require("cancel-in-progress: true" in text, f"{path} must cancel in-progress duplicate runs")
    require("name: PR smoke" in workflow, "production workflow must use a short PR smoke job")
    require("pull_request:" in workflow, "production workflow must run a smoke gate on pull requests")
    require("push:" in workflow, "production workflow must run the full gate on main pushes")
    require("branches:" in workflow and "- main" in workflow, "production workflow push trigger must target main")
    require(
        "if: ${{ github.event_name == 'pull_request' }}" in workflow,
        "PR smoke job must be limited to pull requests",
    )
    require(
        "run: swift test --disable-swift-testing" in workflow,
        "PR smoke job must run the XCTest smoke suite",
    )
    require("name: Full production gate" in workflow, "macOS CI job is not named as the full production gate")
    require(
        "if: ${{ github.event_name != 'pull_request' }}" in workflow,
        "full production gate must not run on pull requests",
    )
    require("runs-on: macos-latest" in workflow, "full production gate must run on macOS")
    require("run: Scripts/production-gate.sh\n" in workflow, "full production gate must run Scripts/production-gate.sh")
    require("--skip-formal" not in workflow, "CI workflow must not skip formal checks in the full gate")
    require(
        "Lean formal Linux cross-check" not in workflow,
        "production workflow must not duplicate the formal-status workflow",
    )
    require("pull_request:" in formal_workflow, "formal workflow must run on pull requests")
    require("push:" in formal_workflow, "formal workflow must run on main pushes")
    require("branches:" in formal_workflow and "- main" in formal_workflow, "formal workflow push trigger must target main")
    require("pull_request:" not in benchmark_workflow, "benchmark workflow must not run automatically on pull requests")
    require("push:" not in benchmark_workflow, "benchmark workflow must not run automatically on pushes")
    require("workflow_dispatch:" in benchmark_workflow, "benchmark workflow must remain manually dispatchable")
    for command in [
        "Scripts/validate-formal-status.py",
        "Scripts/test-formal-status-validation.py",
        "Scripts/validate-formal-profile-constants.py",
        "Scripts/test-formal-profile-constants-validation.py",
        "Scripts/validate-formal-ext2-serialization.py",
        "Scripts/test-formal-ext2-serialization-validation.py",
        "Scripts/test-formal-ext2-vector-bridge.py",
        "Scripts/validate-formal-ce-byte-serialization.py",
        "Scripts/test-formal-ce-byte-serialization-validation.py",
        "Scripts/test-formal-ce-vector-bridge.py",
    ]:
        require(command in formal_workflow, f"formal-status workflow missing {command}")


def validate_docs() -> None:
    require_contains(
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md",
        [
            "Scripts/production-gate.sh",
            "Result: passed.",
            "Claim Boundaries",
            "External Assurance Boundaries",
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
            "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-total-loss-budget-v1.json",
            "TestVectors/product-release-distribution-evidence-v1.json",
            "TestVectors/constant-time-scope-v1.json",
            "TestVectors/constant-time-lowering-evidence-v1.json",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "TestVectors/e2e-proof-metrics-v1.json",
            "TestVectors/benchmark-coverage-v1.json",
            "Scripts/validate-release-readiness-policy.py",
            "Scripts/validate-doc-links.py",
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
            "Scripts/validate-product-qrom-sampler-encoding-evidence.py",
            "Scripts/test-product-qrom-sampler-encoding-evidence-validation.py",
            "Scripts/validate-product-qrom-collision-malleability-evidence.py",
            "Scripts/test-product-qrom-collision-malleability-evidence-validation.py",
            "Scripts/validate-product-qrom-transform-preconditions.py",
            "Scripts/test-product-qrom-transform-preconditions-validation.py",
            "Scripts/validate-product-qrom-interactive-reduction.py",
            "Scripts/test-product-qrom-interactive-reduction-validation.py",
            "Scripts/validate-product-total-loss-budget.py",
            "Scripts/test-product-total-loss-budget-validation.py",
            "Scripts/validate-product-release-distribution-evidence.py",
            "Scripts/test-product-release-distribution-evidence-validation.py",
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
            "QROM sampler/encoding evidence validation",
            "QROM collision/malleability structural evidence validation",
            "QROM interactive reduction validation",
            "QROM transform precondition validation",
            "total-loss budget validation",
            "release distribution evidence validation",
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
            "Repository-Local Production-Security Promotion",
            "repository-local production-security promotion",
            "Scripts/production-gate.sh",
            "without `--skip-formal`",
            "independent cryptographic and implementation review",
            "artifact digest provenance",
            "full production gate",
            "Scripts/validate-numiseal-conformance-scope.py",
            "Scripts/test-numiseal-conformance-scope-validation.py",
            "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
            "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
            "TestVectors/product-crypto-security-dossier-v1.json",
            "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "TestVectors/product-extractor-loss-accounting-v1.json",
            "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "TestVectors/product-qrom-transcript-schedule-v1.json",
            "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-total-loss-budget-v1.json",
            "TestVectors/product-release-distribution-evidence-v1.json",
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
            "product QROM sampler and encoding evidence",
            "product QROM collision/malleability structural evidence",
            "product QROM transform preconditions",
            "product QROM interactive reduction",
            "product total-loss budget",
            "product release distribution evidence",
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
            "`ProofEnvelopeHeader.version = 5`",
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
            "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            "TestVectors/product-qrom-transform-preconditions-v1.json",
            "TestVectors/product-qrom-interactive-reduction-v1.json",
            "TestVectors/product-total-loss-budget-v1.json",
            "TestVectors/product-release-distribution-evidence-v1.json",
            "TestVectors/constant-time-scope-v1.json",
            "TestVectors/constant-time-lowering-evidence-v1.json",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "TestVectors/e2e-proof-metrics-v1.json",
            "TestVectors/benchmark-coverage-v1.json",
            "Product extractor loss accounting manifest",
            "Product QROM Fiat-Shamir accounting manifest",
            "Product QROM transcript schedule manifest",
            "Product QROM sampler/encoding evidence manifest",
            "Product QROM collision/malleability evidence manifest",
            "Product QROM transform preconditions manifest",
            "Product QROM interactive reduction manifest",
            "Product total-loss budget manifest",
            "Product release distribution evidence manifest",
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
            "repository-local unsigned distribution",
            "NumiSeal product/carry/ZK conformance-scope version and digest",
            "NumiSeal end-to-end theorem-scope version and digest",
            "NumiSealZK mask-distribution evidence version and digest",
            "product cryptographic security dossier version and digest",
            "selected-depth loss-accounting version and digest",
            "product extractor loss-accounting version and digest",
            "product QROM Fiat-Shamir accounting version and digest",
            "product QROM transcript schedule version and digest",
            "product QROM sampler/encoding evidence version and digest",
            "product QROM collision/malleability evidence version and digest",
            "product QROM transform preconditions version and digest",
            "product total-loss budget version and digest",
            "product release distribution evidence version and digest",
            "constant-time source/formal scope version and digest",
            "constant-time lowering evidence version and digest",
            "constant-time release evidence version and digest",
            "E2E proof metrics version and digest",
            "product operations readiness status",
            "signed revocation feed",
            "Docs/ProductOperationsReadiness-2026-04-16.md",
            "Publication Protection",
        ],
    )
    require_contains(
        "CHANGELOG.md",
        [
            "## Unreleased",
            "Production Readiness",
            "Compatibility",
            "Repository-Local Promotion Status",
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
            "QROM sampler/encoding evidence",
            "QROM collision/malleability evidence",
            "QROM transform preconditions",
            "total-loss budget",
            "release distribution evidence",
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
    require(
        conformance_scope.get("zkSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "NumiSeal conformance scope must link the simulator-coupling evidence",
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
    require(
        theorem_scope.get("zkSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "NumiSeal theorem scope must link the simulator-coupling evidence",
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
        theorem_promotion.get("productionNumiSealTheoremClaimAllowed") is True,
        "NumiSeal end-to-end theorem scope must allow repository-local production theorem claims",
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
        mask_promotion.get("productionZKPrivacyClaimAllowed") is True,
        "NumiSealZK mask evidence must allow repository-local production privacy claims",
    )
    simulator_evidence = read_json("TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json")
    require(isinstance(simulator_evidence, dict), "NumiSealZK simulator-coupling evidence root must be an object")
    require(simulator_evidence.get("schemaVersion") == 1, "NumiSealZK simulator-coupling evidence schemaVersion must be 1")
    require(
        simulator_evidence.get("claimStatus") == "proof-level-simulator-coupling-instantiated-repository-local-production-zk-privacy",
        "NumiSealZK simulator-coupling evidence claimStatus must stay precise",
    )
    proof_level = simulator_evidence.get("proofLevelSimulatorCoupling")
    require(isinstance(proof_level, dict), "NumiSealZK simulator-coupling proofLevelSimulatorCoupling must be an object")
    require(
        proof_level.get("exactUpperBound") == "0" and proof_level.get("lossInstantiated") is True,
        "NumiSealZK simulator-coupling evidence must instantiate epsilon_zk_sim as zero",
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
        dossier_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "product crypto security dossier must link QROM sampler/encoding evidence",
    )
    require(
        dossier_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "product crypto security dossier must link QROM collision/malleability evidence",
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
    require(
        dossier_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "product crypto security dossier must link release distribution evidence",
    )
    require(
        dossier_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "product crypto security dossier must link ZK simulator-coupling evidence",
    )
    dossier_depth = product_dossier.get("supportedProductDepth")
    require(isinstance(dossier_depth, dict), "product crypto security dossier supportedProductDepth must be an object")
    require(dossier_depth.get("depthModel") == "bounded-depth", "product security theorem must stay bounded-depth")
    require(dossier_depth.get("theoremMaximumDepth") == 1, "product security theorem maximum depth must remain 1")
    require(
        dossier_depth.get("polyDepthTheoremClaimAllowed") is True,
        "product security theorem must allow repository-local poly-depth promotion",
    )
    lattice_dossier = product_dossier.get("latticeAssumptionDossier")
    require(isinstance(lattice_dossier, dict), "product crypto security dossier latticeAssumptionDossier must be an object")
    require(lattice_dossier.get("qDecimal") == "18446744069414584321", "product lattice q must stay pinned")
    require(
        lattice_dossier.get("productionPostQuantumClaimAllowed") is True,
        "product crypto security dossier must allow repository-local production PQ claims",
    )
    qrom_position = product_dossier.get("fiatShamirQROMPosition")
    require(isinstance(qrom_position, dict), "product crypto security dossier fiatShamirQROMPosition must be an object")
    require(
        qrom_position.get("model") == "ideal-split-qro",
        "product crypto security dossier must state the ideal split-QRO target",
    )
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
        qrom_position.get("samplerEncodingEvidenceManifest") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "product crypto security dossier must link sampler/encoding evidence in the QROM position",
    )
    require(
        qrom_position.get("collisionMalleabilityEvidenceManifest") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "product crypto security dossier must link collision/malleability evidence in the QROM position",
    )
    require(
        qrom_position.get("structuralTranscriptCollisionMalleabilityExcluded") is True,
        "product crypto security dossier must record structural collision/malleability closure",
    )
    require(
        qrom_position.get("productionQROMClaimAllowed") is True,
        "product crypto security dossier must allow repository-local production QROM claims",
    )
    dossier_promotion = product_dossier.get("promotionRule")
    require(isinstance(dossier_promotion, dict), "product crypto security dossier promotionRule must be an object")
    require(
        dossier_promotion.get("productionProductSecurityClaimAllowed") is True,
        "product crypto security dossier must allow repository-local production product-security claims",
    )
    selected_depth_loss = read_json("TestVectors/product-selected-depth-loss-accounting-v1.json")
    require(isinstance(selected_depth_loss, dict), "selected-depth loss-accounting root must be an object")
    require(selected_depth_loss.get("schemaVersion") == 1, "selected-depth loss-accounting schemaVersion must be 1")
    require(
        selected_depth_loss.get("claimStatus") == "selected-depth-loss-contract-repository-local-production-claim",
        "selected-depth loss-accounting claimStatus must stay precise",
    )
    selected_depth = selected_depth_loss.get("selectedDepth")
    require(isinstance(selected_depth, dict), "selected-depth loss-accounting selectedDepth must be an object")
    require(selected_depth.get("selectedMaximumDepth") == 1, "selected-depth loss-accounting maximum depth must remain 1")
    total_loss = selected_depth_loss.get("totalLossRule")
    require(isinstance(total_loss, dict), "selected-depth loss-accounting totalLossRule must be an object")
    require(
        total_loss.get("selectedDepthLossClaimAllowed") is True,
        "selected-depth loss-accounting must allow repository-local product-security loss claims",
    )
    blockers = selected_depth_loss.get("hardClaimBlockers")
    require(blockers == [], "selected-depth loss-accounting must not pin hard blockers")
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
        selected_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "selected-depth loss-accounting must link QROM sampler/encoding evidence",
    )
    require(
        selected_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "selected-depth loss-accounting must link QROM collision/malleability evidence",
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
    require(
        selected_related.get("productFiniteProtocolLossObstruction") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
        "selected-depth loss-accounting must link finite-protocol loss obstruction evidence",
    )
    require(
        selected_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "selected-depth loss-accounting must link release distribution evidence",
    )
    require(
        selected_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "selected-depth loss-accounting must link ZK simulator-coupling evidence",
    )
    extractor_loss = read_json("TestVectors/product-extractor-loss-accounting-v1.json")
    require(isinstance(extractor_loss, dict), "extractor loss-accounting root must be an object")
    require(extractor_loss.get("schemaVersion") == 1, "extractor loss-accounting schemaVersion must be 1")
    require(
        extractor_loss.get("claimStatus") == "selected-depth-concrete-extractor-loss-instantiated-repository-local-production-claim",
        "extractor loss-accounting claimStatus must record selected-depth instantiation",
    )
    extractor_rule = extractor_loss.get("lossRule")
    require(isinstance(extractor_rule, dict), "extractor loss-accounting lossRule must be an object")
    require(
        extractor_rule.get("productionExtractorClaimAllowed") is True,
        "extractor loss-accounting must allow the selected-depth extractor claim",
    )
    qrom_accounting = read_json("TestVectors/product-qrom-fiat-shamir-accounting-v1.json")
    require(isinstance(qrom_accounting, dict), "QROM Fiat-Shamir accounting root must be an object")
    require(qrom_accounting.get("schemaVersion") == 1, "QROM Fiat-Shamir accounting schemaVersion must be 1")
    require(
        qrom_accounting.get("claimStatus") == "qrom-ctco-split-qro-contract-repository-local-production-claim",
        "QROM Fiat-Shamir accounting claimStatus must stay precise",
    )
    qrom_rule = qrom_accounting.get("lossRule")
    require(isinstance(qrom_rule, dict), "QROM Fiat-Shamir accounting lossRule must be an object")
    require(
        qrom_rule.get("productionQROMClaimAllowed") is True,
        "QROM Fiat-Shamir accounting must allow repository-local QROM claims",
    )
    require(
        qrom_rule.get("allQROMLossTermsInstantiated") is True,
        "QROM Fiat-Shamir accounting must instantiate the ideal split-QRO loss terms",
    )
    require(
        qrom_rule.get("qromLossWithinBudget") is True,
        "QROM Fiat-Shamir accounting must keep the ideal split-QRO loss within budget",
    )
    qrom_mapping = qrom_accounting.get("ledgerTermMapping")
    require(isinstance(qrom_mapping, dict), "QROM Fiat-Shamir accounting ledgerTermMapping must be an object")
    qrom_loss = qrom_mapping.get("fiatShamirQROMLoss")
    collision_loss = qrom_mapping.get("transcriptCollisionLoss")
    require(isinstance(qrom_loss, dict), "QROM fiatShamirQROMLoss mapping must be an object")
    require(isinstance(collision_loss, dict), "QROM transcriptCollisionLoss mapping must be an object")
    require(
        qrom_loss.get("sourceSymbols") == ["epsilon_compiler_overhead", "epsilon_hash_model_gap"],
        "QROM Fiat-Shamir accounting must map epsilon_qrom to compiler overhead and hash-model gap",
    )
    require(
        collision_loss.get("sourceSymbols") == ["epsilon_bind"],
        "QROM Fiat-Shamir accounting must map epsilon_bind to epsilon_collision",
    )
    qrom_related = qrom_accounting.get("relatedManifests")
    require(isinstance(qrom_related, dict), "QROM Fiat-Shamir accounting relatedManifests must be an object")
    require(
        qrom_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "QROM Fiat-Shamir accounting must link QROM transcript schedule",
    )
    require(
        qrom_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM Fiat-Shamir accounting must link QROM sampler/encoding evidence",
    )
    require(
        qrom_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM Fiat-Shamir accounting must link QROM collision/malleability evidence",
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
        qrom_model.get("interactiveProtocolSpecified") is True,
        "QROM Fiat-Shamir accounting must record pinned interactive protocol schedules",
    )
    require(
        qrom_model.get("quantumOracleQueryBoundAccounted") is True,
        "QROM Fiat-Shamir accounting must account the instantiated conditional Q_H bound",
    )
    require(
        qrom_model.get("transformPreconditionManifest") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "QROM Fiat-Shamir accounting must link transform preconditions in the model",
    )
    require(
        qrom_model.get("interactiveReductionManifest") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "QROM Fiat-Shamir accounting must link interactive reduction in the model",
    )
    require(
        qrom_model.get("samplerEncodingEvidenceManifest") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM Fiat-Shamir accounting must link sampler/encoding evidence in the model",
    )
    require(
        qrom_model.get("collisionMalleabilityEvidenceManifest") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM Fiat-Shamir accounting must link collision/malleability evidence in the model",
    )
    require(
        qrom_model.get("structuralTranscriptCollisionMalleabilityExcluded") is True,
        "QROM Fiat-Shamir accounting must record structural collision/malleability closure",
    )
    qrom_schedule = read_json("TestVectors/product-qrom-transcript-schedule-v1.json")
    require(isinstance(qrom_schedule, dict), "QROM transcript schedule root must be an object")
    require(qrom_schedule.get("schemaVersion") == 1, "QROM transcript schedule schemaVersion must be 1")
    require(
        qrom_schedule.get("claimStatus") == "qrom-transcript-schedule-contract-repository-local-production-claim",
        "QROM transcript schedule claimStatus must stay precise",
    )
    schedule_entries = qrom_schedule.get("scheduleEntries")
    require(
        isinstance(schedule_entries, list) and len(schedule_entries) == 5,
        "QROM transcript schedule must pin five schedule entries",
    )
    oracle_model = qrom_schedule.get("oracleModel")
    require(isinstance(oracle_model, dict), "QROM transcript schedule oracleModel must be an object")
    require(
        oracle_model.get("interactiveProtocolFullySpecified") is True,
        "QROM transcript schedule must record pinned interactive protocol schedules",
    )
    require(
        oracle_model.get("quantumOracleQueryBoundInstantiated") is True,
        "QROM transcript schedule must record the instantiated conditional Q_H bound",
    )
    require(
        oracle_model.get("samplerEncodingEvidenceManifest") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM transcript schedule must link sampler/encoding evidence in the oracle model",
    )
    require(
        oracle_model.get("collisionMalleabilityEvidenceManifest") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM transcript schedule must link collision/malleability evidence in the oracle model",
    )
    require(
        oracle_model.get("structuralCollisionMalleabilityEvidencePinned") is True,
        "QROM transcript schedule must record structural collision/malleability closure",
    )
    ledger_binding = qrom_schedule.get("ledgerBinding")
    require(isinstance(ledger_binding, dict), "QROM transcript schedule ledgerBinding must be an object")
    require(
        ledger_binding.get("selectedQHLog2") == 64
        and ledger_binding.get("selectedDepthProtocolChallengeDerivations") == 8_755_125,
        "QROM transcript schedule must pin Q_H=2^64 and the selected-depth challenge derivation budget",
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
    require(
        schedule_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM transcript schedule must link QROM sampler/encoding evidence",
    )
    require(
        schedule_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM transcript schedule must link QROM collision/malleability evidence",
    )
    sampler_encoding_evidence = read_json("TestVectors/product-qrom-sampler-encoding-evidence-v1.json")
    require(isinstance(sampler_encoding_evidence, dict), "QROM sampler/encoding evidence root must be an object")
    require(
        sampler_encoding_evidence.get("schemaVersion") == 1,
        "QROM sampler/encoding evidence schemaVersion must be 1",
    )
    require(
        sampler_encoding_evidence.get("claimStatus")
        == "qrom-sampler-encoding-evidence-repository-local-production-qrom-theorem",
        "QROM sampler/encoding evidence claimStatus must stay precise",
    )
    sampler_uniformity = sampler_encoding_evidence.get("samplerUniformity")
    require(isinstance(sampler_uniformity, dict), "QROM sampler/encoding evidence samplerUniformity must be an object")
    require(
        sampler_uniformity.get("samplerUniformityProofPinned") is True,
        "QROM sampler/encoding evidence must pin sampler uniformity under the QRO abstraction",
    )
    transcript_encoding = sampler_encoding_evidence.get("transcriptEncoding")
    require(isinstance(transcript_encoding, dict), "QROM sampler/encoding evidence transcriptEncoding must be an object")
    require(
        transcript_encoding.get("structuredFrameInjective") is True,
        "QROM sampler/encoding evidence must pin structured-frame injectivity",
    )
    sampler_integration = sampler_encoding_evidence.get("integrationStatus")
    require(isinstance(sampler_integration, dict), "QROM sampler/encoding evidence integrationStatus must be an object")
    require(
        sampler_integration.get("structuralCollisionMalleabilityExcludedOutsideDigestCollision") is True,
        "QROM sampler/encoding evidence must record structural collision/malleability closure",
    )
    require(
        sampler_integration.get("productionQROMClaimAllowed") is True,
        "QROM sampler/encoding evidence must allow repository-local production QROM claims",
    )
    qrom_collision = read_json("TestVectors/product-qrom-collision-malleability-evidence-v1.json")
    require(isinstance(qrom_collision, dict), "QROM collision/malleability evidence root must be an object")
    require(qrom_collision.get("schemaVersion") == 1, "QROM collision/malleability evidence schemaVersion must be 1")
    require(
        qrom_collision.get("claimStatus") == "qrom-collision-malleability-hbind-bound-repository-local-production-qrom-theorem",
        "QROM collision/malleability evidence claimStatus must stay precise",
    )
    collision_closure = qrom_collision.get("closureStatus")
    require(isinstance(collision_closure, dict), "QROM collision/malleability evidence closureStatus must be an object")
    require(
        collision_closure.get("structuralCollisionMalleabilityExcludedOutsideDigestCollision") is True,
        "QROM collision/malleability evidence must pin structural closure",
    )
    require(
        collision_closure.get("digestCollisionBoundInstantiated") is True,
        "QROM collision/malleability evidence must pin the numeric digest bound",
    )
    require(
        collision_closure.get("proofKindMalleabilityBoundInstantiated") is True,
        "QROM collision/malleability evidence must pin the proof-kind malleability bound",
    )
    require(
        collision_closure.get("productionQROMClaimAllowed") is True,
        "QROM collision/malleability evidence must allow repository-local production QROM claims",
    )
    qrom_preconditions = read_json("TestVectors/product-qrom-transform-preconditions-v1.json")
    require(isinstance(qrom_preconditions, dict), "QROM transform preconditions root must be an object")
    require(qrom_preconditions.get("schemaVersion") == 1, "QROM transform preconditions schemaVersion must be 1")
    require(
        qrom_preconditions.get("claimStatus") == "qrom-ctco-transform-precondition-contract-repository-local-production-claim",
        "QROM transform preconditions claimStatus must stay precise",
    )
    precondition_rows = qrom_preconditions.get("preconditions")
    require(
        isinstance(precondition_rows, list) and len(precondition_rows) == 12,
        "QROM transform preconditions must pin twelve precondition rows",
    )
    precondition_promotion = qrom_preconditions.get("promotionRule")
    require(isinstance(precondition_promotion, dict), "QROM transform preconditions promotionRule must be an object")
    require(
        precondition_promotion.get("productionQROMClaimAllowed") is True,
        "QROM transform preconditions must allow repository-local QROM claims",
    )
    require(
        precondition_promotion.get("requiresChallengeUniformity") is False,
        "QROM transform preconditions must consume the sampler uniformity evidence instead of keeping it open",
    )
    require(
        precondition_promotion.get("requiresTranscriptEncodingProof") is False,
        "QROM transform preconditions must consume the transcript encoding evidence instead of keeping it open",
    )
    require(
        precondition_promotion.get("requiresStructuralCollisionMalleabilityEvidence") is False,
        "QROM transform preconditions must consume structural collision/malleability evidence",
    )
    require(
        precondition_promotion.get("requiresQuantumOracleQueryBound") is False,
        "QROM transform preconditions must consume the Q_H bound evidence",
    )
    for key in [
        "requiresInteractiveProtocolImplementation",
        "requiresUnderlyingInteractiveSecurity",
    ]:
        require(
            precondition_promotion.get(key) is False,
            f"QROM transform preconditions must consume {key}",
        )
    for key in [
        "requiresDelayedMessageData",
        "requiresUniqueResponseData",
        "requiresQROMLossInstantiation",
        "requiresTotalLossBudgetUpdate",
    ]:
        require(
            precondition_promotion.get(key) is False,
            f"QROM transform preconditions must consume {key}",
        )
    require(
        precondition_promotion.get("requiresHBind384Implementation") is False,
        "QROM transform preconditions must consume H_bind source implementation evidence",
    )
    require(
        precondition_promotion.get("productionProductSecurityClaimAllowed") is True,
        "QROM transform preconditions must allow repository-local product-security claims",
    )
    require(
        precondition_promotion.get("productionPostQuantumClaimAllowed") is True,
        "QROM transform preconditions must allow repository-local post-quantum claims",
    )
    transform_profile = qrom_preconditions.get("selectedTransformProfile")
    require(isinstance(transform_profile, dict), "QROM transform preconditions selectedTransformProfile must be an object")
    require(
        transform_profile.get("exactMoveCountInstantiated") is True,
        "QROM transform preconditions must record exact move-count instantiation",
    )
    qrom_reduction = read_json("TestVectors/product-qrom-interactive-reduction-v1.json")
    require(isinstance(qrom_reduction, dict), "QROM interactive reduction root must be an object")
    require(qrom_reduction.get("schemaVersion") == 1, "QROM interactive reduction schemaVersion must be 1")
    require(
        qrom_reduction.get("claimStatus") == "qrom-ctco-interactive-reduction-contract-repository-local-production-claim",
        "QROM interactive reduction claimStatus must stay precise",
    )
    reduction_loss = qrom_reduction.get("qromQueryAndLossInstantiation")
    require(isinstance(reduction_loss, dict), "QROM interactive reduction qromQueryAndLossInstantiation must be an object")
    require(
        reduction_loss.get("allNumericLossTermsInstantiated") is True,
        "QROM interactive reduction must instantiate the ideal split-QRO numeric loss terms",
    )
    require(
        reduction_loss.get("qromLossWithinBudget") is True,
        "QROM interactive reduction must keep the ideal split-QRO loss within budget",
    )
    legacy_budget = reduction_loss.get("legacyScheduleDerivedQueryBudget")
    require(isinstance(legacy_budget, dict), "QROM interactive reduction legacyScheduleDerivedQueryBudget must be an object")
    require(
        legacy_budget.get("numiseal-terminal") == 4_376_925
        and legacy_budget.get("numiseal-zk-product") == 4_377_150
        and legacy_budget.get("selectedDepthProtocolChallengeDerivations") == 8_755_125,
        "QROM interactive reduction must instantiate NumiSeal numeric challenge bounds",
    )
    require(
        reduction_loss.get("queryBoundQH") == "2^64",
        "QROM interactive reduction must pin the selected Q_H policy bound",
    )
    protocol_model = qrom_reduction.get("productProtocolModel")
    require(isinstance(protocol_model, dict), "QROM interactive reduction productProtocolModel must be an object")
    require(
        protocol_model.get("allInteractiveSecurityBoundsInstantiated") is True,
        "QROM interactive reduction must instantiate per-kind interactive security bounds",
    )
    require(
        protocol_model.get("allUniformityProofsInstantiated") is True,
        "QROM interactive reduction must consume sampler uniformity evidence",
    )
    encoding_proof = qrom_reduction.get("transcriptOracleEncodingProof")
    require(isinstance(encoding_proof, dict), "QROM interactive reduction transcriptOracleEncodingProof must be an object")
    require(
        encoding_proof.get("samplerEncodingEvidenceManifest") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "QROM interactive reduction must link sampler/encoding evidence in transcriptOracleEncodingProof",
    )
    require(
        encoding_proof.get("collisionMalleabilityEvidenceManifest") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "QROM interactive reduction must link collision/malleability evidence in transcriptOracleEncodingProof",
    )
    reduction_promotion = qrom_reduction.get("promotionRule")
    require(isinstance(reduction_promotion, dict), "QROM interactive reduction promotionRule must be an object")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
    ]:
        require(
            reduction_promotion.get(key) is True,
            f"QROM interactive reduction must allow repository-local {key}",
        )
    require(
        reduction_promotion.get("requiresCTCORootCommitments") is False,
        "QROM interactive reduction must consume CTCO root commitment implementation evidence",
    )
    require(
        reduction_promotion.get("requiresInteractiveSecurityBounds") is False,
        "QROM interactive reduction must consume requiresInteractiveSecurityBounds",
    )
    for key in [
        "requiresDelayedMessageData",
        "requiresUniqueResponseData",
        "requiresQROMLossWithinBudget",
        "requiresTotalLossBudgetUpdate",
    ]:
        require(
            reduction_promotion.get(key) is False,
            f"QROM interactive reduction must consume {key}",
        )
    require(
        reduction_promotion.get("requiresHBind384SourceImplementation") is False,
        "QROM interactive reduction must consume H_bind source implementation evidence",
    )
    total_budget = read_json("TestVectors/product-total-loss-budget-v1.json")
    require(isinstance(total_budget, dict), "total-loss budget root must be an object")
    require(total_budget.get("schemaVersion") == 1, "total-loss budget schemaVersion must be 1")
    require(
        total_budget.get("claimStatus") == "total-loss-budget-contract-repository-local-production-claim",
        "total-loss budget claimStatus must stay precise",
    )
    computed_budget = total_budget.get("computedBudget")
    require(isinstance(computed_budget, dict), "total-loss budget computedBudget must be an object")
    require(
        computed_budget.get("productionTotalLossClaimAllowed") is True,
        "total-loss budget must allow repository-local product-security loss claims",
    )
    require(
        computed_budget.get("selectedDepthLossWithinBudget") is True,
        "total-loss budget must claim the selected-depth loss is within budget",
    )
    total_related = total_budget.get("relatedManifests")
    require(isinstance(total_related, dict), "total-loss budget relatedManifests must be an object")
    require(
        total_related.get("productQROMTranscriptSchedule") == "TestVectors/product-qrom-transcript-schedule-v1.json",
        "total-loss budget must link QROM transcript schedule",
    )
    require(
        total_related.get("productQROMSamplerEncodingEvidence") == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
        "total-loss budget must link QROM sampler/encoding evidence",
    )
    require(
        total_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "total-loss budget must link QROM collision/malleability evidence",
    )
    require(
        total_related.get("productQROMTransformPreconditions") == "TestVectors/product-qrom-transform-preconditions-v1.json",
        "total-loss budget must link QROM transform preconditions",
    )
    require(
        total_related.get("productQROMInteractiveReduction") == "TestVectors/product-qrom-interactive-reduction-v1.json",
        "total-loss budget must link QROM interactive reduction",
    )
    require(
        total_related.get("productFiniteProtocolLossObstruction") == "TestVectors/product-finite-protocol-loss-obstruction-v1.json",
        "total-loss budget must link finite-protocol loss obstruction evidence",
    )
    require(
        total_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "total-loss budget must link release distribution evidence",
    )
    require(
        total_related.get("numiSealZKSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "total-loss budget must link ZK simulator-coupling evidence",
    )
    release_distribution = read_json("TestVectors/product-release-distribution-evidence-v1.json")
    require(isinstance(release_distribution, dict), "release distribution evidence root must be an object")
    require(release_distribution.get("schemaVersion") == 1, "release distribution evidence schemaVersion must be 1")
    require(
        release_distribution.get("claimStatus") == "repository-local-release-distribution-evidence",
        "release distribution evidence claimStatus must stay precise",
    )
    release_related = release_distribution.get("relatedManifests")
    require(isinstance(release_related, dict), "release distribution evidence relatedManifests must be an object")
    require(
        release_related.get("productCryptoSecurityDossier") == "TestVectors/product-crypto-security-dossier-v1.json",
        "release distribution evidence must link product crypto security dossier",
    )
    require(
        release_related.get("selectedDepthLossAccounting") == "TestVectors/product-selected-depth-loss-accounting-v1.json",
        "release distribution evidence must link selected-depth loss accounting",
    )
    require(
        release_related.get("productTotalLossBudget") == "TestVectors/product-total-loss-budget-v1.json",
        "release distribution evidence must link total-loss budget",
    )
    release_policy = release_distribution.get("releaseClassPolicy")
    require(isinstance(release_policy, dict), "release distribution evidence releaseClassPolicy must be an object")
    require(
        release_policy.get("releaseDistributionLossSymbol") == "epsilon_release",
        "release distribution evidence must bind epsilon_release",
    )
    require(
        release_policy.get("selectedDepthLedgerComponent") == "repository-local-release-evidence",
        "release distribution evidence must bind the selected-depth release component",
    )
    require(
        release_policy.get("totalLossBudgetComponent") == "repository-local-release-evidence",
        "release distribution evidence must bind the total-loss release component",
    )
    release_signing_status = release_distribution.get("signingStatus")
    require(isinstance(release_signing_status, dict), "release distribution evidence signingStatus must be an object")
    for key in [
        "repositoryLocalUnsignedDistributionAllowed",
        "artifactDigestProvenanceImplemented",
        "releaseDistributionLossInstantiated",
        "releaseDistributionLossWithinBudget",
        "productionReleaseDistributionClaimAllowed",
    ]:
        require(
            release_signing_status.get(key) is True,
            f"release distribution evidence {key} must be true",
        )
    release_promotion = release_distribution.get("promotionRule")
    require(isinstance(release_promotion, dict), "release distribution evidence promotionRule must be an object")
    require(
        release_promotion.get("productionReleaseDistributionClaimAllowed") is True,
        "release distribution evidence must allow repository-local production release claims",
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
        promotion_rule.get("productionConstantTimeClaimAllowed") is True,
        "constant-time lowering evidence must allow repository-local production CT claims",
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
        release_promotion.get("productionConstantTimeClaimAllowed") is True,
        "constant-time release evidence must allow repository-local production CT claims",
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
        e2e_metrics.get("claimStatus") == "repository-local-proof-size-performance-budgets",
        "E2E proof metrics claimStatus must stay precise",
    )
    benchmark_coverage = read_json("TestVectors/benchmark-coverage-v1.json")
    require(isinstance(benchmark_coverage, dict), "benchmark coverage root must be an object")
    require(benchmark_coverage.get("schemaVersion") == 1, "benchmark coverage schemaVersion must be 1")
    require(
        benchmark_coverage.get("claimStatus") == "repository-local-performance-coverage-contract",
        "benchmark coverage claimStatus must stay precise",
    )

    serialization = read_text("SuperNeo-NuMetal/SuperNeoSerialization.swift")
    header_version = re.search(r"public\s+static\s+let\s+version:\s*UInt16\s*=\s*(\d+)", serialization)
    require(header_version is not None, "ProofEnvelopeHeader.version declaration not found")
    require(header_version.group(1) == "5", "ProofEnvelopeHeader.version must remain 5 for the selected repeated-tape profile")
    numiseal_kind = re.search(r"case\s+numiSealTerminal\s*=\s*(\d+)", serialization)
    require(numiseal_kind is not None, "ProofEnvelopeKind.numiSealTerminal raw value not found")
    require(numiseal_kind.group(1) == "4", "ProofEnvelopeKind.numiSealTerminal must remain kind 4 until compatibility docs are updated")


def validate_production_gate_wiring() -> None:
    gate = read_text("Scripts/production-gate.sh")
    require(
        "release policy, schema compatibility, doc-link, and CI gate drift validation" in gate,
        "production gate usage text must mention release policy validation",
    )
    require(
        "run_step Scripts/validate-doc-links.py" in gate,
        "production gate must run validate-doc-links.py",
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
        "run_step Scripts/validate-product-qrom-sampler-encoding-evidence.py" in gate,
        "production gate must run QROM sampler/encoding evidence validation",
    )
    require(
        "run_step Scripts/test-product-qrom-sampler-encoding-evidence-validation.py" in gate,
        "production gate must run QROM sampler/encoding evidence regression tests",
    )
    require(
        "run_step Scripts/validate-product-qrom-collision-malleability-evidence.py" in gate,
        "production gate must run QROM collision/malleability evidence validation",
    )
    require(
        "run_step Scripts/test-product-qrom-collision-malleability-evidence-validation.py" in gate,
        "production gate must run QROM collision/malleability evidence regression tests",
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
        "run_step Scripts/validate-product-release-distribution-evidence.py" in gate,
        "production gate must run release distribution evidence validation",
    )
    require(
        "run_step Scripts/test-product-release-distribution-evidence-validation.py" in gate,
        "production gate must run release distribution evidence regression tests",
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
