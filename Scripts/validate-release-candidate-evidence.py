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

    toolchain = require_dict(evidence.get("toolchain"), "toolchain")
    for key in ("swift", "lean", "lake"):
        value = require_string(toolchain.get(key), f"toolchain.{key}")
        require(not value.startswith("unavailable:"), f"toolchain.{key} must record the actual tool version")

    surfaces = require_dict(evidence.get("publicSurfaces"), "publicSurfaces")
    require(require_int(surfaces.get("r1csArtifactVersion"), "r1csArtifactVersion") == 1, "R1CS artifact version must be 1")
    require(require_int(surfaces.get("r1csManifestVersion"), "r1csManifestVersion") == 1, "R1CS manifest version must be 1")
    require(
        require_int(surfaces.get("numiSealProductArtifactVersion"), "numiSealProductArtifactVersion") == 2,
        "NumiSeal product artifact version must be 2",
    )
    require_hex_digest(
        surfaces.get("numiSealProductSchemaDigestHex"),
        "numiSealProductSchemaDigestHex",
    )
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
            surfaces.get("numiSealZKSimulatorCouplingEvidenceVersion"),
            "numiSealZKSimulatorCouplingEvidenceVersion",
        ) == 1,
        "NumiSealZK simulator-coupling evidence version must be 1",
    )
    require_hex_digest(
        surfaces.get("numiSealZKSimulatorCouplingEvidenceDigestHex"),
        "numiSealZKSimulatorCouplingEvidenceDigestHex",
    )
    require(
        require_string(
            surfaces.get("numiSealZKSimulatorCouplingEvidenceClaimStatus"),
            "numiSealZKSimulatorCouplingEvidenceClaimStatus",
        ) == "proof-level-simulator-coupling-instantiated-repository-local-production-zk-privacy",
        "NumiSealZK simulator-coupling evidence claim status must stay precise",
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
        ) == "selected-depth-loss-contract-repository-local-selected-depth-claim",
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
        ) == 11,
        "product selected-depth loss accounting must pin eleven component losses",
    )
    require(
        require_int(
            surfaces.get("productSwiftTraceExtractorEvidenceVersion"),
            "productSwiftTraceExtractorEvidenceVersion",
        ) == 1,
        "product Swift trace/extractor evidence version must be 1",
    )
    require_hex_digest(
        surfaces.get("productSwiftTraceExtractorEvidenceDigestHex"),
        "productSwiftTraceExtractorEvidenceDigestHex",
    )
    require(
        require_string(
            surfaces.get("productSwiftTraceExtractorEvidenceClaimStatus"),
            "productSwiftTraceExtractorEvidenceClaimStatus",
        ) == "swift-executable-trace-surface-pinned-repository-local-production-extractor-theorem",
        "product Swift trace/extractor evidence claim status must stay precise",
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
        ) == "selected-depth-concrete-extractor-loss-instantiated-repository-local-production-claim",
        "product extractor loss accounting claim status must record selected-depth instantiation",
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
            surfaces.get("productQROMPublicCoinAccountingVersion"),
            "productQROMPublicCoinAccountingVersion",
        ) == 1,
        "product QROM public-coin accounting version must be 1",
    )
    require_string(
        surfaces.get("productQROMPublicCoinAccountingDigestHex"),
        "productQROMPublicCoinAccountingDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMPublicCoinAccountingClaimStatus"),
            "productQROMPublicCoinAccountingClaimStatus",
        ) == "qrom-ctco-split-qro-contract-repository-local-production-claim",
        "product QROM public-coin accounting claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMPublicCoinTranscriptInterfaceCount"),
            "productQROMPublicCoinTranscriptInterfaceCount",
        ) == 5,
        "product QROM public-coin accounting must pin five transcript interfaces",
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
        ) == "qrom-transcript-schedule-contract-repository-local-production-claim",
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
            surfaces.get("productQROMSamplerEncodingEvidenceVersion"),
            "productQROMSamplerEncodingEvidenceVersion",
        ) == 1,
        "product QROM sampler/encoding evidence version must be 1",
    )
    require_hex_digest(
        surfaces.get("productQROMSamplerEncodingEvidenceDigestHex"),
        "productQROMSamplerEncodingEvidenceDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMSamplerEncodingEvidenceClaimStatus"),
            "productQROMSamplerEncodingEvidenceClaimStatus",
        ) == "qrom-sampler-encoding-evidence-repository-local-production-qrom-theorem",
        "product QROM sampler/encoding evidence claim status must stay precise",
    )
    require(
        surfaces.get("productQROMSamplerEncodingEvidenceUniformityPinned") is True,
        "product QROM sampler/encoding evidence must pin sampler uniformity under the QRO abstraction",
    )
    require(
        surfaces.get("productQROMSamplerEncodingEvidenceStructuredFrameInjective") is True,
        "product QROM sampler/encoding evidence must pin structured-frame injectivity",
    )
    require(
        require_int(
            surfaces.get("productQROMCollisionMalleabilityEvidenceVersion"),
            "productQROMCollisionMalleabilityEvidenceVersion",
        ) == 1,
        "product QROM collision/malleability evidence version must be 1",
    )
    require_hex_digest(
        surfaces.get("productQROMCollisionMalleabilityEvidenceDigestHex"),
        "productQROMCollisionMalleabilityEvidenceDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMCollisionMalleabilityEvidenceClaimStatus"),
            "productQROMCollisionMalleabilityEvidenceClaimStatus",
        ) == "qrom-collision-malleability-hbind-bound-repository-local-production-qrom-theorem",
        "product QROM collision/malleability evidence claim status must stay precise",
    )
    require(
        surfaces.get("productQROMCollisionMalleabilityStructuralClosurePinned") is True,
        "product QROM collision/malleability evidence must pin structural closure",
    )
    require(
        surfaces.get("productQROMCollisionMalleabilityDigestBoundInstantiated") is True,
        "product QROM collision/malleability evidence must pin the instantiated digest bound",
    )
    require(
        require_int(
            surfaces.get("productQROMCTCOInstantiationVersion"),
            "productQROMCTCOInstantiationVersion",
        ) == 1,
        "product QROM CTCO instantiation version must be 1",
    )
    require_hex_digest(
        surfaces.get("productQROMCTCOInstantiationDigestHex"),
        "productQROMCTCOInstantiationDigestHex",
    )
    require(
        require_string(
            surfaces.get("productQROMCTCOInstantiationClaimStatus"),
            "productQROMCTCOInstantiationClaimStatus",
        ) == "ctco-split-oracle-instantiation-pinned-repository-local-production-qrom-theorem",
        "product QROM CTCO instantiation claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMCTCOBindingDigestBits"),
            "productQROMCTCOBindingDigestBits",
        ) == 384,
        "product QROM CTCO binding digest width must be 384",
    )
    require(
        require_int(
            surfaces.get("productQROMCTCOBindingCollisionBoundLog2Floor"),
            "productQROMCTCOBindingCollisionBoundLog2Floor",
        ) == 250,
        "product QROM CTCO binding collision bound floor must be 250",
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
        ) == "qrom-ctco-transform-precondition-contract-repository-local-production-claim",
        "product QROM transform preconditions claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productQROMTransformPreconditionCount"),
            "productQROMTransformPreconditionCount",
        ) == 12,
        "product QROM transform preconditions must pin twelve preconditions",
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
        ) == "qrom-ctco-interactive-reduction-contract-repository-local-production-claim",
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
            surfaces.get("productSharedBadEventDedupVersion"),
            "productSharedBadEventDedupVersion",
        ) == 1,
        "product shared bad-event dedup version must be 1",
    )
    require_hex_digest(
        surfaces.get("productSharedBadEventDedupDigestHex"),
        "productSharedBadEventDedupDigestHex",
    )
    require(
        require_string(
            surfaces.get("productSharedBadEventDedupClaimStatus"),
            "productSharedBadEventDedupClaimStatus",
        ) == "shared-bad-event-dedup-pinned-repository-local-production-total-loss-claim",
        "product shared bad-event dedup claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productSharedBadEventDedupTagCount"),
            "productSharedBadEventDedupTagCount",
        ) == 2,
        "product shared bad-event dedup must pin two shared-core tags",
    )
    require(
        require_int(
            surfaces.get("productSharedBadEventDedupCoreBoundLog2"),
            "productSharedBadEventDedupCoreBoundLog2",
        ) == 129,
        "product shared bad-event dedup must pin the 2^-129 shared-core bound",
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
        ) == "total-loss-budget-contract-repository-local-selected-depth-claim",
        "product total-loss budget claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetComponentCount"),
            "productTotalLossBudgetComponentCount",
        ) == 11,
        "product total-loss budget must pin eleven component bounds",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetRequiredTermCount"),
            "productTotalLossBudgetRequiredTermCount",
        ) == 7,
        "product total-loss budget must require seven repository-local selected-depth terms",
    )
    require(
        require_int(
            surfaces.get("productTotalLossBudgetInstantiatedRequiredTermCount"),
            "productTotalLossBudgetInstantiatedRequiredTermCount",
        ) == 7,
        "product total-loss budget must instantiate every repository-local selected-depth term",
    )
    require(
        surfaces.get("productTotalLossBudgetWithinBudget") is True,
        "product total-loss budget must claim the selected loss is within budget",
    )
    require(
        require_int(
            surfaces.get("productReleaseDistributionEvidenceVersion"),
            "productReleaseDistributionEvidenceVersion",
        ) == 1,
        "product release distribution evidence version must be 1",
    )
    require_hex_digest(
        surfaces.get("productReleaseDistributionEvidenceDigestHex"),
        "productReleaseDistributionEvidenceDigestHex",
    )
    require(
        require_string(
            surfaces.get("productReleaseDistributionEvidenceClaimStatus"),
            "productReleaseDistributionEvidenceClaimStatus",
        ) == "repository-local-release-distribution-evidence",
        "product release distribution evidence claim status must stay precise",
    )
    require(
        surfaces.get("productReleaseDistributionRepositoryLocalUnsignedAllowed") is True,
        "product release distribution evidence must allow repository-local unsigned distribution",
    )
    require(
        surfaces.get("productReleaseDistributionLossInstantiated") is True,
        "product release distribution evidence must instantiate repository-local release distribution loss",
    )
    require(
        surfaces.get("productReleaseDistributionProductionClaimAllowed") is True,
        "product release distribution evidence must allow repository-local production release claims",
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
        ) == "compiler-lowering-review-complete-hardware-open",
        "constant-time compiler observation lanes claim status must stay precise",
    )
    require(
        require_int(
            surfaces.get("constantTimeCompilerLoweringAuditVersion"),
            "constantTimeCompilerLoweringAuditVersion",
        ) == 1,
        "constant-time compiler lowering audit version must be 1",
    )
    require_string(
        surfaces.get("constantTimeCompilerLoweringAuditDigestHex"),
        "constantTimeCompilerLoweringAuditDigestHex",
    )
    require(
        require_string(
            surfaces.get("constantTimeCompilerLoweringAuditClaimStatus"),
            "constantTimeCompilerLoweringAuditClaimStatus",
        ) == "scoped-compiler-lowering-review-complete",
        "constant-time compiler lowering audit claim status must stay precise",
    )
    require(
        surfaces.get("constantTimeCompilerLoweringReviewComplete") is True,
        "constant-time compiler lowering audit must be marked complete",
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
        require_int(surfaces.get("e2eProofMetricsTrackedArtifactCount"), "e2eProofMetricsTrackedArtifactCount") >= 5,
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
    require(require_int(surfaces.get("proofEnvelopeHeaderVersion"), "proofEnvelopeHeaderVersion") == 5, "proof envelope version must be 5")
    require(require_int(surfaces.get("numiSealProofEnvelopeKind"), "numiSealProofEnvelopeKind") == 4, "NumiSeal envelope kind must be 4")
    require_string(surfaces.get("r1csSchemaID"), "r1csSchemaID")

    documentation = require_dict(evidence.get("documentation"), "documentation")
    for key in [
        "auditPacket",
        "releaseEngineering",
        "schemaCompatibility",
        "numiSealConformanceScope",
        "numiSealEndToEndTheoremScope",
        "numiSealZKMaskDistributionEvidence",
        "numiSealZKSimulatorCouplingEvidence",
        "productCryptoSecurityDossier",
        "productCryptoSecurityDossierPolicy",
        "productSelectedDepthLossAccounting",
        "productSwiftTraceExtractorEvidence",
        "productExtractorLossAccounting",
        "productQROMPublicCoinAccounting",
        "productQROMTranscriptSchedule",
        "productQROMSamplerEncodingEvidence",
        "productQROMCollisionMalleabilityEvidence",
        "productQROMCTCOInstantiation",
        "productQROMTransformPreconditions",
        "productQROMInteractiveReduction",
        "productTotalLossBudget",
        "productReleaseDistributionEvidence",
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
    require(signing.get("status") == "unsigned_repository_local_artifact", "signing.status must remain explicit")
    require(
        signing.get("signedArtifactsRequiredForProductionSecurity") is False,
        "repository-local production must not require external artifact signing",
    )
    require(
        signing.get("releaseDistributionEvidenceManifest") == "TestVectors/product-release-distribution-evidence-v1.json",
        "signing must link product release distribution evidence",
    )
    require_hex_digest(
        signing.get("releaseDistributionEvidenceDigestHex"),
        "signing.releaseDistributionEvidenceDigestHex",
    )
    require(
        signing.get("releaseDistributionEvidenceDigestHex")
        == surfaces.get("productReleaseDistributionEvidenceDigestHex"),
        "signing release distribution digest must match public surface digest",
    )
    require(
        signing.get("releaseDistributionClaimStatus") == "repository-local-release-distribution-evidence",
        "signing.releaseDistributionClaimStatus must stay precise",
    )
    require(
        signing.get("repositoryLocalUnsignedDistributionAllowed") is True,
        "signing.repositoryLocalUnsignedDistributionAllowed must be true",
    )
    require(
        signing.get("releaseDistributionLossInstantiated") is True,
        "signing.releaseDistributionLossInstantiated must be true",
    )
    require(
        signing.get("productionReleaseDistributionClaimAllowed") is True,
        "signing.productionReleaseDistributionClaimAllowed must be true",
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
        any("qrom public-coin accounting" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM public-coin accounting",
    )
    require(
        any("qrom transcript schedule" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM transcript schedule",
    )
    require(
        any("qrom sampler/encoding evidence" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM sampler/encoding evidence",
    )
    require(
        any("qrom collision/malleability structural evidence" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention QROM collision/malleability structural evidence",
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
    require(
        any("release distribution evidence" in str(boundary).lower() for boundary in boundaries),
        "productionSecurityBoundaries must mention release distribution evidence",
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
