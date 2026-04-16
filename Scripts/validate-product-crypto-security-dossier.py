#!/usr/bin/env python3
"""Validate the product cryptographic security theorem dossier."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DOSSIER = ROOT / "TestVectors" / "product-crypto-security-dossier-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "dossierID",
    "claimStatus",
    "formalTheorem",
    "relatedManifests",
    "productTheoremCoverage",
    "supportedProductDepth",
    "latticeAssumptionDossier",
    "normGrowthAndFailureBudget",
    "fiatShamirQROMPosition",
    "zkPrivacyProofStatus",
    "carryRecursionClosure",
    "proofSizeLatencyComparison",
    "implementationHardening",
    "promotionRule",
}

EXPECTED_COVERAGE = {
    "source fold relation",
    "NumiSeal terminal relation",
    "NumiSealZK masked residual relation",
    "typed recursive carry relation",
    "transcript binding",
    "artifact/proof-envelope binding",
    "verifier acceptance policy",
    "soundness/completeness/ZK composition",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "ProductFiatShamirModel",
    "ProductRecursionDepthModel",
    "ProductSecurityParameters",
    "ProductSystemBindings",
    "ProductSystemBindingsAccepted",
    "ProductBoundedDepthLossEvidence",
    "ProductBoundedDepthLossAccepted",
    "ProductLatticeAssumptionDossier",
    "ProductLatticeAssumptionDossierAccepted",
    "ProductFiatShamirQROMEvidence",
    "ProductFiatShamirQROMAccepted",
    "ProductCompletenessSoundnessZKClaim",
    "ProductCompletenessSoundnessZKHolds",
    "ProductSecurityTheoremEvidence",
    "productSecurityTheorem_from_evidence",
    "productSecurityTheorem_requires_bounded_depth",
    "productSecurityTheorem_requires_qrom_accounting",
    "productSecurityTheorem_requires_artifact_envelope_binding",
}

EXPECTED_MANIFESTS = {
    "numiSealConformanceScope": "TestVectors/numiseal-conformance-scope-v1.json",
    "numiSealEndToEndTheoremScope": "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
    "numiSealZKMaskDistributionEvidence": "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
    "constantTimeScope": "TestVectors/constant-time-scope-v1.json",
    "constantTimeLoweringEvidence": "TestVectors/constant-time-lowering-evidence-v1.json",
    "constantTimeReleaseEvidence": "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json",
    "e2eProofMetrics": "TestVectors/e2e-proof-metrics-v1.json",
    "latticeEstimator": "lattice-estimator-results/superneo-goldilocks-phi81.json",
}

EXPECTED_LATTICE = {
    "assumptionName": "Module-SIS over Goldilocks/Phi81 Ajtai commitments",
    "profileID": 1,
    "qDecimal": "18446744069414584321",
    "qHex": "ffffffff00000001",
    "field": "Goldilocks",
    "ring": "F_q[X]/(X^54 + X^27 + 1)",
    "cyclotomicIndex": 81,
    "ringDegree": 54,
    "kappa": 18,
    "decompositionLength": 14,
    "normBound": 2,
    "challengeExpansionFactor": 216,
    "maxFreshBatchCount": 61,
    "maxPriorCEClaimCount": 14,
    "moduleSISDimension": 972,
    "estimatorMSISLength": 1073741824,
    "lengthBoundL2": "927712935936",
    "decompositionRadixBound": 16384,
    "strongSamplingLeft": 16200,
    "claimedSecurityBits": 129,
    "pinnedEstimatorMinimumROPBits": 129.1,
}

EXPECTED_COST_ROWS = {
    ("MATZOV", "default"): 129.1,
    ("ADPS16", "classical"): 100.7,
    ("ADPS16", "quantum"): 91.4,
    ("ADPS16", "paranoid"): 71.6,
    ("ChaLoy21", "enumeration"): 88.7,
    ("LaaMosPol14", "enumeration"): 122.4,
}


def fail(message: str) -> None:
    print(f"product crypto security dossier validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), f"{path.relative_to(ROOT)} root must be an object")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a non-empty list")
    result: list[str] = []
    for index, item in enumerate(value):
        require(isinstance(item, str) and item, f"{label}[{index}] must be a non-empty string")
        result.append(item)
    return result


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false until the required evidence is instantiated")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_formal_theorem(dossier: dict[str, Any]) -> None:
    formal = require_dict(dossier.get("formalTheorem"), "formalTheorem")
    module_path = require_relative_path(formal.get("module"), "formalTheorem.module")
    require(
        formal.get("rootImport") == "import SuperNeoFormal.ProductSecurityTheorem",
        "formalTheorem.rootImport must pin the product security theorem import",
    )
    root = (ROOT / "Formal" / "SuperNeoFormal.lean").read_text(encoding="utf-8")
    require(
        "import SuperNeoFormal.ProductSecurityTheorem" in root,
        "Formal/SuperNeoFormal.lean must import the product security theorem module",
    )
    source = module_path.read_text(encoding="utf-8")
    declarations = set(require_string_list(formal.get("declarations"), "formalTheorem.declarations"))
    require(
        EXPECTED_FORMAL_DECLARATIONS.issubset(declarations),
        "formalTheorem.declarations must pin every product theorem surface declaration",
    )
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing declaration {declaration}")


def validate_related_manifests(dossier: dict[str, Any]) -> None:
    related = require_dict(dossier.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the current evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")


def validate_coverage(dossier: dict[str, Any]) -> None:
    coverage = set(require_string_list(dossier.get("productTheoremCoverage"), "productTheoremCoverage"))
    require(EXPECTED_COVERAGE.issubset(coverage), "product theorem coverage is missing required relation coverage")


def validate_depth(dossier: dict[str, Any]) -> None:
    depth = require_dict(dossier.get("supportedProductDepth"), "supportedProductDepth")
    require(depth.get("depthModel") == "bounded-depth", "product depth model must stay bounded-depth")
    require(depth.get("currentProductDefaultMaximumDepth") == 1, "current product default maximum depth must be 1")
    require(depth.get("theoremMaximumDepth") == 1, "theorem maximum depth must be 1 until losses are instantiated")
    require_false(depth.get("polyDepthTheoremClaimAllowed"), "supportedProductDepth.polyDepthTheoremClaimAllowed")
    require(depth.get("recursiveCarryProductDefault") == "none", "recursive carry product default must remain none")
    require_false(depth.get("recursiveCarryPromotionAllowed"), "supportedProductDepth.recursiveCarryPromotionAllowed")
    obligations = " ".join(require_string_list(depth.get("remainingForDepthPromotion"), "supportedProductDepth.remainingForDepthPromotion")).lower()
    for needle in ["extractor", "recursive typed carry", "loss", "polynomial-depth"]:
        require(needle in obligations, f"depth-promotion obligations must mention {needle}")


def validate_lattice(dossier: dict[str, Any]) -> None:
    lattice = require_dict(dossier.get("latticeAssumptionDossier"), "latticeAssumptionDossier")
    for key, expected in EXPECTED_LATTICE.items():
        require(lattice.get(key) == expected, f"latticeAssumptionDossier.{key} mismatch")
    require(lattice.get("normRoots") == [-1, 0, 1], "norm roots must stay pinned")
    require(lattice.get("challengeCoefficients") == [-2, -1, 0, 1, 2], "challenge coefficients must stay pinned")
    require_false(lattice.get("productionPostQuantumClaimAllowed"), "latticeAssumptionDossier.productionPostQuantumClaimAllowed")
    require("128-bit post-quantum claim" in require_string(lattice.get("postQuantumBoundary"), "postQuantumBoundary"), "postQuantumBoundary must state the PQ boundary")

    estimator = read_json(ROOT / str(EXPECTED_MANIFESTS["latticeEstimator"]))
    profile = require_dict(estimator.get("profile"), "latticeEstimator.profile")
    module_sis = require_dict(estimator.get("module_sis_parameters"), "latticeEstimator.module_sis_parameters")
    pinned = require_dict(estimator.get("pinned_reproduction"), "latticeEstimator.pinned_reproduction")
    require(profile.get("q") == int(lattice["qDecimal"]), "lattice q must match estimator artifact")
    require(profile.get("cyclotomicDegree") == lattice["ringDegree"], "ring degree must match estimator artifact")
    require(profile.get("kappa") == lattice["kappa"], "kappa must match estimator artifact")
    require(profile.get("decompositionLength") == lattice["decompositionLength"], "decomposition length must match estimator artifact")
    require(module_sis.get("n_sis") == lattice["moduleSISDimension"], "n_sis must match dossier")
    require(module_sis.get("m_sis") == lattice["estimatorMSISLength"], "m_sis must match dossier")
    require(str(module_sis.get("length_bound_l2")) == lattice["lengthBoundL2"], "length_bound_l2 must match dossier")
    require(module_sis.get("norm") == lattice["normBound"], "norm must match dossier")
    require(module_sis.get("strong_sampling_left") == lattice["strongSamplingLeft"], "strong sampling left must match dossier")
    require(pinned.get("minimum_extracted_rop_bits") == lattice["pinnedEstimatorMinimumROPBits"], "ROP bits must match pinned estimator")
    require(pinned.get("threshold_bits") == lattice["claimedSecurityBits"], "threshold bits must match claimed security bits")

    rows = require_string_cost_rows(lattice.get("costEstimates"))
    require(rows == EXPECTED_COST_ROWS, "costEstimates must pin the current sensitivity table")


def require_string_cost_rows(value: Any) -> dict[tuple[str, str], float]:
    require(isinstance(value, list) and value, "costEstimates must be a non-empty list")
    rows: dict[tuple[str, str], float] = {}
    for index, item in enumerate(value):
        row = require_dict(item, f"costEstimates[{index}]")
        model = require_string(row.get("model"), f"costEstimates[{index}].model")
        cost_class = require_string(row.get("costClass"), f"costEstimates[{index}].costClass")
        rop_bits = row.get("ropBits")
        require(isinstance(rop_bits, (int, float)), f"costEstimates[{index}].ropBits must be numeric")
        rows[(model, cost_class)] = float(rop_bits)
    return rows


def validate_norm_budget(dossier: dict[str, Any]) -> None:
    norm = require_dict(dossier.get("normGrowthAndFailureBudget"), "normGrowthAndFailureBudget")
    require(norm.get("strongSamplingInequality") == "(K + k) * T * (b - 1) < b^k", "strong sampling inequality mismatch")
    require(norm.get("leftSide") == 16200, "strong sampling left side mismatch")
    require(norm.get("rightSide") == 16384, "strong sampling right side mismatch")
    require(norm.get("status") == "profile-bound-recorded-product-path-losses-not-fully-instantiated", "norm-growth status must stay precise")
    require(norm.get("failureProbabilityBudgetRecorded") is True, "failure probability budget must be recorded")
    obligations = " ".join(require_string_list(norm.get("remainingObligations"), "normGrowthAndFailureBudget.remainingObligations")).lower()
    for needle in ["source folding", "terminal numiseal", "typed carry", "fiat-shamir"]:
        require(needle in obligations, f"norm-growth obligations must mention {needle}")


def validate_fiat_shamir(dossier: dict[str, Any]) -> None:
    qrom = require_dict(dossier.get("fiatShamirQROMPosition"), "fiatShamirQROMPosition")
    require(qrom.get("model") == "qrom", "Fiat-Shamir model must be qrom")
    for key in [
        "interactiveProtocolSpecified",
        "transformPreconditionsSatisfied",
        "quantumOracleQueryBoundAccounted",
        "transcriptCollisionMalleabilityExcluded",
        "productionQROMClaimAllowed",
    ]:
        require_false(qrom.get(key), f"fiatShamirQROMPosition.{key}")
    require(qrom.get("transcriptDomainSeparatorsBound") is True, "transcript domain separator binding must be recorded")
    require(qrom.get("proofKindSeparationBound") is True, "proof kind separation binding must be recorded")
    obligations = " ".join(require_string_list(qrom.get("remainingObligations"), "fiatShamirQROMPosition.remainingObligations")).lower()
    for needle in ["interactive protocol", "preconditions", "quantum random-oracle", "collision", "malleability"]:
        require(needle in obligations, f"QROM obligations must mention {needle}")


def validate_zk_and_carry(dossier: dict[str, Any]) -> None:
    zk = require_dict(dossier.get("zkPrivacyProofStatus"), "zkPrivacyProofStatus")
    require("masked residual" in require_string(zk.get("formalMaskedResidualLanguage"), "formalMaskedResidualLanguage").lower(), "ZK status must name the masked residual language")
    require("evidence-parametric" in require_string(zk.get("simulatorWithoutWitness"), "simulatorWithoutWitness"), "simulator status must stay evidence-parametric")
    require("reuse" in require_string(zk.get("maskReusePolicy"), "maskReusePolicy").lower(), "mask reuse policy must be explicit")
    leakage = set(require_string_list(zk.get("leakageModel"), "zkPrivacyProofStatus.leakageModel"))
    require({"randomness session digest", "declared leakage digest", "mask tensor dimensions"}.issubset(leakage), "ZK leakage model must pin public leakage")
    require_false(zk.get("productionZKPrivacyClaimAllowed"), "zkPrivacyProofStatus.productionZKPrivacyClaimAllowed")

    carry = require_dict(dossier.get("carryRecursionClosure"), "carryRecursionClosure")
    require("implemented" in require_string(carry.get("producerPath"), "producerPath"), "carry producer path must be recorded")
    require("implemented" in require_string(carry.get("consumerPath"), "consumerPath"), "carry consumer path must be recorded")
    require(carry.get("productDefaultCarryMode") == "none", "product default carry mode must remain none")
    require_false(carry.get("productionRecursiveCarryClaimAllowed"), "carryRecursionClosure.productionRecursiveCarryClaimAllowed")
    vectors = set(require_string_list(carry.get("conformanceVectors"), "carryRecursionClosure.conformanceVectors"))
    require("TestVectors/numiseal-typed-carry-conformance-v1.json" in vectors, "typed carry conformance vector must be pinned")
    require_relative_path("TestVectors/numiseal-typed-carry-conformance-v1.json", "carry typed vector")
    swap = require_string(carry.get("swapResistance"), "swapResistance").lower()
    for needle in ["producer", "transcript", "context", "lane", "parent"]:
        require(needle in swap, f"carry swap resistance must mention {needle}")


def validate_performance_and_hardening(dossier: dict[str, Any]) -> None:
    perf = require_dict(dossier.get("proofSizeLatencyComparison"), "proofSizeLatencyComparison")
    require(perf.get("localProofSizeEvidence") == "TestVectors/e2e-proof-metrics-v1.json", "proof-size evidence path mismatch")
    comparison = " ".join(require_string_list(perf.get("comparisonClass"), "proofSizeLatencyComparison.comparisonClass")).lower()
    require("latticefold" in comparison and "stark" in comparison, "comparison class must include LatticeFold and STARK-style systems")
    require_false(perf.get("sameHardwareCompetitorTablePinned"), "proofSizeLatencyComparison.sameHardwareCompetitorTablePinned")
    require_false(perf.get("productionPerformanceClaimAllowed"), "proofSizeLatencyComparison.productionPerformanceClaimAllowed")
    budgets = perf.get("currentLocalBudgets")
    require(isinstance(budgets, list) and len(budgets) == 2, "proof-size comparison must pin two current local budgets")
    budget_ids = {require_dict(item, "currentLocalBudgets item").get("id") for item in budgets}
    require(budget_ids == {"numiseal-product-smoke", "numiseal-zk-product-smoke"}, "proof-size local budget ids mismatch")

    hardening = require_dict(dossier.get("implementationHardening"), "implementationHardening")
    for key, expected in [
        ("constantTimeScopeManifest", "TestVectors/constant-time-scope-v1.json"),
        ("loweringEvidenceManifest", "TestVectors/constant-time-lowering-evidence-v1.json"),
        ("releaseEvidenceManifest", "Evidence/ConstantTime/swift-llvm-metal-v1/manifest.json"),
    ]:
        require(hardening.get(key) == expected, f"implementationHardening.{key} mismatch")
        require_relative_path(expected, f"implementationHardening.{key}")
    for key in [
        "secretDependentArtifactSizeErrorRetryBehaviorExcluded",
        "productionConstantTimeClaimAllowed",
    ]:
        require_false(hardening.get(key), f"implementationHardening.{key}")
    hardening_text = json.dumps(hardening, sort_keys=True).lower()
    for needle in ["sil", "llvm", "assembly", "metal", "hardware-counter", "failure"]:
        require(needle in hardening_text, f"implementation hardening must mention {needle}")


def validate_promotion(dossier: dict[str, Any]) -> None:
    promotion = require_dict(dossier.get("promotionRule"), "promotionRule")
    for key in [
        "productionProductSecurityClaimAllowed",
        "productionPostQuantumClaimAllowed",
        "productionQROMClaimAllowed",
        "productionZKPrivacyClaimAllowed",
        "productionRecursiveCarryClaimAllowed",
        "productionPerformanceClaimAllowed",
        "productionConstantTimeClaimAllowed",
    ]:
        require_false(promotion.get(key), f"promotionRule.{key}")
    require(promotion.get("requiresAllRemainingObligationsClosed") is True, "promotion rule must require all remaining obligations closed")


def validate_docs_and_gate() -> None:
    doc_path = ROOT / "Docs" / "CryptographicSecurityDossier-2026-04-16.md"
    require(doc_path.exists(), "cryptographic security dossier doc must exist")
    doc = doc_path.read_text(encoding="utf-8")
    for needle in [
        "bounded-depth product security theorem",
        "ProductSecurityTheorem",
        "TestVectors/product-crypto-security-dossier-v1.json",
        "Fiat-Shamir/QROM",
        "Module-SIS",
        "NumiSealZK masked residual relation",
        "production claims remain disabled",
    ]:
        require(needle in doc, f"cryptographic security dossier doc missing {needle}")

    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-crypto-security-dossier.py" in gate,
        "production gate must run product crypto security dossier validator",
    )
    require(
        "run_step Scripts/test-product-crypto-security-dossier-validation.py" in gate,
        "production gate must run product crypto security dossier validator regression tests",
    )


def validate_dossier(path: Path) -> None:
    dossier = read_json(path)
    text = json.dumps(dossier, sort_keys=True).lower()
    require("external" + " audit" not in text, "dossier must not encode outsourced review as a product gate")
    require(set(dossier) == EXPECTED_TOP_LEVEL_KEYS, "top-level dossier keys must match the v1 contract exactly")
    require(dossier.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(dossier.get("dossierID") == "superneo-product-crypto-security-dossier-v1", "dossierID mismatch")
    require(
        dossier.get("claimStatus") == "evidence-parametric-product-security-theorem-dossier",
        "claimStatus must stay evidence-parametric",
    )
    validate_formal_theorem(dossier)
    validate_related_manifests(dossier)
    validate_coverage(dossier)
    validate_depth(dossier)
    validate_lattice(dossier)
    validate_norm_budget(dossier)
    validate_fiat_shamir(dossier)
    validate_zk_and_carry(dossier)
    validate_performance_and_hardening(dossier)
    validate_promotion(dossier)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DOSSIER
    if not path.is_absolute():
        path = ROOT / path
    validate_dossier(path)
    print("product crypto security dossier validation passed")


if __name__ == "__main__":
    main()
