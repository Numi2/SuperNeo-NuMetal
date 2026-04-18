#!/usr/bin/env python3
"""Regression tests for shared bad-event dedup validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-shared-bad-event-dedup-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-shared-bad-event-dedup.py"


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

    with tempfile.TemporaryDirectory(prefix=".shared-bad-event-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(manifest)
        wrong_claim["claimStatus"] = "production-shared-bad-event-dedup"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        missing_related = copy.deepcopy(manifest)
        missing_related["relatedManifests"].pop("productTotalLossBudget")
        path = tmp / "missing-related.json"
        write_json(path, missing_related)
        run_fail(str(VALIDATE), str(path))

        wrong_bound = copy.deepcopy(manifest)
        wrong_bound["deduplicationRule"]["sharedCoreExactUpperBound"] = "1/2^128"
        path = tmp / "wrong-bound.json"
        write_json(path, wrong_bound)
        run_fail(str(VALIDATE), str(path))

        missing_tag = copy.deepcopy(manifest)
        missing_tag["sharedCoreTags"] = [
            row for row in missing_tag["sharedCoreTags"] if row["tag"] != "core.commitment.opening_binding"
        ]
        path = tmp / "missing-tag.json"
        write_json(path, missing_tag)
        run_fail(str(VALIDATE), str(path))

        double_count_core = copy.deepcopy(manifest)
        double_count_core["deduplicationRule"]["flatSourceSumNotUsedForSharedCore"] = False
        path = tmp / "double-count-core.json"
        write_json(path, double_count_core)
        run_fail(str(VALIDATE), str(path))

        qrom_collision_mixed = copy.deepcopy(manifest)
        qrom_collision_mixed["deduplicationRule"]["qromCollisionSeparatedFromSharedCore"] = False
        path = tmp / "qrom-collision-mixed.json"
        write_json(path, qrom_collision_mixed)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(manifest)
        premature_promotion["promotionRule"]["productionProductSecurityClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

        duplicate_key = MANIFEST.read_text(encoding="utf-8").replace(
            '"schemaVersion": 1,',
            '"schemaVersion": 1,\\n  "schemaVersion": 1,',
            1,
        )
        path = tmp / "duplicate-key.json"
        path.write_text(duplicate_key, encoding="utf-8")
        run_fail(str(VALIDATE), str(path))

    print("product shared bad-event dedup validation regression tests passed")


if __name__ == "__main__":
    main()
