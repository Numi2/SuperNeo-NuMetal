#!/usr/bin/env python3
"""Validate a SuperNeo release-candidate evidence packet."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"release candidate evidence validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_hex_digest(value: Any, label: str) -> str:
    digest = require_string(value, label)
    require(len(digest) == 64, f"{label} must be a SHA-256 hex digest")
    require(all(character in "0123456789abcdef" for character in digest), f"{label} must be lowercase hex")
    return digest


def require_int(value: Any, label: str) -> int:
    require(isinstance(value, int), f"{label} must be an integer")
    return value


def validate(path: Path, *, allow_dirty: bool, expected_gate_result: str | None) -> None:
    try:
        evidence = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path} is not valid JSON: {error}")
    evidence = require_dict(evidence, "evidence")
    require(evidence.get("schemaVersion") == 1, "schemaVersion must be 1")
    require_string(evidence.get("generatedAtUTC"), "generatedAtUTC")

    release = require_dict(evidence.get("release"), "release")
    require_string(release.get("name"), "release.name")
    require(release.get("class") == "research-or-integration", "release.class must be research-or-integration")

    repository = require_dict(evidence.get("repository"), "repository")
    require_string(repository.get("commit"), "repository.commit")
    require_string(repository.get("branch"), "repository.branch")
    dirty = repository.get("dirty")
    require(isinstance(dirty, bool), "repository.dirty must be boolean")
    require(allow_dirty or not dirty, "release evidence must be generated from a clean worktree")
    require(isinstance(repository.get("statusShort"), list), "repository.statusShort must be a list")

    gate = require_dict(evidence.get("productionGate"), "productionGate")
    command = require_string(gate.get("command"), "productionGate.command")
    result = require_string(gate.get("result"), "productionGate.result")
    require(result in {"passed", "failed", "not_run"}, "productionGate.result is invalid")
    if expected_gate_result is not None:
        require(result == expected_gate_result, f"productionGate.result must be {expected_gate_result}")
    if result == "passed":
        require(command == "Scripts/production-gate.sh", "passed release evidence must come from the full production gate")

    surfaces = require_dict(evidence.get("publicSurfaces"), "publicSurfaces")
    require(require_int(surfaces.get("r1csArtifactVersion"), "r1csArtifactVersion") == 1, "R1CS artifact version must be 1")
    require(require_int(surfaces.get("r1csManifestVersion"), "r1csManifestVersion") == 1, "R1CS manifest version must be 1")
    require(require_int(surfaces.get("numiSealArtifactVersion"), "numiSealArtifactVersion") == 1, "NumiSeal artifact version must be 1")
    require(require_int(surfaces.get("numiSealManifestVersion"), "numiSealManifestVersion") == 1, "NumiSeal manifest version must be 1")
    require(
        require_int(surfaces.get("numiSealConformanceScopeVersion"), "numiSealConformanceScopeVersion") == 1,
        "NumiSeal conformance scope version must be 1",
    )
    require_string(surfaces.get("numiSealConformanceScopeDigestHex"), "numiSealConformanceScopeDigestHex")
    require(
        require_int(
            surfaces.get("numiSealEndToEndTheoremScopeVersion"),
            "numiSealEndToEndTheoremScopeVersion",
        ) == 1,
        "NumiSeal end-to-end theorem scope version must be 1",
    )
    require_string(
        surfaces.get("numiSealEndToEndTheoremScopeDigestHex"),
        "numiSealEndToEndTheoremScopeDigestHex",
    )
    require(
        require_string(
            surfaces.get("numiSealEndToEndTheoremScopeClaimStatus"),
            "numiSealEndToEndTheoremScopeClaimStatus",
        ) == "evidence-parametric-end-to-end-composition-theorem",
        "NumiSeal end-to-end theorem scope claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("numiSealZKMaskDistributionEvidenceVersion"),
            "numiSealZKMaskDistributionEvidenceVersion",
        ) == 1,
        "NumiSealZK mask-distribution evidence version must be 1",
    )
    require_string(
        surfaces.get("numiSealZKMaskDistributionEvidenceDigestHex"),
        "numiSealZKMaskDistributionEvidenceDigestHex",
    )
    require(
        require_string(
            surfaces.get("numiSealZKMaskDistributionEvidenceClaimStatus"),
            "numiSealZKMaskDistributionEvidenceClaimStatus",
        ) == "exact-rejection-sampled-field-mask-evidence",
        "NumiSealZK mask-distribution evidence claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productCryptoSecurityDossierVersion"),
            "productCryptoSecurityDossierVersion",
        ) == 1,
        "product crypto security dossier version must be 1",
    )
    require_string(
        surfaces.get("productCryptoSecurityDossierDigestHex"),
        "productCryptoSecurityDossierDigestHex",
    )
    require(
        require_string(
            surfaces.get("productCryptoSecurityDossierClaimStatus"),
            "productCryptoSecurityDossierClaimStatus",
        ) == "evidence-parametric-product-security-theorem-dossier",
        "product crypto security dossier claim status must stay precise",
    )
    require(
        require_string(
            surfaces.get("productCryptoSecurityDossierDepthModel"),
            "productCryptoSecurityDossierDepthModel",
        ) == "bounded-depth",
        "product crypto security dossier depth model must stay bounded-depth",
    )
    require(
        require_int(
            surfaces.get("productCryptoSecurityDossierMaximumDepth"),
            "productCryptoSecurityDossierMaximumDepth",
        ) == 1,
        "product crypto security dossier maximum depth must be 1",
    )
    require(
        require_int(
            surfaces.get("productSelectedDepthLossAccountingVersion"),
            "productSelectedDepthLossAccountingVersion",
        ) == 1,
        "product selected-depth loss accounting version must be 1",
    )
    require_string(
        surfaces.get("productSelectedDepthLossAccountingDigestHex"),
        "productSelectedDepthLossAccountingDigestHex",
    )
    require(
        require_string(
            surfaces.get("productSelectedDepthLossAccountingClaimStatus"),
            "productSelectedDepthLossAccountingClaimStatus",
        ) == "selected-depth-loss-contract-not-production-claim",
        "product selected-depth loss accounting claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productSelectedDepthLossAccountingMaximumDepth"),
            "productSelectedDepthLossAccountingMaximumDepth",
        ) == 1,
        "product selected-depth loss accounting maximum depth must be 1",
    )
    require(
        require_int(
            surfaces.get("productSelectedDepthLossComponentCount"),
            "productSelectedDepthLossComponentCount",
        ) == 10,
        "product selected-depth loss accounting must pin ten component losses",
    )
    require(
        require_int(
            surfaces.get("productExtractorLossAccountingVersion"),
            "productExtractorLossAccountingVersion",
        ) == 1,
        "product extractor loss accounting version must be 1",
    )
    require_string(
        surfaces.get("productExtractorLossAccountingDigestHex"),
        "productExtractorLossAccountingDigestHex",
    )
    require(
        require_string(
            surfaces.get("productExtractorLossAccountingClaimStatus"),
            "productExtractorLossAccountingClaimStatus",
        ) == "extractor-loss-contract-not-production-claim",
        "product extractor loss accounting claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productExtractorLossComponentCount"),
            "productExtractorLossComponentCount",
        ) == 4,
        "product extractor loss accounting must pin four component losses",
    )
    require(
        require_int(
            surfaces.get("productQROMFiatShamirAccountingVersion"),
            "productQROMFiatShamirAccountingVersion",
        ) == 1,
        "product QROM Fiat-Shamir accounting version must be 1",
    )
    require_string(
        surfaces.get("productQROMFiatShamirAccountingDigestHex"),
        "productQROMFiatShamirAccountingDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMFiatShamirAccountingClaimStatus"),
            "productQROMFiatShamirAccountingClaimStatus",
        ) == "qrom-fiat-shamir-loss-contract-not-production-claim",
        "product QROM Fiat-Shamir accounting claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMFiatShamirTranscriptInterfaceCount"),
            "productQROMFiatShamirTranscriptInterfaceCount",
        ) == 5,
        "product QROM Fiat-Shamir accounting must pin five transcript interfaces",
    )
    require(
        require_int(
            surfaces.get("productQROMTranscriptScheduleVersion"),
            "productQROMTranscriptScheduleVersion",
        ) == 1,
        "product QROM transcript schedule version must be 1",
    )
    require_string(
        surfaces.get("productQROMTranscriptScheduleDigestHex"),
        "productQROMTranscriptScheduleDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMTranscriptScheduleClaimStatus"),
            "productQROMTranscriptScheduleClaimStatus",
        ) == "qrom-transcript-schedule-contract-not-production-claim",
        "product QROM transcript schedule claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMTranscriptScheduleEntryCount"),
            "productQROMTranscriptScheduleEntryCount",
        ) == 5,
        "product QROM transcript schedule must pin five schedule entries",
    )
    require(
        require_int(
            surfaces.get("productQROMTransformPreconditionsVersion"),
            "productQROMTransformPreconditionsVersion",
        ) == 1,
        "product QROM transform preconditions version must be 1",
    )
    require_string(
        surfaces.get("productQROMTransformPreconditionsDigestHex"),
        "productQROMTransformPreconditionsDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMTransformPreconditionsClaimStatus"),
            "productQROMTransformPreconditionsClaimStatus",
        ) == "qrom-transform-precondition-dossier-not-production-claim",
        "product QROM transform preconditions claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMTransformPreconditionCount"),
            "productQROMTransformPreconditionCount",
        ) == 10,
        "product QROM transform preconditions must pin ten preconditions",
    )
    require(
        require_int(
            surfaces.get("productQROMInteractiveReductionVersion"),
            "productQROMInteractiveReductionVersion",
        ) == 1,
        "product QROM interactive reduction version must be 1",
    )
    require_hex_digest(
        surfaces.get("productQROMInteractiveReductionDigestHex"),
        "productQROMInteractiveReductionDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMInteractiveReductionClaimStatus"),
            "productQROMInteractiveReductionClaimStatus",
        ) == "qrom-interactive-reduction-ledger-not-production-claim",
        "product QROM interactive reduction claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMInteractiveReductionProofKindCount"),
            "productQROMInteractiveReductionProofKindCount",
        ) == 5,
        "product QROM interactive reduction must pin five proof-kind protocols",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetVersion"),
            "productTotalLossBudgetVersion",
        ) == 1,
        "product total-loss budget version must be 1",
    )
    require_string(
        surfaces.get("productTotalLossBudgetDigestHex"),
        "productTotalLossBudgetDigestHex",
    )
    require(
        require_string(
            surfaces.get("productTotalLossBudgetClaimStatus"),
            "productTotalLossBudgetClaimStatus",
        ) == "total-loss-budget-contract-not-production-claim",
        "product total-loss budget claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetComponentCount"),
            "productTotalLossBudgetComponentCount",
        ) == 10,
        "product total-loss budget must pin ten component bounds",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetRequiredTermCount"),
            "productTotalLossBudgetRequiredTermCount",
        ) == 9,
        "product total-loss budget must require nine selected-depth terms",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetInstantiatedRequiredTermCount"),
            "productTotalLossBudgetInstantiatedRequiredTermCount",
        ) == 0,
        "product total-loss budget must not pretend required terms are instantiated",
    )
    require(
        surfaces.get("productTotalLossBudgetWithinBudget") is False,
        "product total-loss budget must not prematurely claim the selected loss is within budget",
    )
    require(
        require_int(surfaces.get("constantTimeScopeVersion"), "constantTimeScopeVersion") == 1,
        "constant-time scope version must be 1",
    )
    require_string(surfaces.get("constantTimeScopeDigestHex"), "constantTimeScopeDigestHex")
    require(
        require_int(surfaces.get("constantTimeLoweringEvidenceVersion"), "constantTimeLoweringEvidenceVersion") == 1,
        "constant-time lowering evidence version must be 1",
    )
    require_string(surfaces.get("constantTimeLoweringEvidenceDigestHex"), "constantTimeLoweringEvidenceDigestHex")
    require(
        require_string(
            surfaces.get("constantTimeLoweringEvidenceClaimStatus"),
            "constantTimeLoweringEvidenceClaimStatus",
        ) == "conditional-lowering-and-tcb-proof-contract",
        "constant-time lowering evidence claim status must stay precise",
    )
    require(
        require_int(surfaces.get("constantTimeReleaseEvidenceVersion"), "constantTimeReleaseEvidenceVersion") == 1,
        "constant-time release evidence version must be 1",
    )
    require_string(surfaces.get("constantTimeReleaseEvidenceDigestHex"), "constantTimeReleaseEvidenceDigestHex")
    require(
        require_string(
            surfaces.get("constantTimeReleaseEvidenceClaimStatus"),
            "constantTimeReleaseEvidenceClaimStatus",
        ) == "local-release-evidence-pinned",
        "constant-time release evidence claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("constantTimeCompilerObservationLanesVersion"),
            "constantTimeCompilerObservationLanesVersion",
        ) == 1,
        "constant-time compiler observation lanes version must be 1",
    )
    require_string(
        surfaces.get("constantTimeCompilerObservationLanesDigestHex"),
        "constantTimeCompilerObservationLanesDigestHex",
    )
    require(
        require_string(
            surfaces.get("constantTimeCompilerObservationLanesClaimStatus"),
            "constantTimeCompilerObservationLanesClaimStatus",
        ) == "compiler-observation-lanes-local-and-gap-recorded",
        "constant-time compiler observation lanes claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("constantTimeHardwareObservationLanesVersion"),
            "constantTimeHardwareObservationLanesVersion",
        ) == 1,
        "constant-time hardware observation lanes version must be 1",
    )
    require_string(
        surfaces.get("constantTimeHardwareObservationLanesDigestHex"),
        "constantTimeHardwareObservationLanesDigestHex",
    )
    require(
        require_string(
            surfaces.get("constantTimeHardwareObservationLanesClaimStatus"),
            "constantTimeHardwareObservationLanesClaimStatus",
        ) == "hardware-observation-lanes-local-non-certifying",
        "constant-time hardware observation lanes claim status must stay precise",
    )
    require(
        require_int(surfaces.get("e2eProofMetricsVersion"), "e2eProofMetricsVersion") == 1,
        "E2E proof metrics version must be 1",
    )
    require_string(surfaces.get("e2eProofMetricsDigestHex"), "e2eProofMetricsDigestHex")
    require(
        require_int(surfaces.get("e2eProofMetricsTrackedArtifactCount"), "e2eProofMetricsTrackedArtifactCount") >= 8,
        "E2E proof metrics must track checked vector artifacts",
    )
    require(
        require_int(surfaces.get("e2eProofMetricsGeneratedBudgetCount"), "e2eProofMetricsGeneratedBudgetCount") >= 2,
        "E2E proof metrics must track product smoke budgets",
    )
    require(
        require_int(surfaces.get("benchmarkCoverageVersion"), "benchmarkCoverageVersion") == 1,
        "benchmark coverage version must be 1",
    )
    require_string(surfaces.get("benchmarkCoverageDigestHex"), "benchmarkCoverageDigestHex")
    require(
        require_int(surfaces.get("benchmarkCoverageSurfaceCount"), "benchmarkCoverageSurfaceCount") >= 8,
        "benchmark coverage must track the whole-stack surface set",
    )
    require(
        require_int(surfaces.get("productOperationsStatusVersion"), "productOperationsStatusVersion") == 2,
        "product operations status version must be 2",
    )
    require(require_int(surfaces.get("proofEnvelopeHeaderVersion"), "proofEnvelopeHeaderVersion") == 4, "proof envelope version must be 4")
    require(require_int(surfaces.get("numiSealProofEnvelopeKind"), "numiSealProofEnvelopeKind") == 4, "NumiSeal envelope kind must be 4")
    require_string(surfaces.get("r1csSchemaID"), "r1csSchemaID")
    require_string(surfaces.get("numiSealSchemaID"), "numiSealSchemaID")

    documentation = require_dict(evidence.get("documentation"), "documentation")
    for key in [
        "auditPacket",
        "releaseEngineering",
        "schemaCompatibility",
        "numiSealConformanceScope",
        "numiSealEndToEndTheoremScope",
        "numiSealZKMaskDistributionEvidence",
        "productCryptoSecurityDossier",
        "productCryptoSecurityDossierPolicy",
        "productSelectedDepthLossAccounting",
        "productExtractorLossAccounting",
        "productQROMFiatShamirAccounting",
        "productQROMTranscriptSchedule",
        "productQROMTransformPreconditions",
        "productQROMInteractiveReduction",
        "productTotalLossBudget",
        "constantTimeEvidence",
        "constantTimeScope",
        "constantTimeLoweringEvidence",
        "constantTimeReleaseEvidence",
        "e2eProofMetrics",
        "e2eProofMetricsPolicy",
        "benchmarkCoverage",
        "benchmarkCoveragePolicy",
        "productOperationsReadiness",
        "releaseRunbook",
        "changelog",
    ]:
        relative = require_string(documentation.get(key), f"documentation.{key}")
        require((ROOT / relative).exists(), f"documentation.{key} does not exist: {relative}")

    signing = require_dict(evidence.get("signing"), "signing")
    require(signing.get("status") == "unsigned_research_artifact", "signing.status must remain explicit")
    require(
        signing.get("signedArtifactsRequiredForProductionSecurity") is True,
        "production-security signing requirement must be explicit",
    )
    boundaries = evidence.get("productionSecurityBoundaries")
    require(isinstance(boundaries, list) and len(boundaries) >= 3, "productionSecurityBoundaries must list residual boundaries")
    require(
        all("external" + " audit" not in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must not require outsourced review",
    )
    require(
        any("product cryptographic security dossier" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention the product cryptographic security dossier",
    )
    require(
        any("selected-depth loss-accounting" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention selected-depth loss accounting",
    )
    require(
        any("extractor loss accounting" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention extractor loss accounting",
    )
    require(
        any("qrom fiat-shamir accounting" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM Fiat-Shamir accounting",
    )
    require(
        any("qrom transcript schedule" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM transcript schedule",
    )
    require(
        any("qrom transform preconditions" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM transform preconditions",
    )
    require(
        any("qrom interactive reduction" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM interactive reduction",
    )
    require(
        any("total-loss budget" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention total-loss budget",
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--allow-dirty", action="store_true")
    parser.add_argument("--expect-production-gate-result", choices=["passed", "failed", "not_run"])
    args = parser.parse_args()

    validate(
        args.evidence,
        allow_dirty=args.allow_dirty,
        expected_gate_result=args.expect_production_gate_result,
    )
    print(f"validated {args.evidence}")


if __name__ == "__main__":
    main()
