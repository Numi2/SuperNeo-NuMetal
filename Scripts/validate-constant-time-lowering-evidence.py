#!/usr/bin/env python3
"""Validate the Swift/LLVM/Metal constant-time lowering evidence contract."""

from __future__ import annotations

import json
import hashlib
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "TestVectors" / "constant-time-lowering-evidence-v1.json"
SCOPE_MANIFEST = ROOT / "TestVectors" / "constant-time-scope-v1.json"
REQUIRED_BOUNDARY_IDS = {
    "swift-llvm-goldilocks-arithmetic",
    "metal-air-goldilocks-arithmetic",
    "metal-air-numiseal-zk-kernels",
    "runtime-and-hardware-tcb",
}
REQUIRED_STATUS = {
    "required-before-production-ct-claim",
    "tcb-assumption-recorded",
    "local-release-artifacts-pinned",
    "local-observation-corpus-pinned",
}
REQUIRED_RELEASE_EVIDENCE_IDS = {
    "swift-optimized-sil",
    "swift-optimized-llvm-ir",
    "swift-target-assembly",
    "swift-compiler-artifact-report",
    "metal-air",
    "metal-metallib",
    "metal-artifact-report",
    "runtime-allocation-review",
    "cpu-observation-corpus",
    "gpu-observation-corpus",
    "compiler-observation-lanes",
    "hardware-observation-lanes",
}
REQUIRED_GPU_OPERATIONS = {
    "numiseal_apply_mask_kernel",
    "numiseal_dense_fold_kernel",
    "numiseal_eq_weight_kernel",
    "numiseal_sumcheck_accumulate_kernel",
    "numiseal_mask_accumulate_kernel",
}
REQUIRED_COMPILER_LANE_IDS = {
    "swift-llvm-goldilocks-arithmetic",
    "metal-air-goldilocks-arithmetic",
    "metal-air-numiseal-zk-kernels",
}
REQUIRED_COMPILER_LANE_STATUS = {
    "source-runtime-review-pinned-lowering-artifacts-required",
    "local-sil-llvm-assembly-pinned-review-required",
    "local-air-and-metallib-pinned-disassembly-required",
}
REQUIRED_HARDWARE_LANE_IDS = {
    "cpu-wall-clock-zk-high-assurance",
    "gpu-direct-metal-kernel-observation",
    "power-contention-scheduler-boundary",
}
REQUIRED_HARDWARE_LANE_STATUS = {
    "local-wall-clock-smoke-pinned",
    "local-direct-metal-smoke-pinned",
    "required-before-production-ct-claim",
}


def fail(message: str) -> None:
    print(f"constant-time lowering evidence validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a non-empty list")
    result: list[str] = []
    for index, item in enumerate(value):
        require(isinstance(item, str) and item, f"{label}[{index}] must be a non-empty string")
        result.append(item)
    return result


