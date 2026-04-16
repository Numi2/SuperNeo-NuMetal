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
    require(require_int(surfaces.get("proofEnvelopeHeaderVersion"), "proofEnvelopeHeaderVersion") == 4, "proof envelope version must be 4")
    require(require_int(surfaces.get("numiSealProofEnvelopeKind"), "numiSealProofEnvelopeKind") == 4, "NumiSeal envelope kind must be 4")
    require_string(surfaces.get("r1csSchemaID"), "r1csSchemaID")
    require_string(surfaces.get("numiSealSchemaID"), "numiSealSchemaID")

    documentation = require_dict(evidence.get("documentation"), "documentation")
    for key in ["auditPacket", "releaseEngineering", "schemaCompatibility", "releaseRunbook", "changelog"]:
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
