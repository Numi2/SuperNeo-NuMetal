#!/usr/bin/env python3
"""Regression tests for finite-protocol loss-obstruction validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-finite-protocol-loss-obstruction-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-product-finite-protocol-loss-obstruction.py"


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

    with tempfile.TemporaryDirectory(prefix=".finite-protocol-loss-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)

        wrong_claim = copy.deepcopy(manifest)
        wrong_claim["claimStatus"] = "production-finite-protocol-loss"
        path = tmp / "wrong-claim.json"
        write_json(path, wrong_claim)
        run_fail(str(VALIDATE), str(path))

        missing_manifest = copy.deepcopy(manifest)
        missing_manifest["relatedManifests"].pop("productTotalLossBudget")
        path = tmp / "missing-manifest.json"
        write_json(path, missing_manifest)
        run_fail(str(VALIDATE), str(path))

        wrong_depth = copy.deepcopy(manifest)
        wrong_depth["selectedProfile"]["selectedDepth"] = 2
        path = tmp / "wrong-depth.json"
        write_json(path, wrong_depth)
        run_fail(str(VALIDATE), str(path))

        wrong_security_bits = copy.deepcopy(manifest)
        wrong_security_bits["selectedProfile"]["selectedSecurityBudgetBits"] = 96
        path = tmp / "wrong-security-bits.json"
        write_json(path, wrong_security_bits)
        run_fail(str(VALIDATE), str(path))

        hidden_pirlc_gap = copy.deepcopy(manifest)
        hidden_pirlc_gap["pirlcNumericGap"]["challengeSupportBelowSelectedBudgetDenominator"] = False
        path = tmp / "hidden-pirlc-gap.json"
        write_json(path, hidden_pirlc_gap)
        run_fail(str(VALIDATE), str(path))

        bogus_pirlc_bound = copy.deepcopy(manifest)
        bogus_pirlc_bound["pirlcNumericGap"]["fullRingUnitPivotSingleObservationBound"] = "1/2^256"
        path = tmp / "bogus-pirlc-bound.json"
        write_json(path, bogus_pirlc_bound)
        run_fail(str(VALIDATE), str(path))

        missing_pirlc_lean_obstruction = copy.deepcopy(manifest)
        missing_pirlc_lean_obstruction["pirlcNumericGap"]["leanDeclarations"] = []
        path = tmp / "missing-pirlc-lean-obstruction.json"
        write_json(path, missing_pirlc_lean_obstruction)
        run_fail(str(VALIDATE), str(path))

        hidden_piccs_gap = copy.deepcopy(manifest)
        hidden_piccs_gap["piccsNumericGap"]["selectedPiCCSBadChallengeBudget"] = "0"
        path = tmp / "hidden-piccs-gap.json"
        write_json(path, hidden_piccs_gap)
        run_fail(str(VALIDATE), str(path))

        missing_piccs_lean_obstruction = copy.deepcopy(manifest)
        missing_piccs_lean_obstruction["piccsNumericGap"]["leanDeclarations"] = []
        path = tmp / "missing-piccs-lean-obstruction.json"
        write_json(path, missing_piccs_lean_obstruction)
        run_fail(str(VALIDATE), str(path))

        hidden_terminal_repeated_bound = copy.deepcopy(manifest)
        hidden_terminal_repeated_bound["terminalCENumericGap"]["repeatedChallengeBoundWithinSelectedBudget"] = False
        path = tmp / "hidden-terminal-repeated-bound.json"
        write_json(path, hidden_terminal_repeated_bound)
        run_fail(str(VALIDATE), str(path))

        bogus_terminal_repeated_budget = copy.deepcopy(manifest)
        bogus_terminal_repeated_budget["terminalCENumericGap"]["repeatedChallengeBadTapeBudget"] = "2^1 = 2"
        path = tmp / "bogus-terminal-repeated-budget.json"
        write_json(path, bogus_terminal_repeated_budget)
        run_fail(str(VALIDATE), str(path))

        hidden_terminal_lift_gap = copy.deepcopy(manifest)
        hidden_terminal_lift_gap["terminalCENumericGap"]["fullTapeLiftConclusion"] = "slot lift is production useful"
        path = tmp / "hidden-terminal-lift-gap.json"
        write_json(path, hidden_terminal_lift_gap)
        run_fail(str(VALIDATE), str(path))

        hidden_source_fold_instantiation = copy.deepcopy(manifest)
        hidden_source_fold_instantiation["ledgerDecision"]["sourceFoldLossInstantiated"] = False
        path = tmp / "hidden-source-fold-instantiation.json"
        write_json(path, hidden_source_fold_instantiation)
        run_fail(str(VALIDATE), str(path))

        wrong_repeated_tape_count = copy.deepcopy(manifest)
        wrong_repeated_tape_count["selectedProfile"]["piccsRepeatedTapeCount"] = 1
        path = tmp / "wrong-repeated-tape-count.json"
        write_json(path, wrong_repeated_tape_count)
        run_fail(str(VALIDATE), str(path))

        missing_option = copy.deepcopy(manifest)
        missing_option["ledgerDecision"]["nextMathematicalOptions"] = ["do nothing"]
        path = tmp / "missing-option.json"
        write_json(path, missing_option)
        run_fail(str(VALIDATE), str(path))

    print("product finite-protocol loss obstruction validation regression tests passed")


if __name__ == "__main__":
    main()