def path_label(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def sha256_hex(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path_label(path)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path_label(path)} root must be an object")
    return value


def resolve_manifest_path(value: Any, label: str) -> Path:
    raw = require_string(value, label)
    path = Path(raw)
    if not path.is_absolute():
        path = ROOT / path
    require(path.exists(), f"{label} does not exist: {raw}")
    return path


def require_relative_artifact_path(value: Any, label: str) -> Path:
    raw = require_string(value, label)
    path = Path(raw)
    require(not path.is_absolute(), f"{label} must be a repository-relative path")
    require(".." not in path.parts, f"{label} must not escape the repository")
    absolute = ROOT / path
    require(absolute.exists(), f"{label} does not exist: {raw}")
    return absolute


def read_text(relative_path: str) -> str:
    path = ROOT / relative_path
    require(path.exists(), f"missing required file: {relative_path}")
    return path.read_text(encoding="utf-8")


def scope_region_ids(scope: dict[str, Any], language: str | None = None) -> set[str]:
    scope_regions = scope.get("regions")
    require(isinstance(scope_regions, list) and scope_regions, "constant-time scope regions must be a non-empty list")
    result: set[str] = set()
    for region in scope_regions:
        require(isinstance(region, dict), "scope region entry must be an object")
        if language is not None and region.get("language") != language:
            continue
        region_id = require_string(region.get("id"), "scope region id")
        require(region_id not in result, f"duplicate constant-time scope region id: {region_id}")
        result.add(region_id)
    return result


def scoped_regions(scope: dict[str, Any], language: str) -> list[dict[str, Any]]:
    regions = scope.get("regions")
    require(isinstance(regions, list), "constant-time scope regions must be a list")
    result = [region for region in regions if isinstance(region, dict) and region.get("language") == language]
    require(result, f"constant-time scope must include {language} regions")
    return result


def extract_scoped_region(region: dict[str, Any]) -> str:
    relative_path = require_string(region.get("path"), "scope region path")
    source_path = ROOT / relative_path
    require(source_path.exists(), f"scope region source does not exist: {relative_path}")
    text = source_path.read_text(encoding="utf-8")
    start_marker = require_string(region.get("startMarker"), f"{relative_path}.startMarker")
    end_marker = require_string(region.get("endMarker"), f"{relative_path}.endMarker")
    start = text.find(start_marker)
    end = text.find(end_marker)
    require(start >= 0 and end > start, f"could not extract scoped region: {region.get('id')}")
    return text[start + len(start_marker):end]


def validate_formal_model(manifest: dict[str, Any]) -> None:
    formal_model = manifest.get("formalModel")
    require(isinstance(formal_model, dict), "formalModel must be an object")
    module = require_string(formal_model.get("module"), "formalModel.module")
    formal_text = read_text(module)
    for declaration in require_string_list(formal_model.get("declarations"), "formalModel.declarations"):
        require(declaration in formal_text, f"formal declaration not found: {declaration}")


def validate_boundaries(manifest: dict[str, Any], scope: dict[str, Any]) -> None:
    scoped_region_ids = scope_region_ids(scope)

    boundaries = manifest.get("toolchainBoundaries")
    require(isinstance(boundaries, list), "toolchainBoundaries must be a list")
    seen_boundary_ids: set[str] = set()
    covered_region_ids: set[str] = set()
    remaining_required_statuses = 0

    for boundary in boundaries:
        require(isinstance(boundary, dict), "toolchain boundary entry must be an object")
        boundary_id = require_string(boundary.get("id"), "toolchainBoundary.id")
        require(boundary_id not in seen_boundary_ids, f"duplicate toolchain boundary id: {boundary_id}")
        seen_boundary_ids.add(boundary_id)

        require_string(boundary.get("compilerSurface"), f"{boundary_id}.compilerSurface")
        regions = set(require_string_list(boundary.get("regions"), f"{boundary_id}.regions"))
        require(regions.issubset(scoped_region_ids), f"{boundary_id} names unknown scope region(s)")
        covered_region_ids.update(regions)

        require_string_list(boundary.get("requiredArtifacts"), f"{boundary_id}.requiredArtifacts")
        require_string_list(boundary.get("forbiddenLoweringPatterns"), f"{boundary_id}.forbiddenLoweringPatterns")
        require_string_list(boundary.get("requiredPositiveFindings"), f"{boundary_id}.requiredPositiveFindings")
        status = require_string(boundary.get("status"), f"{boundary_id}.status")
        require(status in REQUIRED_STATUS, f"{boundary_id}.status is not an accepted evidence status")
        if status == "required-before-production-ct-claim":
            remaining_required_statuses += 1

    require(seen_boundary_ids == REQUIRED_BOUNDARY_IDS, f"toolchainBoundaries must be exactly {sorted(REQUIRED_BOUNDARY_IDS)}")
    require(covered_region_ids == scoped_region_ids, "toolchain boundaries must cover every constant-time source region")
    require(
        remaining_required_statuses >= 1,
        "at least one compiler or hardware boundary must remain explicit before production CT claims",
    )


def validate_promotion_rule(manifest: dict[str, Any]) -> None:
    promotion = manifest.get("promotionRule")
    require(isinstance(promotion, dict), "promotionRule must be an object")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "productionConstantTimeClaimAllowed must stay false until lowering and hardware artifacts are recorded",
    )
    require(promotion.get("releaseEvidenceOnly") is True, "releaseEvidenceOnly must be true")
    unblock = require_string_list(promotion.get("unblockRequires"), "promotionRule.unblockRequires")
    require(any("lowering artifacts" in item for item in unblock), "unblockRequires must mention lowering artifacts")
    require(any("CPU and GPU observation" in item for item in unblock), "unblockRequires must mention CPU and GPU observation")


