#!/usr/bin/env python3
"""Regression tests for selected-depth product loss accounting validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "TestVectors" / "product-selected-depth-loss-accounting-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-selected-depth-loss-accounting.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".selected-depth-loss-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(ledger)
        wrong_claim["claimStatus"] = "production-selected-depth-loss-accounting"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        premature_depth = copy.deepcopy(ledger)
        premature_depth["selectedDepth"]["selectedMaximumDepth"] = 2
        path = tmp / "premature-depth.json"
        write_json(path, premature_depth)
        run_fail(str(VALIDATE), str(path))

        premature_total = copy.deepcopy(ledger)
        premature_total["totalLossRule"]["totalLossWithinBudget"] = True
        path = tmp / "premature-total.json"
        write_json(path, premature_total)
        run_fail(str(VALIDATE), str(path))

        missing_extractor = copy.deepcopy(ledger)
        missing_extractor["componentLosses"] = [
            row for row in missing_extractor["componentLosses"] if row["id"] != "extractor-instantiation"
        ]
        path = tmp / "missing-extractor.json"
        write_json(path, missing_extractor)
        run_fail(str(VALIDATE), str(path))

        missing_extractor_accounting = copy.deepcopy(ledger)
        missing_extractor_accounting["relatedManifests"].pop("productExtractorLossAccounting")
        path = tmp / "missing-extractor-accounting.json"
        write_json(path, missing_extractor_accounting)
        run_fail(str(VALIDATE), str(path))

        missing_qrom_accounting = copy.deepcopy(ledger)
        missing_qrom_accounting["relatedManifests"].pop("productQROMFiatShamirAccounting")
        path = tmp / "missing-qrom-accounting.json"
        write_json(path, missing_qrom_accounting)
        run_fail(str(VALIDATE), str(path))

        missing_qrom_schedule = copy.deepcopy(ledger)
        missing_qrom_schedule["relatedManifests"].pop("productQROMTranscriptSchedule")
        path = tmp / "missing-qrom-schedule.json"
        write_json(path, missing_qrom_schedule)
        run_fail(str(VALIDATE), str(path))

        missing_total_budget = copy.deepcopy(ledger)
        missing_total_budget["relatedManifests"].pop("productTotalLossBudget")
        path = tmp / "missing-total-budget.json"
        write_json(path, missing_total_budget)
        run_fail(str(VALIDATE), str(path))

        reordered_components = copy.deepcopy(ledger)
        reordered_components["componentLosses"][0], reordered_components["componentLosses"][1] = (
            reordered_components["componentLosses"][1],
            reordered_components["componentLosses"][0],
        )
        path = tmp / "reordered-components.json"
        write_json(path, reordered_components)
        run_fail(str(VALIDATE), str(path))

        premature_ct = copy.deepcopy(ledger)
        for row in premature_ct["componentLosses"]:
            if row["id"] == "constant-time-side-channel":
                row["productionClaimAllowed"] = True
        path = tmp / "premature-ct.json"
        write_json(path, premature_ct)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(ledger)
        missing_blocker["hardClaimBlockers"].remove("QROM transcript schedule and Fiat-Shamir loss accounting")
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

        missing_collision = copy.deepcopy(ledger)
        missing_collision["componentLosses"] = [
            row for row in missing_collision["componentLosses"] if row["id"] != "transcript-collision-domain-separation"
        ]
        path = tmp / "missing-collision.json"
        write_json(path, missing_collision)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(ledger)
        outsourced_review["hardClaimBlockers"].append("external" + " audit")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(ledger)
        premature_promotion["promotionRule"]["productionProductSecurityClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product selected-depth loss accounting validation regression tests passed")


if __name__ == "__main__":
    main()
