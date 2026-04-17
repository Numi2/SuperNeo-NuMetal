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

        wrong_selected_loss = copy.deepcopy(evidence)
        wrong_selected_loss["publicSurfaces"]["productSelectedDepthLossAccountingVersion"] = 2
        path = tmp / "wrong-selected-loss.json"
        write_json(path, wrong_selected_loss)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_selected_loss = copy.deepcopy(evidence)
        vague_selected_loss["publicSurfaces"]["productSelectedDepthLossAccountingClaimStatus"] = "production-loss-proof"
        path = tmp / "vague-selected-loss.json"
        write_json(path, vague_selected_loss)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        premature_selected_loss_depth = copy.deepcopy(evidence)
        premature_selected_loss_depth["publicSurfaces"]["productSelectedDepthLossAccountingMaximumDepth"] = 2
        path = tmp / "premature-selected-loss-depth.json"
        write_json(path, premature_selected_loss_depth)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_selected_loss_component = copy.deepcopy(evidence)
        missing_selected_loss_component["publicSurfaces"]["productSelectedDepthLossComponentCount"] = 8
        path = tmp / "missing-selected-loss-component.json"
        write_json(path, missing_selected_loss_component)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_extractor_loss = copy.deepcopy(evidence)
        wrong_extractor_loss["publicSurfaces"]["productExtractorLossAccountingVersion"] = 2
        path = tmp / "wrong-extractor-loss.json"
        write_json(path, wrong_extractor_loss)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_extractor_loss = copy.deepcopy(evidence)
        vague_extractor_loss["publicSurfaces"]["productExtractorLossAccountingClaimStatus"] = "production-extractor-proof"
        path = tmp / "vague-extractor-loss.json"
        write_json(path, vague_extractor_loss)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_extractor_component = copy.deepcopy(evidence)
        missing_extractor_component["publicSurfaces"]["productExtractorLossComponentCount"] = 3
        path = tmp / "missing-extractor-component.json"
        write_json(path, missing_extractor_component)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_qrom_accounting = copy.deepcopy(evidence)
        wrong_qrom_accounting["publicSurfaces"]["productQROMFiatShamirAccountingVersion"] = 2
        path = tmp / "wrong-qrom-accounting.json"
        write_json(path, wrong_qrom_accounting)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_qrom_accounting = copy.deepcopy(evidence)
        vague_qrom_accounting["publicSurfaces"]["productQROMFiatShamirAccountingClaimStatus"] = "production-qrom-proof"
        path = tmp / "vague-qrom-accounting.json"
        write_json(path, vague_qrom_accounting)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_interface = copy.deepcopy(evidence)
        missing_qrom_interface["publicSurfaces"]["productQROMFiatShamirTranscriptInterfaceCount"] = 4
        path = tmp / "missing-qrom-interface.json"
        write_json(path, missing_qrom_interface)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_qrom_schedule = copy.deepcopy(evidence)
        wrong_qrom_schedule["publicSurfaces"]["productQROMTranscriptScheduleVersion"] = 2
        path = tmp / "wrong-qrom-schedule.json"
        write_json(path, wrong_qrom_schedule)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_qrom_schedule = copy.deepcopy(evidence)
        vague_qrom_schedule["publicSurfaces"]["productQROMTranscriptScheduleClaimStatus"] = "production-qrom-schedule"
        path = tmp / "vague-qrom-schedule.json"
        write_json(path, vague_qrom_schedule)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_schedule_entry = copy.deepcopy(evidence)
        missing_qrom_schedule_entry["publicSurfaces"]["productQROMTranscriptScheduleEntryCount"] = 4
        path = tmp / "missing-qrom-schedule-entry.json"
        write_json(path, missing_qrom_schedule_entry)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_qrom_sampler_encoding = copy.deepcopy(evidence)
        wrong_qrom_sampler_encoding["publicSurfaces"]["productQROMSamplerEncodingEvidenceVersion"] = 2
        path = tmp / "wrong-qrom-sampler-encoding.json"
        write_json(path, wrong_qrom_sampler_encoding)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_qrom_sampler_encoding = copy.deepcopy(evidence)
        vague_qrom_sampler_encoding["publicSurfaces"][
            "productQROMSamplerEncodingEvidenceClaimStatus"
        ] = "production-qrom-proof"
        path = tmp / "vague-qrom-sampler-encoding.json"
        write_json(path, vague_qrom_sampler_encoding)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_sampler_uniformity = copy.deepcopy(evidence)
        missing_qrom_sampler_uniformity["publicSurfaces"][
            "productQROMSamplerEncodingEvidenceUniformityPinned"
        ] = False
        path = tmp / "missing-qrom-sampler-uniformity.json"
        write_json(path, missing_qrom_sampler_uniformity)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_frame_injectivity = copy.deepcopy(evidence)
        missing_qrom_frame_injectivity["publicSurfaces"][
            "productQROMSamplerEncodingEvidenceStructuredFrameInjective"
        ] = False
        path = tmp / "missing-qrom-frame-injectivity.json"
        write_json(path, missing_qrom_frame_injectivity)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_qrom_collision_malleability = copy.deepcopy(evidence)
        wrong_qrom_collision_malleability["publicSurfaces"][
            "productQROMCollisionMalleabilityEvidenceVersion"
        ] = 2
        path = tmp / "wrong-qrom-collision-malleability.json"
        write_json(path, wrong_qrom_collision_malleability)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_qrom_collision_malleability = copy.deepcopy(evidence)
        vague_qrom_collision_malleability["publicSurfaces"][
            "productQROMCollisionMalleabilityEvidenceClaimStatus"
        ] = "production-qrom-proof"
        path = tmp / "vague-qrom-collision-malleability.json"
        write_json(path, vague_qrom_collision_malleability)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_collision_malleability_structural = copy.deepcopy(evidence)
        missing_qrom_collision_malleability_structural["publicSurfaces"][
            "productQROMCollisionMalleabilityStructuralClosurePinned"
        ] = False
        path = tmp / "missing-qrom-collision-malleability-structural.json"
        write_json(path, missing_qrom_collision_malleability_structural)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        premature_qrom_collision_malleability_digest = copy.deepcopy(evidence)
        premature_qrom_collision_malleability_digest["publicSurfaces"][
            "productQROMCollisionMalleabilityDigestBoundInstantiated"
        ] = True
        path = tmp / "premature-qrom-collision-malleability-digest.json"
        write_json(path, premature_qrom_collision_malleability_digest)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_qrom_transform_preconditions = copy.deepcopy(evidence)
        wrong_qrom_transform_preconditions["publicSurfaces"]["productQROMTransformPreconditionsVersion"] = 2
        path = tmp / "wrong-qrom-transform-preconditions.json"
        write_json(path, wrong_qrom_transform_preconditions)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_qrom_transform_preconditions = copy.deepcopy(evidence)
        vague_qrom_transform_preconditions["publicSurfaces"]["productQROMTransformPreconditionsClaimStatus"] = "production-qrom-transform-proof"
        path = tmp / "vague-qrom-transform-preconditions.json"
        write_json(path, vague_qrom_transform_preconditions)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_transform_precondition = copy.deepcopy(evidence)
        missing_qrom_transform_precondition["publicSurfaces"]["productQROMTransformPreconditionCount"] = 9
        path = tmp / "missing-qrom-transform-precondition.json"
        write_json(path, missing_qrom_transform_precondition)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_qrom_interactive_reduction = copy.deepcopy(evidence)
        wrong_qrom_interactive_reduction["publicSurfaces"]["productQROMInteractiveReductionVersion"] = 2
        path = tmp / "wrong-qrom-interactive-reduction.json"
        write_json(path, wrong_qrom_interactive_reduction)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_qrom_interactive_reduction = copy.deepcopy(evidence)
        vague_qrom_interactive_reduction["publicSurfaces"]["productQROMInteractiveReductionClaimStatus"] = "production-qrom-reduction"
        path = tmp / "vague-qrom-interactive-reduction.json"
        write_json(path, vague_qrom_interactive_reduction)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_qrom_interactive_reduction_kind = copy.deepcopy(evidence)
        missing_qrom_interactive_reduction_kind["publicSurfaces"]["productQROMInteractiveReductionProofKindCount"] = 4
        path = tmp / "missing-qrom-interactive-reduction-kind.json"
        write_json(path, missing_qrom_interactive_reduction_kind)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        wrong_total_loss_budget = copy.deepcopy(evidence)
        wrong_total_loss_budget["publicSurfaces"]["productTotalLossBudgetVersion"] = 2
        path = tmp / "wrong-total-loss-budget.json"
        write_json(path, wrong_total_loss_budget)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        vague_total_loss_budget = copy.deepcopy(evidence)
        vague_total_loss_budget["publicSurfaces"]["productTotalLossBudgetClaimStatus"] = "production-total-loss-proof"
        path = tmp / "vague-total-loss-budget.json"
        write_json(path, vague_total_loss_budget)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_total_loss_component = copy.deepcopy(evidence)
        missing_total_loss_component["publicSurfaces"]["productTotalLossBudgetComponentCount"] = 9
        path = tmp / "missing-total-loss-component.json"
        write_json(path, missing_total_loss_component)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        premature_total_loss_instantiation = copy.deepcopy(evidence)
        premature_total_loss_instantiation["publicSurfaces"]["productTotalLossBudgetInstantiatedRequiredTermCount"] = 1
        path = tmp / "premature-total-loss-instantiation.json"
        write_json(path, premature_total_loss_instantiation)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        premature_total_loss_budget = copy.deepcopy(evidence)
        premature_total_loss_budget["publicSurfaces"]["productTotalLossBudgetWithinBudget"] = True
        path = tmp / "premature-total-loss-budget.json"
        write_json(path, premature_total_loss_budget)
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

        wrong_benchmark_coverage = copy.deepcopy(evidence)
        wrong_benchmark_coverage["publicSurfaces"]["benchmarkCoverageVersion"] = 2
        path = tmp / "wrong-benchmark-coverage.json"
        write_json(path, wrong_benchmark_coverage)
        run_fail(str(VALIDATE), "--allow-dirty", str(path))

        missing_benchmark_surface = copy.deepcopy(evidence)
        missing_benchmark_surface["publicSurfaces"]["benchmarkCoverageSurfaceCount"] = 1
        path = tmp / "missing-benchmark-surface.json"
        write_json(path, missing_benchmark_surface)
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
