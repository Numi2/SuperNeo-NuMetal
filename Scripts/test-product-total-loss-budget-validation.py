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
        wrong_claim["claimStatus"] = "total-loss-budget-contract-repository-local-production-claim"
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

        missing_qrom_transform_preconditions = copy.deepcopy(budget)
        missing_qrom_transform_preconditions["relatedManifests"].pop("productQROMTransformPreconditions")
        path = tmp / "missing-qrom-transform-preconditions.json"
        write_json(path, missing_qrom_transform_preconditions)
        run_fail(str(VALIDATE), str(path))

        missing_qrom_interactive_reduction = copy.deepcopy(budget)
        missing_qrom_interactive_reduction["relatedManifests"].pop("productQROMInteractiveReduction")
        path = tmp / "missing-qrom-interactive-reduction.json"
        write_json(path, missing_qrom_interactive_reduction)
        run_fail(str(VALIDATE), str(path))

        missing_zk_simulator = copy.deepcopy(budget)
        missing_zk_simulator["relatedManifests"].pop("numiSealZKSimulatorCouplingEvidence")
        path = tmp / "missing-zk-simulator.json"
        write_json(path, missing_zk_simulator)
        run_fail(str(VALIDATE), str(path))

        missing_finite_protocol_loss = copy.deepcopy(budget)
        missing_finite_protocol_loss["relatedManifests"].pop("productFiniteProtocolLossObstruction")
        path = tmp / "missing-finite-protocol-loss.json"
        write_json(path, missing_finite_protocol_loss)
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

        wrong_source_fold_bound = copy.deepcopy(budget)
        wrong_source_fold_bound["componentBounds"][1]["exactUpperBound"] = "1/2^256"
        path = tmp / "wrong-source-fold-bound.json"
        write_json(path, wrong_source_fold_bound)
        run_fail(str(VALIDATE), str(path))

        hidden_source_fold_gap = copy.deepcopy(budget)
        hidden_source_fold_gap["componentBounds"][1]["requiredEvidence"] = "residual source fold loss"
        path = tmp / "hidden-source-fold-gap.json"
        write_json(path, hidden_source_fold_gap)
        run_fail(str(VALIDATE), str(path))

        hidden_terminal_ce_closure = copy.deepcopy(budget)
        hidden_terminal_ce_closure["componentBounds"][2]["requiredEvidence"] = "finite-protocol terminal gap"
        path = tmp / "hidden-terminal-ce-closure.json"
        write_json(path, hidden_terminal_ce_closure)
        run_fail(str(VALIDATE), str(path))

        stale_missing_list = copy.deepcopy(budget)
        stale_missing_list["computedBudget"]["missingRequiredTermIDs"] = ["constant-time-side-channel"]
        path = tmp / "stale-missing-list.json"
        write_json(path, stale_missing_list)
        run_fail(str(VALIDATE), str(path))

        stale_partial_sum = copy.deepcopy(budget)
        stale_partial_sum["computedBudget"]["exactInstantiatedRequiredTermUpperBound"] = "1/2^128"
        path = tmp / "stale-partial-sum.json"
        write_json(path, stale_partial_sum)
        run_fail(str(VALIDATE), str(path))

        wrong_qrom_exact_bound = copy.deepcopy(budget)
        for row in wrong_qrom_exact_bound["componentBounds"]:
            if row["id"] == "fiat-shamir-qrom":
                row["exactUpperBound"] = "1/2^256"
        path = tmp / "wrong-qrom-exact-bound.json"
        write_json(path, wrong_qrom_exact_bound)
        run_fail(str(VALIDATE), str(path))

        wrong_zk_simulator_exact_bound = copy.deepcopy(budget)
        for row in wrong_zk_simulator_exact_bound["componentBounds"]:
            if row["id"] == "zk-simulator-composition":
                row["exactUpperBound"] = "1/2^256"
        path = tmp / "wrong-zk-simulator-exact-bound.json"
        write_json(path, wrong_zk_simulator_exact_bound)
        run_fail(str(VALIDATE), str(path))

        wrong_shared_core_exact_bound = copy.deepcopy(budget)
        for row in wrong_shared_core_exact_bound["componentBounds"]:
            if row["id"] == "shared-cryptographic-core":
                row["exactUpperBound"] = "1/2^128"
        path = tmp / "wrong-shared-core-exact-bound.json"
        write_json(path, wrong_shared_core_exact_bound)
        run_fail(str(VALIDATE), str(path))

        wrong_collision_exact_bound = copy.deepcopy(budget)
        for row in wrong_collision_exact_bound["componentBounds"]:
            if row["id"] == "transcript-collision-domain-separation":
                row["exactUpperBound"] = "35/2^256"
        path = tmp / "wrong-collision-exact-bound.json"
        write_json(path, wrong_collision_exact_bound)
        run_fail(str(VALIDATE), str(path))

        stale_within_budget = copy.deepcopy(budget)
        stale_within_budget["computedBudget"]["selectedDepthLossWithinBudget"] = False
        path = tmp / "stale-within-budget.json"
        write_json(path, stale_within_budget)
        run_fail(str(VALIDATE), str(path))

        stale_promotion = copy.deepcopy(budget)
        stale_promotion["promotionRule"]["repositoryLocalProductTheoremClaimAllowed"] = False
        path = tmp / "stale-promotion.json"
        write_json(path, stale_promotion)
        run_fail(str(VALIDATE), str(path))

        premature_production_promotion = copy.deepcopy(budget)
        premature_production_promotion["promotionRule"]["productionProductSecurityClaimAllowed"] = True
        path = tmp / "premature-production-promotion.json"
        write_json(path, premature_production_promotion)
        run_fail(str(VALIDATE), str(path))

        gated_repository_use = copy.deepcopy(budget)
        gated_repository_use["productionGates"][0]["requiredForRepositoryLocalUse"] = True
        path = tmp / "gated-repository-use.json"
        write_json(path, gated_repository_use)
        run_fail(str(VALIDATE), str(path))

        outsourced_review = copy.deepcopy(budget)
        outsourced_review["componentBounds"][0]["requiredEvidence"] += " with external" + " audit"
        path = tmp / "outsourced-review.json"
        write_json(path, outsourced_review)
        run_fail(str(VALIDATE), str(path))

    print("product total-loss budget validation regression tests passed")


if __name__ == "__main__":
    main()
