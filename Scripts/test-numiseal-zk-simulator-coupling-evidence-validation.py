#!/usr/bin/env python3
"""Regression tests for NumiSealZK simulator-coupling evidence validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-zk-simulator-coupling-evidence-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-numiseal-zk-simulator-coupling-evidence.py"


def load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_mutation(mutation: Callable[[dict[str, Any]], None]) -> subprocess.CompletedProcess[str]:
    manifest = copy.deepcopy(load_manifest())
    mutation(manifest)
    with tempfile.TemporaryDirectory(prefix=".zk-coupling-test-", dir=ROOT) as tmpdir:
        path = Path(tmpdir) / MANIFEST.name
        write_json(path, manifest)
        return subprocess.run(
            [str(VALIDATE), str(path)],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )


def expect_failure(name: str, mutation: Callable[[dict[str, Any]], None], expected: str) -> None:
    result = run_mutation(mutation)
    combined = result.stdout + result.stderr
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    if expected not in combined:
        raise AssertionError(f"{name}: expected {expected!r}, got {combined!r}")


def main() -> None:
    subprocess.run([str(VALIDATE)], cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    expect_failure(
        "wrong claim",
        lambda manifest: manifest.__setitem__("claimStatus", "production-zk-privacy"),
        "claimStatus must record repository-local proof-level production",
    )
    expect_failure(
        "missing formal surface",
        lambda manifest: manifest.pop("formalSurface"),
        "formalSurface must be an object",
    )
    expect_failure(
        "wrong digest key",
        lambda manifest: manifest["couplingSurface"].__setitem__("metadataDigestKey", "legacyDigest"),
        "metadata digest key mismatch",
    )
    expect_failure(
        "nonzero simulator loss",
        lambda manifest: manifest["proofLevelSimulatorCoupling"].__setitem__("exactUpperBound", "1/2^256"),
        "proof-level simulator loss must be exactly zero",
    )
    expect_failure(
        "missing benchmark row",
        lambda manifest: manifest["benchmarkAndSideChannelPins"].__setitem__("benchmarkRows", ["missing/row/"]),
        "benchmark row not pinned",
    )
    expect_failure(
        "premature promotion",
        lambda manifest: manifest["promotionRule"].__setitem__("productionZKPrivacyClaimAllowed", False),
        "productionZKPrivacyClaimAllowed must be true",
    )
    expect_failure(
        "reopened epsilon zk sim",
        lambda manifest: manifest["promotionRule"].__setitem__(
            "remainingBoundaries",
            ["selected total-loss promotion remains disabled until epsilon_zk_sim is instantiated"],
        ),
        "epsilon_zk_sim must not remain a simulator-coupling boundary",
    )
    print("NumiSealZK simulator-coupling evidence validation regression tests passed")


if __name__ == "__main__":
    main()
