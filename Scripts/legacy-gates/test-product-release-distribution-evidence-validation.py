#!/usr/bin/env python3
"""Regression tests for product release-distribution evidence validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
VALIDATE = ROOT / "Scripts" / "validate-product-release-distribution-evidence.py"
EVIDENCE = ROOT / "TestVectors" / "product-release-distribution-evidence-v1.json"


def load_evidence() -> dict[str, Any]:
    return json.loads(EVIDENCE.read_text(encoding="utf-8"))


def write_evidence(path: Path, evidence: dict[str, Any]) -> None:
    path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_mutated_validator(mutation: Callable[[dict[str, Any]], None]) -> subprocess.CompletedProcess[str]:
    evidence = copy.deepcopy(load_evidence())
    mutation(evidence)
    with tempfile.TemporaryDirectory(prefix=".release-distribution-test-", dir=ROOT) as raw_tmp:
        path = Path(raw_tmp) / EVIDENCE.name
        write_evidence(path, evidence)
        return subprocess.run(
            [str(VALIDATE), str(path)],
            cwd=ROOT,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )


def expect_failure(
    name: str,
    mutation: Callable[[dict[str, Any]], None],
    expected_output: str,
) -> None:
    result = run_mutated_validator(mutation)
    combined = result.stdout + result.stderr
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    if expected_output not in combined:
        raise AssertionError(f"{name}: expected {expected_output!r}, got {combined!r}")


def production_release_disabled(evidence: dict[str, Any]) -> None:
    evidence["releaseClassPolicy"]["productionSecurityReleaseAllowed"] = False


def repository_local_distribution_disabled(evidence: dict[str, Any]) -> None:
    evidence["signingStatus"]["repositoryLocalUnsignedDistributionAllowed"] = False


def production_claim_disabled(evidence: dict[str, Any]) -> None:
    evidence["promotionRule"]["productionReleaseDistributionClaimAllowed"] = False


def missing_artifact_family(evidence: dict[str, Any]) -> None:
    evidence["requiredArtifactFamilies"].pop()


def wrong_loss_symbol(evidence: dict[str, Any]) -> None:
    evidence["releaseClassPolicy"]["releaseDistributionLossSymbol"] = "epsilon_qrom"


def missing_formal_declaration(evidence: dict[str, Any]) -> None:
    evidence["formalSurface"]["declarations"].remove("ProductReleaseDistributionEvidenceAccepted")


def main() -> None:
    subprocess.run([str(VALIDATE)], cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    expect_failure(
        "production release disabled",
        production_release_disabled,
        "repository-local production release must be allowed",
    )
    expect_failure(
        "repository-local distribution disabled",
        repository_local_distribution_disabled,
        "signingStatus.repositoryLocalUnsignedDistributionAllowed must be true",
    )
    expect_failure(
        "production claim disabled",
        production_claim_disabled,
        "promotionRule.productionReleaseDistributionClaimAllowed must be true",
    )
    expect_failure(
        "missing artifact family",
        missing_artifact_family,
        "requiredArtifactFamilies must stay in the pinned order",
    )
    expect_failure(
        "wrong loss symbol",
        wrong_loss_symbol,
        "releaseDistributionLossSymbol mismatch",
    )
    expect_failure(
        "missing formal declaration",
        missing_formal_declaration,
        "formalSurface.declarations mismatch",
    )
    print("product release distribution evidence validation regression tests passed")


if __name__ == "__main__":
    main()
