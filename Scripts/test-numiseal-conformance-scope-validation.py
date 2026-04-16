#!/usr/bin/env python3
"""Regression tests for NumiSeal conformance and theorem-scope validation."""

from __future__ import annotations

import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-conformance-scope-v1.json"
THEOREM_SCOPE = ROOT / "TestVectors" / "numiseal-end-to-end-theorem-scope-v1.json"
VALIDATE = ROOT / "Scripts" / "validate-numiseal-conformance-scope.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def relative(path: Path) -> str:
    return str(path.relative_to(ROOT))


def manifest_with_theorem(scope: dict, theorem_path: Path) -> dict:
    result = copy.deepcopy(scope)
    result["theoremScopeManifest"] = relative(theorem_path)
    return result


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    theorem = json.loads(THEOREM_SCOPE.read_text(encoding="utf-8"))
    run_ok(str(VALIDATE))

    with tempfile.TemporaryDirectory(prefix=".numiseal-conformance-test-", dir=ROOT) as tmpdir:
        tmp = Path(tmpdir)
        valid_theorem = tmp / "valid-theorem.json"
        valid_manifest = tmp / "valid-manifest.json"
        write_json(valid_theorem, theorem)
        write_json(valid_manifest, manifest_with_theorem(manifest, valid_theorem))
        run_ok(str(VALIDATE), str(valid_manifest))

        missing_theorem_link = copy.deepcopy(manifest)
        del missing_theorem_link["theoremScopeManifest"]
        path = tmp / "missing-theorem-link.json"
        write_json(path, missing_theorem_link)
        run_fail(str(VALIDATE), str(path))

        wrong_claim = copy.deepcopy(theorem)
        wrong_claim["claimStatus"] = "full-product-theorem"
        theorem_path = tmp / "wrong-claim-theorem.json"
        manifest_path = tmp / "wrong-claim-manifest.json"
        write_json(theorem_path, wrong_claim)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

        missing_declaration = copy.deepcopy(theorem)
        missing_declaration["formalModel"]["declarations"] = missing_declaration["formalModel"]["declarations"][:-1]
        theorem_path = tmp / "missing-declaration-theorem.json"
        manifest_path = tmp / "missing-declaration-manifest.json"
        write_json(theorem_path, missing_declaration)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

        missing_auxiliary_module = copy.deepcopy(theorem)
        missing_auxiliary_module["formalModel"]["auxiliaryModules"] = (
            missing_auxiliary_module["formalModel"]["auxiliaryModules"][:-1]
        )
        theorem_path = tmp / "missing-auxiliary-module-theorem.json"
        manifest_path = tmp / "missing-auxiliary-module-manifest.json"
        write_json(theorem_path, missing_auxiliary_module)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

        missing_auxiliary_declaration = copy.deepcopy(theorem)
        missing_auxiliary_declaration["formalModel"]["auxiliaryModules"][0]["declarations"] = (
            missing_auxiliary_declaration["formalModel"]["auxiliaryModules"][0]["declarations"][:-1]
        )
        theorem_path = tmp / "missing-auxiliary-declaration-theorem.json"
        manifest_path = tmp / "missing-auxiliary-declaration-manifest.json"
        write_json(theorem_path, missing_auxiliary_declaration)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

        missing_surface = copy.deepcopy(theorem)
        missing_surface["theoremSurfaces"] = missing_surface["theoremSurfaces"][:-1]
        theorem_path = tmp / "missing-surface-theorem.json"
        manifest_path = tmp / "missing-surface-manifest.json"
        write_json(theorem_path, missing_surface)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

        premature_promotion = copy.deepcopy(theorem)
        premature_promotion["promotionRule"]["productionNumiSealTheoremClaimAllowed"] = True
        theorem_path = tmp / "premature-promotion-theorem.json"
        manifest_path = tmp / "premature-promotion-manifest.json"
        write_json(theorem_path, premature_promotion)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

        outsourced_review = copy.deepcopy(theorem)
        outsourced_review["residualProofObligations"].append("External" + " audit required.")
        theorem_path = tmp / "outsourced-review-theorem.json"
        manifest_path = tmp / "outsourced-review-manifest.json"
        write_json(theorem_path, outsourced_review)
        write_json(manifest_path, manifest_with_theorem(manifest, theorem_path))
        run_fail(str(VALIDATE), str(manifest_path))

    print("NumiSeal conformance scope validation regression tests passed")


if __name__ == "__main__":
    main()