def validate_observation_lane_contract(manifest: dict[str, Any]) -> None:
    reports = manifest.get("observationLaneReports")
    require(isinstance(reports, dict), "observationLaneReports must be an object")
    require(
        reports.get("compiler") == "Evidence/ConstantTime/swift-llvm-metal-v1/compiler/compiler-observation-lanes-v1.json",
        "observationLaneReports.compiler must point to the pinned compiler observation lane report",
    )
    require(
        reports.get("hardware") == "Evidence/ConstantTime/swift-llvm-metal-v1/hardware/hardware-observation-lanes-v1.json",
        "observationLaneReports.hardware must point to the pinned hardware observation lane report",
    )


def release_entries(release_manifest: dict[str, Any]) -> dict[str, dict[str, Any]]:
    entries = release_manifest.get("artifactEntries")
    require(isinstance(entries, list) and entries, "release evidence artifactEntries must be a non-empty list")
    result: dict[str, dict[str, Any]] = {}
    for entry in entries:
        require(isinstance(entry, dict), "release evidence artifact entry must be an object")
        entry_id = require_string(entry.get("id"), "artifactEntries.id")
        require(entry_id not in result, f"duplicate release evidence artifact id: {entry_id}")
        path = require_relative_artifact_path(entry.get("path"), f"{entry_id}.path")
        expected_digest = require_string(entry.get("sha256Hex"), f"{entry_id}.sha256Hex")
        require(len(expected_digest) == 64, f"{entry_id}.sha256Hex must be 64 hex characters")
        try:
            int(expected_digest, 16)
        except ValueError:
            fail(f"{entry_id}.sha256Hex must be hexadecimal")
        require(sha256_hex(path) == expected_digest, f"{entry_id}.sha256Hex does not match {path_label(path)}")
        require(entry.get("byteCount") == path.stat().st_size, f"{entry_id}.byteCount does not match {path_label(path)}")
        require_string(entry.get("role"), f"{entry_id}.role")
        result[entry_id] = entry
    require(set(result) == REQUIRED_RELEASE_EVIDENCE_IDS, f"release evidence artifacts must be exactly {sorted(REQUIRED_RELEASE_EVIDENCE_IDS)}")
    return result


def validate_metal_artifact_report(entries: dict[str, dict[str, Any]], scope: dict[str, Any]) -> None:
    report_path = require_relative_artifact_path(entries["metal-artifact-report"].get("path"), "metal-artifact-report.path")
    report = read_json(report_path)
    require(report.get("schemaVersion") == 1, "metal artifact report schemaVersion must be 1")
    require(
        report.get("claimStatus") == "local-metal-air-and-metallib-artifacts-pinned",
        "metal artifact report claimStatus must stay precise",
    )
    source = report.get("source")
    require(isinstance(source, dict), "metal artifact report source must be an object")
    source_path = require_relative_artifact_path(source.get("path"), "metal artifact source.path")
    require(source.get("sha256Hex") == sha256_hex(source_path), "metal artifact source digest is stale")
    covered = set(require_string_list(report.get("coveredRegions"), "metal artifact coveredRegions"))
    require(covered == scope_region_ids(scope, "metal"), "metal artifact report must cover every Metal scope region")

    command_by_id: dict[str, dict[str, Any]] = {}
    commands = report.get("commands")
    require(isinstance(commands, list), "metal artifact report commands must be a list")
    for command in commands:
        require(isinstance(command, dict), "metal artifact report command must be an object")
        command_id = require_string(command.get("id"), "metal artifact command.id")
        require(command_id not in command_by_id, f"duplicate metal artifact command id: {command_id}")
        command_by_id[command_id] = command
        output_path = require_relative_artifact_path(command.get("outputPath"), f"{command_id}.outputPath")
        require(command.get("outputSHA256Hex") == sha256_hex(output_path), f"{command_id}.outputSHA256Hex is stale")
    require(
        set(command_by_id) == {"compile-metal-air", "link-metal-library"},
        "metal artifact report must record compile and link commands",
    )
    require(command_by_id["compile-metal-air"].get("outputPath") == entries["metal-air"].get("path"), "metal AIR report path mismatch")
    require(command_by_id["link-metal-library"].get("outputPath") == entries["metal-metallib"].get("path"), "metallib report path mismatch")
    require_string_list(report.get("positiveFindings"), "metal artifact positiveFindings")
    require_string_list(report.get("residualBoundaries"), "metal artifact residualBoundaries")


