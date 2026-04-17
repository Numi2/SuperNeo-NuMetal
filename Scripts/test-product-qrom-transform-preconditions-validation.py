#!/usr/bin/env python3
"""Regression tests for product QROM transform precondition validation."""

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
            row for row in missing_source["researchBasis"] if row["id"] != "DFM20"
        ]
        path = tmp / "missing-source.json"
        write_json(path, missing_source)
        run_fail(str(VALIDATE), str(path))

        non_primary_source = copy.deepcopy(preconditions)
        non_primary_source["researchBasis"][0]["url"] = "https://example.com/qrom"
        path = tmp / "non-primary-source.json"
        write_json(path, non_primary_source)
        run_fail(str(VALIDATE), str(path))

        wrong_profile = copy.deepcopy(preconditions)
        wrong_profile["selectedTransformProfile"]["model"] = "rom"
        path = tmp / "wrong-profile.json"
        write_json(path, wrong_profile)
        run_fail(str(VALIDATE), str(path))

        missing_move_count = copy.deepcopy(preconditions)
        missing_move_count["selectedTransformProfile"]["exactMoveCountInstantiated"] = False
        path = tmp / "missing-move-count.json"
        write_json(path, missing_move_count)
        run_fail(str(VALIDATE), str(path))

        missing_schedule = copy.deepcopy(preconditions)
        missing_schedule["relatedManifests"].pop("productQROMTranscriptSchedule")
        path = tmp / "missing-schedule.json"
        write_json(path, missing_schedule)
        run_fail(str(VALIDATE), str(path))

        missing_accounting = copy.deepcopy(preconditions)
        missing_accounting["relatedManifests"].pop("productQROMFiatShamirAccounting")
        path = tmp / "missing-accounting.json"
        write_json(path, missing_accounting)
        run_fail(str(VALIDATE), str(path))

        missing_interactive_reduction = copy.deepcopy(preconditions)
        missing_interactive_reduction["relatedManifests"].pop("productQROMInteractiveReduction")
        path = tmp / "missing-interactive-reduction.json"
        write_json(path, missing_interactive_reduction)
        run_fail(str(VALIDATE), str(path))

        premature_precondition = copy.deepcopy(preconditions)
        premature_precondition["preconditions"][0]["satisfied"] = True
        path = tmp / "premature-precondition.json"
        write_json(path, premature_precondition)
        run_fail(str(VALIDATE), str(path))

        missing_query_bound_precondition = copy.deepcopy(preconditions)
        missing_query_bound_precondition["preconditions"][7]["satisfied"] = False
        path = tmp / "missing-query-bound-precondition.json"
        write_json(path, missing_query_bound_precondition)
        run_fail(str(VALIDATE), str(path))

        missing_precondition = copy.deepcopy(preconditions)
        missing_precondition["preconditions"] = [
            row for row in missing_precondition["preconditions"] if row["id"] != "quantum-query-bound"
        ]
        path = tmp / "missing-precondition.json"
        write_json(path, missing_precondition)
        run_fail(str(VALIDATE), str(path))

        missing_proof_kind = copy.deepcopy(preconditions)
        missing_proof_kind["proofKindFit"] = [
            row for row in missing_proof_kind["proofKindFit"] if row["proofKind"] != "numiseal-zk-product"
        ]
        path = tmp / "missing-proof-kind.json"
        write_json(path, missing_proof_kind)
        run_fail(str(VALIDATE), str(path))

        wrong_challenge_count = copy.deepcopy(preconditions)
        wrong_challenge_count["proofKindFit"][0]["challengeCountN"] = 1
        path = tmp / "wrong-challenge-count.json"
        write_json(path, wrong_challenge_count)
        run_fail(str(VALIDATE), str(path))

        missing_query_bound = copy.deepcopy(preconditions)
        missing_query_bound["proofKindFit"][0]["queryBoundQH"] = None
        path = tmp / "missing-query-bound.json"
        write_json(path, missing_query_bound)
        run_fail(str(VALIDATE), str(path))

        missing_loss_symbol = copy.deepcopy(preconditions)
        missing_loss_symbol["lossInterface"]["selectedDepthExpression"] = "epsilon_fs_transform(depth=1) <= epsilon_interactive"
        path = tmp / "missing-loss-symbol.json"
        write_json(path, missing_loss_symbol)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(preconditions)
        missing_blocker["hardClaimBlockers"].remove(
            "repair of the out-of-budget DFM20 reduction-loss finding under the instantiated Q_H = 2^64 bound"
        )
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(preconditions)
        outsourced_review["hardClaimBlockers"].append("external" + " audit")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(preconditions)
        premature_promotion["promotionRule"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product QROM transform precondition validation regression tests passed")


if __name__ == "__main__":
    main()
