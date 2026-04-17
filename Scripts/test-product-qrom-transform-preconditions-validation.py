#!/usr/bin/env python3
"""Regression tests for product QROM CTCO transform-precondition validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PRECONDITIONS = ROOT / "TestVectors" / "product-qrom-transform-preconditions-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-transform-preconditions.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    preconditions = json.loads(PRECONDITIONS.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".qrom-preconditions-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(preconditions)
        wrong_claim["claimStatus"] = "production-qrom-transform-proof"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        missing_source = copy.deepcopy(preconditions)
        missing_source["researchBasis"] = [
            row for row in missing_source["researchBasis"] if row["id"] != "DFMS22"
        ]
        path = tmp / "missing-source.json"
        write_json(path, missing_source)
        run_fail(str(VALIDATE), str(path))

        wrong_profile = copy.deepcopy(preconditions)
        wrong_profile["selectedTransformProfile"]["compilerFamily"] = "DFM20"
        path = tmp / "wrong-profile.json"
        write_json(path, wrong_profile)
        run_fail(str(VALIDATE), str(path))

        weak_binding = copy.deepcopy(preconditions)
        weak_binding["selectedTransformProfile"]["bindingOracleBits"] = 256
        path = tmp / "weak-binding.json"
        write_json(path, weak_binding)
        run_fail(str(VALIDATE), str(path))

        missing_seed_precondition = copy.deepcopy(preconditions)
        missing_seed_precondition["preconditions"][1]["satisfied"] = False
        path = tmp / "missing-seed-precondition.json"
        write_json(path, missing_seed_precondition)
        run_fail(str(VALIDATE), str(path))

        missing_uniformity = copy.deepcopy(preconditions)
        missing_uniformity["preconditions"][3]["satisfied"] = False
        path = tmp / "missing-uniformity.json"
        write_json(path, missing_uniformity)
        run_fail(str(VALIDATE), str(path))

        missing_precondition = copy.deepcopy(preconditions)
        missing_precondition["preconditions"] = [
            row for row in missing_precondition["preconditions"] if row["id"] != "quantum-query-bound"
        ]
        path = tmp / "missing-precondition.json"
        write_json(path, missing_precondition)
        run_fail(str(VALIDATE), str(path))

        wrong_kind_count = copy.deepcopy(preconditions)
        wrong_kind_count["proofKindFit"][0]["challengeCountN"] = 204
        path = tmp / "wrong-kind-count.json"
        write_json(path, wrong_kind_count)
        run_fail(str(VALIDATE), str(path))

        wrong_legacy_metric = copy.deepcopy(preconditions)
        wrong_legacy_metric["proofKindFit"][4]["legacyMaximumProtocolChallengeDerivations"] = 1
        path = tmp / "wrong-legacy-metric.json"
        write_json(path, wrong_legacy_metric)
        run_fail(str(VALIDATE), str(path))

        missing_loss_symbol = copy.deepcopy(preconditions)
        missing_loss_symbol["lossInterface"]["selectedDepthExpression"] = "epsilon_qrom(depth=1) = epsilon_interactive"
        path = tmp / "missing-loss-symbol.json"
        write_json(path, missing_loss_symbol)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(preconditions)
        missing_blocker["hardClaimBlockers"] = ["interactive special-soundness bounds for every accepted proof kind"]
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(preconditions)
        premature_promotion["promotionRule"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product QROM CTCO transform precondition validation regression tests passed")


if __name__ == "__main__":
    main()
