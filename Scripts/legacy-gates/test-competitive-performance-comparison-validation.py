#!/usr/bin/env python3
"""Regression tests for competitive performance comparison validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "competitive-performance-comparison-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-competitive-performance-comparison.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def system_by_id(manifest: dict[str, object], system_id: str) -> dict[str, object]:
    for item in manifest["systems"]:
        if item["id"] == system_id:
            return item
    raise AssertionError(f"missing system id {system_id}")


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".competitive-performance-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_chip = copy.deepcopy(manifest)
        wrong_chip["sameHardwareEnvironment"]["chip"] = "Apple M5"
        path = tmp / "wrong-chip.json"
        write_json(path, wrong_chip)
        run_fail(str(VALIDATE), str(path))

        missing_row = copy.deepcopy(manifest)
        missing_row["systems"] = [
            item for item in missing_row["systems"] if item["id"] != "winterfell-lamport-a-64"
        ]
        path = tmp / "missing-winterfell.json"
        write_json(path, missing_row)
        run_fail(str(VALIDATE), str(path))

        stale_local_time = copy.deepcopy(manifest)
        system_by_id(stale_local_time, "superneo-numiseal-terminal")["proverTime"]["milliseconds"] = 421
        path = tmp / "stale-local-time.json"
        write_json(path, stale_local_time)
        run_fail(str(VALIDATE), str(path))

        wrong_metal_ratio = copy.deepcopy(manifest)
        system_by_id(wrong_metal_ratio, "superneo-numiseal-terminal")["metalVsCpuCost"]["metalToCpuRatio"] = 2.0
        path = tmp / "wrong-metal-ratio.json"
        write_json(path, wrong_metal_ratio)
        run_fail(str(VALIDATE), str(path))

        wrong_estimator = copy.deepcopy(manifest)
        system_by_id(wrong_estimator, "superneo-numiseal-terminal")["parameterSecurityLevel"]["defaultEstimatorRopBits"] = 128.0
        path = tmp / "wrong-estimator.json"
        write_json(path, wrong_estimator)
        run_fail(str(VALIDATE), str(path))


if __name__ == "__main__":
    main()
