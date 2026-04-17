#!/usr/bin/env python3
"""Validate structural product QROM collision/malleability evidence."""

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
    "proofEnvelopeTranscriptBindingEncode_kind_slice",
    "proofEnvelopeTranscriptBindingEncode_shape_slice",
    "proofEnvelopeTranscriptBindingEncode_statement_slice",
    "proofEnvelopeTranscriptBindingEncode_verifierKey_slice",
    "proofEnvelopeTranscriptBindingEncode_transcriptDomain_slice",
    "proofEnvelopeTranscriptBindingEncode_injective",
    "proofEnvelopeTranscriptInit_context_injective",
    "proofEnvelopeLengthCountedTranscriptInit?_first_payload_decodes",
    "domainSeparatorTag_ne_proofEnvelopeHeaderTag",
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

EXPECTED_TRUE_STRUCTURAL_FLAGS = {
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
}

EXPECTED_TRUE_CLOSURE_FLAGS = {
    "structuralCollisionMalleabilityExcludedOutsideDigestCollision",
    "crossProofKindSwapRequiresEnvelopeKindOrTranscriptBindingCollision",
    "crossTranscriptDomainSwapRequiresTranscriptDomainDigestCollision",
    "crossProductSessionSwapRequiresReplayOrProvenanceDigestCollision",
    "crossCarrySwapRequiresCarryReplayBindingCollision",
}

EXPECTED_FALSE_CLOSURE_FLAGS = {
    "digestCollisionBoundInstantiated",
    "hashQROInstantiationProofProvided",
    "qromReductionLossWithinBudget",
    "totalLossBudgetIntegrated",
    "productionQROMClaimAllowed",
}


def fail(message: str) -> None:
    print(f"product QROM collision/malleability evidence validation failed: {message}", file=sys.stderr)
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
    require(value is False, f"{label} must remain false until the cryptographic QROM theorem is instantiated")


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
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = "\n".join(path.read_text(encoding="utf-8") for path in modules)
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal source missing {declaration}")
    for constructor in ["numiSealTerminal", "numiSealZK"]:
        require(constructor in source, f"formal proof-envelope kind model missing {constructor}")


def validate_source_surfaces(evidence: dict[str, Any]) -> None:
    surfaces = require_dict(evidence.get("sourceSurfaces"), "sourceSurfaces")
    require(surfaces == EXPECTED_SOURCE_SURFACES, "sourceSurfaces mismatch")
    source_by_key = {
        key: require_relative_path(relative, f"sourceSurfaces.{key}").read_text(encoding="utf-8")
        for key, relative in EXPECTED_SOURCE_SURFACES.items()
    }
    proof_envelope = source_by_key["proofEnvelope"]
    for needle in [
        "case foldReduction = 1",
        "case terminalLocal = 2",
        "case compressedPublic = 3",
        "case numiSealTerminal = 4",
        "case numiSealZK = 5",
        "public var transcriptBindingBytes",
        "guard header.transcriptDomain == transcriptDomain else",
        "guard proofKindPolicy.accepts(header.kind) else",
        "Digest256.hash(\"SuperNeo-NuMetal.compressed-public.proof.v2\")",
    ]:
        require(needle in proof_envelope, f"proof envelope source missing {needle}")

    transcript = source_by_key["sumcheckTranscript"]
    for needle in [
        "absorbed.append(contentsOf: Self.frameLength(bytes.count))",
        "absorbed.append(contentsOf: bytes)",
    ]:
        require(needle in transcript, f"transcript source missing {needle}")

    local_controls = source_by_key["localProductControls"]
    for needle in [
        "UNIQUE(expected_context_id, statement_digest, proof_envelope_digest, artifact_digest, provenance_digest, recursive_carry_replay_binding_digest)",
        "recursive_carry_replay_binding_digest",
        "artifact digest does not match provenance",
        "proof envelope digest does not match provenance",
    ]:
        require(needle in local_controls, f"local product controls source missing {needle}")

    numiseal_proof = source_by_key["numiSealProof"]
    for needle in [
        "numiseal.component-digest-root.v1",
        "NumiSeal component digest root mismatch",
        "Digest256.hash(\"SuperNeo-NuMetal.numiseal.v1\")",
        "guard header.transcriptDomain == transcriptDomain else",
    ]:
        require(needle in numiseal_proof, f"NumiSeal proof source missing {needle}")

    zk_source = source_by_key["numiSealZKProof"]
    for needle in [
        "NumiSealZK component digest root mismatch",
        "randomnessSessionDigest",
        "leakageDigest",
    ]:
        require(needle in zk_source, f"NumiSealZK source missing {needle}")

    types_source = source_by_key["numiSealTypes"]
    require(
        "Digest256.hash(\"SuperNeo-NuMetal.numiseal.v1\")" in types_source,
        "NumiSeal types must pin the NumiSeal transcript domain",
    )

    artifact_verifier = source_by_key["numiSealArtifactVerifier"]
    for needle in [
        "envelope.header.transcriptDomain.hexString == artifact.transcriptDomainHex",
        "NumiSeal proof component digest root mismatch",
    ]:
        require(needle in artifact_verifier, f"NumiSeal artifact verifier source missing {needle}")


