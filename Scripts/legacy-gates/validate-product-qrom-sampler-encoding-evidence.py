#!/usr/bin/env python3
"""Validate product QROM sampler-uniformity and transcript-encoding evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "TestVectors" / "product-qrom-sampler-encoding-evidence-v1.json"

GOLDILOCKS_MODULUS = (1 << 64) - (1 << 32) + 1
UINT64_SPACE = 1 << 64
UINT64_MAX = UINT64_SPACE - 1
PHI81_DEGREE = 54

EXPECTED_TOP_LEVEL_KEYS = {
    "schemaVersion",
    "evidenceID",
    "claimStatus",
    "relatedManifests",
    "formalSurface",
    "sourceSurfaces",
    "transcriptEncoding",
    "samplerUniformity",
    "integrationStatus",
}

EXPECTED_MANIFESTS = {
    "productCryptoSecurityDossier": "TestVectors/product-crypto-security-dossier-v1.json",
    "selectedDepthLossAccounting": "TestVectors/product-selected-depth-loss-accounting-v1.json",
    "productQROMTranscriptSchedule": "TestVectors/product-qrom-transcript-schedule-v1.json",
    "productQROMTransformPreconditions": "TestVectors/product-qrom-transform-preconditions-v1.json",
    "productQROMInteractiveReduction": "TestVectors/product-qrom-interactive-reduction-v1.json",
    "productQROMPublicCoinAccounting": "TestVectors/product-qrom-public-coin-accounting-v1.json",
    "productQROMCollisionMalleabilityEvidence": "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
    "productTotalLossBudget": "TestVectors/product-total-loss-budget-v1.json",
}

EXPECTED_FORMAL_DECLARATIONS = {
    "transcriptFrameEncode_injective",
    "transcriptInit_injective",
    "transcriptBytes_absorb",
    "challengeCoefficientSet_card",
    "phi81ChallengeSeed_card",
    "phi81ExpandedChallengeSeed_card",
    "transcriptPhi81ChallengeElement_mem_support",
    "ceOpeningChallengeDomain_card",
    "ceOpeningChallengeFromSymbol_mem_domain",
}

EXPECTED_SOURCE_SURFACES = {
    "transcript": "SuperNeo-NuMetal/Transcript/SumCheckTranscript.swift",
    "terminalCE": "SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift",
    "numiSealLaneAggregation": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealLaneAggregation.swift",
    "numiSealScalarization": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealScalarization.swift",
    "numiSealSumcheck": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealSumcheck.swift",
    "numiSealZK": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealZKProof.swift",
    "wireEncoding": "SuperNeo-NuMetal/Protocols/NumiSeal/NumiSealTypes.swift",
}

EXPECTED_DOMAIN_SEPARATORS = [
    "SuperNeo-NuMetal.fold",
    "SuperNeo-NuMetal.ce-opening.stern",
    "SuperNeo-NuMetal.numiseal.rlc.v1",
    "SuperNeo-NuMetal.numiseal.scalarization.v1",
    "SuperNeo-NuMetal.numiseal.sumcheck.v1",
    "SuperNeo-NuMetal.numiseal.sumcheck-weights.v1",
    "SuperNeo-NuMetal.numiseal.zk.masked-residual-statement.v2",
    "SuperNeo-NuMetal.numiseal.zk.masked-residual-accumulation.v1",
]
EXPECTED_REPEATED_TAPE_LABELS = [
    "selected-repeated-tape-v1/piccs-tape-0",
    "selected-repeated-tape-v1/piccs-tape-1",
    "selected-repeated-tape-v1/pirlc-branch-0",
    "selected-repeated-tape-v1/pirlc-branch-1",
    "selected-repeated-tape-v1/pirlc-branch-2",
]


def fail(message: str) -> None:
    print(f"product QROM sampler/encoding evidence validation failed: {message}", file=sys.stderr)
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


def require_int(value: Any, label: str) -> int:
    require(type(value) is int, f"{label} must be an integer")
    return value


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
    require(related == EXPECTED_MANIFESTS, "relatedManifests must pin the sampler/encoding evidence set exactly")
    for key, relative in EXPECTED_MANIFESTS.items():
        require_relative_path(relative, f"relatedManifests.{key}")

    for manifest_key, expected_key in [
        ("productCryptoSecurityDossier", "productQROMSamplerEncodingEvidence"),
        ("selectedDepthLossAccounting", "productQROMSamplerEncodingEvidence"),
        ("productQROMTranscriptSchedule", "productQROMSamplerEncodingEvidence"),
        ("productQROMTransformPreconditions", "productQROMSamplerEncodingEvidence"),
        ("productQROMInteractiveReduction", "productQROMSamplerEncodingEvidence"),
        ("productQROMPublicCoinAccounting", "productQROMSamplerEncodingEvidence"),
        ("productTotalLossBudget", "productQROMSamplerEncodingEvidence"),
    ]:
        manifest = read_json(ROOT / EXPECTED_MANIFESTS[manifest_key])
        manifest_related = require_dict(manifest.get("relatedManifests"), f"{manifest_key}.relatedManifests")
        require(
            manifest_related.get(expected_key) == "TestVectors/product-qrom-sampler-encoding-evidence-v1.json",
            f"{manifest_key} must link product-qrom-sampler-encoding-evidence-v1.json",
        )
        require(
            manifest_related.get("productQROMCollisionMalleabilityEvidence") == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
            f"{manifest_key} must link product-qrom-collision-malleability-evidence-v1.json",
        )


def validate_formal_surface(evidence: dict[str, Any]) -> None:
    formal = require_dict(evidence.get("formalSurface"), "formalSurface")
    modules = [
        require_relative_path(formal.get("transcriptModule"), "formalSurface.transcriptModule"),
        require_relative_path(formal.get("challengeSamplingModule"), "formalSurface.challengeSamplingModule"),
        require_relative_path(formal.get("transcriptChallengeModule"), "formalSurface.transcriptChallengeModule"),
        require_relative_path(formal.get("terminalCEModule"), "formalSurface.terminalCEModule"),
    ]
    declarations = set(require_string_list(formal.get("declarations"), "formalSurface.declarations"))
    require(declarations == EXPECTED_FORMAL_DECLARATIONS, "formalSurface.declarations mismatch")
    source = "\n".join(path.read_text(encoding="utf-8") for path in modules)
    for declaration in EXPECTED_FORMAL_DECLARATIONS:
        require(declaration in source, f"formal theorem source missing {declaration}")


def validate_source_surfaces(evidence: dict[str, Any]) -> None:
    surfaces = require_dict(evidence.get("sourceSurfaces"), "sourceSurfaces")
    require(surfaces == EXPECTED_SOURCE_SURFACES, "sourceSurfaces mismatch")
    source_by_key = {
        key: require_relative_path(relative, f"sourceSurfaces.{key}").read_text(encoding="utf-8")
        for key, relative in EXPECTED_SOURCE_SURFACES.items()
    }
    transcript_source = source_by_key["transcript"]
    for needle in [
        "public mutating func nextField()",
        "while value >= GoldilocksField.modulus",
        "public mutating func nextExt2()",
        "private mutating func nextUniformIndex(upperBound: Int)",
        "let limit = UInt64.max - (UInt64.max % bound)",
    ]:
        require(needle in transcript_source, f"transcript source missing {needle}")
    hash_oracle_source = (ROOT / "SuperNeo-NuMetal/SuperNeoHashOracles.swift").read_text(encoding="utf-8")
    for needle in [
        "public static func framedBytes(domain: String, frames: [[UInt8]])",
        "appendFrame(Array(domain.utf8), to: &bytes)",
        "public static func appendFrame(_ frame: [UInt8], to bytes: inout [UInt8])",
        "bytes.append(contentsOf: encodeUInt64(UInt64(frame.count)))",
    ]:
        require(needle in hash_oracle_source, f"split-QRO framing source missing {needle}")
    terminal_source = source_by_key["terminalCE"]
    for needle in [
        "private func ceOpeningChallenge(transcript: inout SumCheckTranscript) -> Int",
        "let bound = GoldilocksField.modulus - (GoldilocksField.modulus % 3)",
        "return Int(raw % 3)",
        "SuperNeo-NuMetal.ce-opening.stern",
    ]:
        require(needle in terminal_source, f"terminal CE source missing {needle}")
    for separator in EXPECTED_DOMAIN_SEPARATORS:
        require(
            any(separator in source for source in source_by_key.values()),
            f"source surfaces missing domain separator {separator}",
        )


def validate_transcript_encoding(evidence: dict[str, Any]) -> None:
    encoding = require_dict(evidence.get("transcriptEncoding"), "transcriptEncoding")
    require("64-bit little-endian" in require_string(encoding.get("frameEncoding"), "transcriptEncoding.frameEncoding"), "frame encoding must be 64-bit LE")
    require(require_int(encoding.get("frameLengthBytes"), "transcriptEncoding.frameLengthBytes") == 8, "frameLengthBytes mismatch")
    for key in [
        "appendOnlyState",
        "structuredFrameInjective",
        "leanInjectivityProofsPinned",
        "byteReaderRejectsTrailingBytes",
        "witnessIndependentDomainLabels",
        "randomOracleInputEncodingInjectiveForStructuredFrames",
    ]:
        require_true(encoding.get(key), f"transcriptEncoding.{key}")
    require_false(encoding.get("explicitPerChallengeLabelsAbsorbedByImplementation"), "transcriptEncoding.explicitPerChallengeLabelsAbsorbedByImplementation")
    require_true(encoding.get("repeatedTapeLabelsAbsorbedByImplementation"), "transcriptEncoding.repeatedTapeLabelsAbsorbedByImplementation")
    require_true(encoding.get("seedBitSlicingRejected"), "transcriptEncoding.seedBitSlicingRejected")
    require(encoding.get("repeatedTapeLabelVersion") == "selected-repeated-tape-v1", "transcriptEncoding.repeatedTapeLabelVersion mismatch")
    require(
        require_string_list(encoding.get("repeatedTapeLabels"), "transcriptEncoding.repeatedTapeLabels")
        == EXPECTED_REPEATED_TAPE_LABELS,
        "transcriptEncoding.repeatedTapeLabels mismatch",
    )
    protocol_source = (ROOT / "SuperNeo-NuMetal/Protocols/SuperNeoProtocols.swift").read_text(encoding="utf-8")
    for needle in ["selected-repeated-tape-v1", "repeatedTapeSeed(", "makeFoldTranscript("]:
        require(needle in protocol_source, f"repeated tape source missing {needle}")
    require_true(encoding.get("productionEncodingClaimAllowed"), "transcriptEncoding.productionEncodingClaimAllowed")
    mode = require_string(encoding.get("challengeLabelMode"), "transcriptEncoding.challengeLabelMode")
    require("domain separator" in mode and "append-only challenge position" in mode, "challengeLabelMode must describe current implementation")
    separators = require_string_list(encoding.get("domainSeparatorExamples"), "transcriptEncoding.domainSeparatorExamples")
    require(separators == EXPECTED_DOMAIN_SEPARATORS, "domainSeparatorExamples mismatch")


def validate_sampler_uniformity(evidence: dict[str, Any]) -> None:
    sampler = require_dict(evidence.get("samplerUniformity"), "samplerUniformity")
    require("quantum random-oracle" in require_string(sampler.get("randomOracleModel"), "samplerUniformity.randomOracleModel"), "randomOracleModel must state the QRO abstraction")

    field = require_dict(sampler.get("goldilocksFieldSampler"), "goldilocksFieldSampler")
    require(require_int(field.get("sourceBits"), "goldilocksFieldSampler.sourceBits") == 64, "field sourceBits mismatch")
    require(field.get("sourceValues") == "2^64", "field sourceValues mismatch")
    require(require_int(field.get("modulus"), "goldilocksFieldSampler.modulus") == GOLDILOCKS_MODULUS, "Goldilocks modulus mismatch")
    require(require_int(field.get("acceptedValues"), "goldilocksFieldSampler.acceptedValues") == GOLDILOCKS_MODULUS, "field acceptedValues mismatch")
    require(require_int(field.get("rejectedValues"), "goldilocksFieldSampler.rejectedValues") == UINT64_SPACE - GOLDILOCKS_MODULUS, "field rejectedValues mismatch")
    require(field.get("rejectionProbabilityUpperBound") == "2^-32", "field rejection probability bound mismatch")
    require(field.get("conditionalDistribution") == "exactly uniform on GoldilocksField", "field conditional distribution mismatch")

    ext2 = require_dict(sampler.get("goldilocksExt2Sampler"), "goldilocksExt2Sampler")
    require(require_int(ext2.get("coordinateSamplers"), "goldilocksExt2Sampler.coordinateSamplers") == 2, "Ext2 coordinate count mismatch")
    require(require_int(ext2.get("sourceBitsPerCoordinate"), "goldilocksExt2Sampler.sourceBitsPerCoordinate") == 64, "Ext2 source bits mismatch")
    require("product" in require_string(ext2.get("conditionalDistribution"), "goldilocksExt2Sampler.conditionalDistribution"), "Ext2 must be product-uniform")

    coeff = require_dict(sampler.get("phi81CoefficientSampler"), "phi81CoefficientSampler")
    require(coeff.get("choiceSet") == [-2, -1, 0, 1, 2], "Phi81 coefficient choiceSet mismatch")
    require(require_int(coeff.get("choiceCount"), "phi81CoefficientSampler.choiceCount") == 5, "Phi81 choiceCount mismatch")
    require(require_int(coeff.get("sourceBits"), "phi81CoefficientSampler.sourceBits") == 64, "Phi81 coefficient sourceBits mismatch")
    expected_limit = UINT64_MAX - (UINT64_MAX % 5)
    require(require_int(coeff.get("limit"), "phi81CoefficientSampler.limit") == expected_limit, "Phi81 coefficient rejection limit mismatch")
    require(require_int(coeff.get("acceptedValues"), "phi81CoefficientSampler.acceptedValues") == expected_limit, "Phi81 acceptedValues mismatch")
    require(require_int(coeff.get("rejectedValues"), "phi81CoefficientSampler.rejectedValues") == UINT64_SPACE - expected_limit, "Phi81 rejectedValues mismatch")
    require(expected_limit % 5 == 0, "Phi81 accepted range must divide by choice count")
    require_true(coeff.get("acceptedValuesDivisibleByChoiceCount"), "phi81CoefficientSampler.acceptedValuesDivisibleByChoiceCount")
    require("exactly uniform" in require_string(coeff.get("conditionalDistribution"), "phi81CoefficientSampler.conditionalDistribution"), "Phi81 coefficient distribution must be exact")

    ring = require_dict(sampler.get("phi81RingSampler"), "phi81RingSampler")
    require(require_int(ring.get("degree"), "phi81RingSampler.degree") == PHI81_DEGREE, "Phi81 degree mismatch")
    require(ring.get("supportSizeExpression") == "5^54", "Phi81 support size mismatch")
    require("54 independent" in require_string(ring.get("conditionalDistribution"), "phi81RingSampler.conditionalDistribution"), "Phi81 ring distribution must be coordinate product")

    ce = require_dict(sampler.get("terminalCETernarySampler"), "terminalCETernarySampler")
    ce_domain = require_int(ce.get("challengeDomainSize"), "terminalCETernarySampler.challengeDomainSize")
    require(ce_domain == 3, "CE challengeDomainSize mismatch")
    require(require_int(ce.get("fieldModulusRemainderModuloDomain"), "terminalCETernarySampler.fieldModulusRemainderModuloDomain") == GOLDILOCKS_MODULUS % ce_domain, "CE modulus remainder mismatch")
    ce_accepted = GOLDILOCKS_MODULUS - (GOLDILOCKS_MODULUS % ce_domain)
    require(require_int(ce.get("acceptedFieldValues"), "terminalCETernarySampler.acceptedFieldValues") == ce_accepted, "CE acceptedFieldValues mismatch")
    require(require_int(ce.get("rejectedFieldValues"), "terminalCETernarySampler.rejectedFieldValues") == GOLDILOCKS_MODULUS - ce_accepted, "CE rejectedFieldValues mismatch")
    require(ce_accepted % ce_domain == 0, "CE accepted field range must divide by challenge domain")
    require_true(ce.get("acceptedValuesDivisibleByChallengeDomain"), "terminalCETernarySampler.acceptedValuesDivisibleByChallengeDomain")
    require("exactly uniform" in require_string(ce.get("conditionalDistribution"), "terminalCETernarySampler.conditionalDistribution"), "CE distribution must be exact")

    zk = require_dict(sampler.get("numiSealZKMaskedResidualSampler"), "numiSealZKMaskedResidualSampler")
    require(require_int(zk.get("fieldChallengesPerLaneProof"), "numiSealZKMaskedResidualSampler.fieldChallengesPerLaneProof") == 3, "ZK challenge count mismatch")
    require(zk.get("source") == "GoldilocksField sampler", "ZK source mismatch")
    require("product" in require_string(zk.get("conditionalDistribution"), "numiSealZKMaskedResidualSampler.conditionalDistribution"), "ZK distribution must be product-uniform")
    repeated = require_dict(sampler.get("ctcoRepeatedTapeExpansion"), "ctcoRepeatedTapeExpansion")
    require(require_int(repeated.get("externalChallengeSeedBits"), "ctcoRepeatedTapeExpansion.externalChallengeSeedBits") == 256, "repeated tape external seed bits mismatch")
    require(require_int(repeated.get("piccsTapeCount"), "ctcoRepeatedTapeExpansion.piccsTapeCount") == 2, "repeated tape PiCCS count mismatch")
    require(require_int(repeated.get("pirlcBranchCount"), "ctcoRepeatedTapeExpansion.pirlcBranchCount") == 3, "repeated tape PiRLC count mismatch")
    expansion = require_string(repeated.get("expansionRule"), "ctcoRepeatedTapeExpansion.expansionRule")
    require("H_chal" in expansion and "label" in expansion and "not seed-bit slicing" in expansion, "repeated tape expansion rule mismatch")
    require_true(sampler.get("samplerUniformityProofPinned"), "samplerUniformity.samplerUniformityProofPinned")


def validate_integration(evidence: dict[str, Any]) -> None:
    integration = require_dict(evidence.get("integrationStatus"), "integrationStatus")
    for key in [
        "challengeSpaceUniformitySatisfiedUnderQROAbstraction",
        "transcriptOracleEncodingInjectiveForStructuredFrames",
        "witnessIndependentOracleLabelsPinned",
        "structuralCollisionMalleabilityExcludedOutsideDigestCollision",
    ]:
        require_true(integration.get(key), f"integrationStatus.{key}")
    require(
        integration.get("structuralCollisionMalleabilityEvidenceManifest")
        == "TestVectors/product-qrom-collision-malleability-evidence-v1.json",
        "integrationStatus.structuralCollisionMalleabilityEvidenceManifest mismatch",
    )
    require_relative_path(
        integration.get("structuralCollisionMalleabilityEvidenceManifest"),
        "integrationStatus.structuralCollisionMalleabilityEvidenceManifest",
    )
    require_true(integration.get("idealSplitQROTheoremInstantiated"), "integrationStatus.idealSplitQROTheoremInstantiated")
    require_false(integration.get("hashInstantiationProofProvided"), "integrationStatus.hashInstantiationProofProvided")
    for key in [
        "collisionMalleabilityExcluded",
        "qromReductionLossWithinBudget",
        "repositoryLocalIdealQROMClaimAllowed",
    ]:
        require_true(integration.get(key), f"integrationStatus.{key}")
    require_false(integration.get("productionQROMClaimAllowed"), "integrationStatus.productionQROMClaimAllowed")

def validate_evidence(path: Path) -> None:
    evidence = read_json(path)
    text = json.dumps(evidence, sort_keys=True).lower()
    require("external" + " audit" not in text, "sampler/encoding evidence must not encode outsourced review as a gate")
    require(set(evidence) == EXPECTED_TOP_LEVEL_KEYS, "top-level keys mismatch")
    require(evidence.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(evidence.get("evidenceID") == "superneo-product-qrom-sampler-encoding-evidence-v1", "evidenceID mismatch")
    require(
        evidence.get("claimStatus") == "qrom-sampler-encoding-evidence-repository-local-production-qrom-theorem",
        "claimStatus mismatch",
    )
    validate_related_manifests(evidence)
    validate_formal_surface(evidence)
    validate_source_surfaces(evidence)
    validate_transcript_encoding(evidence)
    validate_sampler_uniformity(evidence)
    validate_integration(evidence)


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else EVIDENCE
    if not path.is_absolute():
        path = ROOT / path
    validate_evidence(path)
    print("product QROM sampler/encoding evidence validation passed")


if __name__ == "__main__":
    main()
