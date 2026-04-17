#!/usr/bin/env python3
"""Regression tests for product total-loss budget validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUDGET = ROOT / "TestVectors" / "product-total-loss-budget-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-total-loss-budget.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    budget = json.loads(BUDGET.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".total-loss-budget-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(budget)
        wrong_claim["claimStatus"] = "production-total-loss-budget"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        missing_qrom = copy.deepcopy(budget)
        missing_qrom["relatedManifests"].pop("productQROMFiatShamirAccounting")
        path = tmp / "missing-qrom.json"
        write_json(path, missing_qrom)
        run_fail(str(VALIDATE), str(path))

        missing_qrom_schedule = copy.deepcopy(budget)
        missing_qrom_schedule["relatedManifests"].pop("productQROMTranscriptSchedule")
        path = tmp / "missing-qrom-schedule.json"
        write_json(path, missing_qrom_schedule)
        run_fail(str(VALIDATE), str(path))

        wrong_security_bits = copy.deepcopy(budget)
        wrong_security_bits["budgetModel"]["selectedSecurityBudgetBits"] = 64
        path = tmp / "wrong-security-bits.json"
        write_json(path, wrong_security_bits)
        run_fail(str(VALIDATE), str(path))

        reordered_components = copy.deepcopy(budget)
        reordered_components["componentBounds"][0], reordered_components["componentBounds"][1] = (
            reordered_components["componentBounds"][1],
            reordered_components["componentBounds"][0],
        )
        path = tmp / "reordered-components.json"
        write_json(path, reordered_components)
        run_fail(str(VALIDATE), str(path))

        missing_collision = copy.deepcopy(budget)
        missing_collision["componentBounds"] = [
            row for row in missing_collision["componentBounds"] if row["id"] != "transcript-collision-domain-separation"
        ]
        path = tmp / "missing-collision.json"
        write_json(path, missing_collision)
        run_fail(str(VALIDATE), str(path))

        premature_bound = copy.deepcopy(budget)
        premature_bound["componentBounds"][0]["boundLog2"] = 256
        path = tmp / "premature-bound.json"
        write_json(path, premature_bound)
        run_fail(str(VALIDATE), str(path))

        stale_missing_list = copy.deepcopy(budget)
        stale_missing_list["computedBudget"]["missingRequiredTermIDs"] = []
        path = tmp / "stale-missing-list.json"
        write_json(path, stale_missing_list)
        run_fail(str(VALIDATE), str(path))

        premature_within_budget = copy.deepcopy(budget)
        premature_within_budget["computedBudget"]["selectedDepthLossWithinBudget"] = True
        path = tmp / "premature-within-budget.json"
        write_json(path, premature_within_budget)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(budget)
        premature_promotion["promotionRule"]["productionProductSecurityClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(budget)
        outsourced_review["componentBounds"][0]["requiredEvidence"] += " with external" + " audit"
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

    print("product total-loss budget validation regression tests passed")


if __name__ == "__main__":
    main()
