#!/usr/bin/env python3
"""Regression tests for validate-product-ops-surface.py."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "Scripts" / "validate-product-ops-surface.py"


def fail(message: str) -> None:
    raise SystemExit(message)


def run_validator(root: Path, expect_ok: bool, expected: str = "") -> None:
    result = subprocess.run(
        ["python3", "Scripts/validate-product-ops-surface.py"],
        cwd=root,
        text=True,
        capture_output=True,
    )
    combined = result.stdout + result.stderr
    if expect_ok and result.returncode != 0:
        fail(f"validator failed unexpectedly:\n{combined}")
    if not expect_ok and result.returncode == 0:
        fail("validator succeeded unexpectedly")
    if expected and expected not in combined:
        fail(f"expected output to contain {expected!r}, got:\n{combined}")


def copy_repo_subset(destination: Path) -> None:
    for relative in [
        "SuperNeo-NuMetal/ProductIntegration/LocalProductControls.swift",
        "SuperNeoCLI/main.swift",
        "Docs/ProductOperationsReadiness-2026-04-16.md",
        "Docs/LocalProductControls-2026-04-16.md",
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md",
        "Docs/ReleaseEngineering-2026-04-16.md",
        "Docs/ReleaseCandidateRunbook-2026-04-16.md",
        "Scripts/production-gate.sh",
        "Scripts/validate-release-readiness-policy.py",
        "Scripts/validate-product-ops-surface.py",
        "Scripts/test-product-ops-surface-validation.py",
    ]:
        source = ROOT / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)


def replace_text(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        fail(f"{old!r} not found in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> None:
    run_validator(ROOT, expect_ok=True)

    with tempfile.TemporaryDirectory(prefix="superneo-product-ops-validation-") as raw_tmp:
        tmp = Path(raw_tmp)
        copy_repo_subset(tmp)

        replace_text(
            tmp / "SuperNeoCLI" / "main.swift",
            "operations readiness:",
            "operator state:",
        )
        run_validator(tmp, expect_ok=False, expected="operations readiness:")

    with tempfile.TemporaryDirectory(prefix="superneo-product-ops-validation-") as raw_tmp:
        tmp = Path(raw_tmp)
        copy_repo_subset(tmp)

        replace_text(
            tmp / "Scripts" / "production-gate.sh",
            "run_step Scripts/validate-product-ops-surface.py",
            "# validator omitted",
        )
        run_validator(tmp, expect_ok=False, expected="validate-product-ops-surface.py")

    with tempfile.TemporaryDirectory(prefix="superneo-product-ops-validation-") as raw_tmp:
        tmp = Path(raw_tmp)
        copy_repo_subset(tmp)

        replace_text(
            tmp / "SuperNeo-NuMetal" / "ProductIntegration" / "LocalProductControls.swift",
            "try validateDigestList(trustedProvenanceIssuerKeyDigestsHex, name: \"trusted provenance issuer key digest\")",
            "try validateDigestList(trustedProvenanceIssuerKeyDigestsHex ?? trustedContextIssuerKeyDigestsHex, name: \"trusted provenance issuer key digest\")",
        )
        run_validator(tmp, expect_ok=False, expected="trust roots must not silently fall back")

    with tempfile.TemporaryDirectory(prefix="superneo-product-ops-validation-") as raw_tmp:
        tmp = Path(raw_tmp)
        copy_repo_subset(tmp)

        doc = tmp / "Docs" / "ProductOperationsReadiness-2026-04-16.md"
        doc.write_text(
            doc.read_text(encoding="utf-8") + "\nExternal" + " audit required.\n",
            encoding="utf-8",
        )
        run_validator(tmp, expect_ok=False, expected="outsourced review")

    print("product ops surface validation regression tests passed")


if __name__ == "__main__":
    main()
