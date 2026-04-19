#!/usr/bin/env python3
"""Validate product release-distribution evidence contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "TestVectors" / "product-release-distribution-evidence-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "evidenceID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "releaseClassPolicy",
    "requiredArtifactFamilies",
    "requiredProvenanceFields",
    "requiredVerificationSteps",
    "signingStatus",
    "releaseEvidenceBinding",
    "promotionRule",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductReleaseDistributionEvidence",
    "ProductReleaseDistributionEvidenceAccepted",
    "productSecurityTheorem_requires_release_distribution_evidence",
}

EXPECTED_ARTIFACT_FAMILIES = [
    "source-archive",
    "swift-cli-binaries",
    "test-vector-bundles",
    "release-candidate-evidence",
    "benchmark-and-estimator-artifacts",
]

EXPECTED_PROVENANCE_FIELDS = [
    "repositoryURL",
    "commitHash",
    "sourceTreeDigest",
    "branch",
    "tag",
    "dirtyState",
    "releaseClass",
    "swiftToolchainVersion",
    "leanToolchainVersion",
    "lakeVersion",
    "productionGateCommand",
    "productionGateResult",
    "artifactDigest",
    "artifactFamily",
    "artifactByteCount",
    "artifactSignatureDigest",
    "releaseSigningKeyDigest",
    "provenanceFormatVersion",
    "releaseEvidenceDigest",
    "productCryptoSecurityDossierDigest",
    "selectedDepthLossAccountingDigest",
    "productTotalLossBudgetDigest",
    "constantTimeReleaseEvidenceDigest",
    "benchmarkCoverageDigest",
    "notarizationOrPublicationProofDigest",
    "publicationProtectionEvidenceDigest",
    "archivedReleaseEvidenceDigest",
]

EXPECTED_FALSE_SIGNING_FLAGS = {
    "releaseSigningKeySelected",
    "artifactSigningImplemented",
    "signedProvenanceFormatPinned",
    "notarizationOrPublicationPathPinned",
    "publicationProtectionEvidencePinned",
    "archivedReleaseEvidencePinned",
    "releaseDistributionLossInstantiated",
    "releaseDistributionLossWithinBudget",
    "productionReleaseDistributionClaimAllowed",
}

EXPECTED_TRUE_PROMOTION_REQUIREMENTS = {
    "requiresReleaseSigningKey",
    "requiresSignedArtifacts",
    "requiresSignedProvenance",
    "requiresNotarizationOrPublicationProof",
    "requiresPublicationProtectionEvidence",
    "requiresArchivedReleaseEvidence",
    "requiresReleaseDistributionLossBudget",
}


def fail(message: str) -> None:
    print(f"product release distribution evidence validation failed: {message}", file=sys.stderr)
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
    require(isinstance(value, list) and value, f"{label} must be a list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must remain false until signed release distribution evidence is instantiated")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(evidence: dict[str, Any]) -> None:
    related = require_dict(evidence.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin release-distribution dependencies exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    dossier = read_json(ROOT / EXPECTED_MANIFESTS["productCryptoSecurityDossier"])
    dossier_related = require_dict(dossier.get("relatedManifests"), "productCryptoSecurityDossier.relatedManifests")
    require(
        dossier_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "product crypto security dossier must link release distribution evidence",
    )
    selected = read_json(ROOT / EXPECTED_MANIFESTS["selectedDepthLossAccounting"])
    selected_related = require_dict(selected.get("relatedManifests"), "selectedDepthLossAccounting.relatedManifests")
    require(
        selected_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "selected-depth loss accounting must link release distribution evidence",
    )
    total = read_json(ROOT / EXPECTED_MANIFESTS["productTotalLossBudget"])
    total_related = require_dict(total.get("relatedManifests"), "productTotalLossBudget.relatedManifests")
    require(
        total_related.get("productReleaseDistributionEvidence") == "TestVectors/product-release-distribution-evidence-v1.json",
        "total-loss budget must link release distribution evidence",
    )


def validate_formal_surface(evidence: dict[str, Any]) -> None:
    formal = require_dict(evidence.get("formalSurface"), "formalSurface")
    module_path = require_relative_path(formal.get("module"), "formalSurface.module")
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = module_path.read_text(encoding="utf-8")
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_release_class_policy(evidence: dict[str, Any]) -> None:
    policy = require_dict(evidence.get("releaseClassPolicy"), "releaseClassPolicy")
    require(policy.get("researchIntegrationReleaseAllowed") is True, "research integration release must remain allowed")
    require_false(policy.get("productionSecurityReleaseAllowed"), "releaseClassPolicy.productionSecurityReleaseAllowed")
    require(policy.get("unsignedResearchArtifactStatus") == "unsigned_research_artifact", "unsigned artifact status mismatch")
    require(policy.get("releaseDistributionLossSymbol") == "epsilon_release", "releaseDistributionLossSymbol mismatch")
    require(policy.get("selectedDepthLedgerComponent") == "release-signing-notarization", "selectedDepthLedgerComponent mismatch")
    require(policy.get("totalLossBudgetComponent") == "release-signing-notarization", "totalLossBudgetComponent mismatch")


def validate_artifacts_and_provenance(evidence: dict[str, Any]) -> None:
    families = evidence.get("requiredArtifactFamilies")
    require(isinstance(families, list), "requiredArtifactFamilies must be a list")
    seen: list[str] = []
    for index, item in enumerate(families):
        family = require_dict(item, f"requiredArtifactFamilies[{index}]")
        family_id = require_string(family.get("id"), f"requiredArtifactFamilies[{index}].id")
        seen.append(family_id)
        require_string(family.get("description"), f"{family_id}.description")
        require(family.get("signatureRequiredForProduction") is True, f"{family_id}.signatureRequiredForProduction must be true")
        require(family.get("provenanceDigestRequired") is True, f"{family_id}.provenanceDigestRequired must be true")
    require(seen == EXPECTED_ARTIFACT_FAMILIES, "requiredArtifactFamilies must stay in the pinned order")

    fields = require_string_list(evidence.get("requiredProvenanceFields"), "requiredProvenanceFields")
    require(fields == EXPECTED_PROVENANCE_FIELDS, "requiredProvenanceFields mismatch")
    steps = require_string_list(evidence.get("requiredVerificationSteps"), "requiredVerificationSteps")
    joined = " ".join(steps).lower()
    for needle in ["signature", "provenance", "production gate", "notarization", "publication protection", "production-security"]:
        require(needle in joined, f"requiredVerificationSteps must mention {needle}")


def validate_signing_status(evidence: dict[str, Any]) -> None:
    status = require_dict(evidence.get("signingStatus"), "signingStatus")
    require(set(status) == EXPECTED_FALSE_SIGNING_FLAGS, "signingStatus keys mismatch")
    for key in EXPECTED_FALSE_SIGNING_FLAGS:
        require_false(status.get(key), f"signingStatus.{key}")


def validate_release_evidence_binding(evidence: dict[str, Any]) -> None:
    binding = require_dict(evidence.get("releaseEvidenceBinding"), "releaseEvidenceBinding")
    for key in [
        "releaseCandidateEvidenceGenerator",
        "releaseCandidateEvidenceValidator",
        "releaseRunbook",
        "releaseEngineeringPolicy",
    ]:
        require_relative_path(binding.get(key), f"releaseEvidenceBinding.{key}")
    for key in [
        "releaseEvidenceRecordsUnsignedStatus",
        "releaseEvidenceRecordsManifestDigest",
        "productionSecurityBoundariesMentionReleaseDistribution",
    ]:
        require(binding.get(key) is True, f"releaseEvidenceBinding.{key} must be true")


def validate_promotion(evidence: dict[str, Any]) -> None:
    promotion = require_dict(evidence.get("promotionRule"), "promotionRule")
    require(set(promotion) == EXPECTED_TRUE_PROMOTION_REQUIREMENTS | {"productionReleaseDistributionClaimAllowed"}, "promotionRule keys mismatch")
    require_false(promotion.get("productionReleaseDistributionClaimAllowed"), "promotionRule.productionReleaseDistributionClaimAllowed")
    for key in EXPECTED_TRUE_PROMOTION_REQUIREMENTS:
        require(promotion.get(key) is True, f"promotionRule.{key} must be true")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-release-distribution-evidence-v1.json",
            "release distribution evidence",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "TestVectors/product-release-distribution-evidence-v1.json",
            "product release distribution evidence",
        ],
        "Docs/ReleaseCandidateRunbook-2026-04-16.md": [
            "product release distribution evidence version and digest",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product release distribution evidence manifest",
        ],
        "TestVectors/README.md": [
            "product-release-distribution-evidence-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-release-distribution-evidence.py" in gate,
        "production gate must run release distribution evidence validator",
    )
    require(
        "run_step Scripts/test-product-release-distribution-evidence-validation.py" in gate,
        "production gate must run release distribution evidence regression tests",
    )


def validate_evidence(path: Path) -> None:
    evidence = read_json(path)
    text = json.dumps(evidence, sort_keys=True).lower()
    require("external" + " audit" not in text, "release distribution evidence must not encode outsourced review as a gate")
    require(set(evidence) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(evidence.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(evidence.get("evidenceID") == "superneo-product-release-distribution-evidence-v1", "evidenceID mismatch")
    require(
        evidence.get("claimStatus") == "release-distribution-evidence-contract-not-production-claim",
        "claimStatus mismatch",
    )
    validate_related_manifests(evidence)
    validate_formal_surface(evidence)
    validate_release_class_policy(evidence)
    validate_artifacts_and_provenance(evidence)
    validate_signing_status(evidence)
    validate_release_evidence_binding(evidence)
    validate_promotion(evidence)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else EVIDENCE
    if not path.is_absolute():
        path = ROOT / path
    validate_evidence(path)
    print("product release distribution evidence validation passed")


if __name__ == "__main__":
    main()
