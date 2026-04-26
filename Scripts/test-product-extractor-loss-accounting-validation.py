#!/usr/bin/env python3
"""Regression tests for product extractor loss accounting validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACCOUNTING = ROOT / "TestVectors" / "product-extractor-loss-accounting-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-extractor-loss-accounting.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    accounting = json.loads(ACCOUNTING.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".extractor-loss-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(accounting)
        wrong_claim["claimStatus"] = "production-extractor-proof"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        premature_depth = copy.deepcopy(accounting)
        premature_depth["selectedDepth"]["selectedMaximumDepth"] = 2
        path = tmp / "premature-depth.json"
        write_json(path, premature_depth)
        run_fail(str(VALIDATE), str(path))

        stale_recurrence = copy.deepcopy(accounting)
        stale_recurrence["chainRootRecurrence"]["selectedDepth"] = 2
        path = tmp / "stale-recurrence.json"
        write_json(path, stale_recurrence)
        run_fail(str(VALIDATE), str(path))

        metadata_root = copy.deepcopy(accounting)
        metadata_root["chainRootRecurrence"]["extractorProcedure"] = "accept claimed recursive root from artifact metadata"
        path = tmp / "metadata-root.json"
        write_json(path, metadata_root)
        run_fail(str(VALIDATE), str(path))

        missing_extractor = copy.deepcopy(accounting)
        missing_extractor["extractorInterface"]["concreteExtractorImplemented"] = False
        path = tmp / "premature-extractor.json"
        write_json(path, missing_extractor)
        run_fail(str(VALIDATE), str(path))

        missing_terminal = copy.deepcopy(accounting)
        missing_terminal["componentLosses"] = [
            row for row in missing_terminal["componentLosses"] if row["id"] != "terminal-seal-extractor"
        ]
        path = tmp / "missing-terminal.json"
        write_json(path, missing_terminal)
        run_fail(str(VALIDATE), str(path))

        missing_budget = copy.deepcopy(accounting)
        missing_budget["lossRule"]["extractorLossWithinBudget"] = False
        path = tmp / "premature-budget.json"
        write_json(path, missing_budget)
        run_fail(str(VALIDATE), str(path))

        missing_carry_symbol = copy.deepcopy(accounting)
        missing_carry_symbol["lossRule"]["recursivePromotionExpression"] = "epsilon_extract(depth=d) = d * epsilon_extract_source_fold"
        path = tmp / "missing-carry-symbol.json"
        write_json(path, missing_carry_symbol)
        run_fail(str(VALIDATE), str(path))

        reopened_blocker = copy.deepcopy(accounting)
        reopened_blocker["hardClaimBlockers"].append("recursive carry extractor for promoted depth beyond selected depth 3")
        path = tmp / "reopened-blocker.json"
        write_json(path, reopened_blocker)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(accounting)
        outsourced_review["hardClaimBlockers"].append("external" + " audit")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        missing_promotion = copy.deepcopy(accounting)
        missing_promotion["promotionRule"]["productionExtractorClaimAllowed"] = False
        path = tmp / "premature-promotion.json"
        write_json(path, missing_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product extractor loss accounting validation regression tests passed")


if __name__ == "__main__":
    main()
