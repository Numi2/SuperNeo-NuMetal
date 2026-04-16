#!/usr/bin/env python3
"""Regression tests for constant-time lowering evidence validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "constant-time-lowering-evidence-v1.json"
RELEASE_EVIDENCE = ROOT / "Evidence" / "ConstantTime" / "swift-llvm-metal-v1" / "manifest.json"
VALIDATE = ROOT / "Scripts" / "validate-constant-time-lowering-evidence.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        valid = tmp / "valid.json"
        write_json(valid, manifest)
        run_ok(str(VALIDATE), str(valid))

        wrong_schema = copy.deepcopy(manifest)
        wrong_schema["schemaVersion"] = 2
        path = tmp / "wrong-schema.json"
        write_json(path, wrong_schema)
        run_fail(str(VALIDATE), str(path))

        vague_status = copy.deepcopy(manifest)
        vague_status["claimStatus"] = "full-swift-llvm-metal-constant-time-proof"
        path = tmp / "vague-status.json"
        write_json(path, vague_status)
        run_fail(str(VALIDATE), str(path))

        missing_boundary = copy.deepcopy(manifest)
        missing_boundary["toolchainBoundaries"] = missing_boundary["toolchainBoundaries"][:-1]
        path = tmp / "missing-boundary.json"
        write_json(path, missing_boundary)
        run_fail(str(VALIDATE), str(path))

        unknown_region = copy.deepcopy(manifest)
        unknown_region["toolchainBoundaries"][0]["regions"].append("missing-region")
        path = tmp / "unknown-region.json"
        write_json(path, unknown_region)
        run_fail(str(VALIDATE), str(path))

        missing_formal = copy.deepcopy(manifest)
        missing_formal["formalModel"]["declarations"].append("missingLoweringTheorem")
        path = tmp / "missing-formal.json"
        write_json(path, missing_formal)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(manifest)
        premature_promotion["promotionRule"]["productionConstantTimeClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

        missing_release_evidence = copy.deepcopy(manifest)
        del missing_release_evidence["releaseEvidenceManifest"]
        path = tmp / "missing-release-evidence.json"
        write_json(path, missing_release_evidence)
        run_fail(str(VALIDATE), str(path))

        missing_observation_lanes = copy.deepcopy(manifest)
        del missing_observation_lanes["observationLaneReports"]
        path = tmp / "missing-observation-lanes.json"
        write_json(path, missing_observation_lanes)
        run_fail(str(VALIDATE), str(path))

        stale_release_artifact = copy.deepcopy(manifest)
        release_evidence = json.loads(RELEASE_EVIDENCE.read_text(encoding="utf-8"))
        release_evidence["artifactEntries"][0]["sha256Hex"] = "0" * 64
        release_path = tmp / "stale-release-evidence.json"
        write_json(release_path, release_evidence)
        stale_release_artifact["releaseEvidenceManifest"] = str(release_path)
        path = tmp / "stale-release-artifact.json"
        write_json(path, stale_release_artifact)
        run_fail(str(VALIDATE), str(path))

        missing_compiler_lane_artifact = copy.deepcopy(manifest)
        release_evidence = json.loads(RELEASE_EVIDENCE.read_text(encoding="utf-8"))
        release_evidence["artifactEntries"] = [
            entry for entry in release_evidence["artifactEntries"]
            if entry.get("id") != "compiler-observation-lanes"
        ]
        release_path = tmp / "missing-compiler-lane-artifact.json"
        write_json(release_path, release_evidence)
        missing_compiler_lane_artifact["releaseEvidenceManifest"] = str(release_path)
        path = tmp / "missing-compiler-lane.json"
        write_json(path, missing_compiler_lane_artifact)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(manifest)
        outsourced_review["promotionRule"]["unblockRequires"].append("External" + " audit required.")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

    print("constant-time lowering evidence validation regression tests passed")


if __name__ == "__main__":
    main()