def validate_accepted_proof_kinds(evidence: dict[str, Any]) -> None:
    rows = evidence.get("acceptedProofKinds")
    require(isinstance(rows, list), "acceptedProofKinds must be a list")
    require(len(rows) == len(EXPECTED_PROOF_KINDS), "acceptedProofKinds length mismatch")
    seen: list[tuple[str, int]] = []
    combined = []
    for index, item in enumerate(rows):
        row = require_dict(item, f"acceptedProofKinds[{index}]")
        proof_kind = require_string(row.get("proofKind"), f"acceptedProofKinds[{index}].proofKind")
        envelope_kind = row.get("envelopeKind")
        require(isinstance(envelope_kind, int), f"{proof_kind}.envelopeKind must be an integer")
        seen.append((proof_kind, envelope_kind))
        bindings = require_string_list(row.get("publicTranscriptBinding"), f"{proof_kind}.publicTranscriptBinding")
        require(len(bindings) >= 4, f"{proof_kind}.publicTranscriptBinding must include public context digests")
        residual = require_string(row.get("residualMalleabilityEvent"), f"{proof_kind}.residualMalleabilityEvent")
        require("collision" in residual, f"{proof_kind}.residualMalleabilityEvent must state the residual collision event")
        combined.append(json.dumps(row, sort_keys=True).lower())
    require(seen == EXPECTED_PROOF_KINDS, "acceptedProofKinds must stay in the pinned proof-kind order")
    envelope_kinds = [kind for _, kind in seen]
    require(envelope_kinds == sorted(set(envelope_kinds)), "envelope kinds must be unique and ordered")
    joined = " ".join(combined)
    for needle in [
        "proofenvelopekind.foldreduction",
        "proofenvelopekind.terminallocal",
        "proofenvelopekind.compressedpublic",
        "proofenvelopekind.numisealterminal",
        "proofenvelopekind.numisealzk",
        "randomness session digest",
        "declared leakage digest",
        "component digest root",
    ]:
        require(needle in joined, f"accepted proof-kind bindings must mention {needle}")


def validate_structural_binding(evidence: dict[str, Any]) -> None:
    binding = require_dict(evidence.get("structuralBinding"), "structuralBinding")
    require(set(binding) == EXPECTED_TRUE_STRUCTURAL_FLAGS, "structuralBinding keys mismatch")
    for key in EXPECTED_TRUE_STRUCTURAL_FLAGS:
        require_true(binding.get(key), f"structuralBinding.{key}")


