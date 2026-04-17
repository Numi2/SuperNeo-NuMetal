#!/usr/bin/env python3
"""Regression tests for product QROM Fiat-Shamir accounting validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACCOUNTING = ROOT / "TestVectors" / "product-qrom-fiat-shamir-accounting-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-fiat-shamir-accounting.py"


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

    with tempfile.TemporaryDirectory(prefix=".qrom-accounting-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(accounting)
        wrong_claim["claimStatus"] = "production-qrom-proof"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        premature_depth = copy.deepcopy(accounting)
        premature_depth["selectedDepth"]["selectedMaximumDepth"] = 2
        path = tmp / "premature-depth.json"
        write_json(path, premature_depth)
        run_fail(str(VALIDATE), str(path))

        premature_interactive = copy.deepcopy(accounting)
        premature_interactive["fiatShamirModel"]["interactiveProtocolSpecified"] = True
        path = tmp / "premature-interactive.json"
        write_json(path, premature_interactive)
        run_fail(str(VALIDATE), str(path))

        missing_kind = copy.deepcopy(accounting)
        missing_kind["transcriptInterfaces"] = [
            row for row in missing_kind["transcriptInterfaces"] if row["proofKind"] != "numiseal-zk-product"
        ]
        path = tmp / "missing-kind.json"
        write_json(path, missing_kind)
        run_fail(str(VALIDATE), str(path))

        missing_schedule = copy.deepcopy(accounting)
        missing_schedule["relatedManifests"].pop("productQROMTranscriptSchedule")
        path = tmp / "missing-schedule.json"
        write_json(path, missing_schedule)
        run_fail(str(VALIDATE), str(path))

        missing_transform_preconditions = copy.deepcopy(accounting)
        missing_transform_preconditions["relatedManifests"].pop("productQROMTransformPreconditions")
        path = tmp / "missing-transform-preconditions.json"
        write_json(path, missing_transform_preconditions)
        run_fail(str(VALIDATE), str(path))

        missing_interactive_reduction = copy.deepcopy(accounting)
        missing_interactive_reduction["relatedManifests"].pop("productQROMInteractiveReduction")
        path = tmp / "missing-interactive-reduction.json"
        write_json(path, missing_interactive_reduction)
        run_fail(str(VALIDATE), str(path))

        wrong_schedule_manifest = copy.deepcopy(accounting)
        wrong_schedule_manifest["fiatShamirModel"]["transcriptScheduleManifest"] = "TestVectors/product-qrom-fiat-shamir-accounting-v1.json"
        path = tmp / "wrong-schedule-manifest.json"
        write_json(path, wrong_schedule_manifest)
        run_fail(str(VALIDATE), str(path))

        wrong_transform_manifest = copy.deepcopy(accounting)
        wrong_transform_manifest["fiatShamirModel"]["transformPreconditionManifest"] = "TestVectors/product-qrom-transcript-schedule-v1.json"
        path = tmp / "wrong-transform-manifest.json"
        write_json(path, wrong_transform_manifest)
        run_fail(str(VALIDATE), str(path))

        wrong_envelope_kind = copy.deepcopy(accounting)
        wrong_envelope_kind["transcriptInterfaces"][0]["envelopeKind"] = 5
        path = tmp / "wrong-envelope-kind.json"
        write_json(path, wrong_envelope_kind)
        run_fail(str(VALIDATE), str(path))

        premature_budget = copy.deepcopy(accounting)
        premature_budget["lossRule"]["qromLossWithinBudget"] = True
        path = tmp / "premature-budget.json"
        write_json(path, premature_budget)
        run_fail(str(VALIDATE), str(path))

        missing_query_symbol = copy.deepcopy(accounting)
        missing_query_symbol["lossRule"]["selectedDepthExpression"] = "epsilon_qrom(depth=1) = epsilon_fs_transform"
        path = tmp / "missing-query-symbol.json"
        write_json(path, missing_query_symbol)
        run_fail(str(VALIDATE), str(path))

        missing_precondition_symbol = copy.deepcopy(accounting)
        missing_precondition_symbol["lossRule"]["selectedDepthExpression"] = "epsilon_qrom(depth=1) = epsilon_fs_transform + epsilon_qro_queries + epsilon_proof_kind_malleability"
        path = tmp / "missing-precondition-symbol.json"
        write_json(path, missing_precondition_symbol)
        run_fail(str(VALIDATE), str(path))

        double_counted_collision = copy.deepcopy(accounting)
        double_counted_collision["lossRule"]["selectedDepthExpression"] += " + epsilon_transcript_collision"
        path = tmp / "double-counted-collision.json"
        write_json(path, double_counted_collision)
        run_fail(str(VALIDATE), str(path))

        missing_mapping = copy.deepcopy(accounting)
        missing_mapping.pop("ledgerTermMapping")
        path = tmp / "missing-mapping.json"
        write_json(path, missing_mapping)
        run_fail(str(VALIDATE), str(path))

        wrong_collision_mapping = copy.deepcopy(accounting)
        wrong_collision_mapping["ledgerTermMapping"]["fiatShamirQROMLoss"]["sourceSymbols"].append(
            "epsilon_transcript_collision"
        )
        path = tmp / "wrong-collision-mapping.json"
        write_json(path, wrong_collision_mapping)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(accounting)
        missing_blocker["hardClaimBlockers"].remove("quantum random-oracle query bound and interactive reduction manifest")
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(accounting)
        outsourced_review["hardClaimBlockers"].append("external" + " audit")
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(accounting)
        premature_promotion["promotionRule"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product QROM Fiat-Shamir accounting validation regression tests passed")


if __name__ == "__main__":
    main()
