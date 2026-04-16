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
            "TestVectors/numiseal-conformance-scope-v1.json",
            "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
            "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
            "TestVectors/constant-time-scope-v1.json",
            "TestVectors/constant-time-lowering-evidence-v1.json",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "TestVectors/e2e-proof-metrics-v1.json",
            "Scripts/validate-release-readiness-policy.py",
            "Scripts/validate-numiseal-conformance-scope.py",
            "Scripts/test-numiseal-conformance-scope-validation.py",
            "Scripts/validate-constant-time-scope.py",
            "Scripts/test-constant-time-scope-validation.py",
            "Scripts/validate-constant-time-lowering-evidence.py",
            "Scripts/test-constant-time-lowering-evidence-validation.py",
            "Scripts/generate-constant-time-release-evidence.py",
            "Scripts/validate-e2e-proof-metrics.py",
            "Scripts/test-e2e-proof-metrics-validation.py",
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
            "TestVectors/constant-time-scope-v1.json",
            "TestVectors/constant-time-lowering-evidence-v1.json",
            "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
            "TestVectors/e2e-proof-metrics-v1.json",
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
