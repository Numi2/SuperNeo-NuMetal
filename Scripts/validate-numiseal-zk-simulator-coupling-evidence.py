#!/usr/bin/env python3
"""Validate NumiSealZK product simulator-coupling evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "numiseal-zk-simulator-coupling-evidence-v1.json"


def fail(message: str) -> None:
    print(f"NumiSealZK simulator-coupling evidence validation failed: {message}", file=sys.stderr)
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
    require(manifest.get("evidenceID") == "numiseal-zk-simulator-coupling-evidence-v1", "evidenceID mismatch")
    require(
        manifest.get("claimStatus") == "product-simulator-coupling-surface-pinned-not-production-zk-privacy",
        "claimStatus must stay fail-closed",
    )

    surfaces = require_dict(manifest.get("implementationSurfaces"), "implementationSurfaces")
    product_prover = require_relative_path(surfaces.get("productProver"), "implementationSurfaces.productProver")
    zk_proof = require_relative_path(surfaces.get("zkProof"), "implementationSurfaces.zkProof")
    side_channel = require_relative_path(surfaces.get("sideChannelCertificate"), "implementationSurfaces.sideChannelCertificate")
    tests = require_relative_path(surfaces.get("tests"), "implementationSurfaces.tests")

    source = product_prover.read_text(encoding="utf-8") + "\n" + zk_proof.read_text(encoding="utf-8")
    for needle in [
        "numiseal.zk.product.simulator-coupling.v1",
        "zkSimulatorCouplingSurface",
        "zkSimulatorCouplingEvidenceDigest",
        "zkRandomnessSessionDigest",
        "zkLeakageDigest",
        "zkMaskedResidualStatementCount",
        "componentDigestRoot",
        "proofTranscriptDigest",
    ]:
        require(needle in source, f"source missing {needle}")
    require("NumiSealZKSideChannelCertificate" in side_channel.read_text(encoding="utf-8"), "side-channel certificate source missing certificate type")

    coupling = require_dict(manifest.get("couplingSurface"), "couplingSurface")
    require(coupling.get("digestLabel") == "numiseal.zk.product.simulator-coupling.v1", "digest label mismatch")
    require(coupling.get("metadataSurface") == "terminal-base-proof-to-masked-residual-session-v1", "metadata surface mismatch")
    require(coupling.get("metadataDigestKey") == "zkSimulatorCouplingEvidenceDigest", "metadata digest key mismatch")
    fields = " ".join(require_string_list(coupling.get("boundFields"), "couplingSurface.boundFields")).lower()
    for needle in ["base terminal proof", "randomness session", "declared leakage", "component", "transcript"]:
        require(needle in fields, f"coupling fields must mention {needle}")

    pins = require_dict(manifest.get("benchmarkAndSideChannelPins"), "benchmarkAndSideChannelPins")
    require(pins.get("productSizedBenchmarkRowsPinned") is True, "productSizedBenchmarkRowsPinned must be true")
    require(pins.get("sideChannelCertificateRequiredBeforeDefaultPromotion") is True, "sideChannelCertificateRequiredBeforeDefaultPromotion must be true")
    benchmark = read_json(ROOT / "TestVectors" / "benchmark-coverage-v1.json")
    benchmark_text = json.dumps(benchmark, sort_keys=True)
    for row in require_string_list(pins.get("benchmarkRows"), "benchmarkAndSideChannelPins.benchmarkRows"):
        require(row in benchmark_text, f"benchmark row not pinned: {row}")

    test_source = tests.read_text(encoding="utf-8")
    for test_name in require_string_list(manifest.get("coveredByTests"), "coveredByTests"):
        require(test_name in test_source, f"covered test not found: {test_name}")

    promotion = require_dict(manifest.get("promotionRule"), "promotionRule")
    require(promotion.get("productionZKPrivacyClaimAllowed") is False, "productionZKPrivacyClaimAllowed must be false")
    require(promotion.get("zkDefaultPromotionAllowed") is False, "zkDefaultPromotionAllowed must be false")
    boundaries = " ".join(require_string_list(promotion.get("remainingBoundaries"), "remainingBoundaries")).lower()
    for needle in ["benchmark", "side-channel", "epsilon_zk_sim"]:
        require(needle in boundaries, f"remaining boundaries must mention {needle}")


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not path.is_absolute():
        path = ROOT / path
    validate(path)
    print("NumiSealZK simulator-coupling evidence validation passed")


if __name__ == "__main__":
    main()
