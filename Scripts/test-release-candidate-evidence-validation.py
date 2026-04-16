#!/usr/bin/env python3
import copy
import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GENERATE = ROOT / "Scripts" / "generate-release-candidate-evidence.py"
VALIDATE = ROOT / "Scripts" / "validate-release-candidate-evidence.py"


def run_ok(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def run_fail(*args: str) -> None:
    completed = subprocess.run(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if completed.returncode == 0:
        raise AssertionError(f"expected failure: {' '.join(args)}")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> None:
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        evidence_path = tmp / "release-evidence.json"
        run_ok(
            str(GENERATE),
            "--allow-dirty",
            "--release-name",
            "test-fixture",
            "--production-gate-result",
            "passed",
            "--output",
            str(evidence_path),
        )
        run_ok(str(VALIDATE), "--allow-dirty", "--expect-production-gate-result", "passed", str(evidence_path))
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))

        wrong_schema = copy.deepcopy(evidence)
        wrong_schema["schemaVersion"] = 2
        path = tmp / "wrong-schema.json"
        write_json(path, wrong_schema)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        dirty_not_allowed = copy.deepcopy(evidence)
        dirty_not_allowed["repository"]["dirty"] = True
        path = tmp / "dirty.json"
        write_json(path, dirty_not_allowed)
        run_fail(str(VALIDATE), str(path))

        skipped_gate = copy.deepcopy(evidence)
        skipped_gate["productionGate"]["command"] = "Scripts/production-gate.sh --skip-formal"
        path = tmp / "skipped-gate.json"
        write_json(path, skipped_gate)
        run_fail(str(VALIDATE), "--allow-dirty", "--expect-production-gate-result", "passed", str(path))

        wrong_version = copy.deepcopy(evidence)
        wrong_version["publicSurfaces"]["proofEnvelopeHeaderVersion"] = 5
        path = tmp / "wrong-version.json"
        write_json(path, wrong_version)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_numiseal_scope = copy.deepcopy(evidence)
        wrong_numiseal_scope["publicSurfaces"]["numiSealConformanceScopeVersion"] = 2
        path = tmp / "wrong-numiseal-scope.json"
        write_json(path, wrong_numiseal_scope)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_numiseal_theorem_scope = copy.deepcopy(evidence)
        wrong_numiseal_theorem_scope["publicSurfaces"]["numiSealEndToEndTheoremScopeVersion"] = 2
        path = tmp / "wrong-numiseal-theorem-scope.json"
        write_json(path, wrong_numiseal_theorem_scope)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_numiseal_theorem_scope = copy.deepcopy(evidence)
        vague_numiseal_theorem_scope["publicSurfaces"]["numiSealEndToEndTheoremScopeClaimStatus"] = "full-product-theorem"
        path = tmp / "vague-numiseal-theorem-scope.json"
        write_json(path, vague_numiseal_theorem_scope)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_numiseal_mask_distribution = copy.deepcopy(evidence)
        wrong_numiseal_mask_distribution["publicSurfaces"]["numiSealZKMaskDistributionEvidenceVersion"] = 2
        path = tmp / "wrong-numiseal-mask-distribution.json"
        write_json(path, wrong_numiseal_mask_distribution)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_numiseal_mask_distribution = copy.deepcopy(evidence)
        vague_numiseal_mask_distribution["publicSurfaces"]["numiSealZKMaskDistributionEvidenceClaimStatus"] = "privacy-proof"
        path = tmp / "vague-numiseal-mask-distribution.json"
        write_json(path, vague_numiseal_mask_distribution)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_product_crypto_dossier = copy.deepcopy(evidence)
        wrong_product_crypto_dossier["publicSurfaces"]["productCryptoSecurityDossierVersion"] = 2
        path = tmp / "wrong-product-crypto-dossier.json"
        write_json(path, wrong_product_crypto_dossier)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_product_crypto_dossier = copy.deepcopy(evidence)
        vague_product_crypto_dossier["publicSurfaces"]["productCryptoSecurityDossierClaimStatus"] = "production-security-theorem"
        path = tmp / "vague-product-crypto-dossier.json"
        write_json(path, vague_product_crypto_dossier)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        premature_product_depth = copy.deepcopy(evidence)
        premature_product_depth["publicSurfaces"]["productCryptoSecurityDossierMaximumDepth"] = 2
        path = tmp / "premature-product-depth.json"
        write_json(path, premature_product_depth)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_constant_time_scope = copy.deepcopy(evidence)
        wrong_constant_time_scope["publicSurfaces"]["constantTimeScopeVersion"] = 2
        path = tmp / "wrong-constant-time-scope.json"
        write_json(path, wrong_constant_time_scope)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_constant_time_lowering = copy.deepcopy(evidence)
        wrong_constant_time_lowering["publicSurfaces"]["constantTimeLoweringEvidenceVersion"] = 2
        path = tmp / "wrong-constant-time-lowering.json"
        write_json(path, wrong_constant_time_lowering)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_constant_time_lowering = copy.deepcopy(evidence)
        vague_constant_time_lowering["publicSurfaces"]["constantTimeLoweringEvidenceClaimStatus"] = "full-proof"
        path = tmp / "vague-constant-time-lowering.json"
        write_json(path, vague_constant_time_lowering)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_constant_time_release_evidence = copy.deepcopy(evidence)
        wrong_constant_time_release_evidence["publicSurfaces"]["constantTimeReleaseEvidenceVersion"] = 2
        path = tmp / "wrong-constant-time-release-evidence.json"
        write_json(path, wrong_constant_time_release_evidence)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_constant_time_release_evidence = copy.deepcopy(evidence)
        vague_constant_time_release_evidence["publicSurfaces"]["constantTimeReleaseEvidenceClaimStatus"] = "certified"
        path = tmp / "vague-constant-time-release-evidence.json"
        write_json(path, vague_constant_time_release_evidence)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_constant_time_compiler_lanes = copy.deepcopy(evidence)
        vague_constant_time_compiler_lanes["publicSurfaces"]["constantTimeCompilerObservationLanesClaimStatus"] = "certified"
        path = tmp / "vague-constant-time-compiler-lanes.json"
        write_json(path, vague_constant_time_compiler_lanes)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_constant_time_hardware_lanes = copy.deepcopy(evidence)
        vague_constant_time_hardware_lanes["publicSurfaces"]["constantTimeHardwareObservationLanesClaimStatus"] = "certified"
        path = tmp / "vague-constant-time-hardware-lanes.json"
        write_json(path, vague_constant_time_hardware_lanes)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_e2e_metrics = copy.deepcopy(evidence)
        wrong_e2e_metrics["publicSurfaces"]["e2eProofMetricsVersion"] = 2
        path = tmp / "wrong-e2e-metrics.json"
        write_json(path, wrong_e2e_metrics)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_product_budget = copy.deepcopy(evidence)
        missing_product_budget["publicSurfaces"]["e2eProofMetricsGeneratedBudgetCount"] = 1
        path = tmp / "missing-product-budget.json"
        write_json(path, missing_product_budget)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_product_ops_surface = copy.deepcopy(evidence)
        wrong_product_ops_surface["publicSurfaces"]["productOperationsStatusVersion"] = 1
        path = tmp / "wrong-product-ops-surface.json"
        write_json(path, wrong_product_ops_surface)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        outsourced_review_boundary = copy.deepcopy(evidence)
        outsourced_review_boundary["productionSecurityBoundaries"].append("External" + " audit required.")
        path = tmp / "outsourced-review-boundary.json"
        write_json(path, outsourced_review_boundary)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_doc = copy.deepcopy(evidence)
        missing_doc["documentation"]["releaseRunbook"] = "Docs/missing-release-runbook.md"
        path = tmp / "missing-doc.json"
        write_json(path, missing_doc)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_signing = copy.deepcopy(evidence)
        vague_signing["signing"]["status"] = "unsigned"
        path = tmp / "vague-signing.json"
        write_json(path, vague_signing)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

    print("release candidate evidence validation regression tests passed")


if __name__ == "__main__":
    main()
