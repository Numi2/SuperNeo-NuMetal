#!/usr/bin/env python3
"""Validate the whole-stack benchmark coverage contract."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "TestVectors" / "benchmark-coverage-v1.json"
EXPECTED_SCOPE_ID = "superneo-whole-stack-benchmark-coverage-v1"
EXPECTED_CLAIM_STATUS = "repository-local-performance-coverage-contract"

TOP_LEVEL_KEYS = {
    "schemaVersion",
    "scopeID",
    "claimStatus",
    "benchmarkCommand",
    "trackedBenchmarkSource",
    "trackedReportRenderer",
    "trackedComparator",
    "requiredArtifacts",
    "requiredSurfaces",
    "coverageBoundaries",
}
SURFACE_KEYS = {
    "id",
    "surface",
    "requiredRows",
    "renderedByReport",
    "comparedByBaseline",
}
EXPECTED_SURFACE_IDS = {
    "fold-prover",
    "fold-verifier",
    "fold-stages",
    "cpu-kernels",
    "metal-kernels",
    "numiseal-product",
    "recursive-carry",
    "product-controls",
}


class DuplicateKeyError(ValueError):
    pass


def fail(message: str) -> None:
    print(f"benchmark coverage validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate JSON object key {key!r}")
        result[key] = value
    return result


def path_label(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_pairs)
    except DuplicateKeyError as error:
        fail(f"{path_label(path)} contains {error}")
    except json.JSONDecodeError as error:
        fail(f"{path_label(path)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path_label(path)} root must be an object")
    return value


def require_allowed_keys(value: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = sorted(set(value) - allowed)
    require(not unknown, f"{label} contains unknown fields: {','.join(unknown)}")


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a non-empty list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_existing_relative_path(value: Any, label: str) -> Path:
    relative = require_string(value, label)
    require(not Path(relative).is_absolute(), f"{label} must be repository-relative")
    path = ROOT / relative
    require(path.exists(), f"{label} does not exist: {relative}")
    return path


def require_source_contains(source: str, needle: str, label: str) -> None:
    require(needle in source, f"{label} missing benchmark row prefix {needle!r}")


def validate_manifest(manifest_path: Path) -> None:
    manifest = read_json(manifest_path)
    manifest_text = manifest_path.read_text(encoding="utf-8").lower()
    require("external" + " audit" not in manifest_text, "manifest must not encode outsourced review as a dependency")
    require_allowed_keys(manifest, TOP_LEVEL_KEYS, "manifest")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(manifest.get("scopeID") == EXPECTED_SCOPE_ID, "unsupported scopeID")
    require(manifest.get("claimStatus") == EXPECTED_CLAIM_STATUS, "claimStatus must stay precise")
    require(manifest.get("benchmarkCommand") == "Scripts/run-benchmarks.sh quick", "benchmark command must pin quick profile")

    benchmark_source_path = require_existing_relative_path(
        manifest.get("trackedBenchmarkSource"),
        "trackedBenchmarkSource",
    )
    renderer_path = require_existing_relative_path(
        manifest.get("trackedReportRenderer"),
        "trackedReportRenderer",
    )
    comparator_path = require_existing_relative_path(
        manifest.get("trackedComparator"),
        "trackedComparator",
    )
    benchmark_source = benchmark_source_path.read_text(encoding="utf-8")
    renderer_source = renderer_path.read_text(encoding="utf-8")
    comparator_source = comparator_path.read_text(encoding="utf-8")

    artifacts = require_string_list(manifest.get("requiredArtifacts"), "requiredArtifacts")
    require(
        artifacts == [
            "benchmark-results/results.json",
            "benchmark-results/metadata.json",
            "benchmark-results/report.md",
        ],
        "requiredArtifacts must pin results, metadata, and report outputs",
    )
    for artifact in artifacts:
        require_existing_relative_path(artifact, f"requiredArtifacts entry {artifact}")

    surfaces = manifest.get("requiredSurfaces")
    require(isinstance(surfaces, list) and surfaces, "requiredSurfaces must be a non-empty list")
    seen_ids: set[str] = set()
    all_rows: set[str] = set()
    for surface in surfaces:
        require(isinstance(surface, dict), "requiredSurfaces entries must be objects")
        require_allowed_keys(surface, SURFACE_KEYS, "requiredSurfaces entry")
        surface_id = require_string(surface.get("id"), "requiredSurfaces.id")
        require(surface_id not in seen_ids, f"duplicate required surface id: {surface_id}")
        seen_ids.add(surface_id)
        require_string(surface.get("surface"), f"{surface_id}.surface")
        require(surface.get("renderedByReport") is True, f"{surface_id} must require report rendering")
        require(surface.get("comparedByBaseline") is True, f"{surface_id} must require baseline comparison")
        rows = require_string_list(surface.get("requiredRows"), f"{surface_id}.requiredRows")
        for row in rows:
            require(row not in all_rows, f"duplicate benchmark row prefix: {row}")
            all_rows.add(row)
            require_source_contains(benchmark_source, row, f"{surface_id} benchmark source")
            family_prefix = row.split("/", 1)[0] + "/"
            require_source_contains(renderer_source, family_prefix, f"{surface_id} report renderer")
            if row.startswith(("kernel/", "fold/", "reduceFold/", "terminalVerify/", "proofEnvelope/", "ceOpeningProof/", "compressedEnvelope/", "numisealProduct/", "productControls/", "stage/")):
                require_source_contains(comparator_source, family_prefix, f"{surface_id} comparator")

    missing_surfaces = EXPECTED_SURFACE_IDS - seen_ids
    require(not missing_surfaces, f"missing required benchmark surfaces: {','.join(sorted(missing_surfaces))}")
    require(len(all_rows) >= 30, "whole-stack benchmark coverage must pin at least 30 row prefixes")

    boundaries = require_string_list(manifest.get("coverageBoundaries"), "coverageBoundaries")
    boundary_text = " ".join(boundaries).lower()
    for needle in ["repository-local performance claim", "metal availability", "competitor"]:
        require(needle in boundary_text, f"coverageBoundaries must mention {needle}")

    docs = (ROOT / "Docs" / "Benchmarking.md").read_text(encoding="utf-8")
    require("TestVectors/benchmark-coverage-v1.json" in docs, "Benchmarking docs must mention benchmark coverage manifest")
    require("Validate benchmark coverage manually" in docs, "Benchmarking docs must keep benchmark validation manual")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    require("TestVectors/benchmark-coverage-v1.json" in readme, "README must mention benchmark coverage manifest")


def main() -> None:
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_MANIFEST
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path
    validate_manifest(manifest_path)
    print("benchmark coverage validation passed")


if __name__ == "__main__":
    main()
