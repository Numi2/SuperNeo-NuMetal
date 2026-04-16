#!/usr/bin/env python3
"""Validate release-readiness policy, schema-version, and CI gate drift."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"release readiness policy validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read_text(relative_path: str) -> str:
    path = ROOT / relative_path
    require(path.exists(), f"missing required file: {relative_path}")
    return path.read_text(encoding="utf-8")


def read_json(relative_path: str) -> object:
    try:
        return json.loads(read_text(relative_path))
    except json.JSONDecodeError as error:
        fail(f"{relative_path} is not valid JSON: {error}")


def require_contains(relative_path: str, needles: list[str]) -> None:
    text = read_text(relative_path)
    for needle in needles:
        require(needle in text, f"{relative_path} missing required text: {needle}")


def validate_workflow() -> None:
    workflow = read_text(".github/workflows/production-gate.yml")
    require("name: Full production gate" in workflow, "macOS CI job is not named as the full production gate")
    require("runs-on: macos-latest" in workflow, "full production gate must run on macOS")
    require("run: Scripts/production-gate.sh\n" in workflow, "full production gate must run Scripts/production-gate.sh")
    require("--skip-formal" not in workflow, "CI workflow must not skip formal checks in the full gate")
    for command in [
        "Scripts/validate-formal-ext2-serialization.py",
        "Scripts/test-formal-ext2-serialization-validation.py",
        "Scripts/validate-formal-ce-byte-serialization.py",
        "Scripts/test-formal-ce-byte-serialization-validation.py",
    ]:
        require(command in workflow, f"formal Linux cross-check missing {command}")


def validate_docs() -> None:
    require_contains(
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md",
        [
            "Scripts/production-gate.sh",
            "Result: passed.",
            "Not Yet Production-Ready For",
            "Remaining No-Go Items",
            "independently audited cryptographic library",
            "Docs/ReleaseEngineering-2026-04-16.md",
            "Docs/SchemaCompatibility-2026-04-16.md",
            "Docs/ReleaseCandidateRunbook-2026-04-16.md",
            "Scripts/validate-release-readiness-policy.py",
            "Scripts/generate-release-candidate-evidence.py",
            "Scripts/validate-release-candidate-evidence.py",
        ],
    )
    require_contains(
        "Docs/ReleaseEngineering-2026-04-16.md",
        [
            "Research or Integration Release",
            "Production-Security Release",
            "Scripts/production-gate.sh",
            "without `--skip-formal`",
            "independent cryptographic and implementation security audit",
            "signed artifacts",
            "branch protection requiring the full production gate",
            "Scripts/generate-release-candidate-evidence.py",
        ],
    )
    require_contains(
        "Docs/SchemaCompatibility-2026-04-16.md",
        [
            "`artifactVersion = 1`",
            "`manifestVersion = 1`",
            "`ProofEnvelopeHeader.version = 4`",
            "`numiseal-test-vector-artifact-v1.json`",
            "`test-vector-artifact-v1.json`",
            "Version Bump Checklist",
        ],
    )
    require_contains(
        "Docs/ReleaseCandidateRunbook-2026-04-16.md",
        [
            "Scripts/production-gate.sh",
            "Scripts/generate-release-candidate-evidence.py",
            "Scripts/validate-release-candidate-evidence.py",
            "--expect-production-gate-result passed",
            "unsigned research artifacts",
            "Branch Protection",
        ],
    )
    require_contains(
        "CHANGELOG.md",
        [
            "## Unreleased",
            "Production Readiness",
            "Compatibility",
            "Remaining Production-Security Blockers",
        ],
    )


def require_schema_version(relative_path: str, expected_id_suffix: str) -> None:
    schema = read_json(relative_path)
    require(isinstance(schema, dict), f"{relative_path} root must be a JSON object")
    schema_id = schema.get("$id")
    require(isinstance(schema_id, str), f"{relative_path} must publish a string $id")
    require(schema_id.endswith(expected_id_suffix), f"{relative_path} $id must end with {expected_id_suffix}")
    properties = schema.get("properties")
    require(isinstance(properties, dict), f"{relative_path} must contain object properties")
    artifact_version = properties.get("artifactVersion")
    require(isinstance(artifact_version, dict), f"{relative_path} must constrain artifactVersion")
    require(artifact_version.get("const") == 1, f"{relative_path} artifactVersion const must be 1")


def require_manifest_version(relative_path: str) -> None:
    manifest = read_json(relative_path)
    require(isinstance(manifest, dict), f"{relative_path} root must be a JSON object")
    require(manifest.get("manifestVersion") == 1, f"{relative_path} manifestVersion must be 1")


def validate_schema_versions() -> None:
    require_schema_version("TestVectors/artifact.schema.json", "/test-vector-artifact-v1.json")
    require_schema_version("TestVectors/numiseal-artifact.schema.json", "/numiseal-test-vector-artifact-v1.json")
    require_manifest_version("TestVectors/manifest.json")
    require_manifest_version("TestVectors/numiseal-manifest.json")

    serialization = read_text("SuperNeo-NuMetal/SuperNeoSerialization.swift")
    header_version = re.search(r"public\s+static\s+let\s+version:\s*UInt16\s*=\s*(\d+)", serialization)
    require(header_version is not None, "ProofEnvelopeHeader.version declaration not found")
    require(header_version.group(1) == "4", "ProofEnvelopeHeader.version must remain 4 until compatibility docs are updated")
    numiseal_kind = re.search(r"case\s+numiSealTerminal\s*=\s*(\d+)", serialization)
    require(numiseal_kind is not None, "ProofEnvelopeKind.numiSealTerminal raw value not found")
    require(numiseal_kind.group(1) == "4", "ProofEnvelopeKind.numiSealTerminal must remain kind 4 until compatibility docs are updated")


def validate_production_gate_wiring() -> None:
    gate = read_text("Scripts/production-gate.sh")
    require(
        "release policy, schema compatibility, and CI gate drift validation" in gate,
        "production gate usage text must mention release policy validation",
    )
    require(
        "run_step Scripts/validate-release-readiness-policy.py" in gate,
        "production gate must run validate-release-readiness-policy.py",
    )
    require(
        "run_step Scripts/test-release-candidate-evidence-validation.py" in gate,
        "production gate must run release-candidate evidence regression tests",
    )


def main() -> None:
    validate_workflow()
    validate_docs()
    validate_schema_versions()
    validate_production_gate_wiring()
    print("release readiness policy validation passed")


if __name__ == "__main__":
    main()
