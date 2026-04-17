#!/usr/bin/env python3
"""Regression tests for product CTCO/QROM instantiation validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-qrom-ctco-instantiation-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-ctco-instantiation.py"


def load_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_mutation(mutation: Callable[[dict[str, Any]], None]) -> subprocess.CompletedProcess[str]:
    manifest = copy.deepcopy(load_manifest())
    mutation(manifest)
    with tempfile.TemporaryDirectory(prefix=".qrom-ctco-test-", dir=ROOT) as tmpdir:
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
        "weak binding width",
        lambda manifest: manifest["numericBounds"].__setitem__("bindingDigestBits", 256),
        "bindingDigestBits must be 384",
    )
    expect_failure(
        "wrong proof-kind malleability",
        lambda manifest: manifest["numericBounds"].__setitem__("proofKindMalleabilityFormula", "epsilon"),
        "proof-kind malleability formula mismatch",
    )
    expect_failure(
        "wrong challenge domain",
        lambda manifest: manifest["ctcoCompiler"].__setitem__("challengeDomain", "legacy"),
        "challenge domain mismatch",
    )
    expect_failure(
        "premature qrom promotion",
        lambda manifest: manifest["promotionRule"].__setitem__("productionQROMClaimAllowed", True),
        "productionQROMClaimAllowed must be false",
    )
    print("product QROM CTCO instantiation validation regression tests passed")


if __name__ == "__main__":
    main()
