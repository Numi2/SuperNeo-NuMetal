#!/usr/bin/env python3
"""Regression tests for product QROM interactive-reduction validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REDUCTION = ROOT / "TestVectors" / "product-qrom-interactive-reduction-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-qrom-interactive-reduction.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    reduction = json.loads(REDUCTION.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".qrom-interactive-reduction-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(reduction)
        wrong_claim["claimStatus"] = "production-qrom-theorem"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        missing_manifest = copy.deepcopy(reduction)
        missing_manifest["relatedManifests"].pop("productQROMTransformPreconditions")
        path = tmp / "missing-manifest.json"
        write_json(path, missing_manifest)
        run_fail(str(VALIDATE), str(path))

        wrong_theorem = copy.deepcopy(reduction)
        wrong_theorem["selectedTheoremFamily"]["selectedFamily"] = "ROM folklore"
        path = tmp / "wrong-theorem.json"
        write_json(path, wrong_theorem)
        run_fail(str(VALIDATE), str(path))

        wrong_qh = copy.deepcopy(reduction)
        wrong_qh["selectedTheoremFamily"]["selectedQHBound"] = "2^32"
        path = tmp / "wrong-qh.json"
        write_json(path, wrong_qh)
        run_fail(str(VALIDATE), str(path))

        premature_numeric_loss = copy.deepcopy(reduction)
        premature_numeric_loss["selectedTheoremFamily"]["numericSelectedLossInstantiated"] = True
        path = tmp / "premature-numeric-loss.json"
        write_json(path, premature_numeric_loss)
        run_fail(str(VALIDATE), str(path))

        missing_proof_kind = copy.deepcopy(reduction)
        missing_proof_kind["proofKindProtocols"] = [
            row for row in missing_proof_kind["proofKindProtocols"] if row["proofKind"] != "numiseal-zk-product"
        ]
        path = tmp / "missing-proof-kind.json"
        write_json(path, missing_proof_kind)
        run_fail(str(VALIDATE), str(path))

        wrong_fold_n = copy.deepcopy(reduction)
        wrong_fold_n["proofKindProtocols"][0]["instantiatedUpperBoundN"] = 203
        path = tmp / "wrong-fold-n.json"
        write_json(path, wrong_fold_n)
        run_fail(str(VALIDATE), str(path))

        wrong_numiseal_n = copy.deepcopy(reduction)
        wrong_numiseal_n["proofKindProtocols"][3]["instantiatedUpperBoundN"] = 1
        path = tmp / "wrong-numiseal-n.json"
        write_json(path, wrong_numiseal_n)
        run_fail(str(VALIDATE), str(path))

        wrong_theorem_limit = copy.deepcopy(reduction)
        wrong_theorem_limit["productProtocolModel"]["selectedProductTheoremLimits"]["maximumNumiSealZKProductChallengeCount"] = 4_377_149
        path = tmp / "wrong-theorem-limit.json"
        write_json(path, wrong_theorem_limit)
        run_fail(str(VALIDATE), str(path))

        missing_loss_symbol = copy.deepcopy(reduction)
        missing_loss_symbol["proofKindProtocols"][1]["numericLossExpression"] = "epsilon_fs_terminal <= epsilon_interactive_terminal"
        path = tmp / "missing-loss-symbol.json"
        write_json(path, missing_loss_symbol)
        run_fail(str(VALIDATE), str(path))

        missing_open_input = copy.deepcopy(reduction)
        missing_open_input["proofKindProtocols"][0]["openInputs"] = ["sampler proof"]
        path = tmp / "missing-open-input.json"
        write_json(path, missing_open_input)
        run_fail(str(VALIDATE), str(path))

        premature_qrom = copy.deepcopy(reduction)
        premature_qrom["promotionRule"]["productionQROMClaimAllowed"] = True
        path = tmp / "premature-qrom.json"
        write_json(path, premature_qrom)
        run_fail(str(VALIDATE), str(path))

        missing_budget_finding = copy.deepcopy(reduction)
        missing_budget_finding["qromQueryAndLossInstantiation"].pop("numericBudgetFinding")
        path = tmp / "missing-budget-finding.json"
        write_json(path, missing_budget_finding)
        run_fail(str(VALIDATE), str(path))

        wrong_schedule_budget = copy.deepcopy(reduction)
        wrong_schedule_budget["qromQueryAndLossInstantiation"]["scheduleDerivedQueryBudget"]["selectedDepthProtocolChallengeDerivations"] = 1
        path = tmp / "wrong-schedule-budget.json"
        write_json(path, wrong_schedule_budget)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(reduction)
        missing_blocker["hardClaimBlockers"].remove(
            "numeric epsilon_interactive_kind bounds for every accepted proof kind"
        )
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

    print("product QROM interactive reduction validation regression tests passed")


if __name__ == "__main__":
    main()
