#!/usr/bin/env python3
"""Validate the NumiSeal product/carry/ZK conformance scope manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-conformance-scope-v1.json"
REQUIRED_SURFACES = {
    "numiseal-product",
    "numiseal-typed-carry",
    "numiseal-zk",
}


def fail(message: str) -> None:
    print(f"NumiSeal conformance scope validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_string_list(value: Any, label: str, *, allow_empty: bool = False) -> list[str]:
    require(isinstance(value, list), f"{label} must be a list")
    require(allow_empty or bool(value), f"{label} must not be empty")
    result: list[str] = []
    for index, item in enumerate(value):
        require(isinstance(item, str) and item, f"{label}[{index}] must be a non-empty string")
        result.append(item)
    return result


def require_path(relative_path: str, label: str) -> None:
    path = ROOT / relative_path
    require(path.exists(), f"{label} does not exist: {relative_path}")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), "conformance scope root must be an object")
    return value


def validate_surface(surface: Any, test_source: str) -> str:
    require(isinstance(surface, dict), "surface entry must be an object")
    surface_id = surface.get("id")
    require(isinstance(surface_id, str) and surface_id, "surface.id must be a non-empty string")

    implementation_paths = require_string_list(
        surface.get("implementationPaths"),
        f"{surface_id}.implementationPaths",
    )
    for path in implementation_paths:
        require_path(path, f"{surface_id} implementation path")

    vectors = require_string_list(
        surface.get("conformanceVectors"),
        f"{surface_id}.conformanceVectors",
    )
    for path in vectors:
        require_path(path, f"{surface_id} conformance vector")
        vector = read_json(ROOT / path)
        if "surface" in vector:
            require(vector.get("formatVersion") == 1, f"{path} formatVersion must be 1")
            require(vector.get("surface") == surface_id, f"{path} surface must be {surface_id}")
            covered_by_tests = require_string_list(vector.get("coveredByTests"), f"{path}.coveredByTests")
            for name in covered_by_tests:
                require(name in test_source, f"{path} covered test not found in XCTest source: {name}")
        else:
            require(vector.get("artifactVersion") == 1, f"{path} artifactVersion must be 1")

    test_names = require_string_list(surface.get("testNames"), f"{surface_id}.testNames")
    for name in test_names:
        require(name in test_source, f"{surface_id} test not found in XCTest source: {name}")

    formal_scope = require_string_list(surface.get("formalScope"), f"{surface_id}.formalScope")
    open_formal_work = require_string_list(surface.get("openFormalWork"), f"{surface_id}.openFormalWork")
    joined_text = " ".join(formal_scope + open_formal_work).lower()
    require("external" + " audit" not in joined_text, f"{surface_id} must not encode outsourced review as formal work")
    return surface_id


def main() -> None:
    scope = read_json(MANIFEST)
    require(scope.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(scope.get("scopeID") == "numiseal-product-carry-zk-conformance-v1", "scopeID is unsupported")
    require(scope.get("externalAuditRequired") is False, "externalAuditRequired must be false")

    test_source = (ROOT / "SuperNeo-NuMetalTests" / "SuperNeoNuMetalTests.swift").read_text(encoding="utf-8")
    surfaces = scope.get("surfaces")
    require(isinstance(surfaces, list), "surfaces must be a list")
    seen = {validate_surface(surface, test_source) for surface in surfaces}
    require(seen == REQUIRED_SURFACES, f"surfaces must be exactly {sorted(REQUIRED_SURFACES)}")

    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "Scripts/validate-numiseal-conformance-scope.py" in gate,
        "production gate must run validate-numiseal-conformance-scope.py",
    )
    release_validator = (ROOT / "Scripts" / "validate-release-readiness-policy.py").read_text(encoding="utf-8")
    require(
        "TestVectors/numiseal-conformance-scope-v1.json" in release_validator,
        "release readiness policy must pin the NumiSeal conformance scope manifest",
    )
    print("NumiSeal conformance scope validation passed")


if __name__ == "__main__":
    main()