def validate_swift_compiler_artifact_report(entries: dict[str, dict[str, Any]], scope: dict[str, Any]) -> None:
    report_path = require_relative_artifact_path(
        entries["swift-compiler-artifact-report"].get("path"),
        "swift-compiler-artifact-report.path",
    )
    report = read_json(report_path)
    require(report.get("schemaVersion") == 1, "Swift compiler artifact report schemaVersion must be 1")
    require(
        report.get("claimStatus") == "local-swift-sil-llvm-assembly-artifacts-pinned",
        "Swift compiler artifact report claimStatus must stay precise",
    )
    source = report.get("source")
    require(isinstance(source, dict), "Swift compiler artifact report source must be an object")
    source_path = require_relative_artifact_path(source.get("path"), "Swift compiler artifact source.path")
    require(source.get("sha256Hex") == sha256_hex(source_path), "Swift compiler artifact source digest is stale")
    covered = set(require_string_list(report.get("coveredRegions"), "Swift compiler artifact coveredRegions"))
    require(covered == scope_region_ids(scope, "swift"), "Swift compiler artifact report must cover every Swift scope region")

    command_by_id: dict[str, dict[str, Any]] = {}
    commands = report.get("commands")
    require(isinstance(commands, list), "Swift compiler artifact report commands must be a list")
    for command in commands:
        require(isinstance(command, dict), "Swift compiler artifact report command must be an object")
        command_id = require_string(command.get("id"), "Swift compiler artifact command.id")
        require(command_id not in command_by_id, f"duplicate Swift compiler artifact command id: {command_id}")
        command_by_id[command_id] = command
        argv = command.get("argv")
        require(isinstance(argv, list) and argv, f"{command_id}.argv must be a non-empty list")
        require("-O" in argv, f"{command_id}.argv must include -O")
        require("-whole-module-optimization" in argv, f"{command_id}.argv must include -whole-module-optimization")
        output_path = require_relative_artifact_path(command.get("outputPath"), f"{command_id}.outputPath")
        require(command.get("outputSHA256Hex") == sha256_hex(output_path), f"{command_id}.outputSHA256Hex is stale")
    require(
        set(command_by_id) == {"emit-optimized-sil", "emit-optimized-llvm-ir", "emit-target-assembly"},
        "Swift compiler artifact report must record SIL, LLVM IR, and assembly commands",
    )
    require(command_by_id["emit-optimized-sil"].get("outputPath") == entries["swift-optimized-sil"].get("path"), "Swift SIL report path mismatch")
    require(command_by_id["emit-optimized-llvm-ir"].get("outputPath") == entries["swift-optimized-llvm-ir"].get("path"), "Swift LLVM IR report path mismatch")
    require(command_by_id["emit-target-assembly"].get("outputPath") == entries["swift-target-assembly"].get("path"), "Swift assembly report path mismatch")
    for artifact_id, marker in {
        "swift-optimized-sil": "GoldilocksField",
        "swift-optimized-llvm-ir": "GoldilocksField",
        "swift-target-assembly": "GoldilocksField",
    }.items():
        artifact_path = require_relative_artifact_path(entries[artifact_id].get("path"), f"{artifact_id}.path")
        require(marker in artifact_path.read_text(encoding="utf-8", errors="ignore"), f"{artifact_id} must contain {marker}")
    require_string_list(report.get("positiveFindings"), "Swift compiler artifact positiveFindings")
    require_string_list(report.get("residualBoundaries"), "Swift compiler artifact residualBoundaries")


