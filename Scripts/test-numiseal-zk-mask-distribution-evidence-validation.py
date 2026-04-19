#!/usr/bin/env python3
"""Regression tests for NumiSealZK mask-distribution evidence validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-zk-mask-distribution-evidence-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-numiseal-zk-mask-distribution-evidence.py"


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
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".numiseal-zk-mask-evidence-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(manifest)
        wrong_claim["claimStatus"] = "production-zk-privacy-proof"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        modulo_sampler = copy.deepcopy(manifest)
        modulo_sampler["sampler"]["acceptanceCondition"] = "candidate is reduced modulo GoldilocksField.modulus"
        path = tmp / "modulo-sampler.json"
        write_json(path, modulo_sampler)
        run_fail(str(VALIDATE), str(path))

        nonzero_distance = copy.deepcopy(manifest)
        nonzero_distance["sampler"]["statisticalDistanceFromUniformAcceptedFieldElement"] = "2^-32"
        path = tmp / "nonzero-distance.json"
        write_json(path, nonzero_distance)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(manifest)
        premature_promotion["promotionRule"]["productionZKPrivacyClaimAllowed"] = False
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(manifest)
        outsourced_review["promotionRule"]["remainingBoundaries"].append("External" + " audit required.")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

    print("NumiSealZK mask-distribution evidence validation regression tests passed")


if __name__ == "__main__":
    main()
