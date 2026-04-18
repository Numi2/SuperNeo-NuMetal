#!/usr/bin/env python3
"""Regression tests for product QROM transcript schedule validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEDULE = ROOT / "TestVectors" / "product-qrom-transcript-schedule-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-transcript-schedule.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    schedule = json.loads(SCHEDULE.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".qrom-schedule-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(schedule)
        wrong_claim["claimStatus"] = "production-qrom-transcript-schedule"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        premature_depth = copy.deepcopy(schedule)
        premature_depth["selectedDepth"]["selectedMaximumDepth"] = 2
        path = tmp / "premature-depth.json"
        write_json(path, premature_depth)
        run_fail(str(VALIDATE), str(path))

        missing_interactive = copy.deepcopy(schedule)
        missing_interactive["oracleModel"]["interactiveProtocolFullySpecified"] = False
        path = tmp / "missing-interactive.json"
        write_json(path, missing_interactive)
        run_fail(str(VALIDATE), str(path))

        missing_qrom = copy.deepcopy(schedule)
        missing_qrom["relatedManifests"].pop("productQROMFiatShamirAccounting")
        path = tmp / "missing-qrom.json"
        write_json(path, missing_qrom)
        run_fail(str(VALIDATE), str(path))

        missing_transform_preconditions = copy.deepcopy(schedule)
        missing_transform_preconditions["relatedManifests"].pop("productQROMTransformPreconditions")
        path = tmp / "missing-transform-preconditions.json"
        write_json(path, missing_transform_preconditions)
        run_fail(str(VALIDATE), str(path))

        missing_interactive_reduction = copy.deepcopy(schedule)
        missing_interactive_reduction["relatedManifests"].pop("productQROMInteractiveReduction")
        path = tmp / "missing-interactive-reduction.json"
        write_json(path, missing_interactive_reduction)
        run_fail(str(VALIDATE), str(path))

        missing_entry = copy.deepcopy(schedule)
        missing_entry["scheduleEntries"] = [
            row for row in missing_entry["scheduleEntries"] if row["proofKind"] != "numiseal-zk-product"
        ]
        path = tmp / "missing-entry.json"
        write_json(path, missing_entry)
        run_fail(str(VALIDATE), str(path))

        wrong_envelope_kind = copy.deepcopy(schedule)
        wrong_envelope_kind["scheduleEntries"][0]["envelopeKind"] = 5
        path = tmp / "wrong-envelope-kind.json"
        write_json(path, wrong_envelope_kind)
        run_fail(str(VALIDATE), str(path))

        duplicate_label = copy.deepcopy(schedule)
        duplicate_label["scheduleEntries"][1]["challengeLabels"][0] = duplicate_label["scheduleEntries"][0]["challengeLabels"][0]
        path = tmp / "duplicate-label.json"
        write_json(path, duplicate_label)
        run_fail(str(VALIDATE), str(path))

        wrong_query_prefix = copy.deepcopy(schedule)
        wrong_query_prefix["scheduleEntries"][4]["oracleQueryFamilies"][0] = "Q_H_fold_wrong_lane"
        path = tmp / "wrong-query-prefix.json"
        write_json(path, wrong_query_prefix)
        run_fail(str(VALIDATE), str(path))

        missing_query_bound = copy.deepcopy(schedule)
        missing_query_bound["scheduleEntries"][0]["maximumQuantumOracleQueries"] = None
        missing_query_bound["scheduleEntries"][0]["queryBoundInstantiated"] = False
        path = tmp / "missing-query-bound.json"
        write_json(path, missing_query_bound)
        run_fail(str(VALIDATE), str(path))

        wrong_challenge_derivation_count = copy.deepcopy(schedule)
        wrong_challenge_derivation_count["scheduleEntries"][4]["maximumProtocolChallengeDerivations"] = 1
        path = tmp / "wrong-challenge-derivation-count.json"
        write_json(path, wrong_challenge_derivation_count)
        run_fail(str(VALIDATE), str(path))

        missing_query_symbol = copy.deepcopy(schedule)
        missing_query_symbol["ledgerBinding"]["selectedDepthQueryExpression"] = "Q_H(depth=1) = Q_H_fold"
        path = tmp / "missing-query-symbol.json"
        write_json(path, missing_query_symbol)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(schedule)
        missing_blocker["hardClaimBlockers"].remove(
            "NumiSealZK simulator composition remains outside the transcript-schedule query bound"
        )
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(schedule)
        outsourced_review["hardClaimBlockers"].append("external" + " audit")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(schedule)
        premature_promotion["promotionRule"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product QROM transcript schedule validation regression tests passed")


if __name__ == "__main__":
    main()
