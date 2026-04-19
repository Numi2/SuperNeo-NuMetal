#!/usr/bin/env python3
"""Collect production-security promotion readiness status.

This script does not promote any claim. It records the evidence state that must
be true before production-security claim flags can be changed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


def run_text(*command: str) -> tuple[int, str, str]:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.returncode, completed.stdout.strip(), completed.stderr.strip()


def read_json(relative_path: str) -> dict[str, Any]:
    path = ROOT / relative_path
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"{relative_path} is not valid JSON: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{relative_path} root must be an object")
    return value


def local_signing_identities() -> dict[str, Any]:
    code, stdout, stderr = run_text("security", "find-identity", "-v", "-p", "codesigning")
    identities: list[str] = []
    if code == 0:
        for line in stdout.splitlines():
            stripped = line.strip()
            if stripped and ")" in stripped and '"' in stripped:
                identities.append(stripped)
    gpg_code, gpg_stdout, gpg_stderr = run_text("gpg", "--list-secret-keys", "--keyid-format=long")
    return {
        "appleCodeSigningIdentityCount": len(identities),
        "appleCodeSigningIdentities": identities,
        "gpgSecretKeyAvailable": gpg_code == 0 and bool(gpg_stdout.strip()),
        "gpgStatus": "available" if gpg_code == 0 and bool(gpg_stdout.strip()) else "unavailable",
        "gpgDetail": "" if gpg_code == 0 else gpg_stderr,
    }


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
        "exactSelectedDepthLossUpperBound": computed.get("exactSelectedDepthLossUpperBound"),
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
        "hostedBranchProtectionEvidencePinned",
        "archivedReleaseEvidencePinned",
        "releaseDistributionLossInstantiated",
        "releaseDistributionLossWithinBudget",
        "productionReleaseDistributionClaimAllowed",
    ]
    missing = [key for key in required if signing.get(key) is not True]
    return {
        "allSigningStatusFlagsTrue": not missing,
        "missingSigningStatusFlags": missing,
        "claimStatus": evidence.get("claimStatus"),
        "statusSource": "checked-in-release-distribution-evidence",
    }


def constant_time_status() -> dict[str, Any]:
    evidence = read_json("TestVectors/constant-time-lowering-evidence-v1.json")
    promotion = evidence.get("promotionRule", {})
    if not isinstance(promotion, dict):
        promotion = {}
    return {
        "productionConstantTimeClaimAllowed": promotion.get("productionConstantTimeClaimAllowed") is True,
        "releaseEvidenceOnly": promotion.get("releaseEvidenceOnly") is True,
        "unblockRequires": promotion.get("unblockRequires", []),
    }


def crypto_dossier_status() -> dict[str, Any]:
    dossier = read_json("TestVectors/product-crypto-security-dossier-v1.json")
    promotion = dossier.get("promotionRule", {})
    if not isinstance(promotion, dict):
        promotion = {}
    flags = {
        key: promotion.get(key) is True
        for key in [
            "productionProductSecurityClaimAllowed",
            "productionPostQuantumClaimAllowed",
            "productionQROMClaimAllowed",
            "productionZKPrivacyClaimAllowed",
            "productionRecursiveCarryClaimAllowed",
            "productionPerformanceClaimAllowed",
            "productionConstantTimeClaimAllowed",
            "productionReleaseDistributionClaimAllowed",
        ]
    }
    return {
        "claimStatus": dossier.get("claimStatus"),
        "promotionFlags": flags,
        "allPromotionFlagsTrue": all(flags.values()),
    }


def collect() -> dict[str, Any]:
    total = total_loss_status()
    release = release_distribution_status()
    constant_time = constant_time_status()
    dossier = crypto_dossier_status()
    blockers: list[str] = []

    for term in total.get("missingRequiredTermIDs", []):
        blockers.append(f"total-loss term not instantiated: {term}")
    if total.get("selectedDepthLossWithinBudget") is not True:
        blockers.append("selected-depth total loss is not proved within 2^-128")
    for flag in release.get("missingSigningStatusFlags", []):
        blockers.append(f"release-distribution evidence flag is not true: {flag}")
    if constant_time.get("productionConstantTimeClaimAllowed") is not True:
        blockers.append("constant-time production claim is not allowed by lowering evidence")
    for flag, enabled in dossier.get("promotionFlags", {}).items():
        if not enabled:
            blockers.append(f"crypto dossier promotion flag is not true: {flag}")

    return {
        "schemaVersion": 1,
        "generatedAtUTC": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "repository": {
            "root": str(ROOT),
        },
        "localSigning": local_signing_identities(),
        "totalLossBudget": total,
        "releaseDistribution": release,
        "constantTime": constant_time,
        "cryptoSecurityDossier": dossier,
        "productionSecurityClaimsPromotable": not blockers,
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
        for blocker in status["blockers"]:
            print(f"- {blocker}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
