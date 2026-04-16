#!/usr/bin/env python3
"""Regression tests for constant-time scope validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "constant-time-scope-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-constant-time-scope.py"


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
        vague_status["claimStatus"] = "formal-constant-time-complete"
        path = tmp / "vague-status.json"
        write_json(path, vague_status)
        run_fail(str(VALIDATE), str(path))

        missing_region = copy.deepcopy(manifest)
        missing_region["regions"] = missing_region["regions"][:-1]
        path = tmp / "missing-region.json"
        write_json(path, missing_region)
        run_fail(str(VALIDATE), str(path))

        missing_marker = copy.deepcopy(manifest)
        missing_marker["regions"][0]["startMarker"] = "// missing-marker"
        path = tmp / "missing-marker.json"
        write_json(path, missing_marker)
        run_fail(str(VALIDATE), str(path))

        unapproved_metal_guard = copy.deepcopy(manifest)
        for region in unapproved_metal_guard["regions"]:
            if region["id"] == "metal-numiseal-zk-secret-bearing-kernels":
                region["allowedPublicControlFlowRegex"] = []
        path = tmp / "unapproved-metal-guard.json"
        write_json(path, unapproved_metal_guard)
        run_fail(str(VALIDATE), str(path))

        missing_formal = copy.deepcopy(manifest)
        missing_formal["formalModel"]["declarations"].append("missingConstantTimeDeclaration")
        path = tmp / "missing-formal.json"
        write_json(path, missing_formal)
        run_fail(str(VALIDATE), str(path))

        missing_lowering_manifest = copy.deepcopy(manifest)
        del missing_lowering_manifest["loweringEvidenceManifest"]
        path = tmp / "missing-lowering-manifest.json"
        write_json(path, missing_lowering_manifest)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(manifest)
        outsourced_review["openBoundaries"].append("External" + " audit required.")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

    print("constant-time scope validation regression tests passed")


if __name__ == "__main__":
    main()
