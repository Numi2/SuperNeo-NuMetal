#!/usr/bin/env python3
"""Regression tests for product QROM CTCO accounting validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ACCOUNTING = ROOT / "TestVectors" / "product-qrom-public-coin-accounting-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-public-coin-accounting.py"


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

        wrong_hash_model = copy.deepcopy(accounting)
        wrong_hash_model["hashModel"]["model"] = "qrom"
        path = tmp / "wrong-hash-model.json"
        write_json(path, wrong_hash_model)
        run_fail(str(VALIDATE), str(path))

        weak_binding = copy.deepcopy(accounting)
        weak_binding["hashModel"]["bindingOracle"]["outputBits"] = 256
        path = tmp / "weak-binding.json"
        write_json(path, weak_binding)
        run_fail(str(VALIDATE), str(path))

        concrete_hash_proof = copy.deepcopy(accounting)
        concrete_hash_proof["hashModel"]["hashQROInstantiationProofProvided"] = True
        path = tmp / "concrete-hash-proof.json"
        write_json(path, concrete_hash_proof)
        run_fail(str(VALIDATE), str(path))

        concrete_shake_proof = copy.deepcopy(accounting)
        concrete_shake_proof["hashModel"]["concreteSHAKE256QROInstantiationProofProvided"] = True
        path = tmp / "concrete-shake-proof.json"
        write_json(path, concrete_shake_proof)
        run_fail(str(VALIDATE), str(path))

        generic_fs_promotion = copy.deepcopy(accounting)
        generic_fs_promotion["hashModel"]["genericOfflineTransformAcceptedForProduction"] = True
        path = tmp / "generic-fs-promotion.json"
        write_json(path, generic_fs_promotion)
        run_fail(str(VALIDATE), str(path))

        wrong_transform = copy.deepcopy(accounting)
        wrong_transform["publicCoinQROModel"]["transformFamily"] = "DFM20"
        path = tmp / "wrong-transform.json"
        write_json(path, wrong_transform)
        run_fail(str(VALIDATE), str(path))

        hidden_source = copy.deepcopy(accounting)
        hidden_source["publicCoinQROModel"]["sourceImplementationComplete"] = False
        path = tmp / "hidden-source.json"
        write_json(path, hidden_source)
        run_fail(str(VALIDATE), str(path))

        uninstantiated_model_bounds = copy.deepcopy(accounting)
        uninstantiated_model_bounds["publicCoinQROModel"]["interactiveSecurityBoundsInstantiated"] = False
        path = tmp / "uninstantiated-model-bounds.json"
        write_json(path, uninstantiated_model_bounds)
        run_fail(str(VALIDATE), str(path))

        missing_kind = copy.deepcopy(accounting)
        missing_kind["transcriptInterfaces"] = [
            row for row in missing_kind["transcriptInterfaces"] if row["proofKind"] != "numiseal-zk-product"
        ]
        path = tmp / "missing-kind.json"
        write_json(path, missing_kind)
        run_fail(str(VALIDATE), str(path))

        wrong_ctco_count = copy.deepcopy(accounting)
        wrong_ctco_count["transcriptInterfaces"][0]["ctcoChallengeCount"] = 2
        path = tmp / "wrong-ctco-count.json"
        write_json(path, wrong_ctco_count)
        run_fail(str(VALIDATE), str(path))

        legacy_formula = copy.deepcopy(accounting)
        legacy_formula["lossRule"]["selectedDepthExpression"] += " + n_kind!"
        path = tmp / "legacy-formula.json"
        write_json(path, legacy_formula)
        run_fail(str(VALIDATE), str(path))

        uninstantiated_loss_bounds = copy.deepcopy(accounting)
        uninstantiated_loss_bounds["lossRule"]["interactiveSecurityBoundsInstantiated"] = False
        path = tmp / "uninstantiated-loss-bounds.json"
        write_json(path, uninstantiated_loss_bounds)
        run_fail(str(VALIDATE), str(path))

        wrong_collision_mapping = copy.deepcopy(accounting)
        wrong_collision_mapping["ledgerTermMapping"]["transcriptCollisionLoss"]["sourceSymbols"] = [
            "epsilon_transcript_collision"
        ]
        path = tmp / "wrong-collision-mapping.json"
        write_json(path, wrong_collision_mapping)
        run_fail(str(VALIDATE), str(path))

        missing_legacy_failure = copy.deepcopy(accounting)
        missing_legacy_failure["legacyDFM20Status"]["decisiveLegacyFailure"] = "deprecated"
        path = tmp / "missing-legacy-failure.json"
        write_json(path, missing_legacy_failure)
        run_fail(str(VALIDATE), str(path))

        missing_non_qrom_blocker = copy.deepcopy(accounting)
        missing_non_qrom_blocker["hardClaimBlockers"] = ["NumiSealZK simulator composition remains outside epsilon_qrom"]
        path = tmp / "missing-non-qrom-blocker.json"
        write_json(path, missing_non_qrom_blocker)
        run_fail(str(VALIDATE), str(path))

        premature_promotion = copy.deepcopy(accounting)
        premature_promotion["promotionRule"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-promotion.json"
        write_json(path, premature_promotion)
        run_fail(str(VALIDATE), str(path))

        reopened_interactive_promotion = copy.deepcopy(accounting)
        reopened_interactive_promotion["promotionRule"]["requiresInteractiveSecurityBounds"] = True
        path = tmp / "reopened-interactive-promotion.json"
        write_json(path, reopened_interactive_promotion)
        run_fail(str(VALIDATE), str(path))

    print("product QROM CTCO accounting validation regression tests passed")


if __name__ == "__main__":
    main()
