#!/usr/bin/env python3
"""Regression tests for product QROM CTCO interactive-reduction validation."""

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
        wrong_theorem["selectedTheoremFamily"]["compilerFamily"] = "DFM20"
        path = tmp / "wrong-theorem.json"
        write_json(path, wrong_theorem)
        run_fail(str(VALIDATE), str(path))

        weak_binding = copy.deepcopy(reduction)
        weak_binding["selectedTheoremFamily"]["selectedBindingBits"] = 256
        path = tmp / "weak-binding.json"
        write_json(path, weak_binding)
        run_fail(str(VALIDATE), str(path))

        missing_numeric_loss = copy.deepcopy(reduction)
        missing_numeric_loss["selectedTheoremFamily"]["numericSelectedLossInstantiated"] = False
        path = tmp / "missing-numeric-loss.json"
        write_json(path, missing_numeric_loss)
        run_fail(str(VALIDATE), str(path))

        missing_proof_kind = copy.deepcopy(reduction)
        missing_proof_kind["proofKindProtocols"] = [
            row for row in missing_proof_kind["proofKindProtocols"] if row["proofKind"] != "numiseal-zk-product"
        ]
        path = tmp / "missing-proof-kind.json"
        write_json(path, missing_proof_kind)
        run_fail(str(VALIDATE), str(path))

        wrong_ctco_count = copy.deepcopy(reduction)
        wrong_ctco_count["proofKindProtocols"][0]["ctcoChallengeCount"] = 2
        path = tmp / "wrong-ctco-count.json"
        write_json(path, wrong_ctco_count)
        run_fail(str(VALIDATE), str(path))

        wrong_legacy_metric = copy.deepcopy(reduction)
        wrong_legacy_metric["proofKindProtocols"][3]["legacyScheduleChallengeDerivations"] = 1
        path = tmp / "wrong-legacy-metric.json"
        write_json(path, wrong_legacy_metric)
        run_fail(str(VALIDATE), str(path))

        missing_interactive_bounds = copy.deepcopy(reduction)
        missing_interactive_bounds.pop("interactiveSecurityBounds")
        path = tmp / "missing-interactive-bounds.json"
        write_json(path, missing_interactive_bounds)
        run_fail(str(VALIDATE), str(path))

        uninstantiated_protocol_bounds = copy.deepcopy(reduction)
        uninstantiated_protocol_bounds["productProtocolModel"]["allInteractiveSecurityBoundsInstantiated"] = False
        path = tmp / "uninstantiated-protocol-bounds.json"
        write_json(path, uninstantiated_protocol_bounds)
        run_fail(str(VALIDATE), str(path))

        missing_per_kind_bound = copy.deepcopy(reduction)
        missing_per_kind_bound["proofKindProtocols"][0].pop("interactiveSecurityBound")
        path = tmp / "missing-per-kind-bound.json"
        write_json(path, missing_per_kind_bound)
        run_fail(str(VALIDATE), str(path))

        reopened_fold_input = copy.deepcopy(reduction)
        reopened_fold_input["proofKindProtocols"][0]["openInputs"] = ["interactive special-soundness remains open"]
        path = tmp / "reopened-fold-input.json"
        write_json(path, reopened_fold_input)
        run_fail(str(VALIDATE), str(path))

        reopened_zk_sim_input = copy.deepcopy(reduction)
        reopened_zk_sim_input["proofKindProtocols"][4]["openInputs"] = [
            "ZK simulator composition for the masked residual relation"
        ]
        path = tmp / "reopened-zk-sim-input.json"
        write_json(path, reopened_zk_sim_input)
        run_fail(str(VALIDATE), str(path))

        wrong_binding_loss = copy.deepcopy(reduction)
        wrong_binding_loss["qromQueryAndLossInstantiation"]["bindingDigestBits"] = 256
        path = tmp / "wrong-binding-loss.json"
        write_json(path, wrong_binding_loss)
        run_fail(str(VALIDATE), str(path))

        missing_legacy_finding = copy.deepcopy(reduction)
        missing_legacy_finding["qromQueryAndLossInstantiation"].pop("legacyNumericBudgetFinding")
        path = tmp / "missing-legacy-finding.json"
        write_json(path, missing_legacy_finding)
        run_fail(str(VALIDATE), str(path))

        missing_blocker = copy.deepcopy(reduction)
        missing_blocker["hardClaimBlockers"] = ["interactive special-soundness bounds against quantum dishonest provers remain open"]
        path = tmp / "missing-blocker.json"
        write_json(path, missing_blocker)
        run_fail(str(VALIDATE), str(path))

        premature_qrom = copy.deepcopy(reduction)
        premature_qrom["promotionRule"]["productionQROMClaimAllowed"] = False
        path = tmp / "premature-qrom.json"
        write_json(path, premature_qrom)
        run_fail(str(VALIDATE), str(path))

    print("product QROM CTCO interactive reduction validation regression tests passed")


if __name__ == "__main__":
    main()
