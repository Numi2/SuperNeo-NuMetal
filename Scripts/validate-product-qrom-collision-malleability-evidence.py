#!/usr/bin/env python3
"""Validate structural product QROM H_bind collision/malleability evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "TestVectors" / "product-qrom-collision-malleability-evidence-v1.json"

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "evidenceID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "sourceSurfaces",
    "acceptedProofKinds",
    "structuralBinding",
    "residualEvents",
    "bindingTargetBound",
    "closureStatus",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productQROMFiatShamirAccounting": "TestVectors/product-qrom-fiat-shamir-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productQROMSamplerEncodingEvidence": "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "proofEnvelopeKindEncode_injective",
    "proofEnvelopeKindDecode?_encode",
    "proofEnvelopeTranscriptBindingEncode_injective",
    "proofEnvelopeTranscriptInit_context_injective",
    "ProductHashOracleInstantiation",
    "ProductQROMCollisionBound",
    "ProductQROMMalleabilityBound",
    "productSecurityTheorem_requires_qrom_collision_malleability_exclusion",
}

EXPECTED_SOURCE_SURFACES = {
    "proofEnvelope": "SuperNeo-NuMetal/SuperNeoSerialization.swift",
    "sumcheckTranscript": "SuperNeo-NuMetal/Transcript/SumCheckTranscript.swift",
    "localProductControls": "SuperNeo-NuMetal/ProductIntegration/LocalProductControls.swift",
    "numiSealProof": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealProof.swift",
    "numiSealZKProof": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealZKProof.swift",
    "numiSealTypes": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealTypes.swift",
    "numiSealArtifactVerifier": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealArtifactVerifier.swift",
}

EXPECTED_PROOF_KINDS = [
    ("fold", 1),
    ("terminal", 2),
    ("compressed-terminal", 3),
    ("numiseal-terminal", 4),
    ("numiseal-zk-product", 5),
]


def fail(message: str) -> None:
    print(f"product QROM H_bind collision/malleability validation failed: {message}", file=sys.stderr)
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
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_true(value: Any, label: str) -> None:
    require(value is True, f"{label} must be true")


def require_false(value: Any, label: str) -> None:
    require(value is False, f"{label} must be false")


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_related_manifests(evidence: dict[str, Any]) -> None:
    related = require_dict(evidence.get("relatedManifests"), "relatedManifests")
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the collision/malleability evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, nested_key in [
        ("productCryptoSecurityDossier", "productQROMCollisionMalleabilityEvidence"),
        ("selectedDepthLossAccounting", "productQROMCollisionMalleabilityEvidence"),
        ("productQROMFiatShamirAccounting", "productQROMCollisionMalleabilityEvidence"),
        ("productQROMTranscriptSchedule", "productQROMCollisionMalleabilityEvidence"),
        ("productQROMTransformPreconditions", "productQROMCollisionMalleabilityEvidence"),
        ("productQROMInteractiveReduction", "productQROMCollisionMalleabilityEvidence"),
        ("productQROMSamplerEncodingEvidence", "productQROMCollisionMalleabilityEvidence"),
        ("productTotalLossBudget", "productQROMCollisionMalleabilityEvidence"),
    ]:
        manifest = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        manifest_related = require_dict(manifest.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            manifest_related.get(nested_key) == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            f"{manifest_key} must link product-qrom-collision-malleability-evidence-v1.json",
        )


def validate_formal_surface(evidence: dict[str, Any]) -> None:
    formal = require_dict(evidence.get("formalSurface"), "formalSurface")
    modules = [
        require_relative_path(formal.get("serializationModule"), "formalSurface.serializationModule"),
        require_relative_path(formal.get("transcriptModule"), "formalSurface.transcriptModule"),
        require_relative_path(formal.get("productSecurityModule"), "formalSurface.productSecurityModule"),
    ]
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(EXPECTED_FORMAL_DECLARATIONS.issubset(declarations), "formalSurface.declarations missing required theorem surfaces")
    source = "\n".join(path.read_text(encoding="utf-8") for path in modules)
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal source missing {declaration}")


def validate_source_surfaces(evidence: dict[str, Any]) -> None:
    surfaces = require_dict(evidence.get("sourceSurfaces"), "sourceSurfaces")
    require(surfaces == EXPECTED_SOURCE_SURFACES, "sourceSurfaces mismatch")
    for key, relative in EXPECTED_SOURCE_SURFACES.items():
        require_relative_path(relative, f"sourceSurfaces.{key}")


def validate_accepted_proof_kinds(evidence: dict[str, Any]) -> None:
    rows = evidence.get("acceptedProofKinds")
    require(isinstance(rows, list) and len(rows) == len(EXPECTED_PROOF_KINDS), "acceptedProofKinds length mismatch")
    seen: list[tuple[str, int]] = []
    joined_rows = []
    for index, item in enumerate(rows):
        row = require_dict(item, f"acceptedProofKinds[{index}]")
        proof_kind = require_string(row.get("proofKind"), f"acceptedProofKinds[{index}].proofKind")
        envelope_kind = row.get("envelopeKind")
        require(isinstance(envelope_kind, int), f"{proof_kind}.envelopeKind must be an integer")
        seen.append((proof_kind, envelope_kind))
        bindings = require_string_list(row.get("hbindTargetBinding"), f"{proof_kind}.hbindTargetBinding")
        require(len(bindings) >= 5, f"{proof_kind}.hbindTargetBinding must include public context")
        residual = require_string(row.get("residualMalleabilityEvent"), f"{proof_kind}.residualMalleabilityEvent")
        require("binding target failure" in residual, f"{proof_kind}.residualMalleabilityEvent must use binding-target terminology")
        joined_rows.append(json.dumps(row, sort_keys=True).lower())
    require(seen == EXPECTED_PROOF_KINDS, "acceptedProofKinds must stay in proof-kind order")
    joined = " ".join(joined_rows)
    for needle in ["randomness session", "declared leakage", "component digest root", "typed-carry", "proofenvelopekind.numisealzk"]:
        require(needle in joined, f"accepted proof-kind bindings must mention {needle}")


def validate_structural_binding(evidence: dict[str, Any]) -> None:
    binding = require_dict(evidence.get("structuralBinding"), "structuralBinding")
    for key in [
        "proofEnvelopeKindRawValuesUnique",
        "proofEnvelopeTranscriptBindingInjective",
        "proofEnvelopeTranscriptDomainBound",
        "proofKindAcceptancePolicyEnforced",
        "artifactBodyDigestBindingRequired",
        "productProvenanceBindsArtifactAndEnvelopeDigests",
        "productReplayIdentityBindsContextStatementEnvelopeArtifactProvenanceAndCarry",
        "numiSealComponentDigestRootBound",
        "recursiveCarryReplayBindingPresent",
        "witnessIndependentOracleLabelsPinned",
        "hbindVersionedFramingRequired",
        "compressedTerminalCanonicalDecompressionBeforeBinding",
    ]:
        require_true(binding.get(key), f"structuralBinding.{key}")


def validate_residual_events(evidence: dict[str, Any]) -> None:
    residual = require_dict(evidence.get("residualEvents"), "residualEvents")
    require(residual.get("proofKindMalleabilityLossSymbol") == "epsilon_proof_kind_malleability", "proofKindMalleabilityLossSymbol mismatch")
    require(residual.get("transcriptCollisionLossSymbol") == "epsilon_bind", "transcriptCollisionLossSymbol mismatch")
    require(residual.get("selectedDepthCollisionLedgerSymbol") == "epsilon_collision", "selectedDepthCollisionLedgerSymbol mismatch")
    require_true(residual.get("epsilonTranscriptCollisionExportedOutsideEpsilonQROM"), "epsilonTranscriptCollisionExportedOutsideEpsilonQROM")
    require_false(residual.get("epsilonProofKindMalleabilityInsideEpsilonQROM"), "epsilonProofKindMalleabilityInsideEpsilonQROM")
    require(residual.get("proofKindMalleabilityFormula") == "0", "proofKindMalleabilityFormula mismatch")
    require_true(residual.get("proofKindMalleabilityChargedToCollisionLedger"), "proofKindMalleabilityChargedToCollisionLedger")
    require_true(residual.get("digestCollisionBoundRequired"), "digestCollisionBoundRequired")
    require_false(residual.get("concreteHashQROInstantiationRequired"), "concreteHashQROInstantiationRequired")
    require_true(residual.get("hashQROInstantiationAssumptionPinned"), "hashQROInstantiationAssumptionPinned")
    require_false(residual.get("hashQROInstantiationProofProvided"), "hashQROInstantiationProofProvided")


def validate_binding_bound(evidence: dict[str, Any]) -> None:
    bound = require_dict(evidence.get("bindingTargetBound"), "bindingTargetBound")
    require(bound.get("queryBoundQH") == "2^64", "queryBoundQH mismatch")
    require(bound.get("queryBoundLog2") == 64, "queryBoundLog2 mismatch")
    require(bound.get("bindingDigestBits") == 384, "bindingDigestBits must be 384")
    require(bound.get("bindingTargetEventCount") == 9, "bindingTargetEventCount must be 9")
    require(bound.get("formula") == "4 * bindingTargetEventCount * Q_H^2 / 2^bindingDigestBits", "formula mismatch")
    require("36 * 2^-256" in require_string(bound.get("instantiatedExpression"), "instantiatedExpression"), "instantiated bound mismatch")
    require_true(bound.get("withinSelectedCollisionBudget"), "withinSelectedCollisionBudget")


def validate_closure_status(evidence: dict[str, Any]) -> None:
    closure = require_dict(evidence.get("closureStatus"), "closureStatus")
    for key in [
        "structuralCollisionMalleabilityExcludedOutsideDigestCollision",
        "crossProofKindSwapRequiresEnvelopeKindOrTranscriptBindingCollision",
        "crossTranscriptDomainSwapRequiresTranscriptDomainDigestCollision",
        "crossProductSessionSwapRequiresReplayOrProvenanceDigestCollision",
        "crossCarrySwapRequiresCarryReplayBindingCollision",
        "digestCollisionBoundInstantiated",
        "proofKindMalleabilityBoundInstantiated",
        "hashQROInstantiationAssumptionPinned",
        "sourceSHAKE256PrimitiveAvailable",
        "sourceDigest384TypeAvailable",
        "sourceCTCOBinderHelpersAvailable",
    ]:
        require_true(closure.get(key), f"closureStatus.{key}")
    source_paths = [
        ROOT / "SuperNeo-NuMetal" / "SuperNeoHashOracles.swift",
        ROOT / "SuperNeo-NuMetal" / "Protocols" / "NumiSeal" / "NumiSealProductProver.swift",
        ROOT / "SuperNeo-NuMetal" / "ProductIntegration" / "LocalProductControls.swift",
    ]
    source = "\n".join(path.read_text(encoding="utf-8") for path in source_paths)
    for needle in ["Digest384", "hBind", "hBindBindingDigest", "hBindReplayBinder"]:
        require(needle in source, f"source H_bind projection missing {needle}")
    for key in [
        "hashQROInstantiationProofProvided",
        "qromReductionLossWithinBudget",
        "totalLossBudgetIntegrated",
        "sourceHBindImplementationComplete",
        "productionQROMClaimAllowed",
    ]:
        require_false(closure.get(key), f"closureStatus.{key}")


def validate_evidence(path: Path) -> None:
    evidence = read_json(path)
    text = json.dumps(evidence, sort_keys=True).lower()
    require("external" + " audit" not in text, "collision/malleability evidence must not encode outsourced review as a gate")
    require(set(evidence) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(evidence.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(evidence.get("evidenceID") == "superneo-product-qrom-collision-malleability-evidence-v1", "evidenceID mismatch")
    require(evidence.get("claimStatus") == "qrom-collision-malleability-hbind-bound-not-production-qrom-theorem", "claimStatus mismatch")
    validate_related_manifests(evidence)
    validate_formal_surface(evidence)
    validate_source_surfaces(evidence)
    validate_accepted_proof_kinds(evidence)
    validate_structural_binding(evidence)
    validate_residual_events(evidence)
    validate_binding_bound(evidence)
    validate_closure_status(evidence)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else EVIDENCE
    if not path.is_absolute():
        path = ROOT / path
    validate_evidence(path)
    print("product QROM H_bind collision/malleability validation passed")


if __name__ == "__main__":
    main()
