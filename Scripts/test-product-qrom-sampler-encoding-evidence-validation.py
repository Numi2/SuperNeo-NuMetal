#!/usr/bin/env python3
"""Regression tests for product QROM sampler/encoding evidence validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-sampler-encoding-evidence.py"
EVIDENCE = ROOT / "TestVectors" / "product-qrom-sampler-encoding-evidence-v1.json"


def load_evidence() -> dict[str, Any]:
    return json.loads(EVIDENCE.read_text(encoding="utf-8"))


def write_evidence(path: Path, evidence: dict[str, Any]) -> None:
    path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")


def run_mutated_validator(
    mutation: Callable[[dict[str, Any]], None],
) -> subprocess.CompletedProcess[str]:
    evidence = copy.deepcopy(load_evidence())
    mutation(evidence)
    with tempfile.TemporaryDirectory(prefix=".qrom-sampler-test-", dir=ROOT) as raw_tmp:
        temp_root = Path(raw_tmp)
        evidence_path = temp_root / EVIDENCE.name
        write_evidence(evidence_path, evidence)
        return subprocess.run(
            [str(VALIDATE), str(evidence_path)],
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
    combined_output = result.stdout + result.stderr
    if result.returncode == 0:
        raise AssertionError(f"{name}: validator succeeded unexpectedly")
    if expected_output not in combined_output:
        raise AssertionError(
            f"{name}: expected output to contain {expected_output!r}, got {combined_output!r}"
        )


def wrong_goldilocks_rejection(evidence: dict[str, Any]) -> None:
    evidence["samplerUniformity"]["goldilocksFieldSampler"]["rejectedValues"] = 1


def biased_phi81_limit(evidence: dict[str, Any]) -> None:
    evidence["samplerUniformity"]["phi81CoefficientSampler"]["limit"] = (1 << 64)


def missing_transcript_injectivity(evidence: dict[str, Any]) -> None:
    evidence["transcriptEncoding"]["structuredFrameInjective"] = False


def production_claim_enabled(evidence: dict[str, Any]) -> None:
    evidence["integrationStatus"]["productionQROMClaimAllowed"] = True


def missing_formal_declaration(evidence: dict[str, Any]) -> None:
    evidence["formalSurface"]["declarations"].remove("transcriptFrameEncode_injective")


def main() -> None:
    subprocess.run([str(VALIDATE)], cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    expect_failure(
        "wrong Goldilocks rejection count",
        wrong_goldilocks_rejection,
        "field rejectedValues mismatch",
    )
    expect_failure(
        "biased Phi81 rejection limit",
        biased_phi81_limit,
        "Phi81 coefficient rejection limit mismatch",
    )
    expect_failure(
        "missing transcript injectivity",
        missing_transcript_injectivity,
        "transcriptEncoding.structuredFrameInjective must be true",
    )
    expect_failure(
        "production claim enabled",
        production_claim_enabled,
        "integrationStatus.productionQROMClaimAllowed must be false",
    )
    expect_failure(
        "missing formal declaration",
        missing_formal_declaration,
        "formalSurface.declarations mismatch",
    )
    print("product QROM sampler/encoding evidence validation regression tests passed")


if __name__ == "__main__":
    main()
