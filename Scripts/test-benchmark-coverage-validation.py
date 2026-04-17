#!/usr/bin/env python3
"""Regression tests for benchmark coverage validation."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "benchmark-coverage-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-benchmark-coverage.py"


def load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_validator(path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VALIDATE), str(path)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_failure(name: str, result: subprocess.CompletedProcess[str], expected_output: str) -> None:
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    combined = result.stdout + result.stderr
    if expected_output not in combined:
        raise AssertionError(f"{name}: expected {expected_output!r}, got {combined!r}")


def test_valid_manifest(temp_root: Path) -> None:
    path = temp_root / "valid.json"
    write_json(path, load_manifest())
    result = run_validator(path)
    require(result.returncode == 0, result.stderr + result.stdout)
    require("benchmark coverage validation passed" in result.stdout, "valid manifest did not pass")


def test_missing_surface(temp_root: Path) -> None:
    manifest = load_manifest()
    manifest["requiredSurfaces"] = [
        surface for surface in manifest["requiredSurfaces"] if surface["id"] != "numiseal-product"
    ]
    path = temp_root / "missing-surface.json"
    write_json(path, manifest)
    expect_failure("missing surface", run_validator(path), "missing required benchmark surfaces")


def test_missing_row(temp_root: Path) -> None:
    manifest = load_manifest()
    for surface in manifest["requiredSurfaces"]:
        if surface["id"] == "recursive-carry":
            surface["requiredRows"] = ["numisealProduct/recursiveCarry/not-registered/"]
            break
    path = temp_root / "missing-row.json"
    write_json(path, manifest)
    expect_failure("missing row", run_validator(path), "missing benchmark row prefix")


def test_boundary_precision(temp_root: Path) -> None:
    manifest = load_manifest()
    manifest["claimStatus"] = "production-performance-claim"
    path = temp_root / "bad-status.json"
    write_json(path, manifest)
    expect_failure("bad claim status", run_validator(path), "claimStatus must stay precise")

    manifest = load_manifest()
    manifest["coverageBoundaries"] = ["fresh hardware numbers are complete"]
    path = temp_root / "bad-boundaries.json"
    write_json(path, manifest)
    expect_failure("bad boundaries", run_validator(path), "coverageBoundaries must mention")


def test_duplicate_keys(temp_root: Path) -> None:
    path = temp_root / "duplicate.json"
    path.write_text(
        '{"schemaVersion": 1, "schemaVersion": 1, "scopeID": "superneo-whole-stack-benchmark-coverage-v1"}\n',
        encoding="utf-8",
    )
    expect_failure("duplicate keys", run_validator(path), "duplicate JSON object key")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="superneo-benchmark-coverage-") as raw_tmp:
        temp_root = Path(raw_tmp)
        test_valid_manifest(temp_root)
        test_missing_surface(temp_root)
        test_missing_row(temp_root)
        test_boundary_precision(temp_root)
        test_duplicate_keys(temp_root)
    print("benchmark coverage validation regression tests passed")


if __name__ == "__main__":
    main()
