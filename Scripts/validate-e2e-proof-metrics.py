#!/usr/bin/env python3
"""Validate checked E2E proof-size metrics and product smoke budgets."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "TestVectors" / "e2e-proof-metrics-v1.json"
EXPECTED_SCOPE_ID = "superneo-e2e-proof-metrics-v1"
EXPECTED_CLAIM_STATUS = "repository-local-proof-size-performance-budgets"

TOP_LEVEL_KEYS = {
    "schemaVersion",
    "scopeID",
    "claimStatus",
    "units",
    "trackedArtifacts",
    "generatedProductBudgets",
    "latencyEvidencePolicy",
    "openBoundaries",
}
TRACKED_KEYS = {
    "id",
    "manifest",
    "file",
    "expectedArtifactVersion",
    "expectedProofKind",
    "proofEnvelopeField",
    "artifactBytes",
    "proofEnvelopeBytes",
    "maximumArtifactBytes",
    "maximumProofEnvelopeBytes",
}
GENERATED_BUDGET_KEYS = {
    "id",
    "expectedArtifactVersion",
    "expectedProofKind",
    "expectedSealMode",
    "expectedCarryMode",
    "expectedZKMode",
    "expectedMetalMode",
    "expectedExecutionPolicy",
    "expectedSourceFoldOutputClaimCount",
    "maximumArtifactBytes",
    "maximumSourceFoldEnvelopeBytes",
    "maximumProofEnvelopeBytes",
}
LATENCY_POLICY_KEYS = {
    "benchmarkCommand",
    "productionReleaseRequiresFreshBenchmarkReport",
    "trackedReportDirectory",
}


class DuplicateKeyError(ValueError):
    pass


def fail(message: str) -> None:
    print(f"e2e proof metrics validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def path_label(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate JSON object key {key!r}")
        result[key] = value
    return result


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_pairs)
    except DuplicateKeyError as error:
        fail(f"{path_label(path)} contains {error}")
    except json.JSONDecodeError as error:
        fail(f"{path_label(path)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path_label(path)} root must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_int(value: Any, label: str) -> int:
    require(isinstance(value, int) and not isinstance(value, bool), f"{label} must be an integer")
    require(value >= 0, f"{label} must be non-negative")
    return value


def require_positive_int(value: Any, label: str) -> int:
    result = require_int(value, label)
    require(result > 0, f"{label} must be positive")
    return result


def require_allowed_keys(value: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = sorted(set(value) - allowed)
    require(not unknown, f"{label} contains unknown fields: {','.join(unknown)}")


def require_existing_relative_path(value: Any, label: str) -> Path:
    relative = require_string(value, label)
    require(not Path(relative).is_absolute(), f"{label} must be repository-relative")
    path = ROOT / relative
    require(path.exists(), f"{label} does not exist: {relative}")
    return path


def decode_base64(value: Any, label: str) -> bytes:
    encoded = require_string(value, label)
    try:
        return base64.b64decode(encoded, validate=True)
    except ValueError as error:
        fail(f"{label} is not valid base64: {error}")


def require_digest(value: Any, expected: bytes, label: str) -> None:
    digest = require_string(value, label)
    require(len(digest) == 64 and all(char in "0123456789abcdef" for char in digest), f"{label} must be lowercase SHA-256 hex")
    require(digest == hashlib.sha256(expected).hexdigest(), f"{label} does not match decoded bytes")


def manifest_entry_by_file(manifest_path: Path, file_path: Path) -> dict[str, Any]:
    manifest = read_json(manifest_path)
    vectors = manifest.get("vectors")
    require(isinstance(vectors, list), f"{path_label(manifest_path)} vectors must be a list")
    expected = path_label(file_path)
    matches: list[dict[str, Any]] = []
    for item in vectors:
        require(isinstance(item, dict), f"{path_label(manifest_path)} vector entry must be an object")
        vector_file = item.get("file")
        if isinstance(vector_file, str) and str((manifest_path.parent / vector_file).resolve()) == str(file_path.resolve()):
            matches.append(item)
    require(len(matches) == 1, f"{path_label(manifest_path)} must contain exactly one entry for {expected}")
    return matches[0]


def validate_tracked_artifact(entry: Any, seen_ids: set[str]) -> None:
    require(isinstance(entry, dict), "trackedArtifacts entry must be an object")
    require_allowed_keys(entry, TRACKED_KEYS, "trackedArtifacts entry")
    metric_id = require_string(entry.get("id"), "trackedArtifacts.id")
    require(metric_id not in seen_ids, f"duplicate tracked artifact id: {metric_id}")
    seen_ids.add(metric_id)

    artifact_path = require_existing_relative_path(entry.get("file"), f"{metric_id}.file")
    manifest_path = require_existing_relative_path(entry.get("manifest"), f"{metric_id}.manifest")
    artifact = read_json(artifact_path)
    manifest_entry = manifest_entry_by_file(manifest_path, artifact_path)

    expected_artifact_version = require_int(entry.get("expectedArtifactVersion"), f"{metric_id}.expectedArtifactVersion")
    expected_proof_kind = require_string(entry.get("expectedProofKind"), f"{metric_id}.expectedProofKind")
    require(artifact.get("artifactVersion") == expected_artifact_version, f"{metric_id} artifactVersion changed")
    require(artifact.get("proofKind") == expected_proof_kind, f"{metric_id} proofKind changed")
    require(manifest_entry.get("proofKind") == expected_proof_kind, f"{metric_id} manifest proofKind changed")

    artifact_bytes = artifact_path.stat().st_size
    recorded_artifact_bytes = require_positive_int(entry.get("artifactBytes"), f"{metric_id}.artifactBytes")
    maximum_artifact_bytes = require_positive_int(entry.get("maximumArtifactBytes"), f"{metric_id}.maximumArtifactBytes")
    manifest_byte_count = require_positive_int(manifest_entry.get("byteCount"), f"{metric_id}.manifest.byteCount")
    require(artifact_bytes == recorded_artifact_bytes, f"{metric_id} artifact byte count changed: {artifact_bytes} != {recorded_artifact_bytes}")
    require(manifest_byte_count == recorded_artifact_bytes, f"{metric_id} manifest byteCount drifted")
    require(artifact_bytes <= maximum_artifact_bytes, f"{metric_id} artifact bytes exceed budget")

    proof_field = require_string(entry.get("proofEnvelopeField"), f"{metric_id}.proofEnvelopeField")
    proof_bytes = decode_base64(artifact.get(proof_field), f"{metric_id}.{proof_field}")
    recorded_proof_bytes = require_positive_int(entry.get("proofEnvelopeBytes"), f"{metric_id}.proofEnvelopeBytes")
    maximum_proof_bytes = require_positive_int(entry.get("maximumProofEnvelopeBytes"), f"{metric_id}.maximumProofEnvelopeBytes")
    require(len(proof_bytes) == recorded_proof_bytes, f"{metric_id} proof envelope byte count changed")
    require(len(proof_bytes) <= maximum_proof_bytes, f"{metric_id} proof envelope bytes exceed budget")


def validate_generated_budget(entry: Any, seen_ids: set[str]) -> dict[str, Any]:
    require(isinstance(entry, dict), "generatedProductBudgets entry must be an object")
    require_allowed_keys(entry, GENERATED_BUDGET_KEYS, "generatedProductBudgets entry")
    budget_id = require_string(entry.get("id"), "generatedProductBudgets.id")
    require(budget_id not in seen_ids, f"duplicate generated product budget id: {budget_id}")
    seen_ids.add(budget_id)
    for key in [
        "expectedArtifactVersion",
        "expectedSourceFoldOutputClaimCount",
        "maximumArtifactBytes",
        "maximumSourceFoldEnvelopeBytes",
        "maximumProofEnvelopeBytes",
    ]:
        require_positive_int(entry.get(key), f"{budget_id}.{key}")
    for key in [
        "expectedProofKind",
        "expectedSealMode",
        "expectedCarryMode",
        "expectedZKMode",
        "expectedMetalMode",
        "expectedExecutionPolicy",
    ]:
        require_string(entry.get(key), f"{budget_id}.{key}")
    return entry


def validate_generated_artifact(budget: dict[str, Any], artifact_path: Path) -> None:
    require(artifact_path.exists(), f"generated artifact does not exist: {artifact_path}")
    artifact = read_json(artifact_path)
    budget_id = require_string(budget.get("id"), "generated budget id")

    checks = [
        ("artifactVersion", "expectedArtifactVersion"),
        ("proofKind", "expectedProofKind"),
        ("sealMode", "expectedSealMode"),
        ("carryMode", "expectedCarryMode"),
        ("zkMode", "expectedZKMode"),
        ("metalMode", "expectedMetalMode"),
        ("executionPolicy", "expectedExecutionPolicy"),
        ("sourceFoldOutputClaimCount", "expectedSourceFoldOutputClaimCount"),
    ]
    for artifact_key, budget_key in checks:
        require(
            artifact.get(artifact_key) == budget.get(budget_key),
            f"{budget_id} {artifact_key} changed: {artifact.get(artifact_key)!r}",
        )

    artifact_bytes = artifact_path.stat().st_size
    require(
        artifact_bytes <= int(budget["maximumArtifactBytes"]),
        f"{budget_id} artifact bytes exceed budget: {artifact_bytes}",
    )
    source_bytes = decode_base64(artifact.get("sourceFoldEnvelopeBase64"), f"{budget_id}.sourceFoldEnvelopeBase64")
    proof_bytes = decode_base64(artifact.get("numiSealProofEnvelopeBase64"), f"{budget_id}.numiSealProofEnvelopeBase64")
    require(
        len(source_bytes) <= int(budget["maximumSourceFoldEnvelopeBytes"]),
        f"{budget_id} source fold envelope bytes exceed budget: {len(source_bytes)}",
    )
    require(
        len(proof_bytes) <= int(budget["maximumProofEnvelopeBytes"]),
        f"{budget_id} proof envelope bytes exceed budget: {len(proof_bytes)}",
    )
    if "sourceFoldEnvelopeDigestHex" in artifact:
        require_digest(artifact.get("sourceFoldEnvelopeDigestHex"), source_bytes, f"{budget_id}.sourceFoldEnvelopeDigestHex")
    if "proofEnvelopeDigestHex" in artifact:
        require_digest(artifact.get("proofEnvelopeDigestHex"), proof_bytes, f"{budget_id}.proofEnvelopeDigestHex")
    metadata = artifact.get("executionPolicyMetadata")
    require(isinstance(metadata, dict), f"{budget_id}.executionPolicyMetadata must be an object")
    require(
        metadata.get("terminalCarryPolicy") == artifact.get("carryMode"),
        f"{budget_id} terminalCarryPolicy must match carryMode",
    )


def parse_generated_artifact(value: str) -> tuple[str, Path]:
    try:
        budget_id, path_text = value.split(":", 1)
    except ValueError:
        fail("--generated-product-artifact must be formatted as budget-id:path")
    require(budget_id, "generated budget id must be non-empty")
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    return budget_id, path


def validate_manifest(manifest_path: Path, generated_artifacts: list[str]) -> None:
    manifest = read_json(manifest_path)
    manifest_text = manifest_path.read_text(encoding="utf-8").lower()
    require("external" + " audit" not in manifest_text, "manifest must not encode outsourced review as a dependency")
    require_allowed_keys(manifest, TOP_LEVEL_KEYS, "manifest")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(manifest.get("scopeID") == EXPECTED_SCOPE_ID, "unsupported scopeID")
    require(manifest.get("claimStatus") == EXPECTED_CLAIM_STATUS, "claimStatus must stay precise")
    require(manifest.get("units") == "bytes", "units must be bytes")

    tracked = manifest.get("trackedArtifacts")
    require(isinstance(tracked, list) and tracked, "trackedArtifacts must be a non-empty list")
    seen_tracked: set[str] = set()
    for entry in tracked:
        validate_tracked_artifact(entry, seen_tracked)
    require(len(seen_tracked) >= 8, "trackedArtifacts must include the checked R1CS and NumiSeal vector set")

    generated = manifest.get("generatedProductBudgets")
    require(isinstance(generated, list) and generated, "generatedProductBudgets must be a non-empty list")
    seen_generated: set[str] = set()
    budgets = {budget["id"]: budget for budget in (validate_generated_budget(entry, seen_generated) for entry in generated)}

    latency = manifest.get("latencyEvidencePolicy")
    require(isinstance(latency, dict), "latencyEvidencePolicy must be an object")
    require_allowed_keys(latency, LATENCY_POLICY_KEYS, "latencyEvidencePolicy")
    require(latency.get("benchmarkCommand") == "Scripts/run-benchmarks.sh quick", "benchmarkCommand must pin the quick benchmark lane")
    require(latency.get("productionReleaseRequiresFreshBenchmarkReport") is True, "fresh benchmark report requirement must be explicit")
    report_dir = require_existing_relative_path(latency.get("trackedReportDirectory"), "latencyEvidencePolicy.trackedReportDirectory")
    require(report_dir.is_dir(), "trackedReportDirectory must be a directory")

    open_boundaries = manifest.get("openBoundaries")
    require(isinstance(open_boundaries, list) and len(open_boundaries) >= 3, "openBoundaries must list proof-size and latency boundaries")
    require(any("latency" in str(boundary).lower() for boundary in open_boundaries), "openBoundaries must mention latency")

    for generated_artifact in generated_artifacts:
        budget_id, artifact_path = parse_generated_artifact(generated_artifact)
        require(budget_id in budgets, f"unknown generated product budget id: {budget_id}")
        validate_generated_artifact(budgets[budget_id], artifact_path)

    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require("run_step Scripts/validate-e2e-proof-metrics.py" in gate, "production gate must run validate-e2e-proof-metrics.py")
    require("run_step Scripts/test-e2e-proof-metrics-validation.py" in gate, "production gate must run e2e proof metrics regression tests")
    release_policy = (ROOT / "Scripts" / "validate-release-readiness-policy.py").read_text(encoding="utf-8")
    require("TestVectors/e2e-proof-metrics-v1.json" in release_policy, "release readiness policy must pin e2e proof metrics")
    docs = (ROOT / "Docs" / "E2EProofMetrics-2026-04-16.md").read_text(encoding="utf-8")
    require("TestVectors/e2e-proof-metrics-v1.json" in docs, "E2E proof metrics doc must mention the manifest")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument(
        "--generated-product-artifact",
        action="append",
        default=[],
        help="Validate a generated product artifact against a budget, formatted as budget-id:path.",
    )
    args = parser.parse_args()

    manifest_path = args.manifest if args.manifest.is_absolute() else ROOT / args.manifest
    validate_manifest(manifest_path, args.generated_product_artifact)
    print("e2e proof metrics validation passed")


if __name__ == "__main__":
    main()
