#!/usr/bin/env python3
"""Validate product CTCO/QROM instantiation evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "TestVectors" / "product-qrom-ctco-instantiation-v1.json"


def fail(message: str) -> None:
    print(f"product QROM CTCO instantiation validation failed: {message}", file=sys.stderr)
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
    require(manifest.get("evidenceID") == "superneo-product-qrom-ctco-instantiation-v1", "evidenceID mismatch")
    require(
        manifest.get("claimStatus") == "ctco-split-oracle-instantiation-pinned-repository-local-production-qrom-theorem",
        "claimStatus must record repository-local production",
    )

    surfaces = require_dict(manifest.get("implementationSurfaces"), "implementationSurfaces")
    split_oracle = require_relative_path(surfaces.get("splitOracle"), "implementationSurfaces.splitOracle")
    transcript = require_relative_path(surfaces.get("transcript"), "implementationSurfaces.transcript")
    product_api = require_relative_path(surfaces.get("productAPI"), "implementationSurfaces.productAPI")
    product_prover = require_relative_path(surfaces.get("productProver"), "implementationSurfaces.productProver")
    tests = require_relative_path(surfaces.get("tests"), "implementationSurfaces.tests")
    source = split_oracle.read_text(encoding="utf-8") + "\n" + transcript.read_text(encoding="utf-8") + "\n" + product_api.read_text(encoding="utf-8") + "\n" + product_prover.read_text(encoding="utf-8")

    compiler = require_dict(manifest.get("ctcoCompiler"), "ctcoCompiler")
    require(compiler.get("family") == "ctco", "CTCO family mismatch")
    require(compiler.get("challengeOracle") == "H_chal", "challenge oracle mismatch")
    require(compiler.get("bindingOracle") == "H_bind", "binding oracle mismatch")
    require(compiler.get("challengeDomain") == "superneo/numiseal/chal/v2", "challenge domain mismatch")
    require(compiler.get("bindingDomain") == "superneo/numiseal/bind/v2", "binding domain mismatch")
    require(compiler.get("contextBinderBits") == 384, "context binder width mismatch")
    require(compiler.get("ctcoRootBits") == 384, "CTCO root width mismatch")
    require(compiler.get("challengeSeedBits") == 256, "challenge seed width mismatch")
    require(compiler.get("challengeTapeLabel") == "numiseal-product-api-trace", "challenge tape label mismatch")
    expansion = require_string(compiler.get("challengeTapeExpansion"), "ctcoCompiler.challengeTapeExpansion")
    for needle in ["SuperNeoChallengeTape", "one H_chal seed", "SuperNeoSplitQRO.expandChallenge"]:
        require(needle in expansion, f"challengeTapeExpansion must mention {needle}")
    for key in require_string_list(compiler.get("metadataKeys"), "ctcoCompiler.metadataKeys"):
        require(key in source, f"metadata key missing from source: {key}")
    for needle in [
        "SuperNeoSplitQRO",
        "SuperNeoChallengeTape",
        "SumCheckTranscript",
        "CTCOMoveOneCommitment",
        "CTCOMerkleOpening",
        "ProofEnvelopeCTCOVerifier",
        "hChal",
        "hBind",
        "hMerkleLeaf",
        "Digest384",
        "challengeTapeSeed",
        "expansionDigest",
        "numiseal.product.qrom.ctco.qro-evidence.v1",
    ]:
        require(needle in source, f"source missing {needle}")

    bounds = require_dict(manifest.get("numericBounds"), "numericBounds")
    require(bounds.get("queryBoundQH") == "2^64", "queryBoundQH mismatch")
    require(bounds.get("queryBoundLog2") == 64, "queryBoundLog2 mismatch")
    require(bounds.get("bindingDigestBits") == 384, "bindingDigestBits must be 384")
    require(bounds.get("bindingTargetEventCount") == 11, "bindingTargetEventCount must be 11")
    require(bounds.get("bindingCollisionFormula") == "4 * bindingTargetEventCount * Q_H^2 / 2^bindingDigestBits", "binding formula mismatch")
    require(bounds.get("bindingCollisionInstantiatedExpression") == "4 * 11 * 2^128 / 2^384 = 44 * 2^-256", "binding expression mismatch")
    require(bounds.get("bindingCollisionBoundLog2Floor") == 250, "binding bound floor mismatch")
    require(bounds.get("proofKindMalleabilityFormula") == "0", "proof-kind malleability formula mismatch")
    require(bounds.get("proofKindMalleabilityChargedToCollisionLedger") is True, "proof-kind malleability ledger mapping must be true")

    test_source = tests.read_text(encoding="utf-8")
    for test_name in require_string_list(manifest.get("coveredByTests"), "coveredByTests"):
        require(test_name in test_source, f"covered test not found: {test_name}")

    promotion = require_dict(manifest.get("promotionRule"), "promotionRule")
    require(
        promotion.get("repositoryLocalIdealQROMClaimAllowed") is True,
        "repositoryLocalIdealQROMClaimAllowed must be true",
    )
    require(
        promotion.get("productionQROMClaimAllowed") is False,
        "productionQROMClaimAllowed must stay false until concrete hash instantiation closes",
    )
    require(
        promotion.get("requiresConcreteHashQROInstantiation") is True,
        "requiresConcreteHashQROInstantiation must be true",
    )
    require(promotion.get("selectedTotalLossClaimAllowed") is True, "selectedTotalLossClaimAllowed must be true")
    boundaries = " ".join(require_string_list(promotion.get("remainingBoundaries"), "remainingBoundaries")).lower()
    for needle in ["epsilon_compiler_overhead is instantiated as 0", "delayed-message", "unique-response"]:
        require(needle in boundaries, f"remaining boundaries must mention {needle}")
    require(
        "compiler_overhead remains uninstantiated" not in boundaries,
        "remaining boundaries must not leave epsilon_compiler_overhead open",
    )


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else MANIFEST
    if not path.is_absolute():
        path = ROOT / path
    validate(path)
    print("product QROM CTCO instantiation validation passed")


if __name__ == "__main__":
    main()
