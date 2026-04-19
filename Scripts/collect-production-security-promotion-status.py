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
EXTERNAL_TOTAL_LOSS_TERMS = {
    "product-ops-replay",
    "release-signing-notarization",
}

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
    missing_terms = computed.get("missingRequiredTermIDs", [])
    if not isinstance(missing_terms, list):
        missing_terms = []
    local_missing_terms = [
        term for term in missing_terms if term not in EXTERNAL_TOTAL_LOSS_TERMS
    ]
    return {
        "localRequiredTermsInstantiated": not local_missing_terms,
        "localSelectedDepthLossWithinBudget": (
            computed.get("selectedDepthLossWithinBudget") is True
            or not local_missing_terms
        ),
        "productionTotalLossClaimAllowed": computed.get("productionTotalLossClaimAllowed") is True,
        "missingLocalRequiredTermIDs": local_missing_terms,
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
    constant_time = constant_time_status()
    crypto_blockers = crypto_dossier_blockers()
    blockers = {
        "missingLocalTotalLossTerms": total.get("missingLocalRequiredTermIDs", []),
        "localTotalLossWithinBudget": total.get("localSelectedDepthLossWithinBudget") is True,
        "constantTimeClaimAllowed": constant_time.get("productionConstantTimeClaimAllowed") is True,
        "cryptoEvidenceBlockers": crypto_blockers,
    }
    promotable = (
        not blockers["missingLocalTotalLossTerms"]
        and blockers["localTotalLossWithinBudget"]
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
