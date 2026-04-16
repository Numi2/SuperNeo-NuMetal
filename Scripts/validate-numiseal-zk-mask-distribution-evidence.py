#!/usr/bin/env python3
"""Validate the NumiSealZK mask-distribution evidence manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-zk-mask-distribution-evidence-v1.json"
GOLDILOCKS_MODULUS = 0xFFFF_FFFF_0000_0001
CANDIDATE_SPACE_SIZE = 1 << 64
REJECTED_CANDIDATES = CANDIDATE_SPACE_SIZE - GOLDILOCKS_MODULUS
DOMAIN_LABEL = "SuperNeo-NuMetal.numiseal.zk.mask-expand.v2"


def fail(message: str) -> None:
    print(f"NumiSealZK mask-distribution evidence validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), "mask-distribution evidence root must be an object")
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


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def validate_manifest(path: Path) -> None:
    manifest = read_json(path)
    text = json.dumps(manifest, sort_keys=True).lower()
    require("external" + " audit" not in text, "mask-distribution evidence must not encode outsourced review")
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        manifest.get("evidenceID") == "numiseal-zk-mask-distribution-evidence-v1",
        "evidenceID is unsupported",
    )
    require(
        manifest.get("claimStatus") == "exact-rejection-sampled-field-mask-evidence",
        "claimStatus must stay precise",
    )
    require(
        manifest.get("conformanceScopeManifest") == "TestVectors/numiseal-conformance-scope-v1.json",
        "mask evidence must link the NumiSeal conformance scope",
    )
    require(
        manifest.get("theoremScopeManifest") == "TestVectors/numiseal-end-to-end-theorem-scope-v1.json",
        "mask evidence must link the NumiSeal theorem scope",
    )

    source_path = require_relative_path(manifest.get("implementationPath"), "implementationPath")
    source = source_path.read_text(encoding="utf-8")
    for needle in [
        "NumiSealZKMaskSampler",
        DOMAIN_LABEL,
        "candidate < GoldilocksField.modulus",
        "sampleFieldElement",
    ]:
        require(needle in source, f"implementation source missing {needle}")
    require(
        "GoldilocksField(UInt64(littleEndianBytes: Array(digest.bytes.prefix(8))))" not in source,
        "implementation must not reduce raw 64-bit mask candidates modulo the field",
    )

    sampler = manifest.get("sampler")
    require(isinstance(sampler, dict), "sampler must be an object")
    require(sampler.get("samplerType") == "rejection-sampled-sha256-xof-candidates", "unsupported samplerType")
    require(sampler.get("domainLabel") == DOMAIN_LABEL, "sampler domainLabel mismatch")
    require(sampler.get("candidateBitWidth") == 64, "candidateBitWidth must be 64")
    require(int(require_string(sampler.get("candidateSpaceSize"), "candidateSpaceSize")) == CANDIDATE_SPACE_SIZE, "candidateSpaceSize mismatch")
    require(int(require_string(sampler.get("fieldModulusDecimal"), "fieldModulusDecimal")) == GOLDILOCKS_MODULUS, "field modulus decimal mismatch")
    require(require_string(sampler.get("fieldModulusHex"), "fieldModulusHex") == f"{GOLDILOCKS_MODULUS:016x}", "field modulus hex mismatch")
    require(sampler.get("acceptanceCondition") == "candidate < GoldilocksField.modulus", "acceptanceCondition mismatch")
    require(int(require_string(sampler.get("acceptedCandidateCount"), "acceptedCandidateCount")) == GOLDILOCKS_MODULUS, "acceptedCandidateCount mismatch")
    require(int(require_string(sampler.get("rejectedCandidateCount"), "rejectedCandidateCount")) == REJECTED_CANDIDATES, "rejectedCandidateCount mismatch")
    require(sampler.get("rejectionProbabilityUpperBound") == "2^-32", "rejectionProbabilityUpperBound mismatch")
    require(sampler.get("statisticalDistanceFromUniformAcceptedFieldElement") == "0", "statistical distance must be zero after rejection")
    require(sampler.get("exactUniformAfterRejection") is True, "exactUniformAfterRejection must be true")

    leakage = manifest.get("leakageModelBinding")
    require(isinstance(leakage, dict), "leakageModelBinding must be an object")
    public_leakage = set(require_string_list(leakage.get("publicLeakageOnly"), "leakageModelBinding.publicLeakageOnly"))
    require(
        {"randomness session digest", "declared leakage digest", "mask tensor dimensions"}.issubset(public_leakage),
        "leakage binding must include session, leakage digest, and tensor dimensions",
    )
    require(leakage.get("secretMaskMaterialExcludedFromVerifierView") is True, "secret mask material must be excluded")
    require(leakage.get("hardwareSideChannelsExcluded") is True, "hardware side-channel exclusion must be explicit")

    test_source = (ROOT / "SuperNeo-NuMetalTests" / "SuperNeoNuMetalTests.swift").read_text(encoding="utf-8")
    for test_name in require_string_list(manifest.get("coveredByTests"), "coveredByTests"):
        require(test_name in test_source, f"covered test not found: {test_name}")

    promotion = manifest.get("promotionRule")
    require(isinstance(promotion, dict), "promotionRule must be an object")
    require(
        promotion.get("productionZKPrivacyClaimAllowed") is False,
        "mask evidence must not prematurely allow production ZK privacy claims",
    )
    require(promotion.get("releaseEvidenceOnly") is True, "promotionRule.releaseEvidenceOnly must be true")
    boundaries = " ".join(require_string_list(promotion.get("remainingBoundaries"), "promotionRule.remainingBoundaries")).lower()
    require("side-channel" in boundaries, "remaining boundaries must mention side-channel evidence")
    require("simulation/privacy" in boundaries, "remaining boundaries must mention simulation/privacy evidence")


def main() -> None:
    manifest_path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path
    validate_manifest(manifest_path)
    print("NumiSealZK mask-distribution evidence validation passed")


if __name__ == "__main__":
    main()