def validate_runtime_review(entries: dict[str, dict[str, Any]], scope: dict[str, Any]) -> None:
    review_path = require_relative_artifact_path(entries["runtime-allocation-review"].get("path"), "runtime-allocation-review.path")
    review = read_json(review_path)
    require(review.get("schemaVersion") == 1, "runtime review schemaVersion must be 1")
    require(
        review.get("claimStatus") == "static-runtime-allocation-and-cow-review-pinned",
        "runtime review claimStatus must stay precise",
    )
    require(
        review.get("allocationRiskStatus") == "no-scope-local-allocation-or-cow-tokens-detected",
        "runtime review must not contain scoped allocation/COW findings",
    )
    require(review.get("scopeManifest") == "TestVectors/constant-time-scope-v1.json", "runtime review scopeManifest mismatch")
    reviewed = review.get("reviewedRegions")
    require(isinstance(reviewed, list) and reviewed, "runtime review reviewedRegions must be a non-empty list")
    reviewed_by_id: dict[str, dict[str, Any]] = {}
    for row in reviewed:
        require(isinstance(row, dict), "runtime reviewed region must be an object")
        region_id = require_string(row.get("id"), "runtime reviewed region id")
        require(region_id not in reviewed_by_id, f"duplicate runtime reviewed region id: {region_id}")
        require(row.get("forbiddenRuntimePatternMatches") == [], f"{region_id} contains forbidden runtime pattern matches")
        reviewed_by_id[region_id] = row
    expected_regions = scoped_regions(scope, "swift")
    require(set(reviewed_by_id) == {str(region["id"]) for region in expected_regions}, "runtime review must cover every Swift scope region")
    for region in expected_regions:
        region_id = str(region["id"])
        expected_digest = hashlib.sha256(extract_scoped_region(region).encode("utf-8")).hexdigest()
        require(reviewed_by_id[region_id].get("regionSHA256Hex") == expected_digest, f"runtime review digest is stale for {region_id}")
    require_string_list(review.get("forbiddenRuntimeRegex"), "runtime review forbiddenRuntimeRegex")
    require_string_list(review.get("positiveFindings"), "runtime review positiveFindings")
    require_string_list(review.get("residualBoundaries"), "runtime review residualBoundaries")


def validate_observation_corpus(
    entries: dict[str, dict[str, Any]],
    entry_id: str,
    expected_policy: str,
) -> dict[str, Any]:
    corpus_path = require_relative_artifact_path(entries[entry_id].get("path"), f"{entry_id}.path")
    corpus = read_json(corpus_path)
    require(corpus.get("schemaVersion") == 1, f"{entry_id} schemaVersion must be 1")
    require(
        corpus.get("claimStatus") == "local-non-certifying-observation-corpus",
        f"{entry_id} claimStatus must stay non-certifying",
    )
    require(corpus.get("policy") == expected_policy, f"{entry_id} policy mismatch")
    sample_classes = corpus.get("sampleClasses")
    require(isinstance(sample_classes, list) and len(sample_classes) >= 2, f"{entry_id} must contain at least two sample classes")
    class_ids = {
        require_string(row.get("classID"), f"{entry_id}.sampleClasses.classID")
        for row in sample_classes
        if isinstance(row, dict)
    }
    require(len(class_ids) >= 2, f"{entry_id} must contain at least two distinct sample class IDs")
    samples = corpus.get("samples")
    require(isinstance(samples, list) and len(samples) >= len(class_ids), f"{entry_id} must contain samples")
    summary = corpus.get("summary")
    require(isinstance(summary, dict), f"{entry_id} summary must be an object")
    require(summary.get("successfulSampleCount") == len(samples), f"{entry_id} summary successful count must match samples")
    require(summary.get("failedSampleCount") in {None, 0}, f"{entry_id} must not contain failed samples")
    require_string_list(corpus.get("observationModel"), f"{entry_id}.observationModel")
    require_string_list(corpus.get("residualBoundaries"), f"{entry_id}.residualBoundaries")
    return corpus


