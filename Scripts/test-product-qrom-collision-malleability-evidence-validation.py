#!/usr/bin/env python3
"""Regression tests for product QROM H_bind collision/malleability validation."""

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


def weak_binding_bits(evidence: dict[str, Any]) -> None:
    evidence["bindingTargetBound"]["bindingDigestBits"] = 256


def wrong_target_count(evidence: dict[str, Any]) -> None:
    evidence["bindingTargetBound"]["bindingTargetEventCount"] = 8


def malleability_inside_qrom(evidence: dict[str, Any]) -> None:
    evidence["residualEvents"]["epsilonProofKindMalleabilityInsideEpsilonQROM"] = True


def digest_bound_removed(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["digestCollisionBoundInstantiated"] = False


def source_hbind_removed(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["sourceHBindImplementationComplete"] = False


def production_claim_enabled(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["productionQROMClaimAllowed"] = True


def concrete_hash_proof_enabled(evidence: dict[str, Any]) -> None:
    evidence["closureStatus"]["hashQROInstantiationProofProvided"] = True


def missing_binding_target(evidence: dict[str, Any]) -> None:
    evidence["acceptedProofKinds"][4]["residualMalleabilityEvent"] = "requires collision"


def main() -> None:
    subprocess.run([str(VALIDATE)], cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    expect_failure(
        "weak binding bits",
        weak_binding_bits,
        "bindingDigestBits must be 384",
    )
    expect_failure(
        "wrong target count",
        wrong_target_count,
        "bindingTargetEventCount must be 9",
    )
    expect_failure(
        "malleability inside qrom",
        malleability_inside_qrom,
        "epsilonProofKindMalleabilityInsideEpsilonQROM must be false",
    )
    expect_failure(
        "digest bound removed",
        digest_bound_removed,
        "closureStatus.digestCollisionBoundInstantiated must be true",
    )
    expect_failure(
        "source hbind removed",
        source_hbind_removed,
        "closureStatus.sourceHBindImplementationComplete must be true",
    )
    expect_failure(
        "production claim enabled",
        production_claim_enabled,
        "closureStatus.productionQROMClaimAllowed must be false",
    )
    expect_failure(
        "concrete hash proof enabled",
        concrete_hash_proof_enabled,
        "closureStatus.hashQROInstantiationProofProvided must be false",
    )
    expect_failure(
        "missing binding target terminology",
        missing_binding_target,
        "residualMalleabilityEvent must use binding-target terminology",
    )
    print("product QROM H_bind collision/malleability validation regression tests passed")


if __name__ == "__main__":
    main()
