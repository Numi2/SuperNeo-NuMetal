#!/usr/bin/env python3
"""Collect production-security promotion readiness status.

This script does not promote any claim. It records the evidence state that must
be true before production-security claim flags can be changed.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]

def read_json(relative_path: str) -> dict[str, Any]:
    path = ROOT / relative_path
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"{relative_path} is not valid JSON: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{relative_path} root must be an object")
    return value


def total_loss_status() -> dict[str, Any]:
    budget = read_json("TestVectors/product-total-loss-budget-v1.json")
    computed = budget.get("computedBudget", {})
    if not isinstance(computed, dict):
        computed = {}
    return {
        "allRequiredTermsInstantiated": computed.get("allRequiredTermsInstantiated") is True,
        "selectedDepthLossWithinBudget": computed.get("selectedDepthLossWithinBudget") is True,
        "productionTotalLossClaimAllowed": computed.get("productionTotalLossClaimAllowed") is True,
        "missingRequiredTermIDs": computed.get("missingRequiredTermIDs", []),
    }


def release_distribution_status() -> dict[str, Any]:
    evidence = read_json("TestVectors/product-release-distribution-evidence-v1.json")
    signing = evidence.get("signingStatus", {})
    if not isinstance(signing, dict):
        signing = {}
    required = [
        "releaseSigningKeySelected",
        "artifactSigningImplemented",
        "signedProvenanceFormatPinned",
        "notarizationOrPublicationPathPinned",
        "publicationProtectionEvidencePinned",
        "archivedReleaseEvidencePinned",
        "releaseDistributionLossInstantiated",
        "releaseDistributionLossWithinBudget",
    ]
    missing = [key for key in required if signing.get(key) is not True]
    return {
        "ready": not missing,
        "missingFlags": missing,
    }


def constant_time_status() -> dict[str, Any]:
    evidence = read_json("TestVectors/constant-time-lowering-evidence-v1.json")
    promotion = evidence.get("promotionRule", {})
    if not isinstance(promotion, dict):
        promotion = {}
    return {
        "productionConstantTimeClaimAllowed": promotion.get("productionConstantTimeClaimAllowed") is True,
    }


def crypto_dossier_blockers() -> list[str]:
    dossier = read_json("TestVectors/product-crypto-security-dossier-v1.json")
    blockers: list[str] = []
    if dossier.get("latticeAssumptionDossier", {}).get("productionPostQuantumClaimAllowed") is not True:
        blockers.append("post-quantum-claim-evidence")
    if dossier.get("fiatShamirQROMPosition", {}).get("productionQROMClaimAllowed") is not True:
        blockers.append("qrom-claim-evidence")
    if dossier.get("zkPrivacyProofStatus", {}).get("productionZKPrivacyClaimAllowed") is not True:
        blockers.append("zk-privacy-claim-evidence")
    return blockers


def collect() -> dict[str, Any]:
    total = total_loss_status()
    release = release_distribution_status()
    constant_time = constant_time_status()
    crypto_blockers = crypto_dossier_blockers()
    blockers = {
        "missingTotalLossTerms": total.get("missingRequiredTermIDs", []),
        "totalLossWithinBudget": total.get("selectedDepthLossWithinBudget") is True,
        "missingReleaseFlags": release.get("missingFlags", []),
        "constantTimeClaimAllowed": constant_time.get("productionConstantTimeClaimAllowed") is True,
        "cryptoEvidenceBlockers": crypto_blockers,
    }
    promotable = (
        not blockers["missingTotalLossTerms"]
        and blockers["totalLossWithinBudget"]
        and not blockers["missingReleaseFlags"]
        and blockers["constantTimeClaimAllowed"]
        and not blockers["cryptoEvidenceBlockers"]
    )

    return {
        "schemaVersion": 1,
        "productionSecurityClaimsPromotable": promotable,
        "blockers": blockers,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="write JSON status to this path")
    parser.add_argument(
        "--require-promotable",
        action="store_true",
        help="exit nonzero unless every production-security promotion condition is satisfied",
    )
    args = parser.parse_args()

    status = collect()
    encoded = json.dumps(status, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
        print(f"wrote {args.output}")
    else:
        sys.stdout.write(encoded)
    if args.require_promotable and not status["productionSecurityClaimsPromotable"]:
        print("production-security promotion is blocked", file=sys.stderr)
        print(json.dumps(status["blockers"], indent=2, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
