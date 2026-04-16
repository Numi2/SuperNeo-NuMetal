#!/usr/bin/env python3
"""Regression tests for product crypto security dossier validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DOSSIER = ROOT / "TestVectors" / "product-crypto-security-dossier-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-crypto-security-dossier.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    dossier = json.loads(DOSSIER.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".product-crypto-dossier-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(dossier)
        wrong_claim["claimStatus"] = "production-product-security-theorem"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        wrong_depth = copy.deepcopy(dossier)
        wrong_depth["supportedProductDepth"]["theoremMaximumDepth"] = 2
        path = tmp / "wrong-depth.json"
        write_json(path, wrong_depth)
        run_fail(str(VALIDATE), str(path))

        premature_poly_depth = copy.deepcopy(dossier)
        premature_poly_depth["supportedProductDepth"]["polyDepthTheoremClaimAllowed"] = True
        path = tmp / "premature-poly-depth.json"
        write_json(path, premature_poly_depth)
        run_fail(str(VALIDATE), str(path))

        wrong_q = copy.deepcopy(dossier)
        wrong_q["latticeAssumptionDossier"]["qDecimal"] = "18446744073709551557"
        path = tmp / "wrong-q.json"
        write_json(path, wrong_q)
        run_fail(str(VALIDATE), str(path))

        premature_pq = copy.deepcopy(dossier)
        premature_pq["latticeAssumptionDossier"]["productionPostQuantumClaimAllowed"] = True
        path = tmp / "premature-pq.json"
        write_json(path, premature_pq)
        run_fail(str(VALIDATE), str(path))

        premature_qrom = copy.deepcopy(dossier)
        premature_qrom["fiatShamirQROMPosition"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-qrom.json"
        write_json(path, premature_qrom)
        run_fail(str(VALIDATE), str(path))

        missing_coverage = copy.deepcopy(dossier)
        missing_coverage["productTheoremCoverage"].remove("artifact/proof-envelope binding")
        path = tmp / "missing-coverage.json"
        write_json(path, missing_coverage)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(dossier)
        outsourced_review["supportedProductDepth"]["remainingForDepthPromotion"].append("External" + " audit required.")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        premature_all_clear = copy.deepcopy(dossier)
        premature_all_clear["promotionRule"]["productionProductSecurityClaimAllowed"] = True
        path = tmp / "premature-all-clear.json"
        write_json(path, premature_all_clear)
        run_fail(str(VALIDATE), str(path))

    print("product crypto security dossier validation regression tests passed")


if __name__ == "__main__":
    main()
