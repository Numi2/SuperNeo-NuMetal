#!/usr/bin/env python3
"""Regression tests for product QROM collision/malleability evidence validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-collision-malleability-evidence.py"
EVIDENCE = ROOT / "TestVectors" / "product-qrom-collision-malleability-evidence-v1.json"


def load_evidence() -> dict[str, Any]:
    return json.loads(EVIDENCE.read_text(encoding="utf-8"))


def write_evidence(path: Path, evidence: dict[str, Any]) -> None:
    path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def run_mutated_validator(
    mutation: Callable[[dict[str, Any]], None],
) -> subprocess.CompletedProcess[str]:
    evidence = copy.deepcopy(load_evidence())
    mutation(evidence)
    with tempfile.TemporaryDirectory(prefix=".qrom-collision-test-", dir=ROOT) as raw_tmp:
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


def duplicate_envelope_kind(evidence: dict[str, Any]) -> None:
    evidence["acceptedProofKinds"][4]["envelopeKind"] = 4


def structural_closure_removed(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["structuralCollisionMalleabilityExcludedOutsideDigestCollision"] = False


def digest_bound_prematurely_enabled(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["digestCollisionBoundInstantiated"] = True


def production_claim_enabled(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["productionQROMClaimAllowed"] = True


def missing_formal_declaration(evidence: dict[str, Any]) -> None:
    evidence["formalSurface"]["declarations"].remove("proofEnvelopeTranscriptBindingEncode_injective")


def missing_residual_symbol(evidence: dict[str, Any]) -> None:
    evidence["residualEvents"]["transcriptCollisionLossSymbol"] = "epsilon_qrom"


def main() -> None:
    subprocess.run([str(VALIDATE)], cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    expect_failure(
        "duplicate envelope kind",
        duplicate_envelope_kind,
        "acceptedProofKinds must stay in the pinned proof-kind order",
    )
    expect_failure(
        "structural closure removed",
        structural_closure_removed,
        "closureStatus.structuralCollisionMalleabilityExcludedOutsideDigestCollision must be true",
    )
    expect_failure(
        "digest bound prematurely enabled",
        digest_bound_prematurely_enabled,
        "closureStatus.digestCollisionBoundInstantiated must remain false",
    )
    expect_failure(
        "production claim enabled",
        production_claim_enabled,
        "closureStatus.productionQROMClaimAllowed must remain false",
    )
    expect_failure(
        "missing formal declaration",
        missing_formal_declaration,
        "formalSurface.declarations mismatch",
    )
    expect_failure(
        "wrong residual symbol",
        missing_residual_symbol,
        "transcriptCollisionLossSymbol mismatch",
    )
    print("product QROM collision/malleability evidence validation regression tests passed")


if __name__ == "__main__":
    main()
