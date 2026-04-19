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
    if payload.get("productionSecurityClaimsPromotable") is not True:
        raise AssertionError("repository-local promotion status must be promotable")
    blockers = payload.get("blockers")
    if blockers != {}:
        raise AssertionError("repository-local promotion status must not carry blockers")
    for external_term in ["product-ops-replay", "release-distribution", "constant-time-side-channel"]:
        if external_term in encoded_payload:
            raise AssertionError(f"{external_term} must not block repository-local promotion status")
    if "missingreleaseflags" in encoded_payload:
        raise AssertionError("release distribution flags must not block local promotion status")
    if "cryptoevidenceblockers" in encoded_payload:
        raise AssertionError("claim attestations must not block repository-local promotion status")
    for optional_flag in ["productionRecursiveCarryClaimAllowed", "productionPerformanceClaimAllowed"]:
        if optional_flag in encoded_payload:
            raise AssertionError(f"{optional_flag} must not block core production-security promotion")
    for final_flag in ["productionProductSecurityClaimAllowed", "productionReleaseDistributionClaimAllowed"]:
        if final_flag in encoded_payload:
            raise AssertionError(f"{final_flag} is an output flag, not a promotion-readiness blocker")

    required = run(str(COLLECT), "--require-promotable")
    if required.returncode != 0:
        raise AssertionError(required.stderr)

    with tempfile.TemporaryDirectory(prefix=".prod-promotion-test-", dir=ROOT) as raw_tmp:
        status_path = Path(raw_tmp) / "status.json"
        status_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        promoted = run(str(PROMOTE), "--status", str(status_path), "--dry-run")
        if promoted.returncode != 0:
            raise AssertionError(promoted.stderr)

    print("production security promotion tooling tests passed")


if __name__ == "__main__":
    main()
