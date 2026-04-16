#!/usr/bin/env python3
"""Validate the checked constant-time source/formal scope manifest."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "TestVectors" / "constant-time-scope-v1.json"
REQUIRED_REGION_IDS = {
    "swift-goldilocks-common-arithmetic",
    "swift-goldilocks-fixed-exponentiation",
    "metal-goldilocks-common-arithmetic",
    "metal-numiseal-zk-secret-bearing-kernels",
}


def fail(message: str) -> None:
    print(f"constant-time scope validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_string_list(value: Any, label: str, *, allow_empty: bool = False) -> list[str]:
    require(isinstance(value, list), f"{label} must be a list")
    require(allow_empty or bool(value), f"{label} must not be empty")
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


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path_label(path)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path_label(path)} root must be an object")
    return value


def path_text(relative_path: str) -> str:
    path = ROOT / relative_path
    require(path.exists(), f"missing path: {relative_path}")
    return path.read_text(encoding="utf-8")


def extract_region(text: str, start_marker: str, end_marker: str, region_id: str) -> str:
    start = text.find(start_marker)
    require(start >= 0, f"{region_id} start marker not found")
    body_start = start + len(start_marker)
    end = text.find(end_marker, body_start)
    require(end >= 0, f"{region_id} end marker not found")
    require(text.find(start_marker, body_start) < 0, f"{region_id} start marker appears more than once")
    require(text.find(end_marker, end + len(end_marker)) < 0, f"{region_id} end marker appears more than once")
    return text[body_start:end]


def strip_allowed_control_flow(region: str, allowed_regexes: list[str]) -> str:
    stripped = region
    for pattern in allowed_regexes:
        stripped = re.sub(pattern, "", stripped)
    return stripped


def validate_region(region: Any, formal_text: str) -> str:
    require(isinstance(region, dict), "region entry must be an object")
    region_id = require_string(region.get("id"), "region.id")
    path = require_string(region.get("path"), f"{region_id}.path")
    text = path_text(path)
    body = extract_region(
        text,
        require_string(region.get("startMarker"), f"{region_id}.startMarker"),
        require_string(region.get("endMarker"), f"{region_id}.endMarker"),
        region_id,
    )

    require_string_list(region.get("secretInputs"), f"{region_id}.secretInputs")
    require_string_list(region.get("publicInputs"), f"{region_id}.publicInputs")
    required_snippets = require_string_list(region.get("requiredSnippets"), f"{region_id}.requiredSnippets")
    for snippet in required_snippets:
        require(snippet in body, f"{region_id} missing required snippet: {snippet}")

    allowed_regexes = require_string_list(
        region.get("allowedPublicControlFlowRegex"),
        f"{region_id}.allowedPublicControlFlowRegex",
        allow_empty=True,
    )
    forbidden_regexes = require_string_list(region.get("forbiddenRegex"), f"{region_id}.forbiddenRegex")
    stripped = strip_allowed_control_flow(body, allowed_regexes)
    for pattern in forbidden_regexes:
        match = re.search(pattern, stripped)
        if match is not None:
            fail(f"{region_id} contains forbidden source pattern {pattern!r}: {match.group(0)!r}")

    formal_declaration = require_string(region.get("formalTraceDeclaration"), f"{region_id}.formalTraceDeclaration")
    require(formal_declaration in formal_text, f"{region_id} formal declaration not found: {formal_declaration}")
    return region_id


def main() -> None:
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_MANIFEST
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path
    manifest = read_json(manifest_path)
    manifest_text = manifest_path.read_text(encoding="utf-8").lower()
    require("external" + " audit" not in manifest_text, "manifest must not encode outsourced review as a dependency")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        manifest.get("scopeID") == "superneo-swift-llvm-metal-constant-time-scope-v1",
        "unsupported scopeID",
    )
    require(
        manifest.get("claimStatus") == "conditional-source-and-formal-trace-model",
        "claimStatus must remain precise",
    )

    formal_model = manifest.get("formalModel")
    require(isinstance(formal_model, dict), "formalModel must be an object")
    formal_module_path = require_string(formal_model.get("module"), "formalModel.module")
    formal_text = path_text(formal_module_path)
    root_import = require_string(formal_model.get("rootImport"), "formalModel.rootImport")
    root_text = path_text("Formal/SuperNeoFormal.lean")
    require(root_import in root_text, "Formal/SuperNeoFormal.lean must import the constant-time module")
    for declaration in require_string_list(formal_model.get("declarations"), "formalModel.declarations"):
        require(declaration in formal_text, f"formal declaration not found: {declaration}")

    regions = manifest.get("regions")
    require(isinstance(regions, list), "regions must be a list")
    seen = {validate_region(region, formal_text) for region in regions}
    require(seen == REQUIRED_REGION_IDS, f"regions must be exactly {sorted(REQUIRED_REGION_IDS)}")

    open_boundaries = require_string_list(manifest.get("openBoundaries"), "openBoundaries")
    require(
        any("swift" in boundary.lower() and "lowering" in boundary.lower() for boundary in open_boundaries),
        "openBoundaries must name Swift lowering",
    )
    require(
        any("llvm" in boundary.lower() or "clang" in boundary.lower() for boundary in open_boundaries),
        "openBoundaries must name compiler lowering",
    )
    require(
        any("allocator" in boundary.lower() for boundary in open_boundaries),
        "openBoundaries must name allocator/runtime behavior",
    )

    gate = path_text("Scripts/production-gate.sh")
    require(
        "run_step Scripts/validate-constant-time-scope.py" in gate,
        "production gate must run validate-constant-time-scope.py",
    )
    release_policy = path_text("Scripts/validate-release-readiness-policy.py")
    require(
        "TestVectors/constant-time-scope-v1.json" in release_policy,
        "release readiness policy must pin the constant-time scope manifest",
    )
    docs = path_text("Docs/ConstantTimeEvidence-2026-04-16.md")
    require(
        "TestVectors/constant-time-scope-v1.json" in docs,
        "constant-time evidence doc must mention the scope manifest",
    )
    print("constant-time scope validation passed")


if __name__ == "__main__":
    main()