def require_artifact_refs(value: Any, label: str, entries: dict[str, dict[str, Any]]) -> list[str]:
    refs = require_string_list(value, label)
    for artifact_id in refs:
        require(artifact_id in entries, f"{label} names unknown artifact id: {artifact_id}")
    return refs


def validate_compiler_observation_lanes(entries: dict[str, dict[str, Any]], scope: dict[str, Any]) -> None:
    report_path = require_relative_artifact_path(
        entries["compiler-observation-lanes"].get("path"),
        "compiler-observation-lanes.path",
    )
    report = read_json(report_path)
    require(report.get("schemaVersion") == 1, "compiler observation lanes schemaVersion must be 1")
    require(
        report.get("reportID") == "superneo-compiler-observation-lanes-v1",
        "compiler observation lanes reportID mismatch",
    )
    require(
        report.get("claimStatus") == "compiler-observation-lanes-local-and-gap-recorded",
        "compiler observation lanes claimStatus must stay precise",
    )
    require(report.get("scopeManifest") == "TestVectors/constant-time-scope-v1.json", "compiler observation lanes scopeManifest mismatch")
    scoped = scope_region_ids(scope)
    lanes = report.get("lanes")
    require(isinstance(lanes, list) and lanes, "compiler observation lanes must be a non-empty list")
    seen: set[str] = set()
    covered: set[str] = set()
    for lane in lanes:
        require(isinstance(lane, dict), "compiler observation lane must be an object")
        lane_id = require_string(lane.get("id"), "compiler observation lane id")
        require(lane_id not in seen, f"duplicate compiler observation lane id: {lane_id}")
        seen.add(lane_id)
        require_string(lane.get("surface"), f"{lane_id}.surface")
        regions = set(require_string_list(lane.get("regions"), f"{lane_id}.regions"))
        require(regions and regions.issubset(scoped), f"{lane_id} names unknown or empty region set")
        covered.update(regions)
        require_artifact_refs(lane.get("observedArtifacts"), f"{lane_id}.observedArtifacts", entries)
        status = require_string(lane.get("observationStatus"), f"{lane_id}.observationStatus")
        require(status in REQUIRED_COMPILER_LANE_STATUS, f"{lane_id}.observationStatus is not accepted")
        require_string_list(lane.get("requiredBeforeProduction"), f"{lane_id}.requiredBeforeProduction")
        require_string_list(lane.get("positiveFindings"), f"{lane_id}.positiveFindings")
        require_string_list(lane.get("residualBoundaries"), f"{lane_id}.residualBoundaries")
    require(seen == REQUIRED_COMPILER_LANE_IDS, f"compiler observation lanes must be exactly {sorted(REQUIRED_COMPILER_LANE_IDS)}")
    require(covered == scoped, "compiler observation lanes must cover every constant-time source region")
    promotion = report.get("promotionImpact")
    require(isinstance(promotion, dict), "compiler observation lanes promotionImpact must be an object")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "compiler observation lanes must not promote production constant-time claims",
    )


