#!/usr/bin/env python3
"""Validate the pinned Swift trace/extractor evidence manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-swift-trace-extractor-evidence-v1.json"

REQUIRED_TRACE_BLOCKS = [
    "frontend-context",
    "source-fold-envelope",
    "source-fold-output-claims",
    "product-proof-envelope",
    "public-statement",
    "obligation-root",
    "lane-summary-root",
    "aggregate-digests",
    "component-root",
    "proof-transcript",
]


def fail(message: str) -> None:
    print(f"product Swift trace/extractor evidence validation failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_string(value: Any, label: str) -> str:
    require(isinstance(value, str) and value, f"{label} must be a non-empty string")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def require_string_list(value: Any, label: str) -> list[str]:
    require(isinstance(value, list) and value, f"{label} must be a list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_string(item, f"{label}[{index}]"))
    return result


def require_relative_path(value: Any, label: str) -> Path:
    relative = Path(require_string(value, label))
    require(not relative.is_absolute(), f"{label} must be repository-relative")
    require(".." not in relative.parts, f"{label} must not escape the repository")
    absolute = ROOT / relative
    require(absolute.exists(), f"{label} does not exist: {relative}")
    return absolute


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {error}")
    require(isinstance(value, dict), "manifest root must be an object")
    return value


def validate(path: Path) -> None:
    manifest = read_json(path)
    require(manifest.get("schemaVersion") == 1, "schemaVersion must be 1")
    require(
        manifest.get("evidenceID") == "superneo-product-swift-trace-extractor-evidence-v1",
        "evidenceID mismatch",
    )
    require(
        manifest.get("claimStatus") == "swift-executable-trace-surface-pinned-not-production-extractor-theorem",
        "claimStatus must stay fail-closed",
    )

    surfaces = require_dict(manifest.get("implementationSurfaces"), "implementationSurfaces")
    product_api = require_relative_path(surfaces.get("productAPI"), "implementationSurfaces.productAPI")
    product_prover = require_relative_path(surfaces.get("productProver"), "implementationSurfaces.productProver")
    product_verifier = require_relative_path(surfaces.get("productVerifier"), "implementationSurfaces.productVerifier")
    tests = require_relative_path(surfaces.get("tests"), "implementationSurfaces.tests")

    trace = require_dict(manifest.get("traceSurface"), "traceSurface")
    require(trace.get("frontendContextDigestLabel") == "numiseal.product.frontend-context.v1", "frontend context label mismatch")
    require(trace.get("frontendObligationPath") == "r1cs-prepared-to-source-fold-output-claims-v1", "frontend obligation path mismatch")
    require(trace.get("swiftTraceExtractorSurface") == "source-fold-output-claims-to-numiseal-obligations-v1", "trace surface mismatch")
    require(trace.get("evidenceDigestLabel") == "numiseal.product.trace-extractor-equivalence.v1", "evidence digest label mismatch")
    require(trace.get("ctcoChallengeTapeLabel") == "numiseal-product-api-trace", "CTCO challenge tape label mismatch")
    require(require_string_list(trace.get("traceBlocks"), "traceSurface.traceBlocks") == REQUIRED_TRACE_BLOCKS, "trace block order mismatch")

    api_source = product_api.read_text(encoding="utf-8")
    prover_source = product_prover.read_text(encoding="utf-8")
    verifier_source = product_verifier.read_text(encoding="utf-8")
    joined_source = api_source + "\n" + prover_source + "\n" + verifier_source
    for needle in [
        "NumiSealProductTrustedContext",
        "NumiSealProductTraceExtractorEvidence",
        "NumiSealProductQROMEvidence",
        "numiseal.product.frontend-context.v1",
        "numiseal.product.trace-extractor-equivalence.v1",
        "source-fold-output-claims-to-numiseal-obligations-v1",
        "r1cs-prepared-to-source-fold-output-claims-v1",
        "ProofEnvelopeHeader.parsePrefix",
        "sourceFoldOutputClaimDigest",
    ]:
        require(needle in joined_source, f"source missing {needle}")
    for block in REQUIRED_TRACE_BLOCKS:
        require(block in api_source, f"product API trace block missing {block}")

    binding = require_dict(manifest.get("extractorBinding"), "extractorBinding")
    for key, value in binding.items():
        if key.endswith("Bound"):
            require(value is True, f"extractorBinding.{key} must be true")
    require(binding.get("sourceFoldOutputClaimDigestFunction") == "NumiSealProductProver.sourceFoldOutputClaimDigest", "sourceFoldOutputClaimDigestFunction mismatch")
    require(binding.get("proofEnvelopeHeaderParser") == "ProofEnvelopeHeader.parsePrefix", "proofEnvelopeHeaderParser mismatch")

    test_source = tests.read_text(encoding="utf-8")
    for test_name in require_string_list(manifest.get("coveredByTests"), "coveredByTests"):
        require(test_name in test_source, f"covered test not found: {test_name}")

    promotion = require_dict(manifest.get("promotionRule"), "promotionRule")
    require(promotion.get("productionExtractorClaimAllowed") is False, "productionExtractorClaimAllowed must be false")
    require(promotion.get("releaseEvidenceOnly") is True, "releaseEvidenceOnly must be true")
    boundaries = " ".join(require_string_list(promotion.get("remainingBoundaries"), "remainingBoundaries")).lower()
    for needle in ["code review", "numeric extractor", "total-loss"]:
        require(needle in boundaries, f"remaining boundaries must mention {needle}")


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not path.is_absolute():
        path = ROOT / path
    validate(path)
    print("product Swift trace/extractor evidence validation passed")


if __name__ == "__main__":
    main()
