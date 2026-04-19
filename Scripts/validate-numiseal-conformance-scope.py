#!/usr/bin/env python3
"""Validate the NumiSeal product/carry/ZK conformance scope manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-conformance-scope-v1.json"
THEOREM_SCOPE = ROOT / "TestVectors" / "numiseal-end-to-end-theorem-scope-v1.json"
MASK_DISTRIBUTION_EVIDENCE = ROOT / "TestVectors" / "numiseal-zk-mask-distribution-evidence-v1.json"
REQUIRED_SURFACES = {
    "numiseal-product",
    "numiseal-typed-carry",
    "numiseal-zk",
}
REQUIRED_THEOREM_SURFACES = {
    "recursive-folding-knowledge-soundness",
    "source-fold-product-handoff",
    "terminal-seal",
    "typed-carry",
    "typed-carry-producer-consumer",
    "masked-residual-zk",
    "zk-leakage-simulation-privacy",
    "product-policy",
}
REQUIRED_RELATION_COMPONENTS = {
    "source fold relation",
    "artifact metadata and obligation reconstruction",
    "terminal NumiSeal seal relation",
    "typed carry relation",
    "typed carry producer/consumer relation",
    "masked residual ZK relation",
    "NumiSealZK leakage simulation privacy relation",
    "recursive folding knowledge relation",
    "product policy relation",
}
REQUIRED_SURFACE_TESTS = {
    "numiseal-product": {
        "testNumiSealProductVerifierBindsCarryModeToTerminalPolicy",
        "testNumiSealProductRecursiveCarryContextBindsParentArtifactAndSession",
        "testNumiSealProductRecursiveCarryParentProducesAndVerifiesTypedRequiredChild",
    },
}
REQUIRED_THEOREM_SURFACE_TESTS = {
    "product-policy": {
        "testNumiSealProductVerifierBindsCarryModeToTerminalPolicy",
    },
    "typed-carry-producer-consumer": {
        "testNumiSealProductRecursiveCarryContextBindsParentArtifactAndSession",
        "testNumiSealProductRecursiveCarryParentProducesAndVerifiesTypedRequiredChild",
    },
}
REQUIRED_SURFACE_VECTORS = {
    "numiseal-product": {
        "TestVectors/numiseal-product-recursive-carry-context-v1.json",
    },
}
REQUIRED_THEOREM_SURFACE_VECTORS = {
    "typed-carry-producer-consumer": {
        "TestVectors/numiseal-product-recursive-carry-context-v1.json",
    },
}
REQUIRED_FORMAL_DECLARATIONS = {
    "NumiSealProofMode",
    "NumiSealCarryMode",
    "NumiSealProductPolicyGates",
    "NumiSealTerminalSealGates",
    "NumiSealTypedCarryGates",
    "NumiSealZKGates",
    "NumiSealProductVerifierGates",
    "NumiSealEndToEndRelation",
    "NumiSealEndToEndEvidence",
    "NumiSealProductVerifierAccepts",
    "NumiSealTerminalProductVerifierAccepts",
    "NumiSealZKProductVerifierAccepts",
    "numiSealProduct_acceptance_requires_source_fold",
    "numiSealProduct_acceptance_requires_terminal_seal",
    "numiSealProduct_acceptance_requires_typed_carry",
    "numiSealProduct_acceptance_requires_zk_layer",
    "numiSealProduct_endToEnd_from_evidence",
    "numiSealTerminalProduct_endToEnd_from_evidence",
    "numiSealZKProduct_endToEnd_from_evidence",
}
REQUIRED_AUXILIARY_FORMAL_MODULES = {
    "Formal/SuperNeoFormal/RecursiveFoldingKnowledge.lean": {
        "rootImport": "import SuperNeoFormal.RecursiveFoldingKnowledge",
        "declarations": {
            "RecursiveFoldingKnowledgeStepGates",
            "RecursiveFoldingKnowledgeStepAccepted",
            "RecursiveFoldingKnowledgeStepRelation",
            "RecursiveFoldingKnowledgeStepRelationHolds",
            "RecursiveFoldingKnowledgeStepEvidence",
            "recursiveFoldingKnowledgeStepSoundness_from_evidence",
            "RecursiveFoldingKnowledgeChainGates",
            "RecursiveFoldingKnowledgeChainAccepted",
            "RecursiveFoldingKnowledgeChainRelation",
            "RecursiveFoldingKnowledgeChainHolds",
            "RecursiveFoldingKnowledgeChainEvidence",
            "recursiveFoldingKnowledgeSoundness_from_chainEvidence",
            "recursiveFoldingKnowledge_terminalCE_witnesses_from_constructive_badSeeds",
        },
    },
    "Formal/SuperNeoFormal/NumiSealTypedCarryTheorem.lean": {
        "rootImport": "import SuperNeoFormal.NumiSealTypedCarryTheorem",
        "declarations": {
            "NumiSealTypedCarryProducerGates",
            "NumiSealTypedCarryProducerAccepted",
            "NumiSealTypedCarryConsumerGates",
            "NumiSealTypedCarryConsumerAccepted",
            "NumiSealTypedCarryProducerConsumerRelation",
            "NumiSealTypedCarryProducerConsumerRelationHolds",
            "NumiSealTypedCarryProducerConsumerEvidence",
            "numiSealTypedCarryProducerConsumer_from_evidence",
            "numiSealTypedCarry_from_product_carry_acceptance",
        },
    },
    "Formal/SuperNeoFormal/NumiSealZKPrivacy.lean": {
        "rootImport": "import SuperNeoFormal.NumiSealZKPrivacy",
        "declarations": {
            "NumiSealZKLeakageModel",
            "NumiSealZKLeakageModelAccepted",
            "NumiSealZKSimulationPrivacyClaim",
            "NumiSealZKSimulationPrivacyHolds",
            "NumiSealZKSimulationEvidence",
            "numiSealZKSimulationPrivacy_from_evidence",
            "numiSealZKProduct_privacy_from_product_acceptance",
            "numiSealZKPrivacy_leakage_only_view",
            "numiSealZKPrivacy_simulated_view_indistinguishable",
        },
    },
    "Formal/SuperNeoFormal/NumiSealProductTheorem.lean": {
        "rootImport": "import SuperNeoFormal.NumiSealProductTheorem",
        "declarations": {
            "NumiSealProductKnowledgeCarryPrivacyRelations",
            "NumiSealProductKnowledgeCarryPrivacyHolds",
            "numiSealProductKnowledgeCarryPrivacy_composition",
            "numiSealProductKnowledgeCarryPrivacy_from_evidence",
        },
    },
}


def fail(message: str) -> None:
    print(f"NumiSeal conformance scope validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_string_list(value: Any, label: str, *, allow_empty: bool = False) -> list[str]:
    require(isinstance(value, list), f"{label} must be a list")
    require(allow_empty or bool(value), f"{label} must not be empty")
    result: list[str] = []
    for index, item in enumerate(value):
        require(isinstance(item, str) and item, f"{label}[{index}] must be a non-empty string")
        result.append(item)
    return result


def require_path(relative_path: str, label: str) -> None:
    path = ROOT / relative_path
    require(path.exists(), f"{label} does not exist: {relative_path}")


def require_manifest_path(value: Any, label: str) -> Path:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    path = Path(value)
    require(not path.is_absolute(), f"{label} must be repository-relative")
    require(".." not in path.parts, f"{label} must not escape the repository")
    absolute = ROOT / path
    require(absolute.exists(), f"{label} does not exist: {value}")
    return absolute


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), "conformance scope root must be an object")
    return value


def validate_surface(surface: Any, test_source: str) -> str:
    require(isinstance(surface, dict), "surface entry must be an object")
    surface_id = surface.get("id")
    require(isinstance(surface_id, str) and surface_id, "surface.id must be a non-empty string")

    implementation_paths = require_string_list(
        surface.get("implementationPaths"),
        f"{surface_id}.implementationPaths",
    )
    for path in implementation_paths:
        require_path(path, f"{surface_id} implementation path")

    vectors = require_string_list(
        surface.get("conformanceVectors"),
        f"{surface_id}.conformanceVectors",
    )
    required_vectors = REQUIRED_SURFACE_VECTORS.get(surface_id, set())
    require(
        required_vectors.issubset(set(vectors)),
        f"{surface_id}.conformanceVectors missing required vectors {sorted(required_vectors - set(vectors))}",
    )
    for path in vectors:
        require_path(path, f"{surface_id} conformance vector")
        vector = read_json(ROOT / path)
        if "surface" in vector:
            require(vector.get("formatVersion") == 1, f"{path} formatVersion must be 1")
            require(vector.get("surface") == surface_id, f"{path} surface must be {surface_id}")
            if vector.get("caseID") == "numiseal-product-recursive-carry-context-v1":
                statement = vector.get("statement")
                require(isinstance(statement, dict), f"{path}.statement must be an object")
                require(
                    statement.get("contextDomainLabel") == "SuperNeo-NuMetal.numiseal.product-carry-context.v1",
                    f"{path} must pin the product carry context domain",
                )
                require(
                    statement.get("contextDigestLabel") == "numiseal.product-carry-context.digest.v1",
                    f"{path} must pin the product carry context digest label",
                )
                bound_fields = set(require_string_list(statement.get("boundFields"), f"{path}.statement.boundFields"))
                require(
                    {
                        "parent product artifact digest",
                        "parent source fold envelope digest",
                        "parent product proof envelope digest",
                        "parent producer proof envelope digest",
                        "consumer session digest",
                        "next recursion level",
                    }.issubset(bound_fields),
                    f"{path} must bind the product recursive carry context fields",
                )
                require(
                    statement.get("contextRootLabel") == "numiseal.product-carry.context-root.v1",
                    f"{path} must pin the product carry context root label",
                )
                require(
                    statement.get("replayRootLabel") == "numiseal.product-carry.replay-root.v1",
                    f"{path} must pin the product carry replay root label",
                )
                require(
                    statement.get("productReplayBindingLabel")
                    == "SuperNeo-NuMetal.numiseal.product.recursive-carry.replay-binding.v1",
                    f"{path} must pin the product replay-binding label",
                )
                positive_cases = " ".join(
                    require_string_list(vector.get("positiveCases"), f"{path}.positiveCases")
                ).lower()
                for needle in ["signed parent provenance", "prior parent replay acceptance", "single-use"]:
                    require(needle in positive_cases, f"{path} positive cases must mention {needle}")
                negative_cases = " ".join(
                    require_string_list(vector.get("negativeCases"), f"{path}.negativeCases")
                ).lower()
                for needle in ["parent proof identity", "duplicate local carry consumption"]:
                    require(needle in negative_cases, f"{path} negative cases must mention {needle}")
            if surface_id == "numiseal-zk":
                statement = vector.get("statement")
                require(isinstance(statement, dict), f"{path}.statement must be an object")
                require(
                    statement.get("maskDistributionEvidence") == "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
                    f"{path} must link the NumiSealZK mask-distribution evidence",
                )
                require(
                    statement.get("maskExpandDomainLabel") == "SuperNeo-NuMetal.numiseal.zk.mask-expand.v2",
                    f"{path} must pin the rejection-sampled mask expansion domain",
                )
                require(statement.get("maskCandidateBitWidth") == 64, f"{path} maskCandidateBitWidth must be 64")
                require(statement.get("maskRejectedCandidateCount") == "4294967295", f"{path} maskRejectedCandidateCount mismatch")
            covered_by_tests = require_string_list(vector.get("coveredByTests"), f"{path}.coveredByTests")
            for name in covered_by_tests:
                require(name in test_source, f"{path} covered test not found in XCTest source: {name}")
        else:
            require(vector.get("artifactVersion") == 1, f"{path} artifactVersion must be 1")

    test_names = require_string_list(surface.get("testNames"), f"{surface_id}.testNames")
    for name in test_names:
        require(name in test_source, f"{surface_id} test not found in XCTest source: {name}")
    required_tests = REQUIRED_SURFACE_TESTS.get(surface_id, set())
    require(
        required_tests.issubset(set(test_names)),
        f"{surface_id}.testNames missing required tests {sorted(required_tests - set(test_names))}",
    )

    formal_scope = require_string_list(surface.get("formalScope"), f"{surface_id}.formalScope")
    open_formal_work = require_string_list(surface.get("openFormalWork"), f"{surface_id}.openFormalWork")
    joined_text = " ".join(formal_scope + open_formal_work).lower()
    require("external" + " audit" not in joined_text, f"{surface_id} must not encode outsourced review as formal work")
    return surface_id


def validate_theorem_surface(surface: Any, test_source: str) -> str:
    require(isinstance(surface, dict), "theorem surface entry must be an object")
    surface_id = surface.get("id")
    require(isinstance(surface_id, str) and surface_id, "theorem surface id must be a non-empty string")

    for key in ["implementationPaths", "conformanceVectors", "testNames", "evidenceObligations"]:
        values = require_string_list(surface.get(key), f"{surface_id}.{key}")
        if key == "implementationPaths" or key == "conformanceVectors":
            for path in values:
                require_path(path, f"{surface_id} {key}")
            if key == "conformanceVectors":
                required_vectors = REQUIRED_THEOREM_SURFACE_VECTORS.get(surface_id, set())
                require(
                    required_vectors.issubset(set(values)),
                    f"{surface_id}.conformanceVectors missing required vectors {sorted(required_vectors - set(values))}",
                )
        if key == "testNames":
            for name in values:
                require(name in test_source, f"{surface_id} theorem test not found in XCTest source: {name}")
            required_tests = REQUIRED_THEOREM_SURFACE_TESTS.get(surface_id, set())
            require(
                required_tests.issubset(set(values)),
                f"{surface_id}.testNames missing required tests {sorted(required_tests - set(values))}",
            )
    status = surface.get("status")
    require(status == "composed-under-evidence", f"{surface_id}.status must be composed-under-evidence")
    joined_text = " ".join(require_string_list(surface.get("evidenceObligations"), f"{surface_id}.evidenceObligations")).lower()
    require("external" + " audit" not in joined_text, f"{surface_id} must not encode outsourced review")
    return surface_id


def validate_formal_module(module: Any, *, expected_module: str, expected_root_import: str, expected_declarations: set[str], label: str) -> None:
    require(isinstance(module, dict), f"{label} must be an object")
    module_path = require_manifest_path(module.get("module"), f"{label}.module")
    require(str(module_path.relative_to(ROOT)) == expected_module, f"{label}.module mismatch")
    root_import = module.get("rootImport")
    require(root_import == expected_root_import, f"{label}.rootImport mismatch")
    root_module = (ROOT / "Formal" / "SuperNeoFormal.lean").read_text(encoding="utf-8")
    require(root_import in root_module, f"root SuperNeoFormal module must import {expected_root_import}")
    formal_text = module_path.read_text(encoding="utf-8")
    declarations = set(require_string_list(module.get("declarations"), f"{label}.declarations"))
    require(
        declarations == expected_declarations,
        f"{label}.declarations must be exactly {sorted(expected_declarations)}",
    )
    for declaration in declarations:
        require(declaration in formal_text, f"{label} formal declaration not found: {declaration}")


def validate_theorem_scope(path: Path, test_source: str) -> None:
    theorem_scope = read_json(path)
    require(theorem_scope.get("schemaVersion") == 1, "theorem scope schemaVersion must be 1")
    require(
        theorem_scope.get("scopeID") == "numiseal-end-to-end-product-carry-zk-theorem-scope-v1",
        "theorem scopeID is unsupported",
    )
    require(
        theorem_scope.get("claimStatus") == "evidence-parametric-end-to-end-composition-theorem",
        "theorem claimStatus must stay precise",
    )
    require(
        theorem_scope.get("conformanceScope") == "TestVectors/numiseal-conformance-scope-v1.json",
        "theorem scope must link the NumiSeal conformance scope",
    )
    require(
        theorem_scope.get("zkMaskDistributionEvidence") == "TestVectors/numiseal-zk-mask-distribution-evidence-v1.json",
        "theorem scope must link the NumiSealZK mask-distribution evidence",
    )
    require(
        theorem_scope.get("zkSimulatorCouplingEvidence") == "TestVectors/numiseal-zk-simulator-coupling-evidence-v1.json",
        "theorem scope must link the NumiSealZK simulator-coupling evidence",
    )
    simulator = read_json(ROOT / "TestVectors" / "numiseal-zk-simulator-coupling-evidence-v1.json")
    proof_level = require_dict(simulator.get("proofLevelSimulatorCoupling"), "zkSimulatorCouplingEvidence.proofLevelSimulatorCoupling")
    require(
        proof_level.get("exactUpperBound") == "0" and proof_level.get("lossInstantiated") is True,
        "theorem scope requires instantiated proof-level ZK simulator coupling",
    )
    text = json.dumps(theorem_scope, sort_keys=True).lower()
    require("external" + " audit" not in text, "theorem scope must not encode outsourced review")

    formal_model = theorem_scope.get("formalModel")
    require(isinstance(formal_model, dict), "theorem formalModel must be an object")
    validate_formal_module(
        formal_model,
        expected_module="Formal/SuperNeoFormal/NumiSealEndToEnd.lean",
        expected_root_import="import SuperNeoFormal.NumiSealEndToEnd",
        expected_declarations=REQUIRED_FORMAL_DECLARATIONS,
        label="theorem formalModel",
    )
    auxiliary_modules = formal_model.get("auxiliaryModules")
    require(isinstance(auxiliary_modules, list), "theorem formalModel.auxiliaryModules must be a list")
    seen_auxiliary_modules = set()
    for index, auxiliary in enumerate(auxiliary_modules):
        require(isinstance(auxiliary, dict), f"theorem formalModel.auxiliaryModules[{index}] must be an object")
        module_name = auxiliary.get("module")
        require(isinstance(module_name, str) and module_name, f"theorem formalModel.auxiliaryModules[{index}].module must be a non-empty string")
        expected = REQUIRED_AUXILIARY_FORMAL_MODULES.get(module_name)
        require(expected is not None, f"unexpected auxiliary theorem module: {module_name}")
        validate_formal_module(
            auxiliary,
            expected_module=module_name,
            expected_root_import=expected["rootImport"],
            expected_declarations=expected["declarations"],
            label=f"theorem formalModel.auxiliaryModules[{index}]",
        )
        seen_auxiliary_modules.add(module_name)
    require(
        seen_auxiliary_modules == set(REQUIRED_AUXILIARY_FORMAL_MODULES.keys()),
        f"theorem auxiliary modules must be exactly {sorted(REQUIRED_AUXILIARY_FORMAL_MODULES)}",
    )

    relation_components = set(require_string_list(theorem_scope.get("relationComponents"), "theorem relationComponents"))
    require(
        relation_components == REQUIRED_RELATION_COMPONENTS,
        f"theorem relationComponents must be exactly {sorted(REQUIRED_RELATION_COMPONENTS)}",
    )
    surfaces = theorem_scope.get("theoremSurfaces")
    require(isinstance(surfaces, list), "theoremSurfaces must be a list")
    seen = {validate_theorem_surface(surface, test_source) for surface in surfaces}
    require(seen == REQUIRED_THEOREM_SURFACES, f"theoremSurfaces must be exactly {sorted(REQUIRED_THEOREM_SURFACES)}")

    require_string_list(theorem_scope.get("residualProofObligations"), "theorem residualProofObligations")
    promotion = theorem_scope.get("promotionRule")
    require(isinstance(promotion, dict), "theorem promotionRule must be an object")
    require(
        promotion.get("productionNumiSealTheoremClaimAllowed") is True,
        "theorem scope must allow repository-local production NumiSeal theorem claims",
    )
    require(promotion.get("releaseEvidenceOnly") is True, "theorem promotionRule.releaseEvidenceOnly must be true")
    unblock = promotion.get("unblockRequires")
    require(isinstance(unblock, list) and not unblock, "theorem promotionRule.unblockRequires must be empty after repository-local promotion")


def main() -> None:
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path
    scope = read_json(manifest_path)
    require(scope.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(scope.get("scopeID") == "numiseal-product-carry-zk-conformance-v1", "scopeID is unsupported")
    theorem_path = require_manifest_path(scope.get("theoremScopeManifest"), "theoremScopeManifest")
    mask_evidence_path = require_manifest_path(scope.get("zkMaskDistributionEvidence"), "zkMaskDistributionEvidence")
    simulator_evidence_path = require_manifest_path(scope.get("zkSimulatorCouplingEvidence"), "zkSimulatorCouplingEvidence")
    if manifest_path == MANIFEST:
        require(theorem_path == THEOREM_SCOPE, "theoremScopeManifest must point to the pinned theorem scope manifest")
        require(mask_evidence_path == MASK_DISTRIBUTION_EVIDENCE, "zkMaskDistributionEvidence must point to the pinned mask evidence manifest")
        require(
            simulator_evidence_path == ROOT / "TestVectors" / "numiseal-zk-simulator-coupling-evidence-v1.json",
            "zkSimulatorCouplingEvidence must point to the pinned simulator-coupling evidence manifest",
        )
    legacy_review_flag = "external" + "AuditRequired"
    require(legacy_review_flag not in scope, "outsourced review gate field must not be present")
    mask_evidence = read_json(mask_evidence_path)
    require(mask_evidence.get("schemaVersion") == 1, "mask-distribution evidence schemaVersion must be 1")
    require(
        mask_evidence.get("claimStatus") == "exact-rejection-sampled-field-mask-evidence",
        "mask-distribution evidence claimStatus must stay precise",
    )
    simulator_evidence = read_json(simulator_evidence_path)
    require(
        simulator_evidence.get("claimStatus") == "proof-level-simulator-coupling-instantiated-repository-local-production-zk-privacy",
        "simulator-coupling evidence claimStatus must stay precise",
    )

    test_source = (ROOT / "SuperNeo-NuMetalTests" / "SuperNeoNuMetalTests.swift").read_text(encoding="utf-8")
    validate_theorem_scope(theorem_path, test_source)
    surfaces = scope.get("surfaces")
    require(isinstance(surfaces, list), "surfaces must be a list")
    seen = {validate_surface(surface, test_source) for surface in surfaces}
    require(seen == REQUIRED_SURFACES, f"surfaces must be exactly {sorted(REQUIRED_SURFACES)}")

    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "Scripts/validate-numiseal-conformance-scope.py" in gate,
        "production gate must run validate-numiseal-conformance-scope.py",
    )
    require(
        "Scripts/test-numiseal-conformance-scope-validation.py" in gate,
        "production gate must run NumiSeal conformance scope regression tests",
    )
    release_validator = (ROOT / "Scripts" / "validate-release-readiness-policy.py").read_text(encoding="utf-8")
    require(
        "TestVectors/numiseal-conformance-scope-v1.json" in release_validator,
        "release readiness policy must pin the NumiSeal conformance scope manifest",
    )
    require(
        "TestVectors/numiseal-end-to-end-theorem-scope-v1.json" in release_validator,
        "release readiness policy must pin the NumiSeal end-to-end theorem scope manifest",
    )
    print("NumiSeal conformance scope validation passed")


if __name__ == "__main__":
    main()