def validate_hardware_observation_lanes(entries: dict[str, dict[str, Any]]) -> None:
    report_path = require_relative_artifact_path(
        entries["hardware-observation-lanes"].get("path"),
        "hardware-observation-lanes.path",
    )
    report = read_json(report_path)
    require(report.get("schemaVersion") == 1, "hardware observation lanes schemaVersion must be 1")
    require(
        report.get("reportID") == "superneo-hardware-observation-lanes-v1",
        "hardware observation lanes reportID mismatch",
    )
    require(
        report.get("claimStatus") == "hardware-observation-lanes-local-non-certifying",
        "hardware observation lanes claimStatus must stay precise",
    )
    require(report.get("scopeManifest") == "TestVectors/constant-time-scope-v1.json", "hardware observation lanes scopeManifest mismatch")
    hardware = report.get("hardware")
    require(isinstance(hardware, dict), "hardware observation lanes hardware metadata must be an object")
    require_string(hardware.get("uname"), "hardware observation lanes hardware.uname")
    require_string(hardware.get("swVers"), "hardware observation lanes hardware.swVers")
    require_string(hardware.get("machine"), "hardware observation lanes hardware.machine")
    lanes = report.get("lanes")
    require(isinstance(lanes, list) and lanes, "hardware observation lanes must be a non-empty list")
    seen: set[str] = set()
    for lane in lanes:
        require(isinstance(lane, dict), "hardware observation lane must be an object")
        lane_id = require_string(lane.get("id"), "hardware observation lane id")
        require(lane_id not in seen, f"duplicate hardware observation lane id: {lane_id}")
        seen.add(lane_id)
        require_string(lane.get("policy"), f"{lane_id}.policy")
        observed = lane.get("observedArtifacts")
        if lane_id == "power-contention-scheduler-boundary":
            require(observed == [], f"{lane_id}.observedArtifacts must be empty for the explicit boundary lane")
        else:
            require_artifact_refs(observed, f"{lane_id}.observedArtifacts", entries)
        status = require_string(lane.get("observationStatus"), f"{lane_id}.observationStatus")
        require(status in REQUIRED_HARDWARE_LANE_STATUS, f"{lane_id}.observationStatus is not accepted")
        require_string_list(lane.get("observationModel"), f"{lane_id}.observationModel")
        require_string_list(lane.get("requiredBeforeProduction"), f"{lane_id}.requiredBeforeProduction")
        require_string_list(lane.get("residualBoundaries"), f"{lane_id}.residualBoundaries")
    require(seen == REQUIRED_HARDWARE_LANE_IDS, f"hardware observation lanes must be exactly {sorted(REQUIRED_HARDWARE_LANE_IDS)}")
    promotion = report.get("promotionImpact")
    require(isinstance(promotion, dict), "hardware observation lanes promotionImpact must be an object")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "hardware observation lanes must not promote production constant-time claims",
    )


def validate_release_evidence(manifest: dict[str, Any], scope: dict[str, Any]) -> None:
    release_manifest_path = resolve_manifest_path(manifest.get("releaseEvidenceManifest"), "releaseEvidenceManifest")
    release_manifest = read_json(release_manifest_path)
    require(release_manifest.get("schemaVersion") == 1, "release evidence schemaVersion must be 1")
    require(
        release_manifest.get("evidenceID") == "superneo-swift-llvm-metal-release-evidence-v1",
        "release evidence evidenceID mismatch",
    )
    require(
        release_manifest.get("claimStatus") == "local-release-evidence-pinned",
        "release evidence claimStatus must be local-release-evidence-pinned",
    )
    require(release_manifest.get("scopeManifest") == "TestVectors/constant-time-scope-v1.json", "release evidence scopeManifest mismatch")
    require(
        release_manifest.get("loweringEvidenceManifest") == "TestVectors/constant-time-lowering-evidence-v1.json",
        "release evidence loweringEvidenceManifest mismatch",
    )
    promotion = release_manifest.get("promotionDecision")
    require(isinstance(promotion, dict), "release evidence promotionDecision must be an object")
    require(
        promotion.get("productionConstantTimeClaimAllowed") is False,
        "release evidence must not promote production constant-time claims",
    )

    entries = release_entries(release_manifest)
    require(
        release_manifest.get("compilerObservationLaneReport") == entries["compiler-observation-lanes"].get("path"),
        "release evidence compilerObservationLaneReport must match the pinned compiler lane artifact",
    )
    require(
        release_manifest.get("hardwareObservationLaneReport") == entries["hardware-observation-lanes"].get("path"),
        "release evidence hardwareObservationLaneReport must match the pinned hardware lane artifact",
    )
    validate_swift_compiler_artifact_report(entries, scope)
    validate_metal_artifact_report(entries, scope)
    validate_runtime_review(entries, scope)

    cpu = validate_observation_corpus(entries, "cpu-observation-corpus", "zk-high-assurance-cpu")
    for sample in cpu.get("samples", []):
        require(isinstance(sample, dict), "CPU observation sample must be an object")
        require(sample.get("exitCode") == 0, "CPU observation sample must have exitCode 0")
        cli_fields = sample.get("cliFields")
        require(isinstance(cli_fields, dict), "CPU observation sample must include cliFields")
        require(cli_fields.get("proof_kind") == "numiseal-zk", "CPU observation must bind a NumiSealZK proof kind")
        require(sample.get("artifactByteCount", 0) > 0, "CPU observation must bind an artifact byte count")
        require_string(sample.get("artifactSHA256Hex"), "CPU observation artifact digest")

    gpu = validate_observation_corpus(entries, "gpu-observation-corpus", "direct-metal-secret-bearing-kernel-observation")
    require_string(gpu.get("metalDevice"), "gpu-observation-corpus.metalDevice")
    for sample in gpu.get("samples", []):
        require(isinstance(sample, dict), "GPU observation sample must be an object")
        timings = sample.get("operationTimings")
        require(isinstance(timings, list) and timings, "GPU observation sample must include operationTimings")
        operations = {
            require_string(timing.get("operation"), "GPU observation operation")
            for timing in timings
            if isinstance(timing, dict)
        }
        require(REQUIRED_GPU_OPERATIONS.issubset(operations), "GPU observation sample must time every scoped NumiSeal Metal kernel")
        digests = sample.get("resultDigestsHex")
        require(isinstance(digests, dict), "GPU observation sample must include resultDigestsHex")
        for operation in REQUIRED_GPU_OPERATIONS:
            require(
                operation in digests or any(str(key).startswith(operation + ".") for key in digests),
                f"GPU observation sample missing result digest for {operation}",
            )
    validate_compiler_observation_lanes(entries, scope)
    validate_hardware_observation_lanes(entries)


