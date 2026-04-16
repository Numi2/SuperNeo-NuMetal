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


def run_text(*command: str) -> str:
    completed = subprocess.run(
        command,
        cwd=ROOT,
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
    status_short = run_text("git", "status", "--short")
    dirty = bool(status_short)
    if dirty and not args.allow_dirty:
        raise SystemExit("working tree is dirty; pass --allow-dirty for non-release fixture evidence")

    formal_status = read_json("Docs/FormalStatus.json")
    blocker_groups = formal_status.get("blocker_groups", [])
    if not isinstance(blocker_groups, list):
        blocker_groups = []

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
            "lean": run_text("lean", "--version").splitlines()[0],
            "lake": run_text("lake", "--version").splitlines()[0],
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
            "constantTimeScopeVersion": int(read_json("TestVectors/constant-time-scope-v1.json")["schemaVersion"]),
            "constantTimeScopeDigestHex": sha256_hex("TestVectors/constant-time-scope-v1.json"),
            "e2eProofMetricsVersion": scoped_manifest_version("TestVectors/e2e-proof-metrics-v1.json"),
            "e2eProofMetricsDigestHex": sha256_hex("TestVectors/e2e-proof-metrics-v1.json"),
            "e2eProofMetricsTrackedArtifactCount": list_count("TestVectors/e2e-proof-metrics-v1.json", "trackedArtifacts"),
            "e2eProofMetricsGeneratedBudgetCount": list_count("TestVectors/e2e-proof-metrics-v1.json", "generatedProductBudgets"),
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
            "constantTimeEvidence": "Docs/ConstantTimeEvidence-2026-04-16.md",
            "constantTimeScope": "TestVectors/constant-time-scope-v1.json",
            "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
            "e2eProofMetricsPolicy": "Docs/E2EProofMetrics-2026-04-16.md",
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
        },
        "productionSecurityBoundaries": [
            "A conditional source/formal constant-time trace scope is recorded; compiler lowering, runtime allocation, and hardware observations remain explicit boundaries.",
            "E2E proof-size budgets are checked for deterministic vectors and local product smokes; hardware latency claims still require fresh benchmark evidence.",
            "Local product-ops readiness and signed revocation-feed verification are machine-readable and audit-exported; no hosted product replay-protection, provenance, persistence, revocation-distribution, or access-control service is recorded.",
            "NumiSeal product, carry, and ZK formalization remains tracked by the conformance scope manifest.",
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
