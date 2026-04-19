#!/usr/bin/env python3
"""Generate a machine-readable release-candidate evidence packet."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run_text(*command: str, cwd: Path = ROOT) -> str:
    completed = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        return f"unavailable: {' '.join(command)}"
    return completed.stdout.strip()


def read_json(relative_path: str) -> dict:
    with (ROOT / relative_path).open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{relative_path} root must be a JSON object")
    return value


def parse_regex(relative_path: str, pattern: str, label: str) -> str:
    text = (ROOT / relative_path).read_text(encoding="utf-8")
    match = re.search(pattern, text)
    if match is None:
        raise ValueError(f"{label} not found in {relative_path}")
    return match.group(1)


def artifact_version(schema_path: str) -> int:
    schema = read_json(schema_path)
    return int(schema["properties"]["artifactVersion"]["const"])


def schema_id(schema_path: str) -> str:
    return str(read_json(schema_path)["$id"])


def manifest_version(manifest_path: str) -> int:
    return int(read_json(manifest_path)["manifestVersion"])


def scoped_manifest_version(manifest_path: str) -> int:
    return int(read_json(manifest_path)["schemaVersion"])


def list_count(manifest_path: str, key: str) -> int:
    value = read_json(manifest_path)[key]
    if not isinstance(value, list):
        raise ValueError(f"{manifest_path} {key} must be a list")
    return len(value)


def sha256_hex(relative_path: str) -> str:
    return hashlib.sha256((ROOT / relative_path).read_bytes()).hexdigest()


def build_evidence(args: argparse.Namespace) -> dict:
    formal_dir = ROOT / "Formal"
    status_short = run_text("git", "status", "--short")
    dirty = bool(status_short)
    if dirty and not args.allow_dirty:
        raise SystemExit("working tree is dirty; pass --allow-dirty for non-release fixture evidence")

    formal_status = read_json("Docs/FormalStatus.json")
    blocker_groups = formal_status.get("blocker_groups", [])
    if not isinstance(blocker_groups, list):
        blocker_groups = []
    lowering_evidence = read_json("TestVectors/constant-time-lowering-evidence-v1.json")
    constant_time_release_evidence = str(lowering_evidence["releaseEvidenceManifest"])
    release_evidence = read_json(constant_time_release_evidence)
    observation_lane_reports = lowering_evidence.get("observationLaneReports", {})
    constant_time_compiler_observation_lanes = str(observation_lane_reports["compiler"])
    constant_time_hardware_observation_lanes = str(observation_lane_reports["hardware"])
    compiler_observation_lanes = read_json(constant_time_compiler_observation_lanes)
    hardware_observation_lanes = read_json(constant_time_hardware_observation_lanes)
    numiseal_mask_distribution_evidence = read_json("TestVectors/numiseal-zk-mask-distribution-evidence-v1.json")
    numiseal_zk_simulator_coupling_evidence = read_json(
        "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json"
    )
    product_crypto_security_dossier = read_json("TestVectors/product-crypto-security-dossier-v1.json")
    product_crypto_depth = product_crypto_security_dossier["supportedProductDepth"]
    product_selected_depth_loss = read_json("TestVectors/product-selected-depth-loss-accounting-v1.json")
    product_selected_depth = product_selected_depth_loss["selectedDepth"]
    product_swift_trace_extractor_evidence = read_json(
        "TestVectors/product-swift-trace-extractor-evidence-v1.json"
    )
    product_extractor_loss = read_json("TestVectors/product-extractor-loss-accounting-v1.json")
    product_qrom_accounting = read_json("TestVectors/product-qrom-fiat-shamir-accounting-v1.json")
    product_qrom_transcript_schedule = read_json("TestVectors/product-qrom-transcript-schedule-v1.json")
    product_qrom_sampler_encoding_evidence = read_json(
        "TestVectors/product-qrom-sampler-encoding-evidence-v1.json"
    )
    product_qrom_collision_malleability_evidence = read_json(
        "TestVectors/product-qrom-collision-malleability-evidence-v1.json"
    )
    product_qrom_ctco_instantiation = read_json("TestVectors/product-qrom-ctco-instantiation-v1.json")
    product_qrom_transform_preconditions = read_json("TestVectors/product-qrom-transform-preconditions-v1.json")
    product_qrom_interactive_reduction = read_json("TestVectors/product-qrom-interactive-reduction-v1.json")
    product_shared_bad_event_dedup = read_json("TestVectors/product-shared-bad-event-dedup-v1.json")
    product_total_loss_budget = read_json("TestVectors/product-total-loss-budget-v1.json")
    product_total_loss_computed = product_total_loss_budget["computedBudget"]
    product_release_distribution_evidence = read_json("TestVectors/product-release-distribution-evidence-v1.json")
    product_release_distribution_signing = product_release_distribution_evidence["signingStatus"]
    product_release_distribution_promotion = product_release_distribution_evidence["promotionRule"]

    return {
        "schemaVersion": 1,
        "generatedAtUTC": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "release": {
            "name": args.release_name,
            "class": "research-or-integration",
            "notes": args.notes,
        },
        "repository": {
            "root": str(ROOT),
            "commit": run_text("git", "rev-parse", "HEAD"),
            "branch": run_text("git", "rev-parse", "--abbrev-ref", "HEAD"),
            "remoteURL": run_text("git", "config", "--get", "remote.origin.url"),
            "dirty": dirty,
            "statusShort": status_short.splitlines(),
        },
        "toolchain": {
            "swift": run_text("swift", "--version").splitlines()[0],
            "lean": run_text("lean", "--version", cwd=formal_dir).splitlines()[0],
            "lake": run_text("lake", "--version", cwd=formal_dir).splitlines()[0],
        },
        "productionGate": {
            "command": args.production_gate_command,
            "result": args.production_gate_result,
        },
        "publicSurfaces": {
            "r1csArtifactVersion": artifact_version("TestVectors/artifact.schema.json"),
            "r1csSchemaID": schema_id("TestVectors/artifact.schema.json"),
            "r1csManifestVersion": manifest_version("TestVectors/manifest.json"),
            "numiSealArtifactVersion": artifact_version("TestVectors/numiseal-artifact.schema.json"),
            "numiSealSchemaID": schema_id("TestVectors/numiseal-artifact.schema.json"),
            "numiSealManifestVersion": manifest_version("TestVectors/numiseal-manifest.json"),
            "numiSealConformanceScopeVersion": int(read_json("TestVectors/numiseal-conformance-scope-v1.json")["schemaVersion"]),
            "numiSealConformanceScopeDigestHex": sha256_hex("TestVectors/numiseal-conformance-scope-v1.json"),
            "numiSealEndToEndTheoremScopeVersion": int(
                read_json("TestVectors/numiseal-end-to-end-theorem-scope-v1.json")["schemaVersion"]
            ),
            "numiSealEndToEndTheoremScopeDigestHex": sha256_hex(
                "TestVectors/numiseal-end-to-end-theorem-scope-v1.json"
            ),
            "numiSealEndToEndTheoremScopeClaimStatus": str(
                read_json("TestVectors/numiseal-end-to-end-theorem-scope-v1.json")["claimStatus"]
            ),
            "numiSealZKMaskDistributionEvidenceVersion": int(
                numiseal_mask_distribution_evidence["schemaVersion"]
            ),
            "numiSealZKMaskDistributionEvidenceDigestHex": sha256_hex(
                "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json"
            ),
            "numiSealZKMaskDistributionEvidenceClaimStatus": str(
                numiseal_mask_distribution_evidence["claimStatus"]
            ),
            "numiSealZKSimulatorCouplingEvidenceVersion": int(
                numiseal_zk_simulator_coupling_evidence["schemaVersion"]
            ),
            "numiSealZKSimulatorCouplingEvidenceDigestHex": sha256_hex(
                "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json"
            ),
            "numiSealZKSimulatorCouplingEvidenceClaimStatus": str(
                numiseal_zk_simulator_coupling_evidence["claimStatus"]
            ),
            "productCryptoSecurityDossierVersion": int(
                product_crypto_security_dossier["schemaVersion"]
            ),
            "productCryptoSecurityDossierDigestHex": sha256_hex(
                "TestVectors/product-crypto-security-dossier-v1.json"
            ),
            "productCryptoSecurityDossierClaimStatus": str(
                product_crypto_security_dossier["claimStatus"]
            ),
            "productCryptoSecurityDossierDepthModel": str(product_crypto_depth["depthModel"]),
            "productCryptoSecurityDossierMaximumDepth": int(
                product_crypto_depth["theoremMaximumDepth"]
            ),
            "productSelectedDepthLossAccountingVersion": int(
                product_selected_depth_loss["schemaVersion"]
            ),
            "productSelectedDepthLossAccountingDigestHex": sha256_hex(
                "TestVectors/product-selected-depth-loss-accounting-v1.json"
            ),
            "productSelectedDepthLossAccountingClaimStatus": str(
                product_selected_depth_loss["claimStatus"]
            ),
            "productSelectedDepthLossAccountingMaximumDepth": int(
                product_selected_depth["selectedMaximumDepth"]
            ),
            "productSelectedDepthLossComponentCount": list_count(
                "TestVectors/product-selected-depth-loss-accounting-v1.json",
                "componentLosses",
            ),
            "productSwiftTraceExtractorEvidenceVersion": int(
                product_swift_trace_extractor_evidence["schemaVersion"]
            ),
            "productSwiftTraceExtractorEvidenceDigestHex": sha256_hex(
                "TestVectors/product-swift-trace-extractor-evidence-v1.json"
            ),
            "productSwiftTraceExtractorEvidenceClaimStatus": str(
                product_swift_trace_extractor_evidence["claimStatus"]
            ),
            "productExtractorLossAccountingVersion": int(
                product_extractor_loss["schemaVersion"]
            ),
            "productExtractorLossAccountingDigestHex": sha256_hex(
                "TestVectors/product-extractor-loss-accounting-v1.json"
            ),
            "productExtractorLossAccountingClaimStatus": str(
                product_extractor_loss["claimStatus"]
            ),
            "productExtractorLossComponentCount": list_count(
                "TestVectors/product-extractor-loss-accounting-v1.json",
                "componentLosses",
            ),
            "productQROMFiatShamirAccountingVersion": int(
                product_qrom_accounting["schemaVersion"]
            ),
            "productQROMFiatShamirAccountingDigestHex": sha256_hex(
                "TestVectors/product-qrom-fiat-shamir-accounting-v1.json"
            ),
            "productQROMFiatShamirAccountingClaimStatus": str(
                product_qrom_accounting["claimStatus"]
            ),
            "productQROMFiatShamirTranscriptInterfaceCount": list_count(
                "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
                "transcriptInterfaces",
            ),
            "productQROMTranscriptScheduleVersion": int(
                product_qrom_transcript_schedule["schemaVersion"]
            ),
            "productQROMTranscriptScheduleDigestHex": sha256_hex(
                "TestVectors/product-qrom-transcript-schedule-v1.json"
            ),
            "productQROMTranscriptScheduleClaimStatus": str(
                product_qrom_transcript_schedule["claimStatus"]
            ),
            "productQROMTranscriptScheduleEntryCount": list_count(
                "TestVectors/product-qrom-transcript-schedule-v1.json",
                "scheduleEntries",
            ),
            "productQROMSamplerEncodingEvidenceVersion": int(
                product_qrom_sampler_encoding_evidence["schemaVersion"]
            ),
            "productQROMSamplerEncodingEvidenceDigestHex": sha256_hex(
                "TestVectors/product-qrom-sampler-encoding-evidence-v1.json"
            ),
            "productQROMSamplerEncodingEvidenceClaimStatus": str(
                product_qrom_sampler_encoding_evidence["claimStatus"]
            ),
            "productQROMSamplerEncodingEvidenceUniformityPinned": bool(
                product_qrom_sampler_encoding_evidence["samplerUniformity"][
                    "samplerUniformityProofPinned"
                ]
            ),
            "productQROMSamplerEncodingEvidenceStructuredFrameInjective": bool(
                product_qrom_sampler_encoding_evidence["transcriptEncoding"][
                    "structuredFrameInjective"
                ]
            ),
            "productQROMCollisionMalleabilityEvidenceVersion": int(
                product_qrom_collision_malleability_evidence["schemaVersion"]
            ),
            "productQROMCollisionMalleabilityEvidenceDigestHex": sha256_hex(
                "TestVectors/product-qrom-collision-malleability-evidence-v1.json"
            ),
            "productQROMCollisionMalleabilityEvidenceClaimStatus": str(
                product_qrom_collision_malleability_evidence["claimStatus"]
            ),
            "productQROMCollisionMalleabilityStructuralClosurePinned": bool(
                product_qrom_collision_malleability_evidence["closureStatus"][
                    "structuralCollisionMalleabilityExcludedOutsideDigestCollision"
                ]
            ),
            "productQROMCollisionMalleabilityDigestBoundInstantiated": bool(
                product_qrom_collision_malleability_evidence["closureStatus"][
                    "digestCollisionBoundInstantiated"
                ]
            ),
            "productQROMCTCOInstantiationVersion": int(
                product_qrom_ctco_instantiation["schemaVersion"]
            ),
            "productQROMCTCOInstantiationDigestHex": sha256_hex(
                "TestVectors/product-qrom-ctco-instantiation-v1.json"
            ),
            "productQROMCTCOInstantiationClaimStatus": str(
                product_qrom_ctco_instantiation["claimStatus"]
            ),
            "productQROMCTCOBindingDigestBits": int(
                product_qrom_ctco_instantiation["numericBounds"]["bindingDigestBits"]
            ),
            "productQROMCTCOBindingCollisionBoundLog2Floor": int(
                product_qrom_ctco_instantiation["numericBounds"]["bindingCollisionBoundLog2Floor"]
            ),
            "productQROMTransformPreconditionsVersion": int(
                product_qrom_transform_preconditions["schemaVersion"]
            ),
            "productQROMTransformPreconditionsDigestHex": sha256_hex(
                "TestVectors/product-qrom-transform-preconditions-v1.json"
            ),
            "productQROMTransformPreconditionsClaimStatus": str(
                product_qrom_transform_preconditions["claimStatus"]
            ),
            "productQROMTransformPreconditionCount": list_count(
                "TestVectors/product-qrom-transform-preconditions-v1.json",
                "preconditions",
            ),
            "productQROMInteractiveReductionVersion": int(
                product_qrom_interactive_reduction["schemaVersion"]
            ),
            "productQROMInteractiveReductionDigestHex": sha256_hex(
                "TestVectors/product-qrom-interactive-reduction-v1.json"
            ),
            "productQROMInteractiveReductionClaimStatus": str(
                product_qrom_interactive_reduction["claimStatus"]
            ),
            "productQROMInteractiveReductionProofKindCount": list_count(
                "TestVectors/product-qrom-interactive-reduction-v1.json",
                "proofKindProtocols",
            ),
            "productSharedBadEventDedupVersion": int(
                product_shared_bad_event_dedup["schemaVersion"]
            ),
            "productSharedBadEventDedupDigestHex": sha256_hex(
                "TestVectors/product-shared-bad-event-dedup-v1.json"
            ),
            "productSharedBadEventDedupClaimStatus": str(
                product_shared_bad_event_dedup["claimStatus"]
            ),
            "productSharedBadEventDedupTagCount": list_count(
                "TestVectors/product-shared-bad-event-dedup-v1.json",
                "sharedCoreTags",
            ),
            "productSharedBadEventDedupCoreBoundLog2": int(
                product_shared_bad_event_dedup["deduplicationRule"]["sharedCoreBoundLog2"]
            ),
            "productTotalLossBudgetVersion": int(
                product_total_loss_budget["schemaVersion"]
            ),
            "productTotalLossBudgetDigestHex": sha256_hex(
                "TestVectors/product-total-loss-budget-v1.json"
            ),
            "productTotalLossBudgetClaimStatus": str(
                product_total_loss_budget["claimStatus"]
            ),
            "productTotalLossBudgetComponentCount": list_count(
                "TestVectors/product-total-loss-budget-v1.json",
                "componentBounds",
            ),
            "productTotalLossBudgetRequiredTermCount": int(
                product_total_loss_computed["requiredTermCount"]
            ),
            "productTotalLossBudgetInstantiatedRequiredTermCount": int(
                product_total_loss_computed["instantiatedRequiredTermCount"]
            ),
            "productTotalLossBudgetWithinBudget": bool(
                product_total_loss_computed["selectedDepthLossWithinBudget"]
            ),
            "productReleaseDistributionEvidenceVersion": int(
                product_release_distribution_evidence["schemaVersion"]
            ),
            "productReleaseDistributionEvidenceDigestHex": sha256_hex(
                "TestVectors/product-release-distribution-evidence-v1.json"
            ),
            "productReleaseDistributionEvidenceClaimStatus": str(
                product_release_distribution_evidence["claimStatus"]
            ),
            "productReleaseDistributionSigningKeySelected": bool(
                product_release_distribution_signing["releaseSigningKeySelected"]
            ),
            "productReleaseDistributionLossInstantiated": bool(
                product_release_distribution_signing["releaseDistributionLossInstantiated"]
            ),
            "productReleaseDistributionProductionClaimAllowed": bool(
                product_release_distribution_promotion["productionReleaseDistributionClaimAllowed"]
            ),
            "constantTimeScopeVersion": int(read_json("TestVectors/constant-time-scope-v1.json")["schemaVersion"]),
            "constantTimeScopeDigestHex": sha256_hex("TestVectors/constant-time-scope-v1.json"),
            "constantTimeLoweringEvidenceVersion": int(lowering_evidence["schemaVersion"]),
            "constantTimeLoweringEvidenceDigestHex": sha256_hex("TestVectors/constant-time-lowering-evidence-v1.json"),
            "constantTimeLoweringEvidenceClaimStatus": str(lowering_evidence["claimStatus"]),
            "constantTimeReleaseEvidenceVersion": int(release_evidence["schemaVersion"]),
            "constantTimeReleaseEvidenceDigestHex": sha256_hex(constant_time_release_evidence),
            "constantTimeReleaseEvidenceClaimStatus": str(release_evidence["claimStatus"]),
            "constantTimeCompilerObservationLanesVersion": int(compiler_observation_lanes["schemaVersion"]),
            "constantTimeCompilerObservationLanesDigestHex": sha256_hex(constant_time_compiler_observation_lanes),
            "constantTimeCompilerObservationLanesClaimStatus": str(compiler_observation_lanes["claimStatus"]),
            "constantTimeHardwareObservationLanesVersion": int(hardware_observation_lanes["schemaVersion"]),
            "constantTimeHardwareObservationLanesDigestHex": sha256_hex(constant_time_hardware_observation_lanes),
            "constantTimeHardwareObservationLanesClaimStatus": str(hardware_observation_lanes["claimStatus"]),
            "e2eProofMetricsVersion": scoped_manifest_version("TestVectors/e2e-proof-metrics-v1.json"),
            "e2eProofMetricsDigestHex": sha256_hex("TestVectors/e2e-proof-metrics-v1.json"),
            "e2eProofMetricsTrackedArtifactCount": list_count("TestVectors/e2e-proof-metrics-v1.json", "trackedArtifacts"),
            "e2eProofMetricsGeneratedBudgetCount": list_count("TestVectors/e2e-proof-metrics-v1.json", "generatedProductBudgets"),
            "benchmarkCoverageVersion": int(read_json("TestVectors/benchmark-coverage-v1.json")["schemaVersion"]),
            "benchmarkCoverageDigestHex": sha256_hex("TestVectors/benchmark-coverage-v1.json"),
            "benchmarkCoverageSurfaceCount": list_count("TestVectors/benchmark-coverage-v1.json", "requiredSurfaces"),
            "productOperationsStatusVersion": int(
                parse_regex(
                    "SuperNeo-NuMetal/ProductIntegration/LocalProductControls.swift",
                    r"public\s+static\s+let\s+formatVersion\s*=\s*(\d+)",
                    "SuperNeoProductOperationsStatus.formatVersion",
                )
            ),
            "proofEnvelopeHeaderVersion": int(
                parse_regex(
                    "SuperNeo-NuMetal/SuperNeoSerialization.swift",
                    r"public\s+static\s+let\s+version:\s*UInt16\s*=\s*(\d+)",
                    "ProofEnvelopeHeader.version",
                )
            ),
            "numiSealProofEnvelopeKind": int(
                parse_regex(
                    "SuperNeo-NuMetal/SuperNeoSerialization.swift",
                    r"case\s+numiSealTerminal\s*=\s*(\d+)",
                    "ProofEnvelopeKind.numiSealTerminal",
                )
            ),
        },
        "documentation": {
            "auditPacket": "Docs/ProductionReadinessAuditPacket-2026-04-16.md",
            "releaseEngineering": "Docs/ReleaseEngineering-2026-04-16.md",
            "schemaCompatibility": "Docs/SchemaCompatibility-2026-04-16.md",
            "numiSealConformanceScope": "TestVectors/numiseal-conformance-scope-v1.json",
            "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
            "numiSealZKMaskDistributionEvidence": "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
            "numiSealZKSimulatorCouplingEvidence": "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
            "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
            "productCryptoSecurityDossierPolicy": "Docs/CryptographicSecurityDossier-2026-04-16.md",
            "productSelectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
            "productSwiftTraceExtractorEvidence": "TestVectors/product-swift-trace-extractor-evidence-v1.json",
            "productExtractorLossAccounting": "TestVectors/product-extractor-loss-accounting-v1.json",
            "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
            "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
            "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            "productQROMCTCOInstantiation": "TestVectors/product-qrom-ctco-instantiation-v1.json",
            "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
            "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
            "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
            "productReleaseDistributionEvidence": "TestVectors/product-release-distribution-evidence-v1.json",
            "constantTimeEvidence": "Docs/ConstantTimeEvidence-2026-04-16.md",
            "constantTimeScope": "TestVectors/constant-time-scope-v1.json",
            "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
            "constantTimeReleaseEvidence": constant_time_release_evidence,
            "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
            "e2eProofMetricsPolicy": "Docs/E2EProofMetrics-2026-04-16.md",
            "benchmarkCoverage": "TestVectors/benchmark-coverage-v1.json",
            "benchmarkCoveragePolicy": "Docs/Benchmarking.md",
            "productOperationsReadiness": "Docs/ProductOperationsReadiness-2026-04-16.md",
            "releaseRunbook": "Docs/ReleaseCandidateRunbook-2026-04-16.md",
            "changelog": "CHANGELOG.md",
        },
        "formalStatus": {
            "claim": formal_status.get("formal_status", "unknown"),
            "blockerGroups": blocker_groups,
        },
        "signing": {
            "status": "unsigned_research_artifact",
            "signedArtifactsRequiredForProductionSecurity": True,
            "releaseDistributionEvidenceManifest": "TestVectors/product-release-distribution-evidence-v1.json",
            "releaseDistributionEvidenceDigestHex": sha256_hex(
                "TestVectors/product-release-distribution-evidence-v1.json"
            ),
            "releaseDistributionClaimStatus": str(product_release_distribution_evidence["claimStatus"]),
            "releaseSigningKeySelected": bool(
                product_release_distribution_signing["releaseSigningKeySelected"]
            ),
            "releaseDistributionLossInstantiated": bool(
                product_release_distribution_signing["releaseDistributionLossInstantiated"]
            ),
            "productionReleaseDistributionClaimAllowed": bool(
                product_release_distribution_promotion["productionReleaseDistributionClaimAllowed"]
            ),
        },
        "productionSecurityBoundaries": [
            "A conditional source/formal constant-time trace scope and Swift/LLVM/Metal lowering proof contract are recorded; local Swift SIL/LLVM/assembly artifacts, Metal AIR/metallib artifacts, runtime allocation/COW review, CPU/GPU smoke corpora, and compiler/hardware observation lane reports are pinned, while scoped emitted-code review, hardware counters, power/contention, and broader device lanes remain explicit evidence boundaries.",
            "E2E proof-size budgets are checked for deterministic vectors and local product smokes; whole-stack benchmark row coverage is checked, but hardware latency claims still require fresh benchmark evidence.",
            "Local product-ops readiness and signed revocation-feed verification are machine-readable and audit-exported; no hosted product replay-protection, provenance, persistence, revocation-distribution, or access-control service is recorded.",
            "NumiSeal product, carry, and ZK formalization has a checked evidence-parametric end-to-end theorem scope, exact rejection-sampled field mask distribution evidence, proof-level ZK simulator coupling with epsilon_zk_sim = 0 under declared leakage, a selected-depth loss-accounting ledger, selected-depth concrete extractor loss accounting with epsilon_extract = 0, QROM Fiat-Shamir accounting with explicit collision mapping and an instantiated conditional Q_H = 2^64 query cap, a QROM transcript schedule, conditional QROM sampler/encoding evidence under the QRO abstraction, QROM collision/malleability structural evidence, QROM transform preconditions, a QROM interactive reduction ledger with code-enforced NumiSeal challenge maxima, shared-core bad-event deduplication, a total-loss budget contract, a product release distribution evidence contract, and a product cryptographic security dossier pinned to bounded depth 1; recursive product carry flow beyond selected depth, side-channel evidence, post-quantum parameter tightening, hosted operations, release signing, notarization/publication proof, publication protection evidence, archived release evidence, and remaining numeric loss instantiations remain production-security boundaries.",
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Write evidence JSON to this path instead of stdout.")
    parser.add_argument("--release-name", default="unreleased-research-candidate")
    parser.add_argument(
        "--production-gate-result",
        choices=["passed", "failed", "not_run"],
        default="not_run",
    )
    parser.add_argument("--production-gate-command", default="Scripts/production-gate.sh")
    parser.add_argument("--notes", default="")
    parser.add_argument("--allow-dirty", action="store_true")
    args = parser.parse_args()

    evidence = build_evidence(args)
    encoded = json.dumps(evidence, indent=2, sort_keys=True) + "\n"
    if args.output is None:
        sys.stdout.write(encoded)
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
        print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