def validate_residual_events(evidence: dict[str, Any]) -> None:
    residual = require_dict(evidence.get("residualEvents"), "residualEvents")
    require(residual.get("proofKindMalleabilityLossSymbol") == "epsilon_proof_kind_malleability", "proofKindMalleabilityLossSymbol mismatch")
    require(residual.get("transcriptCollisionLossSymbol") == "epsilon_transcript_collision", "transcriptCollisionLossSymbol mismatch")
    require(residual.get("selectedDepthCollisionLedgerSymbol") == "epsilon_collision", "selectedDepthCollisionLedgerSymbol mismatch")
    for key in [
        "epsilonTranscriptCollisionExportedOutsideEpsilonQROM",
        "epsilonProofKindMalleabilityInsideEpsilonQROM",
        "digestCollisionBoundRequired",
        "concreteHashQROInstantiationRequired",
    ]:
        require_true(residual.get(key), f"residualEvents.{key}")


def validate_closure_status(evidence: dict[str, Any]) -> None:
    closure = require_dict(evidence.get("closureStatus"), "closureStatus")
    require(set(closure) == EXPECTED_TRUE_CLOSURE_FLAGS | EXPECTED_FALSE_CLOSURE_FLAGS, "closureStatus keys mismatch")
    for key in EXPECTED_TRUE_CLOSURE_FLAGS:
        require_true(closure.get(key), f"closureStatus.{key}")
    for key in EXPECTED_FALSE_CLOSURE_FLAGS:
        require_false(closure.get(key), f"closureStatus.{key}")


def validate_docs_and_gate() -> None:
    docs = {
        "README.md": [
            "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            "QROM collision/malleability structural evidence",
        ],
        "Docs/CryptographicSecurityDossier-2026-04-16.md": [
            "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            "QROM Collision/Malleability Structural Evidence",
        ],
        "Docs/ProductionReadinessAuditPacket-2026-04-16.md": [
            "Scripts/validate-product-qrom-collision-malleability-evidence.py",
        ],
        "Docs/ReleaseEngineering-2026-04-16.md": [
            "product QROM collision/malleability structural evidence",
        ],
        "Docs/ReleaseCandidateRunbook-2026-04-16.md": [
            "product QROM collision/malleability evidence version and digest",
        ],
        "Docs/SchemaCompatibility-2026-04-16.md": [
            "Product QROM collision/malleability evidence manifest",
        ],
        "TestVectors/README.md": [
            "product-qrom-collision-malleability-evidence-v1.json",
        ],
    }
    for relative, needles in docs.items():
        text = (ROOT / relative).read_text(encoding="utf-8")
        for needle in needles:
            require(needle in text, f"{relative} missing {needle}")
    gate = (ROOT / "Scripts" / "production-gate.sh").read_text(encoding="utf-8")
    require(
        "run_step Scripts/validate-product-qrom-collision-malleability-evidence.py" in gate,
        "production gate must run QROM collision/malleability evidence validator",
    )
    require(
        "run_step Scripts/test-product-qrom-collision-malleability-evidence-validation.py" in gate,
        "production gate must run QROM collision/malleability regression tests",
    )


def validate_evidence(path: Path) -> None:
    evidence = read_json(path)
    text = json.dumps(evidence, sort_keys=True).lower()
    require("external" + " audit" not in text, "collision/malleability evidence must not encode outsourced review as a gate")
    require(set(evidence) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(evidence.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(evidence.get("evidenceID") == "superneo-product-qrom-collision-malleability-evidence-v1", "evidenceID mismatch")
    require(
        evidence.get("claimStatus") == "qrom-collision-malleability-structural-evidence-not-production-qrom-theorem",
        "claimStatus mismatch",
    )
    validate_related_manifests(evidence)
    validate_formal_surface(evidence)
    validate_source_surfaces(evidence)
    validate_accepted_proof_kinds(evidence)
    validate_structural_binding(evidence)
    validate_residual_events(evidence)
    validate_closure_status(evidence)
    validate_docs_and_gate()


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else EVIDENCE
    if not path.is_absolute():
        path = ROOT / path
    validate_evidence(path)
    print("product QROM collision/malleability evidence validation passed")


if __name__ == "__main__":
    main()