def main() -> None:
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_MANIFEST
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path
    manifest = read_json(manifest_path)
    manifest_text = manifest_path.read_text(encoding="utf-8").lower()
    require("external" + " audit" not in manifest_text, "manifest must not encode outsourced review as a dependency")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        manifest.get("evidenceID") == "superneo-swift-llvm-metal-lowering-evidence-v1",
        "unsupported evidenceID",
    )
    require(
        manifest.get("claimStatus") == "conditional-lowering-and-tcb-proof-contract",
        "claimStatus must remain precise",
    )
    require(
        manifest.get("proofConclusion") == "complete-under-stated-proof-obligations-not-a-hardware-certificate",
        "proofConclusion must remain explicit",
    )
    require(manifest.get("scopeManifest") == "TestVectors/constant-time-scope-v1.json", "scopeManifest mismatch")
    require(
        manifest.get("releaseEvidenceManifest") == "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json"
        or Path(str(manifest.get("releaseEvidenceManifest"))).is_absolute(),
        "releaseEvidenceManifest must point to the pinned release evidence manifest",
    )
    scope = read_json(SCOPE_MANIFEST)
    require(
        scope.get("loweringEvidenceManifest") == "TestVectors/constant-time-lowering-evidence-v1.json",
        "constant-time scope must link the lowering evidence manifest",
    )

    validate_formal_model(manifest)
    validate_boundaries(manifest, scope)
    validate_promotion_rule(manifest)
    validate_observation_lane_contract(manifest)
    validate_release_evidence(manifest, scope)

    gate = read_text("Scripts/production-gate.sh")
    require(
        "run_step Scripts/validate-constant-time-lowering-evidence.py" in gate,
        "production gate must run validate-constant-time-lowering-evidence.py",
    )
    require(
        "run_step Scripts/test-constant-time-lowering-evidence-validation.py" in gate,
        "production gate must run lowering evidence regression tests",
    )
    release_policy = read_text("Scripts/validate-release-readiness-policy.py")
    require(
        "TestVectors/constant-time-lowering-evidence-v1.json" in release_policy,
        "release readiness policy must pin the lowering evidence manifest",
    )
    require(
        "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json" in release_policy,
        "release readiness policy must pin the constant-time release evidence manifest",
    )
    docs = read_text("Docs/ConstantTimeEvidence-2026-04-16.md")
    require(
        "TestVectors/constant-time-lowering-evidence-v1.json" in docs,
        "constant-time evidence doc must mention the lowering evidence manifest",
    )
    require(
        "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json" in docs,
        "constant-time evidence doc must mention the release evidence manifest",
    )
    print("constant-time lowering evidence validation passed")


if __name__ == "__main__":
    main()
