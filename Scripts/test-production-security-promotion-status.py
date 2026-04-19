#!/usr/bin/env python3
"""Regression tests for guarded production-security promotion tooling."""

from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COLLECT = ROOT / "Scripts" / "collect-production-security-promotion-status.py"
PROMOTE = ROOT / "Scripts" / "promote-production-security-claims.py"


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> None:
    status = run(str(COLLECT))
    if status.returncode != 0:
        raise AssertionError(status.stderr or status.stdout)
    payload = json.loads(status.stdout)
    encoded_payload = json.dumps(payload, sort_keys=True).lower()
    if "github" in encoded_payload:
        raise AssertionError("production promotion status must not depend on GitHub state")
    if "localsigning" in encoded_payload or "repository" in encoded_payload:
        raise AssertionError("production promotion status must stay compact")
    allowed_keys = {"schemaVersion", "productionSecurityClaimsPromotable", "blockers"}
    if set(payload) != allowed_keys:
        raise AssertionError(f"collector payload must stay compact: {sorted(payload)}")
    if payload.get("productionSecurityClaimsPromotable") is not False:
        raise AssertionError("current checked-in evidence must not be promotable")
    blockers = payload.get("blockers")
    if not isinstance(blockers, dict) or not blockers:
        raise AssertionError("collector must report compact blocker groups")
    missing_terms = blockers.get("missingTotalLossTerms")
    if not isinstance(missing_terms, list) or "product-ops-replay" not in missing_terms:
        raise AssertionError("collector must report missing total-loss terms")
    missing_dossier = blockers.get("missingDossierFlags")
    if not isinstance(missing_dossier, list):
        raise AssertionError("collector must report missing dossier flags")
    for optional_flag in ["productionRecursiveCarryClaimAllowed", "productionPerformanceClaimAllowed"]:
        if optional_flag in missing_dossier:
            raise AssertionError(f"{optional_flag} must not block core production-security promotion")

    required = run(str(COLLECT), "--require-promotable")
    if required.returncode == 0:
        raise AssertionError("--require-promotable must fail on current evidence")
    if "production-security promotion is blocked" not in required.stderr:
        raise AssertionError(required.stderr)

    with tempfile.TemporaryDirectory(prefix=".prod-promotion-test-", dir=ROOT) as raw_tmp:
        status_path = Path(raw_tmp) / "status.json"
        status_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        promoted = run(str(PROMOTE), "--status", str(status_path), "--dry-run")
        if promoted.returncode == 0:
            raise AssertionError("guarded promotion must reject non-promotable evidence")
        if "evidence is not promotable" not in promoted.stderr:
            raise AssertionError(promoted.stderr)

    print("production security promotion tooling tests passed")


if __name__ == "__main__":
    main()
